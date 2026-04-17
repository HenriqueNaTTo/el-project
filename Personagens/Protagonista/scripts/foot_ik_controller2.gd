# FootIKController.gd
extends Node3D

# ── Referências exportadas ───────────────────────────────────────────────────
@export var skeleton:        Skeleton3D   
@export var ik_l:            SkeletonIK3D 
@export var ik_r:            SkeletonIK3D 
@export var ray_l:           RayCast3D    
@export var ray_r:           RayCast3D    
@export var target_l:        Node3D       
@export var target_r:        Node3D       
@export var target_joelho_l: Node3D       
@export var target_joelho_r: Node3D       
@export var body:            CharacterBody3D

# ── Parâmetros exportados ────────────────────────────────────────────────────
@export var smooth_speed:     float  = 12.0
@export var rot_speed:        float  = 8.0
@export var max_step_height:  float  = 0.5
@export var ray_length:       float  = 0.8
@export var ik_blend_speed:   float  = 5.0
@export var hip_adjust_speed: float  = 6.0
@export var hip_bone_name:    String = "Hips"

# ── Estado interno ───────────────────────────────────────────────────────────
var _hip_offset: float = 0.0


func _ready() -> void:
	if not _refs_valid():
		push_error("FootIKController: preencha todas as referências no inspetor.")
		return

	ik_l.start()
	ik_r.start()

	ray_l.target_position = Vector3(0.0, -ray_length, 0.0)
	ray_r.target_position = Vector3(0.0, -ray_length, 0.0)

	# Inicializa targets nas poses atuais dos bones
	target_l.global_position = _get_bone_world_pos(ik_l.tip_bone)
	target_r.global_position = _get_bone_world_pos(ik_r.tip_bone)


func _physics_process(delta: float) -> void:
	if not _refs_valid():
		return

	_process_leg(delta, ray_l, target_l, target_joelho_l, ik_l)
	_process_leg(delta, ray_r, target_r, target_joelho_r, ik_r)
	_adjust_hip(delta)


# ── Processa uma perna ────────────────────────────────────────────────────────
func _process_leg(
		delta:          float,
		ray:            RayCast3D,
		target:         Node3D,
		target_joelho:  Node3D,
		ik:             SkeletonIK3D) -> void:

	if ray.is_colliding():
		var hit_pos    := ray.get_collision_point()
		var hit_normal := ray.get_collision_normal()
		var height_diff := hit_pos.y - target.global_position.y

		if height_diff < max_step_height:
			# Suaviza posição
			target.global_position = target.global_position.lerp(hit_pos, smooth_speed * delta)

			# Suaviza rotação alinhada ao normal do chão
			var axis := Vector3.UP.cross(hit_normal)
			var desired_rot: Quaternion
			if axis.length() > 0.001:
				desired_rot = Quaternion(axis.normalized(), Vector3.UP.angle_to(hit_normal))
			else:
				desired_rot = Quaternion.IDENTITY

			var cur_rot := target.global_transform.basis.get_rotation_quaternion()
			target.global_transform.basis = Basis(cur_rot.slerp(desired_rot, rot_speed * delta))

		ik.interpolation = move_toward(ik.interpolation, 1.0, ik_blend_speed * delta)
	else:
		ik.interpolation = move_toward(ik.interpolation, 0.0, ik_blend_speed * delta)

	# Converte target de world space → local do Skeleton3D e aplica ao IK
	ik.set_target_transform(skeleton.global_transform.inverse() * target.global_transform)

	# Magnet do joelho em espaço local do Skeleton3D
	ik.magnet = target_joelho.global_position - skeleton.global_position


# ── Ajuste de altura do quadril ───────────────────────────────────────────────
func _adjust_hip(delta: float) -> void:
	var hip_idx := skeleton.find_bone(hip_bone_name)
	if hip_idx < 0:
		return

	var highest: float = max(target_l.global_position.y, target_r.global_position.y)
	var desired: float = clamp(highest - body.global_position.y, -0.4, 0.1)
	_hip_offset  = lerp(_hip_offset, desired, hip_adjust_speed * delta)

	var pose := skeleton.get_bone_pose(hip_idx)
	pose.origin.y = _hip_offset
	skeleton.set_bone_pose(hip_idx, pose)


# ── Helpers ───────────────────────────────────────────────────────────────────
func _get_bone_world_pos(bone_name: String) -> Vector3:
	var idx := skeleton.find_bone(bone_name)
	if idx < 0:
		return global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(idx).origin


func _refs_valid() -> bool:
	return skeleton != null and ik_l != null and ik_r != null \
		and ray_l != null and ray_r != null \
		and target_l != null and target_r != null \
		and target_joelho_l != null and target_joelho_r != null \
		and body != null
