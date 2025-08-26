# =============================================================================
# HYPERSPACE MAP TEST - Visual test for Gephi CSV data - FIXED VERSION
# Y-axis flipped to match Gephi, Hubs now show as circles, WITH NODE TOOLTIP
# =============================================================================
extends Control

# Configuration - change these paths as needed
const CSV_FOLDER_PATH = "res://data/hyperspace/"
const NODES_CSV_NAME = "universeExport_nodes.csv"
const EDGES_CSV_NAME = "universeExport_edges.csv"

# Data
var data_parser: HyperspaceDataParser
var nodes_data: Array[Dictionary] = []
var edges_data: Array[Dictionary] = []

# View control
var zoom_level: float = 1.0
var pan_offset: Vector2 = Vector2.ZERO
var is_panning: bool = false
var last_pan_position: Vector2

# Visual settings
var node_base_size: float = 8.0
var edge_width: float = 2.0
var show_labels: bool = false
var show_info_panel: bool = true

# Map bounds and scaling
var map_bounds: Rect2
var display_area: Rect2

# UI elements
var info_label: Label
var zoom_label: Label
var controls_label: Label

# NEW: Node tooltip functionality
var tooltip_label: Label = null
var current_tooltip_node: Dictionary = {}
var tooltip_visible: bool = false

func _ready():
	print("=== HYPERSPACE MAP TEST STARTING ===")
	
	# Set up the control
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Create UI elements
	create_ui_elements()
	
	# NEW: Create tooltip
	create_tooltip()
	
	# Load and parse CSV data
	load_hyperspace_data()
	
	# Set up initial view
	setup_initial_view()
	
	print("=== TEST SCENE READY ===")

func create_ui_elements():
	"""Create UI overlays for information"""
	# Info panel (top-left)
	info_label = Label.new()
	info_label.position = Vector2(10, 10)
	info_label.size = Vector2(300, 150)
	info_label.add_theme_color_override("font_color", Color.WHITE)
	info_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	info_label.add_theme_constant_override("shadow_outline_size", 1)
	add_child(info_label)
	
	# Zoom indicator (top-right)
	zoom_label = Label.new()
	zoom_label.position = Vector2(size.x - 150, 10)
	zoom_label.size = Vector2(140, 30)
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	zoom_label.add_theme_color_override("font_color", Color.YELLOW)
	zoom_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	zoom_label.add_theme_constant_override("shadow_outline_size", 1)
	add_child(zoom_label)
	
	# Controls help (bottom-left)
	controls_label = Label.new()
	controls_label.position = Vector2(10, size.y - 160)  # Made more room
	controls_label.size = Vector2(300, 150)
	var control_text = "CONTROLS:\nMouse Wheel - Zoom\nMiddle Click + Drag - Pan\nLeft Click - Node Info\nL - Toggle Labels\nR - Reset View\nI - Toggle Info Panel"
	if OS.is_debug_build():
		control_text += "\nT - Debug Tooltip\nN - Count Nodes\nD - Full Debug"
	controls_label.text = control_text
	controls_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	controls_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	controls_label.add_theme_constant_override("shadow_outline_size", 1)
	add_child(controls_label)
	
	# Connect resize signal
	resized.connect(_on_resized)

func create_tooltip():
	"""Create the node tooltip label"""
	tooltip_label = Label.new()
	tooltip_label.visible = false
	tooltip_label.z_index = 100  # Make sure it's on top
	
	# Style the tooltip
	tooltip_label.add_theme_color_override("font_color", Color.WHITE)
	tooltip_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	tooltip_label.add_theme_constant_override("shadow_outline_size", 1)
	
	# Add background using StyleBoxFlat
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.9)  # Dark semi-transparent background
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color.CYAN
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	
	tooltip_label.add_theme_stylebox_override("normal", style_box)
	
	# Set font size
	tooltip_label.add_theme_font_size_override("font_size", 12)
	
	add_child(tooltip_label)
	print("Tooltip created")

