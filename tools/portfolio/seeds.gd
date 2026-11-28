extends SceneTree
## Headless: finds run seeds with a rich story (won, fallen heroes with successors, bonds, relics).
const Lib := preload("res://tools/portfolio/lib.gd")
const Run := preload("res://scripts/run/run_state.gd")
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var from := int(a[0]) if a.size() > 0 else 1
	var to := int(a[1]) if a.size() > 1 else 30
	for sd in range(from, to):
		var r := Run.new(sd)
		Lib.auto_run(r, sd)
		var bonds := 0
		for h: Dictionary in r.heroes.values():
			if not (h.get("bond", {}) as Dictionary).is_empty():
				bonds += 1
		print("SEED %d over=%s fallen=%d bonds=%d relics=%d chron=%d path=%d" % [sd, r.over, r.fallen.size(), bonds / 2, r.relics.size(), r.chronicle.size(), r.path.size()])
	quit()
