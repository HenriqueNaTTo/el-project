@tool
extends RefCounted

const FoleyNaming := preload("res://addons/foley_ai/core/foley_naming.gd")
const FoleyMetadata := preload("res://addons/foley_ai/core/foley_metadata.gd")

var _editor_interface: EditorInterface


func _init(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


func import_generated_results(response: Dictionary, form: Dictionary) -> Array[String]:
	var imported_paths: Array[String] = []
	var results: Array = response.get("results", [])
	if results.is_empty():
		return imported_paths

	var root_folder := FoleyNaming.normalize_folder(str(form.get("target_folder", FoleyNaming.DEFAULT_OUTPUT_FOLDER)))
	var output_folder := root_folder
	if bool(form.get("create_prompt_subfolder", true)):
		output_folder = "%s/%s" % [root_folder, FoleyNaming.slugify_prompt(str(form.get("prompt", "")))]

	_ensure_project_folder_exists(output_folder)

	var now_utc := Time.get_datetime_dict_from_system(true)
	var output_format := str(form.get("output_format", "pcm_44100"))
	for result_variant in results:
		if not (result_variant is Dictionary):
			continue
		var result: Dictionary = result_variant
		if not bool(result.get("success", false)):
			continue

		var audio_base64 := str(result.get("audioBase64", ""))
		if audio_base64.is_empty():
			continue

		var decoded := Marshalls.base64_to_raw(audio_base64)
		if decoded.is_empty():
			continue

		var bytes_for_asset := _convert_to_godot_friendly_audio(
			decoded,
			output_format,
			str(result.get("mimeType", ""))
		)
		var extension := _get_extension(
			str(result.get("fileName", "")),
			str(result.get("mimeType", "")),
			output_format
		)
		var variation_index := int(result.get("index", 0)) + 1
		var base_name := FoleyNaming.build_base_name(str(form.get("prompt", "")), now_utc, variation_index)
		var asset_path := FoleyNaming.generate_unique_asset_path(output_folder, base_name, extension)
		if _write_bytes(asset_path, bytes_for_asset) != OK:
			continue

		var metadata := {
			"prompt": str(form.get("prompt", "")),
			"requestedVariations": int(form.get("variations", 1)),
			"variationIndex": variation_index,
			"promptInfluence": float(form.get("prompt_influence", 0.3)),
			"useCustomDuration": bool(form.get("use_custom_duration", false)),
			"durationSeconds": float(form.get("duration_seconds", 3.0)),
			"outputFormat": output_format,
			"requestId": str(response.get("requestId", "")),
			"generatedAtUtc": Time.get_datetime_string_from_system(true, true)
		}
		FoleyMetadata.write_metadata(asset_path, metadata)
		imported_paths.append(asset_path)

	_refresh_imported_files(imported_paths)

	return imported_paths


func _ensure_project_folder_exists(asset_folder_path: String) -> void:
	var absolute_folder := ProjectSettings.globalize_path(asset_folder_path)
	DirAccess.make_dir_recursive_absolute(absolute_folder)


func _write_bytes(asset_path: String, bytes: PackedByteArray) -> Error:
	var absolute_folder := ProjectSettings.globalize_path(asset_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(absolute_folder)

	var file := FileAccess.open(asset_path, FileAccess.WRITE)
	if file == null:
		return FAILED
	file.store_buffer(bytes)
	file.close()
	return OK


func _refresh_imported_files(imported_paths: Array[String]) -> void:
	if _editor_interface == null:
		return
	var filesystem := _editor_interface.get_resource_filesystem()
	if filesystem == null:
		return
	if imported_paths.is_empty():
		return

	var updated_any := false
	var packed_paths := PackedStringArray()
	for asset_path in imported_paths:
		packed_paths.append(asset_path)
	if filesystem.has_method("update_file"):
		for asset_path in packed_paths:
			filesystem.call("update_file", asset_path)
			updated_any = true

	if filesystem.has_method("reimport_files"):
		filesystem.call("reimport_files", packed_paths)
		return

	if not updated_any and filesystem.has_method("scan"):
		filesystem.call("scan")


func _get_extension(file_name: String, mime_type: String, output_format: String) -> String:
	if output_format.begins_with("pcm_"):
		return "wav"
	var extension := file_name.get_extension().to_lower()
	if not extension.is_empty():
		return extension
	if mime_type.contains("mpeg"):
		return "mp3"
	return "wav"


func _convert_to_godot_friendly_audio(
	bytes: PackedByteArray,
	output_format: String,
	mime_type: String
) -> PackedByteArray:
	if bytes.is_empty():
		return bytes
	if output_format.begins_with("pcm_"):
		var sample_rate := _parse_sample_rate(output_format)
		return _wrap_pcm16_mono_as_wav(bytes, sample_rate)
	if mime_type.contains("mpeg"):
		return bytes
	return bytes


func _parse_sample_rate(output_format: String) -> int:
	var parts := output_format.split("_")
	if parts.size() < 2:
		return 44100
	if parts[1].is_valid_int():
		return maxi(1, int(parts[1]))
	return 44100


func _wrap_pcm16_mono_as_wav(pcm_bytes: PackedByteArray, sample_rate: int) -> PackedByteArray:
	var channels := 1
	var bits_per_sample := 16
	var byte_rate := sample_rate * channels * bits_per_sample / 8
	var block_align := channels * bits_per_sample / 8
	var data_length := pcm_bytes.size()
	var stream := StreamPeerBuffer.new()
	stream.big_endian = false

	stream.put_data("RIFF".to_ascii_buffer())
	stream.put_u32(36 + data_length)
	stream.put_data("WAVE".to_ascii_buffer())
	stream.put_data("fmt ".to_ascii_buffer())
	stream.put_u32(16)
	stream.put_u16(1)
	stream.put_u16(channels)
	stream.put_u32(sample_rate)
	stream.put_u32(byte_rate)
	stream.put_u16(block_align)
	stream.put_u16(bits_per_sample)
	stream.put_data("data".to_ascii_buffer())
	stream.put_u32(data_length)
	stream.put_data(pcm_bytes)
	return stream.data_array
