extends Node

# This script automatically adds occluders to walls and large objects for better performance

static func add_occluder_to_wall(wall_node: StaticBody3D) -> void:
	# Check if it already has an occluder
	for child in wall_node.get_children():
		if child is OccluderInstance3D:
			return
	
	# Get the mesh instance
	var mesh_instance: MeshInstance3D = null
	for child in wall_node.get_children():
		if child is MeshInstance3D:
			mesh_instance = child
			break
	
	if not mesh_instance or not mesh_instance.mesh:
		return
	
	# Create occluder based on mesh bounds
	var occluder := OccluderInstance3D.new()
	var occluder_shape := QuadOccluder3D.new()
	
	# Set the size based on the mesh
	if mesh_instance.mesh is BoxMesh:
		var box_mesh := mesh_instance.mesh as BoxMesh
		occluder_shape.size = Vector2(box_mesh.size.x, box_mesh.size.y)
	
	occluder.occluder = occluder_shape
	occluder.transform = mesh_instance.transform
	wall_node.add_child(occluder)

static func setup_scene_occluders(root_node: Node) -> void:
	# Find all walls and add occluders
	var walls = []
	_find_walls_recursive(root_node, walls)
	
	for wall in walls:
		add_occluder_to_wall(wall)

static func _find_walls_recursive(node: Node, walls: Array) -> void:
	# Check if this is a wall
	if node is StaticBody3D and (node.name.contains("Wall") or node.name.contains("wall")):
		walls.append(node)
	
	# Recurse through children
	for child in node.get_children():
		_find_walls_recursive(child, walls)