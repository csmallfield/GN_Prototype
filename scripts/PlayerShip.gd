# =============================================================================
# PLAYER SHIP - Main player controller with hyperspace sequence
# =============================================================================
# PlayerShip.gd
extends RigidBody2D
class_name PlayerShip

@export var thrust_power: float = 500.0
@export var rotation_speed: float = 3.0
@export var max_velocity: float = 400.0
@export var hyperspace_thrust_power: float = 1500.0
@export var hyperspace_entry_speed: float = 800.0

@onready var sprite = $Sprite2D
@onready var engine_particles = $EngineParticles
@onready var interaction_area = $InteractionArea
@onready var camera = $Camera2D

var current_target: Node = null
var flash_overlay: ColorRect

# Hyperspace sequence states
enum HyperspaceState {
	NORMAL,
	HYPERSPACE_SEQUENCE
}

enum HyperspacePhase {
	DECELERATION,
	ROTATION,
	ACCELERATION,
	FLASH,
	ENTRY
}

var hyperspace_state: HyperspaceState = HyperspaceState.NORMAL
var hyperspace_phase: HyperspacePhase = HyperspacePhase.DECELERATION
var hyperspace_destination: String = ""
var hyperspace_timer: float = 0.0
var target_rotation: float = 0.0
var acceleration_timer: float = 0.0
var flash_timer: float = 0.0
var rotation_timer: float = 0.0
var deceleration_timer: float = 0.0
var entry_position: Vector2 = Vector2.ZERO
var entry_target: Vector2 = Vector2.ZERO
var jump_direction: Vector2 = Vector2.ZERO
var map_direction: Vector2 = Vector2.ZERO  # Store the direction from the map

func _ready():
	UniverseManager.player_ship = self
	interaction_area.body_entered.connect(_on_interaction_area_entered)
	interaction_area.body_exited.connect(_on_interaction_area_exited)
	
	# Create flash overlay for hyperspace effect
	create_flash_overlay()

func _integrate_forces(state):
	if hyperspace_state == HyperspaceState.NORMAL:
		handle_input(state)
	else:
		handle_hyperspace_sequence(state)
	
	limit_velocity(state)

func handle_input(state):
	# Rotation
	var rotation_input = Input.get_axis("turn_left", "turn_right")
	state.angular_velocity = rotation_input * rotation_speed
	
	# Thrust
	if Input.is_action_pressed("thrust"):
		var thrust_vector = Vector2(0, -thrust_power).rotated(rotation)
		state.apply_central_force(thrust_vector)
		engine_particles.emitting = true
	else:
		engine_particles.emitting = false

func handle_hyperspace_sequence(state):
	"""Handle ship behavior during hyperspace sequence"""
	hyperspace_timer += get_physics_process_delta_time()
	
	# Force camera to stay locked during hyperspace
	if camera:
		camera.global_position = global_position
	
	match hyperspace_phase:
		HyperspacePhase.DECELERATION:
			handle_deceleration_phase(state)
		HyperspacePhase.ROTATION:
			handle_rotation_phase(state)
		HyperspacePhase.ACCELERATION:
			handle_acceleration_phase(state)
		HyperspacePhase.FLASH:
			handle_flash_phase(state)
		HyperspacePhase.ENTRY:
			handle_entry_phase(state)

func handle_deceleration_phase(state):
	"""Phase 1: Automatically decelerate to a stop"""
	deceleration_timer += get_physics_process_delta_time()
	
	var velocity = state.linear_velocity
	var speed = velocity.length()
	
	# If already stopped or nearly stopped, skip to rotation
	if speed <= 20.0 or deceleration_timer < 0.1:  # Check on first frame
		if speed <= 20.0:
			print("Already stopped (speed: ", speed, "), moving to rotation phase")
			state.linear_velocity = Vector2.ZERO  # Full stop
			engine_particles.emitting = false
			hyperspace_phase = HyperspacePhase.ROTATION
			rotation_timer = 0.0
			calculate_target_rotation()
			return
	
	# Timeout check
	if deceleration_timer > 3.0:
		print("Deceleration timeout, forcing stop")
		state.linear_velocity = Vector2.ZERO
		engine_particles.emitting = false
		hyperspace_phase = HyperspacePhase.ROTATION
		rotation_timer = 0.0
		calculate_target_rotation()
		return
	
	# Apply reverse thrust to slow down
	var reverse_direction = -velocity.normalized()
	var decel_force = reverse_direction * thrust_power * 2.0
	state.apply_central_force(decel_force)
	engine_particles.emitting = true
	
	print("Decelerating... Speed: ", speed)

