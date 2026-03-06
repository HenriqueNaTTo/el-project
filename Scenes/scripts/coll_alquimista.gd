extends Area3D

@export var acao: String
@export var textInteracao: String
@export var item: ItemData
@export var interface_path: String
@export var scene_path: String
@export var spawn_point: Vector3
var player_in_area: bool = false
var estaNaArea: bool

@onready var interface_alquimista: Control = $"../interfaceAlquimista"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	#Globais.playerInst.selecionar_level.visible = false
	
func _input(event: InputEvent) -> void:
		if(Globais.playerInst.interaction_interface.visible and estaNaArea):
			if(event.is_action_pressed("interacao")):
				match interface_alquimista.visible:
					false:
						interface_alquimista.move_to_front()
						interface_alquimista.visible = true
						Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
					true:
						interface_alquimista.visible = false
						Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _alquimista_on_body_entered(body: Player) -> void:
	if(body.is_in_group("player")):
		body.interaction_interface.visible = true
		estaNaArea = true
		body.texto_interacao.text = textInteracao

func _alquimista_on_body_exited(body: Player) -> void:
	if(body.is_in_group("player")):
		estaNaArea = false
		body.interaction_interface.visible = false
