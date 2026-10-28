extends Node3D
## Řídí bitvu: fáze (rozestavení → bitva ↔ signál → konec), vstup hráče,
## krokování simulace a propojení simulace s 3D scénou a rozhraním.

const Sim := preload("res://scripts/sim/battle_sim.gd")
const Field := preload("res://scripts/battle/battlefield.gd")
const UnitView := preload("res://scripts/battle/unit_view.gd")
const BattleUI := preload("res://scripts/battle/battle_ui.gd")
const OrbitCamera := preload("res://scripts/battle/orbit_camera.gd")

const STEP := 1.0 / 60.0

enum Phase { DEPLOY, BATTLE, SIGNAL, OVER }

var data: Dictionary
var setup: Dictionary
var sim: Sim
var phase := Phase.DEPLOY
var selected := ""
var speed := 1.0
var paused := false        # automatická pauza nebo otevřený dialog
var log_lines: Array = []

var cam: Camera3D
var ui: BattleUI
var views: Dictionary = {}
var projectile_views: Dictionary = {}
var banner: Node3D
var aura_disc: MeshInstance3D
var aura_ring: MeshInstance3D
var select_ring: MeshInstance3D
var hold_marker: MeshInstance3D
var hover_ring: MeshInstance3D
var drop_ring: MeshInstance3D
var order_line: MeshInstance3D
var zone: MeshInstance3D
var _aura_base := 5.0
var _acc := 0.0
var _ui_t := 0.0

# drag & drop rytířů (rozestavení a rozkazy při signálu)
const PICK_PX := 30.0          # tolerance výběru rytíře na obrazovce (px)
const DRAG_START_PX := 6.0     # o kolik se musí myš pohnout, aby začalo táhnutí
var hover_id := ""
var _drag_id := ""
var _drag_active := false
var _drag_press := Vector2.ZERO
var _drag_origin := Vector2.ZERO
var _drag_target := Vector2.ZERO
var _drag_target_raw := Vector2.ZERO


func _ready() -> void:
	data = Sim.load_data()
	setup = Sim.default_setup(data, 1)
	Field.build(self, data["scenario"])

	cam = OrbitCamera.new()
	add_child(cam)
	cam.make_current()

	var z: Dictionary = data["scenario"]["deploy_zone"]
	zone = MeshInstance3D.new()
	var zm := PlaneMesh.new()
	zm.size = Vector2(float(z["x1"]) - float(z["x0"]), float(z["y1"]) - float(z["y0"]))
	zone.mesh = zm
	zone.material_override = Field.transparent_mat(Color(0.31, 0.47, 0.78, 0.28))
	zone.position = Field.to_world(Vector2((float(z["x0"]) + float(z["x1"])) / 2.0, (float(z["y0"]) + float(z["y1"])) / 2.0), 0.03)
	add_child(zone)

	var aura_r: float = data["house"]["aura"]["radius"]
	_aura_base = aura_r
	aura_disc = Field.disc(aura_r, Color(0.91, 0.77, 0.25, 0.12))
	aura_ring = Field.ring(aura_r, 0.08, Color(0.91, 0.77, 0.25, 0.75))
	add_child(aura_disc)
	add_child(aura_ring)
	select_ring = Field.ring(0.7, 0.14, Color(1, 1, 1, 0.95))
	hold_marker = Field.ring(0.35, 0.1, Color(1, 1, 1, 0.6))
	add_child(select_ring)
	add_child(hold_marker)
	hover_ring = Field.ring(0.75, 0.08, Color(1.0, 0.92, 0.6, 0.8))
	drop_ring = Field.ring(0.55, 0.12, Color(0.4, 1.0, 0.5, 0.9))
	add_child(hover_ring)
	add_child(drop_ring)
	order_line = MeshInstance3D.new()
	order_line.mesh = ImmediateMesh.new()
	order_line.material_override = Field.transparent_mat(Color(1, 1, 1, 0.85))
	order_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(order_line)
	banner = Field.build_banner()
	add_child(banner)

	ui = BattleUI.new()
	add_child(ui)
	ui.knight_clicked.connect(_select)
	ui.posture_changed.connect(_on_posture)
	ui.bearer_changed.connect(_on_bearer)
	ui.signals_count_changed.connect(func(n: int) -> void:
		setup["signals"] = n
		_fresh_deploy())
	ui.start_pressed.connect(_start_battle)
	ui.shout_pressed.connect(_shout)
	ui.signal_pressed.connect(_use_signal)
	ui.charge_pressed.connect(_charge)
	ui.resume_pressed.connect(_resume_signal)
	ui.speed_changed.connect(func(v: float) -> void:
		speed = v
		_refresh_panel())
	ui.continue_pressed.connect(_resume_pause)
	ui.retry_pressed.connect(func() -> void:
		ui.hide_result()
		_start_battle())
	ui.redeploy_pressed.connect(func() -> void:
		ui.hide_result()
		phase = Phase.DEPLOY
		_fresh_deploy())

	_fresh_deploy()


