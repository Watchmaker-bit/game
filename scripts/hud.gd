extends CanvasLayer
## Интерфейс тренажёра: панель кистей, карточка квеста, прогресс.
## Строится кодом, чтобы все Control-ноды и стили были в одном месте.

signal brush_selected(brush: String)
signal radius_changed(value: float)
signal strength_changed(value: float)
signal direction_selected(direction: String)
signal check_requested
signal reset_mesh_requested
signal reset_view_requested
signal reset_progress_requested

const BG_PANEL := Color(0.105, 0.112, 0.13, 0.98)
const BG_PANEL_DARK := Color(0.075, 0.081, 0.095, 1.0)
const BG_FIELD := Color(0.145, 0.155, 0.18, 1.0)
const BORDER := Color(0.21, 0.225, 0.26, 1.0)
const BORDER_SOFT := Color(0.16, 0.17, 0.2, 1.0)
const TEXT := Color(0.9, 0.91, 0.94, 1.0)
const MUTED := Color(0.56, 0.59, 0.66, 1.0)
const ACCENT := Color(0.94, 0.57, 0.22, 1.0)
const ACCENT_DIM := Color(0.55, 0.36, 0.17, 1.0)
const OK := Color(0.36, 0.8, 0.5, 1.0)
const ERR := Color(0.92, 0.4, 0.4, 1.0)
const SMOOTH_BLUE := Color(0.4, 0.67, 1.0, 1.0)

var _syncing := false
var _total := 4
var _progress_segments: Array[ColorRect] = []

var _draw_button: Button
var _smooth_button: Button
var _radius_slider: HSlider
var _radius_value: Label
var _strength_slider: HSlider
var _strength_value: Label
var _direction_box: VBoxContainer
var _direction_select: OptionButton
var _brush_hint: Label

var _eyebrow: Label
var _quest_title: Label
var _quest_description: Label
var _hint_panel: PanelContainer
var _hint_label: Label
var _check_button: Button
var _restart_button: Button
var _result_panel: PanelContainer
var _result_label: Label
var _progress_label: Label


func _ready() -> void:
	_total = QuestManager.get_quest_count()
	_build_root()


func _build_root() -> void:
	var root := Control.new()
	root.name = "HUDRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	root.add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	column.add_child(_build_top_bar())

	var content := HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 0)
	column.add_child(content)

	content.add_child(_build_left_panel())

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)

	content.add_child(_build_quest_panel())

	# Подсказка по управлению снизу, поверх 3D-вида.
	var hint := PanelContainer.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(0, -58)
	var hint_style := _box(Color(0.07, 0.075, 0.09, 0.82), BORDER_SOFT, 8, 1, 14, 7)
	hint.add_theme_stylebox_override("panel", hint_style)
	var hint_text := _label(
		"ЛКМ — лепить    СКМ — вращать    Колесо — масштаб",
		12,
		MUTED
	)
	hint.add_child(hint_text)
	root.add_child(hint)


func _build_top_bar() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_box(BG_PANEL, BORDER, 10, 1, 16, 9)
	)
	panel.custom_minimum_size = Vector2(0, 62)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var mark := ColorRect.new()
	mark.color = ACCENT
	mark.custom_minimum_size = Vector2(4, 38)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)

	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 1)
	row.add_child(titles)
	titles.add_child(_label("SCULPT TRAINER", 18, TEXT))
	titles.add_child(_label("тренажёр sculpt-кистей Blender · Godot 4.7", 11, MUTED))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var progress_box := VBoxContainer.new()
	progress_box.alignment = BoxContainer.ALIGNMENT_CENTER
	progress_box.add_theme_constant_override("separation", 4)
	row.add_child(progress_box)

	_progress_label = _label("ПРОГРЕСС · 1 / %d" % _total, 11, MUTED)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_box.add_child(_progress_label)

	var segments := HBoxContainer.new()
	segments.alignment = BoxContainer.ALIGNMENT_END
	segments.add_theme_constant_override("separation", 5)
	progress_box.add_child(segments)
	_progress_segments.clear()
	for i in _total:
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(32, 5)
		seg.color = BORDER_SOFT
		segments.add_child(seg)
		_progress_segments.append(seg)

	var reset_progress := Button.new()
	reset_progress.text = "Сброс прогресса"
	reset_progress.tooltip_text = "Начать курс с первого квеста"
	reset_progress.custom_minimum_size = Vector2(0, 30)
	reset_progress.add_theme_font_size_override("font_size", 11)
	_style_ghost_button(reset_progress, true)
	reset_progress.pressed.connect(func() -> void: reset_progress_requested.emit())
	row.add_child(reset_progress)

	return panel


