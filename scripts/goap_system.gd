extends Node
class_name GOAPSystem

# Goal-Oriented Action Planning system for NPCs
# Allows NPCs to dynamically plan sequences of actions to achieve goals

# World state representation
var world_state: Dictionary = {}

# Available goals and their priorities
var goals: Array[GOAPGoal] = []

# Available actions
var actions: Array[GOAPAction] = []

# Current plan being executed
var current_plan: Array[GOAPAction] = []
var current_goal: GOAPGoal = null
var current_action_index: int = 0

# Planning system
var planner: GOAPPlanner

# References
var npc: NPCController
var player: PlayerController

# Anti-stuck system
var stuck_timer: float = 0.0
var stuck_position: Vector3 = Vector3.ZERO
var stuck_threshold: float = 5.0  # 5 seconds before forcing waypoint change
var stuck_distance_threshold: float = 0.1  # If moved less than this in stuck_threshold time

# Search timeout system
var search_start_time: float = 0.0
var search_timeout: float = 10.0  # Maximum search time in seconds

func _init(npc_ref: NPCController):
	npc = npc_ref
	planner = GOAPPlanner.new()
	_initialize_world_state()
	_setup_goals()
	_setup_actions()

func _initialize_world_state():
	"""Initialize the world state with default values"""
	world_state = {
		"player_visible": false,
		"player_in_range": false,
		"at_patrol_point": false,
		"investigating": false,
		"player_caught": false,
		"alerted": false,
		"backup_called": false,
		"player_last_position_known": false,
		"energy_level": 100,
		"confidence_level": 50
	}

func _setup_goals():
	"""Setup available goals for the NPC"""
	goals = [
		GOAPGoal.new("catch_player", 100, {"player_caught": true}),
		GOAPGoal.new("find_player", 80, {"player_visible": true}),
		GOAPGoal.new("investigate_disturbance", 60, {"investigating": false, "player_last_position_known": false}),
		GOAPGoal.new("patrol_area", 30, {"at_patrol_point": true}),  # Lower priority than investigation
		GOAPGoal.new("call_backup", 90, {"backup_called": true}),
		GOAPGoal.new("maintain_alertness", 10, {"alerted": true})  # Lowest priority
	]

func _setup_actions():
	"""Setup available actions for the NPC"""
	actions = [
		# Movement actions
		GOAPAction.new("move_to_player", 
			{"player_visible": true}, 
			{"player_in_range": true}, 
			1.0),
		
		GOAPAction.new("move_to_patrol_point", 
			{}, 
			{"at_patrol_point": true}, 
			2.0),
		
		GOAPAction.new("move_to_last_known_position", 
			{"player_last_position_known": true}, 
			{"investigating": true}, 
			3.0),
		
		# Detection actions
		GOAPAction.new("scan_area", 
			{"at_patrol_point": true}, 
			{"player_visible": true}, 
			2.0),
		
		GOAPAction.new("search_hiding_spots", 
			{"investigating": true}, 
			{"player_visible": true}, 
			4.0),
		
		# Interaction actions  
		GOAPAction.new("catch_player", 
			{"player_in_range": true}, 
			{"player_caught": true}, 
			1.0),
		
		GOAPAction.new("call_for_backup", 
			{"player_visible": true, "alerted": true}, 
			{"backup_called": true}, 
			2.0),
		
		# State management actions
		GOAPAction.new("become_alert", 
			{}, 
			{"alerted": true}, 
			1.0),
		
		GOAPAction.new("investigate_sound", 
			{}, 
			{"investigating": true}, 
			2.0)
	]

func update_world_state(key: String, value: bool):
	"""Update a specific world state variable"""
	var old_value = world_state.get(key, false)
	world_state[key] = value
	
	# Reset conflicting states when player visibility changes
	if key == "player_visible":
		if not value:
			# Player lost, clear search-related states after delay
			world_state["investigating"] = false
		
	# If world state changed significantly, replan
	if old_value != value and _should_replan():
		_create_new_plan()

