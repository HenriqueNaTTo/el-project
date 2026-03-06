extends Control

class_name Loading

@export var imgList: Dictionary = {
	0: preload("res://Imagens/img1 (1).png"),
	1: preload("res://Imagens/img1 (2).png"),
	2: preload("res://Imagens/img1 (3).png"),
	3: preload("res://Imagens/img1 (4).png"),
	4: preload("res://Imagens/Captura de tela 2025-11-11 084724.png")
}

@export var textList: Dictionary = {
	0: "As armaduras seram liberadas ao derrotar um inimigo que á possui",
	1: "As espadas seram liberadas ao derrotar um inimigo que á possui",
	2: "Utilizar o Elixir Celestial pode recuperar até 20% da vida total",
	3: "Utilizar o Elixir da Meditação pode recuperar até 100% do ki total",
	4: "Baús dropam moedas em todos os niveis",
}

@onready var img_fundo: TextureRect = $imgFundo
@onready var frase_label: Label = $TextureRect2/fraseLabel

func _ready() -> void:
	pass
	
func _process(delta: float) -> void:
	pass
	
func load_text():
	var fraseAleatoria: String = textList[randi_range(0, 4)]
	frase_label.text = fraseAleatoria

func load_image():
	var imgAleatoria: Texture = imgList[randi_range(0, 4)]
	img_fundo.texture = imgAleatoria
