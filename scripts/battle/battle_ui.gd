extends CanvasLayer
## Battle UI. Holds no game logic: it only draws the state and sends signals to battle.gd.
##
## Layout: command bar at the top (time, glory, All In!, speed; in deployment
## Start battle), battle card top left (scenario, task, house), hero cards at the bottom,
## a small collapsible battle log top right, health and status icons above units.

const Sim := preload("res://scripts/sim/battle_sim.gd")
const Icon := preload("res://scripts/battle/ui_icon.gd")
const UI := preload("res://scripts/ui/ui_theme.gd")

signal knight_clicked(id: String)
signal ability_pressed(id: String)
signal combo_pressed(id: String)
signal passive_toggled(id: String, key: String, on: bool)
signal ability_chosen(id: String, key: String)
signal scenario_changed(id: String)
signal order_pressed(id: String)
signal order_clear_pressed(id: String)
signal start_pressed
signal pause_pressed
signal charge_pressed
signal resume_pressed
signal speed_changed(value: float)
signal continue_pressed
signal retry_pressed
signal redeploy_pressed
signal run_continue_pressed
signal tutorial_skip_pressed
signal tutorial_ok_pressed

# Royal Court Enamel (light, scripts/ui/ui_theme.gd); the names stay so run_main.gd can borrow them
const INK := UI.TEXT
const MUTED := UI.TEXT_MUTED
const PANEL_BG := UI.BATTLE
const LINE := UI.BORDER
const BANNER := UI.OATH
const GLORY := UI.GLORY
const OK := UI.GOOD
const BAD := UI.BAD
const STEEL := UI.HOUSE
const CARD_W := 200.0

const ORDER_COL := UI.TEXT_2
## Order icon by kind (no Oathline icon yet: simple vectors).
const ORDER_ICONS := {"": "hold", "point": "route", "group": "map_battle", "ally": "class_tank"}

## Ability icon by key: the five base abilities have their own Oathline icon, the others borrow the closest one.
const ABILITY_ICONS := {"vyzva": "ability_challenge", "pozehnani": "ability_blessing", "salva": "ability_volley", "najezd": "ability_charge", "uder": "ability_shadow_strike",
	"hradba": "class_tank", "uder_stitem": "class_tank", "kruh": "ability_blessing", "svetlo": "ability_blessing", "mirena": "class_archer", "ustup": "ability_volley",
	"korouhev": "status_commander", "prujezd": "ability_charge", "kour": "status_hidden", "noze": "class_assassin"}

var root: Control
var tutorial: PanelContainer        # tutorial panel (show_tutorial / hide_tutorial)
var _tut_title: Label
var _tut_text: Label
var _tut_ok: Button
var _tut_arrow: Line2D               # arrow from the tutorial card to its target
var _tut_mark: Line2D                # ring on the target
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
var oath_dialog: PanelContainer      # oath confirmation (POWER / RESTRICTION / IF BROKEN), ask_oath
var _oath_veil: ColorRect
var _oath_body: VBoxContainer
var _oath_keep_btn: Button
var select_box: Panel              # box selection rectangle
var scenario_choices: Array = []   # [[key, name], ...] for the battle picker
var run_mode := false              # the battle is part of a run: no battle picker, passives read-only
var run_label := ""                # e.g. "Battle 2 of 3"

