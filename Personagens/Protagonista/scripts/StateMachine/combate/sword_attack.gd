extends "res://Personagens/Protagonista/scripts/StateMachine/combate/combat_state.gd"

# Nomes das animações no AnimationPlayer — ajuste se os seus tiverem nomes diferentes
const ANIM_ATTACK_1 := "sword_attack1"
const ANIM_ATTACK_2 := "sword_attack2"
const ANIM_ATTACK_3 := "sword_attack3"

# Parâmetros dentro do nó espadaAtaque no AnimTree
# Quando configurar a BlendTree interna, esses paths precisam bater
const TREE_ATTACK_1 := "parameters/espadaAtaque/conditions/attack1"
const TREE_ATTACK_2 := "parameters/espadaAtaque/conditions/attack2"
const TREE_ATTACK_3 := "parameters/espadaAtaque/conditions/attack3"


func _ready() -> void:
	max_combo = 3
	attack_speed = 4.0
	# "isEspadaAtaque" é a condition da seta BasicMove → espadaAtaque no AnimTree
	anim_tree_root_condition = "parameters/conditions/isEspadaAtaque"
	# "basicMove" é a condition da seta espadaAtaque → BasicMove
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
