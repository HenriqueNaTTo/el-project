extends Path3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var path = self
	var curve = path.curve
	var ground_y = 0.0  # Altura do chão
	
	for i in range(curve.get_point_count()):
		var point = curve.get_point_position(i)
		point.y = ground_y
		curve.set_point_position(i, point)