var _overhead: Dictionary = {}     # id -> {"root", "fill", "bg", "icons", "sig"}
var _cards: Dictionary = {}        # id -> {"hp": ProgressBar, "icons": HBoxContainer, "sig": String}
var _time_label: Label
var _ability_buttons: Dictionary = {}   # hero id -> Button
var _combo_buttons: Dictionary = {}     # combo id -> Button
var _hint: Label
var _hint_t := 0.0
var _pause_button: Button
var _charge_button: Button
var _morale_box: HBoxContainer       # command bar: enemy morale meter / All In! (states A–E)
var _morale_meter: Control
var _morale_note: Label
var _morale_state := ""
var _last_morale := ""               # survives panel rebuilds: the one-time reveal (state B) when morale breaks
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

	# command bar top centre
	top_bar = PanelContainer.new()
	top_bar.anchor_left = 0.5
	top_bar.anchor_right = 0.5
	top_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top_bar.offset_top = 10
	top_bar.add_theme_stylebox_override("panel", UI.panel_box(8, PANEL_BG))
	root.add_child(top_bar)
	top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	top_bar.add_child(top_row)

	# battle card top left
	info_card = PanelContainer.new()
	info_card.position = Vector2(12, 12)
	info_card.custom_minimum_size = Vector2(300, 0)
	info_card.add_theme_stylebox_override("panel", UI.panel_box(12, PANEL_BG))
	root.add_child(info_card)
	info_box = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 6)
	info_card.add_child(info_box)

	# hero cards bottom centre
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

	# log top right
	log_panel = PanelContainer.new()
	log_panel.anchor_left = 1.0
	log_panel.anchor_right = 1.0
	log_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	log_panel.offset_top = 12
	log_panel.offset_right = -12
	log_panel.custom_minimum_size = Vector2(290, 0)
	log_panel.add_theme_stylebox_override("panel", UI.panel_box(10, Color(PANEL_BG, 0.94)))
	root.add_child(log_panel)
	var lv := VBoxContainer.new()
	log_panel.add_child(lv)
	var lh := Button.new()
	lh.flat = true
	lh.alignment = HORIZONTAL_ALIGNMENT_LEFT
	lh.add_theme_font_size_override("font_size", 11)
	lh.add_theme_font_override("font", UI.font("ui", 700))
	for k: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		lh.add_theme_color_override(k, MUTED)
	lh.text = "BATTLE LOG  ▾"
	lh.focus_mode = Control.FOCUS_NONE
	lh.pressed.connect(func() -> void:
		_log_open = not _log_open
		lh.text = "BATTLE LOG  ▾" if _log_open else "BATTLE LOG  ▸"
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
	toast.add_theme_stylebox_override("panel", UI.panel_box(14, UI.PANEL))
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 14)
	toast.add_child(th)
	toast_label = UI.label("", 16, INK, false, "lore")
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.custom_minimum_size = Vector2(380, 0)
	th.add_child(toast_label)
	var tb := Button.new()
	tb.text = "Continue  [Space]"
	UI.primary(tb, UI.OATH, 14)
	tb.focus_mode = Control.FOCUS_NONE
	tb.pressed.connect(func() -> void: continue_pressed.emit())
	th.add_child(tb)
	toast.visible = false
	root.add_child(toast)

	# tutorial: a card with the step, pinned with an arrow to what the step is about (point_tutorial)
	_tut_arrow = Line2D.new()
	_tut_arrow.width = 3.0
	_tut_arrow.default_color = UI.GILT
	_tut_arrow.visible = false
	root.add_child(_tut_arrow)
	_tut_mark = Line2D.new()
	_tut_mark.width = 3.0
	_tut_mark.default_color = UI.GILT
	_tut_mark.closed = true
	for i in 24:
		_tut_mark.add_point(Vector2.from_angle(TAU * i / 24.0) * 18.0)
	_tut_mark.visible = false
	root.add_child(_tut_mark)
	tutorial = PanelContainer.new()
	var tst := UI.box(UI.PANEL, UI.RADIUS, 14, UI.OUTLINE, 2, 3)
	tst.border_width_top = 5
	tst.border_color = UI.OUTLINE
	tutorial.add_theme_stylebox_override("panel", tst)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 8)
	tutorial.add_child(tv)
	_tut_title = UI.eyebrow("", GLORY, 11)
	tv.add_child(_tut_title)
	_tut_text = _label("", 15, INK, true)
	_tut_text.custom_minimum_size = Vector2(290, 0)
	tv.add_child(_tut_text)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	trow.alignment = BoxContainer.ALIGNMENT_END
	tv.add_child(trow)
	var skip := Button.new()
	skip.text = "Skip tutorial"
	skip.flat = true
	skip.focus_mode = Control.FOCUS_NONE
	skip.pressed.connect(func() -> void: tutorial_skip_pressed.emit())
	trow.add_child(skip)
	_tut_ok = _primary(Button.new())
	_tut_ok.text = "Got it"
	_tut_ok.focus_mode = Control.FOCUS_NONE
	_tut_ok.pressed.connect(func() -> void: tutorial_ok_pressed.emit())
	trow.add_child(_tut_ok)
	tutorial.visible = false
	root.add_child(tutorial)

	_hint = UI.label("", 16, UI.ON_DARK, false, "ui", 600)
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.offset_top = 64
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_outline_color", Color(UI.OUTLINE, 0.9))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint)

	select_box = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UI.GILT, 0.12)
	sb.border_color = UI.GILT
	sb.set_border_width_all(2)
	select_box.add_theme_stylebox_override("panel", sb)
	select_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	select_box.visible = false
	root.add_child(select_box)

	result_box = PanelContainer.new()
	result_box.set_anchors_preset(Control.PRESET_CENTER)
	result_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	result_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	result_box.custom_minimum_size = Vector2(460, 0)
	result_box.add_theme_stylebox_override("panel", UI.panel_box(22, UI.PANEL))
	result_box.visible = false
	root.add_child(result_box)

	# oath confirmation: a veil over the battlefield and an enamel card in the middle
	_oath_veil = ColorRect.new()
	_oath_veil.color = Color(UI.OUTLINE, 0.45)
	_oath_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_oath_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_oath_veil.visible = false
	root.add_child(_oath_veil)
	oath_dialog = PanelContainer.new()
	oath_dialog.set_anchors_preset(Control.PRESET_CENTER)
	oath_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	oath_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	oath_dialog.custom_minimum_size = Vector2(480, 0)
	var ost := UI.box(UI.PANEL, UI.RADIUS, 20, UI.OUTLINE, 2, 4)
	ost.border_width_top = 6
	ost.border_color = UI.OUTLINE
	oath_dialog.add_theme_stylebox_override("panel", ost)
	oath_dialog.visible = false
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 12)
	oath_dialog.add_child(ov)
	_oath_body = VBoxContainer.new()
	_oath_body.add_theme_constant_override("separation", 10)
	ov.add_child(_oath_body)
	var orow := HBoxContainer.new()
	orow.add_theme_constant_override("separation", 10)
	orow.alignment = BoxContainer.ALIGNMENT_END
	ov.add_child(orow)
	_oath_keep_btn = Button.new()
	_oath_keep_btn.text = "Keep the oath"
	_oath_keep_btn.custom_minimum_size = Vector2(150, 40)
	_oath_keep_btn.pressed.connect(func() -> void: _close_oath(_oath_keep_cb))
	orow.add_child(_oath_keep_btn)
	var obreak := UI.primary(Button.new(), UI.OATH, 15)
	obreak.text = "Break the oath"
	obreak.custom_minimum_size = Vector2(170, 40)
	obreak.pressed.connect(func() -> void: _close_oath(_oath_break_cb))
	orow.add_child(obreak)
	root.add_child(oath_dialog)


# ================================================================ theme and helpers

