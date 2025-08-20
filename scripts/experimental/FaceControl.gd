@tool
extends TextureRect

# === FACIAL FEATURE PARAMETERS ===
@export_group("Eyes")
@export var eye_width: float = 1.0 : set = set_eye_width
@export var eye_height: float = 1.0 : set = set_eye_height
@export var eye_distance: float = 0.0 : set = set_eye_distance

@export_group("Mouth") 
@export var mouth_width: float = 1.0 : set = set_mouth_width
@export var mouth_height: float = 1.0 : set = set_mouth_height
@export var mouth_vertical_position: float = 0.0 : set = set_mouth_position

@export_group("Nose")
@export var nose_width: float = 1.0 : set = set_nose_width
@export var nose_length: float = 1.0 : set = set_nose_length

@export_group("Ears")
@export var ear_size: float = 1.0 : set = set_ear_size

# === CONTROL POINT POSITIONS ===
@export_group("Control Point Positions", "position_")
@export var position_left_eye: Vector2 = Vector2(0.35, 0.35) : set = set_left_eye_pos
@export var position_right_eye: Vector2 = Vector2(0.65, 0.35) : set = set_right_eye_pos
@export var position_mouth: Vector2 = Vector2(0.50, 0.70) : set = set_mouth_pos
@export var position_nose: Vector2 = Vector2(0.50, 0.55) : set = set_nose_pos
@export var position_left_ear: Vector2 = Vector2(0.10, 0.50) : set = set_left_ear_pos
@export var position_right_ear: Vector2 = Vector2(0.90, 0.50) : set = set_right_ear_pos

# === INNER RADIUS SETTINGS (Protected Areas) ===
@export_group("Protected Areas (Inner Radius)", "inner_")
@export var inner_eye_radius: float = 0.04 : set = set_inner_eye_radius
@export var inner_mouth_radius: float = 0.06 : set = set_inner_mouth_radius
@export var inner_nose_radius: float = 0.02 : set = set_inner_nose_radius
@export var inner_ear_radius: float = 0.02 : set = set_inner_ear_radius

# === OUTER RADIUS SETTINGS (Falloff Boundaries) ===
@export_group("Influence Areas (Outer Radius)", "outer_")
@export var outer_eye_radius: float = 0.12 : set = set_outer_eye_radius
@export var outer_mouth_radius: float = 0.16 : set = set_outer_mouth_radius
@export var outer_nose_radius: float = 0.08 : set = set_outer_nose_radius
@export var outer_ear_radius: float = 0.07 : set = set_outer_ear_radius

# === DEBUG AND UTILITY ===
@export_group("Debug")
@export var show_control_points: bool = true : set = set_show_points
@export var show_inner_areas: bool = true : set = set_show_inner
@export var show_outer_areas: bool = true : set = set_show_outer
@export var show_blend_weights: bool = false : set = set_show_blend_weights

@export_group("Utility")
@export var reset_all_parameters: bool = false : set = reset_parameters
@export var randomize_face: bool = false : set = randomize_parameters

var shader_material: ShaderMaterial

func _ready():
	if Engine.is_editor_hint():
		print("Advanced Face Controller ready!")
	
	shader_material = material as ShaderMaterial
	if not shader_material:
		print("ERROR: No shader material found. Apply the advanced face deformation shader first.")
		return
	else:
		print("SUCCESS: Shader material found")
	
	# Apply all current settings to shader
	update_all_parameters()

# === MAIN FEATURE CONTROLS ===

func set_eye_width(value: float):
	eye_width = value
	if shader_material:
		shader_material.set_shader_parameter("left_eye_scale", Vector2(value, eye_height))
		shader_material.set_shader_parameter("right_eye_scale", Vector2(value, eye_height))

func set_eye_height(value: float):
	eye_height = value
	if shader_material:
		shader_material.set_shader_parameter("left_eye_scale", Vector2(eye_width, value))
		shader_material.set_shader_parameter("right_eye_scale", Vector2(eye_width, value))

func set_eye_distance(value: float):
	eye_distance = value
	if shader_material:
		var offset = value * 0.05
		shader_material.set_shader_parameter("left_eye_translation", Vector2(-offset, 0.0))
		shader_material.set_shader_parameter("right_eye_translation", Vector2(offset, 0.0))

