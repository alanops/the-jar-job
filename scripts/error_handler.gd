extends Node

# Global error handling and recovery system

signal critical_error_occurred(error_info: Dictionary)

var error_count: int = 0
var last_error_time: float = 0.0
var error_rate_limit: int = 10  # Max errors per minute
var recovery_attempts: Dictionary = {}

func _ready() -> void:
	name = "ErrorHandler"
	
	# Connect to engine error signals if available
	if get_tree().has_signal("node_added"):
		get_tree().connect("node_added", _on_node_added)

func handle_error(error_message: String, source: String, severity: String = "ERROR", context: Dictionary = {}) -> void:
	var error_info = {
		"message": error_message,
		"source": source,
		"severity": severity,
		"context": context,
		"timestamp": Time.get_unix_time_from_system(),
		"stack_trace": get_stack()
	}
	
	# Rate limiting
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_error_time < 60.0:  # Within last minute
		error_count += 1
		if error_count > error_rate_limit:
			DebugLogger.warning("Error rate limit exceeded, suppressing further errors", "ErrorHandler")
			return
	else:
		error_count = 1
		last_error_time = current_time
	
	# Log the error
	match severity.to_upper():
		"DEBUG":
			DebugLogger.debug("%s: %s" % [source, error_message], "ErrorHandler")
		"WARNING":
			DebugLogger.warning("%s: %s" % [source, error_message], "ErrorHandler")
		"ERROR":
			DebugLogger.error("%s: %s" % [source, error_message], "ErrorHandler")
		"CRITICAL":
			DebugLogger.error("CRITICAL - %s: %s" % [source, error_message], "ErrorHandler")
			critical_error_occurred.emit(error_info)
	
	# Attempt recovery for known error types in the background
	_attempt_recovery(error_info)

func _attempt_recovery(error_info: Dictionary) -> void:
	var error_key = "%s:%s" % [error_info.source, error_info.message]
	var attempts = recovery_attempts.get(error_key, 0)
	
	# Limit recovery attempts
	if attempts >= 3:
		DebugLogger.warning("Max recovery attempts reached for: %s" % error_key, "ErrorHandler")
		return
	
	recovery_attempts[error_key] = attempts + 1
	
	# Recovery strategies based on source and error type
	match error_info.source:
		"NPCController":
			_recover_npc_error(error_info)
		"PlayerController":
			_recover_player_error(error_info)
		"AudioManager":
			_recover_audio_error(error_info)
		"VisionSystem":
			_recover_vision_error(error_info)
		_:
			_generic_recovery(error_info)

func _recover_npc_error(error_info: Dictionary) -> void:
	var message = error_info.message.to_lower()
	
	if "navigation" in message or "pathfinding" in message:
		DebugLogger.info("Attempting NPC navigation recovery", "ErrorHandler")
		# Try to reset navigation system
		_reset_navigation_system()
		return
	
	if "vision" in message or "raycast" in message:
		DebugLogger.info("Attempting NPC vision system recovery", "ErrorHandler")
		# Clear vision detection cache  
		var vision_system = get_node_or_null("/root/VisionSystem")
		if vision_system and vision_system.has_method("clear_cache"):
			vision_system.clear_cache()
		return

func _recover_player_error(error_info: Dictionary) -> void:
	var message = error_info.message.to_lower()
	
	if "collision" in message or "shape" in message:
		DebugLogger.info("Attempting player collision recovery", "ErrorHandler")
		# Try to reset player collision shape
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("_initialize_collision_shape"):
			player._initialize_collision_shape()
			return

func _recover_audio_error(error_info: Dictionary) -> void:
	var message = error_info.message.to_lower()
	
	if "load" in message or "resource" in message:
		DebugLogger.info("Attempting audio resource recovery", "ErrorHandler")
		# Try to reload audio resources
		if AudioManager and AudioManager.has_method("load_audio_resources"):
			AudioManager.load_audio_resources()
			return
	
	if "player" in message or "stream" in message:
		DebugLogger.info("Attempting audio player recovery", "ErrorHandler")
		# Try to recreate audio players
		if AudioManager and AudioManager.has_method("create_audio_players"):
			AudioManager.create_audio_players()
			return

func _recover_vision_error(error_info: Dictionary) -> void:
	DebugLogger.info("Attempting vision system recovery", "ErrorHandler")
	
	var vision_system = get_node_or_null("/root/VisionSystem")
	if vision_system and vision_system.has_method("clear_cache"):
		vision_system.clear_cache()
		return

func _generic_recovery(error_info: Dictionary) -> void:
	# Generic recovery strategies
	var message = error_info.message.to_lower()
	
	if "null" in message or "freed" in message:
		DebugLogger.info("Attempting null reference recovery", "ErrorHandler")
		# Try to trigger a scene refresh
		await get_tree().process_frame
		return
	
	if "timeout" in message or "connection" in message:
		DebugLogger.info("Attempting connection recovery", "ErrorHandler")
		# Wait and retry
		await get_tree().create_timer(0.1).timeout
		return

func _reset_navigation_system() -> void:
	# Reset navigation system for all NPCs
	var npcs = get_tree().get_nodes_in_group("npcs")
	for npc in npcs:
		if npc.has_method("reset_npc_state"):
			npc.reset_npc_state()

func _on_node_added(node: Node) -> void:
	# Monitor for nodes that might need error handling
	if node is NPCController:
		_setup_npc_error_monitoring(node)
	elif node is PlayerController:
		_setup_player_error_monitoring(node)

func _setup_npc_error_monitoring(npc: NPCController) -> void:
	# Connect to NPC error signals if they exist
	if npc.has_signal("error_occurred"):
		npc.connect("error_occurred", handle_error)

func _setup_player_error_monitoring(player: PlayerController) -> void:
	# Connect to player error signals if they exist
	if player.has_signal("error_occurred"):
		player.connect("error_occurred", handle_error)

func get_error_statistics() -> Dictionary:
	return {
		"total_errors": error_count,
		"last_error_time": last_error_time,
		"recovery_attempts": recovery_attempts.size(),
		"active_recoveries": recovery_attempts
	}

func clear_error_history() -> void:
	error_count = 0
	last_error_time = 0.0
	recovery_attempts.clear()
	DebugLogger.info("Error history cleared", "ErrorHandler")

# Helper function for other scripts to use
static func safe_call(object: Object, method: String, args: Array = []) -> Variant:
	if not is_instance_valid(object):
		if ErrorHandler:
			ErrorHandler.handle_error("Attempted to call method on invalid object", "ErrorHandler", "WARNING")
		return null
	
	if not object.has_method(method):
		if ErrorHandler:
			ErrorHandler.handle_error("Method '%s' not found on object" % method, "ErrorHandler", "WARNING")
		return null
	
	return object.callv(method, args)

static func safe_get(object: Object, property: String) -> Variant:
	if not is_instance_valid(object):
		return null
	
	if object.get(property) == null:
		return null
	
	return object.get(property)
