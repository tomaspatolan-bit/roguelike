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
			_chron_mark = run.chronicle.size()
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
	else:
		_pending_or_map(v, show_after_battle)
	v.add_child(_roster(show_after_battle))


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
	v.add_child(_roster(show_event))


func show_event_result() -> void:
	var v := _new_screen()
	var ev: Dictionary = run.event()
	v.add_child(_label(String(ev["name"]), 30, GLORY))
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
	v.add_child(_label("Camp", 30, OK))
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
		v.add_child(_label("%s: %s" % [c["name"], c.get("desc", "")], 16, INK, true))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		if String(c.get("needs", "")) == "pair":
			var ks: Array = run.heroes.keys()
			for i in ks.size():
				for j in range(i + 1, ks.size()):
					var a: String = ks[i]
					var b: String = ks[j]
					var btn := _button("%s + %s (%d)" % [run.hero_name(a), run.hero_name(b), run.wins_of(a, b)])
					btn.tooltip_text = "Shared victories: %d" % run.wins_of(a, b)
					btn.pressed.connect(func() -> void:
						_chron_mark = run.chronicle.size()
						run.camp_choose(pick_for, "%s|%s" % [a, b])
						show_campfire())
					flow.add_child(btn)
		else:
			for cls: String in run.heroes:
				var btn := _button("%s (%s)" % [run.hero_name(cls), run.class_name_of(cls)])
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
	v.add_child(_label("The house lights a fire. Choose one thing to do tonight.", 16, INK, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for o: Dictionary in run.camp_options():
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 6)
		var title := String(o["name"]) + (" (%d glory)" % int(o["cost"]) if int(o["cost"]) > 0 else "")
		card.add_child(_label(title, 19, GLORY, true))
		card.add_child(_label(String(o["desc"]), 14, MUTED, true))
		var id: String = o["id"]
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
func _bond_block(v: VBoxContainer, back: Callable) -> void:
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
	v.add_child(_label(title % run.picks_left() if title.contains("%d") else title, 22, GLORY))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for i in offers.size():
		var o: Dictionary = offers[i]
		var cls: String = o["hero"]
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 6)
		var head := HBoxContainer.new()
		head.add_child(Icon.make(cls, INK, 22))
		head.add_child(_label("%s (%s)" % [run.hero_name(cls), run.class_name_of(cls)], 17))
		card.add_child(head)
		match String(o.get("kind", "passive")):
			"max_hp":
				card.add_child(_label("Toughness +%d %%" % roundi(float(o.get("value", 0.1)) * 100.0), 19, GLORY, true))
				card.add_child(_label("More health for good.", 14, MUTED, true))
			"release_oath":
				card.add_child(_label("Lay down: " + run.passive_name(run.oath_of(cls)), 19, BANNER, true))
				card.add_child(_label("Released from the oath without shame or cost.", 14, MUTED, true))
			"ability":
				var ak := String(o["ability"])
				card.add_child(_label("New ability: " + run.ability_name(ak), 19, GLORY, true))
				card.add_child(_label(String(run.units_data["abilities"][ak].get("desc", "")), 14, MUTED, true))
				for note: Array in run.offer_notes(o):
					card.add_child(_label(("+ " if note[0] else "− ") + String(note[1]), 13, OK if note[0] else BAD, true))
			_:
				var key: String = o["passive"]
				card.add_child(_label(("Oath: " if run.is_oath(key) else "") + run.passive_name(key), 19, BANNER if run.is_oath(key) else GLORY, true))
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
	var tl := _label("%s · glory %d" % [run.house["name"], int(run.glory)], 18, GLORY)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tl)
	if back.is_valid():
		var hb := _button("House: abilities, oaths, bonds, combos")
		hb.pressed.connect(func() -> void: show_house(back))
		top.add_child(hb)
	box.add_child(top)
	for cls: String in run.heroes:
		var h: Dictionary = run.heroes[cls]
		var names: Array = [run.ability_name(run.ability_of(cls))]
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


# ================================================================ house page (roster detail)

const BOND_COLORS := [Color("#9aa3ad"), Color("#e2b84a"), Color("#f0d27a")]   # bond level 1, 2, 3 (2 = combos)


