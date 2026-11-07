extends RefCounted
## Run state: act map, house roster (health, passives, oaths), the fallen, glory, fled enemies, rewards and chronicle.
## Pure logic without graphics, can run in tests without a window (tests/test_run.gd).
##
## Flow: available() → choose(id) → by node type:
##   bitva / elita / boss: battle_setup(data) → battle → record_battle(sim.result()) → legacy (legacy_*) → bond (bond_offer / choose_bond) → reward (offers / pick_offer)
##   udalost: event() → event_option_problem(i) / event_choose(i) → maybe a choice (offers / pick_offer)
##   tabor: camp_options() → camp_choose(id, arg) → maybe a choice (offers / pick_offer) or a bond (bond_offer)
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
## "bond": {} or {"with": class, "type": bond key}, "stats": {stat: fraction} permanent bonuses (events),
## "oath_boost": {} or {"mult", "break_cost"} (Trial of the Oath)}
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
var next_battle := {}           # one-shot effects for the next battle (events): {"remove_pods": n, "stats": {class: {stat: v}}}
var event_ctx := {}             # the current event's targets: {"hero", "a", "b", "fallen"}
var used_events := {}           # events already seen in this run (each at most once)
var relics: Array = []          # relics of the house (keys from units.json "relics"), for the whole run
var offer_title := ""           # what the current choice is about (reward, training, rite, event)
var offer_declinable := false   # the current offer can be declined for glory (after a battle)

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
			"stats": {},
			"oath_boost": {},
			"ability": String(units_data["knights"][cls].get("ability", "")),
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
			return event_done and offers().is_empty()
		"tabor":
			return offers().is_empty() and bond_offer().is_empty()   # the camp choice is optional, a started choice is not
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
	_bond_open = false
	_bond_offer = {}
	offer_title = ""
	offer_declinable = false
	if node_type() == "udalost":
		_resolve_event()
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

# --- relics (znamení rodu, 2.3e) ---

func relic_data(key: String) -> Dictionary:
	return (units_data.get("relics", {}) as Dictionary).get(key, {})


func relic_name(key: String) -> String:
	return String(relic_data(key).get("name", key))


func has_relic_flag(field: String) -> bool:
	for k: String in relics:
		if bool(relic_data(k).get(field, false)):
			return true
	return false


## Sum of a numeric relic field over the house's relics.
func relic_sum(field: String) -> float:
	var v := 0.0
	for k: String in relics:
		v += float(relic_data(k).get(field, 0.0))
	return v


## Relics the house does not hold yet, in random order.
func relic_pool() -> Array:
	var out: Array = []
	for k: String in units_data.get("relics", {}):
		if not k.begins_with("_") and not relics.has(k):
			out.append(k)
	_shuffle(out)
	return out


func gain_relic(key: String) -> void:
	if relics.has(key) or relic_data(key).is_empty():
		return
	relics.append(key)
	_note("", "The house gained a relic: %s. %s" % [relic_name(key), relic_data(key).get("desc", "")])


## Lineage line of a successor: "Successor of Sir X" ("" for a hero of the first generation).
func lineage(cls: String) -> String:
	var p := String(heroes[cls].get("predecessor", ""))
	return "Successor of %s" % p if p != "" else ""


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


## The hero's ability key (swapped by an elite reward, the Smith or the Monk; a successor starts with the class one).
func ability_of(cls: String) -> String:
	return String(heroes[cls].get("ability", units_data["knights"][cls].get("ability", "")))


func ability_name(key: String) -> String:
	return String(units_data["abilities"].get(key, {}).get("name", key))


## Abilities the hero could swap to (his class's others).
func other_abilities(cls: String) -> Array:
	var out: Array = []
	for k: String in units_data["knights"][cls].get("abilities", []):
		if k != ability_of(cls):
			out.append(k)
	return out


## Swaps the hero's ability; refinements of the old one are lost.
func set_ability(cls: String, key: String) -> void:
	if not (units_data["knights"][cls].get("abilities", []) as Array).has(key):
		return
	heroes[cls]["ability"] = key
	var keep: Array = []
	var lost: Array = []
	for k: String in heroes[cls]["passives"]:
		if _refine_of(k) != "" and _refine_of(k) != key:
			lost.append(passive_name(k))
		else:
			keep.append(k)
	heroes[cls]["passives"] = keep
	_note("", "%s learned a new way to fight: %s.%s" % [hero_name(cls), ability_name(key), (" Lost: %s." % ", ".join(lost)) if not lost.is_empty() else ""])


## Ability the passive refines ("" = not a refinement).
func _refine_of(key: String) -> String:
	var d: Dictionary = units_data["passives"].get(key, {})
	return String(d.get("ability", "")) if d.get("kind", "") == "refine" else ""


## Combos a hero with this ability would have with his bond partner now: [combo name].
func combos_with(cls: String, ability: String) -> Array:
	var out: Array = []
	var b: Dictionary = heroes[cls]["bond"]
	if b.is_empty():
		return out
	var pa := ability_of(String(b["with"]))
	for cid: String in units_data.get("combos", {}):
		if cid.begins_with("_"):
			continue
		var c: Dictionary = units_data["combos"][cid]
		if (c["a"] == ability and c["b"] == pa) or (c["b"] == ability and c["a"] == pa):
			out.append(String(c["name"]))
	return out


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
	var abl := {}
	for cls: String in heroes:
		abl[cls] = ability_of(cls)
	setup["abilities"] = abl
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
	var hs := {}
	var boost := {}
	var nb_stats: Dictionary = next_battle.get("stats", {})
	var uses := {}
	for cls: String in heroes:
		var st: Dictionary = (heroes[cls].get("stats", {}) as Dictionary).duplicate()
		for k: String in nb_stats.get(cls, {}):
			st[k] = float(st.get(k, 0.0)) + float(nb_stats[cls][k])
		for rk: String in relics:   # relic stats are baked into every hero's values (decision 07.11.2026)
			var rs: Dictionary = relic_data(rk).get("stats", {})
			for k: String in rs:
				st[k] = float(st.get(k, 0.0)) + float(rs[k])
		if relic_sum("extra_uses") > 0.0:
			uses[cls] = int(relic_sum("extra_uses"))
		if not st.is_empty():
			hs[cls] = st
		if not (heroes[cls].get("oath_boost", {}) as Dictionary).is_empty():
			boost[cls] = heroes[cls]["oath_boost"]
	setup["hero_stats"] = hs
	setup["extra_uses"] = uses
	setup["oath_boost"] = boost
	setup["remove_pods"] = int(next_battle.get("remove_pods", 0))
	setup["extra_enemies"] = returnee_rows(data["scenario"])
	return setup


## Enemy rows for fled enemies who return (only in a scenario with returnees).
func returnee_rows(scenario: Dictionary) -> Array:
	var rows: Array = []
	if not scenario.has("returnees") or has_relic_flag("no_returnees"):
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
	next_battle = {}
	var sname := node_label()
	var sc := scenario_info(String(node()["scenario"]))
	var is_boss := node_type() == "boss"
	var earned := float(res["glory"]) - glory   # glory gained in the battle (oath breaks already taken off)
	if earned > 0.0:
		earned *= maxf(0.0, 1.0 + relic_sum("battle_glory"))   # The Chronicler, Castle Horns
	last_result["glory_earned"] = earned
	glory = clampf(glory + earned, 0.0, _glory_max())
	var gb: Dictionary = res.get("glory_by", {})
	for cls: String in gb:
		if heroes.has(cls):
			heroes[cls]["glory"] = float(heroes[cls]["glory"]) + float(gb[cls])

	# returning fled enemies are written into the chronicle and their debt is paid
	returned = []
	if sc.has("returnees") and not fled.is_empty() and has_relic_flag("no_returnees"):
		_note(sname, "The castle horns kept the fled enemies away.")
		fled.clear()
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
	if not dead.is_empty() and relic_sum("fallen_cost") > 0.0:
		var cost := relic_sum("fallen_cost") * dead.size()
		glory = maxf(0.0, glory - cost)
		_note(sname, "Young Blood: the fallen cost the house %d glory." % int(cost))

	# wounds carry over, a little heals after the battle
	var hp: Dictionary = res.get("hp", {})
	for cls: String in heroes:
		if not dead.has(cls) and hp.has(cls):
			heroes[cls]["hp"] = minf(1.0, float(hp[cls]) + float(act.get("regen", 0.0)) + relic_sum("regen"))

	if not is_boss:
		for cls: String in dead:
			var nm := _successor_name(cls)
			var pred := String(heroes[cls]["name"])
			heroes[cls] = {"name": nm, "passives": [], "glory": 0.0, "hp": 1.0, "joined": current_floor(), "bond": {}, "stats": {}, "oath_boost": {},
				"ability": String(units_data["knights"][cls].get("ability", "")), "predecessor": pred}
			_note(sname, "%s takes the place of the fallen %s." % [nm, pred])
			if has_relic_flag("inherit"):   # Bloodline: a random passive of the fallen, not an oath
				var can: Array = []
				var fpas: Array = []
				for fr: Dictionary in fallen:
					if fr["cls"] == cls and fr["name"] == pred:
						fpas = fr["passives"]
				for k: String in fpas:
					if not is_oath(k) and (_refine_of(k) == "" or _refine_of(k) == ability_of(cls)):
						can.append(k)
				if not can.is_empty():
					var pick: String = can[_rng.randi_range(0, can.size() - 1)]
					(heroes[cls]["passives"] as Array).append(pick)
					_note(sname, "Bloodline: %s carries on %s from %s." % [nm, passive_name(pick), pred])
			var ss: Dictionary = {}
			for rk: String in relics:
				var rs: Dictionary = relic_data(rk).get("successor_stats", {})
				for k: String in rs:
					ss[k] = float(ss.get(k, 0.0)) + float(rs[k])
			if not ss.is_empty():   # Young Blood: for the successor's first battle
				if not next_battle.has("stats"):
					next_battle["stats"] = {}
				next_battle["stats"][cls] = ss
			for fi in range(fallen.size() - 1, -1, -1):
				if fallen[fi]["cls"] == cls and fallen[fi]["name"] == pred:
					fallen[fi]["successor"] = nm
					break

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
	offer_title = "elite" if elite else "battle"
	offer_declinable = true
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
		var n := (int(act.get("elite_offers", 4)) if node_type() == "elita" else int(act.get("offers", 3))) + int(relic_sum("extra_offers"))
		_offers = _make_offers(n) if is_battle_node() else []
		_offers_ready = true
	return _offers


## Is the offer (still) valid? After the first elite pick an oath may stop fitting.
## Offer kinds: passive (default, also oaths), max_hp (permanent Toughness), release_oath.
func offer_valid(o: Dictionary) -> bool:
	if String(o.get("kind", "")) == "relic":
		return not relics.has(String(o["relic"]))
	var cls: String = o["hero"]
	match String(o.get("kind", "passive")):
		"max_hp":
			return true
		"release_oath":
			return oath_of(cls) != ""
		"ability":
			return ability_of(cls) != String(o["ability"])
	var key: String = o["passive"]
	if (heroes[cls]["passives"] as Array).has(key):
		return false
	if _refine_of(key) != "" and _refine_of(key) != ability_of(cls):
		return false
	if bool(units_data["passives"][key].get("no_bond", false)) and not (heroes[cls]["bond"] as Dictionary).is_empty():
		return false
	return not (is_oath(key) and oath_of(cls) != "")


## Reward after a battle (rules from the design 05.11.2026): oaths make up `offer_oaths` of the offers
## (1 of 3, 1 of 4 at an elite), the rest are passives; different heroes and different passives first.
## Heroes who fell in this battle get nothing (their successors only from the next battle).
func _make_offers(n: int) -> Array:
	var dead: Array = last_result.get("dead", [])
	var oath_pool: Array = []
	var pas_pool: Array = []
	for cls: String in heroes:
		if dead.has(cls):
			continue
		for key: String in _passives_for(cls, "passive"):
			pas_pool.append({"hero": cls, "passive": key})
		for key: String in _passives_for(cls, "oath"):
			oath_pool.append({"hero": cls, "passive": key})
	_shuffle(pas_pool)
	_shuffle(oath_pool)
	var out: Array = []
	var used_keys := {}
	var used_heroes := {}
	var n_oaths := mini(int(act.get("offer_oaths", 1)), n)
	_fill_offers(out, oath_pool, n_oaths, used_keys, used_heroes)
	_fill_offers(out, pas_pool, n, used_keys, used_heroes)
	_fill_offers(out, oath_pool, n, used_keys, used_heroes)   # not enough passives: more oaths
	if node_type() == "elita" and int(act.get("elite_ability_offers", 1)) > 0:
		# elite: one offer is always a new ability (decision 05.11.2026), for a hero not already in the offers if possible
		var ab_pool := _ability_pool(dead)
		if not ab_pool.is_empty():
			var pick: Dictionary = ab_pool[0]
			for o: Dictionary in ab_pool:
				if not used_heroes.has(o["hero"]):
					pick = o
					break
			if out.size() >= n:
				out.pop_back()
			out.append(pick)
	if node_type() == "elita" and int(act.get("elite_relic_offers", 1)) > 0:
		# elite: and one is a relic of the house (2.3e), it takes the place of a passive
		var rp := relic_pool()
		if not rp.is_empty():
			var at := out.size() - 1
			while at >= 0 and (String(out[at].get("kind", "")) == "ability" or (out[at].has("passive") and is_oath(String(out[at]["passive"])))):
				at -= 1
			var rel := {"hero": "", "kind": "relic", "relic": rp[0]}
			if out.size() < n:
				out.append(rel)
			elif at >= 0:
				out[at] = rel
	return out


## All possible ability swaps [{hero, kind: ability, ability}] in random order (without the fallen in `dead`).
func _ability_pool(dead: Array = []) -> Array:
	var pool: Array = []
	for cls: String in heroes:
		if dead.has(cls):
			continue
		for k: String in other_abilities(cls):
			pool.append({"hero": cls, "kind": "ability", "ability": k})
	_shuffle(pool)
	return pool


## Adds offers from `pool` until `out` has `n`: first different heroes and different passives, then whatever is left.
func _fill_offers(out: Array, pool: Array, n: int, used_keys: Dictionary, used_heroes: Dictionary) -> void:
	for pass_i in 2:
		for o: Dictionary in pool:
			if out.size() >= n:
				return
			if used_keys.has(o["passive"]) or out.has(o):
				continue
			if pass_i == 0 and used_heroes.has(o["hero"]):
				continue
			out.append(o)
			used_keys[o["passive"]] = true
			used_heroes[o["hero"]] = true


