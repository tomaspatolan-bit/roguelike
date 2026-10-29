extends CanvasLayer
## Rozhraní bitvy. Neobsahuje herní logiku: jen vykresluje stav a posílá signály do battle.gd.
##
## Rozvržení: nahoře lišta velení (čas, sláva, signál, Do boje!, rychlost; v rozestavení
## signály a Začít bitvu), vlevo nahoře karta bitvy (scénář, úkol, rod), dole karty rytířů,
## vpravo nahoře malý deník bitvy (dá se sbalit), nad jednotkami zdraví a ikonky stavu.

const Sim := preload("res://scripts/sim/battle_sim.gd")
const Icon := preload("res://scripts/battle/ui_icon.gd")

signal knight_clicked(id: String)
signal ability_pressed(id: String)
signal passive_toggled(id: String, key: String, on: bool)
signal scenario_changed(id: String)
signal route_draw_pressed(id: String)
signal route_clear_pressed(id: String)
signal signals_count_changed(count: int)
signal start_pressed
signal signal_pressed
signal charge_pressed
signal resume_pressed
signal speed_changed(value: float)
signal continue_pressed
signal retry_pressed
signal redeploy_pressed
signal run_continue_pressed

const INK := Color("#e7e9ec")
const MUTED := Color("#9aa3ad")
const PANEL_BG := Color("#1b1f24")
const LINE := Color("#2f353c")
const BANNER := Color("#d0433b")
const GLORY := Color("#e2b84a")
const OK := Color("#5bb36a")
const BAD := Color("#ef6b62")
const STEEL := Color("#8aa2e0")
const CARD_W := 196.0

## Ikona schopnosti podle klíče (zástupné).
const ABILITY_ICONS := {"vyzva": "hradba", "pozehnani": "heal", "salva": "lucistnik", "najezd": "charge", "uder": "asasin"}

var root: Control
var top_bar: PanelContainer
var top_row: HBoxContainer
var info_card: PanelContainer
var info_box: VBoxContainer
var cards_row: HBoxContainer
var log_panel: PanelContainer
var bars_layer: Control
var toast: PanelContainer
var toast_label: Label
var result_box: PanelContainer
var oath_dialog: ConfirmationDialog
var scenario_choices: Array = []   # [[klíč, název], ...] pro výběr bitvy
var run_mode := false              # bitva je součástí běhu: bez výběru bitvy, pasivky jen ke čtení
var run_label := ""                # např. "Bitva 2 ze 3"

