# =============================================================================
# TRAFFIC MANAGER - Spawns and manages NPC ships based on system data
# =============================================================================
# TrafficManager.gd
extends Node2D
class_name TrafficManager

@export var spawn_distance: float = 4000.0  # Distance from center to spawn NPCs
@export var debug_mode: bool = false

var current_npcs: Array[NPCShip] = []
var spawn_timer: float = 0.0
var system_traffic_config: Dictionary = {}
var active: bool = false
# Add archetype loading
var available_archetypes: Dictionary = {}

# Default traffic configuration
var default_config = {
	"spawn_frequency": 15.0,      # Seconds between spawns
	"max_npcs": 3,               # Maximum NPCs in system
	"spawn_frequency_variance": 5.0,  # Random variance in spawn timing
	"npc_config": {
		"thrust_power": 500.0,
		"rotation_speed": 3.0,
		"max_velocity": 400.0,
		"visit_duration_range": [3.0, 8.0]
	}
}

func _ready():
	add_to_group("traffic_manager")
	
	# Load archetypes
	load_archetypes()
	
	# Connect to system changes
	UniverseManager.system_changed.connect(_on_system_changed)
	
	# Initialize with current system
	_on_system_changed(UniverseManager.current_system_id)
	
	
func load_archetypes():
	"""Load all available archetypes from the data folder"""
	available_archetypes = {
		"trader": preload("res://data/ai_archetypes/trader_archetype.tres"),
		"pirate": preload("res://data/ai_archetypes/pirate_archetype.tres"),
		"military": preload("res://data/ai_archetypes/military_archetype.tres"),
		"coward": preload("res://data/ai_archetypes/coward_archetype.tres")
	}
	print("Loaded ", available_archetypes.size(), " archetypes")
		
func _process(delta):
	if not active:
		return
	
	update_spawn_timer(delta)
	cleanup_distant_npcs()
	
	if debug_mode:
		queue_redraw()

func update_spawn_timer(delta):
	"""Handle NPC spawning timing"""
	spawn_timer -= delta
	
	if spawn_timer <= 0.0 and should_spawn_npc():
		spawn_npc()
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

func spawn_npc():
	"""Spawn a new NPC ship from hyperspace"""
	# Occasionally spawn formations arriving from hyperspace
	if randf() < 0.2 and should_spawn_npc():  # 20% chance and room for 2 ships
		spawn_hyperspace_formation()
		return
	
	var npc_ship = create_npc_ship()
	if not npc_ship:
		return
	
	# Calculate spawn position (coming from a connected system)
	var spawn_data = calculate_hyperspace_entry()
	
	# Add to scene
	get_parent().add_child(npc_ship)
	current_npcs.append(npc_ship)
	
	# Initialize hyperspace entry
	npc_ship.start_hyperspace_entry(spawn_data.position, spawn_data.velocity, spawn_data.origin_system)
	
	if debug_mode:
		print("TrafficManager: Spawned NPC at ", spawn_data.position, " from ", spawn_data.origin_system)

func create_npc_ship() -> NPCShip:
	var npc_ship_scene = load("res://scenes/NPCShip.tscn")
	if not npc_ship_scene:
		push_error("Could not load NPCShip.tscn")
		return null
	
	var npc_ship = npc_ship_scene.instantiate()
	
	# Always use simplified AI now
	npc_ship.use_simplified_ai = true
	
	# Choose and apply archetype based on system or random
	var archetype = choose_archetype_for_system()
	var faction = choose_faction_for_archetype(archetype)
	npc_ship.configure_with_archetype(archetype, faction)
	
	# Configure with system settings
	var npc_config = system_traffic_config.get("npc_config", default_config.npc_config)
	npc_ship.configure_npc(npc_config)
	
	return npc_ship

func choose_archetype_for_system() -> NPCArchetype:
	"""Choose an appropriate archetype based on the current system"""
	var system_id = UniverseManager.current_system_id
	
	# System-specific spawning rules
	match system_id:
		"antares_system":  # Pirate haven
			if randf() < 0.7:  # 70% pirates
				return available_archetypes.get("pirate")
		"aldebaran_system":  # Military system
			if randf() < 0.6:  # 60% military
				return available_archetypes.get("military")
	
	# Default weighted selection
	var roll = randf()
	if roll < 0.5:  # 50% traders
		return available_archetypes.get("trader", create_default_archetype())
	elif roll < 0.7:  # 20% cowards
		return available_archetypes.get("coward", create_default_archetype())
	elif roll < 0.85:  # 15% military
		return available_archetypes.get("military", create_default_archetype())
	else:  # 15% pirates
		return available_archetypes.get("pirate", create_default_archetype())

