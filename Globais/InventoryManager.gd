extends Node

# Sinal que será emitido sempre que o inventário mudar
signal inventario_atualizado

# Array para guardar os recursos (ItemData)
var inventario: Array[ItemData] = []

const TAMANHO_MAXIMO = 32 # Define o tamanho máximo do inventário

func adicionar_item(item_data: ItemData) -> bool:
	if inventario.size() < TAMANHO_MAXIMO:
		inventario.append(item_data)
		inventario_atualizado.emit() # Avisa a UI para se atualizar
		print(item_data.nome + " adicionado ao inventário.")
			
		return true
	else:
		print("Inventário cheio!")
		return false
