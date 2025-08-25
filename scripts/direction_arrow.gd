extends MeshInstance3D

class_name DirectionArrow

@export var arrow_length: float = 0.8
@export var shaft_width: float = 0.08
@export var head_width: float = 0.2
@export var head_length: float = 0.3
@export var arrow_color: Color = Color.YELLOW

func _ready() -> void:
	_create_arrow_mesh()

func _create_arrow_mesh() -> void:
	var array_mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	
	# Arrow pointing forward (positive Z direction)
	var shaft_end := arrow_length - head_length
	
	# Shaft vertices (rectangular prism)
	var half_shaft := shaft_width * 0.5
	
	# Bottom face of shaft
	vertices.append(Vector3(-half_shaft, -half_shaft, 0))  # 0
	vertices.append(Vector3(half_shaft, -half_shaft, 0))   # 1
	vertices.append(Vector3(half_shaft, half_shaft, 0))    # 2
	vertices.append(Vector3(-half_shaft, half_shaft, 0))   # 3
	
	# Top face of shaft
	vertices.append(Vector3(-half_shaft, -half_shaft, shaft_end))  # 4
	vertices.append(Vector3(half_shaft, -half_shaft, shaft_end))   # 5
	vertices.append(Vector3(half_shaft, half_shaft, shaft_end))    # 6
	vertices.append(Vector3(-half_shaft, half_shaft, shaft_end))   # 7
	
	# Arrow head base (wider)
	var half_head := head_width * 0.5
	vertices.append(Vector3(-half_head, -half_head, shaft_end))    # 8
	vertices.append(Vector3(half_head, -half_head, shaft_end))     # 9
	vertices.append(Vector3(half_head, half_head, shaft_end))      # 10
	vertices.append(Vector3(-half_head, half_head, shaft_end))     # 11
	
	# Arrow tip
	vertices.append(Vector3(0, 0, arrow_length))  # 12
	
	# Add normals and colors for all vertices
	for i in range(vertices.size()):
		normals.append(Vector3.UP)
		colors.append(arrow_color)
	
	# Create triangular faces
	# Shaft faces
	# Bottom face
	indices.append_array([0, 2, 1, 0, 3, 2])
	# Top face  
	indices.append_array([4, 5, 6, 4, 6, 7])
	# Side faces
	indices.append_array([0, 1, 5, 0, 5, 4])  # Front
	indices.append_array([2, 3, 7, 2, 7, 6])  # Back
	indices.append_array([1, 2, 6, 1, 6, 5])  # Right
	indices.append_array([3, 0, 4, 3, 4, 7])  # Left
	
	# Arrow head faces
	# Connect head base to tip
	indices.append_array([8, 12, 9])   # Bottom triangle
	indices.append_array([9, 12, 10])  # Right triangle
	indices.append_array([10, 12, 11]) # Top triangle
	indices.append_array([11, 12, 8])  # Left triangle
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# Create material
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = arrow_color
	material.emission_energy = 0.5
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	array_mesh.surface_set_material(0, material)
	mesh = array_mesh

func set_arrow_color(color: Color) -> void:
	arrow_color = color
	_create_arrow_mesh()

func set_visibility(visible_state: bool) -> void:
	visible = visible_state