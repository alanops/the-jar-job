extends Node

# Audio streams
@export var ambient_sound: AudioStream
@export var footstep_sound: AudioStream
@export var button_click_sound: AudioStream
@export var item_pickup_sound: AudioStream
@export var victory_sound: AudioStream
@export var alert_suspicious_sound: AudioStream
@export var alert_chase_sound: AudioStream
@export var detected_sound: AudioStream

# Audio players
@onready var ambient_player: AudioStreamPlayer
@onready var sfx_players: Array[AudioStreamPlayer] = []
@onready var npc_alert_players: Array[AudioStreamPlayer] = []
@onready var ui_player: AudioStreamPlayer

# Audio player pool settings
const SFX_PLAYER_POOL_SIZE = 8
const NPC_ALERT_POOL_SIZE = 4

# Prevent spam of NPC alert sounds
var last_suspicious_alert_time: float = 0.0
var last_chase_alert_time: float = 0.0
const ALERT_SOUND_COOLDOWN: float = 0.5  # Minimum time between same alert sounds

# Volume settings - loaded from GameConfig
var master_volume: float
var sfx_volume: float
var ambient_volume: float

var is_ambient_playing: bool = false

func _ready():
	if DebugLogger:
		DebugLogger.info("AudioManager _ready() starting", "AudioManager")
	
	# Load configuration
	_load_config_values()
	
	# Create audio players if they don't exist
	create_audio_players()
	
	# Load audio
	load_audio_resources()
	
	# Set initial volumes
	set_volumes()
	
	# Start ambient sounds
	play_ambient()
	
	if DebugLogger:
		DebugLogger.info("AudioManager initialized successfully", "AudioManager")

func _load_config_values() -> void:
	master_volume = GameConfig.audio_master_volume
	sfx_volume = GameConfig.audio_sfx_volume
	ambient_volume = GameConfig.audio_ambient_volume

func create_audio_players():
	
	# Ambient player
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientPlayer"
	ambient_player.bus = "Ambient"
	add_child(ambient_player)
	
	# SFX player pool
	for i in range(SFX_PLAYER_POOL_SIZE):
		var sfx_player = AudioStreamPlayer.new()
		sfx_player.name = "SFXPlayer" + str(i)
		sfx_player.bus = "SFX"
		sfx_players.append(sfx_player)
		add_child(sfx_player)
	
	# NPC alert player pool (separate from general SFX to avoid conflicts)
	for i in range(NPC_ALERT_POOL_SIZE):
		var npc_alert_player = AudioStreamPlayer.new()
		npc_alert_player.name = "NPCAlertPlayer" + str(i)
		npc_alert_player.bus = "SFX"
		npc_alert_players.append(npc_alert_player)
		add_child(npc_alert_player)
	
	# UI player
	ui_player = AudioStreamPlayer.new()
	ui_player.name = "UIPlayer"
	ui_player.bus = "UI"
	add_child(ui_player)

func load_audio_resources():
	var audio_files = {
		"ambient_sound": "res://assets/audio/ambient.ogg",
		"footstep_sound": "res://assets/audio/footstep.ogg",
		"button_click_sound": "res://assets/audio/button_click.ogg",
		"item_pickup_sound": "res://assets/audio/item_pickup.ogg",
		"victory_sound": "res://assets/audio/victory.ogg",
		"alert_suspicious_sound": "res://assets/audio/alert_suspicious.ogg",
		"alert_chase_sound": "res://assets/audio/alert_chase.ogg",
		"detected_sound": "res://assets/audio/detected.wav"
	}
	
	var loaded_count = 0
	for prop_name in audio_files:
		var file_path = audio_files[prop_name]
		var resource = load(file_path)
		if resource:
			set(prop_name, resource)
			loaded_count += 1
		else:
			if DebugLogger:
				DebugLogger.warning("Failed to load audio file: %s" % file_path, "AudioManager")
	
	if DebugLogger:
		DebugLogger.info("Loaded %d/%d audio resources" % [loaded_count, audio_files.size()], "AudioManager")

func set_volumes():
	if ambient_player:
		ambient_player.volume_db = linear_to_db(master_volume * ambient_volume)
	
	# Set volume for all SFX players
	for player in sfx_players:
		if player:
			player.volume_db = linear_to_db(master_volume * sfx_volume)
	
	# Set volume for all NPC alert players
	for player in npc_alert_players:
		if player:
			player.volume_db = linear_to_db(master_volume * sfx_volume)
	
	if ui_player:
		ui_player.volume_db = linear_to_db(master_volume * sfx_volume)

# Helper functions to get available players from pools
func get_available_sfx_player() -> AudioStreamPlayer:
	for player in sfx_players:
		if player and not player.playing:
			return player
	# If all are playing, return the first one (oldest sound will be interrupted)
	return sfx_players[0] if sfx_players.size() > 0 else null

