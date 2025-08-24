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

func _ready() -> void:
	# Wait a frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Create vision cone mesh
	_create_cone_mesh()
	
	# Ensure we have valid collision components
	if not collision_shape:
		print("ERROR: VisionCone missing CollisionShape3D!")
		return
		
	if not mesh_instance:
		print("ERROR: VisionCone missing MeshInstance3D!")
		return
	
	# Set up collision shape - use a simple box for debugging first
	var shape := BoxShape3D.new()
	var half_width = tan(deg_to_rad(cone_angle / 2)) * cone_length
	shape.size = Vector3(half_width * 2, 3.0, cone_length)  # Make it taller to ensure it catches the player
	collision_shape.shape = shape
	# Position the box so it extends forward from the NPC (positive Z is forward)
	collision_shape.position.z = cone_length / 2
	
	# Set collision layers BEFORE enabling monitoring
	collision_layer = 0
	collision_mask = 7  # Temporarily detect all layers (1+2+4) for debugging
	
	# Enable monitoring
	monitoring = true
	monitorable = false
	
	print("Vision Cone Setup:")
	print("  Global position: ", global_position)
	print("  Local position: ", position)
	print("  collision_layer: ", collision_layer)
	print("  collision_mask: ", collision_mask)
	print("  monitoring: ", monitoring)
	print("  monitorable: ", monitorable)
	print("  Cone angle: ", cone_angle)
	print("  Cone length: ", cone_length)
	if shape is BoxShape3D:
		print("  Box size: ", shape.size)
	print("  CollisionShape3D position: ", collision_shape.position)
	print("  CollisionShape3D rotation: ", collision_shape.rotation)
	print("  CollisionShape3D global position: ", collision_shape.global_position)
	
	# Connect area signals for debugging
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Wait another frame and do an immediate overlap test
	await get_tree().process_frame
	_test_immediate_overlap()
	
	# Start periodic debugging
	_start_debug_timer()

func _on_body_entered(body: Node3D) -> void:
	print("Vision Cone - Body entered: ", body.name, " (Groups: ", body.get_groups(), ")")
	print("Vision Cone - Body collision layer: ", body.collision_layer)
	print("Vision Cone - Is in player group: ", body.is_in_group("player"))
	if body.is_in_group("player"):
		player_in_area = true
		print("Vision Cone - Player in area set to TRUE")

func _on_body_exited(body: Node3D) -> void:
	print("Vision Cone - Body exited: ", body.name, " (Groups: ", body.get_groups(), ")")
	if body.is_in_group("player"):
		player_in_area = false
		print("Vision Cone - Player in area set to FALSE")

func get_cone_debug_info() -> String:
	var shape_info = ""
	if collision_shape.shape is BoxShape3D:
		var shape = collision_shape.shape as BoxShape3D
		shape_info = "BoxSize: %s" % [shape.size]
	elif collision_shape.shape is CylinderShape3D:
		var shape = collision_shape.shape as CylinderShape3D
		shape_info = "Radius: %s, Height: %s" % [shape.radius, shape.height]
	
	var overlapping_bodies = get_overlapping_bodies()
	var body_names = []
	for body in overlapping_bodies:
		body_names.append(body.name + "(" + str(body.get_groups()) + ")")
	
	return "Cone - Length: %s, Angle: %s, %s, Position: %s, Rotation: %s, Overlapping: %s" % [
		cone_length, cone_angle, shape_info, collision_shape.position, collision_shape.rotation, body_names
	]

func _create_cone_mesh() -> void:
	cone_mesh = ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	
	# Cone parameters
	var segments := 32
	var half_angle := deg_to_rad(cone_angle / 2)
	
	# Add cone origin
	vertices.push_back(Vector3.ZERO)
	normals.push_back(Vector3.UP)
	uvs.push_back(Vector2(0.5, 0.5))
	colors.push_back(cone_color)
	
	# Add cone edge vertices (extending forward in positive Z direction)
	for i in range(segments + 1):
		var angle := (float(i) / segments) * TAU - PI - half_angle
		var x := sin(angle) * cone_length
		var z: float = abs(cos(angle)) * cone_length  # Make sure Z is positive (forward)
		
		if abs(angle) <= half_angle:
			vertices.push_back(Vector3(x, 0, z))
			normals.push_back(Vector3.UP)
			uvs.push_back(Vector2(0.5 + x / (2 * cone_length), 0.5 + z / (2 * cone_length)))
			colors.push_back(cone_color)
	
	# Create indices for triangles
	var indices := PackedInt32Array()
	for i in range(vertices.size() - 1):
		indices.push_back(0)
		indices.push_back(i + 1)
		indices.push_back((i + 1) % (vertices.size() - 1) + 1)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	
	cone_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# Create material
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	cone_mesh.surface_set_material(0, material)
	mesh_instance.mesh = cone_mesh

func set_alert_mode(alert: bool) -> void:
	is_alert = alert
	_update_cone_color()

func _update_cone_color() -> void:
	var target_color := alert_color if is_alert else cone_color
	
	if not cone_mesh or cone_mesh.get_surface_count() == 0:
		return
	
	var arrays := cone_mesh.surface_get_arrays(0)
	var colors := PackedColorArray()
	
	for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
		colors.push_back(target_color)
	
	arrays[Mesh.ARRAY_COLOR] = colors
	
	cone_mesh.clear_surfaces()
	cone_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	cone_mesh.surface_set_material(0, material)

func _test_immediate_overlap() -> void:
	print("=== IMMEDIATE OVERLAP TEST ===")
	var overlapping = get_overlapping_bodies()
	print("Overlapping bodies count: ", overlapping.size())
	for body in overlapping:
		print("  - ", body.name, " (Groups: ", body.get_groups(), ", Layer: ", body.collision_layer, ")")

func _start_debug_timer() -> void:
	var timer := Timer.new()
	timer.wait_time = 2.0
	timer.timeout.connect(_periodic_debug)
	add_child(timer)
	timer.start()

func _periodic_debug() -> void:
	print("=== VISION CONE PERIODIC DEBUG ===")
	print("player_in_area: ", player_in_area)
	var overlapping = get_overlapping_bodies()
	print("Currently overlapping bodies: ", overlapping.size())
	for body in overlapping:
		print("  - ", body.name, " at ", body.global_position, " (Groups: ", body.get_groups(), ")")
	print("Vision cone global position: ", global_position)
	print("Collision shape global position: ", collision_shape.global_position)

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