func set_mouth_width(value: float):
	mouth_width = value
	if shader_material:
		shader_material.set_shader_parameter("mouth_scale", Vector2(value, mouth_height))

func set_mouth_height(value: float):
	mouth_height = value
	if shader_material:
		shader_material.set_shader_parameter("mouth_scale", Vector2(mouth_width, value))

func set_mouth_position(value: float):
	mouth_vertical_position = value
	if shader_material:
		shader_material.set_shader_parameter("mouth_translation", Vector2(0.0, value * 0.05))

func set_nose_width(value: float):
	nose_width = value
	if shader_material:
		shader_material.set_shader_parameter("nose_scale", Vector2(value, nose_length))

func set_nose_length(value: float):
	nose_length = value
	if shader_material:
		shader_material.set_shader_parameter("nose_scale", Vector2(nose_width, value))

func set_ear_size(value: float):
	ear_size = value
	if shader_material:
		shader_material.set_shader_parameter("left_ear_scale", Vector2(value, value))
		shader_material.set_shader_parameter("right_ear_scale", Vector2(value, value))

# === CONTROL POINT POSITION SETTERS ===

func set_left_eye_pos(pos: Vector2):
	position_left_eye = pos
	if shader_material:
		shader_material.set_shader_parameter("left_eye_center", pos)

func set_right_eye_pos(pos: Vector2):
	position_right_eye = pos
	if shader_material:
		shader_material.set_shader_parameter("right_eye_center", pos)

func set_mouth_pos(pos: Vector2):
	position_mouth = pos
	if shader_material:
		shader_material.set_shader_parameter("mouth_center", pos)

func set_nose_pos(pos: Vector2):
	position_nose = pos
	if shader_material:
		shader_material.set_shader_parameter("nose_tip", pos)

func set_left_ear_pos(pos: Vector2):
	position_left_ear = pos
	if shader_material:
		shader_material.set_shader_parameter("left_ear", pos)

func set_right_ear_pos(pos: Vector2):
	position_right_ear = pos
	if shader_material:
		shader_material.set_shader_parameter("right_ear", pos)

# === INNER RADIUS SETTERS (Protected Areas) ===

func set_inner_eye_radius(value: float):
	inner_eye_radius = value
	if shader_material:
		shader_material.set_shader_parameter("eye_inner_radius", value)

func set_inner_mouth_radius(value: float):
	inner_mouth_radius = value
	if shader_material:
		shader_material.set_shader_parameter("mouth_inner_radius", value)

func set_inner_nose_radius(value: float):
	inner_nose_radius = value
	if shader_material:
		shader_material.set_shader_parameter("nose_inner_radius", value)

func set_inner_ear_radius(value: float):
	inner_ear_radius = value
	if shader_material:
		shader_material.set_shader_parameter("ear_inner_radius", value)

# === OUTER RADIUS SETTERS (Falloff Boundaries) ===

func set_outer_eye_radius(value: float):
	outer_eye_radius = value
	if shader_material:
		shader_material.set_shader_parameter("eye_outer_radius", value)

func set_outer_mouth_radius(value: float):
	outer_mouth_radius = value
	if shader_material:
		shader_material.set_shader_parameter("mouth_outer_radius", value)

func set_outer_nose_radius(value: float):
	outer_nose_radius = value
	if shader_material:
		shader_material.set_shader_parameter("nose_outer_radius", value)

func set_outer_ear_radius(value: float):
	outer_ear_radius = value
	if shader_material:
		shader_material.set_shader_parameter("ear_outer_radius", value)

# === DEBUG CONTROLS ===

func set_show_points(value: bool):
	show_control_points = value
	if shader_material:
		shader_material.set_shader_parameter("show_control_points", value)

func set_show_inner(value: bool):
	show_inner_areas = value
	if shader_material:
		shader_material.set_shader_parameter("show_inner_areas", value)

func set_show_outer(value: bool):
	show_outer_areas = value
	if shader_material:
		shader_material.set_shader_parameter("show_outer_areas", value)

func set_show_blend_weights(value: bool):
	show_blend_weights = value
	if shader_material:
		shader_material.set_shader_parameter("show_blend_weights", value)

# === UTILITY FUNCTIONS ===

