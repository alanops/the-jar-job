extends Node
class_name NPCVisionComponent

# Component for handling NPC vision detection
# Separates vision logic from main NPC controller

signal player_detected(detected: bool)
signal detection_progress_changed(progress: float)

var npc_controller: NPCController
var player_reference: PlayerController
var flashlight: SpotLight3D

# Detection state
var detection_time: float = 0.0
var detection_threshold: float = 0.5
var player_in_sight: bool = false
var previous_player_in_sight: bool = false

# Peripheral vision
var peripheral_reaction_timer: float = 0.0
var peripheral_reaction_duration: float = 0.8
var is_reacting_to_peripheral: bool = false

# Performance optimization
var vision_check_timer: float = 0.0
var distance_to_player: float = 0.0

func _ready() -> void:
	npc_controller = get_parent() as NPCController
	if not npc_controller:
		DebugLogger.error("NPCVisionComponent must be child of NPCController", "NPCVisionComponent")
		return
	
	detection_threshold = GameConfig.npc_detection_threshold
	
	# Connect to vision detection system
	var vision_system = get_node_or_null("/root/VisionSystem")
	if vision_system and vision_system.has_signal("detection_completed"):
		vision_system.detection_completed.connect(_on_detection_completed)

func initialize(npc: NPCController, player: PlayerController, light: SpotLight3D) -> void:
	npc_controller = npc
	player_reference = player
	flashlight = light
	
	DebugLogger.info("Vision component initialized", "NPCVisionComponent")

func _process(delta: float) -> void:
	if not npc_controller or not player_reference:
		return
	
	# Handle peripheral vision reaction timer
	if is_reacting_to_peripheral:
		peripheral_reaction_timer += delta
		if peripheral_reaction_timer >= peripheral_reaction_duration:
			is_reacting_to_peripheral = false
			DebugLogger.debug("Peripheral reaction ended", "NPCVisionComponent")

func check_vision() -> void:
	if not player_reference or not flashlight or not npc_controller:
		_reset_detection()
		return
	
	# Skip vision checking if game is over to prevent stuck states
	if GameManager.current_state == GameManager.GameState.GAME_OVER:
		_reset_detection()
		return
	
	distance_to_player = npc_controller.global_position.distance_to(player_reference.global_position)
	
	# Use optimized vision detection system
	var detection_type = _get_detection_type()
	var vision_system = get_node_or_null("/root/VisionSystem")
	if vision_system and vision_system.has_method("check_player_visibility"):
		vision_system.check_player_visibility(npc_controller, player_reference, detection_type)

func _get_detection_type() -> String:
	var npc_pos = npc_controller.global_position
	var player_pos = player_reference.global_position
	var to_player = player_pos - npc_pos
	var npc_forward = npc_controller.global_transform.basis.z
	var angle_to_player = rad_to_deg(npc_forward.angle_to(to_player.normalized()))
	
	# Determine detection type based on distance and angle
	if distance_to_player < GameConfig.npc_close_detection_range:
		return "close"
	elif distance_to_player < GameConfig.npc_peripheral_vision_range and angle_to_player < GameConfig.npc_peripheral_vision_angle:
		return "peripheral"
	else:
		return "flashlight"

func _on_detection_completed(npc: Node, detected: bool) -> void:
	if npc != npc_controller:
		return
	
	player_in_sight = detected
	
	# Emit vision change signal if state changed
	if player_in_sight != previous_player_in_sight:
		player_detected.emit(player_in_sight)
		previous_player_in_sight = player_in_sight
	
	if detected:
		detection_time += get_process_delta_time()
		detection_progress_changed.emit(detection_time / detection_threshold)
		
		if detection_time >= detection_threshold:
			_on_player_spotted()
	else:
		_reset_detection()

func _on_player_spotted() -> void:
	DebugLogger.info("Player spotted by %s" % npc_controller.name, "NPCVisionComponent")
	npc_controller._on_player_spotted()

func _reset_detection() -> void:
	if detection_time > 0.0:
		detection_time = 0.0
		detection_progress_changed.emit(0.0)
	
	# Reset peripheral reaction state when detection is lost
	is_reacting_to_peripheral = false
	peripheral_reaction_timer = 0.0

func turn_towards_player(player_pos: Vector3) -> void:
	"""Smoothly turn NPC towards player when spotted in peripheral vision"""
	if not is_reacting_to_peripheral:
		is_reacting_to_peripheral = true
		peripheral_reaction_timer = 0.0
		DebugLogger.debug("Peripheral vision: Starting to turn towards player", "NPCVisionComponent")
	
	var to_player = (player_pos - npc_controller.global_position).normalized()
	var target_angle = atan2(to_player.x, to_player.z)
	
	# Use a fast turn speed for peripheral vision reactions
	var turn_delta = get_process_delta_time()
	var fast_turn_speed = GameConfig.npc_turn_speed * 2.5
	
	npc_controller.rotation.y = lerp_angle(npc_controller.rotation.y, target_angle, fast_turn_speed * turn_delta)

func is_player_detected() -> bool:
	return player_in_sight

func get_detection_progress() -> float:
	return detection_time / detection_threshold if detection_threshold > 0 else 0.0

func reset_state() -> void:
	detection_time = 0.0
	player_in_sight = false
	previous_player_in_sight = false
	is_reacting_to_peripheral = false
	peripheral_reaction_timer = 0.0
	
	DebugLogger.debug("Vision component state reset", "NPCVisionComponent")