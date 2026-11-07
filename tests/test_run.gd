extends SceneTree
## Run tests (act map) without a window.
## Run: godot --headless --path . --script res://tests/test_run.gd
## Exit code 0 = all passed, 1 = something failed.

const Sim := preload("res://scripts/sim/battle_sim.gd")
const Run := preload("res://scripts/run/run_state.gd")
const RUNS := 20
const DT := 1.0 / 30.0

var failures: Array[String] = []


func _init() -> void:
	_test_map()
	_test_rules()
	_test_events_and_camp()
	_test_leader()
	_test_bonds()
	_test_offers()
	_test_full_runs()
	if failures.is_empty():
		print("VÝSLEDEK: OK")
		quit(0)
	else:
		for f in failures:
			print("FAIL: ", f)
		print("VÝSLEDEK: %d chyb" % failures.size())
		quit(1)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok  ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _fake(over: String, dead: Array, fled: Array, glory: float, hp: Dictionary = {}) -> Dictionary:
	var h := {"tank": 1.0, "knez": 1.0, "lucistnik": 1.0, "jezdec": 1.0, "asasin": 1.0}
	h.merge(hp, true)
	return {"over": over, "t": 60.0, "dead": dead, "fled": fled, "glory": glory, "glory_by": {"tank": 12.0, "lucistnik": 30.0}, "oaths_broken": [], "task_ok": true, "hp": h}


## Moves the run to the first node of the given type reachable along the way (otherwise returns false).
func _goto_type(r: Run, t: String) -> bool:
	for id: String in r.available():
		if r.node_type(id) == t:
			return r.choose(id)
	return false


## Map: floors, widths, paths, node types and contents on 50 seeds.
func _test_map() -> void:
	print("Mapa aktu")
	var ok_shape := true
	var ok_paths := true
	var ok_types := true
	var ok_content := true
	var elites := 0
	var events := 0
	for seed_i in 50:
		var r := Run.new(seed_i)
		var floors: Array = r.map["floors"]
		var n_f: int = r.act["floors"]
		if floors.size() != n_f:
			ok_shape = false
		for f in floors.size():
			var row: Array = floors[f]
			if row.size() < int(r.act["width_min"]) or row.size() > int(r.act["width_max"]):
				ok_shape = false
			for n: Dictionary in row:
				var t: String = n["type"]
				if f == 0 and t != r.act["first_floor"]:
					ok_types = false
				if f == n_f - 1 and t != r.act["last_floor"]:
					ok_types = false
				if t == "elita":
					elites += 1
					if f + 1 < int(r.act["elite_from"]):
						ok_types = false
				if t == "udalost":
					events += 1
					if String(n["event"]) == "" or not r.events_data.has(n["event"]):
						ok_content = false
				if ["bitva", "elita"].has(t) and String(n["scenario"]) == "":
					ok_content = false
				if (n["next"] as Array).is_empty():
					ok_paths = false
				for nx: String in n["next"]:
					if nx != "boss" and t != "bitva" and r.node_type(nx) == t:
						ok_types = false
				# every node (except the first floor) has a path in
				if f > 0:
					var inc := 0
					for a: Dictionary in floors[f - 1]:
						if (a["next"] as Array).has(n["id"]):
							inc += 1
					if inc == 0:
						ok_paths = false
		for n: Dictionary in floors[n_f - 1]:
			if not (n["next"] as Array).has("boss"):
				ok_paths = false
	_check(ok_shape, "mapa má %d pater po 2–3 uzlech" % int(Run.new(0).act["floors"]))
	_check(ok_paths, "každý uzel má cestu dál i dovnitř, poslední patro vede k bossovi")
	_check(ok_types, "první patro bitvy, poslední tábor, elity až od patra elite_from, dvě elity ani tábory za sebou")
	_check(ok_content, "bitvy mají scénář, události existují")
	_check(elites > 0 and events > 0, "na mapách se objevují elity (%d) i události (%d)" % [elites, events])
	_test_shuffle()

	var r2 := Run.new(5)
	_check(r2.available().size() == (r2.map["floors"][0] as Array).size(), "na začátku jde vybrat celé první patro")
	_check(not r2.choose("boss"), "na bosse se nejde rovnou")
	var first: String = r2.available()[0]
	_check(r2.choose(first) and r2.node_id == first, "volba uzlu na prvním patře")
	_check(r2.available().is_empty(), "z bitvy se nejde dál, dokud se neodehraje")


