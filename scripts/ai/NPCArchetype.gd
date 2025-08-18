# NPCArchetype.gd - Resource defining NPC behavior tendencies
extends Resource
class_name NPCArchetype

@export var archetype_name: String = "Trader"

# Core personality (0-1 scale)
@export_range(0.0, 1.0) var aggression: float = 0.2
@export_range(0.0, 1.0) var bravery: float = 0.3
@export_range(0.0, 1.0) var greed: float = 0.7
@export_range(0.0, 1.0) var loyalty: float = 0.5

# Combat preferences
@export_range(0.0, 1.0) var flee_threshold: float = 0.7  # Hull % to flee at
@export_range(0.0, 1.0) var attack_weak_targets: float = 0.1  # Chance to attack if stronger

# Simplified behavior weights
@export var behavior_weights: Dictionary = {
	"trade": 1.0,
	"flee": 0.8,
	"attack": 0.1,
	"patrol": 0.0,
	"escort": 0.0
}
