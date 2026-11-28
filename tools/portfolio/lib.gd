extends RefCounted
## Shared helpers for the portfolio shots (tools/portfolio): start a battle, fast-forward the simulation without
## rendering, frame the camera, save a clean shot. Used by shots.gd (current build); old builds get their own
## small scripts because their code differs.

const STEP := 1.0 / 60.0

var tree: SceneTree
var out_dir := ""


func _init(t: SceneTree, out: String) -> void:
	tree = t
	out_dir = out
	DirAccess.make_dir_recursive_absolute(out_dir)


func frames(n: int) -> void:
	for i in n:
		await tree.process_frame


## Renders and saves the current frame. The window is usually 2x the target, the final downscale is done in Python.
func shot(code: String) -> void:
	RenderingServer.render_loop_enabled = true
	await frames(2)
	await RenderingServer.frame_post_draw
	var img := tree.root.get_texture().get_image()
	var path := out_dir.path_join(code + ".png")
	img.save_png(path)
	print("SHOT %s %dx%d" % [code, img.get_width(), img.get_height()])


func render(on: bool) -> void:
	RenderingServer.render_loop_enabled = on


## Battle scene (free battle or sandbox). Returns the battle node once ready.
func battle(scenario: String, sandbox := false) -> Node:
	var B: GDScript = load("res://scripts/battle/battle.gd")
	B.set("tutorial_mode", -1)
	load("res://scripts/battle/orbit_camera.gd").set("edge_scroll_all", false)
	var b: Node = load("res://scenes/battle/battle.tscn").instantiate()
	b.set("scenario_id", scenario)
	if sandbox:
		b.set("sandbox", true)
	tree.root.add_child(b)
	await frames(3)
	return b


## Starts the paused battle running (no deployment phase).
func run_battle(b: Node) -> void:
	# phases: 0 DEPLOY, 1 BATTLE, 2 PAUSE, 3 OVER
	if int(b.get("phase")) == 0:
		b.call("_try_start")
	elif int(b.get("phase")) == 2:
		b.call("_toggle_pause")


## Pause the running battle (phase PAUSE, as the player's Space).
func pause_battle(b: Node) -> void:
	if int(b.get("phase")) == 1:
		b.call("_toggle_pause")


## Fast-forward the simulation by `secs` without rendering. `each` (optional) is called every step with the sim
## (commands, abilities). Physics and views catch up in `settle` frames afterwards.
func ff(b: Node, secs: float, each: Callable = Callable(), settle := 4) -> void:
	render(false)
	var sim: Object = b.get("sim")
	var n := int(secs / STEP)
	for i in n:
		if String(sim.get("over")) != "":
			break
		if each.is_valid():
			each.call(sim)
		sim.call("step", STEP)
		if i % 6 == 0:
			b.call("_flush_events")
	b.call("_flush_events")
	await frames(settle)


## Camera: target in simulation coordinates (x, y), yaw/pitch in degrees, distance in m, optional fov.
func cam(b: Node, x: float, y: float, yaw: float, pitch: float, dist: float, fov := 0.0) -> void:
	var c: Camera3D = b.get("cam")
	c.set("bounds", Rect2(-200, -200, 400, 400))
	c.set("target", Vector3(x, 0.0, -y))
	c.set("yaw", deg_to_rad(yaw))
	c.set("pitch", deg_to_rad(pitch))
	c.set("distance", dist)
	if fov > 0.0:
		c.fov = fov
	c.call("_apply")


func ui(b: Node, on: bool) -> void:
	var u: Variant = b.get("ui")
	if u != null:
		(u as CanvasLayer).visible = on


## Heroes use their ability when the hint says so (like the automatic commander in tests).
static func auto_abilities(sim: Object) -> void:
	for u: Variant in sim.call("living", "k"):
		var h: Array = sim.call("ability_hint", u.get("id"))
		if h[0]:
			sim.call("use_ability", u.get("id"), h[1])


## Plays a run headless (like tests/test_run.gd full runs): random path, auto battles with abilities, random
## rewards, events and camps. Stops when the run ends or after `max_nodes` nodes (then the house stands on a
## finished node, ready for the map). Returns the run.
static func auto_run(r: Object, rng_seed: int, max_nodes := 99, stop_before_offers := false) -> Object:
	var Sim: GDScript = load("res://scripts/sim/battle_sim.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var guard := 0
	while String(r.get("over")) == "" and guard < max_nodes:
		guard += 1
		var av: Array = r.call("available")
		if av.is_empty():
			break
		r.call("choose", av[rng.randi_range(0, av.size() - 1)])
		match String(r.call("node_type")):
			"bitva", "elita", "boss":
				var data: Dictionary = r.call("load_stage_data")
				var s: Object = Sim.new(data, r.call("battle_setup", data), rng_seed * 13 + guard)
				while String(s.get("over")) == "" and float(s.get("t")) < 400.0:
					s.call("step", STEP)
					(s.get("events") as Array).clear()
					s.call("auto_command")
					auto_abilities(s)
				r.call("record_battle", s.call("result"))
				if stop_before_offers and guard >= max_nodes:
					return r
				while bool(r.call("has_legacy")):
					var c: Array = r.call("legacy_candidates")
					r.call("resolve_legacy", c[rng.randi_range(0, c.size() - 1)] if not c.is_empty() else "")
				_finish(r, rng)
			"udalost":
				var opts: Array = r.call("event")["options"]
				var picked := false
				for k in opts.size():
					var oi := rng.randi_range(0, opts.size() - 1)
					if r.call("event_option_problem", oi) == "":
						r.call("event_choose", oi)
						picked = true
						break
				if not picked:
					r.call("event_choose", opts.size() - 1)
					r.set("event_done", true)
				_finish(r, rng)
			"tabor":
				var co: Array = r.call("camp_options")
				var pick: Dictionary = co[rng.randi_range(0, co.size() - 1)]
				var arg := ""
				if String(pick["needs"]) == "hero":
					arg = (r.get("heroes") as Dictionary).keys()[rng.randi_range(0, 4)]
				elif String(pick["needs"]) == "pair":
					arg = "tank|knez"
				if String(pick["problem"]) != "" or not r.call("camp_choose", pick["id"], arg):
					r.call("camp_choose", "rest")
				_finish(r, rng)
	return r


static func _finish(r: Object, rng: RandomNumberGenerator) -> void:
	for g in 10:
		if not (r.call("bond_offer") as Dictionary).is_empty():
			var ch: Array = r.call("bond_offer")["choices"]
			r.call("choose_bond", ch[rng.randi_range(0, ch.size() - 1)] if not ch.is_empty() else "")
		elif not (r.call("offers") as Array).is_empty():
			r.call("pick_offer", rng.randi_range(0, (r.call("offers") as Array).size() - 1))
		else:
			return
