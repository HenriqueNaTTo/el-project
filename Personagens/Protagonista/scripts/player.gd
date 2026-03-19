extends CharacterBody3D
class_name Player

@export_category("Movement")
@export var SPEED: float = 10.0
@export var RUN_SPEED: float = 18.0
@export var JUMP_VELOCITY = 12.0
@export var ROTATION_SPEED: float = 10.0 # Velocidade de rotação do corpo
var current_speed = SPEED

@export_category("BasicStats")
@export var HEALTH: int = 100
@export var MAX_HEALTH: int = 100
var current_health = HEALTH
@export var KI: int = 100
@export var MAX_KI: int = 100
var current_ki = KI
@export var isAttacking: bool = false
@export var defence: int = 0
@export var peso: int = 0

@export_category("Outros")
@export var dinheiro: int = 1600

# --- Referências de Terceira Pessoa ---

# Este deve ser o nó que contém o Script da Câmera que você me mandou
@onready var camera_pivot: Node3D = $CameraController
@onready var mesh_node: Node3D = $mesh

# AnimationTree
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationPlayer/AnimationTree

# Timer de ataque
@onready var attackTimer: Timer = $attackTimer

# UI
@onready var fundo_morte: Control = $interfaceLayer/playerInterface/fundoMorte
@onready var btn_ultimo_save: Button = $interfaceLayer/playerInterface/fundoMorte/botoes/btnIniciar
@onready var btn_voltar_menu: Button = $interfaceLayer/playerInterface/fundoMorte/botoes/btnSair

# Coleta e itens
@onready var area_de_coleta: Area3D = $area_de_coleta
@onready var espadas: VBoxContainer = $interfaceLayer/playerInterface/interfaceInventARIO/HBoxContainer/VBoxContainer/ScrollContainer/espadas
@onready var armaduras: VBoxContainer = $interfaceLayer/playerInterface/interfaceInventARIO/HBoxContainer/VBoxContainer2/ScrollContainer/armaduras
@onready var consumiveis: VBoxContainer = $interfaceLayer/playerInterface/interfaceInventARIO/HBoxContainer/VBoxContainer3/ScrollContainer/consumiveis

@onready var weapon: Node3D = $mesh/protagonistaMesh/root/Skeleton3D/rightHandBone/weapon
@onready var area_attack: Area3D = $mesh/protagonistaMesh/root/Skeleton3D/rightHandBone/weapon/AreaCollision

var current_weapon_data: ItemData

@onready var armor: Node3D = $mesh/protagonistaMesh/root/Skeleton3D/armor

var idle: bool
var currentArmor = null
var currentWeapon = null

# Combos
var combo_count: int = 0
@export var max_sword_combo: int = 3
var interacao_ativa: bool

#interface
@onready var interface_inventario: Control = $interfaceInventario
@onready var player_interface: Control = $interfaceLayer/playerInterface
@onready var proximo_nivel: Control = $interfaceLayer/playerInterface/proximoNivel

var proximoNivelPath: String

@onready var moedas_player: Label = $interfaceLayer/playerInterface/interfaceInventARIO/HBoxContainer2/moedasPlayer
@onready var texture_moeda: TextureRect = $interfaceLayer/playerInterface/interfaceInventARIO/HBoxContainer2/textureMoeda
@onready var selecionar_level: Control = $interfaceLayer/playerInterface/selecionarLevel

#interação
@onready var interaction_interface: Control = $interfaceLayer/playerInterface/interactionInterface
@onready var texto_interacao: Label = $interfaceLayer/playerInterface/interactionInterface/interface/textoInteracao
@export_category("AudioPlayer")

@onready var foot_steps: AudioStreamPlayer3D = $footSteps

@export_category("Sons dos passos")

@export var step_sounds: Dictionary = {

0: preload("res://Sons/passos/Footsteps_Rock_Walk_05.wav"),
1: preload("res://Sons/passos/Footsteps_Walk_Grass_Mono_23.wav"),
2: preload("res://Sons/passos/Footsteps_DirtyGround_Walk_10.wav"),
3: preload("res://Sons/passos/Footsteps_Sand_Walk_16.wav"),
4: preload("res://Sons/passos/Footsteps_Tile_Walk_04.wav"),
5: preload("res://Sons/passos/Footsteps_Rock_Walk_05.wav"),
}

@export var step_sounds_group: Dictionary = {

"concreto": preload("res://Sons/passos/Footsteps_Rock_Walk_05.wav"),
"pedra": preload("res://Sons/passos/Footsteps_Rock_Walk_05.wav"),
"madeira": preload("res://Sons/passos/Footsteps_Rock_Walk_05.wav"),
"tecido": preload("res://Sons/passos/Footsteps_Rock_Walk_05.wav")
}

