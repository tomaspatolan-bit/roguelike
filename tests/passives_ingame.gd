extends SceneTree

const Sim := preload("res://scripts/sim/battle_sim.gd")
## Checks that passives and oaths work in the real game (battle scene with a window).
## Turns passives on the same way as the menu on the hero card (battle.gd _on_passive), plays the battle
## through buttons and targeting like a player and watches what is visible and what happens in the battle.
## Run: godot --path . --script res://tests/passives_ingame.gd -- <screenshot folder> <set A|B>
## Set A: The River Bridge, set B: Ford and Forest (the cavalier with Running Start charges once the tank is fighting). Exit code 0 = all passed.

const SETS := {
	"A": {"scenario": "most_pres_reku", "passives": {
		"tank": ["veteran", "ochrance"],
		"knez": ["milosrdenstvi", "posledni_pomazani"],
		"lucistnik": ["rychle_ruce", "ohniva_salva"],
		"jezdec": ["druhy_najezd", "drtivy_najezd"],
		"asasin": ["ukryt", "lovec"]}},
	"B": {"scenario": "brod_a_les", "passives": {
		"tank": ["hlasita_vyzva", "druhy_dech"],
		"knez": ["pozehnana_zbroj"],
		"lucistnik": ["probodnuti"],
		"jezdec": ["rozbeh", "mstitel"],
		"asasin": ["ze_stinu"]}},
}

var out_dir := ""
var set_key := "A"
var scene: Node
var frame := 0
var started_at := -1
var rider_sent := false
var results: Array = []          # [passive, result, note]
var seen := {}                   # what has already been observed in the battle
var forced_done := false
var shots := {}


const TacticalCamera := preload("res://scripts/battle/orbit_camera.gd")
const BattleScript := preload("res://scripts/battle/battle.gd")

func _init() -> void:
	TacticalCamera.edge_scroll_all = false   # mouse edge panning would change the screenshots
	BattleScript.tutorial_mode = -1   # the tutorial would cover the screenshots
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
		DirAccess.make_dir_recursive_absolute(out_dir)
	if args.size() > 1:
		set_key = args[1]
	scene = load("res://scenes/battle/battle.tscn").instantiate()
	scene.set("scenario_id", SETS[set_key]["scenario"])
	root.add_child(scene)


func _shot(name: String) -> void:
	if out_dir == "" or shots.has(name):
		return
	shots[name] = true
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join("pasivky_%s_%s.png" % [set_key, name]))
	print("Snímek: pasivky_%s_%s.png" % [set_key, name])


func _ok(key: String, cond: bool, note: String) -> void:
	for r: Array in results:
		if r[0] == key:
			return
	results.append([key, "OK" if cond else "CHYBA", note])


func _sim() -> Variant:
	return scene.get("sim")


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 30:
		_enable_passives()
	if frame == 36:
		_shot("rozestaveni")
		var plan: Dictionary = (scene.get("sim") as Object).call("suggest_orders")
		(scene.get("setup") as Dictionary)["orders"] = plan
		scene.call("_start_battle")
		if int(scene.get("phase")) == 2:
			scene.call("_toggle_pause")   # a battle without deployment starts paused
		scene.set("speed", 1.0)
		started_at = frame
	if started_at > 0 and frame > started_at:
		var sim: Variant = _sim()
		if bool(scene.get("paused")):
			scene.call("_resume_pause")
		sim.call("auto_command")
		_auto_abilities(sim)
		_send_rider(sim)
		_observe(sim)
		if not forced_done and float(sim.get("t")) > 6.0:
			forced_done = true
			_forced_checks(sim)
		if String(sim.get("over")) != "" or float(sim.get("t")) > 150.0:
			_finish(sim)
			return true
	return false


