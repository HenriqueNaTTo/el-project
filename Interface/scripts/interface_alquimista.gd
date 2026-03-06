extends Control

@onready var dinheiro_player: Label = $containerValor/dinheiroPlayer
@onready var interface_alquimista: Control = $"."

func _ready() -> void:
	await get_tree().process_frame
	dinheiro_player.text = str(Globais.playerInst.dinheiro)

func _process(delta: float) -> void:
	dinheiro_player.text = str(Globais.playerInst.dinheiro)

func _on_btn_sair_pressed() -> void:
	interface_alquimista.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
