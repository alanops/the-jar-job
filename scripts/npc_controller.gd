extends CharacterBody3D

class_name NPCController

enum NPCState {
	IDLE,
	PATROL,
	SUSPICIOUS,      # New: something caught attention
	INVESTIGATE,     # Actively searching a specific location
	SEARCH,          # Lost the player, searching area
	CHASE,           # Direct pursuit of visible player
	RETURN_TO_PATROL # Returning to normal patrol
}

# Movement Properties
@export var patrol_speed: float = 1.5
@export var suspicious_speed: float = 1.0
@export var investigate_speed: float = 2.0
@export var chase_speed: float = 3.0
@export var search_speed: float = 1.8
@export var turn_speed: float = 2.0

# Timing Properties
@export var wait_time_at_waypoint: float = 2.0
@export var suspicious_time: float = 2.0
@export var investigation_time: float = 3.0
@export var search_time: float = 5.0

# Suspicion System
@export var max_suspicion: float = 100.0
@export var suspicion_gain_rate: float = 25.0
@export var suspicion_decay_rate: float = 15.0
@export var suspicious_threshold: float = 30.0
@export var investigate_threshold: float = 60.0

# Navigation
@export var patrol_waypoints: Array[Node3D] = []

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var vision_cone: Area3D = $VisionCone
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var direction_arrow: DirectionArrow = $DirectionArrow
@onready var state_timer: Timer = $StateTimer
@onready var raycast: RayCast3D = $RayCast3D
@onready var state_label: Label3D = $StateLabel
@onready var flashlight: SpotLight3D = $Flashlight
@onready var vision_debug: Node3D = $VisionDebug

# State Management
var current_state: NPCState = NPCState.PATROL
var previous_state: NPCState = NPCState.PATROL

# Waypoint System
var current_waypoint_index: int = 0

# Player Tracking
var player_reference: PlayerController
var last_known_player_position: Vector3
var time_since_player_seen: float = 0.0
var player_in_sight: bool = false
var previous_player_in_sight: bool = false

# Investigation
var investigation_position: Vector3
var search_positions: Array[Vector3] = []
var current_search_index: int = 0

# Suspicion System
var suspicion_level: float = 0.0
var is_suspicious: bool = false
var is_investigating: bool = false

# Memory & Navigation
var home_position: Vector3
var detection_time: float = 0.0
var detection_threshold: float = 0.5  # Faster detection (was 1.0)

# Performance optimization
var vision_check_timer: float = 0.0
var vision_check_interval: float = 0.05  # Check vision every 0.05 seconds (more responsive)
var distance_to_player: float = 0.0

# Proximity detection
@export var catch_distance: float = 1.2  # Distance at which NPC catches player

# Performance profiling
var performance_monitor: AdvancedPerformanceMonitor

# Communication System
var communication_manager: NPCCommunicationManager
var received_alerts: Array = []
var shared_search_targets: Array[Vector3] = []
var coordination_enabled: bool = true

# Enhanced AI Properties
@export var personality_alertness: float = 1.0  # 0.5 = lazy, 2.0 = very alert
@export var personality_persistence: float = 1.0  # How long they search
@export var communication_range: float = 15.0
@export var help_call_threshold: float = 2.0  # Seconds before calling for help

# Memory and Learning System
var memory_system: NPCMemorySystem
var learning_enabled: bool = true
var last_player_route_position: Vector3 = Vector3.ZERO
var route_tracking_timer: float = 0.0

# Predictive AI System
var predictive_ai: NPCPredictiveAI
var use_predictive_movement: bool = true
var predicted_player_position: Vector3 = Vector3.ZERO
var prediction_confidence: float = 0.0

# Signals
signal player_spotted(npc: NPCController)
signal player_caught(npc: NPCController)
signal detection_progress_changed(progress: float)
signal suspicion_changed_debug(level: int)
signal state_changed_debug(state: String)
signal player_in_vision_changed(in_vision: bool)
signal last_seen_position_changed(position: Vector3)
signal patrol_point_changed(point: int)

