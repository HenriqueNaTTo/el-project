extends CharacterBody3D

class_name EnemyMago

enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	RETURN_TO_PATROL
}

@export var waypoint_container: Node3D
var waypoints: Array[Vector3] = []
var current_waypoint_index: int = 0
var patrol_direction: int = 1  # 1 = ida, -1 = volta
var waypoint_reached_distance: float = 1.5
var current_state = State.IDLE

# Variáveis para retorno à patrulha'
var patrol_start_position: Vector3
var patrol_start_index: int
var target_return_position: Vector3

# --- REFERÊNCIAS DE NÓS (OnReady) ---
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animation_player: AnimationPlayer = $mesh/protagonistaMesh/AnimationPlayer
@onready var attack_timer: Timer = $attackTimer
@onready var pause_timer: Timer = $pauseTimer
@onready var foot_steps: AudioStreamPlayer3D = $footSteps
@onready var weapon_area: Area3D = $mesh/protagonistaMesh/root/Skeleton3D/rightHandBone/weapon/espadaBasicaTeste/AreaCollision
@onready var detection_area: Area3D = $detectionArea
@onready var ray_cast_3d: RayCast3D = $RayCast3D
@onready var barra_vida: TextureProgressBar = $vidaBoss/vida/barraVida

@onready var fireball_spawn_point: Node3D = $mesh/protagonistaMesh/root/Skeleton3D/BoneAttachment3D

# --- VARIÁVEIS EXPORTADAS ---
@export var move_speed: float = 12.0
@export var attack_range: float = 8.0 # Este agora é o alcance do MELEE
@export var attack_damage_range: Vector2 = Vector2(15, 25)
@export var health_enemy: int = 100

@export var max_sword_combo: int = 3

@export_category("Ataque Mágico")
@export var fireball_scene: PackedScene # Arraste seu FireballProjectile.tscn aqui
@export var fireball_attack_range: float = 15.0 
# --- LINHA ADICIONADA ---
# Define o tempo total de "ocupado" ao lançar uma bola de fogo (animação + espera)
@export var fireball_cooldown: float = 1.8 
@onready var bola_de_fogo: MeshInstance3D = $mesh/protagonistaMesh/root/Skeleton3D/BoneAttachment3D/bolaDeFogo

