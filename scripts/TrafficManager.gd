# =============================================================================
# ENHANCED TRAFFIC MANAGER - Realistic Ship Lifecycle and Behavior
# =============================================================================
extends Node2D
class_name TrafficManager

@export var spawn_distance: float = 4000.0
@export var departure_distance: float = 5000.0
@export var debug_mode: bool = false

var current_npcs: Array = []
var spawn_timer: float = 0.0
var system_traffic_config: Dictionary = {}
var active: bool = false

# Ship lifecycle tracking
var arriving_ships: Array = []
var visiting_ships: Array = []
var departing_ships: Array = []
var patrolling_ships: Array = []

# System destinations (planets/stations ships can visit)
var system_destinations: Array = []

# Dynamic archetype weights (loaded from JSON per system)
var current_archetype_weights: Dictionary = {}

# Default archetype weights
var default_archetype_weights = {
	"trader": 0.5,
	"military": 0.3,
	"pirate": 0.2
}

# Default traffic configuration
var default_config = {
	"spawn_frequency": 20.0,
	"max_npcs": 8,
	"spawn_frequency_variance": 10.0,
	"archetype_weights": default_archetype_weights,
	"npc_config": {
		"thrust_power": 500.0,
		"rotation_speed": 3.0,
		"max_velocity": 400.0,
		"visit_duration_range": [8.0, 25.0]
	}
}

func _ready():
	add_to_group("traffic_manager")
	
	# Connect to system changes
	UniverseManager.system_changed.connect(_on_system_changed)
	
	# Initialize with current system
	_on_system_changed(UniverseManager.current_system_id)

func _process(delta):
	if not active:
		return
	
	update_spawn_timer(delta)
	update_ship_lifecycles(delta)
	cleanup_distant_npcs()
	
	if debug_mode:
		queue_redraw()

func update_spawn_timer(delta):
	"""Handle NPC spawning timing"""
	spawn_timer -= delta
	
	if spawn_timer <= 0.0 and should_spawn_npc():
		spawn_arriving_npc()
		reset_spawn_timer()

func should_spawn_npc() -> bool:
	"""Check if we should spawn a new NPC"""
	var max_npcs = system_traffic_config.get("max_npcs", default_config.max_npcs)
	var current_count = get_active_npc_count()
	
	return current_count < max_npcs

func get_active_npc_count() -> int:
	"""Get count of active NPCs, cleaning up invalid ones"""
	current_npcs = current_npcs.filter(func(npc): return is_instance_valid(npc))
	return current_npcs.size()

func spawn_arriving_npc():
	"""Spawn a new NPC arriving from outside the system"""
	var npc_ship = create_npc_ship()
	if not npc_ship:
		return
	
	# Choose arrival point at system edge
	var arrival_angle = randf() * TAU
	var arrival_pos = Vector2.from_angle(arrival_angle) * spawn_distance
	
	# Choose destination in system
	var destination = choose_destination_for_archetype("")
	
	# Add to scene
	get_parent().add_child(npc_ship)
	current_npcs.append(npc_ship)
	arriving_ships.append(npc_ship)
	
	# Position the NPC at system edge
	npc_ship.global_position = arrival_pos
	npc_ship.linear_velocity = Vector2.ZERO
	
	# Assign archetype and enhanced AI
	var archetype_type = choose_archetype_for_system()
	assign_enhanced_archetype_to_npc(npc_ship, archetype_type, destination)
	
	if debug_mode:
		print("TrafficManager: Spawned arriving NPC at ", arrival_pos, " heading to ", destination.get("name", "system center"))

func create_npc_ship():
	"""Create a new NPC ship"""
	var npc_ship_scene = load("res://scenes/NPCShip.tscn")
	if not npc_ship_scene:
		push_error("Could not load NPCShip.tscn")
		return null
	
	return npc_ship_scene.instantiate()

func assign_enhanced_archetype_to_npc(npc_ship, archetype_type: String, destination: Dictionary):
	"""Assign archetype and enhanced behavior to NPC"""
	# Wait for NPC to be fully ready
	await get_tree().process_frame
	
	var ai_component = npc_ship.get_node_or_null("Phase1CombatAI")
	if not ai_component:
		print("⚠️ NPC has no AI component")
		return
	
	# Load the AIArchetype class
	const AIArchetypeClass = preload("res://scripts/ai/AIArchetype.gd")
	
	# Create archetype
	var archetype
	match archetype_type:
		"trader":
			archetype = AIArchetypeClass.create_trader()
		"pirate":
			archetype = AIArchetypeClass.create_pirate()
		"military":
			archetype = AIArchetypeClass.create_military()
		_:
			archetype = AIArchetypeClass.create_trader()
	
	# Set archetype on AI
	ai_component.archetype = archetype
	
	# Add enhanced AI component
	var enhanced_ai = EnhancedShipAI.new()
	enhanced_ai.name = "EnhancedShipAI"
	enhanced_ai.traffic_manager = self
	enhanced_ai.setup_arrival_behavior(destination, archetype_type)
	npc_ship.add_child(enhanced_ai)
	
	# Visual distinction
	apply_visual_archetype_hints(npc_ship, archetype_type)
	
	if debug_mode:
		print("✅ Assigned enhanced ", archetype_type, " archetype to ", npc_ship.name)

