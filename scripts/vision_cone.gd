extends Area3D
class_name VisionCone

@export var cone_angle: float = 60.0  # Total cone angle in degrees
@export var cone_range: float = 10.0  # Maximum detection range

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func is_target_in_cone(target_position: Vector3) -> bool:
	var local_target := to_local(target_position)
	
	# Debug output
	print("Checking vision - Target pos: ", target_position, " Local: ", local_target)
	
	# Check if target is within range
	var distance := local_target.length()
	print("Distance: ", distance, " Range: ", cone_range)
	if distance > cone_range:
		print("Out of range")
		return false
	
	# Check if target is in front of the NPC (negative Z in local space)
	print("Local Z: ", local_target.z)
	if local_target.z >= 0:
		print("Behind NPC")
		return false
	
	# Calculate angle from forward direction (-Z axis in local space)
	var forward := Vector3(0, 0, -1)
	var to_target := local_target.normalized()
	var angle := rad_to_deg(forward.angle_to(to_target))
	
	print("Angle: ", angle, " Max angle: ", cone_angle * 0.5)
	
	# Check if within cone angle (half angle on each side)
	var in_cone := angle <= cone_angle * 0.5
	print("In cone: ", in_cone)
	return in_cone

func set_alert_mode(alert: bool) -> void:
	if mesh_instance and mesh_instance.get_surface_override_material(0):
		var material = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
		if alert:
			material.albedo_color = Color(1, 0.5, 0, 0.25)  # Orange when alert
		else:
			material.albedo_color = Color(1, 0, 0, 0.15)    # Red when normal