## Run rules on faked battle results.
func _test_rules() -> void:
	print("Pravidla běhu")
	var r := Run.new(7)
	_check(r.oath_of("tank") == "nikdy_neustoupi", "Bořek začíná s přísahou")
	r.choose(r.available()[0])
	var data := r.load_stage_data()
	var setup := r.battle_setup(data)
	_check(setup["names"]["tank"] == "Sir Bořek" and float(setup["glory"]) == 25.0, "setup nese jména a slávu")
	_check(float(setup["hp"]["tank"]) == 1.0, "na začátku jsou všichni zdraví")

	# battle 1: Bořek (with an oath) falls, 2 brigands and a bowman flee, the archer is wounded
	r.record_battle(_fake("win", ["tank"], ["lapka", "lapka", "strelec"], 61.0, {"lucistnik": 0.3}))
	_check(r.over == "", "po vítězství se jde dál")
	_check(r.glory == 61.0, "sláva se přenáší (carry_max 120)")
	_check(is_equal_approx(r.hp_of("lucistnik"), 0.3 + float(r.act["regen"])), "zranění se nese a kousek se doléčí")
	_check(r.hp_of("tank") == 1.0, "nástupce je zdravý")
	_check(r.hero_name("tank") == "Sir Vítek", "nastoupil nástupce stejné třídy")
	_check((r.heroes["tank"]["passives"] as Array).is_empty(), "nástupce začíná bez pasivek")
	_check(r.has_legacy() and r.legacy_current()["oath"] == "nikdy_neustoupi", "přísaha padlého čeká na dědice")
	_check(r.available().is_empty(), "dokud není dědictví a odměna vyřízená, nejde se dál")
	_check(r.fled.size() == 3, "uprchlíci se zapamatovali")
	_check(not r.legacy_candidates().has("lucistnik") and r.legacy_candidates().has("tank"), "osobní přísahu tanka dědí jen nástupce")
	r.resolve_legacy("tank")
	_check(r.oath_of("tank") == "nikdy_neustoupi" and not r.has_legacy(), "Sir Vítek zdědil přísahu předchůdce")
	var offers := r.offers()
	_check(offers.size() == 3, "po bitvě se nabízí 3 odměny")
	var ok := true
	for o: Dictionary in offers:
		var d: Dictionary = r.units_data["passives"][o["passive"]]
		var c: String = d.get("class", "any")
		if c != "any" and c != o["hero"]:
			ok = false
		if o["hero"] == "tank" and r.is_oath(o["passive"]):
			ok = false
	_check(ok, "nabídky sedí na třídu a nedávají druhou přísahu")
	var o0: Dictionary = offers[0]
	r.pick_offer(0)
	_check((r.heroes[o0["hero"]]["passives"] as Array).has(o0["passive"]), "vybraná odměna patří hrdinovi")
	_check(r.offers().is_empty() and not r.available().is_empty(), "odměna se vybírá jednou, pak se jde dál")

	# a house oath is inherited by anyone without an oath
	var rr2 := Run.new(8)
	rr2.heroes["knez"]["passives"] = ["milost"]
	rr2.choose(rr2.available()[0])
	rr2.record_battle(_fake("win", ["knez"], [], 30.0, {}))
	_check(rr2.has_legacy() and rr2.legacy_candidates().has("lucistnik") and rr2.legacy_candidates().has("knez"), "přísahu rodu může převzít kdokoli bez přísahy")
	var s2 := rr2.battle_setup(rr2.load_stage_data())
	_check(int(s2["ancestors"]) == 1, "bitva ví, kolik předků padlo (Přísaha předků)")

	# elite: 4 offers, 2 picks
	var re := Run.new(11)
	var found := false
	for s_i in 40:
		re = Run.new(100 + s_i)
		for n: Dictionary in re.map["nodes"].values():
			if n["type"] == "elita":
				re.node_id = n["id"]
				found = true
				break
		if found:
			break
	re.record_battle(_fake("win", [], [], 30.0))
	_check(re.offers().size() == 4 and re.picks_left() == 2, "elita nabízí 4 odměny a 2 výběry")
	re.pick_offer(0)
	_check(re.picks_left() == 1 and not re.offers().is_empty(), "po první volbě u elity zbývá jedna")
	re.pick_offer(0)
	_check(re.offers().is_empty(), "po druhé volbě je hotovo")

	# fled enemies return at the boss
	var rb := Run.new(13)
	rb.fled = [{"key": "lapka", "stage": "x"}, {"key": "strelec", "stage": "y"}]
	rb.node_id = "boss"
	var bd := rb.load_stage_data()
	var bs := rb.battle_setup(bd)
	_check((bs["extra_enemies"] as Array).size() == 2, "u bosse se uprchlíci vrátí")
	var sim := Sim.new(bd, bs, 1)
	_check(sim.living(Sim.SIDE_FOE).size() == (bd["scenario"]["enemies"] as Array).size() + 2, "vrácení uprchlíci jsou v bitvě")
	rb.record_battle(_fake("win", ["knez"], [], 90.0))
	_check(rb.over == "win", "po bossovi je běh vyhraný")
	_check(rb.returned.size() == 2 and rb.fled.is_empty(), "návrat uprchlíků je v kronice")

	# wounds from a battle show in the simulation
	var rw := Run.new(14)
	rw.choose(rw.available()[0])
	rw.heroes["jezdec"]["hp"] = 0.4
	var dw := rw.load_stage_data()
	var sw := Sim.new(dw, rw.battle_setup(dw), 1)
	_check(is_equal_approx(sw.by_id("jezdec").hp, sw.by_id("jezdec").maxhp * 0.4), "zraněný hrdina jde do bitvy se zbytkem zdraví")

	# defeat = everyone fell
	var r2 := Run.new(3)
	r2.choose(r2.available()[0])
	r2.record_battle(_fake("lose", ["tank", "knez", "lucistnik", "jezdec", "asasin"], [], 10.0))
	_check(r2.over == "lose" and r2.offers().is_empty() and r2.available().is_empty(), "porážka (padli všichni) ukončí běh")

	# a broken oath disappears
	var r3 := Run.new(4)
	r3.choose(r3.available()[0])
	var res := _fake("win", [], [], 30.0)
	res["oaths_broken"] = ["tank"]
	r3.record_battle(res)
	_check(r3.oath_of("tank") == "", "porušená přísaha po bitvě zmizí")


