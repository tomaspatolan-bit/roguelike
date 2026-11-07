extends SceneTree
## Starts the battle scene, plays part of a battle automatically and saves screenshots.
## Checks that the scene loads without errors and looks reasonable.
## Run (with a window, for rendering):
##   godot --path . --script res://tests/screenshot_battle.gd -- <screenshot folder> [scenario key]
## Without a window (only an error check, no screenshots):
##   godot --headless --path . --script res://tests/screenshot_battle.gd

var out_dir := ""
var scene: Node
var frame := 0
var started_at := -1
var broken_shot := false


const TacticalCamera := preload("res://scripts/battle/orbit_camera.gd")
const BattleScript := preload("res://scripts/battle/battle.gd")

func _init() -> void:
	TacticalCamera.edge_scroll_all = false   # mouse edge panning would change the screenshots
	BattleScript.tutorial_mode = 1   # tutorial always (and nothing is saved to the settings)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
		DirAccess.make_dir_recursive_absolute(out_dir)
	scene = load("res://scenes/battle/battle.tscn").instantiate()
	if args.size() > 1:
		scene.set("scenario_id", args[1])   # second argument: scenario key
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
		var ui0: Variant = scene.get("ui")
		print("Výcvik se ukázal: %s" % ("OK" if bool((ui0.get("tutorial") as Control).visible) and int(scene.get("_tut_i")) == 0 else "CHYBA"))
		var deploy := int(scene.get("phase")) == 0
		if deploy:
			_test_drag_swap()   # only defense has deployment
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
		if bool(scene.get("_tut_paused")):
			# the tutorial paused the battle for the player to react: screenshot and continue (auto-play below reacts)
			_tut_pauses += 1
			if _tut_pauses <= 3:
				_shot("06_vycvik_pauza_%d.png" % _tut_pauses)
			print("Výcvik zastavil bitvu v %.0f s (krok %d)" % [float(sim.get("t")), int(scene.get("_tut_i")) + 1])
			scene.call("_toggle_pause")
		if sim != null and scene.get("phase") == 1:
			# same principle as the simulation test: the commander leads the squad group by group, an ability when the hint
			# recommends it; targeted ones via a click on the battlefield
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
			_test_tutorial_end()
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


## Drags the tank onto the priest with the mouse: they must swap places.
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
	# swap back so the battle runs in the default deployment
	a = cam.unproject_position((views["tank"] as Node3D).global_position + Vector3(0, 1.0, 0))
	b = cam.unproject_position((views["knez"] as Node3D).global_position + Vector3(0, 1.0, 0))
	scene.call("_pointer_down", a)
	scene.call("_pointer_move", a + Vector2(12, 0))
	scene.call("_pointer_move", b)
	scene.call("_pointer_up", b)
	var back_ok := (tank.get("pos") as Vector2).distance_to(tank_before) < 0.6 and (knez.get("pos") as Vector2).distance_to(knez_before) < 0.6
	print("Drag & drop zpět: %s" % ("OK" if back_ok else "CHYBA"))
	_test_orders_by_click()


## Orders by clicking like a player: Send (target picking) and a click on an enemy,
## an ally or the ground according to the automatic commander's hint.
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
	# whoever should hold his place per the hint gets an order to the spot where he stands (click on the ground)
	for id: String in plan:
		if String((plan[id] as Array)[0]) == "":
			var p: Vector2 = sim.call("by_id", id).get("pos")
			ui.emit_signal("order_pressed", id)
			scene.call("_pointer_down", cam.unproject_position(Vector3(p.x + 0.3, 0.0, -p.y)))
			ok = ok and String(sim.call("by_id", id).get("order")) == "point"
	print("Rozkazy klikem: %s (%s)" % ["OK" if ok else "CHYBA", sim.call("unordered")])


var _paused_t := -1.0


## Space pauses the battle (time stops), and resumes it.
func _test_realtime_pause() -> void:
	var sim: Variant = scene.get("sim")
	scene.call("_toggle_pause")
	_paused_t = float(sim.get("t"))
	print("Pauza: %s" % ("OK" if int(scene.get("phase")) == 2 else "CHYBA"))