func choose_faction_for_archetype(archetype: NPCArchetype) -> Government.Faction:
	"""Choose appropriate faction based on archetype"""
	if not archetype:
		return Government.Faction.INDEPENDENT
	
	match archetype.archetype_name.to_lower():
		"pirate":
			return Government.Faction.PIRATES
		"military":
			return Government.Faction.CONFEDERATION
		"trader", "coward":
			return Government.Faction.MERCHANT_GUILD if randf() < 0.3 else Government.Faction.INDEPENDENT
		_:
			return Government.Faction.INDEPENDENT

func create_default_archetype() -> NPCArchetype:
	"""Create a default archetype if none are loaded"""
	var default = NPCArchetype.new()
	default.archetype_name = "Default"
	default.aggression = 0.3
	default.bravery = 0.5
	default.flee_threshold = 0.3
	return default

# Add debug spawning method
func spawn_hostile_npc_near_player():
	"""Debug method to spawn a hostile NPC near the player"""
	var player = UniverseManager.player_ship
	if not player:
		print("No player ship found")
		return
	
	var npc_ship = create_npc_ship()
	if not npc_ship:
		return
	
	# Force pirate archetype
	var pirate_archetype = available_archetypes.get("pirate", create_default_archetype())
	npc_ship.configure_with_archetype(pirate_archetype, Government.Faction.PIRATES)
	
	# Position near player
	var spawn_offset = Vector2(randf_range(-500, 500), randf_range(-500, 500))
	if spawn_offset.length() < 200:
		spawn_offset = spawn_offset.normalized() * 300
	
	npc_ship.global_position = player.global_position + spawn_offset
	npc_ship.linear_velocity = Vector2.ZERO
	
	# Add to scene
	get_parent().add_child(npc_ship)
	current_npcs.append(npc_ship)
	
	print("Spawned hostile pirate near player at ", npc_ship.global_position)

func spawn_initial_npcs():
	"""Spawn NPCs already in the system when player arrives"""
	var max_npcs = system_traffic_config.get("max_npcs", default_config.max_npcs)
	var initial_count = max(1, max_npcs / 2)  # Spawn about half the max NPCs initially
	
	if debug_mode:
		print("TrafficManager: Spawning ", initial_count, " initial NPCs")
	
	var spawned_count = 0
	while spawned_count < initial_count:
		# Occasionally spawn formations/pairs
		if spawned_count < initial_count - 1 and randf() < 0.3:  # 30% chance for formation
			spawn_formation_pair()
			spawned_count += 2
		else:
			spawn_existing_npc()
			spawned_count += 1
		
		# Small delay between spawns to spread them out
		await get_tree().create_timer(0.1).timeout

func spawn_existing_npc():
	"""Spawn an NPC that's already been in the system for a while"""
	var npc_ship = create_npc_ship()
	if not npc_ship:
		return
	
	# Use call_deferred to avoid "busy setting up children" error
	get_parent().add_child.call_deferred(npc_ship)
	current_npcs.append(npc_ship)
	
	# Wait for the NPC to be added to the scene tree before configuring
	await get_tree().process_frame
	
	# Make sure the NPC is still valid after the frame wait
	if not is_instance_valid(npc_ship):
		return
	
	# Choose a random initial state and position
	var initial_state = choose_initial_npc_state()
	
	match initial_state:
		"visiting":
			spawn_npc_at_celestial_body(npc_ship)
		"traveling_to_planet":
			spawn_npc_traveling_to_planet(npc_ship)
		"traveling_to_exit":
			spawn_npc_traveling_to_exit(npc_ship)
		_:  # Default case including "mid_system"
			spawn_npc_mid_system(npc_ship)
	
	if debug_mode:
		print("TrafficManager: Spawned existing NPC in state: ", initial_state)

