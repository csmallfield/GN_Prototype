# =============================================================================
# UPDATED UI CONTROLLER - Scene Loading Version (Debug Code Removed)
# =============================================================================
# UIController.gd
extends Control

@onready var hyperspace_map = $HyperspaceMap
var minimap: Control
var combat_ui: CombatUI

func _ready():
	add_to_group("ui")
	setup_ui()
	create_minimap()
	create_combat_ui()

func setup_ui():
	# Hide map initially
	if hyperspace_map:
		hyperspace_map.visible = false
	
	# Make sure process mode allows UI to work when paused
	process_mode = Node.PROCESS_MODE_ALWAYS

func create_minimap():
	"""Create and position the minimap in the upper right corner"""
	var minimap_scene = preload("res://scenes/Minimap.tscn")
	minimap = minimap_scene.instantiate()
	
	# Position in upper right corner with some margin
	var margin = 20
	minimap.position = Vector2(
		get_viewport().size.x - minimap.custom_minimum_size.x - margin,
		margin
	)
	
	# Set anchor to top-right so it stays in corner on screen resize
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap.position.x -= minimap.custom_minimum_size.x + margin
	minimap.position.y += margin
	
	add_child(minimap)
	print("Minimap created and positioned")

func create_combat_ui():
	"""Load and create the combat UI from scene file"""
	var combat_ui_scene = preload("res://scenes/ui/CombatUI.tscn")
	if not combat_ui_scene:
		push_error("Could not load CombatUI.tscn - make sure the scene file exists!")
		return
	
	combat_ui = combat_ui_scene.instantiate()
	combat_ui.name = "CombatUI"
	
	add_child(combat_ui)
	print("Combat UI loaded from scene file")

func show_hyperspace_menu():
	"""Show the visual hyperspace map"""
	if hyperspace_map and hyperspace_map.has_method("show_map"):
		hyperspace_map.show_map()

func _input(event):
	if event.is_action_pressed("ui_cancel") and hyperspace_map and hyperspace_map.visible:
		hyperspace_map.hide_map()
		get_viewport().set_input_as_handled()

# Method to adjust minimap settings at runtime (for debugging/tuning)
func set_minimap_zoom(zoom: float):
	if minimap and minimap.has_method("set_zoom_scale"):
		minimap.set_zoom_scale(zoom)

func set_minimap_center_arrow_threshold(distance: float):
	if minimap and minimap.has_method("set_center_arrow_threshold"):
		minimap.set_center_arrow_threshold(distance)

# Method to access combat UI for other systems
func get_combat_ui() -> CombatUI:
	return combat_ui
