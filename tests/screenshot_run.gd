extends SceneTree
## Projde běh přes obrazovky: start → mapa → uzly (bitva, elita, událost, tábor) → … → boss → kronika.
## Cesta: na každém patře první dostupný uzel, ale přednostně typ, který ještě nebyl (ať se ukážou všechny obrazovky).
## Bitvy se hrají automaticky (schopnosti podle rady), odměna a volba v události se berou první.
## Spuštění (s oknem, kvůli snímkům):
##   godot --path . --script res://tests/screenshot_run.gd -- <složka pro snímky>

var out_dir := ""
var scene: Node
var frame := 0
var wait := 0
var shots := {}
var battles := 0
var seen := {}
var step := 0
var map_pending := false
const Run := preload("res://scripts/run/run_state.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
		DirAccess.make_dir_recursive_absolute(out_dir)
	scene = load("res://scenes/run/run.tscn").instantiate()
	root.add_child(scene)


func _shot(file_name: String) -> void:
	if shots.has(file_name):
		return
	shots[file_name] = true
	print("Snímek: " + file_name)
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	root.get_texture().get_image().save_png(out_dir.path_join("beh_" + file_name))


func _process(_delta: float) -> bool:
	frame += 1
	if frame > 60 * 60 * 12:
		print("CHYBA: běh nedoběhl včas")
		return true
	if wait > 0:
		wait -= 1
		return false
	var run: Variant = scene.get("run")
	var battle: Variant = scene.get("battle")
	# napřed obrazovka události (na náhodné cestě nemusí být): podvržený běh s uzlem události
	if frame == 10:
		_shot("00_start.png")
		var r := Run.new(21)
		for n: Dictionary in r.map["nodes"].values():
			if n["type"] == "udalost":
				r.node_id = n["id"]
				break
		scene.set("run", r)
		scene.call("show_event")
		return false
	if frame == 16:
		_shot("00_udalost.png")
		var r2: Variant = scene.get("run")
		scene.set("_chron_mark", (r2.get("chronicle") as Array).size())
		r2.call("event_choose", 0)
		scene.call("show_event_result")
		return false
	if frame == 22:
		_shot("00_udalost_vysledek.png")
		scene.call("start_run")
		wait = 20
		return false
	if frame < 22:
		return false
	if run == null:
		return false
	if battle != null and is_instance_valid(battle):
		_drive_battle(battle)
		return false
	if String(run.get("over")) != "":
		_shot("99_kronika.png")
		print("Běh skončil: %s, bitev %d, uzlů %d, záznamů v kronice %d" % [run.get("over"), battles, (run.get("path") as Array).size(), (run.get("chronicle") as Array).size()])
		print("Typy uzlů na cestě: %s" % [seen.keys()])
		print("VÝSLEDEK: OK")
		return true
	step += 1
	var t: String = run.call("node_type")
	# po bitvě: dědictví a odměna
	if run.call("is_battle_node") and not bool(run.call("node_finished")):
		if bool(run.call("has_legacy")):
			_shot("%02d_dedictvi.png" % step)
			var c: Array = run.call("legacy_candidates")
			run.call("resolve_legacy", c[0] if not c.is_empty() else "")
			scene.call("show_after_battle")
		else:
			_shot("%02d_odmena_%s.png" % [step, t])
			run.call("pick_offer", 0)
			scene.call("show_after_battle")
		wait = 10
		return false
	if t == "udalost" and not bool(run.get("event_done")):
		_shot("%02d_udalost.png" % step)
		var opts: Array = run.call("event")["options"]
		for i in opts.size():
			if run.call("event_option_problem", i) == "":
				run.call("event_choose", i)
				break
		scene.call("show_event_result")
		wait = 10
		return false
	if t == "udalost":
		_shot("%02d_udalost_vysledek.png" % step)
	if t == "tabor" and not bool(run.get("camp_done")):
		_shot("%02d_tabor.png" % step)
		run.call("camp_rest")
		scene.call("show_campfire")
		wait = 10
		return false
	# mapa a volba dalšího uzlu (snímek až po vykreslení)
	if not map_pending:
		scene.call("show_map")
		map_pending = true
		wait = 6
		return false
	map_pending = false
	_shot("%02d_mapa.png" % step)
	var av: Array = run.call("available")
	var pick: String = av[0]
	for id: String in av:
		if not seen.has(run.call("node_type", id)):
			pick = id
			break
	seen[run.call("node_type", pick)] = true
	scene.call("go_to", pick)
	wait = 30
	return false


func _drive_battle(battle: Node) -> void:
	var sim: Variant = battle.get("sim")
	var phase: int = battle.get("phase")
	if phase == 0:
		_shot("b%d_rozestaveni.png" % (battles + 1))
		(battle.get("setup") as Dictionary)["orders"] = (battle.get("sim") as Object).call("suggest_orders")
		battle.call("_start_battle")
		battle.set("speed", 4.0)
		return
	if phase == 2 and sim != null and float(sim.get("t")) == 0.0:
		_shot("b%d_start.png" % (battles + 1))
		battle.call("_toggle_pause")   # bitva bez rozestavení začíná v pauze
		battle.set("speed", 4.0)
		return
	if sim == null:
		return
	if String(sim.get("over")) == "":
		if bool(battle.get("paused")):
			battle.call("_resume_pause")
		sim.call("auto_command")
		for u: Variant in sim.call("living", "k"):
			var h: Array = sim.call("ability_hint", u.get("id"))
			if h[0]:
				sim.call("use_ability", u.get("id"), h[1])
		return
	var ui: Variant = battle.get("ui")
	if ui != null and bool(ui.get("result_box").visible):
		_shot("b%d_vysledek.png" % (battles + 1))
		battles += 1
		print("Bitva %d: %s za %.0f s" % [battles, sim.get("over"), sim.get("t")])
		ui.emit_signal("run_continue_pressed")
		wait = 20
