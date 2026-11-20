extends Node3D
## Главный сценарий: 3D-вьюпорт, ввод, проверка квестов и связь UI со скульптором.

const RING_SHADER := preload("res://shaders/brush_ring.gdshader")
const SPHERE_HIT_RADIUS := 1.02

@onready var mesh_node: DeformMesh = $Target
@onready var cam_rig: OrbitCamera = $CameraRig
@onready var hud: CanvasLayer = $UI

var _painting := false
var _orbiting := false
var _last_paint_mouse := Vector2(-9999, -9999)
var _current_quest: Dictionary = {}
var _advancing := false
var _spread_baseline := 0.0
var _spread_sample_timer := 0.0
var _cursor: MeshInstance3D
var _cursor_material: ShaderMaterial

# Статистика действий, сбрасывается при старте квеста.
var _orbit_pixels := 0.0
var _zoom_steps := 0
var _strokes := 0
var _radius_changes := 0
var _strength_changes := 0
var _used_brushes: Dictionary = {}


func _ready() -> void:
	_setup_environment()
	_setup_lights()
	_build_brush_cursor()

	hud.brush_selected.connect(_on_brush_selected)
	hud.radius_changed.connect(_on_radius_changed)
	hud.strength_changed.connect(_on_strength_changed)
	hud.direction_selected.connect(_on_direction_changed)
	hud.check_requested.connect(_on_check_requested)
	hud.reset_mesh_requested.connect(_on_reset_mesh)
	hud.reset_view_requested.connect(_on_reset_view)
	hud.reset_progress_requested.connect(_on_reset_progress)
	hud.quest_selected.connect(_on_quest_selected)

	_sync_hud()
	_load_current_quest()

	# На первом запуске сразу показываем выбор квеста.
	if QuestManager.completed.is_empty():
		hud.open_quest_list()


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.052, 0.058, 0.072, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.62, 1.0)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	$WorldEnvironment.environment = env


func _setup_lights() -> void:
	# Основной и заполняющий свет вращаются вместе с камерой, поэтому
	# видимая сторона освещена ровно и без пересвета.
	$KeyLight.light_color = Color(1.0, 0.97, 0.94, 1.0)
	$KeyLight.light_energy = 0.9
	$KeyLight.shadow_enabled = true
	$KeyLight.directional_shadow_max_distance = 12.0

	$FillLight.light_color = Color(0.82, 0.85, 0.92, 1.0)
	$FillLight.light_energy = 0.12

	_update_camera_light()


## Свет всегда падает со стороны камеры. Небольшой наклон и слабый
## заполняющий свет оставляют объём, не выжигая одну сторону.
func _update_camera_light() -> void:
	var camera := cam_rig.camera
	if camera == null:
		return
	var cam_basis := camera.global_transform.basis
	var key_tilt := (
		Basis(Vector3.UP, deg_to_rad(34.0))
		* Basis(Vector3.RIGHT, deg_to_rad(-24.0))
	)
	$KeyLight.global_transform = Transform3D(
		cam_basis * key_tilt,
		$KeyLight.global_position
	)
	var fill_tilt := (
		Basis(Vector3.UP, deg_to_rad(-28.0))
		* Basis(Vector3.RIGHT, deg_to_rad(14.0))
	)
	$FillLight.global_transform = Transform3D(
		cam_basis * fill_tilt,
		$FillLight.global_position
	)


func _build_brush_cursor() -> void:
	_cursor = MeshInstance3D.new()
	_cursor.name = "BrushCursor"
	_cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cursor.visible = false

	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	plane.orientation = PlaneMesh.FACE_Y
	_cursor.mesh = plane

	_cursor_material = ShaderMaterial.new()
	_cursor_material.shader = RING_SHADER
	_cursor.material_override = _cursor_material
	add_child(_cursor)


func _sync_hud() -> void:
	hud.set_brush_state(
		BrushManager.brush,
		BrushManager.radius,
		BrushManager.strength,
		BrushManager.direction
	)


