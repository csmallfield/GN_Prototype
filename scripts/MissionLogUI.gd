# =============================================================================
# MISSION LOG UI - In-game mission tracking interface
# =============================================================================
# MissionLogUI.gd
extends Control
class_name MissionLogUI

#@onready var status_label: Label = $MainPanel/MainContainer/StatusLabel
#@onready var active_missions_list: VBoxContainer = $MainPanel/MainContainer/ActiveMissionsScroll/ActiveMissionsList
#@onready var completed_missions_list: VBoxContainer = $MainPanel/MainContainer/CompletedMissionsScroll/CompletedMissionsList
@onready var status_label: Label = $MainPanel/MainContainer/StatusLabel
@onready var active_missions_list: VBoxContainer = $MainPanel/MainContainer/ActiveMissionScroll/ActiveMissionsList
@onready var completed_missions_list: VBoxContainer = $MainPanel/MainContainer/CompletedMissionsScroll/CompletedMissionsList



# State management
var is_visible: bool = false

func _ready():
	# Hide initially
	visible = false
	
	# Set process mode to work when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Wait one frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Verify nodes are accessible
	if not status_label:
		status_label = get_node_or_null("MainPanel/MainContainer/StatusLabel")
	if not active_missions_list:
		active_missions_list = get_node_or_null("MainPanel/MainContainer/ActiveMissionsScroll/ActiveMissionsList")
	if not completed_missions_list:
		completed_missions_list = get_node_or_null("MainPanel/MainContainer/CompletedMissionsScroll/CompletedMissionsList")
	
	# Connect to PlayerData signals for automatic updates
	PlayerData.mission_accepted.connect(_on_mission_accepted)
	PlayerData.mission_completed.connect(_on_mission_completed)
	PlayerData.credits_changed.connect(_on_credits_changed)
	PlayerData.cargo_changed.connect(_on_cargo_changed)
	
	print("Mission Log UI initialized - Nodes ready: ", status_label != null, active_missions_list != null, completed_missions_list != null)

func _input(event):
	"""Handle mission log toggle input"""
	if event.is_action_pressed("mission_log"):
		toggle_mission_log()
		get_viewport().set_input_as_handled()
	elif is_visible and event.is_action_pressed("ui_cancel"):
		hide_mission_log()
		get_viewport().set_input_as_handled()

func toggle_mission_log():
	"""Toggle the mission log display"""
	if is_visible:
		hide_mission_log()
	else:
		show_mission_log()

func show_mission_log():
	"""Show the mission log interface"""
	print("Showing mission log")
	
	# Update all content
	update_status_display()
	update_mission_lists()
	
	# Show interface
	visible = true
	is_visible = true
	
	# Don't pause the game - this is meant to be usable while flying

func hide_mission_log():
	"""Hide the mission log interface"""
	print("Hiding mission log")
	visible = false
	is_visible = false

func update_status_display():
	"""Update the player status information"""
	var credits = PlayerData.get_credits()
	var current_cargo = PlayerData.current_cargo_weight
	var cargo_capacity = PlayerData.cargo_capacity
	
	var status_text = "Credits: %s | Cargo: %d/%d tons" % [
		MissionGenerator.format_credits(credits),
		current_cargo,
		cargo_capacity
	]
	
	status_label.text = status_text

func update_mission_lists():
	"""Update both active and completed mission lists"""
	update_active_missions()
	update_completed_missions()

func update_active_missions():
	"""Update the active missions list"""
	# Clear existing mission displays
	for child in active_missions_list.get_children():
		child.queue_free()
	
	var active_missions = PlayerData.get_active_missions()
	
	if active_missions.is_empty():
		# Show "no missions" message
		var no_missions_label = create_mission_label("No active missions", Color(0.6, 0.6, 0.6, 1.0))
		active_missions_list.add_child(no_missions_label)
	else:
		# Create mission displays
		for mission in active_missions:
			var mission_display = create_active_mission_display(mission)
			active_missions_list.add_child(mission_display)
	
	print("Updated active missions list: ", active_missions.size(), " missions")

