extends SceneTree
## Portfolio shots of the current build (chapter "Mám hru"). Each shot is a function k2_xx below: it stages the
## game into the wanted state through the normal game code (battle scene, sandbox, run screens) and saves a clean
## frame. The window should be 2x the target size; tools/portfolio/finish.py downsamples and crops.
## Run: godot --path . --fixed-fps 60 --resolution 5120x2880 --script res://tools/portfolio/shots.gd -- <out> <shot,...|all> [probe]
## With "probe" every shot saves its candidate cameras instead of the final one.

const Lib := preload("res://tools/portfolio/lib.gd")
const Sim := preload("res://scripts/sim/battle_sim.gd")
const Run := preload("res://scripts/run/run_state.gd")

var L: Lib
var probe := false
var _cams: Array = []


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var args := OS.get_cmdline_user_args()
	L = Lib.new(self, args[0])
	probe = args.size() > 2 and args[2] == "probe"
	var which: Array = Array(String(args[1]).split(","))
	for s: String in which:
		var fn := s.to_lower().replace("-", "_")
		if not fn.begins_with("k2_"):
			fn = "k2_" + fn
		if not has_method(fn):
			print("NEZNÁMÝ SNÍMEK " + s)
			continue
		await call(fn)
		for c in root.get_children():
			if c is Node and c.name != "root":
				c.queue_free()
		await L.frames(3)
	print("HOTOVO")
	quit(0)


## Final camera, or in probe mode all candidates (each [x, y, yaw, pitch, dist, fov]).
func _frame(b: Node, code: String, cams: Array) -> void:
	if probe:
		for i in cams.size():
			var c: Array = cams[i]
			L.cam(b, c[0], c[1], c[2], c[3], c[4], c[5] if c.size() > 5 else 0.0)
			await L.shot("%s_probe%d" % [code, i])
		return
	var c: Array = cams[0]
	L.cam(b, c[0], c[1], c[2], c[3], c[4], c[5] if c.size() > 5 else 0.0)
	await L.shot(code)


func _place(sim: Object, id: String, p: Vector2, face := Vector2(0, 1)) -> void:
	var u: Object = sim.call("by_id", id)
	u.set("pos", p)
	u.set("home", p)
	u.set("face", face)


# ================================================================ K2-01: the bridge, hero shot

## The bridge staged for the camera: the tank holds the near end of the bridge, the brigands of the first group
## come over it, the others stand around (archer and priest behind, assassin and cavalier on the flank).
func _staged_bridge(t: float, abilities := true) -> Node:
	var b: Node = await L.battle("most_pres_reku")
	L.run_battle(b)
	var sim: Object = b.get("sim")
	_place(sim, "tank", Vector2(0.0, 3.0))
	_place(sim, "knez", Vector2(-1.8, -0.5))
	_place(sim, "lucistnik", Vector2(-4.2, 1.6))
	_place(sim, "asasin", Vector2(2.6, 2.4))
	_place(sim, "jezdec", Vector2(4.0, -0.2))
	sim.call("set_order", "tank", "point", Vector2(0.0, 3.2))
	var each := func(s2: Object) -> void:
		if abilities:
			Lib.auto_abilities(s2)
	await L.ff(b, t, each, 40)
	return b


## K2-01: the bridge, cinematic wide shot (21:9), no UI.
func k2_01() -> void:
	var b := await _staged_bridge(_env_f("PF_T", 6.0))
	L.ui(b, false)
	b.set("speed", 0.4)
	await _frame(b, "K2-01", [
		[0.5, 4.5, 55, 26, 15, 50],
		[0.0, 4.0, 35, 28, 18, 50],
		[0.0, 5.0, 75, 18, 14, 45],
		[0.0, 4.0, -40, 24, 16, 50],
	])


# ================================================================ run screens

