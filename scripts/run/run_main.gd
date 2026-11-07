extends Node
## Main scene: start, act map, battle → legacy and reward, event, camp, house chronicle.
## The run logic is in run_state.gd; here only screens and switching between them and the battle.
## Look: Royal Court Enamel (light canvas, enamel panels; scripts/ui/ui_theme.gd).

const Run := preload("res://scripts/run/run_state.gd")
const BattleScript := preload("res://scripts/battle/battle.gd")
const BattleScene := preload("res://scenes/battle/battle.tscn")
const BattleUI := preload("res://scripts/battle/battle_ui.gd")
const Icon := preload("res://scripts/battle/ui_icon.gd")
const MapView := preload("res://scripts/run/map_view.gd")
const UI := preload("res://scripts/ui/ui_theme.gd")
const CAMP_ICONS := {"rest": "camp_rest", "train": "camp_training", "rite": "camp_rite", "feast": "camp_feast"}

const INK := BattleUI.INK
const MUTED := BattleUI.MUTED
const GLORY := BattleUI.GLORY
const OK := BattleUI.OK
const BAD := BattleUI.BAD
const BANNER := BattleUI.BANNER
const LINE := BattleUI.LINE
const STEEL_C := BattleUI.STEEL

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
	var bg := UI.canvas_rect()
	bg.theme = UI.make_theme()
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
	v.add_child(UI.title("Knights", 56))
	v.add_child(UI.eyebrow("Prototype · phase 2", GLORY, 12))
	v.add_child(_rule())
	v.add_child(UI.label("Run: the House of the Wolf marches through %s. On the act map you pick your way on each floor: battle, elite (harder, better reward), event or camp (rest). Captain Kuno waits at the top. Wounds carry over between battles, the fallen stay fallen and successors take their place. Enemies who flee will return in the fight with the Captain." % String(Run.Sim._read_json("res://data/akt_1.json").get("name", "")), 19, UI.TEXT_2, true, "lore"))
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
			_chron_mark = run.chronicle.size()
			show_campfire()


# ================================================================ act map

func show_map() -> void:
	var v := _new_screen(60)
	var head := HBoxContainer.new()
	var tl := UI.title(String(run.act["name"]), 30)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	head.add_child(_label("start" if run.node_id == "" else "floor %d of %d" % [run.current_floor(), run.floor_count()], 16, MUTED))
	v.add_child(head)
	v.add_child(UI.label("Choose where the house goes next. Hover a node to see what awaits you there.", 16, UI.TEXT_2, false, "lore_i"))
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
	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 6)
	info_box.add_child(UI.eyebrow("What awaits", GLORY, 11))
	info_box.add_child(info)
	var info_panel := _panel(info_box)
	side.add_child(info_panel)
	side.add_child(_roster(show_map))
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
			return "Camp\nOne choice: rest, training, rite or feast."
	return ""


# ================================================================ after the battle: legacy and reward

func show_after_battle() -> void:
	var v := _new_screen()
	var last := run.node_label()
	v.add_child(UI.eyebrow("After the battle · %s · floor %d of %d" % [run.act["name"], run.current_floor(), run.floor_count()], MUTED, 12))
	v.add_child(UI.title(last, 32))

	# what happened in the battle
	var news := VBoxContainer.new()
	news.add_theme_constant_override("separation", 4)
	news.add_child(UI.eyebrow("What happened", GLORY, 11))
	for e: Dictionary in run.chronicle:
		if e["stage"] == last:
			news.add_child(_label("• " + String(e["text"]), 15, INK, true))
	v.add_child(_panel(news))

	if run.has_legacy():
		_legacy_block(v)
	else:
		_pending_or_map(v, show_after_battle)
	v.add_child(_roster(show_after_battle))


# ================================================================ event

func show_event() -> void:
	var v := _new_screen()
	var ev: Dictionary = run.event()
	v.add_child(UI.eyebrow("Event", GLORY, 12))
	v.add_child(UI.title(String(ev["name"]), 32))
	v.add_child(_panel(UI.label(String(ev["text"]), 19, UI.TEXT, true, "lore")))
	var opts: Array = ev["options"]
	for i in opts.size():
		var o: Dictionary = opts[i]
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 14)
		var b := _primary(String(o["label"]))
		b.custom_minimum_size = Vector2(300, 44)
		var problem: String = run.event_option_problem(i)
		b.disabled = problem != ""
		b.pressed.connect(func() -> void:
			_chron_mark = run.chronicle.size()
			run.event_choose(i)
			show_event_result())
		box.add_child(b)
		var hint := _label(String(o.get("hint", "")) + ("  (%s)" % problem if problem != "" else ""), 14, BAD if problem != "" else UI.TEXT_2, true)
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(hint)
		var op := _panel(box)
		op.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.RADIUS, 12, UI.OUTLINE if problem == "" else UI.BORDER, 2, 2 if problem == "" else 0))
		v.add_child(op)
	v.add_child(_roster(show_event))


