extends Resource

class_name ItemData

# Enum para organizar os tipos de item
enum ItemType {
	arma,
	armadura,
	consumivel
}

enum armaType {
	espada,
	espada_longa,
	lanca,
	arco
}


@export var nome: String = ""
@export_multiline var descricao: String = ""
@export var status: int = 0
@export var defesa: int = 0
@export var dano: Vector2
@export var icone: Texture2D
@export var cena_3d: PackedScene
@export var tipo_item: ItemType = ItemType.arma
@export var tipo_arma: armaType
