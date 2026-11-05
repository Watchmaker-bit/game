extends Node
## Список квестов и сохранение прогресса (autoload QuestManager).

const PROGRESS_PATH := "user://progress.cfg"

const QUESTS := [
	{
		"id": "brush_setup",
		"title": "Настрой кисть Draw",
		"description": "Выбери кисть Draw и настрой её как настоящий скульптор: Strength = 0.5, Radius = 30. Направление оставь «По нормали».",
		"hint": "Ползунки Radius и Strength находятся в левой панели. У Draw есть ещё Direction.",
		"check_type": "params",
		"target": {
			"brush": "draw",
			"radius": 30.0,
			"strength": 0.5,
			"direction": "normal",
		},
		"tolerance": {"radius": 1.5, "strength": 0.06},
	},
	{
		"id": "bulge",
		"title": "Выпуклость на макушке",
		"description": "Проведи кистью Draw по верхней части сферы. Добейся заметного бугорка: проверка смотрит среднее смещение вершин в верхней зоне.",
		"hint": "ЛКМ — лепить. Вращай сцену СКМ, масштабируй колесом. Веди штрихи по самой макушке.",
		"check_type": "deform",
		"target": {
			"metric": "avg_signed_min",
			"value": 0.010,
			"zone_center": Vector3(0, 1, 0),
			"zone_radius": 0.45,
		},
		"tolerance": 0.003,
	},
	{
		"id": "smooth_bulge",
		"title": "Сгладь выпуклость",
		"description": "Переключись на Smooth и пройдись по бугру. Разброс смещений в верхней зоне должен уменьшиться примерно на 18% относительно самого неровного состояния.",
		"hint": "Smooth не стирает форму полностью — он выравнивает локальные перепады. Несколько коротких проходов эффективнее одного долгого. Если сфера после перезапуска пустая, сначала сделай бугорок Draw.",
		"check_type": "deform",
		"target": {
			"metric": "spread_reduction",
			"value": 0.18,
			"zone_center": Vector3(0, 1, 0),
			"zone_radius": 0.45,
		},
		"tolerance": 0.03,
	},
	{
		"id": "dent",
		"title": "Вмятина направлением -Z",
		"description": "Сбрось скульптуру кнопкой «Сбросить скульптуру», выбери Draw и Direction = -Z (вниз). Продави макушку так, чтобы вершины ушли внутрь сферы.",
		"hint": "Направление в этом тренажёре: +Z — вверх, -Z — вниз (в Godot вертикаль — это Y). Проверяется среднее смещение вдоль исходных нормалей.",
		"check_type": "deform",
		"target": {
			"metric": "avg_signed_max",
			"value": -0.010,
			"zone_center": Vector3(0, 1, 0),
			"zone_radius": 0.45,
		},
		"tolerance": 0.003,
	},
]

var current_index: int = 0
var completed: Array[String] = []


func _ready() -> void:
	load_progress()


func total() -> int:
	return QUESTS.size()


func is_all_completed() -> bool:
	return current_index >= QUESTS.size()


func get_current_quest() -> Dictionary:
	if is_all_completed():
		return {}
	return QUESTS[current_index]


func get_quest_count() -> int:
	return QUESTS.size()


func mark_current_completed() -> void:
	var quest := get_current_quest()
	if quest.is_empty():
		return
	var id: String = quest.id
	if not completed.has(id):
		completed.append(id)
	current_index = mini(current_index + 1, QUESTS.size())
	save_progress()


func reset_progress() -> void:
	current_index = 0
	completed.clear()
	save_progress()


func load_progress() -> void:
	completed.clear()
	current_index = 0
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK:
		return
	current_index = int(cfg.get_value("progress", "current_quest", 0))
	var saved: Variant = cfg.get_value("progress", "completed", PackedStringArray())
	if saved is Array or saved is PackedStringArray:
		for value in saved:
			var text := str(value)
			if not completed.has(text):
				completed.append(text)
	current_index = clampi(current_index, 0, QUESTS.size())


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "current_quest", current_index)
	cfg.set_value("progress", "completed", PackedStringArray(completed))
	var err := cfg.save(PROGRESS_PATH)
	if err != OK:
		push_warning("Не удалось сохранить прогресс: %s" % error_string(err))
