extends Control
## Drawing the act map: nodes as buttons, paths as lines. Only draws and reports clicks (node_pressed).
## Look: Royal Court Enamel (medallions with Oathline icons, scripts/ui/ui_theme.gd).

signal node_pressed(id: String)
signal node_hovered(id: String)

const UI := preload("res://scripts/ui/ui_theme.gd")
const Icon := preload("res://scripts/battle/ui_icon.gd")
const TYPE_COLORS := {
	"bitva": UI.HOUSE,
	"elita": UI.OATH,
	"udalost": UI.GLORY,
	"tabor": UI.GOOD,
	"boss": Color("#704D83"),
}
const TYPE_ICONS := {"bitva": "map_battle", "elita": "map_elite", "udalost": "map_event", "tabor": "map_camp", "boss": "map_boss"}

var run: RefCounted
var _pos := {}       # id -> medallion centre (in control coordinates)
const R := 27.0      # medallion radius
const BOSS_R := 36.0


func setup(r: RefCounted) -> void:
	run = r
	for c in get_children():
		c.queue_free()
	_pos.clear()
	var floors: Array = run.map["floors"]
	var n_rows := floors.size() + 1
	var h := size.y if size.y > 0 else custom_minimum_size.y
	var w := size.x if size.x > 0 else custom_minimum_size.x
	var all: Array = []
	for row: Array in floors:
		all.append_array(row)
	all.append(run.map["boss"])
	var avail: Array = run.available()
	for n: Dictionary in all:
		var f: int = n["floor"]
		var y := h - (float(f) - 0.5) * (h / n_rows) - 8.0
		var x := float(n["x"]) * w
		_pos[n["id"]] = Vector2(x, y)
		var t: String = n["type"]
		var rad := BOSS_R if t == "boss" else R
		var b := Button.new()
		b.custom_minimum_size = Vector2(rad, rad) * 2.0
		b.size = b.custom_minimum_size
		b.position = Vector2(x, y) - Vector2(rad, rad)
		b.focus_mode = Control.FOCUS_NONE
		var col: Color = TYPE_COLORS.get(t, UI.TEXT)
		var here: bool = n["id"] == run.node_id
		var visited: bool = run.path.has(n["id"])
		var can: bool = avail.has(n["id"])
		# medallion: available = white enamel with a gilt ring, here = filled colour, visited = inset, the rest dimmed
		var bg := UI.RAISED if can else (col if here else UI.INSET)
		var ring := UI.GILT if can else (UI.OUTLINE if here or visited else UI.BORDER)
		var st := UI.box(bg, int(rad), 0, ring, 3 if can else 2, 3 if can else 0)
		b.add_theme_stylebox_override("normal", st)
		var sth := UI.box(Color("#FFF6DF"), int(rad), 0, UI.GLORY, 4, 3)
		b.add_theme_stylebox_override("hover", sth)
		b.add_theme_stylebox_override("pressed", sth)
		b.add_theme_stylebox_override("disabled", st)
		b.disabled = not can
		b.tooltip_text = _tooltip(n)
		if not (can or here or visited):
			b.modulate = Color(1, 1, 1, 0.6)
		var id: String = n["id"]
		b.pressed.connect(func() -> void: node_pressed.emit(id))
		b.mouse_entered.connect(func() -> void: node_hovered.emit(id))
		var ipx := rad * 1.05
		var ic := Icon.make(TYPE_ICONS.get(t, "hud_glory"), UI.ON_DARK if here else (col if (can or visited) else UI.TEXT_MUTED), ipx)
		ic.position = Vector2(rad, rad) - Vector2(ipx, ipx) / 2.0
		b.add_child(ic)
		add_child(b)
		var lab := UI.eyebrow(String(run.NODE_NAMES.get(t, t)), UI.TEXT if (can or here) else UI.TEXT_MUTED, 10)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.custom_minimum_size = Vector2(110, 0)
		lab.position = Vector2(x - 55.0, y + rad + 3.0)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lab)
	queue_redraw()


func _tooltip(n: Dictionary) -> String:
	var t: String = n["type"]
	match t:
		"bitva", "elita", "boss":
			var sc: Dictionary = run.scenario_info(String(n["scenario"]))
			var md: Dictionary = run.units_data.get("battle_modes", {}).get(String(sc.get("mode", "stret")), {})
			return "%s (%s)\n%s\nTask: %s" % [sc.get("name", ""), md.get("name", ""), sc.get("subtitle", ""), sc.get("optional_task", {}).get("text", "")]
		"udalost":
			return "Event: %s" % run.events_data[n["event"]]["name"]
		"tabor":
			return "Camp: one choice of rest, training, rite or feast."
	return ""


func _draw() -> void:
	if run == null:
		return
	for id: String in _pos:
		var n: Dictionary = run.node(id)
		for nx: String in n["next"]:
			var walked: bool = run.path.has(id) and run.path.has(nx) and run.path.find(nx) == run.path.find(id) + 1
			var from_here: bool = id == run.node_id and run.available().has(nx)
			var a: Vector2 = _pos[id]
			var b: Vector2 = _pos[nx]
			var dir := (b - a).normalized()
			a += dir * (R + 4.0)
			b -= dir * ((BOSS_R if run.node(nx)["type"] == "boss" else R) + 18.0)   # stop under the label
			if walked:
				draw_line(a, b, UI.GLORY, 4.0, true)
			elif from_here:
				draw_line(a, b, UI.OUTLINE, 3.0, true)
			else:
				draw_dashed_line(a, b, Color(UI.BORDER_STRONG, 0.55), 2.0, 7.0, true, true)
	# from the spot before the first floor
	if run.node_id == "":
		for id: String in run.available():
			var tgt: Vector2 = _pos[id]
			var from := Vector2(size.x / 2.0, size.y)
			draw_line(from, tgt + (from - tgt).normalized() * (R + 4.0), UI.OUTLINE, 3.0, true)
