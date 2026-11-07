extends RefCounted
## Battlefield look "medieval diorama" (style test 2.0s, decision 07.11.2026): the map is a piece of land whose edges
## drop as cliffs into fog (as in Bad North), flat-shaded low-poly, soft light and fog by time of day (data/looks.json),
## a thin dark outline around silhouettes, water with foam. Used for scenarios with a "look" key; the simulation
## does not know about any of it (purely visual, coordinates as in battlefield.gd: Vector3(x, height, -y)).

const ENV_SHADER := preload("res://art/look/env.gdshader")
const WATER_SHADER := preload("res://art/look/water.gdshader")
const FALL_SHADER := preload("res://art/look/fall.gdshader")
const OUTLINE_SHADER := preload("res://art/look/outline.gdshader")

const CELL := 1.0           # terrain grid (m)
const WATER_Y := -0.32      # water surface
const BED_Y := -0.95        # river bed in the middle
const CLIFF_BOTTOM := -11.0

static var _mats := {}


static func load_look(scenario: Dictionary) -> Dictionary:
	var looks: Dictionary = {}
	var f := FileAccess.open("res://data/looks.json", FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			looks = parsed
	var key := String(scenario.get("look", "noon"))
	return looks.get(key, looks.get("noon", {}))


static func c(look: Dictionary, key: String, i: int = -1, fallback: String = "#ff00ff") -> Color:
	var v: Variant = look.get(key, fallback)
	if v is Array:
		v = (v as Array)[clampi(i, 0, (v as Array).size() - 1)] if i >= 0 else (v as Array)[0]
	return Color(String(v))


## Shared environment material for a colour (flat facets, soft wrap light).
static func env_mat(color: Color, vertex_colors: bool = false, sway: float = 0.0, ground_darken: float = 0.0) -> ShaderMaterial:
	var key := "%s|%s|%.2f|%.2f" % [color.to_html(), vertex_colors, sway, ground_darken]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = ENV_SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("use_vertex_color", vertex_colors)
	m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("ground_darken", ground_darken)
	_mats[key] = m
	return m


# ------------------------------------------------------------------ noise helpers (deterministic, no textures)

static func _hash(x: float, y: float) -> float:
	return fposmod(sin(x * 127.1 + y * 311.7) * 43758.5453, 1.0)


static func _noise(x: float, y: float) -> float:
	var ix := floorf(x)
	var iy := floorf(y)
	var fx := x - ix
	var fy := y - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := lerpf(_hash(ix, iy), _hash(ix + 1.0, iy), fx)
	var b := lerpf(_hash(ix, iy + 1.0), _hash(ix + 1.0, iy + 1.0), fx)
	return lerpf(a, b, fy)


# ------------------------------------------------------------------ build

static func build(root: Node3D, scenario: Dictionary, camera_defaults: Dictionary = {}) -> void:
	var look := load_look(scenario)
	_environment(root, look)
	var area := _area(scenario, camera_defaults)
	var river: Dictionary = scenario.get("river", {})
	var terrain := _terrain(root, scenario, look, area, river)
	if not river.is_empty():
		_water(root, look, area, river, terrain)
		_crossings(root, look, river)
	_vegetation(root, scenario, look, area, river)
	_camp(root, scenario, look)


## The diorama's extent (sim coordinates): scenario "diorama" [x0, x1, y0, y1], otherwise the camera's pan bounds
## plus what the camera sees around them.
static func _area(scenario: Dictionary, camera_defaults: Dictionary) -> Rect2:
	if scenario.has("diorama"):
		var d: Array = scenario["diorama"]
		return Rect2(float(d[0]), float(d[2]), float(d[1]) - float(d[0]), float(d[3]) - float(d[2]))
	var cam: Dictionary = camera_defaults.duplicate()
	cam.merge(scenario.get("camera", {}), true)
	var b: Array = cam.get("bounds", [-6, 6, 0, 10])
	return Rect2(float(b[0]) - 18.0, float(b[2]) - 10.0, float(b[1]) - float(b[0]) + 36.0, float(b[3]) - float(b[2]) + 28.0)


static func _environment(root: Node3D, look: Dictionary) -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = c(look, "bg", 0)
	sky_mat.sky_horizon_color = c(look, "bg", 1)
	sky_mat.ground_horizon_color = c(look, "fog")
	sky_mat.ground_bottom_color = c(look, "fog").darkened(0.08)
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = c(look, "ambient")
	env.ambient_light_energy = float(look.get("ambient_energy", 0.6))
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = {"agx": Environment.TONE_MAPPER_AGX, "filmic": Environment.TONE_MAPPER_FILMIC, "aces": Environment.TONE_MAPPER_ACES, "linear": Environment.TONE_MAPPER_LINEAR}.get(String(look.get("tonemap", "filmic")), Environment.TONE_MAPPER_FILMIC)
	env.tonemap_exposure = float(look.get("exposure", 1.0))
	env.ssao_enabled = bool(look.get("ssao", false))
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.2
	env.ssao_light_affect = 0.15
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = c(look, "fog")
	env.fog_density = float(look.get("fog_density", 0.012))
	env.fog_sky_affect = 0.0
	env.fog_height = -1.5
	env.fog_height_density = 0.45
	var g: Array = look.get("grade", [1.0, 1.0, 1.0])
	env.adjustment_enabled = true
	env.adjustment_saturation = float(g[0])
	env.adjustment_contrast = float(g[1])
	env.adjustment_brightness = float(g[2])
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	var s: Array = look.get("sun", [-52, 32])
	sun.rotation_degrees = Vector3(float(s[0]), float(s[1]), 0)
	sun.light_color = c(look, "sun_color")
	sun.light_energy = float(look.get("sun_energy", 1.4))
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.shadow_opacity = 0.82
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 75.0
	root.add_child(sun)


## Height of the land at a sim point (river channel with banks, gentle undulation).
static func _height(p: Vector2, river: Dictionary) -> float:
	var h := (_noise(p.x * 0.12, p.y * 0.12) - 0.5) * 0.18 + (_noise(p.x * 0.4 + 7.0, p.y * 0.4) - 0.5) * 0.025
	if river.is_empty():
		return h
	var lo := float(river["y0"])
	var hi := float(river["y1"])
	if p.y > lo - 0.5 and p.y < hi + 0.5:
		var t := minf(p.y - (lo - 0.5), (hi + 0.5) - p.y)   # distance into the channel from the nearest bank top
		var bed := BED_Y
		for cr: Dictionary in river.get("crossings", []):
			if String(cr.get("kind", "")) == "brod" and p.x > float(cr["x0"]) - 0.5 and p.x < float(cr["x1"]) + 0.5:
				bed = WATER_Y - 0.12   # ford: shallow
		h = lerpf(h, bed, smoothstep(0.0, 1.3, t))
	return h


## Terrain: a grid of flat-shaded triangles with vertex colours, edges pushed out and in by noise, corners cut,
## and cliff walls down into the fog. Returns {"edge_x": [left x at the river, right x at the river]}.
static func _terrain(root: Node3D, scenario: Dictionary, look: Dictionary, area: Rect2, river: Dictionary) -> Dictionary:
	var nx := int(ceilf(area.size.x / CELL))
	var ny := int(ceilf(area.size.y / CELL))
	var lo := float(river.get("y0", 1e9))
	var hi := float(river.get("y1", -1e9))
	# grid points (sim x, sim y, height); the outer ring moves along its outward normal
	var pts := []
	for j in ny + 1:
		var row := []
		for i in nx + 1:
			var p := Vector2(area.position.x + i * CELL, area.position.y + j * CELL)
			var edge := i == 0 or j == 0 or i == nx or j == ny
			if edge:
				var out := Vector2(-1.0 if i == 0 else (1.0 if i == nx else 0.0), -1.0 if j == 0 else (1.0 if j == ny else 0.0))
				var in_river := p.y > lo - 1.2 and p.y < hi + 1.2 and (i == 0 or i == nx)
				var amp := 0.0 if in_river else 0.9
				var off := (_noise(p.x * 0.35 + 3.0, p.y * 0.35) - 0.45) * amp
				# cut the corners (rounded island)
				var ci := mini(i, nx - i)
				var cj := mini(j, ny - j)
				var corner := 0.0
				if ci <= 4 and cj <= 4:
					corner = (4.0 - float(maxi(ci, cj))) * 0.55 + 0.6
				p += out.normalized() * (off - corner)
			row.append(p)
		pts.append(row)
	var g0 := c(look, "ground", 0)
	var g1 := c(look, "ground", 1)
	var gd := c(look, "ground_dark")
	var bank := c(look, "bank")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hf := func(p: Vector2) -> float:
		return _height(p, river)
	for j in ny:
		for i in nx:
			var a: Vector2 = pts[j][i]
			var b: Vector2 = pts[j][i + 1]
			var cc: Vector2 = pts[j + 1][i + 1]
			var d: Vector2 = pts[j + 1][i]
			var ha: float = hf.call(a)
			var hb: float = hf.call(b)
			var hc: float = hf.call(cc)
			var hd: float = hf.call(d)
			var flip := (i + j) % 2 == 0
			var tris := [[a, ha, b, hb, cc, hc], [a, ha, cc, hc, d, hd]] if flip else [[a, ha, b, hb, d, hd], [b, hb, cc, hc, d, hd]]
			for t: Array in tris:
				var ctr: Vector2 = (t[0] + t[2] + t[4]) / 3.0
				var hmin := minf(t[1], minf(t[3], t[5]))
				var col: Color
				if hmin < -0.12 and ctr.y > lo - 0.9 and ctr.y < hi + 0.9:
					col = bank.darkened(clampf((-hmin - 0.12) * 0.2, 0.0, 0.15))   # bank and bed
				else:
					var n := _noise(ctr.x * 0.22, ctr.y * 0.22)
					col = g0.lerp(g1, smoothstep(0.35, 0.65, n))
					if _noise(ctr.x * 0.6 + 11.0, ctr.y * 0.6) > 0.78:
						col = col.lerp(gd, 0.35)
					col = col.lightened((_hash(ctr.x, ctr.y) - 0.5) * 0.03)
				var v0 := Vector3(t[0].x, t[1], -t[0].y)
				var v1 := Vector3(t[2].x, t[3], -t[2].y)
				var v2 := Vector3(t[4].x, t[5], -t[4].y)
				var nrm := (v2 - v0).cross(v1 - v0).normalized()
				if nrm.y < 0.0:
					nrm = -nrm
					var tmp := v1
					v1 = v2
					v2 = tmp
				for v: Vector3 in [v0, v2, v1]:
					st.set_color(col)
					st.set_normal(nrm)
					st.add_vertex(v)
	# cliff walls along the outer ring (counter-clockwise seen from above)
	var ring: Array = []
	for i in nx + 1:
		ring.append(pts[0][i])
	for j in range(1, ny + 1):
		ring.append(pts[j][nx])
	for i in range(nx - 1, -1, -1):
		ring.append(pts[ny][i])
	for j in range(ny - 1, 0, -1):
		ring.append(pts[j][0])
	var ctr_area := area.get_center()
	var cl0 := c(look, "cliff", 0)
	var cl1 := c(look, "cliff", 1)
	var cl2 := c(look, "cliff", 2)
	var levels := [[0.0, 0.0, cl0], [-0.45, 0.22, cl0], [-0.6, 0.18, cl1], [-3.4, 0.35, cl1], [-3.6, 0.1, cl2], [CLIFF_BOTTOM, -0.9, cl2]]
	for k in ring.size():
		var p0: Vector2 = ring[k]
		var p1: Vector2 = ring[(k + 1) % ring.size()]
		var o0 := (p0 - ctr_area).normalized()
		var o1 := (p1 - ctr_area).normalized()
		var top0: float = hf.call(p0)
		var top1: float = hf.call(p1)
		for li in levels.size() - 1:
			var la: Array = levels[li]
			var lb: Array = levels[li + 1]
			var jit0 := (_hash(p0.x + li, p0.y) - 0.5) * 0.25
			var jit1 := (_hash(p1.x + li, p1.y) - 0.5) * 0.25
			var a0 := Vector3(p0.x + o0.x * (float(la[1]) + jit0), (top0 if li == 0 else 0.0) + float(la[0]), -(p0.y + o0.y * (float(la[1]) + jit0)))
			var a1 := Vector3(p1.x + o1.x * (float(la[1]) + jit1), (top1 if li == 0 else 0.0) + float(la[0]), -(p1.y + o1.y * (float(la[1]) + jit1)))
			var b0 := Vector3(p0.x + o0.x * float(lb[1]), float(lb[0]) + minf(top0, 0.0) * (1.0 if li == 0 else 0.0), -(p0.y + o0.y * float(lb[1])))
			var b1 := Vector3(p1.x + o1.x * float(lb[1]), float(lb[0]) + minf(top1, 0.0) * (1.0 if li == 0 else 0.0), -(p1.y + o1.y * float(lb[1])))
			var col: Color = la[2]
			col = col.lightened((_hash(p0.x * 3.0, p0.y + li) - 0.5) * 0.06)
			for tri: Array in [[a0, b0, b1], [a0, b1, a1]]:
				var nrm: Vector3 = (tri[2] - tri[0]).cross(tri[1] - tri[0]).normalized()
				var outw := Vector3(o0.x, 0.0, -o0.y)
				if nrm.dot(outw) < 0.0:
					nrm = -nrm
					tri = [tri[0], tri[2], tri[1]]
				for v: Vector3 in [tri[0], tri[2], tri[1]]:
					st.set_color(col)
					st.set_normal(nrm)
					st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = env_mat(Color.WHITE, true)
	mi.name = "Terrain"
	root.add_child(mi)
	var edge_x := [area.position.x, area.end.x]
	return {"edge_x": edge_x}


static func _water(root: Node3D, look: Dictionary, area: Rect2, river: Dictionary, terrain: Dictionary) -> void:
	var lo := float(river["y0"]) - 0.6
	var hi := float(river["y1"]) + 0.6
	var x0: float = terrain["edge_x"][0]
	var x1: float = terrain["edge_x"][1]
	var m := ShaderMaterial.new()
	m.shader = WATER_SHADER
	m.set_shader_parameter("shallow", c(look, "water", 0))
	m.set_shader_parameter("deep", c(look, "water", 1))
	m.set_shader_parameter("foam", c(look, "water", 2))
	m.set_shader_parameter("flow", Vector2(1.0, 0.0))
	var w := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(x1 - x0, hi - lo)
	pm.subdivide_width = 0
	w.mesh = pm
	w.position = Vector3((x0 + x1) / 2.0, WATER_Y, -(lo + hi) / 2.0)
	w.material_override = m
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.name = "Water"
	root.add_child(w)
	# falls off both edges of the diorama
	var fm := ShaderMaterial.new()
	fm.shader = FALL_SHADER
	fm.set_shader_parameter("water", c(look, "water", 0).lightened(0.1))
	fm.set_shader_parameter("foam", c(look, "water", 2))
	for side: float in [-1.0, 1.0]:
		var f := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(hi - lo - 0.6, 7.0)
		f.mesh = q
		var x := x0 if side < 0.0 else x1
		f.position = Vector3(x + side * 0.12, WATER_Y - 3.5, -(lo + hi) / 2.0)
		f.rotation_degrees = Vector3(0, 90.0 * side, 0)
		f.material_override = fm
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(f)


## Bridge (planks, rails, stone piers), footbridge, ford stones.
static func _crossings(root: Node3D, look: Dictionary, river: Dictionary) -> void:
	var lo := float(river["y0"])
	var hi := float(river["y1"])
	var wood := c(look, "trunk").lightened(0.08)
	var stone := c(look, "rock")
	for cr: Dictionary in river.get("crossings", []):
		var x0 := float(cr["x0"])
		var x1 := float(cr["x1"])
		var cx := (x0 + x1) / 2.0
		var half := (x1 - x0) / 2.0
		var kind := String(cr.get("kind", "most"))
		if kind == "brod":
			var rng := RandomNumberGenerator.new()
			rng.seed = 11
			var y := lo + 0.2
			while y < hi:
				var p := Vector2(rng.randf_range(x0 + 0.3, x1 - 0.3), y)
				_rock(root, p, rng.randf_range(0.25, 0.45), stone, rng, WATER_Y)
				y += rng.randf_range(0.35, 0.6)
			continue
		var length := hi - lo + 2.0
		var deck_y := 0.18
		# planks across the river, each a little different
		var n := int(length / 0.42)
		for k in n:
			var y := lo - 1.0 + (k + 0.5) * (length / n)
			var pc := c(look, "planks", -1, "#b48a5c").darkened(_hash(float(k), 3.0) * 0.18)
			var plank := _box(root, Vector3(half * 2.3, 0.1, length / n - 0.05), Vector3(cx, deck_y + (_hash(float(k), 9.0) - 0.5) * 0.03, -y), env_mat(pc))
			plank.rotation.y = (_hash(float(k), 5.0) - 0.5) * 0.05
		for sx: float in [-1.0, 1.0]:
			# beams under the planks, rails and posts
			_box(root, Vector3(0.22, 0.22, length), Vector3(cx + sx * half * 0.85, deck_y - 0.15, -(lo + hi) / 2.0), env_mat(wood.darkened(0.25)))
			if kind == "most":
				_box(root, Vector3(0.1, 0.1, length - 0.4), Vector3(cx + sx * half * 1.12, deck_y + 0.75, -(lo + hi) / 2.0), env_mat(wood))
				var yy := lo - 0.8
				while yy <= hi + 0.85:
					_box(root, Vector3(0.14, 0.85, 0.14), Vector3(cx + sx * half * 1.12, deck_y + 0.4, -yy), env_mat(wood.darkened(0.12)))
					yy += (length - 0.4) / 4.0
			# stone piers in the water
			for py: float in [lo + 1.2, hi - 1.2]:
				var pier := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.38
				cm.bottom_radius = 0.48
				cm.height = 1.3
				cm.radial_segments = 7
				pier.mesh = cm
				pier.position = Vector3(cx + sx * half * 0.85, WATER_Y - 0.25, -py)
				pier.material_override = env_mat(stone)
				root.add_child(pier)


static func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _sphere(parent: Node3D, r: float, pos: Vector3, m: Material, segs: int = 7, rings: int = 4, squash: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = segs
	sm.rings = rings
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	mi.scale = squash
	parent.add_child(mi)
	return mi


static func _rock(parent: Node3D, p: Vector2, size: float, col: Color, rng: RandomNumberGenerator, base_y: float = 0.0) -> void:
	# a boulder and sometimes a smaller one leaning on it
	for k in (2 if rng.randf() < 0.5 else 1):
		var sz := size * (1.0 if k == 0 else 0.55)
		var off := Vector3.ZERO if k == 0 else Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * size * 0.9
		var r := _sphere(parent, sz, Vector3(p.x, base_y + sz * 0.42, -p.y) + off, env_mat(col.darkened(rng.randf() * 0.1)), 7, 4,
			Vector3(rng.randf_range(1.0, 1.3), rng.randf_range(0.75, 1.0), rng.randf_range(0.9, 1.2)))
		r.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))


