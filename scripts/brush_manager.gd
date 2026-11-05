extends Node
## Единое хранилище состояния кистей (autoload BrushManager).
##
## UI и скульптор читают значения только отсюда, поэтому переключение кистей,
## радиус и сила всегда синхронизированы между панелью и 3D-видом.

signal changed

const DRAW := "draw"
const SMOOTH := "smooth"

const DIR_NORMAL := "normal"
const DIR_PLUS_Z := "plus_z"
const DIR_MINUS_Z := "minus_z"

# Стартовые значения намеренно не совпадают с первым квестом:
# так учащийся действительно настраивает кисть, а не просто жмёт «Проверить».
var brush: String = DRAW
var radius: float = 20.0
var strength: float = 0.7
var direction: String = DIR_NORMAL


func set_brush(value: String) -> void:
	if value != DRAW and value != SMOOTH:
		return
	if brush == value:
		return
	brush = value
	changed.emit()


func set_radius(value: float) -> void:
	var snapped := clampf(snappedf(value, 1.0), 5.0, 60.0)
	if is_equal_approx(radius, snapped):
		return
	radius = snapped
	changed.emit()


func set_strength(value: float) -> void:
	var snapped := clampf(snappedf(value, 0.01), 0.0, 1.0)
	if is_equal_approx(strength, snapped):
		return
	strength = snapped
	changed.emit()


func set_direction(value: String) -> void:
	if value != DIR_NORMAL and value != DIR_PLUS_Z and value != DIR_MINUS_Z:
		return
	if direction == value:
		return
	direction = value
	changed.emit()


## Радиус в единицах сцены. В интерфейсе показываем «пиксели» (5..60),
## а сфера имеет радиус 1.0, поэтому 30 -> 0.30.
func radius_world() -> float:
	return radius / 100.0


func brush_title() -> String:
	return "Draw" if brush == DRAW else "Smooth"


func direction_title() -> String:
	match direction:
		DIR_PLUS_Z:
			return "+Z (вверх)"
		DIR_MINUS_Z:
			return "-Z (вниз)"
		_:
			return "По нормали"
