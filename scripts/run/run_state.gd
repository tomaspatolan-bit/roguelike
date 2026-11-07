extends RefCounted
## Run state: act map, house roster (health, passives, oaths), the fallen, glory, fled enemies, rewards and chronicle.
## Pure logic without graphics, can run in tests without a window (tests/test_run.gd).
##
## Flow: available() → choose(id) → by node type:
##   bitva / elita / boss: battle_setup(data) → battle → record_battle(sim.result()) → legacy (legacy_*) → bond (bond_offer / choose_bond) → reward (offers / pick_offer)
##   udalost: event() → event_option_problem(i) / event_choose(i)
##   tabor: camp_rest()
## and back to the map. After the boss the act (for now the whole run) is won.

const Sim := preload("res://scripts/sim/battle_sim.gd")
const ActMap := preload("res://scripts/run/act_map.gd")

const NODE_NAMES := {"bitva": "Battle", "elita": "Elite", "udalost": "Event", "tabor": "Camp", "boss": "Boss"}

var act: Dictionary
var units_data: Dictionary
var house: Dictionary
var events_data: Dictionary
var map: Dictionary

## Heroes by class: {"name", "passives": Array, "glory": float, "hp": health fraction 0..1, "joined": floor,
## "bond": {} or {"with": class, "type": bond key}}
var heroes := {}
var fallen: Array = []          # [{"cls", "name", "stage", "passives", "glory"}]
var node_id := ""               # node where the house is now ("" = before the first floor)
var path: Array = []            # visited nodes in order
var battles_won := 0
var glory := 0.0                # house glory, carried between battles (at most carry_max)
var fled: Array = []            # fled enemies waiting to return: [{"key", "stage"}]
var returned: Array = []        # fled enemies who returned in the last battle (for the chronicle)
var chronicle: Array = []       # [{"stage": node name or "", "text"}]
var pending_legacy: Array = []  # oaths of the fallen waiting for an heir: [{"oath", "from"}]
var over := ""                  # "" running, "win", "lose"
var last_result := {}
var event_done := false         # the event in the current node has been decided
var camp_done := false          # the house has already rested at the current camp
var pair_wins := {}             # shared victories of pairs: {"a|b" (classes in alphabetical order): count}
var bond_declined := {}         # pairs whose bond the player postponed: {"a|b": victories at that time}

var _offers: Array = []
var _offers_ready := false
var _picks_left := 0
var _rng := RandomNumberGenerator.new()
var _succ_used := {}
var _bond_open := false
var _bond_offer := {}


func _init(rng_seed: int = -1, act_key: String = "akt_1") -> void:
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	act = Sim._read_json("res://data/%s.json" % act_key)
	units_data = Sim._read_json("res://data/units.json")
	house = Sim._read_json("res://data/rod_vlka.json")
	events_data = Sim._read_json("res://data/udalosti.json")
	glory = float(house["glory"]["start"])
	var start: Dictionary = house.get("start_passives", {})
	for cls: String in units_data["knights"]:
		heroes[cls] = {
			"name": units_data["knights"][cls]["name"],
			"passives": (start.get(cls, []) as Array).duplicate(),
			"glory": 0.0,
			"hp": 1.0,
			"joined": 0,
			"bond": {},
		}
	map = ActMap.generate(act, _rng)
	_note("", "The %s sets out into %s. Five heroes, %d floors, Captain Kuno at the end." % [house["name"], act["name"], int(act["floors"])])


# --- mapa ---

func node(id: String = node_id) -> Dictionary:
	return map["nodes"].get(id, {})


func node_type(id: String = node_id) -> String:
	return String(node(id).get("type", ""))


func floor_count() -> int:
	return int(act["floors"]) + 1   # + boss


func current_floor() -> int:
	return int(node().get("floor", 0))


## Where you can go: at the start the whole first floor, otherwise the paths from the current node.
## Until the node is resolved (legacy, reward, event), nowhere.
func available() -> Array:
	if over != "" or not node_finished():
		return []
	if node_id == "":
		var out: Array = []
		for n: Dictionary in map["floors"][0]:
			out.append(n["id"])
		return out
	return (node()["next"] as Array).duplicate()


