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
	_test_passives(data)
	_test_groups(data)
	_test_orders(data)
	_test_target_priority(data)
	_test_morale(data)
	_test_decided(data)
	_test_waves()
	for sid: String in Sim.scenario_list():
		_test_calm(sid)
		_test_mode(sid)
	_test_oath(data)
	_test_stand_firm(data)
	var brod := Sim.load_data("brod_a_les")
	_test_terrain(brod)
	_test_retreat_order(brod)
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
	var no_orders := _run_batch(data, true, false)
	print("[%s] Bez rozkazů (se schopnostmi): výhry %d/%d, průměrná délka %.0f s" % [sid, no_orders["wins"], RUNS, no_orders["avg_t"]])
	print("[%s] Bez schopností: výhry %d/%d, průměrná délka %.0f s" % [sid, without["wins"], RUNS, without["avg_t"]])
	print("[%s] Se schopnostmi: výhry %d/%d, průměrná délka %.0f s, přeživší %.1f, úkol splněn %d×, sláva od: %s" % [sid, with_ab["wins"], RUNS, with_ab["avg_t"], with_ab["avg_alive"], with_ab["task"], with_ab["glory_by"]])
	_check(without["wins"] <= RUNS / 4, "[%s] bez schopností by se měla bitva většinou prohrát" % sid)
	# elita je těžší: se schopnostmi stačí polovina výher (čerstvý oddíl bez pasivek)
	var need: int = RUNS / 2 if bool(data["scenario"].get("elite", false)) else RUNS * 3 / 4
	_check(with_ab["wins"] >= need, "[%s] se schopnostmi by se měla bitva většinou vyhrát (%d/%d, potřeba %d)" % [sid, with_ab["wins"], RUNS, need])
	_check(with_ab["avg_t"] > 30.0 and with_ab["avg_t"] < 180.0, "[%s] bitva by měla trvat 30–180 s" % sid)
	_check(without["stuck"] == 0 and with_ab["stuck"] == 0 and no_orders["stuck"] == 0, "[%s] žádná bitva nesmí uvíznout (pat)" % sid)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


## Rozestavení pro automatické hraní: rozkazy od jednoduchého velitele (suggest_orders).
func _new_sim(data: Dictionary, seed: int, orders: bool = true) -> Sim:
	var s := Sim.new(data, Sim.default_setup(data), seed)
	if orders:
		s.apply_orders(s.suggest_orders())
	return s


## Automatické hraní: každý hrdina použije schopnost, když ji rada (ability_hint) doporučí.
func _auto_abilities(s: Sim) -> void:
	for u in s.living(Sim.SIDE_KNIGHT):
		var h: Array = s.ability_hint(u.id)
		if h[0]:
			s.use_ability(u.id, h[1])


func _run_batch(data: Dictionary, abilities: bool, orders: bool = true) -> Dictionary:
	var wins := 0
	var total_t := 0.0
	var alive := 0
	var task := 0
	var stuck := 0
	var glory_by := {}
	for i in RUNS:
		var s := _new_sim(data, 1000 + i, orders)
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
	var s := Sim.new(data, Sim.default_setup(data), 51)
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
	_check(not s.use_ability("knez", knez.pos + Vector2(0, 30)), "Požehnání nejde mimo dosah")
	_check(s.use_ability("knez", luc.pos) and luc.hp > 50.0 + luc.maxhp * 0.29, "Požehnání léčí hrdiny v mířeném kruhu")
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

	var s2 := Sim.new(data, Sim.default_setup(data), 52)
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

	var s3 := Sim.new(data, Sim.default_setup(data), 53)
	var asasin := s3.by_id("asasin")
	var victim := s3.by_id("e1")
	victim.pos = asasin.pos + Vector2(0, 5)
	var vh := victim.hp
	_check(s3.use_ability("asasin", victim.id) and asasin.pos.distance_to(victim.pos) < 1.5, "Úder ze stínu: skok k nepříteli")
	_check(vh - victim.hp >= asasin.dmg * 3.0 - 0.1 or not victim.alive(), "Úder ze stínu: trojnásobný úder")
	_check(not s3.use_ability("asasin", "tank"), "Úder ze stínu jen na nepřítele")


