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

# ==========================================================
# INPUT
# ==========================================================
func _input(event):
	# OBS: Removi a rotação do mouse daqui, pois o Script da Camera já faz isso!
	
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		
	if Input.is_action_just_pressed("light"):
		pass
		
	if Input.is_action_just_pressed("cura"):
		curaVida(quantCura)

# ==========================================================
# READY
# ==========================================================
func _ready() -> void:
	if Globais.playerInst != null:
		queue_free()
	else:
		Globais.playerInst = self
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if area_attack: area_attack.monitoring = true
	if frascos_vida_text: frascos_vida_text.text = str(frascos_vida)
	if frascos_fogo_text: frascos_fogo_text.text = str(frascos_fogo)
	if selecionar_level: selecionar_level.visible = false
	
	# Verificação de segurança
	if not camera_pivot:
		print("ERRO: O nó 'CameraPivot' não foi encontrado!")

# ==========================================================
# PHYSICS
# ==========================================================
func _physics_process(delta: float) -> void:
	# Idle check
	idle = velocity == Vector3.ZERO

	# AnimationTree - movimento
	if animation_tree:
		animation_tree["parameters/BasicMove/conditions/idle"] = idle
		animation_tree["parameters/BasicMove/conditions/walk"] = !idle and not Input.is_action_pressed("run")
		animation_tree["parameters/BasicMove/conditions/run"] = !idle and Input.is_action_pressed("run")
		animation_tree["parameters/conditions/basicMove"] = !isAttacking

	if Input.is_action_just_pressed("basicAttack"):
		handle_attack()

	# Gravidade
	if not is_on_floor():
		velocity += (get_gravity() * 2) * delta

	# Pulo
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	# --- LÓGICA DE MOVIMENTO INTEGRADA AO NOVO SCRIPT DE CAMERA ---
	
	# Verificamos se o camera_pivot existe
	if camera_pivot:
		# IMPORTANTE: O seu script de câmera gira o nó filho chamado "horizontal".
		# Precisamos pegar a referência dele para saber a direção.
		var cam_horizontal_node = camera_pivot.get_node_or_null("horizontal")
		
		if cam_horizontal_node:
			# 1. Pega a rotação Y do nó "horizontal" da câmera
			var horizontal_rotation = cam_horizontal_node.global_transform.basis.get_euler().y
			
			# 2. Input
			var input_dir := Input.get_vector("left", "right", "up", "down")
			
			# 3. Calcula direção baseada na rotação do "horizontal"
			var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized().rotated(Vector3.UP, horizontal_rotation)

			# 4. Movimento e Rotação do Personagem
			if direction:
				velocity.x = direction.x * current_speed
				velocity.z = direction.z * current_speed
				
				# Gira o personagem suavemente usando lerp_angle
				var target_rotation_y = atan2(direction.x, direction.z)
				mesh_node.rotation.y = lerp_angle(mesh_node.rotation.y, target_rotation_y, delta * ROTATION_SPEED)
				
				# Trava eixos indesejados
				mesh_node.rotation.x = 0
				mesh_node.rotation.z = 0
			else:
				velocity.x = move_toward(velocity.x, 0, current_speed)
				velocity.z = move_toward(velocity.z, 0, current_speed)
		else:
			# Fallback se não achar o nó "horizontal"
			print("AVISO: Nó 'horizontal' não encontrado dentro de CameraPivot.")
			velocity.x = 0
			velocity.z = 0
	else:
		velocity.x = 0
		velocity.z = 0
	# --- FIM DA LÓGICA DE MOVIMENTO ---

	# Ajuste de velocidade
	current_speed = 4.0 if isAttacking else (RUN_SPEED if Input.is_action_pressed("run") else SPEED)
			
	move_and_slide()

# ==========================================================
# ITENS / OUTROS / COMBOS (Tudo mantido igual)
# ==========================================================

func curaVida(quant: int):
	if(frascos_vida > 0):
		if(current_health < MAX_HEALTH):
			cura.emitting = true
			current_health += quant
			current_health = min(current_health, MAX_HEALTH)
			update_health(current_health, MAX_HEALTH)
			frascos_vida -= 1
			frascos_vida_text.text = str(frascos_vida)

