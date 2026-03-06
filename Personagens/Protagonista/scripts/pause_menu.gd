extends Control

@onready var config_interface: Control = $ConfigInterface
@onready var interface_anim: AnimationPlayer = $interfaceAnim
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	visible = false

func _process(delta: float) -> void:
	pass
	
func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("openPauseMenu") and !visible:
			animation_player.play("fadeIn")
			visible = true
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.is_action_pressed("openPauseMenu") and visible:
			animation_player.play("fadeOut")
			visible = false
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_continue_btn_pressed() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _on_sair_btn_pressed() -> void:
	get_tree().quit()

func _on_config_btn_pressed() -> void:
	if(config_interface.visible == false):
		interface_anim.play("configFadeIn")
		config_interface.visible = true
	else:
		interface_anim.play("configFadeOut")
