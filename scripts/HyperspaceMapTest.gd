# =============================================================================
# HYPERSPACE MAP TEST - Visual test for Gephi CSV data
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

func _ready():
	print("=== HYPERSPACE MAP TEST STARTING ===")
	
	# Set up the control
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Create UI elements
	create_ui_elements()
	
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
	controls_label.position = Vector2(10, size.y - 120)
	controls_label.size = Vector2(300, 110)
	controls_label.text = "CONTROLS:\nMouse Wheel - Zoom\nMiddle Click + Drag - Pan\nL - Toggle Labels\nR - Reset View\nI - Toggle Info Panel"
	controls_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	controls_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	controls_label.add_theme_constant_override("shadow_outline_size", 1)
	add_child(controls_label)
	
	# Connect resize signal
	resized.connect(_on_resized)

func _on_resized():
	"""Handle window resize"""
	if zoom_label:
		zoom_label.position.x = size.x - 150
	if controls_label:
		controls_label.position.y = size.y - 120

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
	"""Set up the initial view to show all nodes"""
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
	var map_center = Vector2(bounds.min_x + bounds.width/2, bounds.min_y + bounds.height/2)
	
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
	"""Handle mouse button events"""
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_at_point(event.position, 1.1)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_at_point(event.position, 0.9)
	elif event.button_index == MOUSE_BUTTON_MIDDLE:
		is_panning = event.pressed
		last_pan_position = event.position

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
				queue_redraw()
			KEY_R:
				reset_view()
			KEY_I:
				show_info_panel = !show_info_panel
				info_label.visible = show_info_panel
			KEY_EQUAL, KEY_KP_ADD:
				zoom_at_point(size / 2, 1.2)
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom_at_point(size / 2, 0.8)

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
	setup_initial_view()

func screen_to_world(screen_pos: Vector2) -> Vector2:
	"""Convert screen coordinates to world coordinates"""
	return (screen_pos - pan_offset) / zoom_level

func world_to_screen(world_pos: Vector2) -> Vector2:
	"""Convert world coordinates to screen coordinates"""
	return world_pos * zoom_level + pan_offset

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
	"""Draw all nodes"""
	for node in nodes_data:
		var world_pos = Vector2(node.get("X", 0), node.get("Y", 0))
		var screen_pos = world_to_screen(world_pos)
		
		# Skip nodes that are far off screen
		if not is_point_on_screen(screen_pos, 50):
			continue
		
		# Get node properties
		var color = data_parser.get_node_color(node)
		var size_multiplier = node.get("Size", node_base_size) / node_base_size
		var radius = node_base_size * size_multiplier * max(0.3, zoom_level)
		radius = max(2.0, radius)  # Minimum visible size
		
		# Special visual indicators
		var is_hub = node.get("ishub", false)
		var is_exceptional = node.get("isexceptional", false)
		
		# Draw node
		if is_hub:
			# Draw hubs as squares
			var rect = Rect2(screen_pos - Vector2(radius, radius), Vector2(radius * 2, radius * 2))
			draw_rect(rect, color)
			draw_rect(rect, Color.WHITE, false, 2.0)
		else:
			# Draw regular nodes as circles
			draw_circle(screen_pos, radius, color)
			if is_exceptional:
				draw_arc(screen_pos, radius + 2, 0, TAU, 32, Color.WHITE, 2.0)

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
	
	info_label.text = info_text
	
	if zoom_label:
		zoom_label.text = "Zoom: %.2fx" % zoom_level

func get_node_at_position(screen_pos: Vector2) -> Dictionary:
	"""Get the node at a given screen position (for future mouse interactions)"""
	var world_pos = screen_to_world(screen_pos)
	var min_distance = INF
	var closest_node = {}
	
	for node in nodes_data:
		var node_world_pos = Vector2(node.get("X", 0), node.get("Y", 0))
		var distance = world_pos.distance_to(node_world_pos)
		
		if distance < min_distance:
			min_distance = distance
			closest_node = node
	
	# Return closest node if it's within reasonable distance
	var size_multiplier = closest_node.get("Size", node_base_size) / node_base_size
	var threshold = (node_base_size * size_multiplier + 10) / zoom_level
	
	if min_distance <= threshold:
		return closest_node
	
	return {}

# Debug method
func _unhandled_key_input(event):
	"""Handle debug keys"""
	if event.pressed and event.keycode == KEY_D and OS.is_debug_build():
		# Print debug info
		print("=== DEBUG INFO ===")
		print("Zoom: ", zoom_level)
		print("Pan: ", pan_offset)
		if data_parser:
			data_parser.print_sample_data()
