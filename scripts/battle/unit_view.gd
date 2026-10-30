extends Node3D
## Vizuál jedné jednotky. Rytíř = model z GLB s barvou role, nepřítel = kostičkový panák.
## Pozici a stav bere každý snímek ze simulace (sync).

const Sim := preload("res://scripts/sim/battle_sim.gd")
const Field := preload("res://scripts/battle/battlefield.gd")
const KNIGHT_SCENE := preload("res://art/knight/SK_Knight.glb")
const PALETTE_SHADER := preload("res://art/knight/knight_palette.gdshader")
const PAL_ALBEDO := preload("res://art/knight/T_Knight_Palette_D.png")
const PAL_ORM := preload("res://art/knight/T_Knight_Palette_ORM.png")
const ANIM_IDLE := "A_Knight_Idle"
const ANIM_WALK := "A_Knight_Walk"
const ANIM_HIT := "A_Knight_Hit"
const ANIM_DEATH := "A_Knight_Death"
const ANIM_ATTACK := "A_Knight_Attack_Slash"

static var _foe_mats: Dictionary = {}

var unit_id: String
var is_knight := false
var body: Node3D
var anim: AnimationPlayer
var palette_mat: ShaderMaterial
var _fall := 0.0
var _heal_flash := 0.0
var _anim_attack := ANIM_ATTACK
var _anim_ability := ANIM_ATTACK
var _anim_idle := ANIM_IDLE
var _anim_walk := ANIM_WALK
var _anim_hit := ANIM_HIT
var _anim_death := ANIM_DEATH
var _oneshot_t := 0.0      # jak dlouho ještě hraje jednorázová animace (útok, zásah, schopnost)
var _prev_atk := 0.0
var _prev_hit := 0.0
var _dead_played := false
var _ragdoll := false
var _foe_body: RigidBody3D = null
var _figure: Node3D = null          # postava hrdiny (u jezdce jezdec na koni, jinak totéž co body)
# kůň jezdce (mount_model): vlastní kostra a animace, jezdec sedí na kosti `saddle`
var _mount_anim: AnimationPlayer = null
var _mount_names := {"idle": "A_Horse_Idle", "walk": "A_Horse_Walk", "gallop": "A_Horse_Gallop", "hit": "A_Horse_Hit", "death": "A_Horse_Death"}
var _mount_walk_speed := 5.0
var _mount_hit_t := 0.0
# tětiva luku (lučištník): konce v prostoru modelu luku, úseky horní a dolní
var _bow: Node3D = null
var _bow_top := Vector3.ZERO
var _bow_bottom := Vector3.ZERO
var _string_a: MeshInstance3D = null
var _string_b: MeshInstance3D = null
var _skel: Skeleton3D = null
var _hand_r := -1
const STRING_PLANE := 0.2    # jak blízko roviny luku musí být pravá ruka, aby tětivu táhla (m)
const STRING_DRAW_MAX := 0.75   # dál než plné natažení: ruka je pryč (po vypuštění), tětiva rovně

## Ragdoll: kosti, které dostanou fyzikální tělo [kost, poloměr, hmotnost, kloub].
## Kloub: "cone" (kulový s omezením), "hinge" (loket, koleno).
const RAGDOLL := [
	["pelvis", 0.16, 9.0, "cone"], ["spine_02", 0.17, 7.0, "cone"], ["spine_03", 0.17, 6.0, "cone"], ["head", 0.13, 3.0, "cone"],
	["upperarm_l", 0.08, 2.0, "cone"], ["lowerarm_l", 0.07, 1.5, "hinge"],
	["upperarm_r", 0.08, 2.0, "cone"], ["lowerarm_r", 0.07, 1.5, "hinge"],
	["thigh_l", 0.1, 4.0, "cone"], ["calf_l", 0.08, 3.0, "hinge"],
	["thigh_r", 0.1, 4.0, "cone"], ["calf_r", 0.08, 3.0, "hinge"],
]
const RAGDOLL_LAYER := 2   # těla padlých narážejí jen do země (vrstva 1), ne do sebe


