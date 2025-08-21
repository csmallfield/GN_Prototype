# =============================================================================
# TRAFFIC MANAGER - Simplified for Phase 1 Simple AI
# =============================================================================
extends Node2D
class_name TrafficManager

@export var spawn_distance: float = 4000.0
@export var debug_mode: bool = false

var current_npcs: Array = []  # Removed NPCShip type hint
var spawn_timer: float = 0.0
var system_traffic_config: Dictionary = {}
var active: bool = false

# Default traffic configuration
var default_config = {
	"spawn_frequency": 15.0,
	"max_npcs": 3,
	"spawn_frequency_variance": 5.0,
	"npc_config": {
		"thrust_power": 500.0,
		"rotation_speed": 3.0,
		"max_velocity": 400.0,
		"visit_duration_range": [3.0, 8.0]
	}
}

func _ready():
	add_to_group("traffic_manager")
	
	# Connect to system changes
	UniverseManager.system_changed.connect(_on_system_changed)
	
	# Initialize with current system
	_on_system_changed(UniverseManager.current_system_id)

func _process(delta):
	if not active:
		return
	
	update_spawn_timer(delta)
	cleanup_distant_npcs()
	
	if debug_mode:
		queue_redraw()

func update_spawn_timer(delta):
	"""Handle NPC spawning timing"""
	spawn_timer -= delta
	
	if spawn_timer <= 0.0 and should_spawn_npc():
		spawn_npc()
		reset_spawn_timer()

func should_spawn_npc() -> bool:
	"""Check if we should spawn a new NPC"""
	var max_npcs = system_traffic_config.get("max_npcs", default_config.max_npcs)
	var current_count = get_active_npc_count()
	
	return current_count < max_npcs

func get_active_npc_count() -> int:
	"""Get count of active NPCs, cleaning up invalid ones"""
	current_npcs = current_npcs.filter(func(npc): return is_instance_valid(npc))
	return current_npcs.size()

func spawn_npc():
	"""Spawn a new NPC ship"""
	var npc_ship = create_npc_ship()
	if not npc_ship:
		return
	
	# Calculate spawn position (simple version - just outside system center)
	var spawn_angle = randf() * TAU
	var spawn_pos = Vector2.from_angle(spawn_angle) * spawn_distance
	
	# Add to scene
	get_parent().add_child(npc_ship)
	current_npcs.append(npc_ship)
	
	# Position the NPC
	npc_ship.global_position = spawn_pos
	npc_ship.linear_velocity = Vector2.ZERO
	
	if debug_mode:
		print("TrafficManager: Spawned NPC at ", spawn_pos)

func create_npc_ship():  # Removed return type hint
	"""Create a new NPC ship"""
	var npc_ship_scene = load("res://scenes/NPCShip.tscn")
	if not npc_ship_scene:
		push_error("Could not load NPCShip.tscn")
		return null
	
	var npc_ship = npc_ship_scene.instantiate()
	
	# Simple configuration - no complex archetypes for Phase 1
	print("Created simple NPC ship")
	
	return npc_ship

func spawn_hostile_npc_near_player():
	"""Debug method to spawn a hostile NPC near the player"""
	var player = UniverseManager.player_ship
	if not player:
		print("No player ship found")
		return
	
	var npc_ship_scene = load("res://scenes/NPCShip.tscn")
	if not npc_ship_scene:
		return
		
	var npc_ship = npc_ship_scene.instantiate()
	
	# Position near player
	var spawn_offset = Vector2(randf_range(-500, 500), randf_range(-500, 500))
	if spawn_offset.length() < 200:
		spawn_offset = spawn_offset.normalized() * 300
	
	npc_ship.global_position = player.global_position + spawn_offset
	npc_ship.linear_velocity = Vector2.ZERO
	
	# Add to scene
	get_parent().add_child(npc_ship)
	current_npcs.append(npc_ship)
	
	print("Spawned hostile NPC near player at ", npc_ship.global_position)

func spawn_initial_npcs():
	"""Spawn NPCs already in the system when player arrives"""
	var max_npcs = system_traffic_config.get("max_npcs", default_config.max_npcs)
	var initial_count = max(1, max_npcs / 2)
	
	if debug_mode:
		print("TrafficManager: Spawning ", initial_count, " initial NPCs")
	
	for i in range(initial_count):
		spawn_existing_npc()
		# Small delay between spawns
		await get_tree().create_timer(0.1).timeout

func spawn_existing_npc():
	"""Spawn an NPC that's already been in the system"""
	var npc_ship = create_npc_ship()
	if not npc_ship:
		return
	
	# Use call_deferred to avoid the "busy setting up children" error
	get_parent().call_deferred("add_child", npc_ship)
	current_npcs.append(npc_ship)
	
	# Wait a frame for the NPC to be added to the scene
	await get_tree().process_frame
	
	# Position randomly in system (not too close to center)
	var min_radius = 800.0
	var max_radius = 2000.0
	var spawn_radius = randf_range(min_radius, max_radius)
	var spawn_angle = randf() * TAU
	var spawn_pos = Vector2.from_angle(spawn_angle) * spawn_radius
	
	npc_ship.global_position = spawn_pos
	
	# Give it some random velocity
	var velocity_angle = randf() * TAU
	var velocity_speed = randf_range(50, 150)
	npc_ship.linear_velocity = Vector2.from_angle(velocity_angle) * velocity_speed
	
	if debug_mode:
		print("TrafficManager: Spawned existing NPC")

func reset_spawn_timer():
	"""Reset the spawn timer with variance"""
	var base_frequency = system_traffic_config.get("spawn_frequency", default_config.spawn_frequency)
	var variance = system_traffic_config.get("spawn_frequency_variance", default_config.spawn_frequency_variance)
	
	var random_offset = randf_range(-variance, variance)
	spawn_timer = max(1.0, base_frequency + random_offset)
	
	if debug_mode:
		print("TrafficManager: Next spawn in ", spawn_timer, " seconds")

func cleanup_distant_npcs():
	"""Remove NPCs that have traveled too far from the system"""
	var system_center = Vector2.ZERO
	var cleanup_distance = spawn_distance * 1.5
	
	for i in range(current_npcs.size() - 1, -1, -1):
		var npc = current_npcs[i]
		if not is_instance_valid(npc):
			current_npcs.remove_at(i)
			continue
		
		var distance_from_center = npc.global_position.distance_to(system_center)
		if distance_from_center > cleanup_distance:
			if debug_mode:
				print("TrafficManager: Cleaning up distant NPC at distance ", distance_from_center)
			npc.queue_free()
			current_npcs.remove_at(i)

func _on_system_changed(system_id: String):
	"""Handle system changes"""
	# Clear existing NPCs
	cleanup_all_npcs()
	
	# Load new system configuration
	load_system_traffic_config(system_id)
	
	# Spawn initial NPCs
	spawn_initial_npcs()
	
	# Activate traffic for new system
	active = true
	
	# Reset spawn timer
	reset_spawn_timer()
	
	if debug_mode:
		print("TrafficManager: System changed to ", system_id)

func load_system_traffic_config(_system_id: String):
	"""Load traffic configuration for the specified system"""
	var system_data = UniverseManager.get_current_system()
	system_traffic_config = system_data.get("traffic", {})
	
	# Merge with defaults
	for key in default_config:
		if not system_traffic_config.has(key):
			system_traffic_config[key] = default_config[key]

func cleanup_all_npcs():
	"""Remove all current NPCs (used when changing systems)"""
	for npc in current_npcs:
		if is_instance_valid(npc):
			npc.call_deferred("queue_free")
	current_npcs.clear()

func _on_npc_removed(npc):  # Removed type hint
	"""Called by NPCs when they remove themselves"""
	current_npcs.erase(npc)
	if debug_mode:
		print("TrafficManager: NPC removed, ", current_npcs.size(), " remaining")

func set_debug_mode(enabled: bool):
	"""Enable/disable debug mode"""
	debug_mode = enabled
	queue_redraw()

func _draw():
	"""Debug visualization"""
	if not debug_mode:
		return
	
	var system_center = Vector2.ZERO
	
	# Draw spawn circle
	draw_arc(system_center, spawn_distance, 0, TAU, 64, Color.GREEN, 3.0)
	
	# Draw cleanup circle
	var cleanup_distance = spawn_distance * 1.5
	draw_arc(system_center, cleanup_distance, 0, TAU, 64, Color.RED, 2.0)
	
	# Draw NPC info
	var font = ThemeDB.fallback_font
	for i in range(current_npcs.size()):
		var npc = current_npcs[i]
		if not is_instance_valid(npc):
			continue
		
		var local_pos = to_local(npc.global_position)
		draw_circle(local_pos, 8.0, Color.YELLOW)
		
		# Simple state info
		var npc_info = "NPC " + str(i)
		if npc.has_method("get_current_state_name"):
			npc_info += "\n" + npc.get_current_state_name()
		
		draw_string(font, local_pos + Vector2(10, 0), npc_info, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	
	# Draw spawn timer info
	var timer_info = "Spawn in: " + str(round(spawn_timer * 10) / 10.0) + "s\nNPCs: " + str(current_npcs.size()) + "/" + str(system_traffic_config.get("max_npcs", 0))
	draw_string(font, Vector2(-200, -200), timer_info, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.CYAN)
