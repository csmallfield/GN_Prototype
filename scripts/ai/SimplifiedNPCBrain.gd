# SimplifiedNPCBrain.gd - Complete version
extends Node
class_name SimplifiedNPCBrain

@export var archetype: NPCArchetype
@export var faction: Government.Faction = Government.Faction.INDEPENDENT

var owner_ship: NPCShip
var current_goal: String = "idle"
var target: Node2D
var flee_target: Node2D
var detection_radius: float = 1500.0

func _ready():
	owner_ship = get_parent()

func think(delta: float):
	# Player-centric optimization: Only think in detail if near player
	var player = UniverseManager.player_ship
	if not player:
		return
	
	var distance_to_player = owner_ship.global_position.distance_to(player.global_position)
	
	if distance_to_player > 3000:
		# Far from player - just continue current action
		return
	
	# Detailed thinking for NPCs near player
	evaluate_situation()

func evaluate_situation():
	var threats = detect_threats()
	var opportunities = detect_opportunities()
	
	# Simple priority system
	if threats.size() > 0 and should_flee():
		current_goal = "flee"
		flee_target = threats[0]
	elif opportunities.size() > 0 and should_attack():
		current_goal = "attack"
		target = opportunities[0]
	else:
		current_goal = "wander"

func detect_threats() -> Array:
	"""Detect potential threats (hostile ships, player if hostile)"""
	var threats = []
	var ships_in_range = get_ships_in_radius(detection_radius)
	
	for ship in ships_in_range:
		if is_threat(ship):
			threats.append(ship)
	
	# Sort by distance (closest first)
	threats.sort_custom(func(a, b): 
		return owner_ship.global_position.distance_to(a.global_position) < owner_ship.global_position.distance_to(b.global_position)
	)
	
	return threats

func detect_opportunities() -> Array:
	"""Detect opportunities (weak enemies, valuable targets)"""
	var opportunities = []
	var ships_in_range = get_ships_in_radius(detection_radius)
	
	for ship in ships_in_range:
		if is_opportunity(ship):
			opportunities.append(ship)
	
	return opportunities

func get_ships_in_radius(radius: float) -> Array:
	"""Get all ships within detection radius"""
	var ships = []
	
	# Check player
	var player = UniverseManager.player_ship
	if player and owner_ship.global_position.distance_to(player.global_position) <= radius:
		ships.append(player)
	
	# Check other NPCs
	var npcs = get_tree().get_nodes_in_group("npc_ships")
	for npc in npcs:
		if npc != owner_ship and is_instance_valid(npc):
			if owner_ship.global_position.distance_to(npc.global_position) <= radius:
				ships.append(npc)
	
	return ships

func is_threat(ship: Node2D) -> bool:
	"""Determine if a ship is a threat"""
	if not ship:
		return false
	
	# For now, simple logic - can be expanded
	if ship == UniverseManager.player_ship:
		# Player is a threat if we're pirates
		return faction == Government.Faction.PIRATES
	
	# Other logic here - check faction relationships
	return false

func is_opportunity(ship: Node2D) -> bool:
	"""Determine if a ship is an opportunity to attack"""
	if not ship or not archetype:
		return false
	
	# Only aggressive NPCs see opportunities
	if archetype.aggression < 0.5:
		return false
	
	# Simple check - is target weak?
	if ship.has_method("get_hull_percent"):
		return ship.get_hull_percent() < 0.5
	
	return false

func should_flee() -> bool:
	if not owner_ship or not archetype:
		return false
	
	# Check hull percentage
	if owner_ship.has_method("get_hull_percent"):
		var hull_percent = owner_ship.get_hull_percent()
		return hull_percent < archetype.flee_threshold
	
	return false

func should_attack() -> bool:
	if not archetype:
		return false
	return randf() < archetype.attack_weak_targets
