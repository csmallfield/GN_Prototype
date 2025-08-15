# =============================================================================
# PLANET LANDING UI - Interface for planet interactions with gamepad support
# =============================================================================
# PlanetLandingUI.gd
extends Control
class_name PlanetLandingUI

@onready var shipping_missions_button: Button = $MainContainer/RightPanel/ButtonPanel/ButtonContainer/ShippingMissionsButton
@onready var shipyard_button: Button = $MainContainer/RightPanel/ButtonPanel/ButtonContainer/ShipyardButton
@onready var recharge_button: Button = $MainContainer/RightPanel/ButtonPanel/ButtonContainer/RechargeButton
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

# Input delay system to prevent instant button activation
var input_delay_timer: float = 0.0
var input_delay_duration: float = 0.5  # Increased to 0.5 seconds
var can_accept_input: bool = false

func _ready():
	# Connect button signals
	shipping_missions_button.pressed.connect(_on_shipping_missions_pressed)
	shipyard_button.pressed.connect(_on_shipyard_pressed)
	recharge_button.pressed.connect(_on_recharge_pressed)
	leave_planet_button.pressed.connect(_on_leave_planet_pressed)
	
	# Setup gamepad focus
	setup_gamepad_focus()
	
	# Hide initially
	visible = false
	
	# Set process mode to work when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta):
	"""Handle input delay timer"""
	if visible and not can_accept_input:
		input_delay_timer += delta
		if input_delay_timer >= input_delay_duration:
			can_accept_input = true

func setup_gamepad_focus():
	"""Setup focus navigation for gamepad support"""
	# Enable focus on buttons
	shipping_missions_button.focus_mode = Control.FOCUS_ALL
	shipyard_button.focus_mode = Control.FOCUS_ALL
	recharge_button.focus_mode = Control.FOCUS_ALL
	leave_planet_button.focus_mode = Control.FOCUS_ALL
	
	# Note: Actual focus neighbors are set up in setup_planet_services()
	# based on which services are available on the current planet

func show_landing_interface(planet_data: Dictionary, system_id: String):
	"""Display the landing interface for a specific planet"""
	current_planet_data = planet_data
	current_system_id = system_id
	
	print("Showing landing interface for: ", planet_data.get("name", "Unknown Planet"))
	
	# Reset input delay system
	input_delay_timer = 0.0
	can_accept_input = false
	
	# Load planet data
	setup_planet_display()
	
	# Setup available services (this will configure button visibility and focus)
	setup_planet_services()
	
	# Check for deliveries first
	check_for_deliveries()
	
	# Show the interface
	visible = true
	get_tree().paused = true
	
	# Grab focus for gamepad navigation (always start with missions button)
	shipping_missions_button.grab_focus()
	
	print("Landing interface displayed")

func setup_planet_services():
	"""Setup which services are available on this planet"""
	var services = current_planet_data.get("services", [])
	
	# Check service availability
	var has_shipyard = "shipyard" in services
	var has_recharge = "hyperspace_recharge" in services
	
	# Show/hide buttons based on availability
	shipyard_button.visible = has_shipyard
	shipyard_button.disabled = not has_shipyard
	
	recharge_button.visible = has_recharge
	recharge_button.disabled = not has_recharge
	
	# Build focus chain based on available services
	var available_buttons = [shipping_missions_button]  # Always available
	
	if has_shipyard:
		available_buttons.append(shipyard_button)
	
	if has_recharge:
		available_buttons.append(recharge_button)
	
	available_buttons.append(leave_planet_button)  # Always available
	
	# Setup focus chain
	for i in range(available_buttons.size()):
		var current_button = available_buttons[i]
		var next_button = available_buttons[(i + 1) % available_buttons.size()]
		var prev_button = available_buttons[(i - 1 + available_buttons.size()) % available_buttons.size()]
		
		current_button.focus_neighbor_bottom = current_button.get_path_to(next_button)
		current_button.focus_neighbor_top = current_button.get_path_to(prev_button)
	
	print("Services available: ", services)
	print("Shipyard: ", has_shipyard, " | Recharge: ", has_recharge)

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
	var current_jumps = PlayerData.get_current_jumps()
	var max_jumps = PlayerData.get_max_jumps()
	var active_missions = PlayerData.get_active_missions().size()
	
	var status_text = "\n\n═══ PILOT STATUS ═══\n"
	status_text += "Credits: %s\n" % MissionGenerator.format_credits(credits)
	status_text += "Cargo: %d/%d tons\n" % [cargo_space, cargo_capacity]
	status_text += "Hyperspace Jumps: %d/%d\n" % [current_jumps, max_jumps]
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
	
	# Completely hide this interface and disable input
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	
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
	
	# Don't return to planet interface here - stay in mission interface

