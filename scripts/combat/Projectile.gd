# Projectile.gd
extends Area2D
class_name Projectile

@export var speed: float = 1000.0
@export var damage: float = 10.0
@export var lifetime: float = 2.0
@export var owner_faction: Government.Faction = Government.Faction.INDEPENDENT

var velocity: Vector2
var age: float = 0.0
var shooter: Node2D  # Who fired this

func _ready():
	# Simple sprite - just a line or circle for now
	var sprite = Sprite2D.new()
	sprite.texture = preload("res://sprites/weapons/laser_bolt.png")  # Create a simple 4x16 white rect
	add_child(sprite)
	
	# Collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 4.0
	collision.shape = shape
	add_child(collision)
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta):
	position += velocity * delta
	age += delta
	
	if age >= lifetime:
		queue_free()

func _on_body_entered(body):
	if body == shooter:
		return  # Don't hit ourselves
	
	if body.has_method("take_damage"):
		body.take_damage(damage, shooter)
		queue_free()

func _on_area_entered(area):
	# For hitting other projectiles or shields later
	pass
