# =============================================================================
# AI ARCHETYPE - Defines behavioral characteristics for different ship types
# =============================================================================
extends Resource
class_name AIArchetype

enum ArchetypeType {
	TRADER,
	PIRATE, 
	MILITARY,
	ESCORT
}

@export var archetype_type: ArchetypeType = ArchetypeType.TRADER
@export var archetype_name: String = "Basic Trader"

# Behavioral parameters (0.0 to 1.0)
@export_group("Personality")
@export var aggression: float = 0.2         # How likely to start fights
@export var self_preservation: float = 0.7  # How quickly to flee danger
@export var curiosity: float = 0.5          # How likely to investigate things
@export var discipline: float = 0.6         # How well they follow orders/routes

@export_group("Movement")
@export var preferred_speed: float = 0.6     # Fraction of max speed when cruising
@export var formation_keeping: float = 0.3   # How well they maintain formations
@export var route_deviation: float = 0.3     # How much they deviate from optimal routes

@export_group("Combat")
@export var threat_threshold: float = 0.4    # Hull percentage to start fleeing
@export var engagement_range: float = 600.0  # Preferred combat distance
@export var backup_calling: float = 0.7      # Likelihood to call for help

@export_group("Economic")
@export var trade_value_preference: float = 0.8  # How much they value profitable routes
@export var risk_tolerance: float = 0.4          # Willingness to take dangerous routes

# Create preset archetypes
static func create_trader() -> AIArchetype:
	var archetype = AIArchetype.new()
	archetype.archetype_type = ArchetypeType.TRADER
	archetype.archetype_name = "Independent Trader"
	archetype.aggression = 0.1
	archetype.self_preservation = 0.9
	archetype.curiosity = 0.4
	archetype.discipline = 0.7
	archetype.preferred_speed = 0.7
	archetype.threat_threshold = 0.6  # Flee early
	archetype.trade_value_preference = 0.9
	archetype.risk_tolerance = 0.3
	return archetype

static func create_pirate() -> AIArchetype:
	var archetype = AIArchetype.new()
	archetype.archetype_type = ArchetypeType.PIRATE
	archetype.archetype_name = "Pirate Raider"
	archetype.aggression = 0.8
	archetype.self_preservation = 0.6
	archetype.curiosity = 0.8
	archetype.discipline = 0.4
	archetype.preferred_speed = 0.8
	archetype.threat_threshold = 0.3  # Fight longer
	archetype.risk_tolerance = 0.8
	return archetype

static func create_military() -> AIArchetype:
	var archetype = AIArchetype.new()
	archetype.archetype_type = ArchetypeType.MILITARY
	archetype.archetype_name = "Military Patrol"
	archetype.aggression = 0.5
	archetype.self_preservation = 0.5
	archetype.curiosity = 0.6
	archetype.discipline = 0.9
	archetype.preferred_speed = 0.6
	archetype.formation_keeping = 0.9
	archetype.threat_threshold = 0.25  # Fight to the end
	archetype.backup_calling = 0.9
	return archetype

func get_personality_modifier(base_value: float, personality_trait: float) -> float:
	"""Apply personality variation to base values"""
	return base_value * (0.5 + personality_trait * 0.5)
