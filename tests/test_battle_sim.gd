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

	_report_bearers(data)
	_test_banner_pickup(data)
	_test_bearer(data)
	_test_target_priority(data)
	_test_no_idle(data)
	_test_oath_and_signal(data)
	_test_oath_postures(data)
	_test_stand_firm(data)

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


func _run_batch(data: Dictionary, shouts: bool, bearer: String = "") -> Dictionary:
	var wins := 0
	var total_t := 0.0
	var alive := 0
	var task := 0
	var stuck := 0
	for i in RUNS:
		var setup := Sim.default_setup(data, 0)
		if bearer != "":
			setup["bearer"] = bearer
		var s := Sim.new(data, setup, 1000 + i)
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
	var bearer := s.by_id(s.bearer_id)
	s._hurt(null, bearer, 99999.0)
	var paused := false
	for e in s.events:
		if e["type"] == "autopause":
			paused = true
	_check(paused, "smrt nositele praporu musí vyvolat automatickou pauzu")
	_check(not s.task_ok, "smrt nositele praporu pokazí úkol Prapor nesmí padnout")
	_check(s.aura_center() == null and not s.can_shout("zarod"), "bez praporu nesmí jít pokřiky")
	s.glory = 100.0
	for i in 300:
		s.step(DT)
		if not s.banner_down:
			break
	_check(not s.banner_down and s.aura_center() != null, "padlý prapor musí někdo zvednout")
	if s.aura_center() != null:
		var c := s.aura_center()
		print("Prapor zvedl: %s (%s)" % [c.name, s.posture_name(c.id, c.posture)])
		_check(c.posture != "chranit", "kdo zvedne prapor, přestane ho chránit (nese ho)")
		_check(not s._no_retreat(c), "rytíř s přísahou Nikdy neustoupí prapor nezvedá")


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


func _test_oath_postures(data: Dictionary) -> void:
	var setup := Sim.default_setup(data, 1)
	setup["bearer"] = "lucistnik"   # nositel nesmí prapor chránit, to by se pletlo se zákazem z přísahy
	setup["posture"]["tank"] = "chranit"
	var s := Sim.new(data, setup, 5)
	_check(s.by_id("tank").posture == "drzet", "zakázaný postoj z rozestavení se změní na povolený")
	_check(not s.posture_allowed("tank", "chranit"), "přísaha zakazuje tankovi Chránit prapor")
	_check(not s.set_posture("tank", "chranit") and s.by_id("tank").posture == "drzet", "zakázaný postoj nejde nastavit")
	_check(s.posture_name("tank", "drzet") == "Stát pevně", "přísaha přejmenuje Držet pozici na Stát pevně")
	_check(s.posture_name("knez", "drzet") == "Držet pozici", "ostatním rytířům zůstane Držet pozici")
	s.break_oath()
	_check(s.posture_allowed("tank", "chranit") and s.set_posture("tank", "chranit"), "po porušení přísahy jsou postoje volné")
	_check(s.posture_name("tank", "drzet") == "Držet pozici", "po porušení přísahy se postoj jmenuje zase normálně")


## Tank s přísahou v postoji Stát pevně nikdy sám nejde (necouvá ani se nevrací na místo).
func _test_stand_firm(data: Dictionary) -> void:
	var walked := 0
	var max_back := 0.0
	for i in 10:
		var s := Sim.new(data, Sim.default_setup(data, 0), 200 + i)
		var tank := s.by_id("tank")
		var start_y := tank.pos.y
		while s.over == "" and s.t < 400.0:
			s.step(DT)
			s.events.clear()
			_auto_shouts(s)
			if tank.alive() and s.has_oath("tank") and tank.posture == "drzet":
				if tank.moving:
					walked += 1
				max_back = maxf(max_back, start_y - tank.pos.y)
	print("Stát pevně: kroků chůze %d, největší odsun dozadu %.2f m" % [walked, max_back])
	_check(walked == 0, "tank s přísahou v postoji Stát pevně nesmí sám chodit")
	_check(max_back < 1.0, "tank s přísahou nesmí couvnout (odsun tlačenicí do 1 m je tolerovaný)")


## Informativně: jak dopadne bitva s pokřiky podle toho, kdo nese prapor.
func _report_bearers(data: Dictionary) -> void:
	var line := "Nositel praporu (s pokřiky):"
	for key: String in data["units"]["knights"]:
		var r := _run_batch(data, true, key)
		line += "  %s %d/%d" % [key, r["wins"], RUNS]
	print(line)