## Lines above the hero cards: who is bonded with whom (a bracket from card to card, label in the middle).
class BondLines:
	extends Control
	var cards: Dictionary = {}   # class -> card Control
	var links: Array = []        # [{"a", "b", "text", "color"}]

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
			draw_polyline(PackedVector2Array([Vector2(xa, bottom), Vector2(xa, y), Vector2(xb, y), Vector2(xb, bottom)]), col, 3.0, true)
			draw_circle(Vector2(xa, bottom - 3.0), 5.0, col)
			draw_circle(Vector2(xb, bottom - 3.0), 5.0, col)
			var text := String(l["text"])
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			var mid := Vector2((xa + xb) / 2.0, y)
			draw_rect(Rect2(mid.x - w / 2.0 - 8.0, y - 11.0, w + 16.0, 22.0), Color("#14171b"))
			draw_string(font, Vector2(mid.x - w / 2.0, y + 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)


## The house in detail: each hero's ability and refinements, oath and how it fits, passives, stats, bond;
## lines show who is bonded with whom; below, the combos the bonds give (ready, or what they still need).
func show_house(back: Callable) -> void:
	var v := _new_screen(32)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	var title := _label(String(run.house["name"]), 30, GLORY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_label("Glory %d · %s" % [int(run.glory), "before the first floor" if run.node_id == "" else "floor %d of %d" % [run.current_floor(), run.floor_count()]], 16, MUTED))
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
		links.append({"a": cls, "b": b["with"], "color": BOND_COLORS[clampi(lv - 1, 0, 2)],
			"text": "%s · level %d" % [run.bond_name(b["type"]), lv]})
	if not links.is_empty():
		var lines := BondLines.new()
		lines.cards = cards
		lines.links = links
		lines.custom_minimum_size = Vector2(0, 20.0 + 30.0 * links.size())
		lines.resized.connect(lines.queue_redraw)
		sheets.add_child(lines)
		sheets.move_child(lines, 0)
		lines.queue_redraw.call_deferred()

	# combos
	var cbox := VBoxContainer.new()
	cbox.add_theme_constant_override("separation", 10)
	cbox.add_child(_label("Bond combos", 22, GLORY))
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
		var fb := VBoxContainer.new()
		fb.add_child(_label("The fallen", 18, BAD))
		for d: Dictionary in run.fallen:
			var names: Array = []
			for k: String in d["passives"]:
				names.append(run.passive_name(k))
			fb.add_child(_label("%s (%s), fell at %s. %s" % [d["name"], run.class_name_of(d["cls"]), d["stage"], ("Carried: " + ", ".join(names) + ".") if not names.is_empty() else ""], 14, MUTED, true))
		v.add_child(_panel(fb))


## One hero's sheet for the house page.
func _hero_sheet(cls: String) -> PanelContainer:
	var h: Dictionary = run.heroes[cls]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(Icon.make(cls, INK, 26))
	var nm := VBoxContainer.new()
	nm.add_theme_constant_override("separation", 0)
	nm.add_child(_label(String(h["name"]), 18))
	nm.add_child(_label(run.class_name_of(cls), 13, MUTED))
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
	abox.add_child(_label(run.ability_name(ab), 17, GLORY, true))
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
		obox.add_child(_label(run.passive_name(o), 16, BANNER, true))
		obox.add_child(_label(run.passive_desc(o), 13, INK, true))
		var note := run.oath_note(cls)
		if not note.is_empty():
			obox.add_child(_label(("+ " if note[0] else "− ") + String(note[1]), 12, OK if note[0] else BAD, true))
		var ob: Dictionary = h.get("oath_boost", {})
		if not ob.is_empty():
			obox.add_child(_label("Tried: its bonuses ×%.1f, breaking it costs %d glory." % [float(ob.get("mult", 1.0)), int(ob.get("break_cost", 20))], 12, GLORY, true))
	v.add_child(obox.get_parent())

	# passives
	var pbox := _section("Passives", INK)
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
	var sbox := _section("Stats", INK)
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
	var bbox := _section("Bond", GLORY)
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
	p.add_theme_stylebox_override("panel", _ui_helper._box(Color("#14171b"), 8, 10, Color(col, 0.35), 1))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.add_child(_label(title.to_upper(), 11, Color(col, 0.85)))
	p.add_child(v)
	return v


## A combo card for the house page: name, who with what, what it does, ready or what it still needs.
func _combo_card(c: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	var col := GLORY if c["ready"] else LINE
	p.add_theme_stylebox_override("panel", _ui_helper._box(Color("#14171b"), 8, 12, col, 2 if c["ready"] else 1))
	p.custom_minimum_size = Vector2(340, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(_label(String(c["name"]), 17, GLORY if c["ready"] else INK, true))
	v.add_child(_label("%s (%s) + %s (%s)" % [run.hero_name(c["a"]), run.ability_name(c["a_ability"]), run.hero_name(c["b"]), run.ability_name(c["b_ability"])], 13, MUTED, true))
	v.add_child(_label(String(c["desc"]), 13, INK, true))
	if c["ready"]:
		v.add_child(_label("Ready: Q / E in battle", 13, OK))
	else:
		v.add_child(_label("Needs: " + "; ".join(c["needs"]), 12, BAD, true))
	p.add_child(v)
	return p
