extends Resource
class_name GOAPGoal

# Represents a goal in the GOAP system

var name: String
var priority: int
var desired_state: Dictionary

func _init(goal_name: String, goal_priority: int, goal_state: Dictionary):
	name = goal_name
	priority = goal_priority
	desired_state = goal_state

func is_achieved(world_state: Dictionary) -> bool:
	"""Check if this goal is achieved in the given world state"""
	for key in desired_state:
		if not world_state.has(key):
			return false
		if world_state[key] != desired_state[key]:
			return false
	return true

func get_distance(world_state: Dictionary) -> int:
	"""Calculate how far the current world state is from achieving this goal"""
	var distance = 0
	for key in desired_state:
		if not world_state.has(key) or world_state[key] != desired_state[key]:
			distance += 1
	return distance