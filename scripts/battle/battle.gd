extends Node3D
## Řídí bitvu: fáze (rozestavení → bitva ↔ pauza → konec), vstup hráče,
## krokování simulace a propojení simulace s 3D scénou a rozhraním.

const Sim := preload("res://scripts/sim/battle_sim.gd")
const Field := preload("res://scripts/battle/battlefield.gd")
const UnitView := preload("res://scripts/battle/unit_view.gd")
const BattleUI := preload("res://scripts/battle/battle_ui.gd")
const OrbitCamera := preload("res://scripts/battle/orbit_camera.gd")

const STEP := 1.0 / 60.0

enum Phase { DEPLOY, BATTLE, PAUSE, OVER }

var data: Dictionary
var setup: Dictionary
var sim: Sim
var phase := Phase.DEPLOY
var selected := ""                 # hlavní vybraný hrdina (karta, přetažení)
var selection: Array = []          # všichni vybraní hrdinové (pravé tlačítko jim dá rozkaz)
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
var _order_marks: Array = []        # kruhy cílů rozkazů (barva hrdiny)
var _warn_marks: Array = []         # ohlášené schopnosti velitelů: [kruh, plocha]
var _order_flash: Dictionary = {}    # id hrdiny -> jak dlouho ještě ukazovat cíl právě daného rozkazu (s)
var scenario_id: String = Sim.DEFAULT_SCENARIO

# výběr cíle rozkazu (Poslat na kartě): hrdina, kterému se vybírá cíl
var _order_id := ""
var _pointer := Vector2.ZERO        # poslední místo kurzoru na zemi
var _acc := 0.0
## Běh (scripts/run/run_state.gd), když je bitva jeho součástí; jinak null (volná bitva).
## Nastavuje run_main.gd před přidáním do stromu.
var run: RefCounted = null

## Bitva v běhu skončila a hráč pokračuje: výsledek ze sim.result().
signal battle_done(result: Dictionary)
var _ui_t := 0.0

# drag & drop rytířů (rozestavení; v bitvě přetažení = rozkaz na místo)
const PICK_PX := 30.0          # tolerance výběru rytíře na obrazovce (px)
const MATE_PICK_PX := 16.0     # rozkaz ke spojenci jen při kliku přímo na něj (jinak je to rozkaz na místo)
const DRAG_START_PX := 6.0     # o kolik se musí myš pohnout, aby začalo táhnutí
var hover_id := ""
var _drag_id := ""
var _drag_active := false
var _drag_press := Vector2.ZERO
var _drag_origin := Vector2.ZERO
var _drag_target := Vector2.ZERO
var _drag_target_raw := Vector2.ZERO
var _rpress := Vector2.ZERO          # kde se stisklo pravé tlačítko (klik = rozkaz, táhnutí = kamera)
var _rdown := false
const CLICK_PX := 12.0   # pravé tlačítko: do tolika px pohybu je to klik (rozkaz), dál posun kamery
var _sel_rings: Array = []           # kroužky pod vybranými hrdiny
var _box_pending := false            # levé tlačítko stisknuté na zemi: klik, nebo tažení obdélníku výběru
var _box_active := false
var _box_on_hero := false            # obdélník začal stiskem na hrdinovi (klik bez tažení výběr neruší)
var _hover_cmd: Array = []           # co by teď udělalo pravé tlačítko: [druh, místo, poloměr]
var _box_start := Vector2.ZERO


func _ready() -> void:
	if run != null:
		scenario_id = String(run.node()["scenario"])
		data = run.load_stage_data()
		setup = run.battle_setup(data)
	else:
		data = Sim.load_data(scenario_id)
		setup = Sim.default_setup(data)
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
	ui.order_pressed.connect(func(id: String) -> void:
		if not _can_command():
			return
		_aim_id = ""
		_order_id = id if _order_id != id else ""
		_refresh_panel())
	ui.order_clear_pressed.connect(_clear_order)
	var choices: Array = []
	for sid: String in ([] if run != null else Sim.scenario_list()):
		choices.append([sid, String(Sim._read_json("res://data/scenarios/%s.json" % sid).get("name", sid))])
	ui.scenario_choices = choices
	ui.start_pressed.connect(_try_start)
	ui.pause_pressed.connect(_toggle_pause)
	ui.charge_pressed.connect(_charge)
	ui.resume_pressed.connect(_toggle_pause)
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


