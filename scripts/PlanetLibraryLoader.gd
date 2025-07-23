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
	"""Create a new material copying all parameters from source automatically"""
	var new_material = ShaderMaterial.new()
	new_material.shader = source_material.shader
	
	if not source_material.shader:
		push_error("Source material has no shader!")
		return new_material
	
	# Use Godot's reflection to automatically find and copy ALL shader parameters
	var props = source_material.get_property_list()
	var copied_count = 0
	var skipped_params = []
	
	print("=== Auto-copying shader parameters ===")
	
	for prop in props:
		if prop.name.begins_with("shader_parameter/"):
			var param_name = prop.name.substr(17)  # Remove "shader_parameter/" prefix
			var source_value = source_material.get_shader_parameter(param_name)
			
			if source_value != null:
				new_material.set_shader_parameter(param_name, source_value)
				copied_count += 1
				
				# Debug output for specific problematic parameters
				if param_name in ["light_color", "rim_light_intensity", "river_glow_enabled"]:
					print("  CRITICAL PARAM: ", param_name, " = ", source_value, " (type: ", typeof(source_value), ")")
			else:
				skipped_params.append(param_name)
	
	print("Auto-copied ", copied_count, " shader parameters")
	if skipped_params.size() > 0:
		print("Skipped (null values): ", skipped_params)
	
	# Verify the copy worked for critical parameters
	print("=== Verification ===")
	var test_params = ["light_color", "rim_light_intensity", "river_glow_enabled", "light_intensity"]
	for param in test_params:
		var source_val = source_material.get_shader_parameter(param)
		var copied_val = new_material.get_shader_parameter(param)
		var match_status = "✓" if source_val == copied_val else "✗ MISMATCH"
		print("  ", param, ": ", source_val, " -> ", copied_val, " ", match_status)
	
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
