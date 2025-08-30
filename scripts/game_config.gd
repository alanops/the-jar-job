extends Node

# Singleton for managing game configuration constants
# All gameplay-related constants should be defined here

# === PLAYER SETTINGS ===
var player_walk_speed: float = 5.0
var player_run_speed: float = 8.0
var player_crouch_speed: float = 2.0
var player_crouch_height: float = 0.9
var player_normal_height: float = 1.8

# Noise settings
var noise_radius_walk: float = 5.0
var noise_radius_run: float = 8.0
var noise_radius_crouch: float = 2.0

# === NPC SETTINGS ===
# Movement speeds
var npc_patrol_speed: float = 1.5
var npc_suspicious_speed: float = 1.0
var npc_investigate_speed: float = 2.0
var npc_chase_speed: float = 3.0
var npc_search_speed: float = 1.8
var npc_turn_speed: float = 2.0

# Timing
var npc_wait_time_at_waypoint: float = 2.0
var npc_suspicious_time: float = 2.0
var npc_investigation_time: float = 3.0
var npc_search_time: float = 5.0

# Suspicion system
var npc_max_suspicion: float = 100.0
var npc_suspicion_gain_rate: float = 25.0
var npc_suspicion_decay_rate: float = 15.0
var npc_suspicious_threshold: float = 30.0
var npc_investigate_threshold: float = 60.0

# Detection system
var npc_catch_distance: float = 1.2
var npc_detection_threshold: float = 0.5
var npc_close_detection_range: float = 2.0
var npc_peripheral_vision_range: float = 6.0
var npc_peripheral_vision_angle: float = 60.0

# Vision checking optimization
var vision_check_intervals: Dictionary = {
	"very_far": 0.2,   # > 15.0 units
	"far": 0.1,        # > 10.0 units  
	"medium": 0.05,    # > 5.0 units
	"close": 0.02      # <= 5.0 units
}

var vision_distance_thresholds: Dictionary = {
	"very_far": 15.0,
	"far": 10.0,
	"medium": 5.0
}

# === AUDIO SETTINGS ===
var audio_master_volume: float = 0.8
var audio_music_volume: float = 0.6
var audio_sfx_volume: float = 0.8
var audio_ambient_volume: float = 0.4

# === PERFORMANCE SETTINGS ===
var enable_performance_monitoring: bool = true
var enable_vision_debug: bool = false
var max_concurrent_vision_checks: int = 3
var enable_npc_learning: bool = true
var enable_npc_communication: bool = true

# === GAME SETTINGS ===
var score_jar_collection: int = 1000
var score_time_bonus_multiplier: int = 10
var game_reset_delay: float = 1.0

var config_file_path: String = "user://game_config.cfg"

func _ready() -> void:
	name = "GameConfig"
	load_config()

func load_config() -> void:
	var config = ConfigFile.new()
	var err = config.load(config_file_path)
	
	if err != OK:
		DebugLogger.info("No config file found, using defaults", "GameConfig")
		save_config() # Create default config file
		return
	
	# Load player settings
	player_walk_speed = config.get_value("player", "walk_speed", player_walk_speed)
	player_run_speed = config.get_value("player", "run_speed", player_run_speed)
	player_crouch_speed = config.get_value("player", "crouch_speed", player_crouch_speed)
	
	noise_radius_walk = config.get_value("player", "noise_radius_walk", noise_radius_walk)
	noise_radius_run = config.get_value("player", "noise_radius_run", noise_radius_run)
	noise_radius_crouch = config.get_value("player", "noise_radius_crouch", noise_radius_crouch)
	
	# Load NPC settings
	npc_patrol_speed = config.get_value("npc", "patrol_speed", npc_patrol_speed)
	npc_chase_speed = config.get_value("npc", "chase_speed", npc_chase_speed)
	npc_detection_threshold = config.get_value("npc", "detection_threshold", npc_detection_threshold)
	npc_catch_distance = config.get_value("npc", "catch_distance", npc_catch_distance)
	
	# Load suspicion settings
	npc_max_suspicion = config.get_value("npc", "max_suspicion", npc_max_suspicion)
	npc_suspicion_gain_rate = config.get_value("npc", "suspicion_gain_rate", npc_suspicion_gain_rate)
	npc_suspicion_decay_rate = config.get_value("npc", "suspicion_decay_rate", npc_suspicion_decay_rate)
	
	# Load audio settings
	audio_master_volume = config.get_value("audio", "master_volume", audio_master_volume)
	audio_music_volume = config.get_value("audio", "music_volume", audio_music_volume)
	audio_sfx_volume = config.get_value("audio", "sfx_volume", audio_sfx_volume)
	audio_ambient_volume = config.get_value("audio", "ambient_volume", audio_ambient_volume)
	
	# Load performance settings
	enable_performance_monitoring = config.get_value("performance", "enable_monitoring", enable_performance_monitoring)
	enable_vision_debug = config.get_value("performance", "enable_vision_debug", enable_vision_debug)
	max_concurrent_vision_checks = config.get_value("performance", "max_vision_checks", max_concurrent_vision_checks)
	
	DebugLogger.info("Configuration loaded successfully", "GameConfig")

