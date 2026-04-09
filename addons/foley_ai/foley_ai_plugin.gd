@tool
extends EditorPlugin

const FoleySettings := preload("res://addons/foley_ai/core/foley_settings.gd")
const FoleyNaming := preload("res://addons/foley_ai/core/foley_naming.gd")
const FoleyMetadata := preload("res://addons/foley_ai/core/foley_metadata.gd")
const FoleyDock := preload("res://addons/foley_ai/ui/foley_dock.gd")
const FoleyQuickGenerateDialog := preload("res://addons/foley_ai/ui/foley_quick_generate_dialog.gd")
const FileSystemContextMenu := preload("res://addons/foley_ai/context/filesystem_context_menu.gd")

const KEY_DOCK_LOCATION := "foley_ai/ui/dock_location"
const DOCK_LOCATION_BOTTOM := "bottom"
const DOCK_LOCATION_RIGHT := "right"
const TOOLS_SUBMENU_NAME := "Foley AI"
const TOOLS_ID_OPEN_GENERATOR := 1
const TOOLS_ID_QUICK_GENERATE := 2
const TOOLS_ID_MOVE_BOTTOM := 3
const TOOLS_ID_MOVE_RIGHT := 4
const TOOL_MENU_OPEN_GENERATOR := "Foley AI/Open Generator"
const TOOL_MENU_QUICK_GENERATE := "Foley AI/Quick Generate"
const TOOL_MENU_MOVE_BOTTOM := "Foley AI/Move Generator to Bottom Panel"
const TOOL_MENU_MOVE_RIGHT := "Foley AI/Move Generator to Right Dock"
const COMMAND_OPEN_GENERATOR := "foley_ai/open_generator"
const COMMAND_QUICK_GENERATE := "foley_ai/quick_generate"
const SHORTCUT_OPEN_GENERATOR := "foley_ai/open_generator"
const SHORTCUT_QUICK_GENERATE := "foley_ai/quick_generate"

var _dock
var _editor_dock: Control
var _bottom_panel_button: Button
var _quick_dialog
var _filesystem_context_menu: EditorContextMenuPlugin
var _dock_location := DOCK_LOCATION_RIGHT
var _command_palette
var _open_generator_shortcut: Shortcut
var _quick_generate_shortcut: Shortcut
var _tools_submenu: PopupMenu
var _uses_tools_submenu := false


func _enter_tree() -> void:
	var editor_settings := get_editor_interface().get_editor_settings() if get_editor_interface() != null else null
	FoleySettings.ensure_defaults(editor_settings)
	_ensure_plugin_settings()
	_dock_location = _load_dock_location()
	var default_folder := str(FoleySettings.get_default_form().get("target_folder", "res://audio/foley_ai"))
	FoleyMetadata.migrate_legacy_sidecars(default_folder)
	_register_shortcuts(editor_settings)

	_dock = FoleyDock.new(get_editor_interface())
	_dock.name = "Foley AI"
	_attach_dock(_dock_location)

	_quick_dialog = FoleyQuickGenerateDialog.new()
	_quick_dialog.generate_requested.connect(_on_quick_generate_requested)
	get_editor_interface().get_base_control().add_child(_quick_dialog)

	_filesystem_context_menu = FileSystemContextMenu.new(self)
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, _filesystem_context_menu)

	_setup_tools_submenu()
	_register_command_palette()


func _exit_tree() -> void:
	_teardown_tools_submenu()
	_unregister_command_palette()

	if _filesystem_context_menu != null:
		remove_context_menu_plugin(_filesystem_context_menu)
		_filesystem_context_menu = null

	if _quick_dialog != null:
		_quick_dialog.queue_free()
		_quick_dialog = null

	if _dock != null and is_instance_valid(_dock):
		_detach_dock()
		if _editor_dock != null and is_instance_valid(_editor_dock) and _dock.get_parent() == _editor_dock:
			_editor_dock.remove_child(_dock)
		_dock.queue_free()
	_bottom_panel_button = null
	if _editor_dock != null and is_instance_valid(_editor_dock):
		_editor_dock.queue_free()
	_editor_dock = null
	_dock = null


func _on_open_generator_pressed() -> void:
	_show_generator_panel()


