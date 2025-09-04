# =============================================================================
# HYPERSPACE MAP - Integer ID System
# =============================================================================
# HyperspaceMap.gd
extends Control

@onready var info_label: Label = $MainContainer/RightPanel/JumpPanel/InfoLabel
@onready var jump_button: Button = $MainContainer/RightPanel/InfoPanel/InfoContainer/JumpButton
@onready var cancel_button: Button = $MainContainer/RightPanel/InfoPanel/InfoContainer/CancelButton
@onready var flavor_panel = $MainContainer/RightPanel/FlavorPanel
@onready var flavor_label = $MainContainer/RightPanel/FlavorPanel/FlavorLabel
@onready var left_panel = $MainContainer/LeftPanel

# ALL integer IDs
var systems_data: Dictionary = {}  # int -> system_data
var system_positions: Dictionary = {}  # int -> Vector2
var system_connections: Dictionary = {}  # int -> Array[int]
var selected_system_id: int = -1
var current_system_id: int = -1

# Gamepad navigation
var available_system_ids: Array[int] = []
var system_index: int = -1
var map_has_focus: bool = false
var input_delay_timer: float = 0.0
var input_delay_duration: float = 0.3
var can_accept_input: bool = false

# Navigation cooldown
var navigation_cooldown_timer: float = 0.0
var navigation_cooldown_duration: float = 0.25
var can_navigate: bool = true

# Visual settings
var bg_color = Color(0.0, 0.2, 0.0, 0.25)
var line_color = Color(0.0, 0.8, 0.0, 1.0)
var system_color = Color(0.0, 1.0, 0.0, 1.0)
var current_system_color = Color(1.0, 1.0, 0.0, 1.0)
var selected_system_color = Color(1.0, 0.5, 0.0, 1.0)
var unavailable_color = Color(0.3, 0.3, 0.3, 1.0)

var system_radius = 8.0
var line_width = 2.0
var map_canvas: Control

