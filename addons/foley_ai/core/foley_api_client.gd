@tool
extends RefCounted

const API_BASE := "https://www.foley-ai.com/api"
const PLUGIN_VERSION := "0.2.0-godot"
const GENERATE_MAX_ATTEMPTS := 3
const RETRY_BASE_DELAY_MS := 1000
const RETRY_MAX_DELAY_MS := 8000
const MAX_REDIRECTS := 3

var _host: Node
var _active_request: HTTPRequest
var _cancel_requested := false


func _init(host: Node) -> void:
	_host = host


func clear_cancel() -> void:
	_cancel_requested = false


func cancel_active() -> void:
	_cancel_requested = true
	if is_instance_valid(_active_request):
		_active_request.cancel_request()


func get_me(api_key: String) -> Dictionary:
	return await _request_json(HTTPClient.METHOD_GET, "/plugin/me", api_key, {}, 30.0)


func generate(form: Dictionary, api_key: String, project_name: String, godot_version: String) -> Dictionary:
	var payload := _build_generate_payload(form, project_name, godot_version)
	for attempt in range(1, GENERATE_MAX_ATTEMPTS + 1):
		if _cancel_requested:
			return _build_canceled_error()

		var response := await _request_json(
			HTTPClient.METHOD_POST,
			"/plugin/generate-sound",
			api_key,
			payload,
			180.0
		)
		if bool(response.get("ok", false)):
			return response

		var should_retry := _should_retry(response)
		var can_retry := should_retry and attempt < GENERATE_MAX_ATTEMPTS
		if not can_retry:
			if should_retry and attempt > 1:
				var base_message := str(response.get("message", "API request failed."))
				response["message"] = "%s Retried %d time(s) with backoff." % [base_message, attempt]
			return response

		var delay_ms := _resolve_retry_delay_ms(response, attempt)
		await _host.get_tree().create_timer(float(delay_ms) / 1000.0).timeout

	return {
		"ok": false,
		"status_code": 0,
		"error_code": "api_request_failed",
		"message": "Generation request failed unexpectedly."
	}


func _request_json(
	method: int,
	path: String,
	api_key: String,
	payload: Dictionary,
	timeout_seconds: float
) -> Dictionary:
	return await _request_json_url(method, _build_url(path), api_key, payload, timeout_seconds, 0)


func _request_json_url(
	method: int,
	request_url: String,
	api_key: String,
	payload: Dictionary,
	timeout_seconds: float,
	redirect_count: int
) -> Dictionary:
	if _cancel_requested:
		return _build_canceled_error()

	if _host == null or _host.get_tree() == null:
		return {
			"ok": false,
			"status_code": 0,
			"error_code": "plugin_state_error",
			"message": "Plugin host is not available."
		}

	var request := HTTPRequest.new()
	request.timeout = timeout_seconds
	_host.add_child(request)
	_active_request = request

	var headers := PackedStringArray(["Authorization: Bearer %s" % api_key])
	var body := ""
	if method != HTTPClient.METHOD_GET:
		headers.append("Content-Type: application/json")
		body = JSON.stringify(payload)

	var start_error := request.request(request_url, headers, method, body)
	if start_error != OK:
		request.queue_free()
		_active_request = null
		return {
			"ok": false,
			"status_code": 0,
			"error_code": "network_error",
			"message": "Failed to start HTTP request (error %d)." % start_error
		}

	var completed: Array = await request.request_completed
	var transport_result: int = int(completed[0])
	var status_code: int = int(completed[1])
	var response_headers: PackedStringArray = completed[2]
	var response_body: PackedByteArray = completed[3]
	var response_text := response_body.get_string_from_utf8()
	var content_type := _find_header(response_headers, "content-type").to_lower()
	var trimmed_response := response_text.strip_edges()

	request.queue_free()
	_active_request = null

	if _cancel_requested:
		return _build_canceled_error()

	if transport_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"status_code": 0,
			"error_code": "network_error",
			"message": "Network error while contacting Foley API.",
			"transport_result": transport_result
		}

	if status_code >= 300 and status_code < 400:
		var location := _find_header(response_headers, "location")
		if not location.is_empty() and redirect_count < MAX_REDIRECTS:
			var next_url := _resolve_redirect_url(request_url, location)
			if not next_url.is_empty():
				return await _request_json_url(method, next_url, api_key, payload, timeout_seconds, redirect_count + 1)

	var parsed: Dictionary = {}
	var should_parse_json := false
	if not trimmed_response.is_empty():
		should_parse_json = content_type.contains("application/json") \
			or trimmed_response.begins_with("{") \
			or trimmed_response.begins_with("[")
	if should_parse_json:
		var parsed_variant := JSON.parse_string(trimmed_response)
		if parsed_variant is Dictionary:
			parsed = parsed_variant

	var is_success := status_code >= 200 and status_code < 300
	if is_success:
		if parsed.is_empty():
			return {
				"ok": false,
				"status_code": status_code,
				"error_code": "invalid_response",
				"message": _build_non_json_response_message(status_code, response_headers, trimmed_response)
			}
		return {
			"ok": true,
			"status_code": status_code,
			"data": parsed,
			"headers": response_headers
		}

	var error_code := str(parsed.get("error", _infer_error_code(status_code)))
	var message := str(parsed.get("message", _infer_error_message(status_code)))
	if parsed.is_empty() and not trimmed_response.is_empty():
		message = _build_non_json_response_message(status_code, response_headers, trimmed_response)
	var retry_after := _parse_retry_after(_find_header(response_headers, "retry-after"))
	return {
		"ok": false,
		"status_code": status_code,
		"error_code": error_code,
		"message": message,
		"retry_after_seconds": retry_after,
		"is_rate_limited": _is_rate_limited_code(status_code, error_code)
	}