func spawn_formation_pair():
	"""Spawn two NPCs that will fly in formation"""
	var leader = create_npc_ship()
	var follower = create_npc_ship()
	
	if not leader or not follower:
		return
	
	# Add both to scene
	get_parent().add_child.call_deferred(leader)
	get_parent().add_child.call_deferred(follower)
	current_npcs.append(leader)
	current_npcs.append(follower)
	
	# Wait for them to be added to the scene tree
	await get_tree().process_frame
	
	if not is_instance_valid(leader) or not is_instance_valid(follower):
		return
	
	# Set up formation relationship
	follower.formation_leader = leader
	leader.formation_followers.append(follower)
	follower.formation_offset = Vector2(randf_range(-100, 100), randf_range(120, 180))
	
	# Choose formation spawn type
	var formation_type = choose_initial_npc_state()
	
	match formation_type:
		"visiting":
			spawn_formation_at_celestial_body(leader, follower)
		"traveling_to_planet":
			spawn_formation_traveling_to_planet(leader, follower)
		"traveling_to_exit":
			spawn_formation_traveling_to_exit(leader, follower)
		_:
			spawn_formation_mid_system(leader, follower)
	
	if debug_mode:
		print("TrafficManager: Spawned formation pair in state: ", formation_type)

func spawn_hyperspace_formation():
	"""Spawn a formation arriving from hyperspace"""
	var leader = create_npc_ship()
	var follower = create_npc_ship()
	
	if not leader or not follower:
		return
	
	# Calculate spawn data
	var spawn_data = calculate_hyperspace_entry()
	
	# Set up formation relationship
	follower.formation_leader = leader
	leader.formation_followers.append(follower)
	follower.formation_offset = Vector2(randf_range(-80, 80), randf_range(100, 150))
	
	# Position leader at spawn point
	leader.global_position = spawn_data.position
	leader.linear_velocity = spawn_data.velocity
	
	# Position follower in formation relative to leader
	var entry_direction = spawn_data.velocity.normalized()
	var formation_pos = spawn_data.position + follower.formation_offset.rotated(entry_direction.angle() - PI/2)
	follower.global_position = formation_pos
	follower.linear_velocity = spawn_data.velocity
	
	# Add to scene
	get_parent().add_child(leader)
	get_parent().add_child(follower)
	current_npcs.append(leader)
	current_npcs.append(follower)
	
	# Initialize hyperspace entry for leader
	leader.start_hyperspace_entry(spawn_data.position, spawn_data.velocity, spawn_data.origin_system)
	
	# Follower starts in formation mode
	follower.hyperspace_destination = spawn_data.origin_system
	follower.current_ai_state = follower.AIState.FORMATION_FLYING
	
	if debug_mode:
		print("TrafficManager: Spawned formation from hyperspace at ", spawn_data.position)

func choose_initial_npc_state() -> String:
	"""Choose what state the pre-existing NPC should be in"""
	var states = ["visiting", "traveling_to_planet", "traveling_to_exit", "mid_system"]
	var weights = [0.3, 0.3, 0.2, 0.2]  # 30% visiting, 30% traveling to planet, etc.
	
	var random_value = randf()
	var cumulative = 0.0
	
	for i in range(states.size()):
		cumulative += weights[i]
		if random_value <= cumulative:
			return states[i]
	
	return "mid_system"

func spawn_npc_at_celestial_body(npc_ship: NPCShip):
	"""Spawn NPC already visiting a celestial body"""
	var celestial_body = choose_random_celestial_body()
	if not celestial_body:
		# Fallback to mid-system spawn
		spawn_npc_mid_system(npc_ship)
		return
	
	# Position near the celestial body (but not exactly on it)
	var body_pos = celestial_body.global_position
	var offset_distance = randf_range(80, 150)  # Distance from the body
	var offset_angle = randf() * TAU
	var offset = Vector2.from_angle(offset_angle) * offset_distance
	
	npc_ship.global_position = body_pos + offset
	npc_ship.linear_velocity = Vector2.ZERO
	
	# Set NPC state to visiting
	npc_ship.target_celestial_body = celestial_body
	npc_ship.current_ai_state = npc_ship.AIState.VISITING_BODY
	npc_ship.visit_timer = randf_range(0, npc_ship.visit_duration * 0.8)  # Already been there a while