## Bez vlastních použití se platí slávou; bez slávy nejde.
func _test_glory_extra_use(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data), 54)
	var tank := s.by_id("tank")
	tank.uses = 0
	s.glory = 10.0
	_check(not s.can_use_ability("tank"), "bez použití a slávy schopnost nejde")
	s.glory = 50.0
	var cost := s.ability_cost("tank")
	_check(cost > 0.0 and s.use_ability("tank") and is_equal_approx(s.glory, 50.0 - cost), "použití navíc stojí slávu")
	s.glory = 100.0
	tank.ability_cd = 0.0
	_check(not s.can_use_ability("tank") and s.ability_problem("tank") != "", "za slávu jde schopnost navíc jen jednou za bitvu")

	# Požehnání se po použití nabíjí
	var s2 := Sim.new(data, Sim.default_setup(data), 57)
	s2.glory = 100.0
	_check(s2.use_ability("knez", s2.by_id("knez").pos), "Požehnání jde použít")
	_check(not s2.can_use_ability("knez"), "hned znovu ne (nabíjí se)")
	var cd: float = s2.ability_of("knez").get("cooldown", 0.0)
	while s2.t < cd + 0.5 and s2.over == "":
		s2.step(DT)
		s2.events.clear()
	_check(s2.can_use_ability("knez"), "po nabití jde Požehnání za slávu znovu")


## Obrana: vlny přicházejí postupně, bitva neskončí, dokud nepřijdou všechny, hrdina bez rozkazu drží místo.
func _test_waves() -> void:
	var data := Sim.load_data("lesni_ves")
	var s := Sim.new(data, Sim.default_setup(data), 9)
	var first := s.living(Sim.SIDE_FOE).size()
	_check(s.mode == "obrana" and s.pending.size() > 0 and s.waves_left == 2, "obrana: na začátku je jen první vlna, další dvě čekají")
	_check(s.groups.size() >= 4, "skupiny jsou i pro vlny, které ještě nepřišly (%d)" % s.groups.size())
	# první vlna zmizí: bitva nekončí, protože přijdou další
	for f in s.living(Sim.SIDE_FOE):
		f.hp = 0.0
	s.step(DT)
	_check(s.over == "", "bitva neskončí, dokud nepřijdou všechny vlny")
	var arrived := 0
	var far := 0.0
	while s.t < 40.0 and s.over == "":
		s.step(DT)
		for e in s.events:
			if e["type"] == "arrive":
				arrived += 1
		s.events.clear()
		var tank := s.by_id("tank")
		if tank.alive():
			far = maxf(far, tank.pos.distance_to(tank.home))
	_check(arrived > 0, "druhá vlna dorazila (%d nepřátel, první vlna měla %d)" % [arrived, first])
	var hr: float = data["units"]["orders"]["hold_radius"]
	_check(far <= hr * 2.0 + 2.0, "hrdina bez rozkazu nevybíhá dál než pár metrů od místa (%.1f m)" % far)


## Útok: s rozkazy na skupiny dojde ke kontaktu brzy (nikdo nestojí).
func _test_mode(sid: String) -> void:
	var data := Sim.load_data(sid)
	var s := _new_sim(data, 3)
	var first_contact := -1.0
	while s.over == "" and s.t < 20.0:
		s.step(DT)
		s.events.clear()
		for u in s.living(Sim.SIDE_KNIGHT):
			if first_contact < 0.0 and s.t - u.combat_t < 0.2:
				first_contact = s.t
	if s.mode == "utok" and String(data["scenario"].get("auto_plan", "attack")) != "hold":
		print("[%s] útok: první kontakt %.1f s" % [sid, first_contact])
		_check(first_contact >= 0.0 and first_contact < 20.0, "[%s] v útoku dojde ke kontaktu do 20 s (nikdo nestojí)" % sid)


func _nearest_foe_dist(s: Sim, p: Vector2) -> float:
	var best := INF
	for f in s.living(Sim.SIDE_FOE):
		best = minf(best, f.pos.distance_to(p))
	return best


