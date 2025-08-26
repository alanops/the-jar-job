extends Control

@onready var arrow: Label = $Arrow
@onready var distance_label: Label = $Distance
@onready var objective_label: Label = $ObjectiveTitle

var player: Node3D
var objective_manager: Node
var current_target: Vector3
var current_objective

@export var edge_margin: float = 50.0
@export var center_hide_distance: float = 5.0

func _ready() -> void:
	# Find player
	player = get_tree().get_first_node_in_group("player")
	
	# Get objective manager
	objective_manager = get_node("/root/ObjectiveManager")
	if objective_manager:
		objective_manager.objective_updated.connect(_on_objective_updated)
		objective_manager.objective_completed.connect(_on_objective_completed)
	
	# Initially hide
	visible = false

func _process(_delta: float) -> void:
	if not player or not current_objective:
		visible = false
		return
	
	current_target = current_objective.target_position
	if current_target == Vector3.ZERO:
		visible = false
		return
	
	var distance = player.global_position.distance_to(current_target)
	
	# Hide if very close to target
	if distance < center_hide_distance:
		visible = false
		return
	
	visible = true
	
	# Update distance display
	if distance_label:
		distance_label.text = "%.1fm" % distance
	
	# Update objective title
	if objective_label:
		objective_label.text = current_objective.title
	
	# Get direction to target
	var direction_3d = (current_target - player.global_position).normalized()
	var direction_2d = Vector2(direction_3d.x, direction_3d.z)
	
	# Get camera forward direction for screen space calculation
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	
	# Project to screen space
	var screen_pos = camera.unproject_position(current_target)
	var screen_center = get_viewport().get_visible_rect().size / 2
	var to_target = (screen_pos - screen_center)
	
	# Check if target is on screen
	var viewport_rect = get_viewport().get_visible_rect()
	var is_on_screen = (screen_pos.x >= 0 and screen_pos.x <= viewport_rect.size.x and
					   screen_pos.y >= 0 and screen_pos.y <= viewport_rect.size.y)
	
	var final_pos: Vector2
	var arrow_rotation: float
	
	if is_on_screen:
		# Target is on screen - position near target
		final_pos = screen_pos
		arrow_rotation = to_target.angle() + PI/2
	else:
		# Target is off screen - clamp to screen edge
		var normalized_direction = to_target.normalized()
		var screen_edge = screen_center + normalized_direction * (min(screen_center.x, screen_center.y) - edge_margin)
		
		final_pos = screen_edge
		arrow_rotation = to_target.angle() + PI/2
	
	# Apply position and rotation
	position = final_pos - size / 2
	if arrow:
		arrow.rotation = arrow_rotation

func _on_objective_updated(objective) -> void:
	current_objective = objective
	if objective and objective.target_node:
		current_target = objective.target_node.global_position
	elif objective:
		current_target = objective.target_position

func _on_objective_completed(objective) -> void:
	if current_objective and objective.id == current_objective.id:
		current_objective = null
		visible = false