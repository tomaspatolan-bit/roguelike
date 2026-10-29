extends RefCounted
## Stav běhu: mapa aktu, sestava rodu (zdraví, pasivky, přísahy), padlí, sláva, uprchlíci, odměny a kronika.
## Čistá logika bez grafiky, jde spustit v testech bez okna (tests/test_run.gd).
##
## Průběh: available() → choose(id) → podle typu uzlu:
##   bitva / elita / boss: battle_setup(data) → bitva → record_battle(sim.result()) → dědictví (legacy_*) → odměna (offers / pick_offer)
##   udalost: event() → event_option_problem(i) / event_choose(i)
##   tabor: camp_rest()
## a zpět na mapu. Po bossovi je akt (zatím celý běh) vyhraný.

const Sim := preload("res://scripts/sim/battle_sim.gd")
const ActMap := preload("res://scripts/run/act_map.gd")

const NODE_NAMES := {"bitva": "Bitva", "elita": "Elita", "udalost": "Událost", "tabor": "Tábor", "boss": "Boss"}

var act: Dictionary
var units_data: Dictionary
var house: Dictionary
var events_data: Dictionary
var map: Dictionary

## Hrdinové podle třídy: {"name", "passives": Array, "glory": float, "hp": podíl zdraví 0..1, "joined": patro}
var heroes := {}
var fallen: Array = []          # [{"cls", "name", "stage", "passives", "glory"}]
var node_id := ""               # uzel, kde rod právě je ("" = před prvním patrem)
var path: Array = []            # navštívené uzly popořadě
var battles_won := 0
var glory := 0.0                # sláva rodu, přenáší se mezi bitvami (nejvýš carry_max)
var fled: Array = []            # uprchlíci čekající na návrat: [{"key", "stage"}]
var returned: Array = []        # uprchlíci, kteří se vrátili v poslední bitvě (pro kroniku)
var chronicle: Array = []       # [{"stage": název uzlu nebo "", "text"}]
var pending_legacy: Array = []  # přísahy padlých čekající na dědice: [{"oath", "from"}]
var over := ""                  # "" běží, "win", "lose"
var last_result := {}
var event_done := false         # událost v aktuálním uzlu už je rozhodnutá
var camp_done := false          # v aktuálním táboře už se odpočívalo

var _offers: Array = []
var _offers_ready := false
var _picks_left := 0
var _rng := RandomNumberGenerator.new()
var _succ_used := {}


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
		}
	map = ActMap.generate(act, _rng)
	_note("", "%s vyráží do kraje %s. Pět hrdinů, %d pater, na konci Hejtman Kuno." % [house["name"], act["name"], int(act["floors"])])


# --- mapa ---

func node(id: String = node_id) -> Dictionary:
	return map["nodes"].get(id, {})


func node_type(id: String = node_id) -> String:
	return String(node(id).get("type", ""))


func floor_count() -> int:
	return int(act["floors"]) + 1   # + boss


func current_floor() -> int:
	return int(node().get("floor", 0))


## Kam se dá jít: na začátku celé první patro, jinak cesty z aktuálního uzlu.
## Dokud není uzel vyřízený (dědictví, odměna, událost), nikam.
func available() -> Array:
	if over != "" or not node_finished():
		return []
	if node_id == "":
		var out: Array = []
		for n: Dictionary in map["floors"][0]:
			out.append(n["id"])
		return out
	return (node()["next"] as Array).duplicate()


## Je aktuální uzel vyřízený (a dá se jít dál)?
func node_finished() -> bool:
	match node_type():
		"":
			return true
		"bitva", "elita", "boss":
			return last_result.has("node") and last_result["node"] == node_id and not has_legacy() and offers().is_empty()
		"udalost":
			return event_done
		"tabor":
			return true   # odpočinek je volba, dá se i pokračovat bez něj
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


## Název uzlu pro hráče a kroniku (u bitvy název scénáře, u události její název).
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


