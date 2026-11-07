class_name BattleSim
extends RefCounted
## Logic of a single battle without graphics. Can run in tests without a window.
##
## Coordinates: Vector2(x, y), x to the right, y forward (towards the enemy), 1 unit = 1 m.
## The scene converts it to 3D as Vector3(x, height, -y).
## Data (stats, abilities, house, scenario) come from JSON files in the data/ folder.
##
## The player commands heroes with orders: to a place, at an enemy group, with an ally; without an order a hero holds his place.
## Orders can be given at any time (the battle runs in real time, the player can pause it). Each hero has
## one ability with a number of uses per battle. Glory is the house's shared reserve.

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
	var ability: String = ""      # ability key (heroes)
	var uses: int = 0             # remaining ability uses in this battle
	var order: String = ""        # hero order: "" (none: holds place), "point", "group", "ally"
	var order_pos: Vector2        # point: where to go
	var order_group: int = -1     # group: which enemy group
	var order_ally: String = ""   # ally: whom to stay with
	var order_done: bool = false  # order done (arrived, group fell, ally fell): holds place `home`
	var regroup: bool = false     # returning to the ally (strayed) until he reaches him
	var focus_id: String = ""     # after Shadow Strike and Charge keeps fighting the target before returning to the order
	var focus_t: float = 0.0      # how much longer (s)
	var group: int = -1           # enemy: group (for the group order)
	var t: float = 0.0
	var heal_t: float = 0.0
	var atk: float = 0.0
	var hit: float = 0.0
	var face: Vector2 = Vector2(0, 1)
	var moving: bool = false
	var combat_t: float = -INF    # when he last attacked or was hit
	var taunt_t: float = 0.0      # Challenge: while running, enemies in range attack him
	var stun_t: float = 0.0       # stun: does nothing
	var dashing: bool = false     # Charge: rides to dash_to and knocks down whoever he meets
	var dash_to: Vector2
	var dash_hit: Array = []
	var dash_t: float = 0.0       # Charge ends after this many s at the latest (the target spot may be taken by an enemy)
	var glory_earned: float = 0.0
	var passives: Array = []      # passive and oath keys (units.json "passives")
	var base: Dictionary = {}     # class data the stats are recalculated from
	var oath_broken: bool = false
	var second_wind_used: bool = false
	var revive_used: bool = false # priest: already used Last Rites
	var primed: bool = false      # cavalier: lunge under way (Running Start)
	var struck: Dictionary = {}   # assassin: whom he has already struck (From the Shadows)
	var hidden_t: float = 0.0     # Vanish: no one targets him
	var shield_t: float = 0.0     # Blessed Armor: less damage taken
	var shield: float = 1.0
	var avenger: bool = false     # Avenger: an ally fell
	var kills: int = 0            # how many enemies he killed (Oath of the Ancestors)
	var orders_given: int = 0     # orders given during the battle (Oath of Silence)
	var moved_t: float = -INF     # when he last moved (Never Stand Still)
	var idle_t: float = 0.0       # how long he has stood without fighting (Never Stand Still)
	var alone_t: float = 0.0      # how long he has been without allies (Under the Banner)
	var away_t: float = 0.0       # how long he has been far from the tank (Oath of the Standard)
	var first_struck: bool = false  # has already landed his first blow (Knightly Challenge)
	var ward: String = ""         # whom he protects (Oath of Protection)
	var bond_with: String = ""    # bond: with whom (hero id)
	var bond_type: String = ""    # bond: type (units.json bonds)
	var bond_level: int = 0       # bond: level 1–3
	var student: bool = false     # Master and Pupil: this hero is the pupil
	var rage_t: float = 0.0       # Brothers in Arms grief: rages (stronger, ignores orders)
	var mourn_t: float = 0.0      # Confessor grief: the priest does not heal
	var grief: Dictionary = {}    # grief penalties until the end of the battle {stat: fraction}
	var marked_by: String = ""    # enemy: target of the Hunting Pair (archer id)
	var mark_t: float = 0.0
	var rescue_used: bool = false # Lance and Shield: the cavalier has already ridden to the tank's aid
	var rescue_t: float = 0.0
	var dash_mult: float = 1.0    # combo: stronger Charge
	var extra_stats: Dictionary = {}  # permanent and one-battle stat bonuses from the run (events): {stat: fraction}
	var oath_mult: float = 1.0    # Trial of the Oath: the oath's stat bonuses × this
	var oath_cost: float = -1.0   # Trial of the Oath: glory cost of breaking (−1 = from the data)
	var combo_strike: String = "" # Hammer and Anvil combo: who leaps behind the first one knocked down
	var target_id: String = ""    # enemy: whom he is attacking right now
	var leader: bool = false      # enemy leader: when he falls, morale breaks
	var ability_cd: float = 0.0   # ability recharge (s) before it can be used again
	var mounted: bool = false
	var vs_mounted: float = 1.0   # damage multiplier against cavalry
	var ignores: Array = []       # terrain kinds that do not slow the unit ("les" = forest)
	var traits: Array = []        # traits (enemies): keys from units.json "traits"
	var asleep: bool = false      # enemy in a sleeping group (battle phases): stands until the group wakes
	var pod: int = -1             # group from the scenario (scenario.pods), -1 = none
	var heal_combat: float = 0.0  # priest: heals on his own only when an enemy is within this many m (in combat)
	var skill: String = ""        # commander: ability (units.json foe_skills)
	var skill_t: float = 0.0      # until the next ability (s)
	var casting: bool = false     # commander is winding up (announced ability, a stun interrupts it)
	var cast_t: float = 0.0
	var cast_pos: Vector2
	var cast_target: String = ""
	var rally_t: float = 0.0      # rallied by a commander: stronger attack
	var rally_mult: float = 1.0
	var on_break: String = ""     # how he reacts to broken morale (enemies)
	var desperate: bool = false
	var fleeing: bool = false
	var fled: bool = false        # fled the battlefield (counts as a loss, not as fallen)
	var arrive_t: float = 0.0     # enemy from a later wave: when he arrives on the battlefield

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
var crossings: Array = []   # [{x0, x1, kind, speed}] places where the river can be crossed
var forests: Array = []     # [{x0, x1, y0, y1, speed, path: [x0, x1]}]

# --- state ---
var t: float = 0.0
var units: Array[Unit] = []
var projectiles: Array[Projectile] = []
var events: Array[Dictionary] = []
var glory: float = 0.0
var abilities_used: int = 0
var zones: Array = []          # burning ground: [{pos, r, t, dps, from}]
var grudges: Dictionary = {}    # enemies who wounded a hero (Blood Debt)
var task_ok: bool = true
var mode: String = "stret"         # battle type: utok (assault: enemy holds positions, squad advances), obrana (defense), stret (clash)
var pending: Array[Unit] = []      # enemies from later waves who have not arrived yet (not in units)
var waves_left: int = 0            # how many waves are still to come
var groups: Array = []             # enemy groups: [{"name", "members": [id]}], index = Unit.group
var pods: Array = []               # groups (battle phases) from the scenario: [{"name", "wake", "alarm", "awake"}]
var pod_awake: Dictionary = {}     # group number -> true once it has woken up
var over: String = ""
var foes_broken: bool = false
var broken_t: float = -1.0         # when the enemy's morale broke
var decided: String = ""        # "k" / "e": the side the battle is decided in favour of
var charging: bool = false      # the player gave the All In! command (one-time)
var _next_id: int = 0
var ancestors: int = 0             # fallen ancestors of the house in the run (Oath of the Ancestors)
var _rng := RandomNumberGenerator.new()


## setup = {"pos": {key: Vector2}, "orders": {key: [kind, target]} (optional, see set_order),
##          "passives": {key: [passive keys]} (optional, otherwise the house's default passives),
##          "glory": starting glory (the run carries it over), "names": {key: name} (successors),
##          "extra_enemies": [extra enemy rows] (fled enemies who returned)}
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
	ancestors = int(setup.get("ancestors", 0))
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
		u.extra_stats = ((setup.get("hero_stats", {}) as Dictionary).get(key, {}) as Dictionary).duplicate()
		var ob: Dictionary = (setup.get("oath_boost", {}) as Dictionary).get(key, {})
		u.oath_mult = float(ob.get("mult", 1.0))
		u.oath_cost = float(ob.get("break_cost", -1.0))
		var bd: Dictionary = (setup.get("bonds", {}) as Dictionary).get(key, {})
		if not bd.is_empty() and (units_data.get("bonds", {}) as Dictionary).has(String(bd.get("type", ""))):
			u.bond_with = String(bd["with"])
			u.bond_type = String(bd["type"])
			u.bond_level = clampi(int(bd.get("level", 1)), 1, 3)
			u.student = bool(bd.get("student", false))
		_apply_passives(u)
		var names: Dictionary = setup.get("names", {})
		if names.has(key):
			u.name = names[key]
		var hp_frac: Dictionary = setup.get("hp", {})
		if hp_frac.has(key):
			u.hp = u.maxhp * clampf(float(hp_frac[key]), 0.05, 1.0)   # wounds from the previous battle of the run

	var foes_data: Dictionary = units_data["foes"]
	pods = (scenario.get("pods", []) as Array).duplicate(true)
	for pi in pods.size():
		if bool((pods[pi] as Dictionary).get("awake", false)):
			pod_awake[pi] = true
	var i := 0
	var rows: Array = _without_pods((scenario["enemies"] as Array).duplicate(), int(setup.get("remove_pods", 0)))
	rows.append_array(setup.get("extra_enemies", []))
	for row: Array in rows:
		var fkey: String = row[0]
		var fd: Dictionary = (foes_data[fkey] as Dictionary).duplicate()
		# battle difficulty: scenario multipliers of enemy health and damage
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
			pending.append(u)   # next wave: arrives later
		else:
			units.append(u)
		i += 1
	var wave_times := {}
	for p in pending:
		wave_times[p.arrive_t] = true
	waves_left = wave_times.size()
	_make_groups()
	for k in knights():
		_pick_ward(k, String((setup.get("wards", {}) as Dictionary).get(k.id, "")))
	var orders: Dictionary = setup.get("orders", {})
	for key: String in orders:
		var o: Array = orders[key]
		set_order(key, String(o[0]), o[1] if o.size() > 1 else null)


