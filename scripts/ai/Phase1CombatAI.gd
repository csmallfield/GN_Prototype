# =============================================================================
# PHASE 1 COMBAT AI - Enhanced with Social Combat Integration and Improved Peaceful Behaviors
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

# NEW: Social Combat Integration
var social_combat_system: CombatSocialSystem

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
	
	# Assign random archetype for now (will be replaced by TrafficManager)
	assign_random_archetype()
	
	# NEW: Create and add social combat system
	create_social_combat_system()
	
	# Create behavior tree based on archetype
	setup_behavior_tree()
	
	print("Enhanced Phase1 AI initialized for: ", owner_ship.name, " as ", archetype.archetype_name)

func assign_random_archetype():
	"""Assign a random archetype - will be replaced by TrafficManager"""
	var archetype_choice = randi() % 3
	match archetype_choice:
		0: archetype = AIArchetypeClass.create_trader()
		1: archetype = AIArchetypeClass.create_pirate()
		2: archetype = AIArchetypeClass.create_military()

func create_social_combat_system():
	"""Create and attach the social combat system"""
	social_combat_system = CombatSocialSystem.new()
	social_combat_system.name = "CombatSocialSystem"
	owner_ship.add_child(social_combat_system)
	
	print("✅ Social combat system added to: ", owner_ship.name)

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
	if combat_sequence:
		combat_sequence.tree = behavior_tree
		root_selector.add_child_node(combat_sequence)
	
	# Priority 2: Flee behavior (if critically damaged)
	var flee_sequence = create_flee_sequence()
	if flee_sequence:
		flee_sequence.tree = behavior_tree
		root_selector.add_child_node(flee_sequence)
	
	# Priority 3: Archetype-specific peaceful behavior
	var peaceful_behavior = create_peaceful_behavior()
	if peaceful_behavior:
		peaceful_behavior.tree = behavior_tree
		root_selector.add_child_node(peaceful_behavior)
	
	behavior_tree.set_root(root_selector)
	
	# Propagate tree reference to all nodes
	propagate_tree_reference(root_selector, behavior_tree)
	
	print("✅ Behavior tree created successfully for ", archetype.archetype_name)

# =============================================================================
# ENHANCED DAMAGE HANDLING - Now integrates with Social Combat System
# =============================================================================

func notify_attacked_by(attacker_ship: Node2D):
	"""Called when ship takes damage - FIXED: No recursive social combat call"""
	print("*** ", owner_ship.name, " ATTACKED BY ", attacker_ship.name, " ***")
	
	# Set attacker and enter combat mode
	attacker = attacker_ship
	state = "combat"
	
	# Update behavior tree blackboard if it exists
	if behavior_tree:
		behavior_tree.set_blackboard_value("attacker", attacker_ship)
		behavior_tree.set_blackboard_value("in_combat", true)
	
	print("*** AI entering combat mode against: ", attacker_ship.name, " ***")

func set_legitimate_attacker(attacker_ship: Node2D):
	"""Called by social combat system when we have a confirmed hostile attacker"""
	attacker = attacker_ship
	state = "combat"
	
	if behavior_tree:
		behavior_tree.set_blackboard_value("attacker", attacker_ship)
		behavior_tree.set_blackboard_value("in_combat", true)
	
	print("*** ", owner_ship.name, " confirmed hostile attacker: ", attacker_ship.name, " ***")

func clear_attacker():
	"""Clear current attacker (called by social combat system when threat is resolved)"""
	attacker = null
	state = "peaceful"
	
	if behavior_tree:
		behavior_tree.set_blackboard_value("attacker", null)
		behavior_tree.set_blackboard_value("in_combat", false)
	
	print("*** ", owner_ship.name, " cleared attacker - returning to peaceful mode ***")

# =============================================================================
# BEHAVIOR TREE CREATION
# =============================================================================

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

func propagate_tree_reference(node: BehaviorNodeClass, tree_ref):
	"""Recursively set tree reference on all nodes"""
	if not node:
		return
	
	node.tree = tree_ref
	
	for child in node.children:
		propagate_tree_reference(child, tree_ref)

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

