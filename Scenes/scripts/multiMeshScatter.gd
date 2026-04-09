extends Node3D

@onready var multimesh_instance: MultiMeshInstance3D = $MultiMeshInstance3D
# Defina o quão "plano" o chão precisa ser. 
# 0.8 permite rampas suaves. 0.99 permite apenas chão quase perfeitamente reto.
@export var min_up_slope: float = 0.8 

func _ready():
	# Configurações básicas do MultiMesh (exemplo)
	var mm = multimesh_instance.multimesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = 0 # Vamos aumentar conforme achamos pontos válidos
	
	_generate_placement()

func _generate_placement():
	var space_state = get_world_3d().direct_space_state
	var valid_transforms = []
	
	# Exemplo testando 100 posições aleatórias
	for i in range(100):
		# Escolha um ponto alto aleatório acima do seu objeto/terreno
		var random_x = randf_range(-10.0, 10.0)
		var random_z = randf_range(-10.0, 10.0)
		var ray_origin = Vector3(random_x, 50.0, random_z)
		var ray_end = ray_origin + Vector3.DOWN * 100.0
		
		# Dispara o raycast de cima para baixo
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		var result = space_state.intersect_ray(query)
		
		if result:
			# A MÁGICA ACONTECE AQUI:
			var surface_normal = result.normal
			
			# Se o dot product for maior que o nosso limite, é o "topo"
			if surface_normal.dot(Vector3.UP) >= min_up_slope:
				var t = Transform3D()
				t.origin = result.position
				valid_transforms.append(t)
				
	# Aplica os transforms válidos ao MultiMesh
	multimesh_instance.multimesh.instance_count = valid_transforms.size()
	for i in range(valid_transforms.size()):
		multimesh_instance.multimesh.set_instance_transform(i, valid_transforms[i])
