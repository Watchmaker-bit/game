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
	print("start brushes: ", QuestManager.unlocked_brushes())
	print("last quest open: ", QuestManager.is_unlocked(QuestManager.get_quest_count() - 1))

	var top := Vector3(0, 1, 0)

	# ------------------------------------------------------------ Основы
	print("intro check (empty): ", main.call("_check_quest", QuestManager.QUESTS[0]))
	main.set("_orbit_pixels", 200.0)
	main.set("_zoom_steps", 3)
	main.set("_strokes", 1)
	main.set("_radius_changes", 1)
	main.set("_strength_changes", 1)
	main.set("_used_brushes", {"draw": true})
	print("intro check: ", main.call("_check_quest", QuestManager.QUESTS[0]))

	# ------------------------------------------------------------ Draw
	var q_draw: Dictionary = QuestManager.QUESTS[1]
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
	var q_smooth: Dictionary = QuestManager.QUESTS[2]
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
	print("grab check: ", main.call("_check_quest", QuestManager.QUESTS[3]))

	# ------------------------------------------------------------ Clay Strips
	mesh.reset_shape()
	BrushManager.set_brush("clay_strips")
	BrushManager.set_radius(30.0)
	BrushManager.set_strength(0.5)
	for i in 20:
		mesh.apply_brush(top, 0.3, 0.5, "clay_strips", "normal", Vector3.ZERO, top)
	main.set("_used_brushes", {"clay_strips": true})
	print("after clay: ", mesh.get_zone_stats(top, 0.45))
	print("clay check: ", main.call("_check_quest", QuestManager.QUESTS[4]))

	# ------------------------------------------------------------ Crease
	mesh.reset_shape()
	BrushManager.set_brush("crease")
	BrushManager.set_radius(15.0)
	BrushManager.set_strength(0.6)
	for i in 15:
		mesh.apply_brush(top, 0.15, 0.6, "crease", "normal", Vector3.ZERO, top)
	main.set("_used_brushes", {"crease": true})
	print("after crease: ", mesh.get_zone_stats(top, 0.35))
	print("crease check: ", main.call("_check_quest", QuestManager.QUESTS[5]))

	# ------------------------------------------------------------ Inflate
	mesh.reset_shape()
	BrushManager.set_brush("inflate")
	BrushManager.set_radius(30.0)
	BrushManager.set_strength(0.5)
	for i in 20:
		mesh.apply_brush(top, 0.3, 0.5, "inflate", "normal")
	main.set("_used_brushes", {"inflate": true})
	print("after inflate: ", mesh.get_zone_stats(top, 0.45))
	print("inflate check: ", main.call("_check_quest", QuestManager.QUESTS[6]))

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
	print("control draw+smooth check: ", main.call("_check_quest", QuestManager.QUESTS[7]))

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
	print("final check: ", main.call("_check_quest", QuestManager.QUESTS[8]))

	# ------------------------------------------------------------ Сложные формы
	# Рога
	mesh.reset_shape()
	BrushManager.set_brush("draw")
	BrushManager.set_radius(15.0)
	BrushManager.set_strength(0.7)
	main.set("_used_brushes", {"draw": true})
	var horn_a := Vector3(-0.6, 0.8, 0)
	var horn_b := Vector3(0.6, 0.8, 0)
	for i in 40:
		mesh.apply_brush(horn_a, 0.15, 0.7, "draw", "normal")
		mesh.apply_brush(horn_b, 0.15, 0.7, "draw", "normal")
	print("horns left: ", mesh.get_zone_stats(horn_a, 0.3))
	print("horns right: ", mesh.get_zone_stats(horn_b, 0.3))
	print("horns check: ", main.call("_check_quest", QuestManager.QUESTS[9]))

	# Уши
	mesh.reset_shape()
	BrushManager.set_brush("grab")
	BrushManager.set_radius(30.0)
	BrushManager.set_strength(0.6)
	main.set("_used_brushes", {"grab": true})
	var ear_a := Vector3(-1, 0.1, 0)
	var ear_b := Vector3(1, 0.1, 0)
	for i in 15:
		mesh.apply_brush(ear_a, 0.3, 0.6, "grab", "normal", Vector3(-0.15, 0, 0), ear_a)
		mesh.apply_brush(ear_b, 0.3, 0.6, "grab", "normal", Vector3(0.15, 0, 0), ear_b)
	print("ears: ", mesh.get_zone_stats(ear_a, 0.35))
	print("ears check: ", main.call("_check_quest", QuestManager.QUESTS[10]))

	# Лицо
	mesh.reset_shape()
	BrushManager.set_brush("draw")
	BrushManager.set_radius(20.0)
	BrushManager.set_strength(0.7)
	main.set("_used_brushes", {"draw": true, "crease": true})
	var nose := Vector3(0, 0.05, 1)
	for i in 30:
		mesh.apply_brush(nose, 0.2, 0.7, "draw", "normal")
	for eye in [Vector3(-0.34, 0.22, 0.91), Vector3(0.34, 0.22, 0.91)]:
		for i in 20:
			mesh.apply_brush(eye, 0.1, 0.7, "crease", "normal", Vector3.ZERO, eye)
	print("nose: ", mesh.get_zone_stats(nose, 0.28))
	print("eye L: ", mesh.get_zone_stats(Vector3(-0.34, 0.22, 0.91), 0.2))
	print("eye R: ", mesh.get_zone_stats(Vector3(0.34, 0.22, 0.91), 0.2))
	print("face check: ", main.call("_check_quest", QuestManager.QUESTS[11]))

	# Симметричные бугры
	mesh.reset_shape()
	BrushManager.set_brush("draw")
	BrushManager.set_radius(25.0)
	BrushManager.set_strength(0.6)
	main.set("_used_brushes", {"draw": true})
	var bump_a := Vector3(-0.45, 0.55, 0.7)
	var bump_b := Vector3(0.45, 0.55, 0.7)
	for i in 30:
		mesh.apply_brush(bump_a, 0.25, 0.6, "draw", "normal")
		mesh.apply_brush(bump_b, 0.25, 0.6, "draw", "normal")
	print("balance L: ", mesh.get_zone_stats(bump_a, 0.28))
	print("balance R: ", mesh.get_zone_stats(bump_b, 0.28))
	print("balance check: ", main.call("_check_quest", QuestManager.QUESTS[12]))

	# Маска
	mesh.reset_shape()
	main.set("_spread_baseline", 0.0)
	main.set("_used_brushes", {
		"draw": true,
		"smooth": true,
		"grab": true,
		"clay_strips": true,
		"crease": true,
		"inflate": true,
	})
	for i in 20:
		mesh.apply_brush(Vector3(0, 0.1, 1), 0.2, 0.7, "draw", "normal")
	for i in 15:
		mesh.apply_brush(Vector3(0, 0.5, 0.86), 0.1, 0.7, "crease", "normal", Vector3.ZERO, Vector3(0, 0.5, 0.86))
	for i in 15:
		mesh.apply_brush(Vector3(1, 0.1, 0), 0.3, 0.6, "grab", "normal", Vector3(0.15, 0, 0), Vector3(1, 0.1, 0))
	var cheek := Vector3(0.6, 0.2, 0.78).normalized()
	for i in 20:
		mesh.apply_brush(cheek, 0.2, 0.7, "draw", "normal")
	main.set("_spread_baseline", float(mesh.get_zone_stats(cheek, 0.3).spread))
	for i in 20:
		mesh.apply_brush(cheek, 0.2, 0.7, "smooth", "normal")
	print("mask cheek spread: ", mesh.get_zone_stats(cheek, 0.3))
	print("mask check: ", main.call("_check_quest", QuestManager.QUESTS[13]))

	# ------------------------------------------------------------ Открытие кистей
	QuestManager.reset_progress()
	print("brushes after reset: ", QuestManager.unlocked_brushes())
	QuestManager.completed.append("brush_smooth")
	print("brushes after smooth lesson: ", QuestManager.unlocked_brushes())
	QuestManager.reset_progress()

	# ------------------------------------------------------------ Возврат в меню
	main.set("_orbit_pixels", 200.0)
	main.set("_zoom_steps", 3)
	main.set("_strokes", 1)
	main.set("_radius_changes", 1)
	main.set("_strength_changes", 1)
	main.set("_used_brushes", {"draw": true})
	main.call("_on_check_requested")
	await get_tree().create_timer(2.0).timeout
	var hud: CanvasLayer = main.get_node("UI")
	print(
		"after completion: overlay=",
		hud.call("is_quest_list_open"),
		" current=",
		QuestManager.current_index,
		" completed=",
		QuestManager.completed
	)

	# ------------------------------------------------------------ Прогресс
	QuestManager.reset_progress()
	QuestManager.mark_current_completed()
	print(
		"after mark: current=",
		QuestManager.current_index,
		" completed=",
		QuestManager.completed
	)
	var cfg := ConfigFile.new()
	var err := cfg.load(QuestManager.PROGRESS_PATH)
	print("progress save: err=", err, " index=", cfg.get_value("progress", "current_quest", -1), " completed=", cfg.get_value("progress", "completed", []))
	QuestManager.reset_progress()
	get_tree().quit()
