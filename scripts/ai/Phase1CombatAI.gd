# =============================================================================
# PHASE 2 COMBAT AI - Enhanced with Behavior Trees and Archetypes - FIXED
# =============================================================================
extends Node
class_name Phase1CombatAI

# Explicit preloads to ensure classes are available
const BehaviorTreeClass = preload("res://scripts/ai/BehaviorTree.gd")
const BehaviorNodeClass = preload("res://scripts/ai/BehaviorNode.gd")
const AIArchetypeClass = preload("res://scripts/ai/AIArchetype.gd")

var owner_ship: RigidBody2D
var attacker: Node2D = null
var state: String = "peaceful"

# Phase 2 components
var behavior_tree
var archetype
var current_destination: Vector2
var current_activity: String = "idle"

# Enhanced parameters
var detection_range: float = 800.0
var attack_range: float = 500.0
var flee_threshold: float = 0.3

# Peaceful behavior state
var patrol_waypoints: Array[Vector2] = []
var current_waypoint: int = 0
var waypoint_pause_timer: float = 0.0
var last_destination_time: float = 0.0
var destination_change_interval: float = 30.0

func _ready():
	owner_ship = get_parent()
	
	# Assign random archetype for now
	assign_random_archetype()
	
	# Create behavior tree based on archetype
	setup_behavior_tree()
	
	print("Phase2 AI initialized for: ", owner_ship.name, " as ", archetype.archetype_name)

func assign_random_archetype():
	"""Assign a random archetype - will be replaced by TrafficManager"""
	var archetype_choice = randi() % 3
	match archetype_choice:
		0: archetype = AIArchetypeClass.create_trader()
		1: archetype = AIArchetypeClass.create_pirate()
		2: archetype = AIArchetypeClass.create_military()

func setup_behavior_tree():
	"""Create behavior tree based on archetype"""
	# Create behavior tree with explicit class
	behavior_tree = BehaviorTreeClass.new(owner_ship)
	
	if not behavior_tree:
		push_error("Failed to create behavior tree!")
		return
	
	# Create root selector using explicit class
	var root_selector = BehaviorNodeClass.new()
	root_selector.node_type = BehaviorTreeClass.NodeType.SELECTOR
	root_selector.tree = behavior_tree  # Explicit assignment
	
	# Priority 1: Combat behavior (if being attacked)
	var combat_sequence = create_combat_sequence()
	root_selector.add_child_node(combat_sequence)
	
	# Priority 2: Flee behavior (if critically damaged)
	var flee_sequence = create_flee_sequence()
	root_selector.add_child_node(flee_sequence)
	
	# Priority 3: Archetype-specific peaceful behavior
	var peaceful_behavior = create_peaceful_behavior()
	root_selector.add_child_node(peaceful_behavior)
	
	behavior_tree.set_root(root_selector)
	print("✅ Behavior tree created successfully for ", archetype.archetype_name)

func create_combat_sequence() -> BehaviorNodeClass:
	"""Create combat behavior sequence"""
	var combat_sequence = BehaviorNodeClass.new()
	combat_sequence.node_type = BehaviorTreeClass.NodeType.SEQUENCE
	
	var combat_condition = CombatActiveCondition.new()
	var combat_action = CombatBehavior.new()
	
	combat_sequence.add_child_node(combat_condition)
	combat_sequence.add_child_node(combat_action)
	
	return combat_sequence

func create_flee_sequence() -> BehaviorNodeClass:
	"""Create flee behavior sequence"""
	var flee_sequence = BehaviorNodeClass.new()
	flee_sequence.node_type = BehaviorTreeClass.NodeType.SEQUENCE
	
	var flee_condition = FleeCondition.new()
	flee_condition.threshold = archetype.threat_threshold
	var flee_action = FleeBehavior.new()
	
	flee_sequence.add_child_node(flee_condition)
	flee_sequence.add_child_node(flee_action)
	
	return flee_sequence