## The Deserter (event): the next battle has `n` fewer enemy groups. Removes whole groups (pods) without
## a leader or commander, the last ones first; a scenario without groups loses its last `n` × 3 footmen without a skill.
func _without_pods(rows: Array, n: int) -> Array:
	if n <= 0:
		return rows
	var foes: Dictionary = units_data["foes"]
	var boss_pods := {}
	var pod_ids := {}
	for row: Array in rows:
		var pod := -1
		var leader := bool(foes[row[0]].get("leader", false)) or String(foes[row[0]].get("skill", "")) != ""
		for extra: Variant in row.slice(3):
			if extra is Dictionary:
				pod = int((extra as Dictionary).get("pod", -1))
				leader = leader or bool((extra as Dictionary).get("leader", false))
		if pod >= 0:
			pod_ids[pod] = true
			if leader:
				boss_pods[pod] = true
	var drop := {}
	var ids: Array = pod_ids.keys()
	ids.sort()
	ids.reverse()
	for p: int in ids:
		if drop.size() < n and not boss_pods.has(p):
			drop[p] = true
	var out: Array = []
	var cut := 0 if not drop.is_empty() else n * 3
	for i in range(rows.size() - 1, -1, -1):
		var row: Array = rows[i]
		var pod := -1
		for extra: Variant in row.slice(3):
			if extra is Dictionary:
				pod = int((extra as Dictionary).get("pod", -1))
		var plain := not bool(foes[row[0]].get("leader", false)) and String(foes[row[0]].get("skill", "")) == ""
		if drop.has(pod):
			continue
		if cut > 0 and plain and pod < 0:
			cut -= 1
			continue
		out.push_front(row)
	return out


## scenario = scenario key (file data/scenarios/<key>.json), or a full path to the file.
static func load_data(scenario: String = DEFAULT_SCENARIO) -> Dictionary:
	var path := scenario if scenario.begins_with("res://") else "res://data/scenarios/%s.json" % scenario
	return {
		"units": _read_json("res://data/units.json"),
		"house": _read_json("res://data/rod_vlka.json"),
		"scenario": read_scenario(path),
	}


## Scenario; a variant with "base" takes everything from the base scenario and overrides only its own fields.
static func read_scenario(path_or_key: String) -> Dictionary:
	var path := path_or_key if path_or_key.begins_with("res://") else "res://data/scenarios/%s.json" % path_or_key
	var sc := _read_json(path)
	if sc.has("base"):
		var base := read_scenario(String(sc["base"]))
		base.merge(sc, true)
		base.erase("base")
		return base
	return sc


## List of scenarios in order for the battle picker.
static func scenario_list() -> Array:
	return _read_json("res://data/scenarios/index.json").get("order", [DEFAULT_SCENARIO])


## Default deployment from the scenario.
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
		push_error("Cannot load %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON in %s" % path)
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


## The hero's passive (data), or an empty dictionary if he does not have it. A broken oath does not apply.
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


## Passives the hero can get (by class).
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


## Why the passive cannot be added ("" = it can).
func passive_problem(id: String, key: String) -> String:
	var u := by_id(id)
	if u == null or not units_data["passives"].has(key):
		return "Unknown passive."
	if t > 0.0:
		return "Passives can only be changed before the battle."
	if not passives_for(id).has(key):
		return "This passive is not for this class."
	if units_data["passives"][key].get("kind", "") == "oath":
		for k: String in u.passives:
			if k != key and units_data["passives"][k].get("kind", "") == "oath":
				return "%s has already sworn the oath “%s”." % [u.name, units_data["passives"][k]["name"]]
	return ""


## Adds or removes a passive (only before the battle). Returns false when not possible.
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
	_pick_ward(u, "")
	return true


## Recalculates the hero's stats from class data, passives and oath: health (Toughness), attack delay
## and healing speed (Haste), priest healing (Power), range, ability uses.
func _apply_passives(u: Unit) -> void:
	var extra := 0
	var reach_mult := 1.0
	for k: String in u.passives:
		var d: Dictionary = _pas(u, k)
		extra += int(d.get("extra_uses", 0))
		reach_mult *= float(d.get("reach_mult", 1.0))
	if _bond_side(u) == 0:
		extra += int(_bv(u, "extra_uses"))
	u.maxhp = float(u.base["hp"]) * maxf(0.1, 1.0 + stat(u, "odolnost", null, true))
	u.hp = u.maxhp
	var quick := maxf(0.1, 1.0 + stat(u, "pohotovost", null, true))
	u.cd = float(u.base["cd"]) / quick
	u.heal_cd = float(u.base.get("heal_cd", 0.0)) / quick
	u.heal = float(u.base.get("heal", 0.0)) * maxf(0.0, 1.0 + stat(u, "moc", null, true))
	u.reach = float(u.base["reach"]) * reach_mult
	if u.ability != "":
		u.uses = int(ability_of(u.id).get("uses", 0)) + extra


## The hero's stat bonus (fraction: 0.25 = +25 %): utok, moc, odolnost, pohotovost. Might counts towards Attack and Power.
## Without a target (tg = null) only bonuses independent of the target; conditional ones (when) only if the condition holds now.
## static = true: only unconditional bonuses (health and delays are computed once before the battle).
func stat(u: Unit, key: String, tg: Unit = null, static_only: bool = false) -> float:
	if u == null or u.side != SIDE_KNIGHT:
		return 0.0
	var sum := 0.0
	for k: String in u.passives:
		var d: Dictionary = _pas(u, k)
		if d.is_empty() or (static_only and d.has("when")) or not (static_only or _when_ok(u, d, tg)):
			continue
		var st: Dictionary = d.get("stats", {})
		var om := u.oath_mult if d.get("kind", "") == "oath" else 1.0
		sum += float(st.get(key, 0.0)) * om
		if key == "utok" or key == "moc":
			sum += float(st.get("sila", 0.0)) * om
		if d.has("per_ancestor"):
			var n := mini(ancestors, int(d.get("ancestors_max", 3)))
			var pa: Dictionary = d["per_ancestor"]
			sum += n * float(pa.get(key, 0.0))
			if key == "utok" or key == "moc":
				sum += n * float(pa.get("sila", 0.0))
	sum += float(u.extra_stats.get(key, 0.0))
	if key == "utok" or key == "moc":
		sum += float(u.extra_stats.get("sila", 0.0))
	if static_only:
		return sum
	var sila := key == "utok" or key == "moc"
	sum += float(u.grief.get(key, 0.0)) + (float(u.grief.get("sila", 0.0)) if sila else 0.0)
	if u.rage_t > 0.0 and key == "utok":
		sum += float(_bond_def(u).get("rage_utok", 0.0))
	var p := _partner(u)
	if p != null:
		var bd := _bond_def(u)
		var on := true
		if bd.has("near_radius"):
			on = p.pos.distance_to(u.pos) <= float(bd["near_radius"])
		if bool(bd.get("successor", false)):
			on = on and u.student
		if on:
			var bst: Dictionary = bd.get("stats", {})
			for sk: String in bst:
				if sk == key or (sk == "sila" and sila):
					sum += _lvl(bst[sk], u.bond_level)
	return sum


## Hero stats for the card: {utok, moc, odolnost, pohotovost} as fractions (conditional bonuses as of now).
func stats_of(id: String) -> Dictionary:
	var u := by_id(id)
	var out := {}
	for k: String in ["utok", "moc", "odolnost", "pohotovost"]:
		out[k] = stat(u, k)
	return out


## Does the passive's condition (`when`) hold? Target conditions do not hold without a target.
func _when_ok(u: Unit, d: Dictionary, tg: Unit) -> bool:
	match String(d.get("when", "")):
		"":
			return true
		"allies_near":
			return _allies_within(u, float(d.get("near_radius", 8.0))) >= int(d.get("near_allies", 2))
		"alone":
			return _allies_within(u, float(d.get("alone_radius", 4.0))) == 0
		"moving":
			return u.moving or t - u.moved_t <= float(d.get("moving_grace", 1.5))
		"avenger":
			return u.avenger
		"vs_ranged":
			return tg != null and tg.ranged
		"vs_grudge":
			return tg != null and grudges.has(tg.id)
		"unseen":
			return tg != null and tg.side == SIDE_FOE and tg.target_id != u.id
	return false


# --------------------------------------------------------------- pouta

## Data of the hero's bond type (units.json bonds), empty without a bond.
func _bond_def(u: Unit) -> Dictionary:
	if u == null or u.bond_type == "":
		return {}
	return (units_data.get("bonds", {}) as Dictionary).get(u.bond_type, {})


## Living bond companion, or null.
func _partner(u: Unit) -> Unit:
	if u == null or u.bond_with == "":
		return null
	var p := by_id(u.bond_with)
	return p if p != null and p.alive() else null


## Value for a level: a list [l1, l2, l3] or a single number.
func _lvl(v: Variant, level: int) -> float:
	if v is Array:
		var arr: Array = v
		return float(arr[clampi(level - 1, 0, arr.size() - 1)]) if not arr.is_empty() else 0.0
	return float(v)


## Number from the hero's bond for its level (0 without a bond).
func _bv(u: Unit, key: String) -> float:
	var bd := _bond_def(u)
	return _lvl(bd[key], u.bond_level) if bd.has(key) else 0.0


## The hero's side in the bond's `who`: 0 = group A (e.g. the cavalier in Lance and Shield), 1 = group B, -1 = no bond.
## For a pair that fits both ways, A is the one with the smaller key.
func _bond_side(u: Unit) -> int:
	var bd := _bond_def(u)
	if bd.is_empty():
		return -1
	var who: Array = bd.get("who", [["*"], ["*"]])
	var in_a := (who[0] as Array).has(u.key) or (who[0] as Array).has("*")
	var in_b := (who[1] as Array).has(u.key) or (who[1] as Array).has("*")
	if in_a and not in_b:
		return 0
	if in_b and not in_a:
		return 1
	return 0 if u.key < u.bond_with else 1


