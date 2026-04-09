@tool
extends VBoxContainer

const FoleySettings := preload("res://addons/foley_ai/core/foley_settings.gd")
const FoleyNaming := preload("res://addons/foley_ai/core/foley_naming.gd")
const FoleyApiClient := preload("res://addons/foley_ai/core/foley_api_client.gd")
const FoleyImportService := preload("res://addons/foley_ai/core/foley_import_service.gd")
const FoleyMetadata := preload("res://addons/foley_ai/core/foley_metadata.gd")

const COLOR_BG := Color(0.9686, 0.9490, 0.8118, 1.0) # #F7F2CF
const COLOR_PANEL := Color(0.9882, 0.9686, 0.9020, 1.0) # #FCF7E6
const COLOR_INPUT_BG := Color(0.9922, 0.9804, 0.9294, 1.0) # #FDFBEA
const COLOR_PANEL_BORDER := Color(0.3647, 0.3412, 0.4196, 1.0) # #5D576B
const COLOR_TITLE := Color(0.3647, 0.3412, 0.4196, 1.0) # #5D576B
const COLOR_TITLE_STRONG := Color(0.2314, 0.2157, 0.2824, 1.0) # #3B3748
const COLOR_TEXT := Color(0.3647, 0.3412, 0.4196, 1.0) # #5D576B
const COLOR_TEXT_MUTED := Color(0.4314, 0.4000, 0.5098, 1.0) # #6E6682
const COLOR_PRIMARY_BLUE := Color(0.3059, 0.4745, 0.6510, 1.0) # #4E79A6
const COLOR_PRIMARY_BLUE_HOVER := Color(0.2471, 0.4039, 0.5608, 1.0) # #3F678F
const COLOR_ACCENT := Color(0.6078, 0.7569, 0.7373, 1.0) # #9BC1BC
const COLOR_ACCENT_HOVER := Color(0.3647, 0.3412, 0.4196, 1.0) # #5D576B
const COLOR_SECONDARY_HOVER := Color(0.9059, 0.9529, 0.9490, 1.0) # #E7F3F2
const COLOR_CHIP_HOVER := Color(0.9059, 0.9529, 0.9490, 1.0) # #E7F3F2
const COLOR_SUCCESS := Color(0.2314, 0.5765, 0.3765, 1.0)
const COLOR_SUCCESS_BG := Color(0.3725, 0.7294, 0.5176, 1.0) # #5FBA84
const COLOR_SUCCESS_HOVER := Color(0.3059, 0.6627, 0.4588, 1.0) # #4EA975
const COLOR_SUCCESS_STRONG := Color(0.2275, 0.6275, 0.4000, 1.0) # #3AA066
const COLOR_DANGER := Color(0.9294, 0.4157, 0.3529, 1.0) # #ED6A5A
const COLOR_DANGER_HOVER := Color(0.8471, 0.3529, 0.2902, 1.0) # #D85A4A
const COLOR_DANGER_SOFT := Color(0.9922, 0.9137, 0.8941, 1.0) # #FDE9E4
const COLOR_ITEM_SELECTED := Color(0.8509, 0.9254, 0.9921, 1.0) # #D9ECFD
const COLOR_ITEM_HOVER := Color(0.9058, 0.9530, 0.9020, 1.0) # #E7F3E6
const COLOR_SHADOW := Color(0.2588, 0.2353, 0.3176, 0.75) # #423C51
const COLOR_HARD_SHADOW := Color(0.3647, 0.3412, 0.4196, 0.34) # rgba(93, 87, 107, 0.34)
const COLOR_SLIDER_SHADOW := Color(0.1765, 0.2510, 0.3569, 0.60)
const DEFAULT_PROMPT_CHIPS := [
	"Medieval sword clashing",
	"Footsteps on gravel",
	"Door creak in old house",
	"Sci-fi UI click"
]

var _api_client
var _import_service
var _editor_interface: EditorInterface

var _account_state: Dictionary = {}
var _last_generated_form: Dictionary = {}
var _last_failed_variations := 0
var _last_rate_limited_failures := 0
var _is_busy := false
var _is_authenticated := false

var _auth_status_dot: ColorRect
var _auth_status_label: Label
var _auth_helper_label: Label
var _auth_refresh_button: Button
var _token_label: Label
var _buy_tokens_button: Button
var _api_key_edit: LineEdit
var _save_api_key_button: Button
var _api_key_row: HBoxContainer
var _prompt_edit: TextEdit
var _prompt_chip_container: HFlowContainer
var _recent_prompt_label: Label
var _recent_prompt_chips: HFlowContainer
var _save_preset_button: Button
var _remove_preset_button: Button
var _batch_toggle: CheckBox
var _batch_queue_container: VBoxContainer
var _batch_entry_edit: LineEdit
var _batch_add_button: Button
var _batch_remove_button: Button
var _batch_clear_button: Button
var _batch_queue_list: ItemList
var _batch_hint_label: Label
var _variations_spin: SpinBox
var _variations_label: Label
var _influence_slider: HSlider
var _influence_label: Label
var _duration_toggle: CheckBox
var _duration_slider: HSlider
var _duration_label: Label
var _format_option: OptionButton
var _target_folder_edit: LineEdit
var _create_subfolder_toggle: CheckBox
var _estimated_cost_label: Label
var _generate_button: Button
var _cancel_button: Button
var _retry_button: Button
var _status_label: Label
var _session_summary_label: Label
var _results_list: ItemList
var _results_empty_label: Label
var _show_in_fs_button: Button
var _play_result_button: Button
var _copy_path_button: Button
var _retry_selected_button: Button
var _insufficient_tokens_toast: PanelContainer
var _insufficient_tokens_label: Label
var _insufficient_tokens_button: Button
var _folder_dialog: EditorFileDialog
var _scroll: ScrollContainer
var _layout_grid: GridContainer
var _right_column: VBoxContainer
var _settings_grid: GridContainer
var _result_rows: Array[Dictionary] = []
var _batch_prompts: Array[String] = []
var _audio_preview_player: AudioStreamPlayer
var _is_running_batch := false
var _is_running_variation_queue := false


func _init(editor_interface: EditorInterface = null) -> void:
	_editor_interface = editor_interface


func _ready() -> void:
	name = "Foley AI"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()
	if _editor_interface == null:
		_set_error("Editor interface is not available.")
		return

	_api_client = FoleyApiClient.new(self)
	_import_service = FoleyImportService.new(_editor_interface)

	_apply_default_values()
	_refresh_prompt_library_ui()
	_refresh_key_status()
	_update_cost_label()
	_set_status("Ready")
	_refresh_account()
	_update_retry_button()
	_update_results_empty_state()
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	call_deferred("_update_layout_columns")


func apply_form(form: Dictionary) -> void:
	var clamped := FoleySettings.clamp_form(form)
	_prompt_edit.text = str(clamped.get("prompt", ""))
	_variations_spin.value = int(clamped.get("variations", 1))
	_variations_label.text = _format_variation_label(int(_variations_spin.value))
	_influence_slider.value = float(clamped.get("prompt_influence", 0.3))
	_influence_label.text = "Prompt influence: %.1f (Lower = precise, higher = creative)" % _influence_slider.value
	_duration_toggle.button_pressed = bool(clamped.get("use_custom_duration", false))
	_duration_slider.value = float(clamped.get("duration_seconds", 3.0))
	_duration_label.text = "Duration: %.1fs" % _duration_slider.value
	_duration_slider.visible = _duration_toggle.button_pressed
	_duration_label.visible = _duration_toggle.button_pressed
	_target_folder_edit.text = FoleyNaming.normalize_folder(str(clamped.get("target_folder", FoleyNaming.DEFAULT_OUTPUT_FOLDER)))
	_create_subfolder_toggle.button_pressed = bool(clamped.get("create_prompt_subfolder", true))

	var output_format := str(clamped.get("output_format", "pcm_44100"))
	var selected_index := _find_format_index(output_format)
	_format_option.select(selected_index)
	_update_cost_label()


func focus_primary_input() -> void:
	if _prompt_edit == null or not is_instance_valid(_prompt_edit):
		return
	if _scroll != null and _scroll.has_method("ensure_control_visible"):
		_scroll.ensure_control_visible(_prompt_edit)
	_prompt_edit.grab_focus()


func generate_from_external_form(form: Dictionary) -> void:
	var clamped := FoleySettings.clamp_form(form)
	apply_form(clamped)
	_generate_internal(clamped)


func refresh_account_state(silent: bool = true) -> void:
	_refresh_account(silent)


func generate_variations_for_paths(paths: PackedStringArray) -> void:
	if paths.is_empty():
		return
	if _is_busy or _is_running_batch or _is_running_variation_queue:
		_set_error("Wait for the current generation task to finish.")
		return
	call_deferred("_run_variation_queue", paths)


func _run_variation_queue(paths: PackedStringArray) -> void:
	if paths.is_empty():
		return
	var forms: Array[Dictionary] = []
	for path in paths:
		var form := _build_variation_form_from_metadata(path)
		if form.is_empty():
			continue
		forms.append(form)
	if forms.is_empty():
		_set_error("No Foley-generated clips selected for variation queue.")
		return

	_is_running_variation_queue = true
	var total := forms.size()
	var imported_total := 0
	var failed_total := 0
	for index in range(total):
		var form := forms[index]
		apply_form(form)
		_set_status("Variation queue %d/%d..." % [index + 1, total])
		var result: Dictionary = await _generate_internal(form)
		imported_total += int(result.get("imported_count", 0))
		failed_total += int(result.get("failed_variations", 0))
		if bool(result.get("canceled", false)):
			_set_status("Variation queue canceled at %d/%d." % [index + 1, total])
			_push_toast("Variation queue canceled.")
			_is_running_variation_queue = false
			_set_busy_state(false)
			return
		await get_tree().process_frame

	_is_running_variation_queue = false
	_set_busy_state(false)
	_set_status("Variation queue finished: imported %d clip(s), failed %d variation(s)." % [imported_total, failed_total])
	_push_toast("Variation queue finished.")


func _build_variation_form_from_metadata(audio_path: String) -> Dictionary:
	var metadata := FoleyMetadata.read_metadata(audio_path)
	if metadata.is_empty():
		return {}
	var folder := audio_path.get_base_dir()
	var form := FoleySettings.get_default_form()
	form["prompt"] = str(metadata.get("prompt", ""))
	form["variations"] = clampi(int(metadata.get("requestedVariations", form["variations"])), 1, 5)
	form["prompt_influence"] = clampf(float(metadata.get("promptInfluence", form["prompt_influence"])), 0.0, 1.0)
	form["use_custom_duration"] = bool(metadata.get("useCustomDuration", form["use_custom_duration"]))
	form["duration_seconds"] = clampf(float(metadata.get("durationSeconds", form["duration_seconds"])), 0.5, 5.0)
	form["output_format"] = str(metadata.get("outputFormat", form["output_format"]))
	form["target_folder"] = FoleyNaming.normalize_folder(folder)
	form["create_prompt_subfolder"] = false
	return FoleySettings.clamp_form(form)


