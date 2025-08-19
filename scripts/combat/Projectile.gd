# Complete replacement for Projectile.gd

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
	# Set collision layers - CRITICAL FOR COMBAT
	collision_layer = 4  # Projectiles are on layer 3 (bit 2 = value 4)
	collision_mask = 1   # Can hit Ships on layer 1
	
	# Set monitoring to true to detect collisions
	monitoring = true
	monitorable = true
	
	# Connect signals
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	position += velocity * delta
	rotation = velocity.angle()
	age += delta
	
	if age >= lifetime:
		queue_free()

func _on_body_entered(body):
	# Don't hit the shooter
	if body == shooter:
		return
	
	# Check if it's a ship with health
	if body.has_method("take_damage"):
		print("Projectile hit: ", body.name)
		body.take_damage(damage, shooter)
		queue_free()
	else:
		print("Hit something without take_damage: ", body.name)
