# =============================================================================
# PLANET ANIMATION SET - Node for managing planet parameter animations
# =============================================================================
# PlanetAnimationSet.gd
extends Node
class_name PlanetAnimationSet

# Array of parameter animations for this planet
@export var parameter_animations: Array[ParameterAnimationData] = []

# Optional: Enable/disable all animations for this planet
@export var animations_enabled: bool = true

func _ready():
	# Add this node to the planet_animation_sets group for easy discovery
	add_to_group("planet_animation_sets")

# Get animation data in the format expected by PlanetAnimator
func get_animation_data() -> Dictionary:
	if not animations_enabled:
		return {}
	
	var animation_data = {}
	
	for param_anim in parameter_animations:
		if param_anim and param_anim.is_valid():
			animation_data[param_anim.parameter_name] = param_anim.to_dictionary()
		elif param_anim:
			push_warning("PlanetAnimationSet: Invalid parameter animation: " + str(param_anim.parameter_name))
	
	return animation_data

# Add a new parameter animation (useful for runtime or tool scripts)
func add_parameter_animation(param_name: String, anim_type: String, anim_rate: float, amplitude: float = 1.0, offset_x: float = 0.0, offset_y: float = 0.0):
	var new_anim = ParameterAnimationData.new(param_name, anim_type, anim_rate, amplitude, offset_x, offset_y)
	parameter_animations.append(new_anim)
	notify_property_list_changed()

# Remove parameter animation by name
func remove_parameter_animation(param_name: String) -> bool:
	for i in range(parameter_animations.size() - 1, -1, -1):
		if parameter_animations[i] and parameter_animations[i].parameter_name == param_name:
			parameter_animations.remove_at(i)
			notify_property_list_changed()
			return true
	return false

# Check if a parameter is being animated
func has_parameter_animation(param_name: String) -> bool:
	for param_anim in parameter_animations:
		if param_anim and param_anim.parameter_name == param_name:
			return true
	return false

# Get animation data for a specific parameter
func get_parameter_animation(param_name: String) -> ParameterAnimationData:
	for param_anim in parameter_animations:
		if param_anim and param_anim.parameter_name == param_name:
			return param_anim
	return null

# Get summary of all animations (useful for debugging)
func get_animation_summary() -> String:
	if not animations_enabled:
		return "Animations disabled"
	
	if parameter_animations.is_empty():
		return "No animations defined"
	
	var summary = "Animations (%d):\n" % parameter_animations.size()
	for param_anim in parameter_animations:
		if param_anim:
			summary += "  • %s\n" % param_anim.get_description()
	
	return summary.strip_edges()

# Clear all animations
func clear_animations():
	parameter_animations.clear()
	notify_property_list_changed()

# Duplicate this animation set (useful for copying between planets)
func duplicate_animation_set() -> PlanetAnimationSet:
	var new_set = PlanetAnimationSet.new()
	new_set.animations_enabled = animations_enabled
	
	for param_anim in parameter_animations:
		if param_anim:
			var duplicated_anim = param_anim.duplicate()
			new_set.parameter_animations.append(duplicated_anim)
	
	return new_set

# Debug print all animations
func debug_print_animations():
	print("=== Planet Animation Set Debug ===")
	print("Enabled: ", animations_enabled)
	print("Parameter count: ", parameter_animations.size())
	
	for i in range(parameter_animations.size()):
		var param_anim = parameter_animations[i]
		if param_anim:
			print("  [%d] %s" % [i, param_anim.get_description()])
			print("       Type: %s, Rate: %.3f, Amplitude: %.3f" % [param_anim.animation_type, param_anim.rate, param_anim.amplitude])
			if param_anim.animation_type == "circular":
				print("       Offset: (%.3f, %.3f)" % [param_anim.offset_x, param_anim.offset_y])
		else:
			print("  [%d] NULL animation" % i)
	
	print("Generated animation data:")
	var data = get_animation_data()
	for key in data.keys():
		print("  %s: %s" % [key, str(data[key])])
	print("===================================")

# EDITOR-ONLY FUNCTIONS
# Helper to quickly set up common animation patterns
func setup_rotating_planet(uv_rate: float = 0.01, cloud_rate: float = 0.015):
	if not Engine.is_editor_hint():
		return
	
	clear_animations()
	add_parameter_animation("uv_offset_x", "linear", uv_rate)
	add_parameter_animation("cloud_offset_x", "linear", cloud_rate)
	print("Set up rotating planet with UV rate: %.3f, Cloud rate: %.3f" % [uv_rate, cloud_rate])

func setup_pulsing_planet(rim_rate: float = 2.0, rim_amplitude: float = 0.2):
	if not Engine.is_editor_hint():
		return
	
	clear_animations()
	add_parameter_animation("rim_light_intensity", "sine", rim_rate, rim_amplitude)
	print("Set up pulsing planet with rim rate: %.3f, amplitude: %.3f" % [rim_rate, rim_amplitude])

func setup_dynamic_planet(uv_rate: float = 0.01, cloud_rate: float = 0.017, rim_rate: float = 3.0, rim_amplitude: float = 0.1):
	if not Engine.is_editor_hint():
		return
	
	clear_animations()
	add_parameter_animation("uv_offset_x", "linear", uv_rate)
	add_parameter_animation("cloud_offset_x", "linear", cloud_rate)
	add_parameter_animation("rim_light_intensity", "sine", rim_rate, rim_amplitude)
	print("Set up dynamic planet with multiple animations")
