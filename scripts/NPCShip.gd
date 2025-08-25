# =============================================================================
# NPC SHIP - Enhanced for Phase 2 Social Combat (Scene Script)
# =============================================================================
extends RigidBody2D

# Ship stats
@export var thrust_power: float = 500.0
@export var rotation_speed: float = 3.0
@export var max_velocity: float = 400.0

@onready var sprite = $Sprite2D
@onready var engine_particles = $EngineParticles

# Combat stats - keep it simple for Phase 1
var hull: float = 100.0
var max_hull: float = 100.0
var shields: float = 50.0
var max_shields: float = 50.0

# AI reference
var combat_ai: Phase1CombatAI

# Weapon reference
var weapon_hardpoint: WeaponHardpoint

# NEW: Social Combat Integration
var social_combat_system: CombatSocialSystem

func _ready():
	add_to_group("npc_ships")
	print("NPCShip _ready() called for: ", name)
	
	# Set collision for combat
	collision_layer = 1    # Ships layer
	collision_mask = 5     # Ships + Projectiles
	
	# Visual variety
	var hue_shift = randf() * 360.0
	apply_hue_shift(hue_shift)
	
	# Set up combat stats
	max_hull = 100.0
	hull = max_hull
	max_shields = 30.0
	shields = max_shields
	
	# Get weapon hardpoint
	weapon_hardpoint = get_node_or_null("WeaponHardpoint")
	if weapon_hardpoint:
		# Ensure it has a weapon
		if not weapon_hardpoint.weapon_data:
			weapon_hardpoint.mount_weapon(Weapon.create_basic_laser())
		print("✅ NPC weapon hardpoint ready for: ", name)
	else:
		print("⚠️ WARNING: No weapon hardpoint found on ", name)
	
	# Add the new Enhanced Phase1CombatAI (which includes social combat)
	var combat_ai = Phase1CombatAI.new()
	combat_ai.name = "Phase1CombatAI"
	add_child(combat_ai)
	print("✅ Enhanced Phase1CombatAI added to: ", name)
	
	# Get reference to social combat system (created by the AI)
	await get_tree().process_frame  # Wait for AI to create the social system
	social_combat_system = get_node_or_null("CombatSocialSystem")
	if social_combat_system:
		print("✅ Social combat system found on: ", name)
	else:
		print("⚠️ WARNING: Social combat system not found on ", name)
	
	print("NPCShip initialization complete: ", name)

func _integrate_forces(state):
	"""Handle physics with AI input"""
	
	# Get AI input
	var ai_turn = get_meta("ai_turn_input", 0.0)
	var ai_thrust = get_meta("ai_thrust_input", 0.0)
	var ai_fire = get_meta("ai_fire_input", false)
	
	# Apply rotation
	if abs(ai_turn) > 0.05:
		state.angular_velocity = ai_turn * rotation_speed
	else:
		state.angular_velocity *= 0.9
	
	# Apply thrust
	if ai_thrust > 0.1:
		var thrust_vector = Vector2(0, -thrust_power * ai_thrust).rotated(rotation)
		state.apply_central_force(thrust_vector)
		engine_particles.emitting = true
	elif ai_thrust < -0.1:
		var thrust_vector = Vector2(0, thrust_power * abs(ai_thrust)).rotated(rotation)
		state.apply_central_force(thrust_vector)
		engine_particles.emitting = true
	else:
		engine_particles.emitting = false
	
	# Handle weapon firing
	if ai_fire and weapon_hardpoint:
		weapon_hardpoint.try_fire()
	
	# Limit velocity
	if state.linear_velocity.length() > max_velocity:
		state.linear_velocity = state.linear_velocity.normalized() * max_velocity

func take_damage(amount: float, attacker: Node2D = null):
	"""Take damage and delegate to social combat system for intelligent handling"""
	print("*** NPC TAKING DAMAGE *** Ship: ", name, " Amount: ", amount, " From: ", attacker.name if attacker else "unknown")
	
	# Apply damage to shields first, then hull
	var shield_damage = min(amount, shields)
	shields -= shield_damage
	amount -= shield_damage
	
	if amount > 0:
		hull -= amount
	
	print("NPC status - Hull: ", hull, "/", max_hull, " Shields: ", shields, "/", max_shields)
	
	# NEW: Enhanced damage handling with social combat integration
	if social_combat_system and attacker:
		# Let the social combat system determine if this is a legitimate threat
		# It will handle friendly fire detection and mutual aid coordination
		social_combat_system.on_ship_attacked(attacker, shield_damage + amount)
		print("✅ Delegated attack handling to social combat system")
	else:
		# Fallback to direct AI notification if social system isn't available
		var combat_ai_node = get_node_or_null("Phase1CombatAI")
		if combat_ai_node and attacker:
			combat_ai_node.notify_attacked_by(attacker)
			print("⚠️ Fallback: Direct AI notification (no social combat system)")
		else:
			print("❌ Could not notify AI - combat_ai: ", combat_ai_node, " attacker: ", attacker)
	
	# Check if destroyed
	if hull <= 0:
		print("*** NPC DESTROYED ***")
		destroy()

func destroy():
	"""Ship destroyed - cleanup"""
	print("*** NPC DESTROYED ***")
	
	# NEW: Notify social combat system of our destruction so others stop helping us
	if social_combat_system:
		social_combat_system.queue_free()  # Clean up help requests, etc.
	
	# Create explosion effect
	var explosion = ColorRect.new()
	explosion.size = Vector2(100, 100)
	explosion.position = global_position - explosion.size / 2
	explosion.color = Color.ORANGE
	get_tree().current_scene.add_child(explosion)
	
	# Use a simple timer instead of tween
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.one_shot = true
	timer.timeout.connect(func(): explosion.queue_free())
	explosion.add_child(timer)
	timer.start()
	
	print("Explosion created with 0.5s timer cleanup")
	
	# Clean up the ship
	cleanup_and_remove()

func get_hull_percent() -> float:
	if max_hull <= 0:
		return 0
	return hull / max_hull

func get_shield_percent() -> float:
	if max_shields <= 0:
		return 0
	return shields / max_shields

func apply_hue_shift(hue_shift: float):
	if sprite and sprite.texture:
		var hue_color = Color.from_hsv(hue_shift / 360.0, 0.6, 1.0)
		sprite.modulate = hue_color

func cleanup_and_remove():
	print("NPC cleanup and remove: ", name)
	var traffic_manager = get_tree().get_first_node_in_group("traffic_manager")
	if traffic_manager and traffic_manager.has_method("_on_npc_removed"):
		traffic_manager._on_npc_removed(self)
	queue_free()

# Keep for compatibility with TrafficManager
func configure_with_archetype(archetype, ship_faction: Government.Faction = Government.Faction.INDEPENDENT):
	print("NPC configured for Phase 2 social combat, faction: ", Government.Faction.keys()[ship_faction])
	
	# Wait for AI to be ready, then set the archetype
	await get_tree().process_frame
	var ai = get_node_or_null("Phase1CombatAI")
	if ai:
		ai.archetype = archetype
		print("✅ Archetype set to: ", archetype.archetype_name)
		
		# Enable debug mode for testing (can be removed later)
		if social_combat_system and OS.is_debug_build():
			social_combat_system.enable_debug(true)

# =============================================================================
# DEBUG AND TESTING METHODS
# =============================================================================

func debug_get_social_status() -> Dictionary:
	"""Get current social combat status for debugging"""
	if social_combat_system:
		return social_combat_system.get_debug_status()
	return {"error": "no_social_system"}

func debug_enable_social_combat_debug(enabled: bool = true):
	"""Enable debug output for social combat system"""
	if social_combat_system:
		social_combat_system.enable_debug(enabled)

func debug_is_friendly_with(other_ship: Node2D) -> bool:
	"""Check if this ship considers another ship friendly (for debugging)"""
	if social_combat_system:
		return social_combat_system.is_friendly_ship(other_ship)
	return false

func debug_get_archetype_name() -> String:
	"""Get the archetype name for debugging"""
	var ai = get_node_or_null("Phase1CombatAI")
	if ai and ai.archetype:
		return ai.archetype.archetype_name
	return "unknown"