func create_peaceful_behavior() -> BehaviorNodeClass:
	"""Create peaceful behavior based on archetype"""
	match archetype.archetype_type:
		AIArchetypeClass.ArchetypeType.TRADER:
			return create_trader_behavior()
		AIArchetypeClass.ArchetypeType.PIRATE:
			return create_pirate_behavior()
		AIArchetypeClass.ArchetypeType.MILITARY:
			return create_military_behavior()
		_:
			return create_default_behavior()

func create_trader_behavior() -> BehaviorNodeClass:
	"""Traders fly between planets and stations"""
	var trader_action = TraderPeacefulBehavior.new()
	return trader_action

func create_pirate_behavior() -> BehaviorNodeClass:
	"""Pirates patrol and scan for opportunities"""
	var pirate_action = PiratePeacefulBehavior.new()
	return pirate_action

func create_military_behavior() -> BehaviorNodeClass:
	"""Military ships patrol systematically"""
	var military_action = MilitaryPeacefulBehavior.new()
	return military_action

func create_default_behavior() -> BehaviorNodeClass:
	"""Default peaceful behavior"""
	var default_action = DefaultPeacefulBehavior.new()
	return default_action

func _process(delta):
	if not owner_ship:
		return
	
	# Update state for compatibility
	update_state()
	
	# Run behavior tree if it exists
	if behavior_tree:
		behavior_tree.tick()
	else:
		# Fallback to simple behavior if behavior tree failed
		fallback_behavior()

func fallback_behavior():
	"""Simple fallback if behavior tree fails"""
	if attacker and is_instance_valid(attacker):
		do_combat_internal(attacker)
	elif owner_ship.has_method("get_hull_percent") and owner_ship.get_hull_percent() < flee_threshold:
		do_flee_internal(attacker)
	else:
		do_simple_peaceful_behavior()

func do_simple_peaceful_behavior():
	"""Very basic peaceful movement"""
	var time = Time.get_time_dict_from_system()
	var time_float = time.hour * 3600 + time.minute * 60 + time.second
	
	if time_float - last_destination_time > destination_change_interval:
		current_destination = get_random_destination()
		last_destination_time = time_float
	
	if current_destination != Vector2.ZERO:
		fly_toward_destination(current_destination, 0.3)

func get_random_destination() -> Vector2:
	"""Get a random destination in the system"""
	var system_scene = owner_ship.get_tree().get_first_node_in_group("system_scene")
	if not system_scene:
		return Vector2.ZERO
	
	var celestial_container = system_scene.get_node_or_null("CelestialBodies")
	if not celestial_container:
		return Vector2.ZERO
	
	var bodies = celestial_container.get_children()
	if bodies.is_empty():
		# No celestial bodies, pick random point
		return Vector2(randf_range(-1500, 1500), randf_range(-1500, 1500))
	
	var random_body = bodies[randi() % bodies.size()]
	return random_body.global_position

func fly_toward_destination(destination: Vector2, speed: float = 0.5):
	"""Fly toward a destination with specified speed"""
	var direction = (destination - owner_ship.global_position).normalized()
	var target_angle = direction.angle() + PI/2
	var angle_diff = angle_difference(owner_ship.rotation, target_angle)
	
	var turn_input = 0.0
	if abs(angle_diff) > 0.1:
		turn_input = sign(angle_diff) * 0.8
	
	owner_ship.set_meta("ai_thrust_input", speed)
	owner_ship.set_meta("ai_turn_input", turn_input)
	owner_ship.set_meta("ai_fire_input", false)

func update_state():
	"""Update state for compatibility with existing combat system"""
	if not owner_ship.has_method("get_hull_percent"):
		return
	
	var hull_percent = owner_ship.get_hull_percent()
	
	if hull_percent < flee_threshold and attacker:
		state = "fleeing"
	elif attacker and is_instance_valid(attacker):
		state = "combat"
	else:
		state = "peaceful"
		attacker = null

func notify_attacked_by(attacker_ship: Node2D):
	"""Called when ship takes damage"""
	print("*** ", owner_ship.name, " ATTACKED BY ", attacker_ship.name, " - SWITCHING TO COMBAT ***")
	attacker = attacker_ship
	state = "combat"
	
	# Update behavior tree blackboard if it exists
	if behavior_tree:
		behavior_tree.set_blackboard_value("attacker", attacker_ship)
		behavior_tree.set_blackboard_value("in_combat", true)

