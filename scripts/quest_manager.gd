extends Node
## Список квестов и сохранение прогресса (autoload QuestManager).
##
## Курс разбит на разделы:
##   basics  — камера, настройки кисти и первый штрих;
##   brushes — по одной кисти на квест;
##   control — контрольные по пройденным кистям;
##   shapes  — сложные формы из нескольких зон.
##
## У квеста могут быть сразу несколько условий:
##   actions        — что пользователь сделал мышью;
##   setup_check    — какие настройки кисти должны стоять;
##   require_brushes— какими кистями реально сделаны мазки;
##   sculpt         — какие изменения должны появиться на меше.
##
## Метрики sculpt: avg_signed, avg_length, spread, spread_reduction,
## max_indent, max_signed, zone_diff.

const PROGRESS_PATH := "user://progress.cfg"

## Кисти открываются постепенно. Draw доступна с самого начала,
## остальные появляются после прохождения своего урока (или при выборе
## квеста, которому эта кисть нужна).
const START_BRUSHES := ["draw"]
const LESSON_BRUSHES := {
	"brush_draw": "draw",
	"brush_smooth": "smooth",
	"brush_grab": "grab",
	"brush_clay": "clay_strips",
	"brush_crease": "crease",
	"brush_inflate": "inflate",
}
const BRUSH_ORDER := ["draw", "smooth", "grab", "clay_strips", "crease", "inflate"]

const SECTIONS := [
	{
		"id": "basics",
		"title": "ОСНОВЫ",
	},
	{
		"id": "brushes",
		"title": "КИСТИ",
	},
	{
		"id": "control",
		"title": "КОНТРОЛЬНЫЕ",
	},
	{
		"id": "shapes",
		"title": "СЛОЖНЫЕ ФОРМЫ",
	},
]