func handle_rotation_phase(state):
	"""Phase 2: Rotate to face the destination system"""
	rotation_timer += get_physics_process_delta_time()
	var angle_diff = angle_difference(rotation, target_rotation)
	
	if abs(angle_diff) > 0.1 and rotation_timer < 1.0:
		var turn_speed = rotation_speed * 2.0
		state.angular_velocity = sign(angle_diff) * -turn_speed
	else:
		state.angular_velocity = 0.0
		rotation = target_rotation
		hyperspace_phase = HyperspacePhase.ACCELERATION
		acceleration_timer = 0.0

func handle_acceleration_phase(state):
	"""Phase 3: Dramatically accelerate toward destination"""
	acceleration_timer += get_physics_process_delta_time()
	
	# Apply massive forward thrust
	var thrust_vector = Vector2(0, -hyperspace_thrust_power).rotated(rotation)
	state.apply_central_force(thrust_vector)
	engine_particles.emitting = true
	
	var current_speed = state.linear_velocity.length()
	
	# Save actual travel direction
	if current_speed > 100.0:
		jump_direction = state.linear_velocity.normalized()
	
	print("Accelerating... Speed: ", current_speed)
	
	# After 3 seconds or high speed, trigger flash
	if acceleration_timer >= 3.5 or current_speed >= hyperspace_entry_speed * 4:
		print("Acceleration complete, flash time!")
		hyperspace_phase = HyperspacePhase.FLASH
		flash_timer = 0.0

func handle_flash_phase(state):
	"""Phase 4: Flash effect and system transition"""
	flash_timer += get_physics_process_delta_time()
	
	if flash_timer < 0.3:
		# Show white flash
		if flash_overlay:
			var alpha = sin(flash_timer * PI / 0.3)  # Fade in/out
			flash_overlay.color = Color(1, 1, 1, alpha)
			flash_overlay.visible = true
	else:
		# Flash complete, transition to new system
		print("Flash complete, transitioning to new system")
		if flash_overlay:
			flash_overlay.visible = false
		
		transition_to_new_system()
		hyperspace_phase = HyperspacePhase.ENTRY

func handle_entry_phase(state):
	"""Phase 5: Enter new system and decelerate"""
	var distance_to_target = global_position.distance_to(entry_target)
	var current_speed = state.linear_velocity.length()
	
	print("Entry phase - Speed: ", current_speed, " Distance: ", distance_to_target)
	
	# Complete when close enough or slow enough
	if distance_to_target < 800 or current_speed < max_velocity:
		print("Entry complete - returning control")
		engine_particles.emitting = false
		complete_hyperspace_sequence()
		return
	
	# Apply gentle deceleration
	if current_speed > max_velocity:
		var velocity_direction = state.linear_velocity.normalized()
		var decel_force = -velocity_direction * thrust_power * 1.2
		state.apply_central_force(decel_force)
		engine_particles.emitting = true

func transition_to_new_system():
	"""Handle the actual system change and ship positioning"""
	print("Transitioning to new system: ", hyperspace_destination)
	
	# Calculate entry position based on map direction
	var system_center = Vector2.ZERO
	var edge_distance = 3000.0
	
	# Use the stored map direction (reverse it to enter from opposite side)
	var entry_direction = -map_direction
	entry_position = system_center + entry_direction * edge_distance
	entry_target = system_center
	
	# Set velocity toward center
	linear_velocity = -entry_direction * hyperspace_entry_speed
	
	# Keep the ship's rotation
	print("Entry position: ", entry_position)
	print("Entry velocity: ", linear_velocity)
	print("Ship rotation: ", rad_to_deg(rotation), " degrees")
	
	# Force position update BEFORE changing system
	global_position = entry_position
	
	# Force camera to new position
	if camera:
		camera.global_position = global_position
		camera.reset_smoothing()  # This should reset any interpolation
	
	# Now change the system
	UniverseManager.change_system(hyperspace_destination)
	
	# Force another camera update after system change
	if camera:
		await get_tree().process_frame  # Wait one frame
		camera.global_position = global_position
		camera.force_update_scroll()