func _on_quick_generate_menu_pressed() -> void:
	open_quick_generate(PackedStringArray())


func _on_move_to_bottom_panel_pressed() -> void:
	_set_dock_location(DOCK_LOCATION_BOTTOM)
	_show_generator_panel()


func _on_move_to_right_dock_pressed() -> void:
	_set_dock_location(DOCK_LOCATION_RIGHT)
	_show_generator_panel()


func open_quick_generate(paths: PackedStringArray) -> void:
	if _quick_dialog == null:
		return
	if _quick_dialog.visible:
		_quick_dialog.popup_quick()
		return

	var form := FoleySettings.get_default_form()
	form["target_folder"] = _resolve_target_folder(paths)
	form["create_prompt_subfolder"] = false
	_quick_dialog.set_form(form)
	_quick_dialog.popup_quick()


func open_generate_variations(paths: PackedStringArray) -> void:
	if _quick_dialog == null:
		return

	var generated_paths := _collect_generated_audio_paths(paths)
	if generated_paths.is_empty():
		open_quick_generate(paths)
		return
	if generated_paths.size() > 1:
		_show_generator_panel()
		if _dock != null and _dock.has_method("generate_variations_for_paths"):
			_dock.call("generate_variations_for_paths", generated_paths)
		return

	var selected_audio_path := str(generated_paths[0])

	var metadata := FoleyMetadata.read_metadata(selected_audio_path)
	var folder := selected_audio_path.get_base_dir()
	var form := FoleySettings.get_default_form()
	form["prompt"] = str(metadata.get("prompt", ""))
	form["variations"] = clampi(int(metadata.get("requestedVariations", form["variations"])), 1, 5)
	form["prompt_influence"] = clampf(float(metadata.get("promptInfluence", form["prompt_influence"])), 0.0, 1.0)
	form["use_custom_duration"] = bool(metadata.get("useCustomDuration", form["use_custom_duration"]))
	form["duration_seconds"] = clampf(float(metadata.get("durationSeconds", form["duration_seconds"])), 0.5, 5.0)
	form["output_format"] = str(metadata.get("outputFormat", form["output_format"]))
	form["target_folder"] = FoleyNaming.normalize_folder(folder)
	form["create_prompt_subfolder"] = false

	_quick_dialog.set_form(form)
	_quick_dialog.popup_quick()


func _on_quick_generate_requested(form: Dictionary) -> void:
	if _dock == null:
		return
	_show_generator_panel()
	_run_on_dock(form, true)


func _resolve_target_folder(paths: PackedStringArray) -> String:
	var default_folder := str(FoleySettings.get_default_form().get("target_folder", FoleyNaming.DEFAULT_OUTPUT_FOLDER))
	if paths.is_empty():
		return FoleyNaming.normalize_folder(default_folder)

	var first_path := str(paths[0])
	if first_path.is_empty():
		return FoleyNaming.normalize_folder(default_folder)

	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(first_path)):
		return FoleyNaming.normalize_folder(first_path)
	return FoleyNaming.normalize_folder(first_path.get_base_dir())


func _find_first_generated_audio_path(paths: PackedStringArray) -> String:
	for path in paths:
		if FoleyMetadata.has_metadata(path):
			return path
	return ""


func _collect_generated_audio_paths(paths: PackedStringArray) -> PackedStringArray:
	var generated := PackedStringArray()
	for path in paths:
		if FoleyMetadata.has_metadata(path):
			generated.append(path)
	return generated


