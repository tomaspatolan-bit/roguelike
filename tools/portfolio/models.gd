extends SceneTree
## 3D models of the heroes and commanders for the portfolio's <model-viewer> (chapter "Mám hru", round 2).
## Each figure is assembled exactly as the game builds it (UnitView: class model, weapon on the hand bone, the
## cavalier on his horse, the commanders' build `scale`), then the game shader is swapped for a PBR material with the
## palette baked in (class row, metal darkening, painted AO as vertex colour) and exported with Godot's glTF writer.
## The only animation left is the idle loop, named `Idle`.
## Run (window needed for the previews):
##   godot --path . --script res://tools/portfolio/models.gd -- <out dir> [ids]
## Writes hrdina-<class>.glb, hrdina-<class>-maska.glb (heroes), hrdina-<class>.png (1200x1200, transparent) and
## models.json (data for hrdinove.json; the class colour share comes from tests/prototype_shots.gd).

const Sim := preload("res://scripts/sim/battle_sim.gd")
const UnitView := preload("res://scripts/battle/unit_view.gd")
const Diorama := preload("res://scripts/battle/diorama.gd")
const PAL_D := "res://art/chars/T_Char_Palette_D.png"
const PAL_ORM := "res://art/chars/T_Char_Palette_ORM.png"
const ROWS := 16
const COLS := 32
const ROLE_FROM := 5   # class colour columns of palette v2 (the same rule as the 40 % test)
const ROLE_TO := 8
const METAL_DARK := 0.18
const AO_STRENGTH := 0.85
const PREVIEW := 1200
const SS := 2          # preview supersampling

# file name → unit key in the simulation
const HEROES := {"tank": "tank", "knez": "knez", "lucistnik": "lucistnik", "jezdec": "jezdec", "asasin": "asasin"}
const COMMANDERS := {"vok": "palic", "kuno": "vudce", "borivoj": "setnik", "jira": "ostrostrelec"}

var out := ""
var info := {}


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	var only: Array = Array(String(a[1]).split(",")) if a.size() > 1 else []
	var d := Sim.load_data("most_pres_reku")
	var sim := Sim.new(d, Sim.default_setup(d))
	var units := {}
	for f: String in HEROES:
		units[f] = sim.by_id(HEROES[f])
	var x := 20.0
	for f: String in COMMANDERS:
		var id: Variant = sim.sandbox_spawn(COMMANDERS[f], Vector2(x, 30.0))
		x += 3.0
		units[f] = sim.by_id(String(id)) if id is String else null
		if units[f] == null:
			for u in sim.units:
				if u.key == COMMANDERS[f]:
					units[f] = u
	UnitView.look_lighting = true
	for f: String in units:
		if not only.is_empty() and not (f in only):
			continue
		var u: Sim.Unit = units[f]
		if u == null:
			print("CHYBA: jednotka ", f)
			continue
		await _one(f, u, false)
		if HEROES.has(f):
			await _one(f, u, true)
		await _preview(f, u)
	var fj := FileAccess.open(out.path_join("models.json"), FileAccess.WRITE)
	fj.store_string(JSON.stringify(info, "  "))
	print("HOTOVO")
	quit(0)


# ---------------------------------------------------------------- textures

## Palette with the unit's row moved to the top (the models' UVs point into row 0, the game shifts by role_row),
## metal darkened like the shader does; for the mask: class columns in the class colour, the rest grey.
func _textures(row: int, mask: bool, class_col: Color) -> Array:
	var d := (load(PAL_D) as Texture2D).get_image()
	var orm := (load(PAL_ORM) as Texture2D).get_image()
	d.decompress()
	orm.decompress()
	d.convert(Image.FORMAT_RGBA8)
	orm.convert(Image.FORMAT_RGBA8)
	var w := d.get_width()
	var h := d.get_height()
	var rh := h / ROWS
	var cw := w / COLS
	var nd := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var no := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var sy := (y + row * rh) % h
		for xx in w:
			var c := d.get_pixel(xx, sy)
			var o := orm.get_pixel(xx, sy)
			if mask:
				var col := int(xx / cw)
				c = class_col if (col >= ROLE_FROM and col <= ROLE_TO) else Color(0.42, 0.43, 0.45)
				o = Color(1.0, 0.85, 0.0)
			else:
				# base *= mix(1, 1 - metal_dark, metal) (character.gdshader), in linear light
				var lin := c.srgb_to_linear()
				var k := lerpf(1.0, 1.0 - METAL_DARK, o.b)
				c = Color(lin.r * k, lin.g * k, lin.b * k).linear_to_srgb()
			nd.set_pixel(xx, y, c)
			# glTF metallicRoughness: G = roughness, B = metallic (the game shader uses METALLIC 0)
			no.set_pixel(xx, y, Color(1.0, o.g, 0.0))
	return [ImageTexture.create_from_image(nd), ImageTexture.create_from_image(no)]


