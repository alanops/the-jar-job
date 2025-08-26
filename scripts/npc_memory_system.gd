extends Node
class_name NPCMemorySystem

# Advanced memory and learning system for NPCs
# Tracks player patterns, environmental changes, and adapts behavior

signal pattern_learned(pattern_type: String, pattern_data: Dictionary)
signal behavior_adapted(adaptation_type: String, old_value: float, new_value: float)

# Memory Categories
enum MemoryType {
	PLAYER_SIGHTING,     # Where and when player was seen
	PLAYER_ROUTE,        # Paths player commonly takes  
	HIDING_SPOT,         # Where player hides
	NOISE_EVENT,         # Sounds and their locations
	ENVIRONMENTAL_CHANGE # Doors, objects moved, etc.
}

# Memory storage with decay over time
var memories: Dictionary = {}  # MemoryType -> Array of memory entries
var pattern_recognition: Dictionary = {}  # Learned patterns
var behavioral_adaptations: Dictionary = {}  # How behavior has adapted

# Learning parameters
@export var memory_capacity: int = 100  # Max memories per type
@export var memory_decay_time: float = 300.0  # 5 minutes
@export var pattern_confidence_threshold: float = 0.7
@export var learning_rate: float = 0.1

# Pattern detection
var route_tracking: Dictionary = {}  # Track player movement patterns
var hiding_analysis: Dictionary = {}  # Analyze hiding behavior
var timing_patterns: Dictionary = {}  # When player is most active

# Adaptive behavior
var detection_adjustments: Dictionary = {
	"vision_range_multiplier": 1.0,
	"suspicion_sensitivity": 1.0,
	"patrol_speed_multiplier": 1.0,
	"search_thoroughness": 1.0,
	"alert_duration": 1.0
}

func _ready():
	# Initialize memory categories
	for memory_type in MemoryType.values():
		memories[memory_type] = []
	
	# Set up periodic pattern analysis
	var analysis_timer = Timer.new()
	analysis_timer.wait_time = 10.0  # Analyze patterns every 10 seconds
	analysis_timer.timeout.connect(_analyze_patterns)
	analysis_timer.autostart = true
	add_child(analysis_timer)
	
	# Set up memory cleanup
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 30.0  # Clean old memories every 30 seconds
	cleanup_timer.timeout.connect(_cleanup_old_memories)
	cleanup_timer.autostart = true
	add_child(cleanup_timer)

# ===================== MEMORY STORAGE =====================

func add_memory(type: MemoryType, position: Vector3, context: Dictionary = {}):
	var memory_entry = {
		"position": position,
		"timestamp": Time.get_time_dict_from_system()["unix"],
		"context": context,
		"importance": _calculate_importance(type, context),
		"decay_rate": _get_decay_rate(type)
	}
	
	memories[type].append(memory_entry)
	
	# Limit memory capacity
	if memories[type].size() > memory_capacity:
		# Remove oldest, least important memories
		memories[type].sort_custom(func(a, b): return a.importance > b.importance)
		memories[type] = memories[type].slice(0, memory_capacity)
	
	print("NPCMemorySystem: Added ", MemoryType.keys()[type], " memory at ", position)
	
	# Trigger immediate pattern analysis for important events
	if memory_entry.importance > 0.8:
		_analyze_specific_pattern(type)

func _calculate_importance(type: MemoryType, context: Dictionary) -> float:
	var base_importance = 0.5
	
	match type:
		MemoryType.PLAYER_SIGHTING:
			# More important if player was clearly seen for longer
			base_importance = 0.8 + context.get("detection_duration", 0.0) * 0.1
		MemoryType.PLAYER_ROUTE:
			# Routes become more important with repetition
			base_importance = 0.6 + context.get("frequency", 0) * 0.1
		MemoryType.HIDING_SPOT:
			# Important if player successfully hid there
			base_importance = 0.7 + (0.3 if context.get("successful_hide", false) else 0.0)
		MemoryType.NOISE_EVENT:
			# Important based on noise volume and frequency
			base_importance = 0.4 + context.get("volume", 0.5) * 0.4
		MemoryType.ENVIRONMENTAL_CHANGE:
			# Important if it indicates player presence
			base_importance = 0.5 + (0.4 if context.get("player_caused", false) else 0.0)
	
	return clamp(base_importance, 0.0, 1.0)

func _get_decay_rate(type: MemoryType) -> float:
	match type:
		MemoryType.PLAYER_SIGHTING: return 0.8  # Decay slower - important info
		MemoryType.PLAYER_ROUTE: return 0.6     # Routes remembered longer
		MemoryType.HIDING_SPOT: return 0.7      # Hiding spots stay relevant
		MemoryType.NOISE_EVENT: return 1.2      # Sounds decay faster
		MemoryType.ENVIRONMENTAL_CHANGE: return 1.0  # Standard decay
		_: return 1.0

# ===================== PATTERN RECOGNITION =====================

