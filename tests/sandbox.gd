extends SceneTree
## Sandbox and character gallery (testing tool) like a tester would use them: opens the sandbox from the main menu,
## goes through every map with the diorama look, every ability of every class, every combo through its preset,
## placing enemies by click, cheats, relics, stats, bonds, then the gallery with every animation of every character.
## Run (with a window): godot --path . --script res://tests/sandbox.gd -- <folder>

const Sim := preload("res://scripts/sim/battle_sim.gd")
const Field := preload("res://scripts/battle/battlefield.gd")
const TacticalCamera := preload("res://scripts/battle/orbit_camera.gd")

var out_dir := ""
var failures: Array[String] = []
var main: Node


func _initialize() -> void:
	TacticalCamera.edge_scroll_all = false
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
		DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await _frames(2)
	root.get_texture().get_image().save_png(out_dir.path_join("sandbox_%s.png" % name))
	print("Snímek: sandbox_%s.png" % name)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		print("CHYBA: " + msg)


func _battle() -> Node:
	return main.get("battle")


## Lets the battle run for a while (from the opening pause), then pauses again.
func _run_battle(frames: int) -> void:
	var b := _battle()
	if int(b.get("phase")) == 2:   # Phase.PAUSE
		b.call("_toggle_pause")
	await _frames(frames)


