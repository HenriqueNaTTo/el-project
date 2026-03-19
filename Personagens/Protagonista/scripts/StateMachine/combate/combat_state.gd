extends State

var anim_tree_root_condition: String = ""
var anim_tree_move_condition: String = ""

var combo_count: int = 0
var max_combo: int = 0
var attack_speed: float = 4.0

func enter() -> void:
	combo_count = 0
	player.current_speed = attack_speed
	_set_tree_condition(anim_tree_root_condition, true)
	_set_tree_condition(anim_tree_move_condition, false)
	_execute_attack()

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("basicAttack"):
		if not player.attackTimer.is_stopped() and combo_count < max_combo - 1:
			combo_count += 1
			_execute_attack()

func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity += (player.get_gravity() * 2) * delta

	player.apply_movement_and_rotation(Vector3.ZERO, delta)

	if player.attackTimer.is_stopped():
		transitioned.emit(self, "BasicMove")

func exit() -> void:
	combo_count = 0
	_set_tree_condition(anim_tree_root_condition, false)
	_set_tree_condition(anim_tree_move_condition, true)
	_clear_combo_conditions()

func _play_timer_from_anim(anim_name: String) -> void:
	var anim: Animation = player.animation_player.get_animation(anim_name)
	if anim:
		player.attackTimer.wait_time = anim.length
		player.attackTimer.one_shot = true
		player.attackTimer.start()
	else:
		push_warning("CombatState: animação '%s' não encontrada." % anim_name)
		player.attackTimer.wait_time = 0.5
		player.attackTimer.one_shot = true
		player.attackTimer.start()

func _set_tree_condition(param: String, value: bool) -> void:
	if param != "":
		player.animation_tree[param] = value

func _execute_attack() -> void:
	push_error("CombatState._execute_attack() deve ser implementado pela subclasse.")

func _clear_combo_conditions() -> void:
	pass
