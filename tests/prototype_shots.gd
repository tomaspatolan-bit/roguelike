extends SceneTree
## Visual prototype (phase 2): screenshots of the tank and of The River Bridge from the real game, the class-colour
## coverage test and a frame-time measurement. Checks only that everything loads; the pictures are judged by eye.
## Run (with a window): godot --path . --script res://tests/prototype_shots.gd -- <folder>
## Pictures (prefix proto_): 01 close-up of every hero (front, back), 02 tank from the battle camera, 03 colour test
## (every hero from the battle camera angle in four facings, the tank also in the guard; normal and as a mask:
## blue = class colour cells, red = the rest of the figure incl. weapons and the horse, black = not the figure),
## 04 animation frames of the tank, 05 river crossing in the morning,
## 06 the same in the late afternoon, 07 environment detail. The coverage and the measurement go to
## proto_report.json in the same folder.

const Gallery := preload("res://scripts/sandbox/gallery.gd")
const TacticalCamera := preload("res://scripts/battle/orbit_camera.gd")
const BattleScript := preload("res://scripts/battle/battle.gd")
const Sim := preload("res://scripts/sim/battle_sim.gd")

const MASK_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled;
uniform float cols = 32.0;
uniform float role_from = 5.0;
uniform float role_to = 8.0;
void fragment() {
	float c = floor(UV.x * cols);
	ALBEDO = (c >= role_from && c <= role_to) ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
}
"""
const FRAMES := [   # [label, animation key in the tank's data, time (s) or -1 = last frame]
	["idle", "idle", 0.4], ["walk", "walk", 0.25], ["stance", "stance", 0.8], ["block", "block", 0.3],
	["attack_a", "attack", 0.2], ["attack_b", "attack", 0.42], ["hit", "hit", 0.2], ["death", "death", -1.0],
]

var out_dir := ""
var report := {}
var ok := true


func _initialize() -> void:
	TacticalCamera.edge_scroll_all = false
	BattleScript.tutorial_mode = 0
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
		DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> Image:
	await _frames(3)
	var img := root.get_texture().get_image()
	if out_dir != "" and DisplayServer.get_name() != "headless":
		img.save_png(out_dir.path_join("proto_%s.png" % name))
		print("Snímek: proto_%s.png" % name)
	return img


func _check(cond: bool, what: String) -> void:
	if not cond:
		ok = false
		print("CHYBA: ", what)


func _run() -> void:
	await _frames(5)
	await _gallery_part()
	for look: String in ["morning", "afternoon"]:
		await _battle_part(look)
	report["viewport"] = [root.size.x, root.size.y]
	report["gpu"] = RenderingServer.get_video_adapter_name()
	if out_dir != "":
		var f := FileAccess.open(out_dir.path_join("proto_report.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("Zpráva: ", JSON.stringify(report))
	print("VÝSLEDEK: ", "OK" if ok else "CHYBA")
	quit(0 if ok else 1)


# ------------------------------------------------------------------ tank up close, animation frames, colour test

const HEROES := ["tank", "knez", "lucistnik", "jezdec", "asasin"]


func _gallery_part() -> void:
	var g: Node3D = Gallery.new()
	root.add_child(g)
	await _frames(10)
	var views: Dictionary = g.get("views")
	var v: Node3D = views.get("tank")
	_check(v != null, "galerie nemá tanka")
	if v == null:
		return
	var anim: AnimationPlayer = v.get("anim")
	var tank_data: Dictionary = (g.get("sim") as Sim).by_id("tank").base
	var names: Dictionary = tank_data.get("anims", {})
	for k: String in ["idle", "walk", "attack", "hit", "death", "stance", "block"]:
		_check(anim != null and anim.has_animation(String(names.get(k, ""))), "tank nemá animaci %s" % k)
	# close-ups of every hero, front and back
	for id: String in HEROES:
		g.set("who", id)
		g.call("view_close")
		var big := id == "jezdec"
		for side: Array in [["front", 25.0, 10.0], ["back", 200.0, 30.0]]:
			g.set("_yaw", deg_to_rad(side[1]))
			g.set("_pitch", deg_to_rad(side[2]))   # from behind a bit higher, over the enemies standing in the row
			g.set("_dist", 6.2 if big else 4.3)
			if big:
				g.set("_target", (g.get("_target") as Vector3) + Vector3(0, 0.6, 0))
			g.call("_apply_cam")
			await _frames(12)
			await _shot("01_%s_%s" % [id, side[0]])
	# animation frames of the tank: the gallery stops driving the units, the player is set to an exact moment
	g.set("who", "tank")
	g.call("view_close")
	g.set_process(false)
	g.set("_yaw", deg_to_rad(38.0))
	g.set("_pitch", deg_to_rad(14.0))
	g.set("_dist", 5.4)
	g.call("_apply_cam")
	for fr: Array in FRAMES:
		var a_name := String(names.get(fr[1], ""))
		if anim == null or not anim.has_animation(a_name):
			continue
		anim.play(a_name)
		anim.speed_scale = 0.0
		var t: float = fr[2]
		var length := anim.get_animation(a_name).length
		anim.seek(length - 0.02 if t < 0.0 else minf(t, length - 0.02), true)
		await _shot("04_anim_%s" % fr[0])
	# colour test of every hero from the battle camera angle (pitch 48), four facings
	var mask := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = MASK_SHADER
	mask.shader = sh
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	black.disable_fog = true
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	floor_mi.mesh = pm
	floor_mi.material_override = black
	floor_mi.visible = false
	g.add_child(floor_mi)
	var all_cov := {}
	var lowest_by := {}
	for id: String in HEROES:
		var hv: Node3D = views.get(id)
		if hv == null:
			_check(false, "galerie nemá %s" % id)
			continue
		for other: Node3D in views.values():
			other.visible = other == hv
		g.set("who", id)
		g.call("view_close")
		g.set("_pitch", deg_to_rad(48.0))
		g.set("_yaw", 0.0)
		g.set("_dist", 8.5 if id == "jezdec" else 6.5)
		g.call("_apply_cam")
		var hanim: AnimationPlayer = hv.get("anim")
		var hnames: Dictionary = (g.get("sim") as Sim).by_id(id).base.get("anims", {})
		var poses: Array = ["idle", "stance"] if id == "tank" else ["idle"]
		var meshes: Array = hv.find_children("*", "MeshInstance3D", true, false)
		var originals := {}
		for m: MeshInstance3D in meshes:
			originals[m] = m.material_override
		var base_y := hv.position.y
		var base_rot := hv.rotation.y
		floor_mi.position = hv.position + Vector3(0, 0.5, 0)
		var cov := {}
		for pose: String in poses:
			var a_name := String(hnames.get(pose, ""))
			if hanim != null and hanim.has_animation(a_name):
				hanim.play(a_name)
				hanim.speed_scale = 0.0
				hanim.seek(0.5, true)
			for facing: int in [0, 90, 180, 270]:
				hv.rotation.y = deg_to_rad(float(facing))
				var tag := "%s_%s_%03d" % [id, pose, facing]
				await _shot("03_colour_%s" % tag)
				floor_mi.visible = true
				hv.position.y = base_y + 0.6
				(g.get("outline") as Node3D).visible = false
				for m: MeshInstance3D in meshes:
					m.material_override = mask if m.name != "ContactShade" else null
					if m.name == "ContactShade":
						m.visible = false
				var img: Image = await _shot("03_mask_%s" % tag)
				var blue := 0
				var red := 0
				for y in range(0, img.get_height(), 2):
					for x in range(0, img.get_width(), 2):
						var px := img.get_pixel(x, y)
						if px.b > 0.5 and px.r < 0.35:
							blue += 1
						elif px.r > 0.5 and px.b < 0.35:
							red += 1
				cov["%s_%03d" % [pose, facing]] = snappedf(100.0 * blue / maxf(1.0, float(blue + red)), 0.1)
				floor_mi.visible = false
				hv.position.y = base_y
				(g.get("outline") as Node3D).visible = true
				for m: MeshInstance3D in meshes:
					m.material_override = originals[m]
					m.visible = true
		hv.rotation.y = base_rot
		var lowest := 100.0
		for k: String in cov:
			lowest = minf(lowest, float(cov[k]))
		all_cov[id] = cov
		lowest_by[id] = lowest
		_check(lowest >= 40.0, "%s: barva třídy pokrývá jen %.1f %% postavy (cíl 40 %%)" % [id, lowest])
	for other: Node3D in views.values():
		other.visible = true
	report["class_colour_coverage_percent"] = all_cov
	report["class_colour_coverage_min"] = lowest_by
	g.queue_free()
	await _frames(3)


# ------------------------------------------------------------------ The River Bridge from the battle camera

func _battle_part(look: String) -> void:
	BattleScript.sandbox_state = {"scenario": "most_pres_reku", "look": look, "relics": [], "stats": {}, "bond_type": "bratri", "setup": {}}
	var scene: Node = load("res://scenes/battle/battle.tscn").instantiate()
	scene.set("sandbox", true)
	root.add_child(scene)
	await _frames(20)
	var ui: Variant = scene.get("ui")
	if ui != null:
		(ui as CanvasLayer).visible = false
	var cam: Variant = scene.get("cam")
	var sim: Sim = scene.get("sim")
	var tank := sim.by_id("tank")
	_check(tank != null, "bitva nemá tanka")
	if look == "morning":
		await _frames(10)
		await _shot("02_tank_gameplay")
	# the tank steps up to the bridge so the crossing and the hero are in one picture
	if tank != null:
		tank.pos = Vector2(0.9, 1.6)
		tank.home = tank.pos
	cam.set("target", Vector3(0.0, 0.0, -3.5))
	cam.set("distance", 30.0)
	cam.call("_apply")
	await _frames(10)
	await _shot("05_river_morning" if look == "morning" else "06_river_afternoon")
	# measurement: uncapped frame rate over 150 frames of this view
	var vs := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _frames(20)
	var t0 := Time.get_ticks_usec()
	await _frames(150)
	var ms := float(Time.get_ticks_usec() - t0) / 150.0 / 1000.0
	report["perf_" + look] = {
		"frame_ms": snappedf(ms, 0.01), "fps": snappedf(1000.0 / maxf(ms, 0.001), 0.1),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
	}
	DisplayServer.window_set_vsync_mode(vs)
	cam.set("target", Vector3(1.2, 0.0, -3.2))
	cam.set("distance", 12.5)
	cam.call("_apply")
	await _frames(10)
	await _shot("07_env_detail_%s" % look)
	scene.queue_free()
	await _frames(5)