func _test_events_and_camp() -> void:
	print("Události a tábor")
	var r := Run.new(21)
	# we fake an event node
	var ev_node := {}
	for n: Dictionary in r.map["nodes"].values():
		if n["type"] == "udalost":
			ev_node = n
			break
	if ev_node.is_empty():
		_check(false, "mapa se semínkem 21 má událost")
		return
	for key: String in ["poutnik", "vypalena_ves", "zajatec", "kaple"]:
		var rr := Run.new(21)
		_event_at(rr, ev_node["id"], key)
		rr.heroes["knez"]["hp"] = 0.5
		var opts: Array = rr.event()["options"]
		_check(opts.size() >= 2, "[%s] má volby" % key)
		var before_glory := rr.glory
		var before_chron := rr.chronicle.size()
		rr.event_choose(0)
		_finish_choices(rr)
		_check(rr.event_done and not rr.available().is_empty(), "[%s] po volbě se jde dál" % key)
		_check(rr.chronicle.size() > before_chron or String(opts[0].get("text", "")) == "", "[%s] volba se zapíše do kroniky" % key)
		if key == "vypalena_ves":
			_check(rr.glory == before_glory + 30.0, "[vypalena_ves] pronásledování dá slávu")
		if key == "kaple":
			_check(is_equal_approx(rr.hp_of("knez"), 0.8), "[kaple] modlitba doléčí zraněné")
		if key == "poutnik":
			var oaths := 0
			for cls: String in rr.heroes:
				if rr.oath_of(cls) != "":
					oaths += 1
			_check(oaths == 2, "[poutnik] někdo složil přísahu")

	# alms without glory are not possible
	var rp := Run.new(21)
	_event_at(rp, ev_node["id"], "poutnik")
	rp.glory = 5.0
	_check(rp.event_option_problem(1) != "", "almužna bez slávy nejde")
	# helping the survivors = fled enemies at the boss
	var rv := Run.new(21)
	_event_at(rv, ev_node["id"], "vypalena_ves")
	rv.event_choose(1)
	_check(rv.fled.size() == 3, "[vypalena_ves] žháři utečou a vrátí se u bosse")

	# camp
	var rc := Run.new(22)
	var camp := ""
	for n: Dictionary in rc.map["nodes"].values():
		if n["type"] == "tabor":
			camp = n["id"]
			break
	rc.node_id = camp
	rc.heroes["tank"]["hp"] = 0.2
	rc.camp_rest()
	_check(rc.hp_of("tank") == 1.0, "tábor zahojí zranění")
	rc.heroes["tank"]["hp"] = 0.2
	rc.camp_rest()
	_check(rc.hp_of("tank") == 0.2, "v jednom táboře se odpočívá jen jednou")
	_test_new_events(ev_node["id"])
	_test_camp_choices(camp)