## The hero's bond for the scene: {type, name, with, level, desc, grief_desc} or empty.
func bond_of(id: String) -> Dictionary:
	var u := by_id(id)
	var bd := _bond_def(u)
	if bd.is_empty():
		return {}
	return {"type": u.bond_type, "name": bd["name"], "with": u.bond_with, "level": u.bond_level, "desc": bd.get("desc", ""), "grief_desc": bd.get("grief_desc", "")}


## Heals hero k by `amount` from a healer (priest, Blessing, Second Wind…): Confessor heals the companion more,
## a grieving priest does not heal, Blood Brothers heals the companion too.
func _heal(healer: Unit, k: Unit, amount: float, share: bool = true) -> void:
	if not k.alive() or amount <= 0.0:
		return
	if healer != null and healer.mourn_t > 0.0 and healer != k:
		return
	if healer != null and healer.bond_type == "zpovednik" and healer.bond_with == k.id and healer.heal > 0.0:
		amount *= 1.0 + _bv(healer, "heal_bonus")
	k.hp = minf(k.maxhp, k.hp + amount)
	events.append({"type": "heal", "id": k.id})
	if share and k.bond_type == "krev":
		var p := _partner(k)
		if p != null and not _no_heal(p):
			_heal(null, p, amount * _bv(k, "heal_share"), false)


## Who takes part of the wounded hero's damage: Oath of Protection (ward), Shield-Bearer (companion within share_radius). [hero, share] or [].
func _shield_bearer(tg: Unit) -> Array:
	var guard := _warden_of(tg)
	if guard != null:
		return [guard, float(oath_of(guard.id).get("ward_share", 0.5))]
	var p := _partner(tg)
	if p != null and tg.bond_type == "stitonos" and _bond_side(p) == 0:
		if p.pos.distance_to(tg.pos) <= float(_bond_def(tg).get("share_radius", 3.0)):
			return [p, _bv(tg, "share")]
	return []


## Grief: a hero with a bond fell, the companion gets grief by type and level (level 1 halved, level 3 also −Might).
func _grieve(dead: Unit) -> void:
	var p := _partner(dead)
	if p == null:
		return
	var bd := _bond_def(dead)
	var rules: Dictionary = units_data.get("bond_rules", {})
	var scale := float(rules.get("grief_half", 0.5)) if dead.bond_level <= 1 else 1.0
	match dead.bond_type:
		"bratri":
			p.rage_t = float(bd.get("rage_t", 8.0)) * scale
		"zpovednik":
			if p.heal > 0.0:
				p.mourn_t = float(bd.get("mourn_t", 10.0)) * scale
		"stitonos":
			if _bond_side(p) == 0:
				p.uses = int(floor(p.uses * (1.0 - scale)))
		"lovci":
			p.grief["utok"] = float(p.grief.get("utok", 0.0)) + float(bd.get("grief_utok", -0.2)) * scale
		"krev":
			p.hp = maxf(1.0, p.hp - p.maxhp * float(bd.get("grief_hp", 0.3)) * scale)
	if dead.bond_level >= 3:
		p.grief["sila"] = float(p.grief.get("sila", 0.0)) + float(rules.get("grief_sila", -0.15))
	_log("%s mourns his fallen companion %s (%s)" % [p.name, dead.name, bd.get("name", "")], true)


## Lance and Shield: after the tank's ability the cavalier's ability recharges.
func _after_ability(u: Unit) -> void:
	var p := _partner(u)
	if p != null and u.bond_type == "kopi" and _bond_side(u) == 1:
		p.ability_cd *= 1.0 - _bv(u, "recharge")


func _allies_within(u: Unit, r: float) -> int:
	var n := 0
	for k in living(SIDE_KNIGHT):
		if k != u and k.pos.distance_to(u.pos) <= r:
			n += 1
	return n


## The oath the hero currently holds (data). Empty dictionary when he has none or broke it.
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


## How many oaths were broken in the battle.
func oaths_broken() -> int:
	var n := 0
	for k in knights():
		if k.oath_broken:
			n += 1
	return n


## An oath that does not allow the priest to heal the hero.
func _no_heal(u: Unit) -> bool:
	return bool(oath_of(u.id).get("no_heal", false))


## Vow of Poverty: the priest does not heal himself.
func _no_self_heal(u: Unit) -> bool:
	return bool(oath_of(u.id).get("no_self_heal", false))


func _no_retreat(u: Unit) -> bool:
	return bool(oath_of(u.id).get("no_retreat", false))


## Oath of Vigilance: once the battle starts the hero does not move.
func _no_move(u: Unit) -> bool:
	return t > 0.0 and bool(oath_of(u.id).get("no_move", false))


## May the hero attack this enemy on his own? Oaths that forbid some targets
## (the fleeing, the wounded below a threshold, whoever attacks him, only a commander before the first blow).
func _oath_allows(u: Unit, tg: Unit) -> bool:
	if u.side != SIDE_KNIGHT or tg.side != SIDE_FOE:
		return true
	var o := oath_of(u.id)
	if o.is_empty():
		return true
	if bool(o.get("spare_fleeing", false)) and tg.fleeing:
		return false
	if o.has("spare_below") and tg.hp < tg.maxhp * float(o["spare_below"]):
		return false
	if bool(o.get("spare_attackers", false)) and tg.target_id == u.id:
		return false
	if bool(o.get("first_on_commander", false)) and not u.first_struck and not _is_commander(tg):
		return false
	return true


func _is_commander(f: Unit) -> bool:
	return f.leader or f.skill != ""


## Ability hit: when the oath forbids such a target, the hero breaks it. Knightly Challenge: the first hit decides
## whether he kept the oath.
func _ability_hit(u: Unit, tg: Unit) -> void:
	if not has_oath(u.id):
		return
	if not _oath_allows(u, tg):
		_break(u, "hit %s" % tg.name)
	u.first_struck = true


## Why an order would break the oath ("" = it would not). The scene asks before such an order.
func order_oath_conflict(id: String, kind: String, target: Variant = null) -> String:
	var u := by_id(id)
	var o := oath_of(id)
	if u == null or o.is_empty():
		return ""
	if bool(o.get("no_retreat", false)) and kind == "point" and target is Vector2 and is_retreat(id, target):
		return "an order may not lead back"
	if t <= 0.0:
		return ""   # before the battle starts orders are free
	if bool(o.get("no_orders", false)):
		return "takes no orders once the battle starts"
	if bool(o.get("no_move", false)):
		return "may not move once the battle starts"
	if o.has("max_orders") and u.orders_given >= int(o["max_orders"]):
		return "takes at most %d orders per battle" % int(o["max_orders"])
	return ""


## Why an ability would break the oath ("" = it would not). Area hits are known only on impact.
func ability_oath_conflict(id: String, target: Variant = null) -> String:
	var u := by_id(id)
	var o := oath_of(id)
	if u == null or o.is_empty():
		return ""
	if (o.get("breaks_on_ability", []) as Array).has(u.ability):
		return "%s would break the oath" % String(units_data["abilities"][u.ability]["name"])
	if target is String:
		var e := by_id(target)
		if e != null and not _oath_allows(u, e):
			return "his oath forbids attacking %s" % e.name
	return ""


func _ord(field: String, default: float) -> float:
	return float(units_data.get("orders", {}).get(field, default))


# =============================================================== enemy groups

## Splits enemies into groups (target of the group order): those who come in the same wave, fight the same way
## (ranged / melee) and stand within `orders.group_link` m of someone in the group.
func _make_groups() -> void:
	var all: Array[Unit] = []
	for u in units:
		if u.side == SIDE_FOE:
			all.append(u)
	all.append_array(pending)
	var link := _ord("group_link", 3.0)
	groups.clear()
	# groups from the scenario are groups for orders (with their own name)
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
	return " and ".join(parts)


## Enemy's group (-1 = unknown).
func group_of(id: String) -> int:
	var u := by_id(id)
	return u.group if u != null and u.side == SIDE_FOE else -1


## Living group members already on the battlefield.
func group_members(g: int) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in units:
		if u.side == SIDE_FOE and u.group == g and u.alive() and not u.fleeing:
			out.append(u)
	return out


## Group name for the player, with the number alive ("Brigands (5)").
func group_name(g: int) -> String:
	if g < 0 or g >= groups.size():
		return ""
	return "%s (%d)" % [groups[g]["name"], group_members(g).size()]


## Group centre (only the living on the battlefield).
func group_center(g: int) -> Vector2:
	var m := group_members(g)
	var sum := Vector2.ZERO
	for u in m:
		sum += u.pos
	return sum / maxi(m.size(), 1)


## Damage multiplier. Hero: Attack (basic attack and Shadow Strike); ability (ability = true) only Power via ability_of.
func _dmg_mult(u: Unit, tg: Unit = null, ability: bool = false) -> float:
	if u.side != SIDE_KNIGHT:
		var fm := 1.0
		if u.desperate:
			fm += float(units_data["morale"]["desperate_dmg_bonus"]) + float(_trait_value(u, "desperate_dmg_bonus", 0.0))
		if u.rally_t > 0.0:
			fm *= u.rally_mult
		return fm
	var mark := 1.0
	if tg != null and tg.mark_t > 0.0 and tg.marked_by == u.id:
		mark = _bv(u, "mark_mult") if u.bond_type == "lovci" else 1.0
	if ability:
		return mark
	return maxf(0.0, 1.0 + stat(u, "utok", tg)) * maxf(mark, 0.0)


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


## Target from candidates: the nearest, but a hero with target_priority prefers his kind of target.
func _choose_target(u: Unit, all_cand: Array[Unit]) -> Unit:
	var cand: Array[Unit] = []
	for f in all_cand:
		if _oath_allows(u, f):
			cand.append(f)
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