func get_available_npc_alert_player() -> AudioStreamPlayer:
	for player in npc_alert_players:
		if player and not player.playing:
			return player
	# If all are playing, return the first one (oldest sound will be interrupted)
	return npc_alert_players[0] if npc_alert_players.size() > 0 else null

# Ambient sound control
func play_ambient():
	if ambient_sound and ambient_player and not is_ambient_playing:
		ambient_player.stream = ambient_sound
		ambient_player.play()
		is_ambient_playing = true

func stop_ambient():
	if ambient_player:
		ambient_player.stop()
		is_ambient_playing = false

# Sound effects
func play_footstep():
	if footstep_sound:
		var player = get_available_sfx_player()
		if player:
			player.stream = footstep_sound
			player.play()

func play_button_click():
	if button_click_sound and ui_player:
		ui_player.stream = button_click_sound
		ui_player.play()

func play_item_pickup():
	if item_pickup_sound:
		var player = get_available_sfx_player()
		if player:
			player.stream = item_pickup_sound
			player.play()

func play_victory():
	if victory_sound:
		await get_tree().create_timer(1.0).timeout
		var player = get_available_sfx_player()
		if player:
			player.stream = victory_sound
			player.play()

func play_alert_suspicious():
	if DebugLogger:
		DebugLogger.info("play_alert_suspicious called", "AudioManager")
	
	# Check cooldown to prevent spam
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_suspicious_alert_time < ALERT_SOUND_COOLDOWN:
		if DebugLogger:
			DebugLogger.debug("Suspicious alert sound on cooldown, skipping", "AudioManager")
		return
	
	if alert_suspicious_sound:
		var player = get_available_npc_alert_player()
		if player:
			if DebugLogger:
				DebugLogger.info("Playing suspicious alert sound with available player", "AudioManager")
			player.stream = alert_suspicious_sound
			player.play()
			last_suspicious_alert_time = current_time
		else:
			if DebugLogger:
				DebugLogger.warning("No available NPC alert player for suspicious sound", "AudioManager")
	else:
		if DebugLogger:
			DebugLogger.warning("Cannot play suspicious alert: alert_suspicious_sound is null", "AudioManager")

func play_alert_chase():
	if DebugLogger:
		DebugLogger.info("play_alert_chase called", "AudioManager")
	
	# Check cooldown to prevent spam
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_chase_alert_time < ALERT_SOUND_COOLDOWN:
		if DebugLogger:
			DebugLogger.debug("Chase alert sound on cooldown, skipping", "AudioManager")
		return
	
	if alert_chase_sound:
		var player = get_available_npc_alert_player()
		if player:
			if DebugLogger:
				DebugLogger.info("Playing chase alert sound with available player", "AudioManager")
			player.stream = alert_chase_sound
			player.play()
			last_chase_alert_time = current_time
		else:
			if DebugLogger:
				DebugLogger.warning("No available NPC alert player for chase sound", "AudioManager")
	else:
		if DebugLogger:
			DebugLogger.warning("Cannot play chase alert: alert_chase_sound is null", "AudioManager")


func play_detected():
	if detected_sound:
		var player = get_available_sfx_player()
		if player:
			player.stream = detected_sound
			player.play()

func play_game_over():
	# Stop all other audio
	stop_all_audio()
	# Play detected sound as game over sound
	if detected_sound:
		var player = get_available_sfx_player()
		if player:
			player.stream = detected_sound
			player.play()

func stop_all_audio():
	if ambient_player:
		ambient_player.stop()
	
	# Stop all SFX players
	for player in sfx_players:
		if player:
			player.stop()
	
	# Stop all NPC alert players
	for player in npc_alert_players:
		if player:
			player.stop()
	
	if ui_player:
		ui_player.stop()
	
	is_ambient_playing = false

# Volume controls
func set_master_volume(volume: float):
	master_volume = clamp(volume, 0.0, 1.0)
	set_volumes()


func set_sfx_volume(volume: float):
	sfx_volume = clamp(volume, 0.0, 1.0)
	set_volumes()

func set_ambient_volume(volume: float):
	ambient_volume = clamp(volume, 0.0, 1.0)
	set_volumes()

# Save/load settings
func save_audio_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "ambient_volume", ambient_volume)
	config.save("user://audio_settings.cfg")

func load_audio_settings():
	var config = ConfigFile.new()
	var err = config.load("user://audio_settings.cfg")
	
	if err == OK:
		master_volume = config.get_value("audio", "master_volume", 0.8)
		sfx_volume = config.get_value("audio", "sfx_volume", 0.8)
		ambient_volume = config.get_value("audio", "ambient_volume", 0.4)
		set_volumes()
