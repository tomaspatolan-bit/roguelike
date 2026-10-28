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

	for sid: String in Sim.scenario_list():
		_balance(sid)

	_report_bearers(data)
	_test_banner_pickup(data)
	_test_bearer(data)
	_test_target_priority(data)
	_test_no_idle(data)
	_test_morale(data)
	_test_decided(data)
	_test_oath_and_signal(data)
	_test_oath_postures(data)
	_test_stand_firm(data)
	var brod := Sim.load_data("brod_a_les")
	_test_terrain(brod)
	_test_routes(brod)
	_test_spears_and_traits(brod)
	_test_class_postures(data)
	_test_enemy_hold(brod)

	if failures.is_empty():
		print("OK: všechny testy prošly")
		quit(0)
	else:
		for f in failures:
			print("FAIL: " + f)
		quit(1)


## Balanc scénáře: bez pokřiků většinou prohra, s pokřiky většinou výhra, 30–180 s, žádný pat.
func _balance(sid: String) -> void:
	var data := Sim.load_data(sid)
	var without := _run_batch(data, false)
	var with_shouts := _run_batch(data, true)
	print("[%s] Bez pokřiků: výhry %d/%d, průměrná délka %.0f s" % [sid, without["wins"], RUNS, without["avg_t"]])
	print("[%s] S pokřiky:   výhry %d/%d, průměrná délka %.0f s, přeživší rytíři %.1f, úkol splněn %d×" % [sid, with_shouts["wins"], RUNS, with_shouts["avg_t"], with_shouts["avg_alive"], with_shouts["task"]])
	_check(without["wins"] <= RUNS / 4, "[%s] bez pokřiků by se měla bitva většinou prohrát" % sid)
	_check(with_shouts["wins"] >= RUNS * 3 / 4, "[%s] s pokřiky by se měla bitva většinou vyhrát" % sid)
	_check(with_shouts["avg_t"] > 30.0 and with_shouts["avg_t"] < 180.0, "[%s] bitva by měla trvat 30–180 s" % sid)
	_check(without["stuck"] == 0 and with_shouts["stuck"] == 0, "[%s] žádná bitva nesmí uvíznout (pat)" % sid)


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
			if tank.alive() and s.has_oath("tank") and tank.posture == "drzet" and s.decided == "":
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
	_check(s.bearer_id == "knez" and s.by_id("knez").posture != "chranit" and s.posture_allowed("knez", s.by_id("knez").posture), "nositel z rozestavení s postojem Chránit prapor přejde na jiný povolený postoj")
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
	setup["posture"]["knez"] = "lecit"
	setup["posture"]["jezdec"] = "vypad"
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
	_check(now < start - 3.0, "kněz v Léčit frontu jde za bojujícím spolubojovníkem")
	# Držet pozici: lučištník bez cíle jde pomoct bojujícímu (nestojí bez práce)
	var s2 := Sim.new(data, Sim.default_setup(data, 0), 17)
	for u in s2.units:
		if u.id != "lucistnik" and u.id != "jezdec" and u.id != "e0":
			u.hp = 0.0
	var luc := s2.by_id("lucistnik")
	luc.pos = Vector2(-5.0, -20.0)
	luc.home = luc.pos
	s2.by_id("jezdec").pos = Vector2(5.0, -4.0)
	s2.by_id("e0").pos = Vector2(5.0, -2.8)
	var d0 := luc.pos.distance_to(s2.by_id("e0").pos)
	for i in 150:
		s2.step(DT)
		s2.events.clear()
	_check(luc.pos.distance_to(s2.by_id("e0").pos) < d0 - 3.0, "lučištník v Ostřelovat bez cíle jde pomoct bojujícímu")


## Po ztrátě 70 % se nepřítel zlomí: střelci prchnou z bojiště, pěšáci zoufale dobojují.
func _test_morale(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data, 0), 19)
	for i in 8:
		s.by_id("e%d" % i).hp = 0.0
	s.by_id("e11").hp = 0.0   # 9 z 12 ztrát = 75 %
	s.step(DT)
	var lapka := s.by_id("e8")
	var strelec := s.by_id("e9")
	_check(s.foes_broken, "po ztrátě 70 % se morálka nepřítele zlomí")
	_check(lapka.desperate and not lapka.fleeing and s._dmg_mult(lapka) > 1.0, "pěšák se zlomenou morálkou zoufale útočí silněji")
	_check(strelec.fleeing and not strelec.desperate, "střelec se zlomenou morálkou prchá")
	for i in 600:
		s.step(DT)
		s.events.clear()
		if strelec.fled:
			break
	_check(strelec.fled and not strelec.alive(), "prchající střelec opustí bojiště")
	print("Morálka: střelec utekl za %.1f s" % s.t)
	var tank := s.by_id("tank")
	_check(s.decided == "", "po zlomení morálky se automatické dobojování nespustí, rozhoduje hráč")
	_check(s.can_charge() and s.charge_all() and not s.can_charge(), "povel Do boje! jde po zlomení morálky použít jen jednou")
	var before := tank.pos
	for i in 60:
		s.step(DT)
		s.events.clear()
	_check(tank.pos.distance_to(before) > 0.5 or s.over != "", "po povelu Do boje! jde i tank se Stát pevně dobojovat")
	var fresh := Sim.new(data, Sim.default_setup(data, 0), 19)
	_check(not fresh.can_charge(), "bez zlomené morálky povel Do boje! nejde")