func _box(bg: Color, radius: int, pad: int, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	return UI.box(bg, radius, pad, border, bw)


func _make_theme() -> Theme:
	return UI.make_theme()


func _label(text: String, size: int = 15, color: Color = INK, wrap: bool = false) -> Label:
	return UI.label(text, size, color, wrap)


func _primary(b: Button, col: Color = BANNER) -> Button:
	return UI.primary(b, col)


func _bar(fill: Color, h: int = 6) -> ProgressBar:
	return UI.bar(fill, h)


## Button with an icon and text (the caption is a Label inside so update_dynamic can change it).
## Keyboard shortcut on a button: a small box with the key after the text (the button text stays the first Label).
func _add_keycap(b: Button, key: String) -> void:
	var h := b.get_child(0) as HBoxContainer
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cst := UI.box(UI.RAISED, 3, 2, UI.OUTLINE, 1)
	cst.border_width_bottom = 2
	cap.add_theme_stylebox_override("panel", cst)
	var l := UI.label(key, 11, INK, false, "ui", 700)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(12, 0)
	cap.add_child(l)
	h.add_child(cap)
	b.custom_minimum_size.x += 26.0


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
		var l := UI.label(text, 13, INK, false, "ui", 600)
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
	_combo_buttons.clear()
	_pause_button = null
	_charge_button = null
	_morale_box = null
	_morale_meter = null
	_morale_note = null
	_morale_state = ""
	_time_label = null


## Hero class icon.
static func class_icon(u: Sim.Unit) -> String:
	return u.key if u.key in ["tank", "knez", "lucistnik", "jezdec", "asasin"] else "tank"


## Unit status icons: [kind, colour, struck through, tooltip]. Only reads the simulation.
func _status_icons(sim: Sim, u: Sim.Unit, in_battle: bool) -> Array:
	var out: Array = []
	if u.side == Sim.SIDE_KNIGHT:
		for k: String in u.passives:
			var pd: Dictionary = sim.units_data["passives"][k]
			if pd.get("kind", "") == "oath":
				out.append(["oath", GLORY, u.oath_broken, "Oath %s%s: %s" % [pd["name"], " (broken)" if u.oath_broken else "", pd["desc"]]])
			else:
				out.append(["stat_power", STEEL, false, "%s: %s" % [pd["name"], pd["desc"]]])
		var bond := sim.bond_of(u.id)
		if not bond.is_empty():
			var mate := sim.by_id(String(bond["with"]))
			out.append(["status_bond", UI.BOND[clampi(int(bond["level"]) - 1, 0, 2)], mate == null or not mate.alive(), "Bond %s · companion %s (level %d): %s Grief: %s" % [bond["name"], mate.name if mate != null else "?", int(bond["level"]), bond["desc"], bond["grief_desc"]]])
		var st: Dictionary = sim.stats_of(u.id)
		var parts: Array = []
		for sk: String in ["utok", "moc", "odolnost", "pohotovost"]:
			if absf(float(st[sk])) > 0.001:
				parts.append("%s %+d %%" % [sim.units_data["stats"][sk]["name"], roundi(float(st[sk]) * 100.0)])
		if not parts.is_empty():
			out.append(["stat_attack", GLORY, false, "Stats: " + ", ".join(parts)])
		if in_battle and u.alive():
			if u.taunt_t > 0.0:
				out.append(["ability_challenge", STEEL, false, "Challenge: enemies attack him, half damage"])
		if u.alive():
			out.append([ORDER_ICONS.get("" if u.order_done else u.order, "hold"), ORDER_COL, false, sim.order_text(u.id)])
	else:
		if u.leader:
			out.append(["status_commander", BAD, false, "%s: commander. When he falls, the enemy breaks." % u.name])
		if u.casting:
			out.append(["status_winding_up", BAD, false, "Winding up: a stun (Charge) interrupts him"])
		if u.stun_t > 0.0:
			out.append(["status_stunned", STEEL, false, "Stunned"])
		if u.fleeing:
			out.append(["status_fleeing", MUTED, false, "Fleeing"])
		elif u.desperate:
			out.append(["desperate", BAD, false, "Desperate: attacks harder"])
		elif u.asleep:
			out.append(["hold", MUTED, false, "On watch: joins the fight when you come close or he hears fighting"])
		for tr: String in u.traits:
			if tr == "fanatik":
				out.append(["fanatik", Color("#B5541C"), false, "Fanatic: never breaks"])
			elif tr == "zbabelec":
				out.append(["zbabelec", Color("#7A7058"), false, "Coward: flees when morale breaks"])
		if u.vs_mounted > 1.0:
			out.append(["class_cavalier", BAD, true, "Spear: 2× damage against cavalry"])
	return out


func _fill_icons(box: HBoxContainer, icons: Array, px: float, plate: bool = false) -> void:
	for c in box.get_children():
		c.queue_free()
	for it: Array in icons:
		var ic := Icon.make(it[0], it[1], px, it[3], plate)
		ic.set("crossed", it[2])
		box.add_child(ic)


static func _sig(icons: Array) -> String:
	var s := ""
	for it: Array in icons:
		s += "%s%s%s|" % [it[0], it[2], it[3]]
	return s


# ================================================================ deployment

func show_deploy(sim: Sim, _setup: Dictionary, selection: Array, scenario_id: String = "", order_id: String = "") -> void:
	_clear()
	_fill_info(sim, true, scenario_id)

	# bar: battle start
	var start := _primary(Button.new())
	start.text = "Start battle"
	start.custom_minimum_size = Vector2(150, 36)
	start.pressed.connect(func() -> void: start_pressed.emit())
	top_row.add_child(start)

	_build_cards(sim, selection, false, order_id, "")
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
			pick.add_item("Battle: %s" % ch[1])
			pick.set_item_metadata(i, ch[0])
			if ch[0] == scenario_id:
				pick.select(i)
			i += 1
		pick.item_selected.connect(func(index: int) -> void: scenario_changed.emit(String(pick.get_item_metadata(index))))
		info_box.add_child(pick)
	info_box.add_child(UI.eyebrow("%s · %s" % [run_label if run_mode and run_label != "" else sc["stage_label"], sim.house["name"]], MUTED, 11))
	info_box.add_child(UI.title(String(sc["name"]), 22 if deploy else 18))
	if deploy:
		info_box.add_child(UI.label(String(sc["subtitle"]), 15, UI.TEXT_2, true, "lore_i"))
	var md: Dictionary = sim.units_data.get("battle_modes", {}).get(sim.mode, {})
	if not md.is_empty():
		info_box.add_child(_label("%s: %s" % [md.get("name", ""), md.get("desc", "")], 13, STEEL, true))
	if sim.waves_left > 0:
		info_box.add_child(_label("Waves still to come: %d" % sim.waves_left, 13, GLORY))
	var task: Dictionary = sc["optional_task"]
	var tb := PanelContainer.new()
	var st := UI.box(UI.INSET, 4, 8)
	st.border_color = GLORY
	st.border_width_left = 4
	tb.add_theme_stylebox_override("panel", st)
	tb.add_child(_label("Task: %s Reward: %s." % [task["text"], task["reward"]], 13, INK, true))
	info_box.add_child(tb)
	if sim.sleeping_pods() > 0:
		info_box.add_child(_label("Enemy groups still waiting: %d" % sim.sleeping_pods(), 13, GLORY))
	if deploy:
		info_box.add_child(_label("Select a hero (click, drag a box, Shift adds more) and send him with the right button: to a place, at an enemy (he goes after its whole group) or to an ally (he stays with him). Whoever has no order or has finished it holds his place and defends himself (H cancels the selected heroes' orders). Ability: the key on the button, target with the right button. Space pauses and resumes the battle.", 12, MUTED, true))
		info_box.add_child(_label("Enemies stand in groups and join when you come close or they hear fighting. Abilities have a fixed number of uses for the whole battle (●) and recharge after use; nothing refills between groups and the priest heals only in combat.", 12, MUTED, true))


# ================================================================ battle

func show_battle(sim: Sim, pause_phase: bool, selection: Array, speed: float, log_lines: Array, aim_id: String = "", order_id: String = "", scenario_id: String = "") -> void:
	_clear()
	_fill_info(sim, pause_phase and sim.t == 0.0, scenario_id)   # before the start: battle picker and instructions

	_time_label = UI.label("0:00", 16, INK, false, "ui", 700)
	_time_label.custom_minimum_size = Vector2(48, 0)
	_time_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(_time_label)

	if pause_phase:
		var rb := _primary(Button.new())
		rb.text = "Start battle" if sim.t == 0.0 else "Paused · Continue"
		rb.tooltip_text = "Continue [Space]. While paused you can give orders and use abilities."
		rb.custom_minimum_size = Vector2(200, 36)
		rb.pressed.connect(func() -> void: resume_pressed.emit())
		top_row.add_child(rb)
	else:
		_pause_button = _icon_button("hud_pause", "Pause", INK)
		_pause_button.tooltip_text = "Pause [Space]: stops time so you can give orders and use abilities calmly."
		_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
		top_row.add_child(_pause_button)
		var group := ButtonGroup.new()
		for v: float in [1.0, 2.0]:
			var sp := Button.new()
			sp.text = "%d×" % int(v)
			sp.toggle_mode = true
			sp.button_group = group
			sp.button_pressed = is_equal_approx(speed, v)
			sp.custom_minimum_size = Vector2(40, 36)
			sp.add_theme_stylebox_override("pressed", UI.box(UI.IRON, UI.RADIUS, 8, UI.OUTLINE, 2))
			sp.add_theme_stylebox_override("hover_pressed", UI.box(UI.IRON, UI.RADIUS, 8, UI.OUTLINE, 2))
			sp.add_theme_color_override("font_hover_pressed_color", UI.ON_DARK)
			sp.add_theme_color_override("font_pressed_color", UI.ON_DARK)
			sp.pressed.connect(func() -> void: speed_changed.emit(v))
			top_row.add_child(sp)
	# enemy morale and the All In! command (states A–E), refreshed in update_dynamic
	var sep := VSeparator.new()
	sep.add_theme_stylebox_override("separator", UI.box(UI.BORDER, 0, 0))
	sep.custom_minimum_size = Vector2(2, 0)
	top_row.add_child(sep)
	_morale_box = HBoxContainer.new()
	_morale_box.add_theme_constant_override("separation", 8)
	top_row.add_child(_morale_box)
	_build_morale(sim)

	_build_cards(sim, selection, sim.t > 0.0, order_id, aim_id)
	set_log(log_lines)
	update_dynamic(sim, pause_phase, false)
	_no_focus(root)


# ================================================================ enemy morale and All In! (states A–E)

## Meter of enemy losses with a mark at the break threshold (state A).
class MoraleMeter:
	extends Control
	var value := 0.0
	var threshold := 0.7
	var waves := false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, UI.IRON)
		var fill := Rect2(Vector2(1, 1), Vector2((size.x - 2.0) * clampf(value / maxf(threshold, 0.01), 0.0, 1.0), size.y - 2.0))
		draw_rect(fill, Color(UI.OATH, 0.45) if waves else UI.OATH)
		draw_rect(r, UI.OUTLINE, false, 1.0)
		# notches every quarter of the way to the break
		for i in range(1, 4):
			var x := size.x * i / 4.0
			draw_line(Vector2(x, 1), Vector2(x, size.y - 1), Color(UI.ON_DARK, 0.25), 1.0)


