extends Node
## Main scene: start, act map, battle → legacy and reward, event, camp, house chronicle.
## The run logic is in run_state.gd; here only screens and switching between them and the battle.
## Screen look is placeholder, Tom will design the final UI.

const Run := preload("res://scripts/run/run_state.gd")
const BattleScript := preload("res://scripts/battle/battle.gd")
const BattleScene := preload("res://scenes/battle/battle.tscn")
const BattleUI := preload("res://scripts/battle/battle_ui.gd")
const Icon := preload("res://scripts/battle/ui_icon.gd")
const MapView := preload("res://scripts/run/map_view.gd")

const INK := BattleUI.INK
const MUTED := BattleUI.MUTED
const GLORY := BattleUI.GLORY
const OK := BattleUI.OK
const BAD := BattleUI.BAD
const BANNER := BattleUI.BANNER
const LINE := BattleUI.LINE

var run: Run = null
var battle: Node = null
var layer: CanvasLayer
var screen: Control
var _chron_mark := 0       # where in the chronicle to start showing what the event brought
var _ui_helper: BattleUI   # borrowed styles (theme, buttons) from the battle UI, not added to the tree


func _ready() -> void:
	_ui_helper = BattleUI.new()
	layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	show_start()


func _exit_tree() -> void:
	if _ui_helper != null:
		_ui_helper.free()


# ================================================================ switching

func _new_screen(margin: int = 220) -> VBoxContainer:
	if screen != null:
		screen.queue_free()
	var bg := ColorRect.new()
	bg.color = Color("#14171b")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.theme = _ui_helper._make_theme()
	layer.add_child(bg)
	screen = bg
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bg.add_child(scroll)
	var center := MarginContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		center.add_theme_constant_override("margin_" + side, margin)
	center.add_theme_constant_override("margin_top", 48)
	center.add_theme_constant_override("margin_bottom", 48)
	scroll.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)
	return v


func _hide_screen() -> void:
	if screen != null:
		screen.queue_free()
		screen = null


