extends Node3D

# Distance-based light culling for performance optimization
# Hides elevator light when player is far away to save on shadow rendering

@export var cull_distance: float = 25.0  # Distance at which to hide the light
@export var light_node_path: String = "ElevatorWarmLight2"

var player_reference: PlayerController
var elevator_light: OmniLight3D
var distance_check_timer: float = 0.0
var distance_check_interval: float = 0.5  # Check distance every 0.5 seconds

func _ready() -> void:
	# Find the elevator light
	elevator_light = get_node_or_null(light_node_path)
	if not elevator_light:
		DebugLogger.error("Elevator light not found at path: " + light_node_path, "ElevatorLightCulling")
		return
	
	# Find the player
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_reference = players[0]
	else:
		DebugLogger.warning("Player not found for elevator light culling", "ElevatorLightCulling")

func _process(delta: float) -> void:
	if not player_reference or not elevator_light:
		return
	
	# Only check distance periodically for performance
	distance_check_timer += delta
	if distance_check_timer >= distance_check_interval:
		distance_check_timer = 0.0
		_update_light_visibility()

func _update_light_visibility() -> void:
	# Calculate 2D distance (top-down view)
	var elevator_pos_2d = Vector2(global_position.x, global_position.z)
	var player_pos_2d = Vector2(player_reference.global_position.x, player_reference.global_position.z)
	var distance_2d = elevator_pos_2d.distance_to(player_pos_2d)
	
	# Show/hide light based on distance
	var should_be_visible = distance_2d <= cull_distance
	
	if elevator_light.visible != should_be_visible:
		elevator_light.visible = should_be_visible
		if should_be_visible:
			DebugLogger.info("Elevator light enabled - player within range (" + str(distance_2d) + "m)", "ElevatorLightCulling")
		else:
			DebugLogger.info("Elevator light disabled - player too far (" + str(distance_2d) + "m)", "ElevatorLightCulling")

func set_cull_distance(new_distance: float) -> void:
	cull_distance = new_distance
	DebugLogger.info("Elevator light cull distance set to: " + str(cull_distance), "ElevatorLightCulling")