extends Node
## Headless-проверка деформации, кистей и порогов квестов.
## Запуск:
##   godot --headless --path . res://tests/smoke_test.tscn

func _ready() -> void:
	QuestManager.reset_progress()

	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Node = scene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var mesh: DeformMesh = main.get_node("Target")
	print("--- vertex count: ", mesh.mesh.surface_get_array_len(0))
	print("pristine: ", mesh.is_pristine())
	var s0 := mesh.get_zone_stats(Vector3(0, 1, 0), 0.45)
	print("start: ", s0)

	var top := Vector3(0, 1, 0)

	# ------------------------------------------------------------ Основы
	main.set("_orbit_pixels", 200.0)
	main.set("_zoom_steps", 3)
	main.set("_strokes", 1)
	main.set("_used_brushes", {"draw": true})
	print("basics orbit check: ", main.call("_check_quest", QuestManager.QUESTS[0]))
	print("basics zoom check: ", main.call("_check_quest", QuestManager.QUESTS[1]))
	print("basics stroke check: ", main.call("_check_quest", QuestManager.QUESTS[2]))

	# ------------------------------------------------------------ Draw
	var q_draw: Dictionary = QuestManager.QUESTS[3]
	BrushManager.set_brush("draw")
	BrushManager.set_radius(20.0)
	BrushManager.set_strength(0.7)
	var draw_bad: Dictionary = main.call("_check_quest", q_draw)
	print("draw before tuning: ", draw_bad)

	BrushManager.set_radius(30.0)
	BrushManager.set_strength(0.5)
	BrushManager.set_direction("normal")
	for i in 20:
		mesh.apply_brush(top, 0.3, 0.5, "draw", "normal")
	main.set("_used_brushes", {"draw": true})
	var s_draw := mesh.get_zone_stats(top, 0.45)
	print("after draw (20): ", s_draw)
	print("draw check: ", main.call("_check_quest", q_draw))

	# ------------------------------------------------------------ Smooth
	var baseline := float(s_draw.spread)
	for i in 20:
		mesh.apply_brush(top, 0.3, 0.5, "smooth", "normal")
		if i % 4 == 0:
			var st := mesh.get_zone_stats(top, 0.45)
			print("  smooth ", i, ": spread=", st.spread, " avg=", st.avg_signed)
	BrushManager.set_brush("smooth")
	main.set("_spread_baseline", maxf(baseline, float(main.get("_spread_baseline"))))
	main.set("_used_brushes", {"draw": true, "smooth": true})
	var q_smooth: Dictionary = QuestManager.QUESTS[4]
	print("smooth baseline=", main.get("_spread_baseline"), " final spread=", mesh.get_zone_stats(top, 0.45).spread)
	print("smooth check: ", main.call("_check_quest", q_smooth))

	# ------------------------------------------------------------ Grab
	mesh.reset_shape()
	BrushManager.set_brush("grab")
	BrushManager.set_radius(35.0)
	BrushManager.set_strength(0.6)
	for i in 12:
		mesh.apply_brush(top, 0.35, 0.6, "grab", "normal", Vector3(0.2, 0, 0), top)
	main.set("_used_brushes", {"grab": true})
	print("after grab: ", mesh.get_zone_stats(top, 0.45))
	print("grab check: ", main.call("_check_quest", QuestManager.QUESTS[5]))

	# ------------------------------------------------------------ Clay Strips
	mesh.reset_shape()
	BrushManager.set_brush("clay_strips")
	BrushManager.set_radius(30.0)
	BrushManager.set_strength(0.5)
	for i in 20:
		mesh.apply_brush(top, 0.3, 0.5, "clay_strips", "normal", Vector3.ZERO, top)
	main.set("_used_brushes", {"clay_strips": true})
	print("after clay: ", mesh.get_zone_stats(top, 0.45))
	print("clay check: ", main.call("_check_quest", QuestManager.QUESTS[6]))

	# ------------------------------------------------------------ Crease
	mesh.reset_shape()
	BrushManager.set_brush("crease")
	BrushManager.set_radius(15.0)
	BrushManager.set_strength(0.6)
	for i in 15:
		mesh.apply_brush(top, 0.15, 0.6, "crease", "normal", Vector3.ZERO, top)
	main.set("_used_brushes", {"crease": true})
	print("after crease: ", mesh.get_zone_stats(top, 0.35))
	print("crease check: ", main.call("_check_quest", QuestManager.QUESTS[7]))

	# ------------------------------------------------------------ Inflate
	mesh.reset_shape()
	BrushManager.set_brush("inflate")
	BrushManager.set_radius(30.0)
	BrushManager.set_strength(0.5)
	for i in 20:
		mesh.apply_brush(top, 0.3, 0.5, "inflate", "normal")
	main.set("_used_brushes", {"inflate": true})
	print("after inflate: ", mesh.get_zone_stats(top, 0.45))
	print("inflate check: ", main.call("_check_quest", QuestManager.QUESTS[8]))

	# ------------------------------------------------------------ Контрольная Draw + Smooth
	mesh.reset_shape()
	main.set("_spread_baseline", 0.0)
	for i in 20:
		mesh.apply_brush(top, 0.3, 0.5, "draw", "normal")
	var control_draw := mesh.get_zone_stats(top, 0.45)
	main.set("_spread_baseline", float(control_draw.spread))
	for i in 20:
		mesh.apply_brush(top, 0.3, 0.5, "smooth", "normal")
	main.set("_used_brushes", {"draw": true, "smooth": true})
	print("control draw+smooth: ", mesh.get_zone_stats(top, 0.45))
	print("control draw+smooth check: ", main.call("_check_quest", QuestManager.QUESTS[9]))

	# ------------------------------------------------------------ Финальная модель
	mesh.reset_shape()
	for i in 8:
		mesh.apply_brush(top, 0.3, 0.5, "draw", "normal")
	for i in 8:
		mesh.apply_brush(top, 0.3, 0.5, "clay_strips", "normal", Vector3.ZERO, top)
	for i in 4:
		mesh.apply_brush(top, 0.3, 0.5, "inflate", "normal")
	for i in 8:
		mesh.apply_brush(top, 0.35, 0.6, "grab", "normal", Vector3(0.1, 0, 0), top)
	for i in 6:
		mesh.apply_brush(top, 0.15, 0.6, "crease", "normal", Vector3.ZERO, top)
	for i in 8:
		mesh.apply_brush(top, 0.3, 0.5, "smooth", "normal")
	main.set("_used_brushes", {
		"draw": true,
		"smooth": true,
		"grab": true,
		"clay_strips": true,
		"crease": true,
		"inflate": true,
	})
	print("final model: ", mesh.get_zone_stats(Vector3.ZERO, 1.1))
	print("final check: ", main.call("_check_quest", QuestManager.QUESTS[10]))

	# ------------------------------------------------------------ Прогресс
	QuestManager.reset_progress()
	print("quest 2 unlocked before: ", QuestManager.is_unlocked(1))
	QuestManager.mark_current_completed()
	print(
		"quest 2 unlocked after: ",
		QuestManager.is_unlocked(1),
		" quest 3 locked: ",
		not QuestManager.is_unlocked(2),
		" current=",
		QuestManager.current_index
	)
	var cfg := ConfigFile.new()
	var err := cfg.load(QuestManager.PROGRESS_PATH)
	print("progress save: err=", err, " index=", cfg.get_value("progress", "current_quest", -1), " completed=", cfg.get_value("progress", "completed", []))
	QuestManager.reset_progress()
	get_tree().quit()