func _on_back_to_planet_requested():
	"""Handle return to planet from mission selection"""
	print("Returning to planet interface")
	# Re-enable the planet menu
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Reset input delay to prevent immediate activation
	input_delay_timer = 0.0
	can_accept_input = false
	
	# Grab focus
	shipping_missions_button.grab_focus()

func _on_shipyard_pressed():
	"""Handle shipyard button press"""
	print("Shipyard button pressed")
	
	# Check if planet has shipyard
	var services = current_planet_data.get("services", [])
	if not "shipyard" in services:
		print("No shipyard available at this location")
		return
	
	# Show shipyard interface
	show_shipyard_interface()

func show_shipyard_interface():
	"""Show the shipyard interface"""
	# Get or create the shipyard UI
	var ui_controller = get_parent()  # Should be UIController
	var shipyard_ui = ui_controller.get_node_or_null("ShipyardUI")
	
	if not shipyard_ui:
		# Create the shipyard UI
		var shipyard_ui_scene = load("res://scenes/ShipyardUI.tscn")
		if not shipyard_ui_scene:
			print("❌ Could not load ShipyardUI.tscn")
			return
		
		shipyard_ui = shipyard_ui_scene.instantiate()
		shipyard_ui.name = "ShipyardUI"
		ui_controller.add_child(shipyard_ui)
		
		# Connect signals
		shipyard_ui.ship_purchased.connect(_on_ship_purchased)
		shipyard_ui.back_to_planet_requested.connect(_on_back_to_planet_requested)
		
		print("Created ShipyardUI")
	
	# Completely hide this interface and disable input
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	
	# Show shipyard
	shipyard_ui.show_shipyard(current_planet_data, current_system_id)

func _on_ship_purchased(ship_data: Dictionary):
	"""Handle ship purchase from shipyard UI"""
	print("Ship purchased: ", ship_data.get("name", "Unknown"))
	
	# Show confirmation
	var ship_name = ship_data.get("name", "Unknown Ship")
	
	print("✅ SHIP PURCHASED!")
	print("New ship: ", ship_name)
	print("Credits remaining: ", PlayerData.get_credits())
	
	# Refresh the planet display to show updated status
	setup_planet_display()

func _on_recharge_pressed():
	"""Handle hyperspace recharge button press"""
	print("Recharge button pressed")
	
	# Check if planet has recharge service
	var services = current_planet_data.get("services", [])
	if not "hyperspace_recharge" in services:
		print("No hyperspace recharge available at this location")
		return
	
	# Show recharge interface
	show_recharge_interface()

func show_recharge_interface():
	"""Show the hyperspace recharge interface"""
	var current_jumps = PlayerData.get_current_jumps()
	var max_jumps = PlayerData.get_max_jumps()
	var jumps_needed = PlayerData.get_jumps_needed_for_full()
	
	# Check if already at full capacity
	if jumps_needed <= 0:
		show_already_full_notification()
		return
	
	# Get recharge cost per jump (from system data or default)
	var cost_per_jump = get_recharge_cost_per_jump()
	var max_affordable_jumps = PlayerData.get_credits() / cost_per_jump
	var available_jumps_to_buy = min(jumps_needed, max_affordable_jumps)
	
	if available_jumps_to_buy <= 0:
		show_insufficient_credits_notification(cost_per_jump)
		return
	
	# Show recharge selection popup
	show_recharge_selection_popup(available_jumps_to_buy, cost_per_jump, jumps_needed)

func get_recharge_cost_per_jump() -> int:
	"""Get the cost per jump from system data or default"""
	var current_system = UniverseManager.get_current_system()
	var recharge_cost = current_system.get("hyperspace_recharge_cost", 200)
	return recharge_cost

