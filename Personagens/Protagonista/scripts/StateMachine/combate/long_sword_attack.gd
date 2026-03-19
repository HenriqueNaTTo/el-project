extends "res://Personagens/Protagonista/scripts/StateMachine/combate/combat_state.gd"

const ANIM_ATTACK_1 := "longsword_attack1"
const ANIM_ATTACK_2 := "longsword_attack2"
const ANIM_ATTACK_3 := "longsword_attack3"

const TREE_ATTACK_1 := "parameters/espadaLongaAtaque/conditions/attack1"
const TREE_ATTACK_2 := "parameters/espadaLongaAtaque/conditions/attack2"
const TREE_ATTACK_3 := "parameters/espadaLongaAtaque/conditions/attack3"


func _ready() -> void:
	max_combo = 3
	attack_speed = 2.5
	anim_tree_root_condition = "parameters/conditions/isEspadaLongaAtaque"
	anim_tree_move_condition  = "parameters/conditions/basicMove"


func _execute_attack() -> void:
	_clear_combo_conditions()
	match combo_count:
		0:
			player.animation_tree[TREE_ATTACK_1] = true
			_play_timer_from_anim(ANIM_ATTACK_1)
		1:
			player.animation_tree[TREE_ATTACK_2] = true
			_play_timer_from_anim(ANIM_ATTACK_2)
		2:
			player.animation_tree[TREE_ATTACK_3] = true
			_play_timer_from_anim(ANIM_ATTACK_3)


func _clear_combo_conditions() -> void:
	player.animation_tree[TREE_ATTACK_1] = false
	player.animation_tree[TREE_ATTACK_2] = false
	player.animation_tree[TREE_ATTACK_3] = false
