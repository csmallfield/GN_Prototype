# =============================================================================
# MISSION GENERATOR - Pathfinding-Based Distance System
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

# Distance distribution settings (75% / 20% / 5%)
const CLOSE_RANGE_CHANCE = 0.75    # 1-5 jumps
const MEDIUM_RANGE_CHANCE = 0.20   # 6-10 jumps  
const LONG_RANGE_CHANCE = 0.05     # 11-20 jumps

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
	"""Generate missions using pathfinding-based distance system"""
	var missions: Array[Dictionary] = []
	var num_missions = randi_range(MIN_MISSIONS_PER_PLANET, MAX_MISSIONS_PER_PLANET)
	
	var planet_name = origin_planet_data.get("name", "Unknown Planet")
	var system_name = UniverseManager.get_system_name(origin_system_id)
	print("Generating ", num_missions, " missions for ", planet_name, " in ", system_name, " (ID: ", origin_system_id, ")")
	
	# Get destinations grouped by distance ranges
	var destination_pools = get_destination_pools_by_distance(origin_system_id, origin_planet_data.get("id", -1))
	
	if are_all_pools_empty(destination_pools):
		print("No destinations found for mission generation")
		return missions
	
	# Generate missions with proper distance distribution
	for i in range(num_missions):
		var mission = generate_single_mission_with_distribution(origin_planet_data, origin_system_id, destination_pools)
		if not mission.is_empty():
			missions.append(mission)
	
	print("Generated ", missions.size(), " missions successfully")
	return missions

static func get_destination_pools_by_distance(origin_system_id: int, origin_planet_id: int) -> Dictionary:
	"""Get destination pools organized by distance ranges"""
	var pools = {
		"close": [],    # 1-5 jumps
		"medium": [],   # 6-10 jumps
		"long": []      # 11-20 jumps
	}
	
	# Get destinations from each range
	pools.close = UniverseManager.get_landable_destinations_by_distance(origin_system_id, 1, 5)
	pools.medium = UniverseManager.get_landable_destinations_by_distance(origin_system_id, 6, 10)
	pools.long = UniverseManager.get_landable_destinations_by_distance(origin_system_id, 11, 20)
	
	# Remove origin planet from all pools
	remove_origin_from_pools(pools, origin_planet_id, origin_system_id)
	
	print("Destination pools - Close: ", pools.close.size(), " Medium: ", pools.medium.size(), " Long: ", pools.long.size())
	return pools

static func remove_origin_from_pools(pools: Dictionary, origin_planet_id: int, origin_system_id: int):
	"""Remove origin planet from all destination pools"""
	for pool_name in pools.keys():
		var pool = pools[pool_name]
		for i in range(pool.size() - 1, -1, -1):
			var dest = pool[i]
			if dest.planet_id == origin_planet_id and dest.system_id == origin_system_id:
				pool.remove_at(i)

static func are_all_pools_empty(pools: Dictionary) -> bool:
	"""Check if all destination pools are empty"""
	return pools.close.is_empty() and pools.medium.is_empty() and pools.long.is_empty()

