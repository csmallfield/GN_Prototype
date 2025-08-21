# =============================================================================
# SIMPLE WEAPON HARDPOINT - Phase 1 minimal weapon firing
# =============================================================================
extends Node2D
class_name SimpleWeaponHardpoint

@export var weapon_data: Weapon
var reload_timer: float = 0.0
var ship_owner: Node2D

@onready var muzzle_flash: Node2D = $MuzzleFlash

func _ready():
	ship_owner = find_ship_owner()
	
	if muzzle_flash:
		muzzle_flash.visible = false
	
	# Auto-mount weapon if none
	if not weapon_data:
		weapon_data = Weapon.create_basic_laser()
		print("Auto-mounted basic laser")
	
	print("SimpleWeaponHardpoint ready for: ", ship_owner.name if ship_owner else "unknown")

func _process(delta):
	if reload_timer > 0:
		reload_timer -= delta

func find_ship_owner() -> Node2D:
	"""Find the ship this belongs to"""
	var current = get_parent()
	while current:
		if current is RigidBody2D and (current.has_method("take_damage") or current.get_class() in ["NPCShip", "PlayerShip"]):
			return current
		current = current.get_parent()
	return null

func try_fire() -> bool:
	"""Try to fire - simplified version"""
	if not can_fire_now():
		return false
	
	fire_projectile()
	return true

func can_fire_now() -> bool:
	return weapon_data != null and reload_timer <= 0.0 and ship_owner != null

func fire_projectile():
	"""Fire a projectile - corrected method names"""
	if not weapon_data:
		return
	
	# Calculate fire position and direction
	var fire_position = global_position
	var fire_direction = Vector2(0, -1).rotated(global_rotation)
	
	print("🔥 Firing from: ", fire_position, " direction: ", fire_direction)
	
	# Load and create projectile
	var projectile_scene = load("res://scenes/combat/Projectile.tscn")
	if not projectile_scene:
		print("❌ Could not load Projectile scene")
		return
	
	var projectile = projectile_scene.instantiate()
	if not projectile:
		print("❌ Could not instantiate projectile")
		return
	
	# Add to scene
	ship_owner.get_tree().current_scene.add_child(projectile)
	
	# FIXED: Use the correct method name "setup" instead of "setup_projectile"
	if projectile.has_method("setup"):
		projectile.setup(
			fire_position,
			fire_direction, 
			weapon_data.projectile_speed,
			weapon_data.damage,
			ship_owner
		)
		print("✅ Projectile setup complete with setup() method")
	else:
		print("❌ ERROR: Projectile missing setup() method")
		# Fallback: set properties directly
		projectile.global_position = fire_position
		projectile.velocity = fire_direction * weapon_data.projectile_speed
		projectile.damage = weapon_data.damage
		projectile.shooter = ship_owner
		print("🔧 Used fallback projectile setup")
	
	print("✅ Projectile created and configured")
	
	# Start reload
	reload_timer = weapon_data.reload_time
	
	# Show muzzle flash
	show_muzzle_flash()

func create_simple_projectile(fire_position: Vector2, fire_direction: Vector2):
	"""Fallback: create a simple projectile without scene"""
	print("🔧 Creating fallback projectile")
	
	var projectile = Area2D.new()
	projectile.name = "SimpleProjectile"
	
	# Visual
	var sprite = Sprite2D.new()
	sprite.texture = load("res://icon.svg")
	sprite.scale = Vector2(0.05, 0.05)
	sprite.modulate = Color.YELLOW
	projectile.add_child(sprite)
	
	# Collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 3
	collision.shape = shape
	projectile.add_child(collision)
	
	# Set collision layers
	projectile.collision_layer = 4  # Projectiles
	projectile.collision_mask = 1   # Ships
	
	# Add to scene
	ship_owner.get_tree().current_scene.add_child(projectile)
	
	# Position and setup
	projectile.global_position = fire_position
	projectile.set_meta("velocity", fire_direction * 800)
	projectile.set_meta("damage", weapon_data.damage)
	projectile.set_meta("shooter", ship_owner)
	
	# Simple movement script
	var script = GDScript.new()
	script.source_code = """
extends Area2D

var velocity: Vector2
var damage: float = 10.0
var shooter: Node2D
var age: float = 0.0

func _ready():
	velocity = get_meta('velocity', Vector2.ZERO)
	damage = get_meta('damage', 10.0)
	shooter = get_meta('shooter', null)
	body_entered.connect(_on_body_entered)

func _process(delta):
	position += velocity * delta
	age += delta
	if age > 3.0:
		queue_free()

func _on_body_entered(body):
	if body == shooter:
		return
	if body.has_method('take_damage'):
		body.take_damage(damage, shooter)
		queue_free()
"""
	projectile.set_script(script)

func show_muzzle_flash():
	"""Show muzzle flash effect"""
	if muzzle_flash:
		muzzle_flash.visible = true
		# Hide after short time
		get_tree().create_timer(0.1).timeout.connect(func(): muzzle_flash.visible = false)
