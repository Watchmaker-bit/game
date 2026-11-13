extends Node
## Список квестов и сохранение прогресса (autoload QuestManager).
##
## Курс разбит на разделы:
##   basics  — основы навигации (вращение, масштаб, первый штрих);
##   brushes — по одной кисти на квест;
##   control — контрольные, где можно применять пройденные кисти.
##
## У квеста могут быть сразу несколько условий:
##   actions        — что пользователь сделал мышью;
##   setup_check    — какие настройки кисти должны стоять;
##   require_brushes— какими кистями реально сделаны мазки;
##   sculpt         — какие изменения должны появиться на меше.

const PROGRESS_PATH := "user://progress.cfg"

const SECTIONS := [
	{
		"id": "basics",
		"title": "ОСНОВЫ",
		"subtitle": "Навигация и первый штрих",
	},
	{
		"id": "brushes",
		"title": "КИСТИ",
		"subtitle": "Одна кисть — один квест",
	},
	{
		"id": "control",
		"title": "КОНТРОЛЬНЫЕ",
		"subtitle": "Свободная работа пройденными кистями",
	},
]

const QUESTS := [
	# ---------------------------------------------------------------- ОСНОВЫ
	{
		"id": "basics_orbit",
		"section": "basics",
		"title": "Вращение сцены",
		"brush": "",
		"description": "В Blender сцену вращают средней кнопкой мыши. Это первый навык скульптора: без осмотра модели не понять, где не хватает объёма.",
		"setup": "СКМ (или ПКМ) + движение мыши",
		"task": "Покрути сферу и осмотри её с разных сторон.",
		"hint": "Зажми СКМ и веди мышью. Колесо — масштаб, ЛКМ — лепка.",
		"actions": {"orbit": 160.0},
		"success": "Вид освоен — теперь модель можно осматривать как в Blender."
	},
	{
		"id": "basics_zoom",
		"section": "basics",
		"title": "Масштаб",
		"brush": "",
		"description": "Колесо мыши приближает и отдаляет вид. Масштаб нужен, чтобы лепить мелкие детали и видеть всю модель целиком.",
		"setup": "Колесо мыши",
		"task": "Приблизь сферу колесом и верни масштаб обратно.",
		"hint": "Один щелчок колеса — один шаг масштаба. Приближайся, когда работаешь с мелкими формами.",
		"actions": {"zoom": 2},
		"success": "Масштаб освоен — можно работать и с общим силуэтом, и с деталями.",
	},
	{
		"id": "basics_stroke",
		"section": "basics",
		"title": "Первый штрих",
		"brush": "draw",
		"description": "ЛКМ — лепить. Draw вытягивает вершины вдоль нормалей и создаёт объём. Это основная кисть любого скульптора.",
		"setup": "Кисть Draw · ЛКМ по сфере",
		"task": "Проведи первый мазок и создай небольшой бугорок.",
		"hint": "Зажми ЛКМ и проведи по поверхности. Отпусти кнопку, чтобы закончить штрих.",
		"actions": {"strokes": 1},
		"require_brushes": ["draw"],
		"success": "Первый штрих готов — кисть слушается.",
	},
	# ---------------------------------------------------------------- КИСТИ
	{
		"id": "brush_draw",
		"section": "brushes",
		"title": "Draw · объём",
		"brush": "draw",
		"description": "Draw — базовая кисть скульптора. Она вытягивает вершины вдоль нормалей (или выбранной оси) и строит основной объём модели.",
		"setup": "Кисть Draw · Radius 30 · Strength 0.50 · Direction «По нормали»",
		"task": "Слепи базовую форму — яйцо или камень. Нарасти макушку несколькими мазками Draw.",
		"hint": "Radius — размер пятна, Strength — сила. Сначала крупные формы, мелкие детали — позже.",
		"setup_check": {
			"brush": "draw",
			"radius": 30.0,
			"strength": 0.5,
			"direction": "normal",
			"tolerance": {"radius": 1.5, "strength": 0.06},
		},
		"require_brushes": ["draw"],
		"sculpt": [
			{
				"metric": "avg_signed",
				"zone_center": Vector3(0, 1, 0),
				"zone_radius": 0.45,
				"min": 0.010,
			},
		],
		"success": "Форма построена: Draw задаёт основной объём.",
	},
	{
		"id": "brush_smooth",
		"section": "brushes",
		"title": "Smooth · ровная поверхность",
		"brush": "smooth",
		"description": "Smooth не добавляет объём: он усредняет положение вершин с соседями и убирает локальные перепады. Форма остаётся, но становится мягче.",
		"setup": "Кисть Smooth · Radius 30 · Strength 0.50",
		"task": "Сначала сделай бугор Draw, затем сгладь его Smooth до мягкой ровной формы.",
		"hint": "Несколько коротких проходов Smooth работают лучше одного долгого. Следи, чтобы форма не «поплыла».",
		"setup_check": {
			"brush": "smooth",
			"radius": 30.0,
			"strength": 0.5,
			"tolerance": {"radius": 1.5, "strength": 0.06},
		},
		"require_brushes": ["draw", "smooth"],
		"sculpt": [
			{
				"metric": "spread_reduction",
				"zone_center": Vector3(0, 1, 0),
				"zone_radius": 0.45,
				"min": 0.15,
				"message": "сначала сделай бугорок Draw, затем сгладь его Smooth — разброс должен уменьшиться.",
			},
		],
		"success": "Поверхность выровнена: Smooth убирает перепады, сохраняя форму.",
	},
	{
		"id": "brush_grab",
		"section": "brushes",
		"title": "Grab · вытягивание",
		"brush": "grab",
		"description": "Grab хватает область и тянет её за курсором. Объём не добавляется — форма вытягивается. Так делают шею, уши, рога и конечности.",
		"setup": "Кисть Grab · Radius 35 · Strength 0.60",
		"task": "Создай заготовку уха: потяни часть сферы кистью Grab в сторону.",
		"hint": "Зажми ЛКМ на сфере и веди мышь. Чем больше Radius, тем крупнее захваченная область.",
		"setup_check": {
			"brush": "grab",
			"radius": 35.0,
			"strength": 0.6,
			"tolerance": {"radius": 2.0, "strength": 0.06},
		},
		"require_brushes": ["grab"],
		"sculpt": [
			{
				"metric": "avg_length",
				"zone_center": Vector3(0, 1, 0),
				"zone_radius": 0.45,
				"min": 0.04,
			},
		],
		"success": "Область вытянута: Grab работает как захват формы.",
	},
	{
		"id": "brush_clay",
		"section": "brushes",
		"title": "Clay Strips · полосы глины",
		"brush": "clay_strips",
		"description": "Clay Strips наращивает объём полосами и уплощает поверхность, как мастихин. Кисть строит плотные массы и плоские плоскости.",
		"setup": "Кисть Clay Strips · Radius 30 · Strength 0.50",
		"task": "Нарасти на сфере плоские полосы глины — основу для головы или торса.",
		"hint": "Веди короткие полосы рядом друг с другом. Кисть любит средний Radius и повторные проходы.",
		"setup_check": {
			"brush": "clay_strips",
			"radius": 30.0,
			"strength": 0.5,
			"tolerance": {"radius": 1.5, "strength": 0.06},
		},
		"require_brushes": ["clay_strips"],
		"sculpt": [
			{
				"metric": "avg_signed",
				"zone_center": Vector3(0, 1, 0),
				"zone_radius": 0.45,
				"min": 0.006,
			},
		],
		"success": "Полосы наращены: Clay Strips строит плоские массы.",
	},
	{
		"id": "brush_crease",
		"section": "brushes",
		"title": "Crease · борозда",
		"brush": "crease",
		"description": "Crease вдавливает узкую линию и стягивает края к центру. Так делают швы, складки и резкие детали.",
		"setup": "Кисть Crease · Radius 15 · Strength 0.60",
		"task": "Продави узкую борозду на макушке — наметь шов или складку.",
		"hint": "Маленький Radius делает борозду резкой. Веди по линии, а не крути кисть на месте.",
		"setup_check": {
			"brush": "crease",
			"radius": 15.0,
			"strength": 0.6,
			"tolerance": {"radius": 1.5, "strength": 0.06},
		},
		"require_brushes": ["crease"],
		"sculpt": [
			{
				"metric": "max_indent",
				"zone_center": Vector3(0, 1, 0),
				"zone_radius": 0.35,
				"min": 0.02,
				"message": "продави борозду Crease — в зоне должна появиться заметная впадина.",
			},
		],
		"success": "Борозда готова: Crease делает швы и складки.",
	},
	{
		"id": "brush_inflate",
		"section": "brushes",
		"title": "Inflate · раздувание",
		"brush": "inflate",
		"description": "Inflate раздувает поверхность вдоль нормалей. Им добавляют щёки, живот и мягкие округлые массы.",
		"setup": "Кисть Inflate · Radius 30 · Strength 0.50",
		"task": "Раздуй сферу в округлый объём — заготовку головы или туловища.",
		"hint": "Inflate похож на Draw, но сильнее раздувает. Проходи по форме несколько раз.",
		"setup_check": {
			"brush": "inflate",
			"radius": 30.0,
			"strength": 0.5,
			"tolerance": {"radius": 1.5, "strength": 0.06},
		},
		"require_brushes": ["inflate"],
		"sculpt": [
			{
				"metric": "avg_signed",
				"zone_center": Vector3(0, 1, 0),
				"zone_radius": 0.45,
				"min": 0.010,
			},
		],
		"success": "Объём раздут: Inflate добавляет округлые массы.",
	},
	# ---------------------------------------------------------------- КОНТРОЛЬНЫЕ
	{
		"id": "check_draw_smooth",
		"section": "control",
		"title": "Контрольная · Draw + Smooth",
		"brush": "",
		"description": "Проверка двух базовых кистей. Draw создаёт форму, Smooth доводит поверхность до аккуратного вида.",
		"setup": "Свободные настройки · нужны Draw и Smooth",
		"task": "Слепи гладкий камень: нарасти форму Draw и выровняй её Smooth.",
		"hint": "Сначала набери объём Draw, потом пройди Smooth. Проверка смотрит и на форму, и на уменьшение разброса.",
		"require_brushes": ["draw", "smooth"],
		"sculpt": [
			{
				"metric": "spread_reduction",
				"zone_center": Vector3(0, 1, 0),
				"zone_radius": 0.45,
				"min": 0.10,
				"message": "пройди Smooth по форме после Draw — перепады должны уменьшиться.",
			},
		],
		"success": "Контрольная пройдена: Draw строит, Smooth выравнивает.",
	},
	{
		"id": "check_all",
		"section": "control",
		"title": "Финальная модель · все кисти",
		"brush": "",
		"description": "Свободная работа всеми изученными кистями. Собери базовую голову: объём, вытянутые детали, складки и мягкие массы.",
		"setup": "Любые настройки · нужны все 6 кистей",
		"task": "Слепи базовую модель: Draw и Clay — объём, Inflate — округлость, Grab — вытяни деталь, Crease — шов, Smooth — финиш.",
		"hint": "Кисти можно менять в любой момент. Проверка засчитает только те, которыми ты реально сделал мазок.",
		"require_brushes": ["draw", "smooth", "grab", "clay_strips", "crease", "inflate"],
		"sculpt": [
			{
				"metric": "avg_length",
				"zone_center": Vector3(0, 1, 0),
				"zone_radius": 0.45,
				"min": 0.03,
				"message": "модель почти не изменена: поработай всеми кистями, чтобы получить объёмную форму.",
			},
		],
		"success": "Финальная модель готова — все шесть кистей в деле.",
	},
]

