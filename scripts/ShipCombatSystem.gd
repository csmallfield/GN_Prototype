# =============================================================================
# SHIP COMBAT SYSTEM - Integrates combat with existing ship classes
# This extends your existing PlayerShip and NPCShip with combat capabilities
# =============================================================================
# ShipCombatSystem.gd - Add this as a component to ships

extends Node
class_name ShipCombatSystem

# Combat stats (integrates with existing ShipStats)
var max_hull: float = 100.0
var current_hull: float = 100.0
var max_shields: float = 50.0
var current_shields: float = 50.0
var shield_recharge_rate: float = 5.0
var armor_rating: float = 0.0

# Shield recharge
var shield_recharge_delay: float = 3.0  # Seconds after taking damage before shields recharge
var shield_down_timer: float = 0.0

# Weapon systems
var weapon_hardpoints: Array[WeaponHardpoint] = []
var primary_weapons: Array[WeaponHardpoint] = []
var secondary_weapons: Array[WeaponHardpoint] = []

# Targeting
var current_target: Node2D = null
var auto_target: bool = true
var target_scan_range: float = 1000.0

# Ship reference
var ship: RigidBody2D
var ship_stats: ShipStats

# Status flags
var is_destroyed: bool = false
var is_player_ship: bool = false

# Signals
signal hull_damaged(current_hull: float, max_hull: float)
signal shields_damaged(current_shields: float, max_shields: float)
signal ship_destroyed
signal target_acquired(target: Node2D)
signal target_lost

func _ready():
	# Find parent ship
	ship = get_parent() as RigidBody2D
	if not ship:
		push_error("ShipCombatSystem must be child of RigidBody2D ship")
		return
	
	# Check if this is the player ship
	is_player_ship = ship == UniverseManager.player_ship
	
	# Load ship stats if available
	load_ship_stats()
	
	# Find existing weapon hardpoints
	find_weapon_hardpoints()
	
	print("Combat system initialized for ", ship.name)

func _process(delta):
	if is_destroyed:
		return
		
	update_shield_recharge(delta)
	update_targeting()
	update_weapons(delta)

func load_ship_stats():
	"""Load combat stats from ShipStats resource or use defaults"""
	# Try multiple methods to find ship stats
	if ship.has_method("get_ship_stats"):
		ship_stats = ship.get_ship_stats()
	elif ship.has_meta("ship_stats"):
		ship_stats = ship.get_meta("ship_stats")
	elif ship.get("ship_stats") != null:
		ship_stats = ship.ship_stats
	
	if ship_stats:
		max_hull = ship_stats.max_hull
		current_hull = max_hull
		max_shields = ship_stats.max_shields
		current_shields = max_shields
		shield_recharge_rate = ship_stats.shield_recharge_rate
		armor_rating = ship_stats.armor_rating
		print("Loaded combat stats for ", ship.name, " - Hull: ", max_hull, " Shields: ", max_shields)
	else:
		# Use reasonable defaults based on ship type
		if is_player_ship:
			max_hull = 100.0
			max_shields = 50.0
			shield_recharge_rate = 8.0
		else:
			max_hull = 80.0
			max_shields = 40.0
			shield_recharge_rate = 6.0
		
		current_hull = max_hull
		current_shields = max_shields
		print("Using default combat stats for ", ship.name)

func find_weapon_hardpoints():
	"""Find existing weapon hardpoints on the ship"""
	weapon_hardpoints.clear()
	primary_weapons.clear()
	secondary_weapons.clear()
	
	# Look for WeaponHardpoint nodes
	for child in ship.get_children():
		if child is WeaponHardpoint:
			weapon_hardpoints.append(child)
			# Classify as primary or secondary based on name or position
			if "primary" in child.name.to_lower() or "main" in child.name.to_lower():
				primary_weapons.append(child)
			else:
				secondary_weapons.append(child)
		# Also check grandchildren (hardpoints might be under other nodes)
		for grandchild in child.get_children():
			if grandchild is WeaponHardpoint:
				weapon_hardpoints.append(grandchild)
				secondary_weapons.append(grandchild)
	
	print("Found ", weapon_hardpoints.size(), " weapon hardpoints on ", ship.name)

func take_damage(amount: float, damage_type: Weapon.DamageType = Weapon.DamageType.ENERGY, attacker: Node2D = null):
	"""Apply damage to the ship"""
	if is_destroyed:
		return
	
	var original_amount = amount
	
	# Shields absorb damage first
	if current_shields > 0:
		var shield_absorbed = min(amount, current_shields)
		current_shields -= shield_absorbed
		amount -= shield_absorbed
		
		# Reset shield recharge timer
		shield_down_timer = shield_recharge_delay
		
		shields_damaged.emit(current_shields, max_shields)
		
		if OS.is_debug_build():
			print(ship.name, " shields: ", shield_absorbed, " damage, ", current_shields, " remaining")
	
	# Remaining damage goes to hull, reduced by armor
	if amount > 0:
		var armor_reduction = armor_rating / (armor_rating + 100.0)
		var hull_damage = amount * (1.0 - armor_reduction)
		current_hull -= hull_damage
		
		hull_damaged.emit(current_hull, max_hull)
		
		if OS.is_debug_build():
			print(ship.name, " hull: ", hull_damage, " damage (", armor_reduction * 100, "% absorbed), ", current_hull, " remaining")
		
		# Check for destruction
		if current_hull <= 0:
			destroy_ship(attacker)
	
	# Notify ship of damage (for AI reactions)
	if ship.has_method("on_damage_taken"):
		ship.on_damage_taken(original_amount, damage_type, attacker)

func heal_hull(amount: float):
	"""Restore hull points"""
	current_hull = min(current_hull + amount, max_hull)
	hull_damaged.emit(current_hull, max_hull)

func recharge_shields(amount: float):
	"""Restore shield points"""
	current_shields = min(current_shields + amount, max_shields)
	shields_damaged.emit(current_shields, max_shields)

func update_shield_recharge(delta: float):
	"""Handle automatic shield recharging"""
	if current_shields >= max_shields:
		return
	
	if shield_down_timer > 0:
		shield_down_timer -= delta
		return
	
	# Recharge shields
	var recharge_amount = shield_recharge_rate * delta
	current_shields = min(current_shields + recharge_amount, max_shields)
	shields_damaged.emit(current_shields, max_shields)

func destroy_ship(attacker: Node2D = null):
	"""Handle ship destruction"""
	if is_destroyed:
		return
	
	is_destroyed = true
	current_hull = 0
	current_shields = 0
	
	print(ship.name, " destroyed!")
	ship_destroyed.emit()
	
	# Create explosion effect
	create_destruction_effect()
	
	# Notify attacker (for player kill tracking, etc.)
	if attacker and attacker.has_method("on_kill_confirmed"):
		attacker.on_kill_confirmed(ship)
	
	# Handle ship-specific destruction
	if ship.has_method("on_ship_destroyed"):
		ship.on_ship_destroyed(attacker)
	else:
		# Default: remove the ship after a short delay
		await get_tree().create_timer(0.5).timeout
		ship.queue_free()

func create_destruction_effect():
	"""Create explosion and debris effects"""
	# Simple explosion effect - can be enhanced later
	var explosion = ColorRect.new()
	explosion.size = Vector2(100, 100)
	explosion.position = ship.global_position - explosion.size / 2
	explosion.color = Color.ORANGE
	
	ship.get_tree().current_scene.add_child(explosion)
	
	# Animate explosion
	var tween = create_tween()
	tween.parallel().tween_property(explosion, "scale", Vector2(3, 3), 0.5)
	tween.parallel().tween_property(explosion, "modulate", Color.TRANSPARENT, 0.5)
	tween.tween_callback(explosion.queue_free)

func update_targeting():
	"""Update automatic targeting system"""
	if not auto_target:
		return
	
	# Simple targeting: find closest enemy
	var new_target = find_closest_enemy()
	
	if new_target != current_target:
		if current_target:
			target_lost.emit()
		
		current_target = new_target
		
		if current_target:
			target_acquired.emit(current_target)
			# Set target for all weapons
			for hardpoint in weapon_hardpoints:
				hardpoint.set_target(current_target)