func setup(u: Sim.Unit) -> void:
	unit_id = u.id
	name = "Unit_" + u.id
	is_knight = u.side == Sim.SIDE_KNIGHT
	if is_knight:
		_build_knight(u)
	else:
		_build_foe(u)
		if u.leader:
			scale = Vector3.ONE * 1.3   # vůdce nepřátel je vidět z dálky (zástupné, finální vzhled ve fázi 3)


func _build_knight(u: Sim.Unit) -> void:
	# model třídy z dat (`model`), jinak společný rytíř; stejná kostra a paleta pro všechny
	var scene: PackedScene = KNIGHT_SCENE
	var model := String(u.base.get("model", ""))
	if model != "" and ResourceLoader.exists(model):
		scene = load(model) as PackedScene
	var figure := scene.instantiate() as Node3D
	var mount_path := String(u.base.get("mount_model", ""))
	if mount_path != "" and ResourceLoader.exists(mount_path):
		# jezdec na koni: kůň je tělo jednotky, jezdec sedí na kosti `saddle`
		body = (load(mount_path) as PackedScene).instantiate() as Node3D
		add_child(body)
		_mount_setup(u, figure)
	else:
		body = figure
		add_child(body)
	_figure = figure
	palette_mat = ShaderMaterial.new()
	palette_mat.shader = PALETTE_SHADER
	palette_mat.set_shader_parameter("palette_albedo", PAL_ALBEDO)
	palette_mat.set_shader_parameter("palette_orm", PAL_ORM)
	palette_mat.set_shader_parameter("role_row", float(u.palette_row))
	for n in body.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = palette_mat
	_anim_attack = String(u.base.get("anim_attack", ANIM_ATTACK))
	_anim_ability = String(u.base.get("anim_ability", _anim_attack))
	var anims: Dictionary = u.base.get("anims", {})
	_anim_idle = String(anims.get("idle", ANIM_IDLE))
	_anim_walk = String(anims.get("walk", ANIM_WALK))
	_anim_hit = String(anims.get("hit", ANIM_HIT))
	_anim_death = String(anims.get("death", ANIM_DEATH))
	_anim_attack = String(anims.get("attack", _anim_attack))
	_anim_ability = String(anims.get("ability", _anim_ability))
	var players := _figure.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		anim = players[0] as AnimationPlayer
		for a_name: String in anim.get_animation_list():
			anim.get_animation(a_name).loop_mode = Animation.LOOP_LINEAR if a_name in [_anim_idle, _anim_walk] else Animation.LOOP_NONE
		if anim.has_animation(_anim_idle):
			anim.play(_anim_idle)
			anim.seek(randf() * anim.current_animation_length, true)
	var wm := String(u.base.get("weapon_model", ""))
	if wm != "" and ResourceLoader.exists(wm):
		var w := _attach_weapon_model(wm, String(u.base.get("weapon_bone", "hand_r")))
		var bs: Dictionary = u.base.get("bow_string", {})
		if w != null and not bs.is_empty():
			_setup_bow_string(w, bs)
		var om := String(u.base.get("offhand_model", ""))
		if om != "" and ResourceLoader.exists(om):
			_attach_weapon_model(om, String(u.base.get("offhand_bone", "hand_l")))   # druhá zbraň (asasín: dýka v levé)
	else:
		_attach_weapon(String(u.base.get("weapon", "")))


