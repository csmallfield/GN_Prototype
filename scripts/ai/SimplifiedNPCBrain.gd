# SimplifiedNPCBrain.gd - Enhanced version with combat and smooth movement
extends Node
class_name SimplifiedNPCBrain

@export var archetype: NPCArchetype
@export var faction: Government.Faction = Government.Faction.INDEPENDENT

var owner_ship: NPCShip
var current_goal: String = "idle"
var target: Node2D
var flee_target: Node2D
var destination: Node2D  # For traveling to planets/stations
var detection_radius: float = 1500.0
var attack_range: float = 800.0
var flee_distance: float = 1200.0

# Smooth movement parameters
var desired_rotation: float = 0.0
var rotation_smoothing: float = 0.15
var heading_tolerance: float = 0.3  # Radians - stops micro-corrections
var min_turn_threshold: float = 0.1  # Minimum angle before turning

# Combat state
var last_fire_time: float = 0.0
var fire_cooldown: float = 0.5  # Seconds between shots

# Goal persistence to reduce jittery behavior
var goal_lock_timer: float = 0.0
var min_goal_duration: float = 2.0  # Minimum seconds before changing goals

func _ready():
	owner_ship = get_parent()
	

func create_default_archetype() -> NPCArchetype:
	var default = NPCArchetype.new()
	default.archetype_name = "Default"
	default.aggression = 0.3
	default.bravery = 0.5
	default.greed = 0.5
	default.loyalty = 0.5
	default.flee_threshold = 0.3
	default.attack_weak_targets = 0.2
	return default

func think(delta: float):
	if not owner_ship:
		return
	
	# Create default archetype if none exists
	if not archetype:
		archetype = create_default_archetype()
	
	# Update timers
	goal_lock_timer -= delta
	
	# Player-centric optimization
	var player = UniverseManager.player_ship
	if not player:
		return
	
	var distance_to_player = owner_ship.global_position.distance_to(player.global_position)
	
	# Far from player - simple behavior
	if distance_to_player > 3000:
		if current_goal == "idle":
			current_goal = "wander"
		return
	
	# Can we change goals?
	if goal_lock_timer <= 0:
		evaluate_situation()

func evaluate_situation():
	var threats = detect_threats()
	var opportunities = detect_opportunities()
	var destinations = find_destinations()
	
	var old_goal = current_goal
	
	# Priority-based goal selection with more variety
	if threats.size() > 0 and should_flee():
		current_goal = "flee"
		flee_target = threats[0]
		target = null
		destination = null
		lock_goal()
		print("NPC fleeing from threat!")
	elif opportunities.size() > 0 and should_attack():
		current_goal = "attack"
		target = opportunities[0]
		flee_target = null
		destination = null
		lock_goal()
		print("NPC attacking target!")
	elif destinations.size() > 0 and randf() < 0.6:  # 60% chance to visit planets
		current_goal = "travel"
		destination = destinations[0]
		target = null
		flee_target = null
		lock_goal(5.0)  # Longer lock for travel
		print("NPC traveling to: ", destination.name if destination.has_method("get_name") else "destination")
	else:
		current_goal = "wander"
		target = null
		flee_target = null
		destination = null
		# Don't lock wander, allow quick transitions
	
	if old_goal != current_goal:
		print("NPC [", owner_ship.name, "] goal changed: ", old_goal, " -> ", current_goal)
	# Add to evaluate_situation after the travel check:
	elif randf() < 0.1 and goal_lock_timer <= 0:  # 10% chance to leave system
		current_goal = "exit_system"
		destination = null
		target = null
		flee_target = null
		lock_goal(10.0)  # Commit to leaving
		print("NPC deciding to leave system")

# Add this new function:
func get_exit_command() -> Dictionary:
	"""Command to leave the system via hyperspace"""
	# Pick a random direction away from center
	var exit_direction = Vector2.from_angle(randf() * TAU)
	var desired_heading = exit_direction.angle() + PI/2
	
	# Check distance from center
	var distance_from_center = owner_ship.global_position.length()
	
	if distance_from_center > 3000:  # Far enough to jump
		# Trigger hyperspace exit in the ship
		if owner_ship.has_method("start_hyperspace_exit"):
			owner_ship.start_hyperspace_exit()
		return {"thrust": 0.0, "turn": 0.0, "fire": false}
	else:
		# Head toward exit point
		return {
			"thrust": 1.0,
			"turn": calculate_smooth_turn(desired_heading),
			"fire": false
		}


func lock_goal(duration: float = -1):
	"""Lock the current goal for a minimum duration"""
	if duration > 0:
		goal_lock_timer = duration
	else:
		goal_lock_timer = min_goal_duration