func _chip(text: String, col: Color, filled: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(col if filled else UI.RAISED, 3, 4, col, 1))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(UI.label(text, 10, UI.ON_DARK if filled else col, false, "ui", 800))
	return p


## Rebuilds the morale part of the command bar for the current state.
func _build_morale(sim: Sim) -> void:
	if _morale_box == null:
		return
	for c in _morale_box.get_children():
		c.queue_free()
	_charge_button = null
	_morale_meter = null
	_morale_note = null
	var ms := sim.morale_state()
	var st := String(ms["state"])
	_morale_state = st + ("|w" if ms["waves"] else "")
	match st:
		"steady":
			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", 3)
			v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var cap := HBoxContainer.new()
			cap.add_theme_constant_override("separation", 6)
			cap.add_child(UI.eyebrow("Enemy morale" if not ms["waves"] else "More waves coming", MUTED, 10))
			_morale_note = UI.label("", 10, MUTED, false, "ui", 600)
			cap.add_child(_morale_note)
			v.add_child(cap)
			var m := MoraleMeter.new()
			m.custom_minimum_size = Vector2(150, 10)
			m.threshold = float(ms["threshold"])
			m.waves = bool(ms["waves"])
			v.add_child(m)
			_morale_meter = m
			_morale_box.add_child(v)
			var lock := Icon.make("hud_lock", MUTED, 18, "All In! unlocks when the enemy loses %d %% of its warriors%s." % [roundi(float(ms["threshold"]) * 100.0), " or its commander falls" if ms["leader"] else ""])
			lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_morale_box.add_child(lock)
			_morale_box.tooltip_text = lock.tooltip_text
		"broken":
			_charge_button = _icon_button("hud_all_in", "All In!", UI.ON_DARK)
			UI.primary(_charge_button, UI.OATH)
			for l: Label in _charge_button.find_children("*", "Label", true, false):
				l.add_theme_color_override("font_color", UI.ON_DARK)
				l.add_theme_font_override("font", UI.font("title", 700))
				l.add_theme_font_size_override("font_size", 15)
			_add_keycap(_charge_button, "F")
			_charge_button.custom_minimum_size.x += 10.0
			_charge_button.tooltip_text = "One-time command: all heroes leave their posts and finish off the broken enemy."
			_charge_button.pressed.connect(func() -> void: charge_pressed.emit())
			_morale_box.add_child(_charge_button)
			_morale_box.add_child(_chip("ONCE", UI.GLORY))
			_morale_note = UI.label("", 12, MUTED, false, "ui", 600)
			_morale_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_morale_note.tooltip_text = "Without the command the heroes finish the fight on their own."
			_morale_note.mouse_filter = Control.MOUSE_FILTER_PASS
			_morale_box.add_child(_morale_note)
			if _last_morale == "steady":
				flash_hint("The enemy's morale is broken: All In! is ready (once). [F]")
				var tw := _charge_button.create_tween().set_loops(3)
				tw.tween_property(_charge_button, "modulate", Color(1.25, 1.15, 0.9), 0.25)
				tw.tween_property(_charge_button, "modulate", Color.WHITE, 0.25)
		"given", "auto":
			var p := PanelContainer.new()
			p.add_theme_stylebox_override("panel", UI.box(UI.INSET, UI.RADIUS, 6, UI.GILT if st == "given" else UI.BORDER, 2))
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 6)
			h.add_child(Icon.make("hud_all_in", GLORY if st == "given" else MUTED, 18))
			h.add_child(UI.label("All In! given" if st == "given" else "The heroes charged on their own", 13, INK if st == "given" else MUTED, false, "ui", 700))
			p.add_child(h)
			p.tooltip_text = "Every hero is finishing off the broken enemy."
			_morale_box.add_child(p)
	_last_morale = st
	_no_focus(_morale_box)
	_update_morale(sim, ms)