func _analyze_patterns():
	_analyze_route_patterns()
	_analyze_hiding_patterns()
	_analyze_timing_patterns()
	_analyze_behavioral_patterns()

func _analyze_specific_pattern(type: MemoryType):
	match type:
		MemoryType.PLAYER_ROUTE:
			_analyze_route_patterns()
		MemoryType.HIDING_SPOT:
			_analyze_hiding_patterns()
		MemoryType.PLAYER_SIGHTING:
			_analyze_timing_patterns()

func _analyze_route_patterns():
	var route_memories = memories[MemoryType.PLAYER_ROUTE]
	if route_memories.size() < 3:
		return
	
	# Group nearby positions to identify common routes
	var route_clusters = {}
	var cluster_radius = 3.0
	
	for memory in route_memories:
		var position = memory.position
		var found_cluster = false
		
		for cluster_key in route_clusters.keys():
			var cluster_center = route_clusters[cluster_key].center
			if position.distance_to(cluster_center) <= cluster_radius:
				route_clusters[cluster_key].positions.append(position)
				route_clusters[cluster_key].count += 1
				# Update cluster center (weighted average)
				var total_weight = route_clusters[cluster_key].count
				route_clusters[cluster_key].center = (cluster_center * (total_weight - 1) + position) / total_weight
				found_cluster = true
				break
		
		if not found_cluster:
			var cluster_key = str(position.x) + "_" + str(position.z)
			route_clusters[cluster_key] = {
				"center": position,
				"positions": [position],
				"count": 1,
				"confidence": 0.1
			}
	
	# Identify high-confidence patterns
	for cluster_key in route_clusters.keys():
		var cluster = route_clusters[cluster_key]
		cluster.confidence = min(cluster.count * 0.15, 1.0)
		
		if cluster.confidence >= pattern_confidence_threshold:
			if not pattern_recognition.has("common_routes"):
				pattern_recognition["common_routes"] = []
			
			# Check if this is a new pattern
			var is_new_pattern = true
			for existing_route in pattern_recognition["common_routes"]:
				if cluster.center.distance_to(existing_route.center) <= cluster_radius:
					existing_route.confidence = max(existing_route.confidence, cluster.confidence)
					is_new_pattern = false
					break
			
			if is_new_pattern:
				pattern_recognition["common_routes"].append(cluster)
				pattern_learned.emit("common_route", cluster)
				print("NPCMemorySystem: Learned common route at ", cluster.center)

func _analyze_hiding_patterns():
	var hiding_memories = memories[MemoryType.HIDING_SPOT]
	if hiding_memories.size() < 2:
		return
	
	# Analyze hiding spot effectiveness and patterns
	var hiding_analysis = {}
	
	for memory in hiding_memories:
		var position = memory.position
		var success = memory.context.get("successful_hide", false)
		var detection_time = memory.context.get("time_hidden", 0.0)
		
		var area_key = str(int(position.x / 5.0)) + "_" + str(int(position.z / 5.0))
		
		if not hiding_analysis.has(area_key):
			hiding_analysis[area_key] = {
				"position": position,
				"success_count": 0,
				"total_attempts": 0,
				"avg_time_hidden": 0.0,
				"effectiveness": 0.0
			}
		
		var area = hiding_analysis[area_key]
		area.total_attempts += 1
		if success:
			area.success_count += 1
		area.avg_time_hidden = (area.avg_time_hidden + detection_time) / 2.0
		area.effectiveness = (area.success_count / float(area.total_attempts)) * min(area.avg_time_hidden / 10.0, 1.0)
	
	# Store effective hiding spots
	pattern_recognition["effective_hiding_spots"] = []
	for area_key in hiding_analysis.keys():
		var area = hiding_analysis[area_key]
		if area.effectiveness >= 0.6:  # 60% effectiveness threshold
			pattern_recognition["effective_hiding_spots"].append(area)
			pattern_learned.emit("hiding_spot", area)

func _analyze_timing_patterns():
	var sighting_memories = memories[MemoryType.PLAYER_SIGHTING]
	if sighting_memories.size() < 3:
		return
	
	# Analyze when player is most active
	var time_buckets = {}  # Hour of day -> activity count
	
	for memory in sighting_memories:
		var timestamp = memory.timestamp
		var time_dict = Time.get_datetime_dict_from_unix_time(timestamp)
		var hour = time_dict.hour
		
		if not time_buckets.has(hour):
			time_buckets[hour] = 0
		time_buckets[hour] += 1
	
	# Find peak activity hours
	var peak_activity = 0
	var peak_hour = 12
	for hour in time_buckets.keys():
		if time_buckets[hour] > peak_activity:
			peak_activity = time_buckets[hour]
			peak_hour = hour
	
	if peak_activity >= 3:  # Need at least 3 sightings to establish pattern
		pattern_recognition["peak_activity_hour"] = peak_hour
		pattern_learned.emit("timing_pattern", {"peak_hour": peak_hour, "activity_count": peak_activity})