## Is the current node resolved (can we move on)?
func node_finished() -> bool:
	match node_type():
		"":
			return true
		"bitva", "elita", "boss":
			return last_result.has("node") and last_result["node"] == node_id and not has_legacy() and bond_offer().is_empty() and offers().is_empty()
		"udalost":
			return event_done
		"tabor":
			return true   # resting is a choice, you can move on without it
	return true


func choose(id: String) -> bool:
	if not available().has(id):
		return false
	node_id = id
	path.append(id)
	event_done = false
	camp_done = false
	_offers = []
	_offers_ready = false
	_picks_left = 0
	return true


## Node name for the player and the chronicle (the scenario name for a battle, the event name for an event).
func node_label(id: String = node_id) -> String:
	var n := node(id)
	if n.is_empty():
		return ""
	match String(n["type"]):
		"bitva", "elita", "boss":
			return String(scenario_info(String(n["scenario"])).get("name", n["scenario"]))
		"udalost":
			return String(events_data[n["event"]]["name"])
	return NODE_NAMES.get(n["type"], n["type"])


## Scenario description for the map (name, subtitle, task); variants are merged with their base.
func scenario_info(key: String) -> Dictionary:
	return Sim.read_scenario(key)


func is_battle_node(id: String = node_id) -> bool:
	return ["bitva", "elita", "boss"].has(node_type(id))


# --- house queries ---

func hero_name(cls: String) -> String:
	return heroes[cls]["name"]


func passive_name(key: String) -> String:
	return units_data["passives"][key]["name"]


func passive_desc(key: String) -> String:
	return units_data["passives"][key].get("desc", "")


func is_oath(key: String) -> bool:
	return units_data["passives"][key].get("kind", "") == "oath"


func oath_of(cls: String) -> String:
	for k: String in heroes[cls]["passives"]:
		if is_oath(k):
			return k
	return ""


func class_name_of(cls: String) -> String:
	return units_data["knights"][cls].get("role", cls)


func hp_of(cls: String) -> float:
	return float(heroes[cls]["hp"])


# --- battle ---

func load_stage_data() -> Dictionary:
	return Sim.load_data(String(node()["scenario"]))


## Battle setup for the simulation: passives, names, health, glory and returning fled enemies.
func battle_setup(data: Dictionary) -> Dictionary:
	var setup := Sim.default_setup(data)
	var pas := {}
	var names := {}
	var hp := {}
	for cls: String in heroes:
		pas[cls] = (heroes[cls]["passives"] as Array).duplicate()
		names[cls] = heroes[cls]["name"]
		hp[cls] = heroes[cls]["hp"]
	setup["passives"] = pas
	setup["names"] = names
	setup["hp"] = hp
	setup["glory"] = glory
	setup["ancestors"] = fallen.size()   # Oath of the Ancestors
	var bonds := {}
	for cls: String in heroes:
		var b: Dictionary = heroes[cls]["bond"]
		if not b.is_empty():
			var other: String = b["with"]
			bonds[cls] = {"with": other, "type": b["type"], "level": bond_level(cls),
				"student": b["type"] == "ucitel" and int(heroes[cls]["joined"]) > int(heroes[other]["joined"])}
	setup["bonds"] = bonds
	setup["extra_enemies"] = returnee_rows(data["scenario"])
	return setup


## Enemy rows for fled enemies who return (only in a scenario with returnees).
func returnee_rows(scenario: Dictionary) -> Array:
	var rows: Array = []
	if not scenario.has("returnees"):
		return rows
	var r: Dictionary = scenario["returnees"]
	var c := Vector2(r["pos"][0], r["pos"][1])
	var spread: float = r.get("spread", 1.2)
	var per_row := 5
	for i in mini(fled.size(), int(r.get("max", 99))):
		var col := i % per_row
		var row := i / per_row
		var x := c.x + (col - (per_row - 1) / 2.0) * spread
		var y := c.y + row * spread
		var rrow: Array = [fled[i]["key"], x, y]
		if r.has("pod"):
			rrow.append({"pod": int(r["pod"])})   # they return to a group (e.g. the commander's camp)
		rows.append(rrow)
	return rows


