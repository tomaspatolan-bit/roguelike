extends Node
## Hlavní scéna: start, mapa aktu, bitva → dědictví a odměna, událost, tábor, kronika rodu.
## Logika běhu je v run_state.gd; tady jen obrazovky a přepínání mezi nimi a bitvou.
## Vzhled obrazovek je zástupný, finální UI navrhne Tom.

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
var _chron_mark := 0       # odkud v kronice ukázat, co přinesla událost
var _ui_helper: BattleUI   # půjčené styly (téma, tlačítka) z UI bitvy, nepřidává se do stromu


func _ready() -> void:
	_ui_helper = BattleUI.new()
	layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	show_start()


func _exit_tree() -> void:
	if _ui_helper != null:
		_ui_helper.free()


# ================================================================ přepínání

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
	v.add_child(_label("Rytíři", 44))
	v.add_child(_label("Prototyp · fáze 2", 14, MUTED))
	v.add_child(_label("Běh: Rod Vlka táhne krajem %s. Na mapě aktu si na každém patře vybereš, kudy půjdeš: bitva, elita (těžší, lepší odměna), událost nebo tábor (odpočinek). Nahoře čeká Hejtman Kuno. Zranění se nesou mezi bitvami, padlí zůstanou padlí a nastoupí za ně nástupci. Kdo z nepřátel uteče, vrátí se v boji s Hejtmanem." % String(Run.Sim._read_json("res://data/akt_1.json").get("name", "")), 16, INK, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var b := _primary("Nový běh")
	b.pressed.connect(start_run)
	row.add_child(b)
	var f := _button("Volná bitva")
	f.tooltip_text = "Jedna bitva s výběrem mapy a pasivek na zkoušku (jako dřív)."
	f.pressed.connect(_free_battle)
	row.add_child(f)
	if BattleScript.tutorial_done():
		var t := _button("Výcvik znovu")
		t.tooltip_text = "V příští bitvě se znovu ukáže výcvik ovládání."
		t.pressed.connect(func() -> void:
			BattleScript.set_tutorial_done(false)
			t.disabled = true
			t.text = "Výcvik bude v příští bitvě")
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


## Volba uzlu na mapě: bitva rovnou do bitvy, jinak obrazovka uzlu.
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


# ================================================================ mapa aktu

func show_map() -> void:
	var v := _new_screen(60)
	var head := HBoxContainer.new()
	head.add_child(_label("%s · %s" % [run.act["name"], "začátek" if run.node_id == "" else "patro %d ze %d" % [run.current_floor(), run.floor_count()]], 26))
	v.add_child(head)
	v.add_child(_label("Vyber, kudy rod půjde dál. Najetím na uzel uvidíš, co tě tam čeká.", 14, MUTED))
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
				extra = "\nVrátí se uprchlíci: %d" % run.fled.size()
			var reward := "Odměna: 2 z %d nabídek." % int(run.act.get("elite_offers", 4)) if t == "elita" else "Odměna: 1 z %d nabídek." % int(run.act.get("offers", 3))
			if t == "boss":
				reward = "Boss aktu."
			var md: Dictionary = run.units_data.get("battle_modes", {}).get(String(sc.get("mode", "stret")), {})
			return "%s: %s\n%s: %s\n%s\nÚkol: %s\n%s%s" % [run.NODE_NAMES[t], sc.get("name", ""), md.get("name", ""), md.get("desc", ""), sc.get("subtitle", ""), sc.get("optional_task", {}).get("text", ""), reward, extra]
		"udalost":
			return "Událost: %s\nRozhodnutí s cenou." % run.events_data[n["event"]]["name"]
		"tabor":
			return "Tábor\nOdpočinek: zranění se zahojí."
	return ""


# ================================================================ po bitvě: dědictví a odměna

func show_after_battle() -> void:
	var v := _new_screen()
	var last := run.node_label()
	v.add_child(_label("Po bitvě: %s" % last, 30))
	v.add_child(_label("%s · patro %d ze %d" % [run.act["name"], run.current_floor(), run.floor_count()], 14, MUTED))

	# co se v bitvě stalo
	var news := VBoxContainer.new()
	for e: Dictionary in run.chronicle:
		if e["stage"] == last:
			news.add_child(_label("• " + String(e["text"]), 15, INK, true))
	v.add_child(_panel(news))

	if run.has_legacy():
		_legacy_block(v)
	elif not run.offers().is_empty():
		_reward_block(v)
	else:
		var go := _primary("Na mapu")
		go.pressed.connect(show_map)
		v.add_child(go)
	v.add_child(_roster())


# ================================================================ událost

func show_event() -> void:
	var v := _new_screen()
	var ev: Dictionary = run.event()
	v.add_child(_label("Událost", 14, MUTED))
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
	var go := _primary("Na mapu")
	go.pressed.connect(show_map)
	v.add_child(go)
	v.add_child(_roster())


# ================================================================ tábor

func show_campfire() -> void:
	var v := _new_screen()
	v.add_child(_label("Tábor", 30, OK))
	v.add_child(_label("Rod rozdělá oheň. Odpočinek zahojí zranění všech hrdinů.", 16, INK, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var rest := _primary("Odpočinout si")
	rest.disabled = run.camp_done
	rest.pressed.connect(func() -> void:
		run.camp_rest()
		show_campfire())
	row.add_child(rest)
	var go := _button("Na mapu")
	go.pressed.connect(show_map)
	row.add_child(go)
	v.add_child(row)
	v.add_child(_roster())


func _legacy_block(v: VBoxContainer) -> void:
	var l := run.legacy_current()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_label("Dědictví přísahy", 22, GLORY))
	box.add_child(_label("%s padl a nechal po sobě přísahu %s: %s Kdo ji převezme? Hrdina může mít jen jednu přísahu." % [l["from"], run.passive_name(l["oath"]), run.passive_desc(l["oath"])], 15, INK, true))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	for cls: String in run.legacy_candidates():
		var b := _button("%s (%s)" % [run.hero_name(cls), run.class_name_of(cls)])
		b.pressed.connect(func() -> void:
			run.resolve_legacy(cls)
			show_after_battle())
		row.add_child(b)
	var no := _button("Nechat přísahu zemřít")
	no.pressed.connect(func() -> void:
		run.resolve_legacy("")
		show_after_battle())
	row.add_child(no)
	box.add_child(row)
	v.add_child(_panel(box))


func _reward_block(v: VBoxContainer) -> void:
	var offers := run.offers()
	v.add_child(_label("Odměna: vyber jednu" if run.picks_left() <= 1 else "Odměna elity: vyber %d" % run.picks_left(), 22, GLORY))
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
		card.add_child(_label(("Přísaha: " if run.is_oath(key) else "") + run.passive_name(key), 19, BANNER if run.is_oath(key) else GLORY, true))
		card.add_child(_label(run.passive_desc(key), 14, MUTED, true))
		var pick := _primary("Vybrat")
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
	box.add_child(_label("Rod Vlka · sláva %d" % int(run.glory), 18, GLORY))
	for cls: String in run.heroes:
		var h: Dictionary = run.heroes[cls]
		var names: Array = []
		for k: String in h["passives"]:
			names.append(("Přísaha: " if run.is_oath(k) else "") + run.passive_name(k))
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
		hpb.tooltip_text = "Zdraví %d %%" % roundi(run.hp_of(cls) * 100.0)
		row.add_child(hpb)
		var pl := _label(", ".join(names) if not names.is_empty() else "bez pasivek", 14, MUTED, true)
		pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(pl)
		box.add_child(row)
	if not run.fallen.is_empty():
		var f: Array = []
		for d: Dictionary in run.fallen:
			f.append("%s (%s)" % [d["name"], d["stage"]])
		box.add_child(_label("Padlí: " + ", ".join(f), 14, BAD, true))
	if not run.fled.is_empty():
		box.add_child(_label("Uprchlíků, kteří se mohou vrátit: %d" % run.fled.size(), 14, MUTED))
	return _panel(box)


# ================================================================ kronika

func show_chronicle() -> void:
	var v := _new_screen()
	var win := run.over == "win"
	v.add_child(_label("Kronika rodu", 16, MUTED))
	v.add_child(_label("Rod Vlka zvítězil" if win else "Rod Vlka padl", 36, OK if win else BAD))
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
	var again := _primary("Nový běh")
	again.pressed.connect(start_run)
	row.add_child(again)
	var menu := _button("Hlavní menu")
	menu.pressed.connect(show_start)
	row.add_child(menu)
	v.add_child(row)


# ================================================================ pomocníci

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