func _analyze_behavioral_patterns():
	# Analyze how player behavior changes over time
	# This could include reaction speed, hiding preferences, route choices
	pass

# ===================== ADAPTIVE BEHAVIOR =====================

func adapt_behavior(adaptation_type: String, stimulus_strength: float):
	if not detection_adjustments.has(adaptation_type):
		return
	
	var old_value = detection_adjustments[adaptation_type]
	var adaptation = learning_rate * stimulus_strength
	
	# Different adaptations based on type
	match adaptation_type:
		"vision_range_multiplier":
			# If player frequently escapes, increase vision range
			detection_adjustments[adaptation_type] = clamp(old_value + adaptation, 0.8, 2.0)
		
		"suspicion_sensitivity":
			# If player is often spotted, become more suspicious of small signs
			detection_adjustments[adaptation_type] = clamp(old_value + adaptation, 0.5, 2.5)
		
		"patrol_speed_multiplier":
			# Adapt patrol speed based on player behavior
			detection_adjustments[adaptation_type] = clamp(old_value + adaptation, 0.7, 1.5)
		
		"search_thoroughness":
			# If player uses hiding spots effectively, search more thoroughly
			detection_adjustments[adaptation_type] = clamp(old_value + adaptation, 0.8, 2.0)
		
		"alert_duration":
			# Maintain alertness longer if player is elusive
			detection_adjustments[adaptation_type] = clamp(old_value + adaptation, 0.5, 3.0)
	
	var new_value = detection_adjustments[adaptation_type]
	if abs(new_value - old_value) > 0.01:  # Only emit if significant change
		behavior_adapted.emit(adaptation_type, old_value, new_value)
		print("NPCMemorySystem: Adapted ", adaptation_type, " from ", old_value, " to ", new_value)

func get_behavioral_adjustment(adaptation_type: String) -> float:
	return detection_adjustments.get(adaptation_type, 1.0)

# ===================== QUERY SYSTEM =====================

func get_memories_near_position(position: Vector3, radius: float, type: MemoryType = -1) -> Array:
	var nearby_memories = []
	
	var memory_types = [type] if type != -1 else MemoryType.values()
	
	for memory_type in memory_types:
		if memories.has(memory_type):
			for memory in memories[memory_type]:
				if memory.position.distance_to(position) <= radius:
					nearby_memories.append(memory)
	
	return nearby_memories

func get_pattern_data(pattern_type: String) -> Dictionary:
	return pattern_recognition.get(pattern_type, {})

func has_learned_pattern(pattern_type: String) -> bool:
	return pattern_recognition.has(pattern_type)

func get_predicted_player_location() -> Vector3:
	# Use learned patterns to predict where player might be
	if pattern_recognition.has("common_routes") and not pattern_recognition["common_routes"].is_empty():
		# Return the most confident route center
		var best_route = pattern_recognition["common_routes"][0]
		for route in pattern_recognition["common_routes"]:
			if route.confidence > best_route.confidence:
				best_route = route
		return best_route.center
	
	# Fallback to most recent sighting
	var sightings = memories[MemoryType.PLAYER_SIGHTING]
	if not sightings.is_empty():
		return sightings[-1].position
	
	return Vector3.ZERO

func should_check_area_more_thoroughly(position: Vector3) -> bool:
	# Check if this area has hiding spots or frequent player activity
	if pattern_recognition.has("effective_hiding_spots"):
		for spot in pattern_recognition["effective_hiding_spots"]:
			if position.distance_to(spot.position) <= 8.0:
				return true
	
	return false

# ===================== CLEANUP =====================

func _cleanup_old_memories():
	var current_time = Time.get_time_dict_from_system()["unix"]
	
	for memory_type in memories.keys():
		var updated_memories = []
		
		for memory in memories[memory_type]:
			var age = current_time - memory.timestamp
			var decay_factor = exp(-age / (memory_decay_time * memory.decay_rate))
			
			# Keep memory if it hasn't decayed too much
			if decay_factor > 0.1:  # Keep memories at 10% strength or higher
				memory.importance *= decay_factor  # Apply decay to importance
				updated_memories.append(memory)
		
		memories[memory_type] = updated_memories
	
	print("NPCMemorySystem: Cleaned old memories. Current counts: ", _get_memory_counts())

func _get_memory_counts() -> Dictionary:
	var counts = {}
	for memory_type in memories.keys():
		counts[MemoryType.keys()[memory_type]] = memories[memory_type].size()
	return counts

# ===================== DEBUG =====================

func debug_print_patterns():
	print("=== Learned Patterns ===")
	for pattern_type in pattern_recognition.keys():
		print(pattern_type, ": ", pattern_recognition[pattern_type])
	
	print("=== Behavioral Adaptations ===")
	for adaptation in detection_adjustments.keys():
		print(adaptation, ": ", detection_adjustments[adaptation])
	
	print("=== Memory Counts ===")
	print(_get_memory_counts())