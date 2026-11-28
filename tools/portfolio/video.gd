extends SceneTree
## Portfolio videos (chapter "Mám hru"): renders PNG frames at a fixed 30 fps (run with --fixed-fps 30), ffmpeg
## (tools/portfolio/video.sh) joins the segments. The OS cursor is not in the picture, so a drawn cursor layer shows
## where the player points and clicks.
## Run: godot --path . --fixed-fps 30 --script res://tools/portfolio/video.gd -- <out dir> <segment>
## Segments: v1_reward, v1_battle, v1_win, v1_after, v2_ability, v3_order

const Lib := preload("res://tools/portfolio/lib.gd")
const Run := preload("res://scripts/run/run_state.gd")
const FPS := 30

var L: Lib
var out := ""
var seg := ""
var n := 0
var cursor: Control
var _cur_pos := Vector2(-100, -100)
var _cur_down := 0.0


class Cursor extends Control:
	var pos := Vector2(-100, -100)
	var press := 0.0   # 0..1, a short ring when clicking

	func _draw() -> void:
		var k := 1.0   # drawn in UI units (the window is stretched from 1600x900)
		var pts := PackedVector2Array()
		for p: Vector2 in [Vector2(0, 0), Vector2(0, 21), Vector2(5.5, 16), Vector2(9.5, 24.5), Vector2(13, 22.7), Vector2(9.2, 14.6), Vector2(16.5, 14.6)]:
			pts.append(pos + p * k)
		if press > 0.0:
			draw_arc(pos, (10.0 + 14.0 * (1.0 - press)) * k, 0, TAU, 32, Color(1, 0.86, 0.4, press), 2.5 * k)
		draw_colored_polygon(pts, Color.WHITE)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color(0.08, 0.09, 0.1), 1.6 * k, true)


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	seg = a[1]
	L = Lib.new(self, out)
	DirAccess.make_dir_recursive_absolute(out.path_join(seg))
	var layer := CanvasLayer.new()
	layer.layer = 128
	root.add_child.call_deferred(layer)
	cursor = Cursor.new()
	cursor.set_anchors_preset(Control.PRESET_FULL_RECT)
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child.call_deferred(cursor)
	await L.frames(2)
	await call(seg)
	print("FRAMES %s %d" % [seg, n])
	quit(0)


## Renders and saves `count` frames; `each` (optional) is called before every frame with the frame index.
func rec(count: int, each: Callable = Callable()) -> void:
	RenderingServer.render_loop_enabled = true
	for i in count:
		if each.is_valid():
			each.call(i)
		cursor.pos = _cur_pos
		cursor.press = _cur_down
		_cur_down = maxf(0.0, _cur_down - 1.0 / 8.0)
		cursor.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join(seg).path_join("%05d.png" % n))
		n += 1


## Moves the cursor from where it is to `to` (pixels) over `secs`, recording; ease in-out.
func move(to: Vector2, secs: float, each: Callable = Callable()) -> void:
	var from := _cur_pos
	var count := int(secs * FPS)
	await rec(count, func(i: int) -> void:
		var x := float(i + 1) / count
		x = x * x * (3.0 - 2.0 * x)
		_cur_pos = from.lerp(to, x)
		if each.is_valid():
			each.call(i))


func click() -> void:
	_cur_down = 1.0


## Positions are in UI units (1600x900, canvas_items stretch), the same space as input events and unproject_position.
func _px(base: Vector2) -> Vector2:
	return base