func detect_threats() -> Array:
	var threats = []
	var ships_in_range = get_ships_in_radius(detection_radius)
	
	for ship in ships_in_range:
		if is_threat(ship):
			threats.append(ship)
	
	# Sort by distance
	threats.sort_custom(func(a, b): 
		return owner_ship.global_position.distance_to(a.global_position) < owner_ship.global_position.distance_to(b.global_position)
	)
	
	return threats

func detect_opportunities() -> Array:
	var opportunities = []
	var ships_in_range = get_ships_in_radius(detection_radius)
	
	for ship in ships_in_range:
		if is_opportunity(ship):
			opportunities.append(ship)
	
	return opportunities

func find_destinations() -> Array:
	"""Find nearby planets/stations to visit"""
	var destinations = []
	var system_scene = get_tree().get_first_node_in_group("system_scene")
	if not system_scene:
		return destinations
	
	var celestial_container = system_scene.get_node_or_null("CelestialBodies")
	if not celestial_container:
		return destinations
	
	for body in celestial_container.get_children():
		if body.has_method("can_interact"):
			var distance = owner_ship.global_position.distance_to(body.global_position)
			if distance < 2000 and distance > 200:  # Not too close, not too far
				destinations.append(body)
	
	# Sort by distance
	destinations.sort_custom(func(a, b):
		return owner_ship.global_position.distance_to(a.global_position) < owner_ship.global_position.distance_to(b.global_position)
	)
	
	return destinations

func get_ships_in_radius(radius: float) -> Array:
	var ships = []
	
	# Check player
	var player = UniverseManager.player_ship
	if player and owner_ship.global_position.distance_to(player.global_position) <= radius:
		ships.append(player)
	
	# Check other NPCs
	var npcs = get_tree().get_nodes_in_group("npc_ships")
	for npc in npcs:
		if npc != owner_ship and is_instance_valid(npc):
			if owner_ship.global_position.distance_to(npc.global_position) <= radius:
				ships.append(npc)
	
	return ships

func is_threat(ship: Node2D) -> bool:
	if not ship or not archetype:
		return false
	
	# Check if the ship is hostile to us
	if is_hostile_to(ship):
		# It's a threat if it's stronger than us or we're low on health
		var our_strength = calculate_combat_strength(owner_ship)
		var their_strength = calculate_combat_strength(ship)
		
		if their_strength > our_strength * archetype.bravery:
			return true
	
	return false

func is_opportunity(ship: Node2D) -> bool:
	if not ship or not archetype:
		return false
	
	# Only aggressive NPCs see opportunities
	if archetype.aggression < 0.4:
		return false
	
	# Is it hostile or a valid target?
	if not is_valid_target(ship):
		return false
	
	# Is it weaker than us?
	var our_strength = calculate_combat_strength(owner_ship)
	var their_strength = calculate_combat_strength(ship)
	
	# Attack if we're stronger (modified by aggression)
	return our_strength > their_strength * (2.0 - archetype.aggression)

func is_hostile_to(ship: Node2D) -> bool:
	# For now, simple faction check
	if ship == UniverseManager.player_ship:
		# Pirates are hostile to player
		return faction == Government.Faction.PIRATES
	
	# Could expand with faction relationships later
	return false

func is_valid_target(ship: Node2D) -> bool:
	# Pirates attack anyone
	if faction == Government.Faction.PIRATES:
		return true
	
	# Others only attack hostile ships
	return is_hostile_to(ship)

func calculate_combat_strength(ship: Node2D) -> float:
	"""Calculate relative combat strength of a ship"""
	var strength = 100.0
	
	if ship.has_method("get_hull_percent"):
		strength *= ship.get_hull_percent()
	
	# Could factor in weapons, shields, etc.
	return strength

func should_flee() -> bool:
	if not owner_ship or not archetype:
		return false
	
	var hull_percent = owner_ship.get_hull_percent()
	return hull_percent < archetype.flee_threshold

func should_attack() -> bool:
	if not archetype:
		return false
	return randf() < archetype.attack_weak_targets

func get_movement_command() -> Dictionary:
	"""Get movement commands for the owner ship based on current goal"""
	var command = {
		"thrust": 0.0,
		"turn": 0.0,
		"fire": false
	}
	
	match current_goal:
		"flee":
			if flee_target and is_instance_valid(flee_target):
				command = get_flee_command(flee_target)
		"attack":
			if target and is_instance_valid(target):
				command = get_attack_command(target)
		"travel":
			if destination and is_instance_valid(destination):
				command = get_travel_command(destination)
		"exit_system":
			command = get_exit_command()
		"wander":
			command = get_wander_command()
	
	return command