## The hero's ability including passive modifications (ability_mod).
func ability_of(id: String) -> Dictionary:
	var u := by_id(id)
	if u == null or u.ability == "":
		return {}
	var a: Dictionary = (units_data["abilities"][u.ability] as Dictionary).duplicate()
	for k: String in u.passives:
		a.merge(_pas(u, k).get("ability_mod", {}), true)
	var power := maxf(0.0, 1.0 + stat(u, "moc"))
	for f: String in a.get("power", []):
		if a.has(f):
			a[f] = float(a[f]) * power
	if a.has("cooldown"):
		a["cooldown"] = float(a["cooldown"]) / maxf(0.1, 1.0 + stat(u, "pohotovost"))
	return a


## Why the ability cannot be used now ("" = it can). For the UI hint.
func ability_problem(id: String) -> String:
	var u := by_id(id)
	if u == null or not u.alive() or u.ability == "":
		return "The hero has no ability."
	if u.uses <= 0:
		return "The ability is spent for this battle."
	if u.ability_cd > 0.0:
		return "The ability is recharging (%d s)." % ceili(u.ability_cd)
	return ""


## Can the ability be used (regardless of target)?
func can_use_ability(id: String) -> bool:
	var u := by_id(id)
	if u == null or u.side != SIDE_KNIGHT or not u.alive() or u.ability == "" or over != "" or u.dashing:
		return false
	return u.uses > 0 and u.ability_cd <= 0.0


## Ability target kind: "none", "point" (a spot on the ground), "enemy".
func ability_target(id: String) -> String:
	return String(ability_of(id).get("target", "none"))


## Why this target is not possible ("" = it is).
func ability_target_problem(id: String, target: Variant) -> String:
	var u := by_id(id)
	var a := ability_of(id)
	match String(a.get("target", "none")):
		"point":
			if not target is Vector2:
				return "Choose a spot."
			var p: Vector2 = target
			if u.pos.distance_to(p) > float(a.get("range", INF)):
				return "Too far (at most %d m)." % int(a["range"])
			if a.get("land", false) and _in_water(p):
				return "Can't go into the water."
		"enemy":
			var e := by_id(String(target)) if target is String else null
			if e == null or e.side != SIDE_FOE or not e.alive():
				return "Choose an enemy."
			if u.pos.distance_to(e.pos) > float(a.get("range", INF)):
				return "Too far (at most %d m)." % int(a["range"])
	return ""


## When the ability would make sense and on what (a simple hint; used by tests and auto-play).
## Returns [yes/no, target].
func ability_hint(id: String) -> Array:
	var u := by_id(id)
	if not can_use_ability(id):
		return [false, null]
	var a := ability_of(id)
	var foes := living(SIDE_FOE)
	if (u.ability == "najezd" or u.ability == "uder") and u.hp < u.maxhp * _ord("hint_dive_hp", 0.6):
		return [false, null]   # hint: a wounded hero does not throw himself among enemies again
	match u.ability:
		"vyzva":
			var n := 0
			for f in foes:
				if f.pos.distance_to(u.pos) <= float(a["radius"]):
					n += 1
			return [n >= 2, null]
		"pozehnani":
			# best spot: the centre of the hero with the most wounded around him
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
				# hint: stun a commander who is winding up
				for f in foes:
					if f.casting and f.pos.distance_to(u.pos) <= float(a["range"]) and not (a.get("land", false) and _in_water(f.pos)):
						return [true, f.pos]
				if mode == "obrana":
					return [false, null]   # hint: no sallies in defense, Charge only against a commander
			for f in foes:
				if f.pos.distance_to(u.pos) > float(a["range"]) or (a.get("land", false) and _in_water(f.pos)):
					continue
				if f.asleep or _near_sleeper(f.pos):
					continue   # hint: do not wake a sleeping group with an ability
				if u.ability == "najezd" and (not _near_other_knight(u, f.pos) or _outnumbered(u, f.pos)):
					continue   # hint: Charge only where someone from the squad is already fighting (not alone into superior numbers)
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
			if mode == "obrana":
				return [false, null]   # hint: no sallies in defense
			var pick: Unit = null
			for f in foes:
				if f.pos.distance_to(u.pos) <= float(a["range"]) and (f.ranged or f.hp < f.maxhp * 0.4) and not f.asleep and not _near_sleeper(f.pos) and _near_other_knight(u, f.pos) and not _outnumbered(u, f.pos):
					pick = f
					break
			return [pick != null, pick.id if pick != null else null]
	return [false, null]


## Hint: is there a sleeping group near the spot? (the ability would wake it; within its `wake` + 2 m)
func _near_sleeper(p: Vector2) -> bool:
	for f in living(SIDE_FOE):
		if f.asleep and f.pod >= 0 and f.pod < pods.size():
			var wake := float((pods[f.pod] as Dictionary).get("wake", scenario.get("wake_radius", 7.0)))
			if f.pos.distance_to(p) <= wake + 2.0:
				return true
	return false


## Hint: are there more enemies than heroes at the spot (not counting whoever would leap there)? No leaping into superior numbers.
func _outnumbered(u: Unit, p: Vector2) -> bool:
	var r := _ord("hint_support", 5.0)
	var foes := 0
	for f in living(SIDE_FOE):
		if not f.asleep and f.pos.distance_to(p) <= r:
			foes += 1
	var mates := 0
	for k in living(SIDE_KNIGHT):
		if k != u and k.pos.distance_to(p) <= r:
			mates += 1
	return foes > mates + 1


## Hint: is another hero near the spot (within `hint_support` m)? A leap or Charge must not take a lone hero into superior numbers.
func _near_other_knight(u: Unit, p: Vector2) -> bool:
	for k in living(SIDE_KNIGHT):
		if k != u and k.pos.distance_to(p) <= _ord("hint_support", 5.0):
			return true
	return false


## When the next wave comes (INF = none).
func next_wave_t() -> float:
	var best := INF
	for p in pending:
		best = minf(best, p.arrive_t)
	return best


## Uses the hero's ability (takes a use, starts the recharge). Returns false when not possible.
func use_ability(id: String, target: Variant = null) -> bool:
	if not can_use_ability(id) or ability_target_problem(id, target) != "":
		return false
	var u := by_id(id)
	var a := ability_of(id)
	var conflict := ability_oath_conflict(id, target)
	if conflict != "":
		_break(u, conflict)
	u.uses -= 1
	u.ability_cd = float(a.get("cooldown", 0.0))
	abilities_used += 1
	_after_ability(u)
	var where: Vector2 = u.pos
	match u.ability:
		"vyzva":
			u.taunt_t = float(a["duration"])
		"pozehnani":
			where = target
			_bless(u, where, a, float(a["heal_frac"]))
		"salva":
			where = target
			_volley(u, where, float(a["radius"]), a, 1.0)
		"najezd":
			where = target
			_start_dash(u, target, a, 1.0)
		"uder":
			var e := by_id(String(target))
			where = e.pos
			_shadow_strike(u, e, float(a["mult"]))
	events.append({"type": "ability", "id": u.id, "key": u.ability, "pos": where})
	_log("%s: %s" % [u.name, a["name"]], true)
	return true


## Blessing: heals heroes in a circle around `where` by `frac` of their health (shield from Blessed Armor).
func _bless(u: Unit, where: Vector2, a: Dictionary, frac: float) -> void:
	for k in living(SIDE_KNIGHT):
		if k.pos.distance_to(where) <= float(a["radius"]) and not _no_heal(k) and not (k == u and _no_self_heal(u)):
			_heal(u, k, k.maxhp * frac)
			if a.has("shield_t"):
				k.shield_t = float(a["shield_t"])
				k.shield = float(a["shield"])


## Volley: arrows randomly among enemies in the circle (mult = combo multiplier), Fire Volley sets the ground alight.
func _volley(u: Unit, where: Vector2, radius: float, a: Dictionary, mult: float) -> void:
	var hits: Array[Unit] = []
	for f in living(SIDE_FOE):
		if f.pos.distance_to(where) <= radius:
			hits.append(f)
	for i in int(a["arrows"]):
		if hits.is_empty():
			break
		var f: Unit = hits[_rng.randi() % hits.size()]
		_ability_hit(u, f)
		_hurt(u, f, float(a["dmg"]) * mult * _dmg_mult(u, f, true) * (u.vs_mounted if f.mounted else 1.0))
		if not f.alive():
			hits.erase(f)
	if a.has("fire_t"):
		zones.append({"pos": where, "r": radius, "t": float(a["fire_t"]), "dps": float(a["fire_dps"]), "from": u.id})


## Charge to a point (mult = stronger from a combo).
func _start_dash(u: Unit, target: Vector2, a: Dictionary, mult: float) -> void:
	u.dashing = true
	u.dash_to = target
	u.dash_hit.clear()
	u.dash_mult = mult
	u.dash_t = u.pos.distance_to(target) / maxf(u.speed * float(a["speed_mult"]), 0.1) + 0.3


## Shadow Strike: leap behind an enemy and strike for `mult` × attack (mult already includes Power).
## Hunting Pair: marks the target for the archer.
func _shadow_strike(u: Unit, e: Unit, mult: float) -> void:
	var dir := (e.pos - u.pos).normalized()
	var behind := e.pos + dir * (e.radius + u.radius)
	if not _in_water(behind):
		u.pos = behind
	_face_to(u, e)
	u.focus_id = e.id
	u.focus_t = _ord("focus_time", 3.0)
	u.atk = 0.25
	u.combat_t = t
	_ability_hit(u, e)
	_hurt(u, e, u.dmg * mult * _dmg_mult(u, e))
	if not _pas(u, "ukryt").is_empty():
		u.hidden_t = float(_pas(u, "ukryt")["hidden_t"])
	var p := _partner(u)
	if p != null and u.bond_type == "lovci" and e.alive():
		e.marked_by = p.id
		e.mark_t = float(_bond_def(u).get("mark_t", 5.0))


# --------------------------------------------------------------- bond combos

