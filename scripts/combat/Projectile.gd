# =============================================================================
# PROJECTILE - Handles projectile physics, collision, and damage
# =============================================================================
# Projectile.gd
extends RigidBody2D
class_name Projectile

# Projectile properties
var damage: float = 10.0
var damage_type: Weapon.DamageType = Weapon.DamageType.ENERGY
var max_range: float = 800.0
var firer: Node2D = null  # Who fired this projectile
var weapon_data: Weapon = null

# Internal tracking
var distance_traveled: float = 0.0
var start_position: Vector2
var impact_effect_scene: PackedScene

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var area_detector: Area2D = $AreaDetector

func _ready():
    # Set up collision detection
    if area_detector:
        area_detector.body_entered.connect(_on_body_entered)
        area_detector.area_entered.connect(_on_area_entered)
    
    # Store starting position for range calculation
    start_position = global_position
    
    # Set collision layers (adjust based on your project settings)
    collision_layer = 4  # Projectiles layer
    collision_mask = 1 | 2  # Collide with ships and environment
    
    # Auto-destroy after max lifetime (safety net)
    var max_lifetime = max_range / max(linear_velocity.length(), 100.0) + 2.0
    get_tree().create_timer(max_lifetime).timeout.connect(queue_free)

func _physics_process(delta):
    # Update distance traveled
    var movement = linear_velocity * delta
    distance_traveled += movement.length()
    
    # Destroy if out of range
    if distance_traveled >= max_range:
        destroy_projectile()

func setup_projectile(weapon: Weapon, fire_position: Vector2, fire_direction: Vector2, firing_ship: Node2D):
    """Initialize the projectile with weapon data and firing parameters"""
    weapon_data = weapon
    damage = weapon.damage
    damage_type = weapon.damage_type
    max_range = weapon.range
    firer = firing_ship
    
    # Set position and velocity
    global_position = fire_position
    
    # Apply accuracy - add some spread based on weapon accuracy
    var accuracy_spread = (1.0 - weapon.accuracy) * 0.2  # Max 0.2 radians spread
    var spread_angle = randf_range(-accuracy_spread, accuracy_spread)
    var final_direction = fire_direction.rotated(spread_angle)
    
    linear_velocity = final_direction * weapon.projectile_speed
    rotation = final_direction.angle()
    
    # Set visual properties based on weapon type
    setup_projectile_visuals(weapon)

func setup_projectile_visuals(weapon: Weapon):
    """Configure projectile appearance based on weapon type"""
    if not sprite:
        return
    
    # Set color and size based on damage type
    match weapon.damage_type:
        Weapon.DamageType.ENERGY:
            sprite.modulate = Color.CYAN
        Weapon.DamageType.KINETIC:
            sprite.modulate = Color.YELLOW
        Weapon.DamageType.EXPLOSIVE:
            sprite.modulate = Color.RED
    
    # Scale based on damage (bigger bullets for more damage)
    var scale_factor = 1.0 + (weapon.damage / 50.0)
    scale = Vector2(scale_factor, scale_factor)

func _on_body_entered(body: Node2D):
    """Handle collision with ships or other physics bodies"""
    # Don't hit the ship that fired us
    if body == firer:
        return
    
    # Don't hit other projectiles
    if body is Projectile:
        return
    
    # Apply damage if it's a ship
    if body.has_method("take_damage"):
        body.take_damage(damage, damage_type, firer)
        
        # Create impact effect
        create_impact_effect(body)
        
        # Destroy the projectile
        destroy_projectile()
    elif body.has_method("can_interact"):
        # Hit a celestial body or station - just destroy the projectile
        create_impact_effect(body)
        destroy_projectile()

func _on_area_entered(area: Area2D):
    """Handle collision with areas (shields, etc.)"""
    var area_parent = area.get_parent()
    
    # Don't hit our own ship
    if area_parent == firer:
        return
    
    # Check if it's a ship's area (interaction area, etc.)
    if area_parent.has_method("take_damage"):
        area_parent.take_damage(damage, damage_type, firer)
        create_impact_effect(area_parent)
        destroy_projectile()

func create_impact_effect(target: Node2D):
    """Create visual/audio impact effects"""
    # TODO: Add particle effects, sound, etc.
    # For now, just print debug info
    if OS.is_debug_build():
        print("Projectile hit ", target.name, " for ", damage, " damage")
    
    # Create simple impact flash
    var impact_flash = ColorRect.new()
    impact_flash.size = Vector2(20, 20)
    impact_flash.position = global_position - impact_flash.size / 2
    impact_flash.color = Color.WHITE
    impact_flash.z_index = 10  # Make sure it's visible
    
    # Add to the scene tree
    get_tree().current_scene.add_child(impact_flash)
    
    # Make sure the flash gets cleaned up
    var tween = get_tree().create_tween()
    tween.tween_property(impact_flash, "modulate", Color.TRANSPARENT, 0.2)
    tween.tween_callback(func(): 
        if is_instance_valid(impact_flash):
            impact_flash.queue_free()
    )

func destroy_projectile():
    """Clean up and remove the projectile"""
    # TODO: Add destruction effect if needed
    queue_free()

# Static function to create projectiles easily
static func create_projectile(weapon: Weapon, fire_position: Vector2, fire_direction: Vector2, firing_ship: Node2D) -> Projectile:
    var projectile_scene = load("res://scenes/combat/Projectile.tscn")
    var projectile = projectile_scene.instantiate()
    
    # Add to scene
    firing_ship.get_tree().current_scene.add_child(projectile)
    
    # Setup the projectile
    projectile.setup_projectile(weapon, fire_position, fire_direction, firing_ship)
    
    return projectile