## Records the battle result (sim.result()) into the run: the fallen, successors, wounds, glory, fled enemies, chronicle.
func record_battle(res: Dictionary) -> void:
	last_result = res.duplicate()
	last_result["node"] = node_id
	var sname := node_label()
	var sc := scenario_info(String(node()["scenario"]))
	var is_boss := node_type() == "boss"
	glory = minf(float(res["glory"]), float(house["glory"].get("carry_max", house["glory"]["max"])))
	var gb: Dictionary = res.get("glory_by", {})
	for cls: String in gb:
		if heroes.has(cls):
			heroes[cls]["glory"] = float(heroes[cls]["glory"]) + float(gb[cls])

	# returning fled enemies are written into the chronicle and their debt is paid
	returned = []
	if sc.has("returnees") and not fled.is_empty():
		returned = fled.slice(0, int(sc["returnees"].get("max", 99)))
		fled.clear()
		_note(sname, "Fled enemies returned: %s (from: %s)." % [_count_foes(returned), _stages_of(returned)])

	if res["over"] == "win":
		_note(sname, "Victory: %s." % sname)
		battles_won += 1
	else:
		_note(sname, "Defeat: %s. Everyone fell." % sname)

	# broken oaths disappear
	for cls: String in res.get("oaths_broken", []):
		var o := oath_of(cls)
		if o != "":
			(heroes[cls]["passives"] as Array).erase(o)
			_note(sname, "%s broke his oath: %s." % [hero_name(cls), passive_name(o)])

	# the fallen: record them, the oath waits for an heir, a successor steps in
	var dead: Array = res.get("dead", [])
	_bonds_after_deaths(dead, sname)
	for cls: String in dead:
		var h: Dictionary = heroes[cls]
		fallen.append({"cls": cls, "name": h["name"], "stage": sname, "passives": (h["passives"] as Array).duplicate(), "glory": h["glory"]})
		_note(sname, "%s (%s) fell. He brought the house %d glory." % [h["name"], class_name_of(cls), roundi(float(h["glory"]))])
		var o := oath_of(cls)
		if o != "" and not is_boss:
			pending_legacy.append({"oath": o, "from": h["name"]})
	if res["over"] != "win":
		over = "lose"
		pending_legacy.clear()
		_note("", "The %s has fallen entirely. The run ends." % house["name"])
		return

	_count_wins(dead, sname)

	# wounds carry over, a little heals after the battle
	var hp: Dictionary = res.get("hp", {})
	for cls: String in heroes:
		if not dead.has(cls) and hp.has(cls):
			heroes[cls]["hp"] = minf(1.0, float(hp[cls]) + float(act.get("regen", 0.0)))

	if not is_boss:
		for cls: String in dead:
			var nm := _successor_name(cls)
			heroes[cls] = {"name": nm, "passives": [], "glory": 0.0, "hp": 1.0, "joined": current_floor(), "bond": {}}
			_note(sname, "%s takes the place of the fallen." % nm)

	# enemies who fled this battle may return later
	if not sc.has("returnees"):
		for k: String in res.get("fled", []):
			fled.append({"key": k, "stage": sname})
		if not (res.get("fled", []) as Array).is_empty():
			_note(sname, "Fled: %s." % _count_foes(res["fled"]))

	_offers_ready = false
	if is_boss:
		over = "win"
		_note("", "The %s defeated Captain Kuno and won %s." % [house["name"], act["name"]])
		return
	var elite := node_type() == "elita"
	_picks_left = int(act.get("elite_picks", 2)) if elite else 1
	_bond_open = true
	_bond_offer = {}


# --- oath legacy ---

