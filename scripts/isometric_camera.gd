extends Node3D

class_name IsometricCamera

@export var follow_speed: float = 5.0
@export var camera_distance: float = 15.0
@export var camera_height: float = 15.0
@export var fade_distance: float = 2.0
@export var fade_alpha: float = 0.3

@export_group("Top Down Camera")
@export var topdown_yaw: float = 0.0
@export var topdown_pitch: float = -90.0
@export var topdown_height: float = 20.0
@export var topdown_distance: float = 0.1
@export var topdown_size: float = 20.0

@export_group("Isometric Camera")
@export var iso_yaw: float = -45.0
@export var iso_pitch: float = -30.0
@export var iso_height: float = 12.0
@export var iso_distance: float = 14.0
@export var iso_size: float = 16.0
@export var iso_offset: Vector3 = Vector3(5, 0, 5)

@export_group("First Person Camera")
@export var fps_height: float = 1.6
@export var fps_fov: float = 75.0

# Camera view settings
var current_camera_view: int = 0  # 0 = top-down, 1 = isometric, 2 = first person
var camera_views: Array[Dictionary] = []

@onready var camera: Camera3D = $Camera3D
@onready var fade_raycast: RayCast3D = $FadeRaycast

var target: Node3D
var faded_objects: Dictionary = {}

func _ready() -> void:
	# Build camera views from export variables
	_build_camera_views()
	
	# Set up initial camera view
	_apply_camera_view(current_camera_view)
	
	# Set up fade raycast
	fade_raycast.target_position = Vector3(0, -20, -20)
	fade_raycast.collision_mask = 1  # Only check world layer

func _build_camera_views() -> void:
	# Build camera view configurations from export variables
	camera_views = [
		{
			"name": "Top Down",
			"yaw": topdown_yaw,
			"pitch": topdown_pitch,
			"height": topdown_height,
			"distance": topdown_distance,
			"size": topdown_size,
			"is_first_person": false
		},
		{
			"name": "Isometric",
			"yaw": iso_yaw,
			"pitch": iso_pitch,
			"height": iso_height,
			"distance": iso_distance,
			"size": iso_size,
			"offset": iso_offset,
			"is_first_person": false
		},
		{
			"name": "First Person",
			"yaw": 0,
			"pitch": 0,
			"height": fps_height,
			"distance": 0.1,
			"fov": fps_fov,
			"is_first_person": true
		}
	]

func set_target(new_target: Node3D) -> void:
	target = new_target

func _apply_camera_view(view_index: int) -> void:
	var view = camera_views[view_index]
	
	if view.is_first_person:
		# First person mode
		rotation.y = 0  # Follow player rotation
		rotation.x = 0
		
		# Position camera at eye level
		camera.position = Vector3(0, view.height, 0)
		camera.rotation = Vector3(0, 0, 0)
		
		# Set perspective projection for first person
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = view.fov
		
		# Adjust near plane for first person
		camera.near = 0.01
		camera.far = 100.0
	else:
		# Top-down or isometric mode
		# Set rotation
		rotation.y = deg_to_rad(view.yaw)
		rotation.x = deg_to_rad(view.pitch)
		
		# Position camera with optional offset
		var cam_pos = Vector3(0, view.height, view.distance)
		if view.has("offset"):
			# Apply offset to better center camera over player
			var offset = view.offset
			# Rotate offset by camera yaw to maintain correct positioning
			var rotated_offset = offset.rotated(Vector3.UP, deg_to_rad(view.yaw))
			cam_pos += rotated_offset
		
		camera.position = cam_pos
		camera.look_at(Vector3.ZERO, Vector3.UP)
		
		# Set orthogonal projection
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = view.size
		
		# Enable culling optimizations
		camera.cull_mask = 0xFFFFF  # See all layers
		camera.near = 0.1
		camera.far = 100.0  # Reduce far plane for better culling
	
	print("Camera switched to: ", view.name)

func toggle_camera_view() -> void:
	current_camera_view = (current_camera_view + 1) % camera_views.size()
	_apply_camera_view(current_camera_view)

func _physics_process(delta: float) -> void:
	if not target:
		return
	
	var view = camera_views[current_camera_view]
	
	if view.is_first_person:
		# First person mode - camera follows player exactly
		global_position = target.global_position
		
		# Match player rotation for first person view
		if target.has_method("get_rotation"):
			rotation.y = target.rotation.y
	else:
		# Smooth follow for top-down/isometric
		var target_pos := target.global_position
		global_position = global_position.lerp(target_pos, follow_speed * delta)
	
	# Wall fade system (only for non-first person views)
	if not view.is_first_person:
		_update_wall_fade()

func _update_wall_fade() -> void:
	if not target:
		return
	
	# Cast ray from camera to player
	fade_raycast.global_position = camera.global_position
	fade_raycast.target_position = target.global_position - camera.global_position
	fade_raycast.force_raycast_update()
	
	# Track which objects should be faded
	var current_faded: Dictionary = {}
	
	# Check all collisions along the ray
	while fade_raycast.is_colliding():
		var collider := fade_raycast.get_collider()
		
		if collider and collider.has_method("set_fade"):
			current_faded[collider] = true
			
			# Fade the object if it's not already faded
			if not collider in faded_objects:
				_fade_object(collider, true)
		
		# Move ray past this collision and check for more
		var collision_point := fade_raycast.get_collision_point()
		var remaining_distance := (target.global_position - collision_point).length()
		
		if remaining_distance < 0.1:
			break
		
		fade_raycast.global_position = collision_point + fade_raycast.target_position.normalized() * 0.1
		fade_raycast.target_position = target.global_position - fade_raycast.global_position
		fade_raycast.force_raycast_update()
	
	# Unfade objects that are no longer blocking
	for obj in faded_objects:
		if not obj in current_faded:
			_fade_object(obj, false)
	
	faded_objects = current_faded

func _fade_object(obj: Node3D, fade: bool) -> void:
	if obj.has_method("set_fade"):
		obj.set_fade(fade, fade_alpha)

func toggle_projection() -> void:
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 45
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 10.0

func zoom_in() -> void:
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.size = max(5.0, camera.size - 1.0)
	else:
		camera_distance = max(10.0, camera_distance - 2.0)
		camera.position.z = camera_distance

func zoom_out() -> void:
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.size = min(20.0, camera.size + 1.0)
	else:
		camera_distance = min(30.0, camera_distance + 2.0)
		camera.position.z = camera_distance
