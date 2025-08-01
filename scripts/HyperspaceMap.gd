# =============================================================================
# HYPERSPACE MAP - Visual galaxy map for system navigation
# =============================================================================
# HyperspaceMap.gd
extends Control
@onready var info_label: Label = $MainContainer/RightPanel/JumpPanel/InfoLabel
@onready var jump_button: Button = $MainContainer/RightPanel/InfoPanel/InfoContainer/JumpButton
@onready var cancel_button: Button = $MainContainer/RightPanel/InfoPanel/InfoContainer/CancelButton
@onready var flavor_panel = $MainContainer/RightPanel/FlavorPanel
@onready var flavor_label = $MainContainer/RightPanel/FlavorPanel/FlavorLabel
@onready var left_panel = $MainContainer/LeftPanel



var systems_data: Dictionary = {}
var system_positions: Dictionary = {}
var system_connections: Dictionary = {}
var selected_system: String = ""
var current_system: String = ""

# Visual settings - retro DOS green theme
var bg_color = Color(0.0, 0.2, 0.0, 0.25)  # Dark green with 75% transparency
var line_color = Color(0.0, 0.8, 0.0, 1.0)  # Bright green
var system_color = Color(0.0, 1.0, 0.0, 1.0)  # Bright green
var current_system_color = Color(1.0, 1.0, 0.0, 1.0)  # Yellow
var selected_system_color = Color(1.0, 0.5, 0.0, 1.0)  # Orange
var unavailable_color = Color(0.3, 0.3, 0.3, 1.0)  # Dark gray

var system_radius = 8.0
var line_width = 2.0

# Map drawing control
var map_canvas: Control

func _ready():
	setup_systems()
	current_system = UniverseManager.current_system_id
	
	# Wait for nodes to be ready
	await get_tree().process_frame
	
	# Connect signals - add error checking
	if jump_button:
		jump_button.pressed.connect(_on_jump_pressed)
		print("Jump button connected")
	else:
		print("ERROR: Jump button not found!")
	
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
		print("Cancel button connected")
	else:
		print("ERROR: Cancel button not found!")
	
	# Create map canvas on the left panel
	setup_map_canvas()
	
	update_ui()

func setup_map_canvas():
	"""Create a control for drawing the map on the left panel"""
	if not left_panel:
		print("ERROR: Left panel not found!")
		return
	
	# Create a control to draw on
	map_canvas = Control.new()
	map_canvas.name = "MapCanvas"
	map_canvas.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow mouse events to pass through
	
	# Make it fill the left panel
	left_panel.add_child(map_canvas)
	map_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Connect the drawing
	map_canvas.draw.connect(_draw_map)
	map_canvas.gui_input.connect(_on_map_input)
	
	print("Map canvas created")

func setup_systems():
	"""Define system positions and connections for the map"""
	# Define system positions (distributed across the map)
	var map_width = 480
	var map_height = 500
	var margin = 50
	
	system_positions = {
		"sol_system": Vector2(margin + map_width * 0.3, margin + map_height * 0.5),
		"alpha_centauri": Vector2(margin + map_width * 0.45, margin + map_height * 0.4),
		"vega_system": Vector2(margin + map_width * 0.2, margin + map_height * 0.3),
		"sirius_system": Vector2(margin + map_width * 0.6, margin + map_height * 0.3),
		"rigel_system": Vector2(margin + map_width * 0.7, margin + map_height * 0.6),
		"arcturus_system": Vector2(margin + map_width * 0.1, margin + map_height * 0.7),
		"deneb_system": Vector2(margin + map_width * 0.4, margin + map_height * 0.8),
		"aldebaran_system": Vector2(margin + map_width * 0.8, margin + map_height * 0.4),
		"antares_system": Vector2(margin + map_width * 0.6, margin + map_height * 0.7),
		"capella_system": Vector2(margin + map_width * 0.2, margin + map_height * 0.6)
	}
	
	# Define connections (simple network, 2-3 connections per system)
	system_connections = {
		"sol_system": ["alpha_centauri", "vega_system"],
		"alpha_centauri": ["sol_system", "sirius_system", "rigel_system"],
		"vega_system": ["sol_system", "arcturus_system", "capella_system"],
		"sirius_system": ["alpha_centauri", "aldebaran_system"],
		"rigel_system": ["alpha_centauri", "antares_system", "aldebaran_system"],
		"arcturus_system": ["vega_system", "capella_system", "deneb_system"],
		"deneb_system": ["arcturus_system", "capella_system", "antares_system"],
		"aldebaran_system": ["sirius_system", "rigel_system"],
		"antares_system": ["rigel_system", "deneb_system"],
		"capella_system": ["vega_system", "arcturus_system", "deneb_system"]
	}
	
	systems_data = UniverseManager.universe_data.systems

