# =============================================================================
# SYSTEM DATA RESOURCE
# =============================================================================
# SystemData.gd
extends Resource
class_name SystemData

@export var system_id: String = ""
@export var system_name: String = ""
@export var description: String = ""
@export var flavor_text: String = ""
@export var connections: Array[String] = []

# Map position (for hyperspace map display)
@export_group("Map Position")
@export var map_position: Vector2 = Vector2(0.5, 0.5)  # 0-1 range for percentage

# Starfield configuration
@export_group("Starfield")
@export var base_color: Vector3 = Vector3.ZERO
@export var star_density_multiplier: float = 1.0
@export var star_brightness_multiplier: float = 1.0
@export var twinkle_speed_override: float = -1.0  # -1 = use default

# Traffic configuration
@export_group("Traffic")
@export var spawn_frequency: float = 15.0
@export var max_npcs: int = 5
@export var spawn_frequency_variance: float = 5.0
@export var archetype_weights: Dictionary = {
	"trader": 0.6,
	"military": 0.3, 
	"pirate": 0.1
}

# NPC configuration
@export_group("NPC Config")
@export var npc_thrust_power: float = 500.0
@export var npc_rotation_speed: float = 3.0
@export var npc_max_velocity: float = 400.0
@export var npc_visit_duration_range: Vector2 = Vector2(3.0, 8.0)

# Economic
@export_group("Economy")
@export var hyperspace_recharge_cost: int = 200

# Celestial bodies in this system
@export_group("Celestial Bodies")
@export var celestial_bodies: Array[CelestialBodyData] = []