## Nikdo nekmitá: hrdina v klidu nestřídá krok a stání pořád dokola (změna do 0,5 s po předchozí); kněz léčí.
func _test_calm(sid: String) -> void:
	var data := Sim.load_data(sid)
	var s := _new_sim(data, 7)
	var toggles := {}
	var last := {}
	var last_t := {}
	var heals := 0
	while s.over == "" and s.t < 60.0:
		s.step(DT)
		for e in s.events:
			if e["type"] == "heal":
				heals += 1
		s.events.clear()
		_auto_abilities(s)
		for u in s.living(Sim.SIDE_KNIGHT):
			var calm := s.t - u.combat_t > 1.5   # v boji se za pohyblivým cílem rozbíhat smí
			if last.has(u.id) and last[u.id] != u.moving:
				# kmitání = rozjezd a zastavení rychle po sobě; jít za pohybujícím se spojencem smí
				if calm and s.t - float(last_t.get(u.id, -10.0)) < 0.5:
					toggles[u.id] = int(toggles.get(u.id, 0)) + 1
				last_t[u.id] = s.t
			last[u.id] = u.moving
	var worst := 0
	for id: String in toggles:
		worst = maxi(worst, int(toggles[id]))
	print("[%s] kmitání mimo boj (rozjezdy a zastavení): %s, léčení %d×" % [sid, toggles, heals])
	_check(worst <= 16, "[%s] hrdinové nekmitají (nejvíc %d změn)" % [sid, worst])
	_check(heals > 0, "[%s] kněz u spojence léčí" % sid)


## Skupiny nepřátel: Most má pěší a střelce zvlášť, název s počtem, nepřítel zná svou skupinu.
func _test_groups(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data), 55)
	var archer := s.by_id("e11")
	var lapka := s.by_id("e0")
	_check(archer.ranged and s.group_of(archer.id) != s.group_of(lapka.id), "střelci jsou jiná skupina než pěší")
	var names := []
	for g in s.groups.size():
		names.append(s.group_name(g))
	print("Skupiny (Most): %s" % [names])
	_check(names.has("Lapkové (11)") and names.has("Střelci (5)"), "Most: skupiny Lapkové (11) a Střelci (5)")
	lapka.hp = 0.0
	_check(s.group_name(s.group_of("e1")) == "Lapkové (10)", "počet ve skupině ubývá s padlými")


