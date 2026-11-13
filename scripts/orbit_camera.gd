class_name OrbitCamera
extends Node3D
## Орбитальная камера вокруг начала координат.
## СКМ — вращение, колесо — плавный зум. ЛКМ камера не трогает: она нужна кисти.

@export var focus_point := Vector3.ZERO
@export var min_distance := 2.1
@export var max_distance := 6.5
@export var orbit_sensitivity := 0.009

var _yaw := 0.55
var _pitch := 0.22
var _distance := 3.6
var _target_yaw := 0.55
var _target_pitch := 0.22
var _target_distance := 3.6

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	_apply_transform()


func orbit_relative(relative: Vector2) -> void:
	_target_yaw -= relative.x * orbit_sensitivity
	_target_pitch = clampf(
		_target_pitch - relative.y * orbit_sensitivity,
		-0.45,
		1.25
	)


func zoom_steps(steps: float) -> void:
	_target_distance = clampf(
		_target_distance - steps * 0.32,
		min_distance,
		max_distance
	)


func reset_view() -> void:
	_target_yaw = 0.55
	_target_pitch = 0.22
	_target_distance = 3.6


func _process(delta: float) -> void:
	var t := 1.0 - exp(-12.0 * delta)
	_yaw = lerpf(_yaw, _target_yaw, t)
	_pitch = lerpf(_pitch, _target_pitch, t)
	_distance = lerpf(_distance, _target_distance, t)
	_apply_transform()


func _apply_transform() -> void:
	if camera == null:
		return
	global_position = focus_point
	var offset := Vector3(
		sin(_yaw) * cos(_pitch) * _distance,
		sin(_pitch) * _distance,
		cos(_yaw) * cos(_pitch) * _distance
	)
	camera.position = offset
	camera.look_at(focus_point, Vector3.UP)
