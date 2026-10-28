class_name BattleSim
extends RefCounted
## Logika jedné bitvy bez grafiky. Dá se spustit v testech bez okna.
##
## Souřadnice: Vector2(x, y), x doprava, y dopředu (k nepříteli), 1 jednotka = 1 m.
## Scéna to převádí na 3D jako Vector3(x, výška, -y).
## Data (statistiky, rod, scénář) přicházejí z JSON souborů ve složce data/.

const SIDE_KNIGHT := "k"
const SIDE_FOE := "e"


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
	var color: Color = Color.WHITE
	var pos: Vector2
	var home: Vector2
	var posture: String = "drzet"
	var t: float = 0.0
	var heal_t: float = 0.0
	var atk: float = 0.0
	var hit: float = 0.0
	var face: Vector2 = Vector2(0, 1)
	var moving: bool = false

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
var bridge: float
var aura_radius: float

# --- stav ---
var t: float = 0.0
var units: Array[Unit] = []
var projectiles: Array[Projectile] = []
var events: Array[Dictionary] = []
var glory: float = 0.0
var fx: Dictionary = {}
var signals: int = 0
var signals_used: int = 0
var shouts_used: int = 0
var bearer_id: String = ""
var banner_pos: Vector2 = Vector2.ZERO
var banner_down: bool = false
var picker_id: String = ""
var pick_t: float = 0.0
var oath_kept: bool = true
var task_ok: bool = true
var over: String = ""
var _next_id: int = 0
var _rng := RandomNumberGenerator.new()


## setup = {"signals": int, "pos": {key: Vector2}, "posture": {key: String}}
func _init(data: Dictionary, setup: Dictionary, rng_seed: int = -1) -> void:
	units_data = data["units"]
	house = data["house"]
	scenario = data["scenario"]
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	river_lo = scenario["river_lo"]
	river_hi = scenario["river_hi"]
	bridge = scenario["bridge_half_width"]
	aura_radius = house["aura"]["radius"]
	glory = house["glory"]["start"]
	for k: String in house["shouts"]:
		fx[k] = 0.0
	signals = setup.get("signals", 1)
	bearer_id = scenario["banner_bearer"]

	var knights_data: Dictionary = units_data["knights"]
	for key: String in knights_data:
		var u := _make_unit(key, SIDE_KNIGHT, knights_data[key])
		var p: Vector2 = setup["pos"][key]
		u.pos = p
		u.home = p
		u.posture = setup["posture"][key]
		u.face = Vector2(0, 1)
		units.append(u)
		if not posture_allowed(u.id, u.posture):
			u.posture = "drzet"

	var foes_data: Dictionary = units_data["foes"]
	var i := 0
	for row: Array in scenario["enemies"]:
		var fkey: String = row[0]
		var u := _make_unit(fkey, SIDE_FOE, foes_data[fkey])
		u.id = "e%d" % i
		u.pos = Vector2(row[1], row[2])
		u.home = u.pos
		u.face = Vector2(0, -1)
		u.t = _rng.randf() * 0.6
		units.append(u)
		i += 1


static func load_data(scenario_path: String = "res://data/scenarios/most_pres_reku.json") -> Dictionary:
	return {
		"units": _read_json("res://data/units.json"),
		"house": _read_json("res://data/rod_vlka.json"),
		"scenario": _read_json(scenario_path),
	}


## Výchozí rozestavení ze scénáře.
static func default_setup(data: Dictionary, signal_count: int = 1) -> Dictionary:
	var pos := {}
	var posture := {}
	var deploy: Dictionary = data["scenario"]["deploy"]
	for key: String in deploy:
		var p: Array = deploy[key]["pos"]
		pos[key] = Vector2(p[0], p[1])
		posture[key] = deploy[key]["posture"]
	return {"signals": signal_count, "pos": pos, "posture": posture}


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
	u.color = Color.html(d.get("color", "#ffffff"))
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


func aura_center() -> Unit:
	if bearer_id == "":
		return null
	var b := by_id(bearer_id)
	return b if b != null and b.alive() else null


func in_aura(u: Unit) -> bool:
	var c := aura_center()
	return c != null and c.pos.distance_to(u.pos) <= aura_radius


