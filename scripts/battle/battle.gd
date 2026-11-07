extends Node3D
## Runs the battle: phases (deployment → battle ↔ pause → end), player input,
## stepping the simulation and wiring the simulation to the 3D scene and the UI.

const Sim := preload("res://scripts/sim/battle_sim.gd")
const Field := preload("res://scripts/battle/battlefield.gd")
const UnitView := preload("res://scripts/battle/unit_view.gd")
const BattleUI := preload("res://scripts/battle/battle_ui.gd")
const OrbitCamera := preload("res://scripts/battle/orbit_camera.gd")

const STEP := 1.0 / 60.0
const SETTINGS := "user://nastaveni.cfg"   # player settings (tutorial done)

## Tutorial (data/vycvik.json): 0 = only until the player finishes or skips it, 1 = always, -1 = never (tests).
static var tutorial_mode := 0
var _tut_steps: Array = []
var _tut_i := -1                     # tutorial step (-1 = tutorial not running)
var _tut_flags: Dictionary = {}      # what the player has already done (done keys from the data)
var _tut_data: Dictionary = {}
var _tut_fired: Dictionary = {}      # steps whose situation (trigger) has already happened
var _tut_shown := ""                 # what the panel is showing now (step:wait/go), so it is not rebuilt every frame
var _tut_paused := false             # the tutorial paused the battle (the test continues accordingly)

enum Phase { DEPLOY, BATTLE, PAUSE, OVER }

var data: Dictionary
var setup: Dictionary
var sim: Sim
var phase := Phase.DEPLOY
var selected := ""                 # main selected hero (card, dragging)
var selection: Array = []          # all selected heroes (the right button gives them an order)
var speed := 1.0
var paused := false        # automatic pause or an open dialog
var log_lines: Array = []

var cam: Camera3D
var ui: BattleUI
var views: Dictionary = {}
var projectile_views: Dictionary = {}
var aim_ring: MeshInstance3D      # ability targeting: circle under the cursor
var _fx: Array = []                # short ability effects [MeshInstance3D, time left]
var _aim_id := ""                  # the hero whose ability is being aimed
var _aim_combo := ""                # bond combo being aimed (with _aim_id = who aims)
var _aim_point := Vector2.ZERO
## Ground zones from the simulation by kind: burning ground, Sacred Circle, Holy Light, Smoke, Bulwark.
const ZONE_COLORS := {
	"fire": Color(1.0, 0.45, 0.1, 0.35),
	"kruh": Color(0.5, 1.0, 0.6, 0.3),
	"svetlo": Color(1.0, 0.95, 0.6, 0.45),
	"kour": Color(0.55, 0.55, 0.6, 0.55),
	"hradba": Color(0.55, 0.7, 1.0, 0.25),
}
var _zone_meshes: Array = []      # burning ground from the simulation (sim.zones)
var select_ring: MeshInstance3D
var hold_marker: MeshInstance3D
var hover_ring: MeshInstance3D
var drop_ring: MeshInstance3D
var order_line: MeshInstance3D
var zone: MeshInstance3D
var field_root: Node3D
var _order_marks: Array = []        # order target circles (hero colour)
var _warn_marks: Array = []         # announced commander abilities: [ring, area]
var _order_flash: Dictionary = {}    # hero id -> how much longer to show the target of the order just given (s)
var _engage_warned: Dictionary = {}   # hero id -> true: Never Retreat warning already shown this battle
var _outline: MeshInstance3D          # dark outline around silhouettes (diorama look, style test 2.0s)
var scenario_id: String = Sim.DEFAULT_SCENARIO

# order target picking (Send on the card): the hero whose target is being picked
var _order_id := ""
var _pointer := Vector2.ZERO        # last cursor position on the ground
var _acc := 0.0
## The run (scripts/run/run_state.gd) when the battle is part of one; otherwise null (free battle).
## Set by run_main.gd before adding to the tree.
var run: RefCounted = null