## While paused: select a hero and right-click an enemy = order at his group; then the battle goes on.
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
	# back to the tank (right button on an ally) so the battle runs to plan
	var tank_screen := cam.unproject_position((views["tank"] as Node3D).global_position + Vector3(0, 1.0, 0))
	scene.call("_command_click", tank_screen)
	print("Rozkaz pravým tlačítkem na spojence: %s" % ("OK" if String(j.get("order")) == "ally" and String(j.get("order_ally")) == "tank" else "CHYBA (%s)" % j.get("order")))
	# a drag across the whole screen selects all living heroes
	var vs := root.get_visible_rect().size
	scene.call("_pointer_down", Vector2(3, 3))
	scene.call("_pointer_move", Vector2(40, 40))
	scene.call("_pointer_move", vs - Vector2(3, 3))
	scene.call("_pointer_up", vs - Vector2(3, 3))
	var sel: Array = scene.get("selection")
	var alive_k: int = sim.call("living", "k").size()
	print("Výběr tažením: %s (%d z %d)" % ["OK" if sel.size() == alive_k else "CHYBA", sel.size(), alive_k])
	# clicking a hero while the whole squad is selected selects only him (as in an RTS) and does not move him in battle
	var tpos: Vector2 = sim.call("by_id", "tank").get("pos")
	var torder: String = sim.call("by_id", "tank").get("order")
	scene.call("_pointer_down", tank_screen)
	scene.call("_pointer_up", tank_screen)
	var one: Array = scene.get("selection")
	var still: bool = String(sim.call("by_id", "tank").get("order")) == torder and (sim.call("by_id", "tank").get("pos") as Vector2).distance_to(tpos) < 0.01
	print("Klik na hrdinu vybere jen jeho: %s" % ("OK" if one == ["tank"] and still else "CHYBA (%s)" % [one]))
	# a second click on the selected hero's card does not clear the selection (turns the camera)
	scene.call("_select", "tank")
	var cam_ok := (scene.get("selection") as Array) == ["tank"]
	scene.call("_select_all")
	print("Karta a Ctrl+A: %s" % ("OK" if cam_ok and (scene.get("selection") as Array).size() == alive_k else "CHYBA"))
	# H: the selected hold their place; the card has the ability with its key and has no Send or order text
	scene.call("_set_selected", "jezdec")
	scene.call("_hold_selected")
	var held := String(sim.call("by_id", "jezdec").get("order")) == ""
	var ui: Variant = scene.get("ui")
	var texts: Array = []
	for l: Label in (ui.get("cards_row") as Node).find_children("*", "Label", true, false):
		texts.append(l.text)
	var clean := not texts.has("Send") and not texts.any(func(t: String) -> bool: return t.begins_with("With ally") or t.begins_with("No order"))
	print("H drží místo, karta bez Poslat, schopnost s klávesou: %s" % ("OK" if held and clean and texts.has("1") else "CHYBA (%s, %s)" % [held, texts]))
	# the free battle has trial bonds: two combos on Q and E in the panel after the cards
	var combos: Array = sim.call("combos")
	var combo_ok := combos.size() == 2 and texts.has("Q") and texts.has("E") and (ui.get("_combo_buttons") as Dictionary).size() == 2
	print("Komba pout na Q a E: %s" % ("OK" if combo_ok else "CHYBA (%d komb, Q %s, E %s)" % [combos.size(), texts.has("Q"), texts.has("E")]))
	scene.call("_select_all")
	# right-button preview over an enemy (the camera turned after the second card click, so the position again)
	screen = cam.unproject_position((views[String(foe.get("id"))] as Node3D).global_position + Vector3(0, 1.0, 0))
	scene.call("_pointer_move", screen)
	var hc: Array = scene.get("_hover_cmd")
	print("Náhled rozkazu nad nepřítelem: %s" % ("OK" if not hc.is_empty() and hc[0] == "group" else "CHYBA (%s)" % [hc]))
	scene.call("_toggle_pause")
	scene.call("_clear_selection")


## Tutorial: the test's actions (selection, orders, start, abilities, H) went through the steps; Got it remains.
func _test_tutorial_end() -> void:
	var steps: int = (scene.get("_tut_steps") as Array).size()
	var at_last := int(scene.get("_tut_i")) == steps - 1
	var ui: Variant = scene.get("ui")
	ui.emit_signal("tutorial_ok_pressed")
	var closed := int(scene.get("_tut_i")) == -1 and not bool((ui.get("tutorial") as Control).visible)
	print("Výcvik prošel kroky: %s" % ("OK" if at_last and closed else "CHYBA (krok %d z %d, %s)" % [int(scene.get("_tut_i")) + 1, steps, scene.get("_tut_flags")]))


## The camera has a fixed angle by map and the view does not leave the map bounds.
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
var _tut_pauses := 0


## Uses abilities like a player: without a target by the button, with a target via targeting and a click on the battlefield.
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
		var right := _aimed % 2 == 0   # alternating the right button (perform the action) and the left
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
