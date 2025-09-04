# =============================================================================
# SQLITE UNIVERSE MANAGER - Pure Integer ID System
# =============================================================================
# SQLiteUniverseManager.gd - Singleton (AutoLoad)
extends Node

signal system_changed(new_system_id: int)
signal celestial_body_approached(body_data)

# Core state - ALL integer IDs
var current_system_id: int = -1
var player_ship: Node = null

# Database connection
var db: SQLite
var db_path: String = "res://universe.db"

# Caching system - integer keys
var universe_data: Dictionary = {"systems": {}, "governments": {}}
var system_cache: Dictionary = {}  # int -> system_data
var current_system_cache: Dictionary = {}
var connection_cache: Dictionary = {}  # int -> Array[int] (connected system IDs)
var system_name_cache: Dictionary = {}  # int -> String (for display only)

# Mission system
var current_system_missions: Dictionary = {}  # int (planet_id) -> Array[mission_data]

func _ready():
	print("SQLite UniverseManager initializing with integer ID system...")
	initialize_database()
	load_governments()
	
	# Start in system with ID 1 (should be your starting system)
	var starting_system_id = get_system_id_by_name("Helios")
	if starting_system_id == -1:
		starting_system_id = 1  # Fallback to first system
	change_system(starting_system_id)

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
	
	# Enable foreign keys and optimize for read performance  
	db.query("PRAGMA foreign_keys = ON;")
	db.query("PRAGMA journal_mode = WAL;")
	db.query("PRAGMA cache_size = -64000;")
	
	print("Universe database connected successfully")
	return true

func load_governments():
	"""Load government data for JSON compatibility"""
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
# MAIN API - Integer ID Based
# =============================================================================

func change_system(system_id: int):
	"""Change to new system by ID"""
	print("Changing to system ID: ", system_id)
	
	var system_data = load_system_data(system_id)
	if system_data.is_empty():
		push_error("System not found: " + str(system_id))
		return
	
	current_system_id = system_id
	current_system_cache = system_data
	
	# Update universe_data for HyperspaceMap compatibility (use int keys)
	universe_data.systems[system_id] = system_data
	
	generate_system_missions()
	system_changed.emit(system_id)
	
	var system_name = get_system_name(system_id)
	print("Entered system: ", system_name, " (ID: ", system_id, ")")

func get_current_system() -> Dictionary:
	"""Get current system data"""
	return current_system_cache

func get_celestial_body(body_id: int) -> Dictionary:
	"""Get celestial body by integer ID"""
	var system = get_current_system()
	for body in system.get("celestial_bodies", []):
		if body.id == body_id:
			return body
	return {}

func can_travel_to_system(system_id: int) -> bool:
	"""Check if travel is possible to system by ID"""
	var connections = get_system_connections(current_system_id)
	return system_id in connections

# =============================================================================
# NAME LOOKUP HELPERS - For display only
# =============================================================================

func get_system_name(system_id: int) -> String:
	"""Get system name for display purposes"""
	if system_name_cache.has(system_id):
		return system_name_cache[system_id]
	
	db.query_with_bindings("SELECT name FROM systems WHERE id = ?;", [system_id])
	var results = db.query_result
	
	if results.is_empty():
		return "Unknown System"
	
	var name = results[0].name
	system_name_cache[system_id] = name
	return name

func get_system_id_by_name(system_name: String) -> int:
	"""Get system ID by name (for legacy compatibility/startup)"""
	db.query_with_bindings("SELECT id FROM systems WHERE name = ?;", [system_name])
	var results = db.query_result
	
	if results.is_empty():
		return -1
	
	return results[0].id

func get_body_name(body_id: int) -> String:
	"""Get celestial body name for display purposes"""
	db.query_with_bindings("SELECT name FROM celestial_bodies WHERE id = ?;", [body_id])
	var results = db.query_result
	
	if results.is_empty():
		return "Unknown Body"
	
	return results[0].name

# =============================================================================
# DATABASE LOADING - Pure integer ID operations
# =============================================================================

