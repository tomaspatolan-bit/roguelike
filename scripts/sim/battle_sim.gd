class_name BattleSim
extends RefCounted
## Logika jedné bitvy bez grafiky. Dá se spustit v testech bez okna.
##
## Souřadnice: Vector2(x, y), x doprava, y dopředu (k nepříteli), 1 jednotka = 1 m.
## Scéna to převádí na 3D jako Vector3(x, výška, -y).
## Data (statistiky, schopnosti, rod, scénář) přicházejí z JSON souborů ve složce data/.
##
## Hráč velí hrdinům: každý má pevné výchozí chování podle třídy (behavior) a jednu schopnost
## s počtem použití za bitvu. Sláva je společná rezerva rodu, platí se z ní použití navíc.

const SIDE_KNIGHT := "k"
const SIDE_FOE := "e"
const DEFAULT_SCENARIO := "most_pres_reku"


class Unit:
	extends RefCounted
	var id: String
	var side: String
	var key: String
	var name: String
	var role: String
	var hp: float
	var maxhp: float
	var dmg: float
	var reach: float
	var speed: float
	var cd: float
	var armor: float
	var radius: float
	var ranged: bool = false
	var heal: float = 0.0
	var heal_cd: float = 0.0
	var heal_range: float = 0.0
	var palette_row: int = 0
	var target_priority: String = ""
	var color: Color = Color.WHITE
	var pos: Vector2
	var home: Vector2
	var behavior: String = ""     # výchozí chování třídy (hrdinové)
	var ability: String = ""      # klíč schopnosti (hrdinové)
	var uses: int = 0             # zbývající použití schopnosti v této bitvě
	var holding: bool = false     # rozkaz přesunu: drží místo `home` místo výchozího chování
	var t: float = 0.0
	var heal_t: float = 0.0
	var atk: float = 0.0
	var hit: float = 0.0
	var face: Vector2 = Vector2(0, 1)
	var moving: bool = false
	var combat_t: float = -INF    # kdy naposledy útočil nebo dostal zásah
	var taunt_t: float = 0.0      # Výzva: dokud běží, nepřátelé v dosahu útočí na něj
	var stun_t: float = 0.0       # omráčení: nic nedělá
	var dashing: bool = false     # Nájezd: jede k dash_to a srazí, koho potká
	var dash_to: Vector2
	var dash_hit: Array = []
	var glory_earned: float = 0.0
	var passives: Array = []      # klíče pasivek a přísah (units.json "passives")
	var base: Dictionary = {}     # data třídy, ze kterých se přepočítávají statistiky
	var oath_broken: bool = false
	var second_wind_used: bool = false
	var revive_used: bool = false # kněz: Poslední pomazání už použil
	var primed: bool = false      # jezdec: rozjetý výpad (Rozběh)
	var struck: Dictionary = {}   # asasín: na koho už udeřil (Ze stínu)
	var hidden_t: float = 0.0     # Úkryt: nikdo ho necílí
	var shield_t: float = 0.0     # Požehnaná zbroj: menší zranění
	var shield: float = 1.0
	var avenger: bool = false     # Mstitel: padl spojenec
	var target_id: String = ""    # nepřítel: na koho právě útočí
	var leader: bool = false      # vůdce nepřátel: když padne, zlomí se morálka
	var extra_used: int = 0       # kolikrát hrdina v bitvě použil schopnost navíc za slávu
	var ability_cd: float = 0.0   # nabíjení schopnosti (s), než jde použít znovu
	var kiting: bool = false      # lučištník právě couvá (couvá, dokud nemá odstup)
	var assisting: bool = false   # kněz pomáhá v boji (léčí dál, z dosahu léčení nemusí)
	var mounted: bool = false
	var vs_mounted: float = 1.0   # násobek poškození proti jízdě
	var ignores: Array = []       # druhy terénu, které jednotku nezpomalují ("les")
	var traits: Array = []        # vlastnosti (nepřátelé): klíče z units.json "traits"
	var route: Array[Vector2] = []
	var route_i: int = 0
	var hold: bool = false        # nepřítel drží pozici (rozkaz ze scénáře)
	var hold_engage: float = 4.0  # jak daleko od svého místa vyrazí na rytíře
	var hold_until: float = INF   # do kdy drží (pak postupuje jako ostatní)
	var on_break: String = ""     # jak reaguje na zlomenou morálku (nepřátelé)
	var desperate: bool = false
	var fleeing: bool = false
	var fled: bool = false        # utekl z bojiště (počítá se jako ztráta, ne jako padlý)

	func alive() -> bool:
		return hp > 0.0


class Projectile:
	extends RefCounted
	var id: int
	var pos: Vector2
	var target_id: String
	var from_id: String
	var dmg: float
	var done: bool = false


# --- data ---
var units_data: Dictionary
var house: Dictionary
var scenario: Dictionary
var river_lo: float
var river_hi: float
var crossings: Array = []   # [{x0, x1, kind, speed}] místa, kde jde řeku přejít
var forests: Array = []     # [{x0, x1, y0, y1, speed, path: [x0, x1]}]

# --- stav ---
var t: float = 0.0
var units: Array[Unit] = []
var projectiles: Array[Projectile] = []
var events: Array[Dictionary] = []
var glory: float = 0.0
var signals: int = 0
var signals_used: int = 0
var abilities_used: int = 0
var zones: Array = []          # hořící zem: [{pos, r, t, dps, from}]
var grudges: Dictionary = {}    # nepřátelé, kteří zranili hrdinu (Přísaha pomsty)
var task_ok: bool = true
var over: String = ""
var foes_broken: bool = false
var broken_t: float = -1.0         # kdy se zlomila morálka nepřítele
var decided: String = ""        # "k" / "e": strana, která má bitvu rozhodnutou ve svůj prospěch
var charging: bool = false      # hráč vydal povel Do boje! (jednorázový)
var _next_id: int = 0
var _rng := RandomNumberGenerator.new()


## setup = {"signals": int, "pos": {key: Vector2}, "routes": {key: Array[Vector2]} (nepovinné),
##          "passives": {key: [klíče pasivek]} (nepovinné, jinak výchozí pasivky rodu),
##          "glory": počáteční sláva (běh ji přenáší), "names": {key: jméno} (nástupci),
##          "extra_enemies": [řádky nepřátel navíc] (uprchlíci, kteří se vrátili)}
func _init(data: Dictionary, setup: Dictionary, rng_seed: int = -1) -> void:
	units_data = data["units"]
	house = data["house"]
	scenario = data["scenario"]
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	var river: Dictionary = scenario["river"]
	river_lo = river["y0"]
	river_hi = river["y1"]
	crossings = river["crossings"]
	forests = scenario.get("forests", [])
	glory = float(setup.get("glory", house["glory"]["start"]))
	signals = setup.get("signals", 1)
	task_ok = not scenario["optional_task"].has("kill")

	var knights_data: Dictionary = units_data["knights"]
	for key: String in knights_data:
		var u := _make_unit(key, SIDE_KNIGHT, knights_data[key])
		var p: Vector2 = setup["pos"][key]
		u.pos = p
		u.home = p
		u.face = Vector2(0, 1)
		units.append(u)
		var routes: Dictionary = setup.get("routes", {})
		if routes.has(key):
			_apply_route(u, routes[key])
		var pas: Dictionary = setup.get("passives", house.get("start_passives", {}))
		u.passives = (pas.get(key, []) as Array).duplicate()
		_apply_passives(u)
		var names: Dictionary = setup.get("names", {})
		if names.has(key):
			u.name = names[key]
		var hp_frac: Dictionary = setup.get("hp", {})
		if hp_frac.has(key):
			u.hp = u.maxhp * clampf(float(hp_frac[key]), 0.05, 1.0)   # zranění z minulé bitvy běhu

	var foes_data: Dictionary = units_data["foes"]
	var i := 0
	var rows: Array = (scenario["enemies"] as Array).duplicate()
	rows.append_array(setup.get("extra_enemies", []))
	for row: Array in rows:
		var fkey: String = row[0]
		var u := _make_unit(fkey, SIDE_FOE, foes_data[fkey])
		u.id = "e%d" % i
		for extra: Variant in row.slice(3):
			if extra is Array:
				for tr: String in extra:
					if not u.traits.has(tr):
						u.traits.append(tr)
			elif extra is Dictionary:
				var orders: Dictionary = extra
				u.hold = bool(orders.get("hold", false))
				u.hold_engage = float(orders.get("engage", u.hold_engage))
				u.hold_until = float(orders.get("hold_time", INF))
		u.pos = Vector2(row[1], row[2])
		u.home = u.pos
		u.face = Vector2(0, -1)
		u.t = _rng.randf() * 0.6
		units.append(u)
		i += 1