func _material(row: int, mask: bool, class_col: Color) -> StandardMaterial3D:
	var t := _textures(row, mask, class_col)
	var m := StandardMaterial3D.new()
	m.albedo_texture = t[0]
	m.roughness_texture = t[1]
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.roughness = 1.0
	m.metallic = 0.0
	m.vertex_color_use_as_albedo = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m


## Vertex colour = painted AO as the game applies it: mix(1, pow(r, 1/2.2), 0.85), a linear multiplier.
func _bake_ao(mi: MeshInstance3D) -> void:
	var src := mi.mesh as ArrayMesh
	if src == null:
		return
	var dst := ArrayMesh.new()
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var cols: Variant = arr[Mesh.ARRAY_COLOR]
		var n := (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var out_c := PackedColorArray()
		out_c.resize(n)
		for i in n:
			var r := 1.0
			if cols != null and (cols as PackedColorArray).size() == n:
				r = (cols as PackedColorArray)[i].r
			var ao := lerpf(1.0, pow(maxf(r, 0.0), 1.0 / 2.2), AO_STRENGTH)
			out_c[i] = Color(ao, ao, ao, 1.0)
		arr[Mesh.ARRAY_COLOR] = out_c
		var fmt := src.surface_get_format(s) & (Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		dst.add_surface_from_arrays(src.surface_get_primitive_type(s), arr, [], {}, fmt)
	mi.mesh = dst


# ---------------------------------------------------------------- one figure

func _build(u: Sim.Unit) -> Node3D:
	var v := UnitView.new()
	v.setup(u)
	root.add_child(v)
	await process_frame
	await process_frame
	return v


func _one(f: String, u: Sim.Unit, mask: bool) -> void:
	var v: Node3D = await _build(u)
	# drop what is not the figure: contact shade, code-drawn bow string (follows the hand only at runtime)
	for c: Node in v.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.name == "ContactShade" or mi.mesh is CylinderMesh or mi.mesh is PlaneMesh:
			mi.get_parent().remove_child(mi)
			mi.queue_free()
	var mat := _material(u.palette_row, mask, u.color)
	var tris := 0
	for c: Node in v.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		_bake_ao(mi)
		mi.material_override = null
		for s in mi.mesh.get_surface_count():
			mi.mesh.surface_set_material(s, mat)
			tris += mi.mesh.surface_get_array_len(s) / 3 if mi.mesh.surface_get_array_index_len(s) <= 0 else mi.mesh.surface_get_array_index_len(s) / 3
	var idle_len := _idle_only(v, u)
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_scene(v, st)
	var path := out.path_join("hrdina-%s%s.glb" % [f, "-maska" if mask else ""])
	if err == OK:
		err = doc.write_to_filesystem(st, path)
	var size := FileAccess.get_file_as_bytes(path).size() if FileAccess.file_exists(path) else 0
	print("GLB %s err=%d tris=%d idle=%.2fs size=%d KB" % [path.get_file(), err, tris, idle_len, size / 1024])
	if not mask:
		var aabb := AABB()
		var first := true
		for c: Node in v.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			var bb := mi.global_transform * mi.get_aabb()
			aabb = bb if first else aabb.merge(bb)
			first = false
		info[f] = {"key": u.key, "name": u.name, "row": u.palette_row, "color": "#" + u.color.to_html(false),
			"height_m": snappedf(aabb.size.y, 0.01), "width_m": snappedf(maxf(aabb.size.x, aabb.size.z), 0.01),
			"triangles": tris, "idle_s": snappedf(idle_len, 0.01), "scale": [v.scale.x, v.scale.y]}
	v.queue_free()
	await process_frame


## One AnimationPlayer at the figure's root with one animation `Idle` (the class idle; the cavalier's ride and the
## horse's idle in one clip); every other animation and player removed.
func _idle_only(v: Node3D, u: Sim.Unit) -> float:
	var anims: Dictionary = u.base.get("anims", {})
	var want := {}   # player → animation name
	var players := v.find_children("*", "AnimationPlayer", true, false)
	var mount_idle := String((u.base.get("mount_anims", {}) as Dictionary).get("idle", ""))
	var figure: Node = v.get("_figure")
	for p: AnimationPlayer in players:
		# every model GLB carries the whole shared animation library; which player is the horse's: not in the figure
		var on_horse := mount_idle != "" and figure != null and not figure.is_ancestor_of(p)
		var nm := mount_idle if on_horse else String(anims.get("idle", "A_Knight_Idle"))
		if p.has_animation(nm):
			want[p] = nm
	var clip := Animation.new()
	clip.loop_mode = Animation.LOOP_LINEAR
	var length := 0.0
	for p: AnimationPlayer in want:
		var src: Animation = p.get_animation(want[p])
		var base_node: Node = p.get_node(p.root_node)
		var prefix := String(v.get_path_to(base_node))
		length = maxf(length, src.length)
		for t in src.get_track_count():
			var tp := String(src.track_get_path(t))
			var np := tp if prefix == "." else prefix + "/" + tp
			var nt := clip.add_track(src.track_get_type(t))
			clip.track_set_path(nt, NodePath(np))
			clip.track_set_interpolation_type(nt, src.track_get_interpolation_type(t))
			for k in src.track_get_key_count(t):
				clip.track_insert_key(nt, src.track_get_key_time(t, k), src.track_get_key_value(t, k), src.track_get_key_transition(t, k))
	clip.length = length
	for p: AnimationPlayer in players:
		p.get_parent().remove_child(p)
		p.queue_free()
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	var lib := AnimationLibrary.new()
	lib.add_animation("Idle", clip)
	v.add_child(ap)
	ap.add_animation_library("", lib)
	return length


# ---------------------------------------------------------------- preview

## 1200x1200 PNG with a transparent background, three-quarter front view, the game's look (shader, outline, light).
func _preview(f: String, u: Sim.Unit) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(PREVIEW * SS, PREVIEW * SS)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	vp.own_world_3d = true
	root.add_child(vp)
	var stage := Node3D.new()
	vp.add_child(stage)
	var looks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/looks.json"))
	Diorama._environment(stage, looks["morning"])
	for we: Node in stage.find_children("*", "WorldEnvironment", true, false):
		var env := (we as WorldEnvironment).environment
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.fog_enabled = false
		env.volumetric_fog_enabled = false
	var v := UnitView.new()
	v.setup(u)
	stage.add_child(v)
	for c: Node in v.find_children("ContactShade", "", true, false):
		(c as Node3D).visible = false
	await process_frame
	# frame the figure: bounding box of its meshes
	var aabb := AABB()
	var first := true
	for c: Node in v.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if not mi.visible or mi.name == "ContactShade":
			continue
		var bb := mi.global_transform * mi.get_aabb()
		aabb = bb if first else aabb.merge(bb)
		first = false
	var cam := Camera3D.new()
	cam.fov = 26.0
	stage.add_child(cam)
	var center := aabb.get_center()
	var radius := aabb.size.length() * 0.5
	var dist := radius / sin(deg_to_rad(cam.fov * 0.5)) * 1.02
	var dir := Vector3(sin(deg_to_rad(35.0)), 0.32, cos(deg_to_rad(35.0))).normalized()   # front (+Z) turned 35°, slightly above
	cam.position = center + dir * dist
	cam.look_at(center, Vector3.UP)
	cam.current = true
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(out.path_join("hrdina-%s_2x.png" % f))
	print("PNG hrdina-%s.png" % f)
	vp.queue_free()
	await process_frame