## Turns on passives through battle.gd (same as ticking them in the menu) and checks the deployment.
func _enable_passives() -> void:
	var sim: Variant = _sim()
	# no trial bonds (trial_bonds), so nothing skews the passive numbers
	(scene.get("setup") as Dictionary)["bonds"] = {}
	for k: Variant in sim.call("knights"):
		k.set("bond_with", "")
		k.set("bond_type", "")
		k.set("bond_level", 0)
	var pas: Dictionary = SETS[set_key]["passives"]
	for id: String in pas:
		for k: String in pas[id]:
			scene.call("_on_passive", id, k, true)
	var setup: Dictionary = scene.get("setup")
	var ui: Variant = scene.get("ui")
	# card: the Passives menu shows the count
	var menus: Array = (ui.get("cards_row") as Node).find_children("*", "MenuButton", true, false)
	var counts: Array = []
	for m: MenuButton in menus:
		counts.append(m.text)
	print("Rozestavení, menu na kartách: %s" % ", ".join(counts.slice(maxi(0, counts.size() - 5))))
	for id: String in pas:
		var have: Array = sim.call("passives_of", id)
		for k: String in pas[id]:
			_ok("%s: zapnutí (%s)" % [k, id], have.has(k) and (setup["passives"][id] as Array).has(k), "v simulaci i v rozestavení")


## Abilities like a player: the button and, for targeted ones, a click on the battlefield.
func _auto_abilities(sim: Variant) -> void:
	var cam: Camera3D = scene.get("cam")
	var views: Dictionary = scene.get("views")
	# set B: the test wounds the tank itself (Second Wind); a player would bless him, which checks Blessed Armor
	var knez: Variant = sim.call("by_id", "knez")
	var tank: Variant = sim.call("by_id", "tank")
	if set_key == "B" and not seen.has("bless_tank") and bool(knez.call("alive")) and bool(tank.call("alive")) \
			and float(tank.get("hp")) < float(tank.get("maxhp")) * 0.6 and bool(sim.call("can_use_ability", "knez")):
		seen["bless_tank"] = true
		var tp: Vector2 = tank.get("pos")
		var ts := cam.unproject_position(Vector3(tp.x, 0.0, -tp.y))
		scene.call("_ability", "knez")
		scene.call("_pointer_move", ts)
		scene.call("_aim_click", ts)
		scene.set("_aim_id", "")
	for u: Variant in sim.call("living", "k"):
		var id: String = u.get("id")
		var h: Array = sim.call("ability_hint", id)
		if not h[0]:
			continue
		var kind: String = sim.call("ability_target", id)
		scene.call("_ability", id)
		if kind == "none":
			continue
		var screen := Vector2.ZERO
		if kind == "enemy":
			screen = cam.unproject_position((views[String(h[1])] as Node3D).global_position + Vector3(0, 1.0, 0))
			if String(scene.call("_pick_foe", screen)) != String(h[1]):
				# the click would hit another enemy (overlap on screen): the hint aims elsewhere, use it directly
				sim.call("use_ability", id, h[1])
				scene.set("_aim_id", "")
				continue
		else:
			var p: Vector2 = h[1]
			screen = cam.unproject_position(Vector3(p.x, 0.0, -p.y))
		scene.call("_pointer_move", screen)
		scene.call("_aim_click", screen)
		scene.set("_aim_id", "")


