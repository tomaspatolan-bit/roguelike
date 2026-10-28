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

	_test_abilities(data)
	_test_glory_extra_use(data)
	_test_behaviors(data)
	_test_order_hold(data)
	_test_target_priority(data)
	_test_morale(data)
	_test_decided(data)
	_test_oath_and_signal(data)
	_test_stand_firm(data)
	var brod := Sim.load_data("brod_a_les")
	_test_terrain(brod)
	_test_routes(brod)
	_test_spears_and_traits(brod)
	_test_enemy_hold(brod)

	if failures.is_empty():
		print("OK: všechny testy prošly")
		quit(0)
	else:
		for f in failures:
			print("FAIL: " + f)
		quit(1)


## Balanc scénáře: bez schopností většinou prohra, se schopnostmi většinou výhra, 30–180 s, žádný pat.
func _balance(sid: String) -> void:
	var data := Sim.load_data(sid)
	var without := _run_batch(data, false)
	var with_ab := _run_batch(data, true)
	print("[%s] Bez schopností: výhry %d/%d, průměrná délka %.0f s" % [sid, without["wins"], RUNS, without["avg_t"]])
	print("[%s] Se schopnostmi: výhry %d/%d, průměrná délka %.0f s, přeživší %.1f, úkol splněn %d×, sláva od: %s" % [sid, with_ab["wins"], RUNS, with_ab["avg_t"], with_ab["avg_alive"], with_ab["task"], with_ab["glory_by"]])
	_check(without["wins"] <= RUNS / 4, "[%s] bez schopností by se měla bitva většinou prohrát" % sid)
	_check(with_ab["wins"] >= RUNS * 3 / 4, "[%s] se schopnostmi by se měla bitva většinou vyhrát" % sid)
	_check(with_ab["avg_t"] > 30.0 and with_ab["avg_t"] < 180.0, "[%s] bitva by měla trvat 30–180 s" % sid)
	_check(without["stuck"] == 0 and with_ab["stuck"] == 0, "[%s] žádná bitva nesmí uvíznout (pat)" % sid)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


## Automatické hraní: každý hrdina použije schopnost, když ji rada (ability_hint) doporučí.
func _auto_abilities(s: Sim) -> void:
	for u in s.living(Sim.SIDE_KNIGHT):
		var h: Array = s.ability_hint(u.id)
		if h[0]:
			s.use_ability(u.id, h[1])


func _run_batch(data: Dictionary, abilities: bool) -> Dictionary:
	var wins := 0
	var total_t := 0.0
	var alive := 0
	var task := 0
	var stuck := 0
	var glory_by := {}
	for i in RUNS:
		var s := Sim.new(data, Sim.default_setup(data, 0), 1000 + i)
		while s.over == "" and s.t < 400.0:
			s.step(DT)
			s.events.clear()
			if abilities:
				_auto_abilities(s)
		total_t += s.t
		if s.over == "":
			stuck += 1
		elif s.over == "win":
			wins += 1
			alive += s.living(Sim.SIDE_KNIGHT).size()
			if s.task_ok:
				task += 1
		for k in s.knights():
			glory_by[k.id] = int(glory_by.get(k.id, 0) + k.glory_earned / RUNS)
	return {"wins": wins, "avg_t": total_t / RUNS, "avg_alive": float(alive) / maxi(wins, 1), "task": task, "stuck": stuck, "glory_by": glory_by}


