# =============================================================================
# PLANET LANDING UI - Interface for planet interactions
# =============================================================================
# PlanetLandingUI.gd
extends Control
class_name PlanetLandingUI

@onready var shipping_missions_button: Button = $MainContainer/RightPanel/ButtonPanel/ButtonContainer/ShippingMissionsButton
@onready var leave_planet_button: Button = $MainContainer/RightPanel/ButtonPanel/ButtonContainer/LeavePlanetButton
@onready var flavor_text_label: Label = $MainContainer/RightPanel/InfoPanel/InfoContainer/FlavorText
@onready var planet_name_label: Label = $MainContainer/RightPanel/InfoPanel/InfoContainer/PlanetName
@onready var planet_image: TextureRect = $MainContainer/LeftPanel/PlanetImage

# Current planet data
var current_planet_data: Dictionary = {}
var current_system_id: String = ""

# Signals for mission system integration
signal mission_interface_requested
signal landing_interface_closed

func _ready():
	# Connect button signals
	shipping_missions_button.pressed.connect(_on_shipping_missions_pressed)
	leave_planet_button.pressed.connect(_on_leave_planet_pressed)
	
	# Hide initially
	visible = false
	
	# Set process mode to work when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_landing_interface(planet_data: Dictionary, system_id: String):
	"""Display the landing interface for a specific planet"""
	current_planet_data = planet_data
	current_system_id = system_id
	
	print("Showing landing interface for: ", planet_data.get("name", "Unknown Planet"))
	
	# Load planet data
	setup_planet_display()
	
	# Check for deliveries first
	check_for_deliveries()
	
	# Show the interface
	visible = true
	get_tree().paused = true
	
	print("Landing interface displayed")

func setup_planet_display():
	"""Setup the visual elements of the landing interface"""
	var planet_name = current_planet_data.get("name", "Unknown Planet")
	var planet_id = current_planet_data.get("id", "unknown")
	
	# Set planet name
	planet_name_label.text = planet_name
	
	# Load planet surface image
	load_planet_surface_image(planet_id)
	
	# Set flavor text with player status
	set_planet_flavor_text_with_status()

func load_planet_surface_image(planet_id: String):
	"""Load the planet surface image with fallback"""
	var image_path = "res://sprites/planets/surfaces/" + planet_id + "_surface.png"
	var texture = load(image_path)
	
	if texture:
		planet_image.texture = texture
		print("Loaded surface image: ", image_path)
	else:
		# Try fallback default image
		var fallback_path = "res://sprites/planets/surfaces/default_surface.png"
		var fallback_texture = load(fallback_path)
		
		if fallback_texture:
			planet_image.texture = fallback_texture
			print("Using fallback surface image")
		else:
			print("No surface image found for: ", planet_id)
			# Create a simple colored background as ultimate fallback
			create_fallback_image()

func create_fallback_image():
	"""Create a simple fallback image if no surface image exists"""
	# Create a simple gradient or solid color as fallback
	var fallback_image = ImageTexture.new()
	var image = Image.create(600, 450, false, Image.FORMAT_RGB8)
	
	# Fill with a space-like gradient (dark blue to black)
	for y in range(450):
		for x in range(600):
			var color_intensity = 1.0 - (float(y) / 450.0)
			var color = Color(0.1 * color_intensity, 0.2 * color_intensity, 0.4 * color_intensity)
			image.set_pixel(x, y, color)
	
	fallback_image.set_image(image)
	planet_image.texture = fallback_image
	print("Created fallback gradient image")

func set_planet_flavor_text_with_status():
	"""Set the flavor text with player status information"""
	# Get planet flavor text
	var flavor_text = get_planet_flavor_text()
	
	# Add player status
	var credits = PlayerData.get_credits()
	var cargo_space = PlayerData.current_cargo_weight
	var cargo_capacity = PlayerData.cargo_capacity
	var active_missions = PlayerData.get_active_missions().size()
	
	var status_text = "\n\n═══ PILOT STATUS ═══\n"
	status_text += "Credits: %s\n" % MissionGenerator.format_credits(credits)
	status_text += "Cargo: %d/%d tons\n" % [cargo_space, cargo_capacity]
	status_text += "Active Missions: %d" % active_missions
	
	flavor_text_label.text = flavor_text + status_text

