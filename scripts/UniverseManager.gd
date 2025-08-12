# =============================================================================
# UNIVERSE MANAGER - Main controller for the game universe
# =============================================================================
# UniverseManager.gd - Singleton (AutoLoad)
extends Node

signal system_changed(new_system_id)
signal celestial_body_approached(body_data)

var current_system_id: String = ""
var universe_data: Dictionary = {}
var player_ship: Node = null

# Mission system integration
var current_system_missions: Dictionary = {}  # planet_id -> Array[mission_data]

func _ready():
	load_universe_data()
	change_system("sol_system")  # Starting system

func load_universe_data():
	var file = FileAccess.open("res://data/universe.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_text)
		if parse_result == OK:
			universe_data = json.data
		else:
			push_error("Failed to parse universe.json")
	else:
		push_error("Could not open universe.json")

func change_system(system_id: String):
	if system_id in universe_data.systems:
		current_system_id = system_id
		
		# Generate missions for all planets in the new system
		generate_system_missions()
		
		system_changed.emit(system_id)
		print("Entered system: ", system_id)
	else:
		push_error("System not found: " + system_id)

func generate_system_missions():
	"""Generate cargo missions for all landable planets in the current system"""
	current_system_missions.clear()
	
	var system_data = get_current_system()
	if system_data.is_empty():
		return
	
	var celestial_bodies = system_data.get("celestial_bodies", [])
	var mission_count = 0
	
	print("=== Generating missions for ", system_data.get("name", current_system_id), " ===")
	
	for body in celestial_bodies:
		# Only generate missions for landable planets/stations
		if body.get("can_land", false):
			var planet_id = body.get("id", "")
			var missions = MissionGenerator.generate_missions_for_planet(body, current_system_id)
			
			if not missions.is_empty():
				current_system_missions[planet_id] = missions
				mission_count += missions.size()
				print("Generated ", missions.size(), " missions for ", body.get("name", planet_id))
	
	print("=== Total missions generated: ", mission_count, " ===")

func get_missions_for_planet(planet_id: String) -> Array[Dictionary]:
	"""Get available cargo missions for a specific planet"""
	if current_system_missions.has(planet_id):
		return current_system_missions[planet_id].duplicate()
	return []

func get_current_system() -> Dictionary:
	if current_system_id in universe_data.systems:
		return universe_data.systems[current_system_id]
	return {}

func get_celestial_body(body_id: String) -> Dictionary:
	var system = get_current_system()
	for body in system.get("celestial_bodies", []):
		if body.id == body_id:
			return body
	return {}

func can_travel_to_system(system_id: String) -> bool:
	var current_system = get_current_system()
	var connections = current_system.get("connections", [])
	return system_id in connections

func remove_mission_from_system(planet_id: String, mission_data: Dictionary):
	"""Remove an accepted mission from the current system's available missions"""
	if current_system_missions.has(planet_id):
		var planet_missions = current_system_missions[planet_id]
		
		# Find and remove the mission by comparing cargo type, weight, and destination
		for i in range(planet_missions.size() - 1, -1, -1):
			var mission = planet_missions[i]
			if (mission.get("cargo_type") == mission_data.get("cargo_type") and
				mission.get("cargo_weight") == mission_data.get("cargo_weight") and
				mission.get("destination_planet") == mission_data.get("destination_planet") and
				mission.get("destination_system") == mission_data.get("destination_system")):
				
				planet_missions.remove_at(i)
				print("Removed mission from available list: ", mission_data.get("cargo_type"), " to ", mission_data.get("destination_planet_name"))
				break
		
		# Update the stored missions
		current_system_missions[planet_id] = planet_missions