func get_flee_command(threat: Node2D) -> Dictionary:
	var flee_direction = (owner_ship.global_position - threat.global_position).normalized()
	var desired_heading = flee_direction.angle() + PI/2
	
	return {
		"thrust": 1.0,  # Full speed away
		"turn": calculate_smooth_turn(desired_heading),
		"fire": false
	}

func get_attack_command(target_ship: Node2D) -> Dictionary:
	var to_target = target_ship.global_position - owner_ship.global_position
	var distance = to_target.length()
	var direction = to_target.normalized()
	
	var command = {"thrust": 0.0, "turn": 0.0, "fire": false}
	
	# Approach if too far
	if distance > attack_range * 0.8:
		var desired_heading = direction.angle() + PI/2
		command.thrust = 0.8
		command.turn = calculate_smooth_turn(desired_heading)
	# Back off if too close
	elif distance < attack_range * 0.3:
		var desired_heading = (-direction).angle() + PI/2
		command.thrust = 0.5
		command.turn = calculate_smooth_turn(desired_heading)
	# Circle strafe at optimal range
	else:
		# Orbit around target
		var tangent = Vector2(-direction.y, direction.x)
		var desired_heading = tangent.angle() + PI/2
		command.thrust = 0.6
		command.turn = calculate_smooth_turn(desired_heading)
	
	# Fire if facing target and in range
	if distance < attack_range:
		var facing_dir = Vector2.UP.rotated(owner_ship.rotation)
		var dot = facing_dir.dot(direction)
		if dot > 0.7:  # Facing within ~45 degrees
			command.fire = true
	
	return command

func get_travel_command(dest: Node2D) -> Dictionary:
	var to_destination = dest.global_position - owner_ship.global_position
	var distance = to_destination.length()
	var direction = to_destination.normalized()
	
	# Arrived?
	if distance < 150:
		current_goal = "wander"
		return {"thrust": 0.0, "turn": 0.0, "fire": false}
	
	var desired_heading = direction.angle() + PI/2
	
	# Slow down when approaching
	var thrust = 1.0
	if distance < 500:
		thrust = max(0.3, distance / 500)
	
	return {
		"thrust": thrust,
		"turn": calculate_smooth_turn(desired_heading),
		"fire": false
	}

# Replace the get_wander_command function in SimplifiedNPCBrain.gd

func get_wander_command() -> Dictionary:
	# More interesting wandering behavior
	if not owner_ship.has_meta("wander_timer"):
		owner_ship.set_meta("wander_timer", 0.0)
		owner_ship.set_meta("wander_thrust", randf_range(0.3, 0.7))
		owner_ship.set_meta("wander_turn", randf_range(-0.3, 0.3))
	
	var wander_timer = owner_ship.get_meta("wander_timer")
	wander_timer += get_physics_process_delta_time()
	
	# Change wander pattern every 3-6 seconds
	if wander_timer > randf_range(3.0, 6.0):
		owner_ship.set_meta("wander_timer", 0.0)
		owner_ship.set_meta("wander_thrust", randf_range(0.2, 0.8))
		owner_ship.set_meta("wander_turn", randf_range(-0.5, 0.5))
		
		# Sometimes stop and turn
		if randf() < 0.3:
			owner_ship.set_meta("wander_thrust", 0.0)
			owner_ship.set_meta("wander_turn", randf_range(-1.0, 1.0))
	else:
		owner_ship.set_meta("wander_timer", wander_timer)
	
	return {
		"thrust": owner_ship.get_meta("wander_thrust"),
		"turn": owner_ship.get_meta("wander_turn"),
		"fire": false
	}

func calculate_smooth_turn(desired_heading: float) -> float:
	"""Calculate smooth turning with dead zones to prevent wobbling"""
	var current_heading = owner_ship.rotation
	var angle_diff = angle_difference(current_heading, desired_heading)
	
	# Dead zone - don't turn if we're close enough
	if abs(angle_diff) < heading_tolerance:
		return 0.0
	
	# Smooth turning with proper clamping
	var turn_strength = clamp(angle_diff * 2.0, -1.0, 1.0)
	
	# Apply smoothing
	return turn_strength * rotation_smoothing

func angle_difference(from: float, to: float) -> float:
	"""Calculate shortest angle difference between two angles"""
	var diff = to - from
	while diff > PI:
		diff -= TAU
	while diff < -PI:
		diff += TAU
	return diff
