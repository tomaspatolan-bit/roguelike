extends PanelContainer
## Sandbox panel (testing tool, menu Sandbox): everything for trying out battles and catching edge cases.
## Only draws and sends requests (`request(kind, arg)`); battle.gd changes the setup or calls the simulation.
## Tabs: Battle (map, look, restart, gallery, menu), Heroes (relics of the house, start health, stats), Bonds (combo
## presets, bonds), Foes (without the map's enemies, place by click, kill, morale), Cheats (switches, heal, refill, speed).

const UI := preload("res://scripts/ui/ui_theme.gd")

signal request(kind: String, arg: Variant)

const LOOKS := [["", "Map default"], ["off", "Off (placeholder)"], ["noon", "Noon"], ["dawn", "Dawn"], ["dusk", "Dusk"]]
const SWITCHES := [
	["god", "Heroes cannot fall", "Health never drops below 1."],
	["free_uses", "Unlimited abilities", "Abilities and combos never run out and do not recharge."],
	["foes_idle", "Enemies are dummies", "Enemies stand still and do nothing (they still flee when their morale breaks)."],
	["endless", "Battle never ends", "No decided battle, no victory or defeat screen."],
]
const SPEEDS := [0.25, 0.5, 1.0, 2.0, 4.0]
const HP_STEPS := [1.0, 0.75, 0.5, 0.25]

var units_data: Dictionary = {}
var scenarios: Array = []          # [[key, name]]
var _body: TabContainer
var _bonds_box: VBoxContainer
var _combos_label: Label
var _switch_boxes: Dictionary = {}
var _relic_boxes: Dictionary = {}
var _spawn_btn: Button
var _foe_pick: OptionButton
var _foe_count: SpinBox
var _no_foes: CheckBox
var _map_pick: OptionButton
var _look_pick: OptionButton
var _bond_type: OptionButton
var _combo_pick: OptionButton
var _hp_picks: Dictionary = {}
var _stat_spins: Dictionary = {}    # hero -> stat -> SpinBox
var _speed_btns: Array = []
var _quiet := false                 # refresh in progress: widget signals do not send requests


func build(p_units: Dictionary, p_scenarios: Array) -> void:
	units_data = p_units
	scenarios = p_scenarios
	theme = UI.make_theme()
	theme.set_stylebox("normal", "LineEdit", UI.box(UI.RAISED, 4, 4, UI.BORDER_STRONG, 1))
	theme.set_stylebox("focus", "LineEdit", UI.box(UI.RAISED, 4, 4, UI.HOUSE, 2))
	theme.set_color("font_color", "LineEdit", UI.TEXT)
	add_theme_stylebox_override("panel", UI.panel_box(10, UI.BATTLE))
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = -372
	offset_right = -12
	offset_top = 96
	offset_bottom = -196
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_child(UI.eyebrow("Sandbox · testing", UI.OATH, 12))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var fold := Button.new()
	fold.text = "–"
	fold.tooltip_text = "Hide or show the sandbox panel."
	fold.custom_minimum_size = Vector2(30, 0)
	fold.pressed.connect(func() -> void:
		_body.visible = not _body.visible
		fold.text = "–" if _body.visible else "+"
		offset_bottom = -196 if _body.visible else offset_top - get_viewport_rect().size.y + 60)
	head.add_child(fold)
	v.add_child(head)
	_body = TabContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("font_size", 12)
	_body.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 4, 8, UI.BORDER, 1))
	_body.add_theme_stylebox_override("tab_selected", UI.box(UI.PANEL, 4, 6, UI.BORDER_STRONG, 1))
	_body.add_theme_stylebox_override("tab_unselected", UI.box(UI.INSET, 4, 6, UI.BORDER, 1))
	_body.add_theme_stylebox_override("tab_hovered", UI.box(Color("#FFF6DF"), 4, 6, UI.GLORY, 1))
	for k: String in ["font_selected_color", "font_hovered_color"]:
		_body.add_theme_color_override(k, UI.TEXT)
	_body.add_theme_color_override("font_unselected_color", UI.TEXT_MUTED)
	v.add_child(_body)
	_tab_battle()
	_tab_heroes()
	_tab_bonds()
	_tab_foes()
	_tab_cheats()
	_no_focus(self)