## Výběr bitvy (volná bitva, před začátkem): načte scénář a postaví bojiště znovu.
func _load_scenario(id: String) -> void:
	if id == scenario_id or not (phase == Phase.DEPLOY or (phase == Phase.PAUSE and sim.t == 0.0)):
		return
	scenario_id = id
	data = Sim.load_data(id)
	setup = Sim.default_setup(data)
	field_root.queue_free()
	field_root = Node3D.new()
	add_child(field_root)
	Field.build(field_root, data["scenario"])
	_build_zone()
	_order_id = ""
	_fresh_deploy()


## Zruší rozkaz: hrdina drží místo, kde stojí.
func _clear_order(id: String) -> void:
	if not _can_command():
		return
	sim.set_order(id, "")
	(setup["orders"] as Dictionary).erase(id)
	_order_id = ""
	_refresh_panel()


## Klik při výběru cíle rozkazu: nepřítel = jeho skupina, hrdina = spojenec, jinak místo na zemi.
func _order_click(screen_pos: Vector2) -> void:
	var id := _order_id
	var kind := "point"
	var target: Variant = null
	var foe := _pick_foe(screen_pos)
	var mate := _pick_knight(screen_pos, id)
	if foe != "":
		kind = "group"
		target = sim.group_of(foe)
	elif mate != "":
		kind = "ally"
		target = mate
	else:
		var gp: Variant = _ground(screen_pos)
		if gp == null:
			return
		target = gp
	var problem := sim.order_problem(id, kind, target)
	if problem != "":
		ui.flash_hint(problem)
		return
	_order_id = ""
	_give_order(sim.by_id(id), kind, target)


## Dá rozkaz (v bitvě se u přísahy Nikdy neustoupí zeptá, jestli ji porušit).
func _give_order(u: Sim.Unit, kind: String, target: Variant) -> void:
	var problem := sim.order_problem(u.id, kind, target)
	if problem != "":
		ui.flash_hint(problem)
		_refresh_panel()
		return
	var apply := func() -> void:
		if sim.set_order(u.id, kind, target):
			_order_flash[u.id] = 2.0
			if phase == Phase.DEPLOY:
				setup["orders"][u.id] = [kind, target]
		paused = false
		_flush_events()
		_refresh_panel()
	var retreat := kind == "point" and bool(sim.oath_of(u.id).get("no_retreat", false)) and sim.is_retreat(u.id, target)
	if retreat and phase == Phase.DEPLOY:
		ui.flash_hint("%s složil přísahu „%s“: rozkaz nesmí vést zpět." % [u.name, sim.oath_of(u.id).get("name", "")])
		_refresh_panel()
	elif retreat:
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


## Rozestavení má jen obrana (nepřítel přijde k vám); jinak bitva začne rovnou v pauze.
func _needs_deploy() -> bool:
	return String(data["scenario"].get("mode", "stret")) == "obrana"


func _fresh_deploy() -> void:
	_new_sim()
	_clear_selection()
	phase = Phase.DEPLOY if _needs_deploy() else Phase.PAUSE
	_refresh_panel()


## Začít bitvu (z rozestavení obrany).
func _try_start() -> void:
	if phase != Phase.DEPLOY:
		return
	_order_id = ""
	_start_battle()


## Bitva od začátku: z rozestavení se rovnou běží, jinak začne v pauze (opakování bitvy).
func _start_battle() -> void:
	for u in sim.knights():
		setup["pos"][u.id] = u.pos
	_new_sim()
	phase = Phase.BATTLE if _needs_deploy() else Phase.PAUSE
	_clear_selection()
	_refresh_panel()


func _refresh_panel() -> void:
	if phase == Phase.DEPLOY:
		ui.show_deploy(sim, setup, selection, scenario_id, _order_id)
	else:
		ui.show_battle(sim, phase == Phase.PAUSE, selection, speed, log_lines, _aim_id, _order_id, scenario_id)
	ui.update_dynamic(sim, phase == Phase.PAUSE, paused)


# ================================================================ příkazy

## Klik na kartu: vybere jen tohoto hrdinu (Shift přidá nebo ubere), druhý klik na vybraného
## na něj natočí kameru. Výběr ruší Esc nebo klik na zem.
func _select(id: String) -> void:
	var u := sim.by_id(id)
	if u == null or not u.alive() or phase == Phase.OVER:
		return
	if Input.is_key_pressed(KEY_SHIFT):
		_toggle_in_selection(id)
	elif selection == [id]:
		_focus_camera(u.pos)
	else:
		selection = [id]
		selected = id
	_refresh_panel()


