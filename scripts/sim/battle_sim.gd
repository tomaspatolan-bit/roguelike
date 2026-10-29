class_name BattleSim
extends RefCounted
## Logika jedné bitvy bez grafiky. Dá se spustit v testech bez okna.
##
## Souřadnice: Vector2(x, y), x doprava, y dopředu (k nepříteli), 1 jednotka = 1 m.
## Scéna to převádí na 3D jako Vector3(x, výška, -y).
## Data (statistiky, schopnosti, rod, scénář) přicházejí z JSON souborů ve složce data/.
##
## Hráč velí hrdinům rozkazy: na místo, na skupinu nepřátel, ke spojenci; bez rozkazu hrdina drží místo.
## Rozkazy se dávají kdykoli (bitva běží v reálném čase, hráč ji může pozastavit). Každý hrdina má
## jednu schopnost s počtem použití za bitvu. Sláva je společná rezerva rodu, platí se z ní použití navíc.

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
	var ability: String = ""      # klíč schopnosti (hrdinové)
	var uses: int = 0             # zbývající použití schopnosti v této bitvě
	var order: String = ""        # rozkaz hrdiny: "" (žádný: drží místo), "point", "group", "ally"
	var order_pos: Vector2        # point: kam jít
	var order_group: int = -1     # group: na kterou skupinu nepřátel
	var order_ally: String = ""   # ally: s kým zůstat
	var order_done: bool = false  # rozkaz splněn (došel, skupina padla, spojenec padl): drží místo `home`
	var regroup: bool = false     # vrací se ke spojenci (zatoulal se), dokud k němu nedojde
	var focus_id: String = ""     # po Úderu ze stínu a Nájezdu dobojuje s cílem, než se vrátí k rozkazu
	var focus_t: float = 0.0      # jak dlouho ještě (s)
	var group: int = -1           # nepřítel: skupina (pro rozkaz na skupinu)
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
	var dash_t: float = 0.0       # Nájezd skončí nejpozději po tolika s (cíl může zabírat nepřítel)
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
	var ability_cd: float = 0.0   # nabíjení schopnosti (s), než jde použít znovu
	var mounted: bool = false
	var vs_mounted: float = 1.0   # násobek poškození proti jízdě
	var ignores: Array = []       # druhy terénu, které jednotku nezpomalují ("les")
	var traits: Array = []        # vlastnosti (nepřátelé): klíče z units.json "traits"
	var asleep: bool = false      # nepřítel ve spící skupince (fáze bitvy): stojí, dokud se skupinka neprobudí
	var pod: int = -1             # skupinka ze scénáře (scenario.pods), -1 = žádná
	var heal_combat: float = 0.0  # kněz: samočinně léčí, jen když je nepřítel do tolika m (v boji)
	var skill: String = ""        # velitel: schopnost (units.json foe_skills)
	var skill_t: float = 0.0      # do další schopnosti (s)
	var casting: bool = false     # velitel se napřahuje (ohlášená schopnost, omráčení ji přeruší)
	var cast_t: float = 0.0
	var cast_pos: Vector2
	var cast_target: String = ""
	var rally_t: float = 0.0      # povzbuzený velitelem: silnější útok
	var rally_mult: float = 1.0
	var on_break: String = ""     # jak reaguje na zlomenou morálku (nepřátelé)
	var desperate: bool = false
	var fleeing: bool = false
	var fled: bool = false        # utekl z bojiště (počítá se jako ztráta, ne jako padlý)
	var arrive_t: float = 0.0     # nepřítel z pozdější vlny: kdy dorazí na bojiště

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
var abilities_used: int = 0
var zones: Array = []          # hořící zem: [{pos, r, t, dps, from}]
var grudges: Dictionary = {}    # nepřátelé, kteří zranili hrdinu (Přísaha pomsty)
var task_ok: bool = true
var mode: String = "stret"         # typ bitvy: utok (nepřítel drží pozice, oddíl postupuje), obrana, stret
var pending: Array[Unit] = []      # nepřátelé z dalších vln, ještě nedorazili (nejsou v units)
var waves_left: int = 0            # kolik vln ještě přijde
var groups: Array = []             # skupiny nepřátel: [{"name", "members": [id]}], index = Unit.group
var pods: Array = []               # skupinky (fáze bitvy) ze scénáře: [{"name", "wake", "alarm", "awake"}]
var pod_awake: Dictionary = {}     # číslo skupinky -> true, když se probudila
var over: String = ""
var foes_broken: bool = false
var broken_t: float = -1.0         # kdy se zlomila morálka nepřítele
var decided: String = ""        # "k" / "e": strana, která má bitvu rozhodnutou ve svůj prospěch
var charging: bool = false      # hráč vydal povel Do boje! (jednorázový)
var _next_id: int = 0
var _rng := RandomNumberGenerator.new()