# =============================================================================
# ENHANCED PEACEFUL BEHAVIOR CLASSES
# =============================================================================

# Trader peaceful behavior
class TraderPeacefulBehavior extends BehaviorNodeClass:
	var last_destination_check: float = 0.0
	var destination_check_interval: float = 15.0
	var current_target_body: Node2D = null
	
	func _init():
		node_type = BehaviorTreeClass.NodeType.ACTION
	
	func execute_action() -> BehaviorTreeClass.Status:
		var ship = tree.owner_ship
		# Inline current time calculation
		var time = Time.get_time_dict_from_system()
		var current_time = time.hour * 3600 + time.minute * 60 + time.second
		
		# Check if we need a new destination
		if current_time - last_destination_check > destination_check_interval:
			current_target_body = find_nearest_trading_destination()
			last_destination_check = current_time
			
			if current_target_body:
				print("Trader ", ship.name, " heading to ", current_target_body.celestial_data.get("name", "Unknown"))
		
		# Fly to current destination
		if current_target_body and is_instance_valid(current_target_body):
			var distance = ship.global_position.distance_to(current_target_body.global_position)
			
			# If close enough, find new destination
			if distance <= 200.0:
				current_target_body = null
				return BehaviorTreeClass.Status.SUCCESS
			
			# Fly toward destination
			fly_toward_target(current_target_body.global_position, 0.6)
			return BehaviorTreeClass.Status.RUNNING
		
		# No destination, wander gently
		gentle_wander()
		return BehaviorTreeClass.Status.RUNNING
	
	func find_nearest_trading_destination() -> Node2D:
		var ship = tree.owner_ship
		var system_scene = ship.get_tree().get_first_node_in_group("system_scene")
		if not system_scene:
			return null
		
		var celestial_container = system_scene.get_node_or_null("CelestialBodies")
		if not celestial_container:
			return null
		
		var bodies = celestial_container.get_children()
		var valid_destinations = []
		
		# Find landable planets and stations
		for body in bodies:
			if body.has_method("can_interact") and body.can_interact():
				var distance = ship.global_position.distance_to(body.global_position)
				valid_destinations.append({"body": body, "distance": distance})
		
		if valid_destinations.is_empty():
			return null
		
		# Sort by distance and pick a nearby one (but not always the closest)
		valid_destinations.sort_custom(func(a, b): return a.distance < b.distance)
		
		# Pick from the 3 closest destinations for variety
		var pick_range = min(3, valid_destinations.size())
		return valid_destinations[randi() % pick_range].body
	
	func gentle_wander():
		var ship = tree.owner_ship
		var wander_direction = Vector2.from_angle(randf() * TAU)
		var target_angle = wander_direction.angle() + PI/2
		var angle_diff = Phase1CombatAI.angle_difference_static(ship.rotation, target_angle)
		
		var turn_input = 0.0
		if abs(angle_diff) > 0.3:
			turn_input = sign(angle_diff) * 0.4
		
		ship.set_meta("ai_thrust_input", 0.2)
		ship.set_meta("ai_turn_input", turn_input)
		ship.set_meta("ai_fire_input", false)
	
	func fly_toward_target(target_pos: Vector2, speed: float):
		var ship = tree.owner_ship
		var direction = (target_pos - ship.global_position).normalized()
		var target_angle = direction.angle() + PI/2
		var angle_diff = Phase1CombatAI.angle_difference_static(ship.rotation, target_angle)
		
		var turn_input = 0.0
		if abs(angle_diff) > 0.1:
			turn_input = sign(angle_diff) * 0.7
		
		ship.set_meta("ai_thrust_input", speed)
		ship.set_meta("ai_turn_input", turn_input)
		ship.set_meta("ai_fire_input", false)

