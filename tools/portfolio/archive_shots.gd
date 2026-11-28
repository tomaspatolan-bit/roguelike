extends SceneTree
## Portfolio shots of OLD builds (copied into a worktree of an old commit and run there; the old code is not
## changed). The old battle scenes differ, so everything is looked up by name with has_method / get.
## Run: godot --path <worktree> --fixed-fps 60 --script res://tools/portfolio/archive_shots.gd -- <out> <code> <mode> [t]
## Modes:
##   battle   start the battle, fast-forward t seconds (automatic commander if the build has one), shot with UI
##   paused   like battle, then pause (Space) and show an order preview from the first hero to the enemy
##   routes   deployment with routes drawn for three heroes, the last one still being drawn (cursor in post)
##   map      the act map of a run (builds with run.tscn)
##   reward   the reward screen after the first battle of a run

const STEP := 1.0 / 60.0

var out := ""
var code := ""
var mode := ""
var t := 12.0


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	code = a[1]
	mode = a[2]
	if a.size() > 3:
		t = float(a[3])
	DirAccess.make_dir_recursive_absolute(out)
	var cam_script: GDScript = load("res://scripts/battle/orbit_camera.gd") if ResourceLoader.exists("res://scripts/battle/orbit_camera.gd") else null
	if cam_script != null and "edge_scroll_all" in cam_script:
		cam_script.set("edge_scroll_all", false)
	var bs: GDScript = load("res://scripts/battle/battle.gd")
	if "tutorial_mode" in bs:
		bs.set("tutorial_mode", -1)
	match mode:
		"battle", "paused":
			await _battle(mode == "paused")
		"routes":
			await _routes()
		"map", "reward":
			await _run(mode)
	print("HOTOVO")
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	RenderingServer.render_loop_enabled = true
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("SHOT %s %dx%d" % [name, img.get_width(), img.get_height()])


func _meta(name: String, d: Dictionary) -> void:
	var f := FileAccess.open(out.path_join(name + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(d))


func _call_if(o: Object, m: String, args: Array = []) -> Variant:
	if o.has_method(m):
		return o.callv(m, args)
	return null


func _start(b: Node) -> void:
	# deployment → battle; newer builds start paused (phase PAUSE = 2) and need Space
	# builds with orders (29.10+) warn before a battle without them: give the suggested orders first
	var sim0: Object = b.get("sim")
	var setup: Variant = b.get("setup")
	if sim0.has_method("suggest_orders") and setup is Dictionary:
		(setup as Dictionary)["orders"] = sim0.call("suggest_orders")
	if int(b.get("phase")) == 0:
		b.call("_start_battle")
	await _frames(2)
	if b.has_method("_toggle_pause") and int(b.get("phase")) != 1:
		b.call("_toggle_pause")
	await _frames(2)


func _auto(sim: Object) -> void:
	if sim.has_method("auto_command"):
		sim.call("auto_command")
	elif sim.has_method("suggest_orders") and sim.has_method("apply_orders"):
		pass
	if sim.has_method("ability_hint") and sim.has_method("living"):
		for u: Variant in sim.call("living", "k"):
			var h: Array = sim.call("ability_hint", u.get("id"))
			if h.size() > 1 and h[0]:
				sim.call("use_ability", u.get("id"), h[1])


func _ff(b: Node, secs: float) -> void:
	RenderingServer.render_loop_enabled = false
	var sim: Object = b.get("sim")
	for i in int(secs / STEP):
		if String(sim.get("over")) != "":
			break
		_auto(sim)
		sim.call("step", STEP)
		if i % 6 == 0:
			_call_if(b, "_flush_events")
	_call_if(b, "_flush_events")
	await _frames(30)


func _battle(pause: bool) -> void:
	var b: Node = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(b)
	await _frames(5)
	await _start(b)
	await _ff(b, t)
	b.set("speed", 1.0)
	if pause:
		if b.has_method("_toggle_pause"):
			b.call("_toggle_pause")
		await _frames(5)
		var sim: Object = b.get("sim")
		var hero := ""
		for u: Variant in sim.call("living", "k"):
			hero = u.get("id")
			if String(u.get("key")) == "jezdec" or hero == "jezdec":
				break
		var foe: Variant = null
		for u: Variant in sim.call("living", "e"):
			foe = u
		if hero != "" and foe != null:
			b.set("selection", [hero])
			b.set("selected", hero)
			_call_if(b, "_refresh_panel")
			var cam: Camera3D = b.get("cam")
			var fp: Vector2 = foe.get("pos")
			var sp := cam.unproject_position(Vector3(fp.x, 0.9, -fp.y))
			_call_if(b, "_pointer_move", [sp])
			var vp := cam.get_viewport().get_visible_rect().size
			_meta(code, {"cursor": [sp.x, sp.y], "vp": [vp.x, vp.y]})
		await _frames(10)
	else:
		await _frames(10)
	await _shot(code)
	var ui: Variant = b.get("ui")
	if ui != null and "top_bar" in ui:
		var tb: Control = ui.get("top_bar")
		var r := tb.get_global_rect()
		var k := float(root.size.y) / 900.0
		var m := {"bar": [r.position.x * k, r.position.y * k, r.size.x * k, r.size.y * k]}
		if FileAccess.file_exists(out.path_join(code + ".json")):
			var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out.path_join(code + ".json")))
			m.merge(old)
		_meta(code, m)