## Rozkazy: na místo, na skupinu, ke spojenci, bez rozkazu; přísaha pomsty neposlouchá.
func _test_orders(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data), 57)
	_check(s.unordered().size() == 5, "na začátku jsou všichni bez rozkazu")
	var jezdec := s.by_id("jezdec")
	var spot := jezdec.pos + Vector2(-3.0, 0.0)
	_check(not s.set_order("jezdec", "point", Vector2(-4.0, 6.0)) and s.order_problem("jezdec", "point", Vector2(-4.0, 6.0)) != "", "na místo ve vodě rozkaz nejde")
	_check(s.set_order("jezdec", "point", spot) and s.order_text("jezdec") == "Na místo", "rozkaz na místo")
	_check(not s.set_order("knez", "ally", "knez") and not s.set_order("knez", "ally", "e0"), "ke spojenci jen k jinému hrdinovi")
	_check(s.set_order("knez", "ally", "tank") and s.order_text("knez") == "Se spojencem: Sir Bořek", "rozkaz ke spojenci")
	_check(not s.set_order("asasin", "group", 99), "na neznámou skupinu rozkaz nejde")
	var shooters := s.group_of("e11")
	_check(s.set_order("asasin", "group", "e12") and s.by_id("asasin").order_group == shooters, "rozkaz na skupinu podle nepřítele")
	_check(s.unordered().size() == 2, "bez rozkazu zbývají dva (%s)" % [s.unordered()])
	var tank := s.by_id("tank")
	var tank_home := tank.pos
	s.set_order("lucistnik", "point", tank.pos + Vector2(0.0, -12.0))
	var asasin := s.by_id("asasin")
	var hit_shooter := false
	for i in 300:
		s.step(DT)
		s.events.clear()
		if s.t - asasin.combat_t < 0.1 and asasin.alive():
			var tg := s._nearest(s.living(Sim.SIDE_FOE), asasin.pos)
			hit_shooter = hit_shooter or (tg != null and tg.ranged)
	_check(jezdec.order_done and jezdec.pos.distance_to(spot) < 1.5 or s.t - jezdec.combat_t < 1.0, "na místo: hrdina dojde a drží ho")
	_check(s.by_id("knez").pos.distance_to(tank.pos) < 6.0, "ke spojenci: kněz se drží u tanka (%.1f m)" % s.by_id("knez").pos.distance_to(tank.pos))
	_check(hit_shooter or not asasin.alive(), "na skupinu: asasín jde po střelcích")
	_check(tank.pos.distance_to(tank_home) < 9.0, "tank bez rozkazu drží místo (%.1f m)" % tank.pos.distance_to(tank_home))

	# bez rozkazu: vzdáleného nepřítele nechá, blízkého napadne
	var s2 := Sim.new(data, Sim.default_setup(data), 58)
	for u in s2.units:
		if u.side == Sim.SIDE_FOE and u.id != "e0" and u.id != "e1":
			_park(u)
	s2.by_id("lucistnik").hp = 0.0   # střelec by vzdáleného zasáhl a ten by se rozběhl
	var t2 := s2.by_id("tank")
	var far := s2.by_id("e0")
	var near := s2.by_id("e1")
	for f in [far, near]:
		f.speed = 0.0
		f.hold = true
		f.hold_engage = 0.0
	far.pos = t2.pos + Vector2(0.0, 8.0)
	near.pos = t2.pos + Vector2(2.5, 1.0)
	far.home = far.pos   # poplach po zásahu blízkého (do alarm_radius od jeho místa) vzdáleného nesmí uvolnit
	near.home = near.pos
	for i in 120:
		s2.step(DT)
		s2.events.clear()
	_check(near.hp < near.maxhp and far.pos.distance_to(t2.pos) > 5.0, "bez rozkazu: bojuje s tím, kdo přijde blízko, a za vzdáleným nejde (blízký %.0f/%.0f, vzdálený %.1f m, tank %s, rozhodnuto %s)" % [near.hp, near.maxhp, far.pos.distance_to(t2.pos), t2.pos, s2.decided])

	# skupina padne: rozkaz je splněn, hrdina drží místo
	var s3 := Sim.new(data, Sim.default_setup(data), 59)
	s3.set_order("jezdec", "group", "e11")
	for f in s3.group_members(s3.group_of("e11")):
		f.hp = 0.0
	s3.step(DT)
	_check(s3.by_id("jezdec").order_done and s3.order_text("jezdec") == "Skupina padla, drží místo", "po pádu skupiny drží místo")

	# rada automatického velitele dá rozkaz všem
	var s4 := Sim.new(data, Sim.default_setup(data), 60)
	var plan := s4.suggest_orders()
	_check(plan.size() == 5 and String(plan["knez"][0]) == "ally", "automatický velitel rozhodne o všech (%s)" % [plan])

	# přísaha pomsty: dokud žije viník, jde po něm a rozkaz neplatí
	var s5 := Sim.new(data, Sim.default_setup(data), 64)
	s5.set_passive("tank", "nikdy_neustoupi", false)
	s5.set_passive("tank", "pomsta", true)
	var culprit := s5.by_id("e3")
	s5._hurt(culprit, s5.by_id("knez"), 5.0)
	var tk := s5.by_id("tank")
	var d0 := tk.pos.distance_to(culprit.pos)
	for i in 60:
		s5.step(DT)
		s5.events.clear()
	_check(tk.pos.distance_to(culprit.pos) < d0 - 2.0 or s5.t - tk.combat_t < 0.5, "přísaha pomsty: jde po viníkovi")


## Tank s přísahou Nikdy neustoupí sám necouvne.
func _test_stand_firm(data: Dictionary) -> void:
	var max_back := 0.0
	for i in 10:
		var s := Sim.new(data, Sim.default_setup(data), 200 + i)
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
	var s := Sim.new(data, Sim.default_setup(data), 29)
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


## Rozkaz na místo za zády: rytíř s přísahou Nikdy neustoupí nejde dál od nepřítele (drží, kde stojí).
## Nepřítel odstavený daleko (stojí, drží, nikoho nenapadne): test se týká jen ostatních.
func _park(u: Sim.Unit) -> void:
	u.pos = Vector2(u.pos.x, 60.0)
	u.home = u.pos
	u.speed = 0.0
	u.hold = true
	u.hold_engage = 0.0
	u.ranged = false


func _test_retreat_order(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data), 31)
	var tank := s.by_id("tank")
	var back := tank.pos + Vector2(0.0, -6.0)
	_check(s.has_oath("tank") and s.is_retreat("tank", back), "rozkaz dozadu je ústup")
	s.set_order("tank", "point", back)
	var y0 := tank.pos.y
	for i in 60:
		s.step(DT)
		s.events.clear()
	_check(tank.pos.y > y0 - 1.0 and tank.order_done, "s přísahou nejde dozadu, drží místo (y %.1f -> %.1f)" % [y0, tank.pos.y])
	s.break_oath("tank")
	s.set_order("tank", "point", back)
	for i in 120:
		s.step(DT)
		s.events.clear()
	_check(tank.pos.distance_to(back) < 1.0, "po porušení přísahy rozkaz dozadu poslechne")