func _build_left_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_box(BG_PANEL, BORDER, 10, 1, 16, 16)
	)
	panel.custom_minimum_size = Vector2(268, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 11)
	panel.add_child(col)

	col.add_child(_section_label("КИСТИ"))

	var brush_row := HBoxContainer.new()
	brush_row.add_theme_constant_override("separation", 8)
	col.add_child(brush_row)

	var group := ButtonGroup.new()
	_draw_button = _brush_button("Draw", group)
	_smooth_button = _brush_button("Smooth", group)
	brush_row.add_child(_draw_button)
	brush_row.add_child(_smooth_button)

	_brush_hint = _label("", 11, MUTED)
	_brush_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_brush_hint)

	col.add_child(_separator())

	var radius_row := _field_row("RADIUS")
	col.add_child(radius_row)
	_radius_value = radius_row.get_meta("value_label") as Label
	_radius_value.text = "20 px"
	_radius_slider = HSlider.new()
	_radius_slider.min_value = 5.0
	_radius_slider.max_value = 60.0
	_radius_slider.step = 1.0
	_radius_slider.value = 20.0
	_radius_slider.custom_minimum_size = Vector2(0, 20)
	_radius_slider.value_changed.connect(_on_radius_slider_changed)
	col.add_child(_radius_slider)

	var strength_row := _field_row("STRENGTH")
	col.add_child(strength_row)
	_strength_value = strength_row.get_meta("value_label") as Label
	_strength_value.text = "0.70"
	_strength_slider = HSlider.new()
	_strength_slider.min_value = 0.0
	_strength_slider.max_value = 1.0
	_strength_slider.step = 0.01
	_strength_slider.value = 0.7
	_strength_slider.custom_minimum_size = Vector2(0, 20)
	_strength_slider.value_changed.connect(_on_strength_slider_changed)
	col.add_child(_strength_slider)

	_direction_box = VBoxContainer.new()
	_direction_box.add_theme_constant_override("separation", 5)
	col.add_child(_direction_box)
	_direction_box.add_child(_section_label("DIRECTION"))
	_direction_select = OptionButton.new()
	_direction_select.add_item("По нормали", 0)
	_direction_select.add_item("+Z (вверх)", 1)
	_direction_select.add_item("-Z (вниз)", 2)
	_direction_select.custom_minimum_size = Vector2(0, 32)
	_direction_select.item_selected.connect(_on_direction_selected)
	_style_option_button(_direction_select)
	_direction_box.add_child(_direction_select)

	col.add_child(_separator())

	var reset_mesh := Button.new()
	reset_mesh.text = "Сбросить скульптуру"
	reset_mesh.custom_minimum_size = Vector2(0, 38)
	_style_ghost_button(reset_mesh, false)
	reset_mesh.pressed.connect(func() -> void: reset_mesh_requested.emit())
	col.add_child(reset_mesh)

	var reset_view := Button.new()
	reset_view.text = "Сбросить вид камеры"
	reset_view.custom_minimum_size = Vector2(0, 34)
	_style_ghost_button(reset_view, true)
	reset_view.pressed.connect(func() -> void: reset_view_requested.emit())
	col.add_child(reset_view)

	return panel


func _build_quest_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_box(BG_PANEL, BORDER, 10, 1, 18, 18)
	)
	panel.custom_minimum_size = Vector2(356, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	_eyebrow = _label("КВЕСТ 1 ИЗ %d" % _total, 11, ACCENT)
	col.add_child(_eyebrow)

	_quest_title = _label("", 25, TEXT)
	_quest_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_quest_title)

	_quest_description = _label("", 13, Color(0.75, 0.77, 0.82, 1.0))
	_quest_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_description.add_theme_constant_override("line_spacing", 4)
	col.add_child(_quest_description)

	_hint_panel = PanelContainer.new()
	_hint_panel.add_theme_stylebox_override(
		"panel",
		_hint_style()
	)
	col.add_child(_hint_panel)
	var hint_col := VBoxContainer.new()
	hint_col.add_theme_constant_override("separation", 3)
	_hint_panel.add_child(hint_col)
	hint_col.add_child(_label("ПОДСКАЗКА", 10, ACCENT))
	_hint_label = _label("", 12, MUTED)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_col.add_child(_hint_label)

	_check_button = Button.new()
	_check_button.text = "Проверить"
	_check_button.custom_minimum_size = Vector2(0, 44)
	_check_button.add_theme_font_size_override("font_size", 15)
	_style_primary_button(_check_button)
	_check_button.pressed.connect(func() -> void: check_requested.emit())
	col.add_child(_check_button)

	_result_panel = PanelContainer.new()
	_result_panel.visible = false
	_result_panel.add_theme_stylebox_override(
		"panel",
		_box(Color(0.14, 0.25, 0.17, 1.0), OK, 8, 1, 12, 10)
	)
	col.add_child(_result_panel)
	_result_label = _label("", 12, OK)
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_panel.add_child(_result_label)

	_restart_button = Button.new()
	_restart_button.text = "Начать заново"
	_restart_button.custom_minimum_size = Vector2(0, 42)
	_restart_button.visible = false
	_style_primary_button(_restart_button)
	_restart_button.pressed.connect(func() -> void: reset_progress_requested.emit())
	col.add_child(_restart_button)

	return panel


