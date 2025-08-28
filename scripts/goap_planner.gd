extends Node
class_name GOAPPlanner

# A* pathfinding-based planner for GOAP system

class PlanNode:
	var world_state: Dictionary
	var actions_taken: Array[GOAPAction]
	var total_cost: float
	var heuristic_cost: float
	
	func _init(state: Dictionary, actions: Array[GOAPAction], cost: float, heuristic: float):
		world_state = state
		actions_taken = actions
		total_cost = cost
		heuristic_cost = heuristic
	
	func get_total_cost() -> float:
		return total_cost + heuristic_cost

func create_plan(start_state: Dictionary, goal: GOAPGoal, available_actions: Array[GOAPAction]) -> Array[GOAPAction]:
	"""Create a plan using A* pathfinding to achieve the goal"""
	
	# Check if goal is already achieved
	if goal.is_achieved(start_state):
		return []
	
	var open_set: Array[PlanNode] = []
	var closed_set: Array[Dictionary] = []
	
	# Start with initial state
	var start_node = PlanNode.new(start_state, [], 0.0, _calculate_heuristic(start_state, goal))
	open_set.append(start_node)
	
	var max_iterations = 100  # Prevent infinite loops
	var iterations = 0
	
	while open_set.size() > 0 and iterations < max_iterations:
		iterations += 1
		
		# Sort by total cost (A* algorithm)
		open_set.sort_custom(func(a, b): return a.get_total_cost() < b.get_total_cost())
		
		var current_node = open_set.pop_front()
		
		# Check if we've already explored this state
		if _state_in_closed_set(current_node.world_state, closed_set):
			continue
		
		# Add to closed set
		closed_set.append(current_node.world_state)
		
		# Check if goal is achieved
		if goal.is_achieved(current_node.world_state):
			print("GOAP Planner: Found plan with ", current_node.actions_taken.size(), " actions (cost: ", current_node.total_cost, ")")
			return current_node.actions_taken
		
		# Explore possible actions
		for action in available_actions:
			if action.are_preconditions_met(current_node.world_state):
				var new_state = action.apply_effects(current_node.world_state)
				
				# Don't revisit states we've already explored
				if _state_in_closed_set(new_state, closed_set):
					continue
				
				var new_actions = current_node.actions_taken.duplicate()
				new_actions.append(action)
				
				var new_cost = current_node.total_cost + action.cost
				var heuristic = _calculate_heuristic(new_state, goal)
				
				var new_node = PlanNode.new(new_state, new_actions, new_cost, heuristic)
				open_set.append(new_node)
	
	print("GOAP Planner: No plan found for goal '", goal.name, "' after ", iterations, " iterations")
	return []

func can_achieve_goal(start_state: Dictionary, goal: GOAPGoal, available_actions: Array[GOAPAction]) -> bool:
	"""Check if a goal can be achieved with available actions"""
	var plan = create_plan(start_state, goal, available_actions)
	return plan.size() > 0 or goal.is_achieved(start_state)

func _calculate_heuristic(state: Dictionary, goal: GOAPGoal) -> float:
	"""Calculate heuristic cost (distance to goal)"""
	return float(goal.get_distance(state))

func _state_in_closed_set(state: Dictionary, closed_set: Array[Dictionary]) -> bool:
	"""Check if a state has already been explored"""
	for closed_state in closed_set:
		if _states_equal(state, closed_state):
			return true
	return false

func _states_equal(state1: Dictionary, state2: Dictionary) -> bool:
	"""Check if two world states are equal"""
	if state1.size() != state2.size():
		return false
	
	for key in state1:
		if not state2.has(key):
			return false
		if state1[key] != state2[key]:
			return false
	
	return true