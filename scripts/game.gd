extends Node3D

@onready var player: PlayerController = $Player
@onready var camera_rig: IsometricCamera = $CameraRig
@onready var security_guard: NPCController = $SecurityGuard
@onready var security_guard2: NPCController = $SecurityGuard2
@onready var patrol_waypoints: Node3D = $PatrolWaypoints
@onready var patrol_waypoints2: Node3D = $PatrolWaypoints2
@onready var biscuit_jar: StaticBody3D = $BiscuitJar
@onready var exit_elevator: Area3D = $ExitElevator
@onready var game_ui: Control = $GameUI
@onready var performance_monitor: PerformanceMonitor = $PerformanceMonitor

# Add advanced performance monitor as well
var advanced_performance_monitor: AdvancedPerformanceMonitor

func _ready() -> void:
	# Set up camera to follow player
	camera_rig.set_target(player)
	
	# Set up automatic occluders for better performance
	# Temporarily disabled for debugging
	# AutoOccluder.setup_scene_occluders(self)
	
	# Set up NPC patrol waypoints
	var waypoints: Array[Node3D] = []
	for child in patrol_waypoints.get_children():
		if child is Marker3D:
			waypoints.append(child)
	
	if security_guard:
		security_guard.patrol_waypoints = waypoints
		# Connect to show detection progress
		security_guard.connect("player_spotted", _on_player_spotted)
		security_guard.connect("detection_progress_changed", _on_detection_progress_changed)
		# Connect debug console updates
		security_guard.connect("state_changed_debug", _on_npc_state_changed)
		security_guard.connect("suspicion_changed_debug", _on_npc_suspicion_changed)
		security_guard.connect("player_in_vision_changed", _on_player_in_vision_changed)
		security_guard.connect("last_seen_position_changed", _on_last_seen_position_changed)
		security_guard.connect("patrol_point_changed", _on_patrol_point_changed)
	
	# Set up second NPC patrol waypoints
	var waypoints2: Array[Node3D] = []
	for child in patrol_waypoints2.get_children():
		if child is Marker3D:
			waypoints2.append(child)
	
	if security_guard2:
		security_guard2.patrol_waypoints = waypoints2
		# Connect similar signals for second guard
		security_guard2.connect("player_spotted", _on_player_spotted)
		security_guard2.connect("detection_progress_changed", _on_detection_progress_changed)
	
	# Initialize objectives
	if biscuit_jar and exit_elevator:
		ObjectiveManager.add_objective("Find the biscuit jar", biscuit_jar.global_position)
		ObjectiveManager.add_objective("Escape through the lift", exit_elevator.global_position)
	
	# Connect timer for game start
	$GameStart/Timer.timeout.connect(_on_game_start_timer_timeout)
	
	# Set up performance monitor
	if performance_monitor:
		performance_monitor.set_position_preset("bottom_right")
	
	# Create advanced performance monitor
	advanced_performance_monitor = preload("res://ui/advanced_performance_monitor.tscn").instantiate()
	add_child(advanced_performance_monitor)
	advanced_performance_monitor.position = Vector2(50, 50)

func _input(event: InputEvent) -> void:
	# Toggle performance monitors
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F3:
			# Simple monitor
			if performance_monitor:
				performance_monitor.toggle_visibility()
		elif event.keycode == KEY_F4:
			# Advanced monitor
			if advanced_performance_monitor:
				advanced_performance_monitor.toggle_visibility()
		elif event.keycode == KEY_F5:
			# Log performance report
			if advanced_performance_monitor:
				advanced_performance_monitor.log_performance_report()

func _on_game_start_timer_timeout() -> void:
	GameManager.start_game()

func _on_player_spotted(npc: NPCController) -> void:
	print("Player spotted by: ", npc.name)

func _on_detection_progress_changed(progress: float) -> void:
	print("Game received detection progress: ", progress)
	if game_ui:
		game_ui.update_detection_progress(progress)

# Debug console signal handlers
func _on_npc_state_changed(state: String) -> void:
	if game_ui:
		game_ui.update_npc_state(state)

func _on_npc_suspicion_changed(level: int) -> void:
	if game_ui:
		game_ui.update_suspicion_level(level)

func _on_player_in_vision_changed(in_vision: bool) -> void:
	if game_ui:
		game_ui.update_player_in_vision(in_vision)

func _on_last_seen_position_changed(position: Vector3) -> void:
	if game_ui:
		game_ui.update_last_seen_position(position)

func _on_patrol_point_changed(point: int) -> void:
	if game_ui:
		game_ui.update_patrol_point(point)
