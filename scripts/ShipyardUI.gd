# =============================================================================
# SHIPYARD UI - Interface for purchasing ships with gamepad support
# =============================================================================
# ShipyardUI.gd
extends Control
class_name ShipyardUI

@onready var ship_list_container: VBoxContainer = $MainContainer/LeftPanel/ShipListContainer/ScrollContainer/ShipList
@onready var ship_image: TextureRect = $MainContainer/RightPanel/ShipImagePanel/ShipImage
@onready var ship_name_label: Label = $MainContainer/RightPanel/ShipDetailsPanel/ShipDetailsContainer/ShipNameLabel
@onready var ship_stats_label: Label = $MainContainer/RightPanel/ShipDetailsPanel/ShipDetailsContainer/ShipStatsLabel
@onready var purchase_button: Button = $MainContainer/RightPanel/ButtonPanel/ButtonContainer/PurchaseButton
@onready var back_button: Button = $MainContainer/RightPanel/ButtonPanel/ButtonContainer/BackButton

# Ship data
var available_ships: Array = []
var selected_ship_id: String = ""
var selected_ship_button: Button = null

# Planet info
var current_planet_data: Dictionary = {}
var current_system_id: String = ""

# Signals
signal ship_purchased(ship_data: Dictionary)
signal back_to_planet_requested

