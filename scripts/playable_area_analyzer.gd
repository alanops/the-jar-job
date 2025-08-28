extends Node
class_name PlayableAreaAnalyzer

# Analyzes floor mesh to determine playable area boundaries
signal analysis_complete(bounds: Rect2)

var floor_bounds: Rect2
var floor_height: float = 0.0
var floor_mesh_instance: MeshInstance3D

func analyze_floor_model(floor_node: Node3D) -> Rect2:
	print("PlayableAreaAnalyzer: Analyzing floor model...")
	
	# Find the MeshInstance3D in the floor model
	floor_mesh_instance = _find_mesh_instance(floor_node)
	
	if not floor_mesh_instance:
		print("PlayableAreaAnalyzer: ERROR - No mesh instance found in floor model!")
		return Rect2()
	
	if not floor_mesh_instance.mesh:
		print("PlayableAreaAnalyzer: ERROR - Mesh instance has no mesh!")
		return Rect2()
	
	# Get the AABB (Axis-Aligned Bounding Box) of the mesh
	var aabb = floor_mesh_instance.get_aabb()
	var global_transform = floor_mesh_instance.global_transform
	
	# Transform AABB to world space
	var world_aabb = global_transform * aabb
	
	# Extract 2D bounds (X and Z coordinates)
	floor_bounds = Rect2(
		world_aabb.position.x,
		world_aabb.position.z,
		world_aabb.size.x,
		world_aabb.size.z
	)
	
	# Store the floor height (Y position)
	floor_height = world_aabb.position.y + (world_aabb.size.y / 2.0)
	
	print("PlayableAreaAnalyzer: Floor bounds detected:")
	print("  Position: ", floor_bounds.position)
	print("  Size: ", floor_bounds.size)
	print("  Height: ", floor_height)
	print("  Corners:")
	print("    Top-Left: ", Vector2(floor_bounds.position.x, floor_bounds.position.y))
	print("    Top-Right: ", Vector2(floor_bounds.end.x, floor_bounds.position.y))
	print("    Bottom-Left: ", Vector2(floor_bounds.position.x, floor_bounds.end.y))
	print("    Bottom-Right: ", Vector2(floor_bounds.end.x, floor_bounds.end.y))
	
	analysis_complete.emit(floor_bounds)
	return floor_bounds

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result:
			return result
	
	return null

# Generate evenly distributed waypoints within the playable area
func generate_patrol_waypoints(num_waypoints: int = 6, margin: float = 1.0) -> Array[Vector3]:
	if floor_bounds.size == Vector2.ZERO:
		print("PlayableAreaAnalyzer: No floor bounds available for waypoint generation!")
		return []
	
	var waypoints: Array[Vector3] = []
	
	# Create a smaller rect with margin from edges
	var safe_bounds = floor_bounds.grow(-margin)
	
	# Generate waypoints in a circular pattern
	var center = safe_bounds.get_center()
	var radius = min(safe_bounds.size.x, safe_bounds.size.y) * 0.4
	
	for i in range(num_waypoints):
		var angle = (i * TAU) / num_waypoints
		var x = center.x + cos(angle) * radius
		var z = center.y + sin(angle) * radius
		waypoints.append(Vector3(x, floor_height, z))
	
	print("PlayableAreaAnalyzer: Generated ", waypoints.size(), " waypoints")
	return waypoints

# Get a random position within the playable area
func get_random_position(margin: float = 1.0) -> Vector3:
	if floor_bounds.size == Vector2.ZERO:
		return Vector3.ZERO
	
	var safe_bounds = floor_bounds.grow(-margin)
	var x = randf_range(safe_bounds.position.x, safe_bounds.end.x)
	var z = randf_range(safe_bounds.position.y, safe_bounds.end.y)
	
	return Vector3(x, floor_height, z)

# Check if a position is within the playable area
func is_position_in_playable_area(pos: Vector3, margin: float = 0.5) -> bool:
	var safe_bounds = floor_bounds.grow(-margin)
	return safe_bounds.has_point(Vector2(pos.x, pos.z))

# Get the center of the playable area
func get_center_position() -> Vector3:
	var center = floor_bounds.get_center()
	return Vector3(center.x, floor_height, center.y)

# Generate spawn positions for items
func generate_item_positions(num_items: int, margin: float = 2.0) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var safe_bounds = floor_bounds.grow(-margin)
	
	# Divide area into grid
	var grid_size = ceil(sqrt(num_items))
	var cell_width = safe_bounds.size.x / grid_size
	var cell_height = safe_bounds.size.y / grid_size
	
	for i in range(num_items):
		var grid_x = i % int(grid_size)
		var grid_y = i / int(grid_size)
		
		# Random position within grid cell
		var x = safe_bounds.position.x + (grid_x + randf()) * cell_width
		var z = safe_bounds.position.y + (grid_y + randf()) * cell_height
		
		positions.append(Vector3(x, floor_height + 1.0, z))
	
	return positions