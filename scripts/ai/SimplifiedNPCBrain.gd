# =============================================================================
# FIXED SIMPLIFIED NPC BRAIN - More dynamic and less sticky behavior
# =============================================================================

extends Node
class_name SimplifiedNPCBrain

@export var archetype: NPCArchetype
@export var faction: Government.Faction = Government.Faction.INDEPENDENT

var owner_ship: NPCShip
var current_goal: String = "idle"
var target: Node2D
var flee_target: Node2D
var destination: Node2D
var detection_radius: float = 1500.0
var attack_range: float = 800.0
var flee_distance: float = 1200.0

# FIXED: More responsive movement parameters
var desired_rotation: float = 0.0
var rotation_smoothing: float = 0.25  # Increased responsiveness
var heading_tolerance: float = 0.2     # Tighter tolerance
var min_turn_threshold: float = 0.05   # Lower threshold

# Combat state
var last_fire_time: float = 0.0
var fire_cooldown: float = 0.5

# FIXED: Reduced goal persistence for more dynamic behavior
var goal_lock_timer: float = 0.0
var min_goal_duration: float = 1.0  # Reduced from 2.0
var boredom_timer: float = 0.0      # New: gets bored of current activity

func _ready():
	owner_ship = get_parent()

func think(delta: float):
	if not owner_ship:
		return
	
	# Create default archetype if none exists
	if not archetype:
		archetype = create_default_archetype()
	
	# Update timers
	goal_lock_timer -= delta
	boredom_timer += delta
	
	# Player-centric optimization
	var player = UniverseManager.player_ship
	if not player:
		return
	
	var distance_to_player = owner_ship.global_position.distance_to(player.global_position)
	
	# Far from player - simple behavior but still some variety
	if distance_to_player > 3000:
		if current_goal == "idle" or (boredom_timer > 8.0 and randf() < 0.1):
			current_goal = choose_distant_behavior()
			boredom_timer = 0.0
		return
	
	# FIXED: More frequent goal evaluation when near player
	if goal_lock_timer <= 0 or boredom_timer > 6.0:
		evaluate_situation()
		boredom_timer = 0.0