var current_index: int = 0
var completed: Array[String] = []


func _ready() -> void:
	load_progress()


func total() -> int:
	return QUESTS.size()


func get_quest_count() -> int:
	return QUESTS.size()


func get_quest(index: int) -> Dictionary:
	if index < 0 or index >= QUESTS.size():
		return {}
	return QUESTS[index]


func get_current_quest() -> Dictionary:
	return get_quest(current_index)


func is_quest_completed(index: int) -> bool:
	var quest := get_quest(index)
	if quest.is_empty():
		return false
	return completed.has(str(quest.id))


func first_uncompleted() -> int:
	for i in QUESTS.size():
		if not is_quest_completed(i):
			return i
	return QUESTS.size()


func is_all_completed() -> bool:
	return first_uncompleted() >= QUESTS.size()


func is_unlocked(index: int) -> bool:
	if index < 0 or index >= QUESTS.size():
		return false
	return index <= first_uncompleted()


## Выбор квеста из списка. Открыты пройденные и первый непройденный.
func select_quest(index: int) -> bool:
	if not is_unlocked(index):
		return false
	current_index = index
	save_progress()
	return true


## Отмечает активный квест пройденным.
## Возвращает true, если квест пройден впервые (а не повтор).
func mark_current_completed() -> bool:
	var quest := get_current_quest()
	if quest.is_empty():
		return false
	var id: String = str(quest.id)
	var was_new := not completed.has(id)
	if was_new:
		completed.append(id)
		current_index = first_uncompleted()
	save_progress()
	return was_new


