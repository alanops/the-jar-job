extends Node

# Audio streams
@export var background_music: AudioStream
@export var ambient_sound: AudioStream
@export var footstep_sound: AudioStream
@export var button_click_sound: AudioStream
@export var door_sound: AudioStream
@export var door_open_sound: AudioStream
@export var door_close_sound: AudioStream
@export var item_pickup_sound: AudioStream
@export var victory_sound: AudioStream
@export var alert_sound: AudioStream
@export var alert_suspicious_sound: AudioStream
@export var alert_chase_sound: AudioStream
@export var detected_sound: AudioStream

# Audio players
@onready var music_player: AudioStreamPlayer
@onready var ambient_player: AudioStreamPlayer
@onready var sfx_player: AudioStreamPlayer
@onready var npc_alert_player: AudioStreamPlayer
@onready var ui_player: AudioStreamPlayer

# Volume settings - loaded from GameConfig
var master_volume: float
var music_volume: float
var sfx_volume: float
var ambient_volume: float

var is_music_playing: bool = false
var is_ambient_playing: bool = false

func _ready():
	if DebugLogger:
		DebugLogger.info("AudioManager _ready() starting", "AudioManager")
	
	# Load configuration
	_load_config_values()
	
	# Create audio players if they don't exist
	create_audio_players()
	
	# Load audio resources
	load_audio_resources()
	
	# Set initial volumes
	set_volumes()
	
	# Start ambient sounds
	play_ambient()
	
	if DebugLogger:
		DebugLogger.info("AudioManager initialized successfully", "AudioManager")

func _load_config_values() -> void:
	master_volume = GameConfig.audio_master_volume
	music_volume = GameConfig.audio_music_volume
	sfx_volume = GameConfig.audio_sfx_volume
	ambient_volume = GameConfig.audio_ambient_volume

func create_audio_players():
	# Music player
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	add_child(music_player)
	
	# Ambient player
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientPlayer"
	ambient_player.bus = "Ambient"
	add_child(ambient_player)
	
	# SFX player
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	sfx_player.bus = "SFX"
	add_child(sfx_player)
	
	# NPC alert player (separate from general SFX to avoid conflicts)
	npc_alert_player = AudioStreamPlayer.new()
	npc_alert_player.name = "NPCAlertPlayer"
	npc_alert_player.bus = "SFX"
	add_child(npc_alert_player)
	
	# UI player
	ui_player = AudioStreamPlayer.new()
	ui_player.name = "UIPlayer"
	ui_player.bus = "UI"
	add_child(ui_player)

func load_audio_resources():
	var audio_files = {
		"background_music": "res://assets/audio/background_music.ogg",
		"ambient_sound": "res://assets/audio/ambient.ogg",
		"footstep_sound": "res://assets/audio/footstep.ogg",
		"button_click_sound": "res://assets/audio/button_click.ogg",
		"door_sound": "res://assets/audio/door.ogg",
		"door_open_sound": "res://assets/audio/door_open.ogg",
		"door_close_sound": "res://assets/audio/door_close.ogg",
		"item_pickup_sound": "res://assets/audio/item_pickup.ogg",
		"victory_sound": "res://assets/audio/victory.ogg",
		"alert_sound": "res://assets/audio/alert.ogg",
		"alert_suspicious_sound": "res://assets/audio/alert_suspicious.ogg",
		"alert_chase_sound": "res://assets/audio/alert_chase.ogg",
		"detected_sound": "res://assets/audio/detected.ogg"
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
	if music_player:
		music_player.volume_db = linear_to_db(master_volume * music_volume)
	if ambient_player:
		ambient_player.volume_db = linear_to_db(master_volume * ambient_volume)
	if sfx_player:
		sfx_player.volume_db = linear_to_db(master_volume * sfx_volume)
	if ui_player:
		ui_player.volume_db = linear_to_db(master_volume * sfx_volume)

# Music control
func play_background_music():
	if background_music and music_player and not is_music_playing:
		music_player.stream = background_music
		music_player.play()
		is_music_playing = true

func stop_background_music():
	if music_player:
		music_player.stop()
		is_music_playing = false

func fade_music_in(duration: float = 2.0):
	if music_player and background_music:
		music_player.volume_db = -80
		music_player.stream = background_music
		music_player.play()
		
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", 
			linear_to_db(master_volume * music_volume), duration)
		is_music_playing = true

