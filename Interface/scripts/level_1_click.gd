extends TextureRect


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _gui_input(event: InputEvent) -> void:
	if(event is InputEventMouseButton):
		if (event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
				SceneControler.change_scene("res://Scenes/masmorraAndar1.tscn", Vector3(0.0, 1.0, 0.0))
