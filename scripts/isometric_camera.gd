extends Node3D

class_name IsometricCamera

@export var follow_speed: float = 5.0
@export var camera_distance: float = 15.0
@export var camera_height: float = 15.0
@export var fade_distance: float = 2.0
@export var fade_alpha: float = 0.3

# Camera view settings
var current_camera_view: int = 0  # 0 = top-down, 1 = isometric, 2 = first person
var camera_views: Array[Dictionary] = [
	{
		"name": "Top Down",
		"yaw": 0,
		"pitch": -90,
		"height": 20,
		"distance": 0.1,
		"size": 20.0,
		"is_first_person": false
	},
	{
		"name": "Isometric",
		"yaw": -45,
		"pitch": -30,
		"height": 12,
		"distance": 14,
		"size": 16.0,
		"offset": Vector3(-5, 0, -5),
		"is_first_person": false
	},
	{
		"name": "First Person",
		"yaw": 0,
		"pitch": 0,
		"height": 1.6,
		"distance": 0.1,
		"fov": 75,
		"is_first_person": true
	}
]

@onready var camera: Camera3D = $Camera3D
@onready var fade_raycast: RayCast3D = $FadeRaycast

var target: Node3D
var faded_objects: Dictionary = {}

func _ready() -> void:
	# Set up initial camera view
	_apply_camera_view(current_camera_view)
	
	# Set up fade raycast
	fade_raycast.target_position = Vector3(0, -20, -20)
	fade_raycast.collision_mask = 1  # Only check world layer

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