func _ready() -> void:
	navigation_agent.path_desired_distance = 0.5
	navigation_agent.target_desired_distance = 0.5
	
	state_timer.timeout.connect(_on_state_timer_timeout)
	
	# Store home position
	home_position = global_position
	
	# Find and register with communication manager
	await get_tree().process_frame
	communication_manager = get_tree().get_first_node_in_group("npc_communication_manager")
	if communication_manager:
		communication_manager.register_npc(self)
	else:
		print("Warning: No NPCCommunicationManager found for ", name)
	
	# Initialize memory system
	if learning_enabled:
		memory_system = NPCMemorySystem.new()
		memory_system.name = name + "_Memory"
		add_child(memory_system)
		
		# Connect memory system signals
		memory_system.pattern_learned.connect(_on_pattern_learned)
		memory_system.behavior_adapted.connect(_on_behavior_adapted)
	
	# Initialize predictive AI system
	if use_predictive_movement:
		predictive_ai = NPCPredictiveAI.new()
		predictive_ai.name = name + "_PredictiveAI"
		add_child(predictive_ai)
		
		# Connect predictive AI signals
		predictive_ai.prediction_updated.connect(_on_prediction_updated)
		predictive_ai.interception_route_calculated.connect(_on_interception_route_calculated)
	
	# Initialize state label
	if state_label:
		state_label.text = "PATROL"
		state_label.modulate = Color.WHITE
	
	# Start patrolling if waypoints exist
	if patrol_waypoints.size() > 0:
		_set_next_patrol_target()
	else:
		current_state = NPCState.IDLE
		if state_label:
			state_label.text = "IDLE"
	
	# Connect to player noise signals
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_reference = players[0]
		player_reference.made_noise.connect(_on_player_made_noise)
	
	# Vision cone area detection no longer needed - using light-based detection
	
	# Connect navigation agent avoidance callback
	if navigation_agent:
		navigation_agent.velocity_computed.connect(_on_velocity_computed)
	
	# Find performance monitor
	var game_node = get_tree().get_first_node_in_group("game")
	if game_node and game_node.has_method("get") and game_node.advanced_performance_monitor:
		performance_monitor = game_node.advanced_performance_monitor

func _physics_process(delta: float) -> void:
	if performance_monitor:
		performance_monitor.profile_section_start("NPC_Physics")
	
	if GameManager.current_state != GameManager.GameState.PLAYING:
		velocity = Vector3.ZERO
		move_and_slide()
		if performance_monitor:
			performance_monitor.profile_section_end("NPC_Physics")
		return
	
	# Calculate distance to player for LOD and proximity detection
	if player_reference:
		distance_to_player = global_position.distance_to(player_reference.global_position)
		
		# Check if NPC caught the player
		if distance_to_player <= catch_distance:
			_on_player_caught()
	
	if performance_monitor:
		performance_monitor.profile_section_start("NPC_Suspicion")
	# Update suspicion and player tracking
	_update_suspicion_system(delta)
	_update_player_tracking(delta)
	_update_memory_system(delta)
	if performance_monitor:
		performance_monitor.profile_section_end("NPC_Suspicion")
	
	if performance_monitor:
		performance_monitor.profile_section_start("NPC_StateMachine")
	# Handle current state
	match current_state:
		NPCState.IDLE:
			_handle_idle_state(delta)
		NPCState.PATROL:
			_handle_patrol_state(delta)
		NPCState.SUSPICIOUS:
			_handle_suspicious_state(delta)
		NPCState.INVESTIGATE:
			_handle_investigate_state(delta)
		NPCState.SEARCH:
			_handle_search_state(delta)
		NPCState.CHASE:
			_handle_chase_state(delta)
		NPCState.RETURN_TO_PATROL:
			_handle_return_state(delta)
	if performance_monitor:
		performance_monitor.profile_section_end("NPC_StateMachine")
	
	if performance_monitor:
		performance_monitor.profile_section_start("NPC_Vision")
	# LOD vision checking - only check when timer expires
	vision_check_timer += delta
	if vision_check_timer >= _get_vision_check_interval():
		vision_check_timer = 0.0
		_check_vision_cone()
	if performance_monitor:
		performance_monitor.profile_section_end("NPC_Vision")
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0
	
	move_and_slide()
	
	if performance_monitor:
		performance_monitor.profile_section_end("NPC_Physics")

func _handle_idle_state(_delta: float) -> void:
	velocity.x = 0
	velocity.z = 0

func _handle_patrol_state(delta: float) -> void:
	# Check if we should adapt patrol based on predictions
	adapt_patrol_to_prediction()
	
	if navigation_agent.is_navigation_finished():
		# Reached waypoint, wait then move to next
		if state_timer.is_stopped():
			state_timer.start(wait_time_at_waypoint)
		return
	
	var current_position := global_position
	var next_position := navigation_agent.get_next_path_position()
	var direction := (next_position - current_position).normalized()
	
	# Adjust patrol speed based on predictive confidence
	var speed_multiplier = 1.0
	if prediction_confidence > 0.7:
		speed_multiplier = 1.3  # Move faster when we have high confidence prediction
	elif prediction_confidence > 0.4:
		speed_multiplier = 1.1  # Slightly faster with medium confidence
	
	# Move towards waypoint with avoidance
	var desired_velocity = Vector3(direction.x * patrol_speed * speed_multiplier, 0, direction.z * patrol_speed * speed_multiplier)
	_move_with_avoidance(desired_velocity)
	
	# Rotate to face movement direction
	if direction.length() > 0.1:
		_rotate_towards_direction(direction, delta)