## Každá schopnost dělá, co slibuje, a ubírá použití.
func _test_abilities(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data, 0), 51)
	var tank := s.by_id("tank")
	var lapka := s.by_id("e0")
	lapka.pos = tank.pos + Vector2(0, 3)
	lapka.hold = false
	var uses := tank.uses
	_check(s.use_ability("tank") and tank.uses == uses - 1 and tank.taunt_t > 0.0, "Výzva se použije a ubere použití")
	_check(is_equal_approx(s._taken_mult(tank), (1.0 - tank.armor) * 0.5), "Výzva: poloviční zranění")
	_check(s._taunter_for(lapka, s.living(Sim.SIDE_KNIGHT)) == tank, "Výzva: nepřítel v dosahu útočí na tanka")

	var knez := s.by_id("knez")
	var luc := s.by_id("lucistnik")
	luc.pos = knez.pos + Vector2(2, 0)
	luc.hp = 50.0
	_check(s.use_ability("knez") and luc.hp > 50.0 + luc.maxhp * 0.29, "Požehnání léčí hrdiny v dosahu")
	_check(not s.can_use_ability("knez") or s.glory >= s.ability_cost("knez"), "kněz má jen jedno použití")

	var target := Vector2(luc.pos.x, luc.pos.y + 8.0)
	for f in s.living(Sim.SIDE_FOE):
		f.pos = target + Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
	var hp0 := 0.0
	for f in s.living(Sim.SIDE_FOE):
		hp0 += f.hp
	_check(s.use_ability("lucistnik", target), "Salva jde na místo v dosahu")
	var hp1 := 0.0
	for f in s.living(Sim.SIDE_FOE):
		hp1 += f.hp
	_check(hp0 - hp1 > 40.0, "Salva zraní nepřátele v kruhu (%.0f)" % (hp0 - hp1))
	_check(not s.use_ability("lucistnik", luc.pos + Vector2(0, 30)), "Salva mimo dosah nejde")

	var s2 := Sim.new(data, Sim.default_setup(data, 0), 52)
	var jezdec := s2.by_id("jezdec")
	var f0 := s2.by_id("e0")
	f0.hold = false
	f0.pos = jezdec.pos + Vector2(0, 3)
	_check(s2.use_ability("jezdec", jezdec.pos + Vector2(0, 6)) and jezdec.dashing, "Nájezd se rozjede")
	for i in 30:
		s2.step(DT)
		s2.events.clear()
	_check(f0.hp < f0.maxhp and (f0.stun_t > 0.0 or not f0.alive() or f0.hp < f0.maxhp), "Nájezd zasáhne nepřítele v cestě")
	_check(not jezdec.dashing, "Nájezd skončí v cíli")
	_check(not s2.use_ability("jezdec", Vector2(-3.0, 6.0)), "Nájezd do vody nejde")

	var s3 := Sim.new(data, Sim.default_setup(data, 0), 53)
	var asasin := s3.by_id("asasin")
	var victim := s3.by_id("e1")
	victim.pos = asasin.pos + Vector2(0, 5)
	var vh := victim.hp
	_check(s3.use_ability("asasin", victim.id) and asasin.pos.distance_to(victim.pos) < 1.5, "Úder ze stínu: skok k nepříteli")
	_check(vh - victim.hp >= asasin.dmg * 3.0 - 0.1 or not victim.alive(), "Úder ze stínu: trojnásobný úder")
	_check(not s3.use_ability("asasin", "tank"), "Úder ze stínu jen na nepřítele")


## Bez vlastních použití se platí slávou; bez slávy nejde.
func _test_glory_extra_use(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data, 0), 54)
	var tank := s.by_id("tank")
	tank.uses = 0
	s.glory = 10.0
	_check(not s.can_use_ability("tank"), "bez použití a slávy schopnost nejde")
	s.glory = 50.0
	var cost := s.ability_cost("tank")
	_check(cost > 0.0 and s.use_ability("tank") and is_equal_approx(s.glory, 50.0 - cost), "použití navíc stojí slávu")


