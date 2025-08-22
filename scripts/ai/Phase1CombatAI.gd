# =============================================================================
# PHASE 2 COMBAT AI - Enhanced with Behavior Trees and Archetypes
# =============================================================================
extends Node
class_name Phase1CombatAI

var owner_ship: NPCShip
var attacker: Node2D = null
var state: String = "peaceful"

# New Phase 2 components
var behavior_tree: BehaviorTree
var archetype: AIArchetype
var current_destination: Vector2
var current_activity: String = "idle"

# Enhanced parameters
var detection_range: float = 800.0
var attack_range: float = 500.0
var flee_threshold: float = 0.3

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
		0: archetype = AIArchetype.create_trader()
		1: archetype = AIArchetype.create_pirate()
		2: archetype = AIArchetype.create_military()

func setup_behavior_tree():
	"""Create behavior tree based on archetype"""
	behavior_tree = BehaviorTree.new(owner_ship)
	
	# Create root selector
	var root_selector = BehaviorNode.new()
	root_selector.node_type = BehaviorTree.NodeType.SELECTOR
	
	# Priority 1: Combat behavior
	var combat_condition = CombatActiveCondition.new()
	var combat_action = CombatBehavior.new()
	var combat_sequence = BehaviorNode.new()
	combat_sequence.node_type = BehaviorTree.NodeType.SEQUENCE
	combat_sequence.add_child_node(combat_condition)
	combat_sequence.add_child_node(combat_action)
	
	# Priority 2: Flee behavior
	var flee_condition = FleeCondition.new()
	flee_condition.threshold = archetype.threat_threshold
	var flee_action = FleeBehavior.new()
	var flee_sequence = BehaviorNode.new()
	flee_sequence.node_type = BehaviorTree.NodeType.SEQUENCE
	flee_sequence.add_child_node(flee_condition)
	flee_sequence.add_child_node(flee_action)
	
	# Priority 3: Archetype-specific peaceful behavior
	var peaceful_behavior = create_peaceful_behavior()
	
	# Assemble tree
	root_selector.add_child_node(combat_sequence)
	root_selector.add_child_node(flee_sequence)
	root_selector.add_child_node(peaceful_behavior)
	
	behavior_tree.set_root(root_selector)

func create_peaceful_behavior() -> BehaviorNode:
	"""Create peaceful behavior based on archetype"""
	match archetype.archetype_type:
		AIArchetype.ArchetypeType.TRADER:
			return create_trader_behavior()
		AIArchetype.ArchetypeType.PIRATE:
			return create_pirate_behavior()
		AIArchetype.ArchetypeType.MILITARY:
			return create_military_behavior()
		_:
			return create_default_behavior()

func create_trader_behavior() -> BehaviorNode:
	"""Traders fly between planets and stations"""
	var trader_sequence = BehaviorNode.new()
	trader_sequence.node_type = BehaviorTree.NodeType.SEQUENCE
	
	var need_destination = NeedDestinationCondition.new()
	var choose_destination = ChooseTradeDestination.new()
	var fly_to_destination = FlyToDestinationAction.new()
	
	trader_sequence.add_child_node(need_destination)
	trader_sequence.add_child_node(choose_destination)
	trader_sequence.add_child_node(fly_to_destination)
	
	return trader_sequence

func create_pirate_behavior() -> BehaviorNode:
	"""Pirates patrol and scan for targets"""
	var pirate_selector = BehaviorNode.new()
	pirate_selector.node_type = BehaviorTree.NodeType.SELECTOR
	
	# Try to hunt targets first
	var hunt_sequence = BehaviorNode.new()
	hunt_sequence.node_type = BehaviorTree.NodeType.SEQUENCE
	
	var scan_action = ScanForTargetsAction.new()
	var stalk_target = StalkTargetAction.new()
	
	hunt_sequence.add_child_node(scan_action)
	hunt_sequence.add_child_node(stalk_target)
	
	# Fallback to patrol
	var patrol_action = PatrolAreaAction.new()
	
	pirate_selector.add_child_node(hunt_sequence)
	pirate_selector.add_child_node(patrol_action)
	
	return pirate_selector

func create_military_behavior() -> BehaviorNode:
	"""Military ships patrol systematically"""
	var patrol_action = PatrolAreaAction.new()
	return patrol_action

func create_default_behavior() -> BehaviorNode:
	"""Default peaceful behavior"""
	var default_action = DefaultIdleBehavior.new()
	return default_action

func _process(delta):
	if not owner_ship:
		return
	
	# Update state for compatibility
	update_state()
	
	# Run behavior tree
	if behavior_tree:
		behavior_tree.tick()

func update_state():
	"""Update state for compatibility with existing combat system"""
	var hull_percent = owner_ship.hull / owner_ship.max_hull
	
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
	
	# Update behavior tree blackboard
	if behavior_tree:
		behavior_tree.set_blackboard_value("attacker", attacker_ship)
		behavior_tree.set_blackboard_value("in_combat", true)

# =============================================================================
# INNER CLASSES - Behavior Tree Conditions and Actions
# =============================================================================