func update_completed_missions():
	"""Update the completed missions list"""
	# Clear existing mission displays  
	for child in completed_missions_list.get_children():
		child.queue_free()
	
	var completed_missions = PlayerData.get_completed_missions()
	
	if completed_missions.is_empty():
		# Show "no missions" message
		var no_missions_label = create_mission_label("No completed missions", Color(0.6, 0.6, 0.6, 1.0))
		completed_missions_list.add_child(no_missions_label)
	else:
		# Show only the last 10 completed missions to avoid clutter
		var recent_missions = completed_missions.slice(max(0, completed_missions.size() - 10))
		
		for mission in recent_missions:
			var mission_display = create_completed_mission_display(mission)
			completed_missions_list.add_child(mission_display)
	
	print("Updated completed missions list: ", completed_missions.size(), " total (showing recent)")

func create_active_mission_display(mission_data: Dictionary) -> Control:
	"""Create a display for an active mission"""
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 3)
	
	# Mission summary
	var cargo_type = mission_data.get("cargo_type", "Unknown Cargo")
	var cargo_weight = mission_data.get("cargo_weight", 0)
	var destination_planet = mission_data.get("destination_planet_name", "Unknown")
	var destination_system = mission_data.get("destination_system_name", "Unknown System")
	var payment = mission_data.get("payment", 0)
	
	var summary_text = "▶ %d tons %s" % [cargo_weight, cargo_type]
	var summary_label = create_mission_label(summary_text, Color(1, 1, 1, 1))  # White for active
	container.add_child(summary_label)
	
	# Destination info
	var destination_text = "  → %s (%s)" % [destination_planet, destination_system]
	var destination_label = create_mission_label(destination_text, Color(0, 1, 0, 1))  # Green
	container.add_child(destination_label)
	
	# Payment info
	var payment_text = "  Payment: %s credits" % MissionGenerator.format_credits(payment)
	var payment_label = create_mission_label(payment_text, Color(0, 1, 1, 1))  # Cyan
	container.add_child(payment_label)
	
	return container

func create_completed_mission_display(mission_data: Dictionary) -> Control:
	"""Create a display for a completed mission"""
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	
	# Mission summary (grayed out)
	var cargo_type = mission_data.get("cargo_type", "Unknown Cargo")
	var cargo_weight = mission_data.get("cargo_weight", 0)
	var destination_planet = mission_data.get("destination_planet_name", "Unknown")
	var payment = mission_data.get("payment", 0)
	
	var summary_text = "✓ %d tons %s → %s (%s credits)" % [
		cargo_weight, 
		cargo_type, 
		destination_planet,
		MissionGenerator.format_credits(payment)
	]
	
	var summary_label = create_mission_label(summary_text, Color(0.7, 0.7, 0.7, 1))  # Gray for completed
	container.add_child(summary_label)
	
	return container

func create_mission_label(text: String, color: Color) -> Label:
	"""Create a styled label for mission information"""
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 14)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(350, 0)  # Ensure proper width for wrapping
	
	return label

# =============================================================================
# SIGNAL HANDLERS - Auto-update when missions change
# =============================================================================

func _on_mission_accepted(_mission_data: Dictionary):
	"""Called when a mission is accepted - update display if visible"""
	if is_visible:
		update_mission_lists()
		update_status_display()

func _on_mission_completed(_mission_data: Dictionary):
	"""Called when a mission is completed - update display if visible"""
	if is_visible:
		update_mission_lists()
		update_status_display()

func _on_credits_changed(_new_amount: int):
	"""Called when credits change - update status if visible"""
	if is_visible:
		update_status_display()

func _on_cargo_changed(_current_weight: int, _max_capacity: int):
	"""Called when cargo changes - update status if visible"""
	if is_visible:
		update_status_display()

# =============================================================================
# DEBUG METHODS
# =============================================================================

func debug_show_mission_log():
	"""Debug method to show mission log"""
	show_mission_log()

func debug_add_test_missions():
	"""Debug method to add test missions"""
	# Add some test active missions
	PlayerData.debug_add_test_mission()
	
	# Add a completed mission manually
	var completed_mission = {
		"id": "test_completed",
		"cargo_type": "Test Completed Cargo",
		"cargo_weight": 30,
		"destination_planet_name": "Test Planet",
		"destination_system_name": "Test System",
		"payment": 1500,
		"status": "completed"
	}
	PlayerData.completed_missions.append(completed_mission)
	
	# Update display if visible
	if is_visible:
		update_mission_lists()