var _overhead: Dictionary = {}     # id -> {"root", "fill", "bg", "icons", "sig"}
var _cards: Dictionary = {}        # id -> {"hp": ProgressBar, "icons": HBoxContainer, "sig": String}
var _glory_bar: ProgressBar
var _glory_label: Label
var _time_label: Label
var _ability_buttons: Dictionary = {}   # id hrdiny -> Button
var _hint: Label
var _hint_t := 0.0
var _signal_button: Button
var _charge_button: Button
var _log_box: VBoxContainer
var _log_open := true
var _oath_break_cb: Callable
var _oath_keep_cb: Callable


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)

	bars_layer = Control.new()
	bars_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	bars_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bars_layer)

	# lišta velení nahoře uprostřed
	top_bar = PanelContainer.new()
	top_bar.anchor_left = 0.5
	top_bar.anchor_right = 0.5
	top_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top_bar.offset_top = 10
	top_bar.add_theme_stylebox_override("panel", _box(Color(PANEL_BG, 0.92), 10, 8, LINE, 1))
	root.add_child(top_bar)
	top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	top_bar.add_child(top_row)

	# karta bitvy vlevo nahoře
	info_card = PanelContainer.new()
	info_card.position = Vector2(12, 12)
	info_card.custom_minimum_size = Vector2(300, 0)
	info_card.add_theme_stylebox_override("panel", _box(Color(PANEL_BG, 0.92), 10, 12, LINE, 1))
	root.add_child(info_card)
	info_box = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 6)
	info_card.add_child(info_box)

	# karty rytířů dole uprostřed
	var cards_holder := CenterContainer.new()
	cards_holder.anchor_left = 0.0
	cards_holder.anchor_right = 1.0
	cards_holder.anchor_top = 1.0
	cards_holder.anchor_bottom = 1.0
	cards_holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	cards_holder.offset_bottom = -10
	cards_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cards_holder)
	cards_row = HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 8)
	cards_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards_holder.add_child(cards_row)

	# deník vpravo nahoře
	log_panel = PanelContainer.new()
	log_panel.anchor_left = 1.0
	log_panel.anchor_right = 1.0
	log_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	log_panel.offset_top = 12
	log_panel.offset_right = -12
	log_panel.custom_minimum_size = Vector2(290, 0)
	log_panel.add_theme_stylebox_override("panel", _box(Color(PANEL_BG, 0.85), 10, 10, LINE, 1))
	root.add_child(log_panel)
	var lv := VBoxContainer.new()
	log_panel.add_child(lv)
	var lh := Button.new()
	lh.flat = true
	lh.alignment = HORIZONTAL_ALIGNMENT_LEFT
	lh.add_theme_font_size_override("font_size", 12)
	lh.add_theme_color_override("font_color", MUTED)
	lh.text = "DENÍK BITVY  ▾"
	lh.focus_mode = Control.FOCUS_NONE
	lh.pressed.connect(func() -> void:
		_log_open = not _log_open
		lh.text = "DENÍK BITVY  ▾" if _log_open else "DENÍK BITVY  ▸"
		_log_box.visible = _log_open)
	lv.add_child(lh)
	_log_box = VBoxContainer.new()
	lv.add_child(_log_box)

	toast = PanelContainer.new()
	toast.anchor_left = 0.5
	toast.anchor_right = 0.5
	toast.anchor_top = 1.0
	toast.anchor_bottom = 1.0
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast.offset_bottom = -200
	toast.add_theme_stylebox_override("panel", _box(Color(0.08, 0.09, 0.11, 0.94), 8, 14, BANNER, 1))
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 14)
	toast.add_child(th)
	toast_label = Label.new()
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.custom_minimum_size = Vector2(380, 0)
	th.add_child(toast_label)
	var tb := Button.new()
	tb.text = "Pokračovat  [Mezerník]"
	tb.focus_mode = Control.FOCUS_NONE
	tb.pressed.connect(func() -> void: continue_pressed.emit())
	th.add_child(tb)
	toast.visible = false
	root.add_child(toast)

	_hint = _label("", 15, Color.WHITE)
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.offset_top = 64
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hint.add_theme_constant_override("outline_size", 5)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint)

	result_box = PanelContainer.new()
	result_box.set_anchors_preset(Control.PRESET_CENTER)
	result_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	result_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	result_box.custom_minimum_size = Vector2(420, 0)
	result_box.visible = false
	root.add_child(result_box)

	oath_dialog = ConfirmationDialog.new()
	oath_dialog.title = "Přísaha"
	oath_dialog.ok_button_text = "Porušit přísahu"
	oath_dialog.cancel_button_text = "Zrušit rozkaz"
	oath_dialog.dialog_autowrap = true
	oath_dialog.min_size = Vector2i(440, 0)
	oath_dialog.confirmed.connect(func() -> void:
		if _oath_break_cb.is_valid():
			_oath_break_cb.call())
	oath_dialog.canceled.connect(func() -> void:
		if _oath_keep_cb.is_valid():
			_oath_keep_cb.call())
	add_child(oath_dialog)


# ================================================================ téma a pomocníci

func _box(bg: Color, radius: int, pad: int, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	return s


func _make_theme() -> Theme:
	var t := Theme.new()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "DejaVu Sans", "Arial"])
	t.default_font = f
	t.default_font_size = 15
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("panel", "PanelContainer", _box(Color(PANEL_BG, 0.95), 10, 16, LINE, 1))
	t.set_stylebox("normal", "Button", _box(Color("#252a31"), 7, 8, LINE, 1))
	t.set_stylebox("hover", "Button", _box(Color("#2e343c"), 7, 8, MUTED, 1))
	t.set_stylebox("pressed", "Button", _box(Color("#3a414b"), 7, 8, MUTED, 1))
	t.set_stylebox("disabled", "Button", _box(Color("#1f2328"), 7, 8, LINE, 1))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), 7, 8, STEEL, 2))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.5))
	return t


