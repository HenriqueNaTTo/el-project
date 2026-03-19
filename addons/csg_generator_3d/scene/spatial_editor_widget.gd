@tool extends Control

var editor_selection: EditorSelection

enum GeneratorKeys {
	Box,
	Cylinder,
	Staircase,
	Ramp,
}

@onready var menu_button: MenuButton = $MenuButton
var menu_popup: PopupMenu


func _ready() -> void:
	menu_popup = menu_button.get_popup()
	connect_signals()


func add_generator_options() -> void:
	editor_selection = EditorInterface.get_selection()
	menu_popup.clear(true)
	for i in GeneratorKeys:
		var index := menu_popup.item_count
		menu_popup.add_item(i)
		menu_popup.set_item_disabled(index, EditorInterface.get_edited_scene_root() == null)
		menu_popup.set_item_tooltip(index, "Cannot use in Empty Scenes")


func connect_signals() -> void:
	menu_popup.id_pressed.connect(popup_id_pressed)


func menu_button_about_to_popup() -> void:
	add_generator_options()


func popup_id_pressed(id: int) -> void:
	match id:
		GeneratorKeys.Box:
			make_window("Create Box", 
				{
					"width": 1.0,
					"height": 1.0,
					"depth": 1.0,
				},
				run_box_generator
			)
		GeneratorKeys.Cylinder:
			make_window("Create Cylinder", 
				{
					"segments": 8,
					"width": 1.0,
					"depth": 1.0,
				},
				run_cylinder_generator
			)
		GeneratorKeys.Staircase:
			make_window("Create Staircase", 
				{
					"step_count": 5,
					"step_depth": 0.1,
					"step_height": 0.1,
				},
				run_stair_generator
			)
		GeneratorKeys.Ramp:
			make_window("Create Ramp", 
				{
					"width": 2.0,
					"depth": 2.0,
					"height": 1.0,
					"platform_depth": 0.5,
				},
				run_ramp_generator
			)
		
	


func make_window(title: String, parameters: Dictionary[String, Variant], run_generator: Callable) -> void:
	var window := Window.new()
	window.title = title
	var param_count: int = parameters.size()
	window.size = Vector2i(128 + param_count * 128, 64 + param_count * 64)
	window.close_requested.connect(window.queue_free)
	
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var vbox := VBoxContainer.new()
	window.add_child(bg)
	window.add_child(vbox)
	
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var output_parameters: Dictionary[String, Variant] = parameters.duplicate_deep()
	
	for parameter_key: String in parameters:
		var value: Variant = parameters[parameter_key]
		
		if value is int or value is float:
			var label: Label = Label.new()
			label.add_theme_font_size_override("font_size", 12)
			label.text = parameter_key.capitalize()
			
			var spin_box := SpinBox.new()
			
			vbox.add_child(label)
			vbox.add_child(spin_box)
			
			spin_box.step = 1.0 if value is int else 0.1
			spin_box.min_value = 1.0 if value is int else 0.1
			spin_box.value = value
			
			spin_box.set_meta("parameter_key", parameter_key)
			
			spin_box.value_changed.connect(func(value): output_parameters[parameter_key] = value)
		
	
	var hbox := HBoxContainer.new()
	vbox.add_child(hbox)
	hbox.add_theme_constant_override("separation", 8)
	
	
	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(cancel_button)
	cancel_button.pressed.connect(window.queue_free)
	
	
	var accept_button := Button.new()
	accept_button.text = "Create"
	accept_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(accept_button)
	
	
	add_child(window)
	window.hide()
	window.popup_centered()
	
	if run_generator.is_valid():
		accept_button.pressed.connect(func():
			
			var output: Node = run_generator.call(output_parameters)
			
			var selected_nodes := editor_selection.get_selected_nodes()
			var parent: Node
			
			if selected_nodes.size() > 0:
				parent = selected_nodes[0]
			else:
				var scene_root := EditorInterface.get_edited_scene_root()
				if is_instance_valid(scene_root): parent = scene_root
			
			if is_instance_valid(parent):
				var undoredo := EditorInterface.get_editor_undo_redo()
				undoredo.create_action("%s" % title)
				
				undoredo.add_do_method(parent, "add_child", output)
				undoredo.add_do_reference(output)
				
				undoredo.add_do_property(output, "owner", parent.get_tree().edited_scene_root)
				
				undoredo.add_undo_method(parent, "remove_child", output)
				
				undoredo.commit_action(true)
			window.queue_free()
		)


func run_box_generator(parameters: Dictionary[String, Variant]) -> CSGPolygon3D:
	var polygon := CSGPolygon3D.new()
	var points: PackedVector2Array = []
	
	var width: float = parameters.get("width", 1.0)
	var height: float = parameters.get("height", 1.0)
	var depth: float = parameters.get("depth", 1.0)
	
	points.append(Vector2(-width/2, -height/2))
	points.append(Vector2(width/2, -height/2))
	points.append(Vector2(width/2, height/2))
	points.append(Vector2(-width/2, height/2))
	
	polygon.polygon = points
	polygon.depth = depth
	polygon.name = "CSGBoxPolygon"
	return polygon


func run_cylinder_generator(parameters: Dictionary[String, Variant]) -> CSGPolygon3D:
	var polygon := CSGPolygon3D.new()
	var points: PackedVector2Array = []
	
	var width: float = parameters.get("width", 1.0)
	var depth: float = parameters.get("depth", 1.0)
	var segments: float = parameters.get("segments", 8)
	
	for i: float in range(0, segments, 1):
		var angle: float = i / segments * TAU
		points.append(Vector2(0, width / 2.0).rotated(angle))
	
	polygon.polygon = points
	polygon.depth = depth
	polygon.name = "CSGCylinderPolygon"
	return polygon


func run_stair_generator(parameters: Dictionary[String, Variant]) -> CSGPolygon3D:
	var polygon := CSGPolygon3D.new()
	var points: PackedVector2Array = []
	
	var step_count: int = parameters.get("step_count", 5)
	var step_depth: float = parameters.get("step_depth", 0.1)
	var step_height: float = parameters.get("step_height", 0.1)
	
	var width: float = parameters.get("width", 1.0)

	for i: int in range(0, step_count, 1):
		var offset := Vector2(step_depth * (i - 1), step_height * i)
		if i > 0: 
			points.append(offset)
		
		points.append(Vector2(offset.x + step_depth, offset.y))
		points.append(Vector2(offset.x + step_depth, offset.y + step_height))
	
	points.append(Vector2(step_depth * step_count + step_depth, step_height * step_count))
	points.append(Vector2(step_depth * step_count + step_depth, 0))
	
	polygon.polygon = points
	polygon.depth = width
	polygon.name = "CSGStaircasePolygon"
	return polygon


func run_ramp_generator(parameters: Dictionary[String, Variant]) -> CSGPolygon3D:
	var polygon := CSGPolygon3D.new()
	var points: PackedVector2Array = []
	
	var width: float = parameters.get("width", 2.0)
	var depth: float = parameters.get("depth", 2.0)
	var height: float = parameters.get("height", 2.0)
	var platform_depth: float = parameters.get("platform_depth", .5)
	
	points.append(Vector2.ZERO)
	
	points.append(Vector2(depth, height))
	points.append(Vector2(depth + platform_depth, height))
	points.append(Vector2(depth + platform_depth, 0))
	
	
	polygon.polygon = points
	polygon.depth = width
	polygon.name = "CSGRampPolygon"
	return polygon
