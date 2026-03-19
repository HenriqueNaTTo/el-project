@tool
extends EditorPlugin
const SPATIAL_EDITOR_WIDGET = preload("res://addons/csg_generator_3d/scene/spatial_editor_widget.tscn")
var spatial_editor_instance: Control

func _enable_plugin() -> void:
	# Add autoloads here.
	pass

func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	spatial_editor_instance = SPATIAL_EDITOR_WIDGET.instantiate()
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, spatial_editor_instance)


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	if is_instance_valid(spatial_editor_instance) and spatial_editor_instance.is_inside_tree():
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, spatial_editor_instance)
		spatial_editor_instance.queue_free()
