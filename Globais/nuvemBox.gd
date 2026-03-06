extends CSGBox3D

@export var cloud_to_spawn: int = 50
@export var cloud_scene: PackedScene

var random_number = RandomNumberGenerator.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	spawn_clouds()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func spawn_clouds():
	while  cloud_to_spawn >= 0:
		cloud_to_spawn -= 1
		
		var x: float = random_number.randf_range(size.x/2, -size.x/2)
		var y: float = random_number.randf_range(size.y/2, -size.y/2)
		var z: float = random_number.randf_range(size.z/2, -size.z/2)
		
		var spawn_pos: Vector3 = Vector3(x, y, z)
		
		var cloud := cloud_scene.instantiate()
		add_child(cloud)
		cloud.global_position = self.global_position + spawn_pos
