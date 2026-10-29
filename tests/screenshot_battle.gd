extends SceneTree
## Spustí scénu bitvy, odehraje kus bitvy s automatickými pokřiky a uloží snímky obrazovky.
## Slouží ke kontrole, že se scéna načte bez chyb a vypadá rozumně.
## Spuštění (s oknem, kvůli vykreslení):
##   godot --path . --script res://tests/screenshot_battle.gd -- <složka pro snímky> [klíč scénáře]
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
	if args.size() > 1:
		scene.set("scenario_id", args[1])   # druhý argument: klíč scénáře
	root.add_child(scene)


func _shot(file_name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(_prefix() + file_name))
	print("Snímek: " + file_name)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 40:
		_shot("01_rozestaveni.png")
		_test_drag_swap()
	if frame == 45:
		_shot("02_vyber.png")
		scene.call("_try_start")
		print("Start se všemi rozkazy: %s" % ("OK" if int(scene.get("phase")) == 1 and (scene.get("sim") as Object).call("unordered").is_empty() else "CHYBA"))
		scene.set("speed", 2.0)
		started_at = frame
	if started_at > 0:
		var sim: Variant = scene.get("sim")
		if sim != null and scene.get("phase") == 1:
			# stejná zásada jako test simulace: schopnost, když ji rada doporučí; cílené přes klik na bojiště
			_auto_abilities(sim)
			if bool(scene.get("paused")):
				scene.call("_resume_pause")
		if frame == started_at + 60:
			_test_realtime_pause()
		if frame == started_at + 70:
			_test_realtime_orders()
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
					print("  %s %s pos=%s moving=%s" % [u.get("id"), u.get("key"), u.get("pos"), u.get("moving")])
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
	_test_orders_by_click()


## Rozkazy klikem jako hráč: Začít bez rozkazů se zeptá, pak Poslat (výběr cíle) a klik na nepřítele,
## spojence nebo zem podle rady automatického velitele.
func _test_orders_by_click() -> void:
	var sim: Variant = scene.get("sim")
	var cam: Camera3D = scene.get("cam")
	var views: Dictionary = scene.get("views")
	var ui: Variant = scene.get("ui")
	scene.call("_try_start")
	var asked := bool((ui.get("start_dialog") as Window).visible) and int(scene.get("phase")) == 0
	(ui.get("start_dialog") as Window).hide()
	print("Varování před bitvou bez rozkazů: %s" % ("OK" if asked else "CHYBA"))
	var plan: Dictionary = sim.call("suggest_orders")
	var ok := true
	for id: String in plan:
		var o: Array = plan[id]
		var kind: String = o[0]
		if kind == "":
			continue
		var screen := Vector2.ZERO
		if kind == "group":
			var members: Array = sim.call("group_members", int(o[1]))
			screen = cam.unproject_position((views[String(members[0].get("id"))] as Node3D).global_position + Vector3(0, 1.0, 0))
		elif kind == "ally":
			screen = cam.unproject_position((views[String(o[1])] as Node3D).global_position + Vector3(0, 1.0, 0))
		ui.emit_signal("order_pressed", id)
		scene.call("_pointer_move", screen)
		scene.call("_pointer_down", screen)
		var u: Variant = sim.call("by_id", id)
		var got: String = u.get("order")
		if got != kind:
			ok = false
			print("  %s: čekal jsem %s, je %s" % [id, kind, got])
		if kind == "group" and int(u.get("order_group")) != int(o[1]):
			print("  %s: jiná skupina (%d místo %d), cíl byl přesto přijat" % [id, u.get("order_group"), o[1]])
	# kdo má podle rady držet místo, dostane rozkaz na místo, kde stojí (klik na zem)
	for id: String in plan:
		if String((plan[id] as Array)[0]) == "":
			var p: Vector2 = sim.call("by_id", id).get("pos")
			ui.emit_signal("order_pressed", id)
			scene.call("_pointer_down", cam.unproject_position(Vector3(p.x + 0.3, 0.0, -p.y)))
			ok = ok and String(sim.call("by_id", id).get("order")) == "point"
	print("Rozkazy klikem: %s (%s)" % ["OK" if ok else "CHYBA", sim.call("unordered")])


var _paused_t := -1.0


## Mezerník pozastaví bitvu (čas stojí), znovu ji pustí.
func _test_realtime_pause() -> void:
	var sim: Variant = scene.get("sim")
	scene.call("_toggle_pause")
	_paused_t = float(sim.get("t"))
	print("Pauza: %s" % ("OK" if int(scene.get("phase")) == 2 else "CHYBA"))


## V pauze: výběr hrdiny a pravé tlačítko na nepřítele = rozkaz na jeho skupinu; pak bitva běží dál.
func _test_realtime_orders() -> void:
	var sim: Variant = scene.get("sim")
	var cam: Camera3D = scene.get("cam")
	var views: Dictionary = scene.get("views")
	var stood := is_equal_approx(float(sim.get("t")), _paused_t)
	scene.call("_set_selected", "jezdec")
	var foes: Array = sim.call("living", "e")
	var foe: Variant = foes[0]
	var screen := cam.unproject_position((views[String(foe.get("id"))] as Node3D).global_position + Vector3(0, 1.0, 0))
	scene.call("_command_click", screen)
	var j: Variant = sim.call("by_id", "jezdec")
	var ok := String(j.get("order")) == "group" and int(j.get("order_group")) == int(sim.call("group_of", foe.get("id")))
	print("Rozkaz pravým tlačítkem v pauze: %s (čas stál: %s)" % ["OK" if ok else "CHYBA (%s)" % j.get("order"), "OK" if stood else "CHYBA"])
	# zpátky k tankovi (pravé tlačítko na spojence), ať bitva běží podle plánu
	var tank_screen := cam.unproject_position((views["tank"] as Node3D).global_position + Vector3(0, 1.0, 0))
	scene.call("_command_click", tank_screen)
	print("Rozkaz pravým tlačítkem na spojence: %s" % ("OK" if String(j.get("order")) == "ally" and String(j.get("order_ally")) == "tank" else "CHYBA (%s)" % j.get("order")))
	scene.call("_toggle_pause")
	scene.call("_clear_selection")


func _prefix() -> String:
	var sid: String = scene.get("scenario_id")
	return "" if sid == "most_pres_reku" else sid + "_"



var _aimed := 0


## Použije schopnosti jako hráč: bez cíle tlačítkem, s cílem přes cílení a klik na bojiště.
func _auto_abilities(sim: Variant) -> void:
	var cam: Camera3D = scene.get("cam")
	var views: Dictionary = scene.get("views")
	for u: Variant in sim.call("living", "k"):
		var id: String = u.get("id")
		var h: Array = sim.call("ability_hint", id)
		if not h[0]:
			continue
		var kind: String = sim.call("ability_target", id)
		if kind == "none":
			scene.call("_ability", id)
			continue
		scene.call("_ability", id)
		var screen := Vector2.ZERO
		if kind == "enemy":
			screen = cam.unproject_position((views[String(h[1])] as Node3D).global_position + Vector3(0, 1.0, 0))
		else:
			var p: Vector2 = h[1]
			screen = cam.unproject_position(Vector3(p.x, 0.0, -p.y))
		scene.call("_pointer_move", screen)
		scene.call("_aim_click", screen)
		if String(scene.get("_aim_id")) == "":
			_aimed += 1
			if _aimed == 1:
				print("Cílená schopnost přes klik: OK (%s)" % id)
		else:
			scene.set("_aim_id", "")