func _center_of(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


# ================================================================ helpers shared with shots.gd

func _place(sim: Object, id: String, p: Vector2) -> void:
	var u: Object = sim.call("by_id", id)
	u.set("pos", p)
	u.set("home", p)
	u.set("face", Vector2(0, 1))


func _staged_bridge(t: float) -> Node:
	var b: Node = await L.battle("most_pres_reku")
	L.run_battle(b)
	var sim: Object = b.get("sim")
	_place(sim, "tank", Vector2(0.0, 3.0))
	_place(sim, "knez", Vector2(-1.8, -0.5))
	_place(sim, "lucistnik", Vector2(-4.2, 1.6))
	_place(sim, "asasin", Vector2(2.6, 2.4))
	_place(sim, "jezdec", Vector2(4.0, -0.2))
	sim.call("set_order", "tank", "point", Vector2(0.0, 3.2))
	if t > 0.0:
		await L.ff(b, t, Callable(), 10)
	return b


func _cam(b: Node) -> void:
	L.cam(b, 0.5, 5.0, 25, 50, 22)


func _screen_of(b: Node, id: String) -> Vector2:
	var v: Node3D = (b.get("views") as Dictionary)[id]
	return (b.get("cam") as Camera3D).unproject_position(v.global_position + Vector3(0, 0.9, 0))


func _run_after_battle() -> Node:
	# the same run state as K2-08 (elite reward with fits / clashes on the cards)
	var r := Run.new(5)
	Lib.auto_run(r, 5, 5, true)
	load("res://scripts/battle/battle.gd").set("tutorial_mode", -1)
	var s: Node = load("res://scenes/run/run.tscn").instantiate()
	root.add_child(s)
	await L.frames(3)
	s.set("run", r)
	s.call("show_after_battle")
	await L.frames(3)
	return s


func _buttons(s: Node, text: String) -> Array:
	var outb: Array = []
	for c: Node in (s.get("screen") as Node).find_children("*", "Button", true, false):
		if (c as Button).text == text:
			outb.append(c)
	return outb


# ================================================================ V2-01 segments

## After the battle: the reward cards; the cursor goes to a card and chooses it.
func v1_reward() -> void:
	var s := await _run_after_battle()
	var picks := _buttons(s, "Choose")
	_cur_pos = _px(Vector2(1180, 700))
	await rec(int(0.8 * FPS))
	var target: Control = picks[0] if not picks.is_empty() else null
	if target != null:
		await move(_center_of(target), 1.4)
		click()
		await rec(int(0.25 * FPS))
		(target as Button).emit_signal("pressed")
	await rec(int(0.9 * FPS))


## The battle on the bridge: running, Space (pause), cursor selects the cavalier and right-clicks the bowmen,
## Space again, the cavalier rides out.
func v1_battle() -> void:
	var b := await _staged_bridge(1.0)
	_cam(b)
	var sim: Object = b.get("sim")
	_cur_pos = _px(Vector2(1000, 640))
	await rec(int(1.6 * FPS))
	L.pause_battle(b)
	await rec(int(0.6 * FPS))
	await move(_screen_of(b, "jezdec"), 0.9)
	click()
	b.call("_select", "jezdec")
	await rec(int(0.4 * FPS))
	var foe := ""
	for u: Variant in sim.call("living", "e"):
		if String(u.get("key")) == "strelec":
			foe = u.get("id")
			break
	await move(_screen_of(b, foe), 1.0, func(_i: int) -> void: b.call("_pointer_move", _cur_pos))
	await rec(int(0.5 * FPS))
	click()
	b.call("_command_click", _cur_pos)
	await rec(int(0.8 * FPS))
	b.call("_toggle_pause")
	await move(_px(Vector2(1180, 760)), 2.6)


## The end of the battle: the enemy breaks, the cursor gives All In!, the heroes finish it, the victory box.
func v1_win() -> void:
	# an ordinary battle with the automatic commander; a try where the enemy breaks with no hero lost
	# (the battle is random, nothing in the rules changes, the try is only repeated)
	var each := func(s: Object) -> void:
		s.call("auto_command")
		Lib.auto_abilities(s)
	var b: Node = null
	var sim: Object = null
	for attempt in 12:
		b = await L.battle("most_pres_reku")
		L.run_battle(b)
		sim = b.get("sim")
		for k in 120:
			await L.ff(b, 1.0, each, 0)
			if bool(sim.get("foes_broken")) or String(sim.get("over")) != "":
				break
		var alive: int = (sim.call("living", "k") as Array).size()
		print("try ", attempt, " broken ", sim.get("foes_broken"), " alive ", alive)
		if bool(sim.get("foes_broken")) and String(sim.get("over")) == "" and alive == 5:
			break
		b.queue_free()
		await L.frames(2)
	# frame the heroes that are left
	var c := Vector2.ZERO
	var alive: Array = sim.call("living", "k")
	for u: Variant in alive:
		c += u.get("pos") as Vector2
	c /= maxf(1.0, float(alive.size()))
	L.cam(b, c.x, c.y + 2.0, 25, 50, 22)
	b.set("speed", 1.0)
	var ui: Object = b.get("ui")
	_cur_pos = _px(Vector2(1000, 600))
	await rec(int(0.6 * FPS))
	var btn: Variant = ui.get("_charge_button")
	if btn != null and (btn as Control).is_visible_in_tree():
		await move(_center_of(btn), 1.0)
		click()
		b.call("_charge")
		await rec(int(0.3 * FPS))
		await move(_px(Vector2(1180, 640)), 0.8)
	var box: Control = ui.get("result_box")
	var shown := -1
	for i in int(12.0 * FPS):
		await rec(1)
		if shown < 0 and box.visible:
			shown = i
		if shown >= 0 and i - shown > int(1.8 * FPS):
			break
	print("win segment over=", sim.get("over"), " box shown at ", shown)


## After the battle again: "What happened · Victory" (the chronicle entry), as the loop's way back to the start.
func v1_after() -> void:
	var s := await _run_after_battle()
	_cur_pos = _px(Vector2(1300, 820))
	await move(_px(Vector2(1180, 700)), 2.2)


# ================================================================ V2-02, V2-03

## The tank's Challenge and the priest's Blessing firing (loop 5 s).
func v2_ability() -> void:
	var b: Node = await L.battle("most_pres_reku")
	L.ui(b, false)
	L.run_battle(b)
	var sim: Object = b.get("sim")
	_place(sim, "tank", Vector2(0.0, 0.8))
	_place(sim, "knez", Vector2(-2.2, -2.6))
	_place(sim, "lucistnik", Vector2(-4.6, -1.0))
	_place(sim, "asasin", Vector2(2.4, -0.2))
	_place(sim, "jezdec", Vector2(4.4, -2.2))
	sim.call("set_order", "tank", "point", Vector2(0.0, 0.8))
	await L.ff(b, 5.0, Callable(), 10)
	L.cam(b, 0.0, 3.2, 25, 50, 15)
	_cur_pos = Vector2(-100, -100)
	await rec(int(1.0 * FPS))
	for id: String in ["tank", "knez"]:
		var h: Array = sim.call("ability_hint", id)
		var tgt: Variant = h[1] if h.size() > 1 and h[1] != null else sim.call("by_id", "tank").get("pos")
		sim.call("use_ability", id, tgt)
	b.call("_flush_events")
	await rec(int(4.0 * FPS))


## Pause and an order: the cursor selects the cavalier and sends him at the bowmen (loop 5 s).
func v3_order() -> void:
	var b := await _staged_bridge(2.0)
	L.ui(b, true)
	_cam(b)
	var sim: Object = b.get("sim")
	L.pause_battle(b)
	(b.get("ui") as Object).set("_hint_t", 0.01)
	_cur_pos = _px(Vector2(1050, 640))
	await rec(int(0.5 * FPS))
	await move(_screen_of(b, "jezdec"), 0.9)
	click()
	b.call("_select", "jezdec")
	await rec(int(0.4 * FPS))
	var foe := ""
	for u: Variant in sim.call("living", "e"):
		if String(u.get("key")) == "strelec":
			foe = u.get("id")
			break
	await move(_screen_of(b, foe), 1.1, func(_i: int) -> void: b.call("_pointer_move", _cur_pos))
	await rec(int(0.5 * FPS))
	click()
	b.call("_command_click", _cur_pos)
	await rec(int(1.0 * FPS))
	await move(_px(Vector2(1050, 640)), 0.6)