## Kůň: jezdce posadí na kost `saddle` (rider_offset = počátek jezdce od počátku koně v klidové póze,
## souřadnice Godotu) a připraví animace koně (mount_anims, mount_walk_speed = rychlost, při které klus hraje 1×).
func _mount_setup(u: Sim.Unit, rider: Node3D) -> void:
	var names: Dictionary = u.base.get("mount_anims", {})
	for k: String in names:
		_mount_names[k] = String(names[k])
	_mount_walk_speed = float(u.base.get("mount_walk_speed", 5.0))
	var skels := body.find_children("*", "Skeleton3D", true, false)
	var off_a: Array = u.base.get("rider_offset", [0.0, 0.0, 0.0])
	var off := Vector3(float(off_a[0]), float(off_a[1]), float(off_a[2]))
	if skels.is_empty() or (skels[0] as Skeleton3D).find_bone("saddle") < 0:
		rider.position = off
		body.add_child(rider)
	else:
		var skel := skels[0] as Skeleton3D
		var att := BoneAttachment3D.new()
		att.bone_name = "saddle"
		skel.add_child(att)
		var rest := skel.get_bone_global_rest(skel.find_bone("saddle"))
		rider.transform = rest.affine_inverse() * Transform3D(Basis.IDENTITY, off)
		att.add_child(rider)
	var players := body.find_children("*", "AnimationPlayer", true, false)
	for pl in players:
		if pl.get_parent() == body or not rider.is_ancestor_of(pl):
			_mount_anim = pl as AnimationPlayer
			break
	if _mount_anim != null:
		for a_name: String in _mount_anim.get_animation_list():
			var looped: bool = a_name in [_mount_names["idle"], _mount_names["walk"], _mount_names["gallop"]]
			_mount_anim.get_animation(a_name).loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
		if _mount_anim.has_animation(_mount_names["idle"]):
			_mount_anim.play(_mount_names["idle"])
			_mount_anim.seek(randf() * _mount_anim.current_animation_length, true)


## Kůň podle stavu jednotky: klid, klus, cval při Nájezdu, zásah; smrt spouští _start_ragdoll.
func _sync_mount(u: Sim.Unit, delta: float, sim_running: bool, time_scale: float) -> void:
	if _mount_anim == null or not u.alive():
		return
	if sim_running:
		_mount_hit_t -= delta * time_scale
	var want: String = _mount_names["idle"]
	var scale := time_scale
	if u.dashing and sim_running:
		want = _mount_names["gallop"]
	elif u.moving and sim_running:
		want = _mount_names["walk"]
		scale = clampf(u.speed / maxf(_mount_walk_speed, 0.1), 0.5, 2.0) * time_scale
	elif _mount_hit_t > 0.0:
		want = _mount_names["hit"]
	elif u.hit > _prev_hit + 0.01 and sim_running and _mount_anim.has_animation(_mount_names["hit"]):
		want = _mount_names["hit"]
		_mount_hit_t = _mount_anim.get_animation(want).length
	if _mount_anim.current_animation != want and _mount_anim.has_animation(want):
		_mount_anim.play(want, 0.15)
	if not sim_running:
		_mount_anim.speed_scale = 1.0 if want == _mount_names["idle"] else 0.0
	else:
		_mount_anim.speed_scale = maxf(scale, 0.01)


## Zbraň z modelu (GLB z Blenderu, paleta jako postava). Úchop: počátek zbraně je v pěsti
## (0,08 m po ose Y kosti od zápěstí), osa zbraně (+Z v Blenderu, po importu +Y) leží v ose Z kosti ruky.
func _attach_weapon_model(path: String, hand: String) -> Node3D:
	var skels := _figure.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return null
	var skel := skels[0] as Skeleton3D
	if skel.find_bone(hand) < 0:
		return null
	var att := BoneAttachment3D.new()
	att.bone_name = hand
	skel.add_child(att)
	var w := (load(path) as PackedScene).instantiate() as Node3D
	w.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0.08, 0))
	att.add_child(w)
	for mi in w.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = palette_mat
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return w