## Když je bitva rozhodnutá, rytíř v Držet pozici jde do útoku.
func _test_decided(data: Dictionary) -> void:
	# pojistka sama: scénář, kde se morálka nezlomí (kopie dat, ostatní testy se nezmění)
	var d2 := data.duplicate(true)
	d2["scenario"]["enemy_morale"]["break_losses"] = 1.1
	var s := Sim.new(d2, Sim.default_setup(d2, 0), 23)
	for i in 11:
		s.by_id("e%d" % i).hp = 0.0
	s.step(DT)
	var ev := false
	for e in s.events:
		if e["type"] == "decided":
			ev = true
	_check(s.decided == "k" and ev, "při převaze rytířů je bitva rozhodnutá a ohlásí se")
	var luc := s.by_id("lucistnik")
	var before := luc.pos
	for i in 90:
		s.step(DT)
		s.events.clear()
	_check(luc.pos.distance_to(before) > 1.0 or s.over == "win", "v rozhodnuté bitvě jdou i rytíři v Držet pozici dobojovat")


## Brody zpomalí, lávka a brody vedou přes řeku, les zpomalí všechny kromě asasína, stezka ne.
func _test_terrain(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data, 0), 29)
	var tank := s.by_id("tank")
	var asasin := s.by_id("asasin")
	_check(is_equal_approx(s.terrain_speed(tank, Vector2(-8.5, 6.5)), 0.55), "brod zpomalí")
	_check(s._in_water(Vector2(-3.0, 6.5)) and not s._in_water(Vector2(0.0, 6.5)) and not s._in_water(Vector2(8.0, 6.5)), "voda mimo brody a lávku")
	_check(s.terrain_speed(tank, Vector2(3.0, 12.0)) < 1.0 and is_equal_approx(s.terrain_speed(asasin, Vector2(3.0, 12.0)), 1.0), "les zpomalí, asasína ne")
	_check(is_equal_approx(s.terrain_speed(tank, Vector2(0.0, 12.0)), 1.0), "stezka lesem nezpomaluje")
	# rytíř z levé strany dojde přes řeku na druhý břeh a nikdy nevstoupí do vody
	for u in s.units:
		if u.side == Sim.SIDE_FOE:
			u.hp = 0.0
	s.by_id("e0").hp = 120.0
	s.by_id("e0").pos = Vector2(-8.0, 20.0)
	s.by_id("e0").speed = 0.0
	tank.posture = "utok"
	var wet := false
	for i in 900:
		s.step(DT)
		s.events.clear()
		if s._in_water(tank.pos):
			wet = true
		if tank.pos.y > 9.0:
			break
	_check(tank.pos.y > 9.0 and not wet, "rytíř přejde řeku brodem a nevstoupí do vody (y = %.1f)" % tank.pos.y)


## Trasa: zjednodušení, průchod po bodech, body ve vodě se zahodí, přísaha nedovolí trasu zpět.
func _test_routes(data: Dictionary) -> void:
	var line: Array[Vector2] = []
	for i in 40:
		line.append(Vector2(sin(i * 0.2) * 3.0, i * 0.5))
	var simple := Sim.simplify_route(line, 4)
	_check(simple.size() <= 4 and simple.size() >= 2 and simple[0] == line[0] and simple[-1] == line[-1], "zjednodušení nechá 2–4 body a zachová začátek i konec")

	var s := Sim.new(data, Sim.default_setup(data, 0), 31)
	var asasin := s.by_id("asasin")
	var pts: Array[Vector2] = [Vector2(0.0, 4.0), Vector2(-3.0, 6.5), Vector2(0.0, 10.0), Vector2(0.0, 13.0)]
	_check(s.set_route("asasin", pts) and asasin.route.size() == 3, "bod trasy ve vodě se zahodí")
	var back: Array[Vector2] = [Vector2(-7.5, 3.0), Vector2(-7.5, -3.0)]
	_check(not s.set_route("tank", back) and s.route_problem("tank", back) != "", "rytíř s přísahou Nikdy neustoupí nemá trasu zpět")
	var fwd: Array[Vector2] = [Vector2(-8.0, 3.0)]
	_check(s.set_route("tank", fwd), "trasa dopředu jde i s přísahou")
	for u in s.units:
		if u.side == Sim.SIDE_FOE:
			u.hp = 0.0
	var target := s.by_id("e14")
	target.hp = 90.0
	target.pos = Vector2(14.0, 23.0)
	target.speed = 0.0
	target.traits.append("fanatik")
	var reached := false
	for i in 900:
		s.step(DT)
		s.events.clear()
		if asasin.route_i >= asasin.route.size():
			reached = true
			break
	_check(reached and asasin.pos.distance_to(Vector2(0.0, 13.0)) < 1.0, "rytíř dojde po trase na její konec (%s)" % asasin.pos)
	_check(not s.set_route("asasin", []), "po začátku bitvy se trasa nemění")