func choose_distant_behavior() -> String:
	"""Choose behavior when far from player"""
	var behaviors = ["wander", "travel", "exit_system"]
	var weights = [0.5, 0.3, 0.2]
	
	var roll = randf()
	var cumulative = 0.0
	
	for i in range(behaviors.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return behaviors[i]
	
	return "wander"

func evaluate_situation():
	var threats = detect_threats()
	var opportunities = detect_opportunities()
	var destinations = find_destinations()
	
	var old_goal = current_goal
	
	# FIXED: More balanced priority system with variety
	if threats.size() > 0 and should_flee():
		current_goal = "flee"
		flee_target = threats[0]
		target = null
		destination = null
		lock_goal(1.5)  # Shorter lock
		print("NPC fleeing from threat!")
		
	elif opportunities.size() > 0 and should_attack():
		current_goal = "attack"
		target = opportunities[0]
		flee_target = null
		destination = null
		lock_goal(2.0)
		print("NPC attacking target!")
		
	elif destinations.size() > 0 and should_visit_destination():
		current_goal = "travel"
		destination = destinations[0]
		target = null
		flee_target = null
		lock_goal(3.0)  # Medium lock for travel
		print("NPC traveling to: ", destination.celestial_data.get("name", "destination"))
		
	elif randf() < 0.15:  # 15% chance to leave system
		current_goal = "exit_system"
		destination = null
		target = null
		flee_target = null
		lock_goal(8.0)  # Commit to leaving
		print("NPC deciding to leave system")
		
	else:
		current_goal = "wander"
		target = null
		flee_target = null
		destination = null
		# Shorter wander periods
		lock_goal(0.5)
	
	if old_goal != current_goal:
		print("NPC [", owner_ship.name, "] goal changed: ", old_goal, " -> ", current_goal)

func should_visit_destination() -> bool:
	"""Decide if we should visit a destination"""
	# More likely to visit if we're a trader, less if we're military/pirate
	match faction:
		Government.Faction.MERCHANT_GUILD, Government.Faction.INDEPENDENT:
			return randf() < 0.6  # 60% chance
		Government.Faction.CONFEDERATION:
			return randf() < 0.3  # 30% chance (patrol more)
		Government.Faction.PIRATES:
			return randf() < 0.2  # 20% chance (hunt more)
		_:
			return randf() < 0.4  # 40% default

func lock_goal(duration: float = -1):
	"""Lock the current goal for a minimum duration"""
	if duration > 0:
		goal_lock_timer = duration
	else:
		goal_lock_timer = min_goal_duration

# FIXED: Better wander behavior with more variety
func get_wander_command() -> Dictionary:
	"""More interesting wandering with dynamic target selection"""
	
	# Initialize wander state if needed
	if not owner_ship.has_meta("wander_timer"):
		reset_wander_state()
	
	var wander_timer = owner_ship.get_meta("wander_timer")
	wander_timer += get_physics_process_delta_time()
	owner_ship.set_meta("wander_timer", wander_timer)
	
	# Change wander pattern more frequently
	if wander_timer > randf_range(2.0, 4.0):  # Reduced from 3-6 seconds
		reset_wander_state()
		
		# FIXED: More interesting wander behaviors
		var behavior_roll = randf()
		if behavior_roll < 0.3:
			# Circle around system center
			var center_dir = (Vector2.ZERO - owner_ship.global_position).normalized()
			var tangent = Vector2(-center_dir.y, center_dir.x)
			var heading = tangent.angle() + PI/2
			owner_ship.set_meta("wander_target_heading", heading)
			owner_ship.set_meta("wander_thrust", randf_range(0.4, 0.7))
			owner_ship.set_meta("wander_type", "circle")
			
		elif behavior_roll < 0.6:
			# Head toward a random point
			var random_point = Vector2(randf_range(-2000, 2000), randf_range(-2000, 2000))
			var direction = (random_point - owner_ship.global_position).normalized()
			owner_ship.set_meta("wander_target_heading", direction.angle() + PI/2)
			owner_ship.set_meta("wander_thrust", randf_range(0.3, 0.8))
			owner_ship.set_meta("wander_type", "point")
			
		else:
			# Random drift
			owner_ship.set_meta("wander_target_heading", randf() * TAU)
			owner_ship.set_meta("wander_thrust", randf_range(0.1, 0.5))
			owner_ship.set_meta("wander_type", "drift")
	
	# Execute wander behavior
	var wander_type = owner_ship.get_meta("wander_type", "drift")
	var target_heading = owner_ship.get_meta("wander_target_heading", 0.0)
	var thrust = owner_ship.get_meta("wander_thrust", 0.3)
	
	match wander_type:
		"circle", "point":
			return {
				"thrust": thrust,
				"turn": calculate_smooth_turn(target_heading),
				"fire": false
			}
		_: # drift
			return {
				"thrust": thrust,
				"turn": owner_ship.get_meta("wander_turn", 0.0),
				"fire": false
			}

func reset_wander_state():
	"""Reset wander behavior state"""
	owner_ship.set_meta("wander_timer", 0.0)
	owner_ship.set_meta("wander_thrust", randf_range(0.2, 0.8))
	owner_ship.set_meta("wander_turn", randf_range(-0.5, 0.5))
	owner_ship.set_meta("wander_type", "drift")

# FIXED: Better travel command with arrival detection
func get_travel_command(dest: Node2D) -> Dictionary:
	var to_destination = dest.global_position - owner_ship.global_position
	var distance = to_destination.length()
	var direction = to_destination.normalized()
	
	# FIXED: Better arrival detection and next action
	if distance < 200:  # Increased arrival threshold
		print("NPC arrived at destination, choosing next action")
		
		# Choose what to do at the destination
		var action_roll = randf()
		if action_roll < 0.4:
			# Orbit/visit the destination
			owner_ship.target_celestial_body = dest
			owner_ship.current_ai_state = owner_ship.AIState.VISITING_BODY
			current_goal = "idle"  # Let the old AI system take over briefly
		else:
			# Just keep wandering
			current_goal = "wander"
		
		return {"thrust": 0.0, "turn": 0.0, "fire": false}
	
	var desired_heading = direction.angle() + PI/2
	
	# FIXED: Better speed control for approach
	var thrust = 1.0
	if distance < 800:  # Start slowing down earlier
		thrust = max(0.2, distance / 800)
	
	return {
		"thrust": thrust,
		"turn": calculate_smooth_turn(desired_heading),
		"fire": false
	}

# FIXED: More responsive turning calculation
func calculate_smooth_turn(desired_heading: float) -> float:
	"""Calculate smooth turning with improved responsiveness"""
	var current_heading = owner_ship.rotation
	var angle_diff = angle_difference(current_heading, desired_heading)
	
	# Smaller dead zone for more responsive turning
	if abs(angle_diff) < heading_tolerance:
		return 0.0
	
	# More aggressive turning for better responsiveness
	var turn_strength = clamp(angle_diff * 3.0, -1.0, 1.0)  # Increased from 2.0
	
	# Less smoothing for more responsive movement
	return turn_strength * rotation_smoothing

# Add the missing functions from the original
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

func detect_threats() -> Array:
	var threats = []
	var ships_in_range = get_ships_in_radius(detection_radius)
	
	for ship in ships_in_range:
		if is_threat(ship):
			threats.append(ship)
	
	return threats

func detect_opportunities() -> Array:
	var opportunities = []
	var ships_in_range = get_ships_in_radius(detection_radius)
	
	for ship in ships_in_range:
		if is_opportunity(ship):
			opportunities.append(ship)
	
	return opportunities

func find_destinations() -> Array:
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
			if distance < 2500 and distance > 150:  # Slightly wider range
				destinations.append(body)
	
	return destinations

func get_ships_in_radius(radius: float) -> Array:
	var ships = []
	
	var player = UniverseManager.player_ship
	if player and owner_ship.global_position.distance_to(player.global_position) <= radius:
		ships.append(player)
	
	var npcs = get_tree().get_nodes_in_group("npc_ships")
	for npc in npcs:
		if npc != owner_ship and is_instance_valid(npc):
			if owner_ship.global_position.distance_to(npc.global_position) <= radius:
				ships.append(npc)
	
	return ships

func is_threat(ship: Node2D) -> bool:
	if not ship or not archetype:
		return false
	return is_hostile_to(ship)

func is_opportunity(ship: Node2D) -> bool:
	if not ship or not archetype:
		return false
	if archetype.aggression < 0.4:
		return false
	return is_valid_target(ship)

func is_hostile_to(ship: Node2D) -> bool:
	if ship == UniverseManager.player_ship:
		return faction == Government.Faction.PIRATES
	return false

func is_valid_target(ship: Node2D) -> bool:
	if faction == Government.Faction.PIRATES:
		return true
	return is_hostile_to(ship)

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
	var command = {"thrust": 0.0, "turn": 0.0, "fire": false}
	
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
		"wander", _:
			command = get_wander_command()
	
	return command

func get_flee_command(threat: Node2D) -> Dictionary:
	var flee_direction = (owner_ship.global_position - threat.global_position).normalized()
	var desired_heading = flee_direction.angle() + PI/2
	
	return {
		"thrust": 1.0,
		"turn": calculate_smooth_turn(desired_heading),
		"fire": false
	}

func get_attack_command(target_ship: Node2D) -> Dictionary:
	var to_target = target_ship.global_position - owner_ship.global_position
	var distance = to_target.length()
	var direction = to_target.normalized()
	
	var command = {"thrust": 0.0, "turn": 0.0, "fire": false}
	
	if distance > attack_range * 0.8:
		var desired_heading = direction.angle() + PI/2
		command.thrust = 0.8
		command.turn = calculate_smooth_turn(desired_heading)
	elif distance < attack_range * 0.3:
		var desired_heading = (-direction).angle() + PI/2
		command.thrust = 0.5
		command.turn = calculate_smooth_turn(desired_heading)
	else:
		var tangent = Vector2(-direction.y, direction.x)
		var desired_heading = tangent.angle() + PI/2
		command.thrust = 0.6
		command.turn = calculate_smooth_turn(desired_heading)
	
	if distance < attack_range:
		var facing_dir = Vector2.UP.rotated(owner_ship.rotation)
		var dot = facing_dir.dot(direction)
		if dot > 0.7:
			command.fire = true
	
	return command

func get_exit_command() -> Dictionary:
	var exit_direction = Vector2.from_angle(randf() * TAU)
	var desired_heading = exit_direction.angle() + PI/2
	
	var distance_from_center = owner_ship.global_position.length()
	
	if distance_from_center > 3000:
		if owner_ship.has_method("start_hyperspace_exit"):
			owner_ship.start_hyperspace_exit()
		return {"thrust": 0.0, "turn": 0.0, "fire": false}
	else:
		return {
			"thrust": 1.0,
			"turn": calculate_smooth_turn(desired_heading),
			"fire": false
		}

func angle_difference(from: float, to: float) -> float:
	var diff = to - from
	while diff > PI:
		diff -= TAU
	while diff < -PI:
		diff += TAU
	return diff