## setup = {"pos": {key: Vector2}, "orders": {key: [druh, cíl]} (nepovinné, viz set_order),
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
	task_ok = not scenario["optional_task"].has("kill")
	mode = String(scenario.get("mode", "stret"))

	var knights_data: Dictionary = units_data["knights"]
	for key: String in knights_data:
		var u := _make_unit(key, SIDE_KNIGHT, knights_data[key])
		var p: Vector2 = setup["pos"][key]
		u.pos = p
		u.home = p
		u.face = Vector2(0, 1)
		units.append(u)
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
	pods = (scenario.get("pods", []) as Array).duplicate(true)
	for pi in pods.size():
		if bool((pods[pi] as Dictionary).get("awake", false)):
			pod_awake[pi] = true
	var i := 0
	var rows: Array = (scenario["enemies"] as Array).duplicate()
	rows.append_array(setup.get("extra_enemies", []))
	for row: Array in rows:
		var fkey: String = row[0]
		var fd: Dictionary = (foes_data[fkey] as Dictionary).duplicate()
		# obtížnost bitvy: násobky zdraví a poškození nepřátel ze scénáře
		fd["hp"] = float(fd["hp"]) * float(scenario.get("foe_hp", 1.0))
		fd["dmg"] = float(fd["dmg"]) * float(scenario.get("foe_dmg", 1.0))
		var u := _make_unit(fkey, SIDE_FOE, fd)
		u.id = "e%d" % i
		for extra: Variant in row.slice(3):
			if extra is Array:
				for tr: String in extra:
					if not u.traits.has(tr):
						u.traits.append(tr)
			elif extra is Dictionary:
				var orders: Dictionary = extra
				u.pod = int(orders.get("pod", -1))
				u.arrive_t = float(orders.get("arrive", 0.0))
				if orders.has("leader"):
					u.leader = bool(orders["leader"])
		u.pos = Vector2(row[1], row[2])
		u.home = u.pos
		u.face = Vector2(0, -1)
		u.asleep = u.pod >= 0 and u.pod < pods.size() and not pod_awake.has(u.pod)
		u.t = _rng.randf() * 0.6
		u.skill_t = float(units_data.get("foe_skills", {}).get(u.skill, {}).get("first", 3.0))
		if u.arrive_t > 0.0:
			pending.append(u)   # další vlna: přijde později
		else:
			units.append(u)
		i += 1
	var wave_times := {}
	for p in pending:
		wave_times[p.arrive_t] = true
	waves_left = wave_times.size()
	_make_groups()
	var orders: Dictionary = setup.get("orders", {})
	for key: String in orders:
		var o: Array = orders[key]
		set_order(key, String(o[0]), o[1] if o.size() > 1 else null)


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
static func default_setup(data: Dictionary) -> Dictionary:
	var pos := {}
	var deploy: Dictionary = data["scenario"]["deploy"]
	for key: String in deploy:
		var p: Array = deploy[key]["pos"]
		pos[key] = Vector2(p[0], p[1])
	var passives := {}
	var start: Dictionary = data["house"].get("start_passives", {})
	for key: String in start:
		passives[key] = (start[key] as Array).duplicate()
	return {"pos": pos, "orders": {}, "passives": passives}


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
	u.skill = String(d.get("skill", ""))
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
	u.heal_combat = d.get("heal_combat", 0.0)
	u.palette_row = int(d.get("palette_row", 0))
	u.target_priority = d.get("target_priority", "")
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


## Přísaha, která hrdinovi nedovolí léčení od kněze.
func _no_heal(u: Unit) -> bool:
	return bool(oath_of(u.id).get("no_heal", false))


func _no_retreat(u: Unit) -> bool:
	return bool(oath_of(u.id).get("no_retreat", false))


func _ord(field: String, default: float) -> float:
	return float(units_data.get("orders", {}).get(field, default))


# =============================================================== skupiny nepřátel

## Rozdělí nepřátele do skupin (cíl rozkazu na skupinu): kdo přijde ve stejné vlně, je stejného druhu
## boje (střelec / pěší) a stojí do `orders.group_link` m od někoho ze skupiny.
func _make_groups() -> void:
	var all: Array[Unit] = []
	for u in units:
		if u.side == SIDE_FOE:
			all.append(u)
	all.append_array(pending)
	var link := _ord("group_link", 3.0)
	groups.clear()
	# skupinky ze scénáře jsou skupiny pro rozkazy (i se svým názvem)
	for pi in pods.size():
		var pm: Array = []
		for u in all:
			if u.pod == pi:
				u.group = groups.size()
				pm.append(u.id)
		if not pm.is_empty():
			var pname := String((pods[pi] as Dictionary).get("name", ""))
			groups.append({"members": pm, "name": pname if pname != "" else _group_title(pm)})
	for u in all:
		if u.group >= 0:
			continue
		var g := groups.size()
		var members: Array = []
		var queue: Array[Unit] = [u]
		u.group = g
		while not queue.is_empty():
			var a: Unit = queue.pop_back()
			members.append(a.id)
			for b in all:
				if b.group < 0 and b.arrive_t == a.arrive_t and b.ranged == a.ranged and b.home.distance_to(a.home) <= link:
					b.group = g
					queue.append(b)
		groups.append({"members": members, "name": _group_title(members)})


func _group_title(members: Array) -> String:
	var foes: Dictionary = units_data["foes"]
	var counts := {}
	var leader := ""
	for id: String in members:
		var u := by_id(id)
		if u == null:
			for p in pending:
				if p.id == id:
					u = p
		if u.leader:
			leader = u.name
			continue
		counts[u.key] = int(counts.get(u.key, 0)) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return counts[a] > counts[b])
	var parts: Array = []
	if leader != "":
		parts.append(leader)
	for k: String in keys:
		var pl := String(foes[k].get("plural", foes[k]["name"]))
		parts.append(pl if parts.is_empty() else pl.to_lower())
	return " a ".join(parts)


## Skupina nepřítele (-1 = neznámý).
func group_of(id: String) -> int:
	var u := by_id(id)
	return u.group if u != null and u.side == SIDE_FOE else -1


## Živí nepřátelé skupiny, kteří už jsou na bojišti.
func group_members(g: int) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in units:
		if u.side == SIDE_FOE and u.group == g and u.alive() and not u.fleeing:
			out.append(u)
	return out


## Název skupiny pro hráče, s počtem živých („Lapkové (5)“).
func group_name(g: int) -> String:
	if g < 0 or g >= groups.size():
		return ""
	return "%s (%d)" % [groups[g]["name"], group_members(g).size()]


## Střed skupiny (jen živí na bojišti).
func group_center(g: int) -> Vector2:
	var m := group_members(g)
	var sum := Vector2.ZERO
	for u in m:
		sum += u.pos
	return sum / maxi(m.size(), 1)


func _dmg_mult(u: Unit, tg: Unit = null) -> float:
	if u.side != SIDE_KNIGHT:
		var fm := 1.0
		if u.desperate:
			fm += float(units_data["morale"]["desperate_dmg_bonus"]) + float(_trait_value(u, "desperate_dmg_bonus", 0.0))
		if u.rally_t > 0.0:
			fm *= u.rally_mult
		return fm
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


## Proč schopnost teď nejde použít ("" = jde). Pro nápovědu v UI.
func ability_problem(id: String) -> String:
	var u := by_id(id)
	if u == null or not u.alive() or u.ability == "":
		return "Hrdina nemá schopnost."
	if u.uses <= 0:
		return "Schopnost je pro tuto bitvu vyčerpaná."
	if u.ability_cd > 0.0:
		return "Schopnost se nabíjí (%d s)." % ceili(u.ability_cd)
	return ""


