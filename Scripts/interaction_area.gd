extends Area3D

class_name InteractionArea

@export var levelList: Dictionary = {}
@export var textInterface: String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_body_entered(body) -> void:
	if(body is Player):
		print(body)
		body.interaction_interface.visible = true
		body.texto_interacao.text = textInterface


func _on_body_exited(body) -> void:
		if(body is Player):
			body.interaction_interface.visible = false
