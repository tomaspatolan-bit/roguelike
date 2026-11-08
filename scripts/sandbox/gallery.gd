extends Node3D
## Character gallery (sandbox, testing tool): all heroes and enemies in a row on the battlefield of The River Bridge.
## Free camera (right or middle mouse rotates, wheel zooms, WASD pans), animations for one or all, look and outline.
## Uses the same UnitView as the battle, so what is seen here is what the battle shows.

const Sim := preload("res://scripts/sim/battle_sim.gd")
const Field := preload("res://scripts/battle/battlefield.gd")
const UnitView := preload("res://scripts/battle/unit_view.gd")
const UI := preload("res://scripts/ui/ui_theme.gd")

signal back_pressed

const SCENARIO := "most_pres_reku"
const LOOKS := [["noon", "Noon"], ["dawn", "Dawn"], ["dusk", "Dusk"], ["off", "Off (placeholder)"]]
const ANIMS := [["idle", "Idle"], ["walk", "Walk"], ["attack", "Attack"], ["ability", "Ability"], ["hit", "Hit"], ["death", "Death (animation)"], ["ragdoll", "Fall (ragdoll)"]]
const SPEEDS := [0.25, 0.5, 1.0]

var look := "noon"
var outline_on := true
var speed := 1.0
var loop := true
var turntable := false
var current := "idle"            # what the chosen characters do now
var who := ""                    # "" = everyone, otherwise the unit id
var missing: Array = []          # animations a character does not have (reported in the panel and the test)

var sim: Sim
var data: Dictionary
var field_root: Node3D
var cam: Camera3D
var outline: MeshInstance3D
var views: Dictionary = {}       # id -> UnitView
var order: Array = []            # ids in the row, left to right
var _target := Vector3(0, 1.0, 3.5)
var _yaw := 0.0
var _pitch := deg_to_rad(22.0)
var _dist := 16.0
var _drag := false
var _who_pick: OptionButton
var _info: Label


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 200.0
	add_child(cam)
	cam.make_current()
	_build_world()
	_build_panel()
	_apply_cam()


func _build_world() -> void:
	if field_root != null:
		field_root.queue_free()
	for id: String in views:
		(views[id] as Node3D).queue_free()
	views.clear()
	order.clear()
	data = Sim.load_data(SCENARIO)
	if look == "off":
		data["scenario"].erase("look")
	else:
		data["scenario"]["look"] = look
	field_root = Node3D.new()
	add_child(field_root)
	Field.build(field_root, data["scenario"], data["units"].get("camera", {}))
	UnitView.look_lighting = data["scenario"].has("look")
	if outline == null:
		outline = Field.Diorama.attach_outline(cam)
	outline.visible = outline_on and data["scenario"].has("look")
	var st := Sim.default_setup(data)
	st["sandbox"] = {"no_foes": true, "foes_idle": true, "endless": true}
	sim = Sim.new(data, st, 1)
	var ks := sim.knights()
	for i in ks.size():
		_place(ks[i], Vector2(-5.0 + i * 2.5, -4.5))
	var fkeys: Array = (data["units"]["foes"] as Dictionary).keys()
	for i in fkeys.size():
		var id := sim.sandbox_spawn(String(fkeys[i]), Vector2(-6.0 + i * 2.0, -1.0))
		if id != "":
			_place(sim.by_id(id), sim.by_id(id).pos)
	sim.events.clear()
	missing.clear()
	for id: String in order:
		var v := UnitView.new()
		v.setup(sim.by_id(id))
		add_child(v)
		views[id] = v
		for k: String in ["attack", "ability", "hit", "death"]:
			var nm := String(v.get("_anim_" + k))
			if v.anim == null or not v.anim.has_animation(nm):
				missing.append("%s: %s" % [sim.by_id(id).name, nm])
	current = "idle"


func _place(u: Sim.Unit, p: Vector2) -> void:
	u.pos = p
	u.home = p
	u.face = Vector2(0, -1)   # towards the default camera
	order.append(u.id)


func _chosen() -> Array:
	return order if who == "" else [who]


func _play(kind: String) -> void:
	current = kind
	for id: String in _chosen():
		var u := sim.by_id(id)
		var v: UnitView = views[id]
		u.moving = kind == "walk"
		if kind == "ragdoll":
			u.hp = 0.0
		elif kind in ["attack", "ability", "hit", "death"]:
			v.play_kind(kind, speed)
	_update_info()


func _reset() -> void:
	_build_world()
	_update_info()


