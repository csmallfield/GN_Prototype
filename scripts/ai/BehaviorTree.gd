# =============================================================================
# BEHAVIOR TREE - Simple behavior tree system for AI
# =============================================================================
extends RefCounted
class_name BehaviorTree

enum NodeType {
	SELECTOR,    # Try children until one succeeds
	SEQUENCE,    # Run children in order, fail if any fails
	CONDITION,   # Test a condition
	ACTION       # Perform an action
}

enum Status {
	SUCCESS,
	FAILURE,
	RUNNING
}

var root_node: BehaviorNode
var blackboard: Dictionary = {}
var owner_ship: Node2D

func _init(ship: Node2D):
	owner_ship = ship

func set_root(node: BehaviorNode):
	root_node = node
	if root_node:
		root_node.tree = self

func tick() -> Status:
	if root_node:
		return root_node.execute()
	return Status.FAILURE

func get_blackboard_value(key: String, default_value = null):
	return blackboard.get(key, default_value)

func set_blackboard_value(key: String, value):
	blackboard[key] = value
