# =============================================================================
# MISSION GENERATOR - Generates cargo delivery missions
# =============================================================================
# MissionGenerator.gd
extends RefCounted
class_name MissionGenerator

# Mission generation parameters
const MIN_MISSIONS_PER_PLANET = 3
const MAX_MISSIONS_PER_PLANET = 5
const MIN_CARGO_WEIGHT = 20
const MAX_CARGO_WEIGHT = 75
const BASE_PAYMENT_PER_JUMP = 2000  # Credits per hyperspace jump
const WEIGHT_PAYMENT_MODIFIER = 0.8  # Additional payment per ton

# Cargo types for variety (can be expanded later)
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

# System positions for jump distance calculation (matches hyperspace map)
static func get_system_positions() -> Dictionary:
	var map_width = 480
	var map_height = 500
	var margin = 50
	
	return {
		"sol_system": Vector2(margin + map_width * 0.3, margin + map_height * 0.5),
		"alpha_centauri": Vector2(margin + map_width * 0.45, margin + map_height * 0.4),
		"vega_system": Vector2(margin + map_width * 0.2, margin + map_height * 0.3),
		"sirius_system": Vector2(margin + map_width * 0.6, margin + map_height * 0.3),
		"rigel_system": Vector2(margin + map_width * 0.7, margin + map_height * 0.6),
		"arcturus_system": Vector2(margin + map_width * 0.1, margin + map_height * 0.7),
		"deneb_system": Vector2(margin + map_width * 0.4, margin + map_height * 0.8),
		"aldebaran_system": Vector2(margin + map_width * 0.8, margin + map_height * 0.4),
		"antares_system": Vector2(margin + map_width * 0.6, margin + map_height * 0.7),
		"capella_system": Vector2(margin + map_width * 0.2, margin + map_height * 0.6)
	}