# Combat condition
class CombatActiveCondition extends BehaviorNode:
	func _init():
		node_type = BehaviorTree.NodeType.CONDITION
	
	func execute_condition() -> BehaviorTree.Status:
		var in_combat = tree.get_blackboard_value("in_combat", false)
		var attacker = tree.get_blackboard_value("attacker", null)
		
		if in_combat and attacker and is_instance_valid(attacker):
			return BehaviorTree.Status.SUCCESS
		return BehaviorTree.Status.FAILURE

# Flee condition
class FleeCondition extends BehaviorNode:
	var threshold: float = 0.3
	
	func _init():
		node_type = BehaviorTree.NodeType.CONDITION
	
	func execute_condition() -> BehaviorTree.Status:
		var ship = tree.owner_ship
		var hull_percent = ship.hull / ship.max_hull
		var attacker = tree.get_blackboard_value("attacker", null)
		
		if hull_percent < threshold and attacker:
			return BehaviorTree.Status.SUCCESS
		return BehaviorTree.Status.FAILURE

# Need destination condition
class NeedDestinationCondition extends BehaviorNode:
	func _init():
		node_type = BehaviorTree.NodeType.CONDITION
	
	func execute_condition() -> BehaviorTree.Status:
		var has_destination = tree.get_blackboard_value("has_destination", false)
		var movement_complete = tree.get_blackboard_value("movement_complete", false)
		
		if not has_destination or movement_complete:
			tree.set_blackboard_value("movement_complete", false)
			return BehaviorTree.Status.SUCCESS
		return BehaviorTree.Status.FAILURE

# Combat behavior
class CombatBehavior extends BehaviorNode:
	func _init():
		node_type = BehaviorTree.NodeType.ACTION
	
	func execute_action() -> BehaviorTree.Status:
		var ship = tree.owner_ship
		var attacker = tree.get_blackboard_value("attacker", null)
		
		if not attacker or not is_instance_valid(attacker):
			tree.set_blackboard_value("in_combat", false)
			return BehaviorTree.Status.FAILURE
		
		# Use existing combat logic
		var ai = ship.get_node("Phase1CombatAI")
		if ai:
			ai.do_combat_internal(attacker)
		
		return BehaviorTree.Status.RUNNING

# Flee behavior
class FleeBehavior extends BehaviorNode:
	func _init():
		node_type = BehaviorTree.NodeType.ACTION
	
	func execute_action() -> BehaviorTree.Status:
		var ship = tree.owner_ship
		var attacker = tree.get_blackboard_value("attacker", null)
		
		if not attacker or not is_instance_valid(attacker):
			return BehaviorTree.Status.SUCCESS
		
		# Use existing flee logic
		var ai = ship.get_node("Phase1CombatAI")
		if ai:
			ai.do_flee_internal(attacker)
		
		return BehaviorTree.Status.RUNNING

# Choose trade destination
class ChooseTradeDestination extends BehaviorNode:
	func _init():
		node_type = BehaviorTree.NodeType.ACTION
	
	func execute_action() -> BehaviorTree.Status:
		var destination = find_random_celestial_body()
		if destination != Vector2.ZERO:
			tree.set_blackboard_value("destination", destination)
			tree.set_blackboard_value("has_destination", true)
			return BehaviorTree.Status.SUCCESS
		return BehaviorTree.Status.FAILURE
	
	func find_random_celestial_body() -> Vector2:
		var system_scene = tree.owner_ship.get_tree().get_first_node_in_group("system_scene")
		if not system_scene:
			return Vector2.ZERO
		
		var celestial_container = system_scene.get_node_or_null("CelestialBodies")
		if not celestial_container:
			return Vector2.ZERO
		
		var bodies = celestial_container.get_children()
		if bodies.is_empty():
			return Vector2.ZERO
		
		var random_body = bodies[randi() % bodies.size()]
		return random_body.global_position

# Fly to destination action
class FlyToDestinationAction extends BehaviorNode:
	func _init():
		node_type = BehaviorTree.NodeType.ACTION
	
	func execute_action() -> BehaviorTree.Status:
		var destination = tree.get_blackboard_value("destination", Vector2.ZERO)
		if destination == Vector2.ZERO:
			return BehaviorTree.Status.FAILURE
		
		var ship = tree.owner_ship
		var distance = ship.global_position.distance_to(destination)
		
		if distance <= 150.0:
			tree.set_blackboard_value("movement_complete", true)
			tree.set_blackboard_value("has_destination", false)
			return BehaviorTree.Status.SUCCESS
		
		# Move toward destination
		var direction = (destination - ship.global_position).normalized()
		var target_angle = direction.angle() + PI/2
		var angle_diff = angle_difference(ship.rotation, target_angle)
		
		var turn_input = 0.0
		if abs(angle_diff) > 0.1:
			turn_input = sign(angle_diff)
		
		ship.set_meta("ai_thrust_input", 0.6)
		ship.set_meta("ai_turn_input", turn_input)
		ship.set_meta("ai_fire_input", false)
		
		return BehaviorTree.Status.RUNNING

