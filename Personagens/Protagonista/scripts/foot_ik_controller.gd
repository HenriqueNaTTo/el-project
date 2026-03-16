@tool
extends Node3D
# Anexe este script ao nó "FootIKController"

# Chave mestra para testar no editor sem quebrar a cena salva
@export var run_in_editor: bool = false:
	set(value):
		run_in_editor = value
		if Engine.is_editor_hint():
			_toggle_ik(value)

# Referências Principais
@export var skeleton: Skeleton3D
@export var ik_left: SkeletonIK3D 
@export var ik_right: SkeletonIK3D
@export var ray_left: RayCast3D
@export var ray_right: RayCast3D
@export var target_left: Marker3D
@export var target_right: Marker3D

# Referências dos Joelhos (Poles/Magnets)
@export var pole_left: Marker3D
@export var pole_right: Marker3D

# Configurações de Posição
@export var foot_offset: float = 0.1
@export var max_pelvis_dip: float = 0.5 
@export var ik_smoothness: float = 15.0
@export var pelvis_smoothness: float = 10.0

var default_skeleton_y: float = 0.0
var _is_ready_run: bool = false

func _ready() -> void:
	if skeleton:
		default_skeleton_y = skeleton.position.y
		_is_ready_run = true

	# Liga o IK automaticamente quando o jogo rodar de verdade
	if not Engine.is_editor_hint():
		_toggle_ik(true)

func _toggle_ik(active: bool) -> void:
	if ik_left:
		if active: ik_left.start()
		else: ik_left.stop()
	if ik_right:
		if active: ik_right.start()
		else: ik_right.stop()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() and not run_in_editor:
		return

	if not skeleton or not ray_left or not ray_right or not target_left or not target_right:
		return

	if not _is_ready_run:
		default_skeleton_y = skeleton.position.y
		_is_ready_run = true

	# Atualiza os pés
	ray_left.force_raycast_update()
	ray_right.force_raycast_update()

	var left_hit_y = update_foot_placement(ray_left, target_left, delta)
	var right_hit_y = update_foot_placement(ray_right, target_right, delta)

	adjust_pelvis(left_hit_y, right_hit_y, delta)
	
	# Atualiza a direção dos joelhos
	update_knee_pole(ik_left, pole_left)
	update_knee_pole(ik_right, pole_right)

func update_foot_placement(ray: RayCast3D, target: Marker3D, delta: float):
	if ray.is_colliding():
		var hit_point: Vector3 = ray.get_collision_point()
		var hit_normal: Vector3 = ray.get_collision_normal()

		var target_position: Vector3 = hit_point + Vector3(0, foot_offset, 0)
		
		var smooth_factor = ik_smoothness * delta if not Engine.is_editor_hint() else 1.0
		target.global_position = target.global_position.lerp(target_position, smooth_factor)

		align_target_with_floor(target, hit_normal)
		
		return hit_point.y
		
	return null

func align_target_with_floor(target: Marker3D, normal: Vector3) -> void:
	var right: Vector3 = target.global_transform.basis.x
	var forward: Vector3 = normal.cross(right).normalized()
	right = forward.cross(normal).normalized()
	
	target.global_transform.basis = Basis(right, normal, forward)

func adjust_pelvis(left_y, right_y, delta: float) -> void:
	var target_pelvis_y = default_skeleton_y
	
	var lowest_y = null
	if left_y != null and right_y != null:
		lowest_y = min(left_y, right_y)
	elif left_y != null:
		lowest_y = left_y
	elif right_y != null:
		lowest_y = right_y

	var root_base_y = global_position.y 

	if lowest_y != null and lowest_y < (root_base_y - 0.05):
		var drop_distance = root_base_y - lowest_y
		drop_distance = clamp(drop_distance, 0.0, max_pelvis_dip) 
		target_pelvis_y = default_skeleton_y - drop_distance

	var smooth_factor = pelvis_smoothness * delta if not Engine.is_editor_hint() else 1.0
	skeleton.position.y = lerp(skeleton.position.y, target_pelvis_y, smooth_factor)

# Força o nó nativo SkeletonIK3D a olhar para o Marker3D do joelho
func update_knee_pole(ik_node: SkeletonIK3D, pole: Marker3D) -> void:
	if not ik_node or not pole: return
	
	# SkeletonIK3D usa a propriedade nativa 'magnet' para guiar a articulação
	ik_node.magnet = pole.global_position