## scenario = klíč scénáře (soubor data/scenarios/<klíč>.json), nebo celá cesta k souboru.
static func load_data(scenario: String = DEFAULT_SCENARIO) -> Dictionary:
	var path := scenario if scenario.begins_with("res://") else "res://data/scenarios/%s.json" % scenario
	return {
		"units": _read_json("res://data/units.json"),
		"house": _read_json("res://data/rod_vlka.json"),
		"scenario": read_scenario(path),
	}


## Scénář; varianta s "base" převezme vše ze základního scénáře a přepíše jen svá pole.
static func read_scenario(path_or_key: String) -> Dictionary:
	var path := path_or_key if path_or_key.begins_with("res://") else "res://data/scenarios/%s.json" % path_or_key
	var sc := _read_json(path)
	if sc.has("base"):
		var base := read_scenario(String(sc["base"]))
		base.merge(sc, true)
		base.erase("base")
		return base
	return sc


## Seznam scénářů v pořadí pro výběr bitvy.
static func scenario_list() -> Array:
	return _read_json("res://data/scenarios/index.json").get("order", [DEFAULT_SCENARIO])


## Výchozí rozestavení ze scénáře.
static func default_setup(data: Dictionary, signal_count: int = 1) -> Dictionary:
	var pos := {}
	var routes := {}
	var deploy: Dictionary = data["scenario"]["deploy"]
	for key: String in deploy:
		var p: Array = deploy[key]["pos"]
		pos[key] = Vector2(p[0], p[1])
		if deploy[key].has("route"):
			var pts: Array[Vector2] = []
			for q: Array in deploy[key]["route"]:
				pts.append(Vector2(q[0], q[1]))
			routes[key] = pts
	var passives := {}
	var start: Dictionary = data["house"].get("start_passives", {})
	for key: String in start:
		passives[key] = (start[key] as Array).duplicate()
	return {"signals": signal_count, "pos": pos, "routes": routes, "passives": passives}


static func _read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Nelze načíst %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Neplatný JSON v %s" % path)
		return {}
	return parsed


func _make_unit(key: String, side: String, d: Dictionary) -> Unit:
	var u := Unit.new()
	u.id = key
	u.leader = d.get("leader", false)
	u.side = side
	u.key = key
	u.name = d["name"]
	u.role = d["role"]
	u.hp = d["hp"]
	u.maxhp = u.hp
	u.dmg = d["dmg"]
	u.reach = d["reach"]
	u.speed = d["speed"]
	u.cd = d["cd"]
	u.armor = d["armor"]
	u.radius = d["radius"]
	u.ranged = d.get("ranged", false)
	u.heal = d.get("heal", 0.0)
	u.heal_cd = d.get("heal_cd", 0.0)
	u.heal_range = d.get("heal_range", 0.0)
	u.palette_row = int(d.get("palette_row", 0))
	u.target_priority = d.get("target_priority", "")
	u.behavior = d.get("behavior", "")
	u.ability = d.get("ability", "")
	if u.ability != "":
		u.uses = int(units_data["abilities"][u.ability]["uses"])
	u.on_break = d.get("on_break", "")
	u.mounted = d.get("mounted", false)
	u.vs_mounted = d.get("dmg_vs_mounted", 1.0)
	u.ignores = d.get("ignores", [])
	u.traits = (d.get("traits", []) as Array).duplicate()
	u.color = Color.html(d.get("color", "#ffffff"))
	u.base = d
	return u


# =============================================================== dotazy

func knights() -> Array[Unit]:
	var out: Array[Unit] = []
	for u in units:
		if u.side == SIDE_KNIGHT:
			out.append(u)
	return out


func living(side: String) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in units:
		if u.side == side and u.alive():
			out.append(u)
	return out


func by_id(id: String) -> Unit:
	for u in units:
		if u.id == id:
			return u
	return null


func can_signal() -> bool:
	return over == "" and signals > 0


## Pasivka hrdiny (data), nebo prázdný slovník, když ji nemá. Zlomená přísaha neplatí.
func _pas(u: Unit, key: String) -> Dictionary:
	if u == null or not u.passives.has(key):
		return {}
	var d: Dictionary = units_data["passives"][key]
	if d.get("kind", "") == "oath" and u.oath_broken:
		return {}
	return d


func passives_of(id: String) -> Array:
	var u := by_id(id)
	return u.passives if u != null else []


## Pasivky, které hrdina může dostat (podle třídy).
func passives_for(id: String) -> Array:
	var u := by_id(id)
	var out: Array = []
	for k: String in units_data["passives"]:
		if k.begins_with("_"):
			continue
		var c: String = units_data["passives"][k].get("class", "any")
		if u != null and (c == "any" or c == u.key):
			out.append(k)
	return out


## Proč pasivku nejde přidat ("" = jde).
func passive_problem(id: String, key: String) -> String:
	var u := by_id(id)
	if u == null or not units_data["passives"].has(key):
		return "Neznámá pasivka."
	if t > 0.0:
		return "Pasivky se mění jen před bitvou."
	if not passives_for(id).has(key):
		return "Tahle pasivka není pro tuto třídu."
	if units_data["passives"][key].get("kind", "") == "oath":
		for k: String in u.passives:
			if k != key and units_data["passives"][k].get("kind", "") == "oath":
				return "%s už složil přísahu „%s“." % [u.name, units_data["passives"][k]["name"]]
	return ""


## Přidá nebo odebere pasivku (jen před bitvou). Vrací false, když to nejde.
func set_passive(id: String, key: String, on: bool) -> bool:
	var u := by_id(id)
	if u == null:
		return false
	if on:
		if passive_problem(id, key) != "" or u.passives.has(key):
			return false
		u.passives.append(key)
	else:
		if t > 0.0 or not u.passives.has(key):
			return false
		u.passives.erase(key)
	_apply_passives(u)
	return true


## Přepočítá statistiky hrdiny z dat třídy a pasivek (zdraví, léčení, rychlost útoku, použití).
func _apply_passives(u: Unit) -> void:
	var mult := {"hp": 1.0, "heal": 1.0, "cd": 1.0}
	var extra := 0
	for k: String in u.passives:
		var d: Dictionary = _pas(u, k)
		var sm: Dictionary = d.get("stat_mult", {})
		for f: String in sm:
			mult[f] = float(mult.get(f, 1.0)) * float(sm[f])
		extra += int(d.get("extra_uses", 0))
	u.maxhp = float(u.base["hp"]) * float(mult["hp"])
	u.hp = u.maxhp
	u.heal = float(u.base.get("heal", 0.0)) * float(mult["heal"])
	u.cd = float(u.base["cd"]) * float(mult["cd"])
	if u.ability != "":
		u.uses = int(ability_of(u.id).get("uses", 0)) + extra


## Přísaha, kterou hrdina právě drží (data). Prázdný slovník, když žádnou nemá nebo ji porušil.
func oath_of(id: String) -> Dictionary:
	var u := by_id(id)
	if u == null or u.oath_broken:
		return {}
	for k: String in u.passives:
		var d: Dictionary = units_data["passives"].get(k, {})
		if d.get("kind", "") == "oath":
			return d
	return {}


func has_oath(id: String) -> bool:
	return not oath_of(id).is_empty()


## Kolik přísah bylo v bitvě porušeno.
func oaths_broken() -> int:
	var n := 0
	for k in knights():
		if k.oath_broken:
			n += 1
	return n


