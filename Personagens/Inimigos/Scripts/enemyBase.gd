extends CharacterBody3D

class_name Enemy

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

@onready var barra_vida: TextureProgressBar = $SubViewport/vida/barraVida

# --- VARIÁVEIS EXPORTADAS ---
@export var move_speed: float = 12.0
@export var attack_range: float = 8.0
@export var attack_damage_range: Vector2 = Vector2(15, 25)
@export var health_enemy: int = 100

@export var max_sword_combo: int = 3

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
	# Otimização: Obter o jogador uma vez e verificar se ele existe.
	var player_nodes = get_tree().get_nodes_in_group("player")
	if not player_nodes.is_empty():
		player = player_nodes[0]

	# Conectar sinais a funções que mudam o estado.
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	weapon_area.body_entered.connect(_on_weapon_area_body_entered)
	
	_setup_animation_blends()
	
	await get_tree().process_frame
	setup_waypoints()
	
	#print ("lista waypoints: ", waypoints)
	# Inicia no estado IDLE
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
				enter_state(State.PATROL)
	
		State.PATROL:
			animation_player.play("walkv4")
			
			if(waypoints.size() == 0 or waypoint_container == null):
				enter_state(State.IDLE)
				return
			
			var target_waypoint = waypoints[current_waypoint_index]
			look_at(Vector3(target_waypoint.x, global_position.y, target_waypoint.z), Vector3.UP)
			
			var direction = (target_waypoint - global_position).normalized()
			velocity.x = direction.x * (move_speed - 2.0)
			velocity.z = direction.z * (move_speed - 2.0)
			
			# Verifica se chegou ao waypoint
			var distance = global_position.distance_to(target_waypoint)
			if distance < waypoint_reached_distance:
				advance_to_next_waypoint()
				if(current_waypoint_index == 0 or current_waypoint_index == waypoints.size()):
					enter_state(State.IDLE)  # Pausa breve no waypoint
		
		State.CHASE:
			animation_player.play("Runv2")
		
			if not player:
				enter_state(State.RETURN_TO_PATROL)
				return
		
			navigation_agent.set_target_position(player.global_position)
			var next_pos: Vector3 = navigation_agent.get_next_path_position()
			velocity = global_position.direction_to(next_pos) * move_speed
			
			look_at(Vector3(navigation_agent.get_next_path_position().x, global_position.y, navigation_agent.get_next_path_position().z), Vector3.UP)
		
			if global_position.distance_to(player.global_position) < attack_range:
				enter_state(State.ATTACK)
			elif navigation_agent.is_navigation_finished():
				enter_state(State.RETURN_TO_PATROL) # Volta para o path em vez de IDLE
	
		State.ATTACK:
			velocity = Vector3.ZERO
		
			if not player:
				enter_state(State.RETURN_TO_PATROL) # Volta para o path em vez de IDLE
				return
		
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
		
			if global_position.distance_to(player.global_position) > attack_range:
				enter_state(State.CHASE)
			else:
				_perform_attack_combo()
	
		State.RETURN_TO_PATROL:
			animation_player.play("walkv4")
			
			look_at(Vector3(target_return_position.x, global_position.y, target_return_position.z), Vector3.UP)
		
			# Usa NavigationAgent para navegar até o ponto do path
			navigation_agent.set_target_position(waypoints[0])
			var next_pos: Vector3 = navigation_agent.get_next_path_position()
			velocity = global_position.direction_to(next_pos) * move_speed
			
			# Verifica se chegou próximo ao ponto do path
			var distance_to_target = global_position.distance_to(target_return_position)
			if distance_to_target < 1.5 or navigation_agent.is_navigation_finished():
				# Reposiciona o PathFollow para onde parou
				current_waypoint_index = patrol_start_index
				enter_state(State.PATROL)

	move_and_slide()
	
#=============================================================================
# MÁQUINA DE ESTADOS
#=============================================================================

func enter_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	var old_state = current_state
	current_state = new_state
	
	# Reset timers quando necessário
	if old_state == State.IDLE:
		idle_timer = 0.0

	# A lógica específica de cada estado é executada nos handlers
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
			target_return_position = patrol_start_position

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
	
	# Se está indo para frente
	if patrol_direction == 1:
		current_waypoint_index += 1
		#print("waypoint atual: ", current_waypoint_index)
		# Se chegou ao último waypoint, inverte a direção
		if current_waypoint_index >= waypoints.size():
			current_waypoint_index = waypoints.size() - 2
			patrol_direction = -1
	
	# Se está voltando
	else:
		current_waypoint_index -= 1
		# Se chegou ao primeiro waypoint, inverte a direção
		#print("waypoint atual: ", current_waypoint_index)
		if current_waypoint_index < 0:
			current_waypoint_index = 1
			patrol_direction = 1

func _perform_attack_combo() -> void:
	if not attack_timer.is_stopped():
		return

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
		
		#Globais.spawn_blood(spawn_location)

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
	var anims = ["idlev3", "runv4", "attackCombo1", "attackCombo2", "attackCombo3"]
	for from_anim in anims:
		for to_anim in anims:
			if from_anim != to_anim:
				animation_player.set_blend_time(from_anim, to_anim, 0.3)