func has_legacy() -> bool:
	return not pending_legacy.is_empty()


func legacy_current() -> Dictionary:
	return pending_legacy[0] if has_legacy() else {}


## Who can inherit the oath: living heroes without an oath (incl. successors). A personal class oath
## is inherited only by the successor of the same class, a house oath by anyone.
func legacy_candidates() -> Array:
	var out: Array = []
	var cls_of := ""
	if has_legacy():
		cls_of = String(units_data["passives"][legacy_current()["oath"]].get("class", "any"))
	for cls: String in heroes:
		if oath_of(cls) == "" and (cls_of == "any" or cls_of == "" or cls_of == cls):
			if has_legacy() and bool(units_data["passives"][legacy_current()["oath"]].get("no_bond", false)) and not (heroes[cls]["bond"] as Dictionary).is_empty():
				continue   # the Loner's Oath cannot go to a hero with a bond
			out.append(cls)
	return out


## Gives the fallen hero's current oath to a hero (cls = "" → the oath dies).
func resolve_legacy(cls: String) -> void:
	if not has_legacy():
		return
	var l: Dictionary = pending_legacy.pop_front()
	if cls != "" and legacy_candidates().has(cls):
		(heroes[cls]["passives"] as Array).append(l["oath"])
		_note("", "%s took up %s, the oath left by %s." % [hero_name(cls), passive_name(l["oath"]), l["from"]])
	else:
		_note("", "The oath %s died with %s." % [passive_name(l["oath"]), l["from"]])
	_offers_ready = false


# --- bonds between heroes (decision 07.11.2026) ---

func pair_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


## Shared victories of a pair (both survived).
func wins_of(a: String, b: String) -> int:
	return int(pair_wins.get(pair_key(a, b), 0))


## Level for a number of shared victories (0–3, thresholds bond_rules.levels).
func level_for(wins: int) -> int:
	var lv := 0
	for th: Variant in (units_data["bond_rules"]["levels"] as Array):
		if wins >= int(th):
			lv += 1
	return lv


## The hero's bond level (0 = no bond).
func bond_level(cls: String) -> int:
	var b: Dictionary = heroes[cls]["bond"]
	return 0 if b.is_empty() else maxi(1, level_for(wins_of(cls, String(b["with"]))))


func bond_name(type: String) -> String:
	return String(units_data["bonds"][type]["name"])


func bond_desc(type: String) -> String:
	return String(units_data["bonds"][type].get("desc", ""))


func _no_bond(cls: String) -> bool:
	var o := oath_of(cls)
	return o != "" and bool(units_data["passives"][o].get("no_bond", false))


## Does the bond type fit the pair? (who: one from A, the other from B; successor: one joined later)
func bond_fits(type: String, a: String, b: String) -> bool:
	var bd: Dictionary = units_data["bonds"][type]
	var who: Array = bd.get("who", [["*"], ["*"]])
	var in_set := func(arr: Array, c: String) -> bool: return arr.has("*") or arr.has(c)
	var ok: bool = (in_set.call(who[0], a) and in_set.call(who[1], b)) or (in_set.call(who[0], b) and in_set.call(who[1], a))
	if bool(bd.get("successor", false)):
		ok = ok and int(heroes[a]["joined"]) != int(heroes[b]["joined"])
	return ok