## Combos the squad has now (bond of at least combo_level and the abilities form a pair), in card order:
## [{id, name, a (id of the hero with ability a), b, key ("Q"/"E"), aim, desc}]. At most 2.
func combos() -> Array:
	var out: Array = []
	var cdefs: Dictionary = units_data.get("combos", {})
	var need := int((units_data.get("bond_rules", {}) as Dictionary).get("combo_level", 2))
	var seen := {}
	for u in knights():
		if u.bond_with == "" or u.bond_level < need or seen.has(u.id):
			continue
		var p := by_id(u.bond_with)
		if p == null or p.bond_with != u.id:
			continue
		seen[u.id] = true
		seen[p.id] = true
		for cid: String in cdefs:
			if cid.begins_with("_"):
				continue
			var c: Dictionary = cdefs[cid]
			var ha: Unit = null
			var hb: Unit = null
			if u.ability == c["a"] and p.ability == c["b"]:
				ha = u
				hb = p
			elif p.ability == c["a"] and u.ability == c["b"]:
				ha = p
				hb = u
			if ha != null and out.size() < 2:
				out.append({"id": cid, "name": c["name"], "a": ha.id, "b": hb.id, "key": ["Q", "E"][out.size()], "aim": c.get("aim", "none"), "desc": c.get("desc", "")})
				break
	return out


func _combo(cid: String) -> Dictionary:
	for c: Dictionary in combos():
		if c["id"] == cid:
			return c
	return {}


## Why the combo is not possible now ("" = it is): both alive, both abilities ready, close enough.
func combo_problem(cid: String) -> String:
	var c := _combo(cid)
	if c.is_empty() or over != "":
		return "The squad has no such combo now."
	var ha := by_id(c["a"])
	var hb := by_id(c["b"])
	for h: Unit in [ha, hb]:
		if not h.alive():
			return "%s has fallen." % h.name
		if not can_use_ability(h.id):
			return "%s: %s" % [h.name, ability_problem(h.id)]
	var cd: Dictionary = units_data["combos"][cid]
	if ha.pos.distance_to(hb.pos) > float(cd.get("max_gap", 14.0)):
		return "%s and %s are too far apart (at most %d m)." % [ha.name, hb.name, int(cd.get("max_gap", 14.0))]
	if cid == "za_zady" and _taunted_victim(ha) == null:
		return "There is no enemy at the tank (%s)." % ha.name
	return ""


## The hero whose ability aims the combo (aim = point), otherwise "".
func combo_aimer(cid: String) -> String:
	var c := _combo(cid)
	if c.is_empty() or String(c["aim"]) != "point":
		return ""
	var by := String(units_data["combos"][cid].get("aim_by", ""))
	return c["a"] if by_id(c["a"]).ability == by else c["b"]


func combo_target_problem(cid: String, target: Variant) -> String:
	var aimer := combo_aimer(cid)
	if aimer == "":
		return ""
	return ability_target_problem(aimer, target)


## Fires a combo: both abilities at once, one use of each. Returns false when not possible.
func use_combo(cid: String, target: Variant = null) -> bool:
	if combo_problem(cid) != "" or combo_target_problem(cid, target) != "":
		return false
	var c := _combo(cid)
	var cd: Dictionary = units_data["combos"][cid]
	var ha := by_id(c["a"])
	var hb := by_id(c["b"])
	var aa := ability_of(ha.id)
	var ab := ability_of(hb.id)
	for h: Unit in [ha, hb]:
		var conflict := ability_oath_conflict(h.id, null)
		if conflict != "":
			_break(h, conflict)
		var ha_a := ability_of(h.id)
		h.uses -= 1
		h.ability_cd = float(ha_a.get("cooldown", 0.0))
		abilities_used += 1
		_after_ability(h)
	var where: Vector2 = ha.pos
	match cid:
		"navnada":
			ha.taunt_t = float(aa["duration"])
			_volley(hb, ha.pos, float(cd.get("radius", 3.5)), ab, float(cd.get("dmg_mult", 1.5)))
		"za_zady":
			ha.taunt_t = float(aa["duration"])
			var e := _taunted_victim(ha)
			if e != null:
				_shadow_strike(hb, e, float(cd.get("mult", 4.0)) * maxf(0.0, 1.0 + stat(hb, "moc")))
				where = e.pos
		"stit_a_kopi":
			ha.taunt_t = float(aa["duration"])
			_start_dash(hb, ha.pos, ab, float(cd.get("dmg_mult", 1.5)))
		"posvecene_sipy":
			where = target
			_volley(ha, where, float(aa["radius"]), aa, float(cd.get("dmg_mult", 1.3)))
			var bless := ab.duplicate()
			bless["radius"] = float(cd.get("heal_radius", 4.0))
			bless.erase("shield_t")
			_bless(hb, where, bless, float(cd.get("heal_frac", 0.1)) * maxf(0.0, 1.0 + stat(hb, "moc")))
		"kladivo":
			where = target
			_start_dash(ha, target, aa, 1.0)
			ha.combo_strike = hb.id
	events.append({"type": "ability", "id": ha.id, "key": ha.ability, "pos": where})
	events.append({"type": "ability", "id": hb.id, "key": hb.ability, "pos": where})
	events.append({"type": "combo", "id": cid, "pos": where})
	_log("Combo %s: %s and %s" % [cd["name"], ha.name, hb.name], true)
	return true


## From Behind: an enemy at the tank (within Challenge range), preferably one attacking him.
func _taunted_victim(tank: Unit) -> Unit:
	var r := float(ability_of(tank.id).get("radius", 6.0))
	var on_him: Array[Unit] = []
	var near: Array[Unit] = []
	for f in living(SIDE_FOE):
		if f.asleep or f.fleeing or f.pos.distance_to(tank.pos) > r:
			continue
		near.append(f)
		if f.target_id == tank.id:
			on_him.append(f)
	return _nearest(on_him if not on_him.is_empty() else near, tank.pos)


# =============================================================== player commands

func has_trait(u: Unit, key: String) -> bool:
	return u.traits.has(key)


func _trait_value(u: Unit, field: String, default: Variant) -> Variant:
	var all: Dictionary = units_data.get("traits", {})
	for k: String in u.traits:
		var tr: Dictionary = all.get(k, {})
		if tr.has(field):
			return tr[field]
	return default


## The All In! command: one-time, only when enemy morale is broken. All heroes attack.
func can_charge() -> bool:
	return over == "" and foes_broken and not charging


func charge_all() -> bool:
	if not can_charge():
		return false
	charging = true
	_log("All In! Every hero finishes the fight", true)
	return true


# --------------------------------------------------------------- hero orders

## Why the order cannot be given ("" = it can). kind: "point" (Vector2 target), "group" (group number or enemy id),
## "ally" (hero id), "" (cancel: the hero holds where he stands). Orders can be given at any time.
func order_problem(id: String, kind: String = "", target: Variant = null) -> String:
	var u := by_id(id)
	if u == null or u.side != SIDE_KNIGHT or not u.alive():
		return "Unknown hero."
	if u.rage_t > 0.0:
		return "%s rages for his fallen companion and will not listen." % u.name
	if bool(oath_of(id).get("ignores_orders", false)) and _grudge_target(u) != null:
		return "%s is bound by Blood Debt and will not obey." % u.name
	match kind:
		"point":
			if not target is Vector2:
				return "Choose a spot."
			if _in_water(target):
				return "Can't go into the water."
		"group":
			var g := _group_arg(target)
			if g < 0 or group_members(g).is_empty():
				return "Choose an enemy."
		"ally":
			var a := by_id(String(target)) if target is String else null
			if a == null or a == u or a.side != SIDE_KNIGHT or not a.alive():
				return "Choose another hero."
	return ""


func _group_arg(target: Variant) -> int:
	if target is int:
		return target
	if target is float:
		return int(target)
	if target is String:
		return group_of(target)
	return -1


## Gives the hero an order. Returns false when not possible (order_problem).
func set_order(id: String, kind: String, target: Variant = null) -> bool:
	if order_problem(id, kind, target) != "":
		return false
	var u := by_id(id)
	var conflict := order_oath_conflict(id, kind, target)
	if conflict != "" and t > 0.0:
		_break(u, conflict)
	if t > 0.0:
		u.orders_given += 1
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


## Move order (dragging a hero): same as an order to a place.
func order_move(id: String, target: Vector2) -> bool:
	return set_order(id, "point", target)


## The hero's order for the player ("To a place", "At group: Brigands (5)"…).
func order_text(id: String) -> String:
	var u := by_id(id)
	if u == null:
		return ""
	var names: Dictionary = units_data.get("orders", {}).get("names", {})
	match u.order:
		"point":
			return String(names.get("point_done" if u.order_done else "point", "To a place"))
		"group":
			if u.order_done:
				return String(names.get("group_done", "Group fell, holds place"))
			return "%s: %s" % [names.get("group", "At group"), group_name(u.order_group)]
		"ally":
			var a := by_id(u.order_ally)
			if u.order_done or a == null:
				return String(names.get("ally_done", "Ally fell, holds place"))
			return "%s: %s" % [names.get("ally", "With ally"), a.name]
	return String(names.get("none", "No order: holds place"))


## Heroes without orders (names). The scene warns before the battle.
func unordered() -> Array:
	var out: Array = []
	for k in living(SIDE_KNIGHT):
		if k.order == "":
			out.append(k.name)
	return out


## Squad leader for the automatic commander: the toughest fighter (not a healer, not ranged).
func _auto_lead() -> Unit:
	var lead: Unit = null
	for k in living(SIDE_KNIGHT):
		if k.heal <= 0.0 and not k.ranged and (lead == null or k.maxhp > lead.maxhp):
			lead = k
	return lead


## A simple commander for tests and auto-play: the leader goes at the nearest group,
## the others stay with him. In defense (and while awake enemies fight, when the scenario advises `auto_plan: "hold"`)
## the leader holds his place. Returns {id: [kind, target]}.
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
		# nearest group; melee preferred only at a similar distance (a lone bowman beyond the river can wait)
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