@export_category("Camera e outros")
@export var weapon_sway_amount: float = 0.02
@export var weapon_sway_speed: float = 5.0

signal _update_health_bar(health, max_health)
signal _update_ki_bar(ki, max_ki)

@onready var particulas: Node3D = $Particulas
@onready var cura: GPUParticles3D = $Particulas/cura
var quantCura: int = 30
@export var frascos_vida: int = 5
@export var frascos_fogo: int = 5
@onready var frascos_vida_text: Label = $interfaceLayer/playerInterface/itemIconQ/quantHabilidade
@onready var frascos_fogo_text: Label = $interfaceLayer/playerInterface/itemIconE/quantHabilidade

var particula_sangue = preload("res://Scenes/vfx/particula_sangue.tscn")

@onready var state_machine: StateMachine = $StateMachine

func _ready() -> void:
	
	if Globais.playerInst != null:
		queue_free()
	else:
		Globais.playerInst = self
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if area_attack: area_attack.monitoring = false # Desativado por padrão
	if frascos_vida_text: frascos_vida_text.text = str(frascos_vida)
	if frascos_fogo_text: frascos_fogo_text.text = str(frascos_fogo)

func _input(event):
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if Input.is_action_just_pressed("cura"):
		print("curaVida(30)")

# ==========================================
# FUNÇÕES AUXILIARES PARA OS ESTADOS
# ==========================================

# Os estados vão chamar essa função para descobrir para onde andar baseado na câmera
func get_movement_direction() -> Vector3:
	var cam_horizontal_node = camera_pivot.get_node_or_null("horizontal")
	if cam_horizontal_node:
		var horizontal_rotation = cam_horizontal_node.global_transform.basis.get_euler().y
		var input_dir := Input.get_vector("left", "right", "up", "down")
		return (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized().rotated(Vector3.UP, horizontal_rotation)
	return Vector3.ZERO

func apply_movement_and_rotation(direction: Vector3, delta: float):
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		
		var target_rotation_y = atan2(direction.x, direction.z)
		mesh_node.rotation.y = lerp_angle(mesh_node.rotation.y, target_rotation_y, delta * ROTATION_SPEED)
		mesh_node.rotation.x = 0
		mesh_node.rotation.z = 0
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	
	move_and_slide()

# ==========================================
# COMBATE E ITENS (MANTIDOS DO SEU CÓDIGO)
# ==========================================
# Mantenha suas funções curaVida(), equipItem(), interaction(), die_player(), get_current_texture() etc... aqui.

func dispatch_attack() -> void:
	if current_weapon_data == null:
		return
	# Passa o tipo da arma direto para o combatState aninhado
	var combat = state_machine.get_node_or_null("combatState")
	if combat:
		state_machine.transition_to("combatState")
		combat.enter(current_weapon_data.tipo_arma)

func _on_area_collision_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemy") and current_weapon_data != null:
		if body.has_method("in_self_damage"):
			body.in_self_damage(current_weapon_data.dano)
			var particle_instance = particula_sangue.instantiate()
			body.get_parent().add_child(particle_instance)
			particle_instance.global_position = body.global_position

func get_current_texture():
	var ray_cast_3d = $RayCast3D
	if not ray_cast_3d: return -1
	ray_cast_3d.force_raycast_update()
	if ray_cast_3d.is_colliding():
		var terrain = ray_cast_3d.get_collider()
		if terrain is Terrain3D:
			var pos = terrain.to_global(ray_cast_3d.get_collision_point())
			return terrain.data.get_texture_id(pos).y
	return -1
		
func get_current_surface_group():
	var ray_cast_3d = $RayCast3D
	if not ray_cast_3d: return ""
	ray_cast_3d.force_raycast_update()
	if ray_cast_3d.is_colliding():
		var collider = ray_cast_3d.get_collider()
		if collider.is_in_group("madeira"): return "madeira"
		elif collider.is_in_group("concreto"): return "concreto"
		elif collider.is_in_group("pedra"): return "pedra"
		elif collider.is_in_group("tecido"): return "tecido"
	return ""

func play_step_sound():
	var texture_index = get_current_texture()
	var surface_group = get_current_surface_group()
	if surface_group != "" and step_sounds_group.has(surface_group):
		foot_steps.stream = step_sounds_group[surface_group]
		foot_steps.play()
		texture_index = null
	if texture_index != null and texture_index != -1:
		if step_sounds.has(int(texture_index)):
			foot_steps.stream = step_sounds[int(texture_index)]
			foot_steps.play()

func _on_animation_player_animation_finished(anim_name: String) -> void:
	if anim_name == "bow_shoot":
		var combat = state_machine.get_node_or_null("combatState")
		if combat and combat.current_state and combat.current_state.has_method("spawn_arrow"):
			combat.current_state.spawn_arrow()
