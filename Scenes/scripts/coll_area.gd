extends Area3D

@export var acao: String
@export var textInteracao: String
@export var item: ItemData
@export var interface_path: String
@export var scene_path: String
@export var spawn_point: Vector3
var estaNaArea: bool = false
@onready var interface_alquimista: Control = $"../../alquimista/interfaceAlquimista"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	
func _input(event: InputEvent) -> void:
		if(Globais.playerInst.interaction_interface.visible and estaNaArea):
			if(event.is_action_pressed("interacao")):
				match Globais.playerInst.selecionar_level.visible:
					false:
						Globais.playerInst.selecionar_level.visible = true
						Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
					true:
						Globais.playerInst.selecionar_level.visible = false
						Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_body_entered(body: Player) -> void:
	if(body.is_in_group("player")):
		estaNaArea = true
		body.interaction_interface.visible = true
		body.texto_interacao.text = textInteracao

func _on_body_exited(body: Player) -> void:
	if(body.is_in_group("player")):
		estaNaArea = false
		body.interaction_interface.visible = false