func show_event_result() -> void:
	var v := _new_screen()
	var ev: Dictionary = run.event()
	v.add_child(UI.eyebrow("Event · outcome", GLORY, 12))
	v.add_child(UI.title(String(ev["name"]), 32))
	var news := VBoxContainer.new()
	for e: Dictionary in run.chronicle.slice(_chron_mark):
		news.add_child(_label("• " + String(e["text"]), 15, INK, true))
	if news.get_child_count() > 0:
		v.add_child(_panel(news))
	_pending_or_map(v, show_event_result)
	v.add_child(_roster(show_event_result))


# ================================================================ camp

## Camp: one of four choices (rest, training, rite, feast); training and rite first ask which hero,
## the feast which pair. Then the choice or bond it opened, then back to the map.
func show_campfire(pick_for: String = "") -> void:
	var v := _new_screen()
	v.add_child(UI.eyebrow("Night in the forest", OK, 12))
	v.add_child(UI.title("Camp", 32))
	if run.camp_done:
		var news := VBoxContainer.new()
		for e: Dictionary in run.chronicle.slice(_chron_mark):
			news.add_child(_label("• " + String(e["text"]), 15, INK, true))
		if news.get_child_count() > 0:
			v.add_child(_panel(news))
		_pending_or_map(v, show_campfire)
		v.add_child(_roster(show_campfire))
		return
	if pick_for != "":
		var c: Dictionary = run.act["camp"][pick_for]
		v.add_child(UI.label("%s: %s" % [c["name"], c.get("desc", "")], 18, UI.TEXT_2, true, "lore"))
		v.add_child(UI.eyebrow("Choose a pair" if String(c.get("needs", "")) == "pair" else "Choose a hero", GLORY, 11))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		if String(c.get("needs", "")) == "pair":
			var ks: Array = run.heroes.keys()
			for i in ks.size():
				for j in range(i + 1, ks.size()):
					var a: String = ks[i]
					var b: String = ks[j]
					var btn := _hero_tile([a, b], "%s + %s" % [run.hero_name(a), run.hero_name(b)], "Shared victories: %d" % run.wins_of(a, b))
					btn.tooltip_text = "Shared victories: %d" % run.wins_of(a, b)
					btn.pressed.connect(func() -> void:
						_chron_mark = run.chronicle.size()
						run.camp_choose(pick_for, "%s|%s" % [a, b])
						show_campfire())
					flow.add_child(btn)
		else:
			for cls: String in run.heroes:
				var btn := _hero_tile([cls], run.hero_name(cls), run.class_name_of(cls))
				btn.pressed.connect(func() -> void:
					_chron_mark = run.chronicle.size()
					if not run.camp_choose(pick_for, cls):
						return
					show_campfire())
				flow.add_child(btn)
		v.add_child(flow)
		var back := _button("Back")
		back.pressed.connect(func() -> void: show_campfire())
		v.add_child(back)
		v.add_child(_roster())
		return
	v.add_child(UI.label("The house lights a fire. Choose one thing to do tonight.", 19, UI.TEXT_2, true, "lore_i"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for o: Dictionary in run.camp_options():
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 8)
		var id: String = o["id"]
		var medal := Icon.make(CAMP_ICONS.get(id, "map_camp"), OK if String(o["problem"]) == "" else MUTED, 40)
		medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.add_child(medal)
		var ct := UI.title(String(o["name"]), 19)
		ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(ct)
		if int(o["cost"]) > 0:
			var cost := _chip_label("%d glory" % int(o["cost"]), GLORY)
			cost.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			card.add_child(cost)
		var cd := _label(String(o["desc"]), 14, UI.TEXT_2, true)
		cd.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.add_child(cd)
		if String(o["problem"]) != "":
			card.add_child(_label(String(o["problem"]), 13, BAD, true))
		var btn := _primary("Choose")
		btn.disabled = String(o["problem"]) != ""
		btn.tooltip_text = String(o["problem"])
		btn.pressed.connect(func() -> void:
			if String(o["needs"]) != "":
				show_campfire(id)
			else:
				_chron_mark = run.chronicle.size()
				run.camp_choose(id)
				show_campfire())
		card.add_child(btn)
		var p := _panel(card)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(p)
	v.add_child(row)
	var go := _button("Break camp without a choice")
	go.pressed.connect(show_map)
	v.add_child(go)
	v.add_child(_roster(show_campfire))


func _legacy_block(v: VBoxContainer) -> void:
	var l := run.legacy_current()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var lh := HBoxContainer.new()
	lh.add_theme_constant_override("separation", 10)
	lh.add_child(Icon.make("hud_fallen", BAD, 30))
	var lt := VBoxContainer.new()
	lt.add_theme_constant_override("separation", 0)
	lt.add_child(UI.eyebrow("Oath legacy · %s fell" % l["from"], BAD, 11))
	lt.add_child(UI.title(run.passive_name(l["oath"]), 22, BANNER))
	lh.add_child(lt)
	box.add_child(lh)
	box.add_child(_label("%s Who will take it up? A hero can have only one oath." % run.passive_desc(l["oath"]), 15, INK, true))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	for cls: String in run.legacy_candidates():
		var b := _hero_tile([cls], run.hero_name(cls), run.lineage(cls) if run.lineage(cls) != "" else run.class_name_of(cls))
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
func _bond_block(v: VBoxContainer, back: Callable) -> void:
	var o := run.bond_offer()
	var a: String = o["a"]
	var b: String = o["b"]
	v.add_child(UI.eyebrow("A bond forms · shared victories %d" % int(o["wins"]), UI.BOND[1], 11))
	v.add_child(UI.title("%s and %s" % [run.hero_name(a), run.hero_name(b)], 22))
	v.add_child(_label("Shared victories: %d. What bond will form between them? A bond grows with more shared victories (level 2 unlocks a combo); when one falls, the other carries grief." % int(o["wins"]), 15, INK, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for t: String in o["choices"]:
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 6)
		var bh := HBoxContainer.new()
		bh.add_theme_constant_override("separation", 8)
		bh.add_child(Icon.make("status_bond", UI.BOND[1], 24))
		bh.add_child(UI.title(run.bond_name(t), 18))
		card.add_child(bh)
		card.add_child(_label(run.bond_desc(t), 14, INK, true))
		var grief := PanelContainer.new()
		grief.add_theme_stylebox_override("panel", UI.inset_box(8))
		grief.add_child(_label("Grief: " + String(run.units_data["bonds"][t].get("grief_desc", "")), 13, UI.TEXT_2, true))
		card.add_child(grief)
		var pick := _primary("Choose")
		pick.pressed.connect(func() -> void:
			run.choose_bond(t)
			back.call())
		card.add_child(pick)
		var p := _panel(card)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(p)
	v.add_child(row)
	var later := _button("Not yet (offered again after the next shared victory)")
	later.pressed.connect(func() -> void:
		run.choose_bond("")
		back.call())
	v.add_child(later)


const OFFER_TITLES := {"battle": "Reward: choose one", "elite": "Elite reward: choose %d", "training": "Training: choose a passive",
	"rite": "Rite: choose", "oath": "Swear an oath: choose one", "passive": "Choose a passive", "max_hp": "Whose armour will the smith rework?",
	"ability": "Learn a new ability: choose one"}


## Offer cards (reward after a battle, training, rite, event choice): hero, what he gets, what it means for him
## (green fits, red clashes or a wasted stat), Choose. After a battle the reward can be declined for glory.
func _reward_block(v: VBoxContainer, back: Callable) -> void:
	var offers := run.offers()
	var title := String(OFFER_TITLES.get(run.offer_title, "Choose one"))
	v.add_child(UI.title(title % run.picks_left() if title.contains("%d") else title, 22))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for i in offers.size():
		var o: Dictionary = offers[i]
		var cls: String = o["hero"]
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 6)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		head.add_child(Icon.make(cls, _hero_col(cls), 24))
		var hn := VBoxContainer.new()
		hn.add_theme_constant_override("separation", -2)
		hn.add_child(UI.label(run.hero_name(cls), 16, INK, false, "ui", 700))
		hn.add_child(UI.eyebrow(run.class_name_of(cls), MUTED, 10))
		head.add_child(hn)
		card.add_child(head)
		card.add_child(_rule())
		var okind := String(o.get("kind", "passive"))
		var kind_txt := {"max_hp": "Armour", "release_oath": "Release", "ability": "New ability"}.get(okind, "Oath" if okind == "passive" and run.is_oath(String(o.get("passive", ""))) else "Passive") as String
		card.add_child(_chip_label(kind_txt.to_upper(), BANNER if kind_txt == "Oath" or kind_txt == "Release" else (STEEL_C if kind_txt == "New ability" else GLORY)))
		match String(o.get("kind", "passive")):
			"max_hp":
				card.add_child(UI.label("Toughness +%d %%" % roundi(float(o.get("value", 0.1)) * 100.0), 19, INK, true, "ui", 700))
				card.add_child(_label("More health for good.", 14, MUTED, true))
			"release_oath":
				card.add_child(UI.label("Lay down: " + run.passive_name(run.oath_of(cls)), 19, BANNER, true, "ui", 700))
				card.add_child(_label("Released from the oath without shame or cost.", 14, MUTED, true))
			"ability":
				var ak := String(o["ability"])
				card.add_child(UI.label(run.ability_name(ak), 19, INK, true, "ui", 700))
				card.add_child(_label(String(run.units_data["abilities"][ak].get("desc", "")), 14, MUTED, true))
				for note: Array in run.offer_notes(o):
					card.add_child(_label(("+ " if note[0] else "− ") + String(note[1]), 13, OK if note[0] else BAD, true))
			_:
				var key: String = o["passive"]
				card.add_child(UI.label(run.passive_name(key), 19, BANNER if run.is_oath(key) else INK, true, "ui", 700))
				card.add_child(_label(run.passive_desc(key), 14, MUTED, true))
				for note: Array in run.offer_notes(o):
					card.add_child(_label(("+ " if note[0] else "− ") + String(note[1]), 13, OK if note[0] else BAD, true))
		var pick := _primary("Choose")
		pick.pressed.connect(func() -> void:
			run.pick_offer(i)
			back.call())
		card.add_child(pick)
		var p := _panel(card)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(p)
	v.add_child(row)
	if run.offer_declinable:
		var dec := _button("Decline the reward (+%d glory)" % int(run.act.get("decline_glory", 15)))
		dec.pressed.connect(func() -> void:
			run.decline_offers()
			back.call())
		v.add_child(dec)


## What is still pending at the node (bond, choice), otherwise the way back to the map.
func _pending_or_map(v: VBoxContainer, back: Callable) -> void:
	if not run.bond_offer().is_empty():
		_bond_block(v, back)
	elif not run.offers().is_empty():
		_reward_block(v, back)
	else:
		var go := _primary("To the map")
		go.pressed.connect(show_map)
		v.add_child(go)


## Short house overview under each screen; `back` = the screen to return to from the house page (button "House").
func _roster(back: Callable = Callable()) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var tl := UI.title(String(run.house["name"]), 18)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tl)
	top.add_child(_glory_chip())
	if back.is_valid():
		var hb := _icon_btn("hud_house", "House")
		hb.tooltip_text = "The house in detail: abilities, oaths, bonds, combos, the fallen."
		hb.custom_minimum_size.x = 110
		hb.pressed.connect(func() -> void: show_house(back))
		top.add_child(hb)
	box.add_child(top)
	box.add_child(_rule())
	for cls: String in run.heroes:
		var h: Dictionary = run.heroes[cls]
		var names: Array = [run.ability_name(run.ability_of(cls))]
		for k: String in h["passives"]:
			names.append(("Oath: " if run.is_oath(k) else "") + run.passive_name(k))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var ric := Icon.make(cls, _hero_col(cls), 20)
		ric.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ric)
		var nl := UI.label("%s (%s)" % [h["name"], run.class_name_of(cls)], 15, INK, false, "ui", 600)
		nl.custom_minimum_size = Vector2(220, 0)
		nl.tooltip_text = run.lineage(cls)
		nl.mouse_filter = Control.MOUSE_FILTER_PASS
		if run.lineage(cls) != "":
			var nv := VBoxContainer.new()
			nv.add_theme_constant_override("separation", -2)
			nv.custom_minimum_size = Vector2(220, 0)
			nv.add_child(nl)
			nv.add_child(UI.label(run.lineage(cls), 12, MUTED, false, "lore_i"))
			nv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(nv)
		else:
			nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
		var fr := HBoxContainer.new()
		fr.add_theme_constant_override("separation", 6)
		fr.add_child(Icon.make("hud_fallen", BAD, 18))
		var fl := _label("Fallen: " + ", ".join(f), 14, BAD, true)
		fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fr.add_child(fl)
		box.add_child(fr)
	if not run.fled.is_empty():
		box.add_child(_label("Fled enemies who may return: %d" % run.fled.size(), 14, MUTED))
	return _panel(box)


