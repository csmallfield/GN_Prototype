# =============================================================================
# SIMPLE NPC AI - Phase 1: Basic "shoot back when shot" behavior
# =============================================================================
extends Node
class_name SimpleNPCAI

var owner_ship  # Will be NPCShip, but we'll cast it in _ready
var current_state: String = "wandering"
var attacker: Node2D = null
var wander_target: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var state_timer: float = 0.0

# AI Parameters
var detection_range: float = 800.0
var attack_range: float = 600.0
var flee_health_threshold: float = 0.3  # Flee when health below 30%
var wander_change_interval: float = 3.0  # Change wander direction every 3 seconds

func _ready():
	owner_ship = get_parent()
	
	# Debug: Check what we actually got
	print("SimpleNPCAI parent check:")
	print("  Parent: ", get_parent())
	print("  Parent name: ", get_parent().name if get_parent() else "NULL")
	print("  Parent type: ", get_parent().get_class() if get_parent() else "NULL")
	
	if not owner_ship or not owner_ship.has_method("take_damage"):
		push_error("SimpleNPCAI must be a child of NPCShip, got: " + str(owner_ship))
		return
	
	# Set initial wander target
	choose_new_wander_target()
	print("SimpleNPCAI initialized for ", owner_ship.name)

func _process(delta):
	if not owner_ship:
		return
	
	# DEBUG: Print occasionally to see if AI is running
	if randf() < 0.005:  # Print very occasionally
		print("AI running for: ", owner_ship.name, " State: ", current_state)
	
	wander_timer += delta
	state_timer += delta
	
	# Update AI state
	update_ai_state()
	
	# Execute current behavior
	execute_behavior()

func update_ai_state():
	"""Determine what the NPC should be doing"""
	var old_state = current_state
	
	# Priority 1: Check if we're under attack and should flee
	if attacker and is_instance_valid(attacker) and should_flee():
		current_state = "fleeing"
	
	# Priority 2: Check if we're under attack and should fight back
	elif attacker and is_instance_valid(attacker) and not should_flee():
		current_state = "attacking"
	
	# Priority 3: Default to wandering
	else:
		current_state = "wandering"
		# Clear attacker if we're not fighting
		if attacker and not is_instance_valid(attacker):
			attacker = null
	
	# Reset state timer if state changed
	if old_state != current_state:
		state_timer = 0.0
		print("NPC ", owner_ship.name, " state: ", old_state, " -> ", current_state)

func execute_behavior():
	"""Execute the behavior for the current state"""
	match current_state:
		"wandering":
			do_wander()
		"attacking":
			do_attack()
		"fleeing":
			do_flee()

func do_wander():
	"""Simple wandering behavior"""
	# Change wander target periodically
	if wander_timer >= wander_change_interval:
		choose_new_wander_target()
		wander_timer = 0.0
	
	# Move toward wander target
	var to_target = wander_target - owner_ship.global_position
	var distance = to_target.length()
	
	if distance > 50.0:  # Don't get too close to target point
		var direction = to_target.normalized()
		move_in_direction(direction, 0.5)  # Half throttle for wandering
	else:
		# Reached target, choose a new one
		choose_new_wander_target()

func do_attack():
	"""Attack the current attacker"""
	if not attacker or not is_instance_valid(attacker):
		return
	
	var to_attacker = attacker.global_position - owner_ship.global_position
	var distance = to_attacker.length()
	var direction = to_attacker.normalized()
	
	# Move toward attacker if too far
	if distance > attack_range * 0.8:
		move_in_direction(direction, 0.8)  # Moderate speed approach
	
	# Stay at medium range if too close
	elif distance < attack_range * 0.3:
		move_in_direction(-direction, 0.6)  # Back away
	
	# Circle strafe if at good range
	else:
		var perpendicular = Vector2(-direction.y, direction.x)
		move_in_direction(perpendicular, 0.7)
	
	# Try to fire at attacker
	try_fire_at_target(attacker)