func _label(text: String, size: int = 15, color: Color = INK, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _primary(b: Button, col: Color = BANNER) -> Button:
	b.add_theme_stylebox_override("normal", _box(col, 7, 10))
	b.add_theme_stylebox_override("hover", _box(col.lightened(0.1), 7, 10))
	b.add_theme_stylebox_override("pressed", _box(col.darkened(0.1), 7, 10))
	b.add_theme_stylebox_override("disabled", _box(col.darkened(0.55), 7, 10))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_font_size_override("font_size", 16)
	return b


func _bar(fill: Color, h: int = 6) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, h)
	p.add_theme_stylebox_override("background", _box(LINE, 3, 0))
	p.add_theme_stylebox_override("fill", _box(fill, 3, 0))
	return p


## Tlačítko s ikonkou a textem (popisek je Label uvnitř, aby šel měnit v update_dynamic).
func _icon_button(kind: String, text: String, icon_col: Color = INK) -> Button:
	var b := Button.new()
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 6)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -8
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := Icon.make(kind, icon_col, 18)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	if text != "":
		var l := _label(text, 13)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
	b.add_child(h)
	b.custom_minimum_size = Vector2(maxf(36.0, 34.0 + text.length() * 7.5), 36)
	return b


func _clear() -> void:
	for c in top_row.get_children():
		c.queue_free()
	for c in info_box.get_children():
		c.queue_free()
	for c in cards_row.get_children():
		c.queue_free()
	_cards.clear()
	_ability_buttons.clear()
	_signal_button = null
	_charge_button = null
	_glory_bar = null
	_time_label = null


## Ikona třídy rytíře.
static func class_icon(u: Sim.Unit) -> String:
	return u.key if u.key in ["tank", "knez", "lucistnik", "jezdec", "asasin"] else "tank"


## Ikonky stavu jednotky: [druh, barva, přeškrtnutá, popisek]. Jen čte simulaci.
func _status_icons(sim: Sim, u: Sim.Unit, in_battle: bool) -> Array:
	var out: Array = []
	if u.side == Sim.SIDE_KNIGHT:
		for k: String in u.passives:
			var pd: Dictionary = sim.units_data["passives"][k]
			if pd.get("kind", "") == "oath":
				out.append(["oath", GLORY, u.oath_broken, "Přísaha %s%s: %s" % [pd["name"], " (zlomena)" if u.oath_broken else "", pd["desc"]]])
			else:
				out.append(["glory", Color(STEEL, 0.9), false, "%s: %s" % [pd["name"], pd["desc"]]])
		if in_battle and u.alive():
			if u.taunt_t > 0.0:
				out.append(["hradba", STEEL, false, "Výzva: nepřátelé útočí na něj, poloviční zranění"])
			if u.holding:
				out.append(["hold", Color(1, 1, 1, 0.8), false, "Drží místo z rozkazu"])
		if sim.on_route(u):
			out.append(["route", Color(1.0, 0.92, 0.55), false, "Jde po trase"])
	else:
		if u.stun_t > 0.0:
			out.append(["glory", STEEL, false, "Omráčený"])
		if u.fleeing:
			out.append(["flee", MUTED, false, "Prchá"])
		elif u.desperate:
			out.append(["desperate", BAD, false, "Zoufalý: útočí silněji"])
		elif u.hold:
			out.append(["hold", MUTED, false, "Drží pozici"])
		for tr: String in u.traits:
			if tr == "fanatik":
				out.append(["fanatik", Color("#f08a3c"), false, "Fanatik: nikdy se nezlomí"])
			elif tr == "zbabelec":
				out.append(["zbabelec", Color("#c9c3a6"), false, "Zbabělec: uteče, když se morálka zlomí"])
		if u.vs_mounted > 1.0:
			out.append(["jezdec", BAD, true, "Kopí: proti jízdě 2× poškození"])
	return out


func _fill_icons(box: HBoxContainer, icons: Array, px: float) -> void:
	for c in box.get_children():
		c.queue_free()
	for it: Array in icons:
		var ic := Icon.make(it[0], it[1], px, it[3])
		ic.set("crossed", it[2])
		box.add_child(ic)