func _no_retreat(u: Unit) -> bool:
	return bool(oath_of(u.id).get("no_retreat", false))


## Název výchozího chování pro hráče.
func behavior_name(id: String) -> String:
	var u := by_id(id)
	if u == null:
		return ""
	return units_data["behaviors"].get(u.behavior, {}).get("name", "")


func behavior_desc(id: String) -> String:
	var u := by_id(id)
	if u == null:
		return ""
	return units_data["behaviors"].get(u.behavior, {}).get("desc", "")


func _bparam(u: Unit, field: String, default: float) -> float:
	return float(units_data["behaviors"].get(u.behavior, {}).get(field, default))


func _dmg_mult(u: Unit, tg: Unit = null) -> float:
	if u.side != SIDE_KNIGHT:
		if not u.desperate:
			return 1.0
		return 1.0 + float(units_data["morale"]["desperate_dmg_bonus"]) + float(_trait_value(u, "desperate_dmg_bonus", 0.0))
	var m := 1.0
	m += float(oath_of(u.id).get("dmg_bonus", 0.0))
	if u.avenger:
		m += float(_pas(u, "mstitel").get("dmg_bonus", 0.0))
	if tg != null:
		if grudges.has(tg.id):
			m += float(_pas(u, "pomsta").get("vs_grudge", 0.0))
		if tg.ranged:
			m += float(_pas(u, "lovec").get("vs_ranged", 0.0))
	return m


func _taken_mult(u: Unit) -> float:
	var m := 1.0 - u.armor
	if u.side != SIDE_KNIGHT:
		return m
	if u.taunt_t > 0.0 and u.ability != "":
		m *= float(ability_of(u.id).get("damage_taken", 1.0))
	if u.shield_t > 0.0:
		m *= u.shield
	for k in living(SIDE_KNIGHT):
		var g := _pas(k, "ochrance")
		if k != u and not g.is_empty() and k.pos.distance_to(u.pos) <= float(g["guard_radius"]):
			m *= float(g["guard_taken"])
			break
	return m


func _speed(u: Unit) -> float:
	return u.speed


## Cíl z kandidátů: nejbližší, ale hrdina s target_priority dá přednost svému typu cíle.
func _choose_target(u: Unit, cand: Array[Unit]) -> Unit:
	if u.target_priority == "ranged":
		var pref: Array[Unit] = []
		for f in cand:
			if f.ranged:
				pref.append(f)
		if not pref.is_empty():
			return _nearest(pref, u.pos)
		var weakest: Unit = null
		for f in cand:
			if weakest == null or f.hp < weakest.hp:
				weakest = f
		return weakest
	return _nearest(cand, u.pos)


func _nearest(list: Array[Unit], from: Vector2) -> Unit:
	var best: Unit = null
	var bd := INF
	for e in list:
		var d := from.distance_to(e.pos)
		if d < bd:
			bd = d
			best = e
	return best


## Střed oddílu (průměr pozic živých hrdinů, volitelně bez jednoho).
func _group_center(exclude: Unit = null) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	var roamers := Vector2.ZERO
	var nr := 0
	for k in living(SIDE_KNIGHT):
		if k == exclude:
			continue
		if _bparam(k, "roams", 0.0) > 0.0:
			roamers += k.pos   # kdo se toulá (asasín), netáhne oddíl za sebou
			nr += 1
			continue
		sum += k.pos
		n += 1
	if n > 0:
		return sum / n
	if nr > 0:
		return roamers / nr
	return exclude.pos if exclude != null else Vector2.ZERO


## Nejbližší jiný hrdina, který v posledních chvílích bojoval (útočil nebo dostal zásah).
func _engaged_ally(u: Unit) -> Unit:
	var window := float(units_data["behaviors"]["_common"]["help_window"])
	var list: Array[Unit] = []
	for k in living(SIDE_KNIGHT):
		# za tím, kdo se toulá sám (asasín), oddíl nechodí: táhl by ho přes řeku do přesily
		if k != u and t - k.combat_t <= window and _bparam(k, "roams", 0.0) <= 0.0:
			list.append(k)
	return _nearest(list, u.pos)


# =============================================================== schopnosti

## Schopnost hrdiny včetně úprav z pasivek (ability_mod).
func ability_of(id: String) -> Dictionary:
	var u := by_id(id)
	if u == null or u.ability == "":
		return {}
	var a: Dictionary = (units_data["abilities"][u.ability] as Dictionary).duplicate()
	for k: String in u.passives:
		a.merge(_pas(u, k).get("ability_mod", {}), true)
	return a


## Kolik slávy stojí použití teď (0 = má vlastní použití).
func ability_cost(id: String) -> float:
	var u := by_id(id)
	if u == null or u.uses > 0:
		return 0.0
	return float(house["glory"]["extra_use_cost"])


## Kolik použití navíc za slávu hrdinovi v této bitvě zbývá.
func extra_uses_left(id: String) -> int:
	var u := by_id(id)
	if u == null:
		return 0
	return maxi(0, int(house["glory"].get("extra_uses_max", 1)) - u.extra_used)


## Proč schopnost teď nejde použít ("" = jde). Pro nápovědu v UI.
func ability_problem(id: String) -> String:
	var u := by_id(id)
	if u == null or not u.alive() or u.ability == "":
		return "Hrdina nemá schopnost."
	if u.ability_cd > 0.0:
		return "Schopnost se nabíjí (%d s)." % ceili(u.ability_cd)
	if u.uses > 0:
		return ""
	if extra_uses_left(id) <= 0:
		return "Schopnost je pro tuto bitvu vyčerpaná."
	if glory < ability_cost(id):
		return "Chybí sláva (%d)." % int(ability_cost(id))
	return ""


## Jde schopnost použít (bez ohledu na cíl)?
func can_use_ability(id: String) -> bool:
	var u := by_id(id)
	if u == null or u.side != SIDE_KNIGHT or not u.alive() or u.ability == "" or over != "" or u.dashing:
		return false
	if u.ability_cd > 0.0:
		return false
	return u.uses > 0 or (extra_uses_left(id) > 0 and glory >= ability_cost(id))


## Druh cíle schopnosti: "none", "point" (místo na zemi), "enemy" (nepřítel).
func ability_target(id: String) -> String:
	return String(ability_of(id).get("target", "none"))


## Proč tenhle cíl nejde ("" = jde).
func ability_target_problem(id: String, target: Variant) -> String:
	var u := by_id(id)
	var a := ability_of(id)
	match String(a.get("target", "none")):
		"point":
			if not target is Vector2:
				return "Vyber místo."
			var p: Vector2 = target
			if u.pos.distance_to(p) > float(a.get("range", INF)):
				return "Moc daleko (nejvýš %d m)." % int(a["range"])
			if a.get("land", false) and _in_water(p):
				return "Do vody to nejde."
		"enemy":
			var e := by_id(String(target)) if target is String else null
			if e == null or e.side != SIDE_FOE or not e.alive():
				return "Vyber nepřítele."
			if u.pos.distance_to(e.pos) > float(a.get("range", INF)):
				return "Moc daleko (nejvýš %d m)." % int(a["range"])
	return ""


## Kdy by schopnost dávala smysl a na co (jednoduchá rada; používají ji testy a automatické hraní).
## Vrací [ano/ne, cíl].
func ability_hint(id: String) -> Array:
	var u := by_id(id)
	if not can_use_ability(id):
		return [false, null]
	var a := ability_of(id)
	var foes := living(SIDE_FOE)
	match u.ability:
		"vyzva":
			var n := 0
			for f in foes:
				if f.pos.distance_to(u.pos) <= float(a["radius"]):
					n += 1
			return [n >= 2, null]
		"pozehnani":
			var hurt := 0
			for k in living(SIDE_KNIGHT):
				if k.pos.distance_to(u.pos) <= float(a["radius"]) and k.hp < k.maxhp * 0.6:
					hurt += 1
			return [hurt >= 2, null]
		"salva", "najezd":
			var best: Unit = null
			var best_n := 0
			for f in foes:
				if f.pos.distance_to(u.pos) > float(a["range"]) or (a.get("land", false) and _in_water(f.pos)):
					continue
				var n := 0
				for g in foes:
					if g.pos.distance_to(f.pos) <= 2.0:
						n += 1
				if n > best_n:
					best_n = n
					best = f
			var need := 3 if u.ability == "salva" else 2
			return [best != null and best_n >= need, best.pos if best != null else null]
		"uder":
			var pick: Unit = null
			for f in foes:
				if f.pos.distance_to(u.pos) <= float(a["range"]) and (f.ranged or f.hp < f.maxhp * 0.4):
					pick = f
					break
			return [pick != null, pick.id if pick != null else null]
	return [false, null]


