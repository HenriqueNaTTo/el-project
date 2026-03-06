extends Control

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	visible = false

func _process(delta: float) -> void:
	pass
	
func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("openMenu") and !visible:
			visible = true
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			animation_player.play("fadeIn")
			
		elif event.is_action_pressed("openMenu") and visible:
			animation_player.play("fadeOut")
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_sair_do_jogo_tab_clicked(tab: int) -> void:
	get_tree().change_scene_to_file("res://Scenes/mainMenu.tscn")