# =============================================================================
# MAIN PROCESS LOOP
# =============================================================================

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

# =============================================================================
# FALLBACK AND UTILITY METHODS
# =============================================================================

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

# =============================================================================
# CORE BEHAVIOR CLASSES
# =============================================================================

class CombatActiveCondition extends BehaviorNodeClass:
	func _init():
		node_type = BehaviorTreeClass.NodeType.CONDITION
	
	func execute_condition() -> BehaviorTreeClass.Status:
		if not tree:
			return BehaviorTreeClass.Status.FAILURE
		
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
		if not tree:
			return BehaviorTreeClass.Status.FAILURE
		
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
		if not tree:
			return BehaviorTreeClass.Status.FAILURE
		
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
		if not tree:
			return BehaviorTreeClass.Status.FAILURE
		
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
# ENHANCED PEACEFUL BEHAVIORS - More Realistic Ship Movement
# =============================================================================

class TraderPeacefulBehavior extends BehaviorNodeClass:
	var current_route_state: String = "traveling"  # traveling, visiting, departing
	var current_target_body: Node2D = null
	var visit_start_time: float = 0.0
	var visit_duration: float = 15.0
	var route_check_timer: float = 0.0
	var route_check_interval: float = 30.0
	
	func _init():
		node_type = BehaviorTreeClass.NodeType.ACTION
	
	func execute_action() -> BehaviorTreeClass.Status:
		if not tree:
			return BehaviorTreeClass.Status.FAILURE
		
		var ship = tree.owner_ship
		route_check_timer += ship.get_process_delta_time()
		
		match current_route_state:
			"traveling":
				handle_traveling_state()
			"visiting":
				handle_visiting_state()
			"departing":
				handle_departing_state()
		
		return BehaviorTreeClass.Status.RUNNING
	
	func handle_traveling_state():
		if not tree:
			return
		
		var ship = tree.owner_ship
		
		# Choose destination if we don't have one
		if not current_target_body or not is_instance_valid(current_target_body):
			current_target_body = find_trading_destination()
			if current_target_body:
				print("Trader ", ship.name, " traveling to ", current_target_body.celestial_data.get("name", "Unknown"))
		
		if current_target_body and is_instance_valid(current_target_body):
			var distance = ship.global_position.distance_to(current_target_body.global_position)
			
			# Check if we've arrived
			if distance <= 200.0:
				print("Trader ", ship.name, " arrived at ", current_target_body.celestial_data.get("name", "Unknown"))
				start_visiting()
				return
			
			# Travel toward destination with realistic speed
			travel_to_destination(current_target_body.global_position, distance)
		else:
			# No destination found - gentle cruise
			gentle_cruise()
	
	func handle_visiting_state():
		if not tree:
			return
		
		var ship = tree.owner_ship
		
		# Check if visit time is complete
		var current_time = get_current_time()
		var visit_time = current_time - visit_start_time
		
		if visit_time >= visit_duration:
			print("Trader ", ship.name, " finished visiting, choosing next action")
			choose_next_action()
			return
		
		# Station keeping behavior - stay near destination
		if current_target_body and is_instance_valid(current_target_body):
			station_keeping_near_destination()
		else:
			# Target disappeared, find new one
			current_route_state = "traveling"
	
	func handle_departing_state():
		if not tree:
			return
		
		# Move away from current location
		var ship = tree.owner_ship
		var departure_direction = ship.global_position.normalized()
		if departure_direction.length() < 0.1:
			departure_direction = Vector2(1, 0).rotated(randf() * TAU)
		
		var departure_target = ship.global_position + departure_direction * 1000.0
		travel_to_destination(departure_target, ship.global_position.distance_to(departure_target))
		
		# After traveling for a bit, choose new destination
		if route_check_timer > 10.0:
			current_route_state = "traveling"
			current_target_body = null
			route_check_timer = 0.0
	
	func start_visiting():
		current_route_state = "visiting"
		visit_start_time = get_current_time()
		visit_duration = randf_range(12.0, 25.0)
		route_check_timer = 0.0
	
	func choose_next_action():
		# 70% chance to visit another location, 30% chance to depart
		if randf() < 0.7:
			current_route_state = "traveling"
			current_target_body = null  # Will choose new destination
		else:
			current_route_state = "departing"
	
	func travel_to_destination(target_pos: Vector2, distance: float):
		if not tree:
			return
		
		var ship = tree.owner_ship
		var direction = (target_pos - ship.global_position).normalized()
		var target_angle = direction.angle() + PI/2
		var angle_diff = Phase1CombatAI.angle_difference_static(ship.rotation, target_angle)
		
		# Realistic speed adjustment based on distance
		var base_speed = 0.5
		var adjusted_speed = base_speed
		
		if distance < 400.0:
			# Decelerate as we approach
			adjusted_speed = base_speed * (distance / 400.0)
			adjusted_speed = max(adjusted_speed, 0.15)  # Minimum approach speed
		
		# Smooth turning
		var turn_input = 0.0
		if abs(angle_diff) > 0.1:
			turn_input = sign(angle_diff) * min(abs(angle_diff) * 1.5, 0.8)
		
		ship.set_meta("ai_thrust_input", adjusted_speed)
		ship.set_meta("ai_turn_input", turn_input)
		ship.set_meta("ai_fire_input", false)
	
	func station_keeping_near_destination():
		if not tree:
			return
		
		var ship = tree.owner_ship
		var target_pos = current_target_body.global_position
		var distance = ship.global_position.distance_to(target_pos)
		
		# Gentle orbital movement around the destination
		var orbital_radius = 180.0
		var time = get_current_time()
		var orbital_angle = (time * 0.3) + (hash(ship.get_instance_id()) % 628) / 100.0
		var orbital_target = target_pos + Vector2.from_angle(orbital_angle) * orbital_radius
		
		if distance > orbital_radius * 1.5:
			# Too far, gently return
			travel_to_destination(orbital_target, distance)
		else:
			# Gentle drift
			var drift_direction = (orbital_target - ship.global_position).normalized()
			var target_angle = drift_direction.angle() + PI/2
			var angle_diff = Phase1CombatAI.angle_difference_static(ship.rotation, target_angle)
			
			var turn_input = 0.0
			if abs(angle_diff) > 0.2:
				turn_input = sign(angle_diff) * 0.3
			
			ship.set_meta("ai_thrust_input", 0.1)
			ship.set_meta("ai_turn_input", turn_input)
			ship.set_meta("ai_fire_input", false)
	
	func gentle_cruise():
		if not tree:
			return
		
		var ship = tree.owner_ship
		
		# Very gentle wandering movement
		var time = get_current_time()
		var wander_angle = (time * 0.1) + (hash(ship.get_instance_id()) % 628) / 100.0
		var wander_direction = Vector2.from_angle(wander_angle)
		var target_angle = wander_direction.angle() + PI/2
		var angle_diff = Phase1CombatAI.angle_difference_static(ship.rotation, target_angle)
		
		var turn_input = 0.0
		if abs(angle_diff) > 0.3:
			turn_input = sign(angle_diff) * 0.4
		
		ship.set_meta("ai_thrust_input", 0.25)
		ship.set_meta("ai_turn_input", turn_input)
		ship.set_meta("ai_fire_input", false)
	
	func find_trading_destination() -> Node2D:
		if not tree:
			return null
		
		var ship = tree.owner_ship
		var system_scene = ship.get_tree().get_first_node_in_group("system_scene")
		if not system_scene:
			return null
		
		var celestial_container = system_scene.get_node_or_null("CelestialBodies")
		if not celestial_container:
			return null
		
		var bodies = celestial_container.get_children()
		var valid_destinations = []
		
		for body in bodies:
			if body.has_method("can_interact") and body.can_interact():
				var distance = ship.global_position.distance_to(body.global_position)
				# Skip destinations that are too close (recently visited)
				if distance > 300.0:
					valid_destinations.append({"body": body, "distance": distance})
		
		if valid_destinations.is_empty():
			return null
		
		# Prefer closer destinations but add some randomness
		valid_destinations.sort_custom(func(a, b): return a.distance < b.distance)
		var pick_range = min(3, valid_destinations.size())
		return valid_destinations[randi() % pick_range].body
	
	func get_current_time() -> float:
		var time = Time.get_time_dict_from_system()
		return time.hour * 3600 + time.minute * 60 + time.second

