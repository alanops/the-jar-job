extends Node3D

@onready var player: PlayerController = $Player
@onready var camera_rig: IsometricCamera = $CameraRig
@onready var security_guard: NPCController = $SecurityGuard
@onready var security_guard2: NPCController = $SecurityGuard2
@onready var security_guard3: NPCController = $SecurityGuard3
@onready var boss_npc: NPCController = $BossNPC
@onready var admin_npc: NPCController = $AdminOfficerNPC
@onready var coworker_npc: NPCController = $AngryCoworkerNPC
@onready var patrol_waypoints: Node3D = $PatrolWaypoints
@onready var patrol_waypoints2: Node3D = $PatrolWaypoints2
@onready var patrol_waypoints3: Node3D = $PatrolWaypoints3
@onready var boss_waypoints: Node3D = $BossWaypoints
@onready var admin_waypoints: Node3D = $AdminWaypoints
@onready var coworker_waypoints: Node3D = $CoworkerWaypoints
@onready var biscuit_jar: StaticBody3D = $BiscuitJar
@onready var game_ui: Control = $GameUI
@onready var performance_monitor: PerformanceMonitor = $PerformanceMonitor
@onready var walls_node: Node3D = $walls if has_node("walls") else null
@onready var floor_node: Node3D = $floor if has_node("floor") else null

# Add advanced performance monitor as well
var advanced_performance_monitor: AdvancedPerformanceMonitor
var level_setup_helper: LevelSetupHelper
var playable_area_analyzer: PlayableAreaAnalyzer

# NPC management
var npc_manager: NPCManager