# ================================================================ stav

func _new_sim() -> void:
	sim = Sim.new(data, setup)
	for id: String in views:
		(views[id] as Node3D).queue_free()
	views.clear()
	for id: int in projectile_views:
		(projectile_views[id] as Node3D).queue_free()
	projectile_views.clear()
	ui.clear_hp_bars()
	for u in sim.units:
		var v := UnitView.new()
		v.setup(u)
		add_child(v)
		views[u.id] = v
	log_lines.clear()
	paused = false
	_acc = 0.0


func _fresh_deploy() -> void:
	_new_sim()
	selected = ""
	_refresh_panel()


func _start_battle() -> void:
	for u in sim.knights():
		setup["pos"][u.id] = u.pos
		setup["posture"][u.id] = u.posture
	_new_sim()
	phase = Phase.BATTLE
	selected = ""
	_refresh_panel()


func _refresh_panel() -> void:
	if phase == Phase.DEPLOY:
		ui.show_deploy(sim, setup, selected)
	else:
		ui.show_battle(sim, phase == Phase.SIGNAL, selected, speed, log_lines)
	ui.update_dynamic(sim, phase == Phase.SIGNAL, paused)


# ================================================================ příkazy

## Klik na jméno v panelu: přepne výběr.
func _select(id: String) -> void:
	var u := sim.by_id(id)
	if u == null or not u.alive():
		return
	if phase != Phase.DEPLOY and phase != Phase.SIGNAL:
		return
	selected = "" if selected == id else id
	_refresh_panel()


func _set_selected(id: String) -> void:
	if selected != id:
		selected = id
		_refresh_panel()


## Volba nositele praporu: jen v rozestavení, během bitvy se prapor nepředává.
func _on_bearer(id: String) -> void:
	if phase != Phase.DEPLOY:
		return
	if sim.set_bearer(id):
		setup["bearer"] = id
		for u in sim.knights():
			setup["posture"][u.id] = u.posture
	_refresh_panel()


func _on_posture(id: String, posture: String) -> void:
	var u := sim.by_id(id)
	if u == null:
		return
	if phase == Phase.DEPLOY:
		if sim.set_posture(id, posture):
			setup["posture"][id] = posture
		else:
			_refresh_panel()
		return
	if phase != Phase.SIGNAL or sim.bearer_forbids(id, posture):
		_refresh_panel()
		return
	# Postoj, který zakazuje přísaha, jde při signálu zvolit jen za cenu jejího porušení.
	if not sim.posture_allowed(id, posture):
		paused = true
		var on_break := func() -> void:
			sim.break_oath()
			sim.set_posture(id, posture)
			paused = false
			_refresh_panel()
		var on_keep := func() -> void:
			paused = false
			_refresh_panel()
		ui.ask_oath(u.name, sim.oath_of(id), on_break, on_keep)
		return
	sim.set_posture(id, posture)
	_refresh_panel()


func _shout(key: String) -> void:
	if phase != Phase.BATTLE or paused:
		return
	if sim.shout(key):
		_flush_events()
		_refresh_panel()


