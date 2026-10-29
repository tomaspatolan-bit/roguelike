extends Control
## Kreslení mapy aktu: uzly jako tlačítka, cesty jako čáry. Jen vykresluje a hlásí klik (node_pressed).
## Zástupný vzhled, finální navrhne Tom.

signal node_pressed(id: String)
signal node_hovered(id: String)

const TYPE_COLORS := {
	"bitva": Color("#8aa2e0"),
	"elita": Color("#d0433b"),
	"udalost": Color("#e2b84a"),
	"tabor": Color("#5bb36a"),
	"boss": Color("#b05cd6"),
}
const TYPE_ICONS := {"bitva": "zarod", "elita": "fanatik", "udalost": "signal", "tabor": "heal", "boss": "glory"}
const Icon := preload("res://scripts/battle/ui_icon.gd")

var run: RefCounted
var _pos := {}       # id -> střed tlačítka (v souřadnicích prvku)
const BTN := Vector2(132, 44)


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
		var y := h - (float(f) - 0.5) * (h / n_rows)
		var x := float(n["x"]) * w
		_pos[n["id"]] = Vector2(x, y)
		var b := Button.new()
		var t: String = n["type"]
		b.text = run.NODE_NAMES.get(t, t)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = BTN
		b.size = BTN
		b.position = Vector2(x, y) - BTN / 2.0
		b.focus_mode = Control.FOCUS_NONE
		var col: Color = TYPE_COLORS.get(t, Color.WHITE)
		var here: bool = n["id"] == run.node_id
		var visited: bool = run.path.has(n["id"])
		var can: bool = avail.has(n["id"])
		var bg := Color("#252a31")
		if here:
			bg = col.darkened(0.35)
		elif visited:
			bg = Color("#1f2328")
		var st := StyleBoxFlat.new()
		st.bg_color = bg
		st.set_corner_radius_all(8)
		st.set_content_margin_all(6)
		st.content_margin_left = 30
		st.border_color = col if (can or here) else Color(col, 0.35)
		st.set_border_width_all(3 if can else (2 if here else 1))
		b.add_theme_stylebox_override("normal", st)
		var sth := st.duplicate() as StyleBoxFlat
		sth.bg_color = bg.lightened(0.12)
		b.add_theme_stylebox_override("hover", sth)
		b.add_theme_stylebox_override("pressed", sth)
		b.add_theme_stylebox_override("disabled", st)
		b.add_theme_color_override("font_color", Color.WHITE if (can or here) else Color(1, 1, 1, 0.45))
		b.add_theme_color_override("font_disabled_color", Color.WHITE if here else Color(1, 1, 1, 0.45))
		b.disabled = not can
		b.tooltip_text = _tooltip(n)
		var id: String = n["id"]
		b.pressed.connect(func() -> void: node_pressed.emit(id))
		b.mouse_entered.connect(func() -> void: node_hovered.emit(id))
		var ic := Icon.make(TYPE_ICONS.get(t, "glory"), col if (can or here) else Color(col, 0.45), 18)
		ic.position = Vector2(8, (BTN.y - 18) / 2.0)
		b.add_child(ic)
		add_child(b)
	queue_redraw()


func _tooltip(n: Dictionary) -> String:
	var t: String = n["type"]
	match t:
		"bitva", "elita", "boss":
			var sc: Dictionary = run.scenario_info(String(n["scenario"]))
			var md: Dictionary = run.units_data.get("battle_modes", {}).get(String(sc.get("mode", "stret")), {})
			return "%s (%s)\n%s\nÚkol: %s" % [sc.get("name", ""), md.get("name", ""), sc.get("subtitle", ""), sc.get("optional_task", {}).get("text", "")]
		"udalost":
			return "Událost: %s" % run.events_data[n["event"]]["name"]
		"tabor":
			return "Tábor: odpočinek, zranění se zahojí."
	return ""


func _draw() -> void:
	if run == null:
		return
	for id: String in _pos:
		var n: Dictionary = run.node(id)
		for nx: String in n["next"]:
			var walked: bool = run.path.has(id) and run.path.has(nx) and run.path.find(nx) == run.path.find(id) + 1
			var from_here: bool = id == run.node_id and run.available().has(nx)
			var col := Color(1, 1, 1, 0.12)
			var w := 2.0
			if walked:
				col = Color("#e2b84a")
				w = 4.0
			elif from_here:
				col = Color(1, 1, 1, 0.6)
				w = 3.0
			draw_line(_pos[id] + Vector2(0, -BTN.y / 2.0), _pos[nx] + Vector2(0, BTN.y / 2.0), col, w, true)
	# z místa před prvním patrem
	if run.node_id == "":
		for id: String in run.available():
			draw_line(Vector2(size.x / 2.0, size.y), _pos[id] + Vector2(0, BTN.y / 2.0), Color(1, 1, 1, 0.35), 2.0, true)
