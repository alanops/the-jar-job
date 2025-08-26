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
var player_in_area: bool = false

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
var detection_threshold: float = 1.0

# Performance optimization
var vision_check_timer: float = 0.0
var vision_check_interval: float = 0.1  # Check vision every 0.1 seconds
var distance_to_player: float = 0.0

# Performance profiling
var performance_monitor: AdvancedPerformanceMonitor

# Signals
signal player_spotted(npc: NPCController)
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
	
	# Connect vision cone signals
	if vision_cone:
		vision_cone.body_entered.connect(_on_vision_cone_body_entered)
		vision_cone.body_exited.connect(_on_vision_cone_body_exited)
	
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
	
	# Calculate distance to player for LOD
	if player_reference:
		distance_to_player = global_position.distance_to(player_reference.global_position)
	
	if performance_monitor:
		performance_monitor.profile_section_start("NPC_Suspicion")
	# Update suspicion and player tracking
	_update_suspicion_system(delta)
	_update_player_tracking(delta)
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
	if navigation_agent.is_navigation_finished():
		# Reached waypoint, wait then move to next
		if state_timer.is_stopped():
			state_timer.start(wait_time_at_waypoint)
		return
	
	var current_position := global_position
	var next_position := navigation_agent.get_next_path_position()
	var direction := (next_position - current_position).normalized()
	
	# Move towards waypoint
	velocity.x = direction.x * patrol_speed
	velocity.z = direction.z * patrol_speed
	
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
		
		# Update direction arrow to match rotation
		if direction_arrow:
			direction_arrow.rotation.y = rotation.y
		
		# Update flashlight to match rotation
		if flashlight:
			flashlight.rotation.y = rotation.y
		
		velocity.x = 0
		velocity.z = 0
		return
	
	var current_position := global_position
	var next_position := navigation_agent.get_next_path_position()
	var direction := (next_position - current_position).normalized()
	
	velocity.x = direction.x * patrol_speed
	velocity.z = direction.z * patrol_speed
	
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
	
	velocity.x = direction.x * chase_speed
	velocity.z = direction.z * chase_speed
	
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
	
	velocity.x = direction.x * patrol_speed
	velocity.z = direction.z * patrol_speed
	
	if direction.length() > 0.1:
		_rotate_towards_direction(direction, delta)

func _check_vision_cone() -> void:
	if not player_reference or not vision_cone or current_state == NPCState.CHASE:
		player_in_sight = false
		_reset_detection()
		return
	
	var player_detected: bool = false
	
	# Only do expensive checks if player is in the area
	if player_in_area:
		var in_cone: bool = vision_cone.is_target_in_cone(player_reference.global_position)
		# Only do line of sight check if player is in cone (expensive raycast)
		if in_cone:
			var los_clear: bool = _has_line_of_sight_to_player()
			player_detected = los_clear
	
	player_in_sight = player_detected
	
	# Emit vision change signal if state changed
	if player_in_sight != previous_player_in_sight:
		player_in_vision_changed.emit(player_in_sight)
		previous_player_in_sight = player_in_sight
	
	if player_detected:
		detection_time += get_process_delta_time()
		detection_progress_changed.emit(detection_time / detection_threshold)
		
		if detection_time >= detection_threshold:
			_on_player_spotted()
	else:
		_reset_detection()

func _reset_detection() -> void:
	detection_time = 0.0
	detection_progress_changed.emit(0.0)

func _has_line_of_sight_to_player() -> bool:
	if not player_reference or not raycast:
		return false
	
	var to_player := player_reference.global_position - raycast.global_position
	raycast.target_position = to_player
	raycast.add_exception(self)
	raycast.force_raycast_update()
	
	return not raycast.is_colliding() or raycast.get_collider() == player_reference

func _on_player_spotted() -> void:
	current_state = NPCState.CHASE
	state_timer.stop()
	player_spotted.emit(self)
	GameManager.trigger_game_over("You were spotted by the security guard!")

func _on_player_made_noise(noise_position: Vector3, noise_radius: float) -> void:
	if current_state == NPCState.CHASE:
		return
	
	var distance_to_noise := global_position.distance_to(noise_position)
	
	if distance_to_noise <= noise_radius:
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

func _rotate_towards_direction(direction: Vector3, delta: float) -> void:
	var target_rotation := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_rotation, turn_speed * delta)
	
	# Update direction arrow to match NPC rotation
	if direction_arrow:
		direction_arrow.rotation.y = rotation.y
	
	# Update flashlight to match NPC rotation
	if flashlight:
		flashlight.rotation.y = rotation.y

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
	var base_pos := last_known_player_position
	var search_radius := 3.0
	
	for i in range(4):
		var angle := (i * PI * 0.5) + randf() * PI * 0.25
		var offset := Vector3(cos(angle), 0, sin(angle)) * search_radius
		search_positions.append(base_pos + offset)

func _get_vision_check_interval() -> float:
	# LOD system: check vision less frequently when player is far away
	if distance_to_player > 15.0:
		return 0.5  # Very far - check every 0.5 seconds
	elif distance_to_player > 10.0:
		return 0.25  # Far - check every 0.25 seconds
	elif distance_to_player > 5.0:
		return 0.1  # Medium - check every 0.1 seconds
	else:
		return 0.05  # Close - check every 0.05 seconds

# New State Handlers
func _handle_suspicious_state(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	
	# Slowly turn around looking for the player
	rotation.y += turn_speed * 0.3 * delta
	
	# Update direction arrow to match rotation
	if direction_arrow:
		direction_arrow.rotation.y = rotation.y
	
	# Update flashlight to match rotation
	if flashlight:
		flashlight.rotation.y = rotation.y

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
	
	velocity.x = direction.x * search_speed
	velocity.z = direction.z * search_speed
	
	if direction.length() > 0.1:
		_rotate_towards_direction(direction, delta)

# Vision cone signal handlers
func _on_vision_cone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_area = true

func _on_vision_cone_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_area = false
