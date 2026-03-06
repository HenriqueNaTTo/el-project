extends Control

@export var cena_slot: PackedScene
@export var cena_slot_consumivel: PackedScene

@onready var moedas_player: Label = %moedasPlayer

@onready var espadas: VBoxContainer = $HBoxContainer/VBoxContainer/ScrollContainer/espadas
@onready var armaduras: VBoxContainer = $HBoxContainer/VBoxContainer2/ScrollContainer/armaduras
@onready var consumiveis: VBoxContainer = $HBoxContainer/VBoxContainer3/ScrollContainer/consumiveis

func _ready():
	InventoryManager.inventario_atualizado.connect(atualizar_ui)
	# Chama a função uma vez no início para popular com itens que o jogador já tenha.
	atualizar_ui()
	#Globais.playerInst.update_money(0)

# Esta função redesenha toda a interface do inventário.
func atualizar_ui():
	# 1. Limpa todos os slots antigos de todas as categorias
	for child in espadas.get_children():
		child.queue_free()
	for child in armaduras.get_children():
		child.queue_free()
	for child in consumiveis.get_children():
		child.queue_free()
		
	# 2. Pega a lista atualizada de itens do gerenciador
	var itens = InventoryManager.inventario
	
	# 3. Percorre cada item e o adiciona na categoria correta
	for item_data in itens:
		if not is_instance_valid(item_data):
			continue

		# Cria uma nova instância da cena do slot
		var slot = cena_slot.instantiate()
		var slot_consumivel = cena_slot_consumivel.instantiate()
		
		# Adiciona o slot no contêiner correto baseado no tipo do item
		match item_data.tipo_item:
			ItemData.ItemType.arma:
				espadas.add_child(slot)
			ItemData.ItemType.armadura:
				armaduras.add_child(slot)
			ItemData.ItemType.consumivel:
				consumiveis.add_child(slot_consumivel)
		
		# Manda o slot se atualizar com os dados do item
		slot.atualizar_slot(item_data)