## Bond offer after a battle: a pair with at least levels[0] victories, both without a bond (and without the Loner's Oath),
## the one with the most victories first. {"a", "b", "wins", "choices": [type, type]} or {}.
func bond_offer() -> Dictionary:
	if not _bond_open or over != "" or has_legacy():
		return {}
	if not _bond_offer.is_empty():
		return _bond_offer
	var need := int(units_data["bond_rules"]["levels"][0])
	var best := {}
	for key: String in pair_wins:
		var w := int(pair_wins[key])
		var ab := key.split("|")
		var a: String = ab[0]
		var b: String = ab[1]
		if w < need or not heroes.has(a) or not heroes.has(b):
			continue
		if not (heroes[a]["bond"] as Dictionary).is_empty() or not (heroes[b]["bond"] as Dictionary).is_empty():
			continue
		if _no_bond(a) or _no_bond(b):
			continue
		if bond_declined.has(key) and int(bond_declined[key]) >= w:
			continue
		if best.is_empty() or w > int(best["wins"]):
			best = {"a": a, "b": b, "wins": w}
	if best.is_empty():
		_bond_open = false
		return {}
	var types: Array = []
	for t: String in units_data["bonds"]:
		if not t.begins_with("_") and bond_fits(t, best["a"], best["b"]):
			types.append(t)
	_shuffle(types)
	best["choices"] = types.slice(0, int(units_data["bond_rules"].get("choices", 2)))
	_bond_offer = best
	return _bond_offer


## The player picks a bond type from the offer ("" = not yet, offered again after the next shared victory).
func choose_bond(type: String) -> void:
	var o := bond_offer()
	if o.is_empty():
		return
	var a: String = o["a"]
	var b: String = o["b"]
	if type != "" and (o["choices"] as Array).has(type):
		heroes[a]["bond"] = {"with": b, "type": type}
		heroes[b]["bond"] = {"with": a, "type": type}
		_note("", "A bond formed, %s: %s and %s (shared victories: %d)." % [bond_name(type), hero_name(a), hero_name(b), int(o["wins"])])
	else:
		bond_declined[pair_key(a, b)] = int(o["wins"])
		_note("", "Bond postponed: %s and %s." % [hero_name(a), hero_name(b)])
	_bond_offer = {}
	_offers_ready = false


## The fallen: the companion loses the bond (Master and Pupil: the pupil inherits one of the master's passives), the fallen hero's history is erased.
func _bonds_after_deaths(dead: Array, sname: String) -> void:
	for cls: String in dead:
		var b: Dictionary = heroes[cls]["bond"]
		heroes[cls]["bond"] = {}
		if not b.is_empty():
			var other: String = b["with"]
			if heroes.has(other) and not dead.has(other):
				heroes[other]["bond"] = {}
				_note(sname, "%s mourns his fallen companion %s. The bond %s is gone." % [hero_name(other), hero_name(cls), bond_name(b["type"])])
				if b["type"] == "ucitel" and int(heroes[other]["joined"]) > int(heroes[cls]["joined"]):
					var can: Array = []
					for k: String in heroes[cls]["passives"]:
						var c: String = units_data["passives"][k].get("class", "any")
						if not is_oath(k) and (c == "any" or c == other) and not (heroes[other]["passives"] as Array).has(k):
							can.append(k)
					if not can.is_empty():
						var pick: String = can[_rng.randi() % can.size()]
						(heroes[other]["passives"] as Array).append(pick)
						_note(sname, "%s learned from his master: %s." % [hero_name(other), passive_name(pick)])
		var longest := ""
		for key: String in pair_wins.keys():
			if (key as String).split("|").has(cls):
				var w := int(pair_wins[key])
				if w >= 2 and (longest == "" or w > int(pair_wins.get(longest, 0))):
					longest = key
		if longest != "":
			var ab := longest.split("|")
			var mate: String = ab[1] if ab[0] == cls else ab[0]
			_note(sname, "%s and %s stood side by side (shared victories: %d)." % [hero_name(cls), hero_name(mate), int(pair_wins[longest])])
		for key: String in pair_wins.keys():
			if (key as String).split("|").has(cls):
				pair_wins.erase(key)
				bond_declined.erase(key)


## A won battle: every pair that survived gets one more shared victory; a bond may grow.
func _count_wins(dead: Array, sname: String) -> void:
	var alive: Array = []
	for cls: String in heroes:
		if not dead.has(cls):
			alive.append(cls)
	for i in alive.size():
		for j in range(i + 1, alive.size()):
			var key := pair_key(alive[i], alive[j])
			pair_wins[key] = int(pair_wins.get(key, 0)) + 1
	for cls: String in alive:
		var b: Dictionary = heroes[cls]["bond"]
		if b.is_empty() or cls > String(b["with"]):
			continue
		var w := wins_of(cls, b["with"])
		var lv := level_for(w)
		if lv > level_for(w - 1) and lv >= 2:
			_note(sname, "The bond %s (%s and %s) grew to level %d." % [bond_name(b["type"]), hero_name(cls), hero_name(b["with"]), lv])