## A round deciduous tree (trunk and two or three crowns) or a conifer (stacked cones).
static func _tree(parent: Node3D, p: Vector2, h: Vector2, look: Dictionary, rng: RandomNumberGenerator, conifer: bool) -> void:
	var t := Node3D.new()
	t.position = Vector3(p.x, h.y, -p.y)
	t.rotation.y = rng.randf() * TAU
	var s := rng.randf_range(0.85, 1.25)
	t.scale = Vector3.ONE * s
	parent.add_child(t)
	var leaf := c(look, "leaves", rng.randi_range(0, 2))
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 0.16
	cm.height = 1.4 if not conifer else 1.0
	cm.radial_segments = 6
	trunk.mesh = cm
	trunk.position = Vector3(0, cm.height / 2.0, 0)
	trunk.material_override = env_mat(c(look, "trunk"))
	t.add_child(trunk)
	if conifer:
		for k in 3:
			var cone := MeshInstance3D.new()
			var cc := CylinderMesh.new()
			cc.top_radius = 0.0
			cc.bottom_radius = 1.05 - k * 0.27
			cc.height = 1.6 - k * 0.2
			cc.radial_segments = 7
			cone.mesh = cc
			cone.position = Vector3(0, 1.3 + k * 0.85, 0)
			cone.material_override = env_mat(leaf.darkened(0.05), false, 0.04)
			t.add_child(cone)
	else:
		var n := rng.randi_range(2, 3)
		for k in n:
			var r := rng.randf_range(0.75, 1.05) - k * 0.12
			var off := Vector3(rng.randf_range(-0.35, 0.35), 1.7 + k * 0.6, rng.randf_range(-0.35, 0.35))
			var crown := _sphere(t, r, off, env_mat(leaf.lightened(k * 0.04), false, 0.05), 8, 5)
			crown.scale = Vector3(1.0, rng.randf_range(0.85, 1.0), 1.0)