static func generate_missions_for_planet(origin_planet_data: Dictionary, origin_system_id: String) -> Array[Dictionary]:
	"""Generate 3-5 random cargo missions for a planet"""
	var missions: Array[Dictionary] = []
	var num_missions = randi_range(MIN_MISSIONS_PER_PLANET, MAX_MISSIONS_PER_PLANET)
	
	print("Generating ", num_missions, " missions for ", origin_planet_data.get("name", "Unknown Planet"))
	
	# Get all possible destinations
	var destinations = get_all_landable_destinations()
	if destinations.is_empty():
		push_error("No destinations found for mission generation")
		return missions
	
	# Remove origin planet from destinations
	destinations = destinations.filter(func(dest): 
		return not (dest.planet_id == origin_planet_data.get("id", "") and dest.system_id == origin_system_id)
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

static func generate_single_mission(origin_planet_data: Dictionary, origin_system_id: String, destinations: Array[Dictionary]) -> Dictionary:
	"""Generate a single cargo mission"""
	if destinations.is_empty():
		return {}
	
	# Choose random destination
	var destination = destinations[randi() % destinations.size()]
	
	# Generate cargo details
	var cargo_type = CARGO_TYPES[randi() % CARGO_TYPES.size()]
	var cargo_weight = randi_range(MIN_CARGO_WEIGHT, MAX_CARGO_WEIGHT)
	
	# Calculate payment based on distance
	var jump_distance = calculate_jump_distance(origin_system_id, destination.system_id)
	var base_payment = BASE_PAYMENT_PER_JUMP * jump_distance
	var weight_bonus = int(cargo_weight * WEIGHT_PAYMENT_MODIFIER)
	var total_payment = base_payment + weight_bonus
	
	# Add some randomness to payment (±20%)
	var payment_variance = randf_range(0.8, 1.2)
	total_payment = int(total_payment * payment_variance)
	
	var mission = {
		"cargo_type": cargo_type,
		"cargo_weight": cargo_weight,
		"origin_planet": origin_planet_data.get("id", ""),
		"origin_system": origin_system_id,
		"destination_planet": destination.planet_id,
		"destination_system": destination.system_id,
		"destination_planet_name": destination.planet_name,
		"destination_system_name": destination.system_name,
		"payment": total_payment,
		"jump_distance": jump_distance
	}
	
	print("Generated mission: ", cargo_weight, " tons of ", cargo_type, " to ", destination.planet_name, " (", jump_distance, " jumps) - ", total_payment, " credits")
	
	return mission

static func get_all_landable_destinations() -> Array[Dictionary]:
	"""Get all planets/stations that can be landed on across all systems"""
	var destinations: Array[Dictionary] = []
	
	if not UniverseManager.universe_data.has("systems"):
		push_error("No universe data available")
		return destinations
	
	var systems = UniverseManager.universe_data.systems
	
	for system_id in systems:
		var system_data = systems[system_id]
		var system_name = system_data.get("name", system_id)
		var celestial_bodies = system_data.get("celestial_bodies", [])
		
		for body in celestial_bodies:
			# Check if this celestial body can be landed on
			if body.get("can_land", false):
				var destination = {
					"system_id": system_id,
					"system_name": system_name,
					"planet_id": body.get("id", ""),
					"planet_name": body.get("name", "Unknown"),
					"planet_type": body.get("type", "unknown")
				}
				destinations.append(destination)
	
	print("Found ", destinations.size(), " landable destinations across all systems")
	return destinations

static func calculate_jump_distance(origin_system: String, destination_system: String) -> int:
	"""Calculate the number of hyperspace jumps between two systems"""
	if origin_system == destination_system:
		return 0
	
	var system_positions = get_system_positions()
	
	if not system_positions.has(origin_system) or not system_positions.has(destination_system):
		push_warning("System not found in positions map: ", origin_system, " or ", destination_system)
		return 1  # Default to 1 jump if systems not found
	
	var origin_pos = system_positions[origin_system]
	var dest_pos = system_positions[destination_system]
	
	# Calculate straight-line distance on the hyperspace map
	var map_distance = origin_pos.distance_to(dest_pos)
	
	# Convert map distance to jump count
	# This is a simplified model - in reality you'd use pathfinding through the connection network
	# For now, we'll use distance bands:
	# 0-150 units = 1 jump (adjacent systems)
	# 150-300 units = 2 jumps  
	# 300-450 units = 3 jumps
	# 450+ units = 4+ jumps
	
	var jumps = 1
	if map_distance > 150:
		jumps = 2
	if map_distance > 300:
		jumps = 3
	if map_distance > 450:
		jumps = 4
	if map_distance > 600:
		jumps = 5
	
	return jumps

static func get_mission_description(mission_data: Dictionary) -> String:
	"""Generate a description string for a mission"""
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
	"""Format credit amounts with commas for readability"""
	var formatted = str(amount)
	var result = ""
	var count = 0
	
	# Add commas every 3 digits from right to left
	for i in range(formatted.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = formatted[i] + result
		count += 1
	
	return result

# =============================================================================
# DEBUG AND TESTING METHODS
# =============================================================================

static func debug_generate_test_missions() -> Array[Dictionary]:
	"""Generate test missions for debugging"""
	print("=== GENERATING TEST MISSIONS ===")
	
	# Use Earth as test origin
	var test_planet = {
		"id": "earth",
		"name": "Earth",
		"type": "planet"
	}
	
	var missions = generate_missions_for_planet(test_planet, "sol_system")
	
	print("=== TEST MISSIONS GENERATED ===")
	for mission in missions:
		print(get_mission_description(mission))
		print("---")
	
	return missions

static func debug_print_all_destinations():
	"""Print all available destinations for debugging"""
	print("=== ALL LANDABLE DESTINATIONS ===")
	var destinations = get_all_landable_destinations()
	for dest in destinations:
		print(dest.system_name, " - ", dest.planet_name, " (", dest.planet_type, ")")
	print("=== TOTAL: ", destinations.size(), " destinations ===")

static func debug_test_jump_calculations():
	"""Test jump distance calculations"""
	print("=== TESTING JUMP CALCULATIONS ===")
	var test_pairs = [
		["sol_system", "alpha_centauri"],
		["sol_system", "deneb_system"],
		["vega_system", "antares_system"],
		["arcturus_system", "aldebaran_system"]
	]
	
	for pair in test_pairs:
		var jumps = calculate_jump_distance(pair[0], pair[1])
		print(pair[0], " to ", pair[1], ": ", jumps, " jumps")
	print("=== JUMP CALCULATION TESTS COMPLETE ===")