# --- reward after the battle ---

## How many rewards the player still picks from the offer (elite 2, otherwise 1).
func picks_left() -> int:
	return _picks_left


## Reward offers: [{"hero": class, "passive": key}].
func offers() -> Array:
	if over != "" or _picks_left <= 0 or has_legacy() or not bond_offer().is_empty():
		return []
	if not _offers_ready:
		var n := int(act.get("elite_offers", 4)) if node_type() == "elita" else int(act.get("offers", 3))
		_offers = _make_offers(n)
		_offers_ready = true
	return _offers


## Is the offer (still) valid? After the first elite pick an oath may stop fitting.
func offer_valid(o: Dictionary) -> bool:
	var cls: String = o["hero"]
	var key: String = o["passive"]
	if (heroes[cls]["passives"] as Array).has(key):
		return false
	if bool(units_data["passives"][key].get("no_bond", false)) and not (heroes[cls]["bond"] as Dictionary).is_empty():
		return false
	return not (is_oath(key) and oath_of(cls) != "")


func _make_offers(n: int) -> Array:
	var pool: Array = []
	for cls: String in heroes:
		for key: String in _passives_for(cls, ""):
			pool.append({"hero": cls, "passive": key})
	_shuffle(pool)
	var out: Array = []
	var used_keys := {}
	var used_heroes := {}
	# first different heroes and different passives, then whatever is left
	for pass_i in 2:
		for o: Dictionary in pool:
			if out.size() >= n:
				break
			if used_keys.has(o["passive"]) or out.has(o):
				continue
			if pass_i == 0 and used_heroes.has(o["hero"]):
				continue
			out.append(o)
			used_keys[o["passive"]] = true
			used_heroes[o["hero"]] = true
	return out


## Passives the hero can get (kind = "" all, otherwise only passive / oath).
func _passives_for(cls: String, kind: String) -> Array:
	var out: Array = []
	var has_oath := oath_of(cls) != ""
	for key: String in units_data["passives"]:
		if key.begins_with("_"):
			continue
		var d: Dictionary = units_data["passives"][key]
		var c: String = d.get("class", "any")
		if c != "any" and c != cls:
			continue
		if (heroes[cls]["passives"] as Array).has(key):
			continue
		if bool(d.get("no_bond", false)) and not (heroes[cls]["bond"] as Dictionary).is_empty():
			continue
		var k: String = d.get("kind", "passive")
		if k == "oath" and has_oath:
			continue
		if kind != "" and k != kind:
			continue
		out.append(key)
	return out


func pick_offer(i: int) -> void:
	var list := offers()
	if i < 0 or i >= list.size() or not offer_valid(list[i]):
		return
	var o: Dictionary = list[i]
	_grant(o["hero"], o["passive"])
	_picks_left -= 1
	list.remove_at(i)
	if _picks_left <= 0:
		_offers = []
	else:
		# remaining offers that no longer fit (a second oath) are dropped
		var keep: Array = []
		for x: Dictionary in list:
			if offer_valid(x):
				keep.append(x)
		_offers = keep
		if keep.is_empty():
			_picks_left = 0


func _grant(cls: String, key: String) -> void:
	(heroes[cls]["passives"] as Array).append(key)
	if is_oath(key):
		_note("", "%s swore an oath: %s." % [hero_name(cls), passive_name(key)])
	else:
		_note("", "%s gained: %s." % [hero_name(cls), passive_name(key)])


# --- event ---

func event() -> Dictionary:
	if node_type() != "udalost":
		return {}
	return events_data[node()["event"]]


