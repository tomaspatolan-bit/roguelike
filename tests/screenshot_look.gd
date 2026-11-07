extends SceneTree
## Look of a battlefield (style test 2.0s): starts the battle scene for one scenario and saves screenshots of the
## world without UI (start, zoomed out, during the fight) and one with UI. Checks only that the scene loads.
## Run (with a window): godot --path . --script res://tests/screenshot_look.gd -- <folder> [scenario key]

const TacticalCamera := preload("res://scripts/battle/orbit_camera.gd")
const BattleScript := preload("res://scripts/battle/battle.gd")

var out_dir := ""
var sid := "most_pres_reku"
var scene: Node
var frame := 0


func _init() -> void:
	TacticalCamera.edge_scroll_all = false
	BattleScript.tutorial_mode = 0   # no tutorial in the way
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
		DirAccess.make_dir_recursive_absolute(out_dir)
	if args.size() > 1:
		sid = args[1]
	scene = load("res://scenes/battle/battle.tscn").instantiate()
	scene.set("scenario_id", sid)
	root.add_child(scene)


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	root.get_texture().get_image().save_png(out_dir.path_join("look_%s_%s.png" % [sid, name]))
	print("Snímek: look_%s_%s.png" % [sid, name])


func _ui(on: bool) -> void:
	var ui: Variant = scene.get("ui")
	if ui != null:
		(ui as CanvasLayer).visible = on


func _process(_delta: float) -> bool:
	frame += 1
	var cam: Variant = scene.get("cam")
	match frame:
		20:
			_ui(false)
		40:
			_shot("1_start")
			cam.set("distance", float(cam.get("zoom_max")))
			cam.call("_apply")
		55:
			_shot("2_wide")
			cam.set("distance", 26.0)
			cam.set("target", Vector3(0.0, 0.0, -6.0))
			cam.call("_apply")
		60:
			if int(scene.get("phase")) == 0:
				scene.call("_try_start")
			else:
				scene.call("_toggle_pause")
			scene.set("speed", 2.0)
		300:
			_shot("3_fight")
			cam.set("distance", 18.0)
			cam.call("_apply")
		315:
			_shot("4_close")
			_ui(true)
		330:
			_shot("5_ui")
			print("VÝSLEDEK: OK")
			quit(0)
	return false
