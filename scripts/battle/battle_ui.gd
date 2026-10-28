extends CanvasLayer
## Rozhraní bitvy. Neobsahuje herní logiku: jen vykresluje stav a posílá signály do battle.gd.

const Sim := preload("res://scripts/sim/battle_sim.gd")

signal knight_clicked(id: String)
signal posture_changed(id: String, posture: String)
signal bearer_changed(id: String)
signal signals_count_changed(count: int)
signal start_pressed
signal shout_pressed(key: String)
signal signal_pressed
signal charge_pressed
signal resume_pressed
signal speed_changed(value: float)
signal continue_pressed
signal retry_pressed
signal redeploy_pressed

const INK := Color("#e7e9ec")
const MUTED := Color("#9aa3ad")
const PANEL_BG := Color("#1b1f24")
const LINE := Color("#2f353c")
const BANNER := Color("#d0433b")
const GLORY := Color("#e2b84a")
const OK := Color("#5bb36a")
const BAD := Color("#ef6b62")
const STEEL := Color("#8aa2e0")

var root: Control
var panel: PanelContainer
var content: VBoxContainer
var hud: HBoxContainer
var bars_layer: Control
var toast: PanelContainer
var toast_label: Label
var result_box: PanelContainer
var oath_dialog: ConfirmationDialog

var _hp_bars: Dictionary = {}      # id -> Control (ukazatel nad hlavou)
var _roster_hp: Dictionary = {}    # id -> ProgressBar (v panelu)
var _glory_bar: ProgressBar
var _glory_label: Label
var _shout_buttons: Dictionary = {}
var _signal_button: Button
var _charge_button: Button
var _log_box: VBoxContainer
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

	panel = PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -392
	panel.offset_right = -12
	panel.offset_top = 12
	panel.offset_bottom = -12
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	hud = HBoxContainer.new()
	hud.position = Vector2(14, 12)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_theme_constant_override("separation", 8)
	root.add_child(hud)

	toast = PanelContainer.new()
	toast.anchor_left = 0.5
	toast.anchor_right = 0.5
	toast.anchor_top = 1.0
	toast.anchor_bottom = 1.0
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast.offset_bottom = -24
	toast.offset_left = -400
	toast.offset_right = 0
	toast.add_theme_stylebox_override("panel", _box(Color(0.08, 0.09, 0.11, 0.92), 8, 14))
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


# ================================================================ téma

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


func _heading(text: String) -> Label:
	var l := _label(text.to_upper(), 12, MUTED)
	return l


func _primary(b: Button) -> Button:
	b.add_theme_stylebox_override("normal", _box(BANNER, 7, 10))
	b.add_theme_stylebox_override("hover", _box(BANNER.lightened(0.1), 7, 10))
	b.add_theme_stylebox_override("pressed", _box(BANNER.darkened(0.1), 7, 10))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_font_size_override("font_size", 17)
	return b


func _bar(fill: Color, h: int = 6) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, h)
	p.add_theme_stylebox_override("background", _box(LINE, 3, 0))
	p.add_theme_stylebox_override("fill", _box(fill, 3, 0))
	return p


func _clear() -> void:
	for c in content.get_children():
		c.queue_free()
	_roster_hp.clear()
	_shout_buttons.clear()
	_signal_button = null
	_charge_button = null
	_glory_bar = null
	_log_box = null


# ================================================================ panely

func show_deploy(sim: Sim, setup: Dictionary, selected: String) -> void:
	_clear()
	var sc := sim.scenario
	content.add_child(_label("%s · %s" % [sc["stage_label"], sim.house["name"]], 12, MUTED))
	content.add_child(_label(sc["name"], 28))
	content.add_child(_label(sc["subtitle"], 14, MUTED, true))
	content.add_child(_task_box(sim))

	content.add_child(_heading("Rozestavení"))
	content.add_child(_roster(sim, selected, true, false))
	content.add_child(_label("Přetáhni rytíře myší na místo v modré zóně. Puštěním na jiného rytíře je prohodíš. Postoj určuje, co rytíř dělá bez rozkazu. Tlačítkem Prapor určíš, kdo ponese prapor; během bitvy se už nepředává.", 13, MUTED, true))

	content.add_child(_heading(sim.house["name"]))
	var shouts: Dictionary = sim.house["shouts"]
	var bearer := sim.by_id(sim.bearer_id)
	var text := "Aura praporu (žlutý kruh, %d m): +%d %% útok." % [int(sim.aura_radius), roundi(float(sim.house["aura"]["dmg_bonus"]) * 100)]
	if bearer != null:
		text += "\nPrapor nese %s. %s" % [bearer.name, sim.banner_effects(bearer.id).get("desc", "")]
	for k: String in shouts:
		text += "\nPokřik %s (%d slávy): %s." % [shouts[k]["name"], int(shouts[k]["cost"]), shouts[k]["desc"]]
	text += "\nSláva roste za zásahy, zabití a za tanka, který v boji drží přísahu."
	content.add_child(_label(text, 13, MUTED, true))

	content.add_child(_heading("Signály praporu (experiment)"))
	var row := HBoxContainer.new()
	var group := ButtonGroup.new()
	for n in 3:
		var b := Button.new()
		b.text = str(n)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = int(setup["signals"]) == n
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: signals_count_changed.emit(n))
		row.add_child(b)
	content.add_child(row)
	content.add_child(_label("Kolik zastavení času na bitvu je správně? Zkus 0, 1 i 2.", 13, MUTED, true))

	var start := _primary(Button.new())
	start.text = "Začít bitvu"
	start.pressed.connect(func() -> void: start_pressed.emit())
	content.add_child(start)
	_no_focus(content)