func show_node_tooltip(node_data: Dictionary, screen_position: Vector2):
	"""Show tooltip with node information at specified position"""
	if node_data.is_empty():
		hide_node_tooltip()
		return
	
	current_tooltip_node = node_data
	tooltip_visible = true
	
	# Build tooltip text from node data (renamed to avoid shadowing)
	var node_info_text = "NODE ATTRIBUTES:\n"
	
	# Sort keys for consistent display
	var keys = node_data.keys()
	keys.sort()
	
	for key in keys:
		var value = node_data[key]
		# Format the value nicely
		var value_str = str(value)
		if value is float:
			# Round floats to 2 decimal places for cleaner display
			value_str = "%.2f" % value
		
		node_info_text += "%s: %s\n" % [key, value_str]
	
	tooltip_label.text = node_info_text
	
	# Position tooltip so its top-left corner is at the node center
	tooltip_label.position = screen_position
	tooltip_label.size = Vector2.ZERO  # Let it auto-size to content
	
	# Make sure tooltip stays within screen bounds
	await get_tree().process_frame  # Wait for size to update
	
	# Adjust position if tooltip would go off screen
	var tooltip_size = tooltip_label.get_theme_default_font().get_multiline_string_size(
		node_info_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12
	)
	
	# Add some padding to the calculated size
	tooltip_size += Vector2(16, 16)
	
	# Keep tooltip within screen bounds
	if tooltip_label.position.x + tooltip_size.x > size.x:
		tooltip_label.position.x = size.x - tooltip_size.x
	if tooltip_label.position.y + tooltip_size.y > size.y:
		tooltip_label.position.y = size.y - tooltip_size.y
	
	# Make sure it doesn't go off the top-left
	tooltip_label.position.x = max(0, tooltip_label.position.x)
	tooltip_label.position.y = max(0, tooltip_label.position.y)
	
	tooltip_label.visible = true
	# Force redraw to show highlighting
	queue_redraw()
	# Update info panel
	update_ui()
	print("Tooltip shown for node: ", node_data.get("Label", "Unknown"))

func hide_node_tooltip():
	"""Hide the node tooltip"""
	if tooltip_label:
		tooltip_label.visible = false
	tooltip_visible = false
	current_tooltip_node.clear()
	# Force redraw to remove highlighting
	queue_redraw()
	# Update info panel
	update_ui()
	print("Tooltip hidden")

func _on_resized():
	"""Handle window resize"""
	if zoom_label:
		zoom_label.position.x = size.x - 150
	if controls_label:
		controls_label.position.y = size.y - 160

func load_hyperspace_data():
	"""Load the CSV data"""
	data_parser = HyperspaceDataParser.new()
	
	# Build full paths
	var nodes_path = CSV_FOLDER_PATH + NODES_CSV_NAME
	var edges_path = CSV_FOLDER_PATH + EDGES_CSV_NAME
	
	print("Loading CSV files from:")
	print("  Nodes: ", nodes_path)
	print("  Edges: ", edges_path)
	
	# Try to load the CSV files
	var success = data_parser.load_csv_files(nodes_path, edges_path)
	
	if not success:
		print("❌ Failed to load CSV data")
		info_label.text = "ERROR: Failed to load CSV files\nExpected location: %s\nFiles: %s, %s" % [CSV_FOLDER_PATH, NODES_CSV_NAME, EDGES_CSV_NAME]
		return
	
	# Get the parsed data
	nodes_data = data_parser.nodes_data
	edges_data = data_parser.edges_data
	
	# Print some debug info
	data_parser.print_sample_data()
	
	print("✅ Data loaded successfully")

func setup_initial_view():
	"""Set up the initial view to show all nodes - FIXED: Account for Y-flip"""
	if nodes_data.is_empty():
		return
	
	# Calculate the bounds of our data
	var bounds = data_parser.coord_bounds
	
	# Create display area with some padding
	var padding = 100.0
	display_area = Rect2(
		-padding, -padding,
		bounds.width + padding * 2,
		bounds.height + padding * 2
	)
	
	# Center the map in the viewport
	var viewport_center = size / 2
	# FIXED: Account for Y-flip in center calculation
	var map_center = Vector2(bounds.min_x + bounds.width/2, -(bounds.min_y + bounds.height/2))
	
	# Calculate zoom to fit
	var zoom_x = (size.x - 200) / display_area.size.x  # Leave room for UI
	var zoom_y = (size.y - 200) / display_area.size.y
	zoom_level = min(zoom_x, zoom_y) * 0.8  # 80% to leave some margin
	
	# Set pan to center the map
	pan_offset = viewport_center - map_center * zoom_level
	
	update_ui()
	queue_redraw()