## A run battle ended and the player continues: the result from sim.result().
signal battle_done(result: Dictionary)
var _ui_t := 0.0

# drag & drop of heroes (deployment; in battle dragging = order to a place)
const PICK_PX := 30.0          # hero picking tolerance on screen (px)
const MATE_PICK_PX := 16.0     # order to an ally only when clicking right on him (otherwise it is an order to a place)
const DRAG_START_PX := 6.0     # how far the mouse must move for a drag to start
var hover_id := ""
var _drag_id := ""
var _drag_active := false
var _drag_press := Vector2.ZERO
var _drag_origin := Vector2.ZERO
var _drag_target := Vector2.ZERO
var _drag_target_raw := Vector2.ZERO
var _sel_rings: Array = []           # rings under the selected heroes
var _box_pending := false            # left button pressed on the ground: click, or dragging a selection box
var _box_active := false
var _box_on_hero := false            # the box started with a press on a hero (a click without dragging does not clear the selection)
var _hover_cmd: Array = []           # what the right button would do now: [kind, place, radius]
var _box_start := Vector2.ZERO


func _ready() -> void:
	if run != null:
		scenario_id = String(run.node()["scenario"])
		data = run.load_stage_data()
		setup = run.battle_setup(data)
	else:
		data = Sim.load_data(scenario_id)
		setup = _free_setup(data)
	field_root = Node3D.new()
	add_child(field_root)
	Field.build(field_root, data["scenario"], data["units"].get("camera", {}))

	cam = OrbitCamera.new()
	add_child(cam)
	cam.make_current()
	_configure_camera()
	_outline = Field.Diorama.attach_outline(cam)
	_outline.visible = data["scenario"].has("look")

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
		ui.run_label = "%s · %s · floor %d of %d" % [run.act["name"], run.NODE_NAMES.get(run.node_type(), ""), run.current_floor(), run.floor_count()]
	add_child(ui)
	ui.run_continue_pressed.connect(func() -> void: battle_done.emit(sim.result()))
	ui.knight_clicked.connect(_select)
	ui.ability_pressed.connect(_ability)
	ui.combo_pressed.connect(_combo)
	ui.passive_toggled.connect(_on_passive)
	ui.ability_chosen.connect(_on_ability_chosen)
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
	ui.tutorial_skip_pressed.connect(_tut_finish)
	ui.tutorial_ok_pressed.connect(func() -> void: _tut_mark("ok"))

	_fresh_deploy()
	_tut_init()


# ================================================================ tutorial

## Is the tutorial done (finished or skipped)? Stored in the player settings.
static func tutorial_done() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) != OK:
		return false
	return bool(cfg.get_value("vycvik", "hotovo", false))