## Kopiníci jsou proti jízdě silnější a nezlomí se; Zbabělec uteče, i když je pěšák.
func _test_spears_and_traits(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data), 37)
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
	var ss := Sim.new(Sim.load_data(), Sim.default_setup(Sim.load_data()), 37)
	var lapka := ss.by_id("e0")
	lapka.desperate = true
	_check(is_equal_approx(ss._dmg_mult(lapka), 1.3), "lapka se Zoufalcem: zoufalství 20 % + 10 %")
	s.by_id("tank").hp = 0.0
	s._hurt(null, s.by_id("knez"), 99999.0)
	_check(not s.task_ok, "úkol Nikdo nepadne selže, když padne kdokoli")


## Nepřátelé na Brodu drží pozice; pěšák po zásahu vyrazí, po čase postupují všichni.
func _test_enemy_hold(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data), 43)
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
	var s := Sim.new(data, Sim.default_setup(data), 19)
	for i in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12]:
		s.by_id("e%d" % i).hp = 0.0   # 12 z 16 ztrát = 75 %
	s.step(DT)
	var lapka := s.by_id("e10")
	var strelec := s.by_id("e13")
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
	var fresh := Sim.new(data, Sim.default_setup(data), 19)
	_check(not fresh.can_charge(), "bez zlomené morálky povel Do boje! nejde")


## Když je bitva rozhodnutá, hrdinové jdou do útoku.
func _test_decided(data: Dictionary) -> void:
	# pojistka sama: scénář, kde se morálka nezlomí (kopie dat, ostatní testy se nezmění)
	var d2 := data.duplicate(true)
	d2["scenario"]["enemy_morale"]["break_losses"] = 1.1
	var s := Sim.new(d2, Sim.default_setup(d2), 23)
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


## Rozkaz od nepřítele je ústup; porušení přísahy stojí slávu.
func _test_oath(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data), 3)
	var tank := s.by_id("tank")
	_check(s.is_retreat("tank", tank.pos + Vector2(0, -5)), "přesun od nepřítele je ústup")
	_check(not s.is_retreat("tank", tank.pos + Vector2(0, 2)), "přesun k nepříteli není ústup")
	s.glory = 50.0
	s.break_oath("tank")
	_check(not s.has_oath("tank") and s.oaths_broken() == 1 and is_equal_approx(s.glory, 30.0), "porušení přísahy stojí 20 slávy")


## Asasín si z dosažitelných nepřátel vybírá střelce.
func _test_target_priority(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data), 13)
	var asasin := s.by_id("asasin")
	var tg := s._choose_target(asasin, s.living(Sim.SIDE_FOE))
	_check(tg != null and tg.ranged, "asasín má přednostně cílit na střelce")
	var tank := s.by_id("tank")
	var tg2 := s._choose_target(tank, s.living(Sim.SIDE_FOE))
	_check(tg2 != null and not tg2.ranged, "ostatní cílí na nejbližšího")