func _should_replan() -> bool:
	"""Determine if we need to create a new plan"""
	if current_plan.is_empty():
		return true
	
	# Critical state changes that require replanning
	if world_state.get("player_visible", false) and current_goal.name != "catch_player":
		return true
	
	if world_state.get("player_caught", false):
		return true
	
	# Current action is no longer valid
	if current_action_index < current_plan.size():
		var current_action = current_plan[current_action_index]
		if not current_action.are_preconditions_met(world_state):
			return true
	
	return false

func _create_new_plan():
	"""Create a new action plan to achieve the highest priority goal"""
	var best_goal = _select_best_goal()
	if not best_goal:
		return
	
	var plan = planner.create_plan(world_state, best_goal, actions)
	if plan.size() > 0:
		current_plan = plan
		current_goal = best_goal
		current_action_index = 0
		print("GOAP: Created new plan for goal '", best_goal.name, "' with ", plan.size(), " actions")
		
		# Debug: Print the plan
		for i in range(plan.size()):
			print("  Step ", i+1, ": ", plan[i].name)

func _select_best_goal() -> GOAPGoal:
	"""Select the highest priority achievable goal"""
	var best_goal: GOAPGoal = null
	var best_priority: int = -1
	
	for goal in goals:
		# Skip if goal is already achieved
		if goal.is_achieved(world_state):
			continue
		
		# Check if goal is achievable
		if not planner.can_achieve_goal(world_state, goal, actions):
			continue
		
		# Select highest priority goal
		if goal.priority > best_priority:
			best_goal = goal
			best_priority = goal.priority
	
	return best_goal

func execute_plan(delta: float) -> String:
	"""Execute the current plan and return the current action"""
	if current_plan.is_empty():
		_create_new_plan()
		return "idle"
	
	if current_action_index >= current_plan.size():
		# Plan completed
		current_plan.clear()
		current_goal = null
		return "idle"
	
	var current_action = current_plan[current_action_index]
	
	# Check if action can still be executed
	if not current_action.are_preconditions_met(world_state):
		print("GOAP: Action '", current_action.name, "' preconditions no longer met, replanning...")
		_create_new_plan()
		return "idle"
	
	# Execute the action
	var action_completed = _execute_action(current_action, delta)
	
	if action_completed:
		# Apply action effects to world state
		for effect_key in current_action.effects:
			world_state[effect_key] = current_action.effects[effect_key]
		
		print("GOAP: Completed action '", current_action.name, "'")
		current_action_index += 1
		
		# Check if goal is achieved
		if current_goal and current_goal.is_achieved(world_state):
			print("GOAP: Goal '", current_goal.name, "' achieved!")
			current_plan.clear()
			current_goal = null
			return "goal_achieved"
	
	return current_action.name

func _execute_action(action: GOAPAction, delta: float) -> bool:
	"""Execute a specific action and return true when completed"""
	match action.name:
		"move_to_player":
			return _action_move_to_player(delta)
		"move_to_patrol_point":
			return _action_move_to_patrol_point(delta)
		"move_to_last_known_position":
			return _action_move_to_last_known_position(delta)
		"scan_area":
			return _action_scan_area(delta)
		"search_hiding_spots":
			return _action_search_hiding_spots(delta)
		"catch_player":
			return _action_catch_player()
		"call_for_backup":
			return _action_call_for_backup()
		"become_alert":
			return _action_become_alert()
		"investigate_sound":
			return _action_investigate_sound(delta)
		_:
			return true

