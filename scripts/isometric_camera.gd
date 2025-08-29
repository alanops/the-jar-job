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
@export var iso_offset: Vector3 = Vector3(0, 0, 0)

@export_group("First Person Camera")
@export var fps_height: float = 1.6
@export var fps_fov: float = 75.0

# Camera view settings
var current_camera_view: int = 0  # 0 = top-down, 1 = isometric, 2 = first person
var camera_views: Array[Dictionary] = []

# Mouse look variables
var mouse_sensitivity: float = 0.002
var pitch_limit: float = 89.0
var camera_pitch: float = 0.0
var camera_yaw: float = 0.0

@onready var camera_topdown: Camera3D = $CameraTopDown
@onready var camera_isometric: Camera3D = $CameraIsometric
@onready var camera_firstperson: Camera3D = $CameraFirstPerson
@onready var fade_raycast: RayCast3D = $FadeRaycast

var active_camera: Camera3D

var target: Node3D
var faded_objects: Dictionary = {}

func _ready() -> void:
	# Set up cameras
	_setup_cameras()
	
	# Set initial camera
	_switch_to_camera(current_camera_view)
	
	# Set up fade raycast
	fade_raycast.target_position = Vector3(0, -20, -20)
	fade_raycast.collision_mask = 1  # Only check world layer

func _setup_cameras() -> void:
	# Configure camera properties
	if camera_topdown:
		camera_topdown.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera_topdown.size = topdown_size
		camera_topdown.near = 0.1
		camera_topdown.far = 100.0
		
	if camera_isometric:
		camera_isometric.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera_isometric.size = iso_size
		camera_isometric.near = 0.1
		camera_isometric.far = 100.0
		
	if camera_firstperson:
		camera_firstperson.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera_firstperson.fov = fps_fov
		camera_firstperson.near = 0.01
		camera_firstperson.far = 100.0

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

func get_active_camera() -> Camera3D:
	return active_camera

func get_current_camera_view() -> int:
	return current_camera_view

func get_camera_yaw() -> float:
	return camera_yaw

func _input(event: InputEvent) -> void:
	# Only handle mouse look in first person view
	if current_camera_view != 2:
		return
		
	if event is InputEventMouseMotion:
		var mouse_delta = event.relative
		
		# Apply mouse sensitivity
		camera_yaw -= mouse_delta.x * mouse_sensitivity * 180.0 / PI
		camera_pitch -= mouse_delta.y * mouse_sensitivity * 180.0 / PI
		
		# Clamp pitch to prevent camera from flipping
		camera_pitch = clamp(camera_pitch, -pitch_limit, pitch_limit)
		
		# Wrap yaw to keep it within 0-360 range
		camera_yaw = fmod(camera_yaw, 360.0)

func _apply_camera_view(view_index: int) -> void:
	var view = camera_views[view_index]
	
	if view.is_first_person:
		# First person mode
		rotation.y = 0  # Follow player rotation
		rotation.x = 0
		
		# Position camera at eye level
		active_camera.position = Vector3(0, view.height, 0)
		active_camera.rotation = Vector3(0, 0, 0)
		
		# Set perspective projection for first person
		active_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		active_camera.fov = view.fov
		
		# Adjust near plane for first person
		active_camera.near = 0.01
		active_camera.far = 100.0
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
		
		active_camera.position = cam_pos
		active_camera.look_at(Vector3.ZERO, Vector3.UP)
		
		# Set orthogonal projection
		active_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		active_camera.size = view.size
		
		# Enable culling optimizations
		active_camera.cull_mask = 0xFFFFF  # See all layers
		active_camera.near = 0.1
		active_camera.far = 100.0  # Reduce far plane for better culling
	
	print("Camera switched to: ", view.name)

func toggle_camera_view() -> void:
	current_camera_view = (current_camera_view + 1) % 3
	_switch_to_camera(current_camera_view)

func _switch_to_camera(index: int) -> void:
	# Disable all cameras
	if camera_topdown:
		camera_topdown.current = false
	if camera_isometric:
		camera_isometric.current = false
	if camera_firstperson:
		camera_firstperson.current = false
	
	# Enable selected camera
	match index:
		0:
			if camera_topdown:
				camera_topdown.current = true
				active_camera = camera_topdown
				print("Switched to Top Down camera")
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		1:
			if camera_isometric:
				camera_isometric.current = true
				active_camera = camera_isometric
				print("Switched to Isometric camera")
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		2:
			if camera_firstperson:
				camera_firstperson.current = true
				active_camera = camera_firstperson
				print("Switched to First Person camera")
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				# Reset camera rotation when entering first person
				camera_pitch = 0.0
				camera_yaw = 0.0

func _physics_process(delta: float) -> void:
	if not target or not active_camera:
		return
	
	if current_camera_view == 2:  # First person
		# Camera rig follows player exactly
		global_position = target.global_position
		
		# Apply mouse look rotation to first person camera
		camera_firstperson.rotation.x = deg_to_rad(camera_pitch)
		camera_firstperson.rotation.y = deg_to_rad(camera_yaw)
	else:
		# Smooth follow for top-down/isometric
		var target_pos := target.global_position
		global_position = global_position.lerp(target_pos, follow_speed * delta)
	
	# Wall fade system (only for non-first person views)
	if current_camera_view != 2:
		_update_wall_fade()

func _update_wall_fade() -> void:
	if not target:
		return
	
	# Cast ray from camera to player
	fade_raycast.global_position = active_camera.global_position
	fade_raycast.target_position = target.global_position - active_camera.global_position
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
	if active_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		active_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		active_camera.fov = 45
	else:
		active_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		active_camera.size = 10.0

func zoom_in() -> void:
	if active_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		active_camera.size = max(5.0, active_camera.size - 1.0)
	else:
		camera_distance = max(10.0, camera_distance - 2.0)
		active_camera.position.z = camera_distance

func zoom_out() -> void:
	if active_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		active_camera.size = min(20.0, active_camera.size + 1.0)
	else:
		camera_distance = min(30.0, camera_distance + 2.0)
		active_camera.position.z = camera_distance