func _run() -> void:
	main = load("res://scenes/run/run.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	main.call("open_sandbox")
	await _frames(10)
	var b := _battle()
	_check(b != null and b.get("sb_panel") != null, "sandbox se neotevřel s panelem")
	await _shot("01_panel")
	var tabs: TabContainer = (b.get("sb_panel") as Node).get("_body")
	for i in range(1, tabs.get_tab_count()):
		tabs.current_tab = i
		await _shot("01_tab_%d" % i)
	tabs.current_tab = 0

	for sw: String in ["god", "free_uses", "endless"]:
		b.call("_sandbox_request", "switch", [sw, true])
	var sim: Sim = b.get("sim")
	_check(bool(sim.sandbox.get("god", false)) and bool(sim.sandbox.get("endless", false)), "přepínače se nepropsaly do simulace")

	# every map with the diorama look and without it
	for sid: String in Sim.scenario_list():
		b.call("_sandbox_request", "scenario", sid)
		b.call("_sandbox_request", "look", "noon")
		await _frames(4)
		await _shot("mapa_%s" % sid)
		b.call("_sandbox_request", "look", "off")
		await _frames(2)
	b.call("_sandbox_request", "scenario", "most_pres_reku")
	for lk: String in ["dawn", "dusk", ""]:
		b.call("_sandbox_request", "look", lk)
		await _frames(4)
		await _shot("vzhled_%s" % (lk if lk != "" else "mapy"))
	print("Mapy a vzhledy: OK")

	# start without the map's enemies, place enemies by click
	b.call("_sandbox_request", "no_foes", true)
	sim = b.get("sim")
	_check(sim.living(Sim.SIDE_FOE).is_empty(), "bez nepřátel mapy: na bojišti jsou nepřátelé")
	b.call("_sandbox_request", "spawn_mode", [true, "kopinik", 3])
	var cam: Camera3D = b.get("cam")
	b.call("_sandbox_spawn_at", cam.unproject_position(Field.to_world(Vector2(0.0, -1.0))))
	_check(sim.living(Sim.SIDE_FOE).size() == 3, "klik nepřidal 3 kopiníky (%d)" % sim.living(Sim.SIDE_FOE).size())
	b.call("_sandbox_spawn_at", cam.unproject_position(Field.to_world(Vector2(6.0, 6.0))))
	_check(sim.living(Sim.SIDE_FOE).size() == 3, "nepřítel vznikl ve vodě")
	b.call("_sandbox_request", "spawn_mode", [false, "kopinik", 3])
	await _shot("02_klik")
	await _run_battle(90)
	b.call("_sandbox_request", "morale", null)
	_check(sim.foes_broken, "zlomení morálky nefunguje")
	b.call("_sandbox_request", "kill", null)
	await _frames(3)
	_check(sim.living(Sim.SIDE_FOE).is_empty() and sim.over == "", "zabití nepřátel nebo nekonečná bitva nefunguje")
	print("Nepřátelé klikem, morálka, zabití: OK")

	# every ability of every class (enemies right in front of the hero)
	var used := 0
	var units: Dictionary = sim.units_data
	for cls: String in units["knights"]:
		for ab: String in (units["knights"][cls]["abilities"] as Array):
			b.call("_sandbox_request", "restart", null)
			b.call("_on_ability_chosen", cls, ab)
			sim = b.get("sim")
			var h := sim.by_id(cls)
			_check(h.ability == ab, "%s: schopnost %s se nenastavila" % [cls, ab])
			var fid := sim.sandbox_spawn("lapka", h.pos + Vector2(0.4, 2.5))
			sim.sandbox_spawn("lapka", h.pos + Vector2(-0.6, 2.8))
			b.call("_flush_events")
			var kind := sim.ability_target(cls)
			var target: Variant = null
			if kind == "point":
				target = sim.by_id(fid).pos
			elif kind == "enemy":
				target = fid
			await _run_battle(2)
			var ok := sim.use_ability(cls, target)
			_check(ok, "%s: %s nejde použít (%s)" % [cls, ab, sim.ability_problem(cls) + " " + sim.ability_target_problem(cls, target)])
			b.call("_flush_events")
			await _frames(40)
			if ok:
				used += 1
	print("Schopnosti: použito %d" % used)

	# every combo through its preset
	var fired := 0
	for cid: String in units["combos"]:
		if cid.begins_with("_"):
			continue
		b.call("_sandbox_request", "combo", cid)
		sim = b.get("sim")
		var c := {}
		for cc: Dictionary in sim.combos():
			if cc["id"] == cid:
				c = cc
		_check(not c.is_empty(), "kombo %s: po předvolbě chybí" % cid)
		if c.is_empty():
			continue
		var ha := sim.by_id(c["a"])
		var hb := sim.by_id(c["b"])
		ha.pos = Vector2(0.0, -3.5)
		hb.pos = Vector2(1.2, -3.8)
		var f0 := sim.sandbox_spawn("lapka", Vector2(0.0, -2.1))
		sim.sandbox_spawn("lapka", Vector2(0.8, -1.8))
		sim.sandbox_spawn("lapka", Vector2(-0.8, -1.9))
		b.call("_flush_events")
		await _run_battle(2)
		var target: Variant = sim.by_id(f0).pos if String(c["aim"]) == "point" else null
		var ok := sim.use_combo(cid, target)
		_check(ok, "kombo %s nejde spustit (%s)" % [cid, sim.combo_problem(cid) + " " + sim.combo_target_problem(cid, target)])
		b.call("_flush_events")
		await _frames(45)
		if ok:
			fired += 1
	print("Komba: spuštěno %d" % fired)
	await _shot("03_kombo")

	# hero settings, relics, bonds
	b.call("_sandbox_request", "restart", null)
	sim = b.get("sim")
	var base_uses := sim.by_id("tank").uses
	var base_hp := sim.by_id("tank").maxhp
	b.call("_sandbox_request", "relic", ["tezka_korouhev", true])
	sim = b.get("sim")
	_check(sim.by_id("tank").uses == base_uses + 1, "znamení Těžká korouhev nepřidalo použití")
	b.call("_sandbox_request", "stat", ["tank", "odolnost", 0.5])
	sim = b.get("sim")
	_check(sim.by_id("tank").maxhp > base_hp * 1.4, "Odolnost +50 % se neprojevila")
	b.call("_sandbox_request", "hp", ["tank", 0.5])
	sim = b.get("sim")
	_check(absf(sim.by_id("tank").hp - sim.by_id("tank").maxhp * 0.5) < 1.0, "počáteční zdraví 50 % se neprojevilo")
	b.call("_sandbox_request", "bond_add", ["knez", "asasin", "zpovednik", 3])
	sim = b.get("sim")
	_check(sim.by_id("knez").bond_with == "asasin" and sim.by_id("asasin").bond_level == 3, "pouto se nepřidalo")
	b.call("_sandbox_request", "bond_remove", "knez")
	sim = b.get("sim")
	_check(sim.by_id("knez").bond_with == "" and sim.by_id("asasin").bond_with == "", "pouto se neodebralo")
	sim.by_id("tank").hp = 10.0
	b.call("_sandbox_request", "heal", null)
	_check(sim.by_id("tank").hp == sim.by_id("tank").maxhp, "vyléčení nefunguje")
	b.call("_sandbox_request", "speed", 0.25)
	_check(is_equal_approx(float(b.get("speed")), 0.25), "rychlost 0,25× se nenastavila")
	print("Hrdinové, znamení, pouta, léčení, rychlost: OK")

	# the gallery and back (the sandbox remembers its settings)
	b.call("_sandbox_request", "gallery", null)
	await _frames(10)
	var g: Node = main.get("battle")
	_check(g != null and g.has_method("view_close"), "galerie se neotevřela")
	if g != null and g.has_method("view_close"):
		var missing: Array = g.get("missing")
		print("Galerie: postav %d, chybějící animace: %s" % [(g.get("order") as Array).size(), "žádné" if missing.is_empty() else ", ".join(missing)])
		await _shot("04_galerie")
		for kind: String in ["walk", "attack", "ability", "hit", "death"]:
			g.call("_play", kind)
			await _frames(20)
			await _shot("05_galerie_%s" % kind)
		g.set("who", "tank")
		g.call("view_close")
		g.call("_play", "attack")
		await _frames(12)
		await _shot("06_tank_zblizka")
		g.set("who", "jezdec")
		g.call("view_close")
		await _frames(4)
		await _shot("07_jezdec_zblizka")
		g.set("who", "")
		g.call("_play", "ragdoll")
		await _frames(90)
		await _shot("08_ragdoll")
		g.emit_signal("back_pressed")
		await _frames(10)
		b = _battle()
		_check(b != null and b.get("sb_panel") != null, "zpět z galerie: sandbox se neotevřel")
		if b != null:
			var rl: Array = (b.get("sandbox_state") as Dictionary).get("relics", [])
			_check(rl.has("tezka_korouhev"), "sandbox po návratu z galerie zapomněl nastavení")

	if failures.is_empty():
		print("VÝSLEDEK: OK")
		quit(0)
	else:
		print("VÝSLEDEK: CHYBA (%d)" % failures.size())
		quit(1)
