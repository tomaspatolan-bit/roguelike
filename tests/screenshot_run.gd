extends SceneTree
## Projde zkušební běh přes obrazovky: start → bitva → tábor (dědictví, odměna) → … → kronika.
## Bitvy se hrají automaticky (schopnosti podle rady), odměna se bere první.
## Spuštění (s oknem, kvůli snímkům):
##   godot --path . --script res://tests/screenshot_run.gd -- <složka pro snímky>

var out_dir := ""
var scene: Node
var frame := 0
var wait := 0
var shots := {}
var battles := 0


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
	if frame > 60 * 60 * 6:
		print("CHYBA: běh nedoběhl včas")
		return true
	if wait > 0:
		wait -= 1
		return false
	var run: Variant = scene.get("run")
	var battle: Variant = scene.get("battle")
	if frame == 20:
		_shot("01_start.png")
		scene.call("start_run")
		wait = 30
		return false
	if run == null:
		return false
	if battle != null and is_instance_valid(battle):
		_drive_battle(battle)
		return false
	if String(run.get("over")) != "":
		_shot("09_kronika.png")
		print("Běh skončil: %s, bitev %d, záznamů v kronice %d" % [run.get("over"), battles, (run.get("chronicle") as Array).size()])
		print("VÝSLEDEK: OK")
		return true
	# tábor
	var n: int = run.get("stage")
	if bool(run.call("has_legacy")):
		_shot("%02d_tabor_dedictvi.png" % (n * 2))
		var c: Array = run.call("legacy_candidates")
		run.call("resolve_legacy", c[0] if not c.is_empty() else "")
		scene.call("show_camp")
		wait = 10
		return false
	var offers: Array = run.call("offers")
	if not offers.is_empty():
		_shot("%02d_tabor_odmena.png" % (n * 2 + 1))
		run.call("pick_offer", 0)
		scene.call("show_camp")
		wait = 10
		return false
	_shot("%02d_tabor_pred_bitvou.png" % (n * 2 + 1))
	scene.call("_start_battle")
	wait = 30
	return false


func _drive_battle(battle: Node) -> void:
	var sim: Variant = battle.get("sim")
	var phase: int = battle.get("phase")
	if phase == 0:
		_shot("b%d_rozestaveni.png" % (battles + 1))
		battle.call("_start_battle")
		battle.set("speed", 4.0)
		return
	if sim == null:
		return
	if String(sim.get("over")) == "":
		if bool(battle.get("paused")):
			battle.call("_resume_pause")
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
