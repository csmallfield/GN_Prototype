# =============================================================================
# SQLITE UNIVERSE MANAGER - Database-driven universe with JSON API compatibility
# =============================================================================
# SQLiteUniverseManager.gd - Singleton (AutoLoad) - Replaces UniverseManager.gd
extends Node

signal system_changed(new_system_id)
signal celestial_body_approached(body_data)

# Core state
var current_system_id: String = ""
var player_ship: Node = null

# Database connection
var db: SQLite
var db_path: String = "res://universe.db"

# Caching system - maintains JSON-like structure for compatibility
var universe_data: Dictionary = {"systems": {}, "governments": {}}  # Compatibility layer
var system_cache: Dictionary = {}  # system_id -> full system data
var current_system_cache: Dictionary = {}  # Currently loaded system with all details
var connection_cache: Dictionary = {}  # system_id -> [connected_system_ids]

# Mission system integration (unchanged)
var current_system_missions: Dictionary = {}  # planet_id -> Array[mission_data]

func _ready():
	print("SQLite UniverseManager initializing...")
	initialize_database()
	load_governments()  # Load static government data for compatibility
	change_system("Helios")  # Starting system

# =============================================================================
# DATABASE INITIALIZATION
# =============================================================================

func initialize_database() -> bool:
	"""Initialize SQLite database connection"""
	db = SQLite.new()
	db.path = db_path
	
	if not db.open_db():
		push_error("Failed to open universe database at: " + db_path)
		return false
	
	# Enable foreign keys
	db.query("PRAGMA foreign_keys = ON;")
	
	# Optimize for read performance  
	db.query("PRAGMA journal_mode = WAL;")
	db.query("PRAGMA cache_size = -64000;")  # 64MB cache
	
	print("Universe database connected successfully")
	return true

func load_governments():
	"""Load government data for JSON compatibility"""
	# For now, use static data since governments aren't in database yet
	# This maintains compatibility with existing code that expects universe_data.governments
	universe_data.governments = {
		"confederation": {
			"name": "Terran Confederation",
			"description": "The unified government of human space",
			"color": "#0066CC",
			"starting_reputation": 0
		},
		"independent": {
			"name": "Independent Worlds", 
			"description": "Free traders and frontier settlements",
			"color": "#CC6600",
			"starting_reputation": 0
		}
	}

# =============================================================================
# MAIN API - MAINTAINS EXACT COMPATIBILITY WITH OLD UniverseManager
# =============================================================================

func change_system(system_id: String):
	"""Change to new system - EXACT API match"""
	print("Changing to system: ", system_id)
	
	# ADD THIS DEBUG LINE
	debug_system_loading(system_id)
	
	# Load system data from database
	var system_data = load_system_data(system_id)
	if system_data.is_empty():
		push_error("System not found: " + system_id)
		return
	
	current_system_id = system_id
	current_system_cache = system_data
	
	# Update universe_data for compatibility with HyperspaceMap
	universe_data.systems[system_id] = system_data
	
	# Generate missions (unchanged)
	generate_system_missions()
	
	system_changed.emit(system_id)
	print("Entered system: ", system_id)

func get_current_system() -> Dictionary:
	"""Get current system data - EXACT API match"""
	return current_system_cache

func get_celestial_body(body_id: String) -> Dictionary:
	"""Get specific celestial body - EXACT API match"""
	var system = get_current_system()
	for body in system.get("celestial_bodies", []):
		if body.id == body_id:
			return body
	return {}

func can_travel_to_system(system_id: String) -> bool:
	"""Check if travel is possible - EXACT API match"""
	var connections = get_system_connections(current_system_id)
	return system_id in connections

# =============================================================================
# DATABASE LOADING FUNCTIONS
# =============================================================================

func load_system_data(system_id: String) -> Dictionary:
	"""Load complete system data from database in JSON-compatible format"""
	
	# Check cache first
	if system_cache.has(system_id):
		print("Loading system from cache: ", system_id)
		return system_cache[system_id]
	
	print("Loading system from database: ", system_id)
	
	# Load system basic info
	var system_query = """
		SELECT 
			name, type, x, y, population, security_level, tech_level,
			crime_level, corruption_level, risk_rating, is_hub, is_exceptional,
			asteroid_field, radiation, murk_level, nebula_type,
			bg_color_r, bg_color_g, bg_color_b,
			light_direction, light_color_r, light_color_g, light_color_b, light_intensity,
			map_size, map_color, note, flavor_text
		FROM systems 
		WHERE name = ?;
	"""
	
	db.query_with_bindings(system_query, [system_id])
	var system_results = db.query_result
	
	if system_results.is_empty():
		print("System not found in database: ", system_id)
		return {}
	
	var system_row = system_results[0]
	
	# Build system data in JSON format for compatibility
	var system_data = {
		"name": system_row.name,
		"description": system_row.note if system_row.note else "A star system",
		"flavor_text": system_row.flavor_text if system_row.flavor_text else "",
		"connections": get_system_connections(system_id),
		"map_position": {
			"x": system_row.x / 1000.0,  # Convert back to 0-1 range for HyperspaceMap
			"y": system_row.y / 1000.0
		},
		"celestial_bodies": load_system_bodies(system_id),
		"starfield": build_starfield_config(system_row),
		"traffic": build_traffic_config(system_row)
	}
	
	# Cache the result
	system_cache[system_id] = system_data
	
	print("Loaded system: ", system_data.name, " with ", system_data.celestial_bodies.size(), " bodies")
	return system_data

