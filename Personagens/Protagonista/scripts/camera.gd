extends Node3D

@export var sensitivity = 0.2
@export var acceleration = 10.0
const MIN = -75.0
const MAX = 30.0
var cam_horizontal = 0.0
var cam_vertical = 0.0  # Corrigido o nome da variável (estava "vertival")

func _input(event: InputEvent) -> void:
	if(event is InputEventMouseMotion):
		cam_horizontal -= event.relative.x * sensitivity
		cam_vertical -= event.relative.y * sensitivity
		
func _physics_process(delta: float) -> void:  # Corrigido nome da função (removi **)
	cam_vertical = clamp(cam_vertical, MIN, MAX)
	$horizontal.rotation_degrees.y = lerp($horizontal.rotation_degrees.y, cam_horizontal, acceleration * delta)
	$horizontal/vertical.rotation_degrees.x = lerp($horizontal/vertical.rotation_degrees.x, cam_vertical, acceleration * delta)  # Corrigido para usar o rotation_degrees do nó vertical