## Automatic commander (tests, auto-play): when the leader's plan changes (a group fell, another woke…),
## gives the squad new orders. The player does this himself.
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


## Gives all heroes orders from a dictionary {id: [kind, target]} (e.g. from suggest_orders).
func apply_orders(orders: Dictionary) -> void:
	for id: String in orders:
		var o: Array = orders[id]
		set_order(id, String(o[0]), o[1] if o.size() > 1 else null)


## Is the order a retreat for the hero? (takes him more than 1 m farther from the nearest enemy)
func is_retreat(id: String, target: Vector2) -> bool:
	var u := by_id(id)
	var foe := _nearest(living(SIDE_FOE), u.pos)
	if foe == null:
		return false
	return target.distance_to(foe.pos) > u.pos.distance_to(foe.pos) + 1.0


func break_oath(id: String) -> void:
	_break(by_id(id), "")


## Breaks the oath: it stops applying, the house loses glory (`break_glory_cost`). why = reason (for the battle log).
func _break(u: Unit, why: String) -> void:
	if u == null:
		return
	var o := oath_of(u.id)
	if o.is_empty():
		return
	u.oath_broken = true
	glory = maxf(0.0, glory - (u.oath_cost if u.oath_cost >= 0.0 else float(o.get("break_glory_cost", 0.0))))
	_apply_passives_keep_hp(u)
	_log("%s broke his oath %s%s" % [u.name, o["name"], (" (" + why + ")") if why != "" else ""], true)
	events.append({"type": "oath_broken", "id": u.id, "text": why})


## Who takes part of the hero's damage (Oath of Protection): a tank with the oath whose ward is within `ward_radius` m.
func _warden_of(tg: Unit) -> Unit:
	for k in living(SIDE_KNIGHT):
		if k != tg and k.ward == tg.id and has_oath(k.id):
			var o := oath_of(k.id)
			if o.has("ward_share") and k.pos.distance_to(tg.pos) <= float(o.get("ward_radius", 3.0)):
				return k
	return null


## Ward for the Oath of Protection: chosen (setup.wards), otherwise the priest, otherwise the ally with the least health.
func _pick_ward(u: Unit, chosen: String) -> void:
	u.ward = ""
	if not oath_of(u.id).has("ward_share"):
		return
	var c := by_id(chosen)
	if c != null and c != u and c.side == SIDE_KNIGHT:
		u.ward = c.id
		return
	var best: Unit = null
	for k in knights():
		if k == u:
			continue
		if k.heal > 0.0:
			best = k
			break
		if best == null or k.maxhp < best.maxhp:
			best = k
	u.ward = best.id if best != null else ""


## Oaths watched continuously: Under the Banner (alone), Never Stand Still (standing without fighting), Oath of the Standard (away from the tank).
func _watch_oaths(u: Unit, dt: float) -> void:
	var o := oath_of(u.id)
	if o.is_empty():
		return
	if o.has("alone_break"):
		u.alone_t = 0.0 if _when_ok(u, o, null) else u.alone_t + dt
		if u.alone_t > float(o["alone_break"]):
			_break(u, "was left alone")
			return
	if o.has("idle_break"):
		var awake := false
		for f in living(SIDE_FOE):
			awake = awake or (not f.asleep and not f.fleeing)
		var busy := u.moving or u.dashing or t - u.combat_t <= 1.0
		u.idle_t = 0.0 if busy or not awake else u.idle_t + dt
		if u.idle_t > float(o["idle_break"]):
			_break(u, "stood still")
			return
	if o.has("leash_to"):
		var lead: Unit = null
		for k in living(SIDE_KNIGHT):
			if k.key == String(o["leash_to"]) and k != u:
				lead = k
		var far := lead != null and lead.pos.distance_to(u.pos) > float(o.get("leash_radius", 8.0))
		u.away_t = u.away_t + dt if far else 0.0
		if u.away_t > float(o.get("leash_grace", 2.0)):
			_break(u, "strayed from %s" % lead.name)


## End of a won battle: the Oath of the Ancestors wants the hero to have killed someone himself.
func _end_oaths() -> void:
	# Rivals: whoever killed more brings the house extra glory
	for k in living(SIDE_KNIGHT):
		var p := _partner(k)
		if p != null and k.bond_type == "souperi" and k.kills > p.kills:
			_gain_glory(float(_bond_def(k).get("rival_glory", 15)), k)
			_log("Rivals: %s killed more than %s" % [k.name, p.name], false)
	for k in living(SIDE_KNIGHT):
		if bool(oath_of(k.id).get("needs_kill", false)) and k.kills == 0:
			_break(k, "killed no one in the battle")


## Recalculates stats mid-battle (keeps the health fraction and remaining uses).
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


## The river crossing x lies in (or an empty dictionary).
func _crossing_at(x: float) -> Dictionary:
	for c: Dictionary in crossings:
		if x >= float(c["x0"]) and x <= float(c["x1"]):
			return c
	return {}


## The best crossing for a path from x_from to x_to.
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


## Terrain speed multiplier (ford, forest; a forest trail does not slow).
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


## A step in the band by the bank does not lead deeper into the river.
func _not_deeper(old: Vector2, p: Vector2) -> bool:
	var mid := (river_lo + river_hi) / 2.0
	if old.y >= mid:
		return p.y >= old.y - 0.001
	return p.y <= old.y + 0.001


func _in_water(p: Vector2) -> bool:
	return p.y > river_lo - 0.3 and p.y < river_hi + 0.3 and _crossing_at(p.x).is_empty()


## Where to go so the unit gets to the target across the river (by the best crossing).
func _nav(u: Unit, target: Vector2) -> Vector2:
	var us := _band(u.pos.y)
	var ts := _band(target.y)
	var here := _crossing_at(u.pos.x)
	if us == 1 and ts == 1 and not here.is_empty():
		var there := _crossing_at(target.x)
		if there.is_empty() or float(there["x0"]) != float(here["x0"]):
			# both in the river band but at different crossings (footbridge and ford): first out onto the bank nearer the target
			var mid := (river_lo + river_hi) / 2.0
			var exit_y := river_lo - 0.5 if target.y < mid else river_hi + 0.5
			return Vector2(clampf(u.pos.x, float(here["x0"]) + 0.35, float(here["x1"]) - 0.35), exit_y)
	if us == ts or (us == 1 and not here.is_empty()):
		if us == 1 and ts != 1:
			return Vector2(clampf(u.pos.x, float(here["x0"]) + 0.35, float(here["x1"]) - 0.35), river_lo - 0.5 if ts == 0 else river_hi + 0.5)
		return target
	var c := _best_crossing(u.pos.x, target.x)
	if ts == 1 and not _crossing_at(target.x).is_empty():
		c = _crossing_at(target.x)   # the target stands in a crossing: go through that crossing
	var x0 := float(c["x0"]) + 0.35
	var x1 := float(c["x1"]) - 0.35
	if u.pos.x >= x0 - 0.1 and u.pos.x <= x1 + 0.1 and u.pos.y >= river_lo - 0.7 and u.pos.y <= river_hi + 0.7:
		return Vector2(clampf(u.pos.x, x0, x1), river_hi + 0.5 if us == 0 else river_lo - 0.5)
	return Vector2(clampf(u.pos.x, x0, x1), river_lo - 0.6 if us == 0 else river_hi + 0.6)


func _walk(u: Unit, target: Vector2, dt: float, stop: float = 0.0) -> void:
	if _no_move(u):
		u.moving = false
		return
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
	u.moved_t = t
	if _in_water(u.pos) and _in_water(old) and _not_deeper(old, u.pos):
		return   # already standing in the band by the bank (pushed): may move along the bank or out, not deeper
	if _in_water(u.pos):
		# does not get stuck at the bank: tries to slide along it (only along x, or only along y)
		u.pos = old + Vector2(step_v.x, 0.0)
		if _in_water(u.pos):
			u.pos = old + Vector2(0.0, step_v.y)
			if _in_water(u.pos):
				u.pos = old + Vector2(0.0, -absf(step_v.x) if old.y < river_lo else absf(step_v.x))
				if _in_water(u.pos):
					u.pos = old


## Avoidance: when a unit of the same side stands in the way (within `avoid_look` m ahead), the direction turns aside
## so allies walk around each other instead of through. Enemies are not avoided (one goes there to fight).
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
		out = dir * 0.1 + steer.normalized()   # never backs off, only steps aside
	return out.normalized()


func _face_to(u: Unit, tg: Unit) -> void:
	var v := tg.pos - u.pos
	if v.length() > 0.0001:
		u.face = v.normalized()


func _attack(u: Unit, tg: Unit) -> void:
	_face_to(u, tg)
	if not _oath_allows(u, tg):
		return   # the oath forbids this target: no attack
	u.combat_t = t
	if u.t > 0.0:
		return
	u.first_struck = true
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


