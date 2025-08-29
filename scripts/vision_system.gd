extends Node

# Optimized vision detection system for NPCs
# Handles raycast pooling, spatial partitioning, and performance optimization

var raycast_pool: Array[RayCast3D] = []
var available_raycasts: Array[RayCast3D] = []
var detection_cache: Dictionary = {}
var cache_timeout: float = 0.1  # Cache results for 100ms

var max_concurrent_checks: int = 3
var active_checks: int = 0
var max_detection_points: int = 8  # Maximum detection points for optimization

signal detection_completed(npc: Node, player_detected: bool)

func _ready() -> void:
	name = "VisionSystem"
	_initialize_raycast_pool()

func _initialize_raycast_pool() -> void:
	var pool_size = GameConfig.max_concurrent_vision_checks * 2
	
	for i in range(pool_size):
		var raycast = RayCast3D.new()
		raycast.name = "PooledRaycast_%d" % i
		raycast.collision_mask = 3  # Walls (1) and Player (2)
		raycast.enabled = false
		add_child(raycast)
		raycast_pool.append(raycast)
		available_raycasts.append(raycast)
	
	DebugLogger.info("Vision detection raycast pool initialized with %d raycasts" % pool_size, "VisionSystem")

func _get_raycast() -> RayCast3D:
	if available_raycasts.is_empty():
		DebugLogger.warning("No available raycasts in pool", "VisionSystem")
		return null
	
	return available_raycasts.pop_back()

func _return_raycast(raycast: RayCast3D) -> void:
	if raycast and raycast in raycast_pool:
		raycast.enabled = false
		available_raycasts.append(raycast)

func check_player_visibility(npc: Node3D, player: Node3D, detection_type: String = "flashlight") -> void:
	if not npc or not player:
		DebugLogger.error("Invalid npc or player reference", "VisionSystem")
		return
	
	# Check if we're at the concurrent check limit
	if active_checks >= max_concurrent_checks:
		# Queue the check for next frame
		call_deferred("_queue_vision_check", npc, player, detection_type)
		return
	
	# Check cache first
	var cache_key = "%s_%s_%s" % [npc.get_instance_id(), player.get_instance_id(), detection_type]
	if detection_cache.has(cache_key):
		var cached_result = detection_cache[cache_key]
		if Time.get_time_dict_from_system() - cached_result.timestamp < cache_timeout:
			detection_completed.emit(npc, cached_result.detected)
			return
	
	_perform_vision_check(npc, player, detection_type)

func _queue_vision_check(npc: Node3D, player: Node3D, detection_type: String) -> void:
	await get_tree().process_frame
	check_player_visibility(npc, player, detection_type)

func _perform_vision_check(npc: Node3D, player: Node3D, detection_type: String) -> void:
	active_checks += 1
	
	var npc_pos = npc.global_position
	var player_pos = player.global_position
	var distance = npc_pos.distance_to(player_pos)
	
	# Determine detection points based on type and distance
	var hit_points = _get_detection_points(player_pos, detection_type, distance)
	var from_pos = _get_detection_origin(npc, detection_type)
	
	# Perform raycast checks asynchronously
	_async_raycast_check(npc, player, from_pos, hit_points, detection_type)

func _get_detection_origin(npc: Node3D, detection_type: String) -> Vector3:
	match detection_type:
		"flashlight":
			var flashlight = npc.get_node_or_null("Flashlight")
			return flashlight.global_position if flashlight else npc.global_position
		_:
			return npc.global_position

func _get_detection_points(player_pos: Vector3, detection_type: String, distance: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	
	match detection_type:
		"close":
			points = [player_pos]
		
		"peripheral":
			points = [
				player_pos,
				player_pos + Vector3(0, 0.5, 0),
				player_pos + Vector3(0, -0.5, 0)
			]
		
		"flashlight":
			# Adaptive point count based on distance and performance settings
			var base_point_count = 3 if distance > 10.0 else 5
			var point_count = min(base_point_count, max_detection_points)
			points = [player_pos]  # Always check center
			
			if point_count >= 3:
				points.append_array([
					player_pos + Vector3(0.4, 0, 0),
					player_pos + Vector3(-0.4, 0, 0)
				])
			
			if point_count >= 5:
				points.append_array([
					player_pos + Vector3(0, 0.8, 0),
					player_pos + Vector3(0, -0.8, 0)
				])
			
			# Add more points if allowed and needed
			if point_count >= 6:
				points.append_array([
					player_pos + Vector3(0.3, 0.3, 0),
					player_pos + Vector3(-0.3, 0.3, 0)
				])
			
			if point_count >= 8:
				points.append([player_pos + Vector3(0, 0.3, 0)])
			
			# Trim to max allowed points
			if points.size() > max_detection_points:
				points = points.slice(0, max_detection_points)
	
	return points

func _async_raycast_check(npc: Node3D, player: Node3D, from_pos: Vector3, hit_points: Array[Vector3], detection_type: String) -> void:
	var hits = 0
	var total_points = hit_points.size()
	
	for i in range(total_points):
		var point = hit_points[i]
		var hit = await _perform_single_raycast(from_pos, point, player)
		
		if hit:
			hits += 1
		
		# Early exit optimization - if we already have enough hits
		if _has_sufficient_hits(detection_type, hits, i + 1):
			break
	
	var detected = _evaluate_detection(detection_type, hits, total_points)
	
	# Cache the result
	var cache_key = "%s_%s_%s" % [npc.get_instance_id(), player.get_instance_id(), detection_type]
	detection_cache[cache_key] = {
		"detected": detected,
		"timestamp": Time.get_time_dict_from_system()
	}
	
	# Emit result
	detection_completed.emit(npc, detected)
	active_checks -= 1

func _perform_single_raycast(from: Vector3, to: Vector3, target_player: Node3D) -> bool:
	var raycast = _get_raycast()
	if not raycast:
		return false
	
	raycast.global_position = from
	raycast.target_position = raycast.to_local(to)
	raycast.enabled = true
	raycast.force_raycast_update()
	
	var hit_player = false
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		hit_player = (collider == target_player)
	else:
		hit_player = true  # No obstacle, clear line of sight
	
	_return_raycast(raycast)
	return hit_player

func _has_sufficient_hits(detection_type: String, hits: int, points_checked: int) -> bool:
	match detection_type:
		"close":
			return hits >= 1
		"peripheral":
			return hits >= 2
		"flashlight":
			return hits >= 1
		_:
			return false

func _evaluate_detection(detection_type: String, hits: int, total_points: int) -> bool:
	match detection_type:
		"close":
			return hits >= 1
		"peripheral":
			return hits >= 2
		"flashlight":
			return hits >= 1
		_:
			return false

func _process(_delta: float) -> void:
	# Clean up old cache entries
	_cleanup_cache()

func _cleanup_cache() -> void:
	var current_time = Time.get_time_dict_from_system()
	var keys_to_remove: Array[String] = []
	
	for key in detection_cache.keys():
		var cached_result = detection_cache[key]
		if current_time - cached_result.timestamp > cache_timeout * 2:
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		detection_cache.erase(key)

func clear_cache() -> void:
	detection_cache.clear()
	DebugLogger.info("Vision detection cache cleared", "VisionSystem")

func get_pool_status() -> Dictionary:
	return {
		"total_raycasts": raycast_pool.size(),
		"available": available_raycasts.size(),
		"active_checks": active_checks,
		"cache_entries": detection_cache.size()
	}