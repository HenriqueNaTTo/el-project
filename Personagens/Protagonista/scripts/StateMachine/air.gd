extends State

func enter() -> void:
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		player.velocity.y = player.JUMP_VELOCITY

func physics_update(delta: float) -> void:
	# Aplica gravidade
	player.velocity += (player.get_gravity() * 2) * delta
	
	# Permite movimento no ar
	var direction = player.get_movement_direction()
	player.apply_movement_and_rotation(direction, delta)

	if player.is_on_floor():
		if direction == Vector3.ZERO:
			transitioned.emit(self, "Idle")
		else:
			transitioned.emit(self, "Move")
