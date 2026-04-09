@tool
extends AcceptDialog

signal generate_requested(form: Dictionary)

const FoleySettings := preload("res://addons/foley_ai/core/foley_settings.gd")
const COLOR_BG := Color(0.9686, 0.9490, 0.8118, 1.0)
const COLOR_PANEL := Color(0.9882, 0.9686, 0.9020, 1.0)
const COLOR_INPUT_BG := Color(0.9922, 0.9804, 0.9294, 1.0)
const COLOR_BORDER := Color(0.3647, 0.3412, 0.4196, 1.0)
const COLOR_TEXT := Color(0.3647, 0.3412, 0.4196, 1.0)
const COLOR_MUTED := Color(0.4314, 0.4000, 0.5098, 1.0)
const COLOR_PRIMARY_BLUE := Color(0.3059, 0.4745, 0.6510, 1.0)
const COLOR_PRIMARY_BLUE_HOVER := Color(0.2471, 0.4039, 0.5608, 1.0)
const COLOR_ACCENT := Color(0.6078, 0.7569, 0.7373, 1.0)
const COLOR_ACCENT_HOVER := Color(0.3647, 0.3412, 0.4196, 1.0)
const COLOR_SECONDARY_HOVER := Color(0.9059, 0.9529, 0.9490, 1.0)
const COLOR_SHADOW := Color(0.2588, 0.2353, 0.3176, 0.75)
const COLOR_HARD_SHADOW := Color(0.3647, 0.3412, 0.4196, 0.34)
const COLOR_SLIDER_SHADOW := Color(0.1765, 0.2510, 0.3569, 0.60)
const QUICK_DIALOG_MIN_WIDTH := 620
const QUICK_DIALOG_MIN_HEIGHT := 380
const QUICK_DIALOG_DEFAULT_HEIGHT := 480
const QUICK_DIALOG_COMPACT_MAX_HEIGHT := 540
const QUICK_DIALOG_ADVANCED_DEFAULT_HEIGHT := 720
const QUICK_DIALOG_ADVANCED_MAX_HEIGHT := 860
const QUICK_DIALOG_COMPACT_CAP_RATIO := 0.72
const QUICK_DIALOG_ADVANCED_CAP_RATIO := 0.92

var _target_folder := "res://audio/foley_ai"

var _target_folder_label: Label
var _prompt_edit: LineEdit
var _variations_spin: SpinBox
var _variations_label: Label
var _show_more_button: Button
var _advanced_container: VBoxContainer
var _influence_slider: HSlider
var _influence_label: Label
var _duration_toggle: CheckBox
var _duration_slider: HSlider
var _duration_label: Label
var _format_option: OptionButton
var _surface: PanelContainer
var _form_scroll: ScrollContainer


func _ready() -> void:
	title = "Foley AI Quick Generate"
	dialog_hide_on_ok = true
	dialog_close_on_escape = true
	wrap_controls = false
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	exclusive = false
	unresizable = true
	min_size = Vector2i(QUICK_DIALOG_MIN_WIDTH, QUICK_DIALOG_MIN_HEIGHT)
	size = Vector2i(QUICK_DIALOG_MIN_WIDTH, QUICK_DIALOG_DEFAULT_HEIGHT)
	add_theme_stylebox_override("panel", _build_panel_style(COLOR_BG, COLOR_BORDER, 1, 10))
	_build_ui()
	_apply_defaults()

	confirmed.connect(_on_confirmed)
	canceled.connect(_on_close_requested)
	close_requested.connect(_on_close_requested)
	var ok_button := get_ok_button()
	ok_button.text = "Generate & Import"
	ok_button.custom_minimum_size = Vector2(176, 40)
	_style_button(ok_button, true)
	var close_button := add_cancel_button("Close")
	close_button.custom_minimum_size = Vector2(132, 40)
	_style_button(close_button, false)
	var button_row := ok_button.get_parent()
	if button_row is HBoxContainer:
		var button_box := button_row as HBoxContainer
		button_box.alignment = BoxContainer.ALIGNMENT_CENTER
		button_box.add_theme_constant_override("separation", 10)


