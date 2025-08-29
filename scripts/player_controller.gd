extends CharacterBody3D

class_name PlayerController

# Movement speeds - loaded from GameConfig
var walk_speed: float
var run_speed: float
var crouch_speed: float
var crouch_height: float
var normal_height: float

# Noise radii - loaded from GameConfig
var noise_radius_walk: float
var noise_radius_run: float
var noise_radius_crouch: float

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var interaction_area: Area3D = $InteractionArea
@onready var footstep_timer: Timer = $FootstepTimer

var is_crouching: bool = false
var is_running: bool = false
var current_speed: float
var current_noise_radius: float = noise_radius_walk
var interactable_object: Node3D = null
var game_ui: Control
var camera_rig: Node3D

signal made_noise(position: Vector3, radius: float)

func _ready() -> void:
	_load_config_values()
	_initialize_collision_shape()
	_connect_signals()
	_initialize_components()

func _load_config_values() -> void:
	walk_speed = GameConfig.player_walk_speed
	run_speed = GameConfig.player_run_speed
	crouch_speed = GameConfig.player_crouch_speed
	crouch_height = GameConfig.player_crouch_height
	normal_height = GameConfig.player_normal_height
	
	noise_radius_walk = GameConfig.noise_radius_walk
	noise_radius_run = GameConfig.noise_radius_run
	noise_radius_crouch = GameConfig.noise_radius_crouch
	
	current_speed = walk_speed
	current_noise_radius = noise_radius_walk
	
	DebugLogger.info("Player config loaded", "PlayerController")

func _initialize_collision_shape() -> void:
	if not collision_shape:
		DebugLogger.error("CollisionShape3D not found!", "PlayerController")
		return
	
	collision_shape.shape = collision_shape.shape.duplicate()

func _connect_signals() -> void:
	if not interaction_area:
		DebugLogger.error("InteractionArea not found!", "PlayerController")
		return
	
	if not interaction_area.body_entered.is_connected(_on_interaction_area_entered):
		interaction_area.body_entered.connect(_on_interaction_area_entered)
	if not interaction_area.body_exited.is_connected(_on_interaction_area_exited):
		interaction_area.body_exited.connect(_on_interaction_area_exited)
	if not interaction_area.area_entered.is_connected(_on_interaction_area_area_entered):
		interaction_area.area_entered.connect(_on_interaction_area_area_entered)
	if not interaction_area.area_exited.is_connected(_on_interaction_area_area_exited):
		interaction_area.area_exited.connect(_on_interaction_area_area_exited)
	
	if footstep_timer and not footstep_timer.timeout.is_connected(_on_footstep):
		footstep_timer.timeout.connect(_on_footstep)
	
	if GameManager and not GameManager.game_started.is_connected(_on_game_started):
		GameManager.game_started.connect(_on_game_started)

func _initialize_components() -> void:
	
	# Find the game UI and camera rig
	await get_tree().process_frame
	var game_ui_nodes = get_tree().get_nodes_in_group("game_ui")
	if game_ui_nodes.size() > 0:
		game_ui = game_ui_nodes[0]
	else:
		# Try to find it by path
		var game_node = get_tree().get_first_node_in_group("game")
		if game_node:
			game_ui = game_node.get_node("GameUI")
			camera_rig = game_node.get_node("CameraRig")