func _ready() -> void:
	# Set up camera to follow player
	camera_rig.set_target(player)
	
	# Initialize NPC Manager
	npc_manager = NPCManager.new()
	npc_manager.name = "NPCManager"
	add_child(npc_manager)
	
	# Set up automatic occluders for better performance
	# Temporarily disabled for debugging
	# AutoOccluder.setup_scene_occluders(self)
	
	# Set up NPC patrol waypoints
	var waypoints: Array[Node3D] = []
	if patrol_waypoints:
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
		
		# Register with NPC Manager
		npc_manager.register_npc(security_guard)
	
	# Set up second NPC patrol waypoints
	var waypoints2: Array[Node3D] = []
	if patrol_waypoints2:
		for child in patrol_waypoints2.get_children():
			if child is Marker3D:
				waypoints2.append(child)
	
	if security_guard2:
		security_guard2.patrol_waypoints = waypoints2
		# Connect similar signals for second guard
		security_guard2.connect("player_spotted", _on_player_spotted)
		security_guard2.connect("detection_progress_changed", _on_detection_progress_changed)
		# Connect debug console updates (optional for second guard)
		security_guard2.connect("state_changed_debug", _on_npc_state_changed)
		security_guard2.connect("suspicion_changed_debug", _on_npc_suspicion_changed)
		
		# Register with NPC Manager
		npc_manager.register_npc(security_guard2)
	
	# Set up third NPC patrol waypoints
	var waypoints3: Array[Node3D] = []
	if patrol_waypoints3:
		for child in patrol_waypoints3.get_children():
			if child is Marker3D:
				waypoints3.append(child)
	
	if security_guard3:
		security_guard3.patrol_waypoints = waypoints3
		# Connect signals for third guard
		security_guard3.connect("player_spotted", _on_player_spotted)
		security_guard3.connect("detection_progress_changed", _on_detection_progress_changed)
		# Connect debug console updates
		security_guard3.connect("state_changed_debug", _on_npc_state_changed)
		security_guard3.connect("suspicion_changed_debug", _on_npc_suspicion_changed)
		
		# Register with NPC Manager
		npc_manager.register_npc(security_guard3)
	
	# Set up Boss NPC waypoints
	var boss_waypoint_array: Array[Node3D] = []
	if boss_waypoints:
		for child in boss_waypoints.get_children():
			if child is Marker3D:
				boss_waypoint_array.append(child)
	
	if boss_npc:
		boss_npc.patrol_waypoints = boss_waypoint_array
		boss_npc.connect("player_spotted", _on_player_spotted)
		boss_npc.connect("detection_progress_changed", _on_detection_progress_changed)
		npc_manager.register_npc(boss_npc)
		print("Boss NPC initialized with ", boss_waypoint_array.size(), " waypoints at position ", boss_npc.global_position)
	else:
		print("ERROR: Boss NPC not found!")
	
	# Set up Admin Officer NPC waypoints
	var admin_waypoint_array: Array[Node3D] = []
	if admin_waypoints:
		for child in admin_waypoints.get_children():
			if child is Marker3D:
				admin_waypoint_array.append(child)
	
	if admin_npc:
		admin_npc.patrol_waypoints = admin_waypoint_array
		admin_npc.connect("player_spotted", _on_player_spotted)
		admin_npc.connect("detection_progress_changed", _on_detection_progress_changed)
		npc_manager.register_npc(admin_npc)
		print("Admin NPC initialized with ", admin_waypoint_array.size(), " waypoints at position ", admin_npc.global_position)
	else:
		print("ERROR: Admin NPC not found!")
	
	# Set up Angry Coworker NPC waypoints
	var coworker_waypoint_array: Array[Node3D] = []
	if coworker_waypoints:
		for child in coworker_waypoints.get_children():
			if child is Marker3D:
				coworker_waypoint_array.append(child)
	
	if coworker_npc:
		coworker_npc.patrol_waypoints = coworker_waypoint_array
		coworker_npc.connect("player_spotted", _on_player_spotted)
		coworker_npc.connect("detection_progress_changed", _on_detection_progress_changed)
		npc_manager.register_npc(coworker_npc)
		print("Coworker NPC initialized with ", coworker_waypoint_array.size(), " waypoints at position ", coworker_npc.global_position)
	else:
		print("ERROR: Coworker NPC not found!")
	
	# Objectives are automatically initialized by ObjectiveManager
	
	# Connect timer for game start
	$GameStart/Timer.timeout.connect(_on_game_start_timer_timeout)
	
	# Set up performance monitor
	if performance_monitor:
		performance_monitor.set_position_preset("bottom_right")
	
	# Create advanced performance monitor
	advanced_performance_monitor = preload("res://ui/advanced_performance_monitor.tscn").instantiate()
	add_child(advanced_performance_monitor)
	advanced_performance_monitor.position = Vector2(50, 50)
	
	# Set up imported Blender level
	_setup_imported_level()

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
		elif event.keycode == KEY_TAB:
			# Toggle camera view
			if camera_rig:
				camera_rig.toggle_camera_view()

func _on_game_start_timer_timeout() -> void:
	# Reset all NPC systems before starting
	if npc_manager:
		npc_manager.reset_all_systems()
	
	GameManager.start_game()
	print("Game: NPCs reset and game started")

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