func can_shout(key: String) -> bool:
	if over != "" or not house["shouts"].has(key):
		return false
	var cost: float = house["shouts"][key]["cost"]
	var active: float = fx[key]
	return glory >= cost and aura_center() != null and active <= 0.0


func can_signal() -> bool:
	return over == "" and signals > 0 and aura_center() != null


## Přísaha, kterou rytíř právě drží. Prázdný slovník, když žádnou nemá nebo ji porušil.
func oath_of(id: String) -> Dictionary:
	if not oath_kept:
		return {}
	var oaths: Dictionary = house["oaths"]
	for k: String in oaths:
		var o: Dictionary = oaths[k]
		if o["knight"] == id:
			return o
	return {}


func has_oath(id: String) -> bool:
	return not oath_of(id).is_empty()


## Smí rytíř mít tento postoj? Přísaha může postoje zakázat.
func posture_allowed(id: String, posture: String) -> bool:
	var forbidden: Array = oath_of(id).get("forbidden_postures", [])
	return not forbidden.has(posture)


## Název postoje pro hráče. Přísaha může postoj přejmenovat (u tanka "Držet pozici" = "Stát pevně").
func posture_name(id: String, posture: String) -> String:
	var names: Dictionary = oath_of(id).get("posture_names", {})
	if names.has(posture):
		return names[posture]
	return units_data["postures"][posture]


func _no_retreat(u: Unit) -> bool:
	return bool(oath_of(u.id).get("no_retreat", false))


func _dmg_mult(u: Unit) -> float:
	if u.side != SIDE_KNIGHT:
		return 1.0
	var m := 1.0
	var a := in_aura(u)
	if a:
		m += float(house["aura"]["dmg_bonus"])
	var zarod: float = fx.get("zarod", 0.0)
	if a and zarod > 0.0:
		m += float(house["shouts"]["zarod"]["dmg_bonus"])
	if has_oath(u.id):
		m += float(oath_of(u.id).get("dmg_bonus", 0.0))
	return m


func _taken_mult(u: Unit) -> float:
	var m := 1.0 - u.armor
	var hradba: float = fx.get("hradba", 0.0)
	if u.side == SIDE_KNIGHT and hradba > 0.0 and in_aura(u):
		m *= float(house["shouts"]["hradba"]["damage_taken"])
	return m


func _nearest(list: Array[Unit], from: Vector2) -> Unit:
	var best: Unit = null
	var bd := INF
	for e in list:
		var d := from.distance_to(e.pos)
		if d < bd:
			bd = d
			best = e
	return best


# =============================================================== příkazy hráče

func shout(key: String) -> bool:
	if not can_shout(key):
		return false
	glory -= float(house["shouts"][key]["cost"])
	fx[key] = float(house["shouts"][key]["duration"])
	shouts_used += 1
	_log("Pokřik: %s" % house["shouts"][key]["name"], true)
	return true


func use_signal() -> bool:
	if not can_signal():
		return false
	signals -= 1
	signals_used += 1
	_log("Signál praporu: čas stojí", true)
	return true


## Rozkaz přesunu: rytíř se přesune na místo a drží ho.
func order_move(id: String, target: Vector2) -> void:
	var u := by_id(id)
	if u == null or not u.alive():
		return
	u.home = target
	u.posture = "drzet"
	_log("%s: nová pozice" % u.name, false)


## Změna postoje. Vrací false, když ho zakazuje přísaha (pak se nic nemění).
func set_posture(id: String, posture: String) -> bool:
	var u := by_id(id)
	if u == null or not posture_allowed(id, posture):
		return false
	u.posture = posture
	if posture == "drzet":
		u.home = u.pos
	return true


## Je rozkaz pro rytíře ústupem? (vzdálí ho od nejbližšího nepřítele o víc než 1 m)
func is_retreat(id: String, target: Vector2) -> bool:
	var u := by_id(id)
	var foe := _nearest(living(SIDE_FOE), u.pos)
	if foe == null:
		return false
	return target.distance_to(foe.pos) > u.pos.distance_to(foe.pos) + 1.0


func break_oath() -> void:
	if not oath_kept:
		return
	oath_kept = false
	var cost: float = house["oaths"]["nikdy_neustoupi"]["break_glory_cost"]
	glory = maxf(0.0, glory - cost)
	_log("Sir Bořek porušil přísahu", true)


# =============================================================== simulace