func set_form(form: Dictionary) -> void:
	var clamped := FoleySettings.clamp_form(form)
	_target_folder = _sanitize_target_folder(str(clamped.get("target_folder", _target_folder)))
	_target_folder_label.text = "Output Folder: %s" % _target_folder
	_prompt_edit.text = str(clamped.get("prompt", ""))
	_variations_spin.value = int(clamped.get("variations", 1))
	_variations_label.text = _format_variation_label(int(_variations_spin.value))
	_influence_slider.value = float(clamped.get("prompt_influence", 0.3))
	_influence_label.text = "Prompt influence: %.1f (0 creative - 1 precise)" % _influence_slider.value
	_duration_toggle.button_pressed = bool(clamped.get("use_custom_duration", false))
	_duration_slider.value = float(clamped.get("duration_seconds", 3.0))
	_duration_label.text = "Duration: %.1fs" % _duration_slider.value
	_duration_slider.visible = _duration_toggle.button_pressed
	_duration_label.visible = _duration_toggle.button_pressed

	var output_format := str(clamped.get("output_format", "pcm_44100"))
	var selected_index := _find_format_index(output_format)
	if selected_index >= 0:
		_format_option.select(selected_index)

	_set_advanced_visible(false)
	_reset_scroll_position()


func get_form() -> Dictionary:
	return {
		"prompt": _prompt_edit.text.strip_edges(),
		"variations": int(_variations_spin.value),
		"prompt_influence": float(_influence_slider.value),
		"use_custom_duration": _duration_toggle.button_pressed,
		"duration_seconds": float(_duration_slider.value),
		"output_format": _selected_output_format(),
		"target_folder": _target_folder,
		"create_prompt_subfolder": false
	}


func focus_prompt() -> void:
	if _prompt_edit == null or not is_instance_valid(_prompt_edit):
		return
	_prompt_edit.grab_focus()


func _build_ui() -> void:
	_surface = PanelContainer.new()
	_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_surface.add_theme_stylebox_override("panel", _build_panel_style(COLOR_BG, COLOR_BORDER, 1, 10))
	var content_container := _get_dialog_content_container()
	if content_container == null:
		add_child(_surface)
	else:
		content_container.add_child(_surface)
		content_container.move_child(_surface, 0)

	_form_scroll = ScrollContainer.new()
	_form_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_form_scroll.follow_focus = true
	_form_scroll.clip_contents = true
	_disable_horizontal_scroll(_form_scroll)
	_style_scroll_container(_form_scroll)
	_surface.add_child(_form_scroll)
	call_deferred("_refresh_scroll_styles")

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form_scroll.add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 8)
	root.add_child(heading_row)

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
		heading_row.add_child(logo)

	var heading := Label.new()
	heading.text = "Foley AI Quick Generate"
	heading.add_theme_font_size_override("font_size", 15)
	heading.add_theme_color_override("font_color", COLOR_TEXT)
	heading_row.add_child(heading)

	_target_folder_label = Label.new()
	_target_folder_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_target_folder_label.add_theme_color_override("font_color", COLOR_MUTED)
	root.add_child(_target_folder_label)

	_prompt_edit = LineEdit.new()
	_prompt_edit.placeholder_text = "Sound description"
	_style_input(_prompt_edit)
	root.add_child(_prompt_edit)

	var variations_row := HBoxContainer.new()
	variations_row.add_theme_constant_override("separation", 8)
	root.add_child(variations_row)

	var variations_title := Label.new()
	variations_title.text = "Variations"
	variations_title.add_theme_color_override("font_color", COLOR_MUTED)
	variations_row.add_child(variations_title)

	_variations_spin = SpinBox.new()
	_configure_variations_spinbox(_variations_spin)
	_variations_spin.value_changed.connect(_on_variations_changed)
	variations_row.add_child(_variations_spin)

	_variations_label = Label.new()
	_variations_label.add_theme_color_override("font_color", COLOR_MUTED)
	root.add_child(_variations_label)

	_show_more_button = Button.new()
	_show_more_button.text = "More Options"
	_show_more_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(_show_more_button, false)
	_show_more_button.pressed.connect(_toggle_more_options)
	root.add_child(_show_more_button)

	_advanced_container = VBoxContainer.new()
	_advanced_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_advanced_container.add_theme_constant_override("separation", 6)
	root.add_child(_advanced_container)

	var influence_title := Label.new()
	influence_title.text = "Prompt Influence"
	influence_title.add_theme_color_override("font_color", COLOR_MUTED)
	_advanced_container.add_child(influence_title)

	_influence_slider = HSlider.new()
	_influence_slider.min_value = 0.0
	_influence_slider.max_value = 1.0
	_influence_slider.step = 0.1
	_style_slider(_influence_slider)
	_disable_wheel_change(_influence_slider)
	_release_focus_on_mouse_exit(_influence_slider)
	_influence_slider.value_changed.connect(_on_influence_changed)
	_advanced_container.add_child(_influence_slider)

	_influence_label = Label.new()
	_influence_label.add_theme_color_override("font_color", COLOR_MUTED)
	_advanced_container.add_child(_influence_label)

	_duration_toggle = CheckBox.new()
	_duration_toggle.text = "Custom Duration"
	_style_checkbox(_duration_toggle)
	_duration_toggle.toggled.connect(_on_duration_toggled)
	_advanced_container.add_child(_duration_toggle)

	_duration_slider = HSlider.new()
	_duration_slider.min_value = 0.5
	_duration_slider.max_value = 5.0
	_duration_slider.step = 0.1
	_style_slider(_duration_slider)
	_disable_wheel_change(_duration_slider)
	_release_focus_on_mouse_exit(_duration_slider)
	_duration_slider.value_changed.connect(_on_duration_changed)
	_advanced_container.add_child(_duration_slider)

	_duration_label = Label.new()
	_duration_label.add_theme_color_override("font_color", COLOR_MUTED)
	_advanced_container.add_child(_duration_label)

	var format_title := Label.new()
	format_title.text = "Output Format"
	format_title.add_theme_color_override("font_color", COLOR_MUTED)
	_advanced_container.add_child(format_title)

	_format_option = OptionButton.new()
	_format_option.fit_to_longest_item = false
	_format_option.clip_text = true
	_format_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_option_button(_format_option)
	var formats := FoleySettings.get_output_formats()
	for format in formats:
		_format_option.add_item(FoleySettings.format_output_format_label(format))
	var format_popup := _format_option.get_popup()
	if format_popup != null:
		format_popup.add_theme_color_override("font_color", COLOR_TEXT)
		format_popup.add_theme_color_override("font_hover_color", COLOR_TEXT)
		format_popup.add_theme_color_override("font_pressed_color", COLOR_PRIMARY_BLUE_HOVER)
		format_popup.add_theme_color_override("font_focus_color", COLOR_TEXT)
		format_popup.add_theme_color_override("font_accelerator_color", COLOR_MUTED)
		format_popup.add_theme_color_override("font_disabled_color", COLOR_MUTED)
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
	_advanced_container.add_child(_format_option)