func _input(event):
	"""Handle input events"""
	if event is InputEventMouseButton:
		handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		handle_mouse_motion(event)
	elif event is InputEventKey:
		handle_key_input(event)

func handle_mouse_button(event: InputEventMouseButton):
	"""Handle mouse button events - ENHANCED with node clicking"""
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_at_point(event.position, 1.1)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_at_point(event.position, 0.9)
	elif event.button_index == MOUSE_BUTTON_MIDDLE:
		is_panning = event.pressed
		last_pan_position = event.position
	elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# NEW: Handle left click for node tooltips
		handle_left_click(event.position)

func handle_left_click(click_position: Vector2):
	"""Handle left mouse click - show node tooltip or hide if clicking empty space"""
	# Check if we clicked on a node
	var clicked_node = get_node_at_position(click_position)
	
	if not clicked_node.is_empty():
		# We clicked on a node - show its tooltip
		# Convert the world position back to screen coordinates for tooltip positioning
		var node_world_pos = Vector2(clicked_node.get("X", 0), clicked_node.get("Y", 0))
		var node_screen_pos = world_to_screen(node_world_pos)
		
		show_node_tooltip(clicked_node, node_screen_pos)
	else:
		# We clicked on empty space - hide tooltip if visible
		if tooltip_visible:
			hide_node_tooltip()

func handle_mouse_motion(event: InputEventMouseMotion):
	"""Handle mouse motion for panning"""
	if is_panning:
		pan_offset += event.position - last_pan_position
		last_pan_position = event.position
		queue_redraw()
		update_ui()

func handle_key_input(event: InputEventKey):
	"""Handle keyboard input"""
	if event.pressed:
		match event.keycode:
			KEY_L:
				show_labels = !show_labels
				print("Labels toggled: ", show_labels)
				queue_redraw()
			KEY_R:
				print("Resetting view...")
				reset_view()
			KEY_I:
				show_info_panel = !show_info_panel
				info_label.visible = show_info_panel
				print("Info panel toggled: ", show_info_panel)
			KEY_EQUAL, KEY_KP_ADD:
				zoom_at_point(size / 2, 1.2)
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom_at_point(size / 2, 0.8)
			KEY_ESCAPE:
				# ESC key also hides tooltip
				if tooltip_visible:
					hide_node_tooltip()
			KEY_T:
				# Debug key - print tooltip status
				if OS.is_debug_build():
					print("=== TOOLTIP DEBUG ===")
					print("Tooltip visible: ", tooltip_visible)
					print("Current tooltip node: ", current_tooltip_node)
					print("Total nodes: ", nodes_data.size())
					print("====================")
			KEY_N:
				# Debug key - count visible nodes
				if OS.is_debug_build():
					count_visible_nodes()

func zoom_at_point(screen_point: Vector2, zoom_factor: float):
	"""Zoom in/out at a specific screen point"""
	# Convert screen point to world coordinates
	var world_point = screen_to_world(screen_point)
	
	# Apply zoom
	zoom_level *= zoom_factor
	zoom_level = clamp(zoom_level, 0.01, 10.0)
	
	# Adjust pan to keep the world point under the screen point
	var new_screen_point = world_to_screen(world_point)
	pan_offset += screen_point - new_screen_point
	
	queue_redraw()
	update_ui()

func reset_view():
	"""Reset view to show all nodes"""
	print("Resetting view to show all nodes...")
	hide_node_tooltip()  # Clear any active tooltip
	setup_initial_view()

func screen_to_world(screen_pos: Vector2) -> Vector2:
	"""Convert screen coordinates to world coordinates - FIXED: Y-axis flip"""
	var world_pos = (screen_pos - pan_offset) / zoom_level
	# Flip the Y coordinate back when converting to world space
	return Vector2(world_pos.x, -world_pos.y)

func world_to_screen(world_pos: Vector2) -> Vector2:
	"""Convert world coordinates to screen coordinates - FIXED: Y-axis flip"""
	# Flip the Y coordinate to match Gephi's coordinate system
	var flipped_world_pos = Vector2(world_pos.x, -world_pos.y)
	return flipped_world_pos * zoom_level + pan_offset

func _draw():
	"""Draw the hyperspace map"""
	if nodes_data.is_empty():
		draw_string(get_theme_default_font(), Vector2(50, 50), "No data loaded", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.RED)
		return
	
	# Draw edges first (so they appear behind nodes)
	draw_edges()
	
	# Draw nodes
	draw_nodes()
	
	# Draw additional info if needed
	if show_labels:
		draw_node_labels()