func spawn_formation_at_celestial_body(leader: NPCShip, follower: NPCShip):
	"""Spawn a formation near a celestial body"""
	var celestial_body = choose_random_celestial_body()
	if not celestial_body:
		spawn_formation_mid_system(leader, follower)
		return
	
	var body_pos = celestial_body.global_position
	var base_distance = randf_range(200, 300)
	var base_angle = randf() * TAU
	
	# Position leader
	leader.global_position = body_pos + Vector2.from_angle(base_angle) * base_distance
	leader.target_celestial_body = celestial_body
	leader.current_ai_state = leader.AIState.ORBITING_BODY
	leader.orbit_angle = base_angle
	leader.orbit_radius = base_distance
	
	# Position follower in formation
	var formation_pos = leader.global_position + follower.formation_offset
	follower.global_position = formation_pos
	follower.target_celestial_body = celestial_body
	follower.current_ai_state = follower.AIState.FORMATION_FLYING

func spawn_npc_traveling_to_planet(npc_ship: NPCShip):
	"""Spawn NPC traveling toward a celestial body"""
	var celestial_body = choose_random_celestial_body()
	if not celestial_body:
		spawn_npc_mid_system(npc_ship)
		return
	
	# Position somewhere between system edge and the celestial body
	var body_pos = celestial_body.global_position
	var system_center = Vector2.ZERO
	
	# Avoid spawning too close to system center
	var direction_to_body = (body_pos - system_center).normalized()
	var min_distance_from_center = 800.0  # Minimum distance from center
	
	# Random distance along the path, but not too close to center
	var distance_factor = randf_range(0.4, 0.8)  # Increased minimum from 0.3
	var planet_distance = max(min_distance_from_center, 2000 * distance_factor)
	
	# Calculate spawn position
	var spawn_pos = system_center + direction_to_body * planet_distance
	
	# Add some perpendicular offset to avoid straight lines
	var perpendicular = Vector2(-direction_to_body.y, direction_to_body.x)
	var side_offset = randf_range(-400, 400)
	spawn_pos += perpendicular * side_offset
	
	npc_ship.global_position = spawn_pos
	
	# Set velocity toward the planet
	var travel_speed = randf_range(200, 300)
	npc_ship.linear_velocity = (body_pos - npc_ship.global_position).normalized() * travel_speed
	
	# Set appropriate rotation
	npc_ship.rotation = npc_ship.linear_velocity.angle() - PI/2
	
	# Set NPC state
	npc_ship.target_celestial_body = celestial_body
	npc_ship.current_ai_state = npc_ship.AIState.FLYING_TO_TARGET

func spawn_formation_traveling_to_planet(leader: NPCShip, follower: NPCShip):
	"""Spawn a formation traveling toward a celestial body"""
	var celestial_body = choose_random_celestial_body()
	if not celestial_body:
		spawn_formation_mid_system(leader, follower)
		return
	
	# Position formation somewhere between system edge and celestial body
	var body_pos = celestial_body.global_position
	var system_center = Vector2.ZERO
	var direction_to_body = (body_pos - system_center).normalized()
	
	var distance_factor = randf_range(0.4, 0.7)
	var formation_distance = max(800.0, 2000 * distance_factor)
	var base_pos = system_center + direction_to_body * formation_distance
	
	# Set up leader
	leader.global_position = base_pos
	leader.target_celestial_body = celestial_body
	leader.current_ai_state = leader.AIState.FLYING_TO_TARGET
	
	var travel_speed = randf_range(180, 250)
	leader.linear_velocity = (body_pos - leader.global_position).normalized() * travel_speed
	leader.rotation = leader.linear_velocity.angle() - PI/2
	
	# Set up follower in formation
	var formation_pos = base_pos + follower.formation_offset.rotated(leader.rotation)
	follower.global_position = formation_pos
	follower.linear_velocity = leader.linear_velocity
	follower.rotation = leader.rotation
	follower.current_ai_state = follower.AIState.FORMATION_FLYING

func spawn_npc_traveling_to_exit(npc_ship: NPCShip):
	"""Spawn NPC traveling toward hyperspace exit"""
	var system_center = Vector2.ZERO
	var exit_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	# Position somewhere in mid-system, but avoid center
	var min_distance = 600.0  # Minimum distance from center
	var max_distance = 1500.0
	var exit_distance = randf_range(min_distance, max_distance)
	
	# Create a position that's not at the center
	var spawn_angle = randf() * TAU
	var spawn_offset = Vector2.from_angle(spawn_angle) * exit_distance
	npc_ship.global_position = system_center + spawn_offset
	
	# Set velocity toward exit (in a different direction than spawn position)
	var travel_speed = randf_range(150, 250)
	npc_ship.linear_velocity = exit_direction * travel_speed
	
	# Set appropriate rotation
	npc_ship.rotation = npc_ship.linear_velocity.angle() - PI/2
	
	# Set exit target
	npc_ship.target_position = system_center + exit_direction * 3500.0
	npc_ship.current_ai_state = npc_ship.AIState.FLYING_TO_EXIT

