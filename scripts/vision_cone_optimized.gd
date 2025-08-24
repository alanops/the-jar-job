extends Area3D

class_name VisionCone

@export var cone_angle: float = 60.0
@export var cone_length: float = 6.0
@export var cone_color: Color = Color(1, 1, 0, 0.3)
@export var alert_color: Color = Color(1, 0, 0, 0.5)

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var cone_mesh: ArrayMesh
var cone_material: StandardMaterial3D
var is_alert: bool = false
var player_in_area: bool = false

func _ready() -> void:
	await get_tree().process_frame
	
	# Create vision cone mesh once
	_create_cone_mesh()
	
	# Set up collision shape once
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

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_area = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_area = false

func _create_cone_mesh() -> void:
	cone_mesh = ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	
	# Cone parameters
	var segments := 16  # Reduced from 32
	var half_angle := deg_to_rad(cone_angle / 2)
	
	# Add cone origin
	vertices.push_back(Vector3.ZERO)
	normals.push_back(Vector3.UP)
	uvs.push_back(Vector2(0.5, 0.5))
	
	# Add cone edge vertices
	for i in range(segments + 1):
		var angle := (float(i) / segments) * TAU - PI - half_angle
		var x := sin(angle) * cone_length
		var z: float = abs(cos(angle)) * cone_length
		
		if abs(angle) <= half_angle:
			vertices.push_back(Vector3(x, 0, z))
			normals.push_back(Vector3.UP)
			uvs.push_back(Vector2(0.5 + x / (2 * cone_length), 0.5 + z / (2 * cone_length)))
	
	# Create indices for triangles
	var indices := PackedInt32Array()
	for i in range(vertices.size() - 1):
		indices.push_back(0)
		indices.push_back(i + 1)
		indices.push_back((i + 1) % (vertices.size() - 1) + 1)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	cone_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# Create material once and reuse it
	cone_material = StandardMaterial3D.new()
	cone_material.albedo_color = cone_color
	cone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	cone_mesh.surface_set_material(0, cone_material)
	mesh_instance.mesh = cone_mesh

func set_alert_mode(alert: bool) -> void:
	if is_alert == alert:
		return
	is_alert = alert
	_update_cone_color()

func _update_cone_color() -> void:
	if cone_material:
		cone_material.albedo_color = alert_color if is_alert else cone_color

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
	
	# NPC forward direction
	var npc_forward: Vector3 = parent_npc.global_transform.basis.z
	
	# Angle check using dot product
	var cos_half_fov: float = cos(deg_to_rad(cone_angle * 0.5))
	return npc_forward.dot(to_target) >= cos_half_fov