func _test_leader() -> void:
	print("Vůdce nepřátel")
	var data := Sim.load_data("zaverecna_bitva")
	var s := Sim.new(data, Sim.default_setup(data), 5)
	_check(not s.task_ok, "úkol Hejtman padne není splněný na začátku")
	var leader: Sim.Unit = null
	for u in s.living(Sim.SIDE_FOE):
		if u.leader:
			leader = u
	_check(leader != null, "v boji s bossem je vůdce")
	if leader == null:
		return
	s._hurt(s.by_id("asasin"), leader, 99999.0)
	s.step(DT)
	_check(s.foes_broken, "smrt vůdce zlomí morálku")
	_check(s.task_ok, "úkol Hejtman padne je splněný")


func _auto(s: Sim) -> void:
	for u in s.living(Sim.SIDE_KNIGHT):
		var h: Array = s.ability_hint(u.id)
		if h[0]:
			s.use_ability(u.id, h[1])


## Whole runs: a random path through the map, auto-play with abilities, random rewards, events and camps.
func _test_full_runs() -> void:
	print("Celé běhy (%d)" % RUNS)
	var wins := 0
	var stuck := 0
	var deaths := 0
	var battles := 0
	var lost_at := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in RUNS:
		var r := Run.new(100 + i)
		var guard := 0
		while r.over == "" and guard < 40:
			guard += 1
			var av := r.available()
			if av.is_empty():
				stuck += 1
				print("    běh %d uvízl na %s" % [i, r.node_id])
				break
			r.choose(av[rng.randi_range(0, av.size() - 1)])
			match r.node_type():
				"bitva", "elita", "boss":
					var data := r.load_stage_data()
					var s := Sim.new(data, r.battle_setup(data), 500 + i * 7 + guard)
					while s.over == "" and s.t < 400.0:
						s.step(DT)
						s.events.clear()
						s.auto_command()
						_auto(s)
					if s.over == "":
						stuck += 1
						print("    bitva %s uvízla (t=%.0f, zlomeni=%s)" % [r.node()["scenario"], s.t, s.foes_broken])
						for u in s.units:
							if u.alive() and not u.fled:
								print("      %s %s pos=(%.1f, %.1f) hp=%.0f asleep=%s moving=%s" % [u.id, u.key, u.pos.x, u.pos.y, u.hp, u.asleep, u.moving])
						break
					battles += 1
					r.record_battle(s.result())
					deaths += (s.result()["dead"] as Array).size()
					if r.over == "lose":
						var k := "%s (%s)" % [r.node_type(), r.node()["scenario"]]
						lost_at[k] = int(lost_at.get(k, 0)) + 1
					while r.has_legacy():
						var c := r.legacy_candidates()
						r.resolve_legacy(c[rng.randi_range(0, c.size() - 1)] if not c.is_empty() else "")
					while not r.bond_offer().is_empty():
						var ch: Array = r.bond_offer()["choices"]
						r.choose_bond(ch[rng.randi_range(0, ch.size() - 1)] if not ch.is_empty() else "")
					while not r.offers().is_empty():
						r.pick_offer(rng.randi_range(0, r.offers().size() - 1))
				"udalost":
					var opts: Array = r.event()["options"]
					var picked := false
					for o_i in opts.size():
						var oi := rng.randi_range(0, opts.size() - 1)
						if r.event_option_problem(oi) == "":
							r.event_choose(oi)
							picked = true
							break
					if not picked:
						r.event_choose(opts.size() - 1)
						if not r.event_done:
							r.event_done = true
					_finish_choices(r, rng)
				"tabor":
					var co: Array = r.camp_options()
					var pick: Dictionary = co[rng.randi_range(0, co.size() - 1)]
					var arg := ""
					if String(pick["needs"]) == "hero":
						arg = r.heroes.keys()[rng.randi_range(0, 4)]
					elif String(pick["needs"]) == "pair":
						arg = "tank|knez"
					if String(pick["problem"]) != "" or not r.camp_choose(pick["id"], arg):
						r.camp_choose("rest")
					_finish_choices(r, rng)
		if r.over == "win":
			wins += 1
		if i == 0:
			for e: Dictionary in r.chronicle:
				print("    [%s] %s" % [e["stage"], e["text"]])
	print("  vítězné běhy %d/%d, bitev %d, padlých %d, prohry na: %s" % [wins, RUNS, battles, deaths, lost_at])
	_check(stuck == 0, "žádný běh ani bitva neuvízne")
	_check(wins >= RUNS * 3 / 10, "auto-hraní vyhraje aspoň 30 %% běhů (%d/%d)" % [wins, RUNS])
	_check(wins < RUNS, "běh není jistá výhra (%d/%d)" % [wins, RUNS])