func _apply_defaults() -> void:
	set_form(FoleySettings.get_default_form())


func _on_confirmed() -> void:
	emit_signal("generate_requested", get_form())


func _on_close_requested() -> void:
	hide()


func _on_variations_changed(value: float) -> void:
	_variations_label.text = _format_variation_label(int(value))


func _on_influence_changed(value: float) -> void:
	_influence_label.text = "Prompt influence: %.1f (0 creative - 1 precise)" % value


func _on_duration_toggled(enabled: bool) -> void:
	_duration_slider.visible = enabled
	_duration_label.visible = enabled


func _on_duration_changed(value: float) -> void:
	_duration_label.text = "Duration: %.1fs" % value


func _toggle_more_options() -> void:
	_set_advanced_visible(not _advanced_container.visible)


func _set_advanced_visible(visible: bool) -> void:
	_advanced_container.visible = visible
	_show_more_button.text = "Fewer Options" if visible else "More Options"
	if not self.visible:
		return
	call_deferred("_stabilize_visible_size")


func _selected_output_format() -> String:
	var formats := FoleySettings.get_output_formats()
	var selected_index := _format_option.selected
	if selected_index < 0 or selected_index >= formats.size():
		return "pcm_44100"
	return formats[selected_index]


func _find_format_index(output_format: String) -> int:
	var formats := FoleySettings.get_output_formats()
	for index in formats.size():
		if formats[index] == output_format:
			return index
	return 0


func _format_variation_label(variation_count: int) -> String:
	return "%d variation%s" % [variation_count, "" if variation_count == 1 else "s"]