## Použije schopnost hrdiny. Bez vlastních použití zaplatí slávou. Vrací false, když to nejde.
func use_ability(id: String, target: Variant = null) -> bool:
	if not can_use_ability(id) or ability_target_problem(id, target) != "":
		return false
	var u := by_id(id)
	var a := ability_of(id)
	if u.uses > 0:
		u.uses -= 1
	else:
		glory -= ability_cost(id)
		u.extra_used += 1
	u.ability_cd = float(a.get("cooldown", 0.0))
	abilities_used += 1
	var where: Vector2 = u.pos
	match u.ability:
		"vyzva":
			u.taunt_t = float(a["duration"])
		"pozehnani":
			for k in living(SIDE_KNIGHT):
				if k.pos.distance_to(u.pos) <= float(a["radius"]):
					k.hp = minf(k.maxhp, k.hp + k.maxhp * float(a["heal_frac"]))
					if a.has("shield_t"):
						k.shield_t = float(a["shield_t"])
						k.shield = float(a["shield"])
					events.append({"type": "heal", "id": k.id})
		"salva":
			where = target
			var hits: Array[Unit] = []
			for f in living(SIDE_FOE):
				if f.pos.distance_to(where) <= float(a["radius"]):
					hits.append(f)
			for i in int(a["arrows"]):
				if hits.is_empty():
					break
				var f: Unit = hits[_rng.randi() % hits.size()]
				_hurt(u, f, float(a["dmg"]) * _dmg_mult(u, f) * (u.vs_mounted if f.mounted else 1.0))
				if not f.alive():
					hits.erase(f)
			if a.has("fire_t"):
				zones.append({"pos": where, "r": float(a["radius"]), "t": float(a["fire_t"]), "dps": float(a["fire_dps"]), "from": u.id})
		"najezd":
			where = target
			u.dashing = true
			u.dash_to = target
			u.dash_hit.clear()
			u.route_i = u.route.size()
		"uder":
			var e := by_id(String(target))
			var dir := (e.pos - u.pos).normalized()
			var behind := e.pos + dir * (e.radius + u.radius)
			if not _in_water(behind):
				u.pos = behind
			where = e.pos
			_face_to(u, e)
			u.atk = 0.25
			u.combat_t = t
			_hurt(u, e, u.dmg * float(a["mult"]) * _dmg_mult(u, e))
			if not _pas(u, "ukryt").is_empty():
				u.hidden_t = float(_pas(u, "ukryt")["hidden_t"])
	events.append({"type": "ability", "id": u.id, "key": u.ability, "pos": where})
	_log("%s: %s" % [u.name, a["name"]], true)
	return true


# =============================================================== příkazy hráče

func use_signal() -> bool:
	if not can_signal():
		return false
	signals -= 1
	signals_used += 1
	_log("Signál: čas stojí", true)
	return true


# --------------------------------------------------------------- trasy

## Zjednoduší nakreslenou čáru na nejvýš max_pts bodů (Ramer–Douglas–Peucker, zvětšuje toleranci).
static func simplify_route(points: Array, max_pts: int = 4) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for p: Vector2 in points:
		if pts.is_empty() or pts[-1].distance_to(p) > 0.05:
			pts.append(p)
	if pts.size() <= max_pts:
		return pts
	var eps := 0.25
	var out: Array[Vector2] = pts
	while out.size() > max_pts:
		out = _rdp(pts, eps)
		eps *= 1.5
	return out


static func _rdp(pts: Array[Vector2], eps: float) -> Array[Vector2]:
	if pts.size() < 3:
		return pts.duplicate()
	var a := pts[0]
	var b := pts[-1]
	var best := -1.0
	var idx := 0
	for i in range(1, pts.size() - 1):
		var d := _seg_dist(pts[i], a, b)
		if d > best:
			best = d
			idx = i
	var res: Array[Vector2] = []
	if best <= eps:
		res.append(a)
		res.append(b)
		return res
	var left := _rdp(pts.slice(0, idx + 1), eps)
	var right := _rdp(pts.slice(idx), eps)
	res.append_array(left)
	res.pop_back()
	res.append_array(right)
	return res


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Proč trasu nejde nastavit ("" = jde). Body ve vodě se zahazují, ne zamítají.
func route_problem(id: String, points: Array) -> String:
	var u := by_id(id)
	if u == null or u.side != SIDE_KNIGHT or not u.alive():
		return "Neznámý rytíř."
	if t > 0.0:
		return "Trasa se určuje před bitvou."
	if _no_retreat(u):
		var front := u.pos.y
		for p: Vector2 in points:
			if p.y < front - 1.0:
				return "Trasa vede zpět a %s složil přísahu „%s“." % [u.name, oath_of(id).get("name", "")]
			front = maxf(front, p.y)
	return ""


## Nastaví trasu rytíře (jen v rozestavení). Prázdný seznam trasu smaže. Vrací false, když to nejde.
func set_route(id: String, points: Array) -> bool:
	if route_problem(id, points) != "":
		return false
	_apply_route(by_id(id), points)
	return true


func _apply_route(u: Unit, points: Array) -> void:
	u.route.clear()
	u.route_i = 0
	for p: Vector2 in points:
		if not _in_water(p) and u.route.size() < 4:
			u.route.append(p)


func on_route(u: Unit) -> bool:
	return u.route_i < u.route.size() and decided == "" and not charging


func has_trait(u: Unit, key: String) -> bool:
	return u.traits.has(key)


func _trait_value(u: Unit, field: String, default: Variant) -> Variant:
	var all: Dictionary = units_data.get("traits", {})
	for k: String in u.traits:
		var tr: Dictionary = all.get(k, {})
		if tr.has(field):
			return tr[field]
	return default


## Povel Do boje!: jednorázový, jen když je morálka nepřítele zlomená. Všichni hrdinové útočí.
func can_charge() -> bool:
	return over == "" and foes_broken and not charging


func charge_all() -> bool:
	if not can_charge():
		return false
	charging = true
	_log("Do boje! Všichni hrdinové dobojují", true)
	return true


## Rozkaz přesunu (při signálu): hrdina dojde na místo a drží ho, dokud nepřijde Do boje! nebo jiný rozkaz.
func order_move(id: String, target: Vector2) -> bool:
	var u := by_id(id)
	if u == null or not u.alive():
		return false
	if order_problem(id) != "":
		return false
	u.home = target
	u.holding = true
	u.route_i = u.route.size()   # rozkaz přesunu ruší zbytek trasy
	_log("%s: nová pozice" % u.name, false)
	return true


## Proč hrdina neposlechne rozkaz přesunu ("" = poslechne). Přísaha pomsty: dokud žije, kdo zranil spojence.
func order_problem(id: String) -> String:
	var u := by_id(id)
	if bool(oath_of(id).get("ignores_orders", false)):
		for f in living(SIDE_FOE):
			if grudges.has(f.id):
				return "%s drží přísahu pomsty a rozkaz neposlechne." % u.name
	return ""


## Zruší rozkaz přesunu: hrdina se vrátí k výchozímu chování své třídy.
func release(id: String) -> void:
	var u := by_id(id)
	if u != null:
		u.holding = false