func fade_music_out(duration: float = 2.0):
	if music_player and is_music_playing:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80, duration)
		await tween.finished
		music_player.stop()
		is_music_playing = false

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
	if footstep_sound and sfx_player:
		sfx_player.stream = footstep_sound
		sfx_player.play()

func play_button_click():
	if button_click_sound and ui_player:
		ui_player.stream = button_click_sound
		ui_player.play()

func play_door_sound():
	if door_sound and sfx_player:
		sfx_player.stream = door_sound
		sfx_player.play()

func play_item_pickup():
	if item_pickup_sound and sfx_player:
		sfx_player.stream = item_pickup_sound
		sfx_player.play()

func play_victory():
	if victory_sound and sfx_player:
		# Fade out music first
		fade_music_out(1.0)
		await get_tree().create_timer(1.0).timeout
		
		sfx_player.stream = victory_sound
		sfx_player.play()

func play_alert():
	if alert_sound and sfx_player:
		sfx_player.stream = alert_sound
		sfx_player.play()

func play_alert_suspicious():
	if DebugLogger:
		DebugLogger.info("play_alert_suspicious called", "AudioManager")
	if alert_suspicious_sound and npc_alert_player:
		if DebugLogger:
			DebugLogger.info("Playing suspicious alert sound", "AudioManager")
		npc_alert_player.stream = alert_suspicious_sound
		npc_alert_player.play()
	else:
		if DebugLogger:
			DebugLogger.warning("Cannot play suspicious alert: alert_suspicious_sound=%s, npc_alert_player=%s" % [alert_suspicious_sound != null, npc_alert_player != null], "AudioManager")

func play_alert_chase():
	if DebugLogger:
		DebugLogger.info("play_alert_chase called", "AudioManager")
	if alert_chase_sound and npc_alert_player:
		if DebugLogger:
			DebugLogger.info("Playing chase alert sound", "AudioManager")
		npc_alert_player.stream = alert_chase_sound
		npc_alert_player.play()
	else:
		if DebugLogger:
			DebugLogger.warning("Cannot play chase alert: alert_chase_sound=%s, npc_alert_player=%s" % [alert_chase_sound != null, npc_alert_player != null], "AudioManager")

func play_door_open():
	if door_open_sound and sfx_player:
		sfx_player.stream = door_open_sound
		sfx_player.play()

func play_door_close():
	if door_close_sound and sfx_player:
		sfx_player.stream = door_close_sound
		sfx_player.play()

func play_detected():
	if detected_sound and sfx_player:
		sfx_player.stream = detected_sound
		sfx_player.play()

func play_game_over():
	# Stop all other audio
	stop_all_audio()
	# Play detected sound as game over sound
	if detected_sound and sfx_player:
		sfx_player.stream = detected_sound
		sfx_player.play()

func stop_all_audio():
	if music_player:
		music_player.stop()
	if ambient_player:
		ambient_player.stop()
	if sfx_player:
		sfx_player.stop()
	if ui_player:
		ui_player.stop()
	is_music_playing = false
	is_ambient_playing = false

# Volume controls
func set_master_volume(volume: float):
	master_volume = clamp(volume, 0.0, 1.0)
	set_volumes()

func set_music_volume(volume: float):
	music_volume = clamp(volume, 0.0, 1.0)
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
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "ambient_volume", ambient_volume)
	config.save("user://audio_settings.cfg")

func load_audio_settings():
	var config = ConfigFile.new()
	var err = config.load("user://audio_settings.cfg")
	
	if err == OK:
		master_volume = config.get_value("audio", "master_volume", 0.8)
		music_volume = config.get_value("audio", "music_volume", 0.6)
		sfx_volume = config.get_value("audio", "sfx_volume", 0.8)
		ambient_volume = config.get_value("audio", "ambient_volume", 0.4)
		set_volumes()