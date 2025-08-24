extends Node3D

# This generates a checkered floor using MultiMeshInstance3D for optimal performance

func _ready():
	generate_checkered_floor()

func generate_checkered_floor():
	# Clear existing children
	for child in get_children():
		child.queue_free()
	
	# Create light floor multimesh
	var light_multimesh := MultiMeshInstance3D.new()
	light_multimesh.multimesh = MultiMesh.new()
	light_multimesh.multimesh.mesh = _create_floor_mesh()
	light_multimesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	add_child(light_multimesh)
	
	# Create dark floor multimesh
	var dark_multimesh := MultiMeshInstance3D.new()
	dark_multimesh.multimesh = MultiMesh.new()
	dark_multimesh.multimesh.mesh = _create_floor_mesh()
	dark_multimesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	add_child(dark_multimesh)
	
	# Create materials
	var light_material := StandardMaterial3D.new()
	light_material.albedo_color = Color(0.9, 0.9, 0.95, 1)
	light_material.metallic = 0.0
	light_material.roughness = 1.0
	light_multimesh.material_override = light_material
	
	var dark_material := StandardMaterial3D.new()
	dark_material.albedo_color = Color(0.2, 0.2, 0.25, 1)
	dark_material.metallic = 0.0
	dark_material.roughness = 1.0
	dark_multimesh.material_override = dark_material
	
	# Count instances
	var light_count = 0
	var dark_count = 0
	
	# First pass: count instances
	for row in range(6):
		for col in range(6):
			if (row + col) % 2 == 0:
				light_count += 1
			else:
				dark_count += 1
	
	# Allocate instances
	light_multimesh.multimesh.instance_count = light_count
	dark_multimesh.multimesh.instance_count = dark_count
	
	# Second pass: set transforms
	var light_idx = 0
	var dark_idx = 0
	
	for row in range(6):
		for col in range(6):
			var transform := Transform3D()
			transform.origin = Vector3(-10 + col * 4, 0, -10 + row * 4)
			
			if (row + col) % 2 == 0:
				light_multimesh.multimesh.set_instance_transform(light_idx, transform)
				light_idx += 1
			else:
				dark_multimesh.multimesh.set_instance_transform(dark_idx, transform)
				dark_idx += 1
	
	# Create collision
	var static_body := StaticBody3D.new()
	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(24, 0.05, 24)
	collision_shape.shape = box_shape
	collision_shape.position = Vector3(0, -0.025, 0)
	static_body.add_child(collision_shape)
	static_body.collision_layer = 1
	static_body.collision_mask = 0
	add_child(static_body)

func _create_floor_mesh() -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(4, 0.05, 4)
	return mesh