extends Node3D

@export var light_color : Color = Color(1, 0.9, 0.7, 0.3)  # Cor suave amarelada
@export var density : float = 0.5  # Densidade da névoa
@export var light_intensity : float = 2.0  # Intensidade da luz
@export var particle_speed : float = 0.1  # Velocidade das partículas

var particles : GPUParticles3D

func _ready():
	# Configura o sistema de partículas
	particles = GPUParticles3D.new()
	add_child(particles)
	
	# Configuração do material de partículas
	var particle_material = ParticleProcessMaterial.new()
	particle_material.direction = Vector3.ZERO  # Movimento aleatório
	particle_material.spread = 1.0  # Dispersão total
	particle_material.gravity = Vector3.ZERO  # Sem gravidade
	particle_material.initial_velocity_min = particle_speed
	particle_material.initial_velocity_max = particle_speed * 1.5
	particle_material.color = light_color
	
	# Configuração do processo de emissão
	particles.process_material = particle_material
	particles.amount = 100  # Número de partículas
	particles.lifetime = 2.0  # Tempo de vida das partículas
	particles.explosiveness = 0.0  # Emissão contínua
	particles.randomness = 0.5  # Movimento aleatório
	
	# Definir um mesh simples para as partículas
	var particle_mesh = QuadMesh.new()
	particle_mesh.size = Vector2(0.1, 0.1)  # Tamanho pequeno
	particles.draw_pass_1 = particle_mesh
	
	# Configuração do material de renderização
	var render_material = particles.draw_pass_1.material
	if render_material == null:
		render_material = StandardMaterial3D.new()
	render_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	render_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particles.draw_pass_1.material = render_material
	
	# Iniciar emissão
	particles.emitting = true

func _process(delta):
	# Animação suave da densidade e cor
	particles.process_material.color.a = light_color.a * (1.0 + sin(Time.get_ticks_msec() * 0.01)) * 0.5
