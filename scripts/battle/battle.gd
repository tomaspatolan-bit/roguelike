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
var zone: MeshInstance3D
var _acc := 0.0
var _ui_t := 0.0


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
	aura_disc = Field.disc(aura_r, Color(0.91, 0.77, 0.25, 0.12))
	aura_ring = Field.ring(aura_r, 0.08, Color(0.91, 0.77, 0.25, 0.75))
	add_child(aura_disc)
	add_child(aura_ring)
	select_ring = Field.ring(0.7, 0.14, Color(1, 1, 1, 0.95))
	hold_marker = Field.ring(0.35, 0.1, Color(1, 1, 1, 0.6))
	add_child(select_ring)
	add_child(hold_marker)
	banner = Field.build_banner()
	add_child(banner)

	ui = BattleUI.new()
	add_child(ui)
	ui.knight_clicked.connect(_select)
	ui.posture_changed.connect(_on_posture)
	ui.signals_count_changed.connect(func(n: int) -> void:
		setup["signals"] = n
		_fresh_deploy())
	ui.start_pressed.connect(_start_battle)
	ui.shout_pressed.connect(_shout)
	ui.signal_pressed.connect(_use_signal)
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

func _select(id: String) -> void:
	var u := sim.by_id(id)
	if u == null or not u.alive():
		return
	if phase != Phase.DEPLOY and phase != Phase.SIGNAL:
		return
	selected = "" if selected == id else id
	_refresh_panel()


func _on_posture(id: String, posture: String) -> void:
	var u := sim.by_id(id)
	if u == null:
		return
	if phase == Phase.DEPLOY:
		u.posture = posture
		setup["posture"][id] = posture
		return
	if phase != Phase.SIGNAL:
		return
	# "Chránit prapor" stáhne tanka zpět k praporu: to je ústup
	if u.key == "tank" and sim.oath_kept and posture == "chranit":
		paused = true
		var on_break := func() -> void:
			sim.break_oath()
			sim.set_posture(id, posture)
			paused = false
			_refresh_panel()
		var on_keep := func() -> void:
			paused = false
			_refresh_panel()
		ui.ask_oath(u.name, on_break, on_keep)
		return
	sim.set_posture(id, posture)
	_refresh_panel()


func _shout(key: String) -> void:
	if phase != Phase.BATTLE or paused:
		return
	if sim.shout(key):
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
	if u.key == "tank" and sim.oath_kept and sim.is_retreat(u.id, target):
		paused = true
		var on_break := func() -> void:
			sim.break_oath()
			apply.call()
		var on_keep := func() -> void:
			paused = false
			_refresh_panel()
		ui.ask_oath(u.name, on_break, on_keep)
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
			KEY_S:
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
			_click(mb.position)


func _shout_by_index(i: int) -> void:
	var keys: Array = sim.house["shouts"].keys()
	if i < keys.size():
		_shout(keys[i])


func _click(screen_pos: Vector2) -> void:
	if phase != Phase.DEPLOY and phase != Phase.SIGNAL:
		return
	if paused:
		return
	var hit: Variant = (cam as OrbitCamera).ground_point(screen_pos)
	if hit == null:
		return
	var w: Vector3 = hit
	var p := Vector2(w.x, -w.z)

	# klik na rytíře = výběr
	var best: Sim.Unit = null
	var bd := INF
	for u in sim.knights():
		if not u.alive():
			continue
		var d := u.pos.distance_to(p)
		if d < bd:
			bd = d
			best = u
	if best != null and bd < (1.2 if best.key == "jezdec" else 0.8):
		_select(best.id)
		return

	if selected == "":
		return
	var u := sim.by_id(selected)
	if phase == Phase.DEPLOY:
		var z: Dictionary = data["scenario"]["deploy_zone"]
		u.pos = Vector2(clampf(p.x, float(z["x0"]) + 0.4, float(z["x1"]) - 0.4), clampf(p.y, float(z["y0"]) + 0.4, float(z["y1"]) - 0.4))
		u.home = u.pos
		setup["pos"][u.id] = u.pos
	else:
		_order_move(u, p)


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
				log_lines.append({"t": sim.t, "text": "Praporečník padl, prapor leží", "hot": true})
				relog = true
				paused = true
				ui.show_toast(ev["text"])
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

	var su := sim.by_id(selected) if selected != "" else null
	select_ring.visible = su != null and su.alive() and (phase == Phase.DEPLOY or phase == Phase.SIGNAL)
	if select_ring.visible:
		select_ring.position = Field.to_world(su.pos, 0.06)
	hold_marker.visible = su != null and su.alive() and phase == Phase.SIGNAL and su.posture == "drzet"
	if hold_marker.visible:
		hold_marker.position = Field.to_world(su.home, 0.06)
