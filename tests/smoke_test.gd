extends Node
## Headless-проверка деформации и порогов квестов.
## Запуск:
##   godot --headless --path . res://tests/smoke_test.tscn

func _ready() -> void:
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

	# Квест 1: стартовые значения не должны проходить проверку.
	var q1: Dictionary = QuestManager.QUESTS[0]
	var r1_bad: Dictionary = main.call("_check_quest", q1)
	print("q1 before tuning: ", r1_bad)

	# Квест 1: параметры.
	BrushManager.set_brush("draw")
	BrushManager.set_radius(30.0)
	BrushManager.set_strength(0.5)
	BrushManager.set_direction("normal")
	var r1: Dictionary = main.call("_check_quest", q1)
	print("q1 check: ", r1)

	# Квест 2: 20 шагов Draw по макушке.
	for i in 20:
		mesh.apply_brush(Vector3(0, 1, 0), 0.3, 0.5, "draw", "normal")
	var s2 := mesh.get_zone_stats(Vector3(0, 1, 0), 0.45)
	print("after draw (20): ", s2)
	var q2: Dictionary = QuestManager.QUESTS[1]
	var r2: Dictionary = main.call("_check_quest", q2)
	print("q2 check: ", r2)

	# Квест 3: сглаживание и относительное уменьшение разброса.
	var baseline := float(s2.spread)
	var s3 := s2
	for i in 20:
		mesh.apply_brush(Vector3(0, 1, 0), 0.3, 0.5, "smooth", "normal")
		if i % 4 == 0:
			s3 = mesh.get_zone_stats(Vector3(0, 1, 0), 0.45)
			print("  smooth ", i, ": spread=", s3.spread, " avg=", s3.avg_signed)
	main.set("_smooth_baseline", maxf(baseline, float(main.get("_smooth_baseline"))))
	main.set("_smooth_baseline", maxf(float(main.get("_smooth_baseline")), float(s2.spread)))
	var q3: Dictionary = QuestManager.QUESTS[2]
	var r3: Dictionary = main.call("_check_quest", q3)
	print("smooth baseline=", main.get("_smooth_baseline"), " final spread=", mesh.get_zone_stats(Vector3(0, 1, 0), 0.45).spread)
	print("q3 check: ", r3)

	# Квест 4: сброс и вдавливание -Z.
	mesh.reset_shape()
	BrushManager.set_direction("minus_z")
	for i in 20:
		mesh.apply_brush(Vector3(0, 1, 0), 0.3, 0.5, "draw", "minus_z")
	var s4 := mesh.get_zone_stats(Vector3(0, 1, 0), 0.45)
	print("after dent (20): ", s4)
	var q4: Dictionary = QuestManager.QUESTS[3]
	var r4: Dictionary = main.call("_check_quest", q4)
	print("q4 check: ", r4)

	QuestManager.reset_progress()
	QuestManager.mark_current_completed()
	var cfg := ConfigFile.new()
	var err := cfg.load(QuestManager.PROGRESS_PATH)
	print("progress save: err=", err, " index=", cfg.get_value("progress", "current_quest", -1), " completed=", cfg.get_value("progress", "completed", []))
	QuestManager.reset_progress()
	get_tree().quit()