func _build_ui() -> void:
	var surface := PanelContainer.new()
	surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	surface.add_theme_stylebox_override("panel", _build_panel_style(COLOR_BG, COLOR_PANEL_BORDER, 1, 8))
	add_child(surface)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	surface.add_child(margin)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_scroll.clip_contents = true
	for property_info in _scroll.get_property_list():
		if str(property_info.get("name", "")) == "horizontal_scroll_mode":
			_scroll.set("horizontal_scroll_mode", ScrollContainer.SCROLL_MODE_DISABLED)
			break
	_style_scroll_container(_scroll)
	margin.add_child(_scroll)
	call_deferred("_refresh_scroll_styles")

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	_scroll.add_child(content)

	content.add_child(_build_header())

	_layout_grid = GridContainer.new()
	_layout_grid.columns = 2
	_layout_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_layout_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout_grid.add_theme_constant_override("h_separation", 10)
	_layout_grid.add_theme_constant_override("v_separation", 10)
	content.add_child(_layout_grid)

	var left_column := VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 10)
	_layout_grid.add_child(left_column)

	_right_column = VBoxContainer.new()
	_right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_column.add_theme_constant_override("separation", 10)
	_layout_grid.add_child(_right_column)

	left_column.add_child(_build_prompt_card())
	left_column.add_child(_build_settings_card())
	_right_column.add_child(_build_results_card())
	_set_results_panel_visible(false)

	_folder_dialog = EditorFileDialog.new()
	_folder_dialog.title = "Choose Foley Output Folder"
	_folder_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	_folder_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_folder_dialog.dir_selected.connect(_on_folder_selected)
	add_child(_folder_dialog)

	_audio_preview_player = AudioStreamPlayer.new()
	add_child(_audio_preview_player)


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 10)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 2)
	row.add_child(left)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	left.add_child(title_row)

	var logo_texture := load("res://addons/foley_ai/assets/foley_logo.png") as Texture2D
	if logo_texture != null:
		var logo := TextureRect.new()
		logo.texture = logo_texture
		logo.custom_minimum_size = Vector2(64, 48)
		logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.texture_filter = Control.TEXTURE_FILTER_LINEAR
		title_row.add_child(logo)

	var title := Label.new()
	title.text = "Foley AI Generator"
	title.add_theme_color_override("font_color", COLOR_TITLE_STRONG)
	title.add_theme_font_size_override("font_size", 19)
	title_row.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Generate and import sound effects directly into your project."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	left.add_child(subtitle)

	var account_panel := PanelContainer.new()
	var account_style := _build_panel_style(COLOR_PANEL, COLOR_PANEL_BORDER, 1, 7)
	_apply_hard_shadow(account_style, COLOR_HARD_SHADOW, 1, Vector2(2, 2))
	account_panel.add_theme_stylebox_override("panel", account_style)
	row.add_child(account_panel)

	var account_body := VBoxContainer.new()
	account_body.add_theme_constant_override("separation", 4)
	account_panel.add_child(account_body)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 6)
	account_body.add_child(status_row)

	_auth_status_dot = ColorRect.new()
	_auth_status_dot.custom_minimum_size = Vector2(8, 8)
	_auth_status_dot.color = COLOR_DANGER
	status_row.add_child(_auth_status_dot)

	_auth_status_label = Label.new()
	_auth_status_label.text = "Not authenticated"
	_auth_status_label.add_theme_color_override("font_color", COLOR_DANGER)
	status_row.add_child(_auth_status_label)

	_token_label = Label.new()
	_token_label.text = "Tokens --"
	_token_label.add_theme_color_override("font_color", COLOR_TITLE)
	account_body.add_child(_token_label)

	_auth_helper_label = Label.new()
	_auth_helper_label.text = "Set your Foley API key below or in Project Settings > foley_ai/api_key."
	_auth_helper_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_auth_helper_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	account_body.add_child(_auth_helper_label)

	_api_key_row = HBoxContainer.new()
	_api_key_row.add_theme_constant_override("separation", 6)
	account_body.add_child(_api_key_row)

	_api_key_edit = LineEdit.new()
	_api_key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_api_key_edit.placeholder_text = "API key"
	_api_key_edit.secret = true
	_style_input(_api_key_edit)
	_api_key_edit.text_submitted.connect(_on_api_key_submitted)
	_api_key_row.add_child(_api_key_edit)

	_save_api_key_button = Button.new()
	_save_api_key_button.text = "Save Key"
	_style_button(_save_api_key_button, "secondary")
	_save_api_key_button.pressed.connect(_on_save_api_key_pressed)
	_api_key_row.add_child(_save_api_key_button)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 6)
	account_body.add_child(button_row)

	_auth_refresh_button = Button.new()
	_auth_refresh_button.text = "Refresh Authentication"
	_style_button(_auth_refresh_button, "secondary")
	_auth_refresh_button.pressed.connect(_refresh_account)
	button_row.add_child(_auth_refresh_button)

	_buy_tokens_button = Button.new()
	_buy_tokens_button.text = "Buy Tokens"
	_style_button(_buy_tokens_button, "buy")
	_buy_tokens_button.pressed.connect(_open_checkout_url)
	button_row.add_child(_buy_tokens_button)

	return row

func _build_prompt_card() -> Control:
	var card := _create_card("Prompt")
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var body := _card_body(card)

	_prompt_edit = TextEdit.new()
	_prompt_edit.custom_minimum_size = Vector2(0, 120)
	_prompt_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_configure_nested_text_edit(_prompt_edit)
	_style_input(_prompt_edit)
	body.add_child(_prompt_edit)

	var hint := Label.new()
	hint.text = "Describe the sound, material, intensity, and environment."
	hint.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	body.add_child(hint)

	_prompt_chip_container = HFlowContainer.new()
	_prompt_chip_container.add_theme_constant_override("h_separation", 6)
	_prompt_chip_container.add_theme_constant_override("v_separation", 6)
	body.add_child(_prompt_chip_container)

	for prompt in DEFAULT_PROMPT_CHIPS:
		var prompt_text := str(prompt)
		var chip := Button.new()
		chip.text = prompt_text
		_style_button(chip, "chip")
		chip.pressed.connect(func() -> void:
			_prompt_edit.text = prompt_text
		)
		_prompt_chip_container.add_child(chip)

	var preset_actions := HBoxContainer.new()
	preset_actions.add_theme_constant_override("separation", 6)
	body.add_child(preset_actions)

	_save_preset_button = Button.new()
	_save_preset_button.text = "Save As Preset"
	_style_button(_save_preset_button, "preset_action")
	_save_preset_button.pressed.connect(_on_save_preset_pressed)
	preset_actions.add_child(_save_preset_button)

	_remove_preset_button = Button.new()
	_remove_preset_button.text = "Remove Preset"
	_style_button(_remove_preset_button, "preset_remove")
	_remove_preset_button.pressed.connect(_on_remove_preset_pressed)
	preset_actions.add_child(_remove_preset_button)

	_recent_prompt_label = Label.new()
	_recent_prompt_label.text = "Recent Prompts"
	_recent_prompt_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	body.add_child(_recent_prompt_label)

	_recent_prompt_chips = HFlowContainer.new()
	_recent_prompt_chips.add_theme_constant_override("h_separation", 6)
	_recent_prompt_chips.add_theme_constant_override("v_separation", 6)
	body.add_child(_recent_prompt_chips)

	var batch_title := Label.new()
	batch_title.text = "Batch Generate"
	batch_title.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	body.add_child(batch_title)

	_batch_toggle = CheckBox.new()
	_batch_toggle.text = "Enable prompt queue"
	_style_checkbox(_batch_toggle)
	_batch_toggle.toggled.connect(_on_batch_mode_toggled)
	body.add_child(_batch_toggle)

	_batch_queue_container = VBoxContainer.new()
	_batch_queue_container.add_theme_constant_override("separation", 6)
	_batch_queue_container.visible = false
	body.add_child(_batch_queue_container)

	var queue_entry_row := HBoxContainer.new()
	queue_entry_row.add_theme_constant_override("separation", 6)
	_batch_queue_container.add_child(queue_entry_row)

	_batch_entry_edit = LineEdit.new()
	_batch_entry_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_batch_entry_edit.placeholder_text = "Type prompt and press Enter"
	_style_input(_batch_entry_edit)
	_batch_entry_edit.text_submitted.connect(_on_batch_entry_submitted)
	queue_entry_row.add_child(_batch_entry_edit)

	_batch_add_button = Button.new()
	_batch_add_button.text = "Add"
	_style_button(_batch_add_button, "success")
	_batch_add_button.pressed.connect(_on_batch_add_pressed)
	queue_entry_row.add_child(_batch_add_button)

	_batch_queue_list = ItemList.new()
	_batch_queue_list.custom_minimum_size = Vector2(0, 100)
	_batch_queue_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_batch_queue_list.allow_reselect = true
	_style_item_list(_batch_queue_list)
	_batch_queue_list.item_selected.connect(_on_batch_queue_item_selected)
	_batch_queue_container.add_child(_batch_queue_list)

	var queue_actions := HBoxContainer.new()
	queue_actions.add_theme_constant_override("separation", 6)
	_batch_queue_container.add_child(queue_actions)

	_batch_remove_button = Button.new()
	_batch_remove_button.text = "Remove Selected"
	_style_button(_batch_remove_button, "danger")
	_batch_remove_button.pressed.connect(_on_batch_remove_selected_pressed)
	_batch_remove_button.disabled = true
	queue_actions.add_child(_batch_remove_button)

	_batch_clear_button = Button.new()
	_batch_clear_button.text = "Clear Queue"
	_style_button(_batch_clear_button, "warning")
	_batch_clear_button.pressed.connect(_on_batch_clear_pressed)
	_batch_clear_button.disabled = true
	queue_actions.add_child(_batch_clear_button)

	_batch_hint_label = Label.new()
	_batch_hint_label.text = "Queue runs from top to bottom. Press Enter, click Add, or click Generate to include the pending line."
	_batch_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_batch_hint_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	_batch_hint_label.visible = false
	body.add_child(_batch_hint_label)
	_refresh_batch_queue_ui()

	return card