func _build_panel_style(background: Color, border: Color, border_width: int = 1, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(8)
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
	style.set_content_margin_all(8)
	_apply_hard_shadow(style, shadow_color, shadow_size, shadow_offset)
	return style


func _style_button(button: Button, primary: bool) -> void:
	var normal := COLOR_PANEL
	var hover := COLOR_SECONDARY_HOVER
	var border := COLOR_BORDER
	var font := COLOR_TEXT
	var shadow_base := 2
	var shadow_blur := 1
	if primary:
		normal = COLOR_PRIMARY_BLUE
		hover = COLOR_PRIMARY_BLUE_HOVER
		border = COLOR_PRIMARY_BLUE_HOVER
		font = COLOR_PANEL
		shadow_base = 3
	var hover_shadow := maxi(0, shadow_base - 1)
	var pressed_shadow := maxi(0, shadow_base - 2)
	var disabled_shadow := maxi(0, shadow_base - 2)
	button.add_theme_stylebox_override("normal", _build_button_style(normal, border, shadow_blur, Vector2(shadow_base, shadow_base)))
	button.add_theme_stylebox_override("hover", _build_button_style(hover, border, shadow_blur, Vector2(hover_shadow, hover_shadow)))
	button.add_theme_stylebox_override("pressed", _build_button_style(hover.darkened(0.08), border, shadow_blur, Vector2(pressed_shadow, pressed_shadow)))
	button.add_theme_stylebox_override("disabled", _build_button_style(normal.lerp(COLOR_PANEL, 0.5), border.lerp(COLOR_BORDER, 0.35), shadow_blur, Vector2(disabled_shadow, disabled_shadow)))
	button.add_theme_color_override("font_color", font)
	button.add_theme_color_override("font_hover_color", font)
	button.add_theme_color_override("font_hover_pressed_color", font)
	button.add_theme_color_override("font_pressed_color", font)
	button.add_theme_color_override("font_focus_color", font)
	button.add_theme_color_override("font_disabled_color", Color(font.r, font.g, font.b, 0.65))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _style_input(control: Control) -> void:
	var normal := _build_panel_style(COLOR_INPUT_BG, COLOR_ACCENT, 1, 6)
	var focus := _build_panel_style(COLOR_INPUT_BG, COLOR_PRIMARY_BLUE, 1, 6)
	_apply_hard_shadow(normal, COLOR_SHADOW, 2, Vector2(2, 2))
	_apply_hard_shadow(focus, COLOR_PRIMARY_BLUE_HOVER, 2, Vector2(2, 2))
	control.add_theme_stylebox_override("normal", normal)
	control.add_theme_stylebox_override("focus", focus)
	control.add_theme_stylebox_override("read_only", normal)
	control.add_theme_color_override("font_color", COLOR_TEXT)
	control.add_theme_color_override("font_placeholder_color", COLOR_MUTED)
	control.add_theme_color_override("caret_color", COLOR_PRIMARY_BLUE)
	control.add_theme_color_override("selection_color", COLOR_PRIMARY_BLUE.lerp(COLOR_PANEL, 0.52))


func _style_option_button(option: OptionButton) -> void:
	var normal := _build_button_style(COLOR_INPUT_BG, COLOR_ACCENT)
	var hover := _build_button_style(COLOR_SECONDARY_HOVER, COLOR_BORDER)
	option.add_theme_stylebox_override("normal", normal)
	option.add_theme_stylebox_override("hover", hover)
	option.add_theme_stylebox_override("pressed", hover)
	option.add_theme_stylebox_override("disabled", normal)
	var font := COLOR_TEXT
	option.add_theme_color_override("font_color", font)
	option.add_theme_color_override("font_hover_color", font)
	option.add_theme_color_override("font_hover_pressed_color", font)
	option.add_theme_color_override("font_pressed_color", font)
	option.add_theme_color_override("font_focus_color", COLOR_BORDER)
	option.add_theme_color_override("font_disabled_color", COLOR_MUTED)


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
	_style_scroll_container(_form_scroll)


func _style_scroll_bar(scroll_bar: ScrollBar, vertical: bool) -> void:
	if scroll_bar == null:
		return
	scroll_bar.custom_minimum_size = Vector2(14, 0) if vertical else Vector2(0, 14)
	var track := StyleBoxFlat.new()
	track.bg_color = COLOR_ACCENT.lerp(COLOR_PANEL, 0.15)
	track.border_color = COLOR_ACCENT.lerp(COLOR_BORDER, 0.22)
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
	style.bg_color = COLOR_SECONDARY_HOVER
	style.border_color = COLOR_SECONDARY_HOVER
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
	toggle.add_theme_color_override("font_focus_color", COLOR_BORDER)
	toggle.add_theme_color_override("font_disabled_color", COLOR_MUTED)
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
		COLOR_MUTED,
		COLOR_ACCENT.lerp(COLOR_PANEL, 0.45),
		COLOR_PANEL,
		Color(COLOR_SLIDER_SHADOW.r, COLOR_SLIDER_SHADOW.g, COLOR_SLIDER_SHADOW.b, 0.35),
		Vector2i(1, 1)
	)
	slider.add_theme_icon_override("grabber", grabber)
	slider.add_theme_icon_override("grabber_highlight", grabber_highlight)
	slider.add_theme_icon_override("grabber_disabled", grabber_disabled)


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
	var border := COLOR_BORDER
	var fill := COLOR_INPUT_BG
	var mark := COLOR_PRIMARY_BLUE_HOVER
	if disabled:
		border = COLOR_MUTED
		fill = COLOR_INPUT_BG.lerp(COLOR_PANEL, 0.3)
		mark = COLOR_MUTED

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