## What the offer means for the hero, for the offer card: [[good (bool), text]].
## Oath: how it works with the hero's ability (fits / clashes with the reason). Stat bonus: wasted when
## the stat matters little to the hero (stat_weights 1), strong when it matters most (3).
func offer_notes(o: Dictionary) -> Array:
	var out: Array = []
	if String(o.get("kind", "")) == "relic":
		var rd := relic_data(String(o["relic"]))
		out.append([not bool(rd.get("trade", false)), "For the whole house, for the rest of the run."])
		if bool(rd.get("trade", false)):
			out.append([false, "A trade: it also takes something."])
		return out
	var cls: String = o["hero"]
	if String(o.get("kind", "passive")) == "ability":
		var nk := String(o["ability"])
		out.append([true, "Replaces %s." % ability_name(ability_of(cls))])
		var lost: Array = []
		for k: String in heroes[cls]["passives"]:
			if _refine_of(k) == ability_of(cls):
				lost.append(passive_name(k))
		if not lost.is_empty():
			out.append([false, "Loses refinements: %s." % ", ".join(lost)])
		var o_key := oath_of(cls)
		if o_key != "":
			var od: Dictionary = units_data["passives"][o_key]
			if (od.get("clashes", {}) as Dictionary).has(nk):
				out.append([false, "Clashes with his oath %s: %s" % [od["name"], od["clashes"][nk]]])
			elif (od.get("fits", {}) as Dictionary).has(nk):
				out.append([true, "Fits his oath %s: %s" % [od["name"], od["fits"][nk]]])
		for cn: String in combos_with(cls, nk):
			out.append([true, "Combo with his bond partner: %s." % cn])
		var had := combos_with(cls, ability_of(cls))
		for cn: String in had:
			if not combos_with(cls, nk).has(cn):
				out.append([false, "Loses the combo %s." % cn])
		return out
	if String(o.get("kind", "passive")) != "passive":
		return out
	var d: Dictionary = units_data["passives"][o["passive"]]
	var kd: Dictionary = units_data["knights"][cls]
	var ab: String = ability_of(cls)
	var ab_name := String(units_data["abilities"].get(ab, {}).get("name", ab))
	if (d.get("fits", {}) as Dictionary).has(ab):
		out.append([true, "Fits %s: %s" % [ab_name, d["fits"][ab]]])
	if (d.get("clashes", {}) as Dictionary).has(ab):
		out.append([false, "Clashes with %s: %s" % [ab_name, d["clashes"][ab]]])
	var weights: Dictionary = kd.get("stat_weights", {})
	for st: String in (d.get("stats", {}) as Dictionary):
		var v := float(d["stats"][st])
		if v <= 0.0 or st == "sila":
			continue
		var w := int(weights.get(st, 2))
		var sname := String(units_data["stats"][st]["name"])
		if w <= 1:
			out.append([false, "%s matters little to the %s: mostly wasted." % [sname, kd.get("role", cls)]])
		elif w >= 3:
			out.append([true, "%s is what the %s needs most." % [sname, kd.get("role", cls)]])
	if bool(d.get("no_bond", false)) and (heroes[cls]["bond"] as Dictionary).is_empty():
		out.append([false, "No bond can form while he holds it."])
	return out


## Decline the reward after a battle for glory (`decline_glory` in the act).
func decline_offers() -> void:
	if not offer_declinable or offers().is_empty():
		return
	glory = minf(glory + float(act.get("decline_glory", 15)), _glory_max())
	_note("", "The house declined the reward (+%d glory)." % int(act.get("decline_glory", 15)))
	_offers = []
	_picks_left = 0


## Offers a choice outside the reward after a battle (event, camp): a ready list of offers, picks 1.
func _open_choice(title: String, list: Array) -> void:
	offer_title = title
	offer_declinable = false
	_offers = list
	_offers_ready = true
	_picks_left = 1 if not list.is_empty() else 0


func _glory_max() -> float:
	return float(house["glory"].get("carry_max", house["glory"]["max"]))


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
		if k == "refine":
			if String(d.get("ability", "")) != ability_of(cls):
				continue   # refinement of an ability the hero does not have
			k = "passive"
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
	match String(o.get("kind", "passive")):
		"max_hp":
			var st: Dictionary = heroes[o["hero"]]["stats"]
			st["odolnost"] = float(st.get("odolnost", 0.0)) + float(o.get("value", 0.1))
			_note("", "%s is hardened: Toughness +%d %% for good." % [hero_name(o["hero"]), roundi(float(o.get("value", 0.1)) * 100.0)])
		"ability":
			set_ability(o["hero"], String(o["ability"]))
		"relic":
			gain_relic(String(o["relic"]))
		"release_oath":
			var oo := oath_of(o["hero"])
			(heroes[o["hero"]]["passives"] as Array).erase(oo)
			heroes[o["hero"]]["oath_boost"] = {}
			_note("", "%s was released from his oath %s without shame." % [hero_name(o["hero"]), passive_name(oo)])
		_:
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