# ================================================================ kronika

func show_chronicle() -> void:
	var v := _new_screen()
	var win := run.over == "win"
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 8)
	ch.add_child(Icon.make("hud_chronicle", GLORY, 20))
	ch.add_child(UI.eyebrow("House chronicle", GLORY, 12))
	v.add_child(ch)
	v.add_child(UI.title("The House of the Wolf is victorious" if win else "The House of the Wolf has fallen", 34, OK if win else BAD))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var cur := "-"
	for e: Dictionary in run.chronicle:
		var st: String = e["stage"]
		if st != "" and st != cur:
			cur = st
			if box.get_child_count() > 0:
				box.add_child(_rule())
			box.add_child(UI.title(st, 16, GLORY))
		box.add_child(UI.label(String(e["text"]), 17, INK, true, "lore"))
	v.add_child(_panel(box))
	v.add_child(_roster(show_chronicle))
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


## Thin gilt rule between parts of a panel.
func _rule() -> Control:
	var r := ColorRect.new()
	r.color = Color(UI.BORDER_STRONG, 0.45)
	r.custom_minimum_size = Vector2(0, 1)
	return r


## Small caps chip (offer kind, cost).
func _chip_label(text: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(UI.RAISED, 3, 4, col, 1))
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.add_child(UI.label(text, 10, col, false, "ui", 800))
	return p


