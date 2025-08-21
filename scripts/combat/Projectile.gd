# =============================================================================
# FIXED PROJECTILE.GD - Added missing setup_projectile method
# =============================================================================

extends Area2D
class_name Projectile

@export var speed: float = 1000.0
@export var damage: float = 10.0
@export var lifetime: float = 2.0
@export var owner_faction: Government.Faction = Government.Faction.INDEPENDENT

var velocity: Vector2
var age: float = 0.0
var shooter: Node2D

func _ready():
	# Add to projectiles group for debugging
	add_to_group("projectiles")
	
	# CRITICAL: Set collision layers properly
	collision_layer = 4    # Projectiles are on layer 3 (bit 2 = value 4)
	collision_mask = 1     # Can hit Ships on layer 1 (bit 0 = value 1)
	
	# Enable collision detection
	monitoring = true
	monitorable = true
	
	# Connect signals for BOTH body and area detection
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# IMPORTANT: Make sure we have a collision shape
	if not get_node_or_null("CollisionShape2D"):
		push_error("Projectile has no CollisionShape2D!")
	
	print("Projectile collision setup: layer=", collision_layer, " mask=", collision_mask)

# ADD THIS MISSING METHOD - This is what WeaponHardpoint is trying to call!
func setup_projectile(weapon_data: Weapon, fire_position: Vector2, fire_direction: Vector2, ship_owner: Node2D):
	"""Setup the projectile with weapon parameters - CRITICAL MISSING METHOD"""
	# Set position
	global_position = fire_position
	
	# Set velocity from weapon data and direction
	speed = weapon_data.projectile_speed
	velocity = fire_direction * speed
	
	# Set damage
	damage = weapon_data.damage
	
	# Set shooter reference
	shooter = ship_owner
	
	# Rotate sprite to match movement direction
	if velocity.length() > 0:
		rotation = velocity.angle()
	
	print("✅ Projectile setup complete:")
	print("  Position: ", global_position)
	print("  Velocity: ", velocity)
	print("  Speed: ", speed)
	print("  Damage: ", damage)
	print("  Shooter: ", shooter.name if shooter else "unknown")

func _physics_process(delta):
	# Move the projectile
	position += velocity * delta
	
	# FIXED: Rotate sprite to match movement direction
	if velocity.length() > 0:
		rotation = velocity.angle()
	
	age += delta
	
	# Destroy after lifetime
	if age >= lifetime:
		print("Projectile expired after ", age, " seconds")
		queue_free()

func _on_body_entered(body):
	print("Projectile body_entered: ", body.name, " type: ", body.get_class())
	hit_target(body)

func _on_area_entered(area):
	print("Projectile area_entered: ", area.name, " type: ", area.get_class())
	# Check if area's parent is a ship
	var parent = area.get_parent()
	if parent and parent != shooter:
		hit_target(parent)

func hit_target(target):
	# Don't hit the shooter
	if target == shooter:
		print("Ignoring shooter hit: ", target.name)
		return
	
	# FIXED: Handle different node types that might be hit
	var actual_ship = find_ship_from_collision(target)
	if not actual_ship:
		print("Could not find ship from collision target: ", target.name)
		return
	
	# Don't hit the shooter (check again with actual ship)
	if actual_ship == shooter:
		print("Ignoring shooter hit after ship resolution: ", actual_ship.name)
		return
	
	# Check if it's a ship with health
	if actual_ship.has_method("take_damage"):
		print("*** PROJECTILE HIT CONFIRMED *** Target: ", actual_ship.name, " Damage: ", damage)
		# FIXED: Pass both damage amount AND the shooter as arguments
		actual_ship.take_damage(damage, shooter)
		
		# Create a small visual effect at hit point
		create_hit_effect(actual_ship.global_position)
		
		queue_free()
	else:
		print("Hit ", actual_ship.name, " but it has no take_damage method")

func find_ship_from_collision(collision_target: Node) -> Node:
	"""Find the actual ship node from whatever collision node was hit"""
	var current = collision_target
	
	# Walk up the node tree to find a ship (RigidBody2D with take_damage method)
	while current != null:
		# Check if this node is a ship
		if current.has_method("take_damage") and (current is RigidBody2D or current is CharacterBody2D):
			return current
		
		# Check if this is a known ship class
		if current.get_class() == "NPCShip" or current.get_class() == "PlayerShip":
			return current
		
		# Move up to parent
		current = current.get_parent()
	
	# If we couldn't find a ship, return the original target and let the caller handle it
	return collision_target

func create_hit_effect(pos: Vector2):
	"""Create a simple hit effect"""
	# You can expand this later with particles, but for now just print
	print("*** HIT EFFECT at ", pos, " ***")