## Popis scénáře pro mapu (název, podtitul, úkol); varianty se skládají se základem.
func scenario_info(key: String) -> Dictionary:
	return Sim.read_scenario(key)


func is_battle_node(id: String = node_id) -> bool:
	return ["bitva", "elita", "boss"].has(node_type(id))


# --- dotazy na rod ---

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


# --- bitva ---

func load_stage_data() -> Dictionary:
	return Sim.load_data(String(node()["scenario"]))


## Setup bitvy pro simulaci: pasivky, jména, zdraví, sláva a vrácení uprchlíci.
func battle_setup(data: Dictionary) -> Dictionary:
	var setup := Sim.default_setup(data, 1)
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
	setup["extra_enemies"] = returnee_rows(data["scenario"])
	return setup


## Řádky nepřátel pro uprchlíky, kteří se vrátí (jen ve scénáři s returnees).
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
		rows.append([fled[i]["key"], x, y])
	return rows


## Zapíše výsledek bitvy (sim.result()) do běhu: padlí, nástupci, zranění, sláva, uprchlíci, kronika.
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

	# vrácení uprchlíci se do kroniky zapíšou a jejich dluh je splacen
	returned = []
	if sc.has("returnees") and not fled.is_empty():
		returned = fled.slice(0, int(sc["returnees"].get("max", 99)))
		fled.clear()
		_note(sname, "Vrátili se uprchlíci: %s (z: %s)." % [_count_foes(returned), _stages_of(returned)])

	if res["over"] == "win":
		_note(sname, "Vítězství: %s." % sname)
		battles_won += 1
	else:
		_note(sname, "Porážka: %s. Padli všichni." % sname)

	# porušené přísahy zmizí
	for cls: String in res.get("oaths_broken", []):
		var o := oath_of(cls)
		if o != "":
			(heroes[cls]["passives"] as Array).erase(o)
			_note(sname, "%s porušil přísahu %s." % [hero_name(cls), passive_name(o)])

	# padlí: zapsat, přísaha čeká na dědice, nastoupí nástupce
	var dead: Array = res.get("dead", [])
	for cls: String in dead:
		var h: Dictionary = heroes[cls]
		fallen.append({"cls": cls, "name": h["name"], "stage": sname, "passives": (h["passives"] as Array).duplicate(), "glory": h["glory"]})
		_note(sname, "%s (%s) padl. Přinesl rodu %d slávy." % [h["name"], class_name_of(cls), roundi(float(h["glory"]))])
		var o := oath_of(cls)
		if o != "" and not is_boss:
			pending_legacy.append({"oath": o, "from": h["name"]})
	if res["over"] != "win":
		over = "lose"
		pending_legacy.clear()
		_note("", "%s padl celý. Běh končí." % house["name"])
		return

	# zranění se nesou, po bitvě se kousek doléčí
	var hp: Dictionary = res.get("hp", {})
	for cls: String in heroes:
		if not dead.has(cls) and hp.has(cls):
			heroes[cls]["hp"] = minf(1.0, float(hp[cls]) + float(act.get("regen", 0.0)))

	if not is_boss:
		for cls: String in dead:
			var nm := _successor_name(cls)
			heroes[cls] = {"name": nm, "passives": [], "glory": 0.0, "hp": 1.0, "joined": current_floor()}
			_note(sname, "Na místo padlého nastupuje %s." % nm)

	# uprchlíci z této bitvy se mohou vrátit později
	if not sc.has("returnees"):
		for k: String in res.get("fled", []):
			fled.append({"key": k, "stage": sname})
		if not (res.get("fled", []) as Array).is_empty():
			_note(sname, "Utekl%s %s." % ["o" if (res["fled"] as Array).size() > 1 else "", _count_foes(res["fled"])])

	_offers_ready = false
	if is_boss:
		over = "win"
		_note("", "%s porazil Hejtmana Kuna a dobyl kraj %s." % [house["name"], act["name"]])
		return
	var elite := node_type() == "elita"
	_picks_left = int(act.get("elite_picks", 2)) if elite else 1


