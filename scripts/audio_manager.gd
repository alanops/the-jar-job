extends Node

# Audio streams
@export var background_music: AudioStream
@export var ambient_sound: AudioStream
@export var footstep_sound: AudioStream
@export var button_click_sound: AudioStream
@export var door_sound: AudioStream
@export var item_pickup_sound: AudioStream
@export var victory_sound: AudioStream
@export var alert_sound: AudioStream
@export var detected_sound: AudioStream

# Audio players
@onready var music_player: AudioStreamPlayer
@onready var ambient_player: AudioStreamPlayer
@onready var sfx_player: AudioStreamPlayer
@onready var ui_player: AudioStreamPlayer

# Volume settings
@export var master_volume: float = 0.8
@export var music_volume: float = 0.6
@export var sfx_volume: float = 0.8
@export var ambient_volume: float = 0.4

var is_music_playing: bool = false
var is_ambient_playing: bool = false

func _ready():
	# Create audio players if they don't exist
	create_audio_players()
	
	# Load audio resources
	load_audio_resources()
	
	# Set initial volumes
	set_volumes()
	
	# Start ambient sounds
	play_ambient()

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
	
	# UI player
	ui_player = AudioStreamPlayer.new()
	ui_player.name = "UIPlayer"
	ui_player.bus = "UI"
	add_child(ui_player)

func load_audio_resources():
	background_music = load("res://assets/audio/background_music.ogg")
	ambient_sound = load("res://assets/audio/ambient.ogg")
	footstep_sound = load("res://assets/audio/footstep.ogg")
	button_click_sound = load("res://assets/audio/button_click.ogg")
	door_sound = load("res://assets/audio/door.ogg")
	item_pickup_sound = load("res://assets/audio/item_pickup.ogg")
	victory_sound = load("res://assets/audio/victory.ogg")
	alert_sound = load("res://assets/audio/alert.ogg")
	detected_sound = load("res://assets/audio/detected.ogg")

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

func play_detected():
	if detected_sound and sfx_player:
		sfx_player.stream = detected_sound
		sfx_player.play()

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