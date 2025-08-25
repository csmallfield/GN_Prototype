# =============================================================================
# COMBAT SOCIAL SYSTEM - Handles mutual aid and friendly fire between AI ships
# =============================================================================
extends Node
class_name CombatSocialSystem

# Ship references
var owner_ship: RigidBody2D
var ai_component: Node  # Reference to Phase1CombatAI
var archetype: AIArchetype

# Social combat state
var allies_helping_me: Array[Node2D] = []
var i_am_helping: Node2D = null
var recent_attackers: Dictionary = {}  # attacker -> time_of_attack

# Help request tracking
var active_help_requests: Array[Dictionary] = []  # Track all help requests in area
var my_help_request_id: String = ""
var help_request_cooldown: float = 0.0
var help_cooldown_duration: float = 5.0  # Prevent spam

# Friendly fire tracking
var friendly_fire_incidents: Dictionary = {}  # ship -> incident_count
var friendly_fire_grace_period: float = 2.0  # Time to detect accidental hits

# Debugging
var debug_mode: bool = false

func _ready():
	# Get references
	owner_ship = get_parent()
	ai_component = owner_ship.get_node_or_null("Phase1CombatAI")
	
	if ai_component and ai_component.archetype:
		archetype = ai_component.archetype
	else:
		push_error("CombatSocialSystem requires ship with Phase1CombatAI and archetype")
		return
	
	# Add to social combat group for easy finding
	add_to_group("social_combat_systems")
	
	if debug_mode:
		print("CombatSocialSystem initialized for ", owner_ship.name, " (", archetype.archetype_name, ")")

func _process(delta):
	update_help_request_cooldown(delta)
	cleanup_old_help_requests(delta)
	process_active_help_requests()

func update_help_request_cooldown(delta: float):
	"""Update cooldown timer for help requests"""
	if help_request_cooldown > 0:
		help_request_cooldown -= delta

func cleanup_old_help_requests(delta: float):
	"""Remove expired help requests"""
	for i in range(active_help_requests.size() - 1, -1, -1):
		var request = active_help_requests[i]
		request.age += delta
		
		# Remove old requests (30 seconds max)
		if request.age > 30.0 or not is_instance_valid(request.requester):
			active_help_requests.remove_at(i)

func process_active_help_requests():
	"""Check for help requests we should respond to"""
	if i_am_helping != null:
		# Already helping someone, check if they still need help
		if not is_instance_valid(i_am_helping) or is_ship_safe(i_am_helping):
			stop_helping()
		return
	
	# Look for someone to help
	var best_request = find_best_help_request()
	if best_request:
		start_helping(best_request)

# =============================================================================
# PUBLIC API - Called by AI or damage systems
# =============================================================================

func on_ship_attacked(attacker: Node2D, damage: float):
	"""Called when our ship is attacked"""
	if not attacker or not is_instance_valid(attacker):
		return
	var is_friendly_fire = is_friendly_ship(attacker)
	
	if is_friendly_fire:
		handle_friendly_fire(attacker, damage)
	else:
		handle_hostile_attack(attacker, damage)

func is_friendly_ship(other_ship: Node2D) -> bool:
	"""Check if another ship is the same faction/archetype"""
	if not other_ship:
		return false
	
	# Player is never considered friendly (has no faction)
	if other_ship == UniverseManager.player_ship:
		return false
	
	# Check if other ship has same archetype
	var other_ai = other_ship.get_node_or_null("Phase1CombatAI")
	if not other_ai or not other_ai.archetype:
		return false
	
	return other_ai.archetype.archetype_type == archetype.archetype_type

func handle_friendly_fire(attacker: Node2D, damage: float):
	"""Handle being hit by a friendly ship"""
	if debug_mode:
		print(owner_ship.name, " hit by friendly fire from ", attacker.name, " (", damage, " damage)")
	
	# Check if we should forgive this
	if archetype.should_forgive_friendly_fire(damage):
		if debug_mode:
			print("  -> Forgiving friendly fire from ", attacker.name)
		return
	
	# Don't forgive - treat as hostile
	if debug_mode:
		print("  -> Not forgiving friendly fire from ", attacker.name, " - retaliating!")
	
	# Make the AI treat this ship as hostile
	if ai_component:
		ai_component.notify_attacked_by(attacker)

func handle_hostile_attack(attacker: Node2D, damage: float):
	"""Handle being attacked by a hostile ship"""
	if debug_mode:
		print(owner_ship.name, " attacked by hostile ", attacker.name, " (", damage, " damage)")
	
	# Record the attack
	recent_attackers[attacker] = Time.get_time_dict_from_system()
	
	# Broadcast help request
	broadcast_help_request(attacker, damage)
	
	# Make sure AI knows about the attack
	if ai_component:
		ai_component.notify_attacked_by(attacker)

# =============================================================================
# HELP REQUEST SYSTEM
# =============================================================================

func broadcast_help_request(attacker: Node2D, damage: float):
	"""Broadcast a request for help to nearby allies"""
	if help_request_cooldown > 0:
		return  # Still on cooldown
	
	# Don't spam help requests
	help_request_cooldown = help_cooldown_duration
	
	# Create help request
	var help_request = {
		"id": generate_help_request_id(),
		"requester": owner_ship,
		"attacker": attacker,
		"damage": damage,
		"position": owner_ship.global_position,
		"urgency": archetype.get_help_urgency_score(
			get_hull_percentage(), 
			get_shield_percentage()
		),
		"max_responders": archetype.max_help_responders,
		"current_responders": 0,
		"age": 0.0
	}
	
	my_help_request_id = help_request.id
	
	# Broadcast to all social combat systems
	broadcast_to_all_systems(help_request)
	
	if debug_mode:
		print(owner_ship.name, " broadcasting help request against ", attacker.name, " (urgency: ", help_request.urgency, ")")

func broadcast_to_all_systems(help_request: Dictionary):
	"""Send help request to all nearby social combat systems"""
	var all_systems = get_tree().get_nodes_in_group("social_combat_systems")
	
	for system in all_systems:
		if system == self or not is_instance_valid(system):
			continue
		
		# Check distance
		var distance = owner_ship.global_position.distance_to(system.owner_ship.global_position)
		if distance <= archetype.help_radius:
			system.receive_help_request(help_request)

func receive_help_request(help_request: Dictionary):
	"""Receive a help request from another ship"""
	# Don't help ourselves or invalid requests
	if help_request.requester == owner_ship or not is_instance_valid(help_request.requester):
		return
	
	# Check if we're the same faction
	if not is_friendly_ship(help_request.requester):
		return
	
	# Check if request is at capacity
	if help_request.current_responders >= help_request.max_responders:
		return
	
	# Check distance and willingness to help
	var distance = owner_ship.global_position.distance_to(help_request.position)
	if not archetype.should_respond_to_help_request(distance):
		if debug_mode:
			print(owner_ship.name, " ignoring help request from ", help_request.requester.name, " (too far or unwilling)")
		return
	
	# Add to our list of help requests
	active_help_requests.append(help_request)
	
	if debug_mode:
		print(owner_ship.name, " received help request from ", help_request.requester.name)

func find_best_help_request() -> Dictionary:
	"""Find the most urgent help request we can respond to"""
	if active_help_requests.is_empty():
		return {}
	
	# Sort by urgency (higher = more urgent)
	active_help_requests.sort_custom(func(a, b): return a.urgency > b.urgency)
	
	for request in active_help_requests:
		# Check if still valid and not at capacity
		if (is_instance_valid(request.requester) and 
			request.current_responders < request.max_responders and
			not is_ship_safe(request.requester)):
			return request
	
	return {}

func start_helping(help_request: Dictionary):
	"""Start helping another ship"""
	i_am_helping = help_request.requester
	help_request.current_responders += 1
	
	# Tell our AI to target the attacker
	if ai_component and is_instance_valid(help_request.attacker):
		ai_component.notify_attacked_by(help_request.attacker)
	
	if debug_mode:
		print(owner_ship.name, " starting to help ", help_request.requester.name, " against ", help_request.attacker.name if is_instance_valid(help_request.attacker) else "unknown")

func stop_helping():
	"""Stop helping current ally"""
	if debug_mode and i_am_helping:
		print(owner_ship.name, " stopped helping ", i_am_helping.name)
	
	# Find and update the help request
	for request in active_help_requests:
		if request.requester == i_am_helping:
			request.current_responders = max(0, request.current_responders - 1)
			break
	
	i_am_helping = null
	
	# Clear AI combat state if no longer needed
	if ai_component and not is_under_attack():
		ai_component.attacker = null
		ai_component.state = "peaceful"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

func is_ship_safe(ship: Node2D) -> bool:
	"""Check if a ship no longer needs help"""
	if not ship or not is_instance_valid(ship):
		return true
	
	# Check if ship has high enough health
	if ship.has_method("get_hull_percent"):
		return ship.get_hull_percent() > 0.8
	
	# Check through combat system
	var combat_system = ship.get_node_or_null("ShipCombatSystem")
	if combat_system:
		return combat_system.get_hull_percentage() > 0.8
	
	return false  # Assume ship still needs help if we can't check

func is_under_attack() -> bool:
	"""Check if we are currently under attack"""
	if ai_component and ai_component.attacker and is_instance_valid(ai_component.attacker):
		return true
	
	return false

func get_hull_percentage() -> float:
	"""Get our ship's hull percentage"""
	if owner_ship.has_method("get_hull_percent"):
		return owner_ship.get_hull_percent()
	
	var combat_system = owner_ship.get_node_or_null("ShipCombatSystem")
	if combat_system:
		return combat_system.get_hull_percentage()
	
	return 1.0  # Assume healthy if we can't check

func get_shield_percentage() -> float:
	"""Get our ship's shield percentage"""
	if owner_ship.has_method("get_shield_percent"):
		return owner_ship.get_shield_percent()
	
	var combat_system = owner_ship.get_node_or_null("ShipCombatSystem")
	if combat_system:
		return combat_system.get_shield_percentage()
	
	return 1.0  # Assume healthy if we can't check

func generate_help_request_id() -> String:
	"""Generate a unique ID for help requests"""
	return owner_ship.name + "_" + str(Time.get_time_dict_from_system().second) + "_" + str(randi() % 1000)

# =============================================================================
# DEBUG FUNCTIONS
# =============================================================================

func enable_debug(enabled: bool = true):
	"""Enable debug output for this system"""
	debug_mode = enabled

func get_debug_status() -> Dictionary:
	"""Get current status for debugging"""
	return {
		"allies_helping_me": allies_helping_me.size(),
		"i_am_helping": i_am_helping.name if i_am_helping else "none",
		"active_help_requests": active_help_requests.size(),
		"help_cooldown": help_request_cooldown,
		"archetype": archetype.archetype_name if archetype else "none"
	}

# Static helper to add social combat to existing ships
static func add_to_ship(ship_node: RigidBody2D) -> CombatSocialSystem:
	"""Add social combat system to an existing ship"""
	var social_system = CombatSocialSystem.new()
	social_system.name = "CombatSocialSystem"
	ship_node.add_child(social_system)
	return social_system
