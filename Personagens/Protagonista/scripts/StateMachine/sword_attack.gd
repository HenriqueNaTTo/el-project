# attack_state.gd
extends State

const CONFIG_POR_ARMA = {
	"espada": {
		"max_combo": 2.5,
		"velocidade": 4.0,
		"prefixo_anim": "comboEspada",
		"condicoes": ["ataque1", "ataque2", "ataque3"],
		"nomes_anim": ["espada_ataque1", "espada_ataque2", "espada_ataque3"],
	},
	"espada_longa": {
		"max_combo": 3,
		"velocidade": 1.5,
		"prefixo_anim": "comboEspadaLonga",
		"condicoes": ["ataque1", "ataque2", "ataque3"],
		"nomes_anim": ["espada_longa_ataque1", "espada_longa_ataque2", "espada_longa_ataque3"],
	},
	"lanca": {
		"max_combo": 2,
		"velocidade": 4.0,
		"prefixo_anim": "comboLanca",
		"condicoes": ["ataque1", "ataque2"],
		"nomes_anim": ["lanca_ataque1", "lanca_ataque2"],
	},
	"arco": {
		"max_combo": 1,
		"velocidade": 3.0,
		"prefixo_anim": "ataqueArco",
		"condicoes": ["ataque1"],
		"nomes_anim": ["arco_ataque1"],
	},
}

# ── Ciclo de vida do estado ─────────────────────────────────────────────────
func enter() -> void:
	var config = _obter_config()
	player.current_speed = config.velocidade
	player.isAttacking = true
	player.animation_tree["parameters/conditions/isAttack"] = true
	player.animation_tree["parameters/conditions/basicMove"] = false
	
	# Ativa a hitbox da arma
	if player.area_attack:
		player.area_attack.monitoring = true
	
	_executar_ataque()

func handle_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("basicAttack"):
		var config = _obter_config()
		var pode_continuar_combo = (
			not player.attackTimer.is_stopped()
			and player.combo_count < config.max_combo - 1
			and config.max_combo > 1
		)
		if pode_continuar_combo:
			player.combo_count += 1
			_executar_ataque()

func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity += (player.get_gravity() * 2) * delta

	player.apply_movement_and_rotation(Vector3.ZERO, delta)

	if player.attackTimer.is_stopped():
		transitioned.emit(self, "Idle")

func exit() -> void:
	player.combo_count = 0
	player.isAttacking = false
	player.animation_tree["parameters/conditions/estaAtacando"] = false
	player.animation_tree["parameters/conditions/movimentoBasico"] = true
	
	# Desativa a hitbox da arma
	if player.area_attack:
		player.area_attack.monitoring = false
	
	_limpar_todas_condicoes()

# ── Lógica de ataque ────────────────────────────────────────────────────────
func _executar_ataque() -> void:
	var config = _obter_config()
	_limpar_condicoes_arma(config)

	var indice = player.combo_count
	var pathAnim_condicao = "parameters/" + config.prefixo_anim + "/conditions/" + config.condicoes[indice]
	player.animation_tree[pathAnim_condicao] = true

	var duracao = _obter_duracao_anim(config.nomes_anim[indice])
	_iniciar_timer(duracao)

func _iniciar_timer(tempo: float) -> void:
	player.attackTimer.wait_time = tempo
	player.attackTimer.one_shot = true
	player.attackTimer.start()

# ── Helpers ─────────────────────────────────────────────────────────────────
func _obter_config() -> Dictionary:
	if player.current_weapon_data == null:
		return CONFIG_POR_ARMA["espada"]
	
	match player.current_weapon_data.tipo_arma:
		ItemData.armaType.espada:
			return CONFIG_POR_ARMA["espada"]
		ItemData.armaType.espada_longa:
			return CONFIG_POR_ARMA["espada_longa"]
		ItemData.armaType.lanca:
			return CONFIG_POR_ARMA["lanca"]
		ItemData.armaType.arco:
			return CONFIG_POR_ARMA["arco"]
		_:
			return CONFIG_POR_ARMA["espada"]

func _obter_duracao_anim(nome_anim: String) -> float:
	var animPlayer = player.animation_player
	if animPlayer and animPlayer.has_animation(nome_anim):
		return animPlayer.get_animation(nome_anim).length
	push_warning("EstadoAtaque: animação '%s' não encontrada, usando 0.5s como fallback." % nome_anim)
	return 0.5

func _limpar_condicoes_arma(config: Dictionary) -> void:
	for condicao in config.condicoes:
		var pathAnim = "parameters/" + config.prefixo_anim + "/conditions/" + condicao
		player.animation_tree[pathAnim] = false

func _limpar_todas_condicoes() -> void:
	for arma in CONFIG_POR_ARMA:
		_limpar_condicoes_arma(CONFIG_POR_ARMA[arma])