## The event of the current node with its texts filled in ({hero}, {a}, {b}, {fallen}).
func event() -> Dictionary:
	if node_type() != "udalost":
		return {}
	var ev: Dictionary = (events_data[node()["event"]] as Dictionary).duplicate(true)
	ev["name"] = _fill(String(ev["name"]))
	ev["text"] = _fill(String(ev["text"]))
	for o: Dictionary in ev["options"]:
		o["label"] = _fill(String(o["label"]))
		o["hint"] = _fill(String(o.get("hint", "")))
		o["text"] = _fill(String(o.get("text", "")))
	return ev


func _fill(t: String) -> String:
	for k: String in ["hero", "a", "b", "fallen"]:
		if event_ctx.has(k):
			var who := String(event_ctx[k])
			t = t.replace("{%s}" % k, hero_name(who) if heroes.has(who) and k != "fallen" else who)
	return t


## Picks the event for the node: the one from the map if it has not been used yet and its target exists,
## otherwise another unused one that is possible now (conditional events react to the house's story).
func _resolve_event() -> void:
	var order: Array = [String(node()["event"])]
	var rest: Array = (act["events"] as Array).duplicate()
	_shuffle(rest)
	order.append_array(rest)
	for key: String in order:
		if key == "" or used_events.has(key) or not events_data.has(key):
			continue
		var ctx := _event_target(events_data[key])
		if ctx.is_empty():
			continue
		node()["event"] = key
		used_events[key] = true
		event_ctx = ctx
		return
	used_events[String(node()["event"])] = true   # everything used: repeat the map's event
	event_ctx = _event_target(events_data[node()["event"]])


## The event's target ({"ok": true, ...}), or {} when the event is not possible now.
## target: melee (a random tank, cavalier or assassin), priest, oath (a hero holding an oath),
## unbonded_pair (two heroes without a bond, those with the most shared victories), fallen_successor
## (the successor of the last fallen hero, while he still lives).
func _event_target(ev: Dictionary) -> Dictionary:
	var ctx := {"ok": true}
	match String(ev.get("target", "")):
		"melee":
			var c: Array = []
			for cls: String in heroes:
				if not bool(units_data["knights"][cls].get("ranged", false)) and float(units_data["knights"][cls].get("heal", 0.0)) <= 0.0:
					c.append(cls)
			if c.is_empty():
				return {}
			ctx["hero"] = c[_rng.randi_range(0, c.size() - 1)]
		"priest":
			for cls: String in heroes:
				if float(units_data["knights"][cls].get("heal", 0.0)) > 0.0:
					ctx["hero"] = cls
			if not ctx.has("hero"):
				return {}
		"oath":
			var c: Array = []
			for cls: String in heroes:
				if oath_of(cls) != "":
					c.append(cls)
			if c.is_empty():
				return {}
			ctx["hero"] = c[_rng.randi_range(0, c.size() - 1)]
		"unbonded_pair":
			var free: Array = []
			for cls: String in heroes:
				if (heroes[cls]["bond"] as Dictionary).is_empty():
					free.append(cls)
			if free.size() < 2:
				return {}
			var best := []
			for i in free.size():
				for j in range(i + 1, free.size()):
					if best.is_empty() or wins_of(free[i], free[j]) > wins_of(best[0], best[1]):
						best = [free[i], free[j]]
			ctx["a"] = best[0]
			ctx["b"] = best[1]
		"fallen_successor":
			if fallen.is_empty():
				return {}
			var f: Dictionary = fallen[-1]
			var cls: String = f["cls"]
			if not heroes.has(cls) or String(heroes[cls]["name"]) == String(f["name"]):
				return {}
			ctx["hero"] = cls
			ctx["fallen"] = f["name"]
			ctx["fallen_passives"] = f["passives"]
	return ctx


## Why the option is not possible ("" = it is): e.g. not enough glory or no one can swear an oath.
func event_option_problem(i: int) -> String:
	var opts: Array = event().get("options", [])
	if event_done or i < 0 or i >= opts.size():
		return "Not possible."
	return _effects_problem(opts[i].get("effects", []))


func _effects_problem(effects: Array) -> String:
	for e: Dictionary in effects:
		if e.has("glory") and float(e["glory"]) < 0.0 and glory < -float(e["glory"]):
			return "Not enough glory (%d)." % int(-float(e["glory"]))
		if e.has("gift") and _gift_candidates(String(e["gift"]), String(e.get("who", ""))).is_empty():
			return "No one in the house can accept it."
		if e.has("oath_choice") and _gift_candidates("oath", "").is_empty():
			return "No one in the house can swear an oath."
		if e.has("passive_choice") and _gift_candidates("passive", String(e.get("who", "target"))).is_empty():
			return "%s has nothing more to learn." % _fill("{hero}")
		if e.has("inherit") and _inheritable().is_empty():
			return "Nothing of his can be passed on."
		if e.has("relic_choice") and relic_pool().is_empty():
			return "The house already holds every relic."
	return ""


func event_choose(i: int) -> void:
	if event_option_problem(i) != "":
		return
	var ev := event()
	var opt: Dictionary = ev["options"][i]
	var sname := String(ev["name"])
	if String(opt.get("text", "")) != "":
		_note(sname, String(opt["text"]))
	_apply_effects(opt.get("effects", []), sname)
	event_done = true
	_bond_open = true   # the event may have brought a pair to a bond
	_bond_offer = {}