## Je rozkaz pro hrdinu ústupem? (vzdálí ho od nejbližšího nepřítele o víc než 1 m)
func is_retreat(id: String, target: Vector2) -> bool:
	var u := by_id(id)
	var foe := _nearest(living(SIDE_FOE), u.pos)
	if foe == null:
		return false
	return target.distance_to(foe.pos) > u.pos.distance_to(foe.pos) + 1.0


func break_oath(id: String) -> void:
	var u := by_id(id)
	var o := oath_of(id)
	if u == null or o.is_empty():
		return
	u.oath_broken = true
	glory = maxf(0.0, glory - float(o.get("break_glory_cost", 0.0)))
	_apply_passives_keep_hp(u)
	_log("%s porušil přísahu %s" % [u.name, o["name"]], true)


## Přepočet statistik uprostřed bitvy (zachová podíl zdraví a zbývající použití).
func _apply_passives_keep_hp(u: Unit) -> void:
	var frac := u.hp / maxf(u.maxhp, 0.001)
	var uses := u.uses
	_apply_passives(u)
	u.hp = u.maxhp * frac
	u.uses = mini(uses, u.uses)


# =============================================================== simulace

func _log(text: String, hot: bool) -> void:
	events.append({"type": "log", "t": t, "text": text, "hot": hot})


func _gain_glory(v: float, who: Unit = null) -> void:
	if who != null and bool(oath_of(who.id).get("no_glory", false)):
		return
	var before := glory
	glory = minf(float(house["glory"]["max"]), glory + v)
	if who != null:
		who.glory_earned += glory - before


## Přechod přes řeku, ve kterém x leží (nebo prázdný slovník).
func _crossing_at(x: float) -> Dictionary:
	for c: Dictionary in crossings:
		if x >= float(c["x0"]) and x <= float(c["x1"]):
			return c
	return {}


## Nejvýhodnější přechod pro cestu z x_from do x_to.
func _best_crossing(x_from: float, x_to: float) -> Dictionary:
	var best: Dictionary = {}
	var bd := INF
	for c: Dictionary in crossings:
		var cx := (float(c["x0"]) + float(c["x1"])) / 2.0
		var d := absf(x_from - cx) + absf(x_to - cx)
		if d < bd:
			bd = d
			best = c
	return best


## Násobek rychlosti podle terénu (brod, les; stezka lesem nezpomaluje).
func terrain_speed(u: Unit, p: Vector2) -> float:
	if p.y >= river_lo and p.y <= river_hi:
		var c := _crossing_at(p.x)
		if not c.is_empty():
			return float(c.get("speed", 1.0))
	for f: Dictionary in forests:
		if p.x >= float(f["x0"]) and p.x <= float(f["x1"]) and p.y >= float(f["y0"]) and p.y <= float(f["y1"]):
			var path: Array = f.get("path", [])
			if path.size() == 2 and p.x >= float(path[0]) and p.x <= float(path[1]):
				return 1.0
			if u.ignores.has("les"):
				return 1.0
			return float(f.get("speed", 1.0))
	return 1.0


func _band(y: float) -> int:
	if y < river_lo:
		return 0
	if y > river_hi:
		return 2
	return 1


func _in_water(p: Vector2) -> bool:
	return p.y > river_lo - 0.3 and p.y < river_hi + 0.3 and _crossing_at(p.x).is_empty()


## Kam jít, aby se jednotka dostala k cíli přes řeku (nejvýhodnějším přechodem).
func _nav(u: Unit, target: Vector2) -> Vector2:
	var us := _band(u.pos.y)
	var ts := _band(target.y)
	var here := _crossing_at(u.pos.x)
	if us == ts or (us == 1 and not here.is_empty()):
		if us == 1 and ts != 1:
			return Vector2(clampf(u.pos.x, float(here["x0"]) + 0.35, float(here["x1"]) - 0.35), river_lo - 0.5 if ts == 0 else river_hi + 0.5)
		return target
	var c := _best_crossing(u.pos.x, target.x)
	var x0 := float(c["x0"]) + 0.35
	var x1 := float(c["x1"]) - 0.35
	if u.pos.x >= x0 - 0.1 and u.pos.x <= x1 + 0.1 and u.pos.y >= river_lo - 0.7 and u.pos.y <= river_hi + 0.7:
		return Vector2(clampf(u.pos.x, x0, x1), river_hi + 0.5 if us == 0 else river_lo - 0.5)
	return Vector2(clampf(u.pos.x, x0, x1), river_lo - 0.6 if us == 0 else river_hi + 0.6)


func _walk(u: Unit, target: Vector2, dt: float, stop: float = 0.0) -> void:
	var w := _nav(u, target)
	var dv := w - u.pos
	var d := dv.length()
	if d < 0.000001 or (d <= maxf(stop, 0.05) and w == target):
		u.moving = false
		return
	var st := minf(d, _speed(u) * terrain_speed(u, u.pos) * dt)
	var old := u.pos
	var step_v := dv / d * st
	u.pos += step_v
	u.face = dv / d
	u.moving = true
	if _in_water(u.pos):
		# u břehu se nezasekne: zkusí sklouznout podél břehu (jen po x, nebo jen po y)
		u.pos = old + Vector2(step_v.x, 0.0)
		if _in_water(u.pos):
			u.pos = old + Vector2(0.0, step_v.y)
			if _in_water(u.pos):
				u.pos = old + Vector2(0.0, -absf(step_v.x) if old.y < river_lo else absf(step_v.x))
				if _in_water(u.pos):
					u.pos = old


func _face_to(u: Unit, tg: Unit) -> void:
	var v := tg.pos - u.pos
	if v.length() > 0.0001:
		u.face = v.normalized()


func _attack(u: Unit, tg: Unit) -> void:
	_face_to(u, tg)
	u.combat_t = t
	if u.t > 0.0:
		return
	u.t = u.cd
	u.atk = 0.25
	if u.ranged:
		var p := Projectile.new()
		p.id = _next_id
		_next_id += 1
		p.pos = u.pos
		p.target_id = tg.id
		p.from_id = u.id
		p.dmg = u.dmg * _dmg_mult(u, tg) * (u.vs_mounted if tg.mounted else 1.0)
		projectiles.append(p)
		events.append({"type": "shoot", "id": u.id})
	else:
		var m := _dmg_mult(u, tg) * (u.vs_mounted if tg.mounted else 1.0)
		if u.primed:
			u.primed = false
			m *= float(_pas(u, "rozbeh").get("mult", 1.0))
		var zs := _pas(u, "ze_stinu")
		if not zs.is_empty() and tg.side == SIDE_FOE and tg.target_id != u.id and not u.struck.has(tg.id):
			u.struck[tg.id] = true
			m *= float(zs["mult"])
		_hurt(u, tg, u.dmg * m)


## glory_hit = false: zranění, které slávu za zásah nedává (oheň a jiné trvalé efekty).
func _hurt(att: Unit, tg: Unit, raw: float, glory_hit: bool = true) -> void:
	if not tg.alive():
		return
	tg.hp -= raw * _taken_mult(tg)
	tg.hit = 0.18
	tg.combat_t = t
	if tg.side == SIDE_KNIGHT and att != null and att.side == SIDE_FOE:
		grudges[att.id] = true
	var sw := _pas(tg, "druhy_dech")
	if tg.side == SIDE_KNIGHT and tg.hp > 0.0 and not sw.is_empty() and not tg.second_wind_used and tg.hp < tg.maxhp * float(sw["at"]):
		tg.second_wind_used = true
		tg.hp = minf(tg.maxhp, tg.hp + tg.maxhp * float(sw["heal_frac"]))
		events.append({"type": "heal", "id": tg.id})
		_log("%s: Druhý dech" % tg.name, false)
	if att != null and att.side == SIDE_KNIGHT and glory_hit:
		_gain_glory(float(house["glory"]["per_hit"]), att)
	if tg.hp > 0.0:
		return
	tg.hp = 0.0
	events.append({"type": "death", "id": tg.id})
	if tg.side == SIDE_FOE:
		if att != null and att.side == SIDE_KNIGHT:
			_gain_glory(float(house["glory"]["per_kill"]), att)
		if tg.key == str(scenario["optional_task"].get("kill", "")):
			task_ok = true
		if tg.leader:
			_log("%s padl!" % tg.name, true)
			_break_morale()
		return
	# Poslední pomazání: kněz poblíž jednou za bitvu zvedne padlého
	for k in living(SIDE_KNIGHT):
		var pp := _pas(k, "posledni_pomazani")
		if k != tg and not pp.is_empty() and not k.revive_used and k.pos.distance_to(tg.pos) <= float(pp["radius"]):
			k.revive_used = true
			tg.hp = tg.maxhp * float(pp["revive_frac"])
			events.erase(events[-1])
			events.append({"type": "heal", "id": tg.id})
			_log("%s zvedl padlého: %s" % [k.name, tg.name], true)
			return
	_log("%s padl" % tg.name, true)
	for k in living(SIDE_KNIGHT):
		if not _pas(k, "mstitel").is_empty():
			k.avenger = true
	var protect: String = scenario["optional_task"].get("protect", "")
	if tg.id == protect or protect == "all":
		task_ok = false