## Klik na hrdinu na bojišti: vybere jen jeho (jako v RTS); Shift ho přidá nebo ubere.
func _set_selected(id: String) -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		_toggle_in_selection(id)
	else:
		selection = [id]
		selected = id
	_refresh_panel()


## Ctrl+A: vybere všechny živé hrdiny.
func _select_all() -> void:
	if phase == Phase.OVER:
		return
	selection = []
	for u in sim.knights():
		if u.alive():
			selection.append(u.id)
	selected = String(selection[0]) if not selection.is_empty() else ""
	_refresh_panel()


## Kamera se natočí na místo na bojišti (druhý klik na kartu vybraného hrdiny).
func _focus_camera(p: Vector2) -> void:
	var oc := cam as OrbitCamera
	oc.target = Vector3(p.x, 0.0, -p.y)
	oc.call("_apply")


func _toggle_in_selection(id: String) -> void:
	if selection.has(id):
		selection.erase(id)
		selected = String(selection[-1]) if not selection.is_empty() else ""
	else:
		selection.append(id)
		selected = id


func _clear_selection() -> void:
	selection = []
	selected = ""


## Výběr tažením: hrdinové, jejichž postava (střed těla) je v obdélníku; Shift přidá k výběru.
func _box_select(rect: Rect2) -> void:
	var picked: Array = []
	for u in sim.knights():
		if not u.alive():
			continue
		var base: Vector3 = (views[u.id] as Node3D).global_position
		if cam.is_position_behind(base):
			continue
		if rect.grow(PICK_PX * 0.3).has_point(cam.unproject_position(base + Vector3(0, 1.0, 0))):
			picked.append(u.id)
	if not Input.is_key_pressed(KEY_SHIFT):
		selection = []
	for id: String in picked:
		if not selection.has(id):
			selection.append(id)
	selected = String(selection[-1]) if not selection.is_empty() else ""
	_refresh_panel()


## Vybraní hrdinové, kteří žijí.
func _selection_alive() -> Array:
	var out: Array = []
	for id: String in selection:
		var u := sim.by_id(id)
		if u != null and u.alive():
			out.append(id)
	return out


## Pasivka zapnutá nebo vypnutá v rozestavení (na zkoušku; ve hře budou odměnou v běhu).
func _on_passive(id: String, key: String, on: bool) -> void:
	if run != null:
		return   # v běhu se pasivky získávají jen jako odměna
	if not (phase == Phase.DEPLOY or (phase == Phase.PAUSE and sim.t == 0.0)):
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
	if (phase != Phase.BATTLE and phase != Phase.PAUSE) or paused:
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
	_order_id = ""
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


## Pauza (mezerník): čas stojí, rozkazy a schopnosti jdou dávat dál.
func _toggle_pause() -> void:
	if paused:
		return
	if phase == Phase.BATTLE:
		phase = Phase.PAUSE
	elif phase == Phase.PAUSE:
		phase = Phase.BATTLE
	else:
		return
	_refresh_panel()


func _resume_pause() -> void:
	if not ui.toast.visible:
		return
	ui.hide_toast()
	paused = false
	_refresh_panel()


## Přetažení hrdiny v bitvě = rozkaz na místo.
func _order_move(u: Sim.Unit, target: Vector2) -> void:
	if sim._in_water(target):
		return
	_give_order(u, "point", target)


