extends Node
class_name State

var player: Player
signal transitioned(state: State, new_state_name: String)

func enter() -> void:
	player = Globais.playerInst
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass
