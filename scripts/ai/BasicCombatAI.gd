# =============================================================================
# BASIC COMBAT AI - Phase 1.3: Simple "shoot back when shot" behavior
# =============================================================================
# BasicCombatAI.gd
extends Node
class_name BasicCombatAI

var owner_ship: NPCShip
var current_target: Node2D = null
var detection_range: float = 1000.0
var attack_range: float = 600.0
var flee_hull_threshold: float = 0.3  # Flee when hull < 30%

# Simple states
enum AIState {
	PEACEFUL,    # Normal behavior, not in combat
	COMBAT,      # Fighting back against attacker
	FLEEING      # Running away when damaged
}

var ai_state: AIState = AIState.PEACEFUL
var state_timer: float = 0.0

func _ready():
	owner_ship = get_parent()
	if not owner_ship:
		push_error("BasicCombatAI must be child of NPCShip")

func think(delta: float):
	if not owner_ship:
		return
	
	state_timer += delta
	
	# Check hull condition first
	var hull_percent = owner_ship.get_hull_percent()
	
	# If critically damaged, flee
	if hull_percent < flee_hull_threshold and ai_state != AIState.FLEEING:
		print("NPC [", owner_ship.name, "] hull critical, fleeing!")
		ai_state = AIState.FLEEING
		current_target = find_nearest_threat()
		state_timer = 0.0
		return
	
	# If hull recovered enough, can return to combat
	if hull_percent > flee_hull_threshold + 0.1 and ai_state == AIState.FLEEING:
		ai_state = AIState.PEACEFUL
		current_target = null
		state_timer = 0.0
	
	# Look for threats if not already fleeing
	if ai_state != AIState.FLEEING:
		var threat = find_nearest_threat()
		
		if threat and ai_state == AIState.PEACEFUL:
			# Found a threat, engage
			print("NPC [", owner_ship.name, "] engaging threat: ", threat.name)
			ai_state = AIState.COMBAT
			current_target = threat
			state_timer = 0.0
		elif not threat and ai_state == AIState.COMBAT:
			# No more threats, return to peaceful
			print("NPC [", owner_ship.name, "] no threats detected, returning to peaceful")
			ai_state = AIState.PEACEFUL
			current_target = null
			state_timer = 0.0

func notify_under_attack(attacker: Node2D):
	"""Called by NPCShip when it takes damage"""
	if not attacker:
		return
	
	print("NPC [", owner_ship.name, "] under attack by: ", attacker.name)
	
	# If we're peaceful, immediately switch to combat
	if ai_state == AIState.PEACEFUL:
		ai_state = AIState.COMBAT
		current_target = attacker
		state_timer = 0.0
		print("NPC [", owner_ship.name, "] switching to combat mode!")

func find_nearest_threat() -> Node2D:
	"""Find the nearest threatening ship within detection range"""
	if not owner_ship:
		return null
	
	var nearest_threat = null
	var nearest_distance = detection_range
	
	# Check player
	var player = UniverseManager.player_ship
	if player and is_threat(player):
		var distance = owner_ship.global_position.distance_to(player.global_position)
		if distance < nearest_distance:
			nearest_threat = player
			nearest_distance = distance
	
	# Check other NPCs (for future expansion)
	var npcs = get_tree().get_nodes_in_group("npc_ships")
	for npc in npcs:
		if npc == owner_ship or not is_instance_valid(npc):
			continue
		
		if is_threat(npc):
			var distance = owner_ship.global_position.distance_to(npc.global_position)
			if distance < nearest_distance:
				nearest_threat = npc
				nearest_distance = distance
	
	return nearest_threat

func is_threat(ship: Node2D) -> bool:
	"""Determine if a ship is a threat (very simple for Phase 1.3)"""
	# For now, anything that's not us is a potential threat
	# Later we can add faction relationships
	return ship != owner_ship

func get_movement_command() -> Dictionary:
	"""Get movement command based on current AI state"""
	var command = {"thrust": 0.0, "turn": 0.0, "fire": false}
	
	match ai_state:
		AIState.PEACEFUL:
			# Let the old AI system handle peaceful movement
			command = get_peaceful_command()
		
		AIState.COMBAT:
			if current_target and is_instance_valid(current_target):
				command = get_combat_command()
			else:
				# Target lost, return to peaceful
				ai_state = AIState.PEACEFUL
				current_target = null
		
		AIState.FLEEING:
			if current_target and is_instance_valid(current_target):
				command = get_flee_command()
			else:
				# Threat lost, but keep fleeing for a bit
				command = get_general_flee_command()
	
	return command

func get_peaceful_command() -> Dictionary:
	"""Peaceful movement - just return to old system or wander"""
	# For now, let the existing NPC movement handle this
	return {"thrust": 0.2, "turn": 0.0, "fire": false}

func get_combat_command() -> Dictionary:
	"""PHASE 1.3: Basic combat - face target and shoot"""
	if not current_target:
		return {"thrust": 0.0, "turn": 0.0, "fire": false}
	
	var to_target = current_target.global_position - owner_ship.global_position
	var distance = to_target.length()
	var direction = to_target.normalized()
	
	# Calculate desired rotation to face target
	var desired_rotation = direction.angle() + PI/2
	var current_rotation = owner_ship.rotation
	var angle_diff = angle_difference(current_rotation, desired_rotation)
	
	var command = {"thrust": 0.0, "turn": 0.0, "fire": false}
	
	# Turn to face target
	if abs(angle_diff) > 0.1:
		command.turn = sign(angle_diff) * -1.0  # Turn towards target
	
	# Move based on distance
	if distance > attack_range:
		# Too far - move closer
		command.thrust = 0.8
	elif distance < attack_range * 0.5:
		# Too close - back away
		command.thrust = -0.3
	else:
		# Good range - minimal movement
		command.thrust = 0.1
	
	# Fire if facing target and in range
	if distance < attack_range and abs(angle_diff) < 0.3:
		command.fire = true
	
	return command

func get_flee_command() -> Dictionary:
	"""Flee from current threat"""
	if not current_target:
		return get_general_flee_command()
	
	# Calculate flee direction (away from threat)
	var flee_direction = (owner_ship.global_position - current_target.global_position).normalized()
	var desired_rotation = flee_direction.angle() + PI/2
	var current_rotation = owner_ship.rotation
	var angle_diff = angle_difference(current_rotation, desired_rotation)
	
	var command = {"thrust": 1.0, "turn": 0.0, "fire": false}
	
	# Turn to face flee direction
	if abs(angle_diff) > 0.1:
		command.turn = sign(angle_diff) * -1.0
	
	return command

func get_general_flee_command() -> Dictionary:
	"""Flee in a random direction when no specific threat"""
	# Just move away from system center
	var flee_direction = owner_ship.global_position.normalized()
	var desired_rotation = flee_direction.angle() + PI/2
	var current_rotation = owner_ship.rotation
	var angle_diff = angle_difference(current_rotation, desired_rotation)
	
	var command = {"thrust": 1.0, "turn": 0.0, "fire": false}
	
	if abs(angle_diff) > 0.1:
		command.turn = sign(angle_diff) * -1.0
	
	return command

func angle_difference(current: float, target: float) -> float:
	"""Calculate shortest angle difference"""
	var diff = target - current
	while diff > PI:
		diff -= TAU
	while diff < -PI:
		diff += TAU
	return diff

func get_current_state_name() -> String:
	"""Get current state as string for debugging"""
	return AIState.keys()[ai_state]
