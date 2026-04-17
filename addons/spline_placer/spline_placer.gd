@tool
extends Path3D
class_name SplinePlacer

## --- Entrada para múltiplas cenas ---

class SceneEntry:
	var scene: PackedScene
	var weight: float
	var scale_override: Vector3
	var use_scale_override: bool

	func _init(s: PackedScene = null, w: float = 1.0) -> void:
		scene = s
		weight = w
		scale_override = Vector3.ONE
		use_scale_override = false


@export var scenes: Array[PackedScene] = []:
	set(value):
		scenes = value
		_sync_weights()
		_rebuild()

## Peso de cada cena (mesma ordem de 'scenes'). Maior = mais frequente.
@export var scene_weights: Array[float] = []:
	set(value):
		scene_weights = value
		_rebuild()

## Escala individual por cena (mesma ordem de 'scenes'). Vector3.ZERO = usar instance_scale global.
@export var scene_scale_overrides: Array[Vector3] = []:
	set(value):
		scene_scale_overrides = value
		_rebuild()

## Modo de seleção das cenas
@export_enum("Weighted Random", "Sequential", "Random Uniform") var selection_mode: int = 0:
	set(value):
		selection_mode = value
		_rebuild()

## Semente para aleatoriedade (0 = não fixada)
@export var random_seed: int = 0:
	set(value):
		random_seed = value
		_rebuild()

## --- Parâmetros gerais ---

@export_range(0.1, 100.0, 0.01) var spacing: float = 2.0:
	set(value):
		spacing = value
		_rebuild()

@export var instance_scale: Vector3 = Vector3.ONE:
	set(value):
		instance_scale = value
		_rebuild()

@export var align_to_spline: bool = true:
	set(value):
		align_to_spline = value
		_rebuild()

@export_enum("X", "-X", "Y", "-Y", "Z", "-Z") var forward_axis: int = 4:
	set(value):
		forward_axis = value
		_rebuild()

@export var position_offset: Vector3 = Vector3.ZERO:
	set(value):
		position_offset = value
		_rebuild()

@export var rotation_offset: Vector3 = Vector3.ZERO:
	set(value):
		rotation_offset = value
		_rebuild()

@export var place_at_end: bool = true:
	set(value):
		place_at_end = value
		_rebuild()

@export var instances_parent: NodePath = NodePath(""):
	set(value):
		instances_parent = value
		_rebuild()

## --- Exclusão ---

## Áreas de exclusão: instâncias não serão colocadas dentro dessas áreas
@export var exclusion_areas: Array[Area3D] = []:
	set(value):
		exclusion_areas = value
		_rebuild()

## Margem extra aplicada ao redor de cada shape de exclusão
@export var exclusion_margin: float = 0.0:
	set(value):
		exclusion_margin = value
		_rebuild()

## --- Rebuild manual ---

@export_tool_button("🔄 Rebuild") var rebuild_button := rebuild

const INSTANCE_GROUP := "_spline_placer_instance"

var _instances: Array[Node3D] = []
var _curve_changed_connected := false
var _rng := RandomNumberGenerator.new()
var _seq_index := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		_connect_curve_signal()
	_rebuild()


func _connect_curve_signal() -> void:
	if curve and not _curve_changed_connected:
		if not curve.changed.is_connected(_on_curve_changed):
			curve.changed.connect(_on_curve_changed)
			_curve_changed_connected = true


func _on_curve_changed() -> void:
	_rebuild()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if scenes.is_empty():
		warnings.append("Nenhuma cena em 'scenes'. Adicione ao menos uma PackedScene.")
	else:
		for i in scenes.size():
			if scenes[i] == null:
				warnings.append("scenes[%d] está vazio." % i)
	if curve == null or curve.point_count < 2:
		warnings.append("O Path3D precisa de pelo menos 2 pontos na curva.")
	if spacing <= 0.0:
		warnings.append("'spacing' deve ser maior que zero.")
	return warnings


func _sync_weights() -> void:
	while scene_weights.size() < scenes.size():
		scene_weights.append(1.0)
	while scene_weights.size() > scenes.size():
		scene_weights.pop_back()

	while scene_scale_overrides.size() < scenes.size():
		scene_scale_overrides.append(Vector3.ZERO)
	while scene_scale_overrides.size() > scenes.size():
		scene_scale_overrides.pop_back()


func _rebuild() -> void:
	_clear_instances()

	if not is_inside_tree():
		return

	if scenes.is_empty():
		update_configuration_warnings()
		return

	var valid := false
	for s in scenes:
		if s != null:
			valid = true
			break
	if not valid:
		update_configuration_warnings()
		return

	if curve == null or curve.point_count < 2:
		update_configuration_warnings()
		return

	_connect_curve_signal()
	_sync_weights()

	if random_seed != 0:
		_rng.seed = random_seed
	else:
		_rng.randomize()

	_seq_index = 0

	var parent := _get_instances_parent()
	if parent == null:
		return

	var total_length := curve.get_baked_length()
	if total_length <= 0.0:
		return

	var offset := 0.0
	while offset <= total_length:
		_place_instance_at_offset(offset, total_length, parent)
		offset += spacing

	if place_at_end:
		var last_placed := offset - spacing
		if abs(last_placed - total_length) > 0.01:
			_place_instance_at_offset(total_length, total_length, parent)

	update_configuration_warnings()


