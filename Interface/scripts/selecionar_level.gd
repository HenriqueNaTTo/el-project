extends Control

@onready var grid_container: GridContainer = $fundo/GridContainer
@onready var level_1: TextureRect = $fundo/GridContainer/level1
@onready var level_2: TextureRect = $fundo/GridContainer/level2
@onready var level_3: TextureRect = $fundo/GridContainer/level3
@onready var level_4: TextureRect = $fundo/GridContainer/level4
@onready var btn_sair: Button = $fundo/btnSair

@export_category("level1")
@export var level_1_texture: Texture2D = null
@export var mouse_level_1_texture: Texture2D = null

@export_category("level2")
@export var level_2_texture: Texture2D = null
@export var mouse_level_2_texture: Texture2D = null

func _on_level_1_mouse_entered() -> void:
	level_1.texture = mouse_level_1_texture
	
func _on_level_1_mouse_exited() -> void:
	level_1.texture = level_1_texture
	
func _on_level_2_mouse_entered() -> void:
	level_2.texture = mouse_level_2_texture
	
func _on_level_2_mouse_exited() -> void:
	level_2.texture = level_2_texture

func _on_btn_sair_pressed() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