## Útok na cíl, nebo k němu dojít (stop = jak blízko).
func _engage(u: Unit, tg: Unit, dt: float) -> void:
	if u.side == SIDE_FOE:
		u.target_id = tg.id
	if u.pos.distance_to(tg.pos) <= u.reach + tg.radius * 0.5:
		u.moving = false
		_attack(u, tg)
	else:
		if u.pos.distance_to(tg.pos) > 3.0 and not _pas(u, "rozbeh").is_empty():
			u.primed = true
		_walk(u, tg.pos, dt, u.reach * 0.8)


## Dojít na místo; rytíř s přísahou Nikdy neustoupí nejde tam, kde by byl dál od nepřítele.
## Klidové místo (za oddílem, vedle oddílu…): kdo stojí a je blízko, zůstane stát.
## Rozejde se, až se místo vzdálí o víc než `settle` m. Bez toho hrdinové kmitají
## (krok, stop, krok), protože se jejich místa počítají jeden od druhého.
func _settle(u: Unit, p: Vector2, dt: float, stop: float, foes: Array[Unit]) -> void:
	if not u.moving and u.pos.distance_to(p) <= stop + _bparam(u, "settle", 1.2):
		return
	_go(u, p, dt, stop, foes)


func _go(u: Unit, p: Vector2, dt: float, stop: float, foes: Array[Unit]) -> void:
	if u.pos.distance_to(p) <= stop:
		u.moving = false
		return
	if _no_retreat(u):
		var f := _nearest(foes, u.pos)
		if f != null and p.distance_to(f.pos) > u.pos.distance_to(f.pos) + 0.3:
			u.moving = false
			return
	_walk(u, p, dt, stop)


func _knight_think(u: Unit, dt: float) -> void:
	var foes := living(SIDE_FOE)
	if foes.is_empty():
		u.moving = false
		return

	# kněz léčí nejzraněnějšího hrdinu v dosahu
	if u.heal > 0.0:
		u.heal_t -= dt
		if u.heal_t <= 0.0:
			var best: Unit = null
			for k in living(SIDE_KNIGHT):
				if k.hp < k.maxhp * 0.85 and k.pos.distance_to(u.pos) <= u.heal_range:
					if best == null or k.hp / k.maxhp < best.hp / best.maxhp:
						best = k
			if best != null:
				best.hp = minf(best.maxhp, best.hp + u.heal)
				u.heal_t = u.heal_cd
				events.append({"type": "heal", "id": best.id})

	if u.dashing:
		_dash(u, dt, foes)
		return

	# Trasa: hrdina jde po bodech trasy, cestou bojuje jen s tím, kdo je těsně u něj.
	if on_route(u):
		var close: Array[Unit] = []
		var close_r := u.reach if u.ranged else u.reach + 1.0
		for f in foes:
			if f.pos.distance_to(u.pos) <= close_r:
				close.append(f)
		var ct := _choose_target(u, close)
		if ct != null:
			_engage(u, ct, dt)
			return
		var wp := u.route[u.route_i]
		if u.pos.distance_to(wp) > 0.5:
			_walk(u, wp, dt, 0.3)
			if u.moving:
				return
		u.route_i += 1
		u.home = u.pos
		if u.route_i < u.route.size():
			return

	if has_oath(u.id):
		var nf := _nearest(foes, u.pos)
		if nf != null and u.pos.distance_to(nf.pos) <= u.reach + 0.3:
			_gain_glory(float(house["glory"]["oath_per_second"]) * dt, u)

	# Do boje! nebo rozhodnutá bitva: všichni útočí na nejbližšího.
	if charging or decided != "":
		_engage(u, _choose_target(u, foes), dt)
		return

	if u.holding:
		_hold_place(u, dt, foes)
		return

	match u.behavior:
		"frontline":
			_think_frontline(u, dt, foes)
		"healer":
			_think_healer(u, dt, foes)
		"archer":
			_think_archer(u, dt, foes)
		"rider":
			_think_rider(u, dt, foes)
		"assassin":
			_engage(u, _choose_target(u, foes), dt)
		_:
			_engage(u, _nearest(foes, u.pos), dt)


## Rozkaz přesunu: drží místo, bojuje s tím, kdo přijde blízko (střelec střílí na dostřel).
func _hold_place(u: Unit, dt: float, foes: Array[Unit]) -> void:
	var cand: Array[Unit] = []
	for f in foes:
		if (u.ranged and f.pos.distance_to(u.pos) <= u.reach) or (not u.ranged and f.pos.distance_to(u.home) <= u.reach + 3.0):
			cand.append(f)
	var tg := _choose_target(u, cand)
	if tg != null:
		if u.ranged or u.pos.distance_to(tg.pos) <= u.reach + tg.radius * 0.5:
			if u.pos.distance_to(tg.pos) <= u.reach + tg.radius * 0.5:
				u.moving = false
				_attack(u, tg)
				return
		var dv := tg.pos - u.home
		var d := maxf(dv.length(), 0.0001)
		_walk(u, u.home + dv / d * minf(d, 1.5), dt, 0.1)
		return
	_go(u, u.home, dt, 0.25, foes)


## Tank: drží přední linii. Napadne nepřítele u sebe nebo u spojence, jinak stojí kus před oddílem.
func _think_frontline(u: Unit, dt: float, foes: Array[Unit]) -> void:
	var engage := _bparam(u, "engage", 4.5)
	var guard := _bparam(u, "guard", 3.0)
	var cand: Array[Unit] = []
	for f in foes:
		var near_ally := false
		for k in living(SIDE_KNIGHT):
			if k != u and f.pos.distance_to(k.pos) <= guard:
				near_ally = true
				break
		if f.pos.distance_to(u.pos) <= engage or near_ally:
			cand.append(f)
	var tg := _nearest(cand, u.pos)
	if tg != null:
		if _no_retreat(u) and u.pos.distance_to(tg.pos) > u.reach + 1.0 and tg.pos.y < u.pos.y - 1.0:
			u.moving = false   # přísaha: za nepřítelem dozadu nejde
			return
		_engage(u, tg, dt)
		return
	var nf := _nearest(foes, u.pos)
	var c := _group_center(u)
	var spot := c + (nf.pos - c).normalized() * _bparam(u, "ahead", 1.5)
	if _no_retreat(u):
		u.moving = false   # Stát pevně: bez nepřítele stojí, kde je
		return
	_settle(u, spot, dt, 0.6, foes)


