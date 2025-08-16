# ShipStats.gd - Resource for ship statistics
extends Resource
class_name ShipStats

# Combat stats
@export_group("Defense")
@export var max_hull: float = 100.0
@export var max_shields: float = 50.0
@export var shield_recharge_rate: float = 5.0  # per second
@export var armor_rating: float = 0.0  # damage reduction

@export_group("Physics")
@export var mass: float = 10.0
@export var inertia_dampening: float = 0.1  # for more responsive controls

@export_group("Combat")
@export var weapon_slots: int = 2
@export var turret_turn_rate: float = 3.0  # radians per second

# Existing movement stats already in your ships.json can stay there
# This is just for combat-related stats
