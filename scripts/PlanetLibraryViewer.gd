# =============================================================================
# PLANET LIBRARY VIEWER - Interactive preview system for planet animations
# =============================================================================
# PlanetLibraryViewer.gd
extends Node2D
class_name PlanetLibraryViewer

# Camera controls
@onready var camera: Camera2D
var is_dragging: bool = false
var drag_start_position: Vector2
var camera_start_position: Vector2

# Zoom settings
var zoom_min: float = 0.2
var zoom_max: float = 3.0
var zoom_step: float = 0.1
var zoom_smooth_speed: float = 10.0
var target_zoom: Vector2

# Pan settings
var pan_smooth_speed: float = 8.0
var target_position: Vector2

# Preview settings
var preview_active: bool = false
var planet_previews: Array[Dictionary] = []

# UI References
var ui_layer: CanvasLayer
var info_panel: Panel
var info_label: Label

func _ready():
	print("=== PLANET LIBRARY VIEWER STARTING ===")
	
	# Create camera if it doesn't exist
	setup_camera()
	
	# Create UI
	setup_ui()
	
	# Initialize preview system
	initialize_preview_system()
	
	# Start the preview
	start_preview()

func setup_camera():
	"""Setup the camera for navigation"""
	camera = Camera2D.new()
	camera.name = "ViewerCamera"
	add_child(camera)
	
	# Set initial zoom and position
	target_zoom = Vector2.ONE
	camera.zoom = target_zoom
	target_position = Vector2.ZERO
	camera.position = target_position
	
	# Enable camera processing
	camera.enabled = true
	
	print("Camera setup complete")

func setup_ui():
	"""Setup UI overlay for information display"""
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)
	
	# Create info panel
	info_panel = Panel.new()
	info_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	info_panel.size = Vector2(300, 200)
	info_panel.position = Vector2(10, 10)
	
	# Style the panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.8)
	style_box.border_color = Color(0, 1, 1, 1)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	info_panel.add_theme_stylebox_override("panel", style_box)
	
	ui_layer.add_child(info_panel)
	
	# Create info label
	info_label = Label.new()
	info_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info_label.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.text = "🌍 PLANET LIBRARY VIEWER\n\n🖱️ Controls:\n• Mouse Wheel: Zoom\n• Left Click + Drag: Pan\n• ESC: Exit\n\n📊 Loading planets..."
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	var margin = 10
	info_label.position = Vector2(margin, margin)
	info_label.size = info_panel.size - Vector2(margin * 2, margin * 2)
	
	info_panel.add_child(info_label)
	
	print("UI setup complete")

func initialize_preview_system():
	"""Initialize the planet preview system"""
	planet_previews.clear()
	
	var planet_count = 0
	var animated_count = 0
	
	# Process all planet nodes
	for child in get_children():
		if child.name.begins_with("planet_"):
			var planet_id = child.name.substr(7)
			
			# Get planet data
			var planet_data = PlanetLibraryLoader.get_planet_data(planet_id)
			
			# Create preview info
			var preview_info = {
				"node": child,
				"planet_id": planet_id,
				"material": planet_data.material,
				"animation_data": planet_data.animation_data,
				"has_animations": planet_data.has_animations,
				"animator": null,
				"original_position": child.position,
				"original_scale": child.scale
			}
			
			planet_previews.append(preview_info)
			planet_count += 1
			
			if planet_data.has_animations:
				animated_count += 1
			
			print("Initialized preview for: ", planet_id, " (animated: ", planet_data.has_animations, ")")
	
	print("Preview system initialized:")
	print("  • Total planets: ", planet_count)
	print("  • Animated planets: ", animated_count)
	
	# Update info label
	update_info_display()

func start_preview():
	"""Start the planet preview with animations"""
	print("Starting planet preview...")
	
	var started_animations = 0
	
	for preview_info in planet_previews:
		var planet_node = preview_info.node
		var planet_id = preview_info.planet_id
		var material = preview_info.material
		var animation_data = preview_info.animation_data
		
		# Apply the material
		if material and planet_node is ColorRect:
			planet_node.material = material.duplicate()
			print("Applied material to: ", planet_id)
		
		# Setup animations if available
		if not animation_data.is_empty():
			var animator = PlanetAnimator.new()
			animator.name = "PreviewAnimator_" + planet_id
			planet_node.add_child(animator)
			
			# Setup animations
			animator.setup_animations(planet_node.material, animation_data)
			
			# Store reference
			preview_info.animator = animator
			started_animations += 1
			
			print("Started animations for: ", planet_id, " (", animation_data.size(), " parameters)")
	
	preview_active = true
	print("Preview started with ", started_animations, " animated planets")
	
	# Final info update
	update_info_display()

