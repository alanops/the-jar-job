extends Node
class_name NPCCommunicationManager

# Global communication system for NPCs
# Manages shared information, alerts, and coordination

signal global_alert_raised(alert_level: AlertLevel, position: Vector3, source_npc: NPCController)
signal global_alert_cleared()
signal shared_information_updated(info_type: String, data: Dictionary)

enum AlertLevel {
	NONE = 0,      # Normal patrol
	LOW = 1,       # Something suspicious 
	MEDIUM = 2,    # Player spotted briefly
	HIGH = 3,      # Active chase/player confirmed
	LOCKDOWN = 4   # All exits blocked, coordinated search
}

# Shared memory system
var shared_memory: Dictionary = {
	"last_known_positions": [],      # Array of {position: Vector3, timestamp: float, confidence: float}
	"suspicious_areas": {},          # Dictionary of areas with suspicion levels
	"search_coverage": {},           # Track which areas have been searched recently
	"player_patterns": {},           # Learn common player routes and hiding spots
	"environmental_changes": [],     # Doors left open, objects moved, etc.
	"communication_range": 15.0,     # Range for direct NPC-to-NPC communication
}

# Alert system
var current_alert_level: AlertLevel = AlertLevel.NONE
var alert_start_time: float = 0.0
var alert_position: Vector3 = Vector3.ZERO
var alert_source: NPCController = null

# Network of NPCs
var registered_npcs: Array[NPCController] = []
var npc_positions: Dictionary = {}  # npc_id -> position

# Learning and adaptation
var player_behavior_data: Dictionary = {
	"common_routes": [],          # Frequently used paths
	"preferred_hiding_spots": [], # Where player hides most often
	"detection_history": [],      # When/where player was spotted
	"escape_patterns": [],        # How player typically escapes
	"skill_assessment": 0.5       # 0.0 = novice, 1.0 = expert
}

func _ready():
	# Add to group so NPCs can find this manager
	add_to_group("npc_communication_manager")
	set_process(true)
	
	# Clear old data periodically
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 30.0  # Clean up every 30 seconds
	cleanup_timer.timeout.connect(_cleanup_old_data)
	cleanup_timer.autostart = true
	add_child(cleanup_timer)
	
	print("NPCCommunicationManager: Ready and added to group")

func _process(delta: float):
	_update_npc_positions()
	_update_alert_system(delta)
	_analyze_player_behavior(delta)

# ===================== NPC REGISTRATION =====================

func register_npc(npc: NPCController):
	if npc not in registered_npcs:
		registered_npcs.append(npc)
		npc_positions[npc.get_instance_id()] = npc.global_position
		
		# Connect to NPC signals
		npc.player_spotted.connect(_on_npc_spotted_player)
		npc.player_caught.connect(_on_npc_caught_player)
		npc.state_changed_debug.connect(_on_npc_state_changed.bind(npc))
		
		print("NPCCommunicationManager: Registered NPC ", npc.name)

func unregister_npc(npc: NPCController):
	if npc in registered_npcs:
		registered_npcs.erase(npc)
		npc_positions.erase(npc.get_instance_id())
		
		# Disconnect signals
		if npc.player_spotted.is_connected(_on_npc_spotted_player):
			npc.player_spotted.disconnect(_on_npc_spotted_player)
		if npc.player_caught.is_connected(_on_npc_caught_player):
			npc.player_caught.disconnect(_on_npc_caught_player)

func _update_npc_positions():
	for npc in registered_npcs:
		if is_instance_valid(npc):
			npc_positions[npc.get_instance_id()] = npc.global_position

# ===================== ALERT SYSTEM =====================

func raise_alert(level: AlertLevel, position: Vector3, source: NPCController):
	var old_level = current_alert_level
	
	# Only escalate alerts, don't downgrade immediately
	if level > current_alert_level:
		current_alert_level = level
		alert_position = position
		alert_source = source
		alert_start_time = Time.get_time_dict_from_system()["unix"]
		
		print("NPCCommunicationManager: Alert raised to ", AlertLevel.keys()[level], " at ", position)
		global_alert_raised.emit(level, position, source)
		
		# Notify all NPCs about the alert
		_broadcast_alert_to_npcs(level, position, source)
	
	# Update shared memory with sighting
	_add_known_position(position, 1.0)  # High confidence from direct sighting