## Jde schopnost použít (bez ohledu na cíl)?
func can_use_ability(id: String) -> bool:
	var u := by_id(id)
	if u == null or u.side != SIDE_KNIGHT or not u.alive() or u.ability == "" or over != "" or u.dashing:
		return false
	return u.uses > 0 and u.ability_cd <= 0.0


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
			# nejlepší místo: střed hrdiny, kolem kterého je nejvíc zraněných
			var best_p := Vector2.ZERO
			var best_hurt := 0
			for c in living(SIDE_KNIGHT):
				if c.pos.distance_to(u.pos) > float(a["range"]):
					continue
				var hurt := 0
				for k in living(SIDE_KNIGHT):
					if k.pos.distance_to(c.pos) <= float(a["radius"]) and k.hp < k.maxhp * 0.6:
						hurt += 1
				if hurt > best_hurt:
					best_hurt = hurt
					best_p = c.pos
			return [best_hurt >= 2, best_p if best_hurt >= 2 else null]
		"salva", "najezd":
			var best: Unit = null
			var best_n := 0
			if u.ability == "najezd":
				# rada: omráčit velitele, který se napřahuje
				for f in foes:
					if f.casting and f.pos.distance_to(u.pos) <= float(a["range"]) and not (a.get("land", false) and _in_water(f.pos)):
						return [true, f.pos]
			for f in foes:
				if f.pos.distance_to(u.pos) > float(a["range"]) or (a.get("land", false) and _in_water(f.pos)):
					continue
				if f.asleep or _near_sleeper(f.pos):
					continue   # rada: spící skupinku nebudit schopností
				if u.ability == "najezd" and not _near_other_knight(u, f.pos):
					continue   # rada: nájezd jen tam, kde už bojuje někdo z oddílu (ne sám do přesily)
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
				if f.pos.distance_to(u.pos) <= float(a["range"]) and (f.ranged or f.hp < f.maxhp * 0.4) and not f.asleep and not _near_sleeper(f.pos) and _near_other_knight(u, f.pos):
					pick = f
					break
			return [pick != null, pick.id if pick != null else null]
	return [false, null]


## Rada: je u místa spící skupinka? (schopnost by ji probudila; do jejího `wake` + 2 m)
func _near_sleeper(p: Vector2) -> bool:
	for f in living(SIDE_FOE):
		if f.asleep and f.pod >= 0 and f.pod < pods.size():
			var wake := float((pods[f.pod] as Dictionary).get("wake", scenario.get("wake_radius", 7.0)))
			if f.pos.distance_to(p) <= wake + 2.0:
				return true
	return false


## Rada: stojí u místa (do `hint_support` m) jiný hrdina? Skok a nájezd nemají vést samotného hrdinu do přesily.
func _near_other_knight(u: Unit, p: Vector2) -> bool:
	for k in living(SIDE_KNIGHT):
		if k != u and k.pos.distance_to(p) <= _ord("hint_support", 5.0):
			return true
	return false


## Kdy přijde další vlna (INF = žádná).
func next_wave_t() -> float:
	var best := INF
	for p in pending:
		best = minf(best, p.arrive_t)
	return best


## Použije schopnost hrdiny (ubere použití, spustí nabíjení). Vrací false, když to nejde.
func use_ability(id: String, target: Variant = null) -> bool:
	if not can_use_ability(id) or ability_target_problem(id, target) != "":
		return false
	var u := by_id(id)
	var a := ability_of(id)
	u.uses -= 1
	u.ability_cd = float(a.get("cooldown", 0.0))
	abilities_used += 1
	var where: Vector2 = u.pos
	match u.ability:
		"vyzva":
			u.taunt_t = float(a["duration"])
		"pozehnani":
			where = target
			for k in living(SIDE_KNIGHT):
				if k.pos.distance_to(where) <= float(a["radius"]) and not _no_heal(k):
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
			u.dash_t = u.pos.distance_to(target) / maxf(u.speed * float(a["speed_mult"]), 0.1) + 0.3
		"uder":
			var e := by_id(String(target))
			var dir := (e.pos - u.pos).normalized()
			var behind := e.pos + dir * (e.radius + u.radius)
			if not _in_water(behind):
				u.pos = behind
			where = e.pos
			_face_to(u, e)
			u.focus_id = e.id
			u.focus_t = _ord("focus_time", 3.0)
			u.atk = 0.25
			u.combat_t = t
			_hurt(u, e, u.dmg * float(a["mult"]) * _dmg_mult(u, e))
			if not _pas(u, "ukryt").is_empty():
				u.hidden_t = float(_pas(u, "ukryt")["hidden_t"])
	events.append({"type": "ability", "id": u.id, "key": u.ability, "pos": where})
	_log("%s: %s" % [u.name, a["name"]], true)
	return true


# =============================================================== příkazy hráče

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


# --------------------------------------------------------------- rozkazy hrdinům

## Proč rozkaz nejde dát ("" = jde). kind: "point" (cíl Vector2), "group" (číslo skupiny nebo id nepřítele),
## "ally" (id hrdiny), "" (zrušit: hrdina drží, kde stojí). Rozkazy jdou dávat kdykoli.
func order_problem(id: String, kind: String = "", target: Variant = null) -> String:
	var u := by_id(id)
	if u == null or u.side != SIDE_KNIGHT or not u.alive():
		return "Neznámý hrdina."
	if bool(oath_of(id).get("ignores_orders", false)) and _grudge_target(u) != null:
		return "%s drží přísahu pomsty a rozkaz neposlechne." % u.name
	match kind:
		"point":
			if not target is Vector2:
				return "Vyber místo."
			if _in_water(target):
				return "Do vody to nejde."
		"group":
			var g := _group_arg(target)
			if g < 0 or group_members(g).is_empty():
				return "Vyber nepřítele."
		"ally":
			var a := by_id(String(target)) if target is String else null
			if a == null or a == u or a.side != SIDE_KNIGHT or not a.alive():
				return "Vyber jiného hrdinu."
	return ""


func _group_arg(target: Variant) -> int:
	if target is int:
		return target
	if target is float:
		return int(target)
	if target is String:
		return group_of(target)
	return -1


## Dá hrdinovi rozkaz. Vrací false, když to nejde (order_problem).
func set_order(id: String, kind: String, target: Variant = null) -> bool:
	if order_problem(id, kind, target) != "":
		return false
	var u := by_id(id)
	u.order = kind
	u.order_done = false
	u.focus_id = ""
	u.regroup = false
	match kind:
		"point":
			u.order_pos = target
		"group":
			u.order_group = _group_arg(target)
		"ally":
			u.order_ally = target
		_:
			u.order = ""
			u.home = u.pos
	return true


## Rozkaz přesunu (přetažení hrdiny): totéž co rozkaz na místo.
func order_move(id: String, target: Vector2) -> bool:
	return set_order(id, "point", target)