func _show_generator_panel() -> void:
	if _dock == null or not is_instance_valid(_dock):
		return
	if _dock.get_parent() == null:
		_attach_dock(_dock_location)
	if _dock.has_method("refresh_account_state"):
		_dock.refresh_account_state(true)
	if _dock_location == DOCK_LOCATION_BOTTOM:
		if _bottom_panel_button == null or not is_instance_valid(_bottom_panel_button):
			_attach_dock(DOCK_LOCATION_BOTTOM)
		make_bottom_panel_item_visible(_dock)
		if _bottom_panel_button != null and is_instance_valid(_bottom_panel_button):
			_bottom_panel_button.button_pressed = true
		if _dock.has_method("focus_primary_input"):
			_dock.call_deferred("focus_primary_input")
		return
	if _supports_editor_dock():
		if _editor_dock == null or not is_instance_valid(_editor_dock) or _editor_dock.get_parent() == null:
			_attach_dock(DOCK_LOCATION_RIGHT)
		if _editor_dock != null and is_instance_valid(_editor_dock):
			if _editor_dock.has_method("make_visible"):
				_editor_dock.call("make_visible")
			elif _editor_dock.has_method("open"):
				_editor_dock.call("open")
		_queue_focus_generator_panel()
		return
	if get_editor_interface() != null and get_editor_interface().has_method("set_docks_visible"):
		get_editor_interface().call("set_docks_visible", true)
	var focused_tab := _focus_dock_tab(_dock)
	if not focused_tab and _dock.get_parent() == null:
		_attach_dock(DOCK_LOCATION_RIGHT)
	_dock.show()
	_queue_focus_generator_panel()


func _run_on_dock(form: Dictionary, should_generate: bool) -> void:
	if _dock == null or not is_instance_valid(_dock):
		return
	if not _dock.is_inside_tree():
		call_deferred("_run_on_dock", form, should_generate)
		return
	if should_generate:
		_dock.generate_from_external_form(form)
	else:
		_dock.apply_form(form)


func _focus_dock_tab(control: Control) -> bool:
	var current: Node = control
	while current != null:
		var parent: Node = current.get_parent()
		if parent is TabContainer:
			var tabs: TabContainer = parent as TabContainer
			if tabs != null:
				tabs.current_tab = current.get_index()
				return true
		current = parent
	return false


func _queue_focus_generator_panel(attempt: int = 0) -> void:
	var focus_target := _dock_focus_target()
	if focus_target == null or not is_instance_valid(focus_target):
		return
	if not focus_target.is_inside_tree():
		if attempt < 6:
			call_deferred("_queue_focus_generator_panel", attempt + 1)
		return
	_dock.show()
	if focus_target != _dock and focus_target.has_method("make_visible"):
		focus_target.call("make_visible")
	elif _dock.has_method("move_to_front"):
		_dock.call("move_to_front")
	var focused_tab := _focus_dock_tab(focus_target)
	if _dock.has_method("focus_primary_input"):
		_dock.call_deferred("focus_primary_input")
	if (not focused_tab or not _dock.is_visible_in_tree()) and attempt < 6:
		call_deferred("_queue_focus_generator_panel", attempt + 1)


func _ensure_plugin_settings() -> void:
	if not ProjectSettings.has_setting(FoleySettings.KEY_API_KEY_LEGACY):
		ProjectSettings.add_property_info({
			"name": FoleySettings.KEY_API_KEY_LEGACY,
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_PASSWORD
		})
		ProjectSettings.set_setting(FoleySettings.KEY_API_KEY_LEGACY, "")
		ProjectSettings.save()
	ProjectSettings.set_initial_value(FoleySettings.KEY_API_KEY_LEGACY, "")

	if not ProjectSettings.has_setting(KEY_DOCK_LOCATION):
		ProjectSettings.add_property_info({
			"name": KEY_DOCK_LOCATION,
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "%s,%s" % [DOCK_LOCATION_BOTTOM, DOCK_LOCATION_RIGHT]
		})
		ProjectSettings.set_setting(KEY_DOCK_LOCATION, DOCK_LOCATION_RIGHT)
		ProjectSettings.save()
	ProjectSettings.set_initial_value(KEY_DOCK_LOCATION, DOCK_LOCATION_RIGHT)


func _load_dock_location() -> String:
	var location := str(ProjectSettings.get_setting(KEY_DOCK_LOCATION, DOCK_LOCATION_RIGHT)).strip_edges().to_lower()
	if location == DOCK_LOCATION_RIGHT:
		return DOCK_LOCATION_RIGHT
	if location == DOCK_LOCATION_BOTTOM:
		return DOCK_LOCATION_BOTTOM
	return DOCK_LOCATION_RIGHT


func _save_dock_location(location: String) -> void:
	ProjectSettings.set_setting(KEY_DOCK_LOCATION, location)
	ProjectSettings.save()