func update_info_display():
	"""Update the information display"""
	if not info_label:
		return
	
	var info_text = "🌍 PLANET LIBRARY VIEWER\n\n"
	info_text += "🖱️ Controls:\n"
	info_text += "• Mouse Wheel: Zoom\n"
	info_text += "• Left Click + Drag: Pan\n"
	info_text += "• ESC: Exit Preview\n\n"
	
	info_text += "📊 Library Status:\n"
	info_text += "• Total Planets: %d\n" % planet_previews.size()
	
	var animated_count = 0
	var total_animations = 0
	for preview in planet_previews:
		if preview.has_animations:
			animated_count += 1
			total_animations += preview.animation_data.size()
	
	info_text += "• Animated Planets: %d\n" % animated_count
	info_text += "• Total Animations: %d\n\n" % total_animations
	
	info_text += "🎥 Preview: %s\n" % ("ACTIVE" if preview_active else "LOADING")
	
	info_text += "📸 Camera:\n"
	if camera:
		info_text += "• Zoom: %.1fx\n" % camera.zoom.x
		info_text += "• Position: (%.0f, %.0f)" % [camera.position.x, camera.position.y]
	
	info_label.text = info_text

func _input(event):
	"""Handle input for camera controls"""
	if not camera:
		return
	
	# Mouse wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drag(event.position)
			else:
				end_drag()
			get_viewport().set_input_as_handled()
	
	# Mouse drag
	elif event is InputEventMouseMotion and is_dragging:
		update_drag(event.position)
		get_viewport().set_input_as_handled()
	
	# Exit with escape
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			exit_preview()
			get_viewport().set_input_as_handled()

func zoom_in():
	"""Zoom camera in"""
	target_zoom = camera.zoom * (1.0 + zoom_step)
	target_zoom = target_zoom.clamp(Vector2(zoom_min, zoom_min), Vector2(zoom_max, zoom_max))

func zoom_out():
	"""Zoom camera out"""
	target_zoom = camera.zoom * (1.0 - zoom_step)
	target_zoom = target_zoom.clamp(Vector2(zoom_min, zoom_min), Vector2(zoom_max, zoom_max))

func start_drag(mouse_position: Vector2):
	"""Start camera dragging"""
	is_dragging = true
	drag_start_position = mouse_position
	camera_start_position = camera.position

func update_drag(mouse_position: Vector2):
	"""Update camera drag"""
	if not is_dragging:
		return
	
	var drag_delta = drag_start_position - mouse_position
	target_position = camera_start_position + drag_delta / camera.zoom.x

func end_drag():
	"""End camera dragging"""
	is_dragging = false

func _process(delta):
	"""Update camera smoothing and UI"""
	if not camera:
		return
	
	# Smooth zoom
	camera.zoom = camera.zoom.lerp(target_zoom, zoom_smooth_speed * delta)
	
	# Smooth panning
	camera.position = camera.position.lerp(target_position, pan_smooth_speed * delta)
	
	# Update info display periodically
	if Engine.get_process_frames() % 30 == 0:  # Every half second at 60fps
		update_info_display()

func exit_preview():
	"""Exit the preview and return to normal editing"""
	print("Exiting planet preview...")
	
	# Stop all animations
	stop_all_animations()
	
	# Get back to the editor
	if Engine.is_editor_hint():
		print("Returning to editor...")
	else:
		# If running as main scene, quit
		get_tree().quit()

func stop_all_animations():
	"""Stop all running animations"""
	for preview_info in planet_previews:
		if preview_info.animator:
			preview_info.animator.stop_animations()
			preview_info.animator.queue_free()
			preview_info.animator = null
	
	preview_active = false
	print("All animations stopped")

# Debug functions
func debug_print_preview_status():
	"""Print debug information about the preview system"""
	print("=== PREVIEW SYSTEM DEBUG ===")
	print("Preview active: ", preview_active)
	print("Planet previews: ", planet_previews.size())
	print("Camera zoom: ", camera.zoom if camera else "No camera")
	print("Camera position: ", camera.position if camera else "No camera")
	
	for i in range(planet_previews.size()):
		var preview = planet_previews[i]
		print("  [%d] %s - Animated: %s, Animator: %s" % [
			i, 
			preview.planet_id, 
			preview.has_animations,
			"Active" if preview.animator else "None"
		])
	
	print("=============================")

func reset_camera():
	"""Reset camera to default position and zoom"""
	target_zoom = Vector2.ONE
	target_position = Vector2.ZERO
	print("Camera reset to center")

func focus_on_planet(planet_id: String):
	"""Focus camera on a specific planet"""
	for preview_info in planet_previews:
		if preview_info.planet_id == planet_id:
			target_position = preview_info.original_position
			target_zoom = Vector2(1.5, 1.5)  # Zoom in a bit
			print("Focused on planet: ", planet_id)
			return
	
	print("Planet not found: ", planet_id)

# Cleanup
func _exit_tree():
	"""Cleanup when exiting"""
	stop_all_animations()
	print("Planet Library Viewer cleanup complete")
