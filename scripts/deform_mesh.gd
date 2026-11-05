class_name DeformMesh
extends MeshInstance3D
## Скульптор для одного меша.
##
## Ключевая идея: исходная сфера — это SphereMesh. При старте мы забираем её
## массивы через surface_get_arrays(0), запоминаем исходные позиции и создаём
## собственный ArrayMesh. Дальше при каждой деформации меняем ARRAY_VERTEX
## (и пересчитываем ARRAY_NORMAL), затем пересобираем поверхность:
##
##     _mesh.clear_surfaces()
##     _mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays, [], {},
##             Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
##
## В Godot 4.7 у ArrayMesh нет метода surface_set_arrays(), поэтому это
## рабочий и предсказуемый способ обновить геометрию. Для меша на ~900
## вершин полная пересборка поверхности дешевле, чем борьба с частичным
## обновлением буферов, и заодно обновляет AABB для отсечения.
## В 4.7 есть surface_update_vertex_region(), но она обновляет только
## позиции; для корректного освещения нам всё равно нужны новые нормали,
## поэтому здесь пересобирается вся поверхность.
##
## Позиции вершин храним отдельно от исходных: так можно ограничить
## суммарное смещение и мгновенно вернуть сферу в исходное состояние.

const BRUSH_DRAW := "draw"
const BRUSH_SMOOTH := "smooth"
const DIR_PLUS_Z := "plus_z"
const DIR_MINUS_Z := "minus_z"

const MAX_OFFSET := 0.4          # предел суммарного смещения вершины
const DRAW_STEP := 0.014         # шаг Draw за один вызов
const SMOOTH_STEP := 0.45          # коэффициент лапласиана за один вызов
const GROUP_EPS := 0.0005        # склейка дублей вершин на UV-шве и полюсах
const NEIGHBOR_CUTOFF := 0.29    # радиус поиска соседей для сглаживания

var _base_vertices := PackedVector3Array()
var _base_normals := PackedVector3Array()
var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _indices := PackedInt32Array()
var _arrays: Array = []
var _mesh: ArrayMesh

# Вершины, совпадающие по позиции (шов UV, полюса), объединены в группы,
# чтобы у них были одинаковые нормали и одинаковая деформация.
var _group_of_vertex := PackedInt32Array()
var _group_vertices: Array[PackedInt32Array] = []
var _group_rep := PackedInt32Array()
var _group_neighbors: Array[PackedInt32Array] = []
var _group_normals := PackedVector3Array()
var _base_group_normals := PackedVector3Array()


func _ready() -> void:
	_initialize_from_mesh()


func _initialize_from_mesh() -> void:
	if mesh == null or mesh.get_surface_count() == 0:
		push_error("DeformMesh: нужен меш с поверхностью.")
		return

	var source_arrays := mesh.surface_get_arrays(0)
	if source_arrays.is_empty() or source_arrays[Mesh.ARRAY_VERTEX] == null:
		push_error("DeformMesh: surface_get_arrays не вернул вершины.")
		return

	var src_vertices: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
	_base_vertices = src_vertices.duplicate()
	_vertices = _base_vertices.duplicate()

	var src_normals: PackedVector3Array = source_arrays[Mesh.ARRAY_NORMAL]
	_base_normals = src_normals.duplicate()
	_normals = _base_normals.duplicate()

	var src_index: Variant = source_arrays[Mesh.ARRAY_INDEX]
	if typeof(src_index) == TYPE_PACKED_INT32_ARRAY:
		var idx: PackedInt32Array = src_index
		_indices = idx.duplicate()
	else:
		_indices.resize(_vertices.size())
		for i in _vertices.size():
			_indices[i] = i

	_arrays = source_arrays.duplicate(true)
	_build_connectivity()
	_base_group_normals = _compute_group_normals()
	_group_normals = _base_group_normals.duplicate()

	if material_override == null:
		material_override = _make_clay_material()

	_mesh = ArrayMesh.new()
	_arrays[Mesh.ARRAY_VERTEX] = _vertices
	_arrays[Mesh.ARRAY_NORMAL] = _normals
	_mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES, _arrays, [], {},
		Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE
	)
	mesh = _mesh


