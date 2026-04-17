extends Node3D

@export var skeleton: Skeleton3D

@export var foot_offset: float = 0.05
@export var interp_speed: float = 10.0

@export var ray_l: RayCast3D
@export var ray_r: RayCast3D

@export var target_l: Node3D
@export var target_r: Node3D

@export var ik_l: SkeletonIK3D
@export var ik_r: SkeletonIK3D

func _ready():
	ik_l.start()
	ik_r.start()

func _physics_process(delta):
	update_foot(ray_l, target_l, ik_l, delta)
	update_foot(ray_r, target_r, ik_r, delta)

func update_foot(ray: RayCast3D, target: Node3D, ik: SkeletonIK3D, delta: float):
	if not ray.is_colliding():
		ik.set_influence(0.0)
		return

	var collision_point = ray.get_collision_point()
	var collision_normal = ray.get_collision_normal()

	var desired_pos = collision_point + collision_normal * foot_offset

	# suavização
	var new_pos = target.global_transform.origin.lerp(
		desired_pos,
		delta * interp_speed
	)

	var new_basis = align_with_normal(target.global_transform.basis, collision_normal)

	target.global_transform = Transform3D(new_basis, new_pos)

	# ativa IK suavemente
	var new_influence = lerp(ik.get_influence(), 1.0, delta * interp_speed)
	ik.set_influence(new_influence)

func align_with_normal(basis: Basis, normal: Vector3) -> Basis:
	var up = normal
	var forward = -basis.z

	var right = forward.cross(up).normalized()
	forward = up.cross(right).normalized()

	return Basis(right, up, forward)