func _handle_investigate_state(delta: float) -> void:
	if navigation_agent.is_navigation_finished():
		# Reached investigation point, look around
		if state_timer.is_stopped():
			state_timer.start(investigation_time)
		
		# Rotate while investigating
		rotation.y += turn_speed * 0.5 * delta
		
		# Direction arrow and flashlight rotate with parent automatically
		
		velocity.x = 0
		velocity.z = 0
		return
	
	var current_position := global_position
	var next_position := navigation_agent.get_next_path_position()
	var direction := (next_position - current_position).normalized()
	
	var desired_velocity = Vector3(direction.x * investigate_speed, 0, direction.z * investigate_speed)
	_move_with_avoidance(desired_velocity)
	
	if direction.length() > 0.1:
		_rotate_towards_direction(direction, delta)

func _handle_chase_state(delta: float) -> void:
	if not player_reference:
		_switch_to_return_state()
		return
	
	# Update target to player's current position
	navigation_agent.target_position = player_reference.global_position
	
	if navigation_agent.is_navigation_finished():
		# Lost the player
		_switch_to_investigate_state(player_reference.global_position)
		return
	
	var current_position := global_position
	var next_position := navigation_agent.get_next_path_position()
	var direction := (next_position - current_position).normalized()
	
	var desired_velocity = Vector3(direction.x * chase_speed, 0, direction.z * chase_speed)
	_move_with_avoidance(desired_velocity)
	
	if direction.length() > 0.1:
		_rotate_towards_direction(direction, delta)

func _handle_return_state(delta: float) -> void:
	if navigation_agent.is_navigation_finished():
		# Returned to patrol route
		current_state = NPCState.PATROL
		_set_next_patrol_target()
		return
	
	var current_position := global_position
	var next_position := navigation_agent.get_next_path_position()
	var direction := (next_position - current_position).normalized()
	
	var desired_velocity = Vector3(direction.x * patrol_speed, 0, direction.z * patrol_speed)
	_move_with_avoidance(desired_velocity)
	
	if direction.length() > 0.1:
		_rotate_towards_direction(direction, delta)

func _check_vision_cone() -> void:
	if not player_reference or not flashlight or current_state == NPCState.CHASE:
		player_in_sight = false
		_reset_detection()
		return
	
	# Use light-based detection instead of area collision
	var player_detected: bool = _is_player_in_flashlight()
	player_in_sight = player_detected
	
	# Emit vision change signal if state changed
	if player_in_sight != previous_player_in_sight:
		player_in_vision_changed.emit(player_in_sight)
		previous_player_in_sight = player_in_sight
	
	if player_detected:
		detection_time += get_process_delta_time()
		# Set vision cone to alert mode
		if vision_cone:
			vision_cone.set_alert_mode(true)
		detection_progress_changed.emit(detection_time / detection_threshold)
		
		if detection_time >= detection_threshold:
			_on_player_spotted()
	else:
		_reset_detection()

func _reset_detection() -> void:
	if detection_time > 0.0:
		detection_time = 0.0
		# Reset vision cone to normal mode
		if vision_cone:
			vision_cone.set_alert_mode(false)
		detection_progress_changed.emit(0.0)

func _is_player_in_flashlight() -> bool:
	if not player_reference or not flashlight:
		return false
	
	var flashlight_pos = flashlight.global_position
	# Use NPC forward direction - NPCs face positive Z direction
	var npc_forward = global_transform.basis.z
	var player_pos = player_reference.global_position
	
	# Check if player is within flashlight range
	var to_player = player_pos - flashlight_pos
	var distance = to_player.length()
	if distance > flashlight.spot_range:
		return false
	
	# Skip detection if player is too close (avoid self-intersection)
	if distance < 0.5:
		return true  # Always detect if very close
	
	# Check if player is within flashlight cone angle (more generous)
	var angle_to_player: float = rad_to_deg(npc_forward.angle_to(to_player.normalized()))
	if angle_to_player > flashlight.spot_angle * 0.6:  # 60% of cone angle instead of 50%
		return false
	
	# Perform multiple raycasts to different parts of the player - more coverage points
	var hit_points = [
		player_pos,  # Center
		player_pos + Vector3(0.4, 0, 0),     # Right
		player_pos + Vector3(-0.4, 0, 0),    # Left  
		player_pos + Vector3(0, 0.8, 0),     # Top (head)
		player_pos + Vector3(0, -0.8, 0),    # Bottom (feet)
		player_pos + Vector3(0.3, 0.3, 0),   # Top-right
		player_pos + Vector3(-0.3, 0.3, 0),  # Top-left
		player_pos + Vector3(0, 0.3, 0),     # Mid-height
	]
	
	var hits = 0
	for point in hit_points:
		if _raycast_to_point(flashlight_pos, point):
			hits += 1
	
	# Visualize detection rays if vision_debug exists
	if vision_debug and vision_debug.has_method("show_detection_rays"):
		vision_debug.show_detection_rays(flashlight_pos, hit_points, hits >= 1)
	
	# Debug output to help troubleshoot
	if distance < 5.0:  # Expanded debug range
		print("Debug - Distance: ", distance, " Angle: ", angle_to_player, " Hits: ", hits, "/", hit_points.size())
	
	# Player is detected if at least 1 out of 8 rays hit (much more generous)
	return hits >= 1