func draw_edges():
	"""Draw all edges"""
	for edge in edges_data:
		var source_id = edge.get("Source", -1)
		var target_id = edge.get("Target", -1)
		
		if source_id == -1 or target_id == -1:
			continue
		
		var source_node = data_parser.get_node_by_id(source_id)
		var target_node = data_parser.get_node_by_id(target_id)
		
		if source_node.is_empty() or target_node.is_empty():
			continue
		
		# Get world positions
		var source_pos = Vector2(source_node.get("X", 0), source_node.get("Y", 0))
		var target_pos = Vector2(target_node.get("X", 0), target_node.get("Y", 0))
		
		# Convert to screen coordinates
		var screen_source = world_to_screen(source_pos)
		var screen_target = world_to_screen(target_pos)
		
		# Skip if both points are far off screen
		if not is_line_on_screen(screen_source, screen_target):
			continue
		
		# Get edge color based on safety
		var color = data_parser.get_edge_color(edge)
		color.a = 0.7  # Make edges slightly transparent
		
		# Draw the edge
		var width = edge_width * max(0.5, zoom_level)
		draw_line(screen_source, screen_target, color, width)

func draw_nodes():
	"""Draw all nodes - FIXED: Hubs now use circles, robust node rendering"""
	# Get selected node ID once for efficiency
	var selected_node_id = null
	if not current_tooltip_node.is_empty():
		selected_node_id = current_tooltip_node.get("Id", null)
	
	for node_index in range(nodes_data.size()):
		var node = nodes_data[node_index]
		
		# Get world position
		var world_x = node.get("X", 0.0)
		var world_y = node.get("Y", 0.0)
		var world_pos = Vector2(world_x, world_y)
		var screen_pos = world_to_screen(world_pos)
		
		# Calculate base radius first to use for culling
		var size_multiplier = float(node.get("Size", node_base_size)) / node_base_size
		var base_radius = node_base_size * size_multiplier * max(0.3, zoom_level)
		base_radius = max(2.0, base_radius)  # Minimum visible size
		
		# Check if selected
		var is_selected = false
		var node_id = node.get("Id", null)
		if selected_node_id != null and node_id != null:
			is_selected = (node_id == selected_node_id)
		
		# FIXED: Use consistent culling margin to prevent nodes from disappearing
		# when tooltip is hidden
		var culling_margin = 100.0  # Always use larger margin
		
		# Skip nodes that are far off screen (with appropriate margin)
		if not is_point_on_screen(screen_pos, culling_margin):
			continue
		
		# Get node visual properties
		var base_color = data_parser.get_node_color(node)
		var is_hub = node.get("ishub", false)
		var is_exceptional = node.get("isexceptional", false)
		
		# Calculate final visual properties
		var final_color = base_color
		var final_radius = base_radius
		
		# Apply selection highlighting
		if is_selected:
			final_color = Color.WHITE
			final_radius = base_radius * 1.3
		
		# Draw the node circle
		draw_circle(screen_pos, final_radius, final_color)
		
		# Draw borders based on node type
		var border_color = Color.GRAY
		var border_width = 1.0
		
		if is_hub:
			border_color = Color.WHITE
			border_width = 3.0
		elif is_exceptional:
			border_color = Color.WHITE
			border_width = 2.0
		
		# Draw border
		draw_arc(screen_pos, final_radius + 1, 0, TAU, 32, border_color, border_width)

func draw_node_labels():
	"""Draw node labels if enabled"""
	if zoom_level < 0.3:  # Don't draw labels when zoomed out too far
		return
	
	var font = get_theme_default_font()
	var font_size = 12
	
	for node in nodes_data:
		var world_pos = Vector2(node.get("X", 0), node.get("Y", 0))
		var screen_pos = world_to_screen(world_pos)
		
		if not is_point_on_screen(screen_pos, 20):
			continue
		
		var label = data_parser.get_node_display_name(node)
		var label_pos = screen_pos + Vector2(15, -5)  # Offset from node center
		
		# Draw label with background
		var text_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var bg_rect = Rect2(label_pos - Vector2(2, text_size.y + 2), text_size + Vector2(4, 4))
		draw_rect(bg_rect, Color(0, 0, 0, 0.7))
		draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func is_point_on_screen(point: Vector2, margin: float = 0) -> bool:
	"""Check if a point is visible on screen (with margin)"""
	return point.x >= -margin and point.x <= size.x + margin and \
		   point.y >= -margin and point.y <= size.y + margin