## glory_hit = false: damage that gives no glory per hit (fire and other lasting effects).
func _hurt(att: Unit, tg: Unit, raw: float, glory_hit: bool = true) -> void:
	if not tg.alive():
		return
	if tg.side == SIDE_KNIGHT:
		var sb := _shield_bearer(tg)
		if not sb.is_empty():
			var guard: Unit = sb[0]
			var share: float = sb[1]
			guard.hp -= raw * share * _taken_mult(guard)
			guard.hit = 0.18
			raw *= 1.0 - share
			if guard.hp <= 0.0:
				guard.hp = 0.01   # does not die for his ward, the damage just stops being shared
	tg.hp -= raw * _taken_mult(tg)
	tg.hit = 0.18
	tg.combat_t = t
	if tg.side == SIDE_KNIGHT and att != null and att.side == SIDE_FOE:
		grudges[att.id] = true
	var sw := _pas(tg, "druhy_dech")
	if tg.side == SIDE_KNIGHT and tg.hp > 0.0 and not sw.is_empty() and not tg.second_wind_used and tg.hp < tg.maxhp * float(sw["at"]):
		tg.second_wind_used = true
		_heal(tg, tg, tg.maxhp * float(sw["heal_frac"]))
		_log("%s: Second Wind" % tg.name, false)
	if att != null and att.side == SIDE_KNIGHT and glory_hit:
		_gain_glory(float(house["glory"]["per_hit"]), att)
	if tg.hp > 0.0:
		return
	tg.hp = 0.0
	events.append({"type": "death", "id": tg.id})
	if tg.side == SIDE_FOE:
		if att != null and att.side == SIDE_KNIGHT:
			_gain_glory(float(house["glory"]["per_kill"]), att)
			att.kills += 1
		if tg.key == str(scenario["optional_task"].get("kill", "")):
			task_ok = true
		if tg.leader:
			_log("%s has fallen!" % tg.name, true)
			_break_morale()
		return
	# Last Rites: a nearby priest raises the fallen once per battle
	for k in living(SIDE_KNIGHT):
		var pp := _pas(k, "posledni_pomazani")
		if k != tg and not pp.is_empty() and not k.revive_used and k.pos.distance_to(tg.pos) <= float(pp["radius"]):
			k.revive_used = true
			tg.hp = tg.maxhp * float(pp["revive_frac"])
			events.erase(events[-1])
			events.append({"type": "heal", "id": tg.id})
			_log("%s raised the fallen: %s" % [k.name, tg.name], true)
			return
	_log("%s has fallen" % tg.name, true)
	_grieve(tg)
	var martyr := oath_of(tg.id)
	if martyr.has("martyr_radius"):
		for k in living(SIDE_KNIGHT):
			if k.pos.distance_to(tg.pos) <= float(martyr["martyr_radius"]) and not _no_heal(k):
				k.hp = k.maxhp
				events.append({"type": "heal", "id": k.id})
		_log("%s fell as a martyr and healed his companions" % tg.name, true)
	for k in living(SIDE_KNIGHT):
		if not _pas(k, "mstitel").is_empty():
			k.avenger = true
		if k.ward == tg.id and has_oath(k.id) and oath_of(k.id).has("ward_share"):
			_break(k, "%s fell" % tg.name)
	var protect: String = scenario["optional_task"].get("protect", "")
	if tg.id == protect or protect == "all":
		task_ok = false


## Attack the target, or walk to it (stop = how close).
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


## Walk to a place; a knight with Never Retreat does not go where he would be farther from the enemy.
## Resting spot (behind the squad, beside the squad…): whoever stands still and is close stays put.
## He moves off only once the spot moves more than `settle` m away. Without this heroes jitter
## (step, stop, step), because their spots are computed from one another.
func _settle(u: Unit, p: Vector2, dt: float, stop: float, foes: Array[Unit]) -> void:
	if not u.moving and u.pos.distance_to(p) <= stop + _ord("settle", 1.0):
		return
	_go(u, p, dt, stop, foes)


func _go(u: Unit, p: Vector2, dt: float, stop: float, _foes: Array[Unit]) -> void:
	if u.pos.distance_to(p) <= stop:
		u.moving = false
		return
	if _no_retreat(u):
		var f := _nearest(living(SIDE_FOE), u.pos)   # the direction to the enemy counts the sleeping ones too
		if f != null and p.distance_to(f.pos) > u.pos.distance_to(f.pos) + 0.3:
			u.moving = false
			return
	_walk(u, p, dt, stop)


func _knight_think(u: Unit, dt: float) -> void:
	_watch_oaths(u, dt)
	_priest_heal(u, dt)
	# A hero does not attack sleeping groups on his own (not even a ranged one from afar); they wake when approached or by a group order.
	var all_foes := living(SIDE_FOE)
	var foes: Array[Unit] = []
	for f in all_foes:
		if not f.asleep:
			foes.append(f)
	if u.dashing:
		_dash(u, dt, all_foes)   # Charge hits everyone in the way
		return
	# Brothers in Arms grief: rages, goes for the nearest and ignores orders
	if u.rage_t > 0.0 and not foes.is_empty():
		var rt := _nearest(foes, u.pos)
		if rt != null:
			_engage(u, rt, dt)
			return
	# Lance and Shield: tank below the health threshold, the cavalier rides to his aid on his own
	if u.bond_type == "kopi" and _bond_side(u) == 0:
		var tk := _partner(u)
		if tk != null and not u.rescue_used and tk.hp < tk.maxhp * float(_bond_def(u).get("rescue_at", 0.25)):
			u.rescue_used = true
			u.rescue_t = float(_bond_def(u).get("rescue_t", 4.0))
			_log("%s rushes to help: %s" % [u.name, tk.name], true)
		if u.rescue_t > 0.0 and tk != null:
			u.rescue_t -= dt
			var foes_on: Array[Unit] = []
			for f in foes:
				if f.target_id == tk.id:
					foes_on.append(f)
			if not _fight_close(u, dt, foes_on):
				_walk(u, tk.pos, dt, 2.0)
			return
	if has_oath(u.id):
		var nf := _nearest(foes, u.pos)
		if nf != null and u.pos.distance_to(nf.pos) <= u.reach + 0.3:
			_gain_glory(float(house["glory"]["oath_per_second"]) * dt, u)
	# All In! or a decided battle: everyone attacks.
	if (charging or decided != "") and not foes.is_empty():
		var ct := _choose_target(u, foes)
		if ct != null:
			_engage(u, ct, dt)
			return
	# After Shadow Strike and Charge keeps fighting the target (at most `focus_time` s, while it lives and is near), then returns to the order.
	if u.focus_id != "":
		var fo := by_id(u.focus_id)
		u.focus_t -= dt
		if fo == null or not fo.alive() or fo.fleeing or u.focus_t <= 0.0 or fo.pos.distance_to(u.pos) > u.reach + _ord("focus_leash", 4.0):
			u.focus_id = ""
		else:
			u.regroup = false
			_engage(u, fo, dt)
			return
	# Blood Debt: while whoever wounded an ally lives, he goes after him and orders do not apply.
	if bool(oath_of(u.id).get("ignores_orders", false)):
		var gt := _grudge_target(u)
		if gt != null:
			_engage(u, gt, dt)
			return
	match u.order:
		"point":
			_order_point(u, dt, foes)
		"group":
			_order_group(u, dt, all_foes)
		"ally":
			_order_ally(u, dt, foes)
		_:
			_hold_place(u, dt, foes)


## Nearest living enemy who wounded an ally (Blood Debt).
func _grudge_target(u: Unit) -> Unit:
	var list: Array[Unit] = []
	for f in living(SIDE_FOE):
		if grudges.has(f.id) and not f.fleeing:
			list.append(f)
	return _nearest(list, u.pos)


## Order done: the hero holds the place where he stands.
func _done(u: Unit) -> void:
	u.order_done = true
	u.home = u.pos


## Fights whoever from `foes` is next to him (melee within reach + `on_way`, ranged within `on_way_ranged`).
## Returns true when fighting.
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


## To a place: walks there without fighting (that is how the player pulls a hero out of combat), then holds the place.
func _order_point(u: Unit, dt: float, foes: Array[Unit]) -> void:
	if u.order_done:
		_hold_place(u, dt, foes)
		return
	var d := u.pos.distance_to(u.order_pos)
	var taken := false   # another hero already stands at the spot: it is enough to reach him
	for k in living(SIDE_KNIGHT):
		if k != u and k.pos.distance_to(u.order_pos) <= 1.0:
			taken = true
	if d <= 0.4 or (taken and d <= 2.0):
		u.moving = false
		_done(u)
		return
	_go(u, u.order_pos, dt, 0.3, foes)
	if not u.moving:
		_done(u)   # arrived, or may not go further (Never Retreat): holds where he stands


## At a group: follows the group (even if it moves) and fights its members (and defends against whoever attacks him on the way);
## when the group falls, holds his place.
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
	# defends against whoever attacks him on the way (pulling out of combat is done with an order to a place)
	var attackers: Array[Unit] = []
	for f in foes:
		if f.target_id == u.id and not f.asleep:
			attackers.append(f)
	if _fight_close(u, dt, attackers):
		return
	var tg := _choose_target(u, mem)
	if tg == null:
		_hold_place(u, dt, foes)   # the oath allows no target from the group
		return
	if u.ranged:
		if u.pos.distance_to(tg.pos) <= u.reach:
			u.moving = false
			_attack(u, tg)
		else:
			_walk(u, tg.pos, dt, u.reach * 0.9)
		return
	_engage(u, tg, dt)


## With an ally: stays by him (ranged and healer a bit behind) and fights whoever threatens the ally.
## A healer joins in only when no one in healing range needs healing, otherwise he only defends himself.
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
	if u.bond_type == "souperi" and u.bond_with == a.id and a.hp < a.maxhp * float(_bond_def(u).get("no_help_below", 0.3)):
		helps = false   # Rivals: does not help the companion below 30 % health
	var dist := _ord("ally_dist_back", 4.0) if (u.ranged or u.heal > 0.0) else _ord("ally_dist", 2.0)
	var gap := u.pos.distance_to(a.pos)
	if not u.ranged and gap > dist + guard + _ord("ally_leash", 0.5):
		u.regroup = true
	if u.regroup and gap <= dist + 0.5:
		u.regroup = false
	if u.regroup:
		# strayed (e.g. after a Charge): goes all the way back to the ally without stopping on the way
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


## Does anyone within the healer's range need healing?
func _needs_heal(u: Unit) -> bool:
	for k in living(SIDE_KNIGHT):
		if k.hp < k.maxhp * 0.85 and k.pos.distance_to(u.pos) <= u.heal_range:
			return true
	return false


## Holds `home`: fights whoever comes within `hold_radius` m of the spot and defends against whoever
## attacks him within twice that; a ranged hero shoots at range. Then returns to the spot.
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


## Is the priest in combat? (an awake enemy within `heal_combat` m). He does not heal on his own between groups.
func _in_combat(u: Unit) -> bool:
	for f in living(SIDE_FOE):
		if not f.asleep and not f.fleeing and f.pos.distance_to(u.pos) <= u.heal_combat:
			return true
	return false