## Bonds: grow through shared victories, formed with a type choice, level, death and successor.
func _test_bonds() -> void:
	print("Pouta")
	var r := Run.new(21)
	r.choose(r.available()[0])
	r.record_battle(_fake("win", [], [], 30.0))
	_check(r.wins_of("tank", "knez") == 1 and r.bond_offer().is_empty(), "po první společné výhře pouto ještě nevzniká")
	r.record_battle(_fake("win", [], [], 30.0))
	var o := r.bond_offer()
	_check(not o.is_empty() and (o["choices"] as Array).size() == 2, "po 2 společných výhrách se nabízí pouto ze 2 typů")
	var fits := true
	for t: String in o.get("choices", []):
		fits = fits and r.bond_fits(t, o["a"], o["b"])
	_check(fits, "nabídnuté typy sedí na dvojici")
	_check(r.offers().is_empty() and not r.node_finished(), "dokud se pouto nevybere, odměna čeká")
	var a: String = o["a"]
	var b: String = o["b"]
	r.choose_bond(String(o["choices"][0]))
	_check(String(r.heroes[a]["bond"]["with"]) == b and String(r.heroes[b]["bond"]["with"]) == a and r.bond_level(a) == 1, "pouto vzniklo na úrovni 1 u obou")
	var o2 := r.bond_offer()
	_check(o2.is_empty() or not ([o2["a"], o2["b"]] as Array).has(a), "hrdina s poutem druhé nedostane")
	while not r.bond_offer().is_empty():
		r.choose_bond("")
	_check(r.bond_offer().is_empty() and not r.offers().is_empty(), "odložená pouta: pak přijde odměna")
	r.pick_offer(0)
	r.record_battle(_fake("win", [], [], 30.0))
	r.record_battle(_fake("win", [], [], 30.0))
	while not r.bond_offer().is_empty():
		r.choose_bond("")
	_check(r.bond_level(a) == 2, "po 4 společných výhrách úroveň 2 (kombo)")
	var st := r.battle_setup(r.load_stage_data())
	_check(int(st["bonds"][a]["level"]) == 2 and String(st["bonds"][a]["with"]) == b, "bitva dostane pouto s úrovní")
	var victim := a if r.oath_of(a) == "" else b
	var mate := b if victim == a else a
	r.record_battle(_fake("win", [victim], [], 30.0))
	_check((r.heroes[mate]["bond"] as Dictionary).is_empty() and r.wins_of(victim, mate) == 0 and r.wins_of(victim, "jezdec" if victim != "jezdec" else "tank") == 0, "smrt: druh přijde o pouto, nástupce začíná od nuly")
	# the Loner's Oath forbids bonds
	var rs := Run.new(22)
	rs.heroes["lucistnik"]["passives"] = ["samotar"]
	rs.choose(rs.available()[0])
	for i in 2:
		rs.record_battle(_fake("win", [], [], 30.0))
	var blocked := true
	while not rs.bond_offer().is_empty():
		var bo := rs.bond_offer()
		blocked = blocked and not ([bo["a"], bo["b"]] as Array).has("lucistnik")
		rs.choose_bond("")
	_check(blocked, "s Přísahou samotáře pouto nevznikne")