## Kněz: drží se kousek za tím, kdo bojuje (léčí ho), jinak za středem oddílu.
func _think_healer(u: Unit, dt: float, foes: Array[Unit]) -> void:
	var behind := _bparam(u, "behind", 2.0)
	var close := _nearest(foes, u.pos)
	if close != null and u.pos.distance_to(close.pos) <= maxf(u.reach + 0.5, _bparam(u, "defend", 0.0)):
		_engage(u, close, dt)   # nepřítel u kněze: brání se (a pomáhá tomu, koho léčí)
		return
	var mate := _engaged_ally(u)
	var anchor: Vector2
	var alone := living(SIDE_KNIGHT).size() == 1
	if close != null and (alone or (u.pos.distance_to(close.pos) <= 3.0 and (mate == null or mate.ranged))):
		_engage(u, close, dt)   # nemá se za kým schovat (nebo zbyl sám): brání se
		return
	if mate != null:
		var fn := _nearest(foes, mate.pos)
		# nikdo v dosahu léčení nepotřebuje: kněz nestojí, pomůže tomu, kdo bojuje.
		# Léčí dál (léčení je v dosahu i z boje); couvne, až je sám zraněný pod polovinu.
		if u.hp < u.maxhp * 0.5:
			u.assisting = false
		elif _bparam(u, "assist", 0.0) > 0.0 and not _needs_heal(u):
			u.assisting = true
		if u.assisting and fn.pos.distance_to(mate.pos) <= mate.reach + 1.5:
			_engage(u, fn, dt)
			return
		anchor = mate.pos + (mate.pos - fn.pos).normalized() * behind
		if _in_water(anchor):
			# za bojujícím je voda (boj na mostě, u brodu): jde k němu přes přechod
			_go(u, mate.pos, dt, behind, foes)
			return
		_settle(u, anchor, dt, 0.5, foes)
		return
	var c := _group_center(u)
	anchor = c + (c - close.pos).normalized() * behind
	if _in_water(anchor):
		anchor = u.pos
	_settle(u, anchor, dt, 0.8, foes)


## Potřebuje někdo v dosahu kněze léčení?
func _needs_heal(u: Unit) -> bool:
	for k in living(SIDE_KNIGHT):
		if k.hp < k.maxhp * 0.85 and k.pos.distance_to(u.pos) <= u.heal_range + 2.0:
			return true
	return false


## Lučištník: střílí na dostřel; když se nepřítel přiblíží, couvne; jinak se drží za oddílem
## a když nemá na koho střílet, přiblíží se k tomu, kdo bojuje.
func _think_archer(u: Unit, dt: float, foes: Array[Unit]) -> void:
	var close := _nearest(foes, u.pos)
	var kite := _bparam(u, "kite", 3.0)
	# couvá jen tehdy, když má za kým se schovat (spojenec, který bojuje zblízka, do 6 m)
	var cover := false
	for k in living(SIDE_KNIGHT):
		if k != u and not k.ranged and k.behavior != "healer" and k.pos.distance_to(u.pos) <= 6.0:
			cover = true
			break
	# couvá, dokud nemá odstup kite + kite_gap (jinak by kmital: krok, výstřel, krok)
	if close == null or not cover or u.pos.distance_to(close.pos) >= kite + _bparam(u, "kite_gap", 1.5):
		u.kiting = false
	elif u.pos.distance_to(close.pos) < kite:
		u.kiting = true
	if u.kiting and not _no_retreat(u):
		var away := u.pos + (u.pos - close.pos).normalized() * _bparam(u, "kite_step", 4.0)
		# necouvá donekonečna: nejdál pár metrů za místo, kde začínal
		if not _in_water(away) and away.y >= u.home.y - _bparam(u, "kite_limit", 6.0):
			_walk(u, away, dt, 0.2)
			if u.moving:
				return
		u.kiting = false
	var cand: Array[Unit] = []
	for f in foes:
		if f.pos.distance_to(u.pos) <= u.reach:
			cand.append(f)
	var tg := _choose_target(u, cand)
	if tg != null:
		u.moving = false
		_attack(u, tg)
		return
	var mate := _engaged_ally(u)
	if mate != null:
		_settle(u, mate.pos, dt, u.reach * 0.8, foes)
		return
	if living(SIDE_KNIGHT).size() == 1:
		_go(u, close.pos, dt, u.reach * 0.9, foes)   # zbyl sám: neutíká donekonečna, jde střílet
		return
	var c := _group_center(u)
	var spot := c + (c - close.pos).normalized() * _bparam(u, "behind", 2.0)
	if _in_water(spot):
		spot = u.pos
	_settle(u, spot, dt, 0.8, foes)


## Jezdec: na nepřítele do `engage` m od oddílu vyrazí, udeří a vrátí se k oddílu.
func _think_rider(u: Unit, dt: float, foes: Array[Unit]) -> void:
	var c := _group_center(u)
	var cand: Array[Unit] = []
	for f in foes:
		if f.pos.distance_to(c) <= _bparam(u, "engage", 7.0):
			cand.append(f)
	var tg := _nearest(cand, u.pos)
	if tg != null:
		_engage(u, tg, dt)
		return
	var nf := _nearest(foes, c)
	var side := 1.0 if u.home.x >= c.x else -1.0
	var spot := c + Vector2(side * 2.0, 0.0) + (nf.pos - c).normalized() * 0.5
	if _in_water(spot):
		spot = u.pos
	_settle(u, spot, dt, 1.0, foes)


## Nájezd: jede rychle k cíli, každého nepřítele v cestě zasáhne a omráčí.
func _dash(u: Unit, dt: float, foes: Array[Unit]) -> void:
	var a := ability_of(u.id)
	var dv := u.dash_to - u.pos
	var d := dv.length()
	var st := minf(d, u.speed * float(a["speed_mult"]) * dt)
	var next := u.pos + (dv / maxf(d, 0.0001)) * st
	if d < 0.2 or _in_water(next):
		u.dashing = false
		u.moving = false
		return
	u.pos = next
	u.face = dv / d
	u.moving = true
	for f in foes:
		if not u.dash_hit.has(f.id) and f.pos.distance_to(u.pos) <= float(a["width"]) + f.radius:
			u.dash_hit.append(f.id)
			f.stun_t = float(a["stun"])
			_hurt(u, f, float(a["dmg"]) * _dmg_mult(u, f))


func _foe_think(u: Unit, dt: float) -> void:
	if u.fleeing:
		var edge := Vector2(u.pos.x, float(_enemy_morale()["flee_y"]))
		_walk(u, edge, dt, 0.0)
		if u.pos.y >= edge.y - 0.2:
			u.fled = true
			u.hp = 0.0
			u.moving = false
			events.append({"type": "fled", "id": u.id})
		return
	if u.stun_t > 0.0:
		u.moving = false
		return
	var ks := _visible_knights()
	if ks.is_empty():
		u.moving = false
		return
	# Výzva: kdo je v dosahu tanka s výzvou, útočí na něj
	var taunter := _taunter_for(u, ks)
	if taunter != null:
		u.hold = false
		if u.ranged:
			_foe_shoot_or_walk(u, taunter, dt)
		else:
			_engage(u, taunter, dt)
		return
	if u.hold:
		# Pěšák, kterého něco zasáhlo, opustí pozici a s ním celá jeho skupina (do 5 m);
		# vypršení času nebo zlomení morálky uvolní všechny.
		if t >= u.hold_until or u.desperate:
			u.hold = false
		elif not u.ranged and u.hp < u.maxhp:
			for f in living(SIDE_FOE):
				if f.hold and not f.ranged and f.home.distance_to(u.home) <= 5.0:
					f.hold = false
		if u.hold:
			_foe_hold(u, ks, dt)
			return
	var tg := _nearest(ks, u.pos)
	u.target_id = tg.id
	if u.ranged:
		_foe_shoot_or_walk(u, tg, dt)
		return
	_engage(u, tg, dt)


## Střelec: střílí z dostřelu, ale postupuje na 60 % dostřelu, aby nevznikl pat.
func _foe_shoot_or_walk(u: Unit, tg: Unit, dt: float) -> void:
	var d := u.pos.distance_to(tg.pos)
	if d <= u.reach:
		_attack(u, tg)
	if d > u.reach * 0.6:
		_walk(u, tg.pos, dt, u.reach * 0.6)
	else:
		u.moving = false
	if d <= u.reach:
		_face_to(u, tg)