func _page(title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	return v


func _btn(text: String, kind: String, arg: Variant = null, tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(func() -> void: request.emit(kind, arg))
	return b


func _note(text: String) -> Label:
	return UI.label(text, 12, UI.TEXT_MUTED, true)


func _tab_battle() -> void:
	var v := _page("Battle")
	v.add_child(UI.eyebrow("Map"))
	_map_pick = OptionButton.new()
	for s: Array in scenarios:
		_map_pick.add_item(String(s[1]))
		_map_pick.set_item_metadata(_map_pick.item_count - 1, s[0])
	_map_pick.item_selected.connect(func(i: int) -> void:
		if not _quiet:
			request.emit("scenario", _map_pick.get_item_metadata(i)))
	v.add_child(_map_pick)
	v.add_child(UI.eyebrow("Look"))
	_look_pick = OptionButton.new()
	for l: Array in LOOKS:
		_look_pick.add_item(String(l[1]))
		_look_pick.set_item_metadata(_look_pick.item_count - 1, l[0])
	_look_pick.item_selected.connect(func(i: int) -> void:
		if not _quiet:
			request.emit("look", _look_pick.get_item_metadata(i)))
	v.add_child(_look_pick)
	v.add_child(_note("The diorama look (style test) is finished only for The River Bridge; other maps get the terrain and trees without their own buildings."))
	var r := _btn("Restart battle", "restart", null, "A fresh battle with everything set in the sandbox (heroes return to their places).")
	UI.primary(r, UI.OATH, 14)
	v.add_child(r)
	v.add_child(_btn("Character gallery", "gallery", null, "All heroes and enemies up close: animations, weapons, look."))
	v.add_child(_btn("Main menu", "menu"))
	v.add_child(_note("Ability, refinements, oath and passives of each hero: the menus on his card, before the start (Restart battle to change them again)."))


func _tab_heroes() -> void:
	var v := _page("Heroes")
	_house(v)
	v.add_child(HSeparator.new())
	v.add_child(UI.eyebrow("Heroes"))
	v.add_child(_note("Stat bonuses in % (as from rewards and relics) and starting health. Applied on Restart battle, the change restarts it."))
	var stats: Dictionary = units_data.get("stats", {})
	for cls: String in units_data["knights"]:
		var kd: Dictionary = units_data["knights"][cls]
		var row := HBoxContainer.new()
		var nm := UI.label("%s" % kd.get("name", cls), 14, Color(String(kd.get("color", "#242830"))).darkened(0.35), false, "ui", 700)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		var hp := OptionButton.new()
		hp.add_theme_font_size_override("font_size", 12)
		for f: float in HP_STEPS:
			hp.add_item("Health %d %%" % roundi(f * 100.0))
		hp.item_selected.connect(func(i: int) -> void:
			if not _quiet:
				request.emit("hp", [cls, HP_STEPS[i]]))
		_hp_picks[cls] = hp
		row.add_child(hp)
		v.add_child(row)
		var grid := GridContainer.new()
		grid.columns = 4
		_stat_spins[cls] = {}
		for sk: String in stats:
			if sk.begins_with("_"):
				continue
			grid.add_child(UI.label(String((stats[sk] as Dictionary).get("name", sk)), 12, UI.TEXT_2))
			var s := SpinBox.new()
			s.min_value = -50
			s.max_value = 200
			s.step = 10
			s.suffix = "%"
			s.custom_minimum_size = Vector2(78, 0)
			s.value_changed.connect(func(val: float) -> void:
				if not _quiet:
					request.emit("stat", [cls, sk, val / 100.0]))
			_stat_spins[cls][sk] = s
			grid.add_child(s)
		v.add_child(grid)
		v.add_child(HSeparator.new())


func _tab_bonds() -> void:
	var v := _page("Bonds")
	v.add_child(UI.eyebrow("Combo preset"))
	v.add_child(_note("Gives the pair the abilities of the combo and bonds them at the combo level, then restarts. The combo is on Q or E; both heroes must be close and both abilities ready."))
	_bond_type = OptionButton.new()
	for bk: String in units_data.get("bonds", {}):
		if bk.begins_with("_"):
			continue
		_bond_type.add_item("Bond type: %s" % units_data["bonds"][bk].get("name", bk))
		_bond_type.set_item_metadata(_bond_type.item_count - 1, bk)
	_bond_type.item_selected.connect(func(i: int) -> void:
		if not _quiet:
			request.emit("bond_type", _bond_type.get_item_metadata(i)))
	v.add_child(_bond_type)
	_combo_pick = OptionButton.new()
	_combo_pick.add_item("Pick a combo…")
	var owner := _ability_owners()
	for cid: String in units_data.get("combos", {}):
		if cid.begins_with("_"):
			continue
		var c: Dictionary = units_data["combos"][cid]
		_combo_pick.add_item("%s (%s + %s)" % [c["name"], _hero_name(owner.get(String(c["a"]), "")), _hero_name(owner.get(String(c["b"]), ""))])
		_combo_pick.set_item_metadata(_combo_pick.item_count - 1, cid)
	_combo_pick.item_selected.connect(func(i: int) -> void:
		if not _quiet and i > 0:
			request.emit("combo", _combo_pick.get_item_metadata(i)))
	v.add_child(_combo_pick)
	_combos_label = UI.label("", 13, UI.TEXT, true)
	v.add_child(_combos_label)
	v.add_child(HSeparator.new())
	v.add_child(UI.eyebrow("Bonds now"))
	_bonds_box = VBoxContainer.new()
	v.add_child(_bonds_box)
	v.add_child(UI.eyebrow("Add a bond"))
	var heroes := (units_data["knights"] as Dictionary).keys()
	var a := OptionButton.new()
	var b := OptionButton.new()
	for cls: String in heroes:
		a.add_item(_hero_name(cls))
		b.add_item(_hero_name(cls))
	b.select(1)
	var t := OptionButton.new()
	for bk: String in units_data.get("bonds", {}):
		if not bk.begins_with("_"):
			t.add_item(String(units_data["bonds"][bk].get("name", bk)))
			t.set_item_metadata(t.item_count - 1, bk)
	var lv := OptionButton.new()
	for i in 3:
		lv.add_item("Level %d" % (i + 1))
	lv.select(1)
	var row := HBoxContainer.new()
	row.add_child(a)
	row.add_child(UI.label("+", 14))
	row.add_child(b)
	v.add_child(row)
	var row2 := HBoxContainer.new()
	row2.add_child(t)
	row2.add_child(lv)
	v.add_child(row2)
	var add := Button.new()
	add.text = "Add bond"
	add.pressed.connect(func() -> void:
		request.emit("bond_add", [heroes[a.selected], heroes[b.selected], t.get_item_metadata(t.selected), lv.selected + 1]))
	v.add_child(add)


func _house(v: VBoxContainer) -> void:
	v.add_child(UI.eyebrow("Relics of the house in battle"))
	v.add_child(_note("Only relics that change the battle (stats, ability uses). Run-only relics (glory, healing after a battle, offers) have no effect here."))
	for rk: String in units_data.get("relics", {}):
		if rk.begins_with("_"):
			continue
		var rd: Dictionary = units_data["relics"][rk]
		var cb := CheckBox.new()
		cb.text = String(rd.get("name", rk))
		cb.tooltip_text = String(rd.get("desc", ""))
		cb.add_theme_font_size_override("font_size", 13)
		var battle_effect := rd.has("stats") or rd.has("extra_uses")
		cb.disabled = not battle_effect
		if not battle_effect:
			cb.text += " (run only)"
		cb.toggled.connect(func(on: bool) -> void:
			if not _quiet:
				request.emit("relic", [rk, on]))
		_relic_boxes[rk] = cb
		v.add_child(cb)


func _tab_foes() -> void:
	var v := _page("Foes")
	_no_foes = CheckBox.new()
	_no_foes.text = "Without the map's enemies"
	_no_foes.tooltip_text = "The battle starts empty; place enemies yourself (restarts the battle)."
	_no_foes.toggled.connect(func(on: bool) -> void:
		if not _quiet:
			request.emit("no_foes", on))
	v.add_child(_no_foes)
	v.add_child(UI.eyebrow("Place enemies"))
	_foe_pick = OptionButton.new()
	for fk: String in units_data["foes"]:
		_foe_pick.add_item(String(units_data["foes"][fk].get("name", fk)))
		_foe_pick.set_item_metadata(_foe_pick.item_count - 1, fk)
	v.add_child(_foe_pick)
	var row := HBoxContainer.new()
	row.add_child(UI.label("How many", 13))
	_foe_count = SpinBox.new()
	_foe_count.min_value = 1
	_foe_count.max_value = 12
	_foe_count.value = 1
	row.add_child(_foe_count)
	v.add_child(row)
	_spawn_btn = Button.new()
	_spawn_btn.toggle_mode = true
	_spawn_btn.text = "Place with left click"
	_spawn_btn.tooltip_text = "While on, a left click on the ground places the enemies (not in the water). Click the button again to stop."
	_spawn_btn.toggled.connect(func(on: bool) -> void:
		if not _quiet:
			request.emit("spawn_mode", [on, _foe_pick.get_item_metadata(_foe_pick.selected), int(_foe_count.value)]))
	_foe_pick.item_selected.connect(func(_i: int) -> void: _resend_spawn())
	_foe_count.value_changed.connect(func(_x: float) -> void: _resend_spawn())
	v.add_child(_spawn_btn)
	v.add_child(_note("Placed enemies are awake and form their own group (heroes can be sent at them)."))
	v.add_child(_btn("Kill all enemies", "kill", null, "Every enemy falls, later waves are cancelled."))
	v.add_child(_btn("Break their morale", "morale", null, "As if they had lost enough: bowmen flee, footmen fight desperately, All In! becomes available."))


func _resend_spawn() -> void:
	if not _quiet and _spawn_btn.button_pressed:
		request.emit("spawn_mode", [true, _foe_pick.get_item_metadata(_foe_pick.selected), int(_foe_count.value)])


func _tab_cheats() -> void:
	var v := _page("Cheats")
	for s: Array in SWITCHES:
		var cb := CheckBox.new()
		cb.text = String(s[1])
		cb.tooltip_text = String(s[2])
		cb.add_theme_font_size_override("font_size", 13)
		var key := String(s[0])
		cb.toggled.connect(func(on: bool) -> void:
			if not _quiet:
				request.emit("switch", [key, on]))
		_switch_boxes[key] = cb
		v.add_child(cb)
	v.add_child(_btn("Heal all heroes", "heal"))
	v.add_child(_btn("Refill abilities", "refill", null, "All uses back, no recharge."))
	v.add_child(UI.eyebrow("Speed"))
	var row := HBoxContainer.new()
	for sp: float in SPEEDS:
		var b := Button.new()
		b.toggle_mode = true
		b.text = "%s×" % str(sp)
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(func() -> void: request.emit("speed", sp))
		row.add_child(b)
		_speed_btns.append(b)
	v.add_child(row)


## Shows the current state: state = battle.gd sandbox state, setup = battle setup, combos = sim.combos().
func refresh(state: Dictionary, setup: Dictionary, combos: Array, speed: float) -> void:
	_quiet = true
	for i in _map_pick.item_count:
		if String(_map_pick.get_item_metadata(i)) == String(state.get("scenario", "")):
			_map_pick.select(i)
	for i in _look_pick.item_count:
		if String(_look_pick.get_item_metadata(i)) == String(state.get("look", "")):
			_look_pick.select(i)
	for i in _bond_type.item_count:
		if String(_bond_type.get_item_metadata(i)) == String(state.get("bond_type", "bratri")):
			_bond_type.select(i)
	_combo_pick.select(0)
	var sw: Dictionary = setup.get("sandbox", {})
	for k: String in _switch_boxes:
		(_switch_boxes[k] as CheckBox).button_pressed = bool(sw.get(k, false))
	_no_foes.button_pressed = bool(sw.get("no_foes", false))
	for rk: String in _relic_boxes:
		(_relic_boxes[rk] as CheckBox).button_pressed = (state.get("relics", []) as Array).has(rk)
	var hp: Dictionary = setup.get("hp", {})
	for cls: String in _hp_picks:
		var f := float(hp.get(cls, 1.0))
		var idx := 0
		for i in HP_STEPS.size():
			if absf(float(HP_STEPS[i]) - f) < 0.01:
				idx = i
		(_hp_picks[cls] as OptionButton).select(idx)
	var stats: Dictionary = state.get("stats", {})
	for cls: String in _stat_spins:
		for sk: String in _stat_spins[cls]:
			(_stat_spins[cls][sk] as SpinBox).value = float((stats.get(cls, {}) as Dictionary).get(sk, 0.0)) * 100.0
	for i in _speed_btns.size():
		(_speed_btns[i] as Button).button_pressed = is_equal_approx(float(SPEEDS[i]), speed)
	_spawn_btn.button_pressed = String(state.get("spawn_key", "")) != ""
	for c in _bonds_box.get_children():
		c.queue_free()
	var shown := {}
	var bonds: Dictionary = setup.get("bonds", {})
	for cls: String in bonds:
		var bd: Dictionary = bonds[cls]
		var other := String(bd.get("with", ""))
		if shown.has(other):
			continue
		shown[cls] = true
		var row := HBoxContainer.new()
		var tn := String((units_data.get("bonds", {}) as Dictionary).get(String(bd.get("type", "")), {}).get("name", bd.get("type", "")))
		var l := UI.label("%s + %s · %s, level %d" % [_hero_name(cls), _hero_name(other), tn, int(bd.get("level", 1))], 13, UI.TEXT, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var x := Button.new()
		x.text = "✕"
		x.tooltip_text = "Remove this bond (restarts the battle)."
		x.pressed.connect(func() -> void: request.emit("bond_remove", cls))
		row.add_child(x)
		_bonds_box.add_child(row)
	if shown.is_empty():
		_bonds_box.add_child(_note("No bonds."))
	var lines: Array = []
	for c: Dictionary in combos:
		lines.append("%s: %s (%s + %s)" % [c["key"], c["name"], _hero_name(String(c["a"])), _hero_name(String(c["b"]))])
	_combos_label.text = "Combos now: " + (", ".join(lines) if not lines.is_empty() else "none (a pair needs a bond at level 2 and the right abilities)")
	_quiet = false
	_no_focus(self)


func _ability_owners() -> Dictionary:
	var owner := {}
	for cls: String in units_data["knights"]:
		for ab: String in (units_data["knights"][cls].get("abilities", []) as Array):
			owner[ab] = cls
	return owner


func _hero_name(cls: String) -> String:
	return String((units_data["knights"] as Dictionary).get(cls, {}).get("name", cls))


func _no_focus(node: Node) -> void:
	if node is BaseButton or node is OptionButton:
		(node as Control).focus_mode = Control.FOCUS_NONE
	if node is OptionButton:
		# long items (combo names) must not widen the panel
		var ob := node as OptionButton
		ob.fit_to_longest_item = false
		ob.clip_text = true
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.custom_minimum_size.x = 60.0
	for c in node.get_children():
		_no_focus(c)
