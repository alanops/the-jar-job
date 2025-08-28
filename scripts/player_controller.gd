extends CharacterBody3D

class_name PlayerController

const WALK_SPEED := 5.0
const RUN_SPEED := 8.0
const CROUCH_SPEED := 2.0
const CROUCH_HEIGHT := 0.9
const NORMAL_HEIGHT := 1.8

@export var noise_radius_walk: float = 5.0
@export var noise_radius_run: float = 8.0
@export var noise_radius_crouch: float = 2.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var interaction_area: Area3D = $InteractionArea
@onready var footstep_timer: Timer = $FootstepTimer

var is_crouching: bool = false
var is_running: bool = false
var current_speed: float = WALK_SPEED
var current_noise_radius: float = noise_radius_walk
var interactable_object: Node3D = null
var game_ui: Control

signal made_noise(position: Vector3, radius: float)

func _ready() -> void:
	collision_shape.shape = collision_shape.shape.duplicate()
	
	interaction_area.body_entered.connect(_on_interaction_area_entered)
	interaction_area.body_exited.connect(_on_interaction_area_exited)
	# Also connect area signals for better detection
	interaction_area.area_entered.connect(_on_interaction_area_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_area_exited)
	
	footstep_timer.timeout.connect(_on_footstep)
	
	GameManager.game_started.connect(_on_game_started)
	
	# Find the game UI
	await get_tree().process_frame
	var game_ui_nodes = get_tree().get_nodes_in_group("game_ui")
	if game_ui_nodes.size() > 0:
		game_ui = game_ui_nodes[0]
	else:
		# Try to find it by path
		var game_node = get_tree().get_first_node_in_group("game")
		if game_node:
			game_ui = game_node.get_node("GameUI")

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
	
	# Get input direction - simple top-down controls
	var direction := Vector3()
	
	# Up arrow = move up on screen (negative X)
	if Input.is_action_pressed("move_forward"):
		direction.x -= 1.0
	
	# Down arrow = move down on screen (positive X)
	if Input.is_action_pressed("move_backward"):
		direction.x += 1.0
		
	# Left arrow = move left on screen (positive Z)
	if Input.is_action_pressed("move_left"):
		direction.z += 1.0
		
	# Right arrow = move right on screen (negative Z)
	if Input.is_action_pressed("move_right"):
		direction.z -= 1.0
		
	direction = direction.normalized()
	
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
	current_speed = CROUCH_SPEED
	current_noise_radius = noise_radius_crouch
	footstep_timer.wait_time = 0.8
	_update_crouch_state()

func _stop_crouch() -> void:
	is_crouching = false
	is_running = false  # Stop running when starting to crouch
	current_speed = WALK_SPEED
	current_noise_radius = noise_radius_walk
	footstep_timer.wait_time = 0.5
	_update_crouch_state()

func _start_running() -> void:
	if is_crouching:
		return  # Can't run while crouching
	is_running = true
	current_speed = RUN_SPEED
	current_noise_radius = noise_radius_run
	footstep_timer.wait_time = 0.3  # Faster footsteps when running

func _stop_running() -> void:
	is_running = false
	current_speed = WALK_SPEED
	current_noise_radius = noise_radius_walk  
	footstep_timer.wait_time = 0.5

func _update_crouch_state() -> void:
	var shape: CapsuleShape3D = collision_shape.shape as CapsuleShape3D
	if is_crouching:
		shape.height = CROUCH_HEIGHT
		collision_shape.position.y = CROUCH_HEIGHT / 2
		mesh_instance.scale.y = 0.5
	else:
		shape.height = NORMAL_HEIGHT
		collision_shape.position.y = NORMAL_HEIGHT / 2
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
	print("Body entered: ", body.name, " Groups: ", body.get_groups())
	if body.is_in_group("interactables"):
		interactable_object = body
		print("Set interactable object: ", body.name)
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
	print("Area entered: ", area.name, " Parent: ", area.get_parent().name if area.get_parent() else "None")
	var parent := area.get_parent()
	if parent and parent.is_in_group("interactables"):
		interactable_object = parent
		print("Set interactable object from area: ", parent.name)
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
	print("Attempting to interact with: ", interactable_object.name if interactable_object else "null")
	if not interactable_object:
		print("No interactable object!")
		return
	
	print("Interacting with: ", interactable_object.name, " Groups: ", interactable_object.get_groups())
	if interactable_object.is_in_group("biscuit_jar"):
		print("Collecting biscuit jar!")
		GameManager.collect_jar()
		interactable_object.queue_free()
		interactable_object = null
	elif interactable_object.is_in_group("exit_door") and GameManager.has_jar:
		print("Using exit door!")
		GameManager.trigger_victory()
	else:
		print("Object not recognized for interaction")

func get_noise_position() -> Vector3:
	return global_position