static func generate_single_mission_with_distribution(origin_planet_data: Dictionary, origin_system_id: int, destination_pools: Dictionary) -> Dictionary:
	"""Generate single mission using distance distribution rules"""
	
	# Select destination pool based on distribution percentages
	var destination_pool = select_destination_pool(destination_pools)
	if destination_pool.is_empty():
		print("Selected destination pool is empty")
		return {}
	
	# Randomly select destination from chosen pool
	var destination = destination_pool[randi() % destination_pool.size()]
	
	# Generate cargo details
	var cargo_type = CARGO_TYPES[randi() % CARGO_TYPES.size()]
	var cargo_weight = randi_range(MIN_CARGO_WEIGHT, MAX_CARGO_WEIGHT)
	
	# Get actual jump distance (already calculated and cached)
	var jump_distance = destination.jump_distance
	
	# Calculate payment based on actual distance
	var base_payment = BASE_PAYMENT_PER_JUMP * jump_distance
	var weight_bonus = int(cargo_weight * WEIGHT_PAYMENT_MODIFIER)
	var total_payment = base_payment + weight_bonus
	
	# Add payment variance
	var payment_variance = randf_range(0.8, 1.2)
	total_payment = int(total_payment * payment_variance)
	
	var mission = {
		"cargo_type": cargo_type,
		"cargo_weight": cargo_weight,
		"origin_planet": origin_planet_data.get("id", -1),
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

static func select_destination_pool(pools: Dictionary) -> Array:
	"""Select destination pool based on distribution percentages"""
	var random_value = randf()
	
	# Try close range first (75% chance)
	if random_value < CLOSE_RANGE_CHANCE and not pools.close.is_empty():
		print("Selected close range destination (1-5 jumps)")
		return pools.close
	
	# Try medium range (20% chance)
	elif random_value < CLOSE_RANGE_CHANCE + MEDIUM_RANGE_CHANCE and not pools.medium.is_empty():
		print("Selected medium range destination (6-10 jumps)")
		return pools.medium
	
	# Try long range (5% chance)
	elif not pools.long.is_empty():
		print("Selected long range destination (11-20 jumps)")
		return pools.long
	
	# Fallback: use any available pool if selected pool is empty
	print("Selected pool was empty, using fallback...")
	if not pools.close.is_empty():
		return pools.close
	elif not pools.medium.is_empty():
		return pools.medium
	elif not pools.long.is_empty():
		return pools.long
	
	# No destinations available
	return []

# =============================================================================
# LEGACY COMPATIBILITY - These methods are now deprecated but kept for compatibility
# =============================================================================

static func get_all_landable_destinations() -> Array[Dictionary]:
	"""Legacy method - now redirects to use pathfinding system"""
	print("Warning: get_all_landable_destinations() is deprecated. Using pathfinding system instead.")
	
	# Get destinations from current system within reasonable range
	var current_system_id = UniverseManager.current_system_id
	return UniverseManager.get_landable_destinations_by_distance(current_system_id, 1, 20)

static func calculate_jump_distance(origin_system_id: int, destination_system_id: int) -> int:
	"""Legacy method - now uses actual pathfinding"""
	return UniverseManager.get_jump_distance(origin_system_id, destination_system_id)

static func get_system_positions() -> Dictionary:
	"""Legacy method - kept for compatibility but no longer used for distance calculation"""
	print("Warning: get_system_positions() is deprecated. Distance calculation now uses pathfinding.")
	
	var positions = {}
	UniverseManager.ensure_all_systems_loaded()
	var systems = UniverseManager.universe_data.get("systems", {})
	
	for system_id in systems.keys():
		var system_data = systems[system_id]
		var map_pos = system_data.get("map_position", {"x": 0.5, "y": 0.5})
		positions[system_id] = Vector2(map_pos.x * 480 + 50, map_pos.y * 500 + 50)
	
	return positions

# =============================================================================
# UTILITY METHODS - Updated for pathfinding
# =============================================================================

static func get_mission_description(mission_data: Dictionary) -> String:
	"""Generate mission description using actual jump distances"""
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
# DEBUG METHODS - Updated for pathfinding system
# =============================================================================

static func debug_generate_test_missions() -> Array[Dictionary]:
	"""Generate test missions using pathfinding system"""
	print("=== GENERATING TEST MISSIONS WITH PATHFINDING ===")
	
	var current_system = UniverseManager.get_current_system()
	var celestial_bodies = current_system.get("celestial_bodies", [])
	
	if celestial_bodies.is_empty():
		print("No celestial bodies in current system for testing")
		return []
	
	var test_planet = celestial_bodies[0]
	var current_system_id = UniverseManager.current_system_id
	
	var missions = generate_missions_for_planet(test_planet, current_system_id)
	
	print("=== TEST MISSIONS GENERATED WITH ACTUAL DISTANCES ===")
	for mission in missions:
		print(get_mission_description(mission))
		print("---")
	
	return missions

static func debug_test_distance_distribution():
	"""Test the distance distribution system"""
	print("=== TESTING DISTANCE DISTRIBUTION ===")
	
	var current_system_id = UniverseManager.current_system_id
	
	# Test distribution over many iterations
	var distribution_test = {"close": 0, "medium": 0, "long": 0}
	var test_iterations = 100
	
	# Get destination pools
	var destination_pools = get_destination_pools_by_distance(current_system_id, -1)  # -1 to not exclude any planet
	
	if are_all_pools_empty(destination_pools):
		print("No destinations available for testing")
		return
	
	# Test pool selection distribution
	for i in range(test_iterations):
		var selected_pool = select_destination_pool(destination_pools)
		
		if selected_pool == destination_pools.close:
			distribution_test.close += 1
		elif selected_pool == destination_pools.medium:
			distribution_test.medium += 1
		elif selected_pool == destination_pools.long:
			distribution_test.long += 1
	
	# Print results
	print("Distribution test results (", test_iterations, " iterations):")
	print("  Close (1-5 jumps): ", distribution_test.close, "% (target: 75%)")
	print("  Medium (6-10 jumps): ", distribution_test.medium, "% (target: 20%)")
	print("  Long (11-20 jumps): ", distribution_test.long, "% (target: 5%)")
	
	# Test actual pathfinding
	print("\nPathfinding test from current system:")
	UniverseManager.debug_distance_distribution(current_system_id)
	
	print("=== DISTANCE DISTRIBUTION TEST COMPLETE ===")

static func debug_pathfinding_performance():
	"""Test pathfinding performance"""
	print("=== PATHFINDING PERFORMANCE TEST ===")
	
	var start_time = Time.get_ticks_msec()
	var current_system_id = UniverseManager.current_system_id
	
	# Test getting destinations for all three ranges
	var close_destinations = UniverseManager.get_landable_destinations_by_distance(current_system_id, 1, 5)
	var medium_destinations = UniverseManager.get_landable_destinations_by_distance(current_system_id, 6, 10)
	var long_destinations = UniverseManager.get_landable_destinations_by_distance(current_system_id, 11, 20)
	
	var end_time = Time.get_ticks_msec()
	var total_time = end_time - start_time
	
	print("Performance results:")
	print("  Close destinations: ", close_destinations.size())
	print("  Medium destinations: ", medium_destinations.size())
	print("  Long destinations: ", long_destinations.size())
	print("  Total time: ", total_time, "ms")
	print("=== PERFORMANCE TEST COMPLETE ===")