func _on_game_started() -> void:
	is_crouching = false
	_update_crouch_state()

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	# Handle crouching
	if Input.is_action_pressed("crouch"):
		if not is_crouching:
			_start_crouch()
	else:
		if is_crouching:
			_stop_crouch()
	
	# Handle running (only when not crouching)
	if not is_crouching:
		if Input.is_action_pressed("run"):
			if not is_running:
				_start_running()
		else:
			if is_running:
				_stop_running()
	
	# Get input direction based on camera mode
	var direction := Vector3()
	var is_first_person = false
	
	# Check if we're in first person mode
	if camera_rig and camera_rig.has_method("get_current_camera_view"):
		is_first_person = camera_rig.get_current_camera_view() == 2
	
	if is_first_person:
		# Pure FPS controls using WASD
		var input_vector := Vector2()
		
		# Get FPS input using WASD
		if Input.is_action_pressed("fps_forward"):
			input_vector.y += 1.0
		if Input.is_action_pressed("fps_backward"):
			input_vector.y -= 1.0
		if Input.is_action_pressed("fps_strafe_left"):
			input_vector.x -= 1.0
		if Input.is_action_pressed("fps_strafe_right"):
			input_vector.x += 1.0
		
		input_vector = input_vector.normalized()
		
		if input_vector.length() > 0:
			# Get camera yaw for FPS movement
			var camera_yaw = 0.0
			if camera_rig.has_method("get_camera_yaw"):
				camera_yaw = camera_rig.get_camera_yaw()
			
			# Convert to radians and calculate direction vectors
			var yaw_rad = deg_to_rad(camera_yaw)
			var forward = Vector3(-sin(yaw_rad), 0, -cos(yaw_rad))  # Negative because camera looks down -Z
			var right = Vector3(cos(yaw_rad), 0, -sin(yaw_rad))
			
			# Apply input to movement
			direction = forward * input_vector.y + right * input_vector.x
	else:
		# Top-down/isometric controls using arrow keys
		var input_dir := Vector2()
		
		# Get arrow key input
		if Input.is_action_pressed("move_forward"):
			input_dir.y += 1.0
		if Input.is_action_pressed("move_backward"):
			input_dir.y -= 1.0
		if Input.is_action_pressed("move_left"):
			input_dir.x -= 1.0
		if Input.is_action_pressed("move_right"):
			input_dir.x += 1.0
		
		input_dir = input_dir.normalized()
		
		if input_dir.length() > 0 and camera_rig:
			var active_camera = null
			if camera_rig.has_method("get_active_camera"):
				active_camera = camera_rig.get_active_camera()
			
			if active_camera:
				# Use camera's transform to get proper direction vectors
				var cam_transform = active_camera.global_transform
				var forward = -cam_transform.basis.z  # Camera forward (negative z)
				var right = cam_transform.basis.x     # Camera right
				
				# Project onto horizontal plane for movement
				forward.y = 0
				right.y = 0
				forward = forward.normalized()
				right = right.normalized()
				
				# Combine input with camera-relative directions
				direction = forward * input_dir.y + right * input_dir.x
			else:
				# Fallback: simple world-space movement
				direction.x = input_dir.x
				direction.z = -input_dir.y
		elif input_dir.length() > 0:
			# Fallback to default movement if camera_rig not found
			direction.x = input_dir.x
			direction.z = -input_dir.y
	
	if direction.length() > 0:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		
		# Start footstep timer if not running
		if footstep_timer.is_stopped():
			footstep_timer.start()
			_on_footstep()
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed * delta * 3)
		velocity.z = move_toward(velocity.z, 0, current_speed * delta * 3)
		footstep_timer.stop()
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0
	
	move_and_slide()
	
	# Handle interaction
	if Input.is_action_just_pressed("interact") and interactable_object:
		_interact_with_object()

func _start_crouch() -> void:
	is_crouching = true
	current_speed = crouch_speed
	current_noise_radius = noise_radius_crouch
	if footstep_timer:
		footstep_timer.wait_time = 0.8
	_update_crouch_state()
	DebugLogger.debug("Started crouching", "PlayerController")

func _stop_crouch() -> void:
	is_crouching = false
	is_running = false  # Stop running when starting to crouch
	current_speed = walk_speed
	current_noise_radius = noise_radius_walk
	if footstep_timer:
		footstep_timer.wait_time = 0.5
	_update_crouch_state()
	DebugLogger.debug("Stopped crouching", "PlayerController")

func _start_running() -> void:
	if is_crouching:
		return  # Can't run while crouching
	is_running = true
	current_speed = run_speed
	current_noise_radius = noise_radius_run
	if footstep_timer:
		footstep_timer.wait_time = 0.3  # Faster footsteps when running
	DebugLogger.debug("Started running", "PlayerController")