func load_system_bodies(system_id: String) -> Array:
	"""Load all celestial bodies for a system"""
	
	# First get the system's database ID
	var system_query = "SELECT id FROM systems WHERE name = ?;"
	db.query_with_bindings(system_query, [system_id])
	var system_results = db.query_result
	
	if system_results.is_empty():
		print("System not found: ", system_id)
		return []
	
	var system_db_id = system_results[0].id
	
	# Now get celestial bodies using the numeric ID - with FIXED column names
	var bodies_query = """
		SELECT 
			cb.id, cb.name, cb.type, cb.pos_x, cb.pos_y, cb.scale, cb.can_land,
			cb.shipyard_package, cb.description, cb.flavor_text
		FROM celestial_bodies cb
		WHERE cb.system_id = ?
		ORDER BY cb.name;
	"""
	
	db.query_with_bindings(bodies_query, [system_db_id])
	var bodies_results = db.query_result
	
	print("Loading celestial bodies for ", system_id, " (ID: ", system_db_id, ") - Found: ", bodies_results.size())
	
	var celestial_bodies = []
	
	for body_row in bodies_results:
		var body_data = {
			"id": body_row.id,
			"name": body_row.name,
			"type": body_row.type,
			"description": body_row.description if body_row.description else "",
			"flavor_text": body_row.flavor_text if body_row.flavor_text else "",
			"position": {"x": body_row.pos_x, "y": body_row.pos_y},
			"scale": body_row.scale,
			"can_land": bool(body_row.can_land),
			"services": ["outfitter", "commodity_exchange", "mission_computer"],
			"government": "confederation",
			"tech_level": 4,
			"population": 1000000
		}
		
		if body_row.shipyard_package:
			body_data["shipyard"] = {"available_ships": [body_row.shipyard_package]}
		
		celestial_bodies.append(body_data)
		print("  Loaded body: ", body_data.name, " at (", body_data.position.x, ", ", body_data.position.y, ")")
	
	return celestial_bodies
	
func get_system_connections(system_id: String) -> Array:
	"""Get list of connected systems"""
	
	# Check cache first
	if connection_cache.has(system_id):
		return connection_cache[system_id]
	
	var connections_query = """
		SELECT target_sys.name as target_name
		FROM system_connections sc
		JOIN systems source_sys ON sc.source_system_id = source_sys.id
		JOIN systems target_sys ON sc.target_system_id = target_sys.id
		WHERE source_sys.name = ?;
	"""
	
	db.query_with_bindings(connections_query, [system_id])
	var results = db.query_result
	
	var connections = []
	for row in results:
		connections.append(row.target_name)
	
	# Cache the result
	connection_cache[system_id] = connections
	
	print("Loaded connections for ", system_id, ": ", connections)
	return connections

func build_starfield_config(system_row: Dictionary) -> Dictionary:
	"""Build starfield configuration from system data"""
	return {
		"BaseColor": [system_row.bg_color_r, system_row.bg_color_g, system_row.bg_color_b],
		"StarLayers_Star_Density": 1.0,
		"StarLayers_Star_Brightness": system_row.light_intensity,
		"StarLayers_Twinkle_Speed": 0.3
	}

func build_traffic_config(system_row: Dictionary) -> Dictionary:
	"""Build traffic configuration based on system properties"""
	# Generate traffic based on system characteristics
	var base_frequency = 15.0
	var max_npcs = 3
	
	if system_row.is_hub:
		base_frequency = 5.0
		max_npcs = 8
	elif system_row.population > 1000000:
		base_frequency = 8.0  
		max_npcs = 5
	
	return {
		"spawn_frequency": base_frequency,
		"max_npcs": max_npcs,
		"spawn_frequency_variance": 3.0,
		"npc_config": {
			"thrust_power": 450.0,
			"rotation_speed": 2.8,
			"max_velocity": 380.0,
			"visit_duration_range": [3.0, 8.0]
		}
	}

# =============================================================================
# HYPERSPACE MAP COMPATIBILITY
# =============================================================================