func clear_alert():
	if current_alert_level != AlertLevel.NONE:
		current_alert_level = AlertLevel.NONE
		alert_source = null
		print("NPCCommunicationManager: Alert cleared")
		global_alert_cleared.emit()
		
		# Notify all NPCs
		for npc in registered_npcs:
			if is_instance_valid(npc) and npc.has_method("receive_alert_cleared"):
				npc.receive_alert_cleared()

func _update_alert_system(delta: float):
	# Gradually reduce alert level over time
	if current_alert_level > AlertLevel.NONE:
		var time_since_alert = Time.get_time_dict_from_system()["unix"] - alert_start_time
		
		match current_alert_level:
			AlertLevel.HIGH:
				if time_since_alert > 30.0:  # 30 seconds of high alert
					current_alert_level = AlertLevel.MEDIUM
			AlertLevel.MEDIUM:
				if time_since_alert > 60.0:  # 1 minute total
					current_alert_level = AlertLevel.LOW
			AlertLevel.LOW:
				if time_since_alert > 120.0:  # 2 minutes total
					clear_alert()

func _broadcast_alert_to_npcs(level: AlertLevel, position: Vector3, source: NPCController):
	for npc in registered_npcs:
		if is_instance_valid(npc) and npc != source:
			# Check if NPC is in communication range or if alert is high enough
			var distance = npc.global_position.distance_to(source.global_position)
			var should_notify = false
			
			match level:
				AlertLevel.HIGH, AlertLevel.LOCKDOWN:
					should_notify = true  # All NPCs notified for high alerts
				AlertLevel.MEDIUM:
					should_notify = distance <= shared_memory.communication_range * 2.0
				AlertLevel.LOW:
					should_notify = distance <= shared_memory.communication_range
			
			if should_notify and npc.has_method("receive_communication"):
				var message = {
					"type": "alert",
					"level": level,
					"position": position,
					"source": source,
					"timestamp": Time.get_time_dict_from_system()["unix"]
				}
				npc.receive_communication(message)

# ===================== SHARED MEMORY SYSTEM =====================

func _add_known_position(position: Vector3, confidence: float):
	var timestamp = Time.get_time_dict_from_system()["unix"]
	var position_data = {
		"position": position,
		"timestamp": timestamp,
		"confidence": confidence
	}
	
	shared_memory.last_known_positions.append(position_data)
	
	# Keep only recent positions (last 5 minutes)
	var cutoff_time = timestamp - 300
	shared_memory.last_known_positions = shared_memory.last_known_positions.filter(
		func(pos_data): return pos_data.timestamp > cutoff_time
	)
	
	# Update suspicious areas
	_update_suspicious_areas(position, confidence)

func get_last_known_positions() -> Array:
	return shared_memory.last_known_positions.duplicate()

func get_most_likely_player_position() -> Vector3:
	if shared_memory.last_known_positions.is_empty():
		return Vector3.ZERO
	
	# Weight recent positions more heavily
	var current_time = Time.get_time_dict_from_system()["unix"]
	var weighted_position = Vector3.ZERO
	var total_weight = 0.0
	
	for pos_data in shared_memory.last_known_positions:
		var age = current_time - pos_data.timestamp
		var time_weight = exp(-age / 30.0)  # Exponential decay over 30 seconds
		var weight = pos_data.confidence * time_weight
		
		weighted_position += pos_data.position * weight
		total_weight += weight
	
	if total_weight > 0:
		return weighted_position / total_weight
	else:
		return shared_memory.last_known_positions[-1].position

func _update_suspicious_areas(position: Vector3, suspicion_increase: float):
	# Create grid-based suspicion map
	var grid_size = 4.0  # 4x4 meter grid cells
	var grid_x = int(position.x / grid_size)
	var grid_z = int(position.z / grid_size)
	var grid_key = str(grid_x) + "," + str(grid_z)
	
	if not shared_memory.suspicious_areas.has(grid_key):
		shared_memory.suspicious_areas[grid_key] = 0.0
	
	shared_memory.suspicious_areas[grid_key] += suspicion_increase
	shared_memory.suspicious_areas[grid_key] = min(shared_memory.suspicious_areas[grid_key], 10.0)