func _draw_map():
	"""Draw the hyperspace map on the map canvas"""
	if not map_canvas:
		return
	
	var canvas_size = map_canvas.size
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		return
	
	# Calculate drawing area (with margins)
	var margin = 20
	var draw_area = Rect2(
		Vector2(margin, margin),
		canvas_size - Vector2(margin * 2, margin * 2)
	)
	
	# Draw background
	# map_canvas.draw_rect(draw_area, bg_color)
	
	# Scale system positions to fit within the drawing area
	var scaled_positions = scale_system_positions_to_area(draw_area)
	
	# Draw connection lines first (so they appear behind systems)
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
		
		# Color coding
		if system_id == current_system:
			color = current_system_color
		elif system_id == selected_system:
			color = selected_system_color
		elif not can_travel_to(system_id):
			color = unavailable_color
		
		# Draw system circle
		map_canvas.draw_circle(pos, system_radius, color)
		
		# Draw system name
		var system_name = systems_data.get(system_id, {}).get("name", system_id)
		var font = ThemeDB.fallback_font
		var font_size = 16
		var text_size = font.get_string_size(system_name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = pos + Vector2(-text_size.x / 2, system_radius + 20)
		
		# Make sure text doesn't go outside drawing area
		text_pos.x = clamp(text_pos.x, draw_area.position.x, draw_area.position.x + draw_area.size.x - text_size.x)
		text_pos.y = clamp(text_pos.y, draw_area.position.y + font_size, draw_area.position.y + draw_area.size.y)
		
		map_canvas.draw_string(font, text_pos, system_name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)

func scale_system_positions_to_area(draw_area: Rect2) -> Dictionary:
	"""Scale the original system positions to fit within the specified drawing area"""
	var scaled_positions = {}
	
	if system_positions.is_empty():
		return scaled_positions
	
	# Find the bounds of the original system positions
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	
	for pos in system_positions.values():
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)
	
	# Calculate original size
	var original_size = max_pos - min_pos
	
	# Avoid division by zero
	if original_size.x == 0:
		original_size.x = 1
	if original_size.y == 0:
		original_size.y = 1
	
	# Calculate scale to fit in drawing area (with some padding for text)
	var text_padding = 40  # Extra space for system names
	var available_size = draw_area.size - Vector2(text_padding, text_padding)
	var scale = min(available_size.x / original_size.x, available_size.y / original_size.y)
	
	# Calculate offset to center the scaled positions in the drawing area
	var scaled_size = original_size * scale
	var offset = draw_area.position + (draw_area.size - scaled_size) / 2
	
	# Scale and position each system
	for system_id in system_positions:
		var original_pos = system_positions[system_id]
		var relative_pos = (original_pos - min_pos) * scale
		scaled_positions[system_id] = offset + relative_pos
	
	return scaled_positions

