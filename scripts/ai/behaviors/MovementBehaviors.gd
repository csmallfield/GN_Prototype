# =============================================================================
# MOVEMENT BEHAVIORS - Specific movement patterns for different ship types
# =============================================================================
extends RefCounted

# =============================================================================
# FLY TO DESTINATION - Navigate to a specific point
# =============================================================================
class_name FlyToDestination
extends BehaviorNode

var destination: Vector2
var arrival_distance: float = 100.0
var cruise_speed: float = 0.7

func _init(dest: Vector2, arrival_dist: float = 100.0, speed: float = 0.7):
	node_type = BehaviorTree.NodeType.ACTION
	destination = dest
	arrival_distance = arrival_dist
	cruise_speed = speed

func execute_action() -> BehaviorTree.Status:
	var ship = tree.owner_ship
	var current_pos = ship.global_position
	var distance = current_pos.distance_to(destination)
	
	# Check if we've arrived
	if distance <= arrival_distance:
		tree.set_blackboard_value("movement_complete", true)
		return BehaviorTree.Status.SUCCESS
	
	# Calculate movement direction
	var direction = (destination - current_pos).normalized()
	var target_angle = direction.angle() + PI/2  # Ship faces up
	var angle_diff = angle_difference(ship.rotation, target_angle)
	
	# Calculate inputs
	var turn_input = 0.0
	if abs(angle_diff) > 0.1:
		turn_input = sign(angle_diff)
	
	var thrust_input = cruise_speed
	
	# Apply movement
	ship.set_meta("ai_thrust_input", thrust_input)
	ship.set_meta("ai_turn_input", turn_input)
	ship.set_meta("ai_fire_input", false)
	
	return BehaviorTree.Status.RUNNING

func angle_difference(current: float, target: float) -> float:
	var diff = target - current
	while diff > PI: diff -= TAU
	while diff < -PI: diff += TAU
	return diff

# =============================================================================
# PATROL AREA - Patrol between multiple waypoints
# =============================================================================
class_name PatrolArea
extends BehaviorNode

var waypoints: Array[Vector2] = []
var current_waypoint: int = 0
var patrol_speed: float = 0.5

func _init(patrol_points: Array[Vector2], speed: float = 0.5):
	node_type = BehaviorTree.NodeType.ACTION
	waypoints = patrol_points
	patrol_speed = speed

func execute_action() -> BehaviorTree.Status:
	if waypoints.is_empty():
		return BehaviorTree.Status.FAILURE
	
	var ship = tree.owner_ship
	var target_waypoint = waypoints[current_waypoint]
	var distance = ship.global_position.distance_to(target_waypoint)
	
	# Check if we've reached current waypoint
	if distance <= 80.0:
		current_waypoint = (current_waypoint + 1) % waypoints.size()
		tree.set_blackboard_value("waypoint_reached", current_waypoint)
	
	# Move toward current waypoint
	var direction = (target_waypoint - ship.global_position).normalized()
	var target_angle = direction.angle() + PI/2
	var angle_diff = angle_difference(ship.rotation, target_angle)
	
	var turn_input = 0.0
	if abs(angle_diff) > 0.1:
		turn_input = sign(angle_diff)
	
	ship.set_meta("ai_thrust_input", patrol_speed)
	ship.set_meta("ai_turn_input", turn_input)
	ship.set_meta("ai_fire_input", false)
	
	return BehaviorTree.Status.RUNNING

func angle_difference(current: float, target: float) -> float:
	var diff = target - current
	while diff > PI: diff -= TAU
	while diff < -PI: diff += TAU
	return diff

# =============================================================================
# SCAN FOR TARGETS - Look for interesting ships nearby
# =============================================================================
class_name ScanForTargets
extends BehaviorNode

var scan_range: float = 800.0
var scan_cooldown: float = 2.0
var last_scan_time: float = 0.0

func _init(range: float = 800.0, cooldown: float = 2.0):
	node_type = BehaviorTree.NodeType.ACTION
	scan_range = range
	scan_cooldown = cooldown

func execute_action() -> BehaviorTree.Status:
	var current_time = Time.get_time_dict_from_system()
	var time_float = current_time.hour * 3600 + current_time.minute * 60 + current_time.second
	
	if time_float - last_scan_time < scan_cooldown:
		return BehaviorTree.Status.RUNNING
	
	last_scan_time = time_float
	
	var ship = tree.owner_ship
	var nearby_ships = find_nearby_ships()
	
	if nearby_ships.size() > 0:
		tree.set_blackboard_value("scan_targets", nearby_ships)
		tree.set_blackboard_value("targets_found", true)
		return BehaviorTree.Status.SUCCESS
	
	tree.set_blackboard_value("targets_found", false)
	return BehaviorTree.Status.FAILURE

func find_nearby_ships() -> Array:
	var ship = tree.owner_ship
	var targets = []
	
	# Find all ships in range
	var all_ships = ship.get_tree().get_nodes_in_group("npc_ships")
	
	# Add player ship
	if UniverseManager.player_ship:
		all_ships.append(UniverseManager.player_ship)
	
	for target in all_ships:
		if target == ship:
			continue
		
		var distance = ship.global_position.distance_to(target.global_position)
		if distance <= scan_range:
			targets.append({"ship": target, "distance": distance})
	
	return targets