func choose_destination_for_archetype(archetype_type: String) -> Dictionary:
	"""Choose appropriate destination based on archetype"""
	if system_destinations.is_empty():
		return {"position": Vector2.ZERO, "name": "System Center"}
	
	# For now, choose random destination - can be enhanced per archetype later
	var destination = system_destinations[randi() % system_destinations.size()]
	return destination

func update_ship_lifecycles(delta):
	"""Update all ship lifecycle states"""
	# Update arriving ships
	for i in range(arriving_ships.size() - 1, -1, -1):
		var ship = arriving_ships[i]
		if not is_instance_valid(ship):
			arriving_ships.remove_at(i)
			continue
		
		var enhanced_ai = ship.get_node_or_null("EnhancedShipAI")
		if enhanced_ai and enhanced_ai.has_arrived():
			# Ship has arrived at destination
			arriving_ships.remove_at(i)
			visiting_ships.append(ship)
			enhanced_ai.start_visiting()
			
			if debug_mode:
				print("Ship ", ship.name, " has arrived and is now visiting")
	
	# Update visiting ships
	for i in range(visiting_ships.size() - 1, -1, -1):
		var ship = visiting_ships[i]
		if not is_instance_valid(ship):
			visiting_ships.remove_at(i)
			continue
		
		var enhanced_ai = ship.get_node_or_null("EnhancedShipAI")
		if enhanced_ai and enhanced_ai.should_depart():
			# Ship is ready to leave
			visiting_ships.remove_at(i)
			departing_ships.append(ship)
			enhanced_ai.start_departing()
			
			if debug_mode:
				print("Ship ", ship.name, " is departing the system")
	
	# Update departing ships
	for i in range(departing_ships.size() - 1, -1, -1):
		var ship = departing_ships[i]
		if not is_instance_valid(ship):
			departing_ships.remove_at(i)
			continue
		
		var distance_from_center = ship.global_position.length()
		if distance_from_center > departure_distance:
			# Ship has left the system
			departing_ships.remove_at(i)
			current_npcs.erase(ship)
			ship.queue_free()
			
			if debug_mode:
				print("Ship ", ship.name, " has left the system and been removed")

func find_system_destinations():
	"""Find all visitable destinations in the current system"""
	system_destinations.clear()
	
	var system_scene = get_tree().get_first_node_in_group("system_scene")
	if not system_scene:
		return
	
	var celestial_container = system_scene.get_node_or_null("CelestialBodies")
	if not celestial_container:
		return
	
	for child in celestial_container.get_children():
		if child.has_method("can_interact") and child.celestial_data:
			var destination = {
				"position": child.global_position,
				"name": child.celestial_data.get("name", "Unknown"),
				"type": child.celestial_data.get("type", "unknown"),
				"node": child
			}
			system_destinations.append(destination)
	
	# Add system center as a destination
	system_destinations.append({
		"position": Vector2.ZERO,
		"name": "System Center",
		"type": "waypoint",
		"node": null
	})
	
	if debug_mode:
		print("Found ", system_destinations.size(), " destinations in system")

func choose_archetype_for_system() -> String:
	"""Choose archetype based on current system's loaded weights"""
	var weights_to_use = current_archetype_weights.duplicate()
	if weights_to_use.is_empty():
		weights_to_use = default_archetype_weights
	
	return weighted_random_choice(weights_to_use)

func weighted_random_choice(weights: Dictionary) -> String:
	"""Choose a random key based on weights"""
	var total_weight = 0.0
	for weight in weights.values():
		total_weight += weight
	
	if total_weight <= 0:
		return "trader"
	
	var random_value = randf() * total_weight
	var current_weight = 0.0
	
	for key in weights:
		current_weight += weights[key]
		if random_value <= current_weight:
			return key
	
	return "trader"

func apply_visual_archetype_hints(npc_ship, archetype: String):
	"""Apply subtle visual hints to distinguish archetypes"""
	var sprite = npc_ship.get_node_or_null("Sprite2D")
	if not sprite:
		return
	
	match archetype:
		"trader":
			sprite.modulate = Color(0.9, 1.0, 0.9)  # Slight green tint
		"military":
			sprite.modulate = Color(0.9, 0.9, 1.0)  # Slight blue tint
		"pirate":
			sprite.modulate = Color(1.0, 0.9, 0.9)  # Slight red tint