func _process(delta: float) -> void:
	if turntable:
		_yaw += delta * 0.35
		_apply_cam()
	var pan := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0
	if pan != Vector3.ZERO:
		_target += pan.normalized().rotated(Vector3.UP, _yaw) * delta * maxf(_dist, 4.0) * 0.6
		_apply_cam()
	for id: String in order:
		var u := sim.by_id(id)
		var v: UnitView = views[id]
		if loop and id in _chosen() and current in ["attack", "ability", "hit", "death"] and not v.oneshot_playing() and u.alive():
			v.play_kind(current, speed)
		v.sync(u, delta, true, speed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_drag = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = clampf(_dist * 0.9, 2.0, 60.0)
			_apply_cam()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = clampf(_dist * 1.1, 2.0, 60.0)
			_apply_cam()
	elif event is InputEventMouseMotion and _drag:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.008
		_pitch = clampf(_pitch + mm.relative.y * 0.006, deg_to_rad(-5.0), deg_to_rad(85.0))
		_apply_cam()


func _apply_cam() -> void:
	var off := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
	cam.look_at_from_position(_target + off, _target, Vector3.UP)


## Camera presets: the battle camera angle over the row, or close to the chosen character.
func view_game() -> void:
	_yaw = deg_to_rad(25.0)
	_pitch = deg_to_rad(50.0)
	_dist = 26.0
	_target = Vector3(0, 0, 3.0)
	_apply_cam()


func view_close() -> void:
	var id: String = who if who != "" else order[0]
	var p := Field.to_world(sim.by_id(id).pos)
	_target = p + Vector3(0, 1.0, 0)
	_yaw = 0.0
	_pitch = deg_to_rad(12.0)
	_dist = 4.5
	_apply_cam()


func view_row() -> void:
	_target = Vector3(0, 1.0, 3.5)
	_yaw = 0.0
	_pitch = deg_to_rad(22.0)
	_dist = 16.0
	_apply_cam()


func _build_panel() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var p := PanelContainer.new()
	p.theme = UI.make_theme()
	p.add_theme_stylebox_override("panel", UI.panel_box(12, UI.BATTLE))
	p.position = Vector2(12, 12)
	p.custom_minimum_size = Vector2(300, 0)
	layer.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(UI.eyebrow("Sandbox", UI.OATH, 12))
	v.add_child(UI.title("Character gallery", 20))
	_who_pick = OptionButton.new()
	_who_pick.add_item("Everyone")
	for id: String in order:
		_who_pick.add_item(sim.by_id(id).name)
		_who_pick.set_item_metadata(_who_pick.item_count - 1, id)
	_who_pick.item_selected.connect(func(i: int) -> void:
		who = "" if i == 0 else String(_who_pick.get_item_metadata(i))
		if who != "":
			view_close()
		_update_info())
	v.add_child(_who_pick)
	v.add_child(UI.eyebrow("Animation"))
	var grid := GridContainer.new()
	grid.columns = 2
	for a: Array in ANIMS:
		var b := Button.new()
		b.text = String(a[1])
		b.add_theme_font_size_override("font_size", 13)
		var kind := String(a[0])
		b.pressed.connect(func() -> void: _play(kind))
		grid.add_child(b)
	var r := Button.new()
	r.text = "Reset everyone"
	r.add_theme_font_size_override("font_size", 13)
	r.pressed.connect(_reset)
	grid.add_child(r)
	v.add_child(grid)
	var lp := CheckBox.new()
	lp.text = "Repeat attack, ability, hit"
	lp.button_pressed = loop
	lp.toggled.connect(func(on: bool) -> void: loop = on)
	v.add_child(lp)
	var srow := HBoxContainer.new()
	srow.add_child(UI.label("Speed", 13))
	for s: float in SPEEDS:
		var sb := Button.new()
		sb.text = "%s×" % str(s)
		sb.add_theme_font_size_override("font_size", 12)
		sb.pressed.connect(func() -> void: speed = s)
		srow.add_child(sb)
	v.add_child(srow)
	v.add_child(UI.eyebrow("Camera"))
	var crow := HBoxContainer.new()
	for c: Array in [["Row", view_row], ["Battle view", view_game], ["Close", view_close]]:
		var cb := Button.new()
		cb.text = String(c[0])
		cb.add_theme_font_size_override("font_size", 13)
		cb.pressed.connect(c[1])
		crow.add_child(cb)
	v.add_child(crow)
	var tt := CheckBox.new()
	tt.text = "Turntable (camera circles)"
	tt.toggled.connect(func(on: bool) -> void: turntable = on)
	v.add_child(tt)
	v.add_child(UI.eyebrow("Look"))
	var lk := OptionButton.new()
	for l: Array in LOOKS:
		lk.add_item(String(l[1]))
		lk.set_item_metadata(lk.item_count - 1, l[0])
	lk.item_selected.connect(func(i: int) -> void:
		look = String(lk.get_item_metadata(i))
		_reset())
	v.add_child(lk)
	var ol := CheckBox.new()
	ol.text = "Outline"
	ol.button_pressed = outline_on
	ol.toggled.connect(func(on: bool) -> void:
		outline_on = on
		outline.visible = on and data["scenario"].has("look"))
	v.add_child(ol)
	v.add_child(UI.label("Right or middle mouse: rotate · wheel: zoom · WASD: move", 12, UI.TEXT_MUTED, true))
	_info = UI.label("", 12, UI.TEXT_MUTED, true)
	v.add_child(_info)
	var back := Button.new()
	back.text = "Back to the sandbox"
	UI.primary(back, UI.OATH, 14)
	back.pressed.connect(func() -> void: back_pressed.emit())
	v.add_child(back)
	for n in p.find_children("*", "BaseButton", true, false):
		(n as Control).focus_mode = Control.FOCUS_NONE
	_update_info()


func _update_info() -> void:
	if _info == null:
		return
	var t := "Showing: %s · %s." % ["everyone" if who == "" else sim.by_id(who).name, current]
	if not missing.is_empty():
		t += "\nMissing animations: " + ", ".join(missing)
	_info.text = t