## Event effects (udalosti.json). New since 07.11.2026: oath_choice, passive_choice, max_hp_choice, chance,
## pair_wins, next_battle, inherit, perm_stats, oath_boost, release_oath; who: target = the event's hero.
func _apply_effects(effects: Array, sname: String) -> void:
	for e: Dictionary in effects:
		if e.has("glory"):
			glory = clampf(glory + float(e["glory"]), 0.0, _glory_max())
		if e.has("heal"):
			_change_hp(e["heal"], 1.0)
		if e.has("wound"):
			_change_hp(e["wound"], -1.0)
		if e.has("gift"):
			var cands := _gift_candidates(String(e["gift"]), String(e.get("who", "")))
			if not cands.is_empty():
				var c: Array = cands[_rng.randi_range(0, cands.size() - 1)]
				_grant(c[0], c[1])
		if e.has("fled"):
			var f: Dictionary = e["fled"]
			for k: String in f:
				for n in int(f[k]):
					fled.append({"key": k, "stage": sname})
		if e.has("oath_choice"):
			var cands := _gift_candidates("oath", "")
			_shuffle(cands)
			var list: Array = []
			for c: Array in cands.slice(0, int(e["oath_choice"])):
				list.append({"hero": c[0], "passive": c[1]})
			_open_choice("oath", list)
		if e.has("passive_choice"):
			var cands := _gift_candidates("passive", String(e.get("who", "target")))
			_shuffle(cands)
			var list: Array = []
			for c: Array in cands.slice(0, int(e["passive_choice"])):
				list.append({"hero": c[0], "passive": c[1]})
			_open_choice("passive", list)
		if e.has("ability_choice"):
			var pool: Array = []
			for o: Dictionary in _ability_pool():
				if String(e.get("who", "")) != "target" or String(event_ctx.get("hero", "")) == String(o["hero"]):
					pool.append(o)
			_open_choice("ability", pool.slice(0, int(e["ability_choice"])))
		if e.has("relic_choice"):
			var list: Array = []
			for rk: String in relic_pool().slice(0, int(e["relic_choice"])):
				list.append({"hero": "", "kind": "relic", "relic": rk})
			if not list.is_empty():
				_open_choice("relic", list)
		if e.has("max_hp_choice"):
			var list: Array = []
			for cls: String in heroes:
				list.append({"hero": cls, "kind": "max_hp", "value": float(e["max_hp_choice"])})
			_open_choice("max_hp", list)
		if e.has("chance"):
			var win := _rng.randf() < float(e["chance"])
			var t := String(e.get("win_text" if win else "lose_text", ""))
			if t != "":
				_note(sname, _fill(t))
			_apply_effects(e.get("win" if win else "lose", []), sname)
		if e.has("pair_wins") and event_ctx.has("a"):
			var key := pair_key(event_ctx["a"], event_ctx["b"])
			pair_wins[key] = maxi(0, int(pair_wins.get(key, 0)) + int(e["pair_wins"]))
		if e.has("next_battle"):
			var nb: Dictionary = e["next_battle"]
			if nb.has("remove_pods"):
				next_battle["remove_pods"] = int(next_battle.get("remove_pods", 0)) + int(nb["remove_pods"])
			if nb.has("pair_stats") and event_ctx.has("a"):
				var stt: Dictionary = next_battle.get("stats", {})
				for cls: String in [event_ctx["a"], event_ctx["b"]]:
					var hs: Dictionary = stt.get(cls, {})
					for k: String in nb["pair_stats"]:
						hs[k] = float(hs.get(k, 0.0)) + float(nb["pair_stats"][k])
					stt[cls] = hs
				next_battle["stats"] = stt
		if e.has("inherit"):
			var can := _inheritable()
			if not can.is_empty():
				var pick: String = can[_rng.randi_range(0, can.size() - 1)]
				(heroes[event_ctx["hero"]]["passives"] as Array).append(pick)
				_note(sname, "%s inherited from %s: %s." % [hero_name(event_ctx["hero"]), event_ctx["fallen"], passive_name(pick)])
		if e.has("perm_stats") and event_ctx.has("hero"):
			var st: Dictionary = heroes[event_ctx["hero"]]["stats"]
			for k: String in e["perm_stats"]:
				st[k] = float(st.get(k, 0.0)) + float(e["perm_stats"][k])
		if e.has("oath_boost") and event_ctx.has("hero"):
			heroes[event_ctx["hero"]]["oath_boost"] = (e["oath_boost"] as Dictionary).duplicate()
		if e.has("release_oath") and event_ctx.has("hero"):
			var oo := oath_of(event_ctx["hero"])
			if oo != "":
				(heroes[event_ctx["hero"]]["passives"] as Array).erase(oo)
				heroes[event_ctx["hero"]]["oath_boost"] = {}


