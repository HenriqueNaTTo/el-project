extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interface_alquimista: Control = $interfaceAlquimista

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.play("idleHerbalista")
	interface_alquimista.visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
