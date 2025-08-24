extends Node3D

@onready var player: PlayerController = $Player
@onready var camera_rig: IsometricCamera = $CameraRig
@onready var security_guard: NPCController = $SecurityGuard
@onready var patrol_waypoints: Node3D = $PatrolWaypoints
@onready var game_ui: Control = $GameUI

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
	
	# Connect timer for game start
	$GameStart/Timer.timeout.connect(_on_game_start_timer_timeout)

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
