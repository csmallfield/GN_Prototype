# =============================================================================
# PLANET ANIMATION DATA RESOURCE
# =============================================================================
# PlanetAnimationData.gd  
extends Resource
class_name PlanetAnimationData

@export var parameter_name: String = ""
@export_enum("linear", "sine", "cosine", "pulse", "circular") var animation_type: String = "linear"
@export var rate: float = 1.0
@export var amplitude: float = 1.0
@export var offset: Vector2 = Vector2.ZERO
