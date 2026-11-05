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
var _smooth_baseline := 0.0
var _smooth_sample_timer := 0.0
var _cursor: MeshInstance3D
var _cursor_material: ShaderMaterial


func _ready() -> void:
	_setup_environment()
	_setup_lights()
	_build_grid()
	_build_brush_cursor()

	hud.brush_selected.connect(_on_brush_selected)
	hud.radius_changed.connect(_on_radius_changed)
	hud.strength_changed.connect(_on_strength_changed)
	hud.direction_selected.connect(_on_direction_changed)
	hud.check_requested.connect(_on_check_requested)
	hud.reset_mesh_requested.connect(_on_reset_mesh)
	hud.reset_view_requested.connect(_on_reset_view)
	hud.reset_progress_requested.connect(_on_reset_progress)

	_sync_hud()
	_load_current_quest()


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.052, 0.058, 0.072, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.42, 0.54, 1.0)
	env.ambient_light_energy = 0.55
	$WorldEnvironment.environment = env


func _setup_lights() -> void:
	$KeyLight.rotation_degrees = Vector3(-52, -35, 0)
	$KeyLight.light_color = Color(1.0, 0.94, 0.87, 1.0)
	$KeyLight.light_energy = 1.5
	$KeyLight.shadow_enabled = true
	$KeyLight.directional_shadow_max_distance = 12.0

	$FillLight.rotation_degrees = Vector3(-18, 140, 0)
	$FillLight.light_color = Color(0.55, 0.68, 1.0, 1.0)
	$FillLight.light_energy = 0.55

	$RimLight.position = Vector3(2.0, 1.4, -1.8)
	$RimLight.light_color = Color(1.0, 0.55, 0.24, 1.0)
	$RimLight.light_energy = 1.1
	$RimLight.omni_range = 4.5


func _build_grid() -> void:
	var grid_mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	grid_mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)

	for i in range(-8, 9):
		var v := float(i) * 0.5
		var color := Color(0.32, 0.37, 0.46, 0.2)
		if i == 0:
			color = Color(0.56, 0.62, 0.75, 0.34)
		_add_grid_line(grid_mesh, Vector3(-4, 0, v), Vector3(4, 0, v), color)
		_add_grid_line(grid_mesh, Vector3(v, 0, -4), Vector3(v, 0, 4), color)

	grid_mesh.surface_end()
	$Grid.mesh = grid_mesh


func _add_grid_line(grid: ImmediateMesh, a: Vector3, b: Vector3, color: Color) -> void:
	grid.surface_set_color(color)
	grid.surface_add_vertex(a)
	grid.surface_set_color(color)
	grid.surface_add_vertex(b)


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
	_smooth_sample_timer = 0.0
	if _current_quest.is_empty():
		_smooth_baseline = 0.0
		hud.show_final(QuestManager.completed.size())
		return
	hud.show_quest(
		_current_quest,
		QuestManager.current_index,
		QuestManager.completed.size()
	)
	if str(_current_quest.get("id", "")) == "smooth_bulge":
		_smooth_baseline = _zone_spread(_current_quest)
	else:
		_smooth_baseline = 0.0


func _process(delta: float) -> void:
	var left_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if _painting and not left_down:
		_painting = false

	if _painting and left_down and not _orbiting and not _advancing:
		var mouse := get_viewport().get_mouse_position()
		if mouse != _last_paint_mouse and not _pointer_over_ui():
			_last_paint_mouse = mouse
			_paint_at(mouse)

	var orbit_down := (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	)
	if _orbiting and not orbit_down:
		_orbiting = false

	_update_brush_cursor()
	_sample_smooth_baseline(delta)


