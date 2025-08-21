# =============================================================================
# PHASE 1 COMBAT AI - FIXED: Corrected movement direction and added firing
# =============================================================================
extends Node
class_name Phase1CombatAI

var owner_ship: NPCShip
var attacker: Node2D = null
var state: String = "peaceful"  # "peaceful", "combat", "fleeing"

# Simple parameters
var detection_range: float = 800.0
var attack_range: float = 500.0
var flee_threshold: float = 0.3  # Flee when hull < 30%

func _ready():
	owner_ship = get_parent()
	print("Phase1CombatAI initialized for: ", owner_ship.name)

func _process(delta):
	if not owner_ship:
		return
	
	# Ultra-simple state logic
	update_state()
	execute_behavior()

func update_state():
	"""Dead simple state updates"""
	var hull_percent = owner_ship.hull / owner_ship.max_hull
	
	# Priority 1: Flee if critically damaged
	if hull_percent < flee_threshold and attacker:
		state = "fleeing"
	# Priority 2: Fight if we have an attacker
	elif attacker and is_instance_valid(attacker):
		state = "combat"
	# Priority 3: Be peaceful
	else:
		state = "peaceful"
		attacker = null  # Clear invalid attackers

func execute_behavior():
	"""Execute current behavior"""
	match state:
		"peaceful":
			do_peaceful()
		"combat":
			do_combat()
		"fleeing":
			do_flee()

func do_peaceful():
	"""Just drift around peacefully"""
	# Minimal movement - just drift forward slowly
	set_ship_inputs(0.1, 0.0, false)

func do_combat():
	"""Face attacker and shoot - FIXED: Corrected direction logic"""
	if not attacker or not is_instance_valid(attacker):
		return
	
	var to_attacker = attacker.global_position - owner_ship.global_position
	var distance = to_attacker.length()
	
	# FIXED: Calculate target angle correctly
	# Ships face "up" (-Y direction) when rotation = 0
	# So we need to account for this in our angle calculation
	var target_angle = to_attacker.angle() + PI/2  # ADD PI/2 because ship faces up
	var angle_diff = angle_difference(owner_ship.rotation, target_angle)
	
	# FIXED: Corrected turn direction
	var turn_input = 0.0
	if abs(angle_diff) > 0.1:
		turn_input = sign(angle_diff)  # Removed the -1 multiplier that was causing backwards movement
	
	# Move toward attacker if too far, away if too close
	var thrust_input = 0.0
	if distance > attack_range * 1.2:
		thrust_input = 0.6  # Move closer
	elif distance < attack_range * 0.3:
		thrust_input = -0.3  # Back away
	
	# FIXED: More lenient firing angle and ensure we're trying to fire
	var should_fire = (distance < attack_range and abs(angle_diff) < 0.8)  # Increased from 0.5 to 0.8
	
	set_ship_inputs(thrust_input, turn_input, should_fire)
	
	# DEBUG: Print combat info occasionally
	if randf() < 0.02:  # Print 2% of the time
		print("NPC Combat - Distance: ", int(distance), " Angle diff: ", angle_diff, " Firing: ", should_fire)

func do_flee():
	"""Run away from attacker"""
	if not attacker or not is_instance_valid(attacker):
		return
	
	# Run directly away from attacker
	var flee_direction = (owner_ship.global_position - attacker.global_position).normalized()
	var target_angle = flee_direction.angle() + PI/2  # FIXED: Same correction as combat
	var angle_diff = angle_difference(owner_ship.rotation, target_angle)
	
	var turn_input = 0.0
	if abs(angle_diff) > 0.1:
		turn_input = sign(angle_diff)  # FIXED: Removed -1 multiplier
	
	set_ship_inputs(1.0, turn_input, false)  # Full speed, no shooting

func set_ship_inputs(thrust: float, turn: float, fire: bool):
	"""Set inputs for the ship to follow"""
	owner_ship.set_meta("ai_thrust_input", thrust)
	owner_ship.set_meta("ai_turn_input", turn)
	owner_ship.set_meta("ai_fire_input", fire)
	
	# ADDED: Debug output for firing attempts
	if fire and randf() < 0.05:  # 5% chance to print when trying to fire
		print("NPC ", owner_ship.name, " attempting to fire at ", attacker.name if attacker else "unknown")

func notify_attacked_by(attacker_ship: Node2D):
	"""Called when ship takes damage - THE KEY METHOD"""
	print("*** ", owner_ship.name, " ATTACKED BY ", attacker_ship.name, " - SWITCHING TO COMBAT ***")
	attacker = attacker_ship
	state = "combat"

func angle_difference(current: float, target: float) -> float:
	var diff = target - current
	while diff > PI: diff -= TAU
	while diff < -PI: diff += TAU
	return diff