func _set_dock_location(location: String) -> void:
	var normalized := DOCK_LOCATION_RIGHT if location == DOCK_LOCATION_RIGHT else DOCK_LOCATION_BOTTOM
	_dock_location = normalized
	_save_dock_location(_dock_location)
	if _dock == null or not is_instance_valid(_dock):
		return
	_attach_dock(_dock_location)


func _attach_dock(location: String) -> void:
	if _dock == null or not is_instance_valid(_dock):
		return
	_detach_dock()
	if location == DOCK_LOCATION_RIGHT:
		if _supports_editor_dock():
			var dock_wrapper := _ensure_editor_dock()
			if dock_wrapper != null:
				_adopt_dock(dock_wrapper)
				add_dock(dock_wrapper)
				return
		_detach_dock_from_parent()
		add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, _dock)
		_dock.show()
	else:
		_detach_dock_from_parent()
		_bottom_panel_button = add_control_to_bottom_panel(_dock, "Foley AI")
		_dock.show()


func _detach_dock() -> void:
	if _dock == null or not is_instance_valid(_dock):
		return
	if _bottom_panel_button != null and is_instance_valid(_bottom_panel_button):
		remove_control_from_bottom_panel(_dock)
	elif _editor_dock != null and is_instance_valid(_editor_dock) and _editor_dock.get_parent() != null and _supports_editor_dock():
		remove_dock(_editor_dock)
	elif _dock.get_parent() != null and _dock.get_parent() != _editor_dock:
		remove_control_from_docks(_dock)
	_bottom_panel_button = null


func _supports_editor_dock() -> bool:
	return has_method("add_dock") \
		and has_method("remove_dock") \
		and ClassDB.class_exists("EditorDock")


func _ensure_editor_dock() -> Control:
	if _editor_dock != null and is_instance_valid(_editor_dock):
		return _editor_dock
	var dock_instance := ClassDB.instantiate("EditorDock")
	if not (dock_instance is Control):
		return null
	_editor_dock = dock_instance as Control
	_editor_dock.name = "FoleyAIEditorDock"
	_editor_dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_dock.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor_dock.set("title", "Foley AI")
	_editor_dock.set("layout_key", "foley_ai")
	_editor_dock.set("default_slot", EditorPlugin.DOCK_SLOT_RIGHT_UL)
	if _open_generator_shortcut != null:
		_editor_dock.set("dock_shortcut", _open_generator_shortcut)
	return _editor_dock


func _adopt_dock(parent: Node) -> void:
	if _dock == null or not is_instance_valid(_dock) or parent == null:
		return
	if _dock.get_parent() == parent:
		return
	_detach_dock_from_parent()
	parent.add_child(_dock)
	_dock.show()


func _detach_dock_from_parent() -> void:
	if _dock == null or not is_instance_valid(_dock):
		return
	var parent: Node = _dock.get_parent()
	if parent != null:
		parent.remove_child(_dock)


func _dock_focus_target() -> Control:
	if _editor_dock != null and is_instance_valid(_editor_dock) and _dock.get_parent() == _editor_dock:
		return _editor_dock
	return _dock


func _setup_tools_submenu() -> void:
	_teardown_tools_submenu()
	_uses_tools_submenu = false
	if has_method("add_tool_submenu_item"):
		_tools_submenu = PopupMenu.new()
		_tools_submenu.name = "FoleyAIToolsSubmenu"
		_tools_submenu.add_item("Open Generator", TOOLS_ID_OPEN_GENERATOR)
		_tools_submenu.add_separator()
		_tools_submenu.add_item("Quick Generate", TOOLS_ID_QUICK_GENERATE)
		_tools_submenu.add_separator()
		_tools_submenu.add_item("Move Generator to Bottom Panel", TOOLS_ID_MOVE_BOTTOM)
		_tools_submenu.add_item("Move Generator to Right Dock", TOOLS_ID_MOVE_RIGHT)
		_tools_submenu.id_pressed.connect(_on_tools_submenu_id_pressed)
		add_tool_submenu_item(TOOLS_SUBMENU_NAME, _tools_submenu)
		_uses_tools_submenu = true
		return

	add_tool_menu_item(TOOL_MENU_OPEN_GENERATOR, Callable(self, "_on_open_generator_pressed"))
	add_tool_menu_item(TOOL_MENU_QUICK_GENERATE, Callable(self, "_on_quick_generate_menu_pressed"))
	add_tool_menu_item(TOOL_MENU_MOVE_BOTTOM, Callable(self, "_on_move_to_bottom_panel_pressed"))
	add_tool_menu_item(TOOL_MENU_MOVE_RIGHT, Callable(self, "_on_move_to_right_dock_pressed"))


