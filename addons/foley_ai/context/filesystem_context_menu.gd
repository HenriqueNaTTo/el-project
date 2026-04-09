@tool
extends EditorContextMenuPlugin

const FoleyMetadata := preload("res://addons/foley_ai/core/foley_metadata.gd")

var _plugin: EditorPlugin


func _init(plugin: EditorPlugin) -> void:
	_plugin = plugin


func _popup_menu(paths: PackedStringArray) -> void:
	add_context_menu_item("Foley AI/Generate...", Callable(self, "_on_generate_pressed"))
	var regeneratable_count := _regeneratable_selection_count(paths)
	if regeneratable_count > 0:
		var label := "Foley AI/Generate Variations"
		if regeneratable_count > 1:
			label = "Foley AI/Generate Variations (Batch)"
		add_context_menu_item(label, Callable(self, "_on_generate_variations_pressed"))


func _on_generate_pressed(paths_variant: Variant = PackedStringArray()) -> void:
	if _plugin != null and _plugin.has_method("open_quick_generate"):
		_plugin.call("open_quick_generate", _to_paths(paths_variant))


func _on_generate_variations_pressed(paths_variant: Variant = PackedStringArray()) -> void:
	if _plugin != null and _plugin.has_method("open_generate_variations"):
		_plugin.call("open_generate_variations", _to_paths(paths_variant))


func _has_regeneratable_selection(paths: PackedStringArray) -> bool:
	return _regeneratable_selection_count(paths) > 0


func _regeneratable_selection_count(paths: PackedStringArray) -> int:
	var count := 0
	for path in paths:
		if FoleyMetadata.has_metadata(path):
			count += 1
	return count


func _to_paths(paths_variant: Variant) -> PackedStringArray:
	if paths_variant is PackedStringArray:
		return paths_variant
	if paths_variant is Array:
		var packed := PackedStringArray()
		for item in paths_variant:
			packed.append(str(item))
		return packed
	return PackedStringArray()
