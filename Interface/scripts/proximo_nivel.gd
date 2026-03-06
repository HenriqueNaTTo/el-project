extends Control

class_name ProximoNivel

@onready var btn_proximo: Button = $botoes/btnProximo
@onready var btn_sair: Button = $botoes/btnSair

var proximoNivelPath: String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().process_frame
	proximoNivelPath = Globais.playerInst.proximoNivelPath

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if(visible == true):
		get_tree().paused = true
		proximoNivelPath = Globais.playerInst.proximoNivelPath
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_btn_proximo_pressed() -> void:
	SceneControler.change_scene(proximoNivelPath, Vector3(0, 3.5, 0))

func _on_btn_sair_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	SceneControler.change_scene("res://Scenes/ilhaPrincipal.tscn", Vector3(-58.0, 51.4, -44.6))
