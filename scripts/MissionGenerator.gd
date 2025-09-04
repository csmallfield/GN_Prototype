# =============================================================================
# MISSION GENERATOR - Integer ID System (Fixed)
# =============================================================================
# MissionGenerator.gd
extends RefCounted
class_name MissionGenerator

# Mission parameters unchanged
const MIN_MISSIONS_PER_PLANET = 3
const MAX_MISSIONS_PER_PLANET = 5
const MIN_CARGO_WEIGHT = 20
const MAX_CARGO_WEIGHT = 75
const BASE_PAYMENT_PER_JUMP = 2000
const WEIGHT_PAYMENT_MODIFIER = 0.8

const CARGO_TYPES = [
	"Generic Cargo",
	"Manufactured Goods", 
	"Raw Materials",
	"Consumer Electronics",
	"Medical Supplies",
	"Food Supplies",
	"Industrial Components",
	"Luxury Items"
]

static func generate_missions_for_planet(origin_planet_data: Dictionary, origin_system_id: int) -> Array[Dictionary]:
	"""Generate missions using integer system ID"""
	var missions: Array[Dictionary] = []
	var num_missions = randi_range(MIN_MISSIONS_PER_PLANET, MAX_MISSIONS_PER_PLANET)
	
	var planet_name = origin_planet_data.get("name", "Unknown Planet")
	var system_name = UniverseManager.get_system_name(origin_system_id)
	print("Generating ", num_missions, " missions for ", planet_name, " in ", system_name, " (ID: ", origin_system_id, ")")
	
	# Get all possible destinations
	var destinations = get_all_landable_destinations()
	if destinations.is_empty():
		push_error("No destinations found for mission generation")
		return missions
	
	# Remove origin planet from destinations using integer IDs
	var origin_planet_id = origin_planet_data.get("id", -1)
	destinations = destinations.filter(func(dest): 
		return not (dest.planet_id == origin_planet_id and dest.system_id == origin_system_id)
	)
	
	if destinations.is_empty():
		print("No valid destinations after filtering origin")
		return missions
	
	# Generate missions
	for i in range(num_missions):
		var mission = generate_single_mission(origin_planet_data, origin_system_id, destinations)
		if not mission.is_empty():
			missions.append(mission)
	
	print("Generated ", missions.size(), " missions successfully")
	return missions

static func generate_single_mission(origin_planet_data: Dictionary, origin_system_id: int, destinations: Array[Dictionary]) -> Dictionary:
	"""Generate single mission using integer IDs"""
	if destinations.is_empty():
		return {}
	
	var destination = destinations[randi() % destinations.size()]
	
	# Generate cargo details
	var cargo_type = CARGO_TYPES[randi() % CARGO_TYPES.size()]
	var cargo_weight = randi_range(MIN_CARGO_WEIGHT, MAX_CARGO_WEIGHT)
	
	# Calculate payment based on distance using integer IDs
	var jump_distance = calculate_jump_distance(origin_system_id, destination.system_id)
	var base_payment = BASE_PAYMENT_PER_JUMP * jump_distance
	var weight_bonus = int(cargo_weight * WEIGHT_PAYMENT_MODIFIER)
	var total_payment = base_payment + weight_bonus
	
	# Add payment variance
	var payment_variance = randf_range(0.8, 1.2)
	total_payment = int(total_payment * payment_variance)
	
	var mission = {
		"cargo_type": cargo_type,
		"cargo_weight": cargo_weight,
		"origin_planet": origin_planet_data.get("id", -1),  # Integer ID
		"origin_system": origin_system_id,  # Integer ID
		"destination_planet": destination.planet_id,  # Integer ID
		"destination_system": destination.system_id,  # Integer ID
		"destination_planet_name": destination.planet_name,  # Name for display
		"destination_system_name": destination.system_name,  # Name for display
		"payment": total_payment,
		"jump_distance": jump_distance
	}
	
	print("Generated mission: ", cargo_weight, " tons of ", cargo_type, " to ", destination.planet_name, " (", jump_distance, " jumps) - ", total_payment, " credits")
	
	return mission

static func get_all_landable_destinations() -> Array[Dictionary]:
	"""Get all landable destinations using integer IDs"""
	var destinations: Array[Dictionary] = []
	
	# Ensure all systems are loaded
	UniverseManager.ensure_all_systems_loaded()
	
	if not UniverseManager.universe_data.has("systems"):
		push_error("No universe data available")
		return destinations
	
	var systems = UniverseManager.universe_data.systems
	
	# systems now has integer keys - iterate properly
	for system_id in systems.keys():
		# system_id is now an integer
		var system_data = systems[system_id]
		var system_name = system_data.get("name", "Unknown System")
		var celestial_bodies = system_data.get("celestial_bodies", [])
		
		for body in celestial_bodies:
			if body.get("can_land", false):
				var destination = {
					"system_id": system_id,  # Integer ID
					"system_name": system_name,  # Name for display
					"planet_id": body.get("id", -1),  # Integer ID - body.id is now integer from database
					"planet_name": body.get("name", "Unknown"),  # Name for display
					"planet_type": body.get("type", "unknown")
				}
				destinations.append(destination)
	
	print("Found ", destinations.size(), " landable destinations across all systems")
	return destinations

