# =============================================================================
# MISSION SELECTION UI - Interface for choosing cargo missions with gamepad support
# =============================================================================
# MissionSelectionUI.gd
extends Control
class_name MissionSelectionUI

@onready var mission_list_container: VBoxContainer = $MainContainer/LeftPanel/MissionListContainer/ScrollContainer/MissionList
@onready var mission_details_text: Label = $MainContainer/RightPanel/MissionDetailsContainer/MissionDetailsText
@onready var accept_mission_button: Button = $MainContainer/RightPanel/MissionDetailsContainer/ButtonContainer/AcceptMissionButton
@onready var back_button: Button = $MainContainer/RightPanel/MissionDetailsContainer/ButtonContainer/BackButton

# Mission data
var available_missions: Array[Dictionary] = []
var selected_mission: Dictionary = {}
var selected_mission_button: Button = null

# Planet info
var current_planet_data: Dictionary = {}
var current_system_id: String = ""

# Signals
signal mission_accepted(mission_data: Dictionary)
signal back_to_planet_requested

func _ready():
	# Connect button signals
	accept_mission_button.pressed.connect(_on_accept_mission_pressed)
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
	accept_mission_button.focus_mode = Control.FOCUS_ALL
	back_button.focus_mode = Control.FOCUS_ALL
	
	# Set up focus neighbors for main buttons
	accept_mission_button.focus_neighbor_bottom = accept_mission_button.get_path_to(back_button)
	back_button.focus_neighbor_top = back_button.get_path_to(accept_mission_button)

func setup_mission_list_focus():
	"""Setup focus for mission list buttons"""
	var mission_buttons = mission_list_container.get_children()
	
	for i in range(mission_buttons.size()):
		var button = mission_buttons[i]
		button.focus_mode = Control.FOCUS_ALL
		
		# Connect focus signals to update selection
		if not button.focus_entered.is_connected(_on_mission_focus_changed):
			button.focus_entered.connect(_on_mission_focus_changed.bind(button))
		
		# Set up vertical navigation
		if i > 0:
			button.focus_neighbor_top = button.get_path_to(mission_buttons[i-1])
		if i < mission_buttons.size() - 1:
			button.focus_neighbor_bottom = button.get_path_to(mission_buttons[i+1])
		
		# Set up horizontal navigation to right panel
		button.focus_neighbor_right = button.get_path_to(accept_mission_button)
	
	# Connect right panel back to mission list
	if mission_buttons.size() > 0:
		accept_mission_button.focus_neighbor_left = accept_mission_button.get_path_to(mission_buttons[0])
		back_button.focus_neighbor_left = back_button.get_path_to(mission_buttons[0])

func _on_mission_focus_changed(button: Button):
	"""Handle when a mission button gets focus"""
	# Find which mission this button represents
	var mission_buttons = mission_list_container.get_children()
	var button_index = mission_buttons.find(button)
	
	if button_index >= 0 and button_index < available_missions.size():
		var mission_data = available_missions[button_index]
		_on_mission_button_pressed(mission_data, button)

func show_mission_selection(planet_data: Dictionary, system_id: String, missions: Array[Dictionary]):
	"""Display the mission selection interface"""
	current_planet_data = planet_data
	current_system_id = system_id
	available_missions = missions.duplicate()
	
	print("Showing mission selection for: ", planet_data.get("name", "Unknown Planet"))
	print("Available missions: ", missions.size())
	
	# Clear previous selection
	selected_mission = {}
	selected_mission_button = null
	
	# Setup UI
	create_mission_list()
	update_mission_details()
	
	# Add controller hints
	if Input.get_connected_joypads().size() > 0:
		back_button.text = "Back to Planet (B)"
		accept_mission_button.text = "Accept Mission (A)"
	
	# Show interface
	visible = true
	get_tree().paused = true
	
	# Grab focus for gamepad navigation
	await get_tree().process_frame  # Wait for buttons to be created
	var mission_buttons = mission_list_container.get_children()
	if mission_buttons.size() > 0:
		mission_buttons[0].grab_focus()

