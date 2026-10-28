extends SceneTree
## Testy simulace bitvy bez okna.
## Spuštění: godot --headless --path . --script res://tests/test_battle_sim.gd
## Konec s kódem 0 = vše prošlo, 1 = něco selhalo.

const Sim := preload("res://scripts/sim/battle_sim.gd")
const RUNS := 40
const DT := 1.0 / 30.0

var failures: Array[String] = []


func _init() -> void:
	var data := Sim.load_data()
	if data["units"].is_empty() or data["house"].is_empty() or data["scenario"].is_empty():
		print("FAIL: data se nenačetla")
		quit(1)
		return

	var without := _run_batch(data, false)
	var with_shouts := _run_batch(data, true)
	print("Bez pokřiků: výhry %d/%d, průměrná délka %.0f s" % [without["wins"], RUNS, without["avg_t"]])
	print("S pokřiky:   výhry %d/%d, průměrná délka %.0f s, přeživší rytíři %.1f, úkol splněn %d×" % [with_shouts["wins"], RUNS, with_shouts["avg_t"], with_shouts["avg_alive"], with_shouts["task"]])
	_check(without["wins"] <= RUNS / 4, "bez pokřiků by se měla bitva většinou prohrát")
	_check(with_shouts["wins"] >= RUNS * 3 / 4, "s pokřiky by se měla bitva většinou vyhrát")
	_check(with_shouts["avg_t"] > 30.0 and with_shouts["avg_t"] < 180.0, "bitva by měla trvat 30–180 s")
	_check(without["stuck"] == 0 and with_shouts["stuck"] == 0, "žádná bitva nesmí uvíznout (pat)")

	_test_banner_pickup(data)
	_test_oath_and_signal(data)

	if failures.is_empty():
		print("OK: všechny testy prošly")
		quit(0)
	else:
		for f in failures:
			print("FAIL: " + f)
		quit(1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _auto_shouts(s: Sim) -> void:
	var foe_near := false
	for e in s.living(Sim.SIDE_FOE):
		if s.in_aura(e):
			foe_near = true
			break
	if not foe_near:
		return
	if s.can_shout("zarod"):
		s.shout("zarod")
	elif float(s.fx["zarod"]) <= 0.0 and s.can_shout("hradba"):
		s.shout("hradba")


func _run_batch(data: Dictionary, shouts: bool) -> Dictionary:
	var wins := 0
	var total_t := 0.0
	var alive := 0
	var task := 0
	var stuck := 0
	for i in RUNS:
		var s := Sim.new(data, Sim.default_setup(data, 0), 1000 + i)
		while s.over == "" and s.t < 400.0:
			s.step(DT)
			s.events.clear()
			if shouts:
				_auto_shouts(s)
		total_t += s.t
		if s.over == "":
			stuck += 1
		elif s.over == "win":
			wins += 1
			alive += s.living(Sim.SIDE_KNIGHT).size()
			if s.task_ok:
				task += 1
	return {"wins": wins, "avg_t": total_t / RUNS, "avg_alive": float(alive) / maxi(wins, 1), "task": task, "stuck": stuck}


func _test_banner_pickup(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data, 1), 7)
	var bearer := s.by_id("praporecnik")
	s._hurt(null, bearer, 99999.0)
	var paused := false
	for e in s.events:
		if e["type"] == "autopause":
			paused = true
	_check(paused, "smrt praporečníka musí vyvolat automatickou pauzu")
	_check(s.aura_center() == null and not s.can_shout("zarod"), "bez praporu nesmí jít pokřiky")
	s.glory = 100.0
	for i in 300:
		s.step(DT)
		if not s.banner_down:
			break
	_check(not s.banner_down and s.aura_center() != null, "padlý prapor musí někdo zvednout")
	if s.aura_center() != null:
		print("Prapor zvedl: %s" % s.aura_center().name)


func _test_oath_and_signal(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data, 1), 3)
	_check(s.use_signal() and s.signals == 0, "signál se musí odečíst")
	_check(not s.use_signal(), "bez zbývajících signálů nejde signál použít")
	var tank := s.by_id("tank")
	_check(s.is_retreat("tank", tank.pos + Vector2(0, -5)), "přesun od nepřítele je ústup")
	_check(not s.is_retreat("tank", tank.pos + Vector2(0, 2)), "přesun k nepříteli není ústup")
	s.glory = 50.0
	s.break_oath()
	_check(not s.oath_kept and is_equal_approx(s.glory, 30.0), "porušení přísahy stojí 20 slávy")