static func set_tutorial_done(done: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("vycvik", "hotovo", done)
	cfg.save(SETTINGS)


func _tut_init() -> void:
	if tutorial_mode < 0 or (tutorial_mode == 0 and tutorial_done()):
		return
	_tut_data = Sim._read_json("res://data/vycvik.json")
	_tut_steps = _tut_data.get("steps", [])
	if _tut_steps.is_empty():
		return
	_tut_i = 0
	_tut_flags = {}
	_tut_shown = ""
	_tut_update()


func _tut_step() -> Dictionary:
	return _tut_steps[_tut_i]


## Every frame: is a step waiting for a situation (trigger)? When it happens, the battle pauses and the step shows.
## The tutorial card is pinned to what the step is about (anchor).
func _tut_update() -> void:
	if _tut_i < 0:
		return
	var st := _tut_step()
	var trig := String(st.get("trigger", ""))
	var waiting := trig != "" and not _tut_fired.has(_tut_i)
	if waiting and _tut_trigger(trig):
		waiting = false
		_tut_fired[_tut_i] = true
		if phase == Phase.BATTLE:
			phase = Phase.PAUSE   # so the player has time to react
			_tut_paused = true
			_refresh_panel()
		var wp: Variant = _tut_world(String(st.get("anchor", "")))
		if wp != null:
			_focus_camera(wp)   # so it is visible what is going on
	var key := "%d:%s" % [_tut_i, "wait" if waiting else "go"]
	if key != _tut_shown:
		_tut_shown = key
		var text := String(st.get("wait_text", "")) if waiting else String(st["text"])
		ui.show_tutorial(String(_tut_data.get("title", "Tutorial")), _tut_i + 1, _tut_steps.size(), text, not waiting and String(st["done"]) == "ok")
	ui.point_tutorial(null if waiting else _tut_anchor(String(st.get("anchor", ""))))


## Has the situation the step waits for happened?
func _tut_trigger(trig: String) -> bool:
	match trig:
		"contact":
			for f in sim.living(Sim.SIDE_FOE):
				if f.asleep or f.fleeing:
					continue
				for k in sim.living(Sim.SIDE_KNIGHT):
					if f.pos.distance_to(k.pos) <= 10.0:
						return true
		"combat":
			for k in sim.living(Sim.SIDE_KNIGHT):
				if sim.t - k.combat_t <= 0.3:
					return true
		"warn":
			return not sim.warnings().is_empty()
	return false


## The battlefield spot the step is about (heroes, the spot ahead of them, an enemy, a commander's circle), or null.
func _tut_world(anchor: String) -> Variant:
	var ks := sim.living(Sim.SIDE_KNIGHT)
	var c := Vector2.ZERO
	for k in ks:
		c += k.pos
	if not ks.is_empty():
		c /= ks.size()
	match anchor:
		"heroes":
			return c
		"ahead":
			var front := -INF
			for k in ks:
				front = maxf(front, k.pos.y)
			return Vector2(c.x, front + 3.0)   # in front of the foremost hero, so the click does not land on an ally
		"foe":
			var best: Sim.Unit = null
			for f in sim.living(Sim.SIDE_FOE):
				if f.asleep or f.fleeing:
					continue
				if best == null or f.pos.distance_to(c) < best.pos.distance_to(c):
					best = f
			return best.pos if best != null else null
		"warn":
			var w := sim.warnings()
			if not w.is_empty():
				return (w[0] as Dictionary)["pos"]
	return null


## The screen point the tutorial card belongs to (or null = default spot below the log).
func _tut_anchor(anchor: String) -> Variant:
	var ks := sim.living(Sim.SIDE_KNIGHT)
	match anchor:
		"heroes", "foe":
			var wp: Variant = _tut_world(anchor)
			return _tut_screen(wp, 1.1) if wp != null else null
		"ahead", "warn":
			var gp: Variant = _tut_world(anchor)
			return _tut_screen(gp, 0.0) if gp != null else null
		"pause":
			var r := ui.top_bar.get_global_rect()
			return Vector2(r.get_center().x, r.end.y)
		"cards":
			for k in ks:
				var b: Variant = ui._ability_buttons.get(k.id)
				if b != null and is_instance_valid(b) and sim.can_use_ability(k.id):
					var r := (b as Control).get_global_rect()
					return Vector2(r.get_center().x, r.position.y)
	return null


func _tut_screen(p: Vector2, h: float) -> Variant:
	var w := Field.to_world(p, h)
	if cam.is_position_behind(w):
		return null
	return cam.unproject_position(w)


## The player did something the tutorial watches; when it is the step's goal, move on (also over steps already done).
func _tut_mark(key: String) -> void:
	if _tut_i < 0 or _tut_flags.has(key):
		return
	_tut_flags[key] = true
	while _tut_i < _tut_steps.size() and _tut_flags.has(String(_tut_step()["done"])):
		_tut_i += 1
		if _tut_i >= _tut_steps.size():
			break
	if _tut_i >= _tut_steps.size():
		_tut_finish()
	else:
		_tut_update()


func _tut_finish() -> void:
	if _tut_i < 0:
		return
	_tut_i = -1
	ui.hide_tutorial()
	if tutorial_mode == 0:
		set_tutorial_done(true)


# ================================================================ state

func _build_zone() -> void:
	var z: Dictionary = data["scenario"]["deploy_zone"]
	var zm := PlaneMesh.new()
	zm.size = Vector2(float(z["x1"]) - float(z["x0"]), float(z["y1"]) - float(z["y0"]))
	zone.mesh = zm
	zone.position = Field.to_world(Vector2((float(z["x0"]) + float(z["x1"])) / 2.0, (float(z["y0"]) + float(z["y1"])) / 2.0), 0.03)


## Camera by map: fixed angle, default view and pan bounds (units.json `camera` + scenario `camera`).
func _configure_camera() -> void:
	(cam as OrbitCamera).configure(data["units"].get("camera", {}), data["scenario"].get("camera", {}))


## Battle choice (free battle, before the start): loads the scenario and rebuilds the battlefield.
func _load_scenario(id: String) -> void:
	if id == scenario_id or not (phase == Phase.DEPLOY or (phase == Phase.PAUSE and sim.t == 0.0)):
		return
	scenario_id = id
	data = Sim.load_data(id)
	var keep_abilities: Dictionary = setup.get("abilities", {})
	setup = _free_setup(data)
	setup["abilities"] = keep_abilities   # the tried abilities stay across battles
	field_root.queue_free()
	field_root = Node3D.new()
	add_child(field_root)
	Field.build(field_root, data["scenario"], data["units"].get("camera", {}))
	_outline.visible = data["scenario"].has("look")
	_build_zone()
	_configure_camera()
	_order_id = ""
	_fresh_deploy()


## Cancels the order: the hero holds the place where he stands.
func _clear_order(id: String) -> void:
	if not _can_command():
		return
	sim.set_order(id, "")
	(setup["orders"] as Dictionary).erase(id)
	_order_id = ""
	_refresh_panel()


## Click while picking an order target: enemy = his group, hero = ally, otherwise a spot on the ground.
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


## Gives an order (if it would break an oath, in battle asks whether to break it; in deployment refuses it).
func _give_order(u: Sim.Unit, kind: String, target: Variant) -> void:
	var problem := sim.order_problem(u.id, kind, target)
	if problem != "":
		ui.flash_hint(problem)
		_refresh_panel()
		return
	var apply := func() -> void:
		if sim.set_order(u.id, kind, target):
			_order_flash[u.id] = 2.0
			_tut_mark("order_" + kind)
			if phase == Phase.DEPLOY:
				setup["orders"][u.id] = [kind, target]
		paused = false
		_flush_events()
		_refresh_panel()
	var conflict := sim.order_oath_conflict(u.id, kind, target)
	if conflict != "" and phase == Phase.DEPLOY:
		ui.flash_hint("%s has sworn the oath “%s”: %s." % [u.name, sim.oath_of(u.id).get("name", ""), conflict])
		_refresh_panel()
	elif conflict != "":
		paused = true
		var on_break := func() -> void:
			sim.break_oath(u.id)
			apply.call()
		var on_keep := func() -> void:
			paused = false
			_refresh_panel()
		ui.ask_oath(u.name, sim.oath_of(u.id), conflict, on_break, on_keep)
	else:
		# Never Retreat: the first time in a battle he is sent at an enemy, say that the clash is final
		var warn := sim.engage_warning(u.id, kind)
		apply.call()
		if warn != "" and not _engage_warned.has(u.id):
			_engage_warned[u.id] = true
			ui.flash_hint(warn, 4.0)


## Uses an ability; if it would break an oath, asks first (Break / Cancel).
func _use_ability_asking(id: String, target: Variant) -> void:
	var conflict := sim.ability_oath_conflict(id, target)
	var go := func() -> void:
		if sim.use_ability(id, target):
			_flush_events()
		paused = false if conflict != "" else paused
		_refresh_panel()
	if conflict == "":
		go.call()
		return
	var u := sim.by_id(id)
	paused = true
	var keep := func() -> void:
		paused = false
		_refresh_panel()
	ui.ask_oath(u.name, sim.oath_of(id), conflict, go, keep, "Cancel ability")

func _new_sim() -> void:
	sim = Sim.new(data, setup)
	_engage_warned.clear()
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


## Only defense has deployment (the enemy comes to you); otherwise the battle starts paused.
func _needs_deploy() -> bool:
	return String(data["scenario"].get("mode", "stret")) == "obrana"


func _fresh_deploy() -> void:
	_new_sim()
	_clear_selection()
	phase = Phase.DEPLOY if _needs_deploy() else Phase.PAUSE
	_refresh_panel()


## Start the battle (from defense deployment).
func _try_start() -> void:
	if phase != Phase.DEPLOY:
		return
	_order_id = ""
	_start_battle()


## Battle from the start: from deployment it runs straight away, otherwise it starts paused (battle retry).
func _start_battle() -> void:
	for u in sim.knights():
		setup["pos"][u.id] = u.pos
	_new_sim()
	phase = Phase.BATTLE if _needs_deploy() else Phase.PAUSE
	if phase == Phase.BATTLE:
		_tut_mark("running")
	_clear_selection()
	_refresh_panel()


## Free battle setup: default deployment plus trial bonds from the house (trial_bonds) so combos can be tried.
static func _free_setup(d: Dictionary) -> Dictionary:
	var st := Sim.default_setup(d)
	st["bonds"] = (d["house"].get("trial_bonds", {}) as Dictionary).duplicate(true)
	return st


func _refresh_panel() -> void:
	if phase == Phase.DEPLOY:
		ui.show_deploy(sim, setup, selection, scenario_id, _order_id)
	else:
		ui.show_battle(sim, phase == Phase.PAUSE, selection, speed, log_lines, _aim_id, _order_id, scenario_id)
	ui.update_dynamic(sim, phase == Phase.PAUSE, paused)


# ================================================================ commands

## Click on a card: selects only this hero (Shift adds or removes), a second click on the selected one
## pans the camera to him. Esc or a click on the ground clears the selection.
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
	_tut_mark("selected")
	_refresh_panel()


## Click on a hero on the battlefield: selects only him (as in an RTS); Shift adds or removes him.
func _set_selected(id: String) -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		_toggle_in_selection(id)
	else:
		selection = [id]
		selected = id
	if not selection.is_empty():
		_tut_mark("selected")
	_refresh_panel()


## H: the selected heroes cancel their orders and hold where they stand.
func _hold_selected() -> void:
	if not _selection_alive().is_empty():
		_tut_mark("hold")
	for id: String in _selection_alive():
		_clear_order(id)


## Ctrl+A: selects all living heroes.
func _select_all() -> void:
	if phase == Phase.OVER:
		return
	selection = []
	for u in sim.knights():
		if u.alive():
			selection.append(u.id)
	selected = String(selection[0]) if not selection.is_empty() else ""
	if not selection.is_empty():
		_tut_mark("selected")
	_refresh_panel()


## The camera turns to a spot on the battlefield (second click on the selected hero's card).
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


## Box selection: heroes whose figure (body centre) is in the box; Shift adds to the selection.
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
	if not selection.is_empty():
		_tut_mark("selected")
	_refresh_panel()


## Selected heroes who are alive.
func _selection_alive() -> Array:
	var out: Array = []
	for id: String in selection:
		var u := sim.by_id(id)
		if u != null and u.alive():
			out.append(id)
	return out


## Passive toggled in deployment (for trial; in the game they are run rewards).
func _on_passive(id: String, key: String, on: bool) -> void:
	if run != null:
		return   # in a run passives come only as rewards
	if not (phase == Phase.DEPLOY or (phase == Phase.PAUSE and sim.t == 0.0)):
		return
	if on:
		var problem := sim.passive_problem(id, key)
		if problem != "":
			ui.flash_hint(problem)
	if sim.set_passive(id, key, on):
		setup["passives"][id] = sim.passives_of(id).duplicate()
	_refresh_panel()


## Free battle: try another ability of the class before the start (refinements of the old one fall away).
func _on_ability_chosen(id: String, key: String) -> void:
	if run != null or not (phase == Phase.DEPLOY or (phase == Phase.PAUSE and sim.t == 0.0)):
		return
	if sim.set_ability(id, key):
		if not setup.has("abilities"):
			setup["abilities"] = {}
		setup["abilities"][id] = key
		setup["passives"][id] = sim.passives_of(id).duplicate()
	_refresh_panel()


## Hero ability (card or key 1–5). Without a target it is used at once, otherwise targeting starts.
func _ability(id: String) -> void:
	if (phase != Phase.BATTLE and phase != Phase.PAUSE) or paused:
		return
	if not sim.can_use_ability(id):
		ui.flash_hint(sim.ability_problem(id))
		return
	if sim.ability_target(id) == "none":
		_use_ability_asking(id, null)
		return
	_aim_id = "" if _aim_id == id else id
	_order_id = ""
	_refresh_panel()


## Bond combo (button or Q / E): without aiming it fires at once, otherwise targeting with the aiming ability starts.
func _combo(cid: String) -> void:
	if (phase != Phase.BATTLE and phase != Phase.PAUSE) or paused:
		return
	var problem := sim.combo_problem(cid)
	if problem != "":
		ui.flash_hint(problem)
		return
	var aimer := sim.combo_aimer(cid)
	if aimer == "":
		if sim.use_combo(cid):
			_tut_mark("ability")
			_flush_events()
		_refresh_panel()
		return
	if _aim_combo == cid:
		_aim_combo = ""
		_aim_id = ""
	else:
		_aim_combo = cid
		_aim_id = aimer
	_order_id = ""
	_refresh_panel()


func _combo_by_index(i: int) -> void:
	var list := sim.combos()
	if i < list.size():
		_combo(String(list[i]["id"]))


func _ability_by_index(i: int) -> void:
	var ks := sim.knights()
	if i < ks.size():
		_ability(ks[i].id)


## Click while targeting: a spot on the ground, or the enemy under the cursor.
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
	if _aim_combo != "":
		var cp := sim.combo_target_problem(_aim_combo, target)
		if cp != "":
			ui.flash_hint(cp)
			return
		var cid := _aim_combo
		_aim_combo = ""
		_aim_id = ""
		sim.use_combo(cid, target)
		_flush_events()
		_refresh_panel()
		return
	var problem := sim.ability_target_problem(id, target)
	if problem != "":
		ui.flash_hint(problem)
		return
	_aim_id = ""
	_use_ability_asking(id, target)


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


## Pause (Space): time stops, orders and abilities can still be given.
func _toggle_pause() -> void:
	if paused:
		return
	_tut_paused = false
	if phase == Phase.DEPLOY:
		_try_start()   # Space in deployment (defense) starts the battle
		return
	if phase == Phase.BATTLE:
		phase = Phase.PAUSE
	elif phase == Phase.PAUSE:
		phase = Phase.BATTLE
		_tut_mark("running")
	else:
		return
	_refresh_panel()


func _resume_pause() -> void:
	if not ui.toast.visible:
		return
	ui.hide_toast()
	paused = false
	_refresh_panel()


## Dragging a hero in battle = order to a place.
func _order_move(u: Sim.Unit, target: Vector2) -> void:
	if sim._in_water(target):
		return
	_give_order(u, "point", target)


# ================================================================ vstup

func _unhandled_input(event: InputEvent) -> void:
	if ui.oath_open():
		# the oath question is open: Esc keeps the oath, other keys wait for the answer
		if event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
			ui.oath_keep()
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match (event as InputEventKey).keycode:
			KEY_A:
				if (event as InputEventKey).ctrl_pressed:
					_select_all()
			KEY_H:
				_hold_selected()
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
			KEY_Q:
				_combo_by_index(0)
			KEY_E:
				_combo_by_index(1)
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
					_aim_combo = ""
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
			_command_click(mb.position)   # right button = order (the camera does not move with it)


func _input(event: InputEvent) -> void:
	# Motion and release are tracked over the panel too, so a drag never "gets stuck".
	if event is InputEventMouseMotion:
		_pointer_move((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and (_drag_id != "" or _box_pending):
			_pointer_up(mb.position)
			get_viewport().set_input_as_handled()


func _can_command() -> bool:
	return phase != Phase.OVER and not paused


## Right button with selected heroes: on an enemy = his group, on a hero = with ally,
## on the ground = to a place (several heroes line up across the direction of movement).
## The right button always performs an action: if an ability is being aimed, uses it; if a target is being picked with
## Send, gives the order; otherwise sends the selected heroes (decision 30.10.2026: one button for actions).
func _command_click(screen_pos: Vector2) -> void:
	if not _can_command():
		return
	if _aim_id != "":
		_aim_click(screen_pos)
		return
	if _order_id != "":
		_order_click(screen_pos)
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
		ui.flash_hint("Can't go into the water.")
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


## Preview of the right button under the cursor (for the circle): enemy group, ally, or place.
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


## Hero under the cursor: measured from his figure on screen (from feet to head),
## so he can be grabbed anywhere on the body, not just at the feet.
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
		# heroes are not dragged in battle (accidental orders); a press on a hero = selection, a drag = box
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
	# on the ground: drag = selection box, click = see _ground_click (decided on release)
	_box_pending = true
	_box_active = false
	_box_start = screen_pos
	_box_on_hero = false


## Click on the ground: in deployment moves the selected hero, in battle clears the selection.
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
		# dropping on another hero = swap places
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


# ================================================================ loop

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

	if _tut_i >= 0:
		if phase == Phase.BATTLE:
			_tut_mark("running")
		if phase == Phase.OVER:
			_tut_i = -1   # the battle ended early: the tutorial shows again in the next battle
			ui.hide_tutorial()
		else:
			_tut_update()

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
				# another enemy wave entered the battlefield
				var nu := sim.by_id(String(ev["id"]))
				if nu != null and not views.has(nu.id):
					var nv := UnitView.new()
					nv.setup(nu)
					add_child(nv)
					views[nu.id] = nv
			"ability":
				_spawn_fx(String(ev["key"]), ev["pos"])
				_tut_mark("ability")
				var av: UnitView = views.get(String(ev.get("id", "")))
				if av != null:
					av.play_ability(speed)
			"wake", "warn":
				ui.flash_hint(String(ev.get("text", "")))
			"oath_broken":
				var bu := sim.by_id(String(ev.get("id", "")))
				if bu != null and String(ev.get("text", "")) != "":
					ui.flash_hint("%s broke his oath: %s." % [bu.name, ev["text"]])
				relog = true
			"skill":
				var sr := Field.ring(maxf(float(ev.get("radius", 1.0)), 0.9), 0.2, Color(1.0, 0.3, 0.2, 0.85))
				sr.position = Field.to_world(ev["pos"], 0.1)
				add_child(sr)
				_fx.append([sr, 0.6])
			"decided":
				# a decided battle plays out faster
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


## Projectile from a model (the shooter's projectile_model, GLB with the tip along Y): the node points along -Z like look_at.
## Colour from the shooter's palette (his role row). Without a model null (then a placeholder shape).
func _projectile_model(shooter: Sim.Unit) -> Node3D:
	if shooter == null:
		return null
	var path := String(shooter.base.get("projectile_model", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var root := Node3D.new()
	var m := (load(path) as PackedScene).instantiate() as Node3D
	m.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO)
	root.add_child(m)
	var v: UnitView = views.get(shooter.id)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		if v != null and v.palette_mat != null:
			(mi as MeshInstance3D).material_override = v.palette_mat
	return root


func _sync_projectiles() -> void:
	var alive := {}
	for p in sim.projectiles:
		alive[p.id] = true
		var mi: Node3D = projectile_views.get(p.id)
		if mi == null:
			var shooter := sim.by_id(p.from_id)
			mi = _projectile_model(shooter)
		if mi == null:
			mi = MeshInstance3D.new()
			var shooter := sim.by_id(p.from_id)
			if shooter != null and String(shooter.base.get("projectile", "")) == "svetlo":
				# priest: golden light from the staff
				var sm := SphereMesh.new()
				sm.radius = 0.13
				sm.height = 0.26
				(mi as MeshInstance3D).mesh = sm
				var lm := StandardMaterial3D.new()
				lm.albedo_color = Color("#ffe9a8")
				lm.emission_enabled = true
				lm.emission = Color("#ffd36a")
				lm.emission_energy_multiplier = 2.5
				(mi as MeshInstance3D).material_override = lm
			else:
				var m := BoxMesh.new()
				m.size = Vector3(0.05, 0.05, 0.7)
				(mi as MeshInstance3D).mesh = m
				(mi as MeshInstance3D).material_override = Field.mat(Color("#5a3d22"))
		if mi.get_parent() == null:
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
	# ability effects fade out
	for i in range(_fx.size() - 1, -1, -1):
		var fx: Array = _fx[i]
		fx[1] = float(fx[1]) - get_process_delta_time()
		var mi: MeshInstance3D = fx[0]
		(mi.material_override as StandardMaterial3D).albedo_color.a = clampf(float(fx[1]) / 0.6, 0.0, 1.0) * 0.8
		if float(fx[1]) <= 0.0:
			mi.queue_free()
			_fx.remove_at(i)
	# burning ground (Fire Volley)
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
			(zm.material_override as StandardMaterial3D).albedo_color = ZONE_COLORS.get(String(z.get("kind", "fire")), ZONE_COLORS["fire"])
	# ability targeting: circle under the cursor (sized by the ability), red out of range
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

	# rings under the selected heroes in the hero's colour (main selection stronger)
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


## Announced commander abilities: a red ring and area that intensify as the impact nears.
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


## Hero colour for circles on the battlefield (the data colour lightened so it shows on grass).
static func hero_color(u: Sim.Unit, alpha: float) -> Color:
	var c := u.color.lightened(0.3)
	c.a = alpha
	return c


## Order target circles in the hero's colour: to a place a small circle, at a group a circle around its centre, with an ally
## a circle under the ally (several heroes with the same target = concentric circles). In deployment and pause for all,
## in a running battle for the selected and briefly after an order. While picking a target (Send) a circle under the cursor.
func _sync_order_marks() -> void:
	var dt := get_process_delta_time()
	for id: String in _order_flash.keys():
		_order_flash[id] = float(_order_flash[id]) - dt
		if float(_order_flash[id]) <= 0.0:
			_order_flash.erase(id)
	var marks: Array = []   # [place, radius, colour]
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


## A short ability effect: a circle on the ground that fades.
func _spawn_fx(key: String, pos: Vector2) -> void:
	var a: Dictionary = sim.units_data["abilities"].get(key, {})
	var r := float(a.get("radius", 1.2))
	var col := Color(1.0, 0.85, 0.4, 0.8)
	if key in ["pozehnani", "kruh"]:
		col = Color(0.5, 1.0, 0.6, 0.8)
	elif key in ["vyzva", "hradba", "uder_stitem", "korouhev"]:
		col = Color(0.55, 0.7, 1.0, 0.8)
	var ring := Field.ring(r, 0.18, col)
	ring.position = Field.to_world(pos, 0.1)
	add_child(ring)
	_fx.append([ring, 0.6])