func _build_settings_card() -> Control:
	var card := _create_card("Settings")
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var body := _card_body(card)
	body.add_theme_constant_override("separation", 4)

	body.add_child(_create_section_label("Generation Settings"))

	_settings_grid = GridContainer.new()
	_settings_grid.columns = 2
	_settings_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_grid.add_theme_constant_override("h_separation", 5)
	_settings_grid.add_theme_constant_override("v_separation", 5)
	body.add_child(_settings_grid)

	var variations_group := VBoxContainer.new()
	variations_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	variations_group.add_theme_constant_override("separation", 3)
	_settings_grid.add_child(variations_group)

	var variations_title := Label.new()
	variations_title.text = "Variations"
	variations_title.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	variations_group.add_child(variations_title)

	_variations_spin = SpinBox.new()
	_configure_variations_spinbox(_variations_spin)
	_variations_spin.value_changed.connect(_on_variations_changed)
	variations_group.add_child(_variations_spin)

	_variations_label = Label.new()
	_variations_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	variations_group.add_child(_variations_label)

	var format_group := VBoxContainer.new()
	format_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	format_group.add_theme_constant_override("separation", 3)
	_settings_grid.add_child(format_group)

	var format_title := Label.new()
	format_title.text = "Output Format"
	format_title.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	format_group.add_child(format_title)

	_format_option = OptionButton.new()
	_format_option.fit_to_longest_item = false
	_format_option.clip_text = true
	_format_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_option_button(_format_option)
	for format in FoleySettings.get_output_formats():
		_format_option.add_item(FoleySettings.format_output_format_label(format))
	var format_popup := _format_option.get_popup()
	if format_popup != null:
		format_popup.add_theme_color_override("font_color", COLOR_TEXT)
		format_popup.add_theme_color_override("font_hover_color", COLOR_TEXT)
		format_popup.add_theme_color_override("font_pressed_color", COLOR_PRIMARY_BLUE_HOVER)
		format_popup.add_theme_color_override("font_focus_color", COLOR_TEXT)
		format_popup.add_theme_color_override("font_accelerator_color", COLOR_TEXT_MUTED)
		format_popup.add_theme_color_override("font_disabled_color", COLOR_TEXT_MUTED)
		format_popup.add_theme_stylebox_override("panel", _build_panel_style(COLOR_INPUT_BG, COLOR_ACCENT, 1, 6))
		var popup_hover_style := _build_popup_hover_style()
		format_popup.add_theme_stylebox_override("hover", popup_hover_style)
		format_popup.add_theme_stylebox_override("hover_pressed", popup_hover_style)
		format_popup.add_theme_stylebox_override("focus", popup_hover_style)
		format_popup.add_theme_icon_override("checked", _create_popup_selection_icon(true))
		format_popup.add_theme_icon_override("radio_checked", _create_popup_selection_icon(true))
		format_popup.add_theme_icon_override("checked_disabled", _create_popup_selection_icon(true))
		format_popup.add_theme_icon_override("radio_checked_disabled", _create_popup_selection_icon(true))
		format_popup.add_theme_icon_override("unchecked", _create_popup_selection_icon(false))
		format_popup.add_theme_icon_override("radio_unchecked", _create_popup_selection_icon(false))
		format_popup.add_theme_icon_override("unchecked_disabled", _create_popup_selection_icon(false))
		format_popup.add_theme_icon_override("radio_unchecked_disabled", _create_popup_selection_icon(false))
	format_group.add_child(_format_option)

	var influence_group := VBoxContainer.new()
	influence_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	influence_group.add_theme_constant_override("separation", 3)
	_settings_grid.add_child(influence_group)

	var influence_title := Label.new()
	influence_title.text = "Prompt Influence"
	influence_title.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	influence_group.add_child(influence_title)

	_influence_slider = HSlider.new()
	_influence_slider.min_value = 0.0
	_influence_slider.max_value = 1.0
	_influence_slider.step = 0.1
	_style_slider(_influence_slider)
	_disable_wheel_change(_influence_slider)
	_release_focus_on_mouse_exit(_influence_slider)
	_influence_slider.value_changed.connect(_on_influence_changed)
	influence_group.add_child(_influence_slider)

	_influence_label = Label.new()
	_influence_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	influence_group.add_child(_influence_label)

	var duration_group := VBoxContainer.new()
	duration_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duration_group.add_theme_constant_override("separation", 3)
	_settings_grid.add_child(duration_group)

	var duration_title := Label.new()
	duration_title.text = "Duration"
	duration_title.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	duration_group.add_child(duration_title)

	_duration_toggle = CheckBox.new()
	_duration_toggle.text = "Custom Duration"
	_style_checkbox(_duration_toggle)
	_duration_toggle.toggled.connect(_on_duration_toggled)
	duration_group.add_child(_duration_toggle)

	_duration_slider = HSlider.new()
	_duration_slider.min_value = 0.5
	_duration_slider.max_value = 5.0
	_duration_slider.step = 0.1
	_style_slider(_duration_slider)
	_disable_wheel_change(_duration_slider)
	_release_focus_on_mouse_exit(_duration_slider)
	_duration_slider.value_changed.connect(_on_duration_changed)
	duration_group.add_child(_duration_slider)

	_duration_label = Label.new()
	_duration_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	duration_group.add_child(_duration_label)

	body.add_child(_create_section_label("Import"))

	var folder_row := HBoxContainer.new()
	folder_row.add_theme_constant_override("separation", 6)
	body.add_child(folder_row)

	_target_folder_edit = LineEdit.new()
	_target_folder_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_input(_target_folder_edit)
	folder_row.add_child(_target_folder_edit)

	var browse_button := Button.new()
	browse_button.text = "Browse..."
	_style_button(browse_button, "secondary")
	browse_button.pressed.connect(_on_browse_folder_pressed)
	folder_row.add_child(browse_button)

	_create_subfolder_toggle = CheckBox.new()
	_create_subfolder_toggle.text = "Create prompt subfolder"
	_style_checkbox(_create_subfolder_toggle)
	_create_subfolder_toggle.button_pressed = true
	body.add_child(_create_subfolder_toggle)

	var separator := HSeparator.new()
	body.add_child(separator)

	var generate_row := HBoxContainer.new()
	generate_row.add_theme_constant_override("separation", 8)
	generate_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	body.add_child(generate_row)

	_generate_button = Button.new()
	_generate_button.text = "Generate & Import"
	_generate_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_generate_button.custom_minimum_size = Vector2(290, 40)
	_style_button(_generate_button, "primary")
	_generate_button.pressed.connect(_on_generate_pressed)
	generate_row.add_child(_generate_button)

	_estimated_cost_label = Label.new()
	_estimated_cost_label.add_theme_color_override("font_color", COLOR_PRIMARY_BLUE_HOVER)
	_estimated_cost_label.add_theme_font_size_override("font_size", 16)
	_estimated_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	generate_row.add_child(_estimated_cost_label)

	var action_spacer := Control.new()
	action_spacer.custom_minimum_size = Vector2(0, 8)
	body.add_child(action_spacer)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	body.add_child(action_row)

	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_style_button(_cancel_button, "danger")
	_cancel_button.disabled = true
	_cancel_button.pressed.connect(_on_cancel_pressed)
	action_row.add_child(_cancel_button)

	_retry_button = Button.new()
	_retry_button.text = "Retry Failed"
	_style_button(_retry_button, "secondary")
	_retry_button.disabled = true
	_retry_button.pressed.connect(_on_retry_pressed)
	action_row.add_child(_retry_button)

	_insufficient_tokens_toast = PanelContainer.new()
	_insufficient_tokens_toast.visible = false
	_insufficient_tokens_toast.add_theme_stylebox_override("panel", _build_panel_style(COLOR_DANGER_SOFT, COLOR_DANGER, 1, 6))
	body.add_child(_insufficient_tokens_toast)

	var toast_row := HBoxContainer.new()
	toast_row.add_theme_constant_override("separation", 8)
	_insufficient_tokens_toast.add_child(toast_row)

	_insufficient_tokens_label = Label.new()
	_insufficient_tokens_label.text = "Insufficient tokens."
	_insufficient_tokens_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_insufficient_tokens_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_insufficient_tokens_label.add_theme_color_override("font_color", COLOR_DANGER_HOVER)
	toast_row.add_child(_insufficient_tokens_label)

	_insufficient_tokens_button = Button.new()
	_insufficient_tokens_button.text = "Buy More Tokens"
	_style_button(_insufficient_tokens_button, "buy")
	_insufficient_tokens_button.pressed.connect(_open_checkout_url)
	toast_row.add_child(_insufficient_tokens_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	_status_label.visible = false
	body.add_child(_status_label)

	return card

func _build_results_card() -> Control:
	var card := _create_card("Generated Clips")
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var body := _card_body(card)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	body.add_child(toolbar)

	_play_result_button = Button.new()
	_play_result_button.text = "Preview"
	_style_button(_play_result_button, "secondary")
	_play_result_button.visible = false
	_play_result_button.disabled = true
	_play_result_button.pressed.connect(_on_preview_result_pressed)
	toolbar.add_child(_play_result_button)

	_copy_path_button = Button.new()
	_copy_path_button.text = "Copy Path"
	_style_button(_copy_path_button, "secondary")
	_copy_path_button.visible = false
	_copy_path_button.disabled = true
	_copy_path_button.pressed.connect(_on_copy_path_pressed)
	toolbar.add_child(_copy_path_button)

	_retry_selected_button = Button.new()
	_retry_selected_button.text = "Retry Selected"
	_style_button(_retry_selected_button, "secondary")
	_retry_selected_button.visible = false
	_retry_selected_button.disabled = true
	_retry_selected_button.pressed.connect(_on_retry_selected_pressed)
	toolbar.add_child(_retry_selected_button)

	_show_in_fs_button = Button.new()
	_show_in_fs_button.text = "Open Folder"
	_style_button(_show_in_fs_button, "secondary")
	_show_in_fs_button.visible = false
	_show_in_fs_button.disabled = true
	_show_in_fs_button.pressed.connect(_on_show_in_fs_pressed)
	toolbar.add_child(_show_in_fs_button)

	body.add_child(_create_section_label("Session Summary"))

	_session_summary_label = Label.new()
	_session_summary_label.text = "No generation run yet."
	_session_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_session_summary_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	body.add_child(_session_summary_label)

	_results_empty_label = Label.new()
	_results_empty_label.text = "No clips generated yet.\nYour imported files will appear here."
	_results_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_results_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_results_empty_label.custom_minimum_size = Vector2(0, 250)
	_results_empty_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	body.add_child(_results_empty_label)

	_results_list = ItemList.new()
	_results_list.custom_minimum_size = Vector2(0, 250)
	_results_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_results_list.allow_reselect = true
	_results_list.allow_rmb_select = true
	_style_item_list(_results_list)
	_results_list.item_selected.connect(_on_result_selected)
	_results_list.item_activated.connect(_on_result_activated)
	body.add_child(_results_list)

	return card


func _create_card(title: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _build_panel_style(COLOR_PANEL, COLOR_PANEL_BORDER, 1, 8))

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(content)

	var header := Label.new()
	header.text = title
	header.add_theme_color_override("font_color", COLOR_TITLE_STRONG)
	header.add_theme_font_size_override("font_size", 18)
	content.add_child(header)

	var divider := HSeparator.new()
	divider.add_theme_color_override("separator", Color(0.8471, 0.8118, 0.6745, 1.0)) # #D8CFAC
	content.add_child(divider)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	card.set_meta("body", body)
	return card


func _card_body(card: Control) -> VBoxContainer:
	return card.get_meta("body") as VBoxContainer


func _create_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", COLOR_PRIMARY_BLUE_HOVER)
	label.add_theme_font_size_override("font_size", 16)
	return label


func _build_panel_style(background: Color, border: Color, border_width: int = 1, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin(SIDE_LEFT, 10)
	style.set_content_margin(SIDE_TOP, 8)
	style.set_content_margin(SIDE_RIGHT, 10)
	style.set_content_margin(SIDE_BOTTOM, 8)
	return style


func _apply_hard_shadow(style: StyleBoxFlat, color: Color = COLOR_SHADOW, size: int = 2, offset: Vector2 = Vector2(2, 2)) -> void:
	style.shadow_color = color
	style.shadow_size = size
	style.shadow_offset = offset


func _build_button_style(
	fill: Color,
	border: Color,
	shadow_size: int = 1,
	shadow_offset: Vector2 = Vector2(2, 2),
	shadow_color: Color = COLOR_HARD_SHADOW
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.set_content_margin(SIDE_LEFT, 10)
	style.set_content_margin(SIDE_TOP, 7)
	style.set_content_margin(SIDE_RIGHT, 10)
	style.set_content_margin(SIDE_BOTTOM, 7)
	_apply_hard_shadow(style, shadow_color, shadow_size, shadow_offset)
	return style


func _style_button(button: Button, kind: String) -> void:
	var normal := COLOR_PANEL
	var hover := COLOR_SECONDARY_HOVER
	var border := COLOR_PANEL_BORDER
	var text := COLOR_TEXT
	var shadow_base := 2
	var shadow_color := COLOR_HARD_SHADOW
	var shadow_blur := 1
	var normal_style: StyleBoxFlat
	var hover_style: StyleBoxFlat
	var pressed_style: StyleBoxFlat
	var disabled_style: StyleBoxFlat
	match kind:
		"primary":
			normal = COLOR_PRIMARY_BLUE
			hover = COLOR_PRIMARY_BLUE_HOVER
			border = COLOR_PRIMARY_BLUE_HOVER
			text = COLOR_PANEL
			shadow_base = 3
		"buy":
			normal = COLOR_PRIMARY_BLUE
			hover = COLOR_PRIMARY_BLUE_HOVER
			border = COLOR_PRIMARY_BLUE_HOVER
			text = COLOR_PANEL
			shadow_base = 2
		"preset_action":
			normal = COLOR_SUCCESS_STRONG
			hover = COLOR_SUCCESS_HOVER
			border = COLOR_SUCCESS_HOVER
			text = COLOR_PANEL
			shadow_base = 3
		"success":
			normal = COLOR_SUCCESS_BG
			hover = COLOR_SUCCESS_HOVER
			border = COLOR_SUCCESS_HOVER
			text = COLOR_PANEL
			shadow_base = 3
		"preset_remove":
			normal = COLOR_DANGER
			hover = COLOR_DANGER_HOVER
			border = COLOR_DANGER_HOVER
			text = COLOR_PANEL
			shadow_base = 3
		"warning":
			normal = COLOR_PANEL.lerp(COLOR_ACCENT, 0.25)
			hover = COLOR_ACCENT.lerp(COLOR_PANEL, 0.18)
			border = COLOR_ACCENT
			text = COLOR_TITLE
			shadow_base = 2
		"danger":
			normal = COLOR_DANGER
			hover = COLOR_DANGER_HOVER
			border = hover
			text = COLOR_PANEL
			shadow_base = 3
		"chip":
			normal = COLOR_PANEL
			hover = COLOR_CHIP_HOVER
			border = COLOR_PANEL_BORDER
			shadow_base = 1
		"secondary":
			normal = COLOR_PANEL
			hover = COLOR_SECONDARY_HOVER
			border = COLOR_PANEL_BORDER
			shadow_base = 2
		_:
			pass

	var pressed_fill := hover.darkened(0.06)
	var disabled_fill := normal.lerp(COLOR_PANEL, 0.5)
	var disabled_border := border.lerp(COLOR_PANEL_BORDER, 0.35)
	var hover_shadow := maxi(0, shadow_base - 1)
	var pressed_shadow := maxi(0, shadow_base - 2)
	var disabled_shadow := maxi(0, shadow_base - 2)
	normal_style = _build_button_style(normal, border, shadow_blur, Vector2(shadow_base, shadow_base), shadow_color)
	hover_style = _build_button_style(hover, border, shadow_blur, Vector2(hover_shadow, hover_shadow), shadow_color)
	pressed_style = _build_button_style(pressed_fill, border, shadow_blur, Vector2(pressed_shadow, pressed_shadow), shadow_color)
	disabled_style = _build_button_style(disabled_fill, disabled_border, shadow_blur, Vector2(disabled_shadow, disabled_shadow), shadow_color)
	if kind == "primary":
		normal_style.set_content_margin(SIDE_TOP, 9)
		normal_style.set_content_margin(SIDE_BOTTOM, 9)
		hover_style.set_content_margin(SIDE_TOP, 9)
		hover_style.set_content_margin(SIDE_BOTTOM, 9)
		pressed_style.set_content_margin(SIDE_TOP, 9)
		pressed_style.set_content_margin(SIDE_BOTTOM, 9)
		disabled_style.set_content_margin(SIDE_TOP, 9)
		disabled_style.set_content_margin(SIDE_BOTTOM, 9)
		button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_color_override("font_color", text)
	button.add_theme_color_override("font_hover_color", text)
	button.add_theme_color_override("font_hover_pressed_color", text)
	button.add_theme_color_override("font_pressed_color", text)
	button.add_theme_color_override("font_focus_color", COLOR_TITLE)
	button.add_theme_color_override("font_disabled_color", Color(text.r, text.g, text.b, 0.6))


func _style_input(control: Control) -> void:
	var normal := _build_panel_style(COLOR_INPUT_BG, COLOR_ACCENT, 1, 6)
	var focus := _build_panel_style(COLOR_INPUT_BG, COLOR_PRIMARY_BLUE, 1, 6)
	_apply_hard_shadow(normal, COLOR_SHADOW, 2, Vector2(2, 2))
	_apply_hard_shadow(focus, COLOR_PRIMARY_BLUE_HOVER, 2, Vector2(2, 2))
	control.add_theme_stylebox_override("normal", normal)
	control.add_theme_stylebox_override("focus", focus)
	control.add_theme_stylebox_override("read_only", normal)
	control.add_theme_color_override("font_color", COLOR_TEXT)
	control.add_theme_color_override("font_placeholder_color", COLOR_TEXT_MUTED)
	control.add_theme_color_override("caret_color", COLOR_PRIMARY_BLUE)
	control.add_theme_color_override("selection_color", COLOR_PRIMARY_BLUE.lerp(COLOR_PANEL, 0.52))


func _style_option_button(option: OptionButton) -> void:
	var normal := _build_button_style(COLOR_INPUT_BG, COLOR_ACCENT)
	var hover := _build_button_style(COLOR_CHIP_HOVER, COLOR_PANEL_BORDER)
	option.add_theme_stylebox_override("normal", normal)
	option.add_theme_stylebox_override("hover", hover)
	option.add_theme_stylebox_override("pressed", hover)
	option.add_theme_stylebox_override("disabled", normal)
	var font := COLOR_TEXT
	option.add_theme_color_override("font_color", font)
	option.add_theme_color_override("font_hover_color", font)
	option.add_theme_color_override("font_hover_pressed_color", font)
	option.add_theme_color_override("font_pressed_color", font)
	option.add_theme_color_override("font_focus_color", COLOR_TITLE)
	option.add_theme_color_override("font_disabled_color", COLOR_TEXT_MUTED)


func _configure_variations_spinbox(spin: SpinBox) -> void:
	spin.min_value = 1
	spin.max_value = 5
	spin.step = 1
	spin.rounded = true
	spin.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	spin.custom_minimum_size = Vector2(96, 0)
	_set_control_property_if_exists(spin, "allow_greater", false)
	_set_control_property_if_exists(spin, "allow_lesser", false)
	_disable_wheel_change(spin)
	_release_focus_on_mouse_exit(spin)
	var line_edit := spin.get_line_edit()
	if line_edit != null:
		_disable_wheel_change(line_edit)
		_style_input(line_edit)
		_set_control_property_if_exists(line_edit, "alignment", HORIZONTAL_ALIGNMENT_CENTER)
		_set_control_property_if_exists(line_edit, "horizontal_alignment", HORIZONTAL_ALIGNMENT_CENTER)
		_set_control_property_if_exists(line_edit, "select_all_on_focus", true)


func _style_scroll_container(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	_style_scroll_bar(scroll.get_v_scroll_bar(), true)
	_style_scroll_bar(scroll.get_h_scroll_bar(), false)


func _refresh_scroll_styles() -> void:
	_style_scroll_container(_scroll)


func _style_scroll_bar(scroll_bar: ScrollBar, vertical: bool) -> void:
	if scroll_bar == null:
		return
	scroll_bar.custom_minimum_size = Vector2(14, 0) if vertical else Vector2(0, 14)
	var track := StyleBoxFlat.new()
	track.bg_color = COLOR_ACCENT.lerp(COLOR_PANEL, 0.15)
	track.border_color = COLOR_ACCENT.lerp(COLOR_PANEL_BORDER, 0.22)
	track.set_border_width_all(1)
	track.set_corner_radius_all(6)
	var track_focus := track.duplicate() as StyleBoxFlat
	track_focus.border_color = COLOR_PRIMARY_BLUE
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = COLOR_PRIMARY_BLUE.lerp(COLOR_PANEL, 0.08)
	grabber.border_color = COLOR_PRIMARY_BLUE_HOVER
	grabber.set_border_width_all(1)
	grabber.set_corner_radius_all(6)
	var grabber_highlight := grabber.duplicate() as StyleBoxFlat
	grabber_highlight.bg_color = COLOR_PRIMARY_BLUE
	var grabber_pressed := grabber.duplicate() as StyleBoxFlat
	grabber_pressed.bg_color = COLOR_PRIMARY_BLUE_HOVER
	scroll_bar.add_theme_stylebox_override("scroll", track)
	scroll_bar.add_theme_stylebox_override("scroll_focus", track_focus)
	scroll_bar.add_theme_stylebox_override("grabber", grabber)
	scroll_bar.add_theme_stylebox_override("grabber_highlight", grabber_highlight)
	scroll_bar.add_theme_stylebox_override("grabber_pressed", grabber_pressed)
	var clear_icon := _create_clear_texture()
	for icon_name in [
		"increment",
		"increment_highlight",
		"increment_pressed",
		"decrement",
		"decrement_highlight",
		"decrement_pressed"
	]:
		scroll_bar.add_theme_icon_override(icon_name, clear_icon)


func _build_popup_hover_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CHIP_HOVER
	style.border_color = COLOR_CHIP_HOVER
	style.set_border_width_all(0)
	style.set_corner_radius_all(5)
	style.set_content_margin(SIDE_LEFT, 4)
	style.set_content_margin(SIDE_TOP, 2)
	style.set_content_margin(SIDE_RIGHT, 4)
	style.set_content_margin(SIDE_BOTTOM, 2)
	return style


func _create_popup_selection_icon(selected: bool) -> Texture2D:
	var size := 10
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	if selected:
		_draw_icon_line(image, Vector2i(1, 5), Vector2i(4, 8), COLOR_PRIMARY_BLUE_HOVER, 2)
		_draw_icon_line(image, Vector2i(4, 8), Vector2i(9, 2), COLOR_PRIMARY_BLUE_HOVER, 2)
	return ImageTexture.create_from_image(image)


func _create_clear_texture() -> Texture2D:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	return ImageTexture.create_from_image(image)


func _style_checkbox(toggle: CheckBox) -> void:
	toggle.add_theme_color_override("font_color", COLOR_TEXT)
	toggle.add_theme_color_override("font_hover_color", COLOR_TEXT)
	toggle.add_theme_color_override("font_hover_pressed_color", COLOR_TEXT)
	toggle.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	toggle.add_theme_color_override("font_focus_color", COLOR_TITLE)
	toggle.add_theme_color_override("font_disabled_color", COLOR_TEXT_MUTED)
	toggle.add_theme_icon_override("unchecked", _create_checkbox_icon_texture(false, false))
	toggle.add_theme_icon_override("checked", _create_checkbox_icon_texture(true, false))
	toggle.add_theme_icon_override("unchecked_disabled", _create_checkbox_icon_texture(false, true))
	toggle.add_theme_icon_override("checked_disabled", _create_checkbox_icon_texture(true, true))


func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = COLOR_ACCENT.lerp(COLOR_PANEL, 0.25)
	track.set_corner_radius_all(5)
	track.set_content_margin(SIDE_TOP, 4)
	track.set_content_margin(SIDE_BOTTOM, 4)
	_apply_hard_shadow(track, Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.45), 1, Vector2(1, 1))
	slider.add_theme_stylebox_override("slider", track)

	var fill := StyleBoxFlat.new()
	fill.bg_color = COLOR_PRIMARY_BLUE
	fill.set_corner_radius_all(5)
	fill.set_content_margin(SIDE_TOP, 4)
	fill.set_content_margin(SIDE_BOTTOM, 4)
	_apply_hard_shadow(fill, Color(COLOR_PRIMARY_BLUE_HOVER.r, COLOR_PRIMARY_BLUE_HOVER.g, COLOR_PRIMARY_BLUE_HOVER.b, 0.35), 1, Vector2(1, 1))
	slider.add_theme_stylebox_override("grabber_area", fill)
	var fill_highlight := fill.duplicate() as StyleBoxFlat
	fill_highlight.bg_color = COLOR_PRIMARY_BLUE.lerp(COLOR_PANEL, 0.12)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_highlight)
	slider.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var grabber := _create_slider_grabber_texture(
		20,
		COLOR_PRIMARY_BLUE,
		COLOR_PRIMARY_BLUE.lerp(COLOR_PANEL, 0.30),
		COLOR_PANEL,
		COLOR_SLIDER_SHADOW,
		Vector2i(1, 2)
	)
	var grabber_highlight := _create_slider_grabber_texture(
		20,
		COLOR_PRIMARY_BLUE_HOVER,
		COLOR_PRIMARY_BLUE,
		COLOR_PANEL,
		COLOR_SLIDER_SHADOW,
		Vector2i(1, 2)
	)
	var grabber_disabled := _create_slider_grabber_texture(
		20,
		COLOR_TEXT_MUTED,
		COLOR_ACCENT.lerp(COLOR_PANEL, 0.45),
		COLOR_PANEL,
		Color(COLOR_SLIDER_SHADOW.r, COLOR_SLIDER_SHADOW.g, COLOR_SLIDER_SHADOW.b, 0.35),
		Vector2i(1, 1)
	)
	slider.add_theme_icon_override("grabber", grabber)
	slider.add_theme_icon_override("grabber_highlight", grabber_highlight)
	slider.add_theme_icon_override("grabber_disabled", grabber_disabled)


func _style_item_list(list: ItemList) -> void:
	var panel := _build_panel_style(COLOR_INPUT_BG, COLOR_ACCENT, 1, 6)
	_apply_hard_shadow(panel, COLOR_SHADOW, 2, Vector2(2, 2))
	list.add_theme_stylebox_override("panel", panel)

	var selected := _build_button_style(COLOR_ITEM_SELECTED, COLOR_PRIMARY_BLUE)
	selected.set_content_margin(SIDE_LEFT, 6)
	selected.set_content_margin(SIDE_TOP, 3)
	selected.set_content_margin(SIDE_RIGHT, 6)
	selected.set_content_margin(SIDE_BOTTOM, 3)
	list.add_theme_stylebox_override("selected", selected)
	list.add_theme_stylebox_override("selected_focus", selected)

	var hovered := _build_button_style(COLOR_ITEM_HOVER, COLOR_ACCENT)
	hovered.set_content_margin(SIDE_LEFT, 6)
	hovered.set_content_margin(SIDE_TOP, 3)
	hovered.set_content_margin(SIDE_RIGHT, 6)
	hovered.set_content_margin(SIDE_BOTTOM, 3)
	list.add_theme_stylebox_override("hovered", hovered)
	list.add_theme_stylebox_override("hovered_selected", selected)
	list.add_theme_stylebox_override("cursor", selected)
	list.add_theme_stylebox_override("cursor_unfocused", hovered)

	var font := COLOR_TEXT
	list.add_theme_color_override("font_color", font)
	list.add_theme_color_override("font_selected_color", COLOR_TITLE_STRONG)
	list.add_theme_color_override("font_hovered_color", COLOR_TITLE_STRONG)


func _create_slider_grabber_texture(
	size: int,
	border_color: Color,
	fill_color: Color,
	center_color: Color,
	shadow_color: Color = Color(0.0, 0.0, 0.0, 0.0),
	shadow_offset: Vector2i = Vector2i.ZERO
) -> Texture2D:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center := Vector2((size - 1) / 2.0, (size - 1) / 2.0)
	var radius := (size / 2.0) - 1.0
	var shadow_center := center + Vector2(float(shadow_offset.x), float(shadow_offset.y))
	for y in range(size):
		for x in range(size):
			if shadow_color.a > 0.0:
				var shadow_distance := Vector2(x, y).distance_to(shadow_center)
				if shadow_distance <= radius:
					image.set_pixel(x, y, shadow_color)
			var distance := Vector2(x, y).distance_to(center)
			if distance <= radius:
				var pixel := border_color
				if distance < radius - 2.0:
					pixel = fill_color
				if distance < radius - 6.0:
					pixel = center_color
				image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)


func _create_checkbox_icon_texture(checked: bool, disabled: bool) -> Texture2D:
	var size := 16
	var border := COLOR_PANEL_BORDER
	var fill := COLOR_INPUT_BG
	var mark := COLOR_PRIMARY_BLUE_HOVER
	if disabled:
		border = COLOR_TEXT_MUTED
		fill = COLOR_INPUT_BG.lerp(COLOR_PANEL, 0.3)
		mark = COLOR_TEXT_MUTED

	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in range(size):
		for x in range(size):
			if x >= 1 and x <= size - 2 and y >= 1 and y <= size - 2:
				image.set_pixel(x, y, fill)
			if x == 1 or x == size - 2 or y == 1 or y == size - 2:
				image.set_pixel(x, y, border)

	if checked:
		_draw_icon_line(image, Vector2i(4, 8), Vector2i(7, 11), mark, 3)
		_draw_icon_line(image, Vector2i(7, 11), Vector2i(12, 5), mark, 3)

	return ImageTexture.create_from_image(image)


func _draw_icon_line(image: Image, from: Vector2i, to: Vector2i, color: Color, thickness: int = 1) -> void:
	var steps := maxi(abs(to.x - from.x), abs(to.y - from.y))
	if steps <= 0:
		_plot_thick_pixel(image, from.x, from.y, color, thickness)
		return
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var x := int(round(lerpf(float(from.x), float(to.x), t)))
		var y := int(round(lerpf(float(from.y), float(to.y), t)))
		_plot_thick_pixel(image, x, y, color, thickness)


func _plot_thick_pixel(image: Image, x: int, y: int, color: Color, thickness: int) -> void:
	var half := maxi(0, int((thickness - 1) / 2))
	for oy in range(-half, half + 1):
		for ox in range(-half, half + 1):
			var px := x + ox
			var py := y + oy
			if px >= 0 and px < image.get_width() and py >= 0 and py < image.get_height():
				image.set_pixel(px, py, color)


func _set_control_property_if_exists(control: Object, property_name: String, value: Variant) -> void:
	if control == null:
		return
	for property_info in control.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			control.set(property_name, value)
			return


func _configure_nested_text_edit(text_edit: TextEdit) -> void:
	text_edit.focus_mode = Control.FOCUS_ALL
	text_edit.editable = true
	_set_control_property_if_exists(text_edit, "context_menu_enabled", true)
	_set_control_property_if_exists(text_edit, "shortcut_keys_enabled", true)
	_set_control_property_if_exists(text_edit, "selecting_enabled", true)
	var has_scroll_passthrough_property := false
	for property_info in text_edit.get_property_list():
		if str(property_info.get("name", "")) == "mouse_force_pass_scroll_events":
			text_edit.set("mouse_force_pass_scroll_events", true)
			has_scroll_passthrough_property = true
			break
	if has_scroll_passthrough_property:
		text_edit.focus_entered.connect(func() -> void:
			text_edit.set("mouse_force_pass_scroll_events", false)
		)
		text_edit.focus_exited.connect(func() -> void:
			text_edit.set("mouse_force_pass_scroll_events", true)
		)
	text_edit.mouse_exited.connect(func() -> void:
		if text_edit.has_focus():
			text_edit.release_focus()
	)

func _disable_wheel_change(control: Control) -> void:
	for property_info in control.get_property_list():
		if str(property_info.get("name", "")) == "scrollable":
			control.set("scrollable", false)
			break
	_block_wheel_input(control)


func _block_wheel_input(control: Control) -> void:
	control.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var button_event := event as InputEventMouseButton
			if button_event.pressed and (
				button_event.button_index == MOUSE_BUTTON_WHEEL_UP
				or button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN
			) and control.has_focus():
				control.accept_event()
	)


