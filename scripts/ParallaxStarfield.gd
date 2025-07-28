# =============================================================================
# PARALLAX STARFIELD - Manages layered star backgrounds with simplified JSON control
# =============================================================================
# ParallaxStarfield.gd
extends Node
class_name ParallaxStarfield

# Get references to your existing Parallax2D nodes
@onready var base_color_parallax = $BaseColor
@onready var base_color_rect = $BaseColor/BaseColor
@onready var star_layers = [
	$StarLayer4,
	$StarLayer3, 
	$StarLayer2,
	$StarLayer1
]

var star_rects: Array[ColorRect] = []
var starfield_shader: Shader

# Default layer configurations - will be overridden by reading from scene
var default_layer_configs = []
var original_scene_configs = []  # Store the original scene values

func _ready():
	print("=== PARALLAX STARFIELD SCRIPT LOADED ===")
	print("Script path: ", get_script().resource_path if get_script() else "No script")
	print("Node name: ", name)
	print("Node type: ", get_class())
	
	print("ParallaxStarfield _ready() called")
	
	# Load the shader
	starfield_shader = load("res://shaders/StarfieldShader.gdshader")
	if not starfield_shader:
		push_error("Could not load StarfieldShader.gdshader")
		return
	else:
		print("Loaded starfield shader successfully")
	
	# Read existing scene configurations FIRST
	read_existing_scene_configs()
	
	# Setup background
	setup_background()
	
	print("ParallaxStarfield initialized with ", star_layers.size(), " star layers")
	print("Base color parallax: ", base_color_parallax)
	print("Original scene configs read: ", original_scene_configs.size())
	print("=== END PARALLAX STARFIELD INIT ===")

func read_existing_scene_configs():
	"""Read the existing shader parameter values from the scene"""
	original_scene_configs.clear()
	default_layer_configs.clear()
	
	print("=== READING EXISTING SCENE VALUES ===")
	
	for i in range(star_layers.size()):
		var star_layer = star_layers[i]
		var star_rect = null
		
		# Find the ColorRect child in each Parallax2D layer
		for child in star_layer.get_children():
			if child is ColorRect:
				star_rect = child
				break
		
		if star_rect and star_rect.material:
			# Read existing shader parameters
			var existing_material = star_rect.material as ShaderMaterial
			if existing_material:
				var density = existing_material.get_shader_parameter("star_density")
				var brightness = existing_material.get_shader_parameter("star_brightness") 
				var size = existing_material.get_shader_parameter("star_size")
				var twinkle = existing_material.get_shader_parameter("twinkle_speed")
				
				# Use defaults if values are null
				if density == null: density = 0.02
				if brightness == null: brightness = 0.5
				if size == null: size = 2.0
				if twinkle == null: twinkle = 0.2
				
				var config = [density, brightness, size, twinkle]
				original_scene_configs.append(config)
				default_layer_configs.append(config)
				
				print("Layer ", i, " existing values: Density=", density, " Brightness=", brightness, " Size=", size, " Twinkle=", twinkle)
			else:
				print("Layer ", i, " has no shader material, using fallback")
				var fallback_config = [0.02, 0.5, 2.0, 0.2]
				original_scene_configs.append(fallback_config)
				default_layer_configs.append(fallback_config)
		else:
			print("Layer ", i, " has no ColorRect or material, using fallback")
			var fallback_config = [0.02, 0.5, 2.0, 0.2]
			original_scene_configs.append(fallback_config)
			default_layer_configs.append(fallback_config)
	
	print("=== FINISHED READING SCENE VALUES ===")
	print("Total configs read: ", original_scene_configs.size())

func setup_background():
	if base_color_rect:
		# Keep the existing size and position from the scene, just set default color
		base_color_rect.color = Color.BLACK  # Default black background
		print("Setup background rect - Color: ", base_color_rect.color, " Size: ", base_color_rect.size, " Position: ", base_color_rect.position)
	else:
		push_error("Could not find BaseColor rect")