## Pasivky a přísahy: pravidla přidávání a jejich efekty.
func _test_passives(data: Dictionary) -> void:
	var s := Sim.new(data, Sim.default_setup(data), 61)
	var tank := s.by_id("tank")
	var knez := s.by_id("knez")
	var luc := s.by_id("lucistnik")
	var jezdec := s.by_id("jezdec")
	var asasin := s.by_id("asasin")
	_check(s.has_oath("tank") and s.oath_of("tank")["name"] == "Nikdy neustoupí", "tank má na zkoušku přísahu z rodu")
	_check(not s.set_passive("tank", "rychle_ruce", true), "pasivka jiné třídy nejde")
	_check(not s.set_passive("tank", "pomsta", true), "hrdina má nejvýš jednu přísahu")
	_check(s.set_passive("tank", "veteran", true) and is_equal_approx(tank.maxhp, 375.0 * 1.15), "Veterán: +15 % zdraví")
	_check(s.set_passive("knez", "milosrdenstvi", true) and is_equal_approx(knez.heal, 14.0 * 1.5), "Milosrdenství: léčení +50 %")
	_check(s.set_passive("lucistnik", "rychle_ruce", true) and is_equal_approx(luc.cd, 1.3 * 0.8), "Rychlé ruce: rychlejší střelba")
	_check(s.set_passive("jezdec", "druhy_najezd", true) and jezdec.uses == 3, "Druhý nájezd: 3 použití")
	_check(s.set_passive("tank", "hlasita_vyzva", true) and is_equal_approx(float(s.ability_of("tank")["radius"]), 9.0), "Hlasitá výzva: dosah 9 m")
	_check(s.set_passive("asasin", "chudoba", true) and asasin.uses == 3, "Slib chudoby: použití navíc")
	var g0 := s.glory
	var foe := s.by_id("e0")
	s._hurt(asasin, foe, 1.0)
	_check(is_equal_approx(s.glory, g0), "Slib chudoby: hrdina nepřináší slávu")
	_check(s.set_passive("asasin", "lovec", true) and is_equal_approx(s._dmg_mult(asasin, s.by_id("e12")), 1.3), "Lovec: +30 % proti střelcům")
	_check(s.set_passive("tank", "ochrance", true), "Ochránce jde tankovi")
	luc.pos = tank.pos + Vector2(1.0, 0.0)
	_check(is_equal_approx(s._taken_mult(luc), (1.0 - luc.armor) * 0.8), "Ochránce: spojenec u tanka dostává méně")
	s.set_passive("tank", "druhy_dech", true)
	tank.hp = tank.maxhp * 0.32
	s._hurt(foe, tank, 30.0)
	_check(tank.second_wind_used and tank.hp > tank.maxhp * 0.4, "Druhý dech: pod 30 % se tank vzchopí")
	_check(s.order_problem("tank") == "", "bez přísahy pomsty rozkaz platí")
	s.set_passive("knez", "posledni_pomazani", true)
	knez.pos = luc.pos + Vector2(1.0, 0.0)
	s._hurt(foe, luc, 99999.0)
	_check(luc.alive() and knez.revive_used, "Poslední pomazání: kněz zvedne padlého")
	s.set_passive("jezdec", "mstitel", true)
	s._hurt(foe, luc, 99999.0)
	_check(not luc.alive() and jezdec.avenger, "Mstitel: po smrti spojence silnější")

	var s2 := Sim.new(data, Sim.default_setup(data), 62)
	s2.set_passive("lucistnik", "ohniva_salva", true)
	var l2 := s2.by_id("lucistnik")
	var spot := l2.pos + Vector2(0, 8)
	for f in s2.living(Sim.SIDE_FOE):
		f.pos = spot
		f.hold = true
		f.speed = 0.0
	s2.use_ability("lucistnik", spot)
	_check(s2.zones.size() == 1, "Ohnivá salva zapálí zem")
	var hp_a := s2.by_id("e5").hp
	for i in 30:
		s2.step(DT)
		s2.events.clear()
	_check(s2.by_id("e5").hp < hp_a, "oheň pálí nepřátele")
	var g_fire := s2.glory
	for i in 30:
		s2.step(DT)
		s2.events.clear()
	_check(s2.glory <= g_fire + float(data["house"]["glory"]["per_kill"]) * 3.0, "oheň nedává slávu za každý zásah (%.0f -> %.0f)" % [g_fire, s2.glory])
	s2.set_passive("tank", "ochrance", false)
	var s3 := Sim.new(data, Sim.default_setup(data), 63)
	s3.set_passive("tank", "nikdy_neustoupi", false)
	_check(s3.set_passive("tank", "pomsta", true), "přísahu jde vyměnit")
	s3._hurt(s3.by_id("e0"), s3.by_id("knez"), 5.0)
	_check(s3.order_problem("tank") != "" and not s3.order_move("tank", Vector2.ZERO), "Přísaha pomsty: neposlechne rozkaz, dokud viník žije")
	_check(is_equal_approx(s3._dmg_mult(s3.by_id("tank"), s3.by_id("e0")), 1.4), "Přísaha pomsty: +40 % proti viníkovi")
	s3.set_passive("asasin", "ukryt", true)
	var a3 := s3.by_id("asasin")
	var v3 := s3.by_id("e1")
	v3.pos = a3.pos + Vector2(0, 4)
	s3.use_ability("asasin", v3.id)
	_check(a3.hidden_t > 0.0 and not s3._visible_knights().has(a3), "Úkryt: po úderu ho nikdo necílí")