# Pirate peaceful behavior
class PiratePeacefulBehavior extends BehaviorNodeClass:
	var patrol_points: Array[Vector2] = []
	var current_patrol_index: int = 0
	var scan_timer: float = 0.0
	var scan_interval: float = 3.0
	
	func _init():
		node_type = BehaviorTreeClass.NodeType.ACTION
	
	func execute_action() -> BehaviorTreeClass.Status:
		var ship = tree.owner_ship
		
		# Initialize patrol if needed
		if patrol_points.is_empty():
			setup_pirate_patrol()
		
		# Scan for potential targets periodically
		scan_timer += ship.get_process_delta_time()
		if scan_timer >= scan_interval:
			scan_for_opportunities()
			scan_timer = 0.0
		
		# Patrol behavior
		patrol_area()
		return BehaviorTreeClass.Status.RUNNING
	
	func setup_pirate_patrol():
		# Create patrol pattern around high-traffic areas
		var _ship = tree.owner_ship
		var center = Vector2.ZERO  # System center is always at origin
		var patrol_radius = 800.0
		
		# Create irregular patrol pattern
		for i in range(5):
			var angle = (float(i) / 5.0) * TAU + randf_range(-0.5, 0.5)
			var radius_variance = randf_range(0.7, 1.3)
			var point = center + Vector2.from_angle(angle) * patrol_radius * radius_variance
			patrol_points.append(point)
	
	func scan_for_opportunities():
		var ship = tree.owner_ship
		var targets = find_potential_prey()
		
		if targets.size() > 0:
			# Just observe for now - actual piracy comes later
			var closest = targets[0]
			print("Pirate ", ship.name, " spotted potential target: ", closest.ship.name, " at distance ", closest.distance)
	
	func find_potential_prey() -> Array:
		var ship = tree.owner_ship
		var potential_targets = []
		var scan_range = 1200.0
		
		# Look for player and other non-pirate ships
		var all_ships = ship.get_tree().get_nodes_in_group("npc_ships")
		if UniverseManager.player_ship:
			all_ships.append(UniverseManager.player_ship)
		
		for target in all_ships:
			if target == ship:
				continue
			
			var distance = ship.global_position.distance_to(target.global_position)
			if distance <= scan_range:
				potential_targets.append({"ship": target, "distance": distance})
		
		# Sort by distance
		potential_targets.sort_custom(func(a, b): return a.distance < b.distance)
		return potential_targets
	
	func patrol_area():
		var ship = tree.owner_ship
		
		if patrol_points.is_empty():
			return
		
		var current_target = patrol_points[current_patrol_index]
		var distance = ship.global_position.distance_to(current_target)
		
		# Move to next waypoint if close enough
		if distance <= 150.0:
			current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		
		# Fly toward current patrol point
		var direction = (current_target - ship.global_position).normalized()
		var target_angle = direction.angle() + PI/2
		var angle_diff = Phase1CombatAI.angle_difference_static(ship.rotation, target_angle)
		
		var turn_input = 0.0
		if abs(angle_diff) > 0.1:
			turn_input = sign(angle_diff) * 0.6
		
		ship.set_meta("ai_thrust_input", 0.5)
		ship.set_meta("ai_turn_input", turn_input)
		ship.set_meta("ai_fire_input", false)