func cleanup_distant_npcs():
	"""Remove NPCs that have somehow gotten too far away"""
	var cleanup_distance = departure_distance * 1.2
	
	for i in range(current_npcs.size() - 1, -1, -1):
		var npc = current_npcs[i]
		if not is_instance_valid(npc):
			current_npcs.remove_at(i)
			continue
		
		var distance_from_center = npc.global_position.length()
		if distance_from_center > cleanup_distance:
			# Remove from all tracking lists
			arriving_ships.erase(npc)
			visiting_ships.erase(npc)
			departing_ships.erase(npc)
			current_npcs.remove_at(i)
			
			if debug_mode:
				print("TrafficManager: Cleaned up distant NPC at distance ", distance_from_center)
			npc.queue_free()

func reset_spawn_timer():
	"""Reset the spawn timer with variance"""
	var base_frequency = system_traffic_config.get("spawn_frequency", default_config.spawn_frequency)
	var variance = system_traffic_config.get("spawn_frequency_variance", default_config.spawn_frequency_variance)
	
	var random_offset = randf_range(-variance, variance)
	spawn_timer = max(5.0, base_frequency + random_offset)

func _on_system_changed(system_id: String):
	"""Handle system changes"""
	# Clear existing NPCs
	cleanup_all_npcs()
	
	# Load new system configuration
	load_system_traffic_config(system_id)
	
	# Find destinations in new system
	find_system_destinations()
	
	# Don't spawn initial NPCs immediately - let them arrive naturally
	active = true
	reset_spawn_timer()
	
	if debug_mode:
		print("TrafficManager: System changed to ", system_id)

func load_system_traffic_config(system_id: String):
	"""Load traffic configuration for the specified system"""
	var system_data = UniverseManager.get_current_system()
	system_traffic_config = system_data.get("traffic", {})
	
	# Merge with defaults for missing keys
	for key in default_config:
		if not system_traffic_config.has(key):
			system_traffic_config[key] = default_config[key]
	
	# Load archetype weights
	load_archetype_weights(system_data)

func load_archetype_weights(system_data: Dictionary):
	"""Load archetype weights from system data"""
	var traffic_data = system_data.get("traffic", {})
	var json_weights = traffic_data.get("archetype_weights", {})
	
	current_archetype_weights = default_archetype_weights.duplicate()
	
	if not json_weights.is_empty():
		var total_weight = 0.0
		var loaded_weights = {}
		
		for archetype in ["trader", "military", "pirate"]:
			if json_weights.has(archetype):
				var weight = json_weights[archetype]
				if weight is float or weight is int and weight >= 0:
					loaded_weights[archetype] = float(weight)
					total_weight += weight
		
		if total_weight > 0:
			for archetype in loaded_weights:
				current_archetype_weights[archetype] = loaded_weights[archetype] / total_weight

func cleanup_all_npcs():
	"""Remove all current NPCs"""
	for npc in current_npcs:
		if is_instance_valid(npc):
			npc.call_deferred("queue_free")
	
	current_npcs.clear()
	arriving_ships.clear()
	visiting_ships.clear()
	departing_ships.clear()