func _release_focus_on_mouse_exit(control: Control) -> void:
	control.mouse_exited.connect(func() -> void:
		if control.has_focus():
			control.release_focus()
	)


func _apply_default_values() -> void:
	apply_form(FoleySettings.get_default_form())


func _editor_settings() -> EditorSettings:
	if _editor_interface == null:
		return null
	return _editor_interface.get_editor_settings()


func _refresh_prompt_library_ui() -> void:
	_refresh_prompt_preset_chips()
	_refresh_recent_prompt_chips()


func _refresh_prompt_preset_chips() -> void:
	if _prompt_chip_container == null:
		return
	for child in _prompt_chip_container.get_children():
		child.queue_free()

	var prompts := PackedStringArray()
	for prompt in DEFAULT_PROMPT_CHIPS:
		prompts.append(prompt)
	for prompt in FoleySettings.get_prompt_presets():
		if prompts.has(prompt):
			continue
		prompts.append(prompt)

	for prompt in prompts:
		var prompt_text := str(prompt)
		var chip := Button.new()
		chip.text = prompt_text
		_style_button(chip, "chip")
		chip.pressed.connect(func() -> void:
			_prompt_edit.text = prompt_text
		)
		_prompt_chip_container.add_child(chip)


func _refresh_recent_prompt_chips() -> void:
	if _recent_prompt_chips == null:
		return
	for child in _recent_prompt_chips.get_children():
		child.queue_free()

	var history := FoleySettings.get_prompt_history()
	var has_history := not history.is_empty()
	if _recent_prompt_label != null:
		_recent_prompt_label.visible = has_history
	_recent_prompt_chips.visible = has_history

	for prompt in history:
		var prompt_text := str(prompt)
		var chip := Button.new()
		chip.text = prompt_text
		_style_button(chip, "chip")
		chip.pressed.connect(func() -> void:
			_prompt_edit.text = prompt_text
		)
		_recent_prompt_chips.add_child(chip)