func _stop_running() -> void:
	is_running = false
	current_speed = walk_speed
	current_noise_radius = noise_radius_walk
	if footstep_timer:
		footstep_timer.wait_time = 0.5
	DebugLogger.debug("Stopped running", "PlayerController")

func _update_crouch_state() -> void:
	if not collision_shape or not collision_shape.shape:
		DebugLogger.error("Invalid collision shape for crouch update", "PlayerController")
		return
	
	var shape: CapsuleShape3D = collision_shape.shape as CapsuleShape3D
	if not shape:
		DebugLogger.error("Collision shape is not a CapsuleShape3D", "PlayerController")
		return
	
	if is_crouching:
		shape.height = crouch_height
		collision_shape.position.y = crouch_height / 2
		if mesh_instance:
			mesh_instance.scale.y = 0.5
	else:
		shape.height = normal_height
		collision_shape.position.y = normal_height / 2
		if mesh_instance:
			mesh_instance.scale.y = 1.0

func _on_footstep() -> void:
	if velocity.length() > 0.1:
		made_noise.emit(global_position, current_noise_radius)
		
		# Play footstep sound with volume based on movement type
		if AudioManager:
			var volume_modifier = 1.0
			if is_crouching:
				volume_modifier = 0.3  # Quieter when crouching
			elif is_running:
				volume_modifier = 1.2  # Louder when running
			
			# Vary the pitch slightly for more natural footsteps
			var pitch_variation = randf_range(0.9, 1.1)
			AudioManager.play_footstep()  # We'll add pitch variation later

func _on_interaction_area_entered(body: Node3D) -> void:
	DebugLogger.debug("Body entered: %s Groups: %s" % [body.name, str(body.get_groups())], "PlayerController")
	if body.is_in_group("interactables"):
		interactable_object = body
		DebugLogger.debug("Set interactable object: %s" % body.name, "PlayerController")
		# Show interaction prompt in UI
		if game_ui and game_ui.has_method("show_interaction_prompt"):
			game_ui.show_interaction_prompt(true)

func _on_interaction_area_exited(body: Node3D) -> void:
	if body == interactable_object:
		interactable_object = null
		# Hide interaction prompt
		if game_ui and game_ui.has_method("show_interaction_prompt"):
			game_ui.show_interaction_prompt(false)

func _on_interaction_area_area_entered(area: Area3D) -> void:
	var parent_name = area.get_parent().name if area.get_parent() else "None"
	DebugLogger.debug("Area entered: %s Parent: %s" % [area.name, parent_name], "PlayerController")
	var parent := area.get_parent()
	if parent and parent.is_in_group("interactables"):
		interactable_object = parent
		DebugLogger.debug("Set interactable object from area: %s" % parent.name, "PlayerController")
		# Show interaction prompt
		if game_ui and game_ui.has_method("show_interaction_prompt"):
			game_ui.show_interaction_prompt(true)

func _on_interaction_area_area_exited(area: Area3D) -> void:
	var parent := area.get_parent()
	if parent == interactable_object:
		interactable_object = null
		# Hide interaction prompt
		if game_ui and game_ui.has_method("show_interaction_prompt"):
			game_ui.show_interaction_prompt(false)

func _interact_with_object() -> void:
	var obj_name = interactable_object.name if interactable_object else "null"
	DebugLogger.debug("Attempting to interact with: %s" % obj_name, "PlayerController")
	if not interactable_object:
		DebugLogger.warning("No interactable object!", "PlayerController")
		return
	
	DebugLogger.info("Interacting with: %s Groups: %s" % [interactable_object.name, str(interactable_object.get_groups())], "PlayerController")
	if interactable_object.is_in_group("biscuit_jar"):
		DebugLogger.info("Collecting biscuit jar!", "PlayerController")
		GameManager.collect_jar()
		interactable_object.queue_free()
		interactable_object = null
	elif interactable_object.is_in_group("exit_door") and GameManager.has_jar:
		DebugLogger.info("Using exit door!", "PlayerController")
		GameManager.trigger_victory()
	else:
		DebugLogger.warning("Object not recognized for interaction: %s" % interactable_object.name, "PlayerController")

func get_noise_position() -> Vector3:
	return global_position