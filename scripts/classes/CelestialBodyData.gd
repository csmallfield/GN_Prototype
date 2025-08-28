# =============================================================================
# CELESTIAL BODY DATA RESOURCE  
# =============================================================================
# CelestialBodyData.gd
extends Resource
class_name CelestialBodyData

@export var id: String = ""
@export var name: String = ""
@export var type: String = "planet"  # "planet", "station"
@export var description: String = ""
@export var flavor_text: String = ""

# Position and appearance
@export_group("Transform")
@export var position: Vector2 = Vector2.ZERO
@export var scale: float = 1.0

# Landing and interaction
@export_group("Landing")
@export var can_land: bool = false
@export var services: Array[String] = []

# Government and society
@export_group("Society")
@export var government: String = "independent"
@export var tech_level: int = 3
@export var population: int = 0

# Graphics and animations
@export_group("Graphics")
@export var planet_library_id: String = "default"  # Reference to planet library
@export var sprite_path: String = ""  # For stations or custom sprites
@export var animations: Array[PlanetAnimationData] = []

# Services configuration
@export_group("Services")
@export var shipyard_available_ships: Array[String] = []