## Rozkaz hrdiny pro hráče („Na místo“, „Na skupinu: Lapkové (5)“…).
func order_text(id: String) -> String:
	var u := by_id(id)
	if u == null:
		return ""
	var names: Dictionary = units_data.get("orders", {}).get("names", {})
	match u.order:
		"point":
			return String(names.get("point_done" if u.order_done else "point", "Na místo"))
		"group":
			if u.order_done:
				return String(names.get("group_done", "Skupina padla, drží místo"))
			return "%s: %s" % [names.get("group", "Na skupinu"), group_name(u.order_group)]
		"ally":
			var a := by_id(u.order_ally)
			if u.order_done or a == null:
				return String(names.get("ally_done", "Spojenec padl, drží místo"))
			return "%s: %s" % [names.get("ally", "Se spojencem"), a.name]
	return String(names.get("none", "Bez rozkazu: drží místo"))


## Hrdinové bez rozkazu (jména). Scéna před bitvou varuje.
func unordered() -> Array:
	var out: Array = []
	for k in living(SIDE_KNIGHT):
		if k.order == "":
			out.append(k.name)
	return out


## Vůdce oddílu pro automatického velitele: nejodolnější bojovník (ne léčitel, ne střelec).
func _auto_lead() -> Unit:
	var lead: Unit = null
	for k in living(SIDE_KNIGHT):
		if k.heal <= 0.0 and not k.ranged and (lead == null or k.maxhp > lead.maxhp):
			lead = k
	return lead


## Jednoduchý velitel pro testy a automatické hraní: vůdce jde na nejbližší skupinu,
## ostatní se drží u něj. V obraně (a dokud bojují bdělí nepřátelé, když scénář radí `auto_plan: "hold"`)
## vůdce drží místo. Vrací {id: [druh, cíl]}.
func suggest_orders() -> Dictionary:
	var out := {}
	var ks := living(SIDE_KNIGHT)
	var lead := _auto_lead()
	if lead == null:
		for k in ks:
			out[k.id] = [""]
		return out
	var awake_left := false
	for f in living(SIDE_FOE):
		awake_left = awake_left or (not f.asleep and not f.fleeing)
	var main := -1
	var main_melee := false
	for g in groups.size():
		var mem := group_members(g)
		if mem.is_empty():
			continue
		var melee := false
		for f in mem:
			melee = melee or not f.ranged
		var d := group_center(g).distance_to(lead.pos)
		var md := group_center(main).distance_to(lead.pos) if main >= 0 else INF
		# nejbližší skupina; pěší přednost jen při podobné vzdálenosti (osamělý střelec za řekou počká)
		if main < 0 or d < md - 2.0 or (absf(d - md) <= 2.0 and melee and not main_melee):
			main = g
			main_melee = melee
	var hold := mode == "obrana" or (String(scenario.get("auto_plan", "attack")) == "hold" and awake_left)
	for k in ks:
		if k == lead:
			out[k.id] = [""] if hold or main < 0 else ["group", main]
		else:
			out[k.id] = ["ally", lead.id]
	return out


## Automatický velitel (testy, auto-hraní): když se plán vůdce změní (skupina padla, probudila se jiná…),
## dá oddílu nové rozkazy. Hráč tohle dělá sám.
func auto_command() -> void:
	var lead := _auto_lead()
	if lead == null:
		return
	var plan := suggest_orders()
	var o: Array = plan.get(lead.id, [""])
	var same := lead.order == String(o[0]) and not lead.order_done
	if same and lead.order == "group":
		same = lead.order_group == int(o[1])
	if same or (lead.order == "" and String(o[0]) == ""):
		var fine := true
		for k in living(SIDE_KNIGHT):
			if k != lead and (k.order != "ally" or k.order_ally != lead.id):
				fine = false
		if fine:
			return
	apply_orders(plan)


## Dá všem hrdinům rozkazy ze slovníku {id: [druh, cíl]} (třeba ze suggest_orders).
func apply_orders(orders: Dictionary) -> void:
	for id: String in orders:
		var o: Array = orders[id]
		set_order(id, String(o[0]), o[1] if o.size() > 1 else null)


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


## Krok v pásu u břehu nevede hlouběji do řeky.
func _not_deeper(old: Vector2, p: Vector2) -> bool:
	var mid := (river_lo + river_hi) / 2.0
	if old.y >= mid:
		return p.y >= old.y - 0.001
	return p.y <= old.y + 0.001


func _in_water(p: Vector2) -> bool:
	return p.y > river_lo - 0.3 and p.y < river_hi + 0.3 and _crossing_at(p.x).is_empty()


## Kam jít, aby se jednotka dostala k cíli přes řeku (nejvýhodnějším přechodem).
func _nav(u: Unit, target: Vector2) -> Vector2:
	var us := _band(u.pos.y)
	var ts := _band(target.y)
	var here := _crossing_at(u.pos.x)
	if us == 1 and ts == 1 and not here.is_empty():
		var there := _crossing_at(target.x)
		if there.is_empty() or float(there["x0"]) != float(here["x0"]):
			# oba v pásu řeky, ale na různých přechodech (lávka a brod): nejdřív ven na břeh blíž cíli
			var mid := (river_lo + river_hi) / 2.0
			var exit_y := river_lo - 0.5 if target.y < mid else river_hi + 0.5
			return Vector2(clampf(u.pos.x, float(here["x0"]) + 0.35, float(here["x1"]) - 0.35), exit_y)
	if us == ts or (us == 1 and not here.is_empty()):
		if us == 1 and ts != 1:
			return Vector2(clampf(u.pos.x, float(here["x0"]) + 0.35, float(here["x1"]) - 0.35), river_lo - 0.5 if ts == 0 else river_hi + 0.5)
		return target
	var c := _best_crossing(u.pos.x, target.x)
	if ts == 1 and not _crossing_at(target.x).is_empty():
		c = _crossing_at(target.x)   # cíl stojí v přechodu: jde se tím přechodem
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
	var dir := _avoid(u, dv / d, target, d)
	var step_v := dir * st
	u.pos += step_v
	u.face = dir
	u.moving = true
	if _in_water(u.pos) and _in_water(old) and _not_deeper(old, u.pos):
		return   # už stojí v pásu u břehu (odtlačení): smí se hýbat podél břehu nebo ven, ne hlouběji
	if _in_water(u.pos):
		# u břehu se nezasekne: zkusí sklouznout podél břehu (jen po x, nebo jen po y)
		u.pos = old + Vector2(step_v.x, 0.0)
		if _in_water(u.pos):
			u.pos = old + Vector2(0.0, step_v.y)
			if _in_water(u.pos):
				u.pos = old + Vector2(0.0, -absf(step_v.x) if old.y < river_lo else absf(step_v.x))
				if _in_water(u.pos):
					u.pos = old