func do_flee():
	"""Flee from the attacker"""
	if not attacker or not is_instance_valid(attacker):
		return
	
	# Run away from attacker
	var flee_direction = (owner_ship.global_position - attacker.global_position).normalized()
	move_in_direction(flee_direction, 1.0)  # Full speed retreat
	
	# Stop fleeing if we get far enough away or health recovers
	var distance = owner_ship.global_position.distance_to(attacker.global_position)
	if distance > detection_range * 1.5 or not should_flee():
		print("NPC ", owner_ship.name, " finished fleeing")
		attacker = null  # Stop targeting attacker

func move_in_direction(direction: Vector2, throttle: float):
	"""Move the ship in the specified direction"""
	if not owner_ship:
		return
	
	# Calculate desired rotation (ship faces "up" by default)
	var desired_angle = direction.angle() + PI/2
	var current_angle = owner_ship.rotation
	
	# Calculate turn direction
	var angle_diff = angle_difference(current_angle, desired_angle)
	var turn_input = 0.0
	
	if abs(angle_diff) > 0.1:  # Small dead zone
		turn_input = sign(angle_diff) * -1.0  # Negative because of how rotation works
	
	# Apply movement through the ship's physics
	# We'll store these values for the ship to read in _integrate_forces
	owner_ship.set_meta("ai_turn_input", turn_input)
	owner_ship.set_meta("ai_thrust_input", throttle)

func try_fire_at_target(target: Node2D):
	"""Try to fire at the specified target"""
	if not target or not is_instance_valid(target):
		return
	
	# Find the WeaponHardpoint instead of using owner_ship.weapon
	var weapon_hardpoint = owner_ship.get_node_or_null("WeaponHardpoint")
	if not weapon_hardpoint:
		return
	
	var to_target = target.global_position - owner_ship.global_position
	var distance = to_target.length()
	
	# Only fire if target is in range
	if distance > attack_range:
		return
	
	# Check if we're facing roughly toward the target
	var target_direction = to_target.normalized()
	var ship_forward = Vector2.UP.rotated(owner_ship.rotation)
	var dot_product = ship_forward.dot(target_direction)
	
	# Fire if facing target (dot product > 0.7 means within ~45 degrees)
	if dot_product > 0.7:
		# Set target and try to fire using the WeaponHardpoint
		weapon_hardpoint.set_target(target)
		if weapon_hardpoint.try_fire():
			print("NPC ", owner_ship.name, " fired at ", target.name)
		else:
			print("NPC ", owner_ship.name, " tried to fire but weapon not ready")

func choose_new_wander_target():
	"""Choose a new random point to wander toward"""
	# Pick a random point within a reasonable distance
	var angle = randf() * TAU
	var distance = randf_range(500.0, 1500.0)
	wander_target = owner_ship.global_position + Vector2.from_angle(angle) * distance
	
	# Keep it away from system center (avoid clustering at origin)
	if wander_target.length() < 800.0:
		wander_target = wander_target.normalized() * 800.0

func should_flee() -> bool:
	"""Check if the NPC should flee based on health"""
	if not owner_ship:
		return false
	
	var health_percent = owner_ship.hull / owner_ship.max_hull
	return health_percent < flee_health_threshold

func notify_attacked_by(attacker_ship: Node2D):
	"""Called when this NPC is attacked by someone"""
	print("NPC ", owner_ship.name, " was attacked by ", attacker_ship.name if attacker_ship else "unknown")
	
	# Set this ship as our attacker
	attacker = attacker_ship
	
	# Force immediate state re-evaluation
	update_ai_state()

func angle_difference(from: float, to: float) -> float:
	"""Calculate the shortest angle difference"""
	var diff = to - from
	while diff > PI:
		diff -= TAU
	while diff < -PI:
		diff += TAU
	return diff
