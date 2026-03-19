extends "res://Personagens/Protagonista/scripts/StateMachine/combate/combat_state.gd"

const ANIM_SHOOT := "bow_shoot"
const TREE_SHOOT  := "parameters/arcoAtaque/conditions/shoot"

@export var arrow_scene: PackedScene
@export var arrow_spawn_path: NodePath

func _ready() -> void:
	max_combo = 1
	attack_speed = 0.0
	anim_tree_root_condition = "parameters/conditions/isArcoAtaque"
	anim_tree_move_condition  = "parameters/conditions/basicMove"

func _execute_attack() -> void:
	_clear_combo_conditions()
	player.animation_tree[TREE_SHOOT] = true
	_play_timer_from_anim(ANIM_SHOOT)

# Sem combo — ignora cliques extras
func handle_input(_event: InputEvent) -> void:
	pass

func _clear_combo_conditions() -> void:
	player.animation_tree[TREE_SHOOT] = false

# Conecte ao sinal animation_finished do AnimationPlayer
func spawn_arrow() -> void:
	if arrow_scene == null:
		push_warning("BowAttackState: arrow_scene não atribuída.")
		return
		
	var spawn_node: Node3D = player.get_node_or_null(arrow_spawn_path)
	if spawn_node == null:
		push_warning("BowAttackState: arrow_spawn_path inválido.")
		return
		
	var arrow: Node3D = arrow_scene.instantiate()
	player.get_parent().add_child(arrow)
	arrow.global_transform = spawn_node.global_transform
	
	if arrow.has_method("set_direction"):
		arrow.set_direction(-player.mesh_node.global_basis.z)