static func calculate_jump_distance(origin_system_id: int, destination_system_id: int) -> int:
	"""Calculate jump distance between systems using integer IDs"""
	if origin_system_id == destination_system_id:
		return 0
	
	var system_positions = get_system_positions()
	
	if not system_positions.has(origin_system_id) or not system_positions.has(destination_system_id):
		push_warning("System not found in positions map: ", origin_system_id, " or ", destination_system_id)
		return 1
	
	var origin_pos = system_positions[origin_system_id]
	var dest_pos = system_positions[destination_system_id]
	
	var map_distance = origin_pos.distance_to(dest_pos)
	
	# Convert distance to jump count
	var jumps = 1
	if map_distance > 150: jumps = 2
	if map_distance > 300: jumps = 3
	if map_distance > 450: jumps = 4
	if map_distance > 600: jumps = 5
	
	return jumps

static func get_system_positions() -> Dictionary:
	"""Get system positions using integer IDs as keys"""
	var map_width = 480
	var map_height = 500
	var margin = 50
	var positions = {}
	
	# Get positions from database through UniverseManager
	UniverseManager.ensure_all_systems_loaded()
	var systems = UniverseManager.universe_data.get("systems", {})
	
	# systems has integer keys
	for system_id in systems.keys():
		var system_data = systems[system_id]
		var map_pos = system_data.get("map_position", {"x": 0.5, "y": 0.5})
		positions[system_id] = Vector2(
			margin + map_width * map_pos.x,
			margin + map_height * map_pos.y
		)
	
	return positions

static func get_mission_description(mission_data: Dictionary) -> String:
	"""Generate mission description using names for display"""
	var cargo_type = mission_data.get("cargo_type", "Unknown Cargo")
	var cargo_weight = mission_data.get("cargo_weight", 0)
	var destination_planet = mission_data.get("destination_planet_name", "Unknown Planet")
	var destination_system = mission_data.get("destination_system_name", "Unknown System")
	var payment = mission_data.get("payment", 0)
	var jumps = mission_data.get("jump_distance", 0)
	
	var description = "Deliver %d tons of %s to %s in the %s system.\n" % [cargo_weight, cargo_type, destination_planet, destination_system]
	description += "Distance: %d hyperspace jump%s\n" % [jumps, "s" if jumps != 1 else ""]
	description += "Payment: %s credits" % format_credits(payment)
	
	return description

static func format_credits(amount: int) -> String:
	"""Format credit amounts with commas"""
	var formatted = str(amount)
	var result = ""
	var count = 0
	
	for i in range(formatted.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = formatted[i] + result
		count += 1
	
	return result

# =============================================================================
# DEBUG METHODS - Updated for integer IDs
# =============================================================================

static func debug_generate_test_missions() -> Array[Dictionary]:
	"""Generate test missions using integer IDs"""
	print("=== GENERATING TEST MISSIONS ===")
	
	# Get a test planet from current system
	var current_system = UniverseManager.get_current_system()
	var celestial_bodies = current_system.get("celestial_bodies", [])
	
	if celestial_bodies.is_empty():
		print("No celestial bodies in current system for testing")
		return []
	
	var test_planet = celestial_bodies[0]  # Use first planet
	var current_system_id = UniverseManager.current_system_id  # This is now an integer
	
	var missions = generate_missions_for_planet(test_planet, current_system_id)
	
	print("=== TEST MISSIONS GENERATED ===")
	for mission in missions:
		print(get_mission_description(mission))
		print("---")
	
	return missions

static func debug_print_all_destinations():
	"""Print all destinations with integer IDs"""
	print("=== ALL LANDABLE DESTINATIONS ===")
	var destinations = get_all_landable_destinations()
	for dest in destinations:
		print("System ID ", dest.system_id, " (", dest.system_name, ") - Planet ID ", dest.planet_id, " (", dest.planet_name, ") - Type: ", dest.planet_type)
	print("=== TOTAL: ", destinations.size(), " destinations ===")

static func debug_test_jump_calculations():
	"""Test jump calculations with integer IDs"""
	print("=== TESTING JUMP CALCULATIONS ===")
	
	# Get some system IDs for testing
	UniverseManager.ensure_all_systems_loaded()
	var systems = UniverseManager.universe_data.get("systems", {})
	var system_ids = systems.keys()
	
	if system_ids.size() >= 4:
		var test_pairs = [
			[system_ids[0], system_ids[1]],
			[system_ids[0], system_ids[2]],
			[system_ids[1], system_ids[3]] if system_ids.size() > 3 else [system_ids[1], system_ids[2]],
			[system_ids[2], system_ids[0]]
		]
		
		for pair in test_pairs:
			var jumps = calculate_jump_distance(pair[0], pair[1])
			var name1 = UniverseManager.get_system_name(pair[0])
			var name2 = UniverseManager.get_system_name(pair[1])
			print("System ", pair[0], " (", name1, ") to System ", pair[1], " (", name2, "): ", jumps, " jumps")
	
	print("=== JUMP CALCULATION TESTS COMPLETE ===")
