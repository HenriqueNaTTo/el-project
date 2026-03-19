extends State

func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		transitioned.emit(self, "Air")
		return

	var is_running = Input.is_action_pressed("run")
	player.current_speed = player.RUN_SPEED if is_running else player.SPEED
	
	player.animation_tree["parameters/BasicMove/conditions/idle"] = false
	player.animation_tree["parameters/BasicMove/conditions/walk"] = !is_running
	player.animation_tree["parameters/BasicMove/conditions/run"] = is_running

	var direction = player.get_movement_direction()
	
	if direction == Vector3.ZERO:
		transitioned.emit(self, "Idle")
	else:
		player.apply_movement_and_rotation(direction, delta)

	if Input.is_action_just_pressed("jump"):
		transitioned.emit(self, "Air")
		
	if Input.is_action_just_pressed("basicAttack"):
		transitioned.emit(self, "SwordAttack")
