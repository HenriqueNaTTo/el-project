@tool
extends RefCounted

const KEY_DEFAULT_OUTPUT_FOLDER := "foley_ai/default_output_folder"
const KEY_LAST_PROMPT := "foley_ai/last_prompt"
const KEY_DEFAULT_VARIATIONS := "foley_ai/default_variations"
const KEY_DEFAULT_PROMPT_INFLUENCE := "foley_ai/default_prompt_influence"
const KEY_USE_CUSTOM_DURATION := "foley_ai/use_custom_duration"
const KEY_DEFAULT_DURATION_SECONDS := "foley_ai/default_duration_seconds"
const KEY_DEFAULT_OUTPUT_FORMAT := "foley_ai/default_output_format"
const KEY_PROMPT_HISTORY := "foley_ai/prompt_history"
const KEY_PROMPT_PRESETS := "foley_ai/prompt_presets"
const KEY_API_KEY_LEGACY := "foley_ai/api_key"

const META_SECTION := "foley_ai"
const META_API_KEY := "api_key"

const DEFAULTS := {
	KEY_DEFAULT_OUTPUT_FOLDER: "res://audio/foley_ai",
	KEY_LAST_PROMPT: "",
	KEY_DEFAULT_VARIATIONS: 1,
	KEY_DEFAULT_PROMPT_INFLUENCE: 0.3,
	KEY_USE_CUSTOM_DURATION: false,
	KEY_DEFAULT_DURATION_SECONDS: 3.0,
	KEY_DEFAULT_OUTPUT_FORMAT: "pcm_44100",
	KEY_PROMPT_HISTORY: [],
	KEY_PROMPT_PRESETS: []
}

const OUTPUT_FORMATS := [
	"pcm_44100",
	"pcm_24000",
	"pcm_22050",
	"pcm_16000",
	"mp3_44100_128",
	"mp3_22050_32"
]


static func ensure_defaults(_editor_settings: EditorSettings = null) -> void:
	var is_dirty := false
	for key: String in DEFAULTS.keys():
		if not ProjectSettings.has_setting(key):
			ProjectSettings.set_setting(key, DEFAULTS[key])
			is_dirty = true
		ProjectSettings.set_initial_value(key, DEFAULTS[key])
	if is_dirty:
		ProjectSettings.save()


static func get_default_form() -> Dictionary:
	var form := {
		"prompt": str(ProjectSettings.get_setting(KEY_LAST_PROMPT, DEFAULTS[KEY_LAST_PROMPT])),
		"variations": int(ProjectSettings.get_setting(KEY_DEFAULT_VARIATIONS, DEFAULTS[KEY_DEFAULT_VARIATIONS])),
		"prompt_influence": float(ProjectSettings.get_setting(KEY_DEFAULT_PROMPT_INFLUENCE, DEFAULTS[KEY_DEFAULT_PROMPT_INFLUENCE])),
		"use_custom_duration": bool(ProjectSettings.get_setting(KEY_USE_CUSTOM_DURATION, DEFAULTS[KEY_USE_CUSTOM_DURATION])),
		"duration_seconds": float(ProjectSettings.get_setting(KEY_DEFAULT_DURATION_SECONDS, DEFAULTS[KEY_DEFAULT_DURATION_SECONDS])),
		"output_format": str(ProjectSettings.get_setting(KEY_DEFAULT_OUTPUT_FORMAT, DEFAULTS[KEY_DEFAULT_OUTPUT_FORMAT])),
		"target_folder": str(ProjectSettings.get_setting(KEY_DEFAULT_OUTPUT_FOLDER, DEFAULTS[KEY_DEFAULT_OUTPUT_FOLDER])),
		"create_prompt_subfolder": true
	}
	return clamp_form(form)


static func clamp_form(form: Dictionary) -> Dictionary:
	var output_format := str(form.get("output_format", DEFAULTS[KEY_DEFAULT_OUTPUT_FORMAT]))
	if not OUTPUT_FORMATS.has(output_format):
		output_format = str(DEFAULTS[KEY_DEFAULT_OUTPUT_FORMAT])

	var target_folder := str(form.get("target_folder", DEFAULTS[KEY_DEFAULT_OUTPUT_FOLDER]))
	if target_folder.strip_edges().is_empty() or not target_folder.begins_with("res://"):
		target_folder = str(DEFAULTS[KEY_DEFAULT_OUTPUT_FOLDER])

	return {
		"prompt": str(form.get("prompt", "")),
		"variations": clampi(int(form.get("variations", 1)), 1, 5),
		"prompt_influence": clampf(float(form.get("prompt_influence", 0.3)), 0.0, 1.0),
		"use_custom_duration": bool(form.get("use_custom_duration", false)),
		"duration_seconds": clampf(float(form.get("duration_seconds", 3.0)), 0.5, 5.0),
		"output_format": output_format,
		"target_folder": target_folder,
		"create_prompt_subfolder": bool(form.get("create_prompt_subfolder", true))
	}


static func save_defaults_from_form(form: Dictionary) -> void:
	var clamped := clamp_form(form)
	ProjectSettings.set_setting(KEY_LAST_PROMPT, clamped["prompt"])
	ProjectSettings.set_setting(KEY_DEFAULT_VARIATIONS, clamped["variations"])
	ProjectSettings.set_setting(KEY_DEFAULT_PROMPT_INFLUENCE, clamped["prompt_influence"])
	ProjectSettings.set_setting(KEY_USE_CUSTOM_DURATION, clamped["use_custom_duration"])
	ProjectSettings.set_setting(KEY_DEFAULT_DURATION_SECONDS, clamped["duration_seconds"])
	ProjectSettings.set_setting(KEY_DEFAULT_OUTPUT_FORMAT, clamped["output_format"])
	ProjectSettings.set_setting(KEY_DEFAULT_OUTPUT_FOLDER, clamped["target_folder"])
	ProjectSettings.save()


