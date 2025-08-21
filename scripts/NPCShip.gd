# =============================================================================
# NPC SHIP - Updated for Phase 1 Simple AI
# =============================================================================
extends RigidBody2D
class_name NPCShip

# Ship stats
@export var thrust_power: float = 500.0
@export var rotation_speed: float = 3.0
@export var max_velocity: float = 400.0

@onready var sprite = $Sprite2D
@onready var engine_particles = $EngineParticles

# Combat stats
var hull: float = 100.0
var max_hull: float = 100.0
var shields: float = 50.0
var max_shields: float = 50.0
var weapon: Weapon = null

# AI 
var simple_ai: Node

# Visual variety
var ship_hue_shift: float = 0.0

func _ready():
	# Add to NPC group for easy finding
	add_to_group("npc_ships")
	
	# Debug: Print what we are
	print("NPCShip _ready() called for: ", name)
	print("  Node type: ", get_class())
	print("  Parent: ", get_parent().name if get_parent() else "NULL")
	
	# Set collision layers for combat
	collision_layer = 1    # Ships are on layer 1
	collision_mask = 5     # Ships + Projectiles: 1 + 4 = 5
	
	# Set random hue shift for visual variety
	ship_hue_shift = randf() * 360.0
	apply_hue_shift()
	
	# Set up combat stats
	max_hull = 100.0
	hull = max_hull
	max_shields = 30.0
	shields = max_shields
	
	# Add simple AI (WeaponHardpoint should already exist in the scene)
	setup_simple_ai()
	
	if not weapon:
		setup_weapon()
	
	print("NPCShip initialization complete: ", name)

func setup_weapon():
	var weapon_scene = preload("res://scenes/combat/LaserCannon.tscn")
	if weapon_scene:
		weapon = weapon_scene.instantiate()
		add_child(weapon)
		
func setup_simple_ai():
	"""Add the simple AI brain"""
	# Create a basic Node to hold the AI script
	var ai_node = Node.new()
	ai_node.name = "SimpleAI"
	ai_node.set_script(preload("res://scripts/ai/SimpleNPCAI.gd"))
	add_child(ai_node)
	simple_ai = ai_node
	print("Added simple AI to NPC: ", name)

func _integrate_forces(state):
	"""Handle physics integration with AI input"""
	
	# Get AI input (set by the AI in move_in_direction)
	var ai_turn = get_meta("ai_turn_input", 0.0)
	var ai_thrust = get_meta("ai_thrust_input", 0.0)
	
	# Apply rotation
	if abs(ai_turn) > 0.05:  # Small dead zone
		state.angular_velocity = ai_turn * rotation_speed
	else:
		state.angular_velocity *= 0.9  # Damping when not turning
	
	# Apply thrust
	if ai_thrust > 0.1:  # Small dead zone
		var thrust_vector = Vector2(0, -thrust_power * ai_thrust).rotated(rotation)
		state.apply_central_force(thrust_vector)
		engine_particles.emitting = true
	else:
		engine_particles.emitting = false
	
	# Limit velocity
	if state.linear_velocity.length() > max_velocity:
		state.linear_velocity = state.linear_velocity.normalized() * max_velocity

func take_damage(amount: float, attacker: Node2D = null):
	print("NPC taking damage: ", amount, " from: ", attacker.name if attacker else "unknown")
	
	# Shields first
	var shield_damage = min(amount, shields)
	shields -= shield_damage
	amount -= shield_damage
	
	# Then hull
	if amount > 0:
		hull -= amount
	
	print("NPC status - Hull: ", hull, "/", max_hull, " Shields: ", shields, "/", max_shields)
	
	# Check if destroyed
	if hull <= 0:
		destroy()
	
	# SIMPLE REACTIVE BEHAVIOR: Shoot back if shot
	if attacker and weapon and weapon.can_fire():
		shoot_back_at_attacker(attacker)

func shoot_back_at_attacker(attacker: Node2D):
	if not attacker or not weapon:
		return
	
	var fire_direction = (attacker.global_position - global_position).normalized()
	weapon.fire(fire_direction, Government.Faction.INDEPENDENT)
	print("NPC shooting back at attacker!")

func destroy():
	print("NPC destroyed!")
	queue_free()

func get_hull_percent() -> float:
	"""Get hull as a percentage"""
	if max_hull <= 0:
		return 0
	return hull / max_hull

func apply_hue_shift():
	"""Apply random hue shift for visual variety"""
	if sprite and sprite.texture:
		var hue_color = Color.from_hsv(ship_hue_shift / 360.0, 0.6, 1.0)
		sprite.modulate = hue_color

func cleanup_and_remove():
	"""Clean up and remove this NPC"""
	print("NPC cleanup and remove: ", name)
	
	# Notify traffic manager
	var traffic_manager = get_tree().get_first_node_in_group("traffic_manager")
	if traffic_manager and traffic_manager.has_method("_on_npc_removed"):
		traffic_manager._on_npc_removed(self)
	
	queue_free()

# Configure method for traffic manager compatibility
func configure_with_archetype(archetype, ship_faction: Government.Faction = Government.Faction.INDEPENDENT):
	"""Configure this NPC - simplified for Phase 1"""
	print("NPC configured as simple Phase 1 ship, faction: ", Government.Faction.keys()[ship_faction])
	# For Phase 1, we ignore archetypes and just use the simple AI