func _log(text: String, hot: bool) -> void:
	events.append({"type": "log", "t": t, "text": text, "hot": hot})


func _gain_glory(v: float) -> void:
	glory = minf(float(house["glory"]["max"]), glory + v)


func _band(y: float) -> int:
	if y < river_lo:
		return 0
	if y > river_hi:
		return 2
	return 1


func _in_water(p: Vector2) -> bool:
	return p.y > river_lo - 0.3 and p.y < river_hi + 0.3 and absf(p.x) > bridge


## Kam jít, aby se jednotka dostala k cíli přes most.
func _nav(u: Unit, target: Vector2) -> Vector2:
	var us := _band(u.pos.y)
	var ts := _band(target.y)
	if us == ts or (us == 1 and absf(u.pos.x) <= bridge):
		if us == 1 and ts != 1:
			return Vector2(clampf(u.pos.x, -0.9, 0.9), river_lo - 0.5 if ts == 0 else river_hi + 0.5)
		return target
	if absf(u.pos.x) <= 1.0 and u.pos.y >= river_lo - 0.7 and u.pos.y <= river_hi + 0.7:
		return Vector2(clampf(u.pos.x, -0.9, 0.9), river_hi + 0.5 if us == 0 else river_lo - 0.5)
	return Vector2(clampf(u.pos.x, -0.9, 0.9), river_lo - 0.6 if us == 0 else river_hi + 0.6)


func _walk(u: Unit, target: Vector2, dt: float, stop: float = 0.0) -> void:
	var w := _nav(u, target)
	var dv := w - u.pos
	var d := dv.length()
	if d < 0.000001 or (d <= maxf(stop, 0.05) and w == target):
		u.moving = false
		return
	var st := minf(d, u.speed * dt)
	var old := u.pos
	u.pos += dv / d * st
	u.face = dv / d
	u.moving = true
	if _in_water(u.pos):
		u.pos = old


func _face_to(u: Unit, tg: Unit) -> void:
	var v := tg.pos - u.pos
	if v.length() > 0.0001:
		u.face = v.normalized()


func _attack(u: Unit, tg: Unit) -> void:
	_face_to(u, tg)
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
		p.dmg = u.dmg * _dmg_mult(u)
		projectiles.append(p)
		events.append({"type": "shoot", "id": u.id})
	else:
		_hurt(u, tg, u.dmg * _dmg_mult(u))


func _hurt(att: Unit, tg: Unit, raw: float) -> void:
	if not tg.alive():
		return
	tg.hp -= raw * _taken_mult(tg)
	tg.hit = 0.18
	if att != null and att.side == SIDE_KNIGHT:
		_gain_glory(float(house["glory"]["per_hit"]))
	if tg.hp > 0.0:
		return
	tg.hp = 0.0
	events.append({"type": "death", "id": tg.id})
	if tg.side == SIDE_FOE:
		if att != null and att.side == SIDE_KNIGHT:
			_gain_glory(float(house["glory"]["per_kill"]))
		return
	_log("%s padl" % tg.name, true)
	if tg.id == scenario["optional_task"]["protect"]:
		task_ok = false
	if tg.id == bearer_id:
		bearer_id = ""
		banner_pos = tg.pos
		banner_down = true
		picker_id = ""
		pick_t = 0.0
		events.append({"type": "autopause", "text": "%s padl a prapor leží na zemi. Aura i pokřiky nefungují, dokud ho někdo nezvedne." % tg.name})


