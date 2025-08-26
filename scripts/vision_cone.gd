extends Area3D
class_name VisionCone

@export var cone_angle: float = 25.0  # Total cone angle in degrees (matches SpotLight3D)
@export var cone_range: float = 15.0  # Maximum detection range (matches SpotLight3D)

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func is_target_in_cone(target_position: Vector3) -> bool:
	var local_target := to_local(target_position)
	
	# Check if target is within range
	var distance := local_target.length()
	if distance > cone_range:
		return false
	
	# Check if target is in front of the NPC (positive Z in local space)
	if local_target.z <= 0:
		return false
	
	# Calculate angle from forward direction (+Z axis in local space)
	var forward := Vector3(0, 0, 1)
	var to_target := local_target.normalized()
	var angle := rad_to_deg(forward.angle_to(to_target))
	
	# Check if within cone angle (half angle on each side)
	return angle <= cone_angle * 0.5

func set_alert_mode(alert: bool) -> void:
	if mesh_instance and mesh_instance.get_surface_override_material(0):
		var material = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
		if alert:
			material.albedo_color = Color(1, 0.3, 0, 0.2)  # Orange when alert
		else:
			material.albedo_color = Color(1, 1, 0.8, 0.08)    # Warm white when normal