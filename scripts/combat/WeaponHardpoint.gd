# =============================================================================
# WEAPON HARDPOINT - Manages weapon mounting, aiming, and firing
# =============================================================================
# WeaponHardpoint.gd
extends Node2D
class_name WeaponHardpoint

# Weapon configuration
@export var weapon_data: Weapon
@export var is_turret: bool = false           # Can rotate independently of ship
@export var turret_turn_rate: float = 3.0     # Radians per second
@export var fire_point_offset: Vector2 = Vector2(0, -20)  # Where projectiles spawn

# Current state
var current_target: Node2D = null
var can_fire: bool = true
var reload_timer: float = 0.0
var burst_shots_remaining: int = 0
var burst_timer: float = 0.0
var ship_owner: Node2D = null

# Audio
var audio_player: AudioStreamPlayer2D

# Visual effects
var muzzle_flash_timer: float = 0.0
@onready var muzzle_flash: Node2D = $MuzzleFlash

func _ready():
	# Create audio player
	audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	
	# Find our ship owner
	ship_owner = get_ship_owner()
	
	# DEBUG: Check ship owner
	print("=== HARDPOINT SETUP DEBUG ===")
	print("Hardpoint parent: ", get_parent().name if get_parent() else "NULL")
	print("Ship owner found: ", ship_owner.name if ship_owner else "NULL")
	print("Ship owner type: ", ship_owner.get_class() if ship_owner else "NULL")
	print("=============================")
	
	# Hide muzzle flash initially
	if muzzle_flash:
		muzzle_flash.visible = false
	else:
		print("⚠️ No MuzzleFlash node found!")
	
	# Auto-mount a weapon if none exists
	if not weapon_data:
		print("No weapon mounted, creating default weapon...")
		mount_weapon(Weapon.create_basic_laser())

func _process(delta):
	update_reload_timer(delta)
	update_burst_timer(delta)
	update_muzzle_flash_timer(delta)
	
	if is_turret and current_target:
		update_turret_rotation(delta)

func get_ship_owner() -> Node2D:
	"""Find the ship this hardpoint belongs to"""
	print("=== SEARCHING FOR SHIP OWNER ===")
	var current = self
	var search_depth = 0
	
	while current and search_depth < 10:  # Prevent infinite loops
		print("Checking node: ", current.name, " (type: ", current.get_class(), ")")
		
		# Check if this node is a ship (RigidBody2D with combat capabilities)
		if current is RigidBody2D:
			print("Found RigidBody2D: ", current.name)
			# Additional checks to make sure it's actually a ship
			if current.has_method("take_damage") or current.get_node_or_null("ShipCombatSystem"):
				print("✅ Found ship: ", current.name)
				return current
		
		current = current.get_parent()
		search_depth += 1
	
	print("❌ No ship owner found after searching ", search_depth, " levels")
	return null

func mount_weapon(weapon: Weapon):
	"""Mount a weapon to this hardpoint"""
	weapon_data = weapon
	print("=== MOUNTING WEAPON ===")
	print("Weapon name: ", weapon.weapon_name)
	print("Weapon type: ", weapon.weapon_type)
	print("Is projectile: ", weapon.is_projectile_weapon())
	print("Damage: ", weapon.damage)
	print("Fire rate: ", weapon.fire_rate)
	print("======================")

func set_target(target: Node2D):
	"""Set the current target for this weapon"""
	current_target = target

func clear_target():
	"""Clear the current target"""
	current_target = null

func can_hit_target(target: Node2D) -> bool:
	"""Check if we can hit the target (range, line of sight, etc.)"""
	if not target or not weapon_data:
		return false
	
	var distance = global_position.distance_to(target.global_position)
	if distance > weapon_data.range:
		return false
	
	# TODO: Add line-of-sight checking for obstacles
	
	return true

func get_firing_angle_to_target(target: Node2D) -> float:
	"""Calculate the angle needed to hit the target"""
	if not target:
		return rotation
	
	var target_pos = target.global_position
	
	# For projectile weapons, lead the target
	if weapon_data and weapon_data.is_projectile_weapon():
		target_pos = calculate_intercept_point(target)
	
	return global_position.angle_to_point(target_pos)

func calculate_intercept_point(target: Node2D) -> Vector2:
	"""Calculate where to aim to intercept a moving target"""
	if not target.has_method("get") or "linear_velocity" not in target:
		return target.global_position
	
	var target_velocity = target.linear_velocity
	var target_pos = target.global_position
	var projectile_speed = weapon_data.projectile_speed
	
	# Simple intercept calculation
	var relative_pos = target_pos - global_position
	var relative_velocity = target_velocity
	
	# Time to intercept (solving quadratic equation)
	var a = relative_velocity.dot(relative_velocity) - projectile_speed * projectile_speed
	var b = 2 * relative_pos.dot(relative_velocity)
	var c = relative_pos.dot(relative_pos)
	
	var discriminant = b * b - 4 * a * c
	
	if discriminant < 0 or abs(a) < 0.001:
		# Can't intercept or target not moving - just aim at current position
		return target_pos
	
	var t1 = (-b - sqrt(discriminant)) / (2 * a)
	var t2 = (-b + sqrt(discriminant)) / (2 * a)
	
	var intercept_time = t1 if t1 > 0 else t2
	if intercept_time <= 0:
		return target_pos
	
	return target_pos + target_velocity * intercept_time

