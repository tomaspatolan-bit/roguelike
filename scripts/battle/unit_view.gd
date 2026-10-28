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

static var _foe_mats: Dictionary = {}

var unit_id: String
var is_knight := false
var body: Node3D
var anim: AnimationPlayer
var palette_mat: ShaderMaterial
var _fall := 0.0
var _heal_flash := 0.0


func setup(u: Sim.Unit) -> void:
	unit_id = u.id
	name = "Unit_" + u.id
	is_knight = u.side == Sim.SIDE_KNIGHT
	if is_knight:
		_build_knight(u)
	else:
		_build_foe(u)


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
	var players := body.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		anim = players[0] as AnimationPlayer
		for a_name: String in [ANIM_IDLE, ANIM_WALK]:
			if anim.has_animation(a_name):
				anim.get_animation(a_name).loop_mode = Animation.LOOP_LINEAR
		if anim.has_animation(ANIM_IDLE):
			anim.play(ANIM_IDLE)
			anim.seek(randf() * anim.current_animation_length, true)
	if u.key == "jezdec":
		# Jezdec zatím nemá koně: je o kousek větší a rychlejší.
		body.scale = Vector3.ONE * 1.08


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
	else:
		Field.box(body, Vector3(0.05, 0.9, 0.05), Vector3(0.32, 1.15, 0.14), _foe_mats["steel"], Vector3(0.5, 0, 0))


## Natočení: model kouká po +Z, směr v simulaci (x, y) je ve světě (x, -y).
static func yaw_for(face: Vector2) -> float:
	return atan2(face.x, -face.y)


func sync(u: Sim.Unit, delta: float, sim_running: bool, time_scale: float) -> void:
	var lunge := 0.0
	if u.atk > 0.0:
		lunge = sin(u.atk / 0.25 * PI) * 0.3
	var p := u.pos + u.face * lunge
	position = Field.to_world(p)
	rotation.y = yaw_for(u.face)

	if not u.alive():
		_fall = minf(1.0, _fall + delta * 2.5)
		rotation.x = -_fall * PI * 0.5
		position.y = -_fall * 0.15
		if anim != null:
			anim.pause()
		if palette_mat != null:
			palette_mat.set_shader_parameter("flash", Color(0, 0, 0, 0))
		return

	if anim != null:
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


func flash_heal() -> void:
	_heal_flash = 0.5