func equipItem(item_data: ItemData):
	if not is_instance_valid(item_data): return

	match item_data.tipo_item:
		ItemData.ItemType.arma:
			if is_instance_valid(currentWeapon):
				currentWeapon.queue_free()
			if item_data.cena_3d:
				var nova_arma = item_data.cena_3d.instantiate()
				currentWeapon = nova_arma
				current_weapon_data = item_data
				weapon.add_child(nova_arma)
		
		ItemData.ItemType.armadura:
			if is_instance_valid(currentArmor): pass 
			currentArmor = item_data
			defence += item_data.defesa
			if item_data.cena_3d:
				var nova_armadura = item_data.cena_3d.instantiate()
				currentArmor = nova_armadura
				armor.add_child(nova_armadura)

		ItemData.ItemType.consumivel:
			current_health = min(MAX_HEALTH, current_health + 25)

func interaction(acao: String, interface_path: String = "", interface_node: Control = null, scene_path: String = "", spawn_point: Vector3 = Vector3(0, 0, 0)):
	match acao:
		"dropa_item": update_money(200)
		"pega_item": coletar_item_proximo()
		"troca_scene": SceneControler.change_scene(scene_path, spawn_point)
			
func update_money(coletado: int) -> String:
	dinheiro += coletado
	moedas_player.text = str(dinheiro)
	return str(dinheiro)
	
func update_health(health: int, max_health: int):
	if current_health <= 0: die_player()
	_update_health_bar.emit(health, max_health)
	
func die_player():
	var fundo_morte_inst = load("res://Scenes/interface/fundo_morte.tscn").instantiate()
	Globais.playerInst.player_interface.add_child(fundo_morte_inst)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	
func _on_btn_voltar_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/mainMenu.tscn")
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func update_ki(ki: int, max_ki: int):
	_update_ki_bar.emit(current_ki, max_ki)

func coletar_item_proximo():
	var areas = area_de_coleta.get_overlapping_areas()
	if not areas.is_empty():
		for area in areas:
			if area is WorldItem:
				area.coletar()
				break

func ativar_hitbox(): area_attack.monitoring = true
func desativar_hitbox(): area_attack.monitoring = false
	
func _on_area_collision_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemy"):
		if current_weapon_data == null: return
		if body.has_method("in_self_damage"):
			body.in_self_damage(current_weapon_data.dano)
			var particle_instance = particula_sangue.instantiate()
			body.get_parent().add_child(particle_instance)
			particle_instance.global_position = body.global_position

func handle_attack():
	if isAttacking and attackTimer.is_stopped(): return
	if attackTimer.is_stopped(): combo_count = 0
	else: combo_count += 1
	if combo_count >= max_sword_combo: return

	isAttacking = true
	attackTimer.stop()
	animation_tree["parameters/conditions/isAttack"] = true
	animation_tree["parameters/conditions/basicMove"] = false
	
	match combo_count:
		0:
			animation_tree["parameters/swordCombo/conditions/attack1"] = true
			animation_tree["parameters/swordCombo/conditions/attack2"] = false
			animation_tree["parameters/swordCombo/conditions/attack3"] = false
			play_timer(1.2)
		1:
			animation_tree["parameters/swordCombo/conditions/attack1"] = false
			animation_tree["parameters/swordCombo/conditions/attack2"] = true
			animation_tree["parameters/swordCombo/conditions/attack3"] = false
			play_timer(0.5)
		2:
			animation_tree["parameters/swordCombo/conditions/attack1"] = false
			animation_tree["parameters/swordCombo/conditions/attack2"] = false
			animation_tree["parameters/swordCombo/conditions/attack3"] = true
			play_timer(1.0)

func _on_attack_timer_timeout() -> void:
	isAttacking = false
	combo_count = 0
	animation_tree["parameters/conditions/isAttack"] = false
	animation_tree["parameters/conditions/basicMove"] = true
	animation_tree["parameters/swordCombo/conditions/attack1"] = false
	animation_tree["parameters/swordCombo/conditions/attack2"] = false
	animation_tree["parameters/swordCombo/conditions/attack3"] = false

func play_timer(time: float):
	attackTimer.wait_time = time
	attackTimer.one_shot = true
	attackTimer.start()

func show_interact(texto: String, visibilidade: bool):
	if not has_node("PlayerInfo/InterfaceInteracao"): return
	$PlayerInfo/InterfaceInteracao.visible = visibilidade
	interacao_ativa = visibilidade
	$PlayerInfo/InterfaceInteracao/TextoInteracao.text = texto if visibilidade else ""

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
