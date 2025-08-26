extends Node3D

@export var cone_angle: float = 25.0
@export var cone_range: float = 15.0
@export var num_rays: int = 8
@export var show_debug_rays: bool = true

var ray_lines: Array[MeshInstance3D] = []

func _ready():
	if show_debug_rays:
		_create_debug_rays()

func _create_debug_rays():
	# Clear existing rays
	for ray in ray_lines:
		if ray:
			ray.queue_free()
	ray_lines.clear()
	
	# Create line material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0, 1, 0, 0.3)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Calculate half angle in radians
	var half_angle_rad = deg_to_rad(cone_angle * 0.5)
	
	# Create rays at different angles
	for i in range(num_rays):
		var angle_ratio = float(i) / float(num_rays - 1) if num_rays > 1 else 0.0
		var current_angle = -half_angle_rad + (angle_ratio * half_angle_rad * 2.0)
		
		# Create ray direction (rotate around Y axis)
		var direction = Vector3(sin(current_angle), 0, cos(current_angle))
		var end_point = direction * cone_range
		
		# Create line mesh
		var line_mesh = _create_line_mesh(Vector3.ZERO, end_point)
		var ray_instance = MeshInstance3D.new()
		ray_instance.mesh = line_mesh
		ray_instance.material_override = material
		
		add_child(ray_instance)
		ray_lines.append(ray_instance)

func _create_line_mesh(start: Vector3, end: Vector3) -> ArrayMesh:
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices = PackedVector3Array()
	var colors = PackedColorArray()
	
	vertices.push_back(start)
	vertices.push_back(end)
	colors.push_back(Color(0, 1, 0, 0.3))
	colors.push_back(Color(0, 1, 0, 0.1))
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	
	return mesh

func set_visibility(visible_state: bool):
	for ray in ray_lines:
		if ray:
			ray.visible = visible_state

func update_parameters(angle: float, range_val: float):
	cone_angle = angle
	cone_range = range_val
	if show_debug_rays:
		_create_debug_rays()

var detection_rays: Array[MeshInstance3D] = []

func show_detection_rays(from_pos: Vector3, target_points: Array, is_detecting: bool):
	# Clear existing detection rays
	for ray in detection_rays:
		if ray:
			ray.queue_free()
	detection_rays.clear()
	
	# Create material based on detection state
	var material = StandardMaterial3D.new()
	if is_detecting:
		material.albedo_color = Color(1, 0, 0, 0.8)  # Red when detecting
	else:
		material.albedo_color = Color(0, 1, 0, 0.5)  # Green when not detecting
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Create lines for each detection ray
	for target in target_points:
		var local_from = to_local(from_pos)
		var local_to = to_local(target)
		
		var line_mesh = _create_line_mesh(local_from, local_to)
		var ray_instance = MeshInstance3D.new()
		ray_instance.mesh = line_mesh
		ray_instance.material_override = material
		
		add_child(ray_instance)
		detection_rays.append(ray_instance)