func _load_current_quest() -> void:
	_current_quest = QuestManager.get_current_quest()
	_reset_quest_tracking()
	mesh_node.reset_shape()
	if _current_quest.is_empty():
		hud.show_final(QuestManager.completed.size())
		return
	_ensure_available_brush()
	_sync_hud()
	hud.show_quest(
		_current_quest,
		QuestManager.current_index,
		QuestManager.completed.size()
	)
	var spread_condition := _spread_baseline_condition()
	if not spread_condition.is_empty():
		_spread_baseline = _zone_spread(spread_condition)


## Держит выбранную кисть в пределах открытых и подсказывает кисть квеста.
func _ensure_available_brush() -> void:
	var available := QuestManager.unlocked_brushes()
	if available.is_empty():
		return
	if available.has(BrushManager.brush):
		return
	var preferred := str(_current_quest.get("brush", ""))
	if available.has(preferred):
		BrushManager.set_brush(preferred)
	else:
		BrushManager.set_brush(available[0])


func _reset_quest_tracking() -> void:
	_orbit_pixels = 0.0
	_zoom_steps = 0
	_strokes = 0
	_radius_changes = 0
	_strength_changes = 0
	_used_brushes.clear()
	_spread_baseline = 0.0
	_spread_sample_timer = 0.0


func _process(delta: float) -> void:
	var left_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if _painting and not left_down:
		_painting = false

	if _painting and left_down and not _orbiting and not _advancing:
		var mouse := get_viewport().get_mouse_position()
		if mouse != _last_paint_mouse:
			if not _pointer_over_ui():
				_paint_at(mouse)
			_last_paint_mouse = mouse

	var orbit_down := (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	)
	if _orbiting and not orbit_down:
		_orbiting = false

	_update_brush_cursor()
	_update_camera_light()
	_sample_spread_baseline(delta)


func _sample_spread_baseline(delta: float) -> void:
	if _current_quest.is_empty() or _advancing:
		return
	var condition := _spread_baseline_condition()
	if condition.is_empty():
		return
	_spread_sample_timer += delta
	if _spread_sample_timer < 0.15:
		return
	_spread_sample_timer = 0.0
	_spread_baseline = maxf(_spread_baseline, _zone_spread(condition))