func _run_scene(r: Object) -> Node:
	load("res://scripts/battle/battle.gd").set("tutorial_mode", -1)
	var s: Node = load("res://scenes/run/run.tscn").instantiate()
	root.add_child(s)
	await L.frames(3)
	s.set("run", r)
	return s


## Scrolls the current run screen (0..1 of the scrollable height).
func _scroll(s: Node, frac: float) -> void:
	await L.frames(3)
	var sc: ScrollContainer = (s.get("screen") as Node).find_children("*", "ScrollContainer", true, false)[0]
	var bar := sc.get_v_scroll_bar()
	sc.scroll_vertical = int((bar.max_value - bar.page) * frac)
	await L.frames(2)


func _env_int(k: String, d: int) -> int:
	var v := OS.get_environment(k)
	return int(v) if v != "" else d


func _env_f(k: String, d: float) -> float:
	var v := OS.get_environment(k)
	return float(v) if v != "" else d


## K2-03: the act map mid-run with the path walked so far.
func k2_03() -> void:
	var sd := _env_int("PF_SEED", 22)
	var r := Run.new(sd)
	Lib.auto_run(r, sd, _env_int("PF_NODES", 4))
	var s := await _run_scene(r)
	s.call("show_map")
	await L.frames(4)
	await L.shot("K2-03")


## K2-04: the house chronicle after a finished run.
func k2_04() -> void:
	var sd := _env_int("PF_SEED", 22)
	var r := Run.new(sd)
	Lib.auto_run(r, sd)
	var s := await _run_scene(r)
	s.call("show_chronicle")
	await _scroll(s, _env_f("PF_SCROLL", 0.0))
	await L.shot("K2-04")


## K2-12: the house page with the memorial of the fallen.
func k2_12() -> void:
	var sd := _env_int("PF_SEED", 22)
	var r := Run.new(sd)
	Lib.auto_run(r, sd, _env_int("PF_NODES", 6))
	var s := await _run_scene(r)
	s.call("show_house", Callable(s, "show_map"))
	await _scroll(s, _env_f("PF_SCROLL", 1.0))
	await L.shot("K2-12")


# ================================================================ battle UI

## Battle on the bridge started with the automatic commander, fast-forwarded to `t`, then paused with the UI.
func _bridge_at(t: float, abilities := true, sid := "most_pres_reku") -> Node:
	var b: Node = await L.battle(sid)
	L.run_battle(b)
	var each := func(s: Object) -> void:
		s.call("auto_command")
		if abilities:
			Lib.auto_abilities(s)
	await L.ff(b, t, each, 20)
	return b


func k2_uiprobe() -> void:
	var b := await _bridge_at(_env_f("PF_T", 10.0))
	L.pause_battle(b)
	await L.frames(4)
	await L.shot("uiprobe")


## Gameplay camera over the bridge (the fixed battle angle, a little closer than the default).
const GAME_CAM := [0.0, 3.5, 25, 50, 22]


## Screen position of a unit (for the cursor drawn in post).
func _screen_of(b: Node, id: String) -> Vector2:
	var v: Node3D = (b.get("views") as Dictionary)[id]
	return (b.get("cam") as Camera3D).unproject_position(v.global_position + Vector3(0, 0.9, 0))


