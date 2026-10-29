extends RefCounted
## Staví statické bojiště: světlo, prostředí, zem, řeka, most, stromy, kameny.
## Převod souřadnic simulace na 3D: Vector3(x, výška, -y).

static func to_world(p: Vector2, h: float = 0.0) -> Vector3:
	return Vector3(p.x, h, -p.y)


static func mat(color: Color, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


static func transparent_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	return m


static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func cylinder(parent: Node3D, r_top: float, r_bottom: float, h: float, pos: Vector3, material: Material, segments: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bottom
	m.height = h
	m.radial_segments = segments
	m.rings = 1
	mi.mesh = m
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


static func build(root: Node3D, scenario: Dictionary) -> void:
	# --- fyzikální zem (padající těla, ragdoll) ---
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var gs := CollisionShape3D.new()
	gs.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(gs)
	root.add_child(floor_body)
	# --- prostředí a světlo ---
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#7f98b3")
	sky_mat.sky_horizon_color = Color("#c9d3dc")
	sky_mat.ground_horizon_color = Color("#a9b6c2")
	sky_mat.ground_bottom_color = Color("#56614f")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.ssao_enabled = true
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	root.add_child(sun)

	# --- zem a řeka ---
	var ground := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(80, 80)
	ground.mesh = gm
	ground.material_override = mat(Color("#5f7a45"), 0.95)
	root.add_child(ground)

	var river: Dictionary = scenario["river"]
	var lo: float = river["y0"]
	var hi: float = river["y1"]
	var water := box(root, Vector3(80, 0.04, hi - lo), to_world(Vector2(0, (lo + hi) / 2.0), 0.0), mat(Color("#4f7fa6"), 0.12, 0.1))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for y: float in [lo, hi]:
		box(root, Vector3(80, 0.12, 0.35), to_world(Vector2(0, y), 0.02), mat(Color("#6b6f5a"), 0.95))

	# --- přechody: most, lávka, brod ---
	var wood := mat(Color("#7a5230"), 0.9)
	var stone := mat(Color("#8f8d89"), 0.9)
	for c: Dictionary in river["crossings"]:
		var x0: float = c["x0"]
		var x1: float = c["x1"]
		var cx := (x0 + x1) / 2.0
		var half := (x1 - x0) / 2.0
		var kind: String = c.get("kind", "most")
		if kind == "brod":
			var shallow := box(root, Vector3(x1 - x0, 0.05, hi - lo + 0.4), to_world(Vector2(cx, (lo + hi) / 2.0), 0.01), mat(Color("#8fb0b8"), 0.3, 0.05))
			shallow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var i := 0
			for y in range(int(lo * 2.0), int(hi * 2.0)):
				var sx := x0 + 0.4 + fmod(float(i) * 1.37, x1 - x0 - 0.8)
				box(root, Vector3(0.35, 0.12, 0.3), to_world(Vector2(sx, float(y) / 2.0 + 0.2), 0.05), stone, Vector3(0, float(i) * 0.7, 0))
				i += 1
			continue
		var bridge_len := hi - lo + 1.6
		box(root, Vector3(half * 2.4, 0.08, bridge_len), to_world(Vector2(cx, (lo + hi) / 2.0), 0.04), wood)
		var rail_h := 0.7 if kind == "most" else 0.5
		for sx: float in [-1.0, 1.0]:
			box(root, Vector3(0.1, rail_h, bridge_len), to_world(Vector2(cx + sx * half * 1.2, (lo + hi) / 2.0), rail_h * 0.57), wood)
			for y in [lo + 0.3, (lo + hi) / 2.0, hi - 0.3]:
				cylinder(root, 0.16, 0.16, 0.3, to_world(Vector2(cx + sx * half, y), -0.13), stone, 8)

	# --- les (stezka bez stromů) ---
	var leaf := mat(Color("#3f6b38"), 0.95)
	var dark_leaf := mat(Color("#2f5a2c"), 0.95)
	for f: Dictionary in scenario.get("forests", []):
		var fx0: float = f["x0"]
		var fx1: float = f["x1"]
		var fy0: float = f["y0"]
		var fy1: float = f["y1"]
		var floor_mi := box(root, Vector3(fx1 - fx0, 0.02, fy1 - fy0), to_world(Vector2((fx0 + fx1) / 2.0, (fy0 + fy1) / 2.0), 0.01), mat(Color("#4a6236"), 0.95))
		floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var path: Array = f.get("path", [])
		if path.size() == 2:
			var pw: float = float(path[1]) - float(path[0])
			box(root, Vector3(pw, 0.03, fy1 - fy0), to_world(Vector2((float(path[0]) + float(path[1])) / 2.0, (fy0 + fy1) / 2.0), 0.015), mat(Color("#8a7350"), 0.95))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var yy := fy0 + 0.6
		while yy < fy1:
			var xx := fx0 + 0.6
			while xx < fx1:
				var p := Vector2(xx + rng.randf_range(-0.4, 0.4), yy + rng.randf_range(-0.4, 0.4))
				var on_path := path.size() == 2 and p.x > float(path[0]) - 0.6 and p.x < float(path[1]) + 0.6
				if not on_path:
					var h := rng.randf_range(3.2, 4.6)
					cylinder(root, 0.14, 0.16, 1.2, to_world(p, 0.6), wood, 6)
					cylinder(root, 0.0, 0.85, h - 1.0, to_world(p, 1.0 + (h - 1.0) / 2.0), dark_leaf if rng.randf() < 0.5 else leaf, 7)
				xx += 1.7
			yy += 1.7

	# --- stromy a kameny okolo ---
	var trees: Array = scenario.get("trees", [[-12, -2, 4.5], [-14, 1, 4.0], [-10, 2, 5.0], [-15, -5, 4.2], [-11, 11, 4.6], [-14, 13, 4.0], [12, 13, 4.4], [16, 4, 4.2], [-18, 8, 4.8], [15, -9, 4.6], [-17, -10, 4.4]])
	for t: Array in trees:
		var p := Vector2(t[0], t[1])
		var h: float = t[2]
		cylinder(root, 0.18, 0.2, 1.4, to_world(p, 0.7), wood, 8)
		cylinder(root, 0.0, 1.1, h - 1.0, to_world(p, 1.0 + (h - 1.0) / 2.0), leaf, 8)
	var rocks: Array = scenario.get("rocks", [[10, -3, 1.2, 20], [12, 0, 0.8, 50], [9, 2, 1.0, 10], [-7, -12, 0.7, 35]])
	for r: Array in rocks:
		var sz: float = r[2]
		box(root, Vector3(sz * 1.4, sz, sz * 1.2), to_world(Vector2(r[0], r[1]), sz * 0.35), stone, Vector3(0.2, deg_to_rad(r[3]), 0.1))

	# --- chalupy vsi (zástupné: srub a sedlová střecha) [x, y, šířka, hloubka, otočení°] ---
	var log_wall := mat(Color("#7a5a3c"))
	var thatch := mat(Color("#b39352"))
	for hz: Array in scenario.get("houses", []):
		var w: float = hz[2]
		var d: float = hz[3]
		var rot := Vector3(0.0, deg_to_rad(float(hz[4])), 0.0)
		var c := Vector2(hz[0], hz[1])
		box(root, Vector3(w, 2.0, d), to_world(c, 1.0), log_wall, rot)
		# střecha: dva šikmé hranoly
		for sgn: float in [-1.0, 1.0]:
			var roof := box(root, Vector3(w + 0.4, 0.18, d * 0.62), to_world(c, 2.55), thatch, rot)
			roof.rotate_object_local(Vector3.RIGHT, sgn * deg_to_rad(38.0))
			roof.translate_object_local(Vector3(0.0, 0.0, sgn * d * 0.24))


static func build_banner() -> Node3D:
	var b := Node3D.new()
	var wood := mat(Color("#7a5230"), 0.9)
	cylinder(b, 0.035, 0.035, 3.4, Vector3(0, 1.7, 0), wood, 8)
	box(b, Vector3(0.9, 0.05, 0.05), Vector3(0.45, 3.3, 0), wood)
	box(b, Vector3(0.85, 1.2, 0.03), Vector3(0.45, 2.65, 0), mat(Color("#a3201c"), 0.9))
	box(b, Vector3(0.35, 0.4, 0.04), Vector3(0.45, 2.75, 0.01), mat(Color("#d9bf40"), 0.4, 0.8))
	return b


## Plochý kruh na zemi (aura praporu, výběr jednotky).
static func ring(radius: float, width: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := TorusMesh.new()
	m.inner_radius = radius - width
	m.outer_radius = radius
	m.rings = 64
	m.ring_segments = 4
	mi.mesh = m
	mi.scale = Vector3(1, 0.05, 1)
	mi.material_override = transparent_mat(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func disc(radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = 0.01
	m.radial_segments = 48
	mi.mesh = m
	mi.material_override = transparent_mat(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
