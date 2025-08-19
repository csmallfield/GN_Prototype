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
	
	# Make sure we have an archetype
	if not archetype:
		push_warning("NPCBrain has no archetype! Creating default...")
		archetype = create_default_archetype()

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
	
	# Priority-based goal selection
	if threats.size() > 0 and should_flee():
		current_goal = "flee"
		flee_target = threats[0]
		target = null
		lock_goal()
	elif opportunities.size() > 0 and should_attack():
		current_goal = "attack"
		target = opportunities[0]
		flee_target = null
		lock_goal()
	elif destinations.size() > 0 and randf() < 0.7:  # 70% chance to visit planets
		current_goal = "travel"
		destination = destinations[0]
		target = null
		flee_target = null
		lock_goal(3.0)  # Longer lock for travel
	else:
		current_goal = "wander"
		target = null
		flee_target = null
	
	if old_goal != current_goal:
		print("NPC goal changed: ", old_goal, " -> ", current_goal)

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

func get_wander_command() -> Dictionary:
	# Simple wandering behavior
	if not owner_ship.has_meta("wander_target"):
		# Pick a random point
		var angle = randf() * TAU
		var distance = randf_range(500, 1500)
		var wander_pos = owner_ship.global_position + Vector2.from_angle(angle) * distance
		owner_ship.set_meta("wander_target", wander_pos)
	
	var wander_target = owner_ship.get_meta("wander_target")
	var to_target = wander_target - owner_ship.global_position
	
	# Reached wander target?
	if to_target.length() < 200:
		owner_ship.remove_meta("wander_target")
		return {"thrust": 0.3, "turn": 0.0, "fire": false}
	
	var desired_heading = to_target.normalized().angle() + PI/2
	
	return {
		"thrust": 0.5,
		"turn": calculate_smooth_turn(desired_heading),
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