func _setup_imported_level() -> void:
	print("Game: Setting up imported Blender level...")
	
	# Create temporary floor first to prevent falling
	var temp_floor = preload("res://scripts/temporary_floor.gd").new()
	temp_floor.name = "TemporaryFloor"
	add_child(temp_floor)
	
	# First analyze the floor to get playable area
	if floor_node:
		print("Game: Analyzing floor model for playable area...")
		playable_area_analyzer = PlayableAreaAnalyzer.new()
		add_child(playable_area_analyzer)
		playable_area_analyzer.connect("analysis_complete", _on_playable_area_analyzed)
		var bounds = playable_area_analyzer.analyze_floor_model(floor_node)
		
		# Add collision to floor
		print("Game: Adding collision to floor...")
		var floor_helper = LevelSetupHelper.new()
		add_child(floor_helper)
		floor_helper.setup_imported_level(floor_node)
		
		# Reposition game elements based on floor bounds
		if bounds.size != Vector2.ZERO:
			_reposition_game_elements(bounds)
	
	# Create LevelSetupHelper instance
	level_setup_helper = LevelSetupHelper.new()
	add_child(level_setup_helper)
	
	# Connect completion signal
	level_setup_helper.connect("level_setup_complete", _on_level_setup_complete)
	
	# Run setup on the imported walls
	if walls_node:
		level_setup_helper.setup_imported_level(walls_node)
	else:
		print("Game: Warning - walls node not found!")
	
	# Apply color scheme to imported models
	print("Game: Applying color scheme...")
	MaterialApplier.apply_materials_to_level(walls_node, floor_node)
	
	# Apply colors to game objects
	if player:
		MaterialApplier.apply_player_material(player)
	
	if security_guard:
		MaterialApplier.apply_npc_material(security_guard)
	
	if security_guard2:
		MaterialApplier.apply_npc_material(security_guard2)
	
	if biscuit_jar:
		MaterialApplier.apply_jar_material(biscuit_jar)

func _on_level_setup_complete() -> void:
	print("Game: Level setup completed!")
	if level_setup_helper:
		level_setup_helper.print_level_analysis()
		
		# If no floors were detected, force collision on all meshes
		if level_setup_helper.floor_nodes.is_empty() and walls_node:
			print("Game: WARNING - No floors detected! Adding collision to ALL wall meshes...")
			level_setup_helper.add_collision_to_all_meshes(walls_node)
		
		print("Game: Remember to bake the navigation mesh in the editor!")

func _on_playable_area_analyzed(bounds: Rect2) -> void:
	print("Game: Playable area analyzed successfully")
	print("  Bounds: ", bounds)

func _reposition_game_elements(bounds: Rect2) -> void:
	print("Game: Repositioning game elements within playable area...")
	
	if not playable_area_analyzer:
		return
	
	# Keep player at their starting position (in elevator)
	# Don't reposition the player automatically
	
	# Generate new patrol waypoints within playable area
	if security_guard and playable_area_analyzer:
		var new_waypoints = playable_area_analyzer.generate_patrol_waypoints(6, 2.0)
		
		# Clear old waypoints
		if patrol_waypoints:
			for child in patrol_waypoints.get_children():
				child.queue_free()
		
		# Create new waypoints
		var waypoint_array: Array[Node3D] = []
		for i in range(new_waypoints.size()):
			var marker = Marker3D.new()
			marker.name = "Waypoint" + str(i + 1)
			marker.global_position = new_waypoints[i]
			patrol_waypoints.add_child(marker)
			waypoint_array.append(marker)
		
		# Update guard position and waypoints
		security_guard.global_position = new_waypoints[0] if new_waypoints.size() > 0 else player.global_position
		security_guard.patrol_waypoints = waypoint_array
		print("  Guard positioned with ", waypoint_array.size(), " waypoints")
	
	# Keep biscuit jar at its original position - don't reposition automatically
	# The jar position should be set manually in the scene
	print("  Biscuit jar staying at original position: ", biscuit_jar.global_position if biscuit_jar else "not found")
	
	# Update navigation region to cover playable area
	if has_node("NavigationRegion3D"):
		var nav_region = $NavigationRegion3D
		var center = bounds.get_center()
		nav_region.global_position = Vector3(center.x, 0, center.y)
		
		# Update navigation mesh size
		if nav_region.navigation_mesh:
			var vertices = PackedVector3Array()
			vertices.append(Vector3(bounds.position.x - center.x, 0.5, bounds.position.y - center.y))
			vertices.append(Vector3(bounds.position.x - center.x, 0.5, bounds.end.y - center.y))
			vertices.append(Vector3(bounds.end.x - center.x, 0.5, bounds.end.y - center.y))
			vertices.append(Vector3(bounds.end.x - center.x, 0.5, bounds.position.y - center.y))
			nav_region.navigation_mesh.vertices = vertices
			nav_region.navigation_mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
