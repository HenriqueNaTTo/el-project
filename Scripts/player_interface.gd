extends Control

@onready var interaction_interface: Control = $interactionInterface
@onready var interface: TextureRect = $interface
@onready var texto_interacao: Label = $interface/textoInteracao
@onready var img_btn_interacao: TextureRect = $interface/imgBtnInteracao
@onready var btn_interacao: Label = $interface/btnInteracao

@onready var interface_inventario: Control = $interfaceInventario
@onready var fundo_morte: Control = $fundoMorte

@onready var barra_vida: TextureProgressBar = $playerStats/barraVida
@onready var barra_mana: TextureProgressBar = $playerStats/barraMana

func _ready() -> void:
	interaction_interface.visible = false
	interface_inventario.visible = false
	#fundo_morte.visible = false
	
	await get_tree().process_frame
	
	if(Globais.playerInst):
		Globais.playerInst._update_health_bar.connect(update_health_bar)
	
func update_health_bar(vida_atual, vida_maxima):
	barra_vida.max_value = vida_maxima
	barra_vida.value = vida_atual

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("openMenu"):
		match interface_inventario.visible:
			false:
				interface_inventario.visible = true
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				get_tree().paused = true
			true:
				interface_inventario.visible = false
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				get_tree().paused = false