func _update_morale(sim: Sim, ms: Dictionary = {}) -> void:
	if ms.is_empty():
		ms = sim.morale_state()
	if _morale_meter != null:
		var m := _morale_meter as MoraleMeter
		m.value = float(ms["loss"])
		m.queue_redraw()
		if _morale_note != null:
			_morale_note.text = "%d / %d %%" % [roundi(float(ms["loss"]) * 100.0), roundi(float(ms["threshold"]) * 100.0)]
	elif _morale_note != null and float(ms["auto_in"]) >= 0.0:
		_morale_note.text = "auto in %d s" % ceili(float(ms["auto_in"]))


# ================================================================ hero cards

## Hero cards; the selected ones are highlighted (selection). A retreat order in battle breaks
## the Never Retreat oath (battle.gd asks).
func _build_cards(sim: Sim, selection: Array, in_battle: bool, order_id: String, aim_id: String) -> void:
	for u in sim.knights():
		var sel := selection.has(u.id)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(CARD_W, 0)
		# enamel card: dark outline, a band of the hero's colour on top; selected = gilt frame and a marker above
		var cst := UI.box(PANEL_BG if u.alive() else UI.INSET, UI.RADIUS, 8, UI.GILT if sel else UI.OUTLINE, 3 if sel else 2, 3)
		card.add_theme_stylebox_override("panel", cst)
		card.clip_contents = false
		var band := ColorRect.new()   # strip of the hero's colour (as on the battlefield)
		band.color = u.color if u.alive() else UI.BORDER
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.custom_minimum_size = Vector2(0, 4)
		if sel:
			var mark := Polygon2D.new()
			mark.polygon = PackedVector2Array([Vector2(-8, -15), Vector2(8, -15), Vector2(0, -5)])
			mark.color = UI.GILT
			var outline := Line2D.new()
			outline.points = PackedVector2Array([Vector2(-8, -15), Vector2(8, -15), Vector2(0, -5), Vector2(-8, -15)])
			outline.width = 1.5
			outline.default_color = UI.OUTLINE
			mark.add_child(outline)
			card.resized.connect(func() -> void: mark.position = Vector2(card.size.x / 2.0, 0))
			card.add_child(mark)
		var id := u.id
		card.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				knight_clicked.emit(id))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		card.add_child(v)

		v.add_child(band)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 6)
		var cls := Icon.make(class_icon(u), UI.on_light(u.color) if u.alive() else MUTED, 26, u.role)
		cls.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(cls)
		var names := VBoxContainer.new()
		names.add_theme_constant_override("separation", -2)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_child(UI.label(u.name, 14, INK if u.alive() else MUTED, false, "ui", 700))
		names.add_child(UI.eyebrow(u.role + ("" if u.alive() else " · fallen"), MUTED, 10))
		head.add_child(names)
		var icons := HBoxContainer.new()
		icons.add_theme_constant_override("separation", 2)
		icons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(icons)
		v.add_child(head)

		var hp := _bar(OK if u.alive() else LINE, 8)
		hp.max_value = u.maxhp
		hp.value = maxf(0.0, u.hp)
		v.add_child(hp)
		_cards[u.id] = {"hp": hp, "icons": icons, "sig": ""}

		if not u.alive():
			cards_row.add_child(card)
			continue

		var a := sim.ability_of(u.id)
		if not a.is_empty():
			var key := sim.knights().find(u) + 1   # key 1–5 by card order (battle.gd _ability_by_index)
			var ab := _icon_button(ABILITY_ICONS.get(u.ability, "glory"), String(a["name"]), GLORY)
			ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ab.tooltip_text = String(a["desc"])
			_add_keycap(ab, str(key))
			if aim_id == u.id:
				ab.add_theme_stylebox_override("normal", UI.box(Color("#F3E6C4"), UI.RADIUS, 8, UI.GILT, 3))
				ab.tooltip_text += "\nClick the battlefield (left or right), Esc cancels."
			ab.pressed.connect(func() -> void: ability_pressed.emit(id))
			v.add_child(ab)
			_ability_buttons[u.id] = ab

		if not in_battle and not run_mode:
			# free battle: try another ability of the class (in a run abilities come from elites and events)
			var amb := MenuButton.new()
			amb.text = "Ability: %s" % String(a.get("name", ""))
			amb.flat = false
			amb.add_theme_font_size_override("font_size", 13)
			amb.tooltip_text = "For trial: in the game, a new ability comes from an elite reward, the Smith or the Monk."
			amb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var apm := amb.get_popup()
			var ai := 0
			for akey: String in sim.abilities_for(u.id):
				apm.add_radio_check_item(String(sim.units_data["abilities"][akey]["name"]))
				apm.set_item_checked(ai, akey == u.ability)
				apm.set_item_metadata(ai, akey)
				apm.set_item_tooltip(ai, String(sim.units_data["abilities"][akey].get("desc", "")))
				ai += 1
			apm.index_pressed.connect(func(index: int) -> void:
				ability_chosen.emit(id, String(apm.get_item_metadata(index))))
			v.add_child(amb)
		if not in_battle:
			var mb := MenuButton.new()
			mb.text = "Passives (%d)" % u.passives.size()
			mb.flat = false
			mb.add_theme_font_size_override("font_size", 13)
			mb.tooltip_text = "The hero's passives and oaths (gained after battles)." if run_mode else "For trial: in the game, passives and oaths are run rewards."
			mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var pm := mb.get_popup()
			var pi := 0
			var pkeys: Array = u.passives.duplicate() if run_mode else sim.passives_for(u.id)
			for pk: String in pkeys:
				var pd: Dictionary = sim.units_data["passives"][pk]
				pm.add_check_item(("Oath: " if pd.get("kind", "") == "oath" else "") + String(pd["name"]))
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
		cards_row.add_child(card)
	_build_combos(sim)


