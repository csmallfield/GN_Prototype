# =============================================================================
# ENHANCED TRAFFIC MANAGER - Phase 2 with Archetype Assignment
# =============================================================================
extends Node2D
class_name TrafficManager

@export var spawn_distance: float = 4000.0
@export var debug_mode: bool = false

var current_npcs: Array = []
var spawn_timer: float = 0.0
var system_traffic_config: Dictionary = {}
var active: bool = false

# Enhanced for Phase 2 - Archetype distribution
var archetype_weights = {
	"trader": 0.5,    # 50% traders
	"military": 0.3,  # 30% military  
	"pirate": 0.2     # 20% pirates
}

# Default traffic configuration
var default_config = {
	"spawn_frequency": 15.0,
	"max_npcs": 5,  # Increased for better variety
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
	"""Spawn a new NPC ship with assigned archetype"""
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
	
	# PHASE 2: Assign archetype and configure AI
	assign_archetype_to_npc(npc_ship)
	
	if debug_mode:
		print("TrafficManager: Spawned NPC at ", spawn_pos)

func create_npc_ship():
	"""Create a new NPC ship"""
	var npc_ship_scene = load("res://scenes/NPCShip.tscn")
	if not npc_ship_scene:
		push_error("Could not load NPCShip.tscn")
		return null
	
	var npc_ship = npc_ship_scene.instantiate()
	
	print("Created NPC ship for Phase 2")
	
	return npc_ship

func assign_archetype_to_npc(npc_ship):
	"""Assign a specific archetype to the NPC based on system and weights"""
	# Wait for NPC to be fully ready
	await get_tree().process_frame
	
	var ai_component = npc_ship.get_node_or_null("Phase1CombatAI")
	if not ai_component:
		print("⚠️ NPC has no AI component")
		return
	
	# Determine archetype based on weights and system type
	var chosen_archetype = choose_archetype_for_system()
	
	# Load the AIArchetype class
	const AIArchetypeClass = preload("res://scripts/ai/AIArchetype.gd")
	
	# Assign the archetype
	var archetype
	match chosen_archetype:
		"trader":
			archetype = AIArchetypeClass.create_trader()
		"pirate":
			archetype = AIArchetypeClass.create_pirate()
		"military":
			archetype = AIArchetypeClass.create_military()
		_:
			archetype = AIArchetypeClass.create_trader()
	
	# Apply to AI
	ai_component.archetype = archetype
	ai_component.setup_behavior_tree()  # Recreate behavior tree with new archetype
	
	# Visual distinction (optional)
	apply_visual_archetype_hints(npc_ship, chosen_archetype)
	
	print("✅ Assigned ", chosen_archetype, " archetype to ", npc_ship.name)

func choose_archetype_for_system() -> String:
	"""Choose archetype based on system characteristics and weights"""
	var current_system = UniverseManager.get_current_system()
	var system_name = current_system.get("name", "")
	
	# Modify weights based on system type
	var modified_weights = archetype_weights.duplicate()
	
	# Military systems have more military ships
	if "military" in system_name.to_lower() or "base" in system_name.to_lower():
		modified_weights.military *= 2.0
		modified_weights.pirate *= 0.3
	
	# Pirate systems have more pirates
	elif "antares" in system_name.to_lower() or "freeport" in system_name.to_lower():
		modified_weights.pirate *= 3.0
		modified_weights.military *= 0.2
	
	# Trading systems have more traders
	elif "trade" in system_name.to_lower() or "commercial" in system_name.to_lower():
		modified_weights.trader *= 1.5
	
	# Choose based on weighted random
	return weighted_random_choice(modified_weights)

func weighted_random_choice(weights: Dictionary) -> String:
	"""Choose a random key based on weights"""
	var total_weight = 0.0
	for weight in weights.values():
		total_weight += weight
	
	var random_value = randf() * total_weight
	var current_weight = 0.0
	
	for key in weights:
		current_weight += weights[key]
		if random_value <= current_weight:
			return key
	
	# Fallback
	return weights.keys()[0]

func apply_visual_archetype_hints(npc_ship, archetype: String):
	"""Apply subtle visual hints to distinguish archetypes"""
	var sprite = npc_ship.get_node_or_null("Sprite2D")
	if not sprite:
		return
	
	# Subtle color modifications to help distinguish ship types
	match archetype:
		"trader":
			sprite.modulate = Color(0.8, 1.0, 0.8)  # Slight green tint
		"military":
			sprite.modulate = Color(0.8, 0.8, 1.0)  # Slight blue tint
		"pirate":
			sprite.modulate = Color(1.0, 0.8, 0.8)  # Slight red tint

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
	
	# PHASE 2: Assign archetype
	assign_archetype_to_npc(npc_ship)
	
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

func _on_npc_removed(npc):
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
	
	# Draw NPC info with archetype
	var font = ThemeDB.fallback_font
	for i in range(current_npcs.size()):
		var npc = current_npcs[i]
		if not is_instance_valid(npc):
			continue
		
		var local_pos = to_local(npc.global_position)
		draw_circle(local_pos, 8.0, Color.YELLOW)
		
		# Get archetype info
		var ai_component = npc.get_node_or_null("Phase1CombatAI")
		var archetype_name = "Unknown"
		if ai_component and ai_component.archetype:
			archetype_name = ai_component.archetype.archetype_name.get_slice(" ", 0)  # First word
		
		var npc_info = "NPC " + str(i) + "\n" + archetype_name
		draw_string(font, local_pos + Vector2(10, 0), npc_info, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	
	# Draw spawn timer and archetype distribution
	var timer_info = "Spawn in: " + str(round(spawn_timer * 10) / 10.0) + "s\nNPCs: " + str(current_npcs.size()) + "/" + str(system_traffic_config.get("max_npcs", 0))
	timer_info += "\nArchetypes: T:" + str(archetype_weights.trader) + " M:" + str(archetype_weights.military) + " P:" + str(archetype_weights.pirate)
	draw_string(font, Vector2(-200, -200), timer_info, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.CYAN)
