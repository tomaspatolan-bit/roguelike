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
	# no two elites (or two camps) in a row on one path: the second becomes a battle
	for f in range(1, n_floors - 1):
		for n: Dictionary in floors[f]:
			var t: String = n["type"]
			if t != "elita" and t != "tabor":
				continue
			for p: Dictionary in floors[f - 1]:
				if (p["next"] as Array).has(n["id"]) and p["type"] == t:
					n["type"] = "bitva"
					break
	# a camp right after a camp makes no sense: no camps on the floor before the last
	for n: Dictionary in floors[n_floors - 2]:
		if n["type"] == "tabor":
			n["type"] = "bitva"

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
