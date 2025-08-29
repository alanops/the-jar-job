extends Node

signal game_started()
signal game_over(reason: String)
signal game_won()
signal jar_collected()

enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	GAME_OVER,
	VICTORY
}

var current_state: GameState = GameState.MENU
var has_jar: bool = false
var game_timer: float = 0.0
var score: int = 0
var reset_delay: float

# Game Statistics
var stats = {
	"times_spotted": 0,
	"times_caught": 0,
	"times_suspected": 0,
	"distance_traveled": 0.0,
	"time_crouched": 0.0,
	"time_walking": 0.0,
	"interactions": 0,
	"camera_switches": 0,
	"game_resets": 0,
	"completion_time": 0.0,
	"final_score": 0,
	"victory_achieved": false,
	"biscuits_collected": 0,
	"secrets_found": 0,
	"secrets_by_rarity": {
		"Common": 0,
		"Rare": 0,
		"Legendary": 0
	},
	"secret_names": []
}

# Movement tracking
var last_player_position: Vector3
var is_tracking_movement: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_delay = GameConfig.game_reset_delay

func start_game() -> void:
	current_state = GameState.PLAYING
	has_jar = false
	game_timer = 0.0
	score = 0
	
	# Reset stats
	_reset_stats()
	is_tracking_movement = true
	
	# Reset NPC systems if they exist
	_reset_npc_systems()
	
	# Clear vision detection cache
	var vision_system = get_node_or_null("/root/VisionSystem")
	if vision_system and vision_system.has_method("clear_cache"):
		vision_system.clear_cache()
	
	game_started.emit()
	DebugLogger.info("Game started", "GameManager")

func _reset_npc_systems():
	"""Reset all NPC-related systems"""
	# Find NPC Manager in the scene
	var npc_manager = _find_npc_manager()
	if npc_manager and npc_manager.has_method("reset_all_systems"):
		npc_manager.reset_all_systems()

func _find_npc_manager() -> Node:
	"""Find NPCManager in the current scene"""
	var current_scene = get_tree().current_scene
	if current_scene:
		return current_scene.find_child("NPCManager", true, false)
	return null

func collect_jar() -> void:
	if current_state != GameState.PLAYING:
		return
	
	has_jar = true
	score += GameConfig.score_jar_collection
	jar_collected.emit()
	
	# Play pickup sound
	if AudioManager:
		AudioManager.play_item_pickup()
	
	DebugLogger.info("Biscuit jar collected! Score: %d" % score, "GameManager")

func trigger_game_over(reason: String = "You were spotted!") -> void:
	if current_state != GameState.PLAYING:
		return
	
	current_state = GameState.GAME_OVER
	is_tracking_movement = false
	
	# Update stats based on reason
	stats["completion_time"] = game_timer
	stats["final_score"] = score
	stats["victory_achieved"] = false
	
	if "spotted" in reason.to_lower():
		stats["times_spotted"] += 1
	elif "caught" in reason.to_lower():
		stats["times_caught"] += 1
	
	game_over.emit(reason)
	
	# Play game over sound
	if AudioManager:
		AudioManager.play_game_over()
	
	DebugLogger.info("Game Over: %s" % reason, "GameManager")
	
	# Show stats screen after a brief delay
	await get_tree().create_timer(2.0).timeout
	_show_stats_screen()

func trigger_victory() -> void:
	if current_state != GameState.PLAYING or not has_jar:
		return
	
	current_state = GameState.VICTORY
	is_tracking_movement = false
	var time_bonus: int = max(0, GameConfig.score_jar_collection - int(game_timer * GameConfig.score_time_bonus_multiplier))
	score += time_bonus
	
	# Update victory stats
	stats["completion_time"] = game_timer
	stats["final_score"] = score
	stats["victory_achieved"] = true
	
	game_won.emit()
	
	# Play victory sound
	if AudioManager:
		AudioManager.play_victory()
	
	DebugLogger.info("Victory! Final score: %d (Time bonus: %d)" % [score, time_bonus], "GameManager")
	
	# Show stats screen after a brief delay
	await get_tree().create_timer(3.0).timeout
	_show_stats_screen()