class MilitaryPeacefulBehavior extends BehaviorNodeClass:
	var patrol_points: Array[Vector2] = []
	var current_patrol_index: int = 0
	var patrol_state: String = "traveling"  # traveling, observing
	var observation_timer: float = 0.0
	var observation_duration: float = 8.0
	
	func _init():
		node_type = BehaviorTreeClass.NodeType.ACTION
	
	func execute_action() -> BehaviorTreeClass.Status:
		if not tree:
			return BehaviorTreeClass.Status.FAILURE
		
		if patrol_points.is_empty():
			setup_military_patrol_route()
		
		match patrol_state:
			"traveling":
				handle_patrol_traveling()
			"observing":
				handle_patrol_observation()
		
		return BehaviorTreeClass.Status.RUNNING
	
	func setup_military_patrol_route():
		patrol_points.clear()
		
		# Create patrol route between key locations
		var system_scene = tree.owner_ship.get_tree().get_first_node_in_group("system_scene")
		if system_scene:
			var celestial_container = system_scene.get_node_or_null("CelestialBodies")
			if celestial_container:
				# Add major celestial bodies to patrol route
				for body in celestial_container.get_children():
					if body.celestial_data and body.celestial_data.get("can_land", false):
						patrol_points.append(body.global_position)
		
		# Add system center
		patrol_points.append(Vector2.ZERO)
		
		# Add some strategic points around the system
		for i in range(3):
			var angle = (float(i) / 3.0) * TAU
			var strategic_point = Vector2.from_angle(angle) * 1200.0
			patrol_points.append(strategic_point)
		
		print("Military patrol established with ", patrol_points.size(), " waypoints")
	
	func handle_patrol_traveling():
		if not tree:
			return
		
		var ship = tree.owner_ship
		
		if patrol_points.is_empty():
			return
		
		var target_point = patrol_points[current_patrol_index]
		var distance = ship.global_position.distance_to(target_point)
		
		if distance <= 120.0:
			# Arrived at patrol point
			patrol_state = "observing"
			observation_timer = 0.0
			observation_duration = randf_range(6.0, 12.0)
			print("Military patrol ", ship.name, " observing waypoint ", current_patrol_index)
		else:
			# Travel to patrol point with military precision
			travel_to_patrol_point(target_point, distance)
	
	func handle_patrol_observation():
		if not tree:
			return
		
		var ship = tree.owner_ship
		observation_timer += ship.get_process_delta_time()
		
		if observation_timer >= observation_duration:
			# Observation complete, move to next patrol point
			current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
			patrol_state = "traveling"
			print("Military patrol ", ship.name, " moving to next waypoint")
		else:
			# Slow rotation while observing
			var rotation_speed = 0.5
			ship.set_meta("ai_thrust_input", 0.0)
			ship.set_meta("ai_turn_input", rotation_speed)
			ship.set_meta("ai_fire_input", false)
	
	func travel_to_patrol_point(target_pos: Vector2, distance: float):
		if not tree:
			return
		
		var ship = tree.owner_ship
		var direction = (target_pos - ship.global_position).normalized()
		var target_angle = direction.angle() + PI/2
		var angle_diff = Phase1CombatAI.angle_difference_static(ship.rotation, target_angle)
		
		# Military moves at steady, purposeful speed
		var base_speed = 0.6
		var adjusted_speed = base_speed
		
		# Decelerate for final approach
		if distance < 200.0:
			adjusted_speed = base_speed * max(0.3, distance / 200.0)
		
		# Precise turning
		var turn_input = 0.0
		if abs(angle_diff) > 0.05:
			turn_input = sign(angle_diff) * min(abs(angle_diff) * 2.0, 1.0)
		
		ship.set_meta("ai_thrust_input", adjusted_speed)
		ship.set_meta("ai_turn_input", turn_input)
		ship.set_meta("ai_fire_input", false)