func reset_parameters(value: bool):
	if value:
		print("Resetting all face parameters to defaults...")
		
		# Reset feature parameters
		eye_width = 1.0
		eye_height = 1.0
		eye_distance = 0.0
		mouth_width = 1.0
		mouth_height = 1.0
		mouth_vertical_position = 0.0
		nose_width = 1.0
		nose_length = 1.0
		ear_size = 1.0
		
		# Reset radius settings to defaults
		inner_eye_radius = 0.04
		inner_mouth_radius = 0.06
		inner_nose_radius = 0.02
		inner_ear_radius = 0.02
		
		outer_eye_radius = 0.12
		outer_mouth_radius = 0.16
		outer_nose_radius = 0.08
		outer_ear_radius = 0.07
		
		update_all_parameters()

func randomize_parameters(value: bool):
	if value:
		print("Randomizing face parameters...")
		
		eye_width = randf_range(0.7, 1.3)
		eye_height = randf_range(0.8, 1.2)
		eye_distance = randf_range(-0.5, 0.5)
		mouth_width = randf_range(0.7, 1.3)
		mouth_height = randf_range(0.8, 1.2)
		mouth_vertical_position = randf_range(-0.3, 0.3)
		nose_width = randf_range(0.8, 1.2)
		nose_length = randf_range(0.9, 1.1)
		ear_size = randf_range(0.8, 1.2)
		
		update_all_parameters()

func update_all_parameters():
	"""Apply all current parameter values to the shader"""
	# Feature parameters
	set_eye_width(eye_width)
	set_eye_height(eye_height)
	set_eye_distance(eye_distance)
	set_mouth_width(mouth_width)
	set_mouth_height(mouth_height)
	set_mouth_position(mouth_vertical_position)
	set_nose_width(nose_width)
	set_nose_length(nose_length)
	set_ear_size(ear_size)
	
	# Positions
	set_left_eye_pos(position_left_eye)
	set_right_eye_pos(position_right_eye)
	set_mouth_pos(position_mouth)
	set_nose_pos(position_nose)
	set_left_ear_pos(position_left_ear)
	set_right_ear_pos(position_right_ear)
	
	# Inner radii
	set_inner_eye_radius(inner_eye_radius)
	set_inner_mouth_radius(inner_mouth_radius)
	set_inner_nose_radius(inner_nose_radius)
	set_inner_ear_radius(inner_ear_radius)
	
	# Outer radii
	set_outer_eye_radius(outer_eye_radius)
	set_outer_mouth_radius(outer_mouth_radius)
	set_outer_nose_radius(outer_nose_radius)
	set_outer_ear_radius(outer_ear_radius)
	
	# Debug
	set_show_points(show_control_points)
	set_show_inner(show_inner_areas)
	set_show_outer(show_outer_areas)
	set_show_blend_weights(show_blend_weights)

# === HELPER FUNCTIONS FOR SETUP ===

func set_eye_protected_area(inner: float, outer: float):
	"""Convenience function to set both eye radii at once"""
	inner_eye_radius = inner
	outer_eye_radius = outer

func set_mouth_protected_area(inner: float, outer: float):
	"""Convenience function to set both mouth radii at once"""
	inner_mouth_radius = inner
	outer_mouth_radius = outer

# === PUBLIC API FOR GAME USE ===

func get_current_face_data() -> Dictionary:
	"""Get all current face parameters as a dictionary for saving/loading"""
	return {
		"eye_width": eye_width,
		"eye_height": eye_height,
		"eye_distance": eye_distance,
		"mouth_width": mouth_width,
		"mouth_height": mouth_height,
		"mouth_position": mouth_vertical_position,
		"nose_width": nose_width,
		"nose_length": nose_length,
		"ear_size": ear_size,
		"control_points": {
			"left_eye": position_left_eye,
			"right_eye": position_right_eye,
			"mouth": position_mouth,
			"nose": position_nose,
			"left_ear": position_left_ear,
			"right_ear": position_right_ear
		},
		"inner_radii": {
			"eye": inner_eye_radius,
			"mouth": inner_mouth_radius,
			"nose": inner_nose_radius,
			"ear": inner_ear_radius
		},
		"outer_radii": {
			"eye": outer_eye_radius,
			"mouth": outer_mouth_radius,
			"nose": outer_nose_radius,
			"ear": outer_ear_radius
		}
	}