## Uhnutí: když v cestě (do `avoid_look` m před jednotkou) stojí jednotka stejné strany, směr se stočí do strany,
## aby se spojenci obcházeli, místo aby šli skrz sebe. Nepřítel se neobchází (do něj se jde bojovat).
func _avoid(u: Unit, dir: Vector2, target: Vector2, dist: float) -> Vector2:
	var look := _ord("avoid_look", 1.6)
	var steer := Vector2.ZERO
	for o in units:
		if o == u or o.side != u.side or not o.alive() or o.fled:
			continue
		var rel := o.pos - u.pos
		var d := rel.length()
		if d > look or d < 0.001 or o.pos.distance_to(target) <= o.radius + 0.3:
			continue
		var ahead := rel.dot(dir)
		if ahead <= 0.0 or ahead > dist:
			continue
		var lateral := rel - dir * ahead
		var need := u.radius + o.radius + 0.1
		var lat := lateral.length()
		if lat >= need:
			continue
		var side := -lateral / lat if lat > 0.01 else Vector2(-dir.y, dir.x)
		steer += side * (1.0 - d / look) * (1.0 - lat / need)
	if steer == Vector2.ZERO:
		return dir
	var out := dir + steer * _ord("avoid_strength", 1.5)
	if out.dot(dir) < 0.1:
		out = dir * 0.1 + steer.normalized()   # nikdy necouvá, jen uhne
	return out.normalized()


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
	if not u.moving and u.pos.distance_to(p) <= stop + _ord("settle", 1.0):
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
	_priest_heal(u, dt)
	var foes := living(SIDE_FOE)
	if u.dashing:
		_dash(u, dt, foes)
		return
	if has_oath(u.id):
		var nf := _nearest(foes, u.pos)
		if nf != null and u.pos.distance_to(nf.pos) <= u.reach + 0.3:
			_gain_glory(float(house["glory"]["oath_per_second"]) * dt, u)
	# Do boje! nebo rozhodnutá bitva: všichni útočí.
	if (charging or decided != "") and not foes.is_empty():
		_engage(u, _choose_target(u, foes), dt)
		return
	# Po Úderu ze stínu a Nájezdu dobojuje s cílem (nejvýš `focus_time` s, dokud žije a je u něj), pak se vrátí k rozkazu.
	if u.focus_id != "":
		var fo := by_id(u.focus_id)
		u.focus_t -= dt
		if fo == null or not fo.alive() or fo.fleeing or u.focus_t <= 0.0 or fo.pos.distance_to(u.pos) > u.reach + _ord("focus_leash", 4.0):
			u.focus_id = ""
		else:
			u.regroup = false
			_engage(u, fo, dt)
			return
	# Přísaha pomsty: dokud žije, kdo zranil spojence, jde po něm a rozkaz neplatí.
	if bool(oath_of(u.id).get("ignores_orders", false)):
		var gt := _grudge_target(u)
		if gt != null:
			_engage(u, gt, dt)
			return
	match u.order:
		"point":
			_order_point(u, dt, foes)
		"group":
			_order_group(u, dt, foes)
		"ally":
			_order_ally(u, dt, foes)
		_:
			_hold_place(u, dt, foes)


## Nejbližší živý nepřítel, který zranil spojence (Přísaha pomsty).
func _grudge_target(u: Unit) -> Unit:
	var list: Array[Unit] = []
	for f in living(SIDE_FOE):
		if grudges.has(f.id) and not f.fleeing:
			list.append(f)
	return _nearest(list, u.pos)


## Rozkaz splněn: hrdina drží místo, kde stojí.
func _done(u: Unit) -> void:
	u.order_done = true
	u.home = u.pos


## Bojuje s tím z `foes`, kdo je u něj (pěší do reach + `on_way`, střelec do `on_way_ranged`).
## Vrací true, když bojuje.
func _fight_close(u: Unit, dt: float, foes: Array[Unit]) -> bool:
	var close: Array[Unit] = []
	var r := _ord("on_way_ranged", 2.5) if u.ranged else u.reach + _ord("on_way", 1.0)
	for f in foes:
		if f.pos.distance_to(u.pos) <= r:
			close.append(f)
	var tg := _choose_target(u, close)
	if tg == null:
		return false
	if u.ranged:
		u.moving = false
		_attack(u, tg)
	else:
		_engage(u, tg, dt)
	return true


## Na místo: dojde bez boje (tak hráč hrdinu stáhne z boje), pak místo drží.
func _order_point(u: Unit, dt: float, foes: Array[Unit]) -> void:
	if u.order_done:
		_hold_place(u, dt, foes)
		return
	var d := u.pos.distance_to(u.order_pos)
	var taken := false   # na místě už stojí jiný hrdina: stačí dojít k němu
	for k in living(SIDE_KNIGHT):
		if k != u and k.pos.distance_to(u.order_pos) <= 1.0:
			taken = true
	if d <= 0.4 or (taken and d <= 2.0):
		u.moving = false
		_done(u)
		return
	_go(u, u.order_pos, dt, 0.3, foes)
	if not u.moving:
		_done(u)   # došel, nebo dál nesmí (přísaha Nikdy neustoupí): drží, kde stojí


## Na skupinu: jde po skupině (i když se hýbe) a bojuje s jejími členy (a brání se tomu, kdo ho cestou napadne);
## když skupina padne, drží místo.
func _order_group(u: Unit, dt: float, foes: Array[Unit]) -> void:
	if u.order_done:
		_hold_place(u, dt, foes)
		return
	var mem := group_members(u.order_group)
	if mem.is_empty():
		_done(u)
		_hold_place(u, dt, foes)
		return
	if _fight_close(u, dt, mem):
		return
	# kdo na něj cestou útočí, tomu se brání (stáhnout z boje jde rozkazem na místo)
	var attackers: Array[Unit] = []
	for f in foes:
		if f.target_id == u.id and not f.asleep:
			attackers.append(f)
	if _fight_close(u, dt, attackers):
		return
	var tg := _choose_target(u, mem)
	if u.ranged:
		if u.pos.distance_to(tg.pos) <= u.reach:
			u.moving = false
			_attack(u, tg)
		else:
			_walk(u, tg.pos, dt, u.reach * 0.9)
		return
	_engage(u, tg, dt)


