extends Camera3D
## Taktická kamera s pevným úhlem (rozhodnutí 30.10.2026): úhel a výchozí výřez určuje mapa,
## hráč výřez jen posouvá (WASD, šipky, myš u okraje obrazovky) v hranicích mapy
## a trochu přibližuje kolečkem. Otáčet nejde, pravé tlačítko patří rozkazům.
## Nastavení: `camera` v units.json (výchozí) a ve scénáři (přepíše jednotlivé klíče), viz `configure`.

const EDGE_PX := 10.0        # jak blízko okraje okna musí být myš, aby se výřez posouval

var target := Vector3(0, 0, -1.5)
var yaw := deg_to_rad(25.0)
var pitch := deg_to_rad(50.0)
var distance := 30.0
var zoom_min := 24.0
var zoom_max := 36.0
var pan_speed := 0.6           # podíl vzdálenosti kamery za sekundu
var bounds := Rect2(-30, -30, 60, 60)   # kde smí být střed výřezu (x, y simulace)
var edge_scroll := true
static var edge_scroll_all := true   # testy ho vypínají (myš může ležet u okraje okna a posouvat snímky)


func _ready() -> void:
	fov = 40.0
	far = 200.0
	_apply()


## Nastaví kameru podle mapy: výchozí hodnoty `defaults` (units.json `camera`) přepíše scénář `sc`.
## Klíče: `target` [x, y], `yaw` a `pitch` (°), `distance`, `zoom` [min, max], `bounds` [x0, x1, y0, y1],
## `pan_speed`. Stejné x0 a x1 (nebo y0 a y1) = výřez se tím směrem nehýbe.
func configure(defaults: Dictionary, sc: Dictionary) -> void:
	var c := defaults.duplicate()
	c.merge(sc, true)
	var t: Array = c.get("target", [0.0, 1.5])
	yaw = deg_to_rad(float(c.get("yaw", 25.0)))
	pitch = deg_to_rad(float(c.get("pitch", 50.0)))
	distance = float(c.get("distance", 30.0))
	var z: Array = c.get("zoom", [distance, distance])
	zoom_min = minf(float(z[0]), distance)
	zoom_max = maxf(float(z[1]), distance)
	pan_speed = float(c.get("pan_speed", 0.6))
	var b: Array = c.get("bounds", [t[0], t[0], t[1], t[1]])
	bounds = Rect2(float(b[0]), float(b[2]), float(b[1]) - float(b[0]), float(b[3]) - float(b[2]))
	target = Vector3(float(t[0]), 0.0, -float(t[1]))
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance * 0.92, zoom_min, zoom_max)
			_apply()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance * 1.08, zoom_min, zoom_max)
			_apply()


func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if not Input.is_key_pressed(KEY_CTRL):   # Ctrl+A = vybrat všechny hrdiny, ne posun
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			move.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			move.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			move.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			move.y += 1.0
	if edge_scroll and edge_scroll_all and move == Vector2.ZERO:
		move = _edge_move()
	if move == Vector2.ZERO:
		return
	target += (_right() * move.x + _back() * move.y) * delta * distance * pan_speed
	_apply()


## Myš u okraje okna posouvá výřez (jen když je okno aktivní a myš v něm).
func _edge_move() -> Vector2:
	if not DisplayServer.window_is_focused():
		return Vector2.ZERO
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	var m := vp.get_mouse_position()
	if m.x < 0.0 or m.y < 0.0 or m.x > size.x or m.y > size.y:
		return Vector2.ZERO
	var out := Vector2.ZERO
	if m.x <= EDGE_PX:
		out.x = -1.0
	elif m.x >= size.x - EDGE_PX:
		out.x = 1.0
	if m.y <= EDGE_PX:
		out.y = -1.0
	elif m.y >= size.y - EDGE_PX:
		out.y = 1.0
	return out


func _right() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))


func _back() -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))


func _apply() -> void:
	# hranice jsou v souřadnicích simulace (x, y); ve 3D je y = -z
	target.x = clampf(target.x, bounds.position.x, bounds.end.x)
	target.z = -clampf(-target.z, bounds.position.y, bounds.end.y)
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