## Passives of the last fallen hero his successor could inherit (Grave of an Ancestor).
func _inheritable() -> Array:
	var out: Array = []
	if not event_ctx.has("fallen_passives"):
		return out
	var cls: String = event_ctx["hero"]
	for k: String in event_ctx["fallen_passives"]:
		if not is_oath(k) and not (heroes[cls]["passives"] as Array).has(k):
			out.append(k)
	return out


## Candidates [class, key] for a gift: who = "" anyone, "target" the event's hero.
func _gift_candidates(kind: String, who: String = "") -> Array:
	var out: Array = []
	for cls: String in heroes:
		if who == "target" and String(event_ctx.get("hero", "")) != cls:
			continue
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
		"random2":
			var keys: Array = heroes.keys()
			_shuffle(keys)
			targets = keys.slice(0, 2)
		"target":
			if event_ctx.has("hero"):
				targets.append(event_ctx["hero"])
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

## Camp choices (act `camp`): [{"id", "name", "desc", "cost", "needs" (hero / pair / ""), "problem"}].
func camp_options() -> Array:
	var out: Array = []
	var camp: Dictionary = act.get("camp", {})
	for id: String in camp:
		var c: Dictionary = camp[id]
		var problem := ""
		if camp_done:
			problem = "The house has already made its camp choice."
		elif glory < float(c.get("cost", 0)):
			problem = "Not enough glory (%d)." % int(c.get("cost", 0))
		out.append({"id": id, "name": c["name"], "desc": c.get("desc", ""), "cost": int(c.get("cost", 0)), "needs": String(c.get("needs", "")), "problem": problem})
	return out


## Makes the camp choice. arg = hero class (training, rite) or a pair "a|b" (feast).
func camp_choose(id: String, arg: String = "") -> bool:
	if node_type() != "tabor" or camp_done:
		return false
	var c: Dictionary = act.get("camp", {}).get(id, {})
	if c.is_empty() or glory < float(c.get("cost", 0)):
		return false
	match id:
		"rest":
			var heal := float(c.get("heal", act.get("camp_heal", 1.0)))
			for rk: String in relics:
				if relic_data(rk).has("rest_heal"):
					heal = minf(heal, float(relic_data(rk)["rest_heal"]))   # Heavy Banner
			for cls: String in heroes:
				heroes[cls]["hp"] = minf(1.0, hp_of(cls) + heal)
			_note("Camp", "The house rested by the fire, the wounds healed." if heal >= 1.0 else "The house rested by the fire, the wounds half healed.")
		"train":
			if not heroes.has(arg):
				return false
			var list: Array = []
			var keys := _passives_for(arg, "passive")
			_shuffle(keys)
			for k: String in keys.slice(0, int(c.get("choices", 3))):
				list.append({"hero": arg, "passive": k})
			if list.is_empty():
				return false
			_note("Camp", "%s trained by the fire." % hero_name(arg))
			_open_choice("training", list)
		"rite":
			if not heroes.has(arg):
				return false
			var list: Array = []
			if oath_of(arg) != "":
				list.append({"hero": arg, "kind": "release_oath"})
			else:
				var keys := _passives_for(arg, "oath")
				_shuffle(keys)
				for k: String in keys.slice(0, int(c.get("choices", 2))):
					list.append({"hero": arg, "passive": k})
			if list.is_empty():
				return false
			_open_choice("rite", list)
		"feast":
			var ab := arg.split("|")
			if ab.size() != 2 or not heroes.has(ab[0]) or not heroes.has(ab[1]) or ab[0] == ab[1]:
				return false
			glory -= float(c.get("cost", 0))
			for cls: String in heroes:
				heroes[cls]["hp"] = minf(1.0, hp_of(cls) + float(c.get("heal", 0.5)))
			var key := pair_key(ab[0], ab[1])
			pair_wins[key] = int(pair_wins.get(key, 0)) + int(c.get("wins", 1))
			_note("Camp", "A feast by the fire: %s and %s grew closer (shared victories: %d)." % [hero_name(ab[0]), hero_name(ab[1]), int(pair_wins[key])])
			_bond_open = true
			_bond_offer = {}
		_:
			return false
	camp_done = true
	return true


## Rest at the camp (kept for older calls).
func camp_rest() -> void:
	camp_choose("rest")


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


# --- house detail (roster page) ---

const WHEN_TEXT := {"allies_near": "with 2+ allies near", "alone": "when no ally is near", "moving": "while moving",
	"avenger": "after an ally falls", "vs_ranged": "against ranged enemies", "vs_grudge": "against whoever wounded an ally",
	"unseen": "against enemies not fighting him"}