func spawn_formation_traveling_to_exit(leader: NPCShip, follower: NPCShip):
	"""Spawn a formation traveling toward hyperspace exit"""
	var system_center = Vector2.ZERO
	var exit_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	# Position formation in mid-system
	var formation_distance = randf_range(800, 1200)
	var spawn_angle = randf() * TAU
	var base_pos = system_center + Vector2.from_angle(spawn_angle) * formation_distance
	
	# Set up leader
	leader.global_position = base_pos
	leader.target_position = system_center + exit_direction * 3500.0
	leader.current_ai_state = leader.AIState.FLYING_TO_EXIT
	
	var travel_speed = randf_range(120, 200)
	leader.linear_velocity = exit_direction * travel_speed
	leader.rotation = leader.linear_velocity.angle() - PI/2
	
	# Set up follower in formation
	var formation_pos = base_pos + follower.formation_offset.rotated(leader.rotation)
	follower.global_position = formation_pos
	follower.linear_velocity = leader.linear_velocity
	follower.rotation = leader.rotation
	follower.target_position = leader.target_position
	follower.current_ai_state = follower.AIState.FORMATION_FLYING

func spawn_npc_mid_system(npc_ship: NPCShip):
	"""Spawn NPC in middle of system with random movement"""
	# NEVER spawn near origin - use ring spawning
	var min_radius = 1200.0  # Inner ring boundary
	var max_radius = 2000.0  # Outer ring boundary
	
	var spawn_radius = randf_range(min_radius, max_radius)
	var spawn_angle = randf() * TAU
	
	# Create vector from angle using cos/sin
	npc_ship.global_position = Vector2(cos(spawn_angle), sin(spawn_angle)) * spawn_radius
	
	# Velocity perpendicular to radius for orbiting motion
	var tangent_angle = spawn_angle + PI/2
	var travel_speed = randf_range(100, 200)
	
	# Create velocity vector from tangent angle
	npc_ship.linear_velocity = Vector2(cos(tangent_angle), sin(tangent_angle)) * travel_speed
	npc_ship.rotation = npc_ship.linear_velocity.angle() - PI/2
	
	# Choose a random celestial body to target
	var celestial_body = choose_random_celestial_body()
	if celestial_body:
		npc_ship.target_celestial_body = celestial_body
		npc_ship.current_ai_state = npc_ship.AIState.FLYING_TO_TARGET
	else:
		# No celestial bodies, head to exit
		var exit_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		npc_ship.target_position = Vector2.ZERO + exit_direction * 3500.0
		npc_ship.current_ai_state = npc_ship.AIState.FLYING_TO_EXIT

func spawn_formation_mid_system(leader: NPCShip, follower: NPCShip):
	"""Spawn a formation in the middle of the system"""
	var system_center = Vector2.ZERO
	var formation_distance = randf_range(700, 1200)
	var spawn_angle = randf() * TAU
	var base_pos = Vector2.from_angle(spawn_angle) * formation_distance
	
	# Set up leader
	leader.global_position = base_pos
	var travel_speed = randf_range(100, 180)
	var travel_angle = randf() * TAU
	leader.linear_velocity = Vector2.from_angle(travel_angle) * travel_speed
	leader.rotation = leader.linear_velocity.angle() - PI/2
	
	# Choose target for leader
	var celestial_body = choose_random_celestial_body()
	if celestial_body:
		leader.target_celestial_body = celestial_body
		leader.current_ai_state = leader.AIState.FLYING_TO_TARGET
	else:
		var exit_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		leader.target_position = system_center + exit_direction * 3500.0
		leader.current_ai_state = leader.AIState.FLYING_TO_EXIT
	
	# Set up follower in formation
	var formation_pos = base_pos + follower.formation_offset.rotated(leader.rotation)
	follower.global_position = formation_pos
	follower.linear_velocity = leader.linear_velocity
	follower.rotation = leader.rotation
	follower.current_ai_state = follower.AIState.FORMATION_FLYING

