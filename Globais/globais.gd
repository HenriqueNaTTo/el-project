extends Node

var inventario: Inventario
var armorList = {}
var weaponList = {}

var playerInst: Player = null
var kiUtilizado: int

var current_defense: int
var current_attack: Vector2
var current_peso: int

var quantBau: int = 0
var quantInimigos: int

var quantMaxBau: int = 0
var quantMaxInimigos: int

#var blood = preload("res://modelos/VFX/blood_fx.tscn")
#var decalInst = preload("res://modelos/VFX/decal_texture.tscn")

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if(playerInst == null):
		pass
	else:
		playerInst.proximoNivelPath = ""
	
func update_quant_bau(quant):
	quantBau += quant
	
func update_quant_Inimigo(quant):
	quantInimigos += quant

func damage_player(damageMin, damageMax):
	playerInst.current_health -= randi_range(damageMin, damageMax)
	var vida = playerInst.current_health
	var max = playerInst.MAX_HEALTH
	
	playerInst.update_health(vida, max)
	print(playerInst.current_health)