# Action implementations
func _action_move_to_player(delta: float) -> bool:
	if not npc.player_reference:
		return true
	
	# Direct movement towards player (bypass GOAP state handling)
	var target_pos = npc.player_reference.global_position
	var current_pos = npc.global_position
	var distance_to_player = current_pos.distance_to(target_pos)
	
	if distance_to_player < 2.0:
		return true
	
	# Calculate movement direction
	var direction = (target_pos - current_pos).normalized()
	npc.velocity.x = direction.x * npc.chase_speed
	npc.velocity.z = direction.z * npc.chase_speed
	
	# Fix rotation - ensure NPC and torch face movement direction
	var target_angle = atan2(direction.x, direction.z)
	npc.rotation.y = lerp_angle(npc.rotation.y, target_angle, npc.turn_speed * delta)
	
	return distance_to_player < 2.0

func _action_move_to_patrol_point(delta: float) -> bool:
	if npc.patrol_waypoints.size() == 0:
		return true
	
	var target_waypoint = npc.patrol_waypoints[npc.current_waypoint_index]
	var target_pos = target_waypoint.global_position
	var current_pos = npc.global_position
	
	# Anti-stuck system - track position and force waypoint skip if stuck
	var distance_moved = current_pos.distance_to(stuck_position)
	if distance_moved < stuck_distance_threshold:
		stuck_timer += delta
		if stuck_timer >= stuck_threshold:
			print("GOAP: NPC stuck for ", stuck_threshold, " seconds, skipping to next waypoint")
			npc.current_waypoint_index = (npc.current_waypoint_index + 1) % npc.patrol_waypoints.size()
			stuck_timer = 0.0
			stuck_position = current_pos
			return true
	else:
		stuck_timer = 0.0
		stuck_position = current_pos
	
	# Check if reached waypoint - increase threshold to prevent getting stuck
	var distance_to_waypoint = current_pos.distance_to(target_pos)
	if distance_to_waypoint < 3.0:  # Increased from 2.0 to 3.0 for more reliable detection
		# Move to next waypoint and reset at_patrol_point state
		npc.current_waypoint_index = (npc.current_waypoint_index + 1) % npc.patrol_waypoints.size()
		world_state["at_patrol_point"] = false  # Reset so we can plan next patrol movement
		print("GOAP: Reached waypoint ", npc.current_waypoint_index - 1, ", moving to waypoint ", npc.current_waypoint_index)
		stuck_timer = 0.0
		stuck_position = current_pos
		return true
	
	# Prevent getting stuck by adding boundary checking
	var playable_bounds = Rect2(-20.0, -11.0, 39.0, 21.0)  # From console output
	if not playable_bounds.has_point(Vector2(current_pos.x, current_pos.z)):
		# Move back towards center if outside bounds
		var center = Vector2(-0.5, -0.5)  # Player starting position
		var direction_to_center = (Vector3(center.x, current_pos.y, center.y) - current_pos).normalized()
		npc.velocity.x = direction_to_center.x * npc.patrol_speed
		npc.velocity.z = direction_to_center.z * npc.patrol_speed
		print("GOAP: NPC outside bounds, returning to center")
		return false
	
	# Calculate movement direction
	var direction = (target_pos - current_pos).normalized()
	
	# Set velocity directly for reliable movement
	npc.velocity.x = direction.x * npc.patrol_speed
	npc.velocity.z = direction.z * npc.patrol_speed
	
	# Fix rotation - ensure NPC and torch face movement direction
	# In Godot: positive Z is forward, atan2(x, z) gives Y rotation
	var target_angle = atan2(direction.x, direction.z)
	npc.rotation.y = lerp_angle(npc.rotation.y, target_angle, npc.turn_speed * delta)
	
	print("GOAP: Moving to waypoint ", npc.current_waypoint_index, " distance: ", distance_to_waypoint)
	return false

