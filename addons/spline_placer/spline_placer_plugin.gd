@tool
extends EditorPlugin

func _get_plugin_name() -> String:
	return "SplinePlacer"

func _enter_tree() -> void:
	add_custom_type(
		"SplinePlacer",
		"Path3D",
		preload("res://addons/spline_placer/spline_placer.gd"),
		preload("res://addons/spline_placer/icon.svg")
	)

func _exit_tree() -> void:
	remove_custom_type("SplinePlacer")
