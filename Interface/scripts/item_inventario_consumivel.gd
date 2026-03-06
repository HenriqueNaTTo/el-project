extends TextureRect

@export var item_data: ItemData

@onready var icon_texture: TextureRect = $icon/iconTexture
@onready var nome_item: Label = $nomeItem
@onready var quant_status: Label = $quantStatus
@onready var text_status: Label = $textStatus

@onready var container_valor: HBoxContainer = $containerValor
@onready var valor_item: Label = $containerValor/valorItem

@export var valor: int

func _ready() -> void:
	# Garante que o slot comece "limpo".
	atualizar_slot(item_data)

func atualizar_slot(data: ItemData):
	self.item_data = data
	
	if item_data:
		# Torna os elementos visíveis
		visible = true
		text_status.visible = true
		
		# Preenche os dados do item
		nome_item.text = item_data.nome
		icon_texture.texture = item_data.icone
		quant_status.text = str(item_data.status)
		valor_item.text = str(valor)
		
	else:
		# Esconde tudo se o slot estiver vazio
		visible = false
		text_status.visible = false

func _on_gui_input(event: InputEvent) -> void:
	if item_data and event is InputEventMouseButton and event.pressed:
		if Globais.playerInst:
			if(Globais.playerInst.dinheiro < valor):
				return
			else:
				#InventoryManager.adicionar_item(item_data)
				Globais.playerInst.dinheiro -= valor
				Globais.playerInst.frascos_vida += 1
				Globais.playerInst.frascos_vida_text.text = str(Globais.playerInst.frascos_vida)

func _on_mouse_entered() -> void:
	if visible:
		scale = Vector2(1.1, 1.1)

func _on_mouse_exited() -> void:
	scale = Vector2(1.0, 1.0)
