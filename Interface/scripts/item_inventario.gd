extends TextureRect

var item_data: ItemData

@onready var icon_texture: TextureRect = $icon/iconTexture
@onready var nome_item: Label = $nomeItem
@onready var quant_dano: Label = $quantDano

@onready var text_dano_label: Label = $textDano


func _ready() -> void:
	# Garante que o slot comece "limpo".
	atualizar_slot(null)

func atualizar_slot(data: ItemData):
	self.item_data = data
	
	if item_data:
		# Torna os elementos visíveis
		visible = true
		text_dano_label.visible = true
		
		var danox: int = item_data.dano.x
		var danoy: int = item_data.dano.y
		
		# Preenche os dados do item
		nome_item.text = item_data.nome
		icon_texture.texture = item_data.icone
		quant_dano.text = "{danox}-{danoy}".format({"danox": danox, "danoy": danoy})
		
	else:
		# Esconde tudo se o slot estiver vazio
		visible = false
		text_dano_label.visible = false

func _on_gui_input(event: InputEvent) -> void:
	if item_data and event is InputEventMouseButton and event.pressed:
		if Globais.playerInst:
			Globais.playerInst.equipItem(item_data)

func _on_mouse_entered() -> void:
	if visible:
		scale = Vector2(1.1, 1.1)

func _on_mouse_exited() -> void:
	scale = Vector2(1.0, 1.0)