static func get_prompt_history() -> PackedStringArray:
	return _normalize_string_array(ProjectSettings.get_setting(KEY_PROMPT_HISTORY, PackedStringArray()))


static func add_prompt_to_history(prompt: String, max_items: int = 15) -> PackedStringArray:
	var normalized := prompt.strip_edges()
	if normalized.is_empty():
		return get_prompt_history()

	var history := get_prompt_history()
	var deduped := PackedStringArray()
	deduped.append(normalized)
	for item in history:
		if item == normalized:
			continue
		deduped.append(item)
		if deduped.size() >= maxi(1, max_items):
			break
	ProjectSettings.set_setting(KEY_PROMPT_HISTORY, deduped)
	ProjectSettings.save()
	return deduped


static func get_prompt_presets() -> PackedStringArray:
	return _normalize_string_array(ProjectSettings.get_setting(KEY_PROMPT_PRESETS, PackedStringArray()))


static func save_prompt_presets(presets: PackedStringArray) -> void:
	ProjectSettings.set_setting(KEY_PROMPT_PRESETS, _normalize_string_array(presets))
	ProjectSettings.save()


static func add_prompt_preset(prompt: String, max_items: int = 30) -> PackedStringArray:
	var normalized := prompt.strip_edges()
	if normalized.is_empty():
		return get_prompt_presets()

	var presets := get_prompt_presets()
	if presets.has(normalized):
		return presets
	presets.append(normalized)
	if presets.size() > maxi(1, max_items):
		var trimmed := PackedStringArray()
		for i in range(presets.size() - max_items, presets.size()):
			trimmed.append(presets[i])
		presets = trimmed
	save_prompt_presets(presets)
	return presets


static func remove_prompt_preset(prompt: String) -> PackedStringArray:
	var normalized := prompt.strip_edges()
	var presets := get_prompt_presets()
	if normalized.is_empty() or not presets.has(normalized):
		return presets
	var next := PackedStringArray()
	for item in presets:
		if item == normalized:
			continue
		next.append(item)
	save_prompt_presets(next)
	return next


static func get_output_formats() -> PackedStringArray:
	return PackedStringArray(OUTPUT_FORMATS)


static func format_output_format_label(output_format: String) -> String:
	match output_format:
		"pcm_44100":
			return "WAV PCM 44.1kHz (recommended for SFX)"
		"pcm_24000":
			return "WAV PCM 24kHz"
		"pcm_22050":
			return "WAV PCM 22.05kHz"
		"pcm_16000":
			return "WAV PCM 16kHz"
		"mp3_44100_128":
			return "MP3 44.1kHz 128kbps"
		"mp3_22050_32":
			return "MP3 22.05kHz 32kbps"
		_:
			return output_format


static func calculate_cost(variations: int, token_cost_per_generation: int) -> int:
	return maxi(1, variations) * maxi(1, token_cost_per_generation)


static func get_api_key(editor_settings: EditorSettings = null) -> String:
	var project_setting_key := str(ProjectSettings.get_setting(KEY_API_KEY_LEGACY, "")).strip_edges()
	if not project_setting_key.is_empty():
		return project_setting_key

	var resolved := _resolve_editor_settings(editor_settings)
	if resolved != null:
		var metadata_value := str(resolved.get_project_metadata(META_SECTION, META_API_KEY, "")).strip_edges()
		if not metadata_value.is_empty():
			return metadata_value
	return ""


static func save_api_key(editor_settings: EditorSettings = null, api_key: String = "") -> void:
	var normalized := api_key.strip_edges()
	var resolved := _resolve_editor_settings(editor_settings)
	if resolved != null:
		resolved.set_project_metadata(META_SECTION, META_API_KEY, normalized)


static func clear_api_key(editor_settings: EditorSettings = null) -> void:
	var resolved := _resolve_editor_settings(editor_settings)
	if resolved != null:
		resolved.set_project_metadata(META_SECTION, META_API_KEY, "")


static func migrate_legacy_api_key(editor_settings: EditorSettings = null) -> bool:
	var legacy := str(ProjectSettings.get_setting(KEY_API_KEY_LEGACY, "")).strip_edges()
	if legacy.is_empty():
		return false
	var resolved := _resolve_editor_settings(editor_settings)
	if resolved == null:
		return false

	var existing := str(resolved.get_project_metadata(META_SECTION, META_API_KEY, "")).strip_edges()
	if existing.is_empty():
		resolved.set_project_metadata(META_SECTION, META_API_KEY, legacy)
		return true
	return false


static func _resolve_editor_settings(editor_settings: EditorSettings) -> EditorSettings:
	return editor_settings


static func _normalize_string_array(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		var packed: PackedStringArray = value
		var normalized := PackedStringArray()
		for item in packed:
			var text := str(item).strip_edges()
			if text.is_empty():
				continue
			normalized.append(text)
		return normalized
	if value is Array:
		var array_value: Array = value
		var from_array := PackedStringArray()
		for item in array_value:
			var text := str(item).strip_edges()
			if text.is_empty():
				continue
			from_array.append(text)
		return from_array
	return PackedStringArray()
