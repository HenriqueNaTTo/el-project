@tool
extends DirectionalLight3D

@export_category("Configurações do Editor")
@export var rodar_no_editor: bool = false # Liga/desliga o tempo passando sozinho no editor

@export_category("Configurações do Ciclo")
@export var duracao_do_dia_segundos: float = 60.0
@export var tempo_atual: float = 0.0 # Arraste este valor no Inspector para testar a luz manualmente!

@export_category("Luzes")
@export var luz_da_lua: DirectionalLight3D
@export var energia_max_sol: float = 1.0
@export var energia_max_lua: float = 0.3

func _process(delta: float) -> void:
	# 1. Faz o tempo passar apenas no jogo OU se a opção "rodar_no_editor" estiver ativa
	if not Engine.is_editor_hint() or rodar_no_editor:
		tempo_atual += delta
	
	# 2. Calcula a rotação (Usamos tempo_atual para permitir controle manual no editor)
	var angulo = (tempo_atual / duracao_do_dia_segundos) * TAU
	
	# Roda o Sol
	rotation.x = angulo
	
	# Roda a Lua
	if luz_da_lua:
		luz_da_lua.rotation.x = angulo + PI
	
	# 3. Lógica do Sol
	var direcao_sol = -global_transform.basis.z
	
	if direcao_sol.y < 0.0:
		var transicao = smoothstep(0.0, -0.2, direcao_sol.y)
		light_energy = energia_max_sol * transicao
		shadow_enabled = true
	else:
		light_energy = 0.0
		shadow_enabled = false
		
	# 4. Lógica da Lua
	if luz_da_lua:
		var direcao_lua = -luz_da_lua.global_transform.basis.z
		
		if direcao_lua.y < 0.0:
			var transicao = smoothstep(0.0, -0.2, direcao_lua.y)
			luz_da_lua.light_energy = energia_max_lua * transicao
			luz_da_lua.shadow_enabled = true
		else:
			luz_da_lua.light_energy = 0.0
			luz_da_lua.shadow_enabled = false
