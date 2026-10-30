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


const TacticalCamera := preload("res://scripts/battle/orbit_camera.gd")

func _init() -> void:
	TacticalCamera.edge_scroll_all = false   # posun myší u okraje by měnil snímky
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
		_shot("01_start.png")
		var deploy := int(scene.get("phase")) == 0
		if deploy:
			_test_drag_swap()   # rozestavení má jen obrana
		else:
			var sim0: Variant = scene.get("sim")
			print("Bitva začíná v pauze: %s" % ("OK" if int(scene.get("phase")) == 2 and float(sim0.get("t")) == 0.0 else "CHYBA"))
		_test_orders_by_click()
		_test_camera()
	if frame == 45:
		_shot("02_vyber.png")
		if int(scene.get("phase")) == 0:
			scene.call("_try_start")
		else:
			scene.call("_toggle_pause")
		print("Start: %s" % ("OK" if int(scene.get("phase")) == 1 else "CHYBA"))
		scene.set("speed", 2.0)
		started_at = frame
	if started_at > 0:
		var sim: Variant = scene.get("sim")
		if sim != null and scene.get("phase") == 1:
			# stejná zásada jako test simulace: velitel vede oddíl skupinku po skupince, schopnost, když ji rada
			# doporučí; cílené přes klik na bojiště
			sim.call("auto_command")
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


## Rozkazy klikem jako hráč: Poslat (výběr cíle) a klik na nepřítele,
## spojence nebo zem podle rady automatického velitele.
func _test_orders_by_click() -> void:
	var sim: Variant = scene.get("sim")
	var cam: Camera3D = scene.get("cam")
	var views: Dictionary = scene.get("views")
	var ui: Variant = scene.get("ui")
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
	# výběr tažením přes celou obrazovku vybere všechny živé hrdiny
	var vs := root.get_visible_rect().size
	scene.call("_pointer_down", Vector2(3, 3))
	scene.call("_pointer_move", Vector2(40, 40))
	scene.call("_pointer_move", vs - Vector2(3, 3))
	scene.call("_pointer_up", vs - Vector2(3, 3))
	var sel: Array = scene.get("selection")
	var alive_k: int = sim.call("living", "k").size()
	print("Výběr tažením: %s (%d z %d)" % ["OK" if sel.size() == alive_k else "CHYBA", sel.size(), alive_k])
	# klik na hrdinu při výběru celého oddílu vybere jen jeho (jako v RTS) a v bitvě s ním nepohne
	var tpos: Vector2 = sim.call("by_id", "tank").get("pos")
	var torder: String = sim.call("by_id", "tank").get("order")
	scene.call("_pointer_down", tank_screen)
	scene.call("_pointer_up", tank_screen)
	var one: Array = scene.get("selection")
	var still: bool = String(sim.call("by_id", "tank").get("order")) == torder and (sim.call("by_id", "tank").get("pos") as Vector2).distance_to(tpos) < 0.01
	print("Klik na hrdinu vybere jen jeho: %s" % ("OK" if one == ["tank"] and still else "CHYBA (%s)" % [one]))
	# druhý klik na kartu vybraného výběr nezruší (natočí kameru)
	scene.call("_select", "tank")
	var cam_ok := (scene.get("selection") as Array) == ["tank"]
	scene.call("_select_all")
	print("Karta a Ctrl+A: %s" % ("OK" if cam_ok and (scene.get("selection") as Array).size() == alive_k else "CHYBA"))
	# H: vybraní drží místo; karta má schopnost s klávesou a nemá Poslat ani text rozkazu
	scene.call("_set_selected", "jezdec")
	scene.call("_hold_selected")
	var held := String(sim.call("by_id", "jezdec").get("order")) == ""
	var ui: Variant = scene.get("ui")
	var texts: Array = []
	for l: Label in (ui.get("cards_row") as Node).find_children("*", "Label", true, false):
		texts.append(l.text)
	var clean := not texts.has("Poslat") and not texts.any(func(t: String) -> bool: return t.begins_with("Se spojencem") or t.begins_with("Bez rozkazu"))
	print("H drží místo, karta bez Poslat, schopnost s klávesou: %s" % ("OK" if held and clean and texts.has("1") else "CHYBA (%s, %s)" % [held, texts]))
	scene.call("_select_all")
	# náhled pravého tlačítka nad nepřítelem (kamera se po druhém kliku na kartu natočila, pozice znovu)
	screen = cam.unproject_position((views[String(foe.get("id"))] as Node3D).global_position + Vector3(0, 1.0, 0))
	scene.call("_pointer_move", screen)
	var hc: Array = scene.get("_hover_cmd")
	print("Náhled rozkazu nad nepřítelem: %s" % ("OK" if not hc.is_empty() and hc[0] == "group" else "CHYBA (%s)" % [hc]))
	scene.call("_toggle_pause")
	scene.call("_clear_selection")


## Kamera má pevný úhel podle mapy a výřez neujede za hranice mapy.
func _test_camera() -> void:
	var cam: Variant = scene.get("cam")
	var data: Dictionary = scene.get("data")
	var sc: Dictionary = data["scenario"].get("camera", {})
	var yaw0: float = cam.get("yaw")
	var t0: Vector3 = cam.get("target")
	cam.set("target", Vector3(500, 0, -500))
	cam.call("_apply")
	var b: Rect2 = cam.get("bounds")
	var t: Vector3 = cam.get("target")
	var inside := t.x <= b.end.x + 0.01 and -t.z <= b.end.y + 0.01
	var yaw_ok := is_equal_approx(yaw0, deg_to_rad(float(sc.get("yaw", data["units"]["camera"]["yaw"]))))
	cam.set("target", t0)
	cam.call("_apply")
	print("Kamera s pevným úhlem a hranicemi: %s" % ("OK" if inside and yaw_ok else "CHYBA (%s, %s)" % [t, b]))


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
		var right := _aimed % 2 == 0   # střídavě pravým tlačítkem (provést akci) a levým
		if right:
			scene.call("_command_click", screen)
		else:
			scene.call("_aim_click", screen)
		if String(scene.get("_aim_id")) == "":
			_aimed += 1
			if _aimed == 1:
				print("Cílená schopnost pravým tlačítkem: OK (%s)" % id)
			elif _aimed == 2:
				print("Cílená schopnost přes klik: OK (%s)" % id)
		else:
			scene.set("_aim_id", "")