# ===================== COORDINATION SYSTEM =====================

func request_search_coordination(requesting_npc: NPCController) -> Vector3:
	# Coordinate search patterns to avoid overlap
	var search_position = Vector3.ZERO
	var best_priority = -1.0
	
	# Get areas that need searching, prioritized by suspicion level
	for grid_key in shared_memory.suspicious_areas:
		var suspicion = shared_memory.suspicious_areas[grid_key]
		
		# Check if this area was recently searched
		var last_search_time = shared_memory.search_coverage.get(grid_key, 0.0)
		var current_time = Time.get_time_dict_from_system()["unix"]
		var time_since_search = current_time - last_search_time
		
		# Priority based on suspicion level and time since last search
		var priority = suspicion * (1.0 + time_since_search / 60.0)  # Increases over time
		
		if priority > best_priority:
			best_priority = priority
			# Convert grid key back to world position
			var parts = grid_key.split(",")
			var grid_x = int(parts[0])
			var grid_z = int(parts[1])
			search_position = Vector3(grid_x * 4.0, 0, grid_z * 4.0)
	
	# Mark this area as being searched
	if search_position != Vector3.ZERO:
		var grid_key = str(int(search_position.x / 4.0)) + "," + str(int(search_position.z / 4.0))
		shared_memory.search_coverage[grid_key] = Time.get_time_dict_from_system()["unix"]
	
	return search_position

func get_nearby_npcs(position: Vector3, radius: float) -> Array[NPCController]:
	var nearby: Array[NPCController] = []
	for npc in registered_npcs:
		if is_instance_valid(npc) and position.distance_to(npc.global_position) <= radius:
			nearby.append(npc)
	return nearby

# ===================== LEARNING SYSTEM =====================

func _analyze_player_behavior(delta: float):
	# This would analyze player patterns over time
	# For now, just track basic metrics
	pass

func record_player_detection(position: Vector3, detection_time: float):
	# Record how long it took to detect player at this position
	var detection_record = {
		"position": position,
		"time": detection_time,
		"timestamp": Time.get_time_dict_from_system()["unix"]
	}
	player_behavior_data.detection_history.append(detection_record)
	
	# Update skill assessment based on detection time
	var skill_factor = 1.0 / (detection_time + 0.1)  # Faster detection = higher skill
	player_behavior_data.skill_assessment = lerp(player_behavior_data.skill_assessment, skill_factor, 0.1)

func get_player_skill_assessment() -> float:
	return player_behavior_data.skill_assessment

# ===================== EVENT HANDLERS =====================

func _on_npc_spotted_player(npc: NPCController):
	raise_alert(AlertLevel.HIGH, npc.global_position, npc)

func _on_npc_caught_player(npc: NPCController):
	raise_alert(AlertLevel.LOCKDOWN, npc.global_position, npc)

func _on_npc_state_changed(npc: NPCController, state_name: String):
	# Track NPC state changes for coordination
	pass

func _cleanup_old_data():
	var current_time = Time.get_time_dict_from_system()["unix"]
	var cutoff_time = current_time - 300  # 5 minutes
	
	# Clean up old position data
	shared_memory.last_known_positions = shared_memory.last_known_positions.filter(
		func(pos_data): return pos_data.timestamp > cutoff_time
	)
	
	# Decay suspicion in areas over time
	for grid_key in shared_memory.suspicious_areas.keys():
		shared_memory.suspicious_areas[grid_key] *= 0.95  # 5% decay
		if shared_memory.suspicious_areas[grid_key] < 0.1:
			shared_memory.suspicious_areas.erase(grid_key)
	
	# Clean up old search coverage data
	for grid_key in shared_memory.search_coverage.keys():
		if shared_memory.search_coverage[grid_key] < cutoff_time:
			shared_memory.search_coverage.erase(grid_key)