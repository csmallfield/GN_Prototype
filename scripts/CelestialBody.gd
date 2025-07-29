# =============================================================================
# CELESTIAL BODY - Now with parameter animation support
# =============================================================================
# CelestialBody.gd
extends StaticBody2D
class_name CelestialBody

@export var celestial_data: Dictionary = {}
@onready var sprite = $Sprite2D
@onready var label = $Label

var procedural_planet: ColorRect = null
var planet_animator: PlanetAnimator = null

func _ready():
	if celestial_data.has("type") and celestial_data.type == "planet":
		create_procedural_planet()
	elif celestial_data.has("sprite"):
		load_sprite(celestial_data.sprite)
	
	if celestial_data.has("name"):
		label.text = celestial_data.name

func create_procedural_planet():
	"""Create a procedural planet using the library system"""
	var planet_id = celestial_data.get("id", "default")
	
	# Get material from the planet library
	var material = PlanetLibraryLoader.get_planet_material(planet_id)
	if not material:
		push_error("Failed to get material for planet: " + planet_id)
		return
	
	# Create ColorRect for the procedural planet
	procedural_planet = ColorRect.new()
	procedural_planet.name = "ProceduralPlanet"
	
	# Set size to 512x512
	var planet_size = Vector2(512, 512)
	procedural_planet.size = planet_size
	procedural_planet.position = -planet_size / 2  # Center the planet
	procedural_planet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Apply the material from the library
	procedural_planet.material = material
	
	# Apply any system-specific modifications
	apply_system_variations(material)
	
	# Setup parameter animations if defined
	setup_planet_animations(material)
	
	# Hide the original sprite and add the procedural planet
	sprite.visible = false
	add_child(procedural_planet)
	
	# Update collision shape to match new planet size
	update_collision_shape(planet_size)
	
	print("Created procedural planet: ", planet_id)

func setup_planet_animations(material: ShaderMaterial):
	"""Setup parameter animations if defined in celestial_data"""
	var animation_data = celestial_data.get("animations", {})
	
	if animation_data.is_empty():
		return  # No animations defined
	
	# Create and configure the animator
	planet_animator = PlanetAnimator.new()
	planet_animator.name = "PlanetAnimator"
	add_child(planet_animator)
	
	# Setup animations with the material and configuration
	planet_animator.setup_animations(material, animation_data)
	
	print("Setup animations for planet: ", celestial_data.get("id", "unknown"))

func apply_system_variations(material: ShaderMaterial):
	"""Apply minor system-specific variations (lighting, seeds)"""
	var system_id = UniverseManager.current_system_id
	var planet_id = celestial_data.get("id", "")
	
	# Generate system-consistent but planet-unique seeds
	var base_seed = hash(planet_id + system_id) % 1000
	var system_rng = RandomNumberGenerator.new()
	system_rng.seed = hash(system_id)
	
	# Update terrain seeds for variety while keeping the library's base appearance
	var current_continent_seed = material.get_shader_parameter("continent_seed")
	if current_continent_seed == null or current_continent_seed == 0.0:
		material.set_shader_parameter("continent_seed", float(base_seed))
	
	# Add slight seed variations for other terrain features
	material.set_shader_parameter("terrain_seed", float(base_seed + system_rng.randi() % 200))
	material.set_shader_parameter("detail_seed", float(base_seed + system_rng.randi() % 200))
	material.set_shader_parameter("river_seed", float(base_seed + system_rng.randi() % 200))
	
	# Apply system-based lighting variations (different star types)
	apply_star_lighting(material, system_id)

func apply_star_lighting(material: ShaderMaterial, system_id: String):
	"""Apply star-type-specific lighting"""
	match system_id:
		"sol_system":
			#Yellow star - warm light
			material.set_shader_parameter("light_color", Color(0.921, 0.594, 0.674))
			material.set_shader_parameter("ambient_color", Color(0.4, 0.6, 1.0))
			material.set_shader_parameter("light_intensity", 1.4)
			
			
		#"sirius_system":
			# Blue-white star - cool bright light
			#material.set_shader_parameter("light_color", Color(0.9, 0.95, 1.0))
			#material.set_shader_parameter("light_intensity", 1.2)
			#material.set_shader_parameter("ambient_color", Color(0.6, 0.7, 1.0))
			
		#"antares_system":
			# Red supergiant - warm red light
			#material.set_shader_parameter("light_color", Color(1.0, 0.7, 0.5))
			#material.set_shader_parameter("ambient_color", Color(0.8, 0.4, 0.3))
			
		#"rigel_system":
			# Blue supergiant - intense blue-white light
			#material.set_shader_parameter("light_color", Color(0.8, 0.9, 1.0))
			#material.set_shader_parameter("light_intensity", 1.4)
			#material.set_shader_parameter("ambient_color", Color(0.5, 0.6, 1.0))
			
		#"arcturus_system":
			# Red giant - warm orange light
			#material.set_shader_parameter("light_color", Color(1.0, 0.8, 0.6))
			#material.set_shader_parameter("ambient_color", Color(0.7, 0.5, 0.4))
			
		#"vega_system":
			# Blue-white star - bright cool light
			#material.set_shader_parameter("light_color", Color(0.9, 0.9, 1.0))
			#material.set_shader_parameter("light_intensity", 1.1)
			
		_:
			# Default: slight variation but don't override library settings too much
			pass

func update_collision_shape(planet_size: Vector2):
	"""Update collision shapes to match the new planet size"""
	var collision_shape = $CollisionShape2D
	if collision_shape and collision_shape.shape is CircleShape2D:
		var circle_shape = collision_shape.shape as CircleShape2D
		circle_shape.radius = planet_size.x / 8  # Reasonable collision size
	
	# Update interaction area
	var interaction_area = $CollisionShape2D/InteractionArea/CollisionShape2D
	if interaction_area and interaction_area.shape is CircleShape2D:
		var interaction_circle = interaction_area.shape as CircleShape2D
		interaction_circle.radius = planet_size.x / 2  # Larger interaction range

func load_sprite(sprite_path: String):
	"""Load static sprite for non-planet celestial bodies"""
	var texture = load(sprite_path)
	if texture:
		sprite.texture = texture

func can_interact() -> bool:
	return celestial_data.get("can_land", false)

func interact():
	print("Landing on: ", celestial_data.name)
	UniverseManager.celestial_body_approached.emit(celestial_data)
	# Here you would transition to planet surface or show services menu

func pause_animations():
	"""Pause planet animations (called when leaving system)"""
	if planet_animator:
		planet_animator.stop_animations()

func resume_animations():
	"""Resume planet animations (called when entering system)"""
	if planet_animator:
		planet_animator.start_animations()

# Development helper function
func reload_planet_from_library():
	"""Reload this planet's appearance from the library (useful during development)"""
	if procedural_planet and celestial_data.get("type") == "planet":
		var planet_id = celestial_data.get("id", "default")
		PlanetLibraryLoader.reload_library()
		var new_material = PlanetLibraryLoader.get_planet_material(planet_id)
		if new_material:
			# Stop current animations
			if planet_animator:
				planet_animator.stop_animations()
				planet_animator.queue_free()
				planet_animator = null
			
			# Apply new material and restart animations
			procedural_planet.material = new_material
			apply_system_variations(new_material)
			setup_planet_animations(new_material)
			
			print("Reloaded planet from library: ", planet_id)