func _glory_chip() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(UI.INSET, UI.RADIUS, 6, UI.GILT, 2))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(Icon.make("hud_glory", GLORY, 18))
	h.add_child(UI.label("%d glory" % int(run.glory), 14, INK, false, "ui", 700))
	p.add_child(h)
	p.tooltip_text = "Glory: the run's currency (at most %d)." % int(run.house["glory"].get("max", 120))
	return p


## Secondary button with an Oathline icon in front of the text.
func _icon_btn(kind: String, text: String) -> Button:
	var b := _button(text)
	b.icon = Icon.texture(kind, 36)
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", 18)
	b.add_theme_color_override("icon_normal_color", GLORY)
	b.add_theme_color_override("icon_hover_color", GLORY)
	b.add_theme_color_override("icon_pressed_color", GLORY)
	return b


## Hero picker tile: class icons, name, one line below (class or lineage).
func _hero_tile(classes: Array, title: String, sub: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(220, 64)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.offset_right = -12
	h.add_theme_constant_override("separation", 8)
	for c: String in classes:
		var ic := Icon.make(c, _hero_col(c), 26)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
	var tv := VBoxContainer.new()
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tv.add_theme_constant_override("separation", -1)
	var tl := UI.label(title, 15, INK, false, "ui", 700)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(tl)
	var sl := UI.label(sub, 12, MUTED)
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(sl)
	h.add_child(tv)
	b.add_child(h)
	b.custom_minimum_size.x = maxf(220.0, 64.0 + 30.0 * classes.size() + maxf(title.length(), sub.length()) * 8.0)
	return b


## Hero colour readable on the light canvas.
func _hero_col(cls: String) -> Color:
	return UI.on_light(Color(String(run.units_data["knights"][cls].get("color", "#242830"))))


# ================================================================ house page (roster detail)

const BOND_COLORS := UI.BOND   # bond level 1, 2, 3 (2 = combos): steel, gold, violet


## Lines above the hero cards: who is bonded with whom (a bracket from card to card, label in the middle).
class BondLines:
	extends Control
	var cards: Dictionary = {}   # class -> card Control
	var links: Array = []        # [{"a", "b", "text", "color", "level"}]

	func _draw() -> void:
		var font := get_theme_default_font()
		var o := get_global_rect().position
		for i in links.size():
			var l: Dictionary = links[i]
			var ca: Control = cards.get(l["a"])
			var cb: Control = cards.get(l["b"])
			if ca == null or cb == null:
				continue
			var xa := ca.get_global_rect().get_center().x - o.x + (i % 2) * 14.0 - 7.0
			var xb := cb.get_global_rect().get_center().x - o.x + (i % 2) * 14.0 - 7.0
			var bottom := size.y
			var y := bottom - 26.0 - 30.0 * i
			var col: Color = l["color"]
			var pts := PackedVector2Array([Vector2(xa, bottom), Vector2(xa, y), Vector2(xb, y), Vector2(xb, bottom)])
			var lv := int(l.get("level", 1))
			# line style by level: 1 dashed, 2 solid, 3 double
			if lv <= 1:
				for k in 3:
					draw_dashed_line(pts[k], pts[k + 1], col, 2.0, 6.0, true, true)
			elif lv == 2:
				draw_polyline(pts, col, 3.0, true)
			else:
				var off := PackedVector2Array([Vector2(xa - 3.0, bottom), Vector2(xa - 3.0, y - 3.0), Vector2(xb + 3.0, y - 3.0), Vector2(xb + 3.0, bottom)])
				var inn := PackedVector2Array([Vector2(xa + 3.0, bottom), Vector2(xa + 3.0, y + 3.0), Vector2(xb - 3.0, y + 3.0), Vector2(xb - 3.0, bottom)])
				draw_polyline(off, col, 2.0, true)
				draw_polyline(inn, col, 2.0, true)
			for xx: float in [xa, xb]:
				draw_circle(Vector2(xx, bottom - 3.0), 5.0, col)
				draw_arc(Vector2(xx, bottom - 3.0), 5.0, 0.0, TAU, 16, UI.OUTLINE, 1.5, true)
			var text := String(l["text"]).to_upper()
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			var mid := Vector2((xa + xb) / 2.0, y)
			var pill := Rect2(mid.x - w / 2.0 - 10.0, y - 11.0, w + 20.0, 22.0)
			draw_style_box(UI.box(UI.PANEL, 11, 0, col, 2), pill)
			draw_string(font, Vector2(mid.x - w / 2.0, y + 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


## The house in detail: each hero's ability and refinements, oath and how it fits, passives, stats, bond;
## lines show who is bonded with whom; below, the combos the bonds give (ready, or what they still need).
func show_house(back: Callable) -> void:
	var v := _new_screen(32)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	head.add_child(Icon.make("hud_house", GLORY, 34))
	var title := UI.title(String(run.house["name"]), 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_label("before the first floor" if run.node_id == "" else "floor %d of %d" % [run.current_floor(), run.floor_count()], 16, MUTED))
	head.add_child(_glory_chip())
	var close := _primary("Back")
	close.pressed.connect(back)
	head.add_child(close)
	v.add_child(head)

	var sheets := VBoxContainer.new()
	sheets.add_theme_constant_override("separation", 0)   # the bond lines end right on top of the cards
	v.add_child(sheets)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var cards := {}
	for cls: String in run.heroes:
		var card := _hero_sheet(cls)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)
		cards[cls] = card
	sheets.add_child(row)

	# bonds above the cards
	var links: Array = []
	var seen := {}
	for cls: String in run.heroes:
		var b: Dictionary = run.heroes[cls]["bond"]
		if b.is_empty() or seen.has(run.pair_key(cls, b["with"])):
			continue
		seen[run.pair_key(cls, b["with"])] = true
		var lv := run.bond_level(cls)
		links.append({"a": cls, "b": b["with"], "color": BOND_COLORS[clampi(lv - 1, 0, 2)], "level": lv,
			"text": "%s · level %d" % [run.bond_name(b["type"]), lv]})
	if not links.is_empty():
		var lines := BondLines.new()
		lines.cards = cards
		lines.links = links
		lines.custom_minimum_size = Vector2(0, 26.0 + 30.0 * links.size())
		lines.resized.connect(lines.queue_redraw)
		sheets.add_child(lines)
		sheets.move_child(lines, 0)
		lines.queue_redraw.call_deferred()

	# combos
	var cbox := VBoxContainer.new()
	cbox.add_theme_constant_override("separation", 10)
	cbox.add_child(UI.title("Bond combos", 20))
	var combos := run.house_combos()
	if combos.is_empty():
		cbox.add_child(_label("No combos yet. Two heroes who win battles together form a bond; from bond level %d their abilities combine into a combo (Q and E in battle, at most two)." % int(run.units_data["bond_rules"].get("combo_level", 2)), 14, MUTED, true))
	else:
		cbox.add_child(_label("Ready combos are on Q and E in battle (the first two). The others show what they still need.", 14, MUTED, true))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		for c: Dictionary in combos:
			flow.add_child(_combo_card(c))
		cbox.add_child(flow)
	v.add_child(_panel(cbox))

	if not run.fallen.is_empty():
		# The Fallen: a memorial only (they do not fight any more); successors carry on the line
		var fb := VBoxContainer.new()
		fb.add_theme_constant_override("separation", 10)
		var fh := HBoxContainer.new()
		fh.add_theme_constant_override("separation", 8)
		fh.add_child(Icon.make("hud_fallen", BAD, 24))
		fh.add_child(UI.title("The Fallen", 20))
		fb.add_child(fh)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		for d: Dictionary in run.fallen:
			flow.add_child(_memorial(d))
		fb.add_child(flow)
		v.add_child(_panel(fb))


## One hero's sheet for the house page.
func _hero_sheet(cls: String) -> PanelContainer:
	var h: Dictionary = run.heroes[cls]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(Icon.make(cls, _hero_col(cls), 28))
	var nm := VBoxContainer.new()
	nm.add_theme_constant_override("separation", 0)
	nm.add_child(UI.label(String(h["name"]), 18, INK, false, "ui", 700))
	nm.add_child(UI.eyebrow(run.class_name_of(cls), MUTED, 10))
	if run.lineage(cls) != "":
		nm.add_child(UI.label(run.lineage(cls), 13, UI.TEXT_2, false, "lore_i"))
	head.add_child(nm)
	v.add_child(head)
	var hpb := _ui_helper._bar(OK if run.hp_of(cls) > 0.5 else (GLORY if run.hp_of(cls) > 0.25 else BAD), 8)
	hpb.max_value = 1.0
	hpb.value = run.hp_of(cls)
	hpb.tooltip_text = "Health %d %%" % roundi(run.hp_of(cls) * 100.0)
	v.add_child(hpb)

	# ability and its refinements
	var ab := run.ability_of(cls)
	var ad: Dictionary = run.units_data["abilities"].get(ab, {})
	var abox := _section("Ability", GLORY)
	abox.add_child(UI.label(run.ability_name(ab), 16, INK, true, "ui", 700))
	abox.add_child(_label(String(ad.get("desc", "")), 13, INK, true))
	abox.add_child(_label("%d uses per battle · recharge %d s" % [int(ad.get("uses", 0)), int(ad.get("cooldown", 0))], 12, MUTED, true))
	for r: Dictionary in run.refinements_of(cls):
		var rl := _label(("◆ " if r["owned"] else "◇ ") + String(r["name"]) + ": " + String(r["desc"]), 12, INK if r["owned"] else MUTED, true)
		rl.tooltip_text = "Owned refinement" if r["owned"] else "Not learned yet (refinements come as rewards; lost when the ability is swapped)"
		abox.add_child(rl)
	v.add_child(abox.get_parent())

	# oath
	var o := run.oath_of(cls)
	var obox := _section("Oath", BANNER)
	if o == "":
		obox.add_child(_label("No oath sworn.", 13, MUTED, true))
	else:
		obox.add_child(UI.label(run.passive_name(o), 16, BANNER, true, "ui", 700))
		obox.add_child(_label(run.passive_desc(o), 13, INK, true))
		var note := run.oath_note(cls)
		if not note.is_empty():
			obox.add_child(_label(("+ " if note[0] else "− ") + String(note[1]), 12, OK if note[0] else BAD, true))
		var ob: Dictionary = h.get("oath_boost", {})
		if not ob.is_empty():
			obox.add_child(_label("Tried: its bonuses ×%.1f, breaking it costs %d glory." % [float(ob.get("mult", 1.0)), int(ob.get("break_cost", 20))], 12, GLORY, true))
	v.add_child(obox.get_parent())

	# passives
	var pbox := _section("Passives", STEEL_C)
	var any := false
	for k: String in h["passives"]:
		if run.is_oath(k) or run._refine_of(k) != "":
			continue
		any = true
		var pl := _label("• %s: %s" % [run.passive_name(k), run.passive_desc(k)], 12, INK, true)
		pbox.add_child(pl)
	if not any:
		pbox.add_child(_label("None yet.", 13, MUTED))
	v.add_child(pbox.get_parent())

	# stats
	var sbox := _section("Stats", MUTED)
	for s: Dictionary in run.hero_stats(cls):
		var line := HBoxContainer.new()
		var sl := _label(String(s["name"]), 13, MUTED)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.tooltip_text = String(s["desc"])
		sl.mouse_filter = Control.MOUSE_FILTER_PASS
		line.add_child(sl)
		var val := float(s["value"])
		line.add_child(_label("%+d %%" % roundi(val * 100.0) if not is_zero_approx(val) else "—", 13, OK if val > 0.001 else (BAD if val < -0.001 else MUTED)))
		sbox.add_child(line)
		for ctext: String in s["cond"]:
			sbox.add_child(_label("   " + ctext, 11, MUTED, true))
	v.add_child(sbox.get_parent())

	# bond and his combos
	var bbox := _section("Bond", UI.BOND[1])
	var b: Dictionary = h.get("bond", {})
	if b.is_empty():
		bbox.add_child(_label("No bond yet.", 13, MUTED, true))
	else:
		var lv := run.bond_level(cls)
		var nxt := run.next_bond_at(cls)
		bbox.add_child(_label("%s with %s" % [run.bond_name(b["type"]), run.hero_name(b["with"])], 15, BOND_COLORS[clampi(lv - 1, 0, 2)], true))
		bbox.add_child(_label("Level %d · shared victories %d%s" % [lv, run.wins_of(cls, b["with"]), (" (level %d at %d)" % [lv + 1, nxt]) if nxt > 0 else ""], 12, MUTED, true))
		bbox.add_child(_label(run.bond_desc(b["type"]), 12, INK, true))
		for c: Dictionary in run.house_combos():
			if c["a"] == cls or c["b"] == cls:
				var other: String = c["b"] if c["a"] == cls else c["a"]
				bbox.add_child(_label(("◆ " if c["ready"] else "◇ ") + "Combo %s with %s" % [c["name"], run.hero_name(other)], 12, GLORY if c["ready"] else MUTED, true))
	v.add_child(bbox.get_parent())
	return _panel(v)


## A titled block inside a hero sheet; returns the inner VBox (its parent is the block to add).
func _section(title: String, col: Color) -> VBoxContainer:
	var p := PanelContainer.new()
	var st := UI.inset_box(10, Color(col, 0.5))
	st.border_width_left = 3
	st.border_color = col
	p.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.add_child(UI.eyebrow(title, col, 10))
	p.add_child(v)
	return v


## A combo card for the house page: name, who with what, what it does, ready or what it still needs.
func _combo_card(c: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	var st := UI.box(UI.RAISED if c["ready"] else UI.INSET, UI.RADIUS, 12, UI.GILT if c["ready"] else UI.BORDER, 2, 2 if c["ready"] else 0)
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = Vector2(340, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 6)
	ch.add_child(Icon.make("status_bond", UI.BOND[1] if c["ready"] else MUTED, 20))
	ch.add_child(UI.label(String(c["name"]), 17, INK if c["ready"] else UI.TEXT_2, true, "ui", 700))
	v.add_child(ch)
	v.add_child(_label("%s (%s) + %s (%s)" % [run.hero_name(c["a"]), run.ability_name(c["a_ability"]), run.hero_name(c["b"]), run.ability_name(c["b_ability"])], 13, MUTED, true))
	v.add_child(_label(String(c["desc"]), 13, INK, true))
	if c["ready"]:
		v.add_child(_chip_label("READY · Q / E IN BATTLE", OK))
	else:
		v.add_child(_label("Needs: " + "; ".join(c["needs"]), 12, BAD, true))
	p.add_child(v)
	return p


## Memorial plate of a fallen hero: dark iron plate, name, where he fell, what he carried, who took his place.
func _memorial(d: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	var st := UI.box(UI.IRON, UI.RADIUS, 12, UI.GILT, 2, 3)
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = Vector2(300, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(Icon.make(String(d["cls"]), UI.GILT, 22))
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", -2)
	nv.add_child(UI.title(String(d["name"]), 16, UI.ON_DARK))
	nv.add_child(UI.eyebrow(run.class_name_of(d["cls"]), Color(UI.ON_DARK, 0.65), 10))
	h.add_child(nv)
	v.add_child(h)
	v.add_child(UI.label("Fell at %s · brought %d glory" % [d["stage"], roundi(float(d.get("glory", 0.0)))], 13, Color(UI.ON_DARK, 0.85), true, "lore_i"))
	var names: Array = []
	for k: String in d["passives"]:
		names.append(run.passive_name(k))
	if not names.is_empty():
		v.add_child(UI.label("Carried: " + ", ".join(names), 12, Color(UI.ON_DARK, 0.75), true))
	if String(d.get("successor", "")) != "":
		v.add_child(UI.label("Succeeded by " + String(d["successor"]), 12, UI.GILT, true, "ui", 600))
	p.add_child(v)
	return p
