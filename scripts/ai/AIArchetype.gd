# =============================================================================
# AI ARCHETYPE - Enhanced with Social Combat Parameters
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

# NEW: Social Combat Parameters
@export_group("Social Combat")
@export var help_radius: float = 800.0           # Distance to respond to help requests
@export var max_help_responders: int = 3         # Max ships that will respond to help
@export var help_response_chance: float = 0.8    # Probability of responding to help (0-1)
@export var friendly_fire_forgiveness: float = 0.8  # Probability of forgiving friendly fire (0-1)

@export_group("Economic")
@export var trade_value_preference: float = 0.8  # How much they value profitable routes
@export var risk_tolerance: float = 0.4          # Willingness to take dangerous routes

# Create preset archetypes with social combat parameters
static func create_trader() -> AIArchetype:
	var archetype = AIArchetype.new()
	archetype.archetype_type = ArchetypeType.TRADER
	archetype.archetype_name = "Independent Trader"
	
	# Original parameters
	archetype.aggression = 0.1
	archetype.self_preservation = 0.9
	archetype.curiosity = 0.4
	archetype.discipline = 0.7
	archetype.preferred_speed = 0.7
	archetype.threat_threshold = 0.6  # Flee early
	archetype.trade_value_preference = 0.9
	archetype.risk_tolerance = 0.3
	
	# NEW: Social combat parameters
	archetype.help_radius = 1000.0
	archetype.max_help_responders = 4
	archetype.help_response_chance = 0.9  # Traders help each other
	archetype.friendly_fire_forgiveness = 0.9  # Generally forgiving
	
	return archetype

static func create_pirate() -> AIArchetype:
	var archetype = AIArchetype.new()
	archetype.archetype_type = ArchetypeType.PIRATE
	archetype.archetype_name = "Pirate Raider"
	
	# Original parameters
	archetype.aggression = 0.8
	archetype.self_preservation = 0.6
	archetype.curiosity = 0.8
	archetype.discipline = 0.4
	archetype.preferred_speed = 0.8
	archetype.threat_threshold = 0.3  # Fight longer
	archetype.risk_tolerance = 0.8
	
	# NEW: Social combat parameters
	archetype.help_radius = 600.0
	archetype.max_help_responders = 2  # Pirates less likely to help
	archetype.help_response_chance = 0.4  # Selfish - only sometimes help
	archetype.friendly_fire_forgiveness = 0.2  # Hair-trigger tempers
	
	return archetype

static func create_military() -> AIArchetype:
	var archetype = AIArchetype.new()
	archetype.archetype_type = ArchetypeType.MILITARY
	archetype.archetype_name = "Military Patrol"
	
	# Original parameters
	archetype.aggression = 0.5
	archetype.self_preservation = 0.5
	archetype.curiosity = 0.6
	archetype.discipline = 0.9
	archetype.preferred_speed = 0.6
	archetype.formation_keeping = 0.9
	archetype.threat_threshold = 0.25  # Fight to the end
	archetype.backup_calling = 0.9
	
	# NEW: Social combat parameters
	archetype.help_radius = 1600.0  # Largest response radius
	archetype.max_help_responders = 10  # Most organized response
	archetype.help_response_chance = 0.9  # Disciplined - almost always help
	archetype.friendly_fire_forgiveness = 0.9  # Military discipline - forgive accidents
	
	return archetype

func get_personality_modifier(base_value: float, personality_trait: float) -> float:
	"""Apply personality variation to base values"""
	return base_value * (0.5 + personality_trait * 0.5)

# NEW: Social combat helper functions
func should_respond_to_help_request(distance: float) -> bool:
	"""Determine if this ship should respond to a help request based on distance and personality"""
	if distance > help_radius:
		return false
	
	return randf() < help_response_chance

func should_forgive_friendly_fire(damage_amount: float = 0.0) -> bool:
	"""Determine if friendly fire should be forgiven"""
	# For now, ignore damage amount - just use base forgiveness rate
	return randf() < friendly_fire_forgiveness

func get_help_urgency_score(hull_percentage: float, shield_percentage: float) -> float:
	"""Calculate how urgently this ship needs help (0-1, higher = more urgent)"""
	var hull_urgency = 1.0 - hull_percentage
	var shield_urgency = (1.0 - shield_percentage) * 0.5  # Shields less critical
	
	# Combine with self-preservation trait
	var urgency_modifier = get_personality_modifier(1.0, self_preservation)
	
	return min(1.0, (hull_urgency + shield_urgency) * urgency_modifier)