# ================================================================ vstup

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match (event as InputEventKey).keycode:
			KEY_A:
				if (event as InputEventKey).ctrl_pressed:
					_select_all()
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
				else:
					_toggle_pause()
			KEY_ESCAPE:
				if _aim_id != "":
					_aim_id = ""
					_refresh_panel()
				elif _order_id != "":
					_order_id = ""
					_refresh_panel()
				elif not selection.is_empty():
					_clear_selection()
					_refresh_panel()
			KEY_ENTER, KEY_KP_ENTER:
				if ui.toast.visible:
					_resume_pause()
				elif phase == Phase.PAUSE:
					_toggle_pause()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_pointer_down(mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_rpress = mb.position
			_rdown = true


func _input(event: InputEvent) -> void:
	# Pohyb a puštění se sledují i nad panelem, aby táhnutí nikdy "neuvízlo".
	if event is InputEventMouseMotion:
		_pointer_move((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and (_drag_id != "" or _box_pending):
			_pointer_up(mb.position)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed and _rdown:
			_rdown = false
			if mb.position.distance_to(_rpress) <= CLICK_PX:
				_command_click(mb.position)   # klik pravým = rozkaz; táhnutí pravým posouvá kameru


func _can_command() -> bool:
	return phase != Phase.OVER and not paused


## Pravé tlačítko s vybranými hrdiny: na nepřítele = jeho skupina, na hrdinu = ke spojenci,
## na zem = na místo (víc hrdinů se rozestaví do řady napříč směrem pohybu).
func _command_click(screen_pos: Vector2) -> void:
	if not _can_command() or _aim_id != "":
		return
	var ids := _selection_alive()
	if ids.is_empty():
		return
	_order_id = ""
	var foe := _pick_foe(screen_pos)
	var mate := _pick_knight(screen_pos, "", MATE_PICK_PX)
	if foe != "":
		for id: String in ids:
			_give_order(sim.by_id(id), "group", sim.group_of(foe))
		return
	if mate != "":
		for id: String in ids:
			if id != mate:
				_give_order(sim.by_id(id), "ally", mate)
		return
	var gp: Variant = _ground(screen_pos)
	if gp == null:
		return
	var p: Vector2 = gp
	if sim._in_water(p):
		ui.flash_hint("Do vody to nejde.")
		return
	var c := Vector2.ZERO
	for id: String in ids:
		c += sim.by_id(id).pos
	c /= ids.size()
	var dir := (p - c).normalized() if p.distance_to(c) > 0.1 else Vector2(0, 1)
	var side := Vector2(-dir.y, dir.x)
	for i in ids.size():
		var q := p + side * (float(i) - (ids.size() - 1) / 2.0) * 1.4
		if sim._in_water(q):
			q = p
		_give_order(sim.by_id(String(ids[i])), "point", q)


## Náhled pravého tlačítka pod kurzorem (pro kruh): skupina nepřátel, spojenec, nebo místo.
func _preview_command(screen_pos: Vector2) -> Array:
	if _aim_id != "" or _order_id != "" or _selection_alive().is_empty() or phase == Phase.DEPLOY:
		return []
	var foe := _pick_foe(screen_pos)
	if foe != "":
		var g := sim.group_of(foe)
		return ["group", g]
	var mate := _pick_knight(screen_pos, "", MATE_PICK_PX)
	if mate != "" and not (selection.size() == 1 and selection[0] == mate):
		return ["ally", mate]
	var gp: Variant = _ground(screen_pos)
	if gp == null:
		return []
	return ["point", gp]


static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Rytíř pod kurzorem: měří se vzdálenost od jeho postavy na obrazovce (od nohou po hlavu),
## takže jde chytit kdekoli na těle, ne jen u nohou.
func _pick_knight(screen_pos: Vector2, exclude: String = "", tol: float = PICK_PX) -> String:
	var best := ""
	var bd := tol
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
	if _order_id != "":
		_order_click(screen_pos)
		return
	var id := _pick_knight(screen_pos)
	if id != "" and phase != Phase.DEPLOY:
		# v bitvě se hrdinové netahají (náhodné rozkazy); stisk na hrdinovi = výběr, tažení = obdélník
		_set_selected(id)
		_box_pending = true
		_box_active = false
		_box_start = screen_pos
		_box_on_hero = true
		return
	if id != "":
		_drag_id = id
		_drag_active = false
		_drag_press = screen_pos
		_drag_origin = sim.by_id(id).pos
		_set_selected(id)
		return
	# na zemi: tažení = obdélník výběru, klik = viz _ground_click (rozhodne se při puštění)
	_box_pending = true
	_box_active = false
	_box_start = screen_pos
	_box_on_hero = false


## Klik na zem: v rozestavení přesune vybraného hrdinu, v bitvě zruší výběr.
func _ground_click(screen_pos: Vector2) -> void:
	if selected == "":
		return
	if phase != Phase.DEPLOY:
		_clear_selection()
		_refresh_panel()
		return
	var gp: Variant = _ground(screen_pos)
	if gp == null:
		return
	var p: Vector2 = gp
	var u := sim.by_id(selected)
	u.pos = _clamp_zone(p)
	u.home = u.pos
	setup["pos"][u.id] = u.pos


func _pointer_move(screen_pos: Vector2) -> void:
	if _aim_id != "":
		var ga: Variant = _ground(screen_pos)
		if ga != null:
			_aim_point = ga
	var gq: Variant = _ground(screen_pos)
	if gq != null:
		_pointer = gq
	if not _can_command():
		hover_id = ""
		return
	hover_id = _pick_knight(screen_pos, _drag_id if _drag_active else "")
	_hover_cmd = _preview_command(screen_pos)
	if _box_pending:
		if not _box_active and screen_pos.distance_to(_box_start) > DRAG_START_PX:
			_box_active = true
		if _box_active:
			ui.show_box(Rect2(_box_start, Vector2.ZERO).expand(screen_pos))
		return
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
	if _box_pending:
		_box_pending = false
		ui.hide_box()
		if not _can_command():
			_box_active = false
			return
		if _box_active:
			_box_active = false
			_box_select(Rect2(_box_start, Vector2.ZERO).expand(screen_pos))
		elif not _box_on_hero:
			_ground_click(screen_pos)
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
		ui.update_dynamic(sim, phase == Phase.PAUSE, paused)
	ui.update_hp_bars(sim, cam, views, phase != Phase.DEPLOY)


func _flush_events() -> void:
	var relog := false
	for ev in sim.events:
		match String(ev["type"]):
			"log":
				log_lines.append(ev)
				relog = true
			"arrive":
				# další vlna nepřátel vstoupila na bojiště
				var nu := sim.by_id(String(ev["id"]))
				if nu != null and not views.has(nu.id):
					var nv := UnitView.new()
					nv.setup(nu)
					add_child(nv)
					views[nu.id] = nv
			"ability":
				_spawn_fx(String(ev["key"]), ev["pos"])
				var av: UnitView = views.get(String(ev.get("id", "")))
				if av != null:
					av.play_ability(speed)
			"wake", "warn":
				ui.flash_hint(String(ev.get("text", "")))
			"skill":
				var sr := Field.ring(maxf(float(ev.get("radius", 1.0)), 0.9), 0.2, Color(1.0, 0.3, 0.2, 0.85))
				sr.position = Field.to_world(ev["pos"], 0.1)
				add_child(sr)
				_fx.append([sr, 0.6])
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
	drop_ring.visible = dragging and (phase != Phase.DEPLOY or invalid)
	if drop_ring.visible:
		drop_ring.position = Field.to_world(_drag_target_raw if invalid else _drag_target, 0.08)
		(drop_ring.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.35, 0.3, 0.9) if invalid else Color(0.4, 1.0, 0.5, 0.9)
	var im := order_line.mesh as ImmediateMesh
	im.clear_surfaces()
	if dragging and phase != Phase.DEPLOY:
		var from := Field.to_world(sim.by_id(_drag_id).pos, 0.1)
		var to := Field.to_world(_drag_target, 0.1)
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		im.surface_add_vertex(from)
		im.surface_add_vertex(to)
		im.surface_end()

	_sync_order_marks()
	_sync_warnings()

	# kroužky pod vybranými hrdiny v barvě hrdiny (hlavní výběr silnější)
	var sel_alive := _selection_alive() if phase != Phase.OVER else []
	while _sel_rings.size() < sel_alive.size():
		var r := Field.ring(0.65, 0.09, Color(1, 1, 1, 0.8))
		add_child(r)
		_sel_rings.append(r)
	for i in _sel_rings.size():
		var ring: MeshInstance3D = _sel_rings[i]
		ring.visible = i < sel_alive.size() and String(sel_alive[i]) != selected
		if ring.visible:
			var us := sim.by_id(String(sel_alive[i]))
			ring.position = Field.to_world(us.pos, 0.06)
			(ring.material_override as StandardMaterial3D).albedo_color = hero_color(us, 0.85)
	var su := sim.by_id(selected) if selected != "" else null
	select_ring.visible = su != null and su.alive() and phase != Phase.OVER
	if select_ring.visible:
		select_ring.position = Field.to_world(su.pos, 0.06)
		(select_ring.material_override as StandardMaterial3D).albedo_color = hero_color(su, 1.0)
	hold_marker.visible = su != null and su.alive() and phase != Phase.DEPLOY and phase != Phase.OVER and (su.order == "" or su.order_done)
	if hold_marker.visible:
		hold_marker.position = Field.to_world(su.home, 0.06)


## Ohlášené schopnosti velitelů: červený kruh a plocha, které sílí, jak se blíží dopad.
func _sync_warnings() -> void:
	var ws: Array = sim.warnings() if phase != Phase.OVER else []
	while _warn_marks.size() < ws.size():
		var ring := Field.ring(1.0, 0.08, Color(1.0, 0.25, 0.2, 0.9))
		var area := Field.disc(1.0, Color(1.0, 0.2, 0.15, 0.25))
		add_child(ring)
		add_child(area)
		_warn_marks.append([ring, area])
	for i in _warn_marks.size():
		var pair: Array = _warn_marks[i]
		var ring: MeshInstance3D = pair[0]
		var area: MeshInstance3D = pair[1]
		ring.visible = i < ws.size()
		area.visible = ring.visible
		if not ring.visible:
			continue
		var w: Dictionary = ws[i]
		var r: float = w["radius"]
		var urgency := clampf(1.0 - float(w["t"]) / 1.8, 0.0, 1.0)
		ring.position = Field.to_world(w["pos"], 0.11)
		ring.scale = Vector3(r, 0.05, r)
		area.position = Field.to_world(w["pos"], 0.06)
		area.scale = Vector3(r, 1.0, r)
		(area.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.2, 0.15, 0.15 + 0.35 * urgency)


## Barva hrdiny pro kruhy na bojišti (zesvětlená barva z dat, aby byla vidět na trávě).
static func hero_color(u: Sim.Unit, alpha: float) -> Color:
	var c := u.color.lightened(0.3)
	c.a = alpha
	return c


## Kruhy cílů rozkazů v barvě hrdiny: na místo malý kruh, na skupinu kruh kolem jejího středu, ke spojenci
## kruh pod spojencem (víc hrdinů se stejným cílem = soustředné kruhy). V rozestavení a v pauze u všech,
## v běžící bitvě u vybraných a chvíli po daném rozkazu. Při výběru cíle (Poslat) kruh pod kurzorem.
func _sync_order_marks() -> void:
	var dt := get_process_delta_time()
	for id: String in _order_flash.keys():
		_order_flash[id] = float(_order_flash[id]) - dt
		if float(_order_flash[id]) <= 0.0:
			_order_flash.erase(id)
	var marks: Array = []   # [místo, poloměr, barva]
	if phase != Phase.OVER:
		var all := phase == Phase.DEPLOY or phase == Phase.PAUSE
		var ks := sim.knights()
		for i in ks.size():
			var u: Sim.Unit = ks[i]
			if not u.alive() or u.order == "" or u.order_done:
				continue
			if not (all or selection.has(u.id) or _order_flash.has(u.id)):
				continue
			var col := hero_color(u, 0.9)
			match u.order:
				"point":
					marks.append([u.order_pos, 0.45, col])
				"group":
					if not sim.group_members(u.order_group).is_empty():
						marks.append([sim.group_center(u.order_group), 1.2 + 0.15 * i, col])
				"ally":
					var a := sim.by_id(u.order_ally)
					if a != null and a.alive():
						marks.append([a.pos, 0.9 + 0.12 * i, col])
		if _order_id != "" and sim.by_id(_order_id) != null:
			marks.append([_pointer, 0.45, hero_color(sim.by_id(_order_id), 0.6)])
		elif not _hover_cmd.is_empty() and not _selection_alive().is_empty():
			match String(_hover_cmd[0]):
				"group":
					if not sim.group_members(_hover_cmd[1]).is_empty():
						marks.append([sim.group_center(_hover_cmd[1]), 1.6, Color(1.0, 0.35, 0.3, 0.7)])
				"ally":
					var hm := sim.by_id(String(_hover_cmd[1]))
					if hm != null and hm.alive():
						marks.append([hm.pos, 1.0, Color(0.6, 0.85, 1.0, 0.6)])
				"point":
					marks.append([_hover_cmd[1], 0.35, Color(1, 1, 1, 0.45)])
	while _order_marks.size() < marks.size():
		var r := Field.ring(1.0, 0.12, Color.WHITE)
		add_child(r)
		_order_marks.append(r)
	for i in _order_marks.size():
		var ring: MeshInstance3D = _order_marks[i]
		ring.visible = i < marks.size()
		if ring.visible:
			var m: Array = marks[i]
			var r: float = m[1]
			ring.position = Field.to_world(m[0], 0.1)
			ring.scale = Vector3(r, 0.05, r)
			(ring.material_override as StandardMaterial3D).albedo_color = m[2]


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