## The priest heals the most wounded hero in range, only in combat.
func _priest_heal(u: Unit, dt: float) -> void:
	if u.heal > 0.0:
		u.heal_t -= dt
		if u.heal_t <= 0.0 and u.mourn_t <= 0.0 and _in_combat(u):
			var best: Unit = null
			for k in living(SIDE_KNIGHT):
				if k.hp < k.maxhp * 0.85 and k.pos.distance_to(u.pos) <= u.heal_range and not _no_heal(k) and not (k == u and _no_self_heal(u)):
					if best == null or k.hp / k.maxhp < best.hp / best.maxhp:
						best = k
			if best != null:
				_heal(u, best, u.heal)
				u.heal_t = u.heal_cd


## Charge hit and oaths: Knightly Challenge is kept when the Charge hits a commander (even if it knocks down footmen on the way);
## the other bans (the fleeing, the wounded) apply to every hit.
func _dash_oath(u: Unit, f: Unit) -> void:
	var o := oath_of(u.id)
	if o.is_empty():
		return
	if bool(o.get("first_on_commander", false)) and not u.first_struck:
		if _is_commander(f):
			u.first_struck = true
		return   # decided at the end of the Charge
	_ability_hit(u, f)


## Charge: rides fast to the target, hits and stuns every enemy in the way.
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
		if bool(oath_of(u.id).get("first_on_commander", false)) and not u.first_struck and not u.dash_hit.is_empty():
			_break(u, "Charge did not hit the commander")
		u.dash_mult = 1.0
		if u.combo_strike != "":
			# Hammer and Anvil: the assassin leaps behind the first one knocked down; kills a footman, hits a commander hard
			var sa := by_id(u.combo_strike)
			u.combo_strike = ""
			var first: Unit = null
			for id: String in u.dash_hit:
				var hf := by_id(id)
				if first == null and hf != null and hf.alive():
					first = hf
			if sa != null and sa.alive() and first != null:
				var cm := float(units_data["combos"]["kladivo"].get("mult", 4.0)) * maxf(0.0, 1.0 + stat(sa, "moc"))
				if not _is_commander(first):
					cm = maxf(cm, first.hp / maxf(sa.dmg * _dmg_mult(sa, first) * _taken_mult(first), 0.01) + 1.0)
				_shadow_strike(sa, first, cm)
		# after a Charge keeps fighting the nearest one he knocked down
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
			_dash_oath(u, f)
			_hurt(u, f, float(a["dmg"]) * u.dash_mult * _dmg_mult(u, f, true))


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
		# sleeping group: stands in place until it wakes (_check_pods)
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
	# Challenge: whoever is within range of a challenging tank attacks him
	var tg := _taunter_for(u, ks)
	if tg == null:
		tg = _foe_pick(u, ks)
	u.target_id = tg.id
	if u.ranged:
		_foe_shoot_or_walk(u, tg, dt)
		return
	if not _has_slot(u, tg):
		# the hero is already crowded: waits a little aside, does not push into the crowd
		var away := u.pos - tg.pos
		var spot := tg.pos + (away / maxf(away.length(), 0.01)) * (u.reach + tg.radius + _ord("wait_gap", 1.6))
		if u.pos.distance_to(spot) > 0.4:
			_walk(u, spot, dt, 0.3)
		else:
			u.moving = false
			_face_to(u, tg)
		return
	_engage(u, tg, dt)


# --------------------------------------------------------------- commanders

func _skill_def(u: Unit) -> Dictionary:
	return units_data.get("foe_skills", {}).get(u.skill, {})


## A commander starts his ability when it makes sense (target in range). He announces it: winds up for `windup` s
## (the UI draws the warning from warnings()). Returns true when started.
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
			# throws at the spot where most heroes stand
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
	var warn := String(sd.get("warn", "%s winds up!"))
	var text := warn % (target.name if target != null else u.name) if warn.contains("%s") else warn
	events.append({"type": "warn", "id": u.id, "text": text})
	_log(text, true)
	return true


## The commander's announced ability lands.
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


## A stun interrupts the windup (the player can stop a commander's ability with Charge).
func _skill_cancel(u: Unit) -> void:
	u.casting = false
	u.skill_t = float(_skill_def(u).get("cd", 10.0)) * 0.5
	_log("%s: interrupted!" % u.name, true)


## Announced commander abilities for the UI: [{"pos", "radius", "t", "kind", "target"}].
func warnings() -> Array:
	var out: Array = []
	for f in living(SIDE_FOE):
		if f.casting:
			var sd := _skill_def(f)
			var k := by_id(f.cast_target)
			var pos: Vector2 = k.pos if k != null else (f.pos if String(sd["kind"]) in ["smash", "rally"] else f.cast_pos)
			out.append({"pos": pos, "radius": float(sd.get("radius", 0.9)) if String(sd["kind"]) != "shot" else 0.9, "t": f.cast_t, "kind": String(sd["kind"]), "target": f.cast_target, "id": f.id})
	return out


## How many melee enemies are fighting the hero up close right now.
func _attackers_on(k: Unit, except: Unit = null) -> int:
	var n := 0
	for f in living(SIDE_FOE):
		if f != except and not f.ranged and not f.asleep and f.target_id == k.id and f.pos.distance_to(k.pos) <= f.reach + k.radius + 0.6:
			n += 1
	return n


## Does the enemy have a slot at the hero? (at most `melee_slots` melee at once; whoever already fights has one)
func _has_slot(u: Unit, k: Unit) -> bool:
	if u.target_id == k.id and u.pos.distance_to(k.pos) <= u.reach + k.radius + 0.6:
		return true
	return _attackers_on(k, u) < int(_ord("melee_slots", 3.0))


## Enemy target: the nearest hero with a free slot (ranged simply the nearest); when all are full, the nearest.
func _foe_pick(u: Unit, ks: Array[Unit]) -> Unit:
	if u.ranged:
		return _nearest(ks, u.pos)
	var free: Array[Unit] = []
	for k in ks:
		if _has_slot(u, k):
			free.append(k)
	var best := _nearest(free, u.pos)
	return best if best != null else _nearest(ks, u.pos)


## Bowman: shoots from range but advances to 60 % of range so no stalemate arises.
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


## Heroes the enemy can target (without those in Vanish; when all are hidden, all of them).
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


## Breaks enemy morale when it has lost enough units.
func _check_morale() -> void:
	if foes_broken or not pending.is_empty():
		return   # while more waves are coming the enemy does not break
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
			_wake_pod(pi, "zlom")   # a broken enemy no longer waits anywhere
	for u in living(SIDE_FOE):
		if bool(_trait_value(u, "never_breaks", false)):
			continue
		var reaction := String(_trait_value(u, "on_break", u.on_break))
		if reaction == "flee":
			u.fleeing = true
		elif reaction == "desperate":
			u.desperate = true
	_log("The enemy is broken: bowmen flee, footmen throw themselves desperately into the fight. You can give the All In! command.", true)


## Side strength: health × damage per second (a rough estimate, no bonuses). Sleeping groups do not count
## (they are not fighting yet), later waves do.
func power(side: String) -> float:
	var p := 0.0
	for u in living(side):
		if not u.fleeing and not u.asleep:
			p += u.hp * u.dmg / maxf(u.cd, 0.1)
	if side == SIDE_FOE:
		for u in pending:
			p += u.hp * u.dmg / maxf(u.cd, 0.1)
	return p


## Next wave: enemies whose time has come enter the battlefield (arrive event for the scene).
func _arrivals() -> void:
	if pending.is_empty():
		return
	var keep: Array[Unit] = []
	var came := 0
	for u in pending:
		if t >= u.arrive_t:
			units.append(u)
			if foes_broken:
				u.desperate = u.on_break == "desperate"   # arriving into a lost battle
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
		_log("Another wave is coming: %d enemies" % came, true)


## Waking groups (battle phases): a sleeping group wakes when a hero comes within `wake` m of one of its
## members, when someone wounds it, when an awake enemy fights within `alarm` m of its
## spot (the noise of battle) or when the enemy's morale breaks.
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
			# noise of battle: an awake enemy fights within `alarm` m of the group's spot
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
	var pname := String((pods[pi] as Dictionary).get("name", "Enemies"))
	var msg := ("%s: alarm! They join the fight" if why == "poplach" else "%s join the fight") % pname
	events.append({"type": "wake", "pod": pi, "why": why, "text": msg})
	_log(msg, true)


func _any_asleep() -> bool:
	for f in living(SIDE_FOE):
		if f.asleep:
			return true
	return false


## Sleeping groups that remain (for the UI: "more enemies are waiting").
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
	# stalemate guard: when the player does not give All In! long after the morale break, the heroes finish the fight on their own
	if foes_broken and not charging and broken_t >= 0.0 and t - broken_t > float(units_data["morale"].get("auto_charge_after", 25.0)):
		charging = true
		_log("The heroes finish off the rest of the enemies on their own", true)
	if decided != "":
		return
	var r := float(units_data["morale"]["decided_ratio"])
	var pk := power(SIDE_KNIGHT)
	var pe := power(SIDE_FOE)
	# After the morale break the player decides with All In!, the guard does not fire.
	if pe < pk * r and not foes_broken and not _any_asleep():
		decided = SIDE_KNIGHT
	elif pk < pe * r:
		decided = SIDE_FOE
	else:
		return
	events.append({"type": "decided", "side": decided})
	_log("The battle is decided, the heroes finish the fight" if decided == SIDE_KNIGHT else "The battle is lost, the heroes fight to the last", true)


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
		u.rage_t = maxf(0.0, u.rage_t - dt)
		u.mourn_t = maxf(0.0, u.mourn_t - dt)
		u.mark_t = maxf(0.0, u.mark_t - dt)
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

	# burning ground (Fire Volley)
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
		_end_oaths()
		over = "win"
		events.append({"type": "end"})
	elif living(SIDE_KNIGHT).is_empty():
		over = "lose"
		events.append({"type": "end"})



## Battle result for the run: who fell, who fled, glory.
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
