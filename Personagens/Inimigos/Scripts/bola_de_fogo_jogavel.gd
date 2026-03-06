# FireballProjectile.gd
extends Area3D

var speed: float = 10.0
var target_direction: Vector3 = Vector3.FORWARD

func _physics_process(delta: float):
	# Move a bola de fogo na direção definida
	global_position += target_direction * speed * delta

# Conecte este sinal (body_entered) no Inspector do nó

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		# Causa dano (você pode passar o dano aqui se quiser)
		if body.has_method("in_self_damage"):
			body.in_self_damage(Vector2(20, 35)) # Exemplo de dano
				
			# Destrói a bola de fogo
			queue_free()
		Globais.damage_player(20, 35)
	
	# Opcional: destruir ao colidir com o cenário
	elif not body.is_in_group("enemy") or not body.is_in_group("player"):
		queue_free()