static func _sig(icons: Array) -> String:
	var s := ""
	for it: Array in icons:
		s += "%s%s%s|" % [it[0], it[2], it[3]]
	return s


# ================================================================ rozestavení

func show_deploy(sim: Sim, setup: Dictionary, selected: String, scenario_id: String = "", route_id: String = "") -> void:
	_clear()
	_fill_info(sim, true, scenario_id)

	# lišta: signály a začátek bitvy
	var si := Icon.make("signal", MUTED, 20, "Signál praporu zastaví čas: kolik jich na bitvu (experiment)")
	si.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(si)
	var sl := _label("Signály: %d" % int(setup["signals"]) if run_mode else "Signály", 14, MUTED)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(sl)
	var group := ButtonGroup.new()
	for n in (0 if run_mode else 3):
		var b := Button.new()
		b.text = str(n)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = int(setup["signals"]) == n
		b.custom_minimum_size = Vector2(36, 36)
		b.pressed.connect(func() -> void: signals_count_changed.emit(n))
		top_row.add_child(b)
	var start := _primary(Button.new())
	start.text = "Začít bitvu"
	start.custom_minimum_size = Vector2(150, 36)
	start.pressed.connect(func() -> void: start_pressed.emit())
	top_row.add_child(start)

	_build_cards(sim, selected, true, false, route_id, "")
	_time_label = null
	set_log([])
	update_dynamic(sim, false, false)
	_no_focus(root)


func _fill_info(sim: Sim, deploy: bool, scenario_id: String) -> void:
	var sc := sim.scenario
	if deploy and scenario_choices.size() > 1:
		var pick := OptionButton.new()
		var i := 0
		for ch: Array in scenario_choices:
			pick.add_item("Bitva: %s" % ch[1])
			pick.set_item_metadata(i, ch[0])
			if ch[0] == scenario_id:
				pick.select(i)
			i += 1
		pick.item_selected.connect(func(index: int) -> void: scenario_changed.emit(String(pick.get_item_metadata(index))))
		info_box.add_child(pick)
	info_box.add_child(_label("%s · %s" % [run_label if run_mode and run_label != "" else sc["stage_label"], sim.house["name"]], 12, MUTED))
	info_box.add_child(_label(sc["name"], 24 if deploy else 20))
	if deploy:
		info_box.add_child(_label(sc["subtitle"], 13, MUTED, true))
	var md: Dictionary = sim.units_data.get("battle_modes", {}).get(sim.mode, {})
	if not md.is_empty():
		info_box.add_child(_label("%s: %s" % [md.get("name", ""), md.get("desc", "")], 13, STEEL, true))
	if sim.waves_left > 0:
		info_box.add_child(_label("Ještě přijde vln: %d" % sim.waves_left, 13, GLORY))
	var task: Dictionary = sc["optional_task"]
	var tb := PanelContainer.new()
	var st := _box(Color(GLORY, 0.10), 6, 8)
	st.border_color = GLORY
	st.border_width_left = 3
	tb.add_theme_stylebox_override("panel", st)
	tb.add_child(_label("Úkol: %s Odměna: %s." % [task["text"], task["reward"]], 13, INK, true))
	info_box.add_child(tb)
	if deploy:
		info_box.add_child(_label("Každý hrdina má výchozí chování podle třídy a jednu schopnost na kartě (počet použití za bitvu). Sláva rodu platí jedno použití navíc za bitvu (%d slávy)." % int(sim.house["glory"]["extra_use_cost"]), 12, MUTED, true))
		info_box.add_child(_label("Přetáhni rytíře v modré zóně (puštěním na jiného je prohodíš). Na kartě hrdiny dole můžeš nakreslit trasu.", 12, MUTED, true))


# ================================================================ bitva