func _draw():
	"""Debug visualization"""
	if not debug_mode:
		return
	
	var system_center = Vector2.ZERO
	
	# Draw spawn circle
	draw_arc(system_center, spawn_distance, 0, TAU, 64, Color.GREEN, 3.0)
	
	# Draw departure circle
	draw_arc(system_center, departure_distance, 0, TAU, 64, Color.RED, 2.0)
	
	# Draw destinations
	for dest in system_destinations:
		var local_pos = to_local(dest.position)
		draw_circle(local_pos, 15.0, Color.YELLOW)
	
	# Draw ship lifecycle info
	var font = ThemeDB.fallback_font
	var info_text = "Ships - Arriving: %d, Visiting: %d, Departing: %d" % [
		arriving_ships.size(),
		visiting_ships.size(),
		departing_ships.size()
	]
	draw_string(font, Vector2(-300, -280), info_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

# =============================================================================
# ENHANCED SHIP AI - Handles individual ship lifecycle behavior
# =============================================================================
class EnhancedShipAI extends Node:
	enum ShipState {
		ARRIVING,
		VISITING,
		DEPARTING,
		PATROLLING
	}
	
	var ship: RigidBody2D
	var traffic_manager: Node2D
	var current_state: ShipState = ShipState.ARRIVING
	var destination: Dictionary = {}
	var archetype_type: String = ""
	
	# Timing
	var visit_start_time: float = 0.0
	var visit_duration: float = 15.0
	var last_state_change: float = 0.0
	
	# Movement
	var arrival_distance: float = 150.0
	var cruise_speed: float = 0.4
	var approach_speed: float = 0.2
	
	func _ready():
		ship = get_parent()
		visit_duration = randf_range(10.0, 30.0)
		last_state_change = Time.get_time_dict_from_system().hour * 3600 + Time.get_time_dict_from_system().minute * 60 + Time.get_time_dict_from_system().second
	
	func _process(delta):
	match current_state:
		ShipState.ARRIVING:
			handle_arriving_behavior()
		ShipState.VISITING:
			handle_visiting_behavior()
		ShipState.DEPARTING:
			handle_departing_behavior()
		ShipState.PATROLLING:
			handle_patrolling_behavior()

func setup_arrival_behavior(dest: Dictionary, archetype: String):
	"""Setup the ship's arrival behavior"""
	destination = dest
	archetype_type = archetype
	current_state = ShipState.ARRIVING

func handle_arriving_behavior():
	"""Handle ship arriving at destination"""
	if destination.is_empty():
		destination = {"position": Vector2.ZERO, "name": "System Center"}
	
	var target_pos = destination.position
	var distance = ship.global_position.distance_to(target_pos)
	
	# Use appropriate speed based on distance
	var speed = approach_speed if distance < 400.0 else cruise_speed
	
	fly_toward_destination(target_pos, speed)

func handle_visiting_behavior():
	"""Handle ship visiting/staying at location"""
	# Stay near the destination with minimal movement
	var target_pos = destination.position
	var distance = ship.global_position.distance_to(target_pos)
	
	if distance > arrival_distance * 1.5:
		# If we've drifted too far, gently return
		fly_toward_destination(target_pos, 0.15)
	else:
		# Station keeping - very gentle drift
		var time = Time.get_time_dict_from_system()
		var time_float = time.hour * 3600 + time.minute * 60 + time.second
		var drift_angle = (time_float * 0.1) + (hash(ship.get_instance_id()) % 628) / 100.0
		var drift_direction = Vector2.from_angle(drift_angle)
		
		ship.set_meta("ai_thrust_input", 0.05)
		ship.set_meta("ai_turn_input", 0.0)
		ship.set_meta("ai_fire_input", false)

func handle_departing_behavior():
	"""Handle ship departing the system"""
	# Choose departure direction (away from system center)
	var departure_direction = ship.global_position.normalized()
	if departure_direction.length() < 0.1:
		departure_direction = Vector2(1, 0).rotated(randf() * TAU)
	
	var departure_target = departure_direction * 6000.0
	fly_toward_destination(departure_target, 0.7)

func handle_patrolling_behavior():
	"""Handle patrol behavior for military ships"""
	# Simple patrol between destinations
	handle_arriving_behavior()  # Use same movement logic for now

func fly_toward_destination(target: Vector2, speed: float):
	"""Fly toward a destination with realistic movement"""
	var direction = (target - ship.global_position).normalized()
	var distance = ship.global_position.distance_to(target)
	
	# Calculate desired angle
	var target_angle = direction.angle() + PI/2
	var current_angle = ship.rotation
	var angle_diff = angle_difference(current_angle, target_angle)
	
	# Smooth turning
	var turn_input = 0.0
	if abs(angle_diff) > 0.1:
		turn_input = clamp(angle_diff * 2.0, -1.0, 1.0)
	
	# Decelerate when approaching destination
	var adjusted_speed = speed
	if distance < 300.0:
		adjusted_speed *= (distance / 300.0)
		adjusted_speed = max(adjusted_speed, 0.1)  # Minimum speed
	
	ship.set_meta("ai_thrust_input", adjusted_speed)
	ship.set_meta("ai_turn_input", turn_input)
	ship.set_meta("ai_fire_input", false)

func angle_difference(current: float, target: float) -> float:
	var diff = target - current
	while diff > PI: diff -= TAU
	while diff < -PI: diff += TAU
	return diff

func has_arrived() -> bool:
	"""Check if ship has arrived at destination"""
	if destination.is_empty():
		return true
	
	var distance = ship.global_position.distance_to(destination.position)
	return distance <= arrival_distance

func start_visiting():
	"""Start the visiting phase"""
	current_state = ShipState.VISITING
	var time = Time.get_time_dict_from_system()
	visit_start_time = time.hour * 3600 + time.minute * 60 + time.second

func should_depart() -> bool:
	"""Check if ship should depart"""
	var time = Time.get_time_dict_from_system()
	var current_time = time.hour * 3600 + time.minute * 60 + time.second
	var time_visiting = current_time - visit_start_time
	
	return time_visiting >= visit_duration

func start_departing():
	"""Start the departing phase"""
	current_state = ShipState.DEPARTING
