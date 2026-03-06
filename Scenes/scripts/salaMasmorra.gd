extends Node3D

# Esta variável irá coletar todos os nós Marker3D que são filhos diretos desta cena.
# O gerador usará esta lista para saber onde as portas estão.
@export var doors: Array[Marker3D]

func _ready():
	# Se as portas não foram atribuídas no inspetor, podemos tentar encontrá-las automaticamente.
	if doors.is_empty():
		for child in get_children():
			if child is Marker3D:
				doors.append(child)

# Uma função auxiliar para obter as posições das portas no espaço global.
func get_door_global_transforms() -> Array[Transform3D]:
	var transforms: Array[Transform3D]
	for door in doors:
		transforms.append(door.global_transform)
	return transforms
