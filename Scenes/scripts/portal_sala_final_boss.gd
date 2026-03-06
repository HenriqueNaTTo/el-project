extends Node3D

@onready var particula_portal: GPUParticles3D = $particulaPortal
@onready var area_final: Area3D = $areaFinal

var bossMorto: bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	area_final.monitoring = false
	Globais.playerInst.proximoNivelPath = "res://Scenes/ilhaPrincipal.tscn"
	await get_tree().process_frame
	await get_tree().process_frame

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if(bossMorto):
		area_final.monitoring = true
		particula_portal.emitting

func _on_area_final_body_entered(body: Player) -> void:
	body.proximo_nivel.visible = true