func _raycast_to_point(from: Vector3, to: Vector3) -> bool:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 3  # Check walls (layer 1) and player (layer 2)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	# Debug close range raycasts
	var distance = from.distance_to(to)
	if distance < 3.0:
		print("  Raycast from ", from, " to ", to, " distance: ", distance)
		if not result.is_empty():
			print("    Hit: ", result.collider.name if result.has("collider") else "unknown")
		else:
			print("    No hit")
	
	# Return true if we hit the player, false if we hit a wall or nothing
	return result.is_empty() or (result.has("collider") and result.collider == player_reference)

func _on_player_spotted() -> void:
	# Record sighting in memory system
	if memory_system and learning_enabled:
		memory_system.add_memory(NPCMemorySystem.MemoryType.PLAYER_SIGHTING, player_reference.global_position, {
			"detection_duration": detection_time,
			"distance": distance_to_player,
			"npc_state": current_state
		})
	
	# Alert other NPCs before changing state
	if communication_manager:
		communication_manager.raise_alert(NPCCommunicationManager.AlertLevel.HIGH, player_reference.global_position, self)
	
	current_state = NPCState.CHASE
	state_timer.stop()
	player_spotted.emit(self)
	GameManager.trigger_game_over("You were spotted by the security guard!")

func _on_player_caught() -> void:
	# Prevent multiple game over triggers
	if GameManager.current_state == GameManager.GameState.GAME_OVER:
		return
		
	current_state = NPCState.CHASE
	state_timer.stop()
	player_caught.emit(self)
	GameManager.trigger_game_over("You were caught by the security guard!")

func _on_player_made_noise(noise_position: Vector3, noise_radius: float) -> void:
	if current_state == NPCState.CHASE:
		return
	
	var distance_to_noise := global_position.distance_to(noise_position)
	
	if distance_to_noise <= noise_radius:
		# Share noise information with nearby NPCs
		if communication_manager:
			var alert_level = NPCCommunicationManager.AlertLevel.MEDIUM if noise_radius >= 7.0 else NPCCommunicationManager.AlertLevel.LOW
			communication_manager.raise_alert(alert_level, noise_position, self)
		
		# If noise radius is large (player is running), chase directly
		if noise_radius >= 7.0:  # Running noise threshold
			current_state = NPCState.CHASE
			state_timer.stop()
		else:
			_switch_to_investigate_state(noise_position)

func _switch_to_investigate_state(position: Vector3) -> void:
	current_state = NPCState.INVESTIGATE
	investigation_position = position
	navigation_agent.target_position = investigation_position
	state_timer.stop()

func _switch_to_return_state() -> void:
	current_state = NPCState.RETURN_TO_PATROL
	
	# Return to nearest waypoint
	if patrol_waypoints.size() > 0:
		var nearest_waypoint := patrol_waypoints[0]
		var nearest_distance := global_position.distance_to(nearest_waypoint.global_position)
		
		for i in range(1, patrol_waypoints.size()):
			var distance := global_position.distance_to(patrol_waypoints[i].global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_waypoint = patrol_waypoints[i]
				current_waypoint_index = i
		
		navigation_agent.target_position = nearest_waypoint.global_position
	else:
		navigation_agent.target_position = home_position

func _set_next_patrol_target() -> void:
	if patrol_waypoints.size() == 0:
		return
	
	current_waypoint_index = (current_waypoint_index + 1) % patrol_waypoints.size()
	navigation_agent.target_position = patrol_waypoints[current_waypoint_index].global_position
	patrol_point_changed.emit(current_waypoint_index)

func _move_with_avoidance(desired_velocity: Vector3) -> void:
	# Set the desired velocity for avoidance
	navigation_agent.set_velocity(desired_velocity)
	
	# The actual velocity will be set by the avoidance callback
	# If avoidance is disabled or no obstacles, use desired velocity
	if not navigation_agent.avoidance_enabled:
		velocity.x = desired_velocity.x
		velocity.z = desired_velocity.z

func _rotate_towards_direction(direction: Vector3, delta: float) -> void:
	var target_rotation := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_rotation, turn_speed * delta)
	
	# Direction arrow and flashlight rotate with parent automatically