func update_turret_rotation(delta: float):
	"""Update turret rotation to track target"""
	if not current_target or not can_hit_target(current_target):
		return
	
	var desired_angle = get_firing_angle_to_target(current_target)
	var angle_diff = angle_difference(rotation, desired_angle)
	
	# Rotate towards target at turret turn rate
	var max_rotation = turret_turn_rate * delta
	var rotation_amount = sign(angle_diff) * min(abs(angle_diff), max_rotation)
	rotation += rotation_amount

func angle_difference(current: float, target: float) -> float:
	"""Calculate shortest angle difference"""
	var diff = target - current
	while diff > PI:
		diff -= 2 * PI
	while diff < -PI:
		diff += 2 * PI
	return diff

func update_reload_timer(delta: float):
	"""Update weapon reload timer"""
	if reload_timer > 0:
		reload_timer -= delta
		if reload_timer <= 0:
			can_fire = true

func update_burst_timer(delta: float):
	"""Update burst firing timer"""
	if burst_timer > 0:
		burst_timer -= delta
		if burst_timer <= 0 and burst_shots_remaining > 0:
			fire_single_shot()

func update_muzzle_flash_timer(delta: float):
	"""Update muzzle flash display"""
	if muzzle_flash_timer > 0:
		muzzle_flash_timer -= delta
		if muzzle_flash_timer <= 0 and muzzle_flash:
			muzzle_flash.visible = false

func try_fire() -> bool:
	"""Attempt to fire the weapon"""
	if not can_fire_now():
		return false
	
	start_firing_sequence()
	return true

func can_fire_now() -> bool:
	"""Check if weapon can fire right now - with debug info"""
	var has_weapon = weapon_data != null
	var can_fire_flag = can_fire
	var reload_ready = reload_timer <= 0
	var no_burst = burst_shots_remaining == 0
	var has_owner = ship_owner != null
	
	# Debug output
	print("=== WEAPON DEBUG ===")
	print("Has weapon: ", has_weapon)
	print("Can fire flag: ", can_fire_flag)
	print("Reload ready: ", reload_ready, " (timer: ", reload_timer, ")")
	print("No burst active: ", no_burst, " (remaining: ", burst_shots_remaining, ")")
	print("Has ship owner: ", has_owner)
	if ship_owner:
		print("Ship owner: ", ship_owner.name)
	else:
		print("Ship owner is NULL!")
	print("===================")
	
	return (has_weapon and 
			can_fire_flag and 
			reload_ready and 
			no_burst and
			has_owner)

func start_firing_sequence():
	"""Begin firing sequence (handles burst weapons)"""
	if not weapon_data:
		return
	
	burst_shots_remaining = weapon_data.burst_count
	fire_single_shot()

func fire_single_shot():
	"""Fire a single shot - with detailed debug"""
	print("🔥 FIRE_SINGLE_SHOT START")
	print("Weapon data exists: ", weapon_data != null)
	print("Burst shots remaining: ", burst_shots_remaining)
	
	if not weapon_data or burst_shots_remaining <= 0:
		print("❌ Exiting fire_single_shot - no weapon or no burst shots")
		return
	
	print("✅ Continuing with shot...")
	
	# Calculate fire direction
	var fire_direction = Vector2(0, -1).rotated(global_rotation)
	var fire_position = global_position + fire_point_offset.rotated(global_rotation)
	
	print("Fire position: ", fire_position)
	print("Fire direction: ", fire_direction)
	print("Global rotation: ", global_rotation)
	
	# Create projectile or instant hit
	if weapon_data.is_projectile_weapon():
		print("🚀 Weapon is projectile type - calling fire_projectile")
		fire_projectile(fire_position, fire_direction)
	else:
		print("⚡ Weapon is instant hit type - calling fire_instant_hit")
		#fire_instant_hit(fire_position, fire_direction)
	
	print("🔥 Weapon fired, handling burst logic...")
	
	# Handle burst firing
	burst_shots_remaining -= 1
	if burst_shots_remaining > 0:
		burst_timer = weapon_data.burst_delay
		print("More burst shots remaining: ", burst_shots_remaining)
	else:
		# Burst complete, start reload
		can_fire = false
		reload_timer = weapon_data.reload_time
		print("Burst complete, reload timer set to: ", reload_timer)
	
	# Visual and audio effects
	play_fire_effects()
	print("🔥 FIRE_SINGLE_SHOT COMPLETE")

func fire_projectile(fire_position: Vector2, fire_direction: Vector2):
	"""Fire a projectile weapon - FIXED: Deferred creation to avoid physics conflicts"""
	print("🚀 FIRING PROJECTILE DEBUG:")
	print("Fire position: ", fire_position)
	print("Fire direction: ", fire_direction)
	print("Weapon speed: ", weapon_data.projectile_speed)
	
	# FIXED: Store the firing parameters and defer the actual creation
	var firing_data = {
		"weapon_data": weapon_data,
		"fire_position": fire_position,
		"fire_direction": fire_direction,
		"ship_owner": ship_owner
	}
	
	# Defer the projectile creation to avoid physics query conflicts
	call_deferred("create_projectile_deferred", firing_data)

