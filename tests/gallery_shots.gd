extends SceneTree
## Character gallery snapshots (style pilot 2.0s): the row, the tank and the cavalier up close from several sides,
## in idle, attack and walk, and the battle camera view. For comparing looks, checks only that the gallery loads.
## Run (with a window): godot --path . --script res://tests/gallery_shots.gd -- <folder>

const Gallery := preload("res://scripts/sandbox/gallery.gd")

var out_dir := ""
var g: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
		DirAccess.make_dir_recursive_absolute(out_dir)
	g = Gallery.new()
	root.add_child(g)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	if out_dir != "" and DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png(out_dir.path_join("gal_%s.png" % name))
		print("Snímek: gal_%s.png" % name)


func _close(who: String, yaw_deg: float, dist: float = 4.5, pitch_deg: float = 12.0) -> void:
	g.set("who", who)
	g.call("view_close")
	g.set("_yaw", deg_to_rad(yaw_deg))
	g.set("_pitch", deg_to_rad(pitch_deg))
	g.set("_dist", dist)
	g.call("_apply_cam")


func _run() -> void:
	await _frames(10)
	await _shot("01_rada")
	g.call("view_game")
	await _shot("02_bitevni")
	for side: Array in [["predek", 0.0], ["bok", 70.0], ["zada", 180.0]]:
		_close("tank", side[1])
		g.call("_play", "idle")
		await _frames(8)
		await _shot("tank_%s" % side[0])
	_close("tank", 35.0)
	g.set("speed", 0.25)
	g.call("_play", "attack")
	await _frames(14)
	await _shot("tank_utok")
	g.set("speed", 1.0)
	# library vs own animations of the tank: the same moments side by side
	for mode: Array in [["lib", true], ["own", false]]:
		g.set("library_anims", mode[1])
		g.call("_reset")
		await _frames(6)
		_close("tank", 50.0, 5.0, 10.0)
		g.call("_play", "idle")
		await _frames(20)
		await _shot("tank_%s_klid" % mode[0])
		g.call("_play", "walk")
		await _frames(10)
		await _shot("tank_%s_chuze" % mode[0])
		g.set("speed", 0.5)
		g.set("loop", false)
		for t: Array in [["utok1", 4], ["utok2", 8], ["utok3", 12]]:
			g.call("_play", "attack")
			await _frames(int(t[1]))
			await _shot("tank_%s_%s" % [mode[0], t[0]])
			await _frames(30)
		g.call("_play", "ability")
		await _frames(14)
		await _shot("tank_%s_schopnost" % mode[0])
		await _frames(30)
		g.call("_play", "hit")
		await _frames(5)
		await _shot("tank_%s_zasah" % mode[0])
		g.set("speed", 1.0)
		g.set("loop", true)
	g.set("library_anims", true)
	g.call("_reset")
	await _frames(4)
	for side: Array in [["predek", 20.0, 6.5], ["bok", 90.0, 6.5]]:
		_close("jezdec", side[1], side[2], 15.0)
		g.call("_play", "idle")
		await _frames(8)
		await _shot("jezdec_%s" % side[0])
	_close("jezdec", 90.0, 6.5, 15.0)
	g.call("_play", "walk")
	await _frames(16)
	await _shot("jezdec_chuze")
	print("VÝSLEDEK: OK")
	quit(0)