# --- dědictví přísahy ---

func has_legacy() -> bool:
	return not pending_legacy.is_empty()


func legacy_current() -> Dictionary:
	return pending_legacy[0] if has_legacy() else {}


## Kdo může přísahu zdědit: živí hrdinové bez přísahy (vč. nástupců).
func legacy_candidates() -> Array:
	var out: Array = []
	for cls: String in heroes:
		if oath_of(cls) == "":
			out.append(cls)
	return out


## Přidělí aktuální přísahu padlého hrdinovi (cls = "" → přísaha zanikne).
func resolve_legacy(cls: String) -> void:
	if not has_legacy():
		return
	var l: Dictionary = pending_legacy.pop_front()
	if cls != "" and legacy_candidates().has(cls):
		(heroes[cls]["passives"] as Array).append(l["oath"])
		_note("", "%s převzal přísahu %s, kterou zanechal %s." % [hero_name(cls), passive_name(l["oath"]), l["from"]])
	else:
		_note("", "Přísaha %s zemřela s %s." % [passive_name(l["oath"]), l["from"]])
	_offers_ready = false


# --- odměna po bitvě ---

## Kolik odměn z nabídky si hráč ještě vybere (elita 2, jinak 1).
func picks_left() -> int:
	return _picks_left


## Nabídky odměny: [{"hero": třída, "passive": klíč}].
func offers() -> Array:
	if over != "" or _picks_left <= 0 or has_legacy():
		return []
	if not _offers_ready:
		var n := int(act.get("elite_offers", 4)) if node_type() == "elita" else int(act.get("offers", 3))
		_offers = _make_offers(n)
		_offers_ready = true
	return _offers


## Je nabídka (pořád) platná? Po první volbě u elity může přísaha přestat sedět.
func offer_valid(o: Dictionary) -> bool:
	var cls: String = o["hero"]
	var key: String = o["passive"]
	if (heroes[cls]["passives"] as Array).has(key):
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
	# nejdřív různí hrdinové a různé pasivky, pak cokoli zbylo
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


## Pasivky, které hrdina může dostat (kind = "" všechny, jinak jen passive / oath).
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
		# zbylé nabídky, které už nesedí (druhá přísaha), se vyřadí
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
		_note("", "%s složil přísahu %s." % [hero_name(cls), passive_name(key)])
	else:
		_note("", "%s získal: %s." % [hero_name(cls), passive_name(key)])


# --- událost ---

func event() -> Dictionary:
	if node_type() != "udalost":
		return {}
	return events_data[node()["event"]]


## Proč volba nejde ("" = jde): třeba chybí sláva nebo nikdo nemůže složit přísahu.
func event_option_problem(i: int) -> String:
	var opts: Array = event().get("options", [])
	if event_done or i < 0 or i >= opts.size():
		return "Nejde."
	for e: Dictionary in opts[i].get("effects", []):
		if e.has("glory") and float(e["glory"]) < 0.0 and glory < -float(e["glory"]):
			return "Chybí sláva (%d)." % int(-float(e["glory"]))
		if e.has("gift") and _gift_candidates(String(e["gift"])).is_empty():
			return "Nikdo z rodu to nemůže přijmout."
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
		# zranění z události nikoho nezabije
		heroes[cls]["hp"] = clampf(hp_of(cls) + sign * frac, 0.1, 1.0)
		if sign < 0.0:
			_note("", "%s je zraněn (%d %% zdraví)." % [hero_name(cls), roundi(hp_of(cls) * 100.0)])


# --- tábor ---

func camp_rest() -> void:
	if node_type() != "tabor" or camp_done:
		return
	for cls: String in heroes:
		heroes[cls]["hp"] = minf(1.0, hp_of(cls) + float(act.get("camp_heal", 1.0)))
	camp_done = true
	_note("Tábor", "Rod odpočíval u ohně, zranění se zahojila.")


# --- pomocné ---

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