func _charge() -> void:
	if phase != Phase.BATTLE or paused:
		return
	if sim.charge_all():
		_flush_events()
		_refresh_panel()


func _use_signal() -> void:
	if phase != Phase.BATTLE or paused:
		return
	if sim.use_signal():
		phase = Phase.SIGNAL
		selected = ""
		_flush_events()
		_refresh_panel()


func _resume_signal() -> void:
	if phase != Phase.SIGNAL or paused:
		return
	phase = Phase.BATTLE
	selected = ""
	_refresh_panel()


func _resume_pause() -> void:
	if not ui.toast.visible:
		return
	ui.hide_toast()
	paused = false
	_refresh_panel()


func _order_move(u: Sim.Unit, target: Vector2) -> void:
	if sim._in_water(target):
		return
	var apply := func() -> void:
		sim.order_move(u.id, target)
		paused = false
		_flush_events()
		_refresh_panel()
	if sim.has_oath(u.id) and sim.is_retreat(u.id, target):
		paused = true
		var on_break := func() -> void:
			sim.break_oath()
			apply.call()
		var on_keep := func() -> void:
			paused = false
			_refresh_panel()
		ui.ask_oath(u.name, sim.oath_of(u.id), on_break, on_keep)
	else:
		apply.call()


# ================================================================ vstup

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match (event as InputEventKey).keycode:
			KEY_1:
				_shout_by_index(0)
			KEY_2:
				_shout_by_index(1)
			KEY_F:
				_charge()
			KEY_SPACE:
				if ui.toast.visible:
					_resume_pause()
				elif phase == Phase.SIGNAL:
					_resume_signal()
				else:
					_use_signal()
			KEY_ENTER, KEY_KP_ENTER:
				if ui.toast.visible:
					_resume_pause()
				elif phase == Phase.SIGNAL:
					_resume_signal()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_pointer_down(mb.position)