func _sanitize_target_folder(path: String) -> String:
	var normalized := path.strip_edges()
	if normalized.is_empty() or normalized == "res://" or not normalized.begins_with("res://"):
		return "res://audio/foley_ai"
	return normalized


func popup_quick() -> void:
	_ensure_surface_in_content_container()
	size = _normalized_dialog_size(Vector2i(QUICK_DIALOG_MIN_WIDTH, QUICK_DIALOG_DEFAULT_HEIGHT))
	popup_centered_clamped(Vector2i(size), _current_cap_ratio())
	_reset_scroll_position()
	_focus_popup()
	call_deferred("_stabilize_visible_size")


func _reflow_dialog() -> Vector2i:
	child_controls_changed()
	reset_size()
	return _normalized_dialog_size(Vector2i(size))


func _stabilize_visible_size() -> void:
	if not visible:
		return
	var corrected_size := _reflow_dialog()
	if corrected_size != size:
		popup_centered_clamped(corrected_size, _current_cap_ratio())
	_focus_popup()


func _normalized_dialog_size(candidate: Vector2i) -> Vector2i:
	var width := maxi(candidate.x, QUICK_DIALOG_MIN_WIDTH)
	var advanced_visible := _advanced_container != null and _advanced_container.visible
	var preferred_height := QUICK_DIALOG_ADVANCED_DEFAULT_HEIGHT if advanced_visible else QUICK_DIALOG_DEFAULT_HEIGHT
	var max_height := QUICK_DIALOG_ADVANCED_MAX_HEIGHT if advanced_visible else QUICK_DIALOG_COMPACT_MAX_HEIGHT
	var height := clampi(maxi(candidate.y, preferred_height), QUICK_DIALOG_MIN_HEIGHT, max_height)
	return Vector2i(width, height)


func _current_cap_ratio() -> float:
	var advanced_visible := _advanced_container != null and _advanced_container.visible
	return QUICK_DIALOG_ADVANCED_CAP_RATIO if advanced_visible else QUICK_DIALOG_COMPACT_CAP_RATIO


func _focus_popup() -> void:
	if has_method("move_to_foreground"):
		move_to_foreground()
	call_deferred("focus_prompt")


func _get_dialog_content_container() -> Container:
	var ok_button := get_ok_button()
	if ok_button == null:
		return null
	var button_row := ok_button.get_parent()
	if button_row == null:
		return null
	var container := button_row.get_parent()
	if container is Container:
		return container as Container
	return null


func _ensure_surface_in_content_container() -> void:
	if _surface == null:
		return
	var content_container := _get_dialog_content_container()
	if content_container == null:
		return
	if _surface.get_parent() == content_container:
		return
	if _surface.get_parent() != null:
		_surface.get_parent().remove_child(_surface)
	content_container.add_child(_surface)
	content_container.move_child(_surface, 0)


func _reset_scroll_position() -> void:
	if _form_scroll == null or not is_instance_valid(_form_scroll):
		return
	_form_scroll.scroll_vertical = 0
	_form_scroll.scroll_horizontal = 0


func _disable_horizontal_scroll(scroll: ScrollContainer) -> void:
	for property_info in scroll.get_property_list():
		if str(property_info.get("name", "")) == "horizontal_scroll_mode":
			scroll.set("horizontal_scroll_mode", ScrollContainer.SCROLL_MODE_DISABLED)
			break


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