func create_mission_list():
	"""Create clickable buttons for each available mission"""
	# Clear existing mission buttons
	for child in mission_list_container.get_children():
		child.queue_free()
	
	# Wait for buttons to be removed
	await get_tree().process_frame
	
	# Create mission buttons
	for i in range(available_missions.size()):
		var mission = available_missions[i]
		var mission_button = create_mission_button(mission, i)
		mission_list_container.add_child(mission_button)
	
	# Setup focus navigation for new buttons
	call_deferred("setup_mission_list_focus")
	
	print("Created ", available_missions.size(), " mission buttons")

func create_mission_button(mission_data: Dictionary, index: int) -> Button:
	"""Create a single mission button"""
	var button = Button.new()
	button.name = "MissionButton" + str(index)
	
	# Set button text (summary of mission)
	var cargo_type = mission_data.get("cargo_type", "Unknown Cargo")
	var cargo_weight = mission_data.get("cargo_weight", 0)
	var destination_planet = mission_data.get("destination_planet_name", "Unknown")
	var payment = mission_data.get("payment", 0)
	
	var button_text = "%d tons %s → %s\n%s credits" % [cargo_weight, cargo_type, destination_planet, format_credits(payment)]
	button.text = button_text
	
	# Style the button using Godot 4.4 methods
	button.add_theme_color_override("font_color", Color(0, 1, 0, 1))  # Green text
	button.add_theme_font_size_override("font_size", 14)
	button.custom_minimum_size = Vector2(0, 80)  # Minimum height for multi-line text
	
	# Connect button signal
	button.pressed.connect(_on_mission_button_pressed.bind(mission_data, button))
	
	return button

func _on_mission_button_pressed(mission_data: Dictionary, button: Button):
	"""Handle mission button press"""
	print("Mission selected: ", mission_data.get("cargo_type", "Unknown"))
	
	# Update selection
	selected_mission = mission_data
	
	# Update button styling using Godot 4.4 methods
	if selected_mission_button:
		# Reset previous selection styling
		selected_mission_button.add_theme_color_override("font_color", Color(0, 1, 0, 1))  # Green
	
	# Highlight new selection
	selected_mission_button = button
	button.add_theme_color_override("font_color", Color(1, 1, 0, 1))  # Yellow
	
	# Update details panel
	update_mission_details()

func update_mission_details():
	"""Update the mission details panel"""
	if selected_mission.is_empty():
		# No mission selected
		mission_details_text.text = "Select a mission to view details"
		accept_mission_button.disabled = true
	else:
		# Show selected mission details
		var details_text = generate_mission_details_text(selected_mission)
		mission_details_text.text = details_text
		
		# Enable accept button if player has cargo space
		var cargo_weight = selected_mission.get("cargo_weight", 0)
		var can_accept = PlayerData.can_accept_cargo(cargo_weight)
		accept_mission_button.disabled = not can_accept
		
		if not can_accept:
			var available_space = PlayerData.get_available_cargo_space()
			mission_details_text.text += "\n\n⚠ INSUFFICIENT CARGO SPACE\nRequired: %d tons\nAvailable: %d tons" % [cargo_weight, available_space]

func generate_mission_details_text(mission_data: Dictionary) -> String:
	"""Generate detailed mission description"""
	var cargo_type = mission_data.get("cargo_type", "Unknown Cargo")
	var cargo_weight = mission_data.get("cargo_weight", 0)
	var destination_planet = mission_data.get("destination_planet_name", "Unknown Planet")
	var destination_system = mission_data.get("destination_system_name", "Unknown System")
	var payment = mission_data.get("payment", 0)
	var jump_distance = mission_data.get("jump_distance", 0)
	
	var details = "CARGO DELIVERY CONTRACT\n\n"
	details += "Cargo: %s\n" % cargo_type  
	details += "Weight: %d tons\n\n" % cargo_weight
	details += "Destination: %s\n" % destination_planet
	details += "System: %s\n\n" % destination_system
	details += "Distance: %d hyperspace jump%s\n\n" % [jump_distance, "s" if jump_distance != 1 else ""]
	details += "Payment: %s credits\n\n" % format_credits(payment)
	
	# Add cargo space info
	var current_cargo = PlayerData.current_cargo_weight
	var cargo_capacity = PlayerData.cargo_capacity
	var available_space = PlayerData.get_available_cargo_space()
	
	details += "CARGO BAY STATUS\n"
	details += "Current: %d/%d tons\n" % [current_cargo, cargo_capacity]
	details += "Available: %d tons" % available_space
	
	return details

