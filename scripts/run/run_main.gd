extends Node
## Hlavní scéna: start, zkušební běh (bitva → tábor s odměnou → další bitva) a kronika rodu.
## Logika běhu je v run_state.gd; tady jen obrazovky a přepínání mezi nimi a bitvou.
## Vzhled obrazovek je zástupný, finální UI navrhne Tom.

const Run := preload("res://scripts/run/run_state.gd")
const BattleScene := preload("res://scenes/battle/battle.tscn")
const BattleUI := preload("res://scripts/battle/battle_ui.gd")
const Icon := preload("res://scripts/battle/ui_icon.gd")

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

func _new_screen() -> VBoxContainer:
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
		center.add_theme_constant_override("margin_" + side, 220)
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
	v.add_child(_label("Prototyp · krok 1.7", 14, MUTED))
	v.add_child(_label("Zkušební běh: tři bitvy za sebou. Po každé vítězné bitvě si vybereš jednu ze tří odměn pro konkrétního hrdinu. Padlí zůstanou padlí, na jejich místo nastoupí nástupce a jejich přísahu může někdo převzít. Kdo z nepřátel uteče, vrátí se v závěrečné bitvě.", 16, INK, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var b := _primary("Zkušební běh")
	b.pressed.connect(start_run)
	row.add_child(b)
	var f := _button("Volná bitva")
	f.tooltip_text = "Jedna bitva s výběrem mapy a pasivek na zkoušku (jako dřív)."
	f.pressed.connect(_free_battle)
	row.add_child(f)
	v.add_child(row)


func start_run() -> void:
	run = Run.new()
	_start_battle()


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
		show_camp()


# ================================================================ tábor mezi bitvami

func show_camp() -> void:
	var v := _new_screen()
	var last := run.stage_name(run.stage - 1)
	v.add_child(_label("Tábor po bitvě: %s" % last, 30))
	v.add_child(_label("Bitva %d ze %d za vámi · další: %s" % [run.stage, run.stage_count(), run.stage_name()], 14, MUTED))

	# co se v bitvě stalo
	var news := VBoxContainer.new()
	for e: Dictionary in run.chronicle:
		if e["stage"] == last:
			news.add_child(_label("• " + String(e["text"]), 15, INK, true))
	v.add_child(_panel(news))

	if run.has_legacy():
		_legacy_block(v)
	else:
		_reward_block(v)
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
			show_camp())
		row.add_child(b)
	var no := _button("Nechat přísahu zemřít")
	no.pressed.connect(func() -> void:
		run.resolve_legacy("")
		show_camp())
	row.add_child(no)
	box.add_child(row)
	v.add_child(_panel(box))


func _reward_block(v: VBoxContainer) -> void:
	var offers := run.offers()
	if offers.is_empty():
		var go := _primary("Do bitvy: %s" % run.stage_name())
		go.pressed.connect(_start_battle)
		v.add_child(go)
		return
	v.add_child(_label("Odměna: vyber jednu", 22, GLORY))
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
			show_camp())
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
		nl.custom_minimum_size = Vector2(240, 0)
		row.add_child(nl)
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
