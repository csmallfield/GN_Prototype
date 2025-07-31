# =============================================================================
# MISSION SELECTION UI - Interface for choosing cargo missions
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
	
	# Hide initially
	visible = false
	
	# Set process mode to work when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

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
	
	# Show interface
	visible = true
	get_tree().paused = true

func create_mission_list():
	"""Create clickable buttons for each available mission"""
	# Clear existing mission buttons
	for child in mission_list_container.get_children():
		child.queue_free()
	
	# Create mission buttons
	for i in range(available_missions.size()):
		var mission = available_missions[i]
		var mission_button = create_mission_button(mission, i)
		mission_list_container.add_child(mission_button)
	
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
		
		# Close mission selection interface
		hide_mission_selection()
	else:
		print("❌ Failed to accept mission")
		# Update details to show why it failed
		update_mission_details()

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

func _input(event):
	"""Handle input while mission selection is open"""
	if not visible:
		return
	
	# Close with Escape key
	if event.is_action_pressed("ui_cancel"):
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
