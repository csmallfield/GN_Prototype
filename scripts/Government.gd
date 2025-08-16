# Government.gd - Simple government/faction system
extends Resource
class_name Government

enum Faction {
	CONFEDERATION,
	INDEPENDENT,
	PIRATES,
	REBELS,
	MERCHANT_GUILD
}

@export var faction: Faction = Faction.INDEPENDENT
@export var name: String = "Independent"
@export var color: Color = Color.WHITE

# Relationships (-1 to 1, where -1 is hostile, 1 is allied)
@export var relationships: Dictionary = {
	Faction.CONFEDERATION: 0.0,
	Faction.INDEPENDENT: 0.0,
	Faction.PIRATES: 0.0,
	Faction.REBELS: 0.0,
	Faction.MERCHANT_GUILD: 0.0
}

func get_relationship_with(other_faction: Faction) -> float:
	return relationships.get(other_faction, 0.0)

func is_hostile_to(other_faction: Faction) -> bool:
	return get_relationship_with(other_faction) < -0.3

func is_allied_with(other_faction: Faction) -> bool:
	return get_relationship_with(other_faction) > 0.3