func choose_random_celestial_body() -> Node2D:
	"""Choose a random celestial body from the current system"""
	var system_scene = get_tree().get_first_node_in_group("system_scene")
	if not system_scene:
		return null
	
	var celestial_container = system_scene.get_node_or_null("CelestialBodies")
	if not celestial_container:
		return null
	
	var available_bodies = []
	for child in celestial_container.get_children():
		if child.has_method("can_interact"):
			available_bodies.append(child)
	
	if available_bodies.size() > 0:
		return available_bodies[randi() % available_bodies.size()]
	
	return null

func calculate_hyperspace_entry() -> Dictionary:
	"""Calculate where and how an NPC should enter from hyperspace"""
	var system_center = Vector2.ZERO
	var player_pos = Vector2.ZERO
	
	# Get player position for spawn distance calculations
	var player = UniverseManager.player_ship
	if player:
		player_pos = player.global_position
	
	# Choose origin system from connections
	var current_system = UniverseManager.get_current_system()
	var connections = current_system.get("connections", [])
	var origin_system = ""
	
	if connections.size() > 0:
		origin_system = connections[randi() % connections.size()]
	
	# Get direction from origin system
	var entry_direction = get_entry_direction_from_system(origin_system)
	
	# Calculate spawn position with safety checks
	var spawn_position = calculate_safe_spawn_position(system_center, player_pos, entry_direction)
	
	# Calculate entry velocity (coming toward system center)
	var entry_velocity = -entry_direction * randf_range(800.0, 1200.0)
	
	return {
		"position": spawn_position,
		"velocity": entry_velocity,
		"origin_system": origin_system
	}

func calculate_safe_spawn_position(system_center: Vector2, player_pos: Vector2, preferred_direction: Vector2) -> Vector2:
	"""Calculate a spawn position that's safe from player view and system center"""
	var min_distance_from_center = 2500.0  # INCREASED from 1500
	var min_distance_from_player = 1800.0  # INCREASED from 1200
	var ideal_spawn_distance = 3500.0      # Where we prefer to spawn
	
	# Start with preferred direction from connected system
	var direction = preferred_direction
	
	# Add slight randomization to prevent spawn clustering
	var angle_variance = randf_range(-PI/6, PI/6)  # ±30 degrees
	direction = direction.rotated(angle_variance)
	
	# Calculate spawn position
	var spawn_pos = system_center + direction * ideal_spawn_distance
	
	# Verify it's safe from player
	if spawn_pos.distance_to(player_pos) < min_distance_from_player:
		# Rotate 90 degrees and try again
		direction = direction.rotated(PI/2)
		spawn_pos = system_center + direction * ideal_spawn_distance
	
	return spawn_pos

func get_entry_direction_from_system(origin_system: String) -> Vector2:
	"""Get the direction an NPC should come from based on origin system"""
	if origin_system == "":
		# Random direction if no origin
		return Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	# Use hyperspace map positions to get realistic entry direction
	var system_positions = get_system_positions()
	var current_system_id = UniverseManager.current_system_id
	
	if current_system_id in system_positions and origin_system in system_positions:
		var current_pos = system_positions[current_system_id]
		var origin_pos = system_positions[origin_system]
		# Direction FROM origin TO current (so NPC comes from origin direction)
		return (current_pos - origin_pos).normalized()
	
	# Fallback to random direction
	return Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func get_system_positions() -> Dictionary:
	"""Get system positions from universe.json data"""
	var positions = {}
	var systems_data = UniverseManager.universe_data.get("systems", {})
	var map_width = 480
	var map_height = 500 
	var margin = 50
	
	for system_id in systems_data:
		var system_data = systems_data[system_id]
		var map_pos = system_data.get("map_position", {"x": 0.5, "y": 0.5})
		positions[system_id] = Vector2(
			margin + map_width * map_pos.x,
			margin + map_height * map_pos.y
		)
	
	return positions