## Tětiva luku: dva tenké úseky od konců luku. Leží-li pravá ruka u roviny luku za tětivou
## (natahuje), vede tětiva přes ni, jinak je rovně. Řídí to póza animace, ne simulace.
func _setup_bow_string(w: Node3D, bs: Dictionary) -> void:
	var top: Array = bs.get("top", [])
	var bottom: Array = bs.get("bottom", [])
	if top.size() != 3 or bottom.size() != 3:
		return
	_bow = w
	_bow_top = Vector3(float(top[0]), float(top[1]), float(top[2]))
	_bow_bottom = Vector3(float(bottom[0]), float(bottom[1]), float(bottom[2]))
	_skel = _figure.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_hand_r = _skel.find_bone("hand_r")
	var cm := CylinderMesh.new()
	cm.top_radius = 0.007
	cm.bottom_radius = 0.007
	cm.height = 1.0
	cm.radial_segments = 4
	cm.rings = 1
	var mat := Field.mat(Color("#e8e2d0"), 0.9)
	_string_a = MeshInstance3D.new()
	_string_b = MeshInstance3D.new()
	for mi: MeshInstance3D in [_string_a, _string_b]:
		mi.mesh = cm
		mi.material_override = mat
		mi.top_level = true
		add_child(mi)


## Bod, přes který vede tětiva (globálně); Vector3.INF = tětiva rovně.
func bow_pull_point() -> Vector3:
	if _bow == null or _hand_r < 0:
		return Vector3.INF
	var t := _bow.global_transform * _bow_top
	var b := _bow.global_transform * _bow_bottom
	var grip := _bow.global_position
	var hand := _skel.global_transform * _skel.get_bone_global_pose(_hand_r) * Vector3(0, 0.08, 0)
	var axis := t - b
	var n := axis.cross(grip - b)
	if n.length() < 0.0001 or axis.length() < 0.0001:
		return Vector3.INF
	n = n.normalized()
	var off := (hand - b).dot(n)
	if absf(off) > STRING_PLANE:
		return Vector3.INF
	var p := hand - n * off
	var k := (p - b).dot(axis) / axis.length_squared()
	if k < 0.15 or k > 0.85:
		return Vector3.INF
	var on_line := b + axis * k
	var back := on_line - grip   # směr od rukojeti k tětivě (k lučištníkovi)
	var pull := (p - on_line).dot(back.normalized())
	if pull < 0.0 or pull > STRING_DRAW_MAX:
		return Vector3.INF
	return p


func _process(_delta: float) -> void:
	if _bow == null:
		return
	var t := _bow.global_transform * _bow_top
	var b := _bow.global_transform * _bow_bottom
	var p := bow_pull_point()
	if p == Vector3.INF:
		var m := (t + b) * 0.5
		_place_segment(_string_a, t, m)
		_place_segment(_string_b, m, b)
	else:
		_place_segment(_string_a, t, p)
		_place_segment(_string_b, p, b)


static func _place_segment(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		mi.visible = false
		return
	mi.visible = true
	var y := d / l
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y)
	mi.global_transform = Transform3D(Basis(x, y * l, z), (a + b) * 0.5)