## Kopiníci jsou proti jízdě silnější a nezlomí se; Zbabělec uteče, i když je pěšák.
func _test_spears_and_traits(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data, 0), 37)
	var spear := s.by_id("e5")
	var jezdec := s.by_id("jezdec")
	var tank := s.by_id("tank")
	_check(spear.key == "kopinik" and is_equal_approx(spear.vs_mounted, 2.0) and jezdec.mounted and not tank.mounted, "kopiník má bonus proti jízdě, jezdec je jízda")
	var h0 := jezdec.hp
	spear.t = 0.0
	s._attack(spear, jezdec)
	var hit_j := h0 - jezdec.hp
	spear.t = 0.0
	var t0 := tank.hp
	s._attack(spear, tank)
	var hit_t := t0 - tank.hp
	_check(hit_j > hit_t * 1.5, "kopiník zraní jezdce víc než tanka (%.1f vs %.1f)" % [hit_j, hit_t])
	# naživu zůstane kopiník (Fanatik), lapka se Zbabělcem a jeden střelec
	for i in s.living(Sim.SIDE_FOE).size():
		if i != 5 and i != 9 and i != 12:
			s.by_id("e%d" % i).hp = 0.0
	s.step(DT)
	_check(s.foes_broken, "po ztrátách se morálka zlomí")
	_check(not s.by_id("e5").desperate and not s.by_id("e5").fleeing, "Fanatik (kopiník) se nezlomí")
	_check(s.by_id("e9").fleeing, "Zbabělec uteče, i když je pěšák")
	_check(s.by_id("e12").fleeing, "střelec uteče")
	var ss := Sim.new(Sim.load_data(), Sim.default_setup(Sim.load_data(), 0), 37)
	var lapka := ss.by_id("e0")
	lapka.desperate = true
	_check(is_equal_approx(ss._dmg_mult(lapka), 1.3), "lapka se Zoufalcem: zoufalství 20 % + 10 %")
	s.by_id("tank").hp = 0.0
	s._hurt(null, s.by_id("knez"), 99999.0)
	_check(not s.task_ok, "úkol Nikdo nepadne selže, když padne kdokoli")


## Každá třída má své postoje; Záloha čeká, dokud se oddíl nestřetne; Výpad se vrací k praporu.
func _test_class_postures(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data, 0), 41)
	_check(s.postures_for("jezdec") == ["vypad", "zaloha"] and not s.posture_allowed("jezdec", "drzet"), "jezdec zná jen své postoje")
	_check(s.posture_name("asasin", "utok") == "Lovit střelce" and s.posture_name("lucistnik", "drzet") == "Ostřelovat", "třída má vlastní názvy postojů")
	var setup := Sim.default_setup(data, 0)
	setup["posture"]["jezdec"] = "drzet"
	var s2 := Sim.new(data, setup, 41)
	_check(s2.by_id("jezdec").posture == "vypad", "neznámý postoj z rozestavení se změní na první povolený")
	var asasin := s.by_id("asasin")
	s.set_posture("asasin", "zaloha")
	var start := asasin.pos
	for i in 30:
		s.step(DT)
		s.events.clear()
	_check(asasin.pos.distance_to(start) < 0.3 and not asasin.sprung, "Číhat: asasín čeká, dokud se nikdo nestřetne")
	s.by_id("tank").combat_t = s.t
	s.step(DT)
	_check(asasin.sprung, "Číhat: když se někdo střetne, asasín vyrazí")


## Nepřátelé na Brodu drží pozice; pěšák po zásahu vyrazí, po čase postupují všichni.
func _test_enemy_hold(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data, 0), 43)
	var lapka := s.by_id("e0")
	var archer := s.by_id("e12")
	var l0 := lapka.pos
	for i in 150:
		s.step(DT)
		s.events.clear()
	_check(lapka.hold and lapka.pos.distance_to(l0) < 1.0, "lapka drží brod, dokud k ní nikdo nepřijde")
	_check(archer.hold, "střelec drží břeh")
	lapka.hp -= 10.0
	s.step(DT)
	_check(not lapka.hold, "zasažený pěšák opustí pozici")
	s.t = 31.0
	s.step(DT)
	_check(not archer.hold, "po vypršení času postupují všichni")