## Why the option is not possible ("" = it is): e.g. not enough glory or no one can swear an oath.
func event_option_problem(i: int) -> String:
	var opts: Array = event().get("options", [])
	if event_done or i < 0 or i >= opts.size():
		return "Not possible."
	for e: Dictionary in opts[i].get("effects", []):
		if e.has("glory") and float(e["glory"]) < 0.0 and glory < -float(e["glory"]):
			return "Not enough glory (%d)." % int(-float(e["glory"]))
		if e.has("gift") and _gift_candidates(String(e["gift"])).is_empty():
			return "No one in the house can accept it."
	return ""


func event_choose(i: int) -> void:
	if event_option_problem(i) != "":
		return
	var ev := event()
	var opt: Dictionary = ev["options"][i]
	var sname := String(ev["name"])
	for e: Dictionary in opt.get("effects", []):
		if e.has("glory"):
			glory = clampf(glory + float(e["glory"]), 0.0, float(house["glory"]["max"]))
		if e.has("heal"):
			_change_hp(e["heal"], 1.0)
		if e.has("wound"):
			_change_hp(e["wound"], -1.0)
		if e.has("gift"):
			var cands := _gift_candidates(String(e["gift"]))
			var c: Array = cands[_rng.randi_range(0, cands.size() - 1)]
			_grant(c[0], c[1])
		if e.has("fled"):
			var f: Dictionary = e["fled"]
			for k: String in f:
				for n in int(f[k]):
					fled.append({"key": k, "stage": sname})
	if String(opt.get("text", "")) != "":
		_note(sname, String(opt["text"]))
	event_done = true


func _gift_candidates(kind: String) -> Array:
	var out: Array = []
	for cls: String in heroes:
		for key: String in _passives_for(cls, kind):
			out.append([cls, key])
	return out


func _change_hp(spec: Dictionary, sign: float) -> void:
	var who: String = spec.get("who", "all")
	var frac: float = spec.get("frac", 0.0)
	var targets: Array = []
	match who:
		"random":
			var keys: Array = heroes.keys()
			targets.append(keys[_rng.randi_range(0, keys.size() - 1)])
		"wounded":
			for cls: String in heroes:
				if hp_of(cls) < 1.0:
					targets.append(cls)
		_:
			targets = heroes.keys()
	for cls: String in targets:
		# wounds from an event kill no one
		heroes[cls]["hp"] = clampf(hp_of(cls) + sign * frac, 0.1, 1.0)
		if sign < 0.0:
			_note("", "%s is wounded (%d %% health)." % [hero_name(cls), roundi(hp_of(cls) * 100.0)])


# --- camp ---

func camp_rest() -> void:
	if node_type() != "tabor" or camp_done:
		return
	for cls: String in heroes:
		heroes[cls]["hp"] = minf(1.0, hp_of(cls) + float(act.get("camp_heal", 1.0)))
	camp_done = true
	_note("Camp", "The house rested by the fire, the wounds healed.")


# --- helpers ---

func _note(sname: String, text: String) -> void:
	chronicle.append({"stage": sname, "text": text})


func _successor_name(cls: String) -> String:
	var pool: Array = house.get("successors", {}).get(cls, [])
	var i: int = _succ_used.get(cls, 0)
	_succ_used[cls] = i + 1
	if i < pool.size():
		return pool[i]
	var roman := ["II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
	return "%s %s" % [units_data["knights"][cls]["name"], roman[mini(i - pool.size(), roman.size() - 1)]]


func _count_foes(list: Array) -> String:
	var counts := {}
	for e: Variant in list:
		var k: String = e["key"] if e is Dictionary else str(e)
		counts[k] = int(counts.get(k, 0)) + 1
	var parts: Array = []
	for k: String in counts:
		parts.append("%d× %s" % [counts[k], units_data["foes"][k]["name"]])
	return ", ".join(parts)


func _stages_of(list: Array) -> String:
	var names: Array = []
	for e: Dictionary in list:
		if not names.has(e["stage"]):
			names.append(e["stage"])
	return ", ".join(names)


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