func _write_meta(code: String, d: Dictionary) -> void:
	var f := FileAccess.open(L.out_dir.path_join(code + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(d))


## The same cast meeting the brigands on the grass before the bridge (ground effects are not hidden by the deck).
func _staged_bank(t: float) -> Node:
	var b: Node = await L.battle("most_pres_reku")
	L.run_battle(b)
	var sim: Object = b.get("sim")
	_place(sim, "tank", Vector2(0.0, 0.8))
	_place(sim, "knez", Vector2(-2.2, -2.6))
	_place(sim, "lucistnik", Vector2(-4.6, -1.0))
	_place(sim, "asasin", Vector2(2.4, -0.2))
	_place(sim, "jezdec", Vector2(4.4, -2.2))
	sim.call("set_order", "tank", "point", Vector2(0.0, 0.8))
	await L.ff(b, t, Callable(), 40)
	return b


## K2-06b: heroes' abilities firing (the tank's Challenge and the priest's Blessing), with the battle UI.
func k2_06b() -> void:
	var b := await _staged_bank(_env_f("PF_T", 6.0))
	var sim: Object = b.get("sim")
	var c: Array = [0.0, _env_f("PF_CY", 3.2), 25, 50, _env_f("PF_DIST", 18.0)]
	L.cam(b, c[0], c[1], c[2], c[3], c[4])
	var who := OS.get_environment("PF_WHO") if OS.get_environment("PF_WHO") != "" else "tank,knez"
	for id: String in who.split(","):
		var h: Array = sim.call("ability_hint", id)
		var tgt: Variant = h[1] if h.size() > 1 and h[1] != null else (sim.call("by_id", "tank").get("pos"))
		print("ability %s -> %s" % [id, sim.call("use_ability", id, tgt)])
	b.call("_flush_events")
	b.set("speed", 1.0)
	b.call("_refresh_panel")
	var n := _env_int("PF_N", 1)
	var gap := _env_int("PF_GAP", 6)
	for i in n:
		L.render(false)
		await L.frames(gap)
		await L.shot("K2-06b" if n == 1 else "K2-06b_f%d" % i)


## K2-07b: real-time pause, a hero selected and the right-button order previewed on an enemy (cursor drawn in post).
func k2_07b() -> void:
	var b := await _staged_bridge(_env_f("PF_T", 2.5))
	var sim: Object = b.get("sim")
	L.pause_battle(b)
	L.cam(b, 0.5, _env_f("PF_CY", 6.0), 25, 50, _env_f("PF_DIST", 22.0))
	_clean_hint(b)
	var who := "jezdec"
	b.set("selection", [who])
	b.set("selected", who)
	b.call("_refresh_panel")
	var foe := ""
	var want := OS.get_environment("PF_FOE") if OS.get_environment("PF_FOE") != "" else "strelec"
	for u: Variant in sim.call("living", "e"):
		if String(u.get("key")) == want:
			foe = u.get("id")
			break
	await L.frames(3)
	var sp := _screen_of(b, foe)
	b.call("_pointer_move", sp)
	await L.frames(6)
	await L.shot("K2-07b")
	var vp := (b.get("cam") as Camera3D).get_viewport().get_visible_rect().size   # screen positions are in UI units
	_write_meta("K2-07b", {"cursor": [sp.x, sp.y], "vp": [vp.x, vp.y]})


## K2-11b: the battle bar with the enemy morale close to the breaking line.
func k2_11b() -> void:
	var b: Node = await L.battle("most_pres_reku")
	L.run_battle(b)
	var sim: Object = b.get("sim")
	var target := _env_f("PF_LOSS", 0.6)
	var each := func(s2: Object) -> void:
		s2.call("auto_command")
		Lib.auto_abilities(s2)
	for k in 60:
		await L.ff(b, 1.0, each, 0)
		if float(sim.call("morale_state")["loss"]) >= target:
			break
	L.pause_battle(b)
	_clean_hint(b)
	await L.frames(20)
	await L.shot("K2-11b")
	var tb: Control = (b.get("ui") as Object).get("top_bar")
	var r := tb.get_global_rect()
	var k := float(root.size.y) / 900.0
	_write_meta("K2-11b", {"bar": [r.position.x * k, r.position.y * k, r.size.x * k, r.size.y * k]})


## K2-13: the oath dialog: the tank sworn to Never Retreat is locked in the fight and gets an order out of it.
func k2_13() -> void:
	var b := await _staged_bridge(_env_f("PF_T", 3.5))
	var sim: Object = b.get("sim")
	L.cam(b, GAME_CAM[0], GAME_CAM[1], GAME_CAM[2], GAME_CAM[3], GAME_CAM[4])
	var tank: Object = sim.call("by_id", "tank")
	_clean_hint(b)
	print("tank locked: ", tank.get("locked"))
	b.set("selection", ["tank"])
	b.set("selected", "tank")
	b.call("_give_order", tank, "point", Vector2(-2.0, -4.0))
	await L.frames(20)
	await L.shot("K2-13")


## Hides the short floating hint (an alarm text that happens to be on screen).
func _clean_hint(b: Node) -> void:
	var u: Object = b.get("ui")
	u.set("_hint_t", 0.01)


## K2-08: the reward after a battle; the cards say what each reward changes (fits / clashes, wasted stat).
func k2_08() -> void:
	var best: Array = []   # [score, seed, nodes]
	for sd in range(_env_int("PF_SEED", 1), _env_int("PF_SEED", 1) + _env_int("PF_SEEDS", 12)):
		for n in range(1, 8):
			var r := Run.new(sd)
			Lib.auto_run(r, sd, n, true)
			if r.over != "" or not r.is_battle_node() or r.has_legacy() or not r.bond_offer().is_empty():
				continue
			var offers := r.offers()
			if offers.size() < 3:
				continue
			var plus := 0
			var minus := 0
			var oath := 0
			for o: Dictionary in offers:
				if String(o.get("kind", "passive")) == "passive" and r.is_oath(String(o.get("passive", ""))):
					oath += 1
				for note: Array in r.offer_notes(o):
					if note[0]:
						plus += 1
					else:
						minus += 1
			var score := mini(plus, 2) + mini(minus, 2) * 2 + mini(oath, 1) * 2
			if best.is_empty() or score > int(best[0]):
				best = [score, sd, n]
	print("K2-08 best ", best)
	var r2 := Run.new(int(best[1]))
	Lib.auto_run(r2, int(best[1]), int(best[2]), true)
	var s := await _run_scene(r2)
	s.call("show_after_battle")
	await _scroll(s, _env_f("PF_SCROLL", 0.0))
	await L.shot("K2-08")


## Class colour mask (the same rule as tests/prototype_shots.gd: palette columns 5–8 are the class colour):
## class colour where the class colour is, a neutral light grey elsewhere.
const MASK_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled;
uniform float cols = 32.0;
uniform float role_from = 5.0;
uniform float role_to = 8.0;
uniform vec4 class_col : source_color;
uniform vec4 rest_col : source_color = vec4(0.36, 0.37, 0.40, 1.0);
void fragment() {
	float c = floor(UV.x * cols);
	ALBEDO = (c >= role_from && c <= role_to) ? class_col.rgb : rest_col.rgb;
}
"""


## K2-09: the five heroes from the ordinary battle camera before the battle, and the same frame as a class colour
## mask (K2-09-maska); finish.py also makes a split of the two.
func k2_09() -> void:
	var b: Node = await L.battle("most_pres_reku")
	L.ui(b, false)
	var sim: Object = b.get("sim")
	var heroes := ["lucistnik", "knez", "tank", "asasin", "jezdec"]
	var xs := [-4.4, -2.2, 0.0, 2.2, 4.6]
	for i in heroes.size():
		_place(sim, heroes[i], Vector2(xs[i], -4.6 + (0.6 if heroes[i] == "jezdec" else 0.0)))
	await L.frames(6)
	# the ordinary battle camera of the map (fixed angle), at its closest zoom, centred on the heroes
	var c: Camera3D = b.get("cam")
	var yaw := rad_to_deg(float(c.get("yaw")))
	var pitch := rad_to_deg(float(c.get("pitch")))
	print("battle camera yaw %.0f pitch %.0f zoom_min %.0f" % [yaw, pitch, float(c.get("zoom_min"))])
	L.cam(b, 0.0, _env_f("PF_CY", -1.5), yaw, pitch, _env_f("PF_DIST", float(c.get("zoom_min"))))
	for id: String in heroes:
		var v: Node3D = (b.get("views") as Dictionary)[id]
		var anim: AnimationPlayer = v.get("anim")
		if anim != null:
			anim.speed_scale = 0.0
	await L.shot("K2-09")
	# mask: environment hidden behind a dark floor, every hero in his class colour
	(b.get("field_root") as Node3D).visible = false
	(b.get("_outline") as Node3D).visible = false
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	floor_mi.mesh = pm
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.11, 0.12, 0.14)
	dark.disable_fog = true
	floor_mi.material_override = dark
	floor_mi.position = Vector3(0, -0.6, 0)
	b.add_child(floor_mi)
	b.set_process(false)   # views would show themselves again in sync()
	for u: Variant in sim.call("living", "e"):
		((b.get("views") as Dictionary)[u.get("id")] as Node3D).visible = false
	for id: String in heroes:
		var u: Object = sim.call("by_id", id)
		var v: Node3D = (b.get("views") as Dictionary)[id]
		var m := ShaderMaterial.new()
		m.shader = Shader.new()
		m.shader.code = MASK_SHADER
		m.set_shader_parameter("class_col", (u.get("color") as Color))
		for mi: MeshInstance3D in v.find_children("*", "MeshInstance3D", true, false):
			if mi.name == "ContactShade":
				mi.visible = false
			else:
				mi.material_override = m
	await L.shot("K2-09-maska")


## K2-10b: the tank's hero card in the game, for the comparison with the Figma card (K2-10a). Saves the whole frame
## and the card's rectangle in pixels; finish.py cuts it out and places it like the Figma export (same scale).
func k2_10b() -> void:
	var b := await _staged_bridge(_env_f("PF_T", 1.5), false)
	L.pause_battle(b)
	_clean_hint(b)
	await L.frames(20)
	var u: Object = b.get("ui")
	var row: HBoxContainer = u.get("cards_row")
	var card: Control = row.get_child(0)
	var r := card.get_global_rect()
	var k := float(root.size.y) / 900.0   # canvas_items stretch: the UI is laid out at 1600×900
	await L.shot("K2-10b_frame")
	_write_meta("K2-10b_frame", {"rect": [r.position.x * k, r.position.y * k, r.size.x * k, r.size.y * k], "scale": k})
	print("card rect base ", r, " scale ", k)


## K2-18 (build 5, 17.11.): the new look and the commanders with their own figures: the four commanders of the act
## face the house across the river (sandbox battle without the map's enemies), battle camera angle, no UI.
func k2_18() -> void:
	var B: GDScript = load("res://scripts/battle/battle.gd")
	B.set("sandbox_state", {})
	var b: Node = await L.battle("most_pres_reku", true)
	b.call("_sandbox_request", "no_foes", true)
	await L.frames(5)
	L.ui(b, false)
	var sim: Object = b.get("sim")
	var line := [["palic", -3.6, 10.4], ["vudce", -1.2, 10.0], ["setnik", 1.2, 10.0], ["ostrostrelec", 3.6, 10.6]]
	for c: Array in line:
		print("spawn ", c[0], " -> ", sim.call("sandbox_spawn", c[0], Vector2(c[1], c[2])))
	b.call("_flush_events")
	var heroes := {"tank": Vector2(0.0, 2.6), "knez": Vector2(-1.8, 0.6), "lucistnik": Vector2(-4.4, -0.4), "asasin": Vector2(2.0, 1.4), "jezdec": Vector2(4.0, 0.8)}
	for id: String in heroes:
		_place(sim, id, heroes[id])
	await L.frames(10)
	await _frame(b, "K2-18", [
		[0.0, 6.5, 35, 30, 15, 50],
		[0.0, 6.0, 25, 48, _env_f("PF_DIST", 19.0)],
	])
