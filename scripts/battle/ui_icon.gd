extends Control
## A UI icon. Oathline icons (scripts/ui/icon_svg.gd, from Figma) are rasterised from SVG at runtime
## and tinted with `color`; older kinds without an SVG yet are drawn as simple vectors in _draw.
## `plate` draws a light round backplate with the dark outline (icons above units, over the battlefield).

const Svg := preload("res://scripts/ui/icon_svg.gd")

## Old icon kinds → Oathline icon (the code still uses the old names in places).
const ALIAS := {
	"tank": "class_tank", "knez": "class_priest", "lucistnik": "class_archer", "jezdec": "class_cavalier", "asasin": "class_assassin",
	"oath": "status_oath", "hradba": "class_tank", "heal": "ability_blessing", "aura": "ability_blessing", "banner": "status_commander",
	"zarod": "map_battle", "signal": "ability_challenge", "pause": "hud_pause", "play": "hud_play", "charge": "ability_charge",
	"glory": "hud_glory", "flee": "status_fleeing", "desperate": "status_winding_up",
}
const PLATE_BG := Color("#FFFCF4")
const PLATE_LINE := Color("#121418")

static var _tex := {}   # "key:px" -> ImageTexture (white, tinted when drawn)

var kind := ""
var color := Color.WHITE
var crossed := false   # struck through (broken oath, fallen hero)
var plate := false


static func make(icon_kind: String, icon_color: Color = Color.WHITE, px: float = 18.0, tip: String = "", with_plate: bool = false) -> Control:
	var ic: Variant = load("res://scripts/battle/ui_icon.gd").new()
	ic.kind = icon_kind
	ic.color = icon_color
	ic.plate = with_plate
	ic.custom_minimum_size = Vector2(px, px)
	ic.size = Vector2(px, px)
	ic.tooltip_text = tip
	ic.mouse_filter = Control.MOUSE_FILTER_PASS if tip != "" else Control.MOUSE_FILTER_IGNORE
	return ic


## Oathline icon key for a kind ("" when it has no SVG yet).
static func svg_key(icon_kind: String) -> String:
	var k: String = ALIAS.get(icon_kind, icon_kind)
	return k if Svg.PATHS.has(k) else ""


## White texture of an Oathline icon at a pixel size (cached).
static func texture(key: String, px: int) -> Texture2D:
	var ck := "%s:%d" % [key, px]
	if _tex.has(ck):
		return _tex[ck]
	var d: Array = Svg.PATHS[key]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path fill="#ffffff" fill-rule="%s" d="%s"/></svg>' % [d[1], d[0]]
	var img := Image.new()
	var tex: Texture2D = null
	if img.load_svg_from_string(svg, maxf(0.25, px / 24.0)) == OK:
		tex = ImageTexture.create_from_image(img)
	_tex[ck] = tex
	return tex


func set_kind(icon_kind: String, icon_color: Color, is_crossed: bool = false) -> void:
	if kind == icon_kind and color == icon_color and crossed == is_crossed:
		return
	kind = icon_kind
	color = icon_color
	crossed = is_crossed
	queue_redraw()


func _p(x: float, y: float) -> Vector2:
	return Vector2(x, y) * minf(size.x, size.y)


func _poly(pts: Array, c: Color = color) -> void:
	var arr := PackedVector2Array()
	for q: Vector2 in pts:
		arr.append(_p(q.x, q.y))
	draw_colored_polygon(arr, c)


func _line(a: Vector2, b: Vector2, w: float = 0.1, c: Color = color) -> void:
	draw_line(_p(a.x, a.y), _p(b.x, b.y), c, maxf(1.0, w * minf(size.x, size.y)), true)


func _circle(cx: float, cy: float, r: float, c: Color = color) -> void:
	draw_circle(_p(cx, cy), r * minf(size.x, size.y), c, true, -1.0, true)


func _ring(cx: float, cy: float, r: float, w: float = 0.1, c: Color = color) -> void:
	draw_arc(_p(cx, cy), r * minf(size.x, size.y), 0.0, TAU, 32, c, maxf(1.0, w * minf(size.x, size.y)), true)