class PiratePeacefulBehavior extends BehaviorNodeClass:
	var hunt_state: String = "prowling"  # prowling, stalking, lurking
	var prowl_target: Vector2 = Vector2.ZERO
	var prowl_timer: float = 0.0
	var target_scan_timer: float = 0.0
	var current_interest: Node2D = null
	
	func _init():
		node_type = BehaviorTreeClass.NodeType.ACTION
	
	func execute_action() -> BehaviorTreeClass.Status:
		if not tree:
			return BehaviorTreeClass.Status.FAILURE
		
		var ship = tree.owner_ship
		prowl_timer += ship.get_process_delta_time()
		target_scan_timer += ship.get_process_delta_time()
		
		# Scan for potential targets periodically
		if target_scan_timer >= 5.0:
			scan_for_opportunities()
			target_scan_timer = 0.0
		
		match hunt_state:
			"prowling":
				handle_prowling()
			"stalking":
				handle_stalking()
			"lurking":
				handle_lurking()
		
		return BehaviorTreeClass.Status.RUNNING
	
	func handle_prowling():
		if not tree:
			return
		
		var ship = tree.owner_ship
		
		# Choose new prowl location periodically
		if prowl_timer > 20.0 or prowl_target == Vector2.ZERO:
			choose_new_prowl_location()
			prowl_timer = 0.0
		
		var distance = ship.global_position.distance_to(prowl_target)
		
		if distance <= 150.0:
			# Arrived at prowl location
			if randf() < 0.4:  # 40% chance to lurk
				hunt_state = "lurking"
				prowl_timer = 0.0
			else:
				# Choose new location
				choose_new_prowl_location()
		else:
			# Move toward prowl location
			prowl_toward_target(prowl_target, distance)
	
	func handle_stalking():
		# This would be implemented when we add piracy mechanics
		# For now, just prowl
		hunt_state = "prowling"
	
	func handle_lurking():
		if not tree:
			return
		
		var ship = tree.owner_ship
		
		# Lurk for a while
		if prowl_timer > 15.0:
			hunt_state = "prowling"
			choose_new_prowl_location()
			return
		
		# Minimal movement while lurking
		var time = get_current_time()
		var drift_angle = (time * 0.05) + (hash(ship.get_instance_id()) % 628) / 100.0
		var drift_direction = Vector2.from_angle(drift_angle)
		var target_angle = drift_direction.angle() + PI/2
		var angle_diff = Phase1CombatAI.angle_difference_static(ship.rotation, target_angle)
		
		var turn_input = 0.0
		if abs(angle_diff) > 0.4:
			turn_input = sign(angle_diff) * 0.2
		
		ship.set_meta("ai_thrust_input", 0.08)  # Very slow
		ship.set_meta("ai_turn_input", turn_input)
		ship.set_meta("ai_fire_input", false)
	
	func choose_new_prowl_location():
		# Choose locations near trade routes or planets
		var trade_locations = find_trade_locations()
		
		if not trade_locations.is_empty():
			var chosen_location = trade_locations[randi() % trade_locations.size()]
			# Position near but not too close to the location
			var offset_angle = randf() * TAU
			var offset_distance = randf_range(300.0, 600.0)
			prowl_target = chosen_location + Vector2.from_angle(offset_angle) * offset_distance
		else:
			# Random location in system
			var angle = randf() * TAU
			var distance = randf_range(800.0, 1500.0)
			prowl_target = Vector2.from_angle(angle) * distance
	
	func prowl_toward_target(target_pos: Vector2, distance: float):
		if not tree:
			return
		
		var ship = tree.owner_ship
		var direction = (target_pos - ship.global_position).normalized()
		var target_angle = direction.angle() + PI/2
		var angle_diff = Phase1CombatAI.angle_difference_static(ship.rotation, target_angle)
		
		# Pirates move stealthily
		var base_speed = 0.35
		var adjusted_speed = base_speed
		
		# Slow down when approaching
		if distance < 300.0:
			adjusted_speed = base_speed * max(0.2, distance / 300.0)
		
		var turn_input = 0.0
		if abs(angle_diff) > 0.15:
			turn_input = sign(angle_diff) * 0.6
		
		ship.set_meta("ai_thrust_input", adjusted_speed)
		ship.set_meta("ai_turn_input", turn_input)
		ship.set_meta("ai_fire_input", false)
	
	func scan_for_opportunities():
		if not tree:
			return
		
		var ship = tree.owner_ship
		var potential_targets = []
		var scan_range = 1000.0
		
		# Look for player and other traders
		var all_ships = ship.get_tree().get_nodes_in_group("npc_ships")
		if UniverseManager.player_ship:
			all_ships.append(UniverseManager.player_ship)
		
		for target in all_ships:
			if target == ship:
				continue
			
			var distance = ship.global_position.distance_to(target.global_position)
			if distance <= scan_range:
				potential_targets.append({"ship": target, "distance": distance})
		
		if potential_targets.size() > 0:
			var closest = potential_targets[0]
			print("Pirate ", ship.name, " spotted potential target: ", closest.ship.name)
	
	func find_trade_locations() -> Array[Vector2]:
		if not tree:
			return []
		
		var ship = tree.owner_ship
		var locations = []
		
		var system_scene = ship.get_tree().get_first_node_in_group("system_scene")
		if system_scene:
			var celestial_container = system_scene.get_node_or_null("CelestialBodies")
			if celestial_container:
				for body in celestial_container.get_children():
					if body.has_method("can_interact") and body.can_interact():
						locations.append(body.global_position)
		
		return locations
	
	func get_current_time() -> float:
		var time = Time.get_time_dict_from_system()
		return time.hour * 3600 + time.minute * 60 + time.second