func _action_move_to_last_known_position(delta: float) -> bool:
	if npc.last_known_player_position == Vector3.ZERO:
		return true
	
	var target_pos = npc.last_known_player_position
	var current_pos = npc.global_position
	var distance_to_target = current_pos.distance_to(target_pos)
	
	# Check if reached investigation point
	if distance_to_target < 1.0:
		return true
	
	# Calculate movement direction
	var direction = (target_pos - current_pos).normalized()
	npc.velocity.x = direction.x * npc.investigate_speed
	npc.velocity.z = direction.z * npc.investigate_speed
	
	# Fix rotation - ensure NPC and torch face movement direction  
	var target_angle = atan2(direction.x, direction.z)
	npc.rotation.y = lerp_angle(npc.rotation.y, target_angle, npc.turn_speed * delta)
	
	return false

func _action_scan_area(delta: float) -> bool:
	# Stop movement and rotate to scan
	npc.velocity.x = 0
	npc.velocity.z = 0
	npc.rotation.y += npc.turn_speed * delta
	return randf() < 0.05  # 5% chance to complete per frame (slower scan)

func _action_search_hiding_spots(delta: float) -> bool:
	# Initialize search timer if this is the first frame of searching
	if search_start_time == 0.0:
		search_start_time = Time.get_unix_time_from_system()
		print("GOAP: Starting search action")
	
	# Check if search has timed out
	var current_time = Time.get_unix_time_from_system()
	if current_time - search_start_time >= search_timeout:
		print("GOAP: Search timeout reached, ending search")
		search_start_time = 0.0
		world_state["investigating"] = false
		world_state["player_last_position_known"] = false
		return true
	
	# Simple search pattern - but don't move if player not detected recently
	if not world_state.get("player_last_position_known", false):
		# No recent player detection, just scan in place
		npc.velocity.x = 0
		npc.velocity.z = 0
		npc.rotation.y += npc.turn_speed * delta * 0.5  # Slow turn
		
		# Faster completion when just scanning
		if randf() < 0.02:  # 2% chance to complete per frame
			search_start_time = 0.0
			return true
	else:
		# Move in small circles when investigating
		var time = Time.get_unix_time_from_system()
		npc.velocity.x = sin(time * 2) * npc.search_speed * 0.3  # Smaller, slower circles
		npc.velocity.z = cos(time * 2) * npc.search_speed * 0.3
		
		# Slower completion when actively searching
		if randf() < 0.01:  # 1% chance to complete per frame
			search_start_time = 0.0
			world_state["investigating"] = false
			return true
	
	return false

func _action_catch_player() -> bool:
	if npc.player_reference:
		var distance = npc.global_position.distance_to(npc.player_reference.global_position)
		if distance <= npc.catch_distance:
			npc._on_player_caught()
			return true
	return false

func _action_call_for_backup() -> bool:
	# Implement backup calling logic
	print("NPC: Calling for backup!")
	return true

func _action_become_alert() -> bool:
	npc.suspicion_level = npc.suspicious_threshold + 1
	return true

func _action_investigate_sound(delta: float) -> bool:
	npc.current_state = npc.NPCState.INVESTIGATE
	return true

# Update world state based on NPC sensors
func update_sensors():
	"""Update world state based on current NPC sensor readings"""
	if npc.player_reference:
		world_state["player_visible"] = npc.player_in_sight
		world_state["player_in_range"] = npc.global_position.distance_to(npc.player_reference.global_position) <= npc.catch_distance
		world_state["player_last_position_known"] = npc.last_known_player_position != Vector3.ZERO
	else:
		world_state["player_visible"] = false
		world_state["player_in_range"] = false
	
	# Better patrol point detection - check distance to current waypoint
	if npc.patrol_waypoints.size() > 0:
		var current_waypoint = npc.patrol_waypoints[npc.current_waypoint_index]
		var distance_to_waypoint = npc.global_position.distance_to(current_waypoint.global_position)
		world_state["at_patrol_point"] = distance_to_waypoint < 1.0
	else:
		world_state["at_patrol_point"] = true
	
	world_state["investigating"] = npc.current_state == npc.NPCState.INVESTIGATE
	world_state["alerted"] = npc.suspicion_level > npc.suspicious_threshold