func show_battle(sim: Sim, signal_phase: bool, selected: String, speed: float, log_lines: Array, aim_id: String = "") -> void:
	_clear()
	_fill_info(sim, false, "")

	_time_label = _label("0:00", 16, INK)
	_time_label.custom_minimum_size = Vector2(44, 0)
	_time_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(_time_label)

	var gl := HBoxContainer.new()
	gl.add_theme_constant_override("separation", 4)
	gl.tooltip_text = "Sláva rodu: roste za činy hrdinů. Za %d slávy dostane hrdina jedno použití schopnosti navíc za bitvu." % int(sim.house["glory"]["extra_use_cost"])
	var gi := Icon.make("glory", GLORY, 18)
	gi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gl.add_child(gi)
	_glory_bar = _bar(GLORY, 10)
	_glory_bar.custom_minimum_size = Vector2(110, 10)
	_glory_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gl.add_child(_glory_bar)
	_glory_label = _label("0", 14, GLORY)
	_glory_label.custom_minimum_size = Vector2(28, 0)
	_glory_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gl.add_child(_glory_label)
	top_row.add_child(gl)

	if signal_phase:
		var rb := _primary(Button.new())
		rb.text = "Čas stojí · Pokračovat"
		rb.tooltip_text = "Pokračovat [Mezerník]"
		rb.custom_minimum_size = Vector2(200, 36)
		rb.pressed.connect(func() -> void: resume_pressed.emit())
		top_row.add_child(rb)
	else:
		_signal_button = _icon_button("signal", "Signál · 0", INK)
		_signal_button.tooltip_text = "Signál praporu [Mezerník]: zastaví čas, můžeš měnit postoje a dávat rozkazy přesunu."
		_signal_button.pressed.connect(func() -> void: signal_pressed.emit())
		top_row.add_child(_signal_button)
		if sim.foes_broken:
			_charge_button = _primary(_icon_button("charge", "Do boje! [F]" if not sim.charging else "Dobojují", Color.WHITE))
			_charge_button.tooltip_text = "Jednorázový povel: všichni rytíři opustí postoje a dobojují se zlomeným nepřítelem."
			_charge_button.pressed.connect(func() -> void: charge_pressed.emit())
			top_row.add_child(_charge_button)
		var group := ButtonGroup.new()
		for v: float in [1.0, 2.0]:
			var sp := Button.new()
			sp.text = "%d×" % int(v)
			sp.toggle_mode = true
			sp.button_group = group
			sp.button_pressed = is_equal_approx(speed, v)
			sp.custom_minimum_size = Vector2(40, 36)
			sp.pressed.connect(func() -> void: speed_changed.emit(v))
			top_row.add_child(sp)

	_build_cards(sim, selected, signal_phase, true, "", aim_id)
	set_log(log_lines)
	update_dynamic(sim, signal_phase, false)
	_no_focus(root)


# ================================================================ karty rytířů

