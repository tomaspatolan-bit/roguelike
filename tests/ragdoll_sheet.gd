extends SceneTree
## Ragdoll padlých: pět hrdinů a dva nepřátelé v řadě padnou, snímky po 0,3 s, 1 s a 3 s.
## Hlídá, že fyzikální kosti vzniknou a tělo spadne na zem a zůstane na ní (nepropadne, neodletí).
## Spuštění (s oknem): godot --path . --script res://tests/ragdoll_sheet.gd -- <složka>

const Sim := preload("res://scripts/sim/battle_sim.gd")
const UnitView := preload("res://scripts/battle/unit_view.gd")
const Field := preload("res://scripts/battle/battlefield.gd")

var out_dir := ""
var views: Array = []
var units: Array = []
var t := 0.0
var shots := {0.3: "ragdoll_03.png", 1.0: "ragdoll_10.png", 3.0: "ragdoll_30.png"}
var done := {}
var killed := false
var failures: Array = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ""
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#9fc3e0")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.9, 0.9, 0.95)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	world.add_child(sun)
	Field.build(world, {"river": {"y0": -40.0, "y1": -38.0, "crossings": []}, "trees": [], "rocks": []})
	var data := Sim.load_data("most_pres_reku")
	var s := Sim.new(data, Sim.default_setup(data, 0), 1)
	var picks: Array = s.knights()
	picks.append(s.by_id("e0"))
	picks.append(s.by_id("e11"))
	var i := 0
	for u in picks:
		var v := UnitView.new()
		v.setup(u)
		world.add_child(v)
		u.pos = Vector2(-6.0 + i * 2.0, 0.0)
		u.face = Vector2(0, 1) if i % 2 == 0 else Vector2(1, 0)
		views.append(v)
		units.append(u)
		i += 1
	var cam := Camera3D.new()
	cam.fov = 45
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0, 4.0, 9.0), Vector3(0, 0.3, 0), Vector3.UP)
	cam.make_current()


func _process(delta: float) -> bool:
	for k in views.size():
		(views[k] as UnitView).sync(units[k], delta, true, 1.0)
	if not killed:
		t += delta
		if t > 0.5:
			for u in units:
				u.hp = 0.0
			killed = true
			t = 0.0
		return false
	t += delta
	for at: float in shots:
		if t >= at and not done.has(at):
			done[at] = true
			_check_bodies(at)
			print("Snímek: ", shots[at])
			if out_dir != "" and DisplayServer.get_name() != "headless":
				root.get_texture().get_image().save_png(out_dir.path_join(shots[at]))
	if done.size() == shots.size():
		for f in failures:
			print("FAIL: ", f)
		print("VÝSLEDEK: %s" % ("OK" if failures.is_empty() else "%d chyb" % failures.size()))
		return true
	return false


## Kosti padlých musí ležet na zemi: ne pod ní, ne vysoko ve vzduchu (po 3 s).
func _check_bodies(at: float) -> void:
	for k in views.size():
		var v: UnitView = views[k]
		var ys: Array = []
		for pb in v.find_children("*", "PhysicalBone3D", true, false):
			ys.append((pb as Node3D).global_position.y)
		for rb in v.find_children("*", "RigidBody3D", true, false):
			ys.append((rb as Node3D).global_position.y)
			if at >= 3.0 and (rb as Node3D).global_transform.basis.y.y > 0.7:
				failures.append("%s po 3 s pořád stojí" % units[k].id)
		if ys.is_empty():
			failures.append("%s nemá ragdoll" % units[k].id)
			continue
		var lo: float = ys.min()
		var hi: float = ys.max()
		if lo < -0.3:
			failures.append("%s propadl zemí (%.2f m)" % [units[k].id, lo])
		if at >= 3.0 and hi > 0.9:
			failures.append("%s po 3 s pořád stojí nebo letí (%.2f m)" % [units[k].id, hi])
		print("  %s %.1f s: výška těla %.2f až %.2f m" % [units[k].id, at, lo, hi])
