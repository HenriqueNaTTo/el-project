# DungeonGenerator.gd (Versão Corrigida)
@tool
extends Node3D

#@onready var navigation_region_3d: NavigationRegion3D = $".."

# --- VARIÁVEIS DE CONTROLE ---
@export_group("Configurações da Dungeon")
@export var generate_on_start: bool = true

@export var start_room_scene: PackedScene
@export var end_room_scene: PackedScene
@export var room_scenes: Array[PackedScene] 
@export_range(3, 100, 1) var min_number_of_rooms: int = 8
@export_range(3, 100, 1) var max_number_of_rooms: int = 15
@export var room_size: Vector3 = Vector3(10, 5, 10)

@export var safety_margin: float = 1.0

@export_group("Portas Bloqueadas")
@export var blocked_door_scene: PackedScene
@export var place_blocked_doors: bool = true

@export_group("Debug")
@export var enable_debug_prints: bool = true

@export_group("Ações no Editor")
@export var generate_dungeon_button: bool = false:
	set(value):
		if value:
			generate_dungeon()

@export var clear_dungeon_button: bool = false:
	set(value):
		if value:
			clear_dungeon()

# --- LÓGICA INTERNA ---
var _placed_rooms = []
var _grid = {}
var _connected_doors = []
var _blocked_doors = []

func _ready():
	if not Engine.is_editor_hint() and generate_on_start:
		generate_dungeon()
	
	await get_tree().process_frame
	Globais.playerInst.fundo_morte.visible = false
	Globais.playerInst.selecionar_level.visible = false

func clear_dungeon():
	if enable_debug_prints:
		print("Limpando dungeon...")
	
	for i in range(get_child_count() - 1, -1, -1):
		var child = get_child(i)
		if child.has_method("get_door_global_transforms") or child.name.begins_with("Room") or child.name.begins_with("BlockedDoor"):
			child.queue_free()
			
	_placed_rooms.clear()
	_grid.clear()
	_connected_doors.clear()
	_blocked_doors.clear()
	
	if enable_debug_prints:
		print("Dungeon limpa.")

func generate_dungeon():
	if not start_room_scene or not end_room_scene or room_scenes.is_empty():
		push_warning("Uma ou mais cenas de salas (Start, End, Room Scenes) não foram definidas.")
		return
	if min_number_of_rooms > max_number_of_rooms:
		push_warning("'Min Number Of Rooms' não pode ser maior que 'Max Number Of Rooms'.")
		return
	
	clear_dungeon()
	
	var adjusted_min = max(3, min_number_of_rooms)
	var adjusted_max = max(adjusted_min, max_number_of_rooms)
	var target_number_of_rooms = randi_range(adjusted_min, adjusted_max)
	
	if enable_debug_prints:
		print("Iniciando geração... Meta: ", target_number_of_rooms, " salas (entre ", adjusted_min, " e ", adjusted_max, ").")
	
	if not _place_room(start_room_scene, Transform3D.IDENTITY):
		push_error("Falha ao colocar a sala inicial.")
		return
		
	var intermediate_rooms_needed = target_number_of_rooms - 2  # -1 para inicial, -1 para final
	var intermediate_rooms_placed = 0
	var attempts = 0
	var max_attempts_per_room = 50
	
	while intermediate_rooms_placed < intermediate_rooms_needed and attempts < max_attempts_per_room * intermediate_rooms_needed:
		var random_scene = room_scenes.pick_random()
		
		if _try_place_adjacent_room(random_scene):
			intermediate_rooms_placed += 1
			attempts = 0  # Reset attempts após sucesso
			if enable_debug_prints:
				print("Sala intermediária ", intermediate_rooms_placed, "/", intermediate_rooms_needed, " colocada.")
		else:
			attempts += 1
	
	# Colocar sala final
	var end_room_placed = false
	attempts = 0
	var max_end_room_attempts = 100
	
	while not end_room_placed and attempts < max_end_room_attempts:
		if _try_place_adjacent_room(end_room_scene):
			end_room_placed = true
			if enable_debug_prints:
				print("Sala final colocada.")
		else:
			attempts += 1
	
	if not end_room_placed:
		push_warning("Não foi possível encontrar um local para a sala final.")
	
	var total_rooms = _placed_rooms.size()
	
	if total_rooms < adjusted_min:
		push_warning("Não foi possível atingir o número mínimo de salas. Geradas: ", total_rooms, " / Mínimo: ", adjusted_min)
	elif enable_debug_prints:
		print("✓ Meta atingida!")
		
	if enable_debug_prints:
		print("Geração concluída. Total de ", total_rooms, " salas colocadas.")
	
	if place_blocked_doors and blocked_door_scene:
		_place_blocked_doors()
		if enable_debug_prints:
			print("Portas bloqueadas colocadas: ", _blocked_doors.size())
			
	var quantInimigo = get_tree().get_nodes_in_group("enemy").size()
	var quantBau = get_tree().get_nodes_in_group("bau").size()
	
	Globais.quantMaxBau = quantBau
	Globais.quantMaxInimigos = quantInimigo

	if enable_debug_prints:
		print("Total de inimigos na dungeon: ", quantInimigo)
		print("Total de baús na dungeon: ", quantBau)
	
