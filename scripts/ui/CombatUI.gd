# =============================================================================
# COMBAT UI - Shield and Hull display connected to PlayerShip
# =============================================================================
# CombatUI.gd
extends Control
class_name CombatUI

@onready var shield_bar: ProgressBar = $MainContainer/ShieldContainer/ShieldBar
@onready var hull_bar: ProgressBar = $MainContainer/HullContainer/HullBar
@onready var shield_label: Label = $MainContainer/ShieldContainer/ShieldLabel
@onready var hull_label: Label = $MainContainer/HullContainer/HullLabel

# Reference to player ship
var player_ship: Node2D = null

func _ready():
	# Style the progress bars
	setup_progress_bar_styles()
	
	# Get reference to player ship
	connect_to_player_ship()
	
	print("CombatUI: Connected to player ship combat system")

func _process(_delta):
	# Continuously update the UI to catch shield recharging and other changes
	if player_ship:
		update_shield_display()
		update_hull_display()

func connect_to_player_ship():
	"""Connect to the player ship and its combat system"""
	# Get player ship from UniverseManager
	player_ship = UniverseManager.player_ship
	
	if not player_ship:
		print("CombatUI: Player ship not found, will retry...")
		# Try again next frame if player ship isn't ready yet
		call_deferred("retry_connection")
		return
	
	# Connect to combat system signals if available
	var combat_system = player_ship.get_node_or_null("ShipCombatSystem")
	if combat_system:
		# Connect damage signals for immediate updates
		if not combat_system.hull_damaged.is_connected(_on_hull_damaged):
			combat_system.hull_damaged.connect(_on_hull_damaged)
		if not combat_system.shields_damaged.is_connected(_on_shields_damaged):
			combat_system.shields_damaged.connect(_on_shields_damaged)
		print("CombatUI: Connected to combat system signals")
	else:
		print("CombatUI: No combat system found, will use direct ship values")
	
	# Initialize display with current values
	update_shield_display()
	update_hull_display()

func retry_connection():
	"""Retry connecting to player ship if it wasn't available initially"""
	if not player_ship:
		connect_to_player_ship()

func setup_progress_bar_styles():
	"""Set up the visual styles for the progress bars"""
	# Shield bar styles
	var shield_fill = StyleBoxFlat.new()
	shield_fill.bg_color = Color.CYAN
	shield_bar.add_theme_stylebox_override("fill", shield_fill)
	
	# Hull bar styles  
	var hull_fill = StyleBoxFlat.new()
	hull_fill.bg_color = Color.GREEN
	hull_bar.add_theme_stylebox_override("fill", hull_fill)

func update_shield_display():
	"""Update the shield bar and label with current player ship values"""
	if not shield_bar or not shield_label or not player_ship:
		return
	
	# Get current values from player ship
	var current_shields = get_player_shields()
	var max_shields = get_player_max_shields()
	
	# Avoid division by zero
	if max_shields <= 0:
		max_shields = 1.0
	
	# Calculate percentage
	var shield_percent = (current_shields / max_shields) * 100.0
	shield_bar.value = shield_percent
	
	# Update label with actual values
	shield_label.text = "SHIELDS %d/%d" % [int(current_shields), int(max_shields)]
	
	# Change color based on shield level
	if shield_percent > 60:
		shield_label.add_theme_color_override("font_color", Color.CYAN)
	elif shield_percent > 30:
		shield_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		shield_label.add_theme_color_override("font_color", Color.ORANGE)

func update_hull_display():
	"""Update the hull bar and label with current player ship values"""
	if not hull_bar or not hull_label or not player_ship:
		return
	
	# Get current values from player ship
	var current_hull = get_player_hull()
	var max_hull = get_player_max_hull()
	
	# Avoid division by zero
	if max_hull <= 0:
		max_hull = 1.0
	
	# Calculate percentage
	var hull_percent = (current_hull / max_hull) * 100.0
	hull_bar.value = hull_percent
	
	# Update label with actual values
	hull_label.text = "HULL %d/%d" % [int(current_hull), int(max_hull)]
	
	# Change color based on hull level
	if hull_percent > 60:
		hull_label.add_theme_color_override("font_color", Color.GREEN)
	elif hull_percent > 30:
		hull_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		hull_label.add_theme_color_override("font_color", Color.RED)

func get_player_shields() -> float:
	"""Get current shield value from player ship"""
	if not player_ship:
		return 0.0
	
	# Read directly from PlayerShip properties (where damage is actually applied)
	if "shields" in player_ship:
		return player_ship.shields
	
	# Fallback to combat system if direct property doesn't exist
	var combat_system = player_ship.get_node_or_null("ShipCombatSystem")
	if combat_system and "current_shields" in combat_system:
		return combat_system.current_shields
	
	return 0.0

func get_player_max_shields() -> float:
	"""Get max shield value from player ship"""
	if not player_ship:
		return 1.0
	
	# Read directly from PlayerShip properties
	if "max_shields" in player_ship:
		return player_ship.max_shields
	
	# Fallback to combat system
	var combat_system = player_ship.get_node_or_null("ShipCombatSystem")
	if combat_system and "max_shields" in combat_system:
		return combat_system.max_shields
	
	return 1.0

func get_player_hull() -> float:
	"""Get current hull value from player ship"""
	if not player_ship:
		return 0.0
	
	# Read directly from PlayerShip properties (where damage is actually applied)
	if "hull" in player_ship:
		return player_ship.hull
	
	# Fallback to combat system
	var combat_system = player_ship.get_node_or_null("ShipCombatSystem")
	if combat_system and "current_hull" in combat_system:
		return combat_system.current_hull
	
	return 0.0

func get_player_max_hull() -> float:
	"""Get max hull value from player ship"""
	if not player_ship:
		return 1.0
	
	# Read directly from PlayerShip properties
	if "max_hull" in player_ship:
		return player_ship.max_hull
	
	# Fallback to combat system
	var combat_system = player_ship.get_node_or_null("ShipCombatSystem")
	if combat_system and "max_hull" in combat_system:
		return combat_system.max_hull
	
	return 1.0

# Signal handlers for immediate updates when damage occurs
func _on_hull_damaged(current_hull: float, max_hull: float):
	"""Called when player ship hull takes damage"""
	# The _process loop will handle the visual update
	pass

func _on_shields_damaged(current_shields: float, max_shields: float):
	"""Called when player ship shields take damage"""
	# The _process loop will handle the visual update
	pass