## Trees, bushes, rocks and grass outside the play area, thicker towards the edges; scenario "trees"/"rocks" too.
static func _vegetation(root: Node3D, scenario: Dictionary, look: Dictionary, area: Rect2, river: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(String(scenario.get("name", "")).hash()) & 0xffff
	var cam: Dictionary = scenario.get("camera", {})
	var b: Array = cam.get("bounds", [-6, 6, 0, 10])
	var play := Rect2(float(b[0]) - 4.0, float(b[2]) - 6.0, float(b[1]) - float(b[0]) + 8.0, float(b[3]) - float(b[2]) + 9.0)
	var lo := float(river.get("y0", 1e9))
	var hi := float(river.get("y1", -1e9))
	var keep_clear: Array = []   # enemy positions and deployment
	for e: Variant in scenario.get("enemies", []):
		if e is Array and (e as Array).size() >= 3:
			keep_clear.append(Vector2(float(e[1]), float(e[2])))
	var step := 2.1
	var y := area.position.y + 1.5
	while y < area.end.y - 1.0:
		var x := area.position.x + 1.5
		while x < area.end.x - 1.0:
			var p := Vector2(x + rng.randf_range(-0.8, 0.8), y + rng.randf_range(-0.8, 0.8))
			x += step
			if p.y > lo - 1.4 and p.y < hi + 1.4:
				continue
			var dx := maxf(play.position.x - p.x, p.x - play.end.x)
			var dy := maxf(play.position.y - p.y, p.y - play.end.y)
			var dist := maxf(dx, dy)
			var near_enemy := false
			for q: Vector2 in keep_clear:
				if q.distance_to(p) < 3.0:
					near_enemy = true
			var edge_d := minf(minf(p.x - area.position.x, area.end.x - p.x), minf(p.y - area.position.y, area.end.y - p.y))
			if edge_d < 1.4:
				continue
			var chance := clampf(0.08 + dist * 0.09, 0.0, 0.7) if dist > 0.0 else 0.02
			if near_enemy:
				chance = 0.0
			var r := rng.randf()
			var hgt := _height(p, river)
			if r < chance:
				_tree(root, p, Vector2(0, hgt), look, rng, _noise(p.x * 0.15 + 40.0, p.y * 0.15) > 0.58)
			elif r < chance + 0.035:
				_rock(root, p, rng.randf_range(0.25, 0.5), c(look, "rock"), rng, hgt)
			elif r < chance + 0.2:
				# bush: a few small spheres
				var bm := env_mat(c(look, "leaves", 1).lightened(0.06), false, 0.03)
				for k in rng.randi_range(2, 4):
					_sphere(root, rng.randf_range(0.28, 0.45), Vector3(p.x + rng.randf_range(-0.4, 0.4), hgt + 0.2, -(p.y + rng.randf_range(-0.4, 0.4))), bm, 7, 4)
		y += step
	for t: Array in scenario.get("trees", []):
		var tp := Vector2(t[0], t[1])
		_tree(root, tp, Vector2(0, _height(tp, river)), look, rng, false)
	for rr: Array in scenario.get("rocks", []):
		var rp := Vector2(rr[0], rr[1])
		_rock(root, rp, float(rr[2]) * 0.5, c(look, "rock"), rng, _height(rp, river))
	_grass(root, look, area, river, rng, play)


## Grass tufts (one MultiMesh): small dark-green blades scattered on the land, fewer in the play area.
static func _grass(root: Node3D, look: Dictionary, area: Rect2, river: Dictionary, rng: RandomNumberGenerator, play: Rect2) -> void:
	var tuft := CylinderMesh.new()
	tuft.top_radius = 0.0
	tuft.bottom_radius = 0.055
	tuft.height = 0.26
	tuft.radial_segments = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tuft
	var xs: Array = []
	var lo := float(river.get("y0", 1e9))
	var hi := float(river.get("y1", -1e9))
	for k in 500:
		var p := Vector2(rng.randf_range(area.position.x + 1.0, area.end.x - 1.0), rng.randf_range(area.position.y + 1.0, area.end.y - 1.0))
		if p.y > lo - 0.9 and p.y < hi + 0.9:
			continue
		if play.has_point(p) and rng.randf() < 0.55:
			continue
		var tr := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.4)), Vector3(p.x, _height(p, river) + 0.12, -p.y))
		xs.append(tr)
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = env_mat(c(look, "ground", 1).darkened(0.18), false, 0.08)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)