func _make_clay_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.63, 0.48, 0.38, 1.0)
	mat.roughness = 0.72
	mat.metallic = 0.03
	mat.rim_enabled = true
	mat.rim = 0.25
	mat.rim_tint = 0.4
	return mat


## Группирует вершины по совпадающей локальной позиции.
func _build_connectivity() -> void:
	var count := _base_vertices.size()
	_group_of_vertex.resize(count)
	var key_to_group := {}
	var group_count := 0

	for i in count:
		var p := _base_vertices[i]
		var key := Vector3i(
			roundi(p.x / GROUP_EPS),
			roundi(p.y / GROUP_EPS),
			roundi(p.z / GROUP_EPS)
		)
		if key_to_group.has(key):
			_group_of_vertex[i] = key_to_group[key]
		else:
			key_to_group[key] = group_count
			_group_of_vertex[i] = group_count
			group_count += 1

	_group_vertices.clear()
	_group_vertices.resize(group_count)
	for g in group_count:
		_group_vertices[g] = PackedInt32Array()

	for i in count:
		var g := _group_of_vertex[i]
		var verts := _group_vertices[g]
		verts.append(i)
		_group_vertices[g] = verts

	_group_rep.resize(group_count)
	for g in group_count:
		_group_rep[g] = _group_vertices[g][0]

	_group_neighbors.clear()
	_group_neighbors.resize(group_count)
	var cutoff_sq := NEIGHBOR_CUTOFF * NEIGHBOR_CUTOFF
	for g in group_count:
		var near := PackedInt32Array()
		var p := _base_vertices[_group_rep[g]]
		for h in group_count:
			if h == g:
				continue
			if p.distance_squared_to(_base_vertices[_group_rep[h]]) <= cutoff_sq:
				near.append(h)
		_group_neighbors[g] = near

	# Страховка для очень разреженного меша: у каждой группы должен быть
	# хотя бы один сосед, иначе Smooth не сможет двигать вершину.
	for g in group_count:
		if _group_neighbors[g].is_empty():
			var best := -1
			var best_d := INF
			for h in group_count:
				if h == g:
					continue
				var d := _base_vertices[_group_rep[g]].distance_squared_to(
					_base_vertices[_group_rep[h]]
				)
				if d < best_d:
					best_d = d
					best = h
			if best >= 0:
				_group_neighbors[g] = PackedInt32Array([best])


## Считает сглаженные нормали по группам вершин.
func _compute_group_normals() -> PackedVector3Array:
	var groups := _group_vertices.size()
	var acc := PackedVector3Array()
	acc.resize(groups)
	acc.fill(Vector3.ZERO)

	for i in range(0, _indices.size() - 2, 3):
		var ia := _indices[i]
		var ib := _indices[i + 1]
		var ic := _indices[i + 2]
		var pa := _vertices[ia]
		var pb := _vertices[ib]
		var pc := _vertices[ic]
		var face := (pb - pa).cross(pc - pa)
		if face.length_squared() < 1e-14:
			continue
		acc[_group_of_vertex[ia]] += face
		acc[_group_of_vertex[ib]] += face
		acc[_group_of_vertex[ic]] += face

	var result := PackedVector3Array()
	result.resize(groups)
	for g in groups:
		var n := acc[g]
		if n.length_squared() > 1e-14:
			n = n.normalized()
			# Godot использует часовую намотку, но у SphereMesh нормали
			# уже заданы наружу. Сверяемся с исходной нормалью, чтобы
			# Draw всегда вытягивал сферу, а не вдавливал её.
			if n.dot(_base_normals[_group_rep[g]]) < 0.0:
				n = -n
			result[g] = n
		else:
			result[g] = _base_normals[_group_rep[g]]
	return result


func _sync_normals_from_groups() -> void:
	for i in _vertices.size():
		_normals[i] = _group_normals[_group_of_vertex[i]]