## Hrdinové, které nepřítel může cílit (bez těch v Úkrytu; když jsou schovaní všichni, tak všichni).
func _visible_knights() -> Array[Unit]:
	var all := living(SIDE_KNIGHT)
	var out: Array[Unit] = []
	for k in all:
		if k.hidden_t <= 0.0:
			out.append(k)
	return out if not out.is_empty() else all


func _taunter_for(u: Unit, ks: Array[Unit]) -> Unit:
	var best: Unit = null
	for k in ks:
		if k.taunt_t > 0.0:
			var r := float(ability_of(k.id).get("radius", 6.0))
			if k.pos.distance_to(u.pos) <= r and (best == null or k.pos.distance_to(u.pos) < best.pos.distance_to(u.pos)):
				best = k
	return best


## Nepřítel drží pozici: střelec střílí, co má na dostřel, pěšák vyrazí jen na rytíře blízko svého místa.
func _foe_hold(u: Unit, ks: Array[Unit], dt: float) -> void:
	if u.ranged:
		var tg := _nearest(ks, u.pos)
		if tg != null and u.pos.distance_to(tg.pos) <= u.reach:
			u.moving = false
			_attack(u, tg)
			return
	else:
		var near: Array[Unit] = []
		for k in ks:
			if k.pos.distance_to(u.home) <= u.hold_engage:
				near.append(k)
		var mt := _nearest(near, u.pos)
		if mt != null:
			if u.pos.distance_to(mt.pos) <= u.reach + mt.radius * 0.5:
				u.moving = false
				_attack(u, mt)
			else:
				_walk(u, mt.pos, dt, u.reach * 0.8)
			return
	if u.pos.distance_to(u.home) > 0.4:
		_walk(u, u.home, dt, 0.2)
	else:
		u.moving = false
		u.face = Vector2(0, -1)


func _separate() -> void:
	var al: Array[Unit] = []
	for u in units:
		if u.alive():
			al.append(u)
	for i in al.size():
		for j in range(i + 1, al.size()):
			var a := al[i]
			var b := al[j]
			var dv := b.pos - a.pos
			var d := maxf(dv.length(), 0.01)
			var m := (a.radius + b.radius) * 0.9
			if d < m:
				var push := (m - d) / 2.0
				var n := dv / d
				for pair: Array in [[a, -1.0], [b, 1.0]]:
					var u: Unit = pair[0]
					var sg: float = pair[1]
					var old := u.pos
					u.pos += n * push * sg
					if _in_water(u.pos):
						u.pos = old


func _enemy_morale() -> Dictionary:
	var m: Dictionary = {"break_losses": units_data["morale"]["break_losses"], "flee_y": river_hi + 12.0}
	m.merge(scenario.get("enemy_morale", {}), true)
	return m


## Zlomí morálku nepřátel, když ztratili dost jednotek.
func _check_morale() -> void:
	if foes_broken:
		return
	var total := 0
	var lost := 0
	for u in units:
		if u.side == SIDE_FOE:
			total += 1
			if not u.alive():
				lost += 1
	if total == 0 or float(lost) / total < float(_enemy_morale()["break_losses"]):
		return
	_break_morale()


func _break_morale() -> void:
	if foes_broken:
		return
	foes_broken = true
	broken_t = t
	for u in living(SIDE_FOE):
		if bool(_trait_value(u, "never_breaks", false)):
			continue
		var reaction := String(_trait_value(u, "on_break", u.on_break))
		if reaction == "flee":
			u.fleeing = true
		elif reaction == "desperate":
			u.desperate = true
	_log("Nepřítel je zlomený: střelci prchají, pěšáci se zoufale vrhají do boje. Můžeš dát povel Do boje!", true)


## Síla strany: zdraví × poškození za sekundu (hrubý odhad, bez bonusů).
func power(side: String) -> float:
	var p := 0.0
	for u in living(side):
		if not u.fleeing:
			p += u.hp * u.dmg / maxf(u.cd, 0.1)
	return p


func _check_decided() -> void:
	# pojistka proti patu: když hráč po zlomení morálky dlouho nedá Do boje!, hrdinové dobojují sami
	if foes_broken and not charging and broken_t >= 0.0 and t - broken_t > float(units_data["morale"].get("auto_charge_after", 25.0)):
		charging = true
		_log("Hrdinové sami dobíjejí zbytek nepřátel", true)
	if decided != "":
		return
	var r := float(units_data["behaviors"]["_common"]["decided_ratio"])
	var pk := power(SIDE_KNIGHT)
	var pe := power(SIDE_FOE)
	# Po zlomení morálky rozhoduje hráč povelem Do boje!, pojistka se nespouští.
	if pe < pk * r and not foes_broken:
		decided = SIDE_KNIGHT
	elif pk < pe * r:
		decided = SIDE_FOE
	else:
		return
	events.append({"type": "decided", "side": decided})
	_log("Bitva je rozhodnutá, hrdinové dobojují" if decided == SIDE_KNIGHT else "Bitva je ztracená, hrdinové bojují do posledního", true)


func step(dt: float) -> void:
	if over != "":
		return
	t += dt
	for u in units:
		if not u.alive():
			continue
		u.t -= dt
		u.atk = maxf(0.0, u.atk - dt)
		u.hit = maxf(0.0, u.hit - dt)
		u.taunt_t = maxf(0.0, u.taunt_t - dt)
		u.ability_cd = maxf(0.0, u.ability_cd - dt)
		u.stun_t = maxf(0.0, u.stun_t - dt)
		u.hidden_t = maxf(0.0, u.hidden_t - dt)
		u.shield_t = maxf(0.0, u.shield_t - dt)
		if u.side == SIDE_KNIGHT:
			_knight_think(u, dt)
		else:
			_foe_think(u, dt)
	_separate()

	for p in projectiles:
		var tg := by_id(p.target_id)
		if tg == null or not tg.alive():
			p.done = true
			continue
		var dv := tg.pos - p.pos
		var d := dv.length()
		var st := 18.0 * dt
		if d <= st:
			var src := by_id(p.from_id)
			_hurt(src, tg, p.dmg)
			p.done = true
			var pr := _pas(src, "probodnuti")
			if not pr.is_empty():
				var others: Array[Unit] = []
				for f in living(SIDE_FOE):
					if f != tg and f.pos.distance_to(tg.pos) <= float(pr["pierce_radius"]):
						others.append(f)
				var o := _nearest(others, tg.pos)
				if o != null:
					_hurt(src, o, p.dmg * float(pr["pierce_frac"]))
		else:
			p.pos += dv / d * st
	var still: Array[Projectile] = []
	for p in projectiles:
		if not p.done:
			still.append(p)
	projectiles = still

	# hořící zem (Ohnivá salva)
	for z: Dictionary in zones:
		z["t"] = float(z["t"]) - dt
		for f in living(SIDE_FOE):
			if f.pos.distance_to(z["pos"]) <= float(z["r"]):
				_hurt(by_id(z["from"]), f, float(z["dps"]) * dt / maxf(_taken_mult(f), 0.01), false)
	var keep: Array = []
	for z: Dictionary in zones:
		if float(z["t"]) > 0.0:
			keep.append(z)
	zones = keep

	_check_morale()
	_check_decided()

	if living(SIDE_FOE).is_empty():
		over = "win"
		events.append({"type": "end"})
	elif living(SIDE_KNIGHT).is_empty():
		over = "lose"
		events.append({"type": "end"})



## Výsledek bitvy pro běh: kdo padl, kdo utekl, sláva.
func result() -> Dictionary:
	var dead: Array = []
	var glory_by := {}
	var broken: Array = []
	var hp := {}
	for k in knights():
		hp[k.id] = k.hp / k.maxhp if k.alive() else 0.0
		if not k.alive():
			dead.append(k.id)
		glory_by[k.id] = k.glory_earned
		if k.oath_broken:
			broken.append(k.id)
	var fled: Array = []
	for u in units:
		if u.side == SIDE_FOE and u.fled:
			fled.append(u.key)
	return {"over": over, "t": t, "dead": dead, "fled": fled, "glory": glory, "glory_by": glory_by, "oaths_broken": broken, "task_ok": task_ok, "hp": hp}
