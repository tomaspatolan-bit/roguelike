extends Camera3D
## Taktická kamera: kolečko = přiblížení, prostřední tlačítko = otáčení,
## šipky = posun, Q/E = otočení.

var target := Vector3(0, 0, -1.5)
var yaw := deg_to_rad(27.0)
var pitch := deg_to_rad(41.0)
var distance := 32.0
var _dragging := false


func _ready() -> void:
	fov = 40.0
	far = 200.0
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			distance = clampf(distance * 0.9, 12.0, 60.0)
			_apply()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			distance = clampf(distance * 1.1, 12.0, 60.0)
			_apply()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		yaw -= mm.relative.x * 0.006
		pitch = clampf(pitch + mm.relative.y * 0.004, deg_to_rad(15.0), deg_to_rad(80.0))
		_apply()


func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		move.y += 1.0
	var turn := 0.0
	if Input.is_key_pressed(KEY_Q):
		turn += 1.0
	if Input.is_key_pressed(KEY_E):
		turn -= 1.0
	if move == Vector2.ZERO and turn == 0.0:
		return
	yaw += turn * delta * 1.5
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var back := Vector3(sin(yaw), 0, cos(yaw))
	target += (right * move.x + back * move.y) * delta * distance * 0.6
	_apply()


func _apply() -> void:
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
