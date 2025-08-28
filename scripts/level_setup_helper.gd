extends Node
class_name LevelSetupHelper

# Helper script to automatically set up imported Blender levels
# Handles collision detection, navigation mesh, and AI integration

signal level_setup_complete()

@export var auto_setup_collision: bool = true
@export var auto_setup_navigation: bool = true
@export var collision_layer: int = 1  # Default wall collision layer
@export var shadow_casting: bool = true

# Level analysis results
var wall_nodes: Array[Node3D] = []
var floor_nodes: Array[Node3D] = []
var furniture_nodes: Array[Node3D] = []
var analyzed_bounds: AABB

func _ready():
	print("LevelSetupHelper: Ready to analyze imported level")

# Analyze the imported Blender model and set up game components
func setup_imported_level(root_node: Node3D) -> void:
	print("LevelSetupHelper: Analyzing imported level structure...")
	
	_analyze_level_structure(root_node)
	
	if auto_setup_collision:
		_setup_collision_detection()
	
	if auto_setup_navigation:
		_setup_navigation_mesh(root_node)
	
	if shadow_casting:
		_setup_shadow_casting()
	
	_optimize_for_ai_systems()
	
	print("LevelSetupHelper: Level setup complete!")
	level_setup_complete.emit()

func _analyze_level_structure(node: Node3D, depth: int = 0) -> void:
	# Recursively analyze the imported model structure
	var indent = "  ".repeat(depth)
	print(indent + "Analyzing: " + node.name + " (" + node.get_class() + ")")
	
	# Identify node types based on naming conventions and structure
	var node_name_lower = node.name.to_lower()
	
	if "wall" in node_name_lower or "barrier" in node_name_lower:
		wall_nodes.append(node)
	elif "floor" in node_name_lower or "ground" in node_name_lower or "plane" in node_name_lower:
		floor_nodes.append(node)
	elif "desk" in node_name_lower or "chair" in node_name_lower or "furniture" in node_name_lower:
		furniture_nodes.append(node)
	
	# If it's a MeshInstance3D, analyze its geometry to classify it
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		if mesh_instance.mesh:
			var aabb = mesh_instance.get_aabb()
			# If it's tall and thin, it's likely a wall
			if aabb.size.y > 1.5 and (aabb.size.x > aabb.size.y or aabb.size.z > aabb.size.y):
				if not wall_nodes.has(node):
					print(indent + "  -> Detected as wall based on geometry (tall and thin)")
					wall_nodes.append(node)
	
	# Update level bounds and detect floors by geometry
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		if mesh_instance.mesh:
			var aabb = mesh_instance.get_aabb()
			aabb = mesh_instance.transform * aabb
			
			# If it's a large flat mesh at ground level, it's likely a floor
			if aabb.size.x > 5.0 and aabb.size.z > 5.0 and aabb.size.y < 0.5:
				if abs(aabb.position.y) < 1.0:  # Near ground level
					if not floor_nodes.has(node):
						print(indent + "  -> Detected as floor based on geometry")
						floor_nodes.append(node)
			
			if analyzed_bounds.size == Vector3.ZERO:
				analyzed_bounds = aabb
			else:
				analyzed_bounds = analyzed_bounds.merge(aabb)
	
	# Recursively analyze children
	for child in node.get_children():
		if child is Node3D:
			_analyze_level_structure(child as Node3D, depth + 1)