## Ke spojenci: drží se u něj (střelec a léčitel kus za ním) a bojuje s tím, kdo spojence ohrožuje.
## Léčitel se zapojí, jen když nikdo v dosahu léčení nepotřebuje léčit, jinak se jen brání.
func _order_ally(u: Unit, dt: float, foes: Array[Unit]) -> void:
	var a := by_id(u.order_ally)
	if u.order_done or a == null or not a.alive():
		if not u.order_done:
			_done(u)
		_hold_place(u, dt, foes)
		return
	var cand: Array[Unit] = []
	var guard := _ord("ally_guard", 3.0)
	var own := u.reach + _ord("on_way", 1.0)
	var helps := u.heal <= 0.0 or not _needs_heal(u)
	var dist := _ord("ally_dist_back", 4.0) if (u.ranged or u.heal > 0.0) else _ord("ally_dist", 2.0)
	var gap := u.pos.distance_to(a.pos)
	if not u.ranged and gap > dist + guard + _ord("ally_leash", 0.5):
		u.regroup = true
	if u.regroup and gap <= dist + 0.5:
		u.regroup = false
	if u.regroup:
		# zatoulal se (třeba po Nájezdu): vrací se až ke spojenci a cestou se nezdržuje
		_walk(u, a.pos, dt, dist)
		return
	for f in foes:
		if u.ranged:
			if f.pos.distance_to(u.pos) <= u.reach:
				cand.append(f)
		elif f.pos.distance_to(u.pos) <= own or (helps and f.pos.distance_to(a.pos) <= guard):
			cand.append(f)
	var tg := _choose_target(u, cand)
	if tg != null:
		if u.ranged:
			u.moving = false
			_attack(u, tg)
		else:
			_engage(u, tg, dt)
		return
	var spot := a.pos
	var nf := _nearest(foes, a.pos)
	if nf != null and nf.pos.distance_to(a.pos) > 0.1:
		spot = a.pos + (a.pos - nf.pos).normalized() * dist
		if _in_water(spot):
			spot = a.pos
	_settle(u, spot, dt, 0.6 if spot != a.pos else dist, foes)


## Potřebuje někdo v dosahu léčitele léčení?
func _needs_heal(u: Unit) -> bool:
	for k in living(SIDE_KNIGHT):
		if k.hp < k.maxhp * 0.85 and k.pos.distance_to(u.pos) <= u.heal_range:
			return true
	return false


## Drží místo `home`: bojuje s tím, kdo přijde do `hold_radius` m od místa, a brání se tomu,
## kdo na něj útočí do dvojnásobku; střelec střílí na dostřel. Pak se vrátí na místo.
func _hold_place(u: Unit, dt: float, foes: Array[Unit]) -> void:
	var hr := _ord("hold_radius", 4.0)
	var cand: Array[Unit] = []
	for f in foes:
		if u.ranged:
			if f.pos.distance_to(u.pos) <= u.reach:
				cand.append(f)
		elif f.pos.distance_to(u.home) <= hr or (f.target_id == u.id and f.pos.distance_to(u.home) <= hr * 2.0):
			cand.append(f)
	var tg := _choose_target(u, cand)
	if tg != null:
		if u.ranged:
			u.moving = false
			_attack(u, tg)
		else:
			_engage(u, tg, dt)
		return
	_settle(u, u.home, dt, 0.3, foes)


## Je kněz v boji? (bdělý nepřítel do `heal_combat` m). Mezi skupinkami se samo neléčí.
func _in_combat(u: Unit) -> bool:
	for f in living(SIDE_FOE):
		if not f.asleep and not f.fleeing and f.pos.distance_to(u.pos) <= u.heal_combat:
			return true
	return false


## Kněz léčí nejzraněnějšího hrdinu v dosahu, jen v boji.
func _priest_heal(u: Unit, dt: float) -> void:
	if u.heal > 0.0:
		u.heal_t -= dt
		if u.heal_t <= 0.0 and _in_combat(u):
			var best: Unit = null
			for k in living(SIDE_KNIGHT):
				if k.hp < k.maxhp * 0.85 and k.pos.distance_to(u.pos) <= u.heal_range and not _no_heal(k):
					if best == null or k.hp / k.maxhp < best.hp / best.maxhp:
						best = k
			if best != null:
				best.hp = minf(best.maxhp, best.hp + u.heal)
				u.heal_t = u.heal_cd
				events.append({"type": "heal", "id": best.id})


## Nájezd: jede rychle k cíli, každého nepřítele v cestě zasáhne a omráčí.
func _dash(u: Unit, dt: float, foes: Array[Unit]) -> void:
	var a := ability_of(u.id)
	u.dash_t -= dt
	var dv := u.dash_to - u.pos
	var d := dv.length()
	var st := minf(d, u.speed * float(a["speed_mult"]) * dt)
	var next := u.pos + (dv / maxf(d, 0.0001)) * st
	if d < 0.2 or u.dash_t <= 0.0 or _in_water(next):
		u.dashing = false
		u.moving = false
		# po Nájezdu dobojuje s nejbližším, koho srazil
		var hit: Array[Unit] = []
		for id: String in u.dash_hit:
			var hf := by_id(id)
			if hf != null and hf.alive():
				hit.append(hf)
		var near := _nearest(hit, u.pos)
		if near != null:
			u.focus_id = near.id
			u.focus_t = _ord("focus_time", 3.0)
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
		if u.casting:
			_skill_cancel(u)
		return
	if u.asleep:
		# spící skupinka: stojí na svém místě, dokud se neprobudí (_check_pods)
		if u.pos.distance_to(u.home) > 0.4:
			_walk(u, u.home, dt, 0.2)
		else:
			u.moving = false
		return
	var ks := _visible_knights()
	if ks.is_empty():
		u.moving = false
		return
	if u.skill != "":
		if u.casting:
			u.moving = false
			u.cast_t -= dt
			var aim := by_id(u.cast_target)
			var look: Vector2 = aim.pos if aim != null else u.cast_pos
			if look.distance_to(u.pos) > 0.01:
				u.face = (look - u.pos).normalized()
			if u.cast_t <= 0.0:
				_skill_fire(u)
			return
		u.skill_t -= dt
		if u.skill_t <= 0.0 and _skill_start(u, ks):
			return
	# Výzva: kdo je v dosahu tanka s výzvou, útočí na něj
	var tg := _taunter_for(u, ks)
	if tg == null:
		tg = _foe_pick(u, ks)
	u.target_id = tg.id
	if u.ranged:
		_foe_shoot_or_walk(u, tg, dt)
		return
	if not _has_slot(u, tg):
		# u hrdiny už je plno: počká kousek stranou, nestrká se do chumlu
		var away := u.pos - tg.pos
		var spot := tg.pos + (away / maxf(away.length(), 0.01)) * (u.reach + tg.radius + _ord("wait_gap", 1.6))
		if u.pos.distance_to(spot) > 0.4:
			_walk(u, spot, dt, 0.3)
		else:
			u.moving = false
			_face_to(u, tg)
		return
	_engage(u, tg, dt)


