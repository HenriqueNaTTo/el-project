extends Area3D

var playerCarregado: Player

@export var mensagemInteracao: String = ""
@export var acao: String = ""
@export var sceneDestino: String = ""
@export var interface: String = ""

@export var posicaoSpawn = Vector3(0, 0, 0)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect("area_entered", _on_body_entered)
	connect("area_exited", _on_body_exited)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if(playerCarregado and playerCarregado.interacao_ativa and Input.is_action_just_pressed("interacao")):
		executar_acao(acao)

func _on_body_entered(body: Node3D) -> void:
	if(body.is_in_group("player")):
		playerCarregado = Globais.playerSelf
		playerCarregado.show_interact(mensagemInteracao, true)
		
func _on_body_exited(body: Node3D) -> void:
	if(body.is_in_group("player")):
		playerCarregado = Globais.playerSelf
		playerCarregado.show_interact("fechando" + mensagemInteracao, false)

func executar_acao(acao: String) -> void:
	match (acao):
		"dropItem":
			dropar_item()
		"loadScene":
			load_scene()
		"openInterface":
			open_interface()
			
func load_scene():
	if(sceneDestino == "res://Scenes/mainMenu.tscn"):
		get_tree().change_scene_to_file(sceneDestino)
	else:
		SceneControler.change_scene(sceneDestino, posicaoSpawn)
	
func dropar_item():
	print("item dropado")
	
func open_interface():
	print("abrindo interface")
