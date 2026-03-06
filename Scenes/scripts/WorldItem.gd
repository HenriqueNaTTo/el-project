extends Area3D

class_name WorldItem

# Arraste seu recurso (ex: espada_basica.tres) para esta variável no Inspetor
@export var item_data: ItemData

# Chamado quando o jogador coleta o item
func coletar():
	if InventoryManager.adicionar_item(item_data):
		queue_free() # Remove o item do mundo

func _on_body_entered(body: Player) -> void:
	if body.is_in_group("player"):
		coletar()