## Nositel se volí jen v rozestavení, třída určuje, co prapor dělá, a nositel nemůže prapor chránit.
func _test_bearer(data: Dictionary) -> void:
	var setup := Sim.default_setup(data, 1)
	setup["bearer"] = "knez"
	var s := Sim.new(data, setup, 11)
	_check(s.bearer_id == "knez" and s.by_id("knez").posture == "drzet", "nositel z rozestavení s postojem Chránit prapor přejde na Držet pozici")
	_check(not s.posture_allowed("knez", "chranit") and not s.set_posture("knez", "chranit"), "nositel nesmí mít postoj Chránit prapor")
	_check(s.bearer_forbids("knez", "chranit") and not s.oath_forbids("knez", "chranit"), "zákaz je kvůli praporu, ne kvůli přísaze")

	_check(s.set_bearer("lucistnik") and is_equal_approx(s.aura_radius, 7.0), "lučištník s praporem má auru 7 m")
	_check(s.posture_allowed("knez", "chranit"), "bývalý nositel smí zase prapor chránit")
	_check(s.set_bearer("asasin") and is_equal_approx(s.aura_radius, 4.0), "asasín s praporem má auru 4 m")
	var asasin := s.by_id("asasin")
	_check(is_equal_approx(s._dmg_mult(asasin), 1.30), "asasínův prapor dává v auře +30 % útok")
	_check(s.set_bearer("tank") and is_equal_approx(s.aura_radius, 5.0), "tank s praporem má auru podle rodu")
	var tank := s.by_id("tank")
	_check(is_equal_approx(s._taken_mult(tank), (1.0 - tank.armor) * 0.85), "tankův prapor snižuje v auře zranění o 15 %")
	_check(s.set_bearer("jezdec"), "jezdce jde určit nositelem")
	var jezdec := s.by_id("jezdec")
	_check(is_equal_approx(s._speed(jezdec), jezdec.speed * 1.25), "jezdcův prapor dává v auře +25 % rychlost")

	s.set_bearer("knez")
	var knez := s.by_id("knez")
	knez.hp = 100.0
	knez.heal_t = 99.0
	s.step(DT)
	_check(knez.hp > 100.0, "kněz s praporem léčí v auře")

	_check(not s.set_bearer("tank") and s.bearer_id == "knez", "po začátku bitvy se prapor nepředává")


## Asasín si z dosažitelných nepřátel vybírá střelce.
func _test_target_priority(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data, 0), 13)
	var asasin := s.by_id("asasin")
	var tg := s._choose_target(asasin, s.living(Sim.SIDE_FOE))
	_check(tg != null and tg.ranged, "asasín má přednostně cílit na střelce")
	var tank := s.by_id("tank")
	var tg2 := s._choose_target(tank, s.living(Sim.SIDE_FOE))
	_check(tg2 != null and not tg2.ranged, "ostatní cílí na nejbližšího")


## Rytíř v Držet pozici nestojí, když jeho spolubojovník bojuje jinde (konec bitvy, poslední dva rytíři).
func _test_no_idle(data: Dictionary) -> void:
	var setup := Sim.default_setup(data, 0)
	setup["posture"]["knez"] = "drzet"
	setup["posture"]["jezdec"] = "drzet"
	var s := Sim.new(data, setup, 17)
	for u in s.units:
		if u.id != "knez" and u.id != "jezdec" and u.id != "e0":
			u.hp = 0.0
	var knez := s.by_id("knez")
	var jezdec := s.by_id("jezdec")
	knez.pos = Vector2(-5.0, -8.0)
	knez.home = knez.pos
	jezdec.pos = Vector2(5.0, -4.0)
	jezdec.home = jezdec.pos
	s.by_id("e0").pos = Vector2(5.0, -2.8)
	var start := knez.pos.distance_to(jezdec.pos)
	for i in 150:
		s.step(DT)
		s.events.clear()
	var now := knez.pos.distance_to(jezdec.pos)
	print("Pomoc spolubojovníkovi: kněz %.1f m -> %.1f m od jezdce" % [start, now])
	_check(now < start - 3.0, "rytíř bez cíle v Držet pozici jde pomoct bojujícímu spolubojovníkovi")
