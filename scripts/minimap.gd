extends Control

@onready var minimap_camera: Camera3D = $ViewportContainer/Viewport/MinimapCamera
@onready var player_indicator: Control = $MapOverlay/PlayerIndicator
@onready var player_arrow: Label = $MapOverlay/PlayerIndicator/PlayerArrow
@onready var objective_markers: Control = $MapOverlay/ObjectiveMarkers

var player: Node3D
var objective_manager: Node
var marker_pool: Array[Control] = []
var active_markers: Dictionary = {}

@export var follow_height: float = 30.0
@export var map_size: float = 40.0
@export var marker_scale: float = 1.5

func _ready() -> void:
	# Find player
	player = get_tree().get_first_node_in_group("player")
	
	# Get objective manager
	objective_manager = get_node("/root/ObjectiveManager")
	if objective_manager:
		objective_manager.objective_updated.connect(_on_objective_updated)
		objective_manager.objective_completed.connect(_on_objective_completed)
	
	# Setup minimap camera
	if minimap_camera:
		minimap_camera.position.y = follow_height
		minimap_camera.rotation_degrees.x = -90
		minimap_camera.size = map_size
	
	# Create marker pool
	for i in range(5):
		var marker = create_objective_marker()
		marker.visible = false
		marker_pool.append(marker)

func _process(_delta: float) -> void:
	if not player or not minimap_camera:
		return
		
	# Update camera position to follow player
	minimap_camera.global_position = Vector3(
		player.global_position.x,
		follow_height,
		player.global_position.z
	)
	
	# Update player rotation indicator
	if player_arrow:
		var player_rotation = player.rotation.y
		player_arrow.rotation = player_rotation
	
	# Update objective markers
	update_objective_markers()

func create_objective_marker() -> Control:
	var marker = Label.new()
	marker.add_theme_font_size_override("font_size", 20)
	marker.add_theme_color_override("font_outline_color", Color.BLACK)
	marker.add_theme_constant_override("outline_size", 3)
	marker.set_anchors_preset(Control.PRESET_CENTER)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.size = Vector2(40, 40)
	marker.position = -marker.size / 2
	objective_markers.add_child(marker)
	return marker

func update_objective_markers() -> void:
	if not objective_manager or not player:
		return
	
	var objectives = objective_manager.get_active_objectives()
	var viewport_size = $ViewportContainer/Viewport.size
	
	for i in range(objectives.size()):
		if i >= marker_pool.size():
			break
			
		var objective = objectives[i]
		var marker = marker_pool[i]
		
		if not objective.target_position:
			marker.visible = false
			continue
		
		# Convert world position to minimap position
		var world_offset = objective.target_position - player.global_position
		var map_offset = Vector2(world_offset.x, world_offset.z) / map_size * viewport_size.x
		
		# Center the marker and apply offset
		var marker_pos = viewport_size / 2 + map_offset
		
		# Keep marker within bounds
		marker_pos = marker_pos.clamp(Vector2(20, 20), viewport_size - Vector2(20, 20))
		
		marker.position = marker_pos - marker.size / 2
		marker.text = objective.icon
		marker.visible = true
		marker.scale = Vector2.ONE * marker_scale
		
		# Store active marker reference
		active_markers[objective.id] = marker
	
	# Hide unused markers
	for i in range(objectives.size(), marker_pool.size()):
		marker_pool[i].visible = false

func _on_objective_updated(objective) -> void:
	# Refresh markers when objectives change
	update_objective_markers()

func _on_objective_completed(objective) -> void:
	# Remove completed objective marker
	if objective.id in active_markers:
		active_markers[objective.id].visible = false
		active_markers.erase(objective.id)