## Bond combos (Q, E): a button with the key, the combo name and the hero pair. Only reads the simulation.
func _build_combos(sim: Sim) -> void:
	var list := sim.combos()
	if list.is_empty():
		return
	var card := PanelContainer.new()
	var cst := UI.box(PANEL_BG, UI.RADIUS, 8, UI.OUTLINE, 2, 3)
	card.add_theme_stylebox_override("panel", cst)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	card.add_child(v)
	v.add_child(UI.eyebrow("Bond combos", UI.BOND[1], 10))
	for c: Dictionary in list:
		var a := sim.by_id(String(c["a"]))
		var b := sim.by_id(String(c["b"]))
		var btn := _icon_button("status_bond", String(c["name"]), UI.BOND[1])
		_add_keycap(btn, String(c["key"]))
		btn.tooltip_text = "%s + %s: %s" % [a.name, b.name, c["desc"]]
		btn.set_meta("tip", btn.tooltip_text)
		btn.custom_minimum_size.y = 30
		var cid := String(c["id"])
		btn.pressed.connect(func() -> void: combo_pressed.emit(cid))
		v.add_child(btn)
		_combo_buttons[cid] = btn
	cards_row.add_child(card)


## Tutorial step: title with the step number, text; `ok` = the step is confirmed with the Got it button.
func show_tutorial(title: String, step: int, total: int, text: String, ok: bool) -> void:
	_tut_title.text = "%s · step %d of %d" % [title.to_upper(), step, total]
	_tut_text.text = text
	_tut_ok.visible = ok
	tutorial.visible = true
	tutorial.reset_size()