func _try_place_adjacent_room(scene_to_place: PackedScene) -> bool:
	if _placed_rooms.is_empty(): 
		return false
	
	# Tentar várias salas existentes para aumentar as chances de sucesso
	var existing_rooms = _placed_rooms.duplicate()
	existing_rooms.shuffle()
	
	for existing_room in existing_rooms:
		var doors = existing_room.get_children().filter(func(c): return c is Marker3D)
		
		if doors.is_empty(): 
			continue
			
		# Embaralhar as portas para tentar diferentes orientações
		doors.shuffle()
		
		for exit_door_marker in doors:
			# Verificar se esta porta já está conectada
			if _is_door_connected(existing_room, exit_door_marker):
				continue
				
			var new_room_instance = scene_to_place.instantiate()
			var new_room_doors = new_room_instance.get_children().filter(func(c): return c is Marker3D)
			
			if new_room_doors.is_empty(): 
				new_room_instance.queue_free()
				continue
				
			# Tentar diferentes portas de entrada na nova sala
			for entry_door_marker in new_room_doors:
				var new_transform = _calculate_new_room_transform(existing_room, exit_door_marker, entry_door_marker)
				
				# Verificação mais rigorosa de colisão
				if _is_position_valid(new_transform.origin, new_room_instance):
					new_room_instance.queue_free()
					
					# NOVO: Registrar conexão das portas ANTES de colocar a sala
					var new_room = _place_room(scene_to_place, new_transform)
					if new_room != null:
						_register_door_connection(existing_room, exit_door_marker)
						_register_door_connection(new_room, entry_door_marker)
						return true
			
			new_room_instance.queue_free()
	
	return false

func _is_position_valid(world_pos: Vector3, room_instance: Node3D) -> bool:
	var grid_pos = _world_to_grid(world_pos)
	
	# Verificar se já existe uma sala nesta posição exata
	if _grid.has(grid_pos):
		return false
	
	# Verificar posições adjacentes para evitar sobreposições
	var positions_to_check = [
		grid_pos,
		grid_pos + Vector3i(1, 0, 0), grid_pos + Vector3i(-1, 0, 0),
		grid_pos + Vector3i(0, 0, 1), grid_pos + Vector3i(0, 0, -1),
		grid_pos + Vector3i(1, 0, 1), grid_pos + Vector3i(-1, 0, -1),
		grid_pos + Vector3i(1, 0, -1), grid_pos + Vector3i(-1, 0, 1)
	]
	
	for pos in positions_to_check:
		if _grid.has(pos):
			var existing_room = _grid[pos]
			var distance = world_pos.distance_to(existing_room.global_position)
			var min_distance = (room_size.length() / 2.0) + safety_margin
			
			if distance < min_distance:
				if enable_debug_prints:
					print("Posição inválida: muito próxima de sala existente. Distância: ", distance, " / Mínima: ", min_distance)
				return false
	
	return true

func _place_room(scene: PackedScene, transform: Transform3D) -> Node3D:
	var room_instance = scene.instantiate()
	
	if not Engine.is_editor_hint():
		pass
	else:
		room_instance.owner = get_tree().edited_scene_root
		
	add_child(room_instance)
	room_instance.transform = transform
	_placed_rooms.append(room_instance)
	
	var grid_pos = _world_to_grid(transform.origin)
	_grid[grid_pos] = room_instance
	
	return room_instance

func _calculate_new_room_transform(existing_room: Node3D, exit_door: Marker3D, entry_door: Marker3D) -> Transform3D:
	# Obter a transformação global da porta de saída
	var global_exit_transform = exit_door.global_transform
	var exit_forward = global_exit_transform.basis.z.normalized()
	var entry_forward_local = entry_door.transform.basis.z.normalized()
	
	# A nova sala deve "olhar" na direção oposta à porta de saída
	var target_forward = -exit_forward
	
	# CORREÇÃO: Garantir que a rotação seja apenas no plano horizontal
	target_forward.y = 0
	target_forward = target_forward.normalized()
	
	var entry_horizontal = Vector3(entry_forward_local.x, 0, entry_forward_local.z).normalized()
	
	# Calcular rotação necessária usando look_at (mais confiável)
	var temp_transform = Transform3D.IDENTITY
	temp_transform = temp_transform.looking_at(target_forward, Vector3.UP)
	var entry_transform = Transform3D.IDENTITY
	entry_transform = entry_transform.looking_at(entry_horizontal, Vector3.UP)
	
	# Combinar rotações
	var rotation_diff = temp_transform.basis * entry_transform.basis.inverse()
	
	# Calcular posição: porta de saída - posição rotacionada da porta de entrada
	var rotated_entry_door_pos = rotation_diff * entry_door.position
	var new_origin = global_exit_transform.origin - rotated_entry_door_pos
	
	# CORREÇÃO: Forçar altura Y igual à sala existente
	new_origin.y = existing_room.global_position.y
	
	return Transform3D(rotation_diff, new_origin)