func calculate_target_rotation():
	"""Calculate which direction the ship should face based on map"""
	# Get the direction from hyperspace map
	var system_positions = get_system_positions()
	var current_system = UniverseManager.current_system_id
	
	if current_system in system_positions and hyperspace_destination in system_positions:
		var current_pos = system_positions[current_system]
		var target_pos = system_positions[hyperspace_destination]
		
		# Calculate direction to target
		map_direction = (target_pos - current_pos).normalized()
		
		# Convert to rotation (ship faces up by default, which is -Y direction)
		# So we need to subtract PI/2 instead of adding it
		target_rotation = map_direction.angle() - PI/2
		
		print("Direction to ", hyperspace_destination, ": ", map_direction)
		print("Target rotation: ", rad_to_deg(target_rotation), " degrees")
		print("Current rotation: ", rad_to_deg(rotation), " degrees")
	else:
		# Fallback
		target_rotation = 0.0
		map_direction = Vector2(0, -1)

func get_system_positions() -> Dictionary:
	"""Get the system positions used by the hyperspace map"""
	var map_width = 480
	var map_height = 500
	var margin = 50
	
	return {
		"sol_system": Vector2(margin + map_width * 0.3, margin + map_height * 0.5),
		"alpha_centauri": Vector2(margin + map_width * 0.45, margin + map_height * 0.4),
		"vega_system": Vector2(margin + map_width * 0.2, margin + map_height * 0.3),
		"sirius_system": Vector2(margin + map_width * 0.6, margin + map_height * 0.3),
		"rigel_system": Vector2(margin + map_width * 0.7, margin + map_height * 0.6),
		"arcturus_system": Vector2(margin + map_width * 0.1, margin + map_height * 0.7),
		"deneb_system": Vector2(margin + map_width * 0.4, margin + map_height * 0.8),
		"aldebaran_system": Vector2(margin + map_width * 0.8, margin + map_height * 0.4),
		"antares_system": Vector2(margin + map_width * 0.6, margin + map_height * 0.7),
		"capella_system": Vector2(margin + map_width * 0.2, margin + map_height * 0.6)
	}

func angle_difference(current: float, target: float) -> float:
	"""Calculate the shortest angle difference between two angles"""
	var diff = target - current
	# Normalize to [-PI, PI]
	while diff > PI:
		diff -= 2 * PI
	while diff < -PI:
		diff += 2 * PI
	return diff

func limit_velocity(state):
	if hyperspace_state == HyperspaceState.HYPERSPACE_SEQUENCE:
		return
		
	if state.linear_velocity.length() > max_velocity:
		state.linear_velocity = state.linear_velocity.normalized() * max_velocity

func _input(event):
	if hyperspace_state != HyperspaceState.NORMAL:
		return
		
	if event.is_action_pressed("interact") and current_target:
		interact_with_target()
	elif event.is_action_pressed("hyperspace"):
		open_hyperspace_menu()
	elif event.is_action_pressed("land"):
		# Remove current_target requirement - attempt_landing() will find nearby planets
		attempt_landing()
	
	# Debug: Test mission system (remove this later)
	if OS.is_debug_build() and event.is_action_pressed("ui_accept"):  # Enter key
		debug_test_mission_system()

func interact_with_target():
	if current_target.has_method("interact"):
		current_target.interact()

func open_hyperspace_menu():
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("show_hyperspace_menu"):
		ui.show_hyperspace_menu()

