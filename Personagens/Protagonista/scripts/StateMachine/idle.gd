extends State

func enter() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	
	player.current_speed = player.SPEED
	player.animation_tree["parameters/BasicMove/conditions/idle"] = true
	player.animation_tree["parameters/BasicMove/conditions/walk"] = false
	player.animation_tree["parameters/BasicMove/conditions/run"] = false
	player.animation_tree["parameters/conditions/basicMove"] = true

func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		transitioned.emit(self, "Air")
		return
	
	player.move_and_slide()

	# Desacelera até parar
	player.apply_movement_and_rotation(Vector3.ZERO, delta)

	if Input.get_vector("left", "right", "up", "down") != Vector2.ZERO:
		transitioned.emit(self, "Move")
		
	if Input.is_action_just_pressed("jump"):
		transitioned.emit(self, "Air")
		
	if Input.is_action_just_pressed("basicAttack"):
		transitioned.emit(self, "SwordAttack")