func get_planet_flavor_text() -> String:
	"""Get the flavor text for the planet"""
	var planet_id = current_planet_data.get("id", "")
	var _planet_name = current_planet_data.get("name", "Unknown Planet")
	
	# Try to get custom flavor text from planet data
	var flavor_text = current_planet_data.get("flavor_text", "")
	
	# If no custom flavor text, generate basic text based on planet type
	if flavor_text == "":
		flavor_text = generate_default_flavor_text()
	
	return flavor_text

func generate_default_flavor_text() -> String:
	"""Generate basic flavor text based on planet properties"""
	var planet_type = current_planet_data.get("type", "planet")
	var planet_name = current_planet_data.get("name", "this location")
	var population = current_planet_data.get("population", 0)
	var government = current_planet_data.get("government", "independent")
	var tech_level = current_planet_data.get("tech_level", 3)
	
	var text = ""
	
	# Basic description based on type
	match planet_type:
		"planet":
			text += planet_name + " is a planetary settlement"
		"station":
			text += planet_name + " is a space station"
		_:
			text += planet_name + " is a celestial body"
	
	# Add population info
	if population > 1000000000:
		text += " with billions of inhabitants"
	elif population > 1000000:
		text += " with millions of residents"  
	elif population > 10000:
		text += " with a modest population"
	else:
		text += " with a small community"
	
	# Add government info
	match government:
		"confederation":
			text += " under Confederation governance"
		"independent":
			text += " operating as an independent world"
		_:
			text += ""
	
	text += ". "
	
	# Add tech level description
	if tech_level >= 6:
		text += "Advanced technology and infrastructure make this a hub of innovation."
	elif tech_level >= 4:
		text += "Modern facilities and reliable technology serve the population well."
	elif tech_level >= 2:
		text += "Basic technology provides essential services to residents."
	else:
		text += "A frontier settlement with minimal technological infrastructure."
	
	return text

func check_for_deliveries():
	"""Check if player has deliveries for this planet and auto-complete them"""
	var planet_id = current_planet_data.get("id", "")
	var delivery_mission = PlayerData.has_active_mission_to_planet(planet_id, current_system_id)
	
	if not delivery_mission.is_empty():
		# Show delivery completion
		show_delivery_completion(delivery_mission)
		
		# Complete the mission
		var mission_id = delivery_mission.get("id", "")
		if mission_id != "":
			PlayerData.complete_mission(mission_id)

func show_delivery_completion(mission_data: Dictionary):
	"""Show a delivery completion popup"""
	var cargo_type = mission_data.get("cargo_type", "Unknown Cargo")
	var cargo_weight = mission_data.get("cargo_weight", 0)
	var payment = mission_data.get("payment", 0)
	
	# Create main popup
	var popup = AcceptDialog.new()
	popup.title = "DELIVERY COMPLETED"
	popup.size = Vector2(500, 300)
	
	# Create custom content
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	
	# Header
	var header = Label.new()
	header.text = "✅ SHIPMENT SUCCESSFULLY DELIVERED"
	header.add_theme_color_override("font_color", Color(0, 1, 0, 1))
	header.add_theme_font_size_override("font_size", 20)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)
	
	# Separator
	var separator = HSeparator.new()
	separator.add_theme_color_override("separator", Color(0, 0.8, 0, 1))
	vbox.add_child(separator)
	
	# Details
	var details = Label.new()
	var details_text = "Cargo: %s\n" % cargo_type
	details_text += "Weight: %d tons\n\n" % cargo_weight
	details_text += "Payment: %s credits\n\n" % MissionGenerator.format_credits(payment)
	details_text += "Credits have been transferred to your account."
	
	details.text = details_text
	details.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	details.add_theme_font_size_override("font_size", 16)
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(details)
	
	# Add content to popup
	popup.add_child(vbox)
	
	# Style the popup background
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0.1, 0, 0.95)  # Dark green background
	style_box.border_color = Color(0, 1, 0, 1)   # Green border
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	popup.add_theme_stylebox_override("panel", style_box)
	
	# Add to scene and show
	add_child(popup)
	popup.popup_centered()
	
	# Clean up when closed and refresh the planet display
	popup.confirmed.connect(func(): 
		popup.queue_free()
		# Refresh the planet display to show updated cargo/credits
		setup_planet_display()
	)
	
	print("🎉 DELIVERY COMPLETED: ", cargo_type, " - ", payment, " credits")