func attempt_landing():
	"""Attempt to land on the current target (placeholder for Stage 2)"""
	var current_speed = linear_velocity.length()
	var max_landing_speed = 150.0  # Reasonable landing speed - not too strict
	
	print("=== LANDING ATTEMPT ===")
	print("Current speed: ", current_speed)
	print("Max landing speed: ", max_landing_speed)
	print("Current target: ", current_target.celestial_data.get("name", "Unknown") if current_target else "None")
	
	# Check if we have a target
	if not current_target:
		# Try to find a nearby landable planet manually
		var nearby_planet = find_nearby_landable_planet()
		if nearby_planet:
			print("Found nearby landable planet: ", nearby_planet.celestial_data.get("name", "Unknown"))
			current_target = nearby_planet
		else:
			print("❌ No landable planet nearby")
			return
	
	# Check if target can be landed on
	if not current_target.has_method("can_interact") or not current_target.can_interact():
		print("❌ Cannot land on this target: ", current_target.celestial_data.get("name", "Unknown"))
		return
	
	# Check speed requirement
	if current_speed > max_landing_speed:
		print("❌ Moving too fast to land! Slow down to under ", max_landing_speed, " units/sec")
		print("   (Current speed: ", round(current_speed), ")")
		return
	
	# All checks passed - show landing interface
	print("✅ Landing conditions met!")
	show_planet_landing_ui()

func show_planet_landing_ui():
	"""Show the planet landing user interface"""
	var ui_controller = get_tree().get_first_node_in_group("ui")
	if not ui_controller:
		print("❌ Could not find UI controller")
		return
	
	# Get or create the landing UI
	var landing_ui = ui_controller.get_node_or_null("PlanetLandingUI")
	if not landing_ui:
		# Create the landing UI
		var landing_ui_scene = load("res://scenes/PlanetLandingUI.tscn")
		if not landing_ui_scene:
			print("❌ Could not load PlanetLandingUI.tscn")
			return
		
		landing_ui = landing_ui_scene.instantiate()
		landing_ui.name = "PlanetLandingUI"
		ui_controller.add_child(landing_ui)
		print("Created PlanetLandingUI")
	
	# Show the landing interface with current planet data
	var planet_data = current_target.celestial_data
	var system_id = UniverseManager.current_system_id
	
	landing_ui.show_landing_interface(planet_data, system_id)
	print("✅ Planet landing UI displayed")

func find_nearby_landable_planet() -> Node:
	"""Find a landable planet within reasonable distance"""
	var search_radius = 300.0  # Generous search radius
	var system_scene = get_tree().get_first_node_in_group("system_scene")
	if not system_scene:
		return null
	
	var celestial_container = system_scene.get_node_or_null("CelestialBodies")
	if not celestial_container:
		return null
	
	var closest_planet = null
	var closest_distance = search_radius
	
	for body in celestial_container.get_children():
		if body.has_method("can_interact") and body.can_interact():
			var distance = global_position.distance_to(body.global_position)
			print("Distance to ", body.celestial_data.get("name", "Unknown"), ": ", round(distance))
			
			if distance < closest_distance:
				closest_distance = distance
				closest_planet = body
	
	if closest_planet:
		print("Closest landable planet: ", closest_planet.celestial_data.get("name", "Unknown"), " at distance ", round(closest_distance))
	else:
		print("No landable planets within ", search_radius, " units")
	
	return closest_planet

func check_for_deliveries():
	"""Check if player has missions to deliver to this planet"""
	var planet_id = current_target.celestial_data.get("id", "")
	var system_id = UniverseManager.current_system_id
	
	var delivery_mission = PlayerData.has_active_mission_to_planet(planet_id, system_id)
	if not delivery_mission.is_empty():
		print("🎉 DELIVERY COMPLETED!")
		print("Delivered: ", delivery_mission.get("cargo_type", "Unknown Cargo"))
		print("Payment: ", delivery_mission.get("payment", 0), " credits")
		
		# Complete the mission
		var mission_id = delivery_mission.get("id", "")
		if mission_id != "":
			PlayerData.complete_mission(mission_id)
		
		print("✅ Mission completed successfully!")
	else:
		print("No deliveries for this location")

