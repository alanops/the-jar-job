extends Resource
class_name GOAPAction

# Represents an action in the GOAP system

var name: String
var preconditions: Dictionary
var effects: Dictionary
var cost: float

func _init(action_name: String, action_preconditions: Dictionary, action_effects: Dictionary, action_cost: float = 1.0):
	name = action_name
	preconditions = action_preconditions
	effects = action_effects
	cost = action_cost

func are_preconditions_met(world_state: Dictionary) -> bool:
	"""Check if all preconditions are met in the given world state"""
	for key in preconditions:
		if not world_state.has(key):
			return false
		if world_state[key] != preconditions[key]:
			return false
	return true

func apply_effects(world_state: Dictionary) -> Dictionary:
	"""Apply this action's effects to a world state and return the new state"""
	var new_state = world_state.duplicate()
	for key in effects:
		new_state[key] = effects[key]
	return new_state

func can_achieve_condition(condition_key: String, condition_value: bool) -> bool:
	"""Check if this action can achieve a specific condition"""
	return effects.has(condition_key) and effects[condition_key] == condition_value