func _teardown_tools_submenu() -> void:
	if _uses_tools_submenu:
		remove_tool_menu_item(TOOLS_SUBMENU_NAME)
	else:
		remove_tool_menu_item(TOOL_MENU_OPEN_GENERATOR)
		remove_tool_menu_item(TOOL_MENU_QUICK_GENERATE)
		remove_tool_menu_item(TOOL_MENU_MOVE_BOTTOM)
		remove_tool_menu_item(TOOL_MENU_MOVE_RIGHT)
	_uses_tools_submenu = false
	if _tools_submenu != null:
		if _tools_submenu.get_parent() != null:
			_tools_submenu.queue_free()
		else:
			_tools_submenu.free()
		_tools_submenu = null


func _on_tools_submenu_id_pressed(id: int) -> void:
	match id:
		TOOLS_ID_OPEN_GENERATOR:
			_on_open_generator_pressed()
		TOOLS_ID_QUICK_GENERATE:
			_on_quick_generate_menu_pressed()
		TOOLS_ID_MOVE_BOTTOM:
			_on_move_to_bottom_panel_pressed()
		TOOLS_ID_MOVE_RIGHT:
			_on_move_to_right_dock_pressed()


func _register_command_palette() -> void:
	if get_editor_interface() == null or not get_editor_interface().has_method("get_command_palette"):
		return
	_command_palette = get_editor_interface().get_command_palette()
	if _command_palette == null or not _command_palette.has_method("add_command"):
		return
	_command_palette.call(
		"add_command",
		"Foley AI: Open Generator",
		COMMAND_OPEN_GENERATOR,
		Callable(self, "_on_open_generator_pressed"),
		_shortcut_text(_open_generator_shortcut)
	)
	_command_palette.call(
		"add_command",
		"Foley AI: Quick Generate",
		COMMAND_QUICK_GENERATE,
		Callable(self, "_on_quick_generate_menu_pressed"),
		_shortcut_text(_quick_generate_shortcut)
	)


func _unregister_command_palette() -> void:
	if _command_palette == null or not _command_palette.has_method("remove_command"):
		_command_palette = null
		return
	_command_palette.call("remove_command", COMMAND_OPEN_GENERATOR)
	_command_palette.call("remove_command", COMMAND_QUICK_GENERATE)
	_command_palette = null


func _register_shortcuts(editor_settings: EditorSettings) -> void:
	if editor_settings == null:
		return
	_open_generator_shortcut = _resolve_or_create_shortcut(
		editor_settings,
		SHORTCUT_OPEN_GENERATOR,
		_build_shortcut(KEY_G, true, true, false)
	)
	_quick_generate_shortcut = _resolve_or_create_shortcut(
		editor_settings,
		SHORTCUT_QUICK_GENERATE,
		_build_shortcut(KEY_G, true, false, true)
	)


func _resolve_or_create_shortcut(
	editor_settings: EditorSettings,
	path: String,
	default_shortcut: Shortcut
) -> Shortcut:
	if editor_settings.has_method("get_shortcut"):
		var existing := editor_settings.call("get_shortcut", path)
		if existing is Shortcut:
			return existing
	if editor_settings.has_method("add_shortcut"):
		editor_settings.call("add_shortcut", path, default_shortcut)
	return default_shortcut


func _build_shortcut(keycode: int, ctrl_pressed: bool, shift_pressed: bool, alt_pressed: bool) -> Shortcut:
	var key_event := InputEventKey.new()
	key_event.keycode = keycode
	key_event.ctrl_pressed = ctrl_pressed
	key_event.shift_pressed = shift_pressed
	key_event.alt_pressed = alt_pressed
	var shortcut := Shortcut.new()
	shortcut.events = [key_event]
	return shortcut


func _shortcut_text(shortcut: Shortcut) -> String:
	if shortcut == null or not shortcut.has_method("get_as_text"):
		return ""
	return shortcut.get_as_text()