func is_line_on_screen(p1: Vector2, p2: Vector2, margin: float = 100) -> bool:
	"""Check if a line segment intersects with the screen"""
	var screen_rect = Rect2(-margin, -margin, size.x + margin * 2, size.y + margin * 2)
	
	# Simple check: if either point is on screen, draw the line
	return screen_rect.has_point(p1) or screen_rect.has_point(p2) or \
		   (p1.x < 0 and p2.x > size.x) or (p1.y < 0 and p2.y > size.y)

func update_ui():
	"""Update UI labels with current information"""
	if not info_label or not show_info_panel:
		return
	
	var stats = data_parser.get_stats() if data_parser else {"node_count": 0, "edge_count": 0}
	
	var info_text = "HYPERSPACE NETWORK TEST\n"
	info_text += "Nodes: %d\n" % stats.get("node_count", 0)
	info_text += "Edges: %d\n" % stats.get("edge_count", 0)
	info_text += "Zoom: %.2fx\n" % zoom_level
	info_text += "Pan: (%.0f, %.0f)" % [pan_offset.x, pan_offset.y]
	
	if tooltip_visible and not current_tooltip_node.is_empty():
		var node_label = current_tooltip_node.get("Label", "Unknown")
		var node_id = current_tooltip_node.get("Id", "?")
		info_text += "\nSelected: %s (ID: %s)" % [node_label, node_id]
	
	info_label.text = info_text
	
	if zoom_label:
		zoom_label.text = "Zoom: %.2fx" % zoom_level

func get_node_at_position(screen_pos: Vector2) -> Dictionary:
	"""Get the node at a given screen position (for mouse interactions) - ENHANCED"""
	var world_pos = screen_to_world(screen_pos)
	var min_distance = INF
	var closest_node = {}
	
	for node in nodes_data:
		var node_world_pos = Vector2(node.get("X", 0), node.get("Y", 0))
		var distance = world_pos.distance_to(node_world_pos)
		
		if distance < min_distance:
			min_distance = distance
			closest_node = node
	
	# Return closest node if it's within reasonable distance (considering zoom level)
	var size_multiplier = closest_node.get("Size", node_base_size) / node_base_size
	var threshold = (node_base_size * size_multiplier + 15) / zoom_level  # Slightly larger click area
	
	if min_distance <= threshold:
		return closest_node
	
	return {}

func count_visible_nodes():
	"""Debug function to count how many nodes are being rendered"""
	var visible_count = 0
	var total_count = nodes_data.size()
	var selected_node_id = null
	
	if not current_tooltip_node.is_empty():
		selected_node_id = current_tooltip_node.get("Id", null)
	
	for node in nodes_data:
		var world_pos = Vector2(node.get("X", 0.0), node.get("Y", 0.0))
		var screen_pos = world_to_screen(world_pos)
		
		# Use same culling margin as draw_nodes()
		var culling_margin = 100.0  # Consistent with drawing
		
		if is_point_on_screen(screen_pos, culling_margin):
			visible_count += 1
	
	print("=== NODE VISIBILITY DEBUG ===")
	print("Total nodes: ", total_count)
	print("Visible nodes: ", visible_count)
	print("Hidden nodes: ", total_count - visible_count)
	print("Selected node ID: ", selected_node_id)
	print("Culling margin: 100.0 (consistent)")
	print("Zoom level: ", zoom_level)
	print("Pan offset: ", pan_offset)
	print("==============================")

# Debug method
func _unhandled_key_input(event):
	"""Handle debug keys"""
	if event.pressed and event.keycode == KEY_D and OS.is_debug_build():
		# Print debug info
		print("=== DEBUG INFO ===")
		print("Zoom: ", zoom_level)
		print("Pan: ", pan_offset)
		print("Tooltip visible: ", tooltip_visible)
		if not current_tooltip_node.is_empty():
			print("Current tooltip node: ", current_tooltip_node.get("Label", "Unknown"))
		if data_parser:
			data_parser.print_sample_data()
		count_visible_nodes()