## Výchozí chování: tank jde před oddíl, lučištník couvne před blízkým nepřítelem, kněz se drží za bojujícím,
## lučištník bez cíle jde k bojujícímu (nestojí bez práce).
func _test_behaviors(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data, 0), 55)
	for u in s.units:
		if u.side == Sim.SIDE_FOE and u.id != "e0":
			u.hp = 0.0
	var luc := s.by_id("lucistnik")
	var e := s.by_id("e0")
	e.hold = false
	e.speed = 0.0
	e.pos = luc.pos + Vector2(0, 1.5)
	var d0 := luc.pos.distance_to(e.pos)
	for i in 20:
		s.step(DT)
		s.events.clear()
	_check(luc.pos.distance_to(e.pos) > d0 + 0.5, "lučištník couvne před blízkým nepřítelem")

	var s2 := Sim.new(data, Sim.default_setup(data, 0), 56)
	for u in s2.units:
		if u.side == Sim.SIDE_FOE and u.id != "e0":
			u.hp = 0.0
	var knez := s2.by_id("knez")
	var jezdec := s2.by_id("jezdec")
	var l2 := s2.by_id("lucistnik")
	knez.pos = Vector2(-5.0, -8.0)
	l2.pos = Vector2(-5.0, -20.0)
	jezdec.pos = Vector2(5.0, -4.0)
	var e2 := s2.by_id("e0")
	e2.pos = Vector2(5.0, -2.8)
	e2.speed = 0.0
	var k0 := knez.pos.distance_to(jezdec.pos)
	var a0 := l2.pos.distance_to(e2.pos)
	for i in 150:
		s2.step(DT)
		s2.events.clear()
	print("Chování: kněz %.1f -> %.1f m od bojujícího jezdce, lučištník %.1f -> %.1f m od nepřítele" % [k0, knez.pos.distance_to(jezdec.pos), a0, l2.pos.distance_to(e2.pos)])
	_check(knez.pos.distance_to(jezdec.pos) < k0 - 3.0, "kněz jde za bojujícím spolubojovníkem")
	_check(l2.pos.distance_to(e2.pos) < a0 - 3.0, "lučištník bez cíle jde k tomu, kdo bojuje")


## Rozkaz přesunu: hrdina dojde na místo a drží ho.
func _test_order_hold(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data, 0), 57)
	var jezdec := s.by_id("jezdec")
	var spot := jezdec.pos + Vector2(-3.0, 0.0)
	s.order_move("jezdec", spot)
	for i in 90:
		s.step(DT)
		s.events.clear()
	_check(jezdec.holding and jezdec.pos.distance_to(spot) < 0.8, "rozkaz přesunu: hrdina dojde na místo a drží ho")
	s.release("jezdec")
	_check(not jezdec.holding, "zrušení rozkazu vrátí výchozí chování")


## Tank s přísahou Nikdy neustoupí sám necouvne.
func _test_stand_firm(data: Dictionary) -> void:
	var max_back := 0.0
	for i in 10:
		var s := Sim.new(data, Sim.default_setup(data, 0), 200 + i)
		var tank := s.by_id("tank")
		var start_y := tank.pos.y
		while s.over == "" and s.t < 400.0:
			s.step(DT)
			s.events.clear()
			_auto_abilities(s)
			if tank.alive() and s.has_oath("tank") and s.decided == "" and not s.charging:
				max_back = maxf(max_back, start_y - tank.pos.y)
	print("Nikdy neustoupí: největší odsun dozadu %.2f m" % max_back)
	_check(max_back < 1.0, "tank s přísahou nesmí couvnout (odsun tlačenicí do 1 m je tolerovaný)")


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
	s.charging = true   # všichni jdou na nepřítele
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
	_check(tank.pos.distance_to(before) > 0.5 or s.over != "", "po povelu Do boje! jde i tank s přísahou dobojovat")
	var fresh := Sim.new(data, Sim.default_setup(data, 0), 19)
	_check(not fresh.can_charge(), "bez zlomené morálky povel Do boje! nejde")


## Když je bitva rozhodnutá, hrdinové jdou do útoku.
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
	_check(luc.pos.distance_to(before) > 1.0 or s.over == "win", "v rozhodnuté bitvě jdou hrdinové dobojovat")


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


## Asasín si z dosažitelných nepřátel vybírá střelce.
func _test_target_priority(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data, 0), 13)
	var asasin := s.by_id("asasin")
	var tg := s._choose_target(asasin, s.living(Sim.SIDE_FOE))
	_check(tg != null and tg.ranged, "asasín má přednostně cílit na střelce")
	var tank := s.by_id("tank")
	var tg2 := s._choose_target(tank, s.living(Sim.SIDE_FOE))
	_check(tg2 != null and not tg2.ranged, "ostatní cílí na nejbližšího")
