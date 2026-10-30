extends Control
## Jednoduchá vektorová ikonka pro UI (kreslí se v _draw, bez obrázků).
## Zástupná grafika: finální ikony navrhne Tom (fáze 3). Kreslí se do čtverce 0..1 a škáluje na velikost prvku.

var kind := ""
var color := Color.WHITE
var crossed := false   # přeškrtnutá (zlomená přísaha, padlý prapor)


static func make(icon_kind: String, icon_color: Color = Color.WHITE, px: float = 18.0, tip: String = "") -> Control:
	var ic: Variant = load("res://scripts/battle/ui_icon.gd").new()
	ic.kind = icon_kind
	ic.color = icon_color
	ic.custom_minimum_size = Vector2(px, px)
	ic.size = Vector2(px, px)
	ic.tooltip_text = tip
	ic.mouse_filter = Control.MOUSE_FILTER_PASS if tip != "" else Control.MOUSE_FILTER_IGNORE
	return ic


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
	match kind:
		"tank", "oath", "hradba":
			# štít
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
			# dýka
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
			# zkřížené meče
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
			# pírko
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
		_line(Vector2(0.1, 0.9), Vector2(0.9, 0.1), 0.14, Color(0.95, 0.3, 0.25))
