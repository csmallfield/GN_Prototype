# =============================================================================
# WEAPON RESOURCE - Defines weapon characteristics and behavior
# =============================================================================
# Weapon.gd
extends Resource
class_name Weapon

enum WeaponType {
	PROJECTILE,     # Bullets, missiles - travel time, can miss
	BEAM,           # Lasers - instant hit, continuous damage  
	PULSE           # Burst weapons - instant hit, discrete damage
}

enum DamageType {
	ENERGY,         # Reduced by shields first
	KINETIC,        # Reduced by armor more
	EXPLOSIVE       # Damage spreads to nearby ships
}

# Basic Properties
@export var weapon_name: String = "Basic Laser"
@export var weapon_type: WeaponType = WeaponType.PULSE
@export var damage_type: DamageType = DamageType.ENERGY

# Combat Stats
@export var damage: float = 10.0
@export var fire_rate: float = 2.0           # Shots per second
@export var range: float = 800.0
@export var energy_cost: float = 5.0
@export var accuracy: float = 0.9            # 0.0-1.0, affects spread

# Projectile Properties (for PROJECTILE type)
@export var projectile_speed: float = 1000.0
@export var projectile_scene: PackedScene    # The visual projectile

# Visual/Audio
@export var muzzle_flash_scene: PackedScene
@export var fire_sound: AudioStream
@export var impact_sound: AudioStream

# Weapon Balance
@export var reload_time: float = 0.0         # Time between shots (calculated from fire_rate)
@export var burst_count: int = 1            # Shots per trigger pull
@export var burst_delay: float = 0.1        # Time between burst shots

func _ready():
	# Calculate reload time from fire rate
	if fire_rate > 0:
		reload_time = 1.0 / fire_rate

func get_time_between_shots() -> float:
	"""Get the time between individual shots"""
	return reload_time

func get_burst_duration() -> float:
	"""Get total time for a complete burst"""
	if burst_count <= 1:
		return 0.0
	return (burst_count - 1) * burst_delay

func is_projectile_weapon() -> bool:
	return weapon_type == WeaponType.PROJECTILE

func is_instant_hit_weapon() -> bool:
	return weapon_type in [WeaponType.BEAM, WeaponType.PULSE]

# Static weapon definitions - we'll expand this as we add more weapons
static func create_basic_laser() -> Weapon:
	var weapon = Weapon.new()
	weapon.weapon_name = "Basic Laser"
	weapon.weapon_type = WeaponType.PROJECTILE  # Changed from PULSE to PROJECTILE
	weapon.damage_type = DamageType.ENERGY
	weapon.damage = 15.0
	weapon.fire_rate = 3.0
	weapon.range = 600.0
	weapon.energy_cost = 3.0
	weapon.accuracy = 0.95
	weapon.projectile_speed = 800.0  # Add projectile speed
	weapon.reload_time = 1.0 / weapon.fire_rate
	return weapon

static func create_plasma_cannon() -> Weapon:
	var weapon = Weapon.new()
	weapon.weapon_name = "Plasma Cannon"
	weapon.weapon_type = WeaponType.PROJECTILE
	weapon.damage_type = DamageType.ENERGY
	weapon.damage = 25.0
	weapon.fire_rate = 1.5
	weapon.range = 800.0
	weapon.energy_cost = 8.0
	weapon.accuracy = 0.85
	weapon.projectile_speed = 800.0
	weapon.reload_time = 1.0 / weapon.fire_rate
	return weapon

static func create_mass_driver() -> Weapon:
	var weapon = Weapon.new()
	weapon.weapon_name = "Mass Driver"
	weapon.weapon_type = WeaponType.PROJECTILE
	weapon.damage_type = DamageType.KINETIC
	weapon.damage = 35.0
	weapon.fire_rate = 1.0
	weapon.range = 1000.0
	weapon.energy_cost = 2.0
	weapon.accuracy = 0.9
	weapon.projectile_speed = 1200.0
	weapon.reload_time = 1.0 / weapon.fire_rate
	return weapon