func _on_save_preset_pressed() -> void:
	var prompt := _prompt_edit.text.strip_edges()
	if prompt.is_empty():
		_set_error("Enter a prompt before saving a preset.")
		return
	FoleySettings.add_prompt_preset(prompt)
	_refresh_prompt_library_ui()
	_set_status("Saved preset.")


func _on_remove_preset_pressed() -> void:
	var prompt := _prompt_edit.text.strip_edges()
	if prompt.is_empty():
		_set_error("Enter a prompt to remove a preset.")
		return
	var before := FoleySettings.get_prompt_presets()
	if not before.has(prompt):
		_set_error("Prompt is not in saved presets.")
		return
	FoleySettings.remove_prompt_preset(prompt)
	_refresh_prompt_library_ui()


func _on_batch_mode_toggled(enabled: bool) -> void:
	if _batch_queue_container != null:
		_batch_queue_container.visible = enabled
	if _batch_hint_label != null:
		_batch_hint_label.visible = enabled
	if enabled and _batch_entry_edit != null:
		_batch_entry_edit.call_deferred("grab_focus")


func _on_batch_entry_submitted(text: String) -> void:
	_add_batch_prompt(text)


func _on_batch_add_pressed() -> void:
	if _batch_entry_edit == null:
		return
	_add_batch_prompt(_batch_entry_edit.text)


