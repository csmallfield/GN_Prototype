# =============================================================================
# PLANET LANDING UI - Interface for planet interactions
# =============================================================================
# PlanetLandingUI.gd
extends Control
class_name PlanetLandingUI

#@onready var planet_image = $MainContainer/LeftPanel/PlanetImage
#@onready var planet_name_label = $MainContainer/RightPanel/InfoPanel/InfoContainer/PlanetName
#@onready var flavor_text_label = $MainContainer/RightPanel/InfoPanel/InfoContainer/FlavorText
#@onready var shipping_missions_button = $MainContainer/RightPanel/ButtonPanel/ButtonContainer/ShippingMissionsButton
#@onready var leave_planet_button = $MainContainer/RightPanel/ButtonPanel/ButtonContainer/LeavePlanetButton
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
	
	# Set flavor text
	set_planet_flavor_text()

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

func set_planet_flavor_text():
	"""Set the flavor text for the planet"""
	var planet_id = current_planet_data.get("id", "")
	var planet_name = current_planet_data.get("name", "Unknown Planet")
	
	# Try to get custom flavor text from planet data
	var flavor_text = current_planet_data.get("flavor_text", "")
	
	# If no custom flavor text, generate basic text based on planet type
	if flavor_text == "":
		flavor_text = generate_default_flavor_text()
	
	flavor_text_label.text = flavor_text

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
	var payment = mission_data.get("payment", 0)
	
	# Create a simple notification (for now, just print - could be enhanced with a popup later)
	print("🎉 DELIVERY COMPLETED!")
	print("Cargo: ", cargo_type)
	print("Payment: ", payment, " credits")
	
	# TODO: Could add a nice popup animation here later

func _on_shipping_missions_pressed():
	"""Handle shipping missions button press"""
	print("Shipping Missions button pressed")
	
	# Get available missions for this planet
	var planet_id = current_planet_data.get("id", "")
	var missions = UniverseManager.get_missions_for_planet(planet_id)
	
	print("Found ", missions.size(), " missions for ", current_planet_data.get("name", "Unknown"))
	
	if missions.size() > 0:
		# Show mission selection interface (will be implemented next)
		show_mission_selection(missions)
	else:
		print("No missions available at this location")
		# Could show a "No missions available" popup

func show_mission_selection(missions: Array[Dictionary]):
	"""Show the mission selection interface (placeholder for now)"""
	print("=== AVAILABLE MISSIONS ===")
	for i in range(missions.size()):
		var mission = missions[i]
		print(i + 1, ". ", MissionGenerator.get_mission_description(mission))
	print("=== END MISSIONS ===")
	print("(Mission selection UI will be implemented next)")
	
	# Placeholder: Auto-accept first mission for testing
	if missions.size() > 0:
		var test_mission = missions[0]
		if PlayerData.accept_mission(test_mission):
			print("✅ Accepted mission: ", test_mission.get("cargo_type", "Unknown"))
		else:
			print("❌ Cannot accept mission (insufficient cargo space)")

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