func _draw() -> void:
	var full := minf(size.x, size.y)
	if plate:
		draw_circle(Vector2(full, full) / 2.0, full / 2.0, PLATE_BG, true, -1.0, true)
		draw_arc(Vector2(full, full) / 2.0, full / 2.0 - 0.75, 0.0, TAU, 24, PLATE_LINE, 1.5, true)
	var k := svg_key(kind)
	if crossed and k == "status_oath":
		k = "status_oath_broken"
	if k != "":
		var inner := full * (0.66 if plate else 1.0)
		var tex := texture(k, ceili(inner * 2.0))   # 2× for crisp scaling
		if tex != null:
			var off := (full - inner) / 2.0
			draw_texture_rect(tex, Rect2(Vector2(off, off), Vector2(inner, inner)), false, color)
			if crossed and k != "status_oath_broken":
				_line(Vector2(0.12, 0.88), Vector2(0.88, 0.12), 0.12, Color("#A72D27"))
			return
	match kind:
		"tank", "oath", "hradba":
			# shield
			_poly([Vector2(0.15, 0.12), Vector2(0.85, 0.12), Vector2(0.85, 0.5), Vector2(0.5, 0.92), Vector2(0.15, 0.5)])
			if kind == "oath":
				_line(Vector2(0.32, 0.48), Vector2(0.46, 0.64), 0.1, Color(0.1, 0.1, 0.12))
				_line(Vector2(0.46, 0.64), Vector2(0.7, 0.32), 0.1, Color(0.1, 0.1, 0.12))
			elif kind == "hradba":
				_line(Vector2(0.5, 0.18), Vector2(0.5, 0.82), 0.08, Color(0.1, 0.1, 0.12))
		"knez", "heal":
			_poly([Vector2(0.4, 0.08), Vector2(0.6, 0.08), Vector2(0.6, 0.38), Vector2(0.9, 0.38), Vector2(0.9, 0.58), Vector2(0.6, 0.58), Vector2(0.6, 0.92), Vector2(0.4, 0.92), Vector2(0.4, 0.58), Vector2(0.1, 0.58), Vector2(0.1, 0.38), Vector2(0.4, 0.38)])
		"lucistnik":
			draw_arc(_p(0.3, 0.5), 0.42 * minf(size.x, size.y), -1.2, 1.2, 16, color, maxf(1.5, 0.1 * size.x), true)
			_line(Vector2(0.45, 0.12), Vector2(0.45, 0.88), 0.05)
			_line(Vector2(0.2, 0.5), Vector2(0.92, 0.5), 0.07)
			_poly([Vector2(0.95, 0.5), Vector2(0.8, 0.4), Vector2(0.8, 0.6)])
		"jezdec":
			# podkova
			draw_arc(_p(0.5, 0.45), 0.32 * minf(size.x, size.y), PI * 0.95, PI * 2.05, 20, color, maxf(2.0, 0.16 * size.x), true)
			_line(Vector2(0.2, 0.47), Vector2(0.22, 0.85), 0.16)
			_line(Vector2(0.8, 0.47), Vector2(0.78, 0.85), 0.16)
		"asasin":
			# dagger
			_poly([Vector2(0.5, 0.05), Vector2(0.62, 0.55), Vector2(0.38, 0.55)])
			_line(Vector2(0.25, 0.6), Vector2(0.75, 0.6), 0.1)
			_line(Vector2(0.5, 0.6), Vector2(0.5, 0.92), 0.12)
		"banner":
			_line(Vector2(0.2, 0.06), Vector2(0.2, 0.95), 0.09)
			_poly([Vector2(0.24, 0.1), Vector2(0.88, 0.1), Vector2(0.72, 0.3), Vector2(0.88, 0.5), Vector2(0.24, 0.5)])
		"aura":
			_circle(0.5, 0.5, 0.2)
			for i in 8:
				var a := TAU * i / 8.0
				_line(Vector2(0.5 + cos(a) * 0.3, 0.5 + sin(a) * 0.3), Vector2(0.5 + cos(a) * 0.45, 0.5 + sin(a) * 0.45), 0.08)
		"zarod":
			# crossed swords
			_line(Vector2(0.15, 0.15), Vector2(0.85, 0.85), 0.1)
			_line(Vector2(0.85, 0.15), Vector2(0.15, 0.85), 0.1)
			_line(Vector2(0.62, 0.78), Vector2(0.78, 0.62), 0.1)
			_line(Vector2(0.22, 0.62), Vector2(0.38, 0.78), 0.1)
		"route":
			_line(Vector2(0.12, 0.85), Vector2(0.4, 0.45), 0.09)
			_line(Vector2(0.4, 0.45), Vector2(0.75, 0.3), 0.09)
			_poly([Vector2(0.92, 0.22), Vector2(0.68, 0.18), Vector2(0.76, 0.42)])
		"signal":
			# roh
			_poly([Vector2(0.1, 0.42), Vector2(0.3, 0.42), Vector2(0.85, 0.15), Vector2(0.85, 0.85), Vector2(0.3, 0.58), Vector2(0.1, 0.58)])
		"pause":
			_poly([Vector2(0.22, 0.15), Vector2(0.42, 0.15), Vector2(0.42, 0.85), Vector2(0.22, 0.85)])
			_poly([Vector2(0.58, 0.15), Vector2(0.78, 0.15), Vector2(0.78, 0.85), Vector2(0.58, 0.85)])
		"charge":
			_poly([Vector2(0.1, 0.2), Vector2(0.45, 0.5), Vector2(0.1, 0.8)])
			_poly([Vector2(0.5, 0.2), Vector2(0.85, 0.5), Vector2(0.5, 0.8)])
		"glory":
			var pts: Array = []
			for i in 10:
				var a := -PI / 2.0 + TAU * i / 10.0
				var r := 0.45 if i % 2 == 0 else 0.2
				pts.append(Vector2(0.5 + cos(a) * r, 0.52 + sin(a) * r))
			_poly(pts)
		"desperate":
			_ring(0.5, 0.5, 0.4, 0.1)
			_line(Vector2(0.5, 0.25), Vector2(0.5, 0.58), 0.12)
			_circle(0.5, 0.73, 0.07)
		"flee":
			_line(Vector2(0.5, 0.1), Vector2(0.5, 0.85), 0.1)
			_poly([Vector2(0.5, 0.05), Vector2(0.25, 0.35), Vector2(0.75, 0.35)])
		"fanatik":
			_poly([Vector2(0.5, 0.05), Vector2(0.75, 0.45), Vector2(0.7, 0.8), Vector2(0.5, 0.95), Vector2(0.3, 0.8), Vector2(0.25, 0.45), Vector2(0.4, 0.55)])
		"zbabelec":
			# feather
			_poly([Vector2(0.8, 0.1), Vector2(0.55, 0.55), Vector2(0.3, 0.85), Vector2(0.45, 0.45)])
			_line(Vector2(0.2, 0.92), Vector2(0.45, 0.6), 0.06)
		"hold":
			# kotva
			_ring(0.5, 0.2, 0.1, 0.08)
			_line(Vector2(0.5, 0.3), Vector2(0.5, 0.88), 0.09)
			draw_arc(_p(0.5, 0.6), 0.3 * minf(size.x, size.y), 0.2, PI - 0.2, 16, color, maxf(1.5, 0.09 * size.x), true)
		"wait":
			_ring(0.5, 0.5, 0.4, 0.1)
			_line(Vector2(0.5, 0.5), Vector2(0.5, 0.25), 0.09)
			_line(Vector2(0.5, 0.5), Vector2(0.7, 0.6), 0.09)
		_:
			_circle(0.5, 0.5, 0.3)
	if crossed:
		_line(Vector2(0.1, 0.9), Vector2(0.9, 0.1), 0.14, Color("#A72D27"))