func hide_tutorial() -> void:
	tutorial.visible = false
	_tut_arrow.visible = false
	_tut_mark.visible = false


## Places the tutorial card next to a screen point (above it, or below when it is in the upper half)
## and draws an arrow with a ring to it. Without a point (null) the card sits on the right below the battle log.
func point_tutorial(target: Variant) -> void:
	if not tutorial.visible:
		return
	var vp := root.get_viewport_rect().size
	var sz := tutorial.size
	var margin := 12.0
	if target == null:
		tutorial.position = Vector2(vp.x - sz.x - margin, log_panel.position.y + log_panel.size.y + 10.0)
		_tut_arrow.visible = false
		_tut_mark.visible = false
		return
	var t: Vector2 = target
	var gap := 56.0
	var below := t.y < vp.y * 0.45
	var pos := Vector2(t.x - sz.x / 2.0, t.y + gap if below else t.y - gap - sz.y)
	pos.x = clampf(pos.x, margin, vp.x - sz.x - margin)
	pos.y = clampf(pos.y, margin, vp.y - sz.y - margin)
	tutorial.position = pos
	var edge_y := pos.y if below else pos.y + sz.y
	var from := Vector2(clampf(t.x, pos.x + 24.0, pos.x + sz.x - 24.0), edge_y)
	var dir := (t - from).normalized() if t.distance_to(from) > 1.0 else Vector2.DOWN
	var tip := t - dir * 20.0
	_tut_arrow.clear_points()
	_tut_arrow.add_point(from)
	_tut_arrow.add_point(tip)
	_tut_arrow.add_point(tip + dir.rotated(2.6) * 12.0)
	_tut_arrow.add_point(tip)
	_tut_arrow.add_point(tip + dir.rotated(-2.6) * 12.0)
	_tut_arrow.visible = from.distance_to(t) > 30.0
	_tut_mark.position = t
	_tut_mark.visible = true


func set_log(lines: Array) -> void:
	if _log_box == null:
		return
	for c in _log_box.get_children():
		c.queue_free()
	if lines.is_empty():
		_log_box.add_child(_label("The battle has not started yet." if _time_label == null else "The battle has begun.", 12, MUTED))
		return
	var start := maxi(0, lines.size() - 6)
	for i in range(lines.size() - 1, start - 1, -1):
		var l: Dictionary = lines[i]
		var tt: float = l["t"]
		var lab := _label("%d:%02d  %s" % [int(tt) / 60, int(tt) % 60, l["text"]], 12, INK if l["hot"] else MUTED, true)
		lab.custom_minimum_size = Vector2(270, 0)
		_log_box.add_child(lab)


## Parts that change every fraction of a second (without rebuilding the panels).
func update_dynamic(sim: Sim, _pause_phase: bool, paused: bool) -> void:
	if _time_label != null:
		_time_label.text = "%d:%02d" % [int(sim.t) / 60, int(sim.t) % 60]
		var nw := sim.next_wave_t()
		if nw < INF:
			_time_label.text += "  ·  wave in %d s" % ceili(nw - sim.t)
	var in_play := _time_label != null
	for id: String in _ability_buttons:
		var b: Button = _ability_buttons[id]
		var u := sim.by_id(id)
		b.disabled = not in_play or paused or not sim.can_use_ability(id)
		var labs := b.find_children("*", "Label", true, false)
		if not labs.is_empty():
			var base := String(sim.ability_of(id)["name"])
			var tail := ""
			if u.uses <= 0:
				tail = "spent"
			elif u.ability_cd > 0.0:
				tail = "%s %d s" % ["●".repeat(u.uses), ceili(u.ability_cd)]
			else:
				tail = "●".repeat(u.uses)
			(labs[0] as Label).text = "%s  %s" % [base, tail]
			b.tooltip_text = String(sim.ability_of(id).get("desc", "")) + ("\n" + sim.ability_problem(id) if sim.ability_problem(id) != "" else "")
	for cid: String in _combo_buttons:
		var cb: Button = _combo_buttons[cid]
		var cprob := sim.combo_problem(cid)
		cb.disabled = not in_play or paused or cprob != ""
		cb.tooltip_text = String(cb.get_meta("tip", "")) + ("\n" + cprob if cprob != "" else "")
		cb.modulate = Color(1, 1, 1, 0.55) if cb.disabled else Color.WHITE
	if _hint_t > 0.0:
		_hint_t -= 0.1
		if _hint_t <= 0.0:
			_hint.text = ""
	if _pause_button != null:
		_pause_button.disabled = paused or sim.over != ""
	if _morale_box != null:
		var ms := sim.morale_state()
		if String(ms["state"]) + ("|w" if ms["waves"] else "") != _morale_state:
			_build_morale(sim)
		else:
			_update_morale(sim, ms)
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


# ================================================================ above heads: health and icons

