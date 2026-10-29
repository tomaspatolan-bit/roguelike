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
var aim_ring: MeshInstance3D      # cílení schopnosti: kruh pod kurzorem
var _fx: Array = []                # krátké efekty schopností [MeshInstance3D, zbývající čas]
var _aim_id := ""                  # hrdina, jehož schopnost se právě cílí
var _aim_point := Vector2.ZERO
var _zone_meshes: Array = []      # hořící zem ze simulace (sim.zones)
var select_ring: MeshInstance3D
var hold_marker: MeshInstance3D
var hover_ring: MeshInstance3D
var drop_ring: MeshInstance3D
var order_line: MeshInstance3D
var zone: MeshInstance3D
var field_root: Node3D
var route_mesh: MeshInstance3D
var scenario_id: String = Sim.DEFAULT_SCENARIO

# kreslení trasy v rozestavení
var _route_id := ""          # rytíř, kterému se kreslí trasa (režim kreslení)
var _route_drawing := false
var _route_raw: Array[Vector2] = []
var _acc := 0.0
## Běh (scripts/run/run_state.gd), když je bitva jeho součástí; jinak null (volná bitva).
## Nastavuje run_main.gd před přidáním do stromu.
var run: RefCounted = null

## Bitva v běhu skončila a hráč pokračuje: výsledek ze sim.result().
signal battle_done(result: Dictionary)
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
	if run != null:
		scenario_id = String(run.node()["scenario"])
		data = run.load_stage_data()
		setup = run.battle_setup(data)
	else:
		data = Sim.load_data(scenario_id)
		setup = Sim.default_setup(data, 1)
	field_root = Node3D.new()
	add_child(field_root)
	Field.build(field_root, data["scenario"])

	cam = OrbitCamera.new()
	add_child(cam)
	cam.make_current()

	zone = MeshInstance3D.new()
	zone.material_override = Field.transparent_mat(Color(0.31, 0.47, 0.78, 0.28))
	add_child(zone)
	_build_zone()
	route_mesh = MeshInstance3D.new()
	route_mesh.mesh = ImmediateMesh.new()
	route_mesh.material_override = Field.transparent_mat(Color(1.0, 0.92, 0.55, 0.9))
	route_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(route_mesh)

	aim_ring = Field.ring(1.0, 0.1, Color(1.0, 0.85, 0.4, 0.9))
	aim_ring.visible = false
	add_child(aim_ring)
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

	ui = BattleUI.new()
	if run != null:
		ui.run_mode = true
		ui.run_label = "%s · %s · patro %d ze %d" % [run.act["name"], run.NODE_NAMES.get(run.node_type(), ""), run.current_floor(), run.floor_count()]
	add_child(ui)
	ui.run_continue_pressed.connect(func() -> void: battle_done.emit(sim.result()))
	ui.knight_clicked.connect(_select)
	ui.ability_pressed.connect(_ability)
	ui.passive_toggled.connect(_on_passive)
	ui.scenario_changed.connect(_load_scenario)
	ui.route_draw_pressed.connect(func(id: String) -> void:
		_route_id = id if _route_id != id else ""
		_refresh_panel())
	ui.route_clear_pressed.connect(_clear_route)
	var choices: Array = []
	for sid: String in ([] if run != null else Sim.scenario_list()):
		choices.append([sid, String(Sim._read_json("res://data/scenarios/%s.json" % sid).get("name", sid))])
	ui.scenario_choices = choices
	ui.signals_count_changed.connect(func(n: int) -> void:
		setup["signals"] = n
		_fresh_deploy())
	ui.start_pressed.connect(_start_battle)
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

func _build_zone() -> void:
	var z: Dictionary = data["scenario"]["deploy_zone"]
	var zm := PlaneMesh.new()
	zm.size = Vector2(float(z["x1"]) - float(z["x0"]), float(z["y1"]) - float(z["y0"]))
	zone.mesh = zm
	zone.position = Field.to_world(Vector2((float(z["x0"]) + float(z["x1"])) / 2.0, (float(z["y0"]) + float(z["y1"])) / 2.0), 0.03)


## Výběr bitvy v rozestavení: načte scénář a postaví bojiště znovu.
func _load_scenario(id: String) -> void:
	if phase != Phase.DEPLOY or id == scenario_id:
		return
	scenario_id = id
	var signal_count: int = setup["signals"]
	data = Sim.load_data(id)
	setup = Sim.default_setup(data, signal_count)
	field_root.queue_free()
	field_root = Node3D.new()
	add_child(field_root)
	Field.build(field_root, data["scenario"])
	_build_zone()
	_route_id = ""
	_fresh_deploy()


func _clear_route(id: String) -> void:
	if phase != Phase.DEPLOY:
		return
	sim.set_route(id, [])
	(setup["routes"] as Dictionary).erase(id)
	_route_id = ""
	_refresh_panel()


