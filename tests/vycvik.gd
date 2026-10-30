extends SceneTree
## Výcvik jako hráč: kroky jdou po sobě, karta je přišpendlená k cíli, v klíčových chvílích se bitva zastaví.
## Spuštění (s oknem): godot --path . --script res://tests/vycvik.gd -- <složka na snímky> [scénář]
## Výsledek: „VÝSLEDEK: OK“, snímky vycvik_*.png.

const TacticalCamera := preload("res://scripts/battle/orbit_camera.gd")
const BattleScript := preload("res://scripts/battle/battle.gd")

var scene: Node
var out_dir := ""
var frame := 0
var errors: Array[String] = []
var paused_steps: Array = []   # kroky, u kterých výcvik zastavil bitvu
var shots := {}


func _init() -> void:
	TacticalCamera.edge_scroll_all = false
	BattleScript.tutorial_mode = 1
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
		DirAccess.make_dir_recursive_absolute(out_dir)
	scene = load("res://scenes/battle/battle.tscn").instantiate()
	if args.size() > 1:
		scene.set("scenario_id", args[1])
	root.add_child(scene)


func _shot(file_name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless" or shots.has(file_name):
		return
	shots[file_name] = true
	root.get_texture().get_image().save_png(out_dir.path_join("vycvik_" + file_name))


func _ok(cond: bool, msg: String) -> void:
	print("  %s  %s" % ["ok   " if cond else "CHYBA", msg])
	if not cond:
		errors.append(msg)


func _step() -> int:
	return int(scene.get("_tut_i"))


func _ui() -> Variant:
	return scene.get("ui")


func _pinned() -> bool:
	return bool((_ui().get("_tut_mark") as Node2D).visible)


func _screen(p: Vector2, h: float) -> Vector2:
	return (scene.get("cam") as Camera3D).unproject_position(Vector3(p.x, h, -p.y))


func _process(_delta: float) -> bool:
	frame += 1
	var sim: Variant = scene.get("sim")
	if frame == 30:
		_shot("1_vyber.png")
		_ok(bool((_ui().get("tutorial") as Control).visible) and _step() == 0, "krok 1 se ukázal")
		_ok(_pinned(), "krok 1 je přišpendlený k hrdinům")
		scene.call("_select_all")
		_ok(_step() == 1, "výběr splnil krok 1")
	elif frame == 40:
		_shot("2_rozkaz.png")
		_ok(_pinned(), "krok 2 je přišpendlený k místu před hrdiny")
		scene.call("_command_click", _screen(scene.call("_tut_world", "ahead"), 0.0))   # tam, kam ukazuje karta
		_ok(_step() == 2, "rozkaz pravým splnil krok 2")
	elif frame == 50:
		_shot("3_start.png")
		_ok(_pinned(), "krok 3 ukazuje na tlačítko nahoře")
		scene.call("_toggle_pause")
		_ok(int(scene.get("phase")) == 1 and _step() == 3, "mezerník pustil bitvu (krok 3)")
		scene.set("speed", 2.0)
	elif frame > 50 and _step() >= 0:
		if bool(scene.get("_tut_paused")):
			_react(sim)
		elif _step() == 5:
			scene.call("_hold_selected")   # krok H se ukáže bez čekání; hráč ho zkusí
			_ok(_step() == 6, "H splnilo krok 6")
			scene.call("_select_all")
		if _step() == 6 and int(scene.get("phase")) == 1:
			sim.call("auto_command")   # oddíl dál útočí, ať velitel začne chystat schopnost
	if frame > 50 and (_step() < 0 or String(sim.get("over")) != "" or float(sim.get("t")) > 150.0):
		_ok(_step() < 0, "výcvik prošel všemi kroky (zbývá krok %d)" % (_step() + 1))
		_ok(paused_steps.has(3) and paused_steps.has(4), "bitva se zastavila u nepřátel a u boje (%s)" % [paused_steps])
		print("Zastavení výcviku u kroků: %s, bitva %.0f s" % [paused_steps.map(func(i: int) -> int: return i + 1), float(sim.get("t"))])
		print("VÝSLEDEK: %s" % ("OK" if errors.is_empty() else "%d CHYB" % errors.size()))
		quit()
		return true
	return false


## Výcvik zastavil bitvu: snímek, kontrola a reakce jako hráč, pak pokračovat mezerníkem.
func _react(sim: Variant) -> void:
	var i := _step()
	paused_steps.append(i)
	_shot("pauza_%d.png" % (i + 1))
	_ok(int(scene.get("phase")) == 2, "krok %d: bitva stojí" % (i + 1))
	_ok(_pinned(), "krok %d: karta je přišpendlená" % (i + 1))
	match i:
		3:
			# nepřátelé jdou: oddíl na nejbližší skupinu
			scene.call("_select_all")
			var best: Variant = null
			for f: Variant in sim.call("living", "e"):
				if not bool(f.get("asleep")) and (best == null or float((f.get("pos") as Vector2).y) < float((best.get("pos") as Vector2).y)):
					best = f
			var views: Dictionary = scene.get("views")
			var sp := (scene.get("cam") as Camera3D).unproject_position((views[String(best.get("id"))] as Node3D).global_position + Vector3(0, 1.0, 0))
			scene.call("_command_click", sp)
			_ok(_step() == 4, "útok na skupinu splnil krok 4")
		4:
			scene.call("_ability", "tank")   # Výzva (bez cíle)
			_ok(_step() == 5, "schopnost splnila krok 5")
			_shot("6_h.png")
		6:
			_ui().emit_signal("tutorial_ok_pressed")
			_ok(_step() == -1, "Rozumím ukončilo výcvik")
	scene.call("_toggle_pause")
