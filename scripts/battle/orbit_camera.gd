extends Camera3D
## Taktická kamera.
## Posun: WASD, šipky, nebo tažení pravým tlačítkem myši.
## Otáčení: tažení prostředním tlačítkem, nebo Q/E. Přiblížení: kolečko.

const MIN_DIST := 12.0
const MAX_DIST := 60.0
const LIMIT := 30.0  # jak daleko od středu bojiště smí cíl kamery odjet (m)

var target := Vector3(0, 0, -1.5)
var yaw := deg_to_rad(27.0)
var pitch := deg_to_rad(41.0)
var distance := 32.0
var _rotating := false
var _panning := false


func _ready() -> void:
	fov = 40.0
	far = 200.0
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					distance = clampf(distance * 0.9, MIN_DIST, MAX_DIST)
					_apply()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					distance = clampf(distance * 1.1, MIN_DIST, MAX_DIST)
					_apply()
			MOUSE_BUTTON_MIDDLE:
				_rotating = mb.pressed
			MOUSE_BUTTON_RIGHT:
				_panning = mb.pressed
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _rotating:
			yaw -= mm.relative.x * 0.006
			pitch = clampf(pitch + mm.relative.y * 0.004, deg_to_rad(15.0), deg_to_rad(80.0))
			_apply()
		elif _panning:
			# "uchop a táhni": zem se pohybuje s kurzorem
			var k := distance * 0.0016
			target -= _right() * mm.relative.x * k
			target -= _back() * mm.relative.y * k
			_apply()


func _input(event: InputEvent) -> void:
	# Puštění tlačítka myši nad panelem rozhraní nesmí nechat kameru "přilepenou".
	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_rotating = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_panning = false


func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1.0
	var turn := 0.0
	if Input.is_key_pressed(KEY_Q):
		turn += 1.0
	if Input.is_key_pressed(KEY_E):
		turn -= 1.0
	if move == Vector2.ZERO and turn == 0.0:
		return
	yaw += turn * delta * 1.5
	target += (_right() * move.x + _back() * move.y) * delta * distance * 0.6
	_apply()


func _right() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))


func _back() -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))


func _apply() -> void:
	target.x = clampf(target.x, -LIMIT, LIMIT)
	target.z = clampf(target.z, -LIMIT, LIMIT)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	position = target + offset
	look_at(target, Vector3.UP)


## Bod na zemi (y = 0) pod kurzorem, nebo null.
func ground_point(screen_pos: Vector2) -> Variant:
	var o := project_ray_origin(screen_pos)
	var d := project_ray_normal(screen_pos)
	if absf(d.y) < 0.0001:
		return null
	var k := -o.y / d.y
	if k < 0.0:
		return null
	return o + d * k