func _knight_think(u: Unit, dt: float) -> void:
	var foes := living(SIDE_FOE)
	if foes.is_empty():
		u.moving = false
		return

	# kněz léčí nejzraněnějšího rytíře v dosahu
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

	# běží pro padlý prapor
	if picker_id == u.id and banner_down:
		if u.pos.distance_to(banner_pos) > 0.6:
			_walk(u, banner_pos, dt, 0.5)
			pick_t = 0.0
			return
		u.moving = false
		pick_t += dt
		if pick_t >= float(house["banner"]["pickup_time"]):
			bearer_id = u.id
			banner_down = false
			picker_id = ""
			_gain_glory(float(house["glory"]["per_banner_pickup"]))
			_log("%s zvedl prapor" % u.name, true)
		return

	var has_anchor := false
	var anchor := Vector2.ZERO
	var leash := INF
	var engage := INF
	if u.posture == "drzet":
		has_anchor = true
		var firm := _no_retreat(u)
		if firm and u.pos.distance_to(u.home) < 0.4:
			# "Stát pevně": kam ho boj posune, tam stojí. Nikdy se nevrací.
			u.home = u.pos
		anchor = u.home
		leash = 0.0 if firm else 1.5
		engage = u.reach if u.ranged else u.reach + 3.0
	elif u.posture == "chranit":
		has_anchor = true
		var c := aura_center()
		if c != null and c.id != u.id:
			anchor = c.pos
		elif banner_down:
			anchor = banner_pos
		else:
			anchor = u.home
		leash = 2.5
		engage = 4.5

	var cand: Array[Unit] = []
	for f in foes:
		if not has_anchor:
			cand.append(f)
		elif u.ranged and f.pos.distance_to(u.pos) <= u.reach:
			cand.append(f)
		elif not u.ranged and f.pos.distance_to(anchor) <= engage:
			cand.append(f)
	var tg := _nearest(cand, u.pos)

	if has_oath(u.id) and tg != null and u.pos.distance_to(tg.pos) <= u.reach + 0.3:
		_gain_glory(float(house["glory"]["oath_per_second"]) * dt)

	if tg != null:
		if u.pos.distance_to(tg.pos) <= u.reach + tg.radius * 0.5:
			u.moving = false
			_attack(u, tg)
			return
		if has_anchor and not u.ranged:
			var dv := tg.pos - anchor
			var d := maxf(dv.length(), 0.0001)
			var m := minf(d, leash)
			_walk(u, anchor + dv / d * m, dt, 0.1)
			return
		if not has_anchor:
			_walk(u, tg.pos, dt, u.reach * 0.8)
			return

	if has_anchor:
		var near := 1.6 if u.posture == "chranit" else 0.25
		if u.pos.distance_to(anchor) > near:
			_walk(u, anchor, dt, 1.5 if u.posture == "chranit" else 0.2)
		else:
			u.moving = false
	else:
		u.moving = false


func _foe_think(u: Unit, dt: float) -> void:
	var ks := living(SIDE_KNIGHT)
	if ks.is_empty():
		u.moving = false
		return
	var tg := _nearest(ks, u.pos)
	var d := u.pos.distance_to(tg.pos)
	if u.ranged:
		# střelci střílí z dostřelu, ale postupují na 60 % dostřelu, aby nevznikl pat
		if d <= u.reach:
			_attack(u, tg)
		if d > u.reach * 0.6:
			_walk(u, tg.pos, dt, u.reach * 0.6)
		else:
			u.moving = false
		if d <= u.reach:
			_face_to(u, tg)
		return
	if d <= u.reach + tg.radius * 0.5:
		u.moving = false
		_attack(u, tg)
	else:
		_walk(u, tg.pos, dt, u.reach * 0.8)


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


func step(dt: float) -> void:
	if over != "":
		return
	t += dt
	for k: String in fx.keys():
		fx[k] = maxf(0.0, float(fx[k]) - dt)

	if banner_down and picker_id == "":
		var protectors: Array[Unit] = []
		var near: Array[Unit] = []
		for k in living(SIDE_KNIGHT):
			if k.posture == "chranit":
				protectors.append(k)
			if k.pos.distance_to(banner_pos) < 3.0 and not _no_retreat(k):
				near.append(k)
		var p := _nearest(protectors if not protectors.is_empty() else near, banner_pos)
		if p != null:
			picker_id = p.id
			_log("%s běží pro prapor" % p.name, false)
	if picker_id != "" and not by_id(picker_id).alive():
		picker_id = ""

	for u in units:
		if not u.alive():
			continue
		u.t -= dt
		u.atk = maxf(0.0, u.atk - dt)
		u.hit = maxf(0.0, u.hit - dt)
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
			_hurt(by_id(p.from_id), tg, p.dmg)
			p.done = true
		else:
			p.pos += dv / d * st
	var still: Array[Projectile] = []
	for p in projectiles:
		if not p.done:
			still.append(p)
	projectiles = still

	if living(SIDE_FOE).is_empty():
		over = "win"
		events.append({"type": "end"})
	elif living(SIDE_KNIGHT).is_empty():
		over = "lose"
		events.append({"type": "end"})