## Deployment with routes (build of 28.10): finished routes for the archer and the cavalier, the assassin's route
## still being drawn with the mouse.
func _routes() -> void:
	var b: Node = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(b)
	await _frames(8)
	var sim: Object = b.get("sim")
	var cam: Camera3D = b.get("cam")
	var plans := {
		"lucistnik": [Vector2(-1.5, 1.5), Vector2(-3.0, 3.0)],
		"jezdec": [Vector2(0.5, 2.0), Vector2(0.0, 5.0), Vector2(0.0, 9.0)],
	}
	for id: String in plans:
		var pts: Array = plans[id]
		var u: Object = sim.call("by_id", id)
		var abs_pts: Array = []
		for p: Vector2 in pts:
			abs_pts.append((u.get("pos") as Vector2) + p)
		if String(sim.call("route_problem", id, abs_pts)) == "":
			sim.call("set_route", id, abs_pts)
			(b.get("setup")["routes"] as Dictionary)[id] = abs_pts
	# the assassin's route is being drawn now
	var as_u: Object = sim.call("by_id", "asasin")
	var start: Vector2 = as_u.get("pos")
	b.set("_route_id", "asasin")
	var path: Array = [start, start + Vector2(0.6, 1.2), start + Vector2(1.4, 2.4), start + Vector2(1.8, 3.4), start + Vector2(1.9, 4.6)]
	var sp := Vector2.ZERO
	b.call("_pointer_down", cam.unproject_position(Vector3(start.x, 0, -start.y)))
	for p: Vector2 in path:
		sp = cam.unproject_position(Vector3(p.x, 0, -p.y))
		b.call("_pointer_move", sp)
		await _frames(1)
	_call_if(b, "_refresh_panel")
	await _frames(10)
	await _shot(code)
	var vp2 := cam.get_viewport().get_visible_rect().size
	_meta(code, {"cursor": [sp.x, sp.y], "vp": [vp2.x, vp2.y]})


## Run screens of old builds.
func _run(what: String) -> void:
	var s: Node = load("res://scenes/run/run.tscn").instantiate()
	root.add_child(s)
	await _frames(5)
	_call_if(s, "start_run")
	await _frames(10)
	if what == "map":
		_call_if(s, "show_map")
		await _frames(5)
		await _shot(code)
		return
	# reward: play the first battle headless through the run state and show the screen after it
	var run: Object = s.get("run")
	if run.has_method("available"):   # act map (29.10+); the trial run before it is a fixed row of battles
		var av: Array = run.call("available")
		for id: String in av:
			if run.call("is_battle_node", id):
				run.call("choose", id)
				break
	var Sim: GDScript = load("res://scripts/sim/battle_sim.gd")
	var data: Dictionary = run.call("load_stage_data")
	var sim: Object = Sim.new(data, run.call("battle_setup", data))
	while String(sim.get("over")) == "" and float(sim.get("t")) < 400.0:
		sim.call("step", STEP)
		(sim.get("events") as Array).clear()
		_auto(sim)
	run.call("record_battle", sim.call("result"))
	if s.has_method("show_after_battle"):
		s.call("show_after_battle")
	else:
		_call_if(s, "show_camp")
	await _frames(5)
	await _shot(code)
