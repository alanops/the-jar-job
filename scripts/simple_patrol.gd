extends Node3D
class_name SimplePatrol

# Simple patrol script for NPCs when navigation mesh is not available
@export var patrol_speed: float = 2.0
@export var wait_time: float = 2.0
@export var patrol_points: Array[Vector3] = []

var current_point_index: int = 0
var is_waiting: bool = false
var wait_timer: float = 0.0
var npc_body: CharacterBody3D

func _ready():
	# Get the CharacterBody3D parent
	if get_parent() is CharacterBody3D:
		npc_body = get_parent() as CharacterBody3D
		
		# Set up default patrol points around the imported level if none specified
		if patrol_points.is_empty():
			patrol_points = [
				Vector3(2.71735, 0, -2.904),
				Vector3(5.71735, 0, -2.904),
				Vector3(5.71735, 0, 0.096),
				Vector3(5.71735, 0, 1.096),
				Vector3(2.71735, 0, 1.096),
				Vector3(2.71735, 0, 0.096)
			]
		
		print("SimplePatrol: Starting patrol with ", patrol_points.size(), " waypoints")

func _physics_process(delta: float) -> void:
	if not npc_body or patrol_points.is_empty():
		return
		
	if is_waiting:
		wait_timer -= delta
		if wait_timer <= 0:
			is_waiting = false
			current_point_index = (current_point_index + 1) % patrol_points.size()
			print("SimplePatrol: Moving to waypoint ", current_point_index)
		return
	
	# Get target position
	var target_pos = patrol_points[current_point_index]
	target_pos.y = npc_body.global_position.y  # Keep same Y level
	
	var direction = (target_pos - npc_body.global_position).normalized()
	var distance = npc_body.global_position.distance_to(target_pos)
	
	# Check if reached waypoint
	if distance < 0.5:
		is_waiting = true
		wait_timer = wait_time
		print("SimplePatrol: Reached waypoint ", current_point_index, ", waiting...")
		npc_body.velocity = Vector3.ZERO
	else:
		# Move towards waypoint
		npc_body.velocity = direction * patrol_speed
		npc_body.velocity.y = -9.8  # Gravity
		
		# Rotate to face movement direction
		if direction.length() > 0.1:
			npc_body.look_at(npc_body.global_position + direction, Vector3.UP)
	
	npc_body.move_and_slide()