# Scan for targets action
class ScanForTargetsAction extends BehaviorNode:
	var last_scan_time: float = 0.0
	var scan_cooldown: float = 3.0
	
	func _init():
		node_type = BehaviorTree.NodeType.ACTION
	
	func execute_action() -> BehaviorTree.Status:
		var current_time = Time.get_ticks_msec() / 1000.0
		
		if current_time - last_scan_time < scan_cooldown:
			return BehaviorTree.Status.RUNNING
		
		last_scan_time = current_time
		
		var targets = find_potential_targets()
		if targets.size() > 0:
			tree.set_blackboard_value("potential_targets", targets)
			return BehaviorTree.Status.SUCCESS
		
		return BehaviorTree.Status.FAILURE
	
	func find_potential_targets() -> Array:
		var ship = tree.owner_ship
		var targets = []
		var scan_range = 1000.0
		
		# Look for player ship and other NPCs
		var all_ships = []
		if UniverseManager.player_ship:
			all_ships.append(UniverseManager.player_ship)
		
		var npcs = ship.get_tree().get_nodes_in_group("npc_ships")
		all_ships.append_array(npcs)
		
		for target in all_ships:
			if target == ship:
				continue
			
			var distance = ship.global_position.distance_to(target.global_position)
			if distance <= scan_range:
				targets.append({"ship": target, "distance": distance})
		
		return targets

# Stalk target action
class StalkTargetAction extends BehaviorNode:
	func _init():
		node_type = BehaviorTree.NodeType.ACTION
	
	func execute_action() -> BehaviorTree.Status:
		var targets = tree.get_blackboard_value("potential_targets", [])
		if targets.is_empty():
			return BehaviorTree.Status.FAILURE
		
		# Choose closest target
		targets.sort_custom(func(a, b): return a.distance < b.distance)
		var target = targets[0].ship
		
		if not is_instance_valid(target):
			return BehaviorTree.Status.FAILURE
		
		# Follow target at a distance
		var ship = tree.owner_ship
		var target_pos = target.global_position
		var follow_distance = 400.0
		
		var direction = (target_pos - ship.global_position).normalized()
		var desired_pos = target_pos - direction * follow_distance
		
		# Move toward follow position
		var move_direction = (desired_pos - ship.global_position).normalized()
		var target_angle = move_direction.angle() + PI/2
		var angle_diff = angle_difference(ship.rotation, target_angle)
		
		var turn_input = 0.0
		if abs(angle_diff) > 0.1:
			turn_input = sign(angle_diff)
		
		ship.set_meta("ai_thrust_input", 0.7)
		ship.set_meta("ai_turn_input", turn_input)
		ship.set_meta("ai_fire_input", false)
		
		return BehaviorTree.Status.RUNNING

# Patrol area action
class PatrolAreaAction extends BehaviorNode:
	var waypoints: Array[Vector2] = []
	var current_waypoint: int = 0
	
	func _init():
		node_type = BehaviorTree.NodeType.ACTION
	
	func execute_action() -> BehaviorTree.Status:
		var ship = tree.owner_ship
		
		# Initialize waypoints if empty
		if waypoints.is_empty():
			setup_patrol_waypoints()
		
		if waypoints.is_empty():
			return BehaviorTree.Status.FAILURE
		
		var target = waypoints[current_waypoint]
		var distance = ship.global_position.distance_to(target)
		
		# Check if reached waypoint
		if distance <= 100.0:
			current_waypoint = (current_waypoint + 1) % waypoints.size()
		
		# Move toward current waypoint
		var direction = (target - ship.global_position).normalized()
		var target_angle = direction.angle() + PI/2
		var angle_diff = angle_difference(ship.rotation, target_angle)
		
		var turn_input = 0.0
		if abs(angle_diff) > 0.1:
			turn_input = sign(angle_diff)
		
		ship.set_meta("ai_thrust_input", 0.5)
		ship.set_meta("ai_turn_input", turn_input)
		ship.set_meta("ai_fire_input", false)
		
		return BehaviorTree.Status.RUNNING
	
	func setup_patrol_waypoints():
		var ship = tree.owner_ship
		var center = Vector2.ZERO
		var radius = 1200.0
		
		# Create a square patrol pattern
		waypoints = [
			center + Vector2(radius, radius),
			center + Vector2(-radius, radius),
			center + Vector2(-radius, -radius),
			center + Vector2(radius, -radius)
		]

# Default idle behavior
class DefaultIdleBehavior extends BehaviorNode:
	func _init():
		node_type = BehaviorTree.NodeType.ACTION
	
	func execute_action() -> BehaviorTree.Status:
		var ship = tree.owner_ship
		ship.set_meta("ai_thrust_input", 0.2)
		ship.set_meta("ai_turn_input", 0.0)
		ship.set_meta("ai_fire_input", false)
		return BehaviorTree.Status.RUNNING

# =============================================================================
# PRESERVED COMBAT METHODS FOR COMPATIBILITY
# =============================================================================

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