## editable: jde měnit postoje. V rozestavení jsou zakázané postoje zašedlé,
## při signálu jdou zvolit, ale za cenu porušení přísahy (battle.gd se zeptá).
func _build_cards(sim: Sim, selected: String, editable: bool, in_battle: bool, route_id: String, aim_id: String) -> void:
	var idx_key := 0
	for u in sim.knights():
		var sel := u.id == selected
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(CARD_W, 0)
		card.add_theme_stylebox_override("panel", _box(Color(PANEL_BG, 0.94), 9, 8, STEEL if sel else LINE, 2 if sel else 1))
		var id := u.id
		card.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				knight_clicked.emit(id))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		card.add_child(v)

		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 6)
		var cls := Icon.make(class_icon(u), u.color if u.alive() else MUTED, 26, u.role)
		cls.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(cls)
		var names := VBoxContainer.new()
		names.add_theme_constant_override("separation", -2)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_child(_label(u.name, 14, INK if u.alive() else MUTED))
		names.add_child(_label(u.role + ("" if u.alive() else " · padl"), 11, MUTED))
		head.add_child(names)
		var icons := HBoxContainer.new()
		icons.add_theme_constant_override("separation", 2)
		icons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(icons)
		v.add_child(head)

		var hp := _bar(OK if u.alive() else LINE, 6)
		hp.max_value = u.maxhp
		hp.value = maxf(0.0, u.hp)
		v.add_child(hp)
		_cards[u.id] = {"hp": hp, "icons": icons, "sig": ""}

		if not u.alive():
			cards_row.add_child(card)
			continue

		idx_key += 1
		var bl := _label(sim.behavior_name(u.id), 12, MUTED)
		bl.tooltip_text = sim.behavior_desc(u.id)
		bl.mouse_filter = Control.MOUSE_FILTER_PASS
		v.add_child(bl)
		var a := sim.ability_of(u.id)
		if not a.is_empty():
			var ab := _icon_button(ABILITY_ICONS.get(u.ability, "glory"), "%s [%d]" % [a["name"], idx_key], GLORY)
			ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ab.tooltip_text = String(a["desc"])
			if aim_id == u.id:
				ab.add_theme_stylebox_override("normal", _box(Color("#3a3220"), 7, 8, GLORY, 2))
				ab.tooltip_text += "\nKlikni na bojiště, Esc zruší."
			ab.pressed.connect(func() -> void: ability_pressed.emit(id))
			v.add_child(ab)
			_ability_buttons[u.id] = ab

		if not in_battle:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			var mb := MenuButton.new()
			mb.text = "Pasivky (%d)" % u.passives.size()
			mb.flat = false
			mb.add_theme_font_size_override("font_size", 13)
			mb.tooltip_text = "Pasivky a přísahy hrdiny (získávají se po bitvě)." if run_mode else "Na zkoušku: ve hře budou pasivky a přísahy odměnou v běhu."
			mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var pm := mb.get_popup()
			var pi := 0
			var pkeys: Array = u.passives.duplicate() if run_mode else sim.passives_for(u.id)
			for pk: String in pkeys:
				var pd: Dictionary = sim.units_data["passives"][pk]
				pm.add_check_item(("Přísaha: " if pd.get("kind", "") == "oath" else "") + String(pd["name"]))
				pm.set_item_checked(pi, u.passives.has(pk))
				pm.set_item_metadata(pi, pk)
				pm.set_item_tooltip(pi, String(pd["desc"]))
				pi += 1
			if run_mode:
				mb.disabled = u.passives.is_empty()
			else:
				pm.index_pressed.connect(func(index: int) -> void:
					passive_toggled.emit(id, String(pm.get_item_metadata(index)), not pm.is_item_checked(index)))
			v.add_child(mb)
			var drawing := route_id == u.id
			var rb := _icon_button("route", "Kreslím" if drawing else "Trasa", Color(1.0, 0.92, 0.55))
			rb.tooltip_text = "Táhni myší po zemi, kudy má hrdina jít (nejvýš 4 body). Esc zruší." if drawing else "Nakreslit trasu: klikni a pak táhni myší po zemi, kudy má hrdina jít."
			rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if drawing:
				rb.add_theme_stylebox_override("normal", _box(Color("#3a3220"), 7, 8, GLORY, 1))
			rb.pressed.connect(func() -> void: route_draw_pressed.emit(id))
			row.add_child(rb)
			if u.route.size() > 0:
				var cb := Button.new()
				cb.text = "✕"
				cb.tooltip_text = "Smazat trasu"
				cb.custom_minimum_size = Vector2(32, 36)
				cb.pressed.connect(func() -> void: route_clear_pressed.emit(id))
				row.add_child(cb)
			v.add_child(row)
		cards_row.add_child(card)


func set_log(lines: Array) -> void:
	if _log_box == null:
		return
	for c in _log_box.get_children():
		c.queue_free()
	if lines.is_empty():
		_log_box.add_child(_label("Bitva ještě nezačala." if _time_label == null else "Bitva začala.", 12, MUTED))
		return
	var start := maxi(0, lines.size() - 6)
	for i in range(lines.size() - 1, start - 1, -1):
		var l: Dictionary = lines[i]
		var tt: float = l["t"]
		var lab := _label("%d:%02d  %s" % [int(tt) / 60, int(tt) % 60, l["text"]], 12, INK if l["hot"] else MUTED, true)
		lab.custom_minimum_size = Vector2(270, 0)
		_log_box.add_child(lab)