func _on_state_timer_timeout() -> void:
	match current_state:
		NPCState.PATROL:
			_set_next_patrol_target()
		NPCState.SUSPICIOUS:
			if suspicion_level >= investigate_threshold:
				_change_state(NPCState.INVESTIGATE)
			else:
				_change_state(NPCState.PATROL)
		NPCState.INVESTIGATE:
			_change_state(NPCState.SEARCH)
		NPCState.SEARCH:
			_change_state(NPCState.RETURN_TO_PATROL)

# Enhanced Suspicion & State Management
func _update_suspicion_system(delta: float) -> void:
	var old_suspicion := suspicion_level
	
	if player_in_sight:
		suspicion_level += suspicion_gain_rate * delta
	else:
		suspicion_level -= suspicion_decay_rate * delta
	
	suspicion_level = clamp(suspicion_level, 0.0, max_suspicion)
	
	if abs(old_suspicion - suspicion_level) > 1.0:
		suspicion_changed_debug.emit(int(suspicion_level))
	
	_check_suspicion_state_changes()

func _update_player_tracking(delta: float) -> void:
	if player_in_sight:
		time_since_player_seen = 0.0
		last_known_player_position = player_reference.global_position
		last_seen_position_changed.emit(last_known_player_position)
	else:
		time_since_player_seen += delta

func _check_suspicion_state_changes() -> void:
	match current_state:
		NPCState.PATROL:
			if suspicion_level >= suspicious_threshold:
				_change_state(NPCState.SUSPICIOUS)
		
		NPCState.SUSPICIOUS:
			if suspicion_level >= investigate_threshold:
				_change_state(NPCState.INVESTIGATE)
			elif suspicion_level <= 0.0:
				_change_state(NPCState.PATROL)

func _change_state(new_state: NPCState) -> void:
	if new_state == current_state:
		return
	
	var old_state := current_state
	previous_state = current_state
	current_state = new_state
	
	# Emit debug signal with state name as string
	var state_name := _get_state_name(new_state)
	state_changed_debug.emit(state_name)
	
	# Update 3D state label
	if state_label:
		state_label.text = state_name
		# Color code the label based on state
		match new_state:
			NPCState.IDLE, NPCState.PATROL:
				state_label.modulate = Color.WHITE
			NPCState.SUSPICIOUS:
				state_label.modulate = Color.YELLOW
			NPCState.INVESTIGATE, NPCState.SEARCH:
				state_label.modulate = Color.ORANGE
			NPCState.CHASE:
				state_label.modulate = Color.RED
			NPCState.RETURN_TO_PATROL:
				state_label.modulate = Color.CYAN
	
	_on_state_entered(new_state)

func _get_state_name(state: NPCState) -> String:
	match state:
		NPCState.IDLE: return "IDLE"
		NPCState.PATROL: return "PATROL"
		NPCState.SUSPICIOUS: return "SUSPICIOUS"
		NPCState.INVESTIGATE: return "INVESTIGATE" 
		NPCState.SEARCH: return "SEARCH"
		NPCState.CHASE: return "CHASE"
		NPCState.RETURN_TO_PATROL: return "RETURN_TO_PATROL"
		_: return "UNKNOWN"

func _on_state_entered(state: NPCState) -> void:
	match state:
		NPCState.SUSPICIOUS:
			state_timer.start(suspicious_time)
			velocity = Vector3.ZERO
		
		NPCState.INVESTIGATE:
			investigation_position = last_known_player_position
			navigation_agent.target_position = investigation_position
			state_timer.start(investigation_time)
		
		NPCState.SEARCH:
			_generate_search_positions()
			current_search_index = 0
			if search_positions.size() > 0:
				navigation_agent.target_position = search_positions[0]
			state_timer.start(search_time)
		
		NPCState.CHASE:
			state_timer.stop()
		
		NPCState.RETURN_TO_PATROL:
			_set_next_patrol_target()
			state_timer.stop()