func _separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 1)
	sep.add_theme_stylebox_override("separator", _box(BORDER_SOFT, Color.TRANSPARENT, 0, 0, 0, 0))
	return sep


func _section_label(text: String) -> Label:
	var lbl := _label(text, 11, MUTED)
	return lbl


func _field_row(title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var title_label := _label(title, 11, MUTED)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)
	var value_label := _label("", 12, TEXT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(42, 0)
	row.add_child(value_label)
	row.set_meta("value_label", value_label)
	return row


func _label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _brush_button(text: String, group: ButtonGroup) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_group = group
	btn.custom_minimum_size = Vector2(0, 42)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_stylebox_override(
		"normal",
		_box(BG_FIELD, BORDER, 7, 1, 8, 6)
	)
	btn.add_theme_stylebox_override(
		"hover",
		_box(Color(0.185, 0.195, 0.225, 1.0), Color(0.3, 0.32, 0.37, 1.0), 7, 1, 8, 6)
	)
	btn.add_theme_stylebox_override(
		"pressed",
		_box(ACCENT, Color(1.0, 0.68, 0.34, 1.0), 7, 1, 8, 6)
	)
	btn.add_theme_stylebox_override(
		"hover_pressed",
		_box(Color(1.0, 0.64, 0.3, 1.0), Color(1.0, 0.76, 0.48, 1.0), 7, 1, 8, 6)
	)
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.09, 0.09, 0.1, 1.0))
	btn.add_theme_color_override("font_hover_pressed_color", Color(0.09, 0.09, 0.1, 1.0))
	btn.toggled.connect(
		func(pressed: bool) -> void:
			if _syncing or not pressed:
				return
			brush_selected.emit("draw" if btn == _draw_button else "smooth")
	)
	return btn


func _style_primary_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _box(ACCENT, Color(1.0, 0.7, 0.38, 1.0), 8, 1, 12, 8))
	btn.add_theme_stylebox_override("hover", _box(Color(1.0, 0.64, 0.3, 1.0), Color(1.0, 0.78, 0.5, 1.0), 8, 1, 12, 8))
	btn.add_theme_stylebox_override("pressed", _box(Color(0.78, 0.44, 0.14, 1.0), ACCENT, 8, 1, 12, 8))
	btn.add_theme_stylebox_override("disabled", _box(Color(0.25, 0.22, 0.18, 1.0), BORDER, 8, 1, 12, 8))
	btn.add_theme_color_override("font_color", Color(0.08, 0.08, 0.09, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.05, 0.05, 0.06, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.08, 0.08, 0.09, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.48, 0.45, 1.0))


func _style_ghost_button(btn: Button, compact: bool) -> void:
	var pad_v := 5 if compact else 7
	btn.add_theme_stylebox_override("normal", _box(BG_PANEL_DARK, BORDER_SOFT, 7, 1, 10, pad_v))
	btn.add_theme_stylebox_override("hover", _box(BG_FIELD, BORDER, 7, 1, 10, pad_v))
	btn.add_theme_stylebox_override("pressed", _box(Color(0.2, 0.21, 0.24, 1.0), BORDER, 7, 1, 10, pad_v))
	btn.add_theme_color_override("font_color", Color(0.75, 0.77, 0.82, 1.0))
	btn.add_theme_color_override("font_hover_color", TEXT)


func _style_option_button(btn: OptionButton) -> void:
	btn.add_theme_stylebox_override("normal", _box(BG_FIELD, BORDER, 7, 1, 10, 6))
	btn.add_theme_stylebox_override("hover", _box(Color(0.185, 0.195, 0.225, 1.0), Color(0.3, 0.32, 0.37, 1.0), 7, 1, 10, 6))
	btn.add_theme_stylebox_override("pressed", _box(BG_FIELD, ACCENT_DIM, 7, 1, 10, 6))
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))