func _add_batch_prompt(prompt_text: String) -> void:
	var normalized := prompt_text.strip_edges()
	if normalized.is_empty():
		return
	_batch_prompts.append(normalized)
	if _batch_entry_edit != null:
		_batch_entry_edit.clear()
		_batch_entry_edit.grab_focus()
	_refresh_batch_queue_ui()


func _on_batch_queue_item_selected(_index: int) -> void:
	if _batch_remove_button != null:
		_batch_remove_button.disabled = false


func _on_batch_remove_selected_pressed() -> void:
	if _batch_queue_list == null:
		return
	var selected := _batch_queue_list.get_selected_items()
	if selected.is_empty():
		return
	var index := int(selected[0])
	if index < 0 or index >= _batch_prompts.size():
		return
	_batch_prompts.remove_at(index)
	_refresh_batch_queue_ui()


func _on_batch_clear_pressed() -> void:
	_batch_prompts = []
	_refresh_batch_queue_ui()


func _refresh_batch_queue_ui() -> void:
	if _batch_queue_list == null:
		return
	_batch_queue_list.clear()
	for i in range(_batch_prompts.size()):
		_batch_queue_list.add_item("%d. %s" % [i + 1, _batch_prompts[i]])
		var item_index := _batch_queue_list.get_item_count() - 1
		_batch_queue_list.set_item_tooltip(item_index, _batch_prompts[i])

	var has_items := _batch_prompts.size() > 0
	if _batch_remove_button != null:
		_batch_remove_button.disabled = true
	if _batch_clear_button != null:
		_batch_clear_button.disabled = not has_items


func _on_api_key_submitted(_text: String) -> void:
	_on_save_api_key_pressed()


func _on_save_api_key_pressed() -> void:
	if _api_key_edit == null:
		return
	var api_key := _api_key_edit.text.strip_edges()
	if api_key.is_empty():
		_set_error("API key cannot be empty.")
		return
	FoleySettings.save_api_key(_editor_settings(), api_key)
	_api_key_edit.clear()
	_refresh_key_status()
	_refresh_account()
	_set_status("API key saved for this editor project.")


func _batch_prompt_lines() -> PackedStringArray:
	var prompts := PackedStringArray()
	for prompt in _batch_prompts:
		var normalized := str(prompt).strip_edges()
		if normalized.is_empty():
			continue
		prompts.append(normalized)
	return prompts


func _consume_pending_batch_prompt() -> void:
	if _batch_entry_edit == null:
		return
	var pending := _batch_entry_edit.text.strip_edges()
	if pending.is_empty():
		return
	_add_batch_prompt(pending)


func _push_toast(message: String) -> void:
	if message.strip_edges().is_empty():
		return
	if _editor_interface == null or not _editor_interface.has_method("get_editor_toaster"):
		return
	var toaster := _editor_interface.get_editor_toaster()
	if toaster == null or not toaster.has_method("push_toast"):
		return
	toaster.call("push_toast", message)


func _show_insufficient_tokens_toast(required_tokens: int, available_tokens: int) -> void:
	if _insufficient_tokens_toast == null:
		return
	if _insufficient_tokens_label != null:
		_insufficient_tokens_label.text = "Insufficient tokens: need %d, available %d." % [required_tokens, available_tokens]
	_insufficient_tokens_toast.visible = true


func _hide_insufficient_tokens_toast() -> void:
	if _insufficient_tokens_toast != null:
		_insufficient_tokens_toast.visible = false


func _refresh_key_status() -> void:
	var project_setting_key := str(ProjectSettings.get_setting(FoleySettings.KEY_API_KEY_LEGACY, "")).strip_edges()
	var has_project_key := not project_setting_key.is_empty()
	var api_key := FoleySettings.get_api_key(_editor_settings())
	var has_key := not api_key.is_empty()
	if not has_key:
		_is_authenticated = false
	_set_auth_ui(_is_authenticated, has_key)
	if _api_key_edit != null:
		if has_project_key:
			_api_key_edit.placeholder_text = "Using Project Settings key"
		elif has_key:
			_api_key_edit.placeholder_text = "API key saved"
		else:
			_api_key_edit.placeholder_text = "API key"
		if has_key:
			_api_key_edit.clear()


func _refresh_account(silent: bool = false) -> void:
	var api_key := FoleySettings.get_api_key(_editor_settings())
	if api_key.is_empty():
		_is_authenticated = false
		_set_auth_ui(false, false)
		_account_state = {}
		_token_label.text = "Tokens --"
		_hide_insufficient_tokens_toast()
		if not silent:
			_set_status("Set foley_ai/api_key in Project Settings or use the save field above.")
		_update_cost_label()
		return

	if not silent:
		_set_status("Loading account...")
	var response: Dictionary = await _api_client.get_me(api_key)
	if bool(response.get("ok", false)):
		_is_authenticated = true
		_set_auth_ui(true, true)
		var payload_variant := response.get("data", {})
		_account_state = {}
		if payload_variant is Dictionary:
			_account_state = _normalize_account_payload(payload_variant)
		_token_label.text = "Tokens %d" % _account_tokens()
		_hide_insufficient_tokens_toast()
		if not silent:
			_set_status("Ready")
	else:
		_is_authenticated = false
		_set_auth_ui(false, true)
		_account_state = {}
		_token_label.text = "Tokens --"
		_hide_insufficient_tokens_toast()
		if not silent:
			_set_error("Failed to load account: %s" % str(response.get("message", "Unknown error.")))
	_update_cost_label()


func _build_form_from_inputs() -> Dictionary:
	var formats := FoleySettings.get_output_formats()
	var selected_index := _format_option.selected
	if selected_index < 0 or selected_index >= formats.size():
		selected_index = 0

	var form := {
		"prompt": _prompt_edit.text.strip_edges(),
		"variations": int(_variations_spin.value),
		"prompt_influence": float(_influence_slider.value),
		"use_custom_duration": _duration_toggle.button_pressed,
		"duration_seconds": float(_duration_slider.value),
		"output_format": formats[selected_index],
		"target_folder": FoleyNaming.normalize_folder(_target_folder_edit.text),
		"create_prompt_subfolder": _create_subfolder_toggle.button_pressed
	}
	form = FoleySettings.clamp_form(form)
	FoleySettings.save_defaults_from_form(form)
	return form


