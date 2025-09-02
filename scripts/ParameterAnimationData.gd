# =============================================================================
# PARAMETER ANIMATION DATA - Resource for defining individual parameter animations
# =============================================================================
# ParameterAnimationData.gd
extends Resource
class_name ParameterAnimationData

# The name of the shader parameter to animate
@export var parameter_name: String = ""

# Animation type: linear, sine, cosine, pulse, circular
@export_enum("linear", "sine", "cosine", "pulse", "circular") var animation_type: String = "linear"

# Animation speed/frequency
@export var rate: float = 1.0

# Amplitude for oscillating animations (sine, cosine, pulse)
@export var amplitude: float = 1.0

# Offset values for circular animations or secondary components
@export var offset_x: float = 0.0
@export var offset_y: float = 0.0

func _init(param_name: String = "", anim_type: String = "linear", anim_rate: float = 1.0, anim_amplitude: float = 1.0, anim_offset_x: float = 0.0, anim_offset_y: float = 0.0):
	parameter_name = param_name
	animation_type = anim_type
	rate = anim_rate
	amplitude = anim_amplitude
	offset_x = anim_offset_x
	offset_y = anim_offset_y

# Convert to dictionary format that PlanetAnimator expects
func to_dictionary() -> Dictionary:
	return {
		"type": animation_type,
		"rate": rate,
		"amplitude": amplitude,
		"offset_x": offset_x,
		"offset_y": offset_y
	}

# Validate the parameter data
func is_valid() -> bool:
	if parameter_name == "":
		push_warning("ParameterAnimationData: parameter_name is empty")
		return false
	
	if animation_type not in ["linear", "sine", "cosine", "pulse", "circular"]:
		push_warning("ParameterAnimationData: invalid animation_type: " + animation_type)
		return false
	
	return true

# Get a user-friendly description for editor display
func get_description() -> String:
	return "%s (%s, rate: %.3f)" % [parameter_name, animation_type, rate]
