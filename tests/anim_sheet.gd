extends SceneTree
## Řada pěti hrdinů (každá třída se svou zbraní) a jejich animace v daných okamžicích.
## Kontrola vzhledu animací bez bitvy. Spuštění (s oknem):
##   godot --path . --script res://tests/anim_sheet.gd -- <složka>

const Sim := preload("res://scripts/sim/battle_sim.gd")
const UnitView := preload("res://scripts/battle/unit_view.gd")
const Field := preload("res://scripts/battle/battlefield.gd")

var out_dir := ""
var views: Array = []
var frame := 0
var plan: Array = []   # [název snímku, druh animace, podíl délky]


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
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	Field.box(world, Vector3(20, 0.1, 8), Vector3(0, -0.05, 0), Field.mat(Color("#7fa65a")))
	var data := Sim.load_data("most_pres_reku")
	var s := Sim.new(data, Sim.default_setup(data), 1)
	var i := 0
	for u in s.knights():
		var v := UnitView.new()
		v.setup(u)
		world.add_child(v)
		v.position = Vector3(-4.0 + i * 2.0, 0, 0)
		v.rotation.y = deg_to_rad(-60)   # bokem ke kameře, ať je vidět máchnutí
		views.append(v)
		i += 1
	var cam := Camera3D.new()
	cam.fov = 38
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0, 2.0, 9.5), Vector3(0, 1.0, 0), Vector3.UP)
	cam.make_current()
	for f: float in [0.0, 0.3, 0.5, 0.7]:
		plan.append(["utok_%02d.png" % int(f * 100), "attack", f])
	plan.append(["schopnost.png", "ability", 0.5])
	plan.append(["zasah.png", "hit", 0.3])
	plan.append(["smrt.png", "death", 1.0])


func _pose(kind: String, f: float) -> void:
	for v: UnitView in views:
		var a: AnimationPlayer = v.anim
		var name := ""
		match kind:
			"attack":
				name = v._anim_attack
			"ability":
				name = v._anim_ability
			"hit":
				name = v._anim_hit
			"death":
				name = v._anim_death
		if a == null or not a.has_animation(name):
			print("CHYBÍ animace ", name)
			continue
		a.play(name)
		a.seek(a.get_animation(name).length * f, true)
		a.pause()


func _process(_d: float) -> bool:
	frame += 1
	var idx := (frame - 10) / 6
	if frame < 10:
		return false
	if idx >= plan.size():
		print("VÝSLEDEK: OK")
		return true
	var step: Array = plan[idx]
	var sub := (frame - 10) % 6
	if sub == 0:
		_pose(step[1], step[2])
	elif sub == 4:
		print("Snímek: ", step[0])
		if out_dir != "" and DisplayServer.get_name() != "headless":
			root.get_texture().get_image().save_png(out_dir.path_join("sheet_" + String(step[0])))
	return false