## What is visible and what happens in a running battle.
func _observe(sim: Variant) -> void:
	var ui: Variant = scene.get("ui")
	var pas: Dictionary = SETS[set_key]["passives"]
	var tank: Variant = sim.call("by_id", "tank")
	var knez: Variant = sim.call("by_id", "knez")
	var luc: Variant = sim.call("by_id", "lucistnik")
	var jezdec: Variant = sim.call("by_id", "jezdec")
	var asasin: Variant = sim.call("by_id", "asasin")
	if not seen.has("start"):
		seen["start"] = true
		# values at the start of the battle (after recalculating passives)
		if set_key == "A":
			_ok("veteran", is_equal_approx(float(tank.get("maxhp")), 375.0 * 1.15), "tank má %d zdraví místo 375" % int(tank.get("maxhp")))
			_ok("milosrdenstvi", is_equal_approx(float(knez.get("heal")), 21.0), "kněz léčí %d místo 14" % int(knez.get("heal")))
			_ok("rychle_ruce", is_equal_approx(float(luc.get("cd")), 1.04), "lučištník střílí každých %.2f s místo 1,30 s" % float(luc.get("cd")))
			_ok("druhy_najezd", int(jezdec.get("uses")) == 4, "Nájezd má %d použití" % int(jezdec.get("uses")))
			var labs: Array = (ui.get("_ability_buttons")["jezdec"] as Node).find_children("*", "Label", true, false)
			seen["jezdec_label"] = (labs[0] as Label).text if not labs.is_empty() else ""
			_ok("lovec", is_equal_approx(float(sim.call("_dmg_mult", asasin, _first_ranged(sim))), 1.3), "asasín má proti střelcům ×%.2f útok" % float(sim.call("_dmg_mult", asasin, _first_ranged(sim))))
		else:
			_ok("hlasita_vyzva", is_equal_approx(float(sim.call("ability_of", "tank")["radius"]), 9.0), "Výzva má dosah %d m" % int(sim.call("ability_of", "tank")["radius"]))
	# icons above the head and on the card
	var oh: Dictionary = ui.get("_overhead")
	if oh.has("tank") and not seen.has("icons"):
		var n_over: int = (oh["tank"]["icons"] as Node).get_child_count()
		var n_card: int = (ui.get("_cards")["tank"]["icons"] as Node).get_child_count()
		if n_over >= (pas["tank"] as Array).size():
			seen["icons"] = true
			_ok("ikonky pasivek", true, "tank má nad hlavou %d ikonek, na kartě %d" % [n_over, n_card])
			_shot("ikonky")
	# burning ground
	var zm: Array = scene.get("_zone_meshes")
	for m: MeshInstance3D in zm:
		if m.visible:
			_ok("ohniva_salva", true, "hořící kruh na bojišti (%d s bitvy)" % int(sim.get("t")))
			_shot("ohniva_salva")
	# stun
	for f: Variant in sim.call("living", "e"):
		if float(f.get("stun_t")) > 1.6:
			_ok("drtivy_najezd", true, "nepřítel omráčen na %.1f s (bez pasivky 1,5 s)" % float(f.get("stun_t")))
	if float(asasin.get("hidden_t")) > 0.0:
		_ok("ukryt", not (sim.call("_visible_knights") as Array).has(asasin), "po úderu ho nepřátelé necílí")
	if set_key == "B":
		for k: Variant in sim.call("living", "k"):
			if float(k.get("shield_t")) > 0.0:
				_ok("pozehnana_zbroj", true, "%s má po Požehnání štít %.1f s" % [k.get("name"), float(k.get("shield_t"))])
		if bool(jezdec.get("primed")):
			seen["primed"] = true
		if (asasin.get("struck") as Dictionary).size() > 0:
			_ok("ze_stinu", true, "dvojnásobný první úder na %d nepřátel" % (asasin.get("struck") as Dictionary).size())
	if float(sim.get("t")) > 20.0:
		_shot("bitva")


