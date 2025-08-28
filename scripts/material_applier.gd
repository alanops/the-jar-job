extends Node
class_name MaterialApplier

# Applies color scheme materials to imported models and game objects

static func apply_materials_to_level(walls_node: Node3D, floor_node: Node3D):
	print("MaterialApplier: Applying color scheme to level...")
	
	if walls_node:
		apply_wall_materials(walls_node)
	
	if floor_node:
		apply_floor_materials(floor_node)

static func apply_wall_materials(node: Node3D):
	_apply_material_recursive(node, ColorScheme.get_wall_material(), "wall")

static func apply_floor_materials(node: Node3D):
	_apply_material_recursive(node, ColorScheme.get_floor_material(), "floor")

static func apply_desk_materials(node: Node3D):
	_apply_material_recursive(node, ColorScheme.get_desk_material(), "desk")

static func _apply_material_recursive(node: Node3D, material: StandardMaterial3D, type_name: String):
	# Apply to MeshInstance3D nodes
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		if mesh_instance.mesh:
			# Only apply if no existing material override
			if not mesh_instance.material_override:
				# Check if it's the right type of object based on name or properties
				var node_name_lower = node.name.to_lower()
				
				if _should_apply_material(node_name_lower, type_name):
					mesh_instance.material_override = material
					print("  Applied ", type_name, " material to: ", node.name)
			else:
				print("  Skipping ", node.name, " - already has material override")
	
	# Recursively apply to children
	for child in node.get_children():
		if child is Node3D:
			_apply_material_recursive(child as Node3D, material, type_name)

static func _should_apply_material(node_name: String, type_name: String) -> bool:
	match type_name:
		"wall":
			return "wall" in node_name or "barrier" in node_name
		"floor": 
			return "floor" in node_name or "ground" in node_name or "plane" in node_name or "slab" in node_name
		"desk":
			return "desk" in node_name or "table" in node_name or "furniture" in node_name
		_:
			return true

static func apply_player_material(player_node: Node3D):
	var mesh_instance = _find_mesh_instance(player_node)
	if mesh_instance and not mesh_instance.material_override:
		mesh_instance.material_override = ColorScheme.get_player_material()
		print("MaterialApplier: Applied player color to mesh")
	elif mesh_instance:
		print("MaterialApplier: Skipping player - already has material")

static func apply_npc_material(npc_node: Node3D):
	var mesh_instance = _find_mesh_instance(npc_node)
	if mesh_instance and not mesh_instance.material_override:
		mesh_instance.material_override = ColorScheme.get_npc_material()
		print("MaterialApplier: Applied NPC color to mesh")
	elif mesh_instance:
		print("MaterialApplier: Skipping NPC - already has material")

static func apply_jar_material(jar_node: Node3D):
	var mesh_instance = _find_mesh_instance(jar_node)
	if mesh_instance and not mesh_instance.material_override:
		mesh_instance.material_override = ColorScheme.get_jar_material()
		print("MaterialApplier: Applied jar color with glow effect")
	elif mesh_instance:
		print("MaterialApplier: Skipping jar - already has material")

static func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result:
			return result
	
	return null

# Apply materials to specific object types based on detection
static func apply_smart_materials_to_level(root_node: Node3D):
	print("MaterialApplier: Intelligently applying materials based on object detection...")
	_smart_apply_recursive(root_node)

static func _smart_apply_recursive(node: Node3D):
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		if mesh_instance.mesh:
			var node_name_lower = node.name.to_lower()
			var aabb = mesh_instance.get_aabb()
			
			var material: StandardMaterial3D = null
			var type_name = ""
			
			# Detect object type and assign appropriate material
			if "wall" in node_name_lower or "barrier" in node_name_lower:
				material = ColorScheme.get_wall_material()
				type_name = "wall"
			elif "floor" in node_name_lower or "ground" in node_name_lower or "plane" in node_name_lower:
				material = ColorScheme.get_floor_material()
				type_name = "floor"
			elif "desk" in node_name_lower or "table" in node_name_lower:
				material = ColorScheme.get_desk_material()
				type_name = "desk"
			elif "jar" in node_name_lower or "biscuit" in node_name_lower:
				material = ColorScheme.get_jar_material()
				type_name = "jar"
			# Geometry-based detection
			elif aabb.size.y > 1.5 and (aabb.size.x > aabb.size.y or aabb.size.z > aabb.size.y):
				# Tall and wide/long = likely a wall
				material = ColorScheme.get_wall_material()
				type_name = "wall (geometry)"
			elif aabb.size.y < 0.5 and aabb.size.x > 2.0 and aabb.size.z > 2.0:
				# Flat and large = likely a floor
				material = ColorScheme.get_floor_material()
				type_name = "floor (geometry)"
			
			if material and not mesh_instance.material_override:
				mesh_instance.material_override = material
				print("  Applied ", type_name, " material to: ", node.name)
			elif material:
				print("  Skipping ", node.name, " - already has material override")
	
	# Recursively apply to children
	for child in node.get_children():
		if child is Node3D:
			_smart_apply_recursive(child as Node3D)