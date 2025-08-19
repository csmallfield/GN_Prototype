# Complete replacement for Weapon.gd

extends Node2D
class_name Weapon

@export var weapon_name: String = "Laser Cannon"
@export var damage: float = 10.0
@export var fire_rate: float = 3.0
@export var projectile_speed: float = 1200.0
@export var energy_cost: float = 5.0
@export var spread_angle: float = 0.05

var cooldown: float = 0.0
var owner_ship: Node2D

func _ready():
	owner_ship = get_parent()

func _process(delta):
	if cooldown > 0:
		cooldown -= delta

func can_fire() -> bool:
	return cooldown <= 0

func fire(target_direction: Vector2, owner_faction: Government.Faction = Government.Faction.INDEPENDENT):
	if not can_fire():
		return false
	
	# Load and instantiate the projectile scene
	var projectile_scene = preload("res://scenes/combat/Projectile.tscn")
	var projectile = projectile_scene.instantiate()
	
	# Setup projectile
	projectile.damage = damage
	projectile.speed = projectile_speed
	projectile.shooter = owner_ship
	projectile.owner_faction = owner_faction
	
	# Add spread
	var spread = randf_range(-spread_angle, spread_angle)
	var fire_direction = target_direction.rotated(spread)
	
	# Position and velocity
	projectile.velocity = fire_direction * projectile_speed
	projectile.rotation = fire_direction.angle()
	
	# Add to scene at owner's position
	owner_ship.get_tree().root.add_child(projectile)
	projectile.global_position = owner_ship.global_position
	
	# Set cooldown
	cooldown = 1.0 / fire_rate
	
	print("Weapon fired by: ", owner_ship.name)
	return true