func show_already_full_notification():
	"""Show notification when hyperspace drive is already full"""
	var popup = AcceptDialog.new()
	popup.title = "HYPERSPACE DRIVE STATUS"
	popup.size = Vector2(400, 200)
	
	var label = Label.new()
	label.text = "Your hyperspace drive is already at full capacity.\n\nJumps: %d/%d" % [PlayerData.get_current_jumps(), PlayerData.get_max_jumps()]
	label.add_theme_color_override("font_color", Color(0, 1, 0, 1))
	label.add_theme_font_size_override("font_size", 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	popup.add_child(label)
	add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(func(): popup.queue_free())

func show_insufficient_credits_notification(cost_per_jump: int):
	"""Show notification when player can't afford any jumps"""
	var popup = AcceptDialog.new()
	popup.title = "INSUFFICIENT CREDITS"
	popup.size = Vector2(450, 250)
	
	var label = Label.new()
	label.text = "You don't have enough credits to recharge your hyperspace drive.\n\n"
	label.text += "Cost per jump: %s credits\n" % MissionGenerator.format_credits(cost_per_jump)
	label.text += "Your credits: %s" % MissionGenerator.format_credits(PlayerData.get_credits())
	label.add_theme_color_override("font_color", Color(1, 0.5, 0, 1))
	label.add_theme_font_size_override("font_size", 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	popup.add_child(label)
	add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(func(): popup.queue_free())

func show_recharge_selection_popup(max_affordable: int, cost_per_jump: int, jumps_needed: int):
	"""Show popup for selecting how many jumps to recharge"""
	var popup = AcceptDialog.new()
	popup.title = "HYPERSPACE DRIVE RECHARGE"
	popup.size = Vector2(500, 400)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	
	# Header
	var header = Label.new()
	header.text = "⚡ HYPERSPACE DRIVE RECHARGE"
	header.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	header.add_theme_font_size_override("font_size", 20)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)
	
	# Status
	var status = Label.new()
	status.text = "Current Jumps: %d/%d\n" % [PlayerData.get_current_jumps(), PlayerData.get_max_jumps()]
	status.text += "Cost per Jump: %s credits" % MissionGenerator.format_credits(cost_per_jump)
	status.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	status.add_theme_font_size_override("font_size", 14)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status)
	
	# Recharge options
	var options_label = Label.new()
	options_label.text = "Select recharge amount:"
	options_label.add_theme_color_override("font_color", Color(0, 1, 0, 1))
	options_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(options_label)
	
	# Create buttons for different amounts
	var button_container = VBoxContainer.new()
	button_container.add_theme_constant_override("separation", 8)
	
	# Full recharge button (if possible)
	if jumps_needed <= max_affordable:
		var full_button = Button.new()
		var full_cost = jumps_needed * cost_per_jump
		full_button.text = "Full Recharge (%d jumps) - %s credits" % [jumps_needed, MissionGenerator.format_credits(full_cost)]
		full_button.add_theme_color_override("font_color", Color(0, 1, 0, 1))
		
		# Fixed: Capture variables by value using callable with bind
		full_button.pressed.connect(perform_recharge_and_close.bind(popup, jumps_needed, cost_per_jump))
		button_container.add_child(full_button)
	
	# Individual amount buttons
	for i in range(1, min(max_affordable + 1, jumps_needed + 1)):
		if i == jumps_needed and jumps_needed <= max_affordable:
			continue  # Skip if we already have a full button
		
		var amount_button = Button.new()
		var amount_cost = i * cost_per_jump
		var plural = "jump" if i == 1 else "jumps"
		amount_button.text = "%d %s - %s credits" % [i, plural, MissionGenerator.format_credits(amount_cost)]
		amount_button.add_theme_color_override("font_color", Color(0, 1, 1, 1))
		
		# Fixed: Capture variables by value using callable with bind
		amount_button.pressed.connect(perform_recharge_and_close.bind(popup, i, cost_per_jump))
		button_container.add_child(amount_button)
	
	vbox.add_child(button_container)
	
	# Cancel note
	var cancel_note = Label.new()
	cancel_note.text = "\nPress OK or ESC to cancel"
	cancel_note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	cancel_note.add_theme_font_size_override("font_size", 12)
	cancel_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cancel_note)
	
	popup.add_child(vbox)
	
	# Style the popup
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0.1, 0.1, 0.95)
	style_box.border_color = Color(0, 1, 1, 1)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	popup.add_theme_stylebox_override("panel", style_box)
	
	add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(func(): popup.queue_free())

func perform_recharge_and_close(popup: AcceptDialog, jumps: int, cost_per_jump: int):
	"""Helper function to perform recharge and close popup"""
	popup.queue_free()
	perform_recharge(jumps, cost_per_jump)