func save_config() -> void:
	var config = ConfigFile.new()
	
	# Player settings
	config.set_value("player", "walk_speed", player_walk_speed)
	config.set_value("player", "run_speed", player_run_speed)
	config.set_value("player", "crouch_speed", player_crouch_speed)
	config.set_value("player", "crouch_height", player_crouch_height)
	config.set_value("player", "normal_height", player_normal_height)
	
	config.set_value("player", "noise_radius_walk", noise_radius_walk)
	config.set_value("player", "noise_radius_run", noise_radius_run)
	config.set_value("player", "noise_radius_crouch", noise_radius_crouch)
	
	# NPC settings
	config.set_value("npc", "patrol_speed", npc_patrol_speed)
	config.set_value("npc", "suspicious_speed", npc_suspicious_speed)
	config.set_value("npc", "investigate_speed", npc_investigate_speed)
	config.set_value("npc", "chase_speed", npc_chase_speed)
	config.set_value("npc", "search_speed", npc_search_speed)
	config.set_value("npc", "turn_speed", npc_turn_speed)
	
	config.set_value("npc", "detection_threshold", npc_detection_threshold)
	config.set_value("npc", "catch_distance", npc_catch_distance)
	config.set_value("npc", "close_detection_range", npc_close_detection_range)
	config.set_value("npc", "peripheral_vision_range", npc_peripheral_vision_range)
	config.set_value("npc", "peripheral_vision_angle", npc_peripheral_vision_angle)
	
	# Suspicion system
	config.set_value("npc", "max_suspicion", npc_max_suspicion)
	config.set_value("npc", "suspicion_gain_rate", npc_suspicion_gain_rate)
	config.set_value("npc", "suspicion_decay_rate", npc_suspicion_decay_rate)
	config.set_value("npc", "suspicious_threshold", npc_suspicious_threshold)
	config.set_value("npc", "investigate_threshold", npc_investigate_threshold)
	
	# Audio settings
	config.set_value("audio", "master_volume", audio_master_volume)
	config.set_value("audio", "music_volume", audio_music_volume)
	config.set_value("audio", "sfx_volume", audio_sfx_volume)
	config.set_value("audio", "ambient_volume", audio_ambient_volume)
	
	# Performance settings
	config.set_value("performance", "enable_monitoring", enable_performance_monitoring)
	config.set_value("performance", "enable_vision_debug", enable_vision_debug)
	config.set_value("performance", "max_vision_checks", max_concurrent_vision_checks)
	config.set_value("performance", "enable_npc_learning", enable_npc_learning)
	config.set_value("performance", "enable_npc_communication", enable_npc_communication)
	
	# Game settings
	config.set_value("game", "score_jar_collection", score_jar_collection)
	config.set_value("game", "score_time_bonus_multiplier", score_time_bonus_multiplier)
	config.set_value("game", "game_reset_delay", game_reset_delay)
	
	var err = config.save(config_file_path)
	if err == OK:
		DebugLogger.info("Configuration saved successfully", "GameConfig")
	else:
		DebugLogger.error("Failed to save configuration: " + str(err), "GameConfig")

# Convenience methods for getting vision check intervals
func get_vision_check_interval(distance: float) -> float:
	if distance > vision_distance_thresholds.very_far:
		return vision_check_intervals.very_far
	elif distance > vision_distance_thresholds.far:
		return vision_check_intervals.far
	elif distance > vision_distance_thresholds.medium:
		return vision_check_intervals.medium
	else:
		return vision_check_intervals.close

# Method to validate and clamp configuration values
func validate_config() -> void:
	# Clamp values to reasonable ranges
	player_walk_speed = clamp(player_walk_speed, 1.0, 10.0)
	player_run_speed = clamp(player_run_speed, 2.0, 15.0)
	player_crouch_speed = clamp(player_crouch_speed, 0.5, 5.0)
	
	npc_patrol_speed = clamp(npc_patrol_speed, 0.5, 5.0)
	npc_chase_speed = clamp(npc_chase_speed, 1.0, 10.0)
	npc_detection_threshold = clamp(npc_detection_threshold, 0.1, 3.0)
	
	audio_master_volume = clamp(audio_master_volume, 0.0, 1.0)
	audio_music_volume = clamp(audio_music_volume, 0.0, 1.0)
	audio_sfx_volume = clamp(audio_sfx_volume, 0.0, 1.0)
	audio_ambient_volume = clamp(audio_ambient_volume, 0.0, 1.0)
	
	DebugLogger.info("Configuration validated and clamped", "GameConfig")