# Military peaceful behavior
class MilitaryPeacefulBehavior extends BehaviorNodeClass:
	var patrol_grid: Array[Vector2] = []
	var current_grid_index: int = 0
	var grid_pause_timer: float = 0.0
	
	func _init():
		node_type = BehaviorTreeClass.NodeType.ACTION
	
	func execute_action() -> BehaviorTreeClass.Status:
		var ship = tree.owner_ship
		
		# Initialize systematic patrol grid
		if patrol_grid.is_empty():
			setup_military_patrol_grid()
		
		# Handle pausing at grid points
		if grid_pause_timer > 0:
			grid_pause_timer -= ship.get_process_delta_time()
			# Idle at current position
			ship.set_meta("ai_thrust_input", 0.0)
			ship.set_meta("ai_turn_input", 0.0)
			ship.set_meta("ai_fire_input", false)
			return BehaviorTreeClass.Status.RUNNING
		
		# Patrol the grid systematically
		patrol_grid_systematically()
		return BehaviorTreeClass.Status.RUNNING
	
	func setup_military_patrol_grid():
		# Create systematic grid patrol pattern
		var center = Vector2.ZERO  # System center is always at origin
		var _grid_size = 800.0
		var grid_spacing = 400.0
		
		# 3x3 grid pattern
		for x in range(-1, 2):
			for y in range(-1, 2):
				var point = center + Vector2(x * grid_spacing, y * grid_spacing)
				# Add some randomness to make it less robotic
				point += Vector2(randf_range(-50, 50), randf_range(-50, 50))
				patrol_grid.append(point)
	
	func patrol_grid_systematically():
		var ship = tree.owner_ship
		
		if patrol_grid.is_empty():
			return
		
		var current_target = patrol_grid[current_grid_index]
		var distance = ship.global_position.distance_to(current_target)
		
		# Reached patrol point
		if distance <= 100.0:
			current_grid_index = (current_grid_index + 1) % patrol_grid.size()
			grid_pause_timer = randf_range(2.0, 4.0)  # Pause to "scan" area
			return
		
		# Fly toward current patrol point with military precision
		var direction = (current_target - ship.global_position).normalized()
		var target_angle = direction.angle() + PI/2
		var angle_diff = Phase1CombatAI.angle_difference_static(ship.rotation, target_angle)
		
		var turn_input = 0.0
		if abs(angle_diff) > 0.05:  # More precise turning
			turn_input = sign(angle_diff) * 0.8
		
		ship.set_meta("ai_thrust_input", 0.6)  # Steady military pace
		ship.set_meta("ai_turn_input", turn_input)
		ship.set_meta("ai_fire_input", false)

# Default peaceful behavior
class DefaultPeacefulBehavior extends BehaviorNodeClass:
	var drift_timer: float = 0.0
	var direction_change_time: float = 0.0
	var current_drift_direction: Vector2 = Vector2.ZERO
	
	func _init():
		node_type = BehaviorTreeClass.NodeType.ACTION
	
	func execute_action() -> BehaviorTreeClass.Status:
		var ship = tree.owner_ship
		drift_timer += ship.get_process_delta_time()
		
		# Change direction periodically
		if drift_timer >= direction_change_time:
			current_drift_direction = Vector2.from_angle(randf() * TAU)
			direction_change_time = randf_range(8.0, 15.0)
			drift_timer = 0.0
		
		# Gentle drifting movement
		var target_angle = current_drift_direction.angle() + PI/2
		var angle_diff = Phase1CombatAI.angle_difference_static(ship.rotation, target_angle)
		
		var turn_input = 0.0
		if abs(angle_diff) > 0.2:
			turn_input = sign(angle_diff) * 0.3
		
		ship.set_meta("ai_thrust_input", 0.25)
		ship.set_meta("ai_turn_input", turn_input)
		ship.set_meta("ai_fire_input", false)
		
		return BehaviorTreeClass.Status.RUNNING

# =============================================================================
# COMBAT BEHAVIOR CLASSES (Preserved from Phase 1)
# =============================================================================

class CombatActiveCondition extends BehaviorNodeClass:
	func _init():
		node_type = BehaviorTreeClass.NodeType.CONDITION
	
	func execute_condition() -> BehaviorTreeClass.Status:
		var in_combat = tree.get_blackboard_value("in_combat", false)
		var attacker = tree.get_blackboard_value("attacker", null)
		
		if in_combat and attacker and is_instance_valid(attacker):
			return BehaviorTreeClass.Status.SUCCESS
		return BehaviorTreeClass.Status.FAILURE

class FleeCondition extends BehaviorNodeClass:
	var threshold: float = 0.3
	
	func _init():
		node_type = BehaviorTreeClass.NodeType.CONDITION
	
	func execute_condition() -> BehaviorTreeClass.Status:
		var ship = tree.owner_ship
		if not ship.has_method("get_hull_percent"):
			return BehaviorTreeClass.Status.FAILURE
			
		var hull_percent = ship.get_hull_percent()
		var attacker = tree.get_blackboard_value("attacker", null)
		
		if hull_percent < threshold and attacker:
			return BehaviorTreeClass.Status.SUCCESS
		return BehaviorTreeClass.Status.FAILURE