func load_all_systems_for_map() -> Dictionary:
	"""Load all system positions and connections for HyperspaceMap compatibility"""
	print("Loading all systems for hyperspace map...")
	
	# Clear existing cache to force reload
	universe_data.systems.clear()
	
	# Load basic system info for all systems
	var systems_query = """
		SELECT name, x, y, flavor_text
		FROM systems 
		ORDER BY name;
	"""
	
	db.query(systems_query)
	var systems_results = db.query_result
	
	for system_row in systems_results:
		var system_id = system_row.name
		
		# Create minimal system data for map display
		var system_data = {
			"name": system_row.name,
			"map_position": {
				"x": system_row.x / 1000.0,  # Convert to 0-1 range
				"y": system_row.y / 1000.0
			},
			"flavor_text": system_row.flavor_text if system_row.flavor_text else "",
			"connections": get_system_connections(system_id)
		}
		
		universe_data.systems[system_id] = system_data
	
	print("Loaded ", universe_data.systems.size(), " systems for hyperspace map")
	return universe_data.systems

# =============================================================================
# MISSION SYSTEM (UNCHANGED - MAINTAINS COMPATIBILITY)
# =============================================================================

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

# =============================================================================
# PERFORMANCE OPTIMIZATION
# =============================================================================

func preload_connected_systems():
	"""Preload systems connected to current system for faster hyperspace jumps"""
	var connections = get_system_connections(current_system_id)
	
	for system_id in connections:
		if not system_cache.has(system_id):
			# Load system data in background
			call_deferred("load_system_data", system_id)

func clear_distant_system_cache():
	"""Clear cache for systems not connected to current system to save memory"""
	var connections = get_system_connections(current_system_id)
	connections.append(current_system_id)  # Keep current system
	
	var systems_to_remove = []
	for cached_system_id in system_cache.keys():
		if not cached_system_id in connections:
			systems_to_remove.append(cached_system_id)
	
	for system_id in systems_to_remove:
		system_cache.erase(system_id)
		print("Cleared cache for distant system: ", system_id)

func get_cache_stats() -> Dictionary:
	"""Get caching statistics for debugging"""
	return {
		"cached_systems": system_cache.size(),
		"cached_connections": connection_cache.size(),
		"universe_data_systems": universe_data.systems.size()
	}

# =============================================================================
# SPECIAL METHODS FOR HYPERSPACE MAP
# =============================================================================

func _notification(what):
	"""Handle when HyperspaceMap needs all systems loaded"""
	if what == NOTIFICATION_READY:
		# Don't load all systems at startup - only when needed
		pass

func ensure_all_systems_loaded():
	"""Called by HyperspaceMap when it needs all systems - lazy loading"""
	if universe_data.systems.size() < 10:  # Arbitrary threshold
		load_all_systems_for_map()

# =============================================================================
# CLEANUP
# =============================================================================

func _exit_tree():
	if db:
		db.close_db()
		print("Universe database connection closed")

# =============================================================================
# DEBUG METHODS
# =============================================================================

func debug_print_system_info(system_id: String = ""):
	"""Debug method to print system information"""
	if system_id == "":
		system_id = current_system_id
	
	var system_data = load_system_data(system_id)
	print("=== SYSTEM DEBUG INFO: ", system_id, " ===")
	print("Name: ", system_data.get("name", "Unknown"))
	print("Bodies: ", system_data.get("celestial_bodies", []).size())
	print("Connections: ", system_data.get("connections", []))
	print("Cache stats: ", get_cache_stats())
	print("=======================================")

func debug_test_database_connection() -> bool:
	"""Test database connection and basic queries"""
	if not db:
		print("No database connection")
		return false
	
	db.query("SELECT COUNT(*) as system_count FROM systems;")
	var result = db.query_result
	
	if result.is_empty():
		print("Database query failed")
		return false
	
	print("Database test successful - ", result[0].system_count, " systems found")
	return true

func debug_system_loading(system_id: String):
	"""Debug celestial body loading"""
	print("=== DEBUG SYSTEM LOADING: ", system_id, " ===")
	
	# Check if system exists
	var system_query = "SELECT id, name FROM systems WHERE name = ?;"
	db.query_with_bindings(system_query, [system_id])
	var system_results = db.query_result
	
	print("System query results: ", system_results)
	
	if system_results.is_empty():
		print("❌ System not found!")
		return
	
	var system_db_id = system_results[0].id
	print("✅ Found system - DB ID: ", system_db_id, ", Name: ", system_results[0].name)
	
	# Check celestial bodies for this system
	var bodies_query = """
		SELECT cb.id, cb.name, cb.system_id
		FROM celestial_bodies cb
		WHERE cb.system_id = ?;
	"""
	db.query_with_bindings(bodies_query, [system_db_id])
	var bodies_results = db.query_result
	
	print("Celestial bodies found: ", bodies_results.size())
	for body in bodies_results:
		print("  - ", body.name, " (system_id: ", body.system_id, ")")
	
	print("===========================================")