func _setup_collision_detection() -> void:
	print("LevelSetupHelper: Setting up collision detection...")
	
	var collision_nodes_added = 0
	
	# CRITICAL: Set up floor collisions first!
	for floor_node in floor_nodes:
		if floor_node is MeshInstance3D:
			var mesh_instance = floor_node as MeshInstance3D
			if mesh_instance.mesh and not _has_collision_shape(mesh_instance):
				_add_static_collision(mesh_instance, collision_layer)
				collision_nodes_added += 1
				print("  Added collision to floor: ", floor_node.name)
	
	# Set up wall collisions - PRIORITY!
	print("LevelSetupHelper: Setting up WALL collisions...")
	for wall_node in wall_nodes:
		if wall_node is MeshInstance3D:
			var mesh_instance = wall_node as MeshInstance3D
			if mesh_instance.mesh and not _has_collision_shape(mesh_instance):
				_add_static_collision(mesh_instance, 1)  # Wall collision layer
				collision_nodes_added += 1
				print("  Added collision to wall: ", wall_node.name)
	
	# Set up furniture collisions
	for furniture_node in furniture_nodes:
		if furniture_node is MeshInstance3D:
			var mesh_instance = furniture_node as MeshInstance3D
			if mesh_instance.mesh and not _has_collision_shape(mesh_instance):
				_add_static_collision(mesh_instance, collision_layer)
				collision_nodes_added += 1
	
	print("LevelSetupHelper: Added collision to ", collision_nodes_added, " objects total")
	print("  Walls: ", wall_nodes.size(), " detected")
	print("  Floors: ", floor_nodes.size(), " detected")
	print("  Furniture: ", furniture_nodes.size(), " detected")

func _has_collision_shape(node: Node3D) -> bool:
	# Check if node already has collision
	return node.get_parent() is StaticBody3D or node.get_parent() is RigidBody3D or node.get_parent() is CharacterBody3D

func _add_static_collision(mesh_instance: MeshInstance3D, layer: int) -> void:
	# Add StaticBody3D with collision shape to mesh
	var static_body = StaticBody3D.new()
	static_body.name = mesh_instance.name + "_Collision"
	static_body.collision_layer = layer
	static_body.collision_mask = 0
	
	var collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	
	# Create collision shape from mesh
	if mesh_instance.mesh:
		collision_shape.shape = mesh_instance.mesh.create_trimesh_shape()
	
	# Reparent mesh to StaticBody3D
	var original_parent = mesh_instance.get_parent()
	var original_transform = mesh_instance.transform
	
	mesh_instance.reparent(static_body)
	static_body.add_child(collision_shape)
	original_parent.add_child(static_body)
	
	# Restore transform
	static_body.transform = original_transform
	mesh_instance.transform = Transform3D.IDENTITY

func _setup_navigation_mesh(root_node: Node3D) -> void:
	print("LevelSetupHelper: Setting up navigation mesh...")
	
	# Find existing NavigationRegion3D or create one
	var nav_region = _find_navigation_region()
	if not nav_region:
		nav_region = NavigationRegion3D.new()
		nav_region.name = "LevelNavigation"
		root_node.get_parent().add_child(nav_region)
	
	# Create navigation mesh for floor areas
	var nav_mesh = NavigationMesh.new()
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.1
	nav_mesh.agent_height = 1.8
	nav_mesh.agent_radius = 0.35
	nav_mesh.agent_max_climb = 0.4
	nav_mesh.agent_max_slope = 45.0
	
	# Set up source geometry for navigation mesh baking
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES
	nav_mesh.geometry_collision_mask = collision_layer
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	
	nav_region.navigation_mesh = nav_mesh
	
	# Add root node as source for baking
	nav_region.add_child(root_node)
	
	print("LevelSetupHelper: Navigation mesh created - remember to bake it in the editor!")

func _find_navigation_region() -> NavigationRegion3D:
	# Find existing NavigationRegion3D in scene
	var scene_root = get_tree().current_scene
	if not scene_root:
		return null
	return _find_node_of_type(scene_root, NavigationRegion3D) as NavigationRegion3D

func _find_node_of_type(node: Node, type) -> Node:
	if not node:
		return null
	
	if is_instance_of(node, type):
		return node
	
	for child in node.get_children():
		var result = _find_node_of_type(child, type)
		if result:
			return result
	
	return null