## Zbraň v ruce hrdiny (zástupná primitiva na kosti ruky; finální modely ve fázi 3).
func _attach_weapon(kind: String) -> void:
	if kind == "":
		return
	var skels := _figure.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	var skel := skels[0] as Skeleton3D
	var steel := Field.mat(Color("#c9cdd4"), 0.3, 0.85)
	var wood := Field.mat(Color("#6b4a2b"), 0.9)
	var grip := Field.mat(Color("#3a2a1c"), 0.9)
	var hand := "hand_l" if kind == "bow" else "hand_r"
	if skel.find_bone(hand) < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = hand
	skel.add_child(att)
	# kost ruky míří po své ose Y od zápěstí k prstům: čepel pokračuje z pěsti
	match kind:
		"sword":
			Field.box(att, Vector3(0.05, 0.16, 0.05), Vector3(0, 0.08, 0), grip)
			Field.box(att, Vector3(0.22, 0.04, 0.05), Vector3(0, 0.17, 0), steel)
			Field.box(att, Vector3(0.06, 0.78, 0.015), Vector3(0, 0.57, 0), steel)
		"dagger":
			Field.box(att, Vector3(0.04, 0.1, 0.04), Vector3(0, 0.06, 0), grip)
			Field.box(att, Vector3(0.12, 0.03, 0.04), Vector3(0, 0.12, 0), steel)
			Field.box(att, Vector3(0.04, 0.3, 0.012), Vector3(0, 0.28, 0), steel)
		"mace":
			Field.box(att, Vector3(0.045, 0.6, 0.045), Vector3(0, 0.3, 0), wood)
			Field.box(att, Vector3(0.13, 0.16, 0.13), Vector3(0, 0.62, 0), steel)
		"bow":
			# luk napříč pěstí, oblouk ze dvou ramen
			Field.box(att, Vector3(0.035, 0.035, 0.6), Vector3(0, 0.08, 0.28), wood, Vector3(0.25, 0, 0))
			Field.box(att, Vector3(0.035, 0.035, 0.6), Vector3(0, 0.08, -0.28), wood, Vector3(-0.25, 0, 0))
			Field.box(att, Vector3(0.006, 0.006, 1.1), Vector3(0, -0.05, 0), Field.mat(Color("#e8e2d0"), 0.9))
	for mi in att.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Jednorázová animace (útok, zásah, schopnost); po doběhnutí se vrátí klid nebo chůze.
func _play_once(a_name: String, time_scale: float) -> void:
	if anim == null or not anim.has_animation(a_name) or _dead_played:
		return
	anim.play(a_name, 0.06)
	anim.speed_scale = maxf(time_scale, 0.01)
	_oneshot_t = anim.get_animation(a_name).length


## Schopnost hrdiny (volá scéna při události ability).
func play_ability(time_scale: float = 1.0) -> void:
	_play_once(_anim_ability, time_scale)


func _build_foe(u: Sim.Unit) -> void:
	if _foe_mats.is_empty():
		_foe_mats["dark"] = Field.mat(Color("#2b2d31"), 0.8)
		_foe_mats["cloth"] = Field.mat(Color("#7a3029"), 0.9)
		_foe_mats["skin"] = Field.mat(Color("#9c7a5c"), 0.9)
		_foe_mats["steel"] = Field.mat(Color("#8a9099"), 0.35, 0.8)
		_foe_mats["wood"] = Field.mat(Color("#7a5230"), 0.9)
	body = Node3D.new()
	add_child(body)
	Field.box(body, Vector3(0.40, 0.80, 0.22), Vector3(0, 0.40, 0), _foe_mats["dark"])
	Field.box(body, Vector3(0.50, 0.62, 0.30), Vector3(0, 1.10, 0), _foe_mats["cloth"])
	Field.box(body, Vector3(0.26, 0.28, 0.26), Vector3(0, 1.56, 0), _foe_mats["skin"])
	Field.box(body, Vector3(0.34, 0.12, 0.34), Vector3(0, 1.74, 0), _foe_mats["cloth"])
	if u.ranged:
		Field.box(body, Vector3(0.04, 1.1, 0.04), Vector3(-0.34, 1.15, 0.14), _foe_mats["wood"], Vector3(0, 0, 0.15))
	elif u.vs_mounted > 1.0:
		# kopiník: dlouhé kopí skloněné dopředu a kovová přilba
		Field.box(body, Vector3(0.05, 0.05, 2.6), Vector3(0.3, 1.2, 0.7), _foe_mats["wood"], Vector3(-0.12, 0, 0))
		Field.box(body, Vector3(0.08, 0.08, 0.25), Vector3(0.3, 1.35, 1.98), _foe_mats["steel"], Vector3(-0.12, 0, 0))
		Field.box(body, Vector3(0.32, 0.14, 0.32), Vector3(0, 1.76, 0), _foe_mats["steel"])
	else:
		Field.box(body, Vector3(0.05, 0.9, 0.05), Vector3(0.32, 1.15, 0.14), _foe_mats["steel"], Vector3(0.5, 0, 0))