## The hero's stat bonuses for the house page: [{key, name, desc, value (always on), cond: [text]}] for Attack, Power,
## Toughness, Haste. Might counts towards Attack and Power; an oath boosted by the Trial counts × its multiplier.
func hero_stats(cls: String) -> Array:
	var h: Dictionary = heroes[cls]
	var boost := float((h.get("oath_boost", {}) as Dictionary).get("mult", 1.0))
	var out: Array = []
	for st: String in ["utok", "moc", "odolnost", "pohotovost"]:
		var both := st == "utok" or st == "moc"
		var val := float((h.get("stats", {}) as Dictionary).get(st, 0.0))
		if both:
			val += float((h.get("stats", {}) as Dictionary).get("sila", 0.0))
		var cond: Array = []
		for k: String in h["passives"]:
			var d: Dictionary = units_data["passives"][k]
			var m := boost if d.get("kind", "") == "oath" else 1.0
			var sd: Dictionary = d.get("stats", {})
			var v := (float(sd.get(st, 0.0)) + (float(sd.get("sila", 0.0)) if both else 0.0)) * m
			if d.has("per_ancestor"):
				var pa: Dictionary = d["per_ancestor"]
				v += mini(fallen.size(), int(d.get("ancestors_max", 3))) * (float(pa.get(st, 0.0)) + (float(pa.get("sila", 0.0)) if both else 0.0))
			if is_zero_approx(v):
				continue
			if d.has("when"):
				cond.append("%+d %% %s (%s)" % [roundi(v * 100.0), WHEN_TEXT.get(String(d["when"]), String(d["when"])), d["name"]])
			else:
				val += v
		var b: Dictionary = h.get("bond", {})
		if not b.is_empty():
			var bd: Dictionary = units_data["bonds"][b["type"]]
			var bst: Dictionary = bd.get("stats", {})
			var lv := bond_level(cls)
			for sk: String in bst:
				if sk == st or (sk == "sila" and both):
					var arr: Array = bst[sk] if bst[sk] is Array else [bst[sk]]
					var bv := float(arr[clampi(lv - 1, 0, arr.size() - 1)])
					cond.append("%+d %% near %s (%s)" % [roundi(bv * 100.0), hero_name(b["with"]), bd["name"]])
		out.append({"key": st, "name": units_data["stats"][st]["name"], "desc": units_data["stats"][st].get("desc", ""), "value": val, "cond": cond})
	return out


## Refinements of the hero's current ability: [{key, name, desc, owned}].
func refinements_of(cls: String) -> Array:
	var out: Array = []
	for k: String in units_data["passives"]:
		if k.begins_with("_") or _refine_of(k) != ability_of(cls):
			continue
		var d: Dictionary = units_data["passives"][k]
		out.append({"key": k, "name": d["name"], "desc": d.get("desc", ""), "owned": (heroes[cls]["passives"] as Array).has(k)})
	return out


## How the hero's oath works with his ability: [good (bool), text], or [] when it is neutral or he has no oath.
func oath_note(cls: String) -> Array:
	var o := oath_of(cls)
	if o == "":
		return []
	var d: Dictionary = units_data["passives"][o]
	var ab := ability_of(cls)
	if (d.get("fits", {}) as Dictionary).has(ab):
		return [true, "Fits %s: %s" % [ability_name(ab), d["fits"][ab]]]
	if (d.get("clashes", {}) as Dictionary).has(ab):
		return [false, "Clashes with %s: %s" % [ability_name(ab), d["clashes"][ab]]]
	return []


## Shared victories the bond needs for its next level (0 = top level).
func next_bond_at(cls: String) -> int:
	var lv := bond_level(cls)
	var levels: Array = units_data["bond_rules"]["levels"]
	return int(levels[lv]) if lv < levels.size() else 0


## Combos of the house's bonded pairs: every combo the two classes could have, and what it still needs.
## [{id, name, desc, a, b (classes), a_ability, b_ability, ready, needs: [text]}], ready ones first.
func house_combos() -> Array:
	var out: Array = []
	var need_lv := int(units_data["bond_rules"].get("combo_level", 2))
	var seen := {}
	for cls: String in heroes:
		var b: Dictionary = heroes[cls]["bond"]
		if b.is_empty() or seen.has(pair_key(cls, b["with"])):
			continue
		var other: String = b["with"]
		seen[pair_key(cls, other)] = true
		for cid: String in units_data["combos"]:
			if cid.begins_with("_"):
				continue
			var c: Dictionary = units_data["combos"][cid]
			var ca := ""
			var cb := ""
			for pair: Array in [[cls, other], [other, cls]]:
				if (units_data["knights"][pair[0]]["abilities"] as Array).has(c["a"]) and (units_data["knights"][pair[1]]["abilities"] as Array).has(c["b"]):
					ca = pair[0]
					cb = pair[1]
			if ca == "":
				continue
			var needs: Array = []
			if bond_level(cls) < need_lv:
				needs.append("bond level %d (shared victories %d/%d)" % [need_lv, wins_of(ca, cb), int(units_data["bond_rules"]["levels"][need_lv - 1])])
			for x: Array in [[ca, c["a"]], [cb, c["b"]]]:
				if ability_of(x[0]) != x[1]:
					needs.append("%s must learn %s" % [hero_name(x[0]), ability_name(x[1])])
			out.append({"id": cid, "name": c["name"], "desc": c.get("desc", ""), "a": ca, "b": cb, "a_ability": c["a"], "b_ability": c["b"], "ready": needs.is_empty(), "needs": needs})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return bool(x["ready"]) and not bool(y["ready"]))
	return out
