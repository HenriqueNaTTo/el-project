extends SpringArm3D

func _ready() -> void:
	add_excluded_object(get_parent())
	
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		add_excluded_object(player)
