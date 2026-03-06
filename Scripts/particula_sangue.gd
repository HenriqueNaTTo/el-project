extends Node3D

@onready var gpu_particles_3d: GPUParticles3D = $GPUParticles3D
@onready var decal: Decal = $Decal

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	gpu_particles_3d.emitting = true
	decal.visible = true
	await get_tree().create_timer(1.7).timeout
	queue_free()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