const QUESTS := [
	# ---------------------------------------------------------------- ОСНОВЫ
	{
		"id": "basics_intro",
		"section": "basics",
		"title": "Камера, кисть и настройки",
		"brush": "draw",
		"setup": "СКМ/ПКМ — вращение · колесо — масштаб · ЛКМ — Draw",
		"task": "Покрути сферу, приблизь и отдали её колесом, подвинь Radius и Strength, затем проведи мазок Draw.",
		"hint": "Radius — площадь мазка: 40–60 для крупных форм, 10–20 для деталей. Strength — сила: 0.3–0.5 для мягкой лепки, 0.7–1.0 для резкой.",
		"actions": {
			"orbit": 160.0,
			"zoom": 2,
			"strokes": 1,
			"radius_changes": 1,
			"strength_changes": 1,
		},
		"require_brushes": ["draw"],
		"success": "Управление, настройки кисти и первый штрих освоены.",
	},
	# ---------------------------------------------------------------- КИСТИ
	{
		"id": "brush_draw",
		"section": "brushes",
		"title": "Draw · объём",
		"brush": "draw",
		"setup": "Кисть Draw · Radius 30 · Strength 0.50 · Direction «По нормали»",
		"task": "Нарасти макушку несколькими мазками Draw — сделай яйцо или камень.",
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
		"setup": "Кисть Smooth · Radius 30 · Strength 0.50",
		"task": "Сначала сделай бугор Draw, затем сгладь его Smooth до мягкой формы.",
		"hint": "Несколько коротких проходов Smooth работают лучше одного долгого.",
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
		"setup": "Кисть Clay Strips · Radius 30 · Strength 0.50",
		"task": "Нарасти на сфере плоские полосы глины.",
		"hint": "Веди короткие полосы рядом друг с другом.",
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
		"setup": "Кисть Crease · Radius 15 · Strength 0.60",
		"task": "Продави узкую борозду на макушке — наметь шов или складку.",
		"hint": "Веди по линии, а не крути кисть на месте.",
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
		"setup": "Кисть Inflate · Radius 30 · Strength 0.50",
		"task": "Раздуй сферу в округлый объём.",
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
		"setup": "Свободные настройки · нужны Draw и Smooth",
		"task": "Слепи гладкий камень: нарасти форму Draw и выровняй её Smooth.",
		"hint": "Сначала набери объём Draw, потом пройди Smooth.",
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
		"setup": "Любые настройки · нужны все 6 кистей",
		"task": "Слепи модель всеми кистями: объём, округлость, вытянутая деталь, шов и финиш Smooth.",
		"hint": "Проверка засчитает только те кисти, которыми ты реально сделал мазок.",
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
	# ---------------------------------------------------------------- СЛОЖНЫЕ ФОРМЫ
	{
		"id": "shape_horns",
		"section": "shapes",
		"title": "Пара рогов",
		"brush": "draw",
		"setup": "Кисть Draw · Radius 15 · Strength 0.70 · По нормали",
		"task": "Вытяни два рога по бокам макушки.",
		"hint": "Мелкий Radius делает рог тонким. Вращай сцену, чтобы добраться до обеих сторон.",
		"setup_check": {
			"brush": "draw",
			"radius": 15.0,
			"strength": 0.7,
			"tolerance": {"radius": 1.5, "strength": 0.06},
		},
		"require_brushes": ["draw"],
		"sculpt": [
			{
				"metric": "avg_signed",
				"zone_center": Vector3(-0.6, 0.8, 0),
				"zone_radius": 0.3,
				"min": 0.007,
				"message": "вытяни левый рог — слева от макушки мало объёма.",
			},
			{
				"metric": "avg_signed",
				"zone_center": Vector3(0.6, 0.8, 0),
				"zone_radius": 0.3,
				"min": 0.007,
				"message": "вытяни правый рог — справа от макушки мало объёма.",
			},
		],
		"success": "Оба рога готовы.",
	},
	{
		"id": "shape_ears",
		"section": "shapes",
		"title": "Уши · две стороны",
		"brush": "grab",
		"setup": "Кисть Grab · Radius 30 · Strength 0.60",
		"task": "Оттяни два уха по бокам головы.",
		"hint": "Разверни модель и потяни сначала одну сторону, потом другую.",
		"setup_check": {
			"brush": "grab",
			"radius": 30.0,
			"strength": 0.6,
			"tolerance": {"radius": 2.0, "strength": 0.06},
		},
		"require_brushes": ["grab"],
		"sculpt": [
			{
				"metric": "avg_length",
				"zone_center": Vector3(-1, 0.1, 0),
				"zone_radius": 0.35,
				"min": 0.05,
				"message": "оттяни левое ухо — сбоку нет вытянутой формы.",
			},
			{
				"metric": "avg_length",
				"zone_center": Vector3(1, 0.1, 0),
				"zone_radius": 0.35,
				"min": 0.05,
				"message": "оттяни правое ухо — сбоку нет вытянутой формы.",
			},
		],
		"success": "Оба уха вытянуты: Grab работает на любой стороне.",
	},
	{
		"id": "shape_face",
		"section": "shapes",
		"title": "Лицо · нос и глазницы",
		"brush": "",
		"setup": "Draw для носа · Crease для глазниц",
		"task": "Слепи нос и продави две глазницы по бокам от него.",
		"hint": "Нос — несколькими мазками Draw. Глазницы — короткими Crease с небольшим Radius.",
		"require_brushes": ["draw", "crease"],
		"sculpt": [
			{
				"metric": "avg_signed",
				"zone_center": Vector3(0, 0.05, 1),
				"zone_radius": 0.28,
				"min": 0.012,
				"message": "нарасти нос по центру лица.",
			},
			{
				"metric": "max_indent",
				"zone_center": Vector3(-0.34, 0.22, 0.91),
				"zone_radius": 0.2,
				"min": 0.015,
				"message": "продави левую глазницу кистью Crease.",
			},
			{
				"metric": "max_indent",
				"zone_center": Vector3(0.34, 0.22, 0.91),
				"zone_radius": 0.2,
				"min": 0.015,
				"message": "продави правую глазницу кистью Crease.",
			},
		],
		"success": "Лицо намечено: нос и глазницы на месте.",
	},
	{
		"id": "shape_balance",
		"section": "shapes",
		"title": "Симметричные бугры",
		"brush": "draw",
		"setup": "Кисть Draw · Radius 25 · Strength 0.60",
		"task": "Сделай два одинаковых бугра слева и справа от макушки.",
		"hint": "Следи за размером: разница между сторонами должна быть минимальной.",
		"setup_check": {
			"brush": "draw",
			"radius": 25.0,
			"strength": 0.6,
			"tolerance": {"radius": 1.5, "strength": 0.06},
		},
		"require_brushes": ["draw"],
		"sculpt": [
			{
				"metric": "avg_signed",
				"zone_center": Vector3(-0.45, 0.55, 0.7),
				"zone_radius": 0.28,
				"min": 0.010,
				"message": "нарасти левый бугор.",
			},
			{
				"metric": "avg_signed",
				"zone_center": Vector3(0.45, 0.55, 0.7),
				"zone_radius": 0.28,
				"min": 0.010,
				"message": "нарасти правый бугор.",
			},
			{
				"metric": "zone_diff",
				"zone_center": Vector3(-0.45, 0.55, 0.7),
				"zone_center_b": Vector3(0.45, 0.55, 0.7),
				"zone_radius": 0.28,
				"max": 0.010,
				"message": "бугры разной высоты — подровняй стороны Draw.",
			},
		],
		"success": "Симметрия выдержана.",
	},
	{
		"id": "shape_mask",
		"section": "shapes",
		"title": "Маска · полный рельеф",
		"brush": "",
		"setup": "Все кисти · любые настройки",
		"task": "Собери маску: нос, надбровная складка, ухо и гладкая щека.",
		"hint": "Сначала крупные массы, затем детали. Финиш — Smooth по щеке.",
		"require_brushes": ["draw", "smooth", "grab", "clay_strips", "crease", "inflate"],
		"sculpt": [
			{
				"metric": "avg_signed",
				"zone_center": Vector3(0, 0.1, 1),
				"zone_radius": 0.26,
				"min": 0.012,
				"message": "нарасти нос.",
			},
			{
				"metric": "max_indent",
				"zone_center": Vector3(0, 0.5, 0.86),
				"zone_radius": 0.22,
				"min": 0.015,
				"message": "продави надбровную складку Crease.",
			},
			{
				"metric": "avg_length",
				"zone_center": Vector3(1, 0.1, 0),
				"zone_radius": 0.35,
				"min": 0.04,
				"message": "оттяни ухо кистью Grab.",
			},
			{
				"metric": "spread_reduction",
				"zone_center": Vector3(0.6, 0.2, 0.78),
				"zone_radius": 0.3,
				"min": 0.10,
				"message": "сделай щёку объёмной и выровняй её Smooth.",
			},
		],
		"success": "Маска готова: объём, детали и ровная поверхность.",
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
	return index >= 0 and index < QUESTS.size()


## Все кисти, доступные игроку сейчас:
## стартовые, изученные на пройденных уроках и нужные текущему квесту.
func unlocked_brushes() -> Array[String]:
	var available: Array[String] = []
	for brush_id in START_BRUSHES:
		available.append(str(brush_id))
	for lesson_id in LESSON_BRUSHES:
		var brush_id := str(LESSON_BRUSHES[lesson_id])
		if completed.has(str(lesson_id)) and not available.has(brush_id):
			available.append(brush_id)
	var required: Variant = get_current_quest().get("require_brushes", [])
	if required is Array:
		for raw in required:
			var brush_id := str(raw)
			if not available.has(brush_id):
				available.append(brush_id)
	var ordered: Array[String] = []
	for brush_id in BRUSH_ORDER:
		if available.has(brush_id):
			ordered.append(brush_id)
	return ordered


## Выбор квеста из списка. Все квесты открыты с самого начала.
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