class DefaultPeacefulBehavior extends BehaviorNodeClass:
	var cruise_target: Vector2 = Vector2.ZERO
	var cruise_timer: float = 0.0
	var direction_change_interval: float = 25.0
	
	func _init():
		node_type = BehaviorTreeClass.NodeType.ACTION
	
	func execute_action() -> BehaviorTreeClass.Status:
		if not tree:
			return BehaviorTreeClass.Status.FAILURE
		
		var ship = tree.owner_ship
		cruise_timer += ship.get_process_delta_time()
		
		# Change direction periodically
		if cruise_timer >= direction_change_interval or cruise_target == Vector2.ZERO:
			choose_new_cruise_direction()
			cruise_timer = 0.0
		
		# Cruise toward target
		gentle_cruise_toward_target()
		
		return BehaviorTreeClass.Status.RUNNING
	
	func choose_new_cruise_direction():
		if not tree:
			return
		
		var ship = tree.owner_ship
		
		# Choose a direction that keeps us in the general system area
		var current_distance = ship.global_position.length()
		
		if current_distance > 1800.0:
			# Too far out, head back toward system center
			var direction_to_center = -ship.global_position.normalized()
			var angle_variation = randf_range(-1.0, 1.0)
			var target_direction = direction_to_center.rotated(angle_variation)
			cruise_target = ship.global_position + target_direction * 1000.0
		else:
			# Normal cruise
			var cruise_angle = randf() * TAU
			var cruise_distance = randf_range(800.0, 1200.0)
			cruise_target = ship.global_position + Vector2.from_angle(cruise_angle) * cruise_distance
		
		direction_change_interval = randf_range(20.0, 35.0)
	
	func gentle_cruise_toward_target():
		if not tree:
			return
		
		var ship = tree.owner_ship
		var direction = (cruise_target - ship.global_position).normalized()
		var distance = ship.global_position.distance_to(cruise_target)
		
		var target_angle = direction.angle() + PI/2
		var angle_diff = Phase1CombatAI.angle_difference_static(ship.rotation, target_angle)
		
		# Very gentle movement
		var turn_input = 0.0
		if abs(angle_diff) > 0.2:
			turn_input = sign(angle_diff) * 0.3
		
		var thrust_input = 0.2
		if distance < 200.0:
			thrust_input *= (distance / 200.0)
			thrust_input = max(thrust_input, 0.05)
		
		ship.set_meta("ai_thrust_input", thrust_input)
		ship.set_meta("ai_turn_input", turn_input)
		ship.set_meta("ai_fire_input", false)