func _ready():
	# Connect button signals
	purchase_button.pressed.connect(_on_purchase_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	
	# Setup gamepad focus
	setup_gamepad_focus()
	
	# Hide initially
	visible = false
	
	# Set process mode to work when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup_gamepad_focus():
	"""Setup focus navigation for gamepad support"""
	# Enable focus on main buttons
	purchase_button.focus_mode = Control.FOCUS_ALL
	back_button.focus_mode = Control.FOCUS_ALL
	
	# Set up focus neighbors for main buttons
	purchase_button.focus_neighbor_bottom = purchase_button.get_path_to(back_button)
	back_button.focus_neighbor_top = back_button.get_path_to(purchase_button)

func setup_ship_list_focus():
	"""Setup focus for ship list buttons"""
	var ship_buttons = ship_list_container.get_children()
	
	for i in range(ship_buttons.size()):
		var button = ship_buttons[i]
		button.focus_mode = Control.FOCUS_ALL
		
		# Connect focus signals to update selection
		if not button.focus_entered.is_connected(_on_ship_focus_changed):
			button.focus_entered.connect(_on_ship_focus_changed.bind(button))
		
		# Set up vertical navigation
		if i > 0:
			button.focus_neighbor_top = button.get_path_to(ship_buttons[i-1])
		if i < ship_buttons.size() - 1:
			button.focus_neighbor_bottom = button.get_path_to(ship_buttons[i+1])
		
		# Set up horizontal navigation to right panel
		button.focus_neighbor_right = button.get_path_to(purchase_button)
	
	# Connect right panel back to ship list
	if ship_buttons.size() > 0:
		purchase_button.focus_neighbor_left = purchase_button.get_path_to(ship_buttons[0])
		back_button.focus_neighbor_left = back_button.get_path_to(ship_buttons[0])

func _on_ship_focus_changed(button: Button):
	"""Handle when a ship button gets focus"""
	# Find which ship this button represents
	var ship_buttons = ship_list_container.get_children()
	var button_index = ship_buttons.find(button)
	
	if button_index >= 0 and button_index < available_ships.size():
		var ship_id = available_ships[button_index]
		_on_ship_button_pressed(ship_id, button)

func show_shipyard(planet_data: Dictionary, system_id: String):
	"""Display the shipyard interface"""
	current_planet_data = planet_data
	current_system_id = system_id
	
	print("Showing shipyard for: ", planet_data.get("name", "Unknown Planet"))
	
	# Get available ships for this planet
	load_available_ships()
	
	# Clear previous selection
	selected_ship_id = ""
	selected_ship_button = null
	
	# Setup UI
	create_ship_list()
	update_ship_details()
	
	# Add controller hints
	if Input.get_connected_joypads().size() > 0:
		back_button.text = "Back to Planet (B)"
		purchase_button.text = "Purchase Ship (A)"
	
	# Show interface
	visible = true
	get_tree().paused = true
	
	# Grab focus for gamepad navigation
	await get_tree().process_frame  # Wait for buttons to be created
	var ship_buttons = ship_list_container.get_children()
	if ship_buttons.size() > 0:
		ship_buttons[0].grab_focus()

func load_available_ships():
	"""Load available ships for this planet from universe data or ShipManager"""
	available_ships.clear()
	
	# Check if this planet has a shipyard with specific ships
	var shipyard_data = current_planet_data.get("shipyard", {})
	var planet_ships = shipyard_data.get("available_ships", [])
	
	if planet_ships.size() > 0:
		# Use planet-specific ship list
		available_ships = planet_ships.duplicate()
		print("Loaded ", available_ships.size(), " ships from planet shipyard data")
	else:
		# Fallback to all ships
		available_ships = ShipManager.get_available_ships()
		print("Loaded ", available_ships.size(), " ships from ShipManager (no planet-specific data)")

func create_ship_list():
	"""Create clickable buttons for each available ship"""
	# Clear existing ship buttons
	for child in ship_list_container.get_children():
		child.queue_free()
	
	# Wait for buttons to be removed
	await get_tree().process_frame
	
	# Create ship buttons
	for i in range(available_ships.size()):
		var ship_id = available_ships[i]
		var ship_button = create_ship_button(ship_id, i)
		ship_list_container.add_child(ship_button)
	
	# Setup focus navigation for new buttons
	call_deferred("setup_ship_list_focus")
	
	print("Created ", available_ships.size(), " ship buttons")

func create_ship_button(ship_id: String, index: int) -> Button:
	"""Create a single ship button with thumbnail and basic info"""
	var button = Button.new()
	button.name = "ShipButton" + str(index)
	
	# Create a container for ship thumbnail and info
	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create thumbnail
	var thumbnail = TextureRect.new()
	thumbnail.custom_minimum_size = Vector2(80, 60)
	thumbnail.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Load thumbnail texture
	var thumbnail_path = ShipManager.get_ship_thumbnail_path(ship_id)
	var thumbnail_texture = load(thumbnail_path)
	if thumbnail_texture:
		thumbnail.texture = thumbnail_texture
	else:
		print("Could not load thumbnail: ", thumbnail_path)
	
	# Create text info
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var ship_data = ShipManager.get_ship_data(ship_id)
	var ship_name = ship_data.get("name", "Unknown Ship")
	var ship_cost = ShipManager.get_ship_cost(ship_id)
	var ship_class = ship_data.get("class", "Unknown Class")
	
	var name_label = Label.new()
	name_label.text = ship_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var info_label = Label.new()
	info_label.text = ship_class + "\n" + ShipManager.format_credits(ship_cost) + " credits"
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Check if this is the current ship
	if ship_id == ShipManager.current_ship_id:
		name_label.text += " (OWNED)"
		name_label.add_theme_color_override("font_color", Color.YELLOW)
		info_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		name_label.add_theme_color_override("font_color", Color.WHITE)
		info_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	
	# Assemble the button
	vbox.add_child(name_label)
	vbox.add_child(info_label)
	
	hbox.add_child(thumbnail)
	hbox.add_child(vbox)
	
	button.add_child(hbox)
	
	# Style the button
	button.custom_minimum_size = Vector2(0, 100)
	button.add_theme_color_override("font_color", Color.TRANSPARENT)  # Hide default button text
	
	# Connect button signal
	button.pressed.connect(_on_ship_button_pressed.bind(ship_id, button))
	
	return button

func _on_ship_button_pressed(ship_id: String, button: Button):
	"""Handle ship button press"""
	print("Ship selected: ", ship_id)
	
	# Update selection
	selected_ship_id = ship_id
	
	# Update button styling
	if selected_ship_button:
		# Reset previous selection styling - use modulate for visual feedback
		selected_ship_button.modulate = Color.WHITE
	
	# Highlight new selection
	selected_ship_button = button
	button.modulate = Color(1.2, 1.2, 0.8)  # Slight yellow tint
	
	# Update details panel
	update_ship_details()

func update_ship_details():
	"""Update the ship details panel"""
	if selected_ship_id == "":
		# No ship selected
		ship_name_label.text = "Select a ship to view details"
		ship_stats_label.text = ""
		ship_image.texture = null
		purchase_button.disabled = true
	else:
		# Show selected ship details
		var ship_data = ShipManager.get_ship_data(selected_ship_id)
		update_ship_display(ship_data)
		
		# Enable/disable purchase button
		var can_purchase = can_purchase_ship(selected_ship_id)
		purchase_button.disabled = not can_purchase

func update_ship_display(ship_data: Dictionary):
	"""Update the ship display with ship data"""
	var ship_name = ship_data.get("name", "Unknown Ship")
	var ship_cost = ShipManager.get_ship_cost(selected_ship_id)
	var trade_in_value = ShipManager.get_current_ship_trade_in_value()
	var net_cost = ShipManager.get_net_ship_cost(selected_ship_id)
	var stats = ship_data.get("stats", {})
	var description = ship_data.get("description", "No description available.")
	var flavor_text = ship_data.get("flavor_text", "")
	
	# Update ship name
	ship_name_label.text = ship_name
	
	# Load ship image
	var large_image_path = ShipManager.get_ship_large_view_path(selected_ship_id)
	var large_texture = load(large_image_path)
	if large_texture:
		ship_image.texture = large_texture
	else:
		print("Could not load large ship image: ", large_image_path)
		ship_image.texture = null
	
	# Create stats text
	var stats_text = description + "\n\n"
	
	# Add specifications
	stats_text += "═══ SPECIFICATIONS ═══\n"
	stats_text += "Thrust Power: " + str(stats.get("thrust_power", 0)) + "\n"
	stats_text += "Max Velocity: " + str(stats.get("max_velocity", 0)) + " m/s\n"
	stats_text += "Turn Rate: " + str(stats.get("rotation_speed", 0)) + "\n"
	stats_text += "Cargo Capacity: " + str(stats.get("cargo_capacity", 0)) + " tons\n\n"
	
	# Add pricing info
	stats_text += "═══ PRICING ═══\n"
	stats_text += "Ship Cost: " + ShipManager.format_credits(ship_cost) + " credits\n"
	
	if selected_ship_id != ShipManager.current_ship_id:
		stats_text += "Trade-in Value: " + ShipManager.format_credits(trade_in_value) + " credits\n"
		stats_text += "Net Cost: " + ShipManager.format_credits(net_cost) + " credits\n\n"
		
		# Current credits vs required
		var player_credits = PlayerData.get_credits()
		stats_text += "Your Credits: " + ShipManager.format_credits(player_credits) + "\n"
		
		if net_cost > player_credits:
			stats_text += "⚠ INSUFFICIENT FUNDS\n"
			stats_text += "Need: " + ShipManager.format_credits(net_cost - player_credits) + " more credits\n\n"
		else:
			stats_text += "✓ Can afford this ship\n\n"
	else:
		stats_text += "✓ YOU OWN THIS SHIP\n\n"
	
	# Add flavor text
	if flavor_text != "":
		stats_text += "═══ DESCRIPTION ═══\n"
		stats_text += flavor_text
	
	ship_stats_label.text = stats_text

func can_purchase_ship(ship_id: String) -> bool:
	"""Check if the player can purchase this ship"""
	if ship_id == ShipManager.current_ship_id:
		return false  # Already own this ship
	
	return ShipManager.can_afford_ship(ship_id)

func _on_purchase_button_pressed():
	"""Handle purchase button press"""
	if selected_ship_id == "":
		print("No ship selected")
		return
	
	if selected_ship_id == ShipManager.current_ship_id:
		print("Player already owns this ship")
		return
	
	print("Attempting to purchase ship: ", selected_ship_id)
	
	# Try to purchase ship through ShipManager
	if ShipManager.purchase_ship(selected_ship_id):
		print("✅ Ship purchased successfully!")
		
		# Show purchase confirmation
		show_purchase_confirmation()
		
		# Emit signal to notify planet UI
		var ship_data = ShipManager.get_ship_data(selected_ship_id)
		ship_purchased.emit(ship_data)
		
		# Refresh the shipyard interface to show new ownership
		refresh_shipyard_interface()
		
	else:
		print("❌ Failed to purchase ship")
		# Update details to show why it failed
		update_ship_details()

func show_purchase_confirmation():
	"""Show a purchase confirmation popup"""
	var ship_data = ShipManager.get_ship_data(selected_ship_id)
	var ship_name = ship_data.get("name", "Unknown Ship")
	
	# Create popup
	var popup = AcceptDialog.new()
	popup.title = "SHIP PURCHASED"
	popup.size = Vector2(500, 300)
	
	# Create custom content
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	
	# Header
	var header = Label.new()
	header.text = "✅ SHIP PURCHASE COMPLETE"
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
	details.text = "Congratulations on your new " + ship_name + "!\n\n"
	details.text += "Your ship has been delivered and is ready for flight.\n"
	details.text += "All cargo has been transferred to your new vessel."
	
	details.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	details.add_theme_font_size_override("font_size", 16)
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(details)
	
	# Add content to popup
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
	
	# Add to scene and show
	add_child(popup)
	popup.popup_centered()
	
	# Clean up when closed
	popup.confirmed.connect(func(): popup.queue_free())

func refresh_shipyard_interface():
	"""Refresh the shipyard interface after a purchase"""
	# Clear current selection
	selected_ship_id = ""
	selected_ship_button = null
	
	# Recreate the ship list to show new ownership
	create_ship_list()
	
	# Update the details panel
	update_ship_details()
	
	print("Shipyard interface refreshed")

func _on_back_button_pressed():
	"""Handle back button press"""
	print("Back to planet requested")
	back_to_planet_requested.emit()
	hide_shipyard()

func hide_shipyard():
	"""Hide the shipyard interface"""
	visible = false
	get_tree().paused = false
	
	# Clear selection data
	selected_ship_id = ""
	selected_ship_button = null
	available_ships.clear()
	
	# Clean up ship buttons
	for child in ship_list_container.get_children():
		child.queue_free()

func get_focused_control() -> Control:
	"""Get the currently focused control"""
	return get_viewport().gui_get_focus_owner()

func _input(event):
	"""Handle input while shipyard is open"""
	if not visible:
		return
	
	# Handle ui_accept (A button)
	if event.is_action_pressed("ui_accept"):
		var focused_control = get_focused_control()
		if focused_control:
			if focused_control == purchase_button:
				_on_purchase_button_pressed()
			elif focused_control == back_button:
				_on_back_button_pressed()
			elif focused_control in ship_list_container.get_children():
				# Pressing A on a ship button selects it and moves focus to purchase button
				if selected_ship_id != "":
					purchase_button.grab_focus()
		get_viewport().set_input_as_handled()
	
	# Close with Escape/B button
	elif event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
		get_viewport().set_input_as_handled()

# =============================================================================
# DEBUG METHODS
# =============================================================================

func debug_show_test_shipyard():
	"""Debug method to test the shipyard interface"""
	var test_planet = {
		"id": "earth",
		"name": "Earth",
		"shipyard": {
			"available_ships": ["scout_mk1", "cargo_hauler", "interceptor"]
		}
	}
	
	show_shipyard(test_planet, "sol_system")