func _generate_internal(form: Dictionary) -> Dictionary:
	var outcome := {
		"ok": false,
		"canceled": false,
		"imported_count": 0,
		"failed_variations": 0
	}
	if _is_busy:
		return outcome

	_hide_insufficient_tokens_toast()
	_refresh_key_status()
	var clamped := FoleySettings.clamp_form(form)
	var prompt := str(clamped.get("prompt", ""))
	if prompt.is_empty():
		_set_error("Sound description is required.")
		return outcome

	var api_key := FoleySettings.get_api_key(_editor_settings())
	if api_key.is_empty():
		_set_error("No API key configured.")
		return outcome

	if not _account_state.is_empty():
		var token_cost := _account_token_cost()
		var estimated_cost := FoleySettings.calculate_cost(int(clamped.get("variations", 1)), token_cost)
		var tokens := _account_tokens()
		if tokens < estimated_cost:
			_set_error("Insufficient tokens. Need %d, have %d." % [estimated_cost, tokens])
			_show_insufficient_tokens_toast(estimated_cost, tokens)
			return outcome

	_is_busy = true
	_set_busy_state(true)
	_api_client.clear_cancel()
	_set_status("Generating...")

	var project_name := str(ProjectSettings.get_setting("application/config/name", "Godot Project"))
	var version_info := Engine.get_version_info()
	var godot_version := str(version_info.get("string", "unknown"))

	var response: Dictionary = await _api_client.generate(clamped, api_key, project_name, godot_version)
	if bool(response.get("ok", false)):
		var payload_variant := response.get("data", {})
		var payload: Dictionary = payload_variant if payload_variant is Dictionary else {}
		var imported_paths: Array[String] = _import_service.import_generated_results(payload, clamped)
		_last_generated_form = clamped.duplicate(true)
		_render_results(payload, imported_paths)
		outcome["ok"] = true
		outcome["imported_count"] = imported_paths.size()
		outcome["failed_variations"] = _last_failed_variations
		FoleySettings.add_prompt_to_history(prompt)
		_refresh_prompt_library_ui()

		if _account_has_tokens():
			_account_state["tokens"] = _coerce_int(payload.get("tokensAfter", _account_tokens()))
			_token_label.text = "Tokens %d" % _account_tokens()
		call_deferred("_refresh_account", true)
		if _last_failed_variations > 0:
			var info := ""
			if _last_rate_limited_failures > 0:
				info = " %d were rate limited." % _last_rate_limited_failures
			_set_error("Imported %d clip(s); %d failed.%s Use retry." % [imported_paths.size(), _last_failed_variations, info])
			if not _is_running_batch and not _is_running_variation_queue:
				_push_toast("Imported %d clip(s); %d failed." % [imported_paths.size(), _last_failed_variations])
		else:
			_set_status("Imported %d clip(s)." % imported_paths.size())
			if not _is_running_batch and not _is_running_variation_queue:
				_push_toast("Imported %d clip(s)." % imported_paths.size())
		_select_imported_assets(imported_paths)
	else:
		var error_code := str(response.get("error_code", ""))
		if error_code == "canceled":
			_set_status("Generation canceled.")
			outcome["canceled"] = true
			if not _is_running_batch and not _is_running_variation_queue:
				_push_toast("Generation canceled.")
		else:
			_set_error(_build_api_error_message(response))
			if not _is_running_batch and not _is_running_variation_queue:
				_push_toast("Generation failed.")

	_set_busy_state(false)
	_is_busy = false
	_update_cost_label()
	_update_retry_button()
	return outcome


func _render_results(response: Dictionary, imported_paths: Array[String]) -> void:
	_set_results_panel_visible(true)
	_result_rows.clear()
	_results_list.clear()

	var results: Array = response.get("results", [])
	var total_count := results.size()
	var success_count := 0
	var failed_count := 0
	var rate_limited_count := 0
	var imported_index := 0

	for item_variant in results:
		if not (item_variant is Dictionary):
			continue
		var item: Dictionary = item_variant
		var is_success := bool(item.get("success", false))
		var variation_number := int(item.get("index", 0)) + 1
		var duration_seconds := _result_duration_seconds(item)
		if is_success:
			success_count += 1
			var path := ""
			if imported_index < imported_paths.size():
				path = imported_paths[imported_index]
				imported_index += 1
			_append_result_row({
				"variation": variation_number,
				"success": true,
				"path": path,
				"duration_seconds": duration_seconds
			})
		else:
			failed_count += 1
			var is_rate_limited := bool(item.get("rateLimited", false)) or str(item.get("errorCode", "")).to_lower().contains("rate_limit")
			if is_rate_limited:
				rate_limited_count += 1
			var prefix := "Rate limited" if is_rate_limited else "Failed"
			var error_text := str(item.get("error", item.get("errorCode", "Unknown error")))
			_append_result_row({
				"variation": variation_number,
				"success": false,
				"status": prefix,
				"error": error_text,
				"duration_seconds": duration_seconds
			})

	if _result_rows.is_empty() and not imported_paths.is_empty():
		total_count = imported_paths.size()
		success_count = imported_paths.size()
		for idx in range(imported_paths.size()):
			_append_result_row({
				"variation": idx + 1,
				"success": true,
				"path": imported_paths[idx],
				"duration_seconds": _result_duration_seconds({})
			})

	_last_failed_variations = maxi(0, failed_count)
	_last_rate_limited_failures = maxi(0, rate_limited_count)
	_update_retry_button()
	_update_results_empty_state()

	var summary := "Imported %d / %d clip(s), %d failed. %s" % [
		success_count,
		maxi(total_count, _result_rows.size()),
		failed_count,
		_current_duration_summary()
	]
	if rate_limited_count > 0:
		summary += " (%d rate limited)" % rate_limited_count
	_session_summary_label.text = summary
	_update_show_in_fs_button_state()

func _result_duration_seconds(item: Dictionary) -> float:
	var duration := -1.0
	if item.has("durationSeconds"):
		duration = float(item.get("durationSeconds", -1.0))
	elif item.has("duration_seconds"):
		duration = float(item.get("duration_seconds", -1.0))
	elif not _last_generated_form.is_empty() and bool(_last_generated_form.get("use_custom_duration", false)):
		duration = float(_last_generated_form.get("duration_seconds", -1.0))
	return duration


func _append_result_row(row: Dictionary) -> void:
	_result_rows.append(row)
	var variation := int(row.get("variation", _result_rows.size()))
	var duration := float(row.get("duration_seconds", -1.0))
	var duration_text := "%.1fs" % duration if duration > 0.0 else "auto"
	var label := ""
	var tooltip := ""

	if bool(row.get("success", false)):
		var path := str(row.get("path", ""))
		var file_name := path.get_file() if not path.is_empty() else "(import failed)"
		label = "V%d   %s   Imported   %s" % [variation, duration_text, file_name]
		tooltip = path
	else:
		var status := str(row.get("status", "Failed"))
		var error_text := str(row.get("error", "Unknown error"))
		var clipped_error := error_text
		if clipped_error.length() > 80:
			clipped_error = clipped_error.substr(0, 80) + "..."
		label = "V%d   %s   %s   %s" % [variation, duration_text, status, clipped_error]
		tooltip = error_text

	_results_list.add_item(label)
	var item_index := _results_list.get_item_count() - 1
	_results_list.set_item_metadata(item_index, row)
	if not tooltip.is_empty():
		_results_list.set_item_tooltip(item_index, tooltip)
	if not bool(row.get("success", false)):
		_results_list.set_item_custom_fg_color(item_index, COLOR_DANGER)


func _update_results_empty_state() -> void:
	var has_rows := _result_rows.size() > 0
	_results_empty_label.visible = not has_rows
	_results_list.visible = has_rows
	_update_show_in_fs_button_state()


func _selected_imported_path() -> String:
	var row := _selected_result_row()
	if not row.is_empty() and bool(row.get("success", false)):
		return str(row.get("path", ""))
	for result_row in _result_rows:
		var path := str(result_row.get("path", ""))
		if bool(result_row.get("success", false)) and not path.is_empty():
			return path
	return ""


func _selected_result_row() -> Dictionary:
	if _results_list == null:
		return {}

	var selected_items := _results_list.get_selected_items()
	if selected_items.size() > 0:
		var selected_metadata := _results_list.get_item_metadata(int(selected_items[0]))
		if selected_metadata is Dictionary:
			return selected_metadata
	if _result_rows.is_empty():
		return {}
	return _result_rows[0]


func _update_show_in_fs_button_state() -> void:
	var selected_row := _selected_result_row()
	var selected_path := str(selected_row.get("path", ""))
	var has_success_path := bool(selected_row.get("success", false)) and not selected_path.is_empty()
	var has_path := not _selected_imported_path().is_empty()

	if _show_in_fs_button != null:
		_show_in_fs_button.visible = has_path
		_show_in_fs_button.disabled = not has_path

	if _play_result_button != null:
		_play_result_button.visible = has_success_path
		_play_result_button.disabled = not has_success_path

	if _copy_path_button != null:
		_copy_path_button.visible = has_success_path
		_copy_path_button.disabled = not has_success_path

	if _retry_selected_button == null:
		return
	var can_retry_selected := not selected_row.is_empty() \
		and not bool(selected_row.get("success", false)) \
		and not _last_generated_form.is_empty() \
		and not _is_busy \
		and not _is_running_batch \
		and not _is_running_variation_queue
	_retry_selected_button.visible = not selected_row.is_empty()
	_retry_selected_button.disabled = not can_retry_selected


func _select_imported_assets(imported_paths: Array[String]) -> void:
	if imported_paths.is_empty():
		return
	if _editor_interface.has_method("select_file"):
		_editor_interface.select_file(imported_paths[0])
	if _editor_interface.get_file_system_dock() != null:
		_editor_interface.get_file_system_dock().navigate_to_path(imported_paths[0])


func _build_api_error_message(api_response: Dictionary) -> String:
	var status_code := int(api_response.get("status_code", 0))
	var message := str(api_response.get("message", "API request failed."))
	if bool(api_response.get("is_rate_limited", false)):
		var retry_after := int(api_response.get("retry_after_seconds", -1))
		if retry_after > 0:
			return "Rate limit reached. %s Retry after about %d second(s)." % [message, retry_after]
		return "Rate limit reached. %s" % message
	if status_code <= 0:
		return message
	return "API error (%d): %s" % [status_code, message]


func _set_busy_state(is_busy: bool) -> void:
	var busy_any := is_busy or _is_running_batch or _is_running_variation_queue
	_generate_button.disabled = busy_any
	_cancel_button.disabled = not is_busy
	if _save_preset_button != null:
		_save_preset_button.disabled = busy_any
	if _remove_preset_button != null:
		_remove_preset_button.disabled = busy_any
	if _api_key_edit != null:
		_api_key_edit.editable = not is_busy
	if _save_api_key_button != null:
		_save_api_key_button.disabled = is_busy
	if _insufficient_tokens_button != null:
		_insufficient_tokens_button.disabled = is_busy
	if _batch_entry_edit != null:
		_batch_entry_edit.editable = not busy_any
	if _batch_add_button != null:
		_batch_add_button.disabled = busy_any
	if _batch_remove_button != null:
		_batch_remove_button.disabled = busy_any or _batch_queue_list == null or _batch_queue_list.get_selected_items().is_empty()
	if _batch_clear_button != null:
		_batch_clear_button.disabled = busy_any or _batch_prompts.is_empty()
	_update_retry_button()


func _set_status(text: String) -> void:
	_status_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	_status_label.text = "" if text == "Ready" else text
	_status_label.visible = not _status_label.text.is_empty()


func _set_error(text: String) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", COLOR_DANGER)
	_status_label.visible = not text.strip_edges().is_empty()


func _update_retry_button() -> void:
	if _retry_button == null:
		return
	if _last_failed_variations > 0:
		_retry_button.text = "Retry Failed (%d)" % _last_failed_variations
		_retry_button.disabled = _is_busy or _is_running_batch or _is_running_variation_queue
	else:
		_retry_button.text = "Retry Failed"
		_retry_button.disabled = true
	_update_show_in_fs_button_state()