func _on_map_input(event):
	"""Handle mouse input on the map canvas"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var clicked_system = get_system_at_position(event.position)
			if clicked_system != "":
				select_system(clicked_system)

func get_system_at_position(pos: Vector2) -> String:
	"""Find which system was clicked based on mouse position"""
	if not map_canvas:
		return ""
	
	# Calculate drawing area and get scaled positions
	var canvas_size = map_canvas.size
	var margin = 20
	var draw_area = Rect2(
		Vector2(margin, margin),
		canvas_size - Vector2(margin * 2, margin * 2)
	)
	
	var scaled_positions = scale_system_positions_to_area(draw_area)
	
	# Check each scaled system position
	for system_id in scaled_positions:
		var system_pos = scaled_positions[system_id]
		var distance = pos.distance_to(system_pos)
		if distance <= system_radius + 10:  # Small margin for easier clicking
			return system_id
	
	return ""

func select_system(system_id: String):
	"""Select a system and update UI"""
	selected_system = system_id
	update_ui()
	if map_canvas:
		map_canvas.queue_redraw()

func update_ui():
	"""Update the info panel based on current selection"""
	var flavor_text = ""
	
	if selected_system == "":
		info_label.text = "Select a destination system"
		jump_button.disabled = true
		flavor_text = "Navigate the galaxy using the hyperspace network. Click on connected systems to plan your route."
	elif selected_system == current_system:
		info_label.text = "Current location: " + get_system_name(selected_system)
		jump_button.disabled = true
		flavor_text = get_system_flavor(selected_system)
	elif can_travel_to(selected_system):
		info_label.text = "Jump to: " + get_system_name(selected_system)
		jump_button.disabled = false
		flavor_text = get_system_flavor(selected_system)
	else:
		info_label.text = get_system_name(selected_system) + " - Not accessible"
		jump_button.disabled = true
		flavor_text = get_system_flavor(selected_system)
	
	# Set flavor text
	if flavor_label != null:
		flavor_label.text = flavor_text
	else:
		print("ERROR: flavor_label is null!")

func get_system_flavor(system_id: String) -> String:
	"""Get the flavor text for a system"""
	var system_data = systems_data.get(system_id, {})
	var flavor = system_data.get("flavor_text", "No information available about this system.")
	return flavor

func get_system_name(system_id: String) -> String:
	return systems_data.get(system_id, {}).get("name", system_id)

func can_travel_to(system_id: String) -> bool:
	"""Check if we can travel to the specified system"""
	if current_system == "":
		return false
	var connections = system_connections.get(current_system, [])
	return system_id in connections

func _on_jump_pressed():
	print("Jump button pressed!")
	if selected_system != "" and can_travel_to(selected_system):
		# Start hyperspace sequence instead of instant jump
		var player_ship = UniverseManager.player_ship
		if player_ship and player_ship.has_method("start_hyperspace_sequence"):
			player_ship.start_hyperspace_sequence(selected_system)
			hide_map()
		else:
			# Fallback to instant jump if player ship not found
			UniverseManager.change_system(selected_system)
			hide_map()

func _on_cancel_pressed():
	print("Cancel button pressed!")
	hide_map()

func show_map():
	"""Show the hyperspace map"""
	print("Showing hyperspace map")
	
	# Hide minimap when hyperspace map is open
	hide_minimap()
	
	setup_systems()
	current_system = UniverseManager.current_system_id
	selected_system = ""
	update_ui()
	visible = true
	get_tree().paused = true
	
	# Make sure map canvas redraws
	if map_canvas:
		map_canvas.queue_redraw()

func hide_map():
	"""Hide the hyperspace map"""
	print("Hiding hyperspace map")
	visible = false
	get_tree().paused = false
	
	# Show minimap again
	show_minimap()

func hide_minimap():
	"""Hide the minimap when hyperspace map is open"""
	var ui_controller = get_tree().get_first_node_in_group("ui")
	if ui_controller:
		var minimap = ui_controller.get_node_or_null("Minimap")
		if minimap:
			minimap.visible = false

func show_minimap():
	"""Show the minimap when hyperspace map is closed"""
	var ui_controller = get_tree().get_first_node_in_group("ui")
	if ui_controller:
		var minimap = ui_controller.get_node_or_null("Minimap")
		if minimap:
			minimap.visible = true

func _input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		hide_map()
		get_viewport().set_input_as_handled()