func create_projectile_deferred(firing_data: Dictionary):
	"""Create the projectile after physics frame is complete"""
	var weapon_data = firing_data.weapon_data
	var fire_position = firing_data.fire_position
	var fire_direction = firing_data.fire_direction
	var ship_owner = firing_data.ship_owner
	
	# Check if Projectile scene exists
	var projectile_scene_path = "res://scenes/combat/Projectile.tscn"
	if not ResourceLoader.exists(projectile_scene_path):
		print("❌ ERROR: Projectile scene not found at: ", projectile_scene_path)
		return
	
	# Try to load the scene
	var projectile_scene = load(projectile_scene_path)
	if not projectile_scene:
		print("❌ ERROR: Could not load Projectile scene")
		return
	
	print("✅ Projectile scene loaded successfully")
	
	# Try to instantiate
	var projectile = projectile_scene.instantiate()
	if not projectile:
		print("❌ ERROR: Could not instantiate projectile")
		return
	
	print("✅ Projectile instantiated: ", projectile.name)
	
	# Add to scene
	var scene_root = ship_owner.get_tree().current_scene
	if not scene_root:
		print("❌ ERROR: Could not find scene root")
		return
	
	scene_root.add_child(projectile)
	print("✅ Projectile added to scene")
	
	# Setup the projectile
	if projectile.has_method("setup_projectile"):
		projectile.setup_projectile(weapon_data, fire_position, fire_direction, ship_owner)
		print("✅ Projectile setup complete")
		print("Projectile position: ", projectile.global_position)
		#print("Projectile velocity: ", projectile.linear_velocity)
	else:
		print("❌ ERROR: Projectile missing setup_projectile method")

func find_target_in_direction(start_pos: Vector2, direction: Vector2) -> Node2D:
	"""Find the first target hit by an instant weapon"""
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		start_pos, 
		start_pos + direction * weapon_data.range
	)
	query.exclude = [ship_owner]  # Don't hit our own ship
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.collider
	
	return null

func create_beam_effect(start_pos: Vector2, end_pos: Vector2):
	"""Create visual effect for beam weapons"""
	# Simple line effect - can be enhanced later
	var line = Line2D.new()
	line.add_point(to_local(start_pos))
	line.add_point(to_local(end_pos))
	line.width = 3.0
	line.default_color = Color.CYAN
	
	add_child(line)
	
	# Fade out the beam
	var tween = create_tween()
	tween.tween_property(line, "modulate", Color.TRANSPARENT, 0.1)
	tween.tween_callback(line.queue_free)

func play_fire_effects():
	"""Play muzzle flash and sound effects"""
	# Muzzle flash
	if muzzle_flash:
		muzzle_flash.visible = true
		muzzle_flash_timer = 0.1  # Flash duration
	
	# Sound effect
	if weapon_data and weapon_data.fire_sound and audio_player:
		audio_player.stream = weapon_data.fire_sound
		audio_player.play()
	

# Debug visualization
func _draw():
	if not OS.is_debug_build() or not weapon_data:
		return
	
	# Draw weapon range
	#draw_arc(Vector2.ZERO, weapon_data.range, 0, TAU, 32, Color.GREEN, 2.0)
	
	# Draw fire point
	draw_circle(fire_point_offset, 3.0, Color.RED)
	
	# Draw target line
	if current_target:
		var target_pos = to_local(current_target.global_position)
		draw_line(Vector2.ZERO, target_pos, Color.YELLOW, 1.0)
		
#TEMP Code Below this line
func create_simple_test_projectile(fire_position: Vector2, fire_direction: Vector2):
	"""Create a simple test projectile without using the scene"""
	print("🧪 Creating simple test projectile...")
	
	# Create a simple RigidBody2D
	var projectile = RigidBody2D.new()
	projectile.name = "TestProjectile"
	projectile.gravity_scale = 0
	projectile.linear_damp = 0
	
	# Add a visible sprite
	var sprite = Sprite2D.new()
	sprite.texture = load("res://icon.svg")  # Use the Godot icon as projectile
	sprite.scale = Vector2(0.05, 0.05)  # Make it very small
	sprite.modulate = Color.CYAN  # Make it cyan
	projectile.add_child(sprite)
	
	# Add collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 5
	collision.shape = shape
	projectile.add_child(collision)
	
	# Set position and velocity
	projectile.global_position = fire_position
	projectile.linear_velocity = fire_direction * 800  # Fast bullet
	
	# Add to scene
	ship_owner.get_tree().current_scene.add_child(projectile)
	
	# Auto-destroy after 3 seconds
	projectile.get_tree().create_timer(3.0).timeout.connect(projectile.queue_free)
	
	print("✅ Test projectile created at: ", fire_position, " with velocity: ", projectile.linear_velocity)
