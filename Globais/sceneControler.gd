extends Node

var player: Player = null
var current_scene = null
var loading_interface: Loading

func _ready() -> void:
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	
	# Carrega a interface de loading
	_setup_loading_interface()

func _setup_loading_interface():
	# Cria a interface de loading
	loading_interface = preload("res://Scenes/interface/loading_screen.tscn").instantiate()
	await get_tree().process_frame
	# Adiciona à árvore mas mantém invisível
	get_tree().root.add_child(loading_interface)
	loading_interface.visible = false

func change_scene(new_scene_path: String, player_spawn_point: Vector3 = Vector3.ZERO):
	# Mostra a interface de loading
	_show_loading()
	
	# Aguarda um frame para garantir que a interface seja exibida
	await get_tree().process_frame
	
	# Guarda a referência ao player apenas se ainda não tiver
	if player == null:
		player = Globais.playerInst
		
		# Só remove o player do parent se ele tiver um parent
		if player.get_parent():
			player.get_parent().remove_child(player)
	else:
		# Se já temos uma referência ao player, apenas remove ele da cena atual
		if player.get_parent():
			player.get_parent().remove_child(player)
	
	# Inicia o carregamento da nova cena usando ResourceLoader
	ResourceLoader.load_threaded_request(new_scene_path)
	
	# Aguarda o carregamento completo
	var next_scene_resource = await _wait_for_scene_load(new_scene_path)
	
	# Instancia a nova cena
	var next_scene = next_scene_resource.instantiate()
	
	# Remove a cena atual
	current_scene.queue_free()
	
	# Adiciona a nova cena
	get_tree().root.add_child(next_scene)
	current_scene = next_scene
	
	# Encontra o ponto de spawn
	var spawn_point = current_scene.get_node_or_null("PlayerSpawnPoint")
	if spawn_point:
		player_spawn_point = spawn_point.global_transform.origin
	
	# Adiciona o player à nova cena
	current_scene.add_child(player)
	player.global_transform.origin = player_spawn_point
	
	# Aguarda um frame para garantir que tudo esteja carregado
	await get_tree().process_frame
	
	# Esconde a interface de loading
	_hide_loading()

func _wait_for_scene_load(scene_path: String) -> PackedScene:
	var progress = []
	var status = ResourceLoader.load_threaded_get_status(scene_path, progress)
	
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		# Atualiza o progresso na interface de loading se disponível
		if loading_interface and loading_interface.has_method("update_progress"):
			loading_interface.update_progress(progress[0])
		
		# Aguarda um frame antes de verificar novamente
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(scene_path, progress)
	
	# Verifica se o carregamento foi bem-sucedido
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		return ResourceLoader.load_threaded_get(scene_path)
	else:
		push_error("Falha ao carregar a cena: " + scene_path)
		return null

func _show_loading():
	if loading_interface:
		loading_interface.load_text()
		loading_interface.load_image()
		
		loading_interface.visible = true
		# Move para o topo da hierarquia para garantir que fique visível
		loading_interface.move_to_front()

func _hide_loading():
	if loading_interface:
		loading_interface.visible = false