## Části, které se mění každý zlomek sekundy (bez přestavby panelů).
func update_dynamic(sim: Sim, signal_phase: bool, paused: bool) -> void:
	if _time_label != null:
		_time_label.text = "%d:%02d" % [int(sim.t) / 60, int(sim.t) % 60]
		var nw := sim.next_wave_t()
		if nw < INF:
			_time_label.text += "  ·  vlna za %d s" % ceili(nw - sim.t)
	if _glory_bar != null:
		_glory_bar.max_value = float(sim.house["glory"]["max"])
		_glory_bar.value = sim.glory
		_glory_label.text = str(int(sim.glory))
	var in_play := _time_label != null
	for id: String in _ability_buttons:
		var b: Button = _ability_buttons[id]
		var u := sim.by_id(id)
		b.disabled = not in_play or paused or not sim.can_use_ability(id)
		var labs := b.find_children("*", "Label", true, false)
		if not labs.is_empty():
			var base := String(sim.ability_of(id)["name"])
			var tail := ""
			if u.ability_cd > 0.0:
				tail = "%d s" % ceili(u.ability_cd)
			elif u.uses > 0:
				tail = "●".repeat(u.uses)
			elif sim.extra_uses_left(id) > 0:
				tail = "%d slávy" % int(sim.ability_cost(id))
			else:
				tail = "vyčerpáno"
			(labs[0] as Label).text = "%s  %s" % [base, tail]
			b.tooltip_text = String(sim.ability_of(id).get("desc", "")) + ("\n" + sim.ability_problem(id) if sim.ability_problem(id) != "" else "")
	if _hint_t > 0.0:
		_hint_t -= 0.1
		if _hint_t <= 0.0:
			_hint.text = ""
	if _signal_button != null:
		var labs := _signal_button.find_children("*", "Label", true, false)
		if not labs.is_empty():
			(labs[0] as Label).text = "Signál · %d" % sim.signals
		_signal_button.disabled = not sim.can_signal() or paused
	if _charge_button != null:
		_charge_button.disabled = not sim.can_charge() or paused
	var in_battle := _time_label != null
	for id: String in _cards:
		var u := sim.by_id(id)
		var c: Dictionary = _cards[id]
		(c["hp"] as ProgressBar).value = maxf(0.0, u.hp)
		var icons := _status_icons(sim, u, in_battle)
		var sg := _sig(icons)
		if sg != c["sig"]:
			c["sig"] = sg
			_fill_icons(c["icons"], icons, 16)


# ================================================================ nad hlavami: zdraví a ikonky

func update_hp_bars(sim: Sim, cam: Camera3D, views: Dictionary, show_full: bool) -> void:
	for u in sim.units:
		var o: Dictionary = _overhead.get(u.id, {})
		if o.is_empty():
			var holder := Control.new()
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var icons := HBoxContainer.new()
			icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icons.add_theme_constant_override("separation", 1)
			holder.add_child(icons)
			var bg := ColorRect.new()
			bg.color = Color(0, 0, 0, 0.5)
			bg.size = Vector2(36, 5)
			bg.position = Vector2(-18, 0)
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(bg)
			var fill := ColorRect.new()
			fill.color = OK if u.side == Sim.SIDE_KNIGHT else BAD
			fill.size = Vector2(36, 5)
			fill.position = Vector2(-18, 0)
			fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(fill)
			bars_layer.add_child(holder)
			o = {"root": holder, "fill": fill, "bg": bg, "icons": icons, "sig": ""}
			_overhead[u.id] = o
		var holder: Control = o["root"]
		var view: Node3D = views.get(u.id)
		var world := view.global_position + Vector3(0, 2.25, 0) if view != null else Vector3.ZERO
		var hidden_now := not u.alive() or cam.is_position_behind(world)
		holder.visible = not hidden_now
		if hidden_now:
			continue
		holder.position = cam.unproject_position(world)
		var hp_visible := show_full or u.hp < u.maxhp
		(o["bg"] as ColorRect).visible = hp_visible
		(o["fill"] as ColorRect).visible = hp_visible
		(o["fill"] as ColorRect).size.x = 36.0 * clampf(u.hp / u.maxhp, 0.0, 1.0)
		var icons := _status_icons(sim, u, show_full)
		var sg := _sig(icons)
		if sg != o["sig"]:
			o["sig"] = sg
			var box: HBoxContainer = o["icons"]
			_fill_icons(box, icons, 15)
			box.position = Vector2(-icons.size() * 8.0, -19)