@export_category("Sons dos Passos")
@export var step_sounds: Dictionary = {
	0: preload("res://Sons/passos/Footsteps_Walk_Grass_Mono_23.wav"),
	1: preload("res://Sons/passos/Footsteps_Rock_Walk_05.wav"),
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

# --- VARIÁVEIS INTERNAS ---
var player: CharacterBody3D
var combo_count: int = 0
var idle_timer: float = 0.0

#=============================================================================
# FUNÇÕES DO GODOT
#=============================================================================

func _ready() -> void:
	var player_nodes = get_tree().get_nodes_in_group("player")
	if not player_nodes.is_empty():
		player = player_nodes[0]

	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	weapon_area.body_entered.connect(_on_weapon_area_body_entered)
	
	_setup_animation_blends()
	
	await get_tree().process_frame
	setup_waypoints()
	
	player = Globais.playerInst
	
	enter_state(State.IDLE)

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			animation_player.play("idlev3")
			velocity = Vector3.ZERO
		
			idle_timer += delta
			if idle_timer >= randf_range(3.0, 5.0):
				idle_timer = 0.0
				enter_state(State.CHASE)
		
		State.CHASE:
			animation_player.play("Runv2")
		
			if not player:
				enter_state(State.IDLE)
				return
		
			navigation_agent.set_target_position(player.global_position)
			var next_pos: Vector3 = navigation_agent.get_next_path_position()
			velocity = global_position.direction_to(next_pos) * move_speed
			
			look_at(Vector3(navigation_agent.get_next_path_position().x, global_position.y, navigation_agent.get_next_path_position().z), Vector3.UP)
		
			if global_position.distance_to(player.global_position) < fireball_attack_range:
				enter_state(State.ATTACK)
			elif navigation_agent.is_navigation_finished():
				enter_state(State.IDLE)
	
		State.ATTACK:
			if not player:
				enter_state(State.IDLE)
				return
		
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
			
			var distance_to_player = global_position.distance_to(player.global_position)

			if distance_to_player > fireball_attack_range:
				enter_state(State.CHASE)
				return
				
			if not attack_timer.is_stopped():
				velocity = Vector3.ZERO 
				return

			if distance_to_player <= attack_range:
				velocity = Vector3.ZERO
				_choose_and_perform_attack()
				
			elif distance_to_player <= fireball_attack_range:
				velocity = Vector3.ZERO
				_perform_attack_fireball()
				
			else:
				velocity = Vector3.ZERO

	move_and_slide()
	
#=============================================================================
# MÁQUINA DE ESTADOS
#=============================================================================

func enter_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	var old_state = current_state
	current_state = new_state
	
	if old_state == State.IDLE:
		idle_timer = 0.0

	match current_state:
		State.IDLE:
			velocity = Vector3.ZERO
		State.PATROL:
			pass
		State.CHASE:
			patrol_start_position = global_position
			patrol_start_index = current_waypoint_index
		State.ATTACK:
			velocity = Vector3.ZERO
			combo_count = 0
		State.RETURN_TO_PATROL:
			pass

#=============================================================================
# LÓGICA DE COMPORTAMENTO
#=============================================================================

func setup_waypoints():
	if waypoint_container:
		for child in waypoint_container.get_children():
			if child is CollisionShape3D:
				waypoints.append(child.global_position)
				
		if waypoints.size() > 0:
			global_position = waypoints[0]
	else:
		enter_state(State.IDLE)
			
func advance_to_next_waypoint():
	if waypoints.size() <= 1:
		enter_state(State.IDLE)
	
	if patrol_direction == 1:
		current_waypoint_index += 1
		if current_waypoint_index >= waypoints.size():
			current_waypoint_index = waypoints.size() - 2
			patrol_direction = -1
	else:
		current_waypoint_index -= 1
		if current_waypoint_index < 0:
			current_waypoint_index = 1
			patrol_direction = 1

func _choose_and_perform_attack() -> void:
	if combo_count == 0:
		if randf() < 0.5:
			_perform_attack_fireball()
		else:
			_perform_attack_combo()
	else:
		_perform_attack_combo()

func _perform_attack_combo() -> void:
	match combo_count:
		0:
			animation_player.play("attackCombo1")
			play_timer(0.56)
			combo_count = 1
		1:
			animation_player.play("attackCombo3")
			play_timer(0.56)
			combo_count = 2
		2:
			animation_player.play("attackCombo3")
			play_timer(0.56)
			combo_count = 0 
			
# --- FUNÇÃO MODIFICADA ---
func _perform_attack_fireball() -> void:
	animation_player.play("root_bola_de_fogo")
	
	# Usa a nova variável de cooldown em vez do valor fixo 0.53
	play_timer(fireball_cooldown) 
	
	combo_count = 0

# --- FUNÇÃO NOVA ---
func _spawn_and_throw_fireball() -> void:
	if not fireball_scene or not player or not is_instance_valid(player):
		printerr("Cena da bola de fogo ou player não definidos.")
		return
		
	var fireball = fireball_scene.instantiate()
	
	get_tree().root.add_child(fireball)
	fireball.global_position = fireball_spawn_point.global_position
	
	var target_pos = player.global_position + Vector3.UP * 1.0 # Mirar no "peito"
	var direction_to_player = (target_pos - fireball.global_position).normalized()
	
	if fireball.has_method("set_target_direction"):
		fireball.set_target_direction(direction_to_player)
	elif "target_direction" in fireball:
		fireball.target_direction = direction_to_player
	else:
		printerr("Script da Bola de Fogo não tem 'target_direction' ou 'set_target_direction'.")

func in_self_damage(player_attack: Vector2) -> void:
	health_enemy -= randi_range(player_attack.x, player_attack.y)
	barra_vida.value = health_enemy
	print(health_enemy)
	
	if health_enemy <= 0:
		Globais.update_quant_Inimigo(1)
		await get_tree().process_frame
		queue_free()

#=============================================================================
# SINAIS (SIGNALS)
#=============================================================================

func _on_detection_area_body_entered(body: Node3D) -> void:
	if body == player:
		enter_state(State.CHASE)

func _on_detection_area_body_exited(body: Node3D) -> void:
	if body == player:
		enter_state(State.IDLE)

func _on_weapon_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		Globais.damage_player(attack_damage_range.x, attack_damage_range.y)
		
		if body.has_method("in_self_damage"):
			body.in_self_damage(attack_damage_range)

		var spawn_location = body.global_transform.origin
		spawn_location.y += 1

#=============================================================================
# FUNÇÕES AUXILIARES
#=============================================================================

func play_step_sound() -> void:
	ray_cast_3d.force_raycast_update()

	if not ray_cast_3d.is_colliding():
		return

	var collider = ray_cast_3d.get_collider()
	
	for group_name in step_sounds_group:
		if collider.is_in_group(group_name):
			foot_steps.stream = step_sounds_group[group_name]
			foot_steps.play()
			return

func play_timer(time: float):
	attack_timer.stop()
	attack_timer.wait_time = time
	attack_timer.one_shot = true
	attack_timer.start()

func _setup_animation_blends() -> void:
	var anims = ["idlev3", "runv4", "attackCombo1", "attackCombo2", "attackCombo3", "root_bola_de_fogo"]
	for from_anim in anims:
		for to_anim in anims:
			if from_anim != to_anim:
				animation_player.set_blend_time(from_anim, to_anim, 0.3)