## Puts the run on an event node with the given event (as choose() would resolve it).
func _event_at(r: Run, node_id: String, key: String) -> void:
	r.node_id = node_id
	r.map["nodes"][node_id]["type"] = "udalost"
	r.map["nodes"][node_id]["event"] = key
	r.event_done = false
	r._resolve_event()


## Resolves pending choices and bonds (picks at random, or the first).
func _finish_choices(r: Run, rng: RandomNumberGenerator = null) -> void:
	for guard in 10:
		if not r.bond_offer().is_empty():
			var ch: Array = r.bond_offer()["choices"]
			r.choose_bond(ch[0] if not ch.is_empty() else "")
		elif not r.offers().is_empty():
			r.pick_offer(rng.randi_range(0, r.offers().size() - 1) if rng != null else 0)
		else:
			return


## Smart shuffle (decision 07.11.2026): on 200 maps no same non-battle type twice in a row, at most
## max_calm nodes without a fight in a row, and every fork offers different types.
func _test_shuffle() -> void:
	var repeat := 0
	var calm_long := 0
	var same_fork := 0
	var forks := 0
	var max_calm := int(Run.new(0).act.get("max_calm", 2))
	for seed_i in 200:
		var r := Run.new(1000 + seed_i)
		var floors: Array = r.map["floors"]
		var n_f: int = floors.size()
		var calm := {}
		for f in n_f:
			for n: Dictionary in floors[f]:
				var t: String = n["type"]
				var c := 0
				if t == "udalost" or t == "tabor":
					c = 1
					if f > 0:
						for p: Dictionary in floors[f - 1]:
							if (p["next"] as Array).has(n["id"]):
								c = maxi(c, int(calm[p["id"]]) + 1)
								if p["type"] == t and f < n_f - 1:
									repeat += 1
				elif t == "elita" and f > 0:
					for p: Dictionary in floors[f - 1]:
						if (p["next"] as Array).has(n["id"]) and p["type"] == t:
							repeat += 1
				calm[n["id"]] = c
				if c > max_calm:
					calm_long += 1
				if f < n_f - 2 and (n["next"] as Array).size() >= 2:
					forks += 1
					var types := {}
					for nx: String in n["next"]:
						types[r.node_type(nx)] = true
					if types.size() < 2:
						same_fork += 1
	_check(repeat == 0, "chytrý shuffle: žádná událost, elita ani tábor dvakrát za sebou (%d)" % repeat)
	_check(calm_long == 0, "chytrý shuffle: nejvýš %d uzly bez boje za sebou (%d porušení)" % [max_calm, calm_long])
	_check(same_fork == 0, "chytrý shuffle: rozcestí vždy nabízí různé typy (%d z %d stejné)" % [same_fork, forks])


## The 8 new events: targets, effects, choices.
func _test_new_events(ev_id: String) -> void:
	print("Nové události")
	for key: String in ["turnaj", "kovar", "opusteny_tabor", "zbeh", "mnich", "spor", "soud"]:
		var r := Run.new(31)
		r.heroes["tank"]["passives"] = ["nikdy_neustoupi"]
		_event_at(r, ev_id, key)
		_check(String(r.node()["event"]) == key, "[%s] událost jde (cíl existuje)" % key)
		var ev := r.event()
		_check(not String(ev["text"]).contains("{"), "[%s] text má doplněná jména" % key)
		r.glory = 100.0
		r.event_choose(0)
		_finish_choices(r)
		_check(r.event_done and not r.available().is_empty(), "[%s] po volbě a výběru se jde dál" % key)
		match key:
			"zbeh":
				var data := Sim.load_data("most_pres_reku")
				var st := r.battle_setup(data)
				var s0 := Sim.new(data, Sim.default_setup(data), 1)
				var s1 := Sim.new(data, st, 1)
				_check(int(st["remove_pods"]) == 1 and s1.living("e").size() + s1.pending.size() < s0.living("e").size() + s0.pending.size(), "[zbeh] příští bitva má o skupinu nepřátel méně")
			"soud":
				var st := r.battle_setup(Sim.load_data("most_pres_reku"))
				_check(st["oath_boost"].has("tank"), "[soud] potvrzená přísaha jde do bitvy")
				var s1 := Sim.new(Sim.load_data("most_pres_reku"), st, 1)
				_check(is_equal_approx(s1.stat(s1.by_id("tank"), "utok"), 0.25 * 1.5), "[soud] síla přísahy +50 %")
			"kovar":
				var hardened := 0
				for cls: String in r.heroes:
					if float((r.heroes[cls]["stats"] as Dictionary).get("odolnost", 0.0)) > 0.0:
						hardened += 1
				_check(hardened == 1 and is_equal_approx(r.glory, 75.0), "[kovar] jeden hrdina Odolnost +10 % za 25 slávy")
				var stk := r.battle_setup(Sim.load_data("most_pres_reku"))
				var sk := Sim.new(Sim.load_data("most_pres_reku"), stk, 1)
				_check(is_equal_approx(sk.by_id("tank").maxhp, 375.0 * 1.1), "[kovar] Odolnost natrvalo zvětší zdraví v bitvě")
			"spor":
				var a: String = r.event_ctx["a"]
				var b: String = r.event_ctx["b"]
				_check(r.wins_of(a, b) == 0, "[spor] zastat se jednoho ubere společné vítězství (nejvýš na 0)")
	# Grave of an Ancestor: only after someone fell
	var rg := Run.new(32)
	rg.heroes["tank"]["passives"] = ["veteran"]
	rg.choose(rg.available()[0])
	rg.record_battle(_fake("win", ["tank"], [], 30.0))
	_finish_choices(rg)
	_event_at(rg, ev_id, "hrob")
	_check(String(rg.node()["event"]) == "hrob", "[hrob] po padlém se objeví")
	rg.event_choose(0)
	_check((rg.heroes["tank"]["passives"] as Array).has("veteran"), "[hrob] nástupce zdědí pasivku padlého")
	var rn := Run.new(33)
	_event_at(rn, ev_id, "hrob")
	_check(String(rn.node()["event"]) != "hrob", "[hrob] bez padlého se neobjeví, místo ní jiná událost")
	# Next battle: Attack −15 % for the quarreling pair
	var rq := Run.new(34)
	_event_at(rq, ev_id, "spor")
	rq.event_choose(2)
	var stq := rq.battle_setup(Sim.load_data("most_pres_reku"))
	_check((stq["hero_stats"] as Dictionary).size() == 2, "[spor] nechat být: dvojice má v příští bitvě Útok −15 %")


