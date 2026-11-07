extends RefCounted
## Act map generator: floors with nodes and paths between them, the boss at the top.
## Pure logic (no graphics). Rules and numbers are in data/akt_*.json.
##
## Node: {"id", "floor" (1..floors, boss = floors + 1), "col" (order within the floor), "x" (0..1, for drawing),
##        "type" (bitva | elita | udalost | tabor | boss), "next": [id], "scenario" (battles), "event" (events)}

const TYPES := ["bitva", "elita", "udalost", "tabor"]


## Creates the map: {"floors": [[node, …] per floor], "boss": node, "nodes": {id: node}}.
static func generate(act: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var floors: Array = []
	var nodes := {}
	var n_floors: int = act["floors"]
	for f in range(1, n_floors + 1):
		var w := rng.randi_range(int(act["width_min"]), int(act["width_max"]))
		var row: Array = []
		for c in w:
			var node := {"id": "f%dn%d" % [f, c], "floor": f, "col": c, "x": (c + 1.0) / (w + 1.0), "type": "", "next": [], "scenario": "", "event": ""}
			row.append(node)
			nodes[node["id"]] = node
		floors.append(row)
	var boss := {"id": "boss", "floor": n_floors + 1, "col": 0, "x": 0.5, "type": "boss", "next": [], "scenario": String(act["boss"]), "event": ""}
	nodes["boss"] = boss

	# paths: each node leads to 1–2 nodes one floor up, each node has at least one path in,
	# paths do not cross (neighbours in order)
	for f in range(n_floors - 1):
		var a: Array = floors[f]
		var b: Array = floors[f + 1]
		var lo := 0
		for i in a.size():
			var target := roundi(float(i) * (b.size() - 1) / maxf(a.size() - 1, 1))
			target = maxi(target, lo)
			_link(a[i], b[target])
			# sometimes also to the neighbour on the right (a fork); the next node then starts no lower than here, so paths do not cross
			if target + 1 < b.size() and rng.randf() < 0.4:
				_link(a[i], b[target + 1])
				target += 1
			lo = target
		# a node without a path in gets one from the nearest neighbour below
		for j in b.size():
			if _incoming(a, b[j]["id"]) == 0:
				var best: Dictionary = a[0]
				for cand: Dictionary in a:
					if absf(float(cand["x"]) - float(b[j]["x"])) < absf(float(best["x"]) - float(b[j]["x"])):
						best = cand
				_link(best, b[j])
	for n: Dictionary in floors[n_floors - 1]:
		_link(n, boss)

	# node types
	var weights: Dictionary = act["weights"]
	for f in n_floors:
		for n: Dictionary in floors[f]:
			var floor_i := f + 1
			if floor_i == 1:
				n["type"] = act["first_floor"]
			elif floor_i == n_floors:
				n["type"] = act["last_floor"]
			else:
				n["type"] = _pick_type(weights, floor_i >= int(act["elite_from"]), rng)
	_balance_types(floors, n_floors, act, rng)

	# content: battles and elites from shuffled lists, events without repeats while possible
	var bag := {"bitva": _bag(act["battles"], rng), "elita": _bag(act["elites"], rng), "udalost": _bag(act["events"], rng)}
	var used := {"bitva": 0, "elita": 0, "udalost": 0}
	for f in n_floors:
		for n: Dictionary in floors[f]:
			var t: String = n["type"]
			if not bag.has(t):
				continue
			var list: Array = bag[t]
			var key: String = list[int(used[t]) % list.size()]
			used[t] = int(used[t]) + 1
			if t == "udalost":
				n["event"] = key
			else:
				n["scenario"] = key
	return {"floors": floors, "boss": boss, "nodes": nodes}


## Smart shuffle (decision 07.11.2026, a playtester got three events in a row): repairs node types until
## 1) no two nodes of the same non-battle type follow each other on a path (event, elite, camp),
## 2) a path never has more than `max_calm` nodes without a fight in a row (event, camp),
## 3) a node with several paths up always offers different types (a real choice),
## 4) no camp on the floor before the last (that floor is all camps).
## First and last floors keep their fixed types.
static func _balance_types(floors: Array, n_floors: int, act: Dictionary, rng: RandomNumberGenerator) -> void:
	var max_calm := int(act.get("max_calm", 2))
	var weights: Dictionary = act["weights"]
	for n: Dictionary in floors[n_floors - 2]:
		if n["type"] == "tabor":
			n["type"] = "bitva"
	for pass_i in 30:
		var changed := false
		var parents := {}
		for f in range(n_floors - 1):
			for p: Dictionary in floors[f]:
				for id: String in p["next"]:
					if not parents.has(id):
						parents[id] = []
					(parents[id] as Array).append(p)
		# 1) the same non-battle type twice in a row: the second becomes a battle
		for f in range(1, n_floors - 1):
			for n: Dictionary in floors[f]:
				var t: String = n["type"]
				if t == "bitva":
					continue
				for p: Dictionary in parents.get(n["id"], []):
					if p["type"] == t:
						n["type"] = "bitva"
						changed = true
						break
		# 2) too long without a fight: the node that exceeds it (or its parent before the fixed last floor) becomes a battle
		var calm := {}
		for f in n_floors:
			for n: Dictionary in floors[f]:
				var c := 0
				if _calm(n["type"]):
					c = 1
					for p: Dictionary in parents.get(n["id"], []):
						c = maxi(c, int(calm.get(p["id"], 0)) + 1)
				calm[n["id"]] = c
				if c > max_calm:
					var fix: Dictionary = n
					if f == n_floors - 1:
						for p: Dictionary in parents.get(n["id"], []):
							if _calm(p["type"]):
								fix = p
								break
					if fix != n or f > 0:
						if fix["floor"] != 1 and fix["floor"] != n_floors:
							fix["type"] = "bitva"
							changed = true
		# 3) a real choice: the paths from a node must not all lead to the same type
		for f in range(n_floors - 2):
			for n: Dictionary in floors[f]:
				var nx: Array = n["next"]
				if nx.size() < 2:
					continue
				var types := {}
				var kids: Array = []
				for row: Dictionary in floors[f + 1]:
					if nx.has(row["id"]):
						kids.append(row)
						types[row["type"]] = true
				if types.size() > 1:
					continue
				var fixed := false
				if kids[0]["type"] != "bitva":
					kids[rng.randi_range(0, kids.size() - 1)]["type"] = "bitva"
					fixed = true
				else:
					var order: Array = kids.duplicate()
					for i in range(order.size() - 1, 0, -1):
						var j := rng.randi_range(0, i)
						var tmp: Variant = order[i]
						order[i] = order[j]
						order[j] = tmp
					for k: Dictionary in order:
						var alt := _alt_type(k, parents, floors, n_floors, act, calm, rng)
						if alt != "bitva":
							k["type"] = alt
							fixed = true
							break
				if not fixed:
					# no type fits: drop a path that is not needed, so the map does not pretend to offer a choice
					for k: Dictionary in kids:
						if nx.size() >= 2 and (parents.get(k["id"], []) as Array).size() > 1:
							nx.erase(k["id"])
							fixed = true
							break
				if not fixed:
					continue
				changed = true
		if not changed:
			break
	# a fork that still leads to one type only (no type fits the rules): drop a path that is not needed,
	# so the map never pretends to offer a choice
	for f in range(n_floors - 2):
		for n: Dictionary in floors[f]:
			var nx: Array = n["next"]
			if nx.size() < 2:
				continue
			var types := {}
			for row: Dictionary in floors[f + 1]:
				if nx.has(row["id"]):
					types[row["type"]] = true
			if types.size() > 1:
				continue
			for id: String in nx.duplicate():
				if nx.size() < 2:
					break
				if _incoming(floors[f], id) > 1:
					nx.erase(id)


## Another type for a battle node so a fork offers a choice: an elite (from elite_from) or an event or camp
## that does not repeat a parent's type and does not make the calm streak too long. Battle when nothing fits.
static func _alt_type(k: Dictionary, parents: Dictionary, floors: Array, n_floors: int, act: Dictionary, calm: Dictionary, rng: RandomNumberGenerator) -> String:
	var near := {}
	var calm_in := 0
	for p: Dictionary in parents.get(k["id"], []):
		near[p["type"]] = true
		calm_in = maxi(calm_in, int(calm.get(p["id"], 0)))
	var f := int(k["floor"])   # children of the same type are fixed by rule 1 in the next pass (the later node yields)
	var cands: Array = ["udalost", "tabor"]
	if f >= int(act["elite_from"]):
		cands.append("elita")
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	for t: String in cands:
		if near.has(t):
			continue
		if t == "tabor" and f >= n_floors - 1:
			continue
		if _calm(t) and calm_in + 1 > int(act.get("max_calm", 2)) - (1 if f == n_floors - 1 else 0):
			continue
		return t
	return "bitva"


## A node without a fight (event, camp).
static func _calm(t: String) -> bool:
	return t == "udalost" or t == "tabor"


static func _link(a: Dictionary, b: Dictionary) -> void:
	if not (a["next"] as Array).has(b["id"]):
		(a["next"] as Array).append(b["id"])


static func _incoming(row: Array, id: String) -> int:
	var n := 0
	for a: Dictionary in row:
		if (a["next"] as Array).has(id):
			n += 1
	return n


static func _pick_type(weights: Dictionary, elite_ok: bool, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for t: String in weights:
		if t == "elita" and not elite_ok:
			continue
		total += float(weights[t])
	var r := rng.randf() * total
	for t: String in weights:
		if t == "elita" and not elite_ok:
			continue
		r -= float(weights[t])
		if r <= 0.0:
			return t
	return "bitva"


static func _bag(list: Array, rng: RandomNumberGenerator) -> Array:
	var a := list.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
	return a