func _finish_route() -> void:
	var id := _route_id
	_route_drawing = false
	_route_id = ""
	if id == "" or _route_raw.size() < 2:
		_refresh_panel()
		return
	var pts := Sim.simplify_route(_route_raw, 5)
	pts.remove_at(0)   # první bod je rytíř sám
	var problem := sim.route_problem(id, pts)
	if problem != "":
		ui.show_toast(problem)
	elif sim.set_route(id, pts):
		setup["routes"][id] = sim.by_id(id).route.duplicate()
	_route_raw.clear()
	_refresh_panel()

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
	_aim_id = ""
	paused = false
	_acc = 0.0


func _fresh_deploy() -> void:
	_new_sim()
	selected = ""
	_refresh_panel()


func _start_battle() -> void:
	for u in sim.knights():
		setup["pos"][u.id] = u.pos
	_new_sim()
	phase = Phase.BATTLE
	selected = ""
	_refresh_panel()


func _refresh_panel() -> void:
	if phase == Phase.DEPLOY:
		ui.show_deploy(sim, setup, selected, scenario_id, _route_id)
	else:
		ui.show_battle(sim, phase == Phase.SIGNAL, selected, speed, log_lines, _aim_id)
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


## Pasivka zapnutá nebo vypnutá v rozestavení (na zkoušku; ve hře budou odměnou v běhu).
func _on_passive(id: String, key: String, on: bool) -> void:
	if run != null:
		return   # v běhu se pasivky získávají jen jako odměna
	if phase != Phase.DEPLOY:
		return
	if on:
		var problem := sim.passive_problem(id, key)
		if problem != "":
			ui.flash_hint(problem)
	if sim.set_passive(id, key, on):
		setup["passives"][id] = sim.passives_of(id).duplicate()
	_refresh_panel()


## Schopnost hrdiny (karta nebo klávesa 1–5). Bez cíle se použije hned, jinak začne cílení.
func _ability(id: String) -> void:
	if (phase != Phase.BATTLE and phase != Phase.SIGNAL) or paused:
		return
	if not sim.can_use_ability(id):
		ui.flash_hint(sim.ability_problem(id))
		return
	if sim.ability_target(id) == "none":
		if sim.use_ability(id):
			_flush_events()
			_refresh_panel()
		return
	_aim_id = "" if _aim_id == id else id
	_refresh_panel()


func _ability_by_index(i: int) -> void:
	var ks := sim.knights()
	if i < ks.size():
		_ability(ks[i].id)


## Klik při cílení: místo na zemi, nebo nepřítel pod kurzorem.
func _aim_click(screen_pos: Vector2) -> void:
	var id := _aim_id
	var target: Variant = null
	if sim.ability_target(id) == "enemy":
		var e := _pick_foe(screen_pos)
		if e == "":
			return
		target = e
	else:
		var gp: Variant = _ground(screen_pos)
		if gp == null:
			return
		target = gp
	var problem := sim.ability_target_problem(id, target)
	if problem != "":
		ui.flash_hint(problem)
		return
	_aim_id = ""
	sim.use_ability(id, target)
	_flush_events()
	_refresh_panel()