func _update_cost_label() -> void:
	if _estimated_cost_label == null or _variations_spin == null:
		return
	var token_cost := _account_token_cost()
	var variation_count := int(_variations_spin.value)
	var estimated_cost := FoleySettings.calculate_cost(variation_count, token_cost)
	_estimated_cost_label.text = "Cost: %d tokens" % estimated_cost
	_estimated_cost_label.tooltip_text = "%s, %s" % [
		_format_variation_label(variation_count),
		_current_duration_summary()
	]
	if _account_has_tokens():
		var available_tokens := _account_tokens()
		if available_tokens < estimated_cost:
			_show_insufficient_tokens_toast(estimated_cost, available_tokens)
		else:
			_hide_insufficient_tokens_toast()
	else:
		_hide_insufficient_tokens_toast()


func _current_duration_summary() -> String:
	if _duration_toggle == null or _duration_slider == null:
		return "auto duration"
	if not _duration_toggle.button_pressed:
		return "auto duration"
	return "%.1fs duration" % _duration_slider.value


func _format_variation_label(variation_count: int) -> String:
	return "%d variation%s" % [variation_count, "" if variation_count == 1 else "s"]


func _find_format_index(output_format: String) -> int:
	var formats := FoleySettings.get_output_formats()
	for index in formats.size():
		if formats[index] == output_format:
			return index
	return 0


func _on_variations_changed(value: float) -> void:
	_variations_label.text = _format_variation_label(int(value))
	_update_cost_label()


func _on_influence_changed(value: float) -> void:
	_influence_label.text = "Prompt influence: %.1f (Lower = precise, higher = creative)" % value


func _on_duration_toggled(enabled: bool) -> void:
	if _duration_slider != null:
		_duration_slider.visible = enabled
	if _duration_label != null:
		_duration_label.visible = enabled
		_duration_label.text = "Duration: %.1fs" % _duration_slider.value
	_update_cost_label()


func _on_duration_changed(value: float) -> void:
	if _duration_label != null:
		_duration_label.text = "Duration: %.1fs" % value
	_update_cost_label()


func _on_generate_pressed() -> void:
	if _is_running_batch or _is_running_variation_queue:
		_set_error("Wait for the current generation task to finish.")
		return
	if _batch_toggle != null and _batch_toggle.button_pressed:
		call_deferred("_run_batch_generation")
		return
	_generate_internal(_build_form_from_inputs())


func _run_batch_generation() -> void:
	if _is_busy or _is_running_batch or _is_running_variation_queue:
		_set_error("Wait for the current generation task to finish.")
		return

	_consume_pending_batch_prompt()
	var prompts := _batch_prompt_lines()
	if prompts.is_empty():
		_set_error("Batch mode is enabled but no prompts were provided.")
		return

	var base_form := _build_form_from_inputs()
	_is_running_batch = true
	var total := prompts.size()
	var imported_total := 0
	var failed_total := 0
	for index in range(total):
		var form := base_form.duplicate(true)
		form["prompt"] = prompts[index]
		apply_form(form)
		_set_status("Batch %d/%d..." % [index + 1, total])
		var result: Dictionary = await _generate_internal(form)
		imported_total += int(result.get("imported_count", 0))
		failed_total += int(result.get("failed_variations", 0))
		if bool(result.get("canceled", false)):
			_set_status("Batch generation canceled at %d/%d." % [index + 1, total])
			_push_toast("Batch generation canceled.")
			_is_running_batch = false
			apply_form(base_form)
			_set_busy_state(false)
			return
		await get_tree().process_frame

	_is_running_batch = false
	apply_form(base_form)
	_set_busy_state(false)
	_set_status("Batch finished: imported %d clip(s), failed %d variation(s)." % [imported_total, failed_total])
	_push_toast("Batch generation finished.")


func _on_retry_pressed() -> void:
	if _is_running_batch or _is_running_variation_queue:
		_set_error("Wait for the current generation task to finish.")
		return
	if _last_generated_form.is_empty() or _last_failed_variations <= 0:
		_set_error("No failed variations to retry.")
		return
	var retry_form := _last_generated_form.duplicate(true)
	retry_form["variations"] = clampi(_last_failed_variations, 1, 5)
	_generate_internal(retry_form)


func _on_cancel_pressed() -> void:
	_api_client.cancel_active()


func _on_browse_folder_pressed() -> void:
	var folder := FoleyNaming.normalize_folder(_target_folder_edit.text)
	_folder_dialog.current_dir = folder
	_folder_dialog.popup_centered_ratio(0.65)


func _on_folder_selected(path: String) -> void:
	_target_folder_edit.text = FoleyNaming.normalize_folder(path)


func _on_result_selected(_index: int) -> void:
	_update_show_in_fs_button_state()


func _on_result_activated(_index: int) -> void:
	_on_show_in_fs_pressed()


func _on_show_in_fs_pressed() -> void:
	var path := _selected_imported_path()
	if path.is_empty():
		_set_error("No imported clip available yet.")
		return
	if _editor_interface.has_method("select_file"):
		_editor_interface.select_file(path)
	if _editor_interface.get_file_system_dock() != null:
		_editor_interface.get_file_system_dock().navigate_to_path(path)


func _on_preview_result_pressed() -> void:
	var path := _selected_imported_path()
	if path.is_empty():
		_set_error("No imported clip available for preview.")
		return
	if _audio_preview_player == null:
		_set_error("Preview player unavailable.")
		return
	var stream := ResourceLoader.load(path)
	if not (stream is AudioStream):
		_set_error("Selected file is not a previewable audio stream.")
		return
	_audio_preview_player.stream = stream
	_audio_preview_player.play()
	_set_status("Previewing %s" % path.get_file())


func _on_copy_path_pressed() -> void:
	var path := _selected_imported_path()
	if path.is_empty():
		_set_error("No imported clip available to copy.")
		return
	DisplayServer.clipboard_set(path)
	_set_status("Copied path to clipboard.")


func _on_retry_selected_pressed() -> void:
	if _last_generated_form.is_empty():
		_set_error("No prior generation form available for retry.")
		return
	var selected_row := _selected_result_row()
	if selected_row.is_empty() or bool(selected_row.get("success", false)):
		_set_error("Select a failed row to retry.")
		return
	var retry_form := _last_generated_form.duplicate(true)
	retry_form["variations"] = 1
	_set_status("Retrying selected failed variation...")
	_generate_internal(retry_form)


func _on_reveal_first_pressed() -> void:
	_on_show_in_fs_pressed()


func _on_resized() -> void:
	_update_layout_columns()


func _set_results_panel_visible(visible: bool) -> void:
	if _right_column == null:
		return
	_right_column.visible = visible
	_update_layout_columns()


func _update_layout_columns() -> void:
	if _layout_grid == null:
		return
	var available_width := _scroll.size.x if _scroll != null else size.x
	var can_show_two_columns := _right_column != null and _right_column.visible and available_width >= 980
	_layout_grid.columns = 2 if can_show_two_columns else 1

	if _settings_grid != null:
		var left_width := float(available_width)
		if _layout_grid.columns == 2:
			left_width = (float(available_width) - 10.0) / 2.0
		_settings_grid.columns = 2 if left_width >= 430.0 else 1


func _open_checkout_url() -> void:
	var url := _account_checkout_url()
	OS.shell_open(url)


func _normalize_account_payload(payload: Dictionary) -> Dictionary:
	if _account_looks_valid(payload):
		return payload

	for key in ["data", "account", "user", "result"]:
		var nested_variant := payload.get(key, null)
		if nested_variant is Dictionary:
			var nested_payload: Dictionary = nested_variant
			var normalized := _normalize_account_payload(nested_payload)
			if _account_looks_valid(normalized):
				if payload.has("checkoutUrl") and not normalized.has("checkoutUrl"):
					normalized["checkoutUrl"] = payload["checkoutUrl"]
				if payload.has("tokenCostPerGeneration") and not normalized.has("tokenCostPerGeneration"):
					normalized["tokenCostPerGeneration"] = payload["tokenCostPerGeneration"]
				return normalized
	return payload


func _account_looks_valid(payload: Dictionary) -> bool:
	return payload.has("tokens") \
		or payload.has("tokenBalance") \
		or payload.has("tokenCostPerGeneration") \
		or payload.has("checkoutUrl")


func _account_tokens() -> int:
	return _coerce_int(_account_state.get("tokens", _account_state.get("tokenBalance", 0)))


func _account_has_tokens() -> bool:
	return _account_state.has("tokens") or _account_state.has("tokenBalance")


func _account_token_cost() -> int:
	return maxi(1, _coerce_int(_account_state.get("tokenCostPerGeneration", _account_state.get("token_cost_per_generation", 100))))


func _account_checkout_url() -> String:
	var fallback := "https://www.foley-ai.com/?source=godot-plugin"
	var url := str(_account_state.get("checkoutUrl", _account_state.get("checkout_url", fallback))).strip_edges()
	return fallback if url.is_empty() else url


func _coerce_int(value: Variant) -> int:
	if value is int:
		return value
	if value is float:
		return int(round(value))
	var as_text := str(value).strip_edges()
	if as_text.is_valid_int():
		return int(as_text)
	return 0


func _set_auth_ui(is_authenticated: bool, has_key: bool) -> void:
	if _auth_status_dot == null or _auth_status_label == null:
		return
	var project_setting_key := str(ProjectSettings.get_setting(FoleySettings.KEY_API_KEY_LEGACY, "")).strip_edges()
	var has_project_key := not project_setting_key.is_empty()
	var authenticated := has_key and is_authenticated
	var success_color := COLOR_SUCCESS
	var error_color := COLOR_DANGER
	_auth_status_dot.color = success_color if authenticated else error_color
	_auth_status_label.text = "Authenticated" if authenticated else "Not authenticated"
	_auth_status_label.add_theme_color_override("font_color", success_color if authenticated else error_color)
	if _auth_helper_label != null:
		if authenticated:
			_auth_helper_label.visible = false
		elif not has_key:
			_auth_helper_label.visible = true
			_auth_helper_label.text = "No API key found. Set foley_ai/api_key in Project Settings or save one here."
		else:
			_auth_helper_label.visible = true
			_auth_helper_label.text = "Authentication failed. Check foley_ai/api_key in Project Settings." if has_project_key else "Authentication failed. Set foley_ai/api_key in Project Settings to override the saved key."
	if _api_key_row != null:
		_api_key_row.visible = not has_key
	if _auth_refresh_button != null:
		_auth_refresh_button.visible = has_key
	if _buy_tokens_button != null:
		_buy_tokens_button.visible = authenticated
	if _save_api_key_button != null:
		_save_api_key_button.visible = not has_key
		_save_api_key_button.text = "Save Key"