func _world_to_grid(world_pos: Vector3) -> Vector3i:
	var gx = roundi(world_pos.x / room_size.x)
	var gy = roundi(world_pos.y / room_size.y) 
	var gz = roundi(world_pos.z / room_size.z)
	
	return Vector3i(gx, gy, gz)

# NOVO: Registrar que uma porta foi conectada a outra sala
func _register_door_connection(room: Node3D, door: Marker3D):
	var door_info = {
		"room": room,
		"door": door,
		"door_name": door.name,
		"room_name": room.name,
		"room_path": room.get_path(),
		"door_path": door.get_path()
	}
	_connected_doors.append(door_info)
	
	if enable_debug_prints:
		print("Porta conectada registrada: ", room.name, " -> ", door.name, " (Path: ", door.get_path(), ")")

# NOVO: Verificar se uma porta específica já está conectada
func _is_door_connected(room: Node3D, door: Marker3D) -> bool:
	for connected_door in _connected_doors:
		# Verificar por referência direta para maior precisão
		if connected_door.room == room and connected_door.door == door:
			return true
		
		# Verificação adicional por nome (para debug)
		if connected_door.room.name == room.name and connected_door.door.name == door.name:
			if enable_debug_prints:
				print("Encontrada correspondência por nome: ", room.name, " -> ", door.name)
			return true
			
	return false

# NOVO: Colocar portas bloqueadas nas saídas não conectadas
func _place_blocked_doors():
	if not blocked_door_scene:
		return
	
	var total_doors = 0
	var connected_count = 0
	var blocked_count = 0
	
	if enable_debug_prints:
		print("=== ANALISANDO PORTAS PARA BLOQUEIO ===")
		print("Portas conectadas registradas: ", _connected_doors.size())
		
	for room in _placed_rooms:
		var doors = room.get_children().filter(func(c): return c is Marker3D)
		total_doors += doors.size()
		
		for door in doors:
			# Verificar se esta porta foi conectada
			var is_connected = _is_door_connected(room, door)
			
			if is_connected:
				connected_count += 1
				if enable_debug_prints:
					print("PORTA CONECTADA: ", room.name, " -> ", door.name, " (NÃO será bloqueada)")
			else:
				# Se não foi conectada, colocar porta bloqueada
				if enable_debug_prints:
					print("PORTA NÃO CONECTADA: ", room.name, " -> ", door.name, " (SERÁ bloqueada)")
				_place_blocked_door(room, door)
				blocked_count += 1
	
	if enable_debug_prints:
		print("=== RESUMO FINAL DAS PORTAS ===")
		print("  Total de portas: ", total_doors)
		print("  Portas conectadas: ", connected_count)
		print("  Portas bloqueadas: ", blocked_count)
	
	# Limpar portas bloqueadas que possam ter sido colocadas erroneamente
	_cleanup_misplaced_blocked_doors()

# NOVO: Colocar uma porta bloqueada específica
func _place_blocked_door(room: Node3D, door_marker: Marker3D):
	var blocked_door_instance = blocked_door_scene.instantiate()
	
	if not Engine.is_editor_hint():
		pass
	else:
		blocked_door_instance.owner = get_tree().edited_scene_root
	
	# Configurar nome para facilitar identificação
	blocked_door_instance.name = "BlockedDoor_" + room.name + "_" + door_marker.name
	
	# Posicionar a porta bloqueada na mesma posição da porta
	add_child(blocked_door_instance)
	
	# Usar a mesma transformação global do marcador da porta
	blocked_door_instance.global_transform = door_marker.global_transform
	
	_blocked_doors.append(blocked_door_instance)
	
	if enable_debug_prints:
		print("Porta bloqueada colocada em: ", room.name, " -> ", door_marker.name)

# NOVO: Função para limpar portas bloqueadas erroneamente colocadas
func _cleanup_misplaced_blocked_doors():
	for blocked_door in _blocked_doors.duplicate():
		# Verificar se esta porta bloqueada está em uma porta que deveria estar conectada
		var door_marker = _find_door_marker_for_blocked_door(blocked_door)
		if door_marker and _is_door_connected(door_marker.get_parent(), door_marker):
			if enable_debug_prints:
				print("Removendo porta bloqueada erroneamente colocada: ", blocked_door.name)
			_blocked_doors.erase(blocked_door)
			blocked_door.queue_free()

# NOVO: Encontrar o marcador de porta correspondente a uma porta bloqueada
func _find_door_marker_for_blocked_door(blocked_door: Node3D) -> Marker3D:
	var blocked_door_name = blocked_door.name
	# Extrair informações do nome (formato: "BlockedDoor_RoomName_DoorName")
	if "BlockedDoor_" in blocked_door_name:
		var parts = blocked_door_name.split("_")
		if parts.size() >= 3:
			var room_name = parts[1]
			var door_name = parts[2]
			
			# Encontrar a sala
			for room in _placed_rooms:
				if room.name == room_name:
					# Encontrar a porta
					for child in room.get_children():
						if child is Marker3D and child.name == door_name:
							return child
	return null
