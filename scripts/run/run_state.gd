extends RefCounted
## Stav zkušebního běhu (krok 1.7): sestava rodu, padlí, sláva, uprchlíci, odměny a kronika.
## Čistá logika bez grafiky, jde spustit v testech bez okna (tests/test_run.gd).
## Průběh: battle_setup(data) → bitva v simulaci → record_battle(sim.result())
## → dědictví přísah (legacy_*) → odměna (offers / pick_offer) → další bitva.

const Sim := preload("res://scripts/sim/battle_sim.gd")

var run_data: Dictionary
var units_data: Dictionary
var house: Dictionary

## Hrdinové podle třídy: {"name", "passives": Array, "glory": float, "kills": int, "joined": int (index bitvy)}
var heroes := {}
var fallen: Array = []          # [{"cls", "name", "stage", "passives", "glory"}]
var stage := 0                  # index další bitvy
var glory := 0.0                # sláva rodu, přenáší se mezi bitvami
var fled: Array = []            # uprchlíci čekající na návrat: [{"key", "stage"}]
var returned: Array = []        # uprchlíci, kteří se vrátili v poslední bitvě (pro kroniku)
var chronicle: Array = []       # [{"stage": název bitvy nebo "", "text"}]
var pending_legacy: Array = []  # přísahy padlých čekající na dědice: [{"oath", "from"}]
var over := ""                  # "" běží, "win", "lose"
var last_result := {}

var _offers: Array = []
var _offers_ready := false
var _rng := RandomNumberGenerator.new()
var _succ_used := {}


func _init(rng_seed: int = -1, run_key: String = "run_zkusebni") -> void:
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	run_data = Sim._read_json("res://data/%s.json" % run_key)
	units_data = Sim._read_json("res://data/units.json")
	house = Sim._read_json("res://data/rod_vlka.json")
	glory = float(house["glory"]["start"])
	var start: Dictionary = house.get("start_passives", {})
	for cls: String in units_data["knights"]:
		heroes[cls] = {
			"name": units_data["knights"][cls]["name"],
			"passives": (start.get(cls, []) as Array).duplicate(),
			"glory": 0.0,
			"joined": 0,
		}
	_note("", "%s vyráží. Pět hrdinů, tři bitvy." % house["name"])


# --- dotazy ---

func stage_count() -> int:
	return (run_data["stages"] as Array).size()


func stage_key(i: int = stage) -> String:
	return run_data["stages"][i]


func stage_name(i: int = stage) -> String:
	var sc := Sim._read_json("res://data/scenarios/%s.json" % stage_key(i))
	return sc.get("name", stage_key(i))


func load_stage_data() -> Dictionary:
	return Sim.load_data(stage_key())


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


# --- bitva ---

## Setup bitvy pro simulaci: pasivky, jména, sláva a vrácení uprchlíci.
func battle_setup(data: Dictionary) -> Dictionary:
	var setup := Sim.default_setup(data, 1)
	var pas := {}
	var names := {}
	for cls: String in heroes:
		pas[cls] = (heroes[cls]["passives"] as Array).duplicate()
		names[cls] = heroes[cls]["name"]
	setup["passives"] = pas
	setup["names"] = names
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
	for i in fled.size():
		var col := i % per_row
		var row := i / per_row
		var x := c.x + (col - (per_row - 1) / 2.0) * spread
		var y := c.y + row * spread
		rows.append([fled[i]["key"], x, y])
	return rows


## Zapíše výsledek bitvy (sim.result()) do běhu: padlí, nástupci, sláva, uprchlíci, kronika.
func record_battle(res: Dictionary) -> void:
	last_result = res
	var sname := stage_name()
	var sc := Sim._read_json("res://data/scenarios/%s.json" % stage_key())
	glory = minf(float(res["glory"]), float(house["glory"].get("carry_max", house["glory"]["max"])))
	var gb: Dictionary = res.get("glory_by", {})
	for cls: String in gb:
		if heroes.has(cls):
			heroes[cls]["glory"] = float(heroes[cls]["glory"]) + float(gb[cls])

	# vrácení uprchlíci se do kroniky zapíšou a jejich dluh je splacen
	returned = []
	if sc.has("returnees") and not fled.is_empty():
		returned = fled.duplicate()
		fled.clear()
		_note(sname, "Vrátili se uprchlíci: %s (z bitvy %s)." % [_count_foes(returned), _stages_of(returned)])

	if res["over"] == "win":
		_note(sname, "Vítězství: %s." % sname)
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
		if o != "" and stage + 1 < stage_count():
			pending_legacy.append({"oath": o, "from": h["name"]})
	if res["over"] != "win":
		over = "lose"
		pending_legacy.clear()
		_note("", "%s padl celý. Běh končí." % house["name"])
		return
	for cls: String in dead:
		if stage + 1 >= stage_count():
			break   # po závěrečné bitvě už nikdo nenastupuje
		var nm := _successor_name(cls)
		heroes[cls] = {"name": nm, "passives": [], "glory": 0.0, "joined": stage + 1}
		_note(sname, "Na místo padlého nastupuje %s." % nm)

	# uprchlíci z této bitvy se mohou vrátit později
	if not sc.has("returnees"):
		for k: String in res.get("fled", []):
			fled.append({"key": k, "stage": sname})
		if not (res.get("fled", []) as Array).is_empty():
			_note(sname, "Utekl%s %s." % ["o" if (res["fled"] as Array).size() > 1 else "", _count_foes(res["fled"])])

	stage += 1
	_offers_ready = false
	if stage >= stage_count():
		over = "win"
		_note("", "%s dokončil zkušební běh." % house["name"])


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

## Nabídky odměny: [{"hero": třída, "passive": klíč}], vybírá se jedna.
func offers() -> Array:
	if over != "":
		return []
	if not _offers_ready:
		_offers = _make_offers(int(run_data.get("offers", 3)))
		_offers_ready = true
	return _offers


func _make_offers(n: int) -> Array:
	var pool: Array = []
	for cls: String in heroes:
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
			if d.get("kind", "") == "oath" and has_oath:
				continue
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


func pick_offer(i: int) -> void:
	var list := offers()
	if i < 0 or i >= list.size():
		return
	var o: Dictionary = list[i]
	var cls: String = o["hero"]
	var key: String = o["passive"]
	(heroes[cls]["passives"] as Array).append(key)
	if is_oath(key):
		_note("", "%s složil přísahu %s." % [hero_name(cls), passive_name(key)])
	else:
		_note("", "%s získal: %s." % [hero_name(cls), passive_name(key)])
	_offers = []
	_offers_ready = true


# --- pomocné ---

func _note(sname: String, text: String) -> void:
	chronicle.append({"stage": sname, "text": text})


func _successor_name(cls: String) -> String:
	var pool: Array = run_data.get("successors", {}).get(cls, [])
	var i: int = _succ_used.get(cls, 0)
	_succ_used[cls] = i + 1
	if i < pool.size():
		return pool[i]
	return "%s %d." % [units_data["knights"][cls]["name"], i + 2]


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