func _unhandled_input(event: InputEvent) -> void:
	if hud.is_quest_list_open():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if not _advancing:
				_zoom_steps += 1
			cam_rig.zoom_steps(1.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if not _advancing:
				_zoom_steps += 1
			cam_rig.zoom_steps(-1.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_painting = true
				if not _advancing:
					hud.clear_result()
				_last_paint_mouse = get_viewport().get_mouse_position()
				if not _pointer_over_ui():
					if _paint_at(_last_paint_mouse):
						_strokes += 1
			else:
				_painting = false
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = event.pressed
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _orbiting:
		if not _advancing:
			_orbit_pixels += event.relative.length()
		cam_rig.orbit_relative(event.relative)
		get_viewport().set_input_as_handled()


func _paint_at(screen_position: Vector2) -> bool:
	if _advancing:
		return false
	var hit := _raycast_sphere(screen_position)
	if hit.is_empty():
		return false
	var local_point := mesh_node.to_local(hit.position)
	var local_normal: Vector3 = (
		mesh_node.global_transform.basis.inverse() * (hit.normal as Vector3)
	).normalized()
	var drag := Vector3.ZERO
	if BrushManager.brush == BrushManager.GRAB:
		drag = _grab_drag(hit)
	var changed := mesh_node.apply_brush(
		local_point,
		BrushManager.radius_world(),
		BrushManager.strength,
		BrushManager.brush,
		BrushManager.direction,
		drag,
		local_normal
	)
	if changed:
		_used_brushes[BrushManager.brush] = true
		var spread_condition := _spread_baseline_condition()
		if not spread_condition.is_empty():
			_spread_baseline = maxf(_spread_baseline, _zone_spread(spread_condition))
	return changed


## Смещение курсора в локальных координатах меша для кисти Grab.
func _grab_drag(hit: Dictionary) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.ZERO
	var depth := camera.global_position.distance_to(hit.position)
	var previous_world := camera.project_position(_last_paint_mouse, depth)
	var current_world := camera.project_position(
		get_viewport().get_mouse_position(),
		depth
	)
	return mesh_node.to_local(current_world) - mesh_node.to_local(previous_world)


func _raycast_sphere(screen_position: Vector2) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return {}
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var center := mesh_node.global_position
	var oc := origin - center
	var b := oc.dot(direction)
	var c := oc.length_squared() - SPHERE_HIT_RADIUS * SPHERE_HIT_RADIUS
	var disc := b * b - c
	if disc < 0.0:
		return {}
	var t := -b - sqrt(disc)
	if t < 0.0:
		t = -b + sqrt(disc)
	if t < 0.0:
		return {}
	var point := origin + direction * t
	var normal := (point - center).normalized()
	return {"position": point, "normal": normal}


func _pointer_over_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.is_visible_in_tree()


func _update_brush_cursor() -> void:
	if _cursor == null:
		return
	if _orbiting or _pointer_over_ui():
		_cursor.visible = false
		return

	var hit := _raycast_sphere(get_viewport().get_mouse_position())
	if hit.is_empty():
		_cursor.visible = false
		return

	var normal: Vector3 = hit.normal
	var tangent := Vector3.RIGHT
	if absf(normal.dot(tangent)) > 0.9:
		tangent = Vector3.FORWARD
	tangent = (tangent - normal * tangent.dot(normal)).normalized()
	var bitangent := tangent.cross(normal).normalized()
	var radius := BrushManager.radius_world() / 0.92
	var basis := Basis(tangent * radius, normal, bitangent * radius)

	_cursor.visible = true
	_cursor.global_transform = Transform3D(basis, hit.position + normal * 0.006)
	var color := _brush_cursor_color()
	if _painting:
		color.a = 1.0
	else:
		color.a = 0.9
	_cursor_material.set_shader_parameter("ring_color", color)


func _brush_cursor_color() -> Color:
	match BrushManager.brush:
		"smooth":
			return Color(0.4, 0.67, 1.0, 0.95)
		"grab":
			return Color(0.45, 0.82, 0.6, 0.95)
		"clay_strips":
			return Color(0.94, 0.72, 0.42, 0.95)
		"crease":
			return Color(0.95, 0.52, 0.66, 0.95)
		"inflate":
			return Color(0.38, 0.82, 0.8, 0.95)
		_:
			return Color(0.95, 0.57, 0.22, 0.95)


func _on_brush_selected(brush: String) -> void:
	BrushManager.set_brush(brush)
	hud.clear_result()
	_sync_hud()


func _on_radius_changed(value: float) -> void:
	BrushManager.set_radius(value)
	_radius_changes += 1
	hud.clear_result()


func _on_strength_changed(value: float) -> void:
	BrushManager.set_strength(value)
	_strength_changes += 1
	hud.clear_result()


func _on_direction_changed(direction: String) -> void:
	BrushManager.set_direction(direction)
	hud.clear_result()


func _on_quest_selected(index: int) -> void:
	if _advancing:
		return
	if not QuestManager.select_quest(index):
		return
	mesh_node.reset_shape()
	hud.clear_result()
	_sync_hud()
	_load_current_quest()


func _on_reset_mesh() -> void:
	mesh_node.reset_shape()
	_reset_quest_tracking()
	hud.clear_result()


func _on_reset_view() -> void:
	cam_rig.reset_view()


func _on_reset_progress() -> void:
	if _advancing:
		return
	QuestManager.reset_progress()
	mesh_node.reset_shape()
	_reset_quest_tracking()
	hud.clear_result()
	hud.refresh_quest_list()
	BrushManager.set_brush(BrushManager.DRAW)
	BrushManager.set_radius(20.0)
	BrushManager.set_strength(0.7)
	BrushManager.set_direction(BrushManager.DIR_NORMAL)
	_sync_hud()
	_load_current_quest()


func _on_check_requested() -> void:
	if _advancing or _current_quest.is_empty():
		return
	var result := check()
	var success: bool = result.get("ok", false)
	hud.show_result(success, str(result.get("message", "")))
	if not success:
		return

	_advancing = true
	hud.set_check_enabled(false)
	QuestManager.mark_current_completed()
	hud.refresh_quest_list()
	await get_tree().create_timer(1.4).timeout
	_advancing = false
	# Каждый квест — отдельное задание: после прохождения возвращаемся
	# в меню выбора квестов, а не переходим к следующему автоматически.
	_load_current_quest()
	hud.open_quest_list()


## Публичная точка входа проверки текущего квеста.
func check() -> Dictionary:
	if _current_quest.is_empty():
		return {
			"ok": false,
			"message": "Курс пройден. Открой список квестов и выбери любой для повтора.",
		}
	return _check_quest(_current_quest)


func _check_quest(quest: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	issues.append_array(_check_actions(quest))
	issues.append_array(_check_setup(quest))
	issues.append_array(_check_brushes(quest))
	issues.append_array(_check_sculpt(quest))
	if issues.is_empty():
		return {"ok": true, "message": str(quest.get("success", "Квест выполнен."))}
	return {"ok": false, "message": " ".join(issues)}


func _check_actions(quest: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var actions: Dictionary = quest.get("actions", {})
	if actions.is_empty():
		return issues
	if actions.has("orbit") and _orbit_pixels < float(actions.get("orbit", 0.0)):
		issues.append("покрути сцену средней кнопкой мыши — нужно осмотреть модель.")
	if actions.has("zoom") and _zoom_steps < int(actions.get("zoom", 0)):
		issues.append("приблизь и отдали сферу колесом мыши.")
	if actions.has("strokes") and _strokes < int(actions.get("strokes", 0)):
		issues.append("сделай хотя бы один результативный мазок ЛКМ.")
	if (
		actions.has("radius_changes")
		and _radius_changes < int(actions.get("radius_changes", 0))
	):
		issues.append("подвинь ползунок Radius — выбери площадь кисти под форму.")
	if (
		actions.has("strength_changes")
		and _strength_changes < int(actions.get("strength_changes", 0))
	):
		issues.append("подвинь ползунок Strength — настрой силу мазка.")
	return issues


func _check_setup(quest: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var setup: Dictionary = quest.get("setup_check", {})
	if setup.is_empty():
		return issues
	var tolerance: Dictionary = setup.get("tolerance", {})

	var wanted_brush := str(setup.get("brush", "draw"))
	if BrushManager.brush != wanted_brush:
		issues.append("выбери кисть %s." % BrushManager.title_of(wanted_brush))

	if setup.has("radius"):
		var wanted_radius := float(setup.get("radius", 30.0))
		var radius_tolerance := float(tolerance.get("radius", 1.5))
		if absf(BrushManager.radius - wanted_radius) > radius_tolerance:
			issues.append(
				"Radius = %d px, нужно %d." % [
					roundi(BrushManager.radius),
					roundi(wanted_radius),
				]
			)

	if setup.has("strength"):
		var wanted_strength := float(setup.get("strength", 0.5))
		var strength_tolerance := float(tolerance.get("strength", 0.06))
		if absf(BrushManager.strength - wanted_strength) > strength_tolerance:
			issues.append(
				"Strength = %.2f, нужно %.2f." % [
					BrushManager.strength,
					wanted_strength,
				]
			)

	if setup.has("direction"):
		var wanted_direction := str(setup.get("direction", "normal"))
		if BrushManager.direction != wanted_direction:
			issues.append(
				"Direction должен быть «%s»."
				% BrushManager.direction_title_of(wanted_direction)
			)

	return issues


func _check_brushes(quest: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var required: Variant = quest.get("require_brushes", [])
	if not (required is Array):
		return issues
	var required_array: Array = required
	for raw in required_array:
		var brush_id := str(raw)
		if not _used_brushes.has(brush_id):
			issues.append(
				"используй кисть %s хотя бы одним мазком."
				% BrushManager.title_of(brush_id)
			)
	return issues


func _check_sculpt(quest: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	for raw in _sculpt_conditions(quest):
		if not (raw is Dictionary):
			continue
		var condition: Dictionary = raw
		var metric := str(condition.get("metric", "avg_signed"))
		var center: Vector3 = condition.get("zone_center", Vector3(0, 1, 0))
		var zone_radius := float(condition.get("zone_radius", 0.45))
		var stats: Dictionary = mesh_node.get_zone_stats(center, zone_radius)
		var value := 0.0

		match metric:
			"avg_signed":
				value = float(stats.get("avg_signed", 0.0))
			"avg_length":
				value = float(stats.get("avg_length", 0.0))
			"spread":
				value = float(stats.get("spread", 0.0))
			"max_indent":
				value = float(stats.get("max_indent", 0.0))
			"max_signed":
				value = float(stats.get("max_signed", 0.0))
			"zone_diff":
				var other_center: Vector3 = condition.get(
					"zone_center_b", Vector3.ZERO
				)
				var other: Dictionary = mesh_node.get_zone_stats(
					other_center, zone_radius
				)
				value = absf(
					float(stats.get("avg_signed", 0.0))
					- float(other.get("avg_signed", 0.0))
				)
			"spread_reduction":
				var spread := float(stats.get("spread", 0.0))
				_spread_baseline = maxf(_spread_baseline, spread)
				if _spread_baseline < 0.003:
					issues.append(_condition_message(condition, metric, 0.0, true))
					continue
				value = 1.0 - spread / _spread_baseline
			_:
				value = float(stats.get("avg_signed", 0.0))

		var ok := true
		if condition.has("min") and value < float(condition.get("min")):
			ok = false
		if condition.has("max") and value > float(condition.get("max")):
			ok = false
		if not ok:
			issues.append(_condition_message(condition, metric, value, false))

	return issues


func _condition_message(
	condition: Dictionary,
	metric: String,
	value: float,
	missing_baseline: bool
) -> String:
	var custom := str(condition.get("message", "")).strip_edges()
	if missing_baseline and not custom.is_empty():
		return custom
	if not custom.is_empty():
		return custom
	if metric == "spread_reduction":
		return (
			"разброс уменьшился на %.0f%%, нужно ≥ %.0f%%."
			% [value * 100.0, float(condition.get("min", 0.0)) * 100.0]
		)
	if condition.has("min"):
		return (
			"%s = %.3f, нужно ≥ %.3f."
			% [_metric_title(metric), value, float(condition.get("min", 0.0))]
		)
	return (
		"%s = %.3f, нужно ≤ %.3f."
		% [_metric_title(metric), value, float(condition.get("max", 0.0))]
	)


func _metric_title(metric: String) -> String:
	match metric:
		"avg_signed":
			return "среднее смещение"
		"avg_length":
			return "среднее смещение"
		"spread":
			return "разброс"
		"max_indent":
			return "глубина впадины"
		"max_signed":
			return "высота бугра"
		"zone_diff":
			return "разница сторон"
		"spread_reduction":
			return "уменьшение разброса"
		_:
			return metric


func _sculpt_conditions(quest: Dictionary) -> Array:
	var raw: Variant = quest.get("sculpt", [])
	if raw is Array:
		var conditions: Array = raw
		return conditions
	return []


func _spread_baseline_condition() -> Dictionary:
	for raw in _sculpt_conditions(_current_quest):
		if raw is Dictionary:
			var condition: Dictionary = raw
			if str(condition.get("metric", "")) == "spread_reduction":
				return condition
	return {}


func _zone_spread(condition: Dictionary) -> float:
	var center: Vector3 = condition.get("zone_center", Vector3(0, 1, 0))
	var zone_radius := float(condition.get("zone_radius", 0.45))
	var stats: Dictionary = mesh_node.get_zone_stats(center, zone_radius)
	return float(stats.get("spread", 0.0))
