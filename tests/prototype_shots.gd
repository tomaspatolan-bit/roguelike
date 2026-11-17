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
	_check_models()
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


## Every model a unit refers to must exist (the scene skips a missing weapon silently: 15.11.2026 the bow, lance and
## daggers were missing from the repository and the tests did not notice).
func _check_models() -> void:
	var units: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json"))
	var n := 0
	for group: String in ["knights", "foes"]:
		var d: Dictionary = units.get(group, {})
		for key: String in d.keys():
			var u: Dictionary = d[key]
			for field: String in ["model", "weapon_model", "offhand_model", "projectile_model", "mount_model"]:
				var path := String(u.get(field, ""))
				if path == "":
					continue
				n += 1
				_check(ResourceLoader.exists(path), "%s.%s: model %s chybí" % [key, field, path])
	print("Modely jednotek: zkontrolováno %d" % n)


# ------------------------------------------------------------------ tank up close, animation frames, colour test

const HEROES := ["tank", "knez", "lucistnik", "jezdec", "asasin"]
const FOES := ["lapka", "kopinik", "strelec", "vudce", "palic", "ostrostrelec", "setnik"]
const COMMANDERS := ["vudce", "palic", "ostrostrelec", "setnik"]
## Two figures count as told apart from the battle camera when their outlines (same camera distance, aligned on the
## centre) overlap less than this (intersection over union).
const SILHOUETTE_MAX_IOU := 0.8


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
	# close-ups of the brigands (one of each model: axe, spear, bow, commander), front and back, and the whole row
	var gsim: Sim = g.get("sim")
	for id: String in views.keys():
		var fu: Sim.Unit = gsim.by_id(id)
		if fu == null or not (fu.key in FOES):
			continue
		g.set("who", id)
		g.call("view_close")
		for other: Node3D in views.values():
			other.visible = other == views[id]   # nobody in front of him
		for side: Array in [["front", 25.0, 10.0], ["back", 200.0, 30.0]]:
			g.set("_yaw", deg_to_rad(side[1]))
			g.set("_pitch", deg_to_rad(side[2]))
			g.set("_dist", 6.0 if fu.key in COMMANDERS else 4.3)
			g.call("_apply_cam")
			await _frames(12)
			await _shot("01_%s_%s" % [fu.key, side[0]])
		for other: Node3D in views.values():
			other.visible = true
		if fu.key == "vudce":
			g.set("_yaw", 0.0)
			g.set("_pitch", deg_to_rad(30.0))
			g.set("_dist", 11.0)
			g.call("_apply_cam")
			await _frames(12)
			await _shot("01_lapkove_rada")
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
	await _silhouettes(g, views, mask, floor_mi)
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


## Outline test (decision 17.11.2026): every commander and a plain brigand from the battle camera (pitch 48, the same
## distance for all, so the size counts too), two facings, as a mask; pairwise intersection over union of the outlines.
func _silhouettes(g: Node3D, views: Dictionary, mask: ShaderMaterial, floor_mi: MeshInstance3D) -> void:
	var gsim: Sim = g.get("sim")
	var who := {}
	for id: String in views.keys():
		var fu: Sim.Unit = gsim.by_id(id)
		if fu != null and (fu.key in COMMANDERS or fu.key == "lapka") and not who.has(fu.key):
			who[fu.key] = id
	var outl: Dictionary = {}   # key -> {facing: PackedByteArray}
	var size: Dictionary = {}
	const STEP := 3
	for key: String in who.keys():
		var hv: Node3D = views[who[key]]
		for other: Node3D in views.values():
			other.visible = other == hv
		g.set("who", who[key])
		g.call("view_close")
		g.set("_pitch", deg_to_rad(48.0))
		g.set("_yaw", 0.0)
		g.set("_dist", 9.0)
		g.call("_apply_cam")
		var hanim: AnimationPlayer = hv.get("anim")
		var idle := String(gsim.by_id(who[key]).base.get("anims", {}).get("idle", "A_Knight_Idle"))
		if hanim != null and hanim.has_animation(idle):
			hanim.play(idle)
			hanim.speed_scale = 0.0
			hanim.seek(0.5, true)
		var meshes: Array = hv.find_children("*", "MeshInstance3D", true, false)
		var originals := {}
		for m: MeshInstance3D in meshes:
			originals[m] = m.material_override
		var base_y := hv.position.y
		var base_rot := hv.rotation.y
		floor_mi.position = hv.position + Vector3(0, 0.5, 0)
		outl[key] = {}
		for facing: int in [0, 90]:
			hv.rotation.y = deg_to_rad(float(facing))
			floor_mi.visible = true
			hv.position.y = base_y + 0.6
			(g.get("outline") as Node3D).visible = false
			for m: MeshInstance3D in meshes:
				m.material_override = mask if m.name != "ContactShade" else null
				m.visible = m.name != "ContactShade"
			var img: Image = await _shot("08_silhouette_%s_%03d" % [key, facing])
			var w := img.get_width() / STEP
			var h := img.get_height() / STEP
			var bits := PackedByteArray()
			bits.resize(w * h)
			var cx := 0.0
			var cy := 0.0
			var n := 0
			for y in h:
				for x in w:
					var px := img.get_pixel(x * STEP, y * STEP)
					# only the pure mask colours (the gallery panel, trees and fences stay out)
					if (px.b > 0.55 and px.r < 0.3 and px.g < 0.3) or (px.r > 0.55 and px.g < 0.3 and px.b < 0.3):
						bits[y * w + x] = 1
						cx += x
						cy += y
						n += 1
			outl[key][facing] = {"bits": bits, "w": w, "h": h, "cx": cx / maxf(n, 1), "cy": cy / maxf(n, 1), "n": n}
			size["%s_%03d" % [key, facing]] = n
			floor_mi.visible = false
			hv.position.y = base_y
			(g.get("outline") as Node3D).visible = true
			for m: MeshInstance3D in meshes:
				m.material_override = originals[m]
				m.visible = true
		hv.rotation.y = base_rot
	for other: Node3D in views.values():
		other.visible = true
	var ious := {}
	var keys: Array = outl.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var worst := 0.0
			for facing: int in [0, 90]:
				worst = maxf(worst, _iou(outl[keys[i]][facing], outl[keys[j]][facing]))
			ious["%s~%s" % [keys[i], keys[j]]] = snappedf(worst, 0.01)
			_check(worst <= SILHOUETTE_MAX_IOU, "obrysy %s a %s se z bitevní kamery skoro kryjí (IoU %.2f, nejvýš %.2f)" % [keys[i], keys[j], worst, SILHOUETTE_MAX_IOU])
	report["silhouette_iou"] = ious
	report["silhouette_area_px"] = size
	print("Obrysy velitelů (IoU, nejhorší natočení): ", JSON.stringify(ious))


## Intersection over union of two outlines aligned on their centres.
func _iou(a: Dictionary, b: Dictionary) -> float:
	var w: int = a["w"]
	var h: int = a["h"]
	var dx := roundi(float(b["cx"]) - float(a["cx"]))
	var dy := roundi(float(b["cy"]) - float(a["cy"]))
	var ab: PackedByteArray = a["bits"]
	var bb: PackedByteArray = b["bits"]
	var inter := 0
	for y in h:
		for x in w:
			if ab[y * w + x] == 0:
				continue
			var x2 := x + dx
			var y2 := y + dy
			if x2 >= 0 and x2 < w and y2 >= 0 and y2 < h and bb[y2 * w + x2] == 1:
				inter += 1
	var uni := int(a["n"]) + int(b["n"]) - inter
	return float(inter) / maxf(1.0, float(uni))