func _box(
	bg: Color,
	border: Color,
	radius: int,
	border_width: int,
	pad_h: int,
	pad_v: int
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = float(pad_h)
	sb.content_margin_right = float(pad_h)
	sb.content_margin_top = float(pad_v)
	sb.content_margin_bottom = float(pad_v)
	return sb


func _hint_style() -> StyleBoxFlat:
	var sb := _box(Color(0.075, 0.082, 0.1, 1.0), ACCENT_DIM, 7, 0, 11, 9)
	sb.border_width_left = 3
	return sb


func _on_radius_slider_changed(value: float) -> void:
	_radius_value.text = "%d px" % roundi(value)
	if not _syncing:
		radius_changed.emit(value)


func _on_strength_slider_changed(value: float) -> void:
	_strength_value.text = "%.2f" % value
	if not _syncing:
		strength_changed.emit(value)


func _on_direction_selected(index: int) -> void:
	if _syncing:
		return
	var values := ["normal", "plus_z", "minus_z"]
	direction_selected.emit(values[index])


## Синхронизация панели с BrushManager без повторной эмиссии сигналов.
func set_brush_state(brush: String, radius: float, strength: float, direction: String) -> void:
	_syncing = true
	_draw_button.set_pressed_no_signal(brush == "draw")
	_smooth_button.set_pressed_no_signal(brush == "smooth")
	_radius_slider.value = radius
	_strength_slider.value = strength
	_radius_value.text = "%d px" % roundi(radius)
	_strength_value.text = "%.2f" % strength
	_direction_box.visible = brush == "draw"
	var dir_index := 0
	if direction == "plus_z":
		dir_index = 1
	elif direction == "minus_z":
		dir_index = 2
	_direction_select.select(dir_index)
	_brush_hint.text = (
		"Рисует объём по нормалям или выбранной оси."
		if brush == "draw"
		else "Выравнивает локальные перепады высот."
	)
	_syncing = false


func show_quest(
	quest: Dictionary,
	index: int,
	completed_count: int
) -> void:
	_syncing = true
	_result_panel.visible = false
	_check_button.visible = true
	_check_button.disabled = false
	_restart_button.visible = false
	_hint_panel.visible = true
	_eyebrow.text = "КВЕСТ %d ИЗ %d" % [index + 1, _total]
	_eyebrow.add_theme_color_override("font_color", ACCENT)
	_quest_title.text = str(quest.get("title", ""))
	_quest_description.text = str(quest.get("description", ""))
	_hint_label.text = str(quest.get("hint", ""))
	_update_progress(index, completed_count)
	_syncing = false


func show_final(completed_count: int) -> void:
	_result_panel.visible = false
	_check_button.visible = false
	_restart_button.visible = true
	_hint_panel.visible = false
	_eyebrow.text = "КУРС ПРОЙДЕН"
	_eyebrow.add_theme_color_override("font_color", OK)
	_quest_title.text = "Отличная работа!"
	_quest_description.text = (
		"Все %d квеста пройдены. Ты настроил кисть, сделал выпуклость, " % _total
		+ "сгладил её и освоил направление -Z. Теперь можно продолжать лепить "
		+ "свободно."
	)
	_update_progress(_total, completed_count)


func show_result(success: bool, message: String) -> void:
	_result_panel.visible = true
	var color := OK if success else ERR
	var bg := Color(0.13, 0.25, 0.17, 1.0) if success else Color(0.28, 0.12, 0.13, 1.0)
	_result_panel.add_theme_stylebox_override("panel", _box(bg, color, 8, 1, 12, 10))
	_result_label.add_theme_color_override("font_color", color)
	_result_label.text = ("Готово! " if success else "Пока не то. ") + message


func set_check_enabled(enabled: bool) -> void:
	_check_button.disabled = not enabled


func clear_result() -> void:
	_result_panel.visible = false


func _update_progress(current_index: int, completed_count: int) -> void:
	var shown := clampi(current_index, 0, _total)
	_progress_label.text = "ПРОГРЕСС · %d / %d" % [completed_count, _total]
	for i in _progress_segments.size():
		if i < completed_count:
			_progress_segments[i].color = ACCENT
		elif i == shown:
			_progress_segments[i].color = Color(0.46, 0.31, 0.17, 1.0)
		else:
			_progress_segments[i].color = BORDER_SOFT