func _input(event: InputEvent) -> void:
	# Pohyb a puštění se sledují i nad panelem, aby táhnutí nikdy "neuvízlo".
	if event is InputEventMouseMotion:
		_pointer_move((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _drag_id != "":
			_pointer_up(mb.position)
			get_viewport().set_input_as_handled()


func _shout_by_index(i: int) -> void:
	var keys: Array = sim.house["shouts"].keys()
	if i < keys.size():
		_shout(keys[i])


func _can_command() -> bool:
	return (phase == Phase.DEPLOY or phase == Phase.SIGNAL) and not paused


static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Rytíř pod kurzorem: měří se vzdálenost od jeho postavy na obrazovce (od nohou po hlavu),
## takže jde chytit kdekoli na těle, ne jen u nohou.
func _pick_knight(screen_pos: Vector2, exclude: String = "") -> String:
	var best := ""
	var bd := PICK_PX
	for u in sim.knights():
		if not u.alive() or u.id == exclude:
			continue
		var base: Vector3 = (views[u.id] as Node3D).global_position
		if cam.is_position_behind(base):
			continue
		var a := cam.unproject_position(base + Vector3(0, 0.2, 0))
		var b := cam.unproject_position(base + Vector3(0, 1.9, 0))
		var d := _dist_to_segment(screen_pos, a, b)
		if d < bd:
			bd = d
			best = u.id
	return best


func _ground(screen_pos: Vector2) -> Variant:
	var hit: Variant = (cam as OrbitCamera).ground_point(screen_pos)
	if hit == null:
		return null
	var w: Vector3 = hit
	return Vector2(w.x, -w.z)


func _clamp_zone(p: Vector2) -> Vector2:
	var z: Dictionary = data["scenario"]["deploy_zone"]
	return Vector2(clampf(p.x, float(z["x0"]) + 0.4, float(z["x1"]) - 0.4), clampf(p.y, float(z["y0"]) + 0.4, float(z["y1"]) - 0.4))


func _pointer_down(screen_pos: Vector2) -> void:
	if not _can_command():
		return
	var id := _pick_knight(screen_pos)
	if id != "":
		_drag_id = id
		_drag_active = false
		_drag_press = screen_pos
		_drag_origin = sim.by_id(id).pos
		_set_selected(id)
		return
	# klik na zem s vybraným rytířem = přesun (alternativa k táhnutí)
	if selected == "":
		return
	var gp: Variant = _ground(screen_pos)
	if gp == null:
		return
	var p: Vector2 = gp
	var u := sim.by_id(selected)
	if phase == Phase.DEPLOY:
		u.pos = _clamp_zone(p)
		u.home = u.pos
		setup["pos"][u.id] = u.pos
	else:
		_order_move(u, p)


func _pointer_move(screen_pos: Vector2) -> void:
	if not _can_command():
		hover_id = ""
		return
	hover_id = _pick_knight(screen_pos, _drag_id if _drag_active else "")
	if _drag_id == "":
		return
	if not _drag_active and screen_pos.distance_to(_drag_press) > DRAG_START_PX:
		_drag_active = true
	if not _drag_active:
		return
	var gp: Variant = _ground(screen_pos)
	if gp == null:
		return
	_drag_target_raw = gp
	if phase == Phase.DEPLOY:
		_drag_target = _clamp_zone(_drag_target_raw)
		var u := sim.by_id(_drag_id)
		u.pos = _drag_target
		u.home = u.pos
	else:
		_drag_target = _drag_target_raw


func _pointer_up(screen_pos: Vector2) -> void:
	var id := _drag_id
	var was_drag := _drag_active
	_drag_id = ""
	_drag_active = false
	if not was_drag or not _can_command():
		return
	var u := sim.by_id(id)
	if phase == Phase.DEPLOY:
		# puštění na jiného rytíře = prohodit místa
		var other_id := _pick_knight(screen_pos, id)
		if other_id != "":
			var o := sim.by_id(other_id)
			u.pos = o.pos
			o.pos = _drag_origin
			o.home = o.pos
			setup["pos"][other_id] = o.pos
		u.home = u.pos
		setup["pos"][id] = u.pos
	elif _drag_target.distance_to(u.pos) > 0.5:
		_order_move(u, _drag_target)


# ================================================================ smyčka

func _process(delta: float) -> void:
	var running := phase == Phase.BATTLE and not paused and sim.over == ""
	if running:
		_acc += delta * speed
		var steps := 0
		while _acc >= STEP and steps < 8:
			sim.step(STEP)
			_acc -= STEP
			steps += 1
		_flush_events()

	for u in sim.units:
		(views[u.id] as UnitView).sync(u, delta, running, speed)
	_sync_projectiles()
	_sync_markers()

	_ui_t += delta
	if _ui_t > 0.1:
		_ui_t = 0.0
		ui.update_dynamic(sim, phase == Phase.SIGNAL, paused)
	ui.update_hp_bars(sim, cam, views, phase != Phase.DEPLOY)


func _flush_events() -> void:
	var relog := false
	for ev in sim.events:
		match String(ev["type"]):
			"log":
				log_lines.append(ev)
				relog = true
			"autopause":
				log_lines.append({"t": sim.t, "text": "Nositel praporu padl, prapor leží", "hot": true})
				relog = true
				paused = true
				ui.show_toast(ev["text"])
			"decided":
				# rozhodnutá bitva se dohraje zrychleně
				speed = maxf(speed, 2.0)
				relog = true
			"heal":
				var v: UnitView = views.get(ev["id"])
				if v != null:
					v.flash_heal()
			"end":
				phase = Phase.OVER
				relog = true
				get_tree().create_timer(0.8).timeout.connect(func() -> void: ui.show_result(sim, setup))
	sim.events.clear()
	if relog:
		_refresh_panel()


func _sync_projectiles() -> void:
	var alive := {}
	for p in sim.projectiles:
		alive[p.id] = true
		var mi: MeshInstance3D = projectile_views.get(p.id)
		if mi == null:
			mi = MeshInstance3D.new()
			var m := BoxMesh.new()
			m.size = Vector3(0.05, 0.05, 0.7)
			mi.mesh = m
			mi.material_override = Field.mat(Color("#5a3d22"))
			add_child(mi)
			projectile_views[p.id] = mi
		var pos := Field.to_world(p.pos, 1.3)
		mi.position = pos
		var tg := sim.by_id(p.target_id)
		if tg != null:
			var to := Field.to_world(tg.pos, 1.3)
			if to.distance_to(pos) > 0.01:
				mi.look_at(to, Vector3.UP)
	for id: int in projectile_views.keys():
		if not alive.has(id):
			(projectile_views[id] as Node3D).queue_free()
			projectile_views.erase(id)


func _sync_markers() -> void:
	zone.visible = phase == Phase.DEPLOY
	var c := sim.aura_center()
	if c != null:
		var v: Node3D = views[c.id]
		banner.rotation = Vector3(0, v.rotation.y, 0)
		banner.position = v.position + v.basis * Vector3(-0.38, 0, -0.12) + Vector3(0, 0, 0)
		banner.position.y = 0.0
		aura_disc.visible = true
		aura_ring.visible = true
		aura_disc.position = Field.to_world(c.pos, 0.04)
		aura_ring.position = Field.to_world(c.pos, 0.05)
		var k := sim.aura_radius / _aura_base
		aura_disc.scale = Vector3(k, 1.0, k)
		aura_ring.scale = Vector3(k, 1.0, k)
		var shout_on := float(sim.fx.get("zarod", 0.0)) > 0.0
		var wall_on := float(sim.fx.get("hradba", 0.0)) > 0.0
		var col := Color(0.5, 0.69, 1.0) if wall_on else Color(0.91, 0.77, 0.25)
		var pulse := 0.06 * sin(Time.get_ticks_msec() / 120.0) if (shout_on or wall_on) else 0.0
		(aura_disc.material_override as StandardMaterial3D).albedo_color = Color(col, 0.12 + (0.1 if shout_on or wall_on else 0.0) + pulse)
		(aura_ring.material_override as StandardMaterial3D).albedo_color = Color(col, 0.75)
	else:
		aura_disc.visible = false
		aura_ring.visible = false
		banner.position = Field.to_world(sim.banner_pos, 0.15)
		banner.rotation = Vector3(0, 0, deg_to_rad(80))

	hover_ring.visible = hover_id != "" and hover_id != selected
	if hover_ring.visible:
		hover_ring.position = Field.to_world(sim.by_id(hover_id).pos, 0.07)
	var dragging := _drag_id != "" and _drag_active
	var invalid := false
	if dragging and phase == Phase.DEPLOY:
		invalid = _drag_target_raw.distance_to(_drag_target) > 0.05
	elif dragging:
		invalid = sim._in_water(_drag_target)
	drop_ring.visible = dragging and (phase == Phase.SIGNAL or invalid)
	if drop_ring.visible:
		drop_ring.position = Field.to_world(_drag_target_raw if invalid else _drag_target, 0.08)
		(drop_ring.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.35, 0.3, 0.9) if invalid else Color(0.4, 1.0, 0.5, 0.9)
	var im := order_line.mesh as ImmediateMesh
	im.clear_surfaces()
	if dragging and phase == Phase.SIGNAL:
		var from := Field.to_world(sim.by_id(_drag_id).pos, 0.1)
		var to := Field.to_world(_drag_target, 0.1)
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		im.surface_add_vertex(from)
		im.surface_add_vertex(to)
		im.surface_end()

	var su := sim.by_id(selected) if selected != "" else null
	select_ring.visible = su != null and su.alive() and (phase == Phase.DEPLOY or phase == Phase.SIGNAL)
	if select_ring.visible:
		select_ring.position = Field.to_world(su.pos, 0.06)
	hold_marker.visible = su != null and su.alive() and phase == Phase.SIGNAL and su.posture == "drzet"
	if hold_marker.visible:
		hold_marker.position = Field.to_world(su.home, 0.06)