func reset_spawn_timer():
	"""Reset the spawn timer with variance"""
	var base_frequency = system_traffic_config.get("spawn_frequency", default_config.spawn_frequency)
	var variance = system_traffic_config.get("spawn_frequency_variance", default_config.spawn_frequency_variance)
	
	var random_offset = randf_range(-variance, variance)
	spawn_timer = max(1.0, base_frequency + random_offset)  # Minimum 1 second between spawns
	
	if debug_mode:
		print("TrafficManager: Next spawn in ", spawn_timer, " seconds")

func cleanup_distant_npcs():
	"""Remove NPCs that have traveled too far from the system"""
	var system_center = Vector2.ZERO
	var cleanup_distance = spawn_distance * 1.5  # Give extra room before cleanup
	
	for i in range(current_npcs.size() - 1, -1, -1):
		var npc = current_npcs[i]
		if not is_instance_valid(npc):
			current_npcs.remove_at(i)
			continue
		
		var distance_from_center = npc.global_position.distance_to(system_center)
		if distance_from_center > cleanup_distance:
			if debug_mode:
				print("TrafficManager: Cleaning up distant NPC at distance ", distance_from_center)
			npc.cleanup_and_remove()
			current_npcs.remove_at(i)

func _on_system_changed(system_id: String):
	"""Handle system changes"""
	# Clear existing NPCs
	cleanup_all_npcs()
	
	# Load new system configuration
	load_system_traffic_config(system_id)
	
	# Spawn initial NPCs to populate the system
	spawn_initial_npcs()
	
	# Activate traffic for new system
	active = true
	
	# Reset spawn timer for new system
	reset_spawn_timer()
	
	if debug_mode:
		print("TrafficManager: System changed to ", system_id, " - Config: ", system_traffic_config)

func load_system_traffic_config(_system_id: String):
	"""Load traffic configuration for the specified system"""
	var system_data = UniverseManager.get_current_system()
	system_traffic_config = system_data.get("traffic", {})
	
	# Merge with defaults
	for key in default_config:
		if not system_traffic_config.has(key):
			system_traffic_config[key] = default_config[key]
	
	# Merge NPC config specifically
	if system_traffic_config.has("npc_config") and default_config.has("npc_config"):
		var merged_npc_config = default_config.npc_config.duplicate()
		for key in system_traffic_config.npc_config:
			merged_npc_config[key] = system_traffic_config.npc_config[key]
		system_traffic_config.npc_config = merged_npc_config
	elif not system_traffic_config.has("npc_config"):
		system_traffic_config.npc_config = default_config.npc_config

func cleanup_all_npcs():
	"""Remove all current NPCs (used when changing systems)"""
	for npc in current_npcs:
		if is_instance_valid(npc):
			# Use call_deferred to avoid tree access issues during system changes
			npc.call_deferred("queue_free")
	current_npcs.clear()

func _on_npc_removed(npc: NPCShip):
	"""Called by NPCs when they remove themselves"""
	current_npcs.erase(npc)
	if debug_mode:
		print("TrafficManager: NPC removed, ", current_npcs.size(), " remaining")

func set_debug_mode(_enabled: bool):
	"""Enable/disable debug mode"""
	debug_mode = _enabled
	queue_redraw()

func _draw():
	"""Debug visualization"""
	if not debug_mode:
		return
	
	var system_center = Vector2.ZERO
	
	# Draw spawn circle
	draw_arc(system_center, spawn_distance, 0, TAU, 64, Color.GREEN, 3.0)
	
	# Draw cleanup circle
	var cleanup_distance = spawn_distance * 1.5
	draw_arc(system_center, cleanup_distance, 0, TAU, 64, Color.RED, 2.0)
	
	# Draw NPC positions and states
	var font = ThemeDB.fallback_font
	for i in range(current_npcs.size()):
		var npc = current_npcs[i]
		if not is_instance_valid(npc):
			continue
		
		var local_pos = to_local(npc.global_position)
		draw_circle(local_pos, 8.0, Color.YELLOW)
		
		# Draw NPC info
		var npc_info = "NPC " + str(i) + "\n" + NPCShip.AIState.keys()[npc.current_ai_state]
		draw_string(font, local_pos + Vector2(10, 0), npc_info, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	
	# Draw spawn timer info
	var timer_info = "Spawn in: " + str(round(spawn_timer * 10) / 10.0) + "s\nNPCs: " + str(current_npcs.size()) + "/" + str(system_traffic_config.get("max_npcs", 0))
	draw_string(font, Vector2(-200, -200), timer_info, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.CYAN)
