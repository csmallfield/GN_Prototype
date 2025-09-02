# =============================================================================
# CELESTIAL BODY DATA RESOURCE  
# =============================================================================
# CelestialBodyData.gd
extends Resource
class_name CelestialBodyData

@export var id: String = "" ## "Unique identifier for this celestial body (used for referencing in code)"
@export var name: String = "" ## "Display name shown to the player in-game"
@export_enum("planet", "station", "entity") var type: String = "planet" ## "Type of celestial body - affects gameplay mechanics and available interactions"
@export var description: String = "" ## "Brief description displayed in system info and targeting displays"
@export var flavor_text: String = "" ## "Atmospheric text shown when viewing or approaching this celestial body"

# Position and appearance
@export_group("Transform")
@export var position: Vector2 = Vector2.ZERO ## "Position in the system using world coordinates"
@export var scale: float = 1.0 ## "Size multiplier for the visual representation (1.0 = normal size)"

# Landing and interaction
@export_group("Landing")
@export var can_land: bool = false ## "Whether the player can land on this celestial body"
@export_flags("Shipyard", "Commodity Exchange", "Equipment Dealer", "Mission Computer", "Bar", "Refuel", "Repair", "Bank") var services_flags: int = 0 ## "Available services when landed - multiple selections allowed via checkboxes"

# Helper function to convert flags to string array
func get_services_array() -> Array[String]:
	var services: Array[String] = []
	var service_names = ["Shipyard", "Commodity Exchange", "Equipment Dealer", "Mission Computer", "Bar", "Refuel", "Repair", "Bank"]
	
	for i in range(service_names.size()):
		if services_flags & (1 << i):
			services.append(service_names[i])
	
	return services

# Government and society
@export_group("Society")
@export_enum("Independent", "Federation", "Empire", "Corporate", "Rebel", "Pirate", "Military", "Theocracy", "Confederation", "Colony") var government: String = "Independent" ## "Political faction controlling this celestial body - affects available missions and reputation"
@export_range(0, 7) var tech_level: int = 3 ## "Technological advancement level (0=Stone Age, 7=Post-Stellar) - affects available equipment and ships"
@export var population: int = 0 ## "Population count - affects economic activity, mission availability, and traffic density"

# Graphics and animations
@export_group("Graphics")
@export var planet_library_id: String = "default" ## "Reference ID for planet appearance in the planet library system"
@export var sprite_path: String = "" ## "Custom sprite path for stations or unique entities (overrides planet library if set)"
@export var animations: Array[PlanetAnimationData] = [] ## "Animation effects applied to this celestial body (rotation, pulsing, etc.)"

# Services configuration
@export_group("Services")
@export var shipyard_available_ships: Array[String] = [] ## "Ship type IDs available for purchase at this location's shipyard service"