func update_hp_bars(sim: Sim, cam: Camera3D, views: Dictionary, show_full: bool) -> void:
	for u in sim.units:
		var o: Dictionary = _overhead.get(u.id, {})
		if o.is_empty():
			var holder := Control.new()
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var icons := HBoxContainer.new()
			icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icons.add_theme_constant_override("separation", 2)
			holder.add_child(icons)
			# dark backplate with the outline; heroes get a strip of their colour under it (told apart above their heads too)
			var bg := ColorRect.new()
			bg.color = UI.OUTLINE
			bg.size = Vector2(38, 7)
			bg.position = Vector2(-19, -1)
			if u.side == Sim.SIDE_KNIGHT:
				bg.color = u.color
				bg.size = Vector2(40, 11)
				bg.position = Vector2(-20, -2)
				var plate := ColorRect.new()
				plate.color = UI.OUTLINE
				plate.size = Vector2(38, 7)
				plate.position = Vector2(1, 1)
				plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
				bg.add_child(plate)
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(bg)
			var fill := ColorRect.new()
			fill.color = Color("#5E9A52") if u.side == Sim.SIDE_KNIGHT else Color("#C8423A")
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
			_fill_icons(box, icons, 17, true)
			box.position = Vector2(-icons.size() * 9.5, -22)


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


## Oath confirmation: the order would break an oath. Shows the oath's POWER, RESTRICTION and what breaking it costs.
func ask_oath(knight_name: String, oath: Dictionary, why: String, on_break: Callable, on_keep: Callable, keep_text: String = "Cancel order") -> void:
	_oath_break_cb = on_break
	_oath_keep_cb = on_keep
	_oath_keep_btn.text = keep_text
	var cost := int(oath.get("break_glory_cost", 0))
	for c in _oath_body.get_children():
		c.queue_free()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(Icon.make("status_oath", UI.OATH, 34))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.add_child(UI.eyebrow("%s would break his oath" % knight_name, UI.OATH, 11))
	hv.add_child(UI.title(String(oath.get("name", "")), 22))
	head.add_child(hv)
	_oath_body.add_child(head)
	var why_l := UI.label("“%s”" % why.strip_edges().trim_suffix("."), 16, UI.TEXT_2, true, "lore_i")
	why_l.custom_minimum_size = Vector2(440, 0)
	_oath_body.add_child(why_l)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	for row: Array in [["Power", String(oath.get("power", oath.get("desc", ""))), UI.GOOD],
			["Restriction", String(oath.get("restriction", "")), UI.OATH],
			["If broken", "The oath stops working, the house loses %d glory and a broken oath is not passed on." % cost, UI.TEXT]]:
		if String(row[1]) == "":
			continue
		var k := UI.eyebrow(row[0], row[2], 11)
		k.custom_minimum_size = Vector2(96, 0)
		grid.add_child(k)
		var val := UI.label(row[1], 14, INK, true)
		val.custom_minimum_size = Vector2(330, 0)
		grid.add_child(val)
	var gp := PanelContainer.new()
	gp.add_theme_stylebox_override("panel", UI.inset_box(12))
	gp.add_child(grid)
	_oath_body.add_child(gp)
	_no_focus(oath_dialog)
	_oath_veil.visible = true
	oath_dialog.visible = true
	oath_dialog.reset_size()


func _close_oath(cb: Callable) -> void:
	_oath_veil.visible = false
	oath_dialog.visible = false
	if cb.is_valid():
		cb.call()


func oath_open() -> bool:
	return oath_dialog != null and oath_dialog.visible


func oath_keep() -> void:
	_close_oath(_oath_keep_cb)


func show_result(sim: Sim, _setup: Dictionary) -> void:
	for c in result_box.get_children():
		c.queue_free()
	var win := sim.over == "win"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	result_box.add_child(v)
	v.add_child(UI.eyebrow("Battle over · %d:%02d" % [int(sim.t) / 60, int(sim.t) % 60], MUTED, 11))
	v.add_child(UI.title(String(sim.scenario.get("win_title", "Victory")) if win else "The squad has fallen", 28, OK if win else BAD))
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
		["Fallen", ", ".join(fallen) if not fallen.is_empty() else "no one"],
		["Enemies fled", str(fled)],
		["Optional task", "done, %s" % sim.scenario["optional_task"]["reward"] if win and sim.task_ok else "not done"],
		["Oaths", "kept" if sim.oaths_broken() == 0 else "broken: %d" % sim.oaths_broken()],
		["Abilities used", "%d×" % sim.abilities_used],
		["Glory", str(int(sim.glory))],
		["Most glory brought by", best_glory if best_glory != "" else "no one"],
	]:
		g.add_child(UI.label(pair[0], 14, MUTED, false, "ui", 600))
		g.add_child(_label(pair[1], 14))
	v.add_child(g)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	if run_mode:
		var cont := _primary(Button.new())
		cont.text = "Continue the run" if win else "House chronicle"
		cont.pressed.connect(func() -> void: run_continue_pressed.emit())
		row.add_child(cont)
		v.add_child(row)
		_no_focus(result_box)
		result_box.visible = true
		return
	var again := Button.new()
	again.text = "Again, same setup"
	again.pressed.connect(func() -> void: retry_pressed.emit())
	row.add_child(again)
	var redeploy := _primary(Button.new())
	redeploy.text = "New deployment"
	redeploy.pressed.connect(func() -> void: redeploy_pressed.emit())
	row.add_child(redeploy)
	v.add_child(row)
	_no_focus(result_box)
	result_box.visible = true


func hide_result() -> void:
	result_box.visible = false


## Buttons must not take keyboard focus: otherwise Space and the arrows would control the panel instead of the game.
func _no_focus(node: Node) -> void:
	for c in node.find_children("*", "Control", true, false):
		(c as Control).focus_mode = Control.FOCUS_NONE



## A short hint at the top centre (e.g. why a target is not possible), disappears by itself.
## Box selection rectangle (in screen pixels).
func show_box(rect: Rect2) -> void:
	select_box.position = rect.position
	select_box.size = rect.size
	select_box.visible = true


func hide_box() -> void:
	select_box.visible = false


func flash_hint(text: String) -> void:
	_hint.text = text
	_hint_t = 2.0