func setup_star_layers(layer_configs: Array):
	# Clear existing star rects
	star_rects.clear()
	
	for i in range(star_layers.size()):
		if i >= layer_configs.size():
			break
			
		var star_layer = star_layers[i]
		var star_rect = null
		
		# Find the ColorRect child in each Parallax2D layer
		for child in star_layer.get_children():
			if child is ColorRect:
				star_rect = child
				break
		
		if star_rect:
			setup_star_rect(star_rect, layer_configs[i])
			star_rects.append(star_rect)
			print("Setup star layer ", i, " - Density: ", layer_configs[i][0], " Brightness: ", layer_configs[i][1])
		else:
			print("ERROR: Could not find ColorRect child in star layer ", i)
			print("  Star layer children: ")
			for child in star_layer.get_children():
				print("    - ", child.name, " (", child.get_class(), ")")

func setup_star_rect(rect: ColorRect, config: Array):
	# Create shader material
	var material = ShaderMaterial.new()
	material.shader = starfield_shader
	
	# Apply configuration
	material.set_shader_parameter("star_density", config[0])
	material.set_shader_parameter("star_brightness", config[1]) 
	material.set_shader_parameter("star_size", config[2])
	material.set_shader_parameter("twinkle_speed", config[3])
	material.set_shader_parameter("tile_size", 200.0)
	material.set_shader_parameter("world_offset", Vector2.ZERO)
	
	print("Star rect config - Density: ", config[0], " Brightness: ", config[1], " Size: ", config[2], " Twinkle: ", config[3])
	
	# Apply the new material - keep existing size and position from scene
	rect.material = material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	print("Star rect size/position preserved: ", rect.size, " at ", rect.position)

func load_system_starfield(system_data: Dictionary):
	"""Configure the starfield based on simplified system data from universe.json"""
	print("=== STARFIELD DEBUG ===")
	print("System data keys: ", system_data.keys())
	print("System name: ", system_data.get("name", "Unknown"))
	print("Star rects initialized: ", star_rects.size(), " rects")
	print("Base color rect exists: ", base_color_rect != null)
	print("Original scene configs available: ", original_scene_configs.size())
	
	# Make sure we have the original scene configs
	if original_scene_configs.is_empty():
		print("WARNING: No original scene configs found, re-reading")
		read_existing_scene_configs()
	
	var starfield_config = system_data.get("starfield", {})
	print("Starfield config found: ", not starfield_config.is_empty())
	print("Starfield config: ", starfield_config)
	
	# Get new simplified attributes with defaults
	var base_color_values = starfield_config.get("BaseColor", [0.0, 0.0, 0.0])
	var density_multiplier = starfield_config.get("StarLayers_Star_Density", 1.0)
	var brightness_multiplier = starfield_config.get("StarLayers_Star_Brightness", 1.0)
	var twinkle_speed_override = null
	
	# Handle twinkle speed - if specified in JSON, use it; otherwise keep original
	if starfield_config.has("StarLayers_Twinkle_Speed"):
		twinkle_speed_override = starfield_config.get("StarLayers_Twinkle_Speed")
	
	print("Parsed values:")
	print("  BaseColor: ", base_color_values)
	print("  Density multiplier: ", density_multiplier)
	print("  Brightness multiplier: ", brightness_multiplier)
	print("  Twinkle speed override: ", twinkle_speed_override, " (null = keep original)")
	
	# Apply base background color
	if base_color_rect and base_color_values.size() >= 3:
		var bg_color = Color(base_color_values[0], base_color_values[1], base_color_values[2])
		base_color_rect.color = bg_color
		print("Set background color to: ", bg_color)
	else:
		print("ERROR: base_color_rect not found or invalid color values")
		print("  base_color_rect: ", base_color_rect)
		print("  base_color_values size: ", base_color_values.size())
	
	# Create modified layer configs using ORIGINAL SCENE VALUES as base
	var modified_configs = []
	for i in range(original_scene_configs.size()):
		var original_config = original_scene_configs[i]
		var modified_config = [
			original_config[0] * density_multiplier,    # Apply density multiplier to original
			original_config[1] * brightness_multiplier, # Apply brightness multiplier to original
			original_config[2],                         # Keep original size
			twinkle_speed_override if twinkle_speed_override != null else original_config[3]  # Use JSON value or keep original
		]
		modified_configs.append(modified_config)
		print("Layer ", i, " - Original: ", original_config, " -> Modified: ", modified_config)
	
	# Apply the modified configurations
	setup_star_layers(modified_configs)
	
	print("Final star rects count: ", star_rects.size())
	print("=== END STARFIELD DEBUG ===")
	print("Loaded starfield for system: ", system_data.get("name", "Unknown"))