## Brigand camp: tents and a fire by the group named like a camp (pods), purely decoration.
static func _camp(root: Node3D, scenario: Dictionary, look: Dictionary) -> void:
	var pods: Array = scenario.get("pods", [])
	var camp_pod := -1
	for i in pods.size():
		if String((pods[i] as Dictionary).get("name", "")).to_lower().contains("camp"):
			camp_pod = i
	if camp_pod < 0:
		return
	var sum := Vector2.ZERO
	var n := 0
	var maxy := -1e9
	for e: Variant in scenario.get("enemies", []):
		if e is Array and (e as Array).size() >= 4 and e[3] is Dictionary and int((e[3] as Dictionary).get("pod", -1)) == camp_pod:
			sum += Vector2(float(e[1]), float(e[2]))
			maxy = maxf(maxy, float(e[2]))
			n += 1
	if n == 0:
		return
	var ctr := sum / n
	var canvas := Color("#d8cdb4")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 3:
		var p := ctr + Vector2(-3.2 + k * 3.2, 2.6 + rng.randf_range(-0.5, 0.5))
		var tent := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(1.9, 1.4, 2.2)
		tent.mesh = pm
		tent.position = Vector3(p.x, 0.7, -p.y)
		tent.rotation.y = rng.randf_range(-0.4, 0.4)
		tent.material_override = env_mat(canvas.darkened(k * 0.08))
		root.add_child(tent)
	# fire: stones in a ring and a warm glow
	for k in 7:
		var a := TAU * k / 7.0
		_sphere(root, 0.14, Vector3(ctr.x + cos(a) * 0.5, 0.06, -(ctr.y + sin(a) * 0.5)), env_mat(c(look, "rock").darkened(0.15)), 5, 3)
	var fire := OmniLight3D.new()
	fire.light_color = Color("#ffb060")
	fire.light_energy = 1.2
	fire.omni_range = 4.0
	fire.position = Vector3(ctr.x, 0.5, -ctr.y)
	root.add_child(fire)
	var flame := MeshInstance3D.new()
	var fc := CylinderMesh.new()
	fc.top_radius = 0.0
	fc.bottom_radius = 0.22
	fc.height = 0.55
	fc.radial_segments = 5
	flame.mesh = fc
	flame.position = Vector3(ctr.x, 0.3, -ctr.y)
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color("#ffae4a")
	flame.material_override = fmat
	root.add_child(flame)


## Thin dark outline around silhouettes: a full-screen quad attached to the camera.
static func attach_outline(cam: Camera3D) -> MeshInstance3D:
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2.0, 2.0)
	q.mesh = qm
	q.extra_cull_margin = 16384.0
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = OUTLINE_SHADER
	m.render_priority = 100
	q.material_override = m
	q.name = "Outline"
	cam.add_child(q)
	q.position = Vector3(0, 0, -1.0)
	return q