## Natočení: model kouká po +Z, směr v simulaci (x, y) je ve světě (x, -y).
static func yaw_for(face: Vector2) -> float:
	return atan2(face.x, -face.y)


func sync(u: Sim.Unit, delta: float, sim_running: bool, time_scale: float) -> void:
	visible = not u.fled
	if u.fled or _ragdoll:
		return   # ragdoll už řídí fyzika
	var lunge := 0.0
	if u.atk > 0.0:
		lunge = sin(u.atk / 0.25 * PI) * 0.3
	var p := u.pos + u.face * lunge
	position = Field.to_world(p)
	rotation.y = yaw_for(u.face)

	if not u.alive():
		if not _ragdoll and not _dead_played:
			_start_ragdoll(u)
		if _ragdoll:
			if palette_mat != null:
				palette_mat.set_shader_parameter("flash", Color(0, 0, 0, 0))
			return
		if anim != null and anim.has_animation(_anim_death):
			# hrdina padne animací a zůstane ležet (poslední snímek)
			if not _dead_played:
				_dead_played = true
				anim.play(_anim_death, 0.08)
			anim.speed_scale = maxf(time_scale, 0.01) if sim_running else 0.0
		else:
			_fall = minf(1.0, _fall + delta * 2.5)
			rotation.x = -_fall * PI * 0.5
			position.y = -_fall * 0.15
			if anim != null:
				anim.pause()
		if palette_mat != null:
			palette_mat.set_shader_parameter("flash", Color(0, 0, 0, 0))
		return

	_sync_mount(u, delta, sim_running, time_scale)
	if anim != null:
		# jednorázové animace: útok (náběh u.atk), zásah (náběh u.hit, jen když neútočí)
		if sim_running:
			if u.atk > _prev_atk + 0.01:
				_play_once(_anim_attack, time_scale)
			elif u.hit > _prev_hit + 0.01 and _oneshot_t <= 0.0:
				_play_once(_anim_hit, time_scale)
			_oneshot_t -= delta * time_scale
		_prev_atk = u.atk
		_prev_hit = u.hit
		if _oneshot_t > 0.0:
			if not sim_running:
				anim.speed_scale = 0.0
			else:
				anim.speed_scale = time_scale
		else:
			var want := _anim_walk if u.moving and sim_running else _anim_idle
			if anim.current_animation != want and anim.has_animation(want):
				anim.play(want, 0.15)
			if not sim_running:
				anim.speed_scale = 1.0 if want == _anim_idle else 0.0
			elif want == _anim_walk:
				anim.speed_scale = clampf(u.speed / 2.4, 0.8, 2.2) * time_scale
			else:
				anim.speed_scale = time_scale

	_heal_flash = maxf(0.0, _heal_flash - delta)
	if palette_mat != null:
		if u.hit > 0.0:
			palette_mat.set_shader_parameter("flash", Color(1.0, 0.25, 0.2, 0.45))
		elif _heal_flash > 0.0:
			palette_mat.set_shader_parameter("flash", Color(0.4, 1.0, 0.5, _heal_flash))
		else:
			palette_mat.set_shader_parameter("flash", Color(0, 0, 0, 0))
	else:
		var sc := 1.08 if u.hit > 0.0 else 1.0
		body.scale = Vector3.ONE * sc


## Smrt jako ragdoll: hrdina dostane fyzikální kosti a padne podle toho, odkud dostal ránu.
## Nepřítel (kostičkový panák) padne jako jedno tuhé tělo. Když to nejde, zůstává animace smrti.
func _start_ragdoll(u: Sim.Unit) -> void:
	var push := Vector3(-u.face.x, 0.0, u.face.y)   # dozadu od směru, kterým se díval (k nepříteli)
	if is_knight:
		_ragdoll = _knight_ragdoll(push)
		if _mount_anim != null and _mount_anim.has_animation(_mount_names["death"]):
			_mount_anim.play(_mount_names["death"], 0.1)   # kůň padne na bok, jezdec z něj spadne
			_mount_anim.speed_scale = 1.0
	else:
		_ragdoll = _foe_ragdoll(push)