func show_battle(sim: Sim, signal_phase: bool, selected: String, speed: float, log_lines: Array) -> void:
	_clear()
	content.add_child(_label(sim.scenario["stage_label"], 12, MUTED))
	content.add_child(_label(sim.scenario["name"], 26))

	if signal_phase:
		var sb := PanelContainer.new()
		sb.add_theme_stylebox_override("panel", _box(Color(BANNER, 0.12), 8, 12, BANNER, 1))
		var v := VBoxContainer.new()
		sb.add_child(v)
		v.add_child(_label("Signál praporu", 19, BANNER))
		v.add_child(_label("Čas stojí. Změň postoje, nebo přetáhni rytíře na místo, které má držet.", 13, INK, true))
		var rb := _primary(Button.new())
		rb.text = "Pokračovat  [Mezerník]"
		rb.pressed.connect(func() -> void: resume_pressed.emit())
		v.add_child(rb)
		content.add_child(sb)

	content.add_child(_heading("Sláva"))
	var gr := HBoxContainer.new()
	_glory_bar = _bar(GLORY, 12)
	_glory_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_glory_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gr.add_child(_glory_bar)
	_glory_label = _label("0", 14, GLORY)
	_glory_label.custom_minimum_size = Vector2(32, 0)
	_glory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gr.add_child(_glory_label)
	content.add_child(gr)

	content.add_child(_heading("Pokřiky"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var i := 1
	for k: String in sim.house["shouts"]:
		var s: Dictionary = sim.house["shouts"][k]
		var b := Button.new()
		b.text = "%s\n%s\n[%d] · %d slávy" % [s["name"], s["desc"], i, int(s["cost"])]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 76)
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(func() -> void: shout_pressed.emit(k))
		grid.add_child(b)
		_shout_buttons[k] = b
		i += 1
	content.add_child(grid)

	if sim.foes_broken and not signal_phase:
		_charge_button = _primary(Button.new())
		_charge_button.text = "Do boje!  [F]" if not sim.charging else "Rytíři dobojují"
		_charge_button.tooltip_text = "Jednorázový povel: všichni rytíři opustí postoje a dobojují se zlomeným nepřítelem."
		_charge_button.pressed.connect(func() -> void: charge_pressed.emit())
		content.add_child(_charge_button)

	if not signal_phase:
		var row := HBoxContainer.new()
		_signal_button = Button.new()
		_signal_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_signal_button.pressed.connect(func() -> void: signal_pressed.emit())
		row.add_child(_signal_button)
		var group := ButtonGroup.new()
		for v: float in [1.0, 2.0]:
			var sp := Button.new()
			sp.text = "%d×" % int(v)
			sp.toggle_mode = true
			sp.button_group = group
			sp.button_pressed = is_equal_approx(speed, v)
			sp.custom_minimum_size = Vector2(46, 0)
			sp.pressed.connect(func() -> void: speed_changed.emit(v))
			row.add_child(sp)
		content.add_child(row)

	content.add_child(_heading("Oddíl"))
	content.add_child(_roster(sim, selected, signal_phase, true))

	content.add_child(_heading("Deník bitvy"))
	_log_box = VBoxContainer.new()
	content.add_child(_log_box)
	set_log(log_lines)
	update_dynamic(sim, signal_phase, false)
	_no_focus(content)


func _task_box(sim: Sim) -> Control:
	var tb := PanelContainer.new()
	var st := _box(Color(GLORY, 0.10), 6, 10)
	st.border_color = GLORY
	st.border_width_left = 3
	tb.add_theme_stylebox_override("panel", st)
	var task: Dictionary = sim.scenario["optional_task"]
	tb.add_child(_label("Volitelný úkol: %s Odměna: %s." % [task["text"], task["reward"]], 14, INK, true))
	return tb


## editable: jde měnit postoje. V rozestavení jsou zakázané postoje zašedlé,
## při signálu jdou zvolit, ale za cenu porušení přísahy (battle.gd se zeptá).
func _roster(sim: Sim, selected: String, editable: bool, with_hp: bool) -> Control:
	var signal_mode := with_hp
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	for u in sim.knights():
		var row := PanelContainer.new()
		var sel := u.id == selected
		row.add_theme_stylebox_override("panel", _box(Color(STEEL, 0.12) if sel else Color(0, 0, 0, 0), 6, 6, STEEL if sel else Color(0, 0, 0, 0), 1 if sel else 0))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		row.add_child(h)
		var dot := ColorRect.new()
		dot.color = u.color
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(dot)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		var name_btn := Button.new()
		name_btn.flat = true
		name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_btn.text = u.name
		name_btn.add_theme_font_size_override("font_size", 15)
		name_btn.disabled = not u.alive()
		var id := u.id
		name_btn.pressed.connect(func() -> void: knight_clicked.emit(id))
		info.add_child(name_btn)
		var tags := u.role
		if not u.alive():
			tags += " · padl"
		if sim.bearer_id == u.id:
			tags += " · nese prapor"
		elif sim.banner_down and sim.picker_id == u.id:
			tags += " · běží pro prapor"
		if u.key == "tank":
			tags += " · Nikdy neustoupí" if sim.oath_kept else " · přísaha zlomena"
		info.add_child(_label(tags, 12, MUTED, true))
		if with_hp:
			var hp := _bar(OK, 5)
			hp.max_value = u.maxhp
			hp.value = u.hp
			info.add_child(hp)
			_roster_hp[u.id] = hp
		h.add_child(info)
		if u.alive():
			if editable and not signal_mode:
				var fb := Button.new()
				fb.text = "Prapor"
				fb.toggle_mode = true
				fb.button_pressed = sim.bearer_id == u.id
				fb.disabled = sim.bearer_id == u.id
				fb.tooltip_text = "Ponese prapor: %s" % sim.banner_effects(u.id).get("desc", "")
				fb.add_theme_font_size_override("font_size", 13)
				fb.pressed.connect(func() -> void: bearer_changed.emit(id))
				h.add_child(fb)
			if editable:
				var ob := OptionButton.new()
				var postures: Dictionary = sim.units_data["postures"]
				var idx := 0
				var pdesc: Dictionary = sim.units_data.get("posture_desc", {})
				for pk: String in postures:
					var by_oath := sim.oath_forbids(u.id, pk)
					var by_banner := sim.bearer_forbids(u.id, pk)
					var label := sim.posture_name(u.id, pk)
					if by_oath and not by_banner and signal_mode:
						label += " (poruší přísahu)"
					ob.add_item(label)
					ob.set_item_metadata(idx, pk)
					ob.set_item_tooltip(idx, String(pdesc.get(pk, "")))
					if by_banner:
						ob.set_item_disabled(idx, true)
						ob.set_item_tooltip(idx, "Nositel praporu prapor nechrání, nese ho.")
					elif by_oath and not signal_mode:
						ob.set_item_disabled(idx, true)
						ob.set_item_tooltip(idx, "Zakazuje přísaha %s" % sim.oath_of(u.id).get("name", ""))
					if pk == u.posture:
						ob.select(idx)
					idx += 1
				ob.focus_mode = Control.FOCUS_NONE
				ob.fit_to_longest_item = false
				ob.clip_text = true
				ob.custom_minimum_size = Vector2(124, 0)
				ob.add_theme_font_size_override("font_size", 13)
				ob.item_selected.connect(func(index: int) -> void: posture_changed.emit(id, String(ob.get_item_metadata(index))))
				h.add_child(ob)
			else:
				h.add_child(_label(sim.posture_name(u.id, u.posture), 12, MUTED))
		box.add_child(row)
	return box


func set_log(lines: Array) -> void:
	if _log_box == null:
		return
	for c in _log_box.get_children():
		c.queue_free()
	if lines.is_empty():
		_log_box.add_child(_label("Bitva začala.", 13, MUTED))
		return
	var start := maxi(0, lines.size() - 7)
	for i in range(lines.size() - 1, start - 1, -1):
		var l: Dictionary = lines[i]
		var tt: float = l["t"]
		_log_box.add_child(_label("%d:%02d  %s" % [int(tt) / 60, int(tt) % 60, l["text"]], 13, INK if l["hot"] else MUTED, true))


## Části, které se mění každý zlomek sekundy (bez přestavby panelu).
func update_dynamic(sim: Sim, signal_phase: bool, paused: bool) -> void:
	if _glory_bar != null:
		_glory_bar.max_value = float(sim.house["glory"]["max"])
		_glory_bar.value = sim.glory
		_glory_label.text = str(int(sim.glory))
	for k: String in _shout_buttons:
		var b: Button = _shout_buttons[k]
		var active: float = sim.fx[k]
		b.disabled = not sim.can_shout(k) or signal_phase or paused
		b.add_theme_stylebox_override("normal", _box(Color("#3a3220") if active > 0.0 else Color("#252a31"), 7, 8, GLORY if active > 0.0 else LINE, 1))
	if _charge_button != null:
		_charge_button.disabled = not sim.can_charge() or paused
	if _signal_button != null:
		_signal_button.text = "Signál praporu [Mezerník] · zbývá %d" % sim.signals
		_signal_button.disabled = not sim.can_signal() or paused
	for id: String in _roster_hp:
		var u := sim.by_id(id)
		(_roster_hp[id] as ProgressBar).value = maxf(0.0, u.hp)

	for c in hud.get_children():
		c.queue_free()
	_pill("%d:%02d" % [int(sim.t) / 60, int(sim.t) % 60], Color(0.08, 0.09, 0.11, 0.8))
	for k: String in sim.fx:
		var rest: float = sim.fx[k]
		if rest > 0.0:
			_pill("%s %.1f s" % [sim.house["shouts"][k]["name"], rest], Color(0.47, 0.35, 0.04, 0.9))
	if sim.aura_center() == null:
		_pill("Prapor leží na zemi", Color(0.59, 0.1, 0.09, 0.9))
	_pill("Úkol: %s" % ("plní se" if sim.task_ok else "nesplněn"), Color(0.08, 0.09, 0.11, 0.8))
	if signal_phase:
		_pill("Čas stojí", Color(0.59, 0.1, 0.09, 0.9))


func _pill(text: String, bg: Color) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _box(bg, 12, 6))
	var l := _label(text, 13, Color.WHITE)
	p.add_child(l)
	hud.add_child(p)


