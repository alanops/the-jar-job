extends Area3D

class_name VisionCone

@export var cone_angle: float = 60.0
@export var cone_length: float = 6.0
@export var cone_color: Color = Color(1, 1, 0, 0.3)
@export var alert_color: Color = Color(1, 0, 0, 0.5)

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var cone_mesh: ArrayMesh
var is_alert: bool = false
var player_in_area: bool = false

# Performance optimization
var last_alert_state: bool = false
var color_update_timer: float = 0.0
var color_update_interval: float = 0.1  # Only update color every 0.1 seconds

func _ready() -> void:
	# Wait a frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Create vision cone mesh with reduced complexity
	_create_cone_mesh()
	
	# Ensure we have valid collision components
	if not collision_shape or not mesh_instance:
		return
	
	# Set up collision shape - use a simple box
	var shape := BoxShape3D.new()
	var half_width = tan(deg_to_rad(cone_angle / 2)) * cone_length
	shape.size = Vector3(half_width * 2, 3.0, cone_length)
	collision_shape.shape = shape
	collision_shape.position.z = cone_length / 2
	
	# Set collision layers
	collision_layer = 0
	collision_mask = 2  # Only detect player layer
	
	# Enable monitoring
	monitoring = true
	monitorable = false
	
	# Connect area signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Optimize: Disable mesh visibility in release builds for better performance
	if not OS.is_debug_build():
		mesh_instance.visible = false

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_area = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_area = false

func get_cone_debug_info() -> String:
	return "Cone - Length: %s, Angle: %s" % [cone_length, cone_angle]

func _create_cone_mesh() -> void:
	cone_mesh = ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	
	# Simplified cone with fewer segments for performance
	var segments := 8  # Reduced from 32
	var half_angle := deg_to_rad(cone_angle / 2)
	
	# Add cone origin
	vertices.push_back(Vector3.ZERO)
	normals.push_back(Vector3.UP)
	colors.push_back(cone_color)
	
	# Add cone edge vertices
	for i in range(segments + 1):
		var angle := (float(i) / segments) * TAU - PI - half_angle
		var x := sin(angle) * cone_length
		var z: float = abs(cos(angle)) * cone_length
		
		if abs(angle) <= half_angle:
			vertices.push_back(Vector3(x, 0, z))
			normals.push_back(Vector3.UP)
			colors.push_back(cone_color)
	
	# Create indices for triangles
	var indices := PackedInt32Array()
	for i in range(vertices.size() - 1):
		indices.push_back(0)
		indices.push_back(i + 1)
		indices.push_back((i + 1) % (vertices.size() - 1) + 1)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	
	cone_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# Create optimized material
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = false  # We'll use albedo_color instead
	material.albedo_color = cone_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.flags_unshaded = true
	
	mesh_instance.mesh = cone_mesh
	mesh_instance.set_surface_override_material(0, material)

func set_alert_mode(alert: bool) -> void:
	is_alert = alert
	# Only update color if state actually changed and enough time has passed
	if alert != last_alert_state:
		_update_cone_color()
		last_alert_state = alert

func _update_cone_color() -> void:
	# Optimize: Just change material color instead of rebuilding mesh
	if not mesh_instance:
		return
	
	var material := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	if not material:
		# Material should exist from _create_cone_mesh(), but create if missing
		material = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = false
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.flags_unshaded = true
		mesh_instance.set_surface_override_material(0, material)
	
	# Simply change the albedo color instead of rebuilding mesh
	var target_color := alert_color if is_alert else cone_color
	material.albedo_color = target_color

# Removed debug functions for performance

func is_target_in_cone(target_position: Vector3) -> bool:
	var parent_npc: Node3D = get_parent()
	if not parent_npc:
		return false
	
	var npc_position: Vector3 = parent_npc.global_position
	var to_target: Vector3 = target_position - npc_position
	
	# Distance check
	if to_target.length() > cone_length:
		return false
	
	# Normalize for angle calculation
	to_target = to_target.normalized()
	
	# NPC forward direction (positive Z is forward for our setup)
	var npc_forward: Vector3 = parent_npc.global_transform.basis.z
	
	# Angle check using dot product (cosine)
	var cos_half_fov: float = cos(deg_to_rad(cone_angle * 0.5))
	return npc_forward.dot(to_target) >= cos_half_fov
