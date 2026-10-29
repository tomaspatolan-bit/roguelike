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
var _oneshot_t := 0.0      # jak dlouho ještě hraje jednorázová animace (útok, zásah, schopnost)
var _prev_atk := 0.0
var _prev_hit := 0.0
var _dead_played := false
var _ragdoll := false
var _foe_body: RigidBody3D = null

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
	body = KNIGHT_SCENE.instantiate() as Node3D
	add_child(body)
	palette_mat = ShaderMaterial.new()
	palette_mat.shader = PALETTE_SHADER
	palette_mat.set_shader_parameter("palette_albedo", PAL_ALBEDO)
	palette_mat.set_shader_parameter("palette_orm", PAL_ORM)
	palette_mat.set_shader_parameter("role_row", float(u.palette_row))
	for n in body.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = palette_mat
	_anim_attack = String(u.base.get("anim_attack", ANIM_ATTACK))
	_anim_ability = String(u.base.get("anim_ability", _anim_attack))
	var players := body.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		anim = players[0] as AnimationPlayer
		for a_name: String in anim.get_animation_list():
			anim.get_animation(a_name).loop_mode = Animation.LOOP_LINEAR if a_name in [ANIM_IDLE, ANIM_WALK] else Animation.LOOP_NONE
		if anim.has_animation(ANIM_IDLE):
			anim.play(ANIM_IDLE)
			anim.seek(randf() * anim.current_animation_length, true)
	if u.key == "jezdec":
		# Jezdec zatím nemá koně: je o kousek větší a rychlejší.
		body.scale = Vector3.ONE * 1.08
	_attach_weapon(String(u.base.get("weapon", "")))


## Zbraň v ruce hrdiny (zástupná primitiva na kosti ruky; finální modely ve fázi 3).
func _attach_weapon(kind: String) -> void:
	if kind == "":
		return
	var skels := body.find_children("*", "Skeleton3D", true, false)
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
		if anim != null and anim.has_animation(ANIM_DEATH):
			# hrdina padne animací a zůstane ležet (poslední snímek)
			if not _dead_played:
				_dead_played = true
				anim.play(ANIM_DEATH, 0.08)
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

	if anim != null:
		# jednorázové animace: útok (náběh u.atk), zásah (náběh u.hit, jen když neútočí)
		if sim_running:
			if u.atk > _prev_atk + 0.01:
				_play_once(_anim_attack, time_scale)
			elif u.hit > _prev_hit + 0.01 and _oneshot_t <= 0.0:
				_play_once(ANIM_HIT, time_scale)
			_oneshot_t -= delta * time_scale
		_prev_atk = u.atk
		_prev_hit = u.hit
		if _oneshot_t > 0.0:
			if not sim_running:
				anim.speed_scale = 0.0
			else:
				anim.speed_scale = time_scale
		else:
			var want := ANIM_WALK if u.moving and sim_running else ANIM_IDLE
			if anim.current_animation != want and anim.has_animation(want):
				anim.play(want, 0.15)
			if not sim_running:
				anim.speed_scale = 1.0 if want == ANIM_IDLE else 0.0
			elif want == ANIM_WALK:
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
	else:
		_ragdoll = _foe_ragdoll(push)


func _knight_ragdoll(push: Vector3) -> bool:
	var skels := body.find_children("*", "Skeleton3D", true, false)
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