func _setup_shadow_casting() -> void:
	print("LevelSetupHelper: Setting up shadow casting...")
	
	var shadow_nodes_updated = 0
	
	# Enable shadow casting for all mesh instances
	for node_array in [wall_nodes, furniture_nodes]:
		for node in node_array:
			if node is MeshInstance3D:
				var mesh_instance = node as MeshInstance3D
				mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				shadow_nodes_updated += 1
	
	print("LevelSetupHelper: Enabled shadows for ", shadow_nodes_updated, " objects")

func _optimize_for_ai_systems() -> void:
	print("LevelSetupHelper: Optimizing level for AI systems...")
	
	# Set up optimal collision layers for AI detection
	var ai_optimized_nodes = 0
	
	for wall_node in wall_nodes:
		var static_body = _get_static_body_parent(wall_node)
		if static_body:
			# Set collision layers for AI raycast detection
			static_body.collision_layer = 17  # Wall + AI detection layers
			ai_optimized_nodes += 1
	
	# Analyze level layout for optimal AI waypoint suggestions
	_suggest_ai_waypoints()
	
	print("LevelSetupHelper: AI optimization complete for ", ai_optimized_nodes, " objects")

func _get_static_body_parent(node: Node3D) -> StaticBody3D:
	var parent = node.get_parent()
	if parent is StaticBody3D:
		return parent as StaticBody3D
	return null

func _suggest_ai_waypoints() -> void:
	if analyzed_bounds.size == Vector3.ZERO:
		return
	
	print("LevelSetupHelper: Level bounds: ", analyzed_bounds)
	print("Suggested AI waypoints:")
	
	# Suggest waypoints based on level layout
	var waypoint_spacing = 4.0
	var bounds_center = analyzed_bounds.get_center()
	var bounds_size = analyzed_bounds.size
	
	# Create grid of suggested waypoint positions
	var suggested_waypoints: Array[Vector3] = []
	
	for x in range(-int(bounds_size.x / waypoint_spacing / 2), int(bounds_size.x / waypoint_spacing / 2) + 1):
		for z in range(-int(bounds_size.z / waypoint_spacing / 2), int(bounds_size.z / waypoint_spacing / 2) + 1):
			var waypoint_pos = bounds_center + Vector3(x * waypoint_spacing, 0, z * waypoint_spacing)
			suggested_waypoints.append(waypoint_pos)
	
	print("Consider adding AI waypoints at these positions:")
	for i in range(min(8, suggested_waypoints.size())):
		print("  Waypoint ", i + 1, ": ", suggested_waypoints[i])

# Public interface functions
func get_level_bounds() -> AABB:
	return analyzed_bounds

func get_wall_count() -> int:
	return wall_nodes.size()

func get_furniture_count() -> int:
	return furniture_nodes.size()

func print_level_analysis() -> void:
	print("=== Level Analysis Results ===")
	print("Walls found: ", wall_nodes.size())
	print("Floor pieces found: ", floor_nodes.size())
	print("Furniture found: ", furniture_nodes.size())
	print("Level bounds: ", analyzed_bounds)
	print("================================")

# Force collision on all meshes (emergency fallback)
func add_collision_to_all_meshes(root_node: Node3D) -> void:
	print("LevelSetupHelper: Adding collision to ALL mesh instances...")
	var meshes_processed = _add_collision_recursive(root_node, 0)
	print("LevelSetupHelper: Processed ", meshes_processed, " meshes")

func _add_collision_recursive(node: Node3D, meshes_processed: int) -> int:
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		if mesh_instance.mesh and not _has_collision_shape(mesh_instance):
			_add_static_collision(mesh_instance, collision_layer)
			meshes_processed += 1
			print("  Added collision to: ", node.name)
	
	for child in node.get_children():
		if child is Node3D:
			meshes_processed = _add_collision_recursive(child as Node3D, meshes_processed)
	
	return meshes_processed