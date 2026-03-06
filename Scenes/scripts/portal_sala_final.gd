extends Node3D

@onready var quant_bau: Label = $Sprite3D/SubViewport/contagemFinal/fotoBau/progressBau/quantBau
@onready var quant_bau_total: Label = $Sprite3D/SubViewport/contagemFinal/fotoBau/progressBau/quantBauTotal

@onready var quant_inimigos: Label = $Sprite3D/SubViewport/contagemFinal/fotoBau2/progressInimigos/quantInimigos
@onready var quant_inimigos_total: Label = $Sprite3D/SubViewport/contagemFinal/fotoBau2/progressInimigos/quantInimigosTotal

@onready var particula_portal: GPUParticles3D = $particulaPortal
@onready var area_final: Area3D = $areaFinal

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	area_final.monitoring = false
	await get_tree().process_frame
	await get_tree().process_frame
	quant_bau.text = str(Globais.quantMaxBau)
	quant_bau_total.text = str(Globais.quantMaxBau)
	
	quant_inimigos.text = str(Globais.quantMaxInimigos)
	quant_inimigos_total.text = str(Globais.quantMaxInimigos)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	quant_bau.text = str(Globais.quantBau)
	quant_inimigos.text = str(Globais.quantInimigos)
	
	if((Globais.quantBau == Globais.quantMaxBau) and (Globais.quantInimigos == Globais.quantMaxInimigos)):
		area_final.monitoring = true
		particula_portal.emitting

func _on_area_final_body_entered(body: Player) -> void:
	body.proximo_nivel.visible = true