# ================================================================ ukazatele zdraví nad hlavou

func update_hp_bars(sim: Sim, cam: Camera3D, views: Dictionary, show_full: bool) -> void:
	for u in sim.units:
		var bar: Control = _hp_bars.get(u.id)
		if bar == null:
			bar = Control.new()
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.size = Vector2(36, 5)
			var bg := ColorRect.new()
			bg.color = Color(0, 0, 0, 0.5)
			bg.size = bar.size
			bar.add_child(bg)
			var fill := ColorRect.new()
			fill.name = "Fill"
			fill.color = OK if u.side == Sim.SIDE_KNIGHT else BAD
			fill.size = bar.size
			bar.add_child(fill)
			bars_layer.add_child(bar)
			_hp_bars[u.id] = bar
		var view: Node3D = views.get(u.id)
		var world := view.global_position + Vector3(0, 2.25, 0) if view != null else Vector3.ZERO
		var hidden_bar := not u.alive() or (u.hp >= u.maxhp and not show_full) or cam.is_position_behind(world)
		bar.visible = not hidden_bar
		if hidden_bar:
			continue
		var sp := cam.unproject_position(world)
		bar.position = sp - Vector2(18, 0)
		(bar.get_node("Fill") as ColorRect).size.x = 36.0 * clampf(u.hp / u.maxhp, 0.0, 1.0)


func clear_hp_bars() -> void:
	for id: String in _hp_bars:
		(_hp_bars[id] as Control).queue_free()
	_hp_bars.clear()


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
	v.add_child(_label("Vítězství u mostu" if win else "Oddíl padl", 26, OK if win else BAD))
	var fallen: Array[String] = []
	for u in sim.knights():
		if not u.alive():
			fallen.append(u.name)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 16)
	for pair: Array in [
		["Padlí", ", ".join(fallen) if not fallen.is_empty() else "nikdo"],
		["Volitelný úkol", "splněn, %s" % sim.scenario["optional_task"]["reward"] if win and sim.task_ok else "nesplněn"],
		["Přísaha", "Sir Bořek ji dodržel" if sim.oath_kept else "zlomena"],
		["Signály", "%d z %d" % [sim.signals_used, int(setup["signals"])]],
		["Pokřiky", "%d×" % sim.shouts_used],
		["Sláva", str(int(sim.glory))],
	]:
		g.add_child(_label(pair[0], 14, MUTED))
		g.add_child(_label(pair[1], 14))
	v.add_child(g)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
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