func clear_hp_bars() -> void:
	for id: String in _overhead:
		(_overhead[id]["root"] as Control).queue_free()
	_overhead.clear()


# ================================================================ dialogy

func show_toast(text: String) -> void:
	toast_label.text = text
	toast.visible = true


func hide_toast() -> void:
	toast.visible = false


func ask_oath(knight_name: String, oath: Dictionary, on_break: Callable, on_keep: Callable) -> void:
	_oath_break_cb = on_break
	_oath_keep_cb = on_keep
	var bonus := roundi(float(oath.get("dmg_bonus", 0.0)) * 100.0)
	var cost := int(oath.get("break_glory_cost", 0))
	oath_dialog.dialog_text = "%s složil přísahu „%s“ a tenhle rozkaz ji poruší.\n\nKdyž ji porušíš, ztratí bonus +%d %% k útoku, oddíl přijde o %d slávy a zlomená přísaha se nedědí." % [knight_name, oath.get("name", ""), bonus, cost]
	oath_dialog.popup_centered()


func show_result(sim: Sim, setup: Dictionary) -> void:
	for c in result_box.get_children():
		c.queue_free()
	var win := sim.over == "win"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	result_box.add_child(v)
	v.add_child(_label("Konec bitvy · %d:%02d" % [int(sim.t) / 60, int(sim.t) % 60], 12, MUTED))
	v.add_child(_label(String(sim.scenario.get("win_title", "Vítězství")) if win else "Oddíl padl", 26, OK if win else BAD))
	var fallen: Array[String] = []
	var best_glory := ""
	var best_g := 0.0
	for u in sim.knights():
		if not u.alive():
			fallen.append(u.name)
		if u.glory_earned > best_g:
			best_g = u.glory_earned
			best_glory = "%s (%d)" % [u.name, int(u.glory_earned)]
	var fled := 0
	for u in sim.units:
		if u.fled:
			fled += 1
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 16)
	for pair: Array in [
		["Padlí", ", ".join(fallen) if not fallen.is_empty() else "nikdo"],
		["Uprchlí nepřátelé", str(fled)],
		["Volitelný úkol", "splněn, %s" % sim.scenario["optional_task"]["reward"] if win and sim.task_ok else "nesplněn"],
		["Přísahy", "dodrženy" if sim.oaths_broken() == 0 else "zlomeno %d" % sim.oaths_broken()],
		["Signály", "%d z %d" % [sim.signals_used, int(setup["signals"])]],
		["Schopnosti", "%d×" % sim.abilities_used],
		["Sláva", str(int(sim.glory))],
		["Nejvíc slávy přinesl", best_glory if best_glory != "" else "nikdo"],
	]:
		g.add_child(_label(pair[0], 14, MUTED))
		g.add_child(_label(pair[1], 14))
	v.add_child(g)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	if run_mode:
		var cont := _primary(Button.new())
		cont.text = "Pokračovat v běhu" if win else "Kronika rodu"
		cont.pressed.connect(func() -> void: run_continue_pressed.emit())
		row.add_child(cont)
		v.add_child(row)
		_no_focus(result_box)
		result_box.visible = true
		return
	var again := Button.new()
	again.text = "Znovu stejně"
	again.pressed.connect(func() -> void: retry_pressed.emit())
	row.add_child(again)
	var redeploy := _primary(Button.new())
	redeploy.text = "Nové rozestavení"
	redeploy.pressed.connect(func() -> void: redeploy_pressed.emit())
	row.add_child(redeploy)
	v.add_child(row)
	_no_focus(result_box)
	result_box.visible = true


func hide_result() -> void:
	result_box.visible = false


## Tlačítka nesmí brát fokus z klávesnice: jinak by mezerník a šipky ovládaly panel místo hry.
func _no_focus(node: Node) -> void:
	for c in node.find_children("*", "Control", true, false):
		(c as Control).focus_mode = Control.FOCUS_NONE



## Krátká nápověda uprostřed nahoře (třeba proč cíl nejde), sama zmizí.
func flash_hint(text: String) -> void:
	_hint.text = text
	_hint_t = 2.0