func _rebuild_mesh() -> void:
	if _mesh == null:
		return
	_arrays[Mesh.ARRAY_VERTEX] = _vertices
	_arrays[Mesh.ARRAY_NORMAL] = _normals
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES, _arrays, [], {},
		Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE
	)


func _set_group_position(group: int, position: Vector3) -> void:
	var verts := _group_vertices[group]
	for i in verts:
		_vertices[i] = position


## Применяет один шаг кисти. hit_point — в локальных координатах меша.
## direction_mode используется только для Draw/Inflate.
func apply_brush(
	hit_point: Vector3,
	radius: float,
	strength: float,
	brush_type: String,
	direction_mode: String = "normal"
) -> bool:
	if radius <= 0.0001 or strength <= 0.0001:
		return false

	var radius_sq := radius * radius
	var changed := false
	var group_count := _group_vertices.size()

	for g in group_count:
		var rep := _group_rep[g]
		var p := _vertices[rep]
		var dist_sq := p.distance_squared_to(hit_point)
		if dist_sq > radius_sq:
			continue

		var dist := sqrt(dist_sq)
		var falloff := pow(1.0 - dist / radius, 2.0)
		var new_p := p

		if brush_type == BRUSH_DRAW:
			var dir := _group_normals[g]
			if direction_mode == DIR_PLUS_Z:
				# В Blender вертикаль — Z, в Godot — Y. Для интуитивного
				# поведения кнопки «+Z» двигаем вверх по Y.
				dir = Vector3.UP
			elif direction_mode == DIR_MINUS_Z:
				dir = Vector3.DOWN
			new_p = p + dir * (strength * DRAW_STEP * falloff)
		elif brush_type == BRUSH_SMOOTH:
			var neighbors := _group_neighbors[g]
			if neighbors.is_empty():
				continue
			var avg := Vector3.ZERO
			for h in neighbors:
				avg += _vertices[_group_rep[h]]
			avg /= float(neighbors.size())
			new_p = p + (avg - p) * (strength * SMOOTH_STEP * falloff)
		else:
			continue

		var base := _base_vertices[rep]
		var offset := new_p - base
		var offset_len := offset.length()
		if offset_len > MAX_OFFSET:
			new_p = base + offset / offset_len * MAX_OFFSET

		if new_p.distance_squared_to(p) > 1e-14:
			_set_group_position(g, new_p)
			changed = true

	if changed:
		_group_normals = _compute_group_normals()
		_sync_normals_from_groups()
		_rebuild_mesh()
	return changed


func reset_shape() -> void:
	_vertices = _base_vertices.duplicate()
	_normals = _base_normals.duplicate()
	_group_normals = _base_group_normals.duplicate()
	_rebuild_mesh()


func is_pristine() -> bool:
	for i in _vertices.size():
		if not _vertices[i].is_equal_approx(_base_vertices[i]):
			return false
	return true


## Статистика зоны для проверки квестов.
## spread — среднеквадратичное отклонение подписанного смещения вдоль
## исходной нормали. Чем ровнее поверхность, тем меньше spread.
func get_zone_stats(center: Vector3, radius: float) -> Dictionary:
	var radius_sq := radius * radius
	var count := 0
	var sum_signed := 0.0
	var sum_sq := 0.0
	var sum_len := 0.0

	for g in _group_vertices.size():
		var rep := _group_rep[g]
		if _base_vertices[rep].distance_squared_to(center) > radius_sq:
			continue
		var delta := _vertices[rep] - _base_vertices[rep]
		var signed := delta.dot(_base_normals[rep])
		count += 1
		sum_signed += signed
		sum_sq += signed * signed
		sum_len += delta.length()

	if count == 0:
		return {
			"count": 0,
			"avg_signed": 0.0,
			"spread": 0.0,
			"avg_length": 0.0,
		}

	var mean := sum_signed / float(count)
	var variance := maxf(sum_sq / float(count) - mean * mean, 0.0)
	return {
		"count": count,
		"avg_signed": mean,
		"spread": sqrt(variance),
		"avg_length": sum_len / float(count),
	}