## Situations that need not happen in one battle: sets them up in the game and watches how the game handles them.
func _forced_checks(sim: Variant) -> void:
	var tank: Variant = sim.call("by_id", "tank")
	var knez: Variant = sim.call("by_id", "knez")
	var luc: Variant = sim.call("by_id", "lucistnik")
	var foe: Variant = sim.call("living", "e")[0]
	if set_key == "A":
		# Guardian: an ally next to the tank
		luc.set("pos", (tank.get("pos") as Vector2) + Vector2(1.0, 0.0))
		var m: float = sim.call("_taken_mult", luc)
		_ok("ochrance", m < (1.0 - float(luc.get("armor"))) * 0.81, "lučištník u tanka dostává ×%.2f zranění (bez Ochránce ×%.2f)" % [m, 1.0 - float(luc.get("armor"))])
		# Last Rites: a fallen hero next to the priest
		luc.set("pos", (knez.get("pos") as Vector2) + Vector2(1.0, 0.0))
		sim.call("_hurt", foe, luc, 99999.0)
		scene.call("_flush_events")
		_ok("posledni_pomazani", bool(luc.call("alive")) and _log_has("raised the fallen"), "deník: „%s“" % _log_find("raised the fallen"))
	else:
		# Second Wind
		tank.set("hp", float(tank.get("maxhp")) * 0.31)
		sim.call("_hurt", foe, tank, 10.0)
		scene.call("_flush_events")
		_ok("druhy_dech", _log_has("Second Wind"), "deník: „%s“, tank má %d %% zdraví" % [_log_find("Second Wind"), int(100.0 * float(tank.get("hp")) / float(tank.get("maxhp")))])
		# Piercing Shot: an arrow at an enemy with another standing behind
		var foes: Array = sim.call("living", "e")
		var a: Variant = foes[0]
		var b: Variant = foes[1]
		b.set("pos", (a.get("pos") as Vector2) + Vector2(0.0, 1.0))
		var hb: float = b.get("hp")
		var p := Sim.Projectile.new()
		p.id = 999999
		p.pos = a.get("pos")
		p.target_id = a.get("id")
		p.from_id = "lucistnik"
		p.dmg = 9.0
		(sim.get("projectiles") as Array).append(p)
		for i in 3:
			sim.call("step", 1.0 / 60.0)
		scene.call("_flush_events")
		_ok("probodnuti", float(b.get("hp")) < hb, "nepřítel za cílem dostal %.1f" % (hb - float(b.get("hp"))))
		# Avenger: an ally falls
		sim.call("_hurt", foe, luc, 99999.0)
		scene.call("_flush_events")
		var jezdec: Variant = sim.call("by_id", "jezdec")
		_ok("mstitel", bool(jezdec.get("avenger")), "po smrti lučištníka má jezdec útok ×%.2f" % float(sim.call("_dmg_mult", jezdec, null)))


func _log_find(part: String) -> String:
	for l: Dictionary in scene.get("log_lines"):
		if String(l["text"]).contains(part):
			return l["text"]
	return ""


func _log_has(part: String) -> bool:
	return _log_find(part) != ""


func _first_ranged(sim: Variant) -> Variant:
	for f: Variant in sim.call("living", "e"):
		if bool(f.get("ranged")):
			return f
	return null


func _finish(sim: Variant) -> void:
	var asasin: Variant = sim.call("by_id", "asasin")
	if set_key == "A":
		_ok("druhy_najezd (karta)", String(seen.get("jezdec_label", "")).contains("●●"), "tlačítko na kartě: „%s“" % seen.get("jezdec_label", ""))
	else:
		_ok("rozbeh", seen.has("primed"), "jezdec se rozjel k výpadu (dvojnásobný první úder)")
	for k in ["ohniva_salva", "drtivy_najezd", "ukryt", "pozehnana_zbroj", "ze_stinu"]:
		var needed: bool = (set_key == "A" and k in ["ohniva_salva", "drtivy_najezd", "ukryt"]) or (set_key == "B" and k in ["pozehnana_zbroj", "ze_stinu"])
		if needed:
			_ok(k, false, "v této bitvě se neprojevila")
	_shot("konec")
	print("Bitva skončila: %s za %.0f s" % [sim.get("over"), sim.get("t")])
	print("Sada %s (%s):" % [set_key, SETS[set_key]["scenario"]])
	var bad := 0
	for r: Array in results:
		print("  %-26s %-6s %s" % [r[0], r[1], r[2]])
		if r[1] != "OK":
			bad += 1
	print("VÝSLEDEK: %s" % ("OK" if bad == 0 else "%d CHYB" % bad))


## Running Start like a player: once the tank is fighting, sends the cavalier (right button) at the group of the enemy the tank fights.
func _send_rider(sim: Variant) -> void:
	if rider_sent or not (SETS[set_key]["passives"]["jezdec"] as Array).has("rozbeh"):
		return
	var tank: Variant = sim.call("by_id", "tank")
	if float(sim.get("t")) - float(tank.get("combat_t")) > 0.2:
		return
	var best: Variant = null
	for f: Variant in sim.call("living", "e"):
		if best == null or (f.get("pos") as Vector2).distance_to(tank.get("pos")) < (best.get("pos") as Vector2).distance_to(tank.get("pos")):
			best = f
	if best == null:
		return
	rider_sent = true
	sim.call("set_order", "jezdec", "group", String(best.get("id")))
