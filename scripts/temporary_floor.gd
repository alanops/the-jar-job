extends StaticBody3D
class_name TemporaryFloor

# Creates a large temporary floor to prevent falling through the world
func _ready():
	# Create a large box shape for the floor
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(100, 0.1, 100)  # Large flat floor
	collision_shape.shape = box_shape
	collision_shape.position = Vector3(0, -0.05, 0)
	add_child(collision_shape)
	
	# Create a visual representation
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(100, 0.1, 100)
	mesh_instance.mesh = box_mesh
	mesh_instance.position = Vector3(0, -0.05, 0)
	
	# Create a simple material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.3, 0.3, 1.0)
	mesh_instance.material_override = material
	
	add_child(mesh_instance)
	
	print("TemporaryFloor: Created emergency floor at y=0")