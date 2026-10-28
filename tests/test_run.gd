extends SceneTree
## Testy zkušebního běhu bez okna.
## Spuštění: godot --headless --path . --script res://tests/test_run.gd
## Konec s kódem 0 = vše prošlo, 1 = něco selhalo.

const Sim := preload("res://scripts/sim/battle_sim.gd")
const Run := preload("res://scripts/run/run_state.gd")
const RUNS := 20
const DT := 1.0 / 30.0

var failures: Array[String] = []


func _init() -> void:
	_test_rules()
	_test_leader()
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


func _fake(over: String, dead: Array, fled: Array, glory: float) -> Dictionary:
	return {"over": over, "t": 60.0, "dead": dead, "fled": fled, "glory": glory, "glory_by": {"tank": 12.0, "lucistnik": 30.0}, "oaths_broken": [], "task_ok": true}


## Pravidla běhu na podvržených výsledcích bitev.
func _test_rules() -> void:
	print("Pravidla běhu")
	var r := Run.new(7)
	_check(r.stage_count() == 3, "běh má 3 bitvy")
	_check(r.oath_of("tank") == "nikdy_neustoupi", "Bořek začíná s přísahou")
	var data := r.load_stage_data()
	var setup := r.battle_setup(data)
	_check(setup["names"]["tank"] == "Sir Bořek" and float(setup["glory"]) == 25.0, "setup nese jména a slávu")
	_check((setup["extra_enemies"] as Array).is_empty(), "v první bitvě se nikdo nevrací")

	# bitva 1: padne Bořek (s přísahou), utečou 2 lapkové a střelec
	r.record_battle(_fake("win", ["tank"], ["lapka", "lapka", "strelec"], 61.0))
	_check(r.stage == 1 and r.over == "", "po vítězství se jde dál")
	_check(r.glory == 61.0, "sláva se přenáší")
	_check(r.hero_name("tank") == "Sir Vítek", "nastoupil nástupce stejné třídy")
	_check((r.heroes["tank"]["passives"] as Array).is_empty(), "nástupce začíná bez pasivek")
	_check(r.fallen.size() == 1 and r.fallen[0]["name"] == "Sir Bořek", "padlý je v seznamu padlých")
	_check(r.has_legacy() and r.legacy_current()["oath"] == "nikdy_neustoupi", "přísaha padlého čeká na dědice")
	_check(r.legacy_candidates().has("tank") and r.legacy_candidates().size() == 5, "zdědit může kdokoli bez přísahy, i nástupce")
	_check(r.fled.size() == 3, "uprchlíci se zapamatovali")
	r.resolve_legacy("lucistnik")
	_check(r.oath_of("lucistnik") == "nikdy_neustoupi" and not r.has_legacy(), "Matěj zdědil přísahu")

	var offers := r.offers()
	_check(offers.size() == 3, "nabízí se 3 odměny")
	var ok := true
	for o: Dictionary in offers:
		var d: Dictionary = r.units_data["passives"][o["passive"]]
		var c: String = d.get("class", "any")
		if c != "any" and c != o["hero"]:
			ok = false
		if o["hero"] == "lucistnik" and r.is_oath(o["passive"]):
			ok = false
	_check(ok, "nabídky sedí na třídu a nedávají druhou přísahu")
	var o0: Dictionary = offers[0]
	r.pick_offer(0)
	_check((r.heroes[o0["hero"]]["passives"] as Array).has(o0["passive"]), "vybraná odměna patří hrdinovi")
	_check(r.offers().is_empty(), "odměna se vybírá jen jednou")

	# bitva 2: nikdo nepadne, uteče kopiník
	r.record_battle(_fake("win", [], ["kopinik"], 80.0))
	_check(r.fled.size() == 4, "uprchlíci z bitev 1 a 2")
	var d3 := r.load_stage_data()
	var s3 := r.battle_setup(d3)
	_check((s3["extra_enemies"] as Array).size() == 4, "v závěrečné bitvě se uprchlíci vrátí")
	var sim := Sim.new(d3, s3, 1)
	_check(sim.living(Sim.SIDE_FOE).size() == (d3["scenario"]["enemies"] as Array).size() + 4, "vrácení uprchlíci jsou v bitvě")
	_check(sim.by_id("tank").name == "Sir Vítek", "nástupce bojuje pod svým jménem")

	# bitva 3: vítězství, konec běhu
	r.record_battle(_fake("win", ["knez"], [], 90.0))
	_check(r.over == "win", "po závěrečné bitvě běh končí vítězstvím")
	_check(r.returned.size() == 4 and r.fled.is_empty(), "návrat uprchlíků je v kronice")
	_check(r.chronicle.size() >= 8, "kronika má záznamy (%d)" % r.chronicle.size())

	# prohra = padli všichni
	var r2 := Run.new(3)
	r2.record_battle(_fake("lose", ["tank", "knez", "lucistnik", "jezdec", "asasin"], [], 10.0))
	_check(r2.over == "lose" and r2.offers().is_empty(), "porážka (padli všichni) ukončí běh")

	# porušená přísaha zmizí
	var r3 := Run.new(4)
	var res := _fake("win", [], [], 30.0)
	res["oaths_broken"] = ["tank"]
	r3.record_battle(res)
	_check(r3.oath_of("tank") == "", "porušená přísaha po bitvě zmizí")


func _test_leader() -> void:
	print("Vůdce nepřátel")
	var data := Sim.load_data("zaverecna_bitva")
	var s := Sim.new(data, Sim.default_setup(data, 0), 5)
	_check(not s.task_ok, "úkol Hejtman padne není splněný na začátku")
	var leader: Sim.Unit = null
	for u in s.living(Sim.SIDE_FOE):
		if u.leader:
			leader = u
	_check(leader != null, "v závěrečné bitvě je vůdce")
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


## Celé běhy: auto-hraní se schopnostmi, náhodné odměny a dědictví.
func _test_full_runs() -> void:
	print("Celé běhy (%d)" % RUNS)
	var wins := 0
	var stuck := 0
	var deaths := 0
	var returned := 0
	var stages := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in RUNS:
		var r := Run.new(100 + i)
		while r.over == "":
			var data := r.load_stage_data()
			var s := Sim.new(data, r.battle_setup(data), 500 + i * 7 + r.stage)
			while s.over == "" and s.t < 400.0:
				s.step(DT)
				s.events.clear()
				_auto(s)
			if s.over == "":
				stuck += 1
				break
			r.record_battle(s.result())
			stages += 1
			deaths += (s.result()["dead"] as Array).size()
			returned += r.returned.size()
			while r.has_legacy():
				var c := r.legacy_candidates()
				r.resolve_legacy(c[rng.randi_range(0, c.size() - 1)] if not c.is_empty() else "")
			var offs := r.offers()
			if not offs.is_empty():
				r.pick_offer(rng.randi_range(0, offs.size() - 1))
		if r.over == "win":
			wins += 1
		if i == 0:
			for e: Dictionary in r.chronicle:
				print("    [%s] %s" % [e["stage"], e["text"]])
	print("  vítězné běhy %d/%d, bitev %d, padlých %d, vrácených uprchlíků %d" % [wins, RUNS, stages, deaths, returned])
	_check(stuck == 0, "žádná bitva v běhu neuvízne")
	_check(wins >= RUNS / 2, "auto-hraní se schopnostmi vyhraje aspoň polovinu běhů")