func load_system_data(system_id: int) -> Dictionary:
	"""Load complete system data by integer ID"""
	
	# Check cache first
	if system_cache.has(system_id):
		return system_cache[system_id]
	
	print("Loading system from database - ID: ", system_id)
	
	var system_query = """
		SELECT 
			id, name, type, x, y, population, security_level, tech_level,
			crime_level, corruption_level, risk_rating, is_hub, is_exceptional,
			asteroid_field, radiation, murk_level, nebula_type,
			bg_color_r, bg_color_g, bg_color_b,
			light_direction, light_color_r, light_color_g, light_color_b, light_intensity,
			map_size, map_color, note, flavor_text
		FROM systems 
		WHERE id = ?;
	"""
	
	db.query_with_bindings(system_query, [system_id])
	var system_results = db.query_result
	
	if system_results.is_empty():
		return {}
	
	var system_row = system_results[0]
	
	# Cache the name for quick lookup
	system_name_cache[system_id] = system_row.name
	
	# Build system data with integer IDs
	var system_data = {
		"id": system_row.id,
		"name": system_row.name,
		"description": system_row.note if system_row.note else "A star system",
		"flavor_text": system_row.flavor_text if system_row.flavor_text else "",
		"connections": get_system_connections(system_id),
		"map_position": {
			"x": system_row.x / 1000.0,
			"y": system_row.y / 1000.0
		},
		"celestial_bodies": load_system_bodies(system_id),
		"starfield": build_starfield_config(system_row),
		"traffic": build_traffic_config(system_row)
	}
	
	# Cache by integer ID
	system_cache[system_id] = system_data
	return system_data

func load_system_bodies(system_id: int) -> Array:
	"""Load celestial bodies for a system by integer ID"""
	var bodies_query = """
		SELECT 
			id, name, type, pos_x, pos_y, scale, can_land,
			shipyard_package, description, flavor_text,
			service_refuel, service_missions, service_shipyard
		FROM celestial_bodies
		WHERE system_id = ?
		ORDER BY name;
	"""
	
	db.query_with_bindings(bodies_query, [system_id])
	var bodies_results = db.query_result
	
	print("Loading celestial bodies for system ID ", system_id, " - Found: ", bodies_results.size())
	
	var celestial_bodies = []
	
	for body_row in bodies_results:
		# Build services array from database boolean columns
		var services = build_services_array(body_row)
		
		# Use integer IDs throughout
		var body_data = {
			"id": body_row.id,  # Integer database ID
			"name": body_row.name,
			"type": body_row.type,
			"description": body_row.description if body_row.description else "",
			"flavor_text": body_row.flavor_text if body_row.flavor_text else "",
			"position": {"x": body_row.pos_x, "y": body_row.pos_y},
			"scale": body_row.scale,
			"can_land": bool(body_row.can_land),
			"services": services,  # ← Now loaded from database
			"government": "confederation",
			"tech_level": 4,
			"population": 1000000
		}
		
		if body_row.shipyard_package:
			body_data["shipyard"] = {"available_ships": [body_row.shipyard_package]}
		
		celestial_bodies.append(body_data)
		print("  Loaded body: ", body_data.name, " (ID: ", body_data.id, ") with services: ", services)
	
	return celestial_bodies

func build_services_array(body_row: Dictionary) -> Array:
	"""Convert database service columns to services array"""
	var services = []
	
	# Add services based on database boolean columns
	if body_row.get("service_missions", 0):
		services.append("mission_computer")  # This enables shipping missions
	
	if body_row.get("service_refuel", 0):
		services.append("hyperspace_recharge")
	
	if body_row.get("service_shipyard", 0):
		services.append("shipyard")
	
	# Add standard services for landable planets
	if body_row.get("can_land", 0):
		services.append("outfitter")
		services.append("commodity_exchange")
	
	# Always ensure mission_computer is available if no services specified but can_land is true
	if services.is_empty() and body_row.get("can_land", 0):
		services.append("mission_computer")
	
	return services

func get_system_connections(system_id: int) -> Array[int]:
	"""Get array of connected system IDs"""
	
	# Check cache first
	if connection_cache.has(system_id):
		return connection_cache[system_id]
	
	var connections_query = """
		SELECT target_system_id
		FROM system_connections
		WHERE source_system_id = ?;
	"""
	
	db.query_with_bindings(connections_query, [system_id])
	var results = db.query_result
	
	var connections: Array[int] = []
	for row in results:
		connections.append(row.target_system_id)
	
	# Cache the result
	connection_cache[system_id] = connections
	
	print("Loaded connections for system ID ", system_id, ": ", connections)
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
# HYPERSPACE MAP SUPPORT - Integer ID based
# =============================================================================

func load_all_systems_for_map() -> Dictionary:
	"""Load all systems for hyperspace map with integer keys"""
	print("Loading all systems for hyperspace map...")
	
	universe_data.systems.clear()
	
	var systems_query = """
		SELECT id, name, x, y, flavor_text
		FROM systems 
		ORDER BY name;
	"""
	
	db.query(systems_query)
	var systems_results = db.query_result
	
	for system_row in systems_results:
		var system_id = system_row.id
		
		# Cache name for quick lookup
		system_name_cache[system_id] = system_row.name
		
		var system_data = {
			"id": system_id,
			"name": system_row.name,
			"map_position": {
				"x": system_row.x / 1000.0,
				"y": system_row.y / 1000.0
			},
			"flavor_text": system_row.flavor_text if system_row.flavor_text else "",
			"connections": get_system_connections(system_id),
			"celestial_bodies": load_system_bodies(system_id)
		}
		
		universe_data.systems[system_id] = system_data
	
	print("Loaded ", universe_data.systems.size(), " systems for hyperspace map")
	return universe_data.systems

func ensure_all_systems_loaded():
	"""Ensure all systems are loaded for hyperspace map"""
	if universe_data.systems.size() < 10:  # Adjust threshold as needed
		load_all_systems_for_map()

# =============================================================================
# MISSION SYSTEM - Integer ID based
# =============================================================================

func generate_system_missions():
	"""Generate missions for current system using integer IDs"""
	current_system_missions.clear()
	
	var system_data = get_current_system()
	if system_data.is_empty():
		return
	
	var celestial_bodies = system_data.get("celestial_bodies", [])
	var mission_count = 0
	
	print("=== Generating missions for system ID ", current_system_id, " ===")
	
	for body in celestial_bodies:
		if body.get("can_land", false):
			var planet_id = body.get("id", -1)  # Integer ID
			var missions = MissionGenerator.generate_missions_for_planet(body, current_system_id)
			
			if not missions.is_empty():
				current_system_missions[planet_id] = missions
				mission_count += missions.size()
				print("Generated ", missions.size(), " missions for ", body.get("name", str(planet_id)))
	
	print("=== Total missions generated: ", mission_count, " ===")

func get_missions_for_planet(planet_id: int) -> Array[Dictionary]:
	"""Get missions for planet by integer ID"""
	if current_system_missions.has(planet_id):
		return current_system_missions[planet_id].duplicate()
	return []

func remove_mission_from_system(planet_id: int, mission_data: Dictionary):
	"""Remove mission from system using integer planet ID"""
	if current_system_missions.has(planet_id):
		var planet_missions = current_system_missions[planet_id]
		
		for i in range(planet_missions.size() - 1, -1, -1):
			var mission = planet_missions[i]
			if (mission.get("cargo_type") == mission_data.get("cargo_type") and
				mission.get("cargo_weight") == mission_data.get("cargo_weight") and
				mission.get("destination_planet") == mission_data.get("destination_planet") and
				mission.get("destination_system") == mission_data.get("destination_system")):
				
				planet_missions.remove_at(i)
				print("Removed mission from available list")
				break
		
		current_system_missions[planet_id] = planet_missions

# =============================================================================
# DEBUG METHODS
# =============================================================================

func debug_print_current_system():
	"""Debug method to print current system info"""
	print("=== CURRENT SYSTEM DEBUG ===")
	print("System ID: ", current_system_id)
	print("System Name: ", get_system_name(current_system_id))
	print("Cached systems: ", system_cache.size())
	print("Cached connections: ", connection_cache.size())
	
	var system_data = get_current_system()
	var bodies = system_data.get("celestial_bodies", [])
	print("Celestial bodies: ", bodies.size())
	for body in bodies:
		print("  - ", body.name, " (ID: ", body.id, ")")
	print("===========================")

# =============================================================================
# CLEANUP
# =============================================================================

func _exit_tree():
	if db:
		db.close_db()
		print("Universe database connection closed")