func perform_recharge(jumps: int, cost_per_jump: int):
	"""Perform the hyperspace recharge transaction"""
	var result = PlayerData.recharge_hyperspace_jumps(jumps, cost_per_jump)
	
	if result.success:
		show_recharge_success_popup(result)
		# Refresh the planet display to show updated status
		setup_planet_display()
	else:
		show_recharge_failure_popup(result.message)

func show_recharge_success_popup(result: Dictionary):
	"""Show success notification for recharge"""
	var popup = AcceptDialog.new()
	popup.title = "RECHARGE SUCCESSFUL"
	popup.size = Vector2(500, 300)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	
	# Header
	var header = Label.new()
	header.text = "✅ HYPERSPACE DRIVE RECHARGED"
	header.add_theme_color_override("font_color", Color(0, 1, 0, 1))
	header.add_theme_font_size_override("font_size", 20)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)
	
	# Details
	var details = Label.new()
	var jumps_recharged = result.get("jumps_recharged", 0)
	var cost_paid = result.get("cost_paid", 0)
	var current_jumps = result.get("current_jumps", 0)
	var max_jumps = result.get("max_jumps", 0)
	
	var plural = "jump" if jumps_recharged == 1 else "jumps"
	details.text = "Recharged: %d %s\n" % [jumps_recharged, plural]
	details.text += "Cost: %s credits\n\n" % MissionGenerator.format_credits(cost_paid)
	details.text += "Hyperspace Status: %d/%d jumps\n\n" % [current_jumps, max_jumps]
	details.text += "Your hyperspace drive is ready for travel!"
	
	details.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	details.add_theme_font_size_override("font_size", 16)
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(details)
	
	popup.add_child(vbox)
	
	# Style the popup
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0.1, 0, 0.95)
	style_box.border_color = Color(0, 1, 0, 1)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	popup.add_theme_stylebox_override("panel", style_box)
	
	add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(func(): popup.queue_free())
	
	print("✅ RECHARGE SUCCESSFUL: ", jumps_recharged, " jumps for ", cost_paid, " credits")

func show_recharge_failure_popup(message: String):
	"""Show failure notification for recharge"""
	var popup = AcceptDialog.new()
	popup.title = "RECHARGE FAILED"
	popup.size = Vector2(400, 200)
	
	var label = Label.new()
	label.text = "❌ " + message
	label.add_theme_color_override("font_color", Color(1, 0.5, 0, 1))
	label.add_theme_font_size_override("font_size", 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	popup.add_child(label)
	add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(func(): popup.queue_free())

func _on_leave_planet_pressed():
	"""Handle leave planet button press"""
	print("Leave Planet button pressed")
	hide_landing_interface()

func hide_landing_interface():
	"""Hide the landing interface and return to game"""
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # Reset process mode
	get_tree().paused = false
	
	# Refresh the player's interaction detection to ensure clean state
	var player_ship = UniverseManager.player_ship
	if player_ship and player_ship.has_method("refresh_interaction_detection"):
		player_ship.refresh_interaction_detection()
	
	# Clear any pending input to prevent issues
	get_viewport().set_input_as_handled()
	
	# Reset input delay system
	input_delay_timer = 0.0
	can_accept_input = false
	
	landing_interface_closed.emit()
	print("Landing interface closed")

func get_focused_control() -> Control:
	"""Get the currently focused control"""
	return get_viewport().gui_get_focus_owner()

func _input(event):
	"""Handle input while landing interface is open"""
	if not visible or not can_accept_input:
		return
	
	# Handle ui_accept (A button) for focused button
	if event.is_action_pressed("ui_accept"):
		var focused_control = get_focused_control()
		if focused_control:
			if focused_control == shipping_missions_button:
				_on_shipping_missions_pressed()
			elif focused_control == shipyard_button:
				_on_shipyard_pressed()
			elif focused_control == recharge_button:
				_on_recharge_pressed()
			elif focused_control == leave_planet_button:
				_on_leave_planet_pressed()
		get_viewport().set_input_as_handled()
	
	# Close with Escape/B button
	elif event.is_action_pressed("ui_cancel"):
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
		"tech_level": 5,
		"services": ["shipyard", "outfitter", "commodity_exchange", "mission_computer", "hyperspace_recharge"],
		"shipyard": {
			"available_ships": ["scout_mk1", "cargo_hauler", "interceptor"]
		}
	}
	
	show_landing_interface(test_planet, "sol_system")