func reset_progress() -> void:
	current_index = 0
	completed.clear()
	save_progress()


func section_title(section_id: String) -> String:
	for section in SECTIONS:
		if str(section.id) == section_id:
			return str(section.title)
	return ""


func section_subtitle(section_id: String) -> String:
	for section in SECTIONS:
		if str(section.id) == section_id:
			return str(section.subtitle)
	return ""


func load_progress() -> void:
	completed.clear()
	current_index = 0
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK:
		return
	current_index = int(cfg.get_value("progress", "current_quest", 0))
	var saved: Variant = cfg.get_value("progress", "completed", PackedStringArray())
	var known: Dictionary = {}
	for quest in QUESTS:
		known[str(quest.id)] = true
	var filtered: Array[String] = []
	if saved is Array or saved is PackedStringArray:
		for value in saved:
			var text := str(value)
			if known.has(text) and not filtered.has(text):
				filtered.append(text)
	completed = filtered
	current_index = clampi(current_index, 0, QUESTS.size())
	if not is_unlocked(current_index):
		current_index = first_uncompleted()


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "current_quest", current_index)
	cfg.set_value("progress", "completed", PackedStringArray(completed))
	var err := cfg.save(PROGRESS_PATH)
	if err != OK:
		push_warning("Не удалось сохранить прогресс: %s" % error_string(err))