func _knight_ragdoll(push: Vector3) -> bool:
	var skels := _figure.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return false
	var skel := skels[0] as Skeleton3D
	if anim != null:
		anim.pause()
		anim.active = false
	var sim3d := PhysicalBoneSimulator3D.new()
	skel.add_child(sim3d)
	var made: Array[PhysicalBone3D] = []
	for spec: Array in RAGDOLL:
		var bname: String = spec[0]
		var idx := skel.find_bone(bname)
		if idx < 0:
			continue
		var pb := PhysicalBone3D.new()
		pb.name = "PB_" + bname
		pb.bone_name = bname
		pb.mass = float(spec[2])
		pb.linear_damp = 0.6
		pb.angular_damp = 3.0
		pb.friction = 0.9
		pb.collision_layer = RAGDOLL_LAYER
		pb.collision_mask = 1
		# délka kosti = vzdálenost k jejímu prvnímu dítěti (v klidové póze)
		var length := 0.2
		var kids := skel.get_bone_children(idx)
		if not kids.is_empty():
			length = maxf(skel.get_bone_rest(kids[0]).origin.length(), 0.08)
		var r: float = spec[1]
		var cs := CollisionShape3D.new()
		if bname == "head":
			var sp := SphereShape3D.new()
			sp.radius = r
			cs.shape = sp
		else:
			var cap := CapsuleShape3D.new()
			cap.radius = r
			cap.height = maxf(length, r * 2.0 + 0.01)
			cs.shape = cap
		cs.position = Vector3(0, length * 0.5, 0)   # kost míří po své ose Y
		pb.add_child(cs)
		if spec[3] == "hinge":
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
			pb.set("joint_constraints/angular_limit_enabled", true)
			pb.set("joint_constraints/angular_limit_upper", 0.0)
			pb.set("joint_constraints/angular_limit_lower", -120.0)
		else:
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			pb.set("joint_constraints/swing_span", 40.0)
			pb.set("joint_constraints/twist_span", 25.0)
		sim3d.add_child(pb)
		pb.global_transform = skel.global_transform * skel.get_bone_global_pose(idx)
		made.append(pb)
	if made.is_empty():
		sim3d.queue_free()
		return false
	sim3d.physical_bones_start_simulation()
	for pb in made:
		var w := 1.0 if pb.bone_name.begins_with("spine") or pb.bone_name == "head" else 0.5
		pb.apply_central_impulse((push * 3.5 + Vector3(0, 0.8, 0)) * pb.mass * w)
	return true


func _foe_ragdoll(push: Vector3) -> bool:
	if body == null:
		return false
	var rb := RigidBody3D.new()
	rb.collision_layer = RAGDOLL_LAYER
	rb.collision_mask = 1
	rb.mass = 30.0
	rb.angular_damp = 2.0
	rb.linear_damp = 0.4
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(0.5, 1.75, 0.3)
	cs.shape = bx
	cs.position = Vector3(0, 0.88, 0)
	rb.add_child(cs)
	var gt := body.global_transform
	remove_child(body)
	rb.add_child(body)
	rb.top_level = true   # pohyb uzlu jednotky nesmí tělo vracet zpátky
	add_child(rb)
	rb.global_transform = gt
	body.transform = Transform3D.IDENTITY
	_foe_body = rb
	# náraz dozadu a nahoru u hlavy: panák se překotí
	# rychlost místo impulzu: tělo ještě není ve fyzikálním světě, impulz by se ztratil
	rb.linear_velocity = push * 1.2 + Vector3(0, 0.6, 0)
	rb.angular_velocity = Vector3.UP.cross(push).normalized() * 3.5
	return true


func flash_heal() -> void:
	_heal_flash = 0.5
