extends SceneTree
## Spustí scénu bitvy, odehraje kus bitvy s automatickými pokřiky a uloží snímky obrazovky.
## Slouží ke kontrole, že se scéna načte bez chyb a vypadá rozumně.
## Spuštění (s oknem, kvůli vykreslení):
##   godot --path . --script res://tests/screenshot_battle.gd -- <složka pro snímky>
## Bez okna (jen kontrola chyb, bez snímků):
##   godot --headless --path . --script res://tests/screenshot_battle.gd

var out_dir := ""
var scene: Node
var frame := 0
var started_at := -1
var broken_shot := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
		DirAccess.make_dir_recursive_absolute(out_dir)
	scene = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(scene)


func _shot(file_name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(file_name))
	print("Snímek: " + file_name)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 40:
		_shot("01_rozestaveni.png")
		_test_drag_swap()
	if frame == 45:
		_shot("02_vyber.png")
		scene.call("_start_battle")
		scene.set("speed", 2.0)
		started_at = frame
	if started_at > 0:
		var sim: Variant = scene.get("sim")
		if sim != null and scene.get("phase") == 1:
			if sim.call("can_shout", "zarod"):
				scene.call("_shout", "zarod")
			if bool(scene.get("paused")):
				scene.call("_resume_pause")
		if frame == started_at + 300:
			_shot("03_bitva.png")
		if frame == started_at + 900:
			_shot("04_bitva_pozdeji.png")
		if sim != null and bool(sim.get("foes_broken")) and not broken_shot:
			broken_shot = true
			_shot("04b_zlomeni.png")
			scene.call("_charge")
			print("Morálka zlomena v %.0f s, povel Do boje!: %s" % [sim.get("t"), "OK" if bool(sim.get("charging")) else "CHYBA"])
		var over := sim != null and String(sim.get("over")) != ""
		if over and frame > started_at + 60:
			print("Bitva skončila: %s za %.0f s" % [sim.get("over"), sim.get("t")])
			_shot("05_konec.png")
			return true
		if sim != null and float(sim.get("t")) > 300.0:
			var alive_k: int = sim.call("living", "k").size()
			var alive_e: int = sim.call("living", "e").size()
			print("Bitva neskončila do 300 s (rytíři %d, nepřátelé %d)" % [alive_k, alive_e])
			for u: Variant in sim.get("units"):
				if u.call("alive"):
					print("  %s %s pos=%s posture=%s moving=%s" % [u.get("id"), u.get("key"), u.get("pos"), u.get("posture"), u.get("moving")])
			_shot("05_konec.png")
			return true
	return false


## Přetáhne tanka myší na kněze: musí si prohodit místa.
func _test_drag_swap() -> void:
	var sim: Variant = scene.get("sim")
	var cam: Camera3D = scene.get("cam")
	var views: Dictionary = scene.get("views")
	var tank: Variant = sim.call("by_id", "tank")
	var knez: Variant = sim.call("by_id", "knez")
	var tank_before: Vector2 = tank.get("pos")
	var knez_before: Vector2 = knez.get("pos")
	var a := cam.unproject_position((views["tank"] as Node3D).global_position + Vector3(0, 1.0, 0))
	var b := cam.unproject_position((views["knez"] as Node3D).global_position + Vector3(0, 1.0, 0))
	scene.call("_pointer_down", a)
	scene.call("_pointer_move", a + Vector2(12, 0))
	scene.call("_pointer_move", b)
	scene.call("_pointer_up", b)
	var ok_t := (tank.get("pos") as Vector2).distance_to(knez_before) < 0.6
	var ok_k := (knez.get("pos") as Vector2).distance_to(tank_before) < 0.01
	print("Drag & drop prohození: %s" % ("OK" if ok_t and ok_k else "CHYBA (tank %s, kněz %s)" % [tank.get("pos"), knez.get("pos")]))
	# prohodit zpátky, aby bitva běžela ve výchozím rozestavení
	a = cam.unproject_position((views["tank"] as Node3D).global_position + Vector3(0, 1.0, 0))
	b = cam.unproject_position((views["knez"] as Node3D).global_position + Vector3(0, 1.0, 0))
	scene.call("_pointer_down", a)
	scene.call("_pointer_move", a + Vector2(12, 0))
	scene.call("_pointer_move", b)
	scene.call("_pointer_up", b)
	var back_ok := (tank.get("pos") as Vector2).distance_to(tank_before) < 0.6 and (knez.get("pos") as Vector2).distance_to(knez_before) < 0.6
	print("Drag & drop zpět: %s" % ("OK" if back_ok else "CHYBA"))
	var posture_label: String = sim.call("posture_name", "tank", "drzet")
	print("Postoj tanka s přísahou: %s" % posture_label)