func _resolve_redirect_url(current_url: String, location: String) -> String:
	var trimmed_location := location.strip_edges()
	if trimmed_location.is_empty():
		return ""
	if trimmed_location.begins_with("http://") or trimmed_location.begins_with("https://"):
		return trimmed_location

	var scheme_index := current_url.find("://")
	if scheme_index < 0:
		return trimmed_location
	var host_start := scheme_index + 3
	var path_index := current_url.find("/", host_start)
	var origin := current_url if path_index < 0 else current_url.substr(0, path_index)

	if trimmed_location.begins_with("/"):
		return origin + trimmed_location
	return origin + "/" + trimmed_location


func _build_generate_payload(form: Dictionary, project_name: String, godot_version: String) -> Dictionary:
	var parameters := {
		"text": str(form.get("prompt", "")),
		"prompt_influence": clampf(float(form.get("prompt_influence", 0.3)), 0.0, 1.0),
		"output_format": str(form.get("output_format", "pcm_44100")),
		"variations": clampi(int(form.get("variations", 1)), 1, 5)
	}
	if bool(form.get("use_custom_duration", false)):
		parameters["duration_seconds"] = clampf(float(form.get("duration_seconds", 3.0)), 0.5, 5.0)

	return {
		"parameters": parameters,
		"client": {
			"plugin_version": PLUGIN_VERSION,
			"godot_version": godot_version,
			"project_name": project_name
		}
	}


func _build_url(path: String) -> String:
	var normalized := path.strip_edges()
	if not normalized.begins_with("/"):
		normalized = "/" + normalized
	if normalized.begins_with("/api/"):
		normalized = normalized.trim_prefix("/api")
	return API_BASE + normalized


func _find_header(headers: PackedStringArray, header_name: String) -> String:
	var lowered_name := header_name.to_lower()
	for header_line in headers:
		var separator_index := header_line.find(":")
		if separator_index <= 0:
			continue
		var name := header_line.substr(0, separator_index).strip_edges().to_lower()
		if name == lowered_name:
			return header_line.substr(separator_index + 1).strip_edges()
	return ""


func _parse_retry_after(value: String) -> int:
	if value.is_empty():
		return -1
	if value.is_valid_int():
		return maxi(1, int(value))
	return -1


func _should_retry(response: Dictionary) -> bool:
	if response.is_empty():
		return false
	if bool(response.get("is_rate_limited", false)):
		return true

	var status_code := int(response.get("status_code", 0))
	var error_code := str(response.get("error_code", ""))
	if status_code == 0 or status_code == 408:
		return true
	if status_code >= 500 and status_code <= 599:
		return true
	return error_code == "network_error" or error_code == "request_timeout"


func _resolve_retry_delay_ms(response: Dictionary, attempt: int) -> int:
	var retry_after := int(response.get("retry_after_seconds", -1))
	if retry_after > 0:
		return clampi(retry_after * 1000, RETRY_BASE_DELAY_MS, 30000)

	var exponent := maxi(0, attempt - 1)
	var delay := RETRY_BASE_DELAY_MS * (1 << exponent)
	return clampi(delay, RETRY_BASE_DELAY_MS, RETRY_MAX_DELAY_MS)


func _infer_error_code(status_code: int) -> String:
	if status_code == 429:
		return "rate_limited"
	if status_code == 408:
		return "request_timeout"
	if status_code >= 300 and status_code <= 399:
		return "redirect_response"
	if status_code == 0:
		return "network_error"
	return "api_request_failed"


func _infer_error_message(status_code: int) -> String:
	if status_code == 429:
		return "Rate limit reached. Please retry shortly."
	if status_code == 408:
		return "Request timed out. Please retry."
	if status_code >= 300 and status_code <= 399:
		return "Unexpected redirect from Foley API."
	if status_code == 0:
		return "Network error while contacting Foley API."
	return "API request failed."


func _is_rate_limited_code(status_code: int, error_code: String) -> bool:
	if status_code == 429:
		return true
	var lowered := error_code.to_lower()
	return lowered == "rate_limited" or lowered == "rate_limit_exceeded" or lowered.contains("rate_limit")


func _build_canceled_error() -> Dictionary:
	return {
		"ok": false,
		"status_code": 0,
		"error_code": "canceled",
		"message": "Generation canceled by user."
	}


func _build_non_json_response_message(status_code: int, headers: PackedStringArray, body: String) -> String:
	if status_code >= 300 and status_code <= 399:
		var location := _find_header(headers, "location")
		if not location.is_empty():
			return "API returned redirect (%d) to %s. Expected JSON API response." % [status_code, location]
		return "API returned redirect (%d). Expected JSON API response." % status_code

	if body.is_empty():
		return "API response was empty."

	var preview := body.substr(0, mini(120, body.length()))
	return "API returned non-JSON response: %s" % preview