func show_start() -> void:
	var v := _new_screen()
	v.add_child(_label("Knights", 44))
	v.add_child(_label("Prototype · phase 2", 14, MUTED))
	v.add_child(_label("Run: the House of the Wolf marches through %s. On the act map you pick your way on each floor: battle, elite (harder, better reward), event or camp (rest). Captain Kuno waits at the top. Wounds carry over between battles, the fallen stay fallen and successors take their place. Enemies who flee will return in the fight with the Captain." % String(Run.Sim._read_json("res://data/akt_1.json").get("name", "")), 16, INK, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var b := _primary("New run")
	b.pressed.connect(start_run)
	row.add_child(b)
	var f := _button("Free battle")
	f.tooltip_text = "A single battle with a choice of map and passives to try out (as before)."
	f.pressed.connect(_free_battle)
	row.add_child(f)
	if BattleScript.tutorial_done():
		var t := _button("Tutorial again")
		t.tooltip_text = "The controls tutorial will show again in the next battle."
		t.pressed.connect(func() -> void:
			BattleScript.set_tutorial_done(false)
			t.disabled = true
			t.text = "Tutorial in the next battle")
		row.add_child(t)
	v.add_child(row)


func start_run() -> void:
	run = Run.new()
	show_map()


func _free_battle() -> void:
	run = null
	_hide_screen()
	battle = BattleScene.instantiate()
	add_child(battle)


func _start_battle() -> void:
	_hide_screen()
	battle = BattleScene.instantiate()
	battle.set("run", run)
	battle.connect("battle_done", _on_battle_done)
	add_child(battle)


func _on_battle_done(result: Dictionary) -> void:
	run.record_battle(result)
	battle.queue_free()
	battle = null
	if run.over != "":
		show_chronicle()
	else:
		show_after_battle()


## Choosing a node on the map: a battle goes straight to the battle, otherwise the node screen.
func go_to(id: String) -> void:
	if not run.choose(id):
		return
	match run.node_type():
		"bitva", "elita", "boss":
			_start_battle()
		"udalost":
			show_event()
		"tabor":
			show_campfire()


# ================================================================ act map

func show_map() -> void:
	var v := _new_screen(60)
	var head := HBoxContainer.new()
	head.add_child(_label("%s · %s" % [run.act["name"], "start" if run.node_id == "" else "floor %d of %d" % [run.current_floor(), run.floor_count()]], 26))
	v.add_child(head)
	v.add_child(_label("Choose where the house goes next. Hover a node to see what awaits you there.", 14, MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)
	var mv := MapView.new()
	mv.custom_minimum_size = Vector2(880, 700)
	mv.size = mv.custom_minimum_size
	row.add_child(mv)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 12)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(side)
	var info := _label("", 15, INK, true)
	var info_panel := _panel(info)
	side.add_child(info_panel)
	side.add_child(_roster())
	mv.node_pressed.connect(go_to)
	mv.node_hovered.connect(func(id: String) -> void: info.text = _node_info(id))
	mv.setup(run)
	var av: Array = run.available()
	info.text = _node_info(av[0]) if not av.is_empty() else ""


func _node_info(id: String) -> String:
	var n: Dictionary = run.node(id)
	var t: String = n["type"]
	match t:
		"bitva", "elita", "boss":
			var sc: Dictionary = run.scenario_info(String(n["scenario"]))
			var extra := ""
			if sc.has("returnees") and not run.fled.is_empty():
				extra = "\nFled enemies return: %d" % run.fled.size()
			var reward := "Reward: 2 of %d offers." % int(run.act.get("elite_offers", 4)) if t == "elita" else "Reward: 1 of %d offers." % int(run.act.get("offers", 3))
			if t == "boss":
				reward = "Act boss."
			var md: Dictionary = run.units_data.get("battle_modes", {}).get(String(sc.get("mode", "stret")), {})
			return "%s: %s\n%s: %s\n%s\nTask: %s\n%s%s" % [run.NODE_NAMES[t], sc.get("name", ""), md.get("name", ""), md.get("desc", ""), sc.get("subtitle", ""), sc.get("optional_task", {}).get("text", ""), reward, extra]
		"udalost":
			return "Event: %s\nA decision with a price." % run.events_data[n["event"]]["name"]
		"tabor":
			return "Camp\nRest: wounds heal."
	return ""


# ================================================================ after the battle: legacy and reward

func show_after_battle() -> void:
	var v := _new_screen()
	var last := run.node_label()
	v.add_child(_label("After the battle: %s" % last, 30))
	v.add_child(_label("%s · floor %d of %d" % [run.act["name"], run.current_floor(), run.floor_count()], 14, MUTED))

	# what happened in the battle
	var news := VBoxContainer.new()
	for e: Dictionary in run.chronicle:
		if e["stage"] == last:
			news.add_child(_label("• " + String(e["text"]), 15, INK, true))
	v.add_child(_panel(news))

	if run.has_legacy():
		_legacy_block(v)
	elif not run.bond_offer().is_empty():
		_bond_block(v)
	elif not run.offers().is_empty():
		_reward_block(v)
	else:
		var go := _primary("To the map")
		go.pressed.connect(show_map)
		v.add_child(go)
	v.add_child(_roster())


# ================================================================ event

func show_event() -> void:
	var v := _new_screen()
	var ev: Dictionary = run.event()
	v.add_child(_label("Event", 14, MUTED))
	v.add_child(_label(String(ev["name"]), 30, GLORY))
	v.add_child(_panel(_label(String(ev["text"]), 16, INK, true)))
	var opts: Array = ev["options"]
	for i in opts.size():
		var o: Dictionary = opts[i]
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		var b := _primary(String(o["label"]))
		var problem: String = run.event_option_problem(i)
		b.disabled = problem != ""
		b.pressed.connect(func() -> void:
			_chron_mark = run.chronicle.size()
			run.event_choose(i)
			show_event_result())
		box.add_child(b)
		box.add_child(_label(String(o.get("hint", "")) + ("  (%s)" % problem if problem != "" else ""), 14, MUTED, true))
		v.add_child(_panel(box))
	v.add_child(_roster())


func show_event_result() -> void:
	var v := _new_screen()
	var ev: Dictionary = run.event()
	v.add_child(_label(String(ev["name"]), 30, GLORY))
	var news := VBoxContainer.new()
	for e: Dictionary in run.chronicle.slice(_chron_mark):
		news.add_child(_label("• " + String(e["text"]), 15, INK, true))
	if news.get_child_count() > 0:
		v.add_child(_panel(news))
	var go := _primary("To the map")
	go.pressed.connect(show_map)
	v.add_child(go)
	v.add_child(_roster())


# ================================================================ camp

func show_campfire() -> void:
	var v := _new_screen()
	v.add_child(_label("Camp", 30, OK))
	v.add_child(_label("The house lights a fire. Rest heals the wounds of all heroes.", 16, INK, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var rest := _primary("Rest")
	rest.disabled = run.camp_done
	rest.pressed.connect(func() -> void:
		run.camp_rest()
		show_campfire())
	row.add_child(rest)
	var go := _button("To the map")
	go.pressed.connect(show_map)
	row.add_child(go)
	v.add_child(row)
	v.add_child(_roster())


func _legacy_block(v: VBoxContainer) -> void:
	var l := run.legacy_current()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_label("Oath legacy", 22, GLORY))
	box.add_child(_label("%s fell and left behind the oath %s: %s Who will take it up? A hero can have only one oath." % [l["from"], run.passive_name(l["oath"]), run.passive_desc(l["oath"])], 15, INK, true))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	for cls: String in run.legacy_candidates():
		var b := _button("%s (%s)" % [run.hero_name(cls), run.class_name_of(cls)])
		b.pressed.connect(func() -> void:
			run.resolve_legacy(cls)
			show_after_battle())
		row.add_child(b)
	var no := _button("Let the oath die")
	no.pressed.connect(func() -> void:
		run.resolve_legacy("")
		show_after_battle())
	row.add_child(no)
	box.add_child(row)
	v.add_child(_panel(box))


## Bond: the pair won enough battles together, the player picks the type out of two (or postpones).
func _bond_block(v: VBoxContainer) -> void:
	var o := run.bond_offer()
	var a: String = o["a"]
	var b: String = o["b"]
	v.add_child(_label("Bond: %s and %s" % [run.hero_name(a), run.hero_name(b)], 22, GLORY))
	v.add_child(_label("Shared victories: %d. What bond will form between them? A bond grows with more shared victories (level 2 unlocks a combo); when one falls, the other carries grief." % int(o["wins"]), 15, INK, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for t: String in o["choices"]:
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 6)
		card.add_child(_label(run.bond_name(t), 19, GLORY, true))
		card.add_child(_label(run.bond_desc(t), 14, INK, true))
		card.add_child(_label("Grief: " + String(run.units_data["bonds"][t].get("grief_desc", "")), 13, MUTED, true))
		var pick := _primary("Choose")
		pick.pressed.connect(func() -> void:
			run.choose_bond(t)
			show_after_battle())
		card.add_child(pick)
		var p := _panel(card)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(p)
	v.add_child(row)
	var later := _button("Not yet (offered again after the next shared victory)")
	later.pressed.connect(func() -> void:
		run.choose_bond("")
		show_after_battle())
	v.add_child(later)


func _reward_block(v: VBoxContainer) -> void:
	var offers := run.offers()
	v.add_child(_label("Reward: choose one" if run.picks_left() <= 1 else "Elite reward: choose %d" % run.picks_left(), 22, GLORY))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for i in offers.size():
		var o: Dictionary = offers[i]
		var key: String = o["passive"]
		var cls: String = o["hero"]
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 6)
		var head := HBoxContainer.new()
		head.add_child(Icon.make(cls, INK, 22))
		head.add_child(_label("%s" % run.hero_name(cls), 17))
		card.add_child(head)
		card.add_child(_label(("Oath: " if run.is_oath(key) else "") + run.passive_name(key), 19, BANNER if run.is_oath(key) else GLORY, true))
		card.add_child(_label(run.passive_desc(key), 14, MUTED, true))
		var pick := _primary("Choose")
		pick.pressed.connect(func() -> void:
			run.pick_offer(i)
			show_after_battle())
		card.add_child(pick)
		var p := _panel(card)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(p)
	v.add_child(row)


func _roster() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_label("House of the Wolf · glory %d" % int(run.glory), 18, GLORY))
	for cls: String in run.heroes:
		var h: Dictionary = run.heroes[cls]
		var names: Array = []
		for k: String in h["passives"]:
			names.append(("Oath: " if run.is_oath(k) else "") + run.passive_name(k))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(Icon.make(cls, INK, 18))
		var nl := _label("%s (%s)" % [h["name"], run.class_name_of(cls)], 15)
		nl.custom_minimum_size = Vector2(220, 0)
		row.add_child(nl)
		var hpb := _ui_helper._bar(OK if run.hp_of(cls) > 0.5 else (GLORY if run.hp_of(cls) > 0.25 else BAD), 8)
		hpb.max_value = 1.0
		hpb.value = run.hp_of(cls)
		hpb.custom_minimum_size = Vector2(70, 8)
		hpb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hpb.tooltip_text = "Health %d %%" % roundi(run.hp_of(cls) * 100.0)
		row.add_child(hpb)
		var bd: Dictionary = h.get("bond", {})
		if not bd.is_empty():
			names.append("Bond %s · %s (lvl %d, shared victories: %d)" % [run.bond_name(bd["type"]), run.hero_name(bd["with"]), run.bond_level(cls), run.wins_of(cls, bd["with"])])
		var pl := _label(", ".join(names) if not names.is_empty() else "no passives", 14, MUTED, true)
		pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(pl)
		box.add_child(row)
	if not run.fallen.is_empty():
		var f: Array = []
		for d: Dictionary in run.fallen:
			f.append("%s (%s)" % [d["name"], d["stage"]])
		box.add_child(_label("Fallen: " + ", ".join(f), 14, BAD, true))
	if not run.fled.is_empty():
		box.add_child(_label("Fled enemies who may return: %d" % run.fled.size(), 14, MUTED))
	return _panel(box)


# ================================================================ kronika

func show_chronicle() -> void:
	var v := _new_screen()
	var win := run.over == "win"
	v.add_child(_label("House chronicle", 16, MUTED))
	v.add_child(_label("The House of the Wolf is victorious" if win else "The House of the Wolf has fallen", 36, OK if win else BAD))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var cur := "-"
	for e: Dictionary in run.chronicle:
		var st: String = e["stage"]
		if st != "" and st != cur:
			cur = st
			box.add_child(_label(st, 18, GLORY))
		box.add_child(_label("• " + String(e["text"]), 15, INK, true))
	v.add_child(_panel(box))
	v.add_child(_roster())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var again := _primary("New run")
	again.pressed.connect(start_run)
	row.add_child(again)
	var menu := _button("Main menu")
	menu.pressed.connect(show_start)
	row.add_child(menu)
	v.add_child(row)


# ================================================================ helpers

func _label(text: String, size: int = 15, color: Color = INK, wrap: bool = false) -> Label:
	return _ui_helper._label(text, size, color, wrap)


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	return b


func _primary(text: String) -> Button:
	var b := _ui_helper._primary(Button.new())
	b.text = text
	b.custom_minimum_size = Vector2(180, 44)
	return b


func _panel(child: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_child(child)
	return p