class CombatBehavior extends BehaviorNodeClass:
	func _init():
		node_type = BehaviorTreeClass.NodeType.ACTION
	
	func execute_action() -> BehaviorTreeClass.Status:
		var ship = tree.owner_ship
		var attacker = tree.get_blackboard_value("attacker", null)
		
		if not attacker or not is_instance_valid(attacker):
			tree.set_blackboard_value("in_combat", false)
			return BehaviorTreeClass.Status.FAILURE
		
		# Use existing combat logic
		var ai = ship.get_node("Phase1CombatAI")
		if ai:
			ai.do_combat_internal(attacker)
		
		return BehaviorTreeClass.Status.RUNNING

class FleeBehavior extends BehaviorNodeClass:
	func _init():
		node_type = BehaviorTreeClass.NodeType.ACTION
	
	func execute_action() -> BehaviorTreeClass.Status:
		var ship = tree.owner_ship
		var attacker = tree.get_blackboard_value("attacker", null)
		
		if not attacker or not is_instance_valid(attacker):
			return BehaviorTreeClass.Status.SUCCESS
		
		# Use existing flee logic
		var ai = ship.get_node("Phase1CombatAI")
		if ai:
			ai.do_flee_internal(attacker)
		
		return BehaviorTreeClass.Status.RUNNING

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

func get_system_center() -> Vector2:
	"""Get the center point of the current system"""
	return Vector2.ZERO  # Systems are centered at origin

static func get_system_center_static() -> Vector2:
	"""Static version for inner classes"""
	return Vector2.ZERO

func get_current_time() -> float:
	"""Get current time as float for timing operations"""
	var time = Time.get_time_dict_from_system()
	return time.hour * 3600 + time.minute * 60 + time.second

static func get_current_time_static() -> float:
	"""Static version for inner classes"""
	var time = Time.get_time_dict_from_system()
	return time.hour * 3600 + time.minute * 60 + time.second

func angle_difference(current: float, target: float) -> float:
	var diff = target - current
	while diff > PI: diff -= TAU
	while diff < -PI: diff += TAU
	return diff

static func angle_difference_static(current: float, target: float) -> float:
	var diff = target - current
	while diff > PI: diff -= TAU
	while diff < -PI: diff += TAU
	return diff

# Preserved combat methods for compatibility
func do_combat_internal(target):
	"""Internal combat logic"""
	var to_attacker = target.global_position - owner_ship.global_position
	var distance = to_attacker.length()
	
	var target_angle = to_attacker.angle() + PI/2
	var angle_diff = angle_difference(owner_ship.rotation, target_angle)
	
	var turn_input = 0.0
	if abs(angle_diff) > 0.1:
		turn_input = sign(angle_diff)
	
	var thrust_input = 0.0
	if distance > attack_range * 1.2:
		thrust_input = 0.6
	elif distance < attack_range * 0.3:
		thrust_input = -0.3
	
	var should_fire = (distance < attack_range and abs(angle_diff) < 0.8)
	
	owner_ship.set_meta("ai_thrust_input", thrust_input)
	owner_ship.set_meta("ai_turn_input", turn_input)
	owner_ship.set_meta("ai_fire_input", should_fire)

func do_flee_internal(threat):
	"""Internal flee logic"""
	var flee_direction = (owner_ship.global_position - threat.global_position).normalized()
	var target_angle = flee_direction.angle() + PI/2
	var angle_diff = angle_difference(owner_ship.rotation, target_angle)
	
	var turn_input = 0.0
	if abs(angle_diff) > 0.1:
		turn_input = sign(angle_diff)
	
	owner_ship.set_meta("ai_thrust_input", 1.0)
	owner_ship.set_meta("ai_turn_input", turn_input)
	owner_ship.set_meta("ai_fire_input", false)