# --------------------------------------------------------------- velitelé

func _skill_def(u: Unit) -> Dictionary:
	return units_data.get("foe_skills", {}).get(u.skill, {})


## Velitel začne schopnost, když má smysl (cíl v dosahu). Ohlásí ji: napřahuje se `windup` s
## (rozhraní kreslí varování z warnings()). Vrací true, když začal.
func _skill_start(u: Unit, ks: Array[Unit]) -> bool:
	var sd := _skill_def(u)
	if sd.is_empty():
		return false
	var kind := String(sd["kind"])
	var rng := float(sd.get("range", 0.0))
	var r := float(sd.get("radius", 0.0))
	var target: Unit = null
	var where := u.pos
	match kind:
		"zone":
			# hodí na místo, kde stojí nejvíc hrdinů
			var best_n := 0
			for k in ks:
				if k.pos.distance_to(u.pos) > rng:
					continue
				var n := 0
				for o in ks:
					if o.pos.distance_to(k.pos) <= r:
						n += 1
				if n > best_n:
					best_n = n
					where = k.pos
			if best_n == 0:
				return false
		"shot":
			for k in ks:
				if k.pos.distance_to(u.pos) <= rng and (target == null or k.hp / k.maxhp < target.hp / target.maxhp):
					target = k
			if target == null:
				return false
			where = target.pos
		"smash":
			var any := false
			for k in ks:
				any = any or k.pos.distance_to(u.pos) <= r * 0.8
			if not any:
				return false
		"rally":
			var near := false
			for k in ks:
				near = near or k.pos.distance_to(u.pos) <= 6.0
			if not near:
				return false
	u.casting = true
	u.cast_t = float(sd.get("windup", 1.5))
	u.cast_pos = where
	u.cast_target = target.id if target != null else ""
	u.moving = false
	var warn := String(sd.get("warn", "%s se napřahuje!"))
	var text := warn % (target.name if target != null else u.name) if warn.contains("%s") else warn
	events.append({"type": "warn", "id": u.id, "text": text})
	_log(text, true)
	return true


## Ohlášená schopnost velitele dopadne.
func _skill_fire(u: Unit) -> void:
	var sd := _skill_def(u)
	u.casting = false
	u.skill_t = float(sd.get("cd", 10.0))
	u.combat_t = t
	var r := float(sd.get("radius", 0.0))
	var where := u.cast_pos
	match String(sd["kind"]):
		"zone":
			for k in living(SIDE_KNIGHT):
				if k.pos.distance_to(where) <= r:
					_hurt(u, k, float(sd.get("dmg", 0.0)) * _dmg_mult(u, k))
			if sd.has("burn_t"):
				zones.append({"pos": where, "r": r, "t": float(sd["burn_t"]), "dps": float(sd["burn_dps"]), "from": u.id, "hurts": SIDE_KNIGHT})
		"shot":
			var k := by_id(u.cast_target)
			if k != null and k.alive() and k.hidden_t <= 0.0 and k.pos.distance_to(u.pos) <= float(sd.get("range", 0.0)) + 2.0:
				_hurt(u, k, float(sd.get("dmg", 0.0)) * _dmg_mult(u, k))
				where = k.pos
		"smash":
			where = u.pos
			for k in living(SIDE_KNIGHT):
				if k.pos.distance_to(u.pos) <= r:
					_hurt(u, k, float(sd.get("dmg", 0.0)) * _dmg_mult(u, k))
		"rally":
			where = u.pos
			for f in living(SIDE_FOE):
				if f.pos.distance_to(u.pos) <= r and not f.asleep:
					f.rally_t = float(sd.get("duration", 5.0))
					f.rally_mult = float(sd.get("dmg_mult", 1.3))
	events.append({"type": "skill", "id": u.id, "key": u.skill, "pos": where, "radius": r})


## Omráčení přeruší napřahování (hráč může schopnost velitele zastavit Nájezdem).
func _skill_cancel(u: Unit) -> void:
	u.casting = false
	u.skill_t = float(_skill_def(u).get("cd", 10.0)) * 0.5
	_log("%s: přerušeno!" % u.name, true)


## Ohlášené schopnosti velitelů pro rozhraní: [{"pos", "radius", "t", "kind", "target"}].
func warnings() -> Array:
	var out: Array = []
	for f in living(SIDE_FOE):
		if f.casting:
			var sd := _skill_def(f)
			var k := by_id(f.cast_target)
			var pos: Vector2 = k.pos if k != null else (f.pos if String(sd["kind"]) in ["smash", "rally"] else f.cast_pos)
			out.append({"pos": pos, "radius": float(sd.get("radius", 0.9)) if String(sd["kind"]) != "shot" else 0.9, "t": f.cast_t, "kind": String(sd["kind"]), "target": f.cast_target, "id": f.id})
	return out


## Kolik pěších nepřátel teď bojuje s hrdinou zblízka.
func _attackers_on(k: Unit, except: Unit = null) -> int:
	var n := 0
	for f in living(SIDE_FOE):
		if f != except and not f.ranged and not f.asleep and f.target_id == k.id and f.pos.distance_to(k.pos) <= f.reach + k.radius + 0.6:
			n += 1
	return n


## Má nepřítel u hrdiny místo? (nejvýš `melee_slots` pěších najednou; kdo už bojuje, místo má)
func _has_slot(u: Unit, k: Unit) -> bool:
	if u.target_id == k.id and u.pos.distance_to(k.pos) <= u.reach + k.radius + 0.6:
		return true
	return _attackers_on(k, u) < int(_ord("melee_slots", 3.0))


