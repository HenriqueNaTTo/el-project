extends Area3D

@export var acao: String
@export var textInteracao: String
@export var item: String
@export var interface_path: String
var player_in_area: bool = false
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"

var coletado: bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	
func _input(event: InputEvent) -> void:
		if(Globais.playerInst.interaction_interface.visible and player_in_area and !coletado):
			if(event.is_action_pressed("interacao")):
				match acao:
					"mosta_interface":
						Globais.playerInst.interaction("mostra_interface", interface_path)
					"dropa_item":
						Globais.playerInst.interaction("dropa_item")
						animation_player.play("abrindoBau")
						Globais.update_quant_bau(1)

func _on_body_entered(body: Player) -> void:
	if(body.is_in_group("player")):
		body.interaction_interface.visible = true
		body.texto_interacao.text = textInteracao
		player_in_area = true

func _on_body_exited(body: Player) -> void:
	if(body.is_in_group("player")):
		body.interaction_interface.visible = false
		player_in_area = false