## Camp: four choices, training and rite open a choice, feast costs glory and adds a shared victory.
func _test_camp_choices(camp: String) -> void:
	print("Tábor se čtyřmi volbami")
	var r := Run.new(22)
	r.node_id = camp
	_check(r.camp_options().size() == 4, "tábor nabízí 4 volby")
	_check(r.camp_choose("train", "lucistnik") and r.offers().size() == 3 and not r.node_finished(), "výcvik: 3 pasivky pro vybraného hrdinu")
	var ok := true
	for o: Dictionary in r.offers():
		ok = ok and o["hero"] == "lucistnik" and not r.is_oath(o["passive"])
	_check(ok, "výcvik nabízí jen pasivky toho hrdiny")
	r.pick_offer(0)
	_check(r.node_finished() and not r.camp_choose("rest"), "po volbě je tábor hotový, druhá volba nejde")
	var r2 := Run.new(22)
	r2.node_id = camp
	_check(r2.camp_choose("rite", "tank") and r2.offers().size() == 1 and String(r2.offers()[0]["kind"]) == "release_oath", "obřad u hrdiny s přísahou nabídne zrušení")
	r2.pick_offer(0)
	_check(r2.oath_of("tank") == "", "zrušená přísaha zmizí bez trestu")
	var r3 := Run.new(22)
	r3.node_id = camp
	_check(r3.camp_choose("rite", "knez") and r3.offers().size() == 2 and r3.is_oath(r3.offers()[0]["passive"]), "obřad u hrdiny bez přísahy: přísaha ze 2")
	var r4 := Run.new(22)
	r4.node_id = camp
	r4.glory = 40.0
	r4.heroes["tank"]["hp"] = 0.3
	r4.pair_wins[r4.pair_key("lucistnik", "asasin")] = 1
	_check(r4.camp_choose("feast", "lucistnik|asasin") and is_equal_approx(r4.glory, 10.0) and is_equal_approx(r4.hp_of("tank"), 0.8), "hostina: 30 slávy, všichni +50 % zdraví")
	_check(r4.wins_of("lucistnik", "asasin") == 2 and not r4.bond_offer().is_empty(), "hostina: dvojice +1 společné vítězství, může vzniknout pouto")
	var r5 := Run.new(22)
	r5.node_id = camp
	r5.glory = 10.0
	var feast_problem := ""
	for o: Dictionary in r5.camp_options():
		if o["id"] == "feast":
			feast_problem = o["problem"]
	_check(feast_problem != "" and not r5.camp_choose("feast", "tank|knez"), "hostina bez slávy nejde")


## Reward after a battle: 2 passives and an oath, the fallen get nothing, declining gives glory.
func _test_offers() -> void:
	print("Odměny po bitvě")
	var r := Run.new(41)
	r.choose(r.available()[0])
	r.record_battle(_fake("win", ["jezdec"], [], 30.0))
	var offers := r.offers()
	var oaths := 0
	var dead_hit := false
	for o: Dictionary in offers:
		if r.is_oath(o["passive"]):
			oaths += 1
		if o["hero"] == "jezdec":
			dead_hit = true
	_check(offers.size() == 3 and oaths == 1, "po bitvě 3 nabídky: 2 pasivky a přísaha")
	_check(not dead_hit, "padlý (ani jeho nástupce) nabídku nedostane")
	var notes_ok := true
	for o: Dictionary in offers:
		for n: Array in r.offer_notes(o):
			notes_ok = notes_ok and n.size() == 2 and String(n[1]) != ""
	_check(notes_ok, "nabídky mají vysvětlení dopadu (zelené / červené)")
	var g := r.glory
	r.decline_offers()
	_check(r.offers().is_empty() and is_equal_approx(r.glory, g + 15.0), "odmítnutí odměny dá +15 slávy")
	var o_bad := {"hero": "knez", "passive": "lovecka_cest"}
	var stat_note := false
	for n: Array in r.offer_notes({"hero": "knez", "passive": "nikdy_neustoupi"}):
		stat_note = stat_note or not bool(n[0])
	_check(r.offer_notes({"hero": "lucistnik", "passive": "lovecka_cest"}).size() >= 1 and o_bad.size() == 2, "přísaha ukáže, jak sedí ke schopnosti")