## Cíl nepřítele: nejbližší hrdina s volným místem (střelec prostě nejbližší); když je všude plno, nejbližší.
func _foe_pick(u: Unit, ks: Array[Unit]) -> Unit:
	if u.ranged:
		return _nearest(ks, u.pos)
	var free: Array[Unit] = []
	for k in ks:
		if _has_slot(u, k):
			free.append(k)
	var best := _nearest(free, u.pos)
	return best if best != null else _nearest(ks, u.pos)


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
			var m := (a.radius + b.radius) * _ord("body_gap", 1.0)
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
	if foes_broken or not pending.is_empty():
		return   # dokud přicházejí další vlny, nepřítel se nezlomí
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
	for pi in pods.size():
		if not pod_awake.has(pi):
			_wake_pod(pi, "zlom")   # zlomený nepřítel už nikde nečeká
	for u in living(SIDE_FOE):
		if bool(_trait_value(u, "never_breaks", false)):
			continue
		var reaction := String(_trait_value(u, "on_break", u.on_break))
		if reaction == "flee":
			u.fleeing = true
		elif reaction == "desperate":
			u.desperate = true
	_log("Nepřítel je zlomený: střelci prchají, pěšáci se zoufale vrhají do boje. Můžeš dát povel Do boje!", true)


## Síla strany: zdraví × poškození za sekundu (hrubý odhad, bez bonusů). Spící skupinky se nepočítají
## (ještě nebojují), další vlny ano.
func power(side: String) -> float:
	var p := 0.0
	for u in living(side):
		if not u.fleeing and not u.asleep:
			p += u.hp * u.dmg / maxf(u.cd, 0.1)
	if side == SIDE_FOE:
		for u in pending:
			p += u.hp * u.dmg / maxf(u.cd, 0.1)
	return p


## Další vlna: nepřátelé, jejichž čas přišel, vstoupí na bojiště (událost arrive pro scénu).
func _arrivals() -> void:
	if pending.is_empty():
		return
	var keep: Array[Unit] = []
	var came := 0
	for u in pending:
		if t >= u.arrive_t:
			units.append(u)
			if foes_broken:
				u.desperate = u.on_break == "desperate"   # přicházejí do prohrané bitvy
			events.append({"type": "arrive", "id": u.id})
			came += 1
		else:
			keep.append(u)
	pending = keep
	if came > 0:
		var wave_times := {}
		for p in pending:
			wave_times[p.arrive_t] = true
		waves_left = wave_times.size()
		_log("Přichází další vlna: %d nepřátel" % came, true)


## Probouzení skupinek (fáze bitvy): spící skupinka se probudí, když se k některému jejímu členovi
## přiblíží hrdina na `wake` m, když ji někdo zraní, když bdělý nepřítel bojuje do `alarm` m od jejího
## místa (hluk boje) nebo když se nepříteli zlomí morálka.
func _check_pods() -> void:
	for pi in pods.size():
		if pod_awake.has(pi):
			continue
		var pd: Dictionary = pods[pi]
		var wake := float(pd.get("wake", scenario.get("wake_radius", 7.0)))
		var alarm := float(pd.get("alarm", scenario.get("alarm_radius", 0.0)))
		var members: Array[Unit] = []
		for f in living(SIDE_FOE):
			if f.pod == pi:
				members.append(f)
		if members.is_empty():
			continue
		var why := ""
		if foes_broken:
			why = "zlom"
		for f in members:
			if why != "":
				break
			if f.hp < f.maxhp:
				why = "zasah"
				break
			for k in living(SIDE_KNIGHT):
				if k.pos.distance_to(f.pos) <= wake:
					why = "blizko"
					break
		if why == "" and alarm > 0.0:
			# hluk boje: bdělý nepřítel bojuje do `alarm` m od místa skupinky
			var c := _pod_center(pi)
			for f in living(SIDE_FOE):
				if f.pod != pi and not f.asleep and t - f.combat_t <= 1.0 and f.pos.distance_to(c) <= alarm:
					why = "poplach"
					break
		if why != "":
			_wake_pod(pi, why)


func _pod_center(pi: int) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for f in living(SIDE_FOE):
		if f.pod == pi:
			sum += f.home
			n += 1
	return sum / maxi(n, 1)


func _wake_pod(pi: int, why: String) -> void:
	pod_awake[pi] = true
	for f in living(SIDE_FOE):
		if f.pod == pi:
			f.asleep = false
	var pname := String((pods[pi] as Dictionary).get("name", "Nepřátelé"))
	var msg := ("%s: poplach! Přidávají se do boje" if why == "poplach" else "%s se dávají do boje") % pname
	events.append({"type": "wake", "pod": pi, "why": why, "text": msg})
	_log(msg, true)


func _any_asleep() -> bool:
	for f in living(SIDE_FOE):
		if f.asleep:
			return true
	return false


## Spící skupinky, které ještě zbývají (pro rozhraní: „čekají další nepřátelé“).
func sleeping_pods() -> int:
	var n := 0
	for pi in pods.size():
		if pod_awake.has(pi):
			continue
		for f in living(SIDE_FOE):
			if f.pod == pi:
				n += 1
				break
	return n


func _check_decided() -> void:
	# pojistka proti patu: když hráč po zlomení morálky dlouho nedá Do boje!, hrdinové dobojují sami
	if foes_broken and not charging and broken_t >= 0.0 and t - broken_t > float(units_data["morale"].get("auto_charge_after", 25.0)):
		charging = true
		_log("Hrdinové sami dobíjejí zbytek nepřátel", true)
	if decided != "":
		return
	var r := float(units_data["morale"]["decided_ratio"])
	var pk := power(SIDE_KNIGHT)
	var pe := power(SIDE_FOE)
	# Po zlomení morálky rozhoduje hráč povelem Do boje!, pojistka se nespouští.
	if pe < pk * r and not foes_broken and not _any_asleep():
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
	_arrivals()
	_check_pods()
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
		u.rally_t = maxf(0.0, u.rally_t - dt)
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
		for f in living(String(z.get("hurts", SIDE_FOE))):
			if f.pos.distance_to(z["pos"]) <= float(z["r"]):
				_hurt(by_id(z["from"]), f, float(z["dps"]) * dt / maxf(_taken_mult(f), 0.01), false)
	var keep: Array = []
	for z: Dictionary in zones:
		if float(z["t"]) > 0.0:
			keep.append(z)
	zones = keep

	_check_morale()
	_check_decided()

	if living(SIDE_FOE).is_empty() and pending.is_empty():
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