func _pick_foe(screen_pos: Vector2) -> String:
	var best := ""
	var bd := PICK_PX * 1.5
	for u in sim.living(Sim.SIDE_FOE):
		var v: Node3D = views[u.id]
		if cam.is_position_behind(v.global_position):
			continue
		var a := cam.unproject_position(v.global_position + Vector3(0, 0.2, 0))
		var b := cam.unproject_position(v.global_position + Vector3(0, 1.8, 0))
		var d := _dist_to_segment(screen_pos, a, b)
		if d < bd:
			bd = d
			best = u.id
	return best


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
	var problem := sim.order_problem(u.id)
	if problem != "":
		ui.flash_hint(problem)
		return
	var apply := func() -> void:
		sim.order_move(u.id, target)
		paused = false
		_flush_events()
		_refresh_panel()
	if bool(sim.oath_of(u.id).get("no_retreat", false)) and sim.is_retreat(u.id, target):
		paused = true
		var on_break := func() -> void:
			sim.break_oath(u.id)
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
				_ability_by_index(0)
			KEY_2:
				_ability_by_index(1)
			KEY_3:
				_ability_by_index(2)
			KEY_4:
				_ability_by_index(3)
			KEY_5:
				_ability_by_index(4)
			KEY_F:
				_charge()
			KEY_SPACE:
				if ui.toast.visible:
					_resume_pause()
				elif phase == Phase.SIGNAL:
					_resume_signal()
				else:
					_use_signal()
			KEY_ESCAPE:
				if _aim_id != "":
					_aim_id = ""
					_refresh_panel()
				elif _route_id != "":
					_route_id = ""
					_route_drawing = false
					_route_raw.clear()
					_refresh_panel()
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
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and (_drag_id != "" or _route_drawing):
			_pointer_up(mb.position)
			get_viewport().set_input_as_handled()


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
	if _aim_id != "":
		_aim_click(screen_pos)
		return
	if not _can_command():
		return
	if phase == Phase.DEPLOY and _route_id != "":
		# režim kreslení trasy: čára začíná u rytíře a vede tam, kam táhneš
		_route_drawing = true
		_route_raw.clear()
		_route_raw.append(sim.by_id(_route_id).pos)
		var gp0: Variant = _ground(screen_pos)
		if gp0 != null:
			_route_raw.append(gp0)
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
	if _aim_id != "":
		var ga: Variant = _ground(screen_pos)
		if ga != null:
			_aim_point = ga
	if not _can_command():
		hover_id = ""
		return
	if _route_drawing:
		var gpr: Variant = _ground(screen_pos)
		if gpr != null and (gpr as Vector2).distance_to(_route_raw[-1]) > 0.4:
			_route_raw.append(gpr)
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
	if _route_drawing:
		_finish_route()
		return
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
			"ability":
				_spawn_fx(String(ev["key"]), ev["pos"])
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
				_aim_id = ""
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
	# efekty schopností doznívají
	for i in range(_fx.size() - 1, -1, -1):
		var fx: Array = _fx[i]
		fx[1] = float(fx[1]) - get_process_delta_time()
		var mi: MeshInstance3D = fx[0]
		(mi.material_override as StandardMaterial3D).albedo_color.a = clampf(float(fx[1]) / 0.6, 0.0, 1.0) * 0.8
		if float(fx[1]) <= 0.0:
			mi.queue_free()
			_fx.remove_at(i)
	# hořící zem (Ohnivá salva)
	while _zone_meshes.size() < sim.zones.size():
		var zd := Field.disc(1.0, Color(1.0, 0.45, 0.1, 0.35))
		add_child(zd)
		_zone_meshes.append(zd)
	for i in _zone_meshes.size():
		var zm: MeshInstance3D = _zone_meshes[i]
		zm.visible = i < sim.zones.size()
		if zm.visible:
			var z: Dictionary = sim.zones[i]
			zm.position = Field.to_world(z["pos"], 0.05)
			zm.scale = Vector3(float(z["r"]), 1.0, float(z["r"]))
	# cílení schopnosti: kruh pod kurzorem (velikost podle schopnosti), červený mimo dosah
	aim_ring.visible = _aim_id != "" and sim.by_id(_aim_id) != null
	if aim_ring.visible:
		var a := sim.ability_of(_aim_id)
		var r := float(a.get("radius", 0.9)) if String(a.get("target", "")) == "point" else 0.9
		aim_ring.scale = Vector3(r, 0.05, r)
		aim_ring.position = Field.to_world(_aim_point, 0.09)
		var tgt: Variant = _aim_point
		var bad := sim.ability_target(_aim_id) == "point" and sim.ability_target_problem(_aim_id, tgt) != ""
		(aim_ring.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.35, 0.3, 0.9) if bad else Color(1.0, 0.85, 0.4, 0.9)

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

	_draw_routes()

	var su := sim.by_id(selected) if selected != "" else null
	select_ring.visible = su != null and su.alive() and (phase == Phase.DEPLOY or phase == Phase.SIGNAL)
	if select_ring.visible:
		select_ring.position = Field.to_world(su.pos, 0.06)
	hold_marker.visible = su != null and su.alive() and phase == Phase.SIGNAL and su.holding
	if hold_marker.visible:
		hold_marker.position = Field.to_world(su.home, 0.06)


## Trasy rytířů: v rozestavení celé, v bitvě jen zbytek. Kreslená čára se ukazuje celá.
func _draw_routes() -> void:
	var im := route_mesh.mesh as ImmediateMesh
	im.clear_surfaces()
	var segs: Array = []
	if phase != Phase.OVER:
		for u in sim.knights():
			if not u.alive() or u.route_i >= u.route.size():
				continue
			var prev := u.pos
			for i in range(u.route_i, u.route.size()):
				segs.append([prev, u.route[i]])
				prev = u.route[i]
	if _route_drawing:
		for i in range(1, _route_raw.size()):
			segs.append([_route_raw[i - 1], _route_raw[i]])
	if segs.is_empty():
		return
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for sg: Array in segs:
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		im.surface_add_vertex(Field.to_world(a, 0.12))
		im.surface_add_vertex(Field.to_world(b, 0.12))
		# šipka na konci úseku
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x)
		for side: float in [-1.0, 1.0]:
			im.surface_add_vertex(Field.to_world(b, 0.12))
			im.surface_add_vertex(Field.to_world(b - d * 0.45 + n * side * 0.25, 0.12))
	im.surface_end()



## Krátký efekt schopnosti: kruh na zemi, který zmizí.
func _spawn_fx(key: String, pos: Vector2) -> void:
	var a: Dictionary = sim.units_data["abilities"].get(key, {})
	var r := float(a.get("radius", 1.2))
	var col := Color(1.0, 0.85, 0.4, 0.8)
	if key == "pozehnani":
		col = Color(0.5, 1.0, 0.6, 0.8)
	elif key == "vyzva":
		col = Color(0.55, 0.7, 1.0, 0.8)
	var ring := Field.ring(r, 0.18, col)
	ring.position = Field.to_world(pos, 0.1)
	add_child(ring)
	_fx.append([ring, 0.6])