func format_credits(amount: int) -> String:
	"""Format credit amounts with commas"""
	return MissionGenerator.format_credits(amount)

func _on_accept_mission_pressed():
	"""Handle accept mission button press"""
	if selected_mission.is_empty():
		print("No mission selected")
		return
	
	print("Attempting to accept mission...")
	
	# Try to accept mission through PlayerData
	if PlayerData.accept_mission(selected_mission):
		print("✅ Mission accepted successfully!")
		
		# Emit signal to notify planet UI
		mission_accepted.emit(selected_mission)
		
		# Remove the accepted mission from available missions
		remove_accepted_mission_from_list()
		
		# Refresh the mission list and clear selection
		refresh_mission_interface()
		
		# Keep focus in the mission menu after accepting
		await get_tree().process_frame
		var mission_buttons = mission_list_container.get_children()
		if mission_buttons.size() > 0:
			mission_buttons[0].grab_focus()
		else:
			# No more missions, focus on back button
			back_button.grab_focus()
		
	else:
		print("❌ Failed to accept mission")
		# Update details to show why it failed
		update_mission_details()

func remove_accepted_mission_from_list():
	"""Remove the accepted mission from the available missions array"""
	for i in range(available_missions.size() - 1, -1, -1):
		var mission = available_missions[i]
		# Compare missions by their key properties to find the match
		if (mission.get("cargo_type") == selected_mission.get("cargo_type") and
			mission.get("cargo_weight") == selected_mission.get("cargo_weight") and
			mission.get("destination_planet") == selected_mission.get("destination_planet") and
			mission.get("destination_system") == selected_mission.get("destination_system") and
			mission.get("payment") == selected_mission.get("payment")):
			
			available_missions.remove_at(i)
			print("Removed accepted mission from available list")
			break

func refresh_mission_interface():
	"""Refresh the mission list and clear selection after accepting a mission"""
	# Clear current selection
	selected_mission = {}
	selected_mission_button = null
	
	# Recreate the mission list
	create_mission_list()
	
	# Update the details panel
	update_mission_details()
	
	print("Mission interface refreshed - ", available_missions.size(), " missions remaining")

func _on_back_button_pressed():
	"""Handle back button press"""
	print("Back to planet requested")
	back_to_planet_requested.emit()
	hide_mission_selection()

func hide_mission_selection():
	"""Hide the mission selection interface"""
	visible = false
	get_tree().paused = false
	
	# Clear selection data
	selected_mission = {}
	selected_mission_button = null
	available_missions.clear()
	
	# Clean up mission buttons
	for child in mission_list_container.get_children():
		child.queue_free()

func get_focused_control() -> Control:
	"""Get the currently focused control"""
	return get_viewport().gui_get_focus_owner()

func _input(event):
	"""Handle input while mission selection is open"""
	if not visible:
		return
	
	# Handle ui_accept (A button)
	if event.is_action_pressed("ui_accept"):
		var focused_control = get_focused_control()
		if focused_control:
			if focused_control == accept_mission_button:
				_on_accept_mission_pressed()
			elif focused_control == back_button:
				_on_back_button_pressed()
			elif focused_control in mission_list_container.get_children():
				# Pressing A on a mission button selects it and moves focus to accept button
				if not selected_mission.is_empty():
					accept_mission_button.grab_focus()
		get_viewport().set_input_as_handled()
	
	# Close with Escape/B button  
	elif event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
		get_viewport().set_input_as_handled()

# =============================================================================
# DEBUG METHODS
# =============================================================================

func debug_show_test_missions():
	"""Debug method to test mission selection interface"""
	var test_planet = {
		"id": "earth",
		"name": "Earth"
	}
	
	var test_missions = MissionGenerator.debug_generate_test_missions()
	show_mission_selection(test_planet, "sol_system", test_missions)