func show_available_missions():
	"""Show missions available for pickup at this planet"""
	var planet_id = current_target.celestial_data.get("id", "")
	if planet_id != "":
		var missions = UniverseManager.get_missions_for_planet(planet_id)
		print("📦 Available missions at this location: ", missions.size())
		
		if missions.size() > 0:
			print("Available cargo missions:")
			for i in range(missions.size()):
				var mission = missions[i]
				print("  ", i + 1, ". ", MissionGenerator.get_mission_description(mission))
			print("(Mission selection UI will be implemented in Stage 2)")
		else:
			print("No missions available at this location")
	print("=== END LANDING ===")

func debug_test_mission_system():
	"""Debug method to test mission system foundation (remove later)"""
	print("=== TESTING MISSION SYSTEM FOUNDATION ===")
	
	# Test PlayerData
	print("Testing PlayerData...")
	PlayerData.debug_print_status()
	
	# Test MissionGenerator
	print("Testing MissionGenerator...")
	MissionGenerator.debug_print_all_destinations()
	
	# Test system missions
	print("Testing current system missions...")
	var current_system = UniverseManager.get_current_system()
	print("Current system: ", current_system.get("name", "Unknown"))
	
	# Get missions for Earth (if we're in Sol system)
	if UniverseManager.current_system_id == "sol_system":
		var earth_missions = UniverseManager.get_missions_for_planet("earth")
		print("Earth has ", earth_missions.size(), " missions:")
		for mission in earth_missions:
			print("  - ", MissionGenerator.get_mission_description(mission))
	
	print("=== MISSION SYSTEM TEST COMPLETE ===")
	print("Press Enter again to test, L to land on planets when implemented")

func _on_interaction_area_entered(body):
	if body.has_method("can_interact") and body.can_interact():
		current_target = body
		print("Can interact with: ", body.celestial_data.name)

func _on_interaction_area_exited(body):
	if body == current_target:
		current_target = null

func start_hyperspace_sequence(destination_system: String):
	"""Begin the hyperspace jump sequence"""
	print("Starting hyperspace sequence to: ", destination_system)
	
	# Disable camera smoothing for the entire sequence
	if camera:
		camera.position_smoothing_enabled = false
		camera.global_position = global_position
	
	# Reset all state
	hyperspace_state = HyperspaceState.HYPERSPACE_SEQUENCE
	hyperspace_phase = HyperspacePhase.DECELERATION
	hyperspace_destination = destination_system
	hyperspace_timer = 0.0
	target_rotation = 0.0
	acceleration_timer = 0.0
	flash_timer = 0.0
	rotation_timer = 0.0
	deceleration_timer = 0.0
	entry_position = Vector2.ZERO
	entry_target = Vector2.ZERO
	jump_direction = Vector2.ZERO
	
	print("Phase 1: Beginning deceleration")

func complete_hyperspace_sequence():
	"""Complete the hyperspace sequence and return control to player"""
	print("Hyperspace sequence complete")
	
	# Re-enable camera smoothing
	if camera:
		camera.position_smoothing_enabled = true
	
	# Reset to normal state
	hyperspace_state = HyperspaceState.NORMAL
	hyperspace_phase = HyperspacePhase.DECELERATION
	hyperspace_destination = ""
	hyperspace_timer = 0.0
	target_rotation = 0.0
	acceleration_timer = 0.0
	flash_timer = 0.0
	rotation_timer = 0.0
	deceleration_timer = 0.0
	entry_position = Vector2.ZERO
	entry_target = Vector2.ZERO
	jump_direction = Vector2.ZERO
	map_direction = Vector2.ZERO

func create_flash_overlay():
	"""Create the white flash overlay for hyperspace effect"""
	# Create a CanvasLayer to ensure it renders above everything
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "FlashLayer"
	canvas_layer.layer = 10  # High layer to be above everything
	add_child(canvas_layer)
	
	# Create the flash overlay
	flash_overlay = ColorRect.new()
	flash_overlay.name = "FlashOverlay"
	flash_overlay.color = Color(1, 1, 1, 0)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_overlay.visible = false
	
	# Make it full screen
	flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Add to canvas layer
	canvas_layer.add_child(flash_overlay)
	
	print("Flash overlay created in CanvasLayer")