func _generate_search_positions() -> void:
	search_positions.clear()
	
	# Use memory system for intelligent search if available
	var base_pos := last_known_player_position
	if memory_system and learning_enabled:
		var predicted_pos = memory_system.get_predicted_player_location()
		if predicted_pos != Vector3.ZERO:
			base_pos = predicted_pos
		
		# Add known hiding spots to search list
		var hiding_spots = memory_system.get_pattern_data("effective_hiding_spots")
		if hiding_spots.has("effective_hiding_spots"):
			for spot in hiding_spots["effective_hiding_spots"]:
				if base_pos.distance_to(spot.position) <= 10.0:  # Within reasonable distance
					search_positions.append(spot.position)
		
		# Add common route positions
		var routes = memory_system.get_pattern_data("common_routes")
		if routes.has("common_routes"):
			for route in routes["common_routes"]:
				if base_pos.distance_to(route.center) <= 8.0:  # Near current search area
					search_positions.append(route.center)
	
	# Use communication manager for coordinated search if available
	if communication_manager and coordination_enabled:
		var coordinated_pos = communication_manager.request_search_coordination(self)
		if coordinated_pos != Vector3.ZERO:
			search_positions.append(coordinated_pos)
	
	# Use shared information to improve search
	if communication_manager:
		var shared_positions = communication_manager.get_last_known_positions()
		if not shared_positions.is_empty():
			# Use most recent shared position if we don't have better intel
			if search_positions.is_empty():
				base_pos = communication_manager.get_most_likely_player_position()
	
	# Generate search positions around the base position if we don't have specific targets
	if search_positions.is_empty():
		var search_radius := 3.0 * personality_persistence
		var num_positions = 4
		
		# More thorough search if memory suggests this area has hiding spots
		if should_search_thoroughly_here(base_pos):
			search_radius *= 1.5
			num_positions = 6
		
		for i in range(num_positions):
			var angle: float = (i * PI * 2.0 / num_positions) + randf() * PI * 0.25
			var offset := Vector3(cos(angle), 0, sin(angle)) * (search_radius * (0.5 + randf() * 0.5))
			search_positions.append(base_pos + offset)

func _get_vision_check_interval() -> float:
	# More aggressive LOD system for better detection
	if distance_to_player > 15.0:
		return 0.2  # Very far - check every 0.2 seconds (was 0.5)
	elif distance_to_player > 10.0:
		return 0.1  # Far - check every 0.1 seconds (was 0.25)
	elif distance_to_player > 5.0:
		return 0.05  # Medium - check every 0.05 seconds (was 0.1)
	else:
		return 0.02  # Close - check every 0.02 seconds (was 0.05)