func _pick_scene_index() -> int:
	var valid_indices: Array[int] = []
	for i in scenes.size():
		if scenes[i] != null:
			valid_indices.append(i)

	if valid_indices.is_empty():
		return -1

	match selection_mode:
		0:
			var total_weight := 0.0
			for i in valid_indices:
				var w := scene_weights[i] if i < scene_weights.size() else 1.0
				total_weight += maxf(w, 0.0)

			if total_weight <= 0.0:
				return valid_indices[_rng.randi() % valid_indices.size()]

			var roll := _rng.randf() * total_weight
			var acc := 0.0
			for i in valid_indices:
				var w := scene_weights[i] if i < scene_weights.size() else 1.0
				acc += maxf(w, 0.0)
				if roll <= acc:
					return i
			return valid_indices[-1]

		1:
			var idx := valid_indices[_seq_index % valid_indices.size()]
			_seq_index += 1
			return idx

		2:
			return valid_indices[_rng.randi() % valid_indices.size()]

	return valid_indices[0]


func _is_position_excluded(world_pos: Vector3) -> bool:
	for area in exclusion_areas:
		if not is_instance_valid(area):
			continue
		for child in area.get_children():
			if not child is CollisionShape3D:
				continue
			var cs := child as CollisionShape3D
			if cs.disabled or cs.shape == null:
				continue

			var local_pos: Vector3 = cs.global_transform.affine_inverse() * world_pos
			var shape := cs.shape

			if shape is BoxShape3D:
				var half := (shape as BoxShape3D).size * 0.5 + Vector3.ONE * exclusion_margin
				if (abs(local_pos.x) <= half.x and
					abs(local_pos.y) <= half.y and
					abs(local_pos.z) <= half.z):
					return true

			elif shape is SphereShape3D:
				var radius := (shape as SphereShape3D).radius + exclusion_margin
				if local_pos.length_squared() <= radius * radius:
					return true

			elif shape is CylinderShape3D:
				var cyl := shape as CylinderShape3D
				var half_h := cyl.height * 0.5 + exclusion_margin
				var r := cyl.radius + exclusion_margin
				if abs(local_pos.y) <= half_h:
					var flat := Vector2(local_pos.x, local_pos.z)
					if flat.length_squared() <= r * r:
						return true

	return false


func _place_instance_at_offset(offset: float, total_length: float, parent: Node3D) -> void:
	var baked_pos := curve.sample_baked(offset)
	var world_pos: Vector3 = global_transform * (baked_pos + position_offset)

	if _is_position_excluded(world_pos):
		return

	var scene_idx := _pick_scene_index()
	if scene_idx < 0:
		return

	var packed := scenes[scene_idx]
	var instance := packed.instantiate() as Node3D
	if instance == null:
		push_error("SplinePlacer: scenes[%d] não é um Node3D." % scene_idx)
		return

	instance.add_to_group(INSTANCE_GROUP)

	var tangent := _get_tangent(offset, total_length)

	instance.position = baked_pos + position_offset

	if align_to_spline and tangent.length_squared() > 0.001:
		instance.basis = _basis_from_tangent(tangent)

	if rotation_offset != Vector3.ZERO:
		instance.rotate_object_local(Vector3.RIGHT,   deg_to_rad(rotation_offset.x))
		instance.rotate_object_local(Vector3.UP,      deg_to_rad(rotation_offset.y))
		instance.rotate_object_local(Vector3.FORWARD, deg_to_rad(rotation_offset.z))

	var override := scene_scale_overrides[scene_idx] if scene_idx < scene_scale_overrides.size() else Vector3.ZERO
	instance.scale = override if override != Vector3.ZERO else instance_scale

	parent.add_child(instance)

	if Engine.is_editor_hint():
		instance.owner = get_tree().edited_scene_root

	_instances.append(instance)


func _get_tangent(offset: float, total_length: float) -> Vector3:
	var delta := 0.05
	var p1 := curve.sample_baked(clampf(offset - delta, 0.0, total_length))
	var p2 := curve.sample_baked(clampf(offset + delta, 0.0, total_length))
	var tangent := p2 - p1
	return tangent.normalized() if tangent.length_squared() > 0.0001 else Vector3.FORWARD


func _basis_from_tangent(tangent: Vector3) -> Basis:
	var up := Vector3.UP
	if abs(tangent.dot(up)) > 0.99:
		up = Vector3.RIGHT

	var right := tangent.cross(up).normalized()
	up = right.cross(tangent).normalized()

	match forward_axis:
		0: return Basis(tangent,  up,      -right)
		1: return Basis(-tangent, up,       right)
		2: return Basis(right,    tangent, -up)
		3: return Basis(right,   -tangent,  up)
		4: return Basis(right,    up,      -tangent)
		5: return Basis(-right,   up,       tangent)
	return Basis(right, up, -tangent)


func _get_instances_parent() -> Node3D:
	if instances_parent != NodePath(""):
		var node := get_node_or_null(instances_parent)
		if node is Node3D:
			return node as Node3D
		push_warning("SplinePlacer: 'instances_parent' não encontrado, usando este nó.")
	return self


func _clear_instances() -> void:
	for instance in _instances:
		if is_instance_valid(instance):
			instance.queue_free()
	_instances.clear()


## API pública

func rebuild() -> void:
	_rebuild()

func get_instances() -> Array[Node3D]:
	return _instances.duplicate()

func get_instances_of_scene(scene: PackedScene) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var idx := scenes.find(scene)
	if idx < 0:
		return result
	for inst in _instances:
		if is_instance_valid(inst) and inst.get_meta("_spline_scene_idx", -1) == idx:
			result.append(inst)
	return result

func get_nearest_instance(global_pos: Vector3) -> Node3D:
	var nearest: Node3D = null
	var min_dist := INF
	for inst in _instances:
		if is_instance_valid(inst):
			var d := inst.global_position.distance_squared_to(global_pos)
			if d < min_dist:
				min_dist = d
				nearest = inst
	return nearest