func _on_shipping_missions_pressed():
	"""Handle shipping missions button press"""
	print("Shipping Missions button pressed")
	
	# Get available missions for this planet
	var planet_id = current_planet_data.get("id", "")
	var missions = UniverseManager.get_missions_for_planet(planet_id)
	
	print("Found ", missions.size(), " missions for ", current_planet_data.get("name", "Unknown"))
	
	if missions.size() > 0:
		# Show mission selection interface
		show_mission_selection_interface(missions)
	else:
		print("No missions available at this location")
		# TODO: Could show a "No missions available" popup later

func show_mission_selection_interface(missions: Array[Dictionary]):
	"""Show the mission selection interface"""
	# Get or create the mission selection UI
	var ui_controller = get_parent()  # Should be UIController
	var mission_selection_ui = ui_controller.get_node_or_null("MissionSelectionUI")
	
	if not mission_selection_ui:
		# Create the mission selection UI
		var mission_ui_scene = load("res://scenes/MissionSelectionUI.tscn")
		if not mission_ui_scene:
			print("❌ Could not load MissionSelectionUI.tscn")
			return
		
		mission_selection_ui = mission_ui_scene.instantiate()
		mission_selection_ui.name = "MissionSelectionUI"
		ui_controller.add_child(mission_selection_ui)
		
		# Connect signals
		mission_selection_ui.mission_accepted.connect(_on_mission_accepted)
		mission_selection_ui.back_to_planet_requested.connect(_on_back_to_planet_requested)
		
		print("Created MissionSelectionUI")
	
	# Hide this interface temporarily
	visible = false
	
	# Show mission selection
	mission_selection_ui.show_mission_selection(current_planet_data, current_system_id, missions)

func _on_mission_accepted(mission_data: Dictionary):
	"""Handle mission acceptance from mission selection UI"""
	print("Mission accepted: ", mission_data.get("cargo_type", "Unknown"))
	
	# Show confirmation (for now just print, could add a nice popup later)
	var cargo_type = mission_data.get("cargo_type", "Unknown Cargo")
	var cargo_weight = mission_data.get("cargo_weight", 0)
	var _payment = mission_data.get("payment", 0)
	
	print("✅ MISSION ACCEPTED!")
	print("Cargo: ", cargo_type, " (", cargo_weight, " tons)")
	print("Current cargo space: ", PlayerData.current_cargo_weight, "/", PlayerData.cargo_capacity)
	
	# Refresh the planet display to show updated status
	setup_planet_display()
	
	# Return to planet interface
	visible = true

func _on_back_to_planet_requested():
	"""Handle return to planet from mission selection"""
	print("Returning to planet interface")
	visible = true

func _on_leave_planet_pressed():
	"""Handle leave planet button press"""
	print("Leave Planet button pressed")
	hide_landing_interface()

func hide_landing_interface():
	"""Hide the landing interface and return to game"""
	visible = false
	get_tree().paused = false
	landing_interface_closed.emit()
	print("Landing interface closed")

func _input(event):
	"""Handle input while landing interface is open"""
	if not visible:
		return
	
	# Close with Escape key
	if event.is_action_pressed("ui_cancel"):
		hide_landing_interface()
		get_viewport().set_input_as_handled()

# =============================================================================
# DEBUG METHODS
# =============================================================================

func debug_show_test_landing():
	"""Debug method to test the landing interface"""
	var test_planet = {
		"id": "earth",
		"name": "Earth", 
		"type": "planet",
		"population": 8000000000,
		"government": "confederation",
		"tech_level": 5
	}
	
	show_landing_interface(test_planet, "sol_system")
