extends Node
class_name NPCManager

# Singleton NPC management system for coordinating multiple NPCs

signal all_npcs_alerted
signal npc_spotted_player(npc: NPCController)
signal npc_lost_player(npc: NPCController)

# NPC registry
var registered_npcs: Array[NPCController] = []
var npc_count: int = 0

# Global alert system
var global_alert_level: int = 0  # 0=calm, 1=suspicious, 2=searching, 3=full_alert
var last_known_player_position: Vector3 = Vector3.ZERO
var alert_timer: float = 0.0
var alert_decay_time: float = 30.0  # Time before alert level decreases

# Communication system
var alert_messages: Array = []
var max_alert_messages: int = 10

# Performance optimization
var update_interval: float = 0.1
var update_timer: float = 0.0

func _ready():
	# Set up as singleton if needed
	set_process(true)
	print("NPCManager: Initialized")

func _process(delta):
	update_timer += delta
	if update_timer >= update_interval:
		update_timer = 0.0
		_update_npc_coordination(delta * 10)  # Pass accumulated delta
	
	# Handle alert decay
	if global_alert_level > 0:
		alert_timer += delta
		if alert_timer >= alert_decay_time:
			_decay_alert_level()

func register_npc(npc: NPCController) -> void:
	"""Register an NPC with the manager system"""
	if not registered_npcs.has(npc):
		registered_npcs.append(npc)
		npc_count = registered_npcs.size()
		
		# Connect NPC signals
		npc.player_spotted.connect(_on_npc_spotted_player.bind(npc))
		npc.player_lost.connect(_on_npc_lost_player.bind(npc))
		npc.suspicion_raised.connect(_on_npc_suspicion_raised.bind(npc))
		
		print("NPCManager: Registered NPC ", npc.name, " (Total: ", npc_count, ")")

func unregister_npc(npc: NPCController) -> void:
	"""Unregister an NPC from the manager system"""
	if registered_npcs.has(npc):
		registered_npcs.erase(npc)
		npc_count = registered_npcs.size()
		
		# Disconnect signals if still valid
		if is_instance_valid(npc):
			if npc.player_spotted.is_connected(_on_npc_spotted_player):
				npc.player_spotted.disconnect(_on_npc_spotted_player)
			if npc.player_lost.is_connected(_on_npc_lost_player):
				npc.player_lost.disconnect(_on_npc_lost_player)
			if npc.suspicion_raised.is_connected(_on_npc_suspicion_raised):
				npc.suspicion_raised.disconnect(_on_npc_suspicion_raised)
		
		print("NPCManager: Unregistered NPC ", npc.name, " (Remaining: ", npc_count, ")")

func _update_npc_coordination(delta: float) -> void:
	"""Coordinate behavior between NPCs"""
	if npc_count < 2:
		return
	
	# Share information between nearby NPCs
	for i in range(npc_count):
		for j in range(i + 1, npc_count):
			var npc1 = registered_npcs[i]
			var npc2 = registered_npcs[j]
			
			if not is_instance_valid(npc1) or not is_instance_valid(npc2):
				continue
				
			var distance = npc1.global_position.distance_to(npc2.global_position)
			
			# Share information if NPCs are close
			if distance < 15.0:  # Communication range
				_share_information(npc1, npc2)

func _share_information(npc1: NPCController, npc2: NPCController) -> void:
	"""Share information between two NPCs"""
	# Share alert levels
	if npc1.suspicion_level > npc2.suspicion_level:
		npc2.suspicion_level = min(npc2.suspicion_level + 10.0, npc1.suspicion_level * 0.5)
	elif npc2.suspicion_level > npc1.suspicion_level:
		npc1.suspicion_level = min(npc1.suspicion_level + 10.0, npc2.suspicion_level * 0.5)
	
	# Share last known player positions
	if npc1.last_known_player_position != Vector3.ZERO and npc2.last_known_player_position == Vector3.ZERO:
		npc2.last_known_player_position = npc1.last_known_player_position
		npc2.investigation_position = npc1.last_known_player_position
	elif npc2.last_known_player_position != Vector3.ZERO and npc1.last_known_player_position == Vector3.ZERO:
		npc1.last_known_player_position = npc2.last_known_player_position
		npc1.investigation_position = npc2.last_known_player_position

func broadcast_alert(position: Vector3, alert_type: String, severity: int = 1) -> void:
	"""Broadcast an alert to all NPCs"""
	last_known_player_position = position
	global_alert_level = max(global_alert_level, severity)
	alert_timer = 0.0
	
	var alert_message = {
		"position": position,
		"type": alert_type,
		"severity": severity,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Add to message queue
	alert_messages.append(alert_message)
	if alert_messages.size() > max_alert_messages:
		alert_messages.pop_front()
	
	# Notify all NPCs
	for npc in registered_npcs:
		if is_instance_valid(npc):
			npc.receive_alert(alert_message)
	
	print("NPCManager: Broadcasting ", alert_type, " alert at ", position, " (Level ", severity, ")")

func _decay_alert_level() -> void:
	"""Gradually reduce alert level over time"""
	global_alert_level = max(0, global_alert_level - 1)
	alert_timer = 0.0
	
	if global_alert_level == 0:
		last_known_player_position = Vector3.ZERO
		print("NPCManager: Alert level decayed to calm")

func get_nearest_npc_to_position(pos: Vector3) -> NPCController:
	"""Find the NPC closest to a given position"""
	var nearest_npc: NPCController = null
	var min_distance: float = INF
	
	for npc in registered_npcs:
		if not is_instance_valid(npc):
			continue
			
		var distance = npc.global_position.distance_to(pos)
		if distance < min_distance:
			min_distance = distance
			nearest_npc = npc
	
	return nearest_npc

func get_npcs_in_area(center: Vector3, radius: float) -> Array[NPCController]:
	"""Get all NPCs within a specified area"""
	var npcs_in_area: Array[NPCController] = []
	
	for npc in registered_npcs:
		if not is_instance_valid(npc):
			continue
			
		if npc.global_position.distance_to(center) <= radius:
			npcs_in_area.append(npc)
	
	return npcs_in_area

func get_alert_status() -> Dictionary:
	"""Get current alert system status"""
	return {
		"global_alert_level": global_alert_level,
		"last_known_position": last_known_player_position,
		"active_npcs": npc_count,
		"recent_alerts": alert_messages.slice(-5)  # Last 5 alerts
	}

func reset_all_systems() -> void:
	"""Reset all NPC Manager systems to initial state"""
	# Reset global alert system
	global_alert_level = 0
	last_known_player_position = Vector3.ZERO
	alert_timer = 0.0
	
	# Clear all alert messages
	alert_messages.clear()
	
	# Reset all registered NPCs
	for npc in registered_npcs:
		if is_instance_valid(npc) and npc.has_method("reset_npc_state"):
			npc.reset_npc_state()
	
	print("NPCManager: All systems reset to initial state")

# Signal handlers
func _on_npc_spotted_player(npc: NPCController) -> void:
	broadcast_alert(npc.last_known_player_position, "PLAYER_SPOTTED", 3)
	npc_spotted_player.emit(npc)

func _on_npc_lost_player(npc: NPCController) -> void:
	if npc.last_known_player_position != Vector3.ZERO:
		broadcast_alert(npc.last_known_player_position, "PLAYER_LOST", 2)
	npc_lost_player.emit(npc)

func _on_npc_suspicion_raised(npc: NPCController, level: float) -> void:
	if level > npc.suspicious_threshold:
		var severity = 1 if level < npc.investigate_threshold else 2
		broadcast_alert(npc.global_position, "SUSPICIOUS_ACTIVITY", severity)