extends Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_btn_iniciar_pressed() -> void:
	SceneControler.change_scene("res://Scenes/ilhaPrincipal.tscn", Vector3(-58.0, 51.4, -44.6))

func _on_btn_sair_pressed() -> void:
	get_tree().quit()

func _on_btn_ajuda_pressed() -> void:
	pass # Replace with function body.
