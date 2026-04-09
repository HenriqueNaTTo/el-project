@tool
extends RefCounted

const SIDE_CAR_SUFFIX := ".foley.json"


static func metadata_path_for_audio(audio_path: String) -> String:
	var file_name := audio_path.get_file()
	var folder := audio_path.get_base_dir()
	return "%s/.%s%s" % [folder, file_name, SIDE_CAR_SUFFIX]


static func legacy_metadata_path_for_audio(audio_path: String) -> String:
	return "%s%s" % [audio_path, SIDE_CAR_SUFFIX]


static func has_metadata(audio_path: String) -> bool:
	return FileAccess.file_exists(metadata_path_for_audio(audio_path)) \
		or FileAccess.file_exists(legacy_metadata_path_for_audio(audio_path))


static func write_metadata(audio_path: String, metadata: Dictionary) -> Error:
	var metadata_path := metadata_path_for_audio(audio_path)
	var file := FileAccess.open(metadata_path, FileAccess.WRITE)
	if file == null:
		return FAILED

	file.store_string(JSON.stringify(metadata, "\t"))
	file.close()

	var legacy_path := legacy_metadata_path_for_audio(audio_path)
	if legacy_path != metadata_path and FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))
	return OK


static func read_metadata(audio_path: String) -> Dictionary:
	var metadata_path := metadata_path_for_audio(audio_path)
	if not FileAccess.file_exists(metadata_path):
		metadata_path = legacy_metadata_path_for_audio(audio_path)
	if not FileAccess.file_exists(metadata_path):
		return {}

	var file := FileAccess.open(metadata_path, FileAccess.READ)
	if file == null:
		return {}

	var raw := file.get_as_text()
	file.close()
	var parsed := JSON.parse_string(raw)
	if parsed is Dictionary:
		if metadata_path == legacy_metadata_path_for_audio(audio_path):
			write_metadata(audio_path, parsed)
		return parsed
	return {}


static func migrate_legacy_sidecars(root_folder: String = "res://") -> void:
	_migrate_folder_recursive(root_folder)


static func _migrate_folder_recursive(folder_path: String) -> void:
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if name == "." or name == "..":
			continue
		if name.begins_with("."):
			continue

		var child_path := folder_path.path_join(name)
		if dir.current_is_dir():
			_migrate_folder_recursive(child_path)
			continue

		if not name.ends_with(SIDE_CAR_SUFFIX):
			continue
		var audio_path := child_path.trim_suffix(SIDE_CAR_SUFFIX)
		read_metadata(audio_path)
	dir.list_dir_end()