# New State Handlers
func _handle_suspicious_state(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	
	# Slowly turn around looking for the player
	rotation.y += turn_speed * 0.3 * delta
	
	# Direction arrow and flashlight rotate with parent automatically

func _handle_search_state(delta: float) -> void:
	if search_positions.is_empty():
		_change_state(NPCState.RETURN_TO_PATROL)
		return
	
	if navigation_agent.is_navigation_finished():
		# Move to next search position
		current_search_index += 1
		if current_search_index >= search_positions.size():
			_change_state(NPCState.RETURN_TO_PATROL)
			return
		
		navigation_agent.target_position = search_positions[current_search_index]
		return
	
	# Move to current search position
	var current_position := global_position
	var next_position := navigation_agent.get_next_path_position()
	var direction := (next_position - current_position).normalized()
	
	var desired_velocity = Vector3(direction.x * search_speed, 0, direction.z * search_speed)
	_move_with_avoidance(desired_velocity)
	
	if direction.length() > 0.1:
		_rotate_towards_direction(direction, delta)

# ===================== COMMUNICATION SYSTEM =====================

func receive_communication(message: Dictionary) -> void:
	# Handle messages from other NPCs
	match message.type:
		"alert":
			_handle_received_alert(message)
		"request_help":
			_handle_help_request(message)
		"share_position":
			_handle_shared_position(message)
		"coordinate_search":
			_handle_coordinate_search(message)

func _handle_received_alert(message: Dictionary) -> void:
	var alert_level = message.level
	var alert_position = message.position
	var distance_to_alert = global_position.distance_to(alert_position)
	
	# React based on alert level and distance
	match alert_level:
		NPCCommunicationManager.AlertLevel.HIGH:
			# High alert - move to assist immediately
			if current_state != NPCState.CHASE and distance_to_alert <= communication_range * 2:
				_switch_to_investigate_state(alert_position)
				suspicion_level = investigate_threshold * 0.8  # Boost suspicion
		
		NPCCommunicationManager.AlertLevel.MEDIUM:
			# Medium alert - investigate if nearby
			if current_state == NPCState.PATROL and distance_to_alert <= communication_range:
				_switch_to_investigate_state(alert_position)
		
		NPCCommunicationManager.AlertLevel.LOW:
			# Low alert - increase suspicion
			if distance_to_alert <= communication_range * 0.5:
				suspicion_level += suspicious_threshold * 0.3

func _handle_help_request(message: Dictionary) -> void:
	var help_position = message.position
	var distance = global_position.distance_to(help_position)
	
	# Respond to help requests from nearby NPCs
	if distance <= communication_range and current_state != NPCState.CHASE:
		_switch_to_investigate_state(help_position)

func _handle_shared_position(message: Dictionary) -> void:
	# Update our knowledge with shared position information
	var shared_pos = message.position
	var confidence = message.get("confidence", 0.5)
	
	# Use shared information to improve our search
	if current_state == NPCState.SEARCH or current_state == NPCState.INVESTIGATE:
		last_known_player_position = shared_pos

func _handle_coordinate_search(message: Dictionary) -> void:
	# Coordinate search patterns with other NPCs
	var search_area = message.get("search_area", Vector3.ZERO)
	if search_area != Vector3.ZERO:
		shared_search_targets.append(search_area)

func receive_alert_cleared() -> void:
	# React to alert being cleared
	if current_state in [NPCState.INVESTIGATE, NPCState.SEARCH]:
		# Gradually return to normal patrol
		suspicion_level *= 0.5

func call_for_backup() -> void:
	# Call nearby NPCs for help
	if communication_manager:
		var nearby_npcs = communication_manager.get_nearby_npcs(global_position, communication_range)
		for npc in nearby_npcs:
			if npc != self and npc.has_method("receive_communication"):
				var message = {
					"type": "request_help",
					"position": global_position,
					"source": self,
					"timestamp": Time.get_time_dict_from_system()["unix"]
				}
				npc.receive_communication(message)

# ===================== MEMORY & LEARNING SYSTEM =====================

func _update_memory_system(delta: float):
	if not memory_system or not learning_enabled or not player_reference:
		return
	
	# Track player routes
	route_tracking_timer += delta
	if route_tracking_timer >= 2.0:  # Sample player position every 2 seconds
		route_tracking_timer = 0.0
		var current_player_pos = player_reference.global_position
		
		# Only track if player moved significantly
		if last_player_route_position.distance_to(current_player_pos) > 3.0:
			# Check if we can see the player's route (indirect tracking)
			var space_state = get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(global_position, current_player_pos)
			query.collision_mask = 1  # Only walls
			var result = space_state.intersect_ray(query)
			
			if result.is_empty():  # Clear line of sight to player area
				memory_system.add_memory(NPCMemorySystem.MemoryType.PLAYER_ROUTE, current_player_pos, {
					"timestamp": Time.get_time_dict_from_system()["unix"],
					"frequency": 1
				})
			
			last_player_route_position = current_player_pos
	
	# Apply behavioral adaptations
	_apply_memory_based_adaptations()

func _apply_memory_based_adaptations():
	if not memory_system:
		return
	
	# Adjust detection parameters based on learned behavior
	var vision_multiplier = memory_system.get_behavioral_adjustment("vision_range_multiplier")
	var suspicion_multiplier = memory_system.get_behavioral_adjustment("suspicion_sensitivity")
	var search_multiplier = memory_system.get_behavioral_adjustment("search_thoroughness")
	
	# Apply vision range adjustment
	if flashlight:
		var base_range = 15.0
		flashlight.spot_range = base_range * vision_multiplier
	
	# Apply suspicion sensitivity
	suspicion_gain_rate = 25.0 * suspicion_multiplier
	
	# Apply search thoroughness
	search_time = 5.0 * search_multiplier

func _on_pattern_learned(pattern_type: String, pattern_data: Dictionary):
	print("NPC ", name, " learned pattern: ", pattern_type, " - ", pattern_data)
	
	match pattern_type:
		"common_route":
			# Adapt patrol to cover common player routes
			_adapt_patrol_for_route(pattern_data.center)
		
		"hiding_spot":
			# Check hiding spots more thoroughly
			memory_system.adapt_behavior("search_thoroughness", 0.3)
		
		"timing_pattern":
			# Adjust alertness based on player activity times
			var current_hour = Time.get_time_dict_from_system().hour
			if current_hour == pattern_data.get("peak_hour", 12):
				memory_system.adapt_behavior("suspicion_sensitivity", 0.2)

func _on_behavior_adapted(adaptation_type: String, old_value: float, new_value: float):
	print("NPC ", name, " adapted ", adaptation_type, " from ", old_value, " to ", new_value)
	
	# Update state label to show adaptation
	if state_label and abs(new_value - 1.0) > 0.2:  # Show if significantly different from default
		var adaptation_text = ""
		match adaptation_type:
			"vision_range_multiplier":
				adaptation_text = " [Enhanced Vision]" if new_value > 1.2 else " [Reduced Vision]"
			"suspicion_sensitivity":
				adaptation_text = " [Paranoid]" if new_value > 1.5 else " [Relaxed]"
			"search_thoroughness":
				adaptation_text = " [Thorough]" if new_value > 1.3 else ""
		
		if adaptation_text != "":
			state_label.text = _get_state_name(current_state) + adaptation_text

func _adapt_patrol_for_route(route_position: Vector3):
	# Add new patrol waypoint near common player route
	if patrol_waypoints.size() > 0:
		# Find closest existing waypoint
		var closest_waypoint = patrol_waypoints[0]
		var closest_distance = route_position.distance_to(closest_waypoint.global_position)
		var closest_index = 0
		
		for i in range(1, patrol_waypoints.size()):
			var distance = route_position.distance_to(patrol_waypoints[i].global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_waypoint = patrol_waypoints[i]
				closest_index = i
		
		# If route is far from existing waypoints, suggest adding a new one
		if closest_distance > 8.0:
			print("NPC ", name, " suggests adding waypoint near ", route_position, " to cover player route")

func record_noise_event(noise_position: Vector3, noise_volume: float):
	if memory_system and learning_enabled:
		memory_system.add_memory(NPCMemorySystem.MemoryType.NOISE_EVENT, noise_position, {
			"volume": noise_volume,
			"timestamp": Time.get_time_dict_from_system()["unix"]
		})

func record_environmental_change(position: Vector3, change_type: String, player_caused: bool = false):
	if memory_system and learning_enabled:
		memory_system.add_memory(NPCMemorySystem.MemoryType.ENVIRONMENTAL_CHANGE, position, {
			"change_type": change_type,
			"player_caused": player_caused,
			"timestamp": Time.get_time_dict_from_system()["unix"]
		})

func get_predicted_search_location() -> Vector3:
	if memory_system and learning_enabled:
		var predicted = memory_system.get_predicted_player_location()
		if predicted != Vector3.ZERO:
			return predicted
	
	# Fallback to last known position
	return last_known_player_position

func should_search_thoroughly_here(position: Vector3) -> bool:
	if memory_system and learning_enabled:
		return memory_system.should_check_area_more_thoroughly(position)
	return false

# ===================== PREDICTIVE AI INTEGRATION =====================

func _on_prediction_updated(predicted_position: Vector3, confidence: float):
	predicted_player_position = predicted_position
	prediction_confidence = confidence
	
	# Update investigation target if we're actively searching
	if current_state == NPCState.INVESTIGATE and confidence > 0.7:
		# High confidence prediction - redirect investigation
		navigation_agent.target_position = predicted_position
		investigation_position = predicted_position

func _on_interception_route_calculated(waypoints: Array[Vector3]):
	# Use interception points for patrol adaptation
	if current_state == NPCState.PATROL and waypoints.size() > 0:
		var closest_interception = waypoints[0]
		var closest_distance = global_position.distance_to(closest_interception)
		
		for waypoint in waypoints:
			var distance = global_position.distance_to(waypoint)
			if distance < closest_distance:
				closest_distance = distance
				closest_interception = waypoint
		
		# If interception point is reasonable distance, consider it
		if closest_distance <= 10.0 and prediction_confidence > 0.6:
			print("NPC ", name, " considering interception at ", closest_interception)

func get_predictive_search_position() -> Vector3:
	if predictive_ai and use_predictive_movement:
		var prediction = predictive_ai.get_current_prediction()
		if prediction != Vector3.ZERO and predictive_ai.get_prediction_confidence() > 0.5:
			return prediction
	return get_predicted_search_location()

func use_predictive_patrolling() -> bool:
	# Use predictive patrolling when confidence is high
	return predictive_ai and prediction_confidence > 0.8

func adapt_patrol_to_prediction():
	if not use_predictive_patrolling():
		return
	
	# Temporarily modify patrol target to intercept predicted player position
	if predicted_player_position != Vector3.ZERO:
		# Find if predicted position is near any patrol waypoint
		var nearest_waypoint_index = -1
		var nearest_distance = float("inf")
		
		for i in range(patrol_waypoints.size()):
			var distance = patrol_waypoints[i].global_position.distance_to(predicted_player_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_waypoint_index = i
		
		# If prediction is reasonably close to a waypoint, prioritize it
		if nearest_distance < 8.0 and nearest_waypoint_index != current_waypoint_index:
			current_waypoint_index = nearest_waypoint_index
			navigation_agent.target_position = patrol_waypoints[current_waypoint_index].global_position
			print("NPC ", name, " adapting patrol to intercept predicted player at waypoint ", nearest_waypoint_index)

# Light-based detection - no need for area collision handlers

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	# This callback receives the collision-free velocity from NavigationAgent3D
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
