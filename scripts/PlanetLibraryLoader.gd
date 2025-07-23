# =============================================================================
# PLANET LIBRARY LOADER - Loads planet settings from PlanetLibrary.tscn
# =============================================================================
# PlanetLibraryLoader.gd
extends RefCounted
class_name PlanetLibraryLoader

static var _cached_library: Node = null
static var _library_loaded: bool = false

static func get_planet_material(planet_id: String) -> ShaderMaterial:
	"""Get a configured shader material for the specified planet ID"""
	
	# Load library if not already loaded
	if not _library_loaded:
		_load_library()
	
	if not _cached_library:
		push_error("Failed to load PlanetLibrary.tscn")
		return _create_default_material()
	
	# Look for planet with the specified ID
	var planet_node_name = "planet_" + planet_id
	var planet_node = _cached_library.get_node_or_null(planet_node_name)
	
	if not planet_node:
		# Try default planet
		planet_node = _cached_library.get_node_or_null("planet_default")
		if not planet_node:
			push_warning("No planet found for ID '" + planet_id + "' and no default planet available")
			return _create_default_material()
		else:
			print("Using default planet settings for ID: ", planet_id)
	
	# Get the material from the library planet
	var library_material = planet_node.material as ShaderMaterial
	if not library_material:
		push_warning("Planet node '" + planet_node_name + "' has no ShaderMaterial")
		return _create_default_material()
	
	# Create a new material and copy all parameters
	return _copy_material(library_material)

static func _load_library():
	"""Load the PlanetLibrary scene"""
	print("Loading PlanetLibrary.tscn...")
	
	var library_scene = load("res://scenes/PlanetLibrary.tscn")
	if not library_scene:
		push_error("Could not load res://scenes/PlanetLibrary.tscn")
		_library_loaded = true
		return
	
	_cached_library = library_scene.instantiate()
	_library_loaded = true
	
	print("PlanetLibrary loaded successfully with ", _cached_library.get_child_count(), " planets")

static func _copy_material(source_material: ShaderMaterial) -> ShaderMaterial:
	"""Create a new material copying all parameters from source"""
	var new_material = ShaderMaterial.new()
	new_material.shader = source_material.shader
	
	# Get all shader parameters and copy them
	# This list should match all parameters in your PlanetShader_Stage10.gdshader
	var shader_params = [
		"planet_radius", "edge_softness", "uv_offset_x", "uv_offset_y",
		"continent_seed", "terrain_seed", "river_seed", "detail_seed", "cloud_seed",
		"output_mode", "normal_map_intensity", "sphere_strength",
		"light_direction", "light_intensity", "light_color",
		"shadow_tint", "shadow_tint_strength", "ambient_light", "ambient_color",
		"rim_light_intensity", "rim_light_color", "rim_light_falloff",
		"rim_light_crescent_power", "rim_light_crescent_offset", "rim_light_glow_intensity", 
		"rim_light_glow_radius", "rim_light_glow_enabled",
		"continent_scale", "continent_threshold", "continent_sharpness", 
		"continent_octaves", "continent_persistence", "ocean_depth",
		"warp_strength", "warp_scale", "terrain_scale", "terrain_strength",
		"terrain_octaves", "terrain_persistence", "terrain_softness",
		"detail_scale", "detail_strength", "detail_octaves",
		"mountain_threshold", "highland_threshold", "cloud_coverage",
		"cloud_scale", "cloud_stretch_x", "cloud_stretch_y", "cloud_octaves",
		"cloud_persistence", "cloud_density", "cloud_sharpness",
		"cloud_color", "cloud_shadow_color", "cloud_opacity", "cloud_shadow_strength",
		"cloud_offset_x", "cloud_offset_y", "river_scale", "river_strength",
		"river_width", "river_octaves", "river_persistence", 
		"river_glow_enabled", "river_glow_intensity", "river_glow_radius", "river_glow_color",
		"ice_cap_size", "ice_cap_softness", "desert_latitude", "desert_width", "desert_intensity",
		"deep_ocean_color", "shallow_water_color", "river_color",
		"mountain_color", "highland_color", "lowland_color", "desert_color",
		"ice_color", "coastal_blend", "beach_color", "core_color", "core_size",
		"color_variation", "variation_tint"
	]
	
	# Copy each parameter
	for param_name in shader_params:
		var value = source_material.get_shader_parameter(param_name)
		if value != null:
			new_material.set_shader_parameter(param_name, value)
	
	return new_material

static func _create_default_material() -> ShaderMaterial:
	"""Create a basic default material as fallback"""
	var material = ShaderMaterial.new()
	var shader = load("res://shaders/PlanetShader_Stage9.gdshader")
	
	if shader:
		material.shader = shader
		# Set some basic default colors
		material.set_shader_parameter("deep_ocean_color", Color(0.1, 0.2, 0.4))
		material.set_shader_parameter("shallow_water_color", Color(0.2, 0.4, 0.6))
		material.set_shader_parameter("lowland_color", Color(0.3, 0.5, 0.3))
		material.set_shader_parameter("highland_color", Color(0.4, 0.4, 0.2))
		material.set_shader_parameter("mountain_color", Color(0.5, 0.4, 0.3))
		material.set_shader_parameter("continent_seed", randf() * 1000.0)
	
	return material

static func get_available_planets() -> Array[String]:
	"""Get list of all available planet IDs in the library"""
	if not _library_loaded:
		_load_library()
	
	if not _cached_library:
		return []
	
	var planet_ids: Array[String] = []
	for child in _cached_library.get_children():
		if child.name.begins_with("planet_"):
			var planet_id = child.name.substr(7)  # Remove "planet_" prefix
			planet_ids.append(planet_id)
	
	return planet_ids

static func reload_library():
	"""Force reload of the library (useful for development)"""
	if _cached_library:
		_cached_library.queue_free()
		_cached_library = null
	_library_loaded = false
	_load_library()