func _process(delta: float) -> void:
	if current_state == GameState.PLAYING:
		game_timer += delta
		_track_player_movement(delta)
	
	# Handle reset key
	if Input.is_action_just_pressed("reset"):
		reset_game()

func get_time_string() -> String:
	var minutes: int = int(game_timer) / 60
	var seconds: int = int(game_timer) % 60
	return "%02d:%02d" % [minutes, seconds]

func reset_game() -> void:
	# Track reset stat
	stats["game_resets"] += 1
	
	# Reset systems before reloading scene
	_reset_npc_systems()
	
	# Clear vision detection cache
	var vision_system = get_node_or_null("/root/VisionSystem")
	if vision_system and vision_system.has_method("clear_cache"):
		vision_system.clear_cache()
	
	DebugLogger.info("Resetting game scene", "GameManager")
	get_tree().reload_current_scene()

func return_to_menu() -> void:
	current_state = GameState.MENU
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# Stats tracking methods
func _reset_stats() -> void:
	stats = {
		"times_spotted": 0,
		"times_caught": 0,
		"times_suspected": 0,
		"distance_traveled": 0.0,
		"time_crouched": 0.0,
		"time_walking": 0.0,
		"interactions": 0,
		"camera_switches": 0,
		"game_resets": 0,
		"completion_time": 0.0,
		"final_score": 0,
		"victory_achieved": false,
		"biscuits_collected": 0,
		"secrets_found": 0,
		"secrets_by_rarity": {
			"Common": 0,
			"Rare": 0,
			"Legendary": 0
		},
		"secret_names": []
	}

func _track_player_movement(delta: float) -> void:
	if not is_tracking_movement:
		return
		
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var current_position = player.global_position
	
	if last_player_position != Vector3.ZERO:
		var distance = current_position.distance_to(last_player_position)
		stats["distance_traveled"] += distance
	
	last_player_position = current_position
	
	# Track movement states
	if player.has_method("get_is_crouching") and player.get_is_crouching():
		stats["time_crouched"] += delta
	else:
		stats["time_walking"] += delta

func track_interaction() -> void:
	stats["interactions"] += 1

func track_camera_switch() -> void:
	stats["camera_switches"] += 1

func track_suspicion_raised() -> void:
	stats["times_suspected"] += 1

func track_biscuit_collected() -> void:
	stats["biscuits_collected"] += 1

func track_secret_collected(secret_name: String, rarity: String) -> void:
	stats["secrets_found"] += 1
	stats["secrets_by_rarity"][rarity] += 1
	stats["secret_names"].append(secret_name)

func get_stats() -> Dictionary:
	return stats.duplicate()

func get_stats_summary() -> String:
	var time_str = get_time_string()
	var distance_m = stats["distance_traveled"]
	var speed = distance_m / max(game_timer, 0.1)
	
	var secret_summary = ""
	if stats["secrets_found"] > 0:
		secret_summary = "\n🗝️ Secrets Found: %d (C:%d R:%d L:%d)" % [
			stats["secrets_found"],
			stats["secrets_by_rarity"]["Common"],
			stats["secrets_by_rarity"]["Rare"],
			stats["secrets_by_rarity"]["Legendary"]
		]
	
	return """GAME STATISTICS
	
🎯 Result: %s
⏱️ Time: %s
🏆 Score: %d
📏 Distance: %.1fm
🚶 Speed: %.1fm/s
🍪 Biscuits: %d
👁️ Times Spotted: %d
🤐 Times Suspected: %d  
🔄 Camera Switches: %d
🎮 Interactions: %d
♻️ Resets Used: %d%s""" % [
		"VICTORY" if stats["victory_achieved"] else "DEFEAT",
		time_str,
		stats["final_score"],
		distance_m,
		speed,
		stats["biscuits_collected"],
		stats["times_spotted"],
		stats["times_suspected"],
		stats["camera_switches"],
		stats["interactions"],
		stats["game_resets"],
		secret_summary
	]

func _show_stats_screen() -> void:
	# Load and show the stats screen
	var stats_screen_scene = preload("res://ui/stats_screen.tscn")
	var stats_screen = stats_screen_scene.instantiate()
	
	# Add to current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(stats_screen)
		stats_screen.z_index = 100  # Make sure it's on top