func find_closest_enemy() -> Node2D:
	"""Find the closest enemy ship within range"""
	var enemies = []
	var ships = get_tree().get_nodes_in_group("npc_ships")
	
	# Add player ship if this is an NPC
	if not is_player_ship and UniverseManager.player_ship:
		ships.append(UniverseManager.player_ship)
	
	for potential_enemy in ships:
		if potential_enemy == ship:
			continue
		
		if not is_valid_target(potential_enemy):
			continue
		
		var distance = ship.global_position.distance_to(potential_enemy.global_position)
		if distance <= target_scan_range:
			enemies.append({"ship": potential_enemy, "distance": distance})
	
	if enemies.is_empty():
		return null
	
	# Sort by distance and return closest
	enemies.sort_custom(func(a, b): return a.distance < b.distance)
	return enemies[0].ship

func is_valid_target(target: Node2D) -> bool:
	"""Check if a ship is a valid target"""
	if not target or not is_instance_valid(target):
		return false
	
	# Don't target destroyed ships
	var target_combat = target.get_node_or_null("ShipCombatSystem")
	if target_combat and target_combat.is_destroyed:
		return false
	
	# Add faction/government checks here later
	# For now, everyone can target everyone
	return true

func update_weapons(delta: float):
	"""Update all weapon systems"""
	for hardpoint in weapon_hardpoints:
		if hardpoint and is_instance_valid(hardpoint):
			hardpoint._process(delta)

func fire_primary_weapons():
	"""Fire all primary weapons"""
	var fired = false
	for weapon in primary_weapons:
		if weapon.try_fire():
			fired = true
	return fired

func fire_secondary_weapons():
	"""Fire all secondary weapons"""
	var fired = false
	for weapon in secondary_weapons:
		if weapon.try_fire():
			fired = true
	return fired

func fire_all_weapons():
	"""Fire all available weapons"""
	var primary_fired = fire_primary_weapons()
	var secondary_fired = fire_secondary_weapons()
	return primary_fired or secondary_fired

func set_target(target: Node2D):
	"""Manually set target (disables auto-targeting temporarily)"""
	current_target = target
	
	# Update all weapon hardpoints
	for hardpoint in weapon_hardpoints:
		hardpoint.set_target(target)
	
	if target:
		target_acquired.emit(target)
	else:
		target_lost.emit()

func clear_target():
	"""Clear current target"""
	set_target(null)

func enable_auto_targeting(enabled: bool = true):
	"""Enable or disable automatic targeting"""
	auto_target = enabled

func get_hull_percentage() -> float:
	"""Get hull as percentage (0.0 to 1.0)"""
	return current_hull / max_hull if max_hull > 0 else 0.0

func get_shield_percentage() -> float:
	"""Get shields as percentage (0.0 to 1.0)"""
	return current_shields / max_shields if max_shields > 0 else 0.0

func is_critically_damaged() -> bool:
	"""Check if ship is critically damaged (low hull)"""
	return get_hull_percentage() < 0.25

func is_heavily_damaged() -> bool:
	"""Check if ship is heavily damaged"""
	return get_hull_percentage() < 0.5

func get_combat_status() -> Dictionary:
	"""Get current combat status for AI decision making"""
	return {
		"hull_percentage": get_hull_percentage(),
		"shield_percentage": get_shield_percentage(),
		"is_critically_damaged": is_critically_damaged(),
		"is_heavily_damaged": is_heavily_damaged(),
		"has_target": current_target != null,
		"weapons_ready": weapon_hardpoints.any(func(w): return w.can_fire_now())
	}

# Static helper function to add combat to existing ships
static func add_combat_to_ship(ship_node: RigidBody2D) -> ShipCombatSystem:
	"""Add combat system to an existing ship"""
	var combat_system = ShipCombatSystem.new()
	combat_system.name = "ShipCombatSystem"
	ship_node.add_child(combat_system)
	return combat_system