func _ready():
	load_systems_from_universe_data()
	current_system_id = UniverseManager.current_system_id
	
	await get_tree().process_frame
	
	if jump_button:
		jump_button.pressed.connect(_on_jump_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	
	setup_map_canvas()
	setup_gamepad_focus()
	update_ui()

func _process(delta):
	if visible and not can_accept_input:
		input_delay_timer += delta
		if input_delay_timer >= input_delay_duration:
			can_accept_input = true
	
	if not can_navigate:
		navigation_cooldown_timer += delta
		if navigation_cooldown_timer >= navigation_cooldown_duration:
			can_navigate = true
			navigation_cooldown_timer = 0.0

func setup_gamepad_focus():
	jump_button.focus_mode = Control.FOCUS_ALL
	cancel_button.focus_mode = Control.FOCUS_ALL
	
	jump_button.focus_neighbor_bottom = jump_button.get_path_to(cancel_button)
	cancel_button.focus_neighbor_top = cancel_button.get_path_to(jump_button)
	
	if map_canvas:
		map_canvas.focus_mode = Control.FOCUS_ALL
		map_canvas.focus_entered.connect(_on_map_focus_entered)
		map_canvas.focus_exited.connect(_on_map_focus_exited)
		
		map_canvas.focus_neighbor_right = map_canvas.get_path_to(jump_button)
		jump_button.focus_neighbor_left = jump_button.get_path_to(map_canvas)
		cancel_button.focus_neighbor_left = cancel_button.get_path_to(map_canvas)

func _on_map_focus_entered():
	map_has_focus = true
	if selected_system_id == -1 and available_system_ids.size() > 0:
		system_index = 0
		select_system(available_system_ids[system_index])

func _on_map_focus_exited():
	map_has_focus = false

func load_systems_from_universe_data():
	"""Load systems using integer IDs"""
	print("Loading systems from universe data...")
	
	UniverseManager.ensure_all_systems_loaded()
	
	# Get systems data from UniverseManager (now with integer keys)
	systems_data = UniverseManager.universe_data.get("systems", {})
	
	if systems_data.is_empty():
		push_error("No systems data found in UniverseManager!")
		return
	
	# Clear existing data
	system_positions.clear()
	system_connections.clear()
	
	var map_width = 480
	var map_height = 500
	var margin = 50
	
	# Load positions and connections using integer IDs
	for system_id in systems_data:
		var system_data = systems_data[system_id]
		
		# system_id is now an integer
		var map_pos = system_data.get("map_position", {"x": 0.5, "y": 0.5})
		var actual_position = Vector2(
			margin + map_width * map_pos.x,
			margin + map_height * map_pos.y
		)
		system_positions[system_id] = actual_position
		
		# Connections are now arrays of integers
		var connections = system_data.get("connections", [])
		system_connections[system_id] = connections
		
		print("Loaded system ID ", system_id, " (", system_data.name, ") at ", map_pos, " with ", connections.size(), " connections")
	
	print("Loaded ", systems_data.size(), " systems from universe data")
	build_available_systems_list()

func build_available_systems_list():
	"""Build list of all system IDs for gamepad navigation"""
	available_system_ids.clear()
	
	# Get all system IDs and sort them
	for system_id in systems_data.keys():
		available_system_ids.append(system_id)
	
	# Sort by system name for consistent order
	available_system_ids.sort_custom(func(a, b): 
		var name_a = systems_data[a].get("name", "")
		var name_b = systems_data[b].get("name", "")
		return name_a < name_b
	)
	
	print("Available systems for navigation: ", available_system_ids)

func setup_map_canvas():
	if not left_panel:
		print("ERROR: Left panel not found!")
		return
	
	map_canvas = Control.new()
	map_canvas.name = "MapCanvas"
	map_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	
	left_panel.add_child(map_canvas)
	map_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	map_canvas.draw.connect(_draw_map)
	map_canvas.gui_input.connect(_on_map_input)

func _draw_map():
	if not map_canvas:
		return
	
	var canvas_size = map_canvas.size
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		return
	
	var margin = 20
	var draw_area = Rect2(
		Vector2(margin, margin),
		canvas_size - Vector2(margin * 2, margin * 2)
	)
	
	var scaled_positions = scale_system_positions_to_area(draw_area)
	
	# Draw connection lines using integer IDs
	for system_id in system_connections:
		if system_id in scaled_positions:
			var system_pos = scaled_positions[system_id]
			var connections = system_connections[system_id]
			
			for connected_id in connections:
				if connected_id in scaled_positions:
					var connected_pos = scaled_positions[connected_id]
					map_canvas.draw_line(system_pos, connected_pos, line_color, line_width)
	
	# Draw systems
	for system_id in scaled_positions:
		var pos = scaled_positions[system_id]
		var color = system_color
		
		# Color coding using integer IDs
		if system_id == current_system_id:
			color = current_system_color
		elif system_id == selected_system_id:
			color = selected_system_color
		elif not can_travel_to(system_id):
			color = unavailable_color
		
		map_canvas.draw_circle(pos, system_radius, color)
		
		# Focus ring for selected system
		if system_id == selected_system_id and map_has_focus:
			map_canvas.draw_arc(pos, system_radius + 4, 0, TAU, 32, Color.WHITE, 2.0)
		
		# System name
		var system_name = get_system_name(system_id)
		var font = ThemeDB.fallback_font
		var font_size = 16
		var text_size = font.get_string_size(system_name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = pos + Vector2(-text_size.x / 2, system_radius + 20)
		
		text_pos.x = clamp(text_pos.x, draw_area.position.x, draw_area.position.x + draw_area.size.x - text_size.x)
		text_pos.y = clamp(text_pos.y, draw_area.position.y + font_size, draw_area.position.y + draw_area.size.y)
		
		map_canvas.draw_string(font, text_pos, system_name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
	
	# Controller instructions
	if map_has_focus:
		var font = ThemeDB.fallback_font
		var instruction_text = "D-pad/Stick: Select System  |  A: Confirm  |  →: Jump Options"
		var instruction_size = font.get_string_size(instruction_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		var instruction_pos = Vector2((canvas_size.x - instruction_size.x) / 2, canvas_size.y - 10)
		map_canvas.draw_string(font, instruction_pos, instruction_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.YELLOW)

func scale_system_positions_to_area(draw_area: Rect2) -> Dictionary:
	"""Scale positions maintaining integer keys"""
	var scaled_positions = {}
	
	if system_positions.is_empty():
		return scaled_positions
	
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	
	for pos in system_positions.values():
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)
	
	var original_size = max_pos - min_pos
	if original_size.x == 0: original_size.x = 1
	if original_size.y == 0: original_size.y = 1
	
	var text_padding = 40
	var available_size = draw_area.size - Vector2(text_padding, text_padding)
	var scale = min(available_size.x / original_size.x, available_size.y / original_size.y)
	
	var scaled_size = original_size * scale
	var offset = draw_area.position + (draw_area.size - scaled_size) / 2
	
	# Scale each system position (maintaining integer keys)
	for system_id in system_positions:
		var original_pos = system_positions[system_id]
		var relative_pos = (original_pos - min_pos) * scale
		scaled_positions[system_id] = offset + relative_pos
	
	return scaled_positions

func _on_map_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var clicked_system_id = get_system_at_position(event.position)
			if clicked_system_id != -1:
				select_system(clicked_system_id)

func get_system_at_position(pos: Vector2) -> int:
	"""Find system ID at mouse position"""
	if not map_canvas:
		return -1
	
	var canvas_size = map_canvas.size
	var margin = 20
	var draw_area = Rect2(
		Vector2(margin, margin),
		canvas_size - Vector2(margin * 2, margin * 2)
	)
	
	var scaled_positions = scale_system_positions_to_area(draw_area)
	
	for system_id in scaled_positions:
		var system_pos = scaled_positions[system_id]
		var distance = pos.distance_to(system_pos)
		if distance <= system_radius + 10:
			return system_id
	
	return -1

func navigate_systems(direction: int):
	"""Navigate through systems using integer IDs"""
	if not can_navigate:
		return
	
	if available_system_ids.is_empty():
		return
	
	if system_index < 0:
		system_index = 0
	else:
		system_index = (system_index + direction) % available_system_ids.size()
		if system_index < 0:
			system_index = available_system_ids.size() - 1
	
	var new_system_id = available_system_ids[system_index]
	select_system(new_system_id)
	
	can_navigate = false
	navigation_cooldown_timer = 0.0
	
	var system_name = get_system_name(new_system_id)
	print("Selected: ", system_name, " (ID: ", new_system_id, ") - ", system_index + 1, "/", available_system_ids.size())

func select_system(system_id: int):
	"""Select system by integer ID"""
	selected_system_id = system_id
	
	# Update system index for controller navigation
	system_index = available_system_ids.find(system_id)
	if system_index < 0:
		system_index = 0
	
	update_ui()
	if map_canvas:
		map_canvas.queue_redraw()

func update_ui():
	"""Update UI with system information"""
	var flavor_text = ""
	
	if selected_system_id == -1:
		info_label.text = "Select a destination system"
		jump_button.disabled = true
		flavor_text = "Navigate the galaxy using the hyperspace network."
	elif selected_system_id == current_system_id:
		var system_name = get_system_name(selected_system_id)
		info_label.text = "Current location: " + system_name
		jump_button.disabled = true
		flavor_text = get_system_flavor(selected_system_id)
	elif can_travel_to(selected_system_id):
		var system_name = get_system_name(selected_system_id)
		info_label.text = "Jump to: " + system_name
		jump_button.disabled = false
		flavor_text = get_system_flavor(selected_system_id)
	else:
		var system_name = get_system_name(selected_system_id)
		info_label.text = system_name + " - Not accessible"
		jump_button.disabled = true
		flavor_text = get_system_flavor(selected_system_id)
	
	if flavor_label:
		flavor_label.text = flavor_text

func get_system_flavor(system_id: int) -> String:
	"""Get flavor text by system ID"""
	var system_data = systems_data.get(system_id, {})
	return system_data.get("flavor_text", "No information available about this system.")

func get_system_name(system_id: int) -> String:
	"""Get system name by ID"""
	var system_data = systems_data.get(system_id, {})
	return system_data.get("name", "Unknown System")

func can_travel_to(system_id: int) -> bool:
	"""Check if travel is possible using integer IDs"""
	if current_system_id == -1:
		return false
	var connections = system_connections.get(current_system_id, [])
	return system_id in connections

func _on_jump_pressed():
	if selected_system_id != -1 and can_travel_to(selected_system_id):
		var player_ship = UniverseManager.player_ship
		if player_ship and player_ship.has_method("start_hyperspace_sequence"):
			player_ship.start_hyperspace_sequence(selected_system_id)
			hide_map()
		else:
			UniverseManager.change_system(selected_system_id)
			hide_map()

func _on_cancel_pressed():
	hide_map()

func show_map():
	load_systems_from_universe_data()
	current_system_id = UniverseManager.current_system_id
	selected_system_id = -1
	system_index = -1
	
	input_delay_timer = 0.0
	can_accept_input = false
	navigation_cooldown_timer = 0.0
	can_navigate = true
	
	update_ui()
	visible = true
	get_tree().paused = true
	
	await get_tree().process_frame
	
	if map_canvas:
		map_canvas.grab_focus()
		map_canvas.queue_redraw()

func hide_map():
	visible = false
	get_tree().paused = false
	
	map_has_focus = false
	selected_system_id = -1
	system_index = -1

func _input(event):
	if not visible or not can_accept_input:
		if event.is_action_pressed("ui_cancel"):
			hide_map()
			get_viewport().set_input_as_handled()
		return
	
	if map_has_focus:
		if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
			var direction = 1 if event.is_action_pressed("ui_down") else -1
			navigate_systems(direction)
			get_viewport().set_input_as_handled()
		
		elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			var direction = 1 if event.is_action_pressed("ui_right") else -1
			navigate_systems(direction)
			get_viewport().set_input_as_handled()
		
		elif event.is_action_pressed("ui_accept"):
			if selected_system_id != -1 and can_travel_to(selected_system_id):
				_on_jump_pressed()
			elif selected_system_id != -1:
				jump_button.grab_focus()
			get_viewport().set_input_as_handled()
	
	if event.is_action_pressed("ui_cancel"):
		hide_map()
		get_viewport().set_input_as_handled()
	
	elif event.is_action_pressed("ui_accept"):
		var focused_control = get_viewport().gui_get_focus_owner()
		if focused_control == jump_button:
			_on_jump_pressed()
		elif focused_control == cancel_button:
			_on_cancel_pressed()
		get_viewport().set_input_as_handled()

# =============================================================================
# COMPATIBILITY METHODS
# =============================================================================

func get_system_positions() -> Dictionary:
	"""Return system positions for compatibility"""
	return system_positions
