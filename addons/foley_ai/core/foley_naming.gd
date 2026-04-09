@tool
extends RefCounted

const DEFAULT_OUTPUT_FOLDER := "res://audio/foley_ai"


static func slugify_prompt(prompt: String) -> String:
	if prompt.strip_edges().is_empty():
		return "sound"

	var builder := ""
	var lowered := prompt.strip_edges().to_lower()
	var previous_was_dash := false

	for index in lowered.length():
		var code := lowered.unicode_at(index)
		var is_alnum := (code >= 97 and code <= 122) or (code >= 48 and code <= 57)
		if is_alnum:
			builder += String.chr(code)
			previous_was_dash = false
			if builder.length() >= 40:
				break
			continue

		if not previous_was_dash and builder.length() > 0:
			builder += "-"
			previous_was_dash = true

	builder = builder.trim_prefix("-").trim_suffix("-")
	return builder if not builder.is_empty() else "sound"


static func build_base_name(prompt: String, utc_now: Dictionary, variation_index: int) -> String:
	var slug := slugify_prompt(prompt)
	var timestamp := "%04d%02d%02d_%02d%02d%02d" % [
		int(utc_now.get("year", 1970)),
		int(utc_now.get("month", 1)),
		int(utc_now.get("day", 1)),
		int(utc_now.get("hour", 0)),
		int(utc_now.get("minute", 0)),
		int(utc_now.get("second", 0))
	]
	return "%s_%s_v%02d" % [slug, timestamp, maxi(1, variation_index)]


static func normalize_folder(folder: String) -> String:
	if folder.strip_edges().is_empty():
		return DEFAULT_OUTPUT_FOLDER

	var normalized := folder.replace("\\", "/").strip_edges()
	if normalized == "res://":
		return normalized
	if not normalized.begins_with("res://"):
		return DEFAULT_OUTPUT_FOLDER
	return normalized.trim_suffix("/")


static func generate_unique_asset_path(folder: String, file_name_without_extension: String, extension: String) -> String:
	var safe_folder := normalize_folder(folder)
	var safe_extension := extension.strip_edges().trim_prefix(".").to_lower()
	if safe_extension.is_empty():
		safe_extension = "wav"

	var candidate := "%s/%s.%s" % [safe_folder, file_name_without_extension, safe_extension]
	if not FileAccess.file_exists(candidate):
		return candidate

	var suffix := 2
	while true:
		candidate = "%s/%s_%03d.%s" % [safe_folder, file_name_without_extension, suffix, safe_extension]
		if not FileAccess.file_exists(candidate):
			return candidate
		suffix += 1
	return candidate
