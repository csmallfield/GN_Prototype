# =============================================================================
# COMBAT UI - Shield and Hull display (Static Test Version)
# =============================================================================
# CombatUI.gd
extends Control
class_name CombatUI

@onready var shield_bar: ProgressBar = $MainContainer/ShieldContainer/ShieldBar
@onready var hull_bar: ProgressBar = $MainContainer/HullContainer/HullBar
@onready var shield_label: Label = $MainContainer/ShieldContainer/ShieldLabel
@onready var hull_label: Label = $MainContainer/HullContainer/HullLabel

# Test values since PlayerShip doesn't have working combat stats yet
var test_shields: float = 50.0
var test_max_shields: float = 50.0
var test_hull: float = 100.0
var test_max_hull: float = 100.0

func _ready():
	# Style the progress bars
	setup_progress_bar_styles()
	
	# Show initial test values
	update_shield_display()
	update_hull_display()
	
	print("CombatUI: Using test values since PlayerShip combat isn't implemented yet")
	print("Test controls:")
	print("  1 - Damage shields")
	print("  2 - Damage hull") 
	print("  3 - Restore health")

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

#func _input(event):
	#"""Handle test input"""
	#if not OS.is_debug_build():
		#return
		
	#if event is InputEventKey and event.pressed:
		#match event.keycode:
			#KEY_1:
				#debug_damage_shields(15.0)
			#KEY_2:
				#debug_damage_hull(10.0)
			#KEY_3:
				#debug_restore_health()

func update_shield_display():
	"""Update the shield bar and label using test values"""
	if not shield_bar or not shield_label:
		return
	
	# Use test values
	var current_shields = test_shields
	var max_shields = test_max_shields
	
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
	"""Update the hull bar and label using test values"""
	if not hull_bar or not hull_label:
		return
	
	# Use test values
	var current_hull = test_hull
	var max_hull = test_max_hull
	
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

# Debug methods for testing the UI
func debug_damage_shields(amount: float = 10.0):
	"""Debug method to test shield damage on UI"""
	print("CombatUI Debug: Applying ", amount, " shield damage to test values")
	var old_shields = test_shields
	test_shields = max(0, test_shields - amount)
	print("Test Shields: ", old_shields, " -> ", test_shields)
	update_shield_display()

func debug_damage_hull(amount: float = 10.0):
	"""Debug method to test hull damage on UI"""
	print("CombatUI Debug: Applying ", amount, " hull damage to test values")
	var old_hull = test_hull
	test_hull = max(0, test_hull - amount)
	print("Test Hull: ", old_hull, " -> ", test_hull)
	update_hull_display()

func debug_restore_health():
	"""Debug method to restore full health to test values"""
	test_shields = test_max_shields
	test_hull = test_max_hull
	print("CombatUI Debug: Test health restored to full")
	update_shield_display()
	update_hull_display()
