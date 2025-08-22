# =============================================================================
# BEHAVIOR NODE - Base class for behavior tree nodes
# =============================================================================
extends RefCounted
class_name BehaviorNode

var tree: BehaviorTree
var children: Array[BehaviorNode] = []
var node_type: BehaviorTree.NodeType

func add_child_node(child: BehaviorNode):
	children.append(child)
	child.tree = tree

func execute() -> BehaviorTree.Status:
	match node_type:
		BehaviorTree.NodeType.SELECTOR:
			return execute_selector()
		BehaviorTree.NodeType.SEQUENCE:
			return execute_sequence()
		BehaviorTree.NodeType.CONDITION:
			return execute_condition()
		BehaviorTree.NodeType.ACTION:
			return execute_action()
	return BehaviorTree.Status.FAILURE

func execute_selector() -> BehaviorTree.Status:
	for child in children:
		var result = child.execute()
		if result != BehaviorTree.Status.FAILURE:
			return result
	return BehaviorTree.Status.FAILURE

func execute_sequence() -> BehaviorTree.Status:
	for child in children:
		var result = child.execute()
		if result != BehaviorTree.Status.SUCCESS:
			return result
	return BehaviorTree.Status.SUCCESS

# Override these in subclasses
func execute_condition() -> BehaviorTree.Status:
	return BehaviorTree.Status.FAILURE

func execute_action() -> BehaviorTree.Status:
	return BehaviorTree.Status.FAILURE

# Utility function for angle differences
func angle_difference(current: float, target: float) -> float:
	var diff = target - current
	while diff > PI: diff -= TAU
	while diff < -PI: diff += TAU
	return diff