func _sample_smooth_baseline(delta: float) -> void:
	if _current_quest.is_empty() or _advancing:
		return
	if str(_current_quest.get("id", "")) != "smooth_bulge":
		return
	_smooth_sample_timer += delta
	if _smooth_sample_timer < 0.15:
		return
	_smooth_sample_timer = 0.0
	_smooth_baseline = maxf(_smooth_baseline, _zone_spread(_current_quest))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			cam_rig.zoom_steps(1.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			cam_rig.zoom_steps(-1.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_painting = true
				if not _advancing:
					hud.clear_result()
				_last_paint_mouse = get_viewport().get_mouse_position()
				if not _pointer_over_ui():
					_paint_at(_last_paint_mouse)
			else:
				_painting = false
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = event.pressed
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _orbiting:
		cam_rig.orbit_relative(event.relative)
		get_viewport().set_input_as_handled()


func _paint_at(screen_position: Vector2) -> bool:
	if _advancing:
		return false
	var hit := _raycast_sphere(screen_position)
	if hit.is_empty():
		return false
	var local_point := mesh_node.to_local(hit.position)
	return mesh_node.apply_brush(
		local_point,
		BrushManager.radius_world(),
		BrushManager.strength,
		BrushManager.brush,
		BrushManager.direction
	)


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
	if BrushManager.brush == BrushManager.SMOOTH:
		_cursor_material.set_shader_parameter("ring_color", Color(0.4, 0.67, 1.0, 0.95))
	else:
		_cursor_material.set_shader_parameter(
			"ring_color",
			Color(0.95, 0.57, 0.22, 1.0 if _painting else 0.92)
		)


func _on_brush_selected(brush: String) -> void:
	BrushManager.set_brush(brush)
	hud.clear_result()
	_sync_hud()


func _on_radius_changed(value: float) -> void:
	BrushManager.set_radius(value)
	hud.clear_result()


func _on_strength_changed(value: float) -> void:
	BrushManager.set_strength(value)
	hud.clear_result()


func _on_direction_changed(direction: String) -> void:
	BrushManager.set_direction(direction)
	hud.clear_result()


func _on_reset_mesh() -> void:
	mesh_node.reset_shape()
	_smooth_baseline = 0.0
	_smooth_sample_timer = 0.0
	hud.clear_result()


func _on_reset_view() -> void:
	cam_rig.reset_view()


func _on_reset_progress() -> void:
	if _advancing:
		return
	QuestManager.reset_progress()
	mesh_node.reset_shape()
	_smooth_baseline = 0.0
	hud.clear_result()
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
	await get_tree().create_timer(1.5).timeout
	_advancing = false
	_load_current_quest()


## Публичная точка входа проверки текущего квеста.
func check() -> Dictionary:
	if _current_quest.is_empty():
		return {"ok": false, "message": "Квесты уже пройдены."}
	return _check_quest(_current_quest)


func _check_quest(quest: Dictionary) -> Dictionary:
	var check_type := str(quest.get("check_type", ""))
	if check_type == "params":
		return _check_params(quest)
	if check_type == "deform":
		return _check_deform(quest)
	return {"ok": false, "message": "Неизвестный тип проверки."}


func _check_params(quest: Dictionary) -> Dictionary:
	var target: Dictionary = quest.get("target", {})
	var tolerance: Dictionary = quest.get("tolerance", {})
	var issues: Array[String] = []

	if BrushManager.brush != str(target.get("brush", "draw")):
		issues.append("выбрана не та кисть")
	if absf(BrushManager.radius - float(target.get("radius", 30.0))) > float(
		tolerance.get("radius", 1.5)
	):
		issues.append(
			"Radius = %d px, нужно %d" % [
				roundi(BrushManager.radius),
				roundi(float(target.get("radius", 30.0))),
			]
		)
	if absf(BrushManager.strength - float(target.get("strength", 0.5))) > float(
		tolerance.get("strength", 0.06)
	):
		issues.append(
			"Strength = %.2f, нужно %.2f" % [
				BrushManager.strength,
				float(target.get("strength", 0.5)),
			]
		)
	if BrushManager.direction != str(target.get("direction", "normal")):
		issues.append("Direction должен быть «По нормали»")

	if issues.is_empty():
		return {
			"ok": true,
			"message": "Параметры Draw настроены верно.",
		}
	return {"ok": false, "message": "Проверь: " + ", ".join(issues) + "."}


func _check_deform(quest: Dictionary) -> Dictionary:
	var target: Dictionary = quest.get("target", {})
	var tolerance := float(quest.get("tolerance", 0.0))
	var center: Vector3 = target.get("zone_center", Vector3.ZERO)
	var zone_radius := float(target.get("zone_radius", 0.45))
	var stats := mesh_node.get_zone_stats(center, zone_radius)
	var avg_signed := float(stats.get("avg_signed", 0.0))
	var spread := float(stats.get("spread", 0.0))
	var metric := str(target.get("metric", ""))

	if metric == "avg_signed_min":
		var required := float(target.get("value", 0.018)) - tolerance
		var ok := avg_signed >= required
		var message := (
			"Среднее смещение %.3f, нужно ≥ %.3f. Сделай бугорок на макушке."
			% [avg_signed, required]
		)
		if ok:
			message = "Выпуклость %.3f — достаточно. Отличный штрих!" % avg_signed
		return {"ok": ok, "message": message}

	if metric == "avg_signed_max":
		var limit := float(target.get("value", -0.018)) + tolerance
		var ok := avg_signed <= limit
		var message := (
			"Среднее смещение %.3f, нужно ≤ %.3f. Продави макушку направлением -Z."
			% [avg_signed, limit]
		)
		if ok:
			message = "Вмятина %.3f — то, что нужно!" % avg_signed
		return {"ok": ok, "message": message}

	if metric == "spread_reduction":
		var required_reduction := maxf(float(target.get("value", 0.18)) - tolerance, 0.0)
		_smooth_baseline = maxf(_smooth_baseline, spread)
		if _smooth_baseline < 0.002:
			return {
				"ok": false,
				"message": "Сначала сделай заметный бугорок Draw, затем сгладь его Smooth.",
			}
		var reduction := 1.0 - spread / _smooth_baseline
		var ok := reduction >= required_reduction
		var message := (
			"Разброс %.3f → %.3f, уменьшение %.0f%%, нужно ≥ %.0f%%."
			% [ _smooth_baseline, spread, reduction * 100.0, required_reduction * 100.0 ]
		)
		if ok:
			message = "Разброс уменьшился на %.0f%% — поверхность ровнее." % (
				reduction * 100.0
			)
		return {"ok": ok, "message": message}

	return {"ok": false, "message": "Неизвестная метрика деформации."}


func _zone_spread(quest: Dictionary) -> float:
	var target: Dictionary = quest.get("target", {})
	var center: Vector3 = target.get("zone_center", Vector3.ZERO)
	var zone_radius := float(target.get("zone_radius", 0.45))
	var stats := mesh_node.get_zone_stats(center, zone_radius)
	return float(stats.get("spread", 0.0))
