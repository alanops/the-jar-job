extends Control

# Main menu buttons
@onready var audio_button: Button = $SettingsPanel/VBoxContainer/MenuContainer/AudioButton
@onready var controls_button: Button = $SettingsPanel/VBoxContainer/MenuContainer/ControlsButton

# Audio sub-menu buttons
@onready var general_audio_button: Button = $SettingsPanel/VBoxContainer/AudioPanel/AudioSubMenu/GeneralAudioButton
@onready var music_audio_button: Button = $SettingsPanel/VBoxContainer/AudioPanel/AudioSubMenu/MusicAudioButton

# Panels
@onready var audio_panel: VBoxContainer = $SettingsPanel/VBoxContainer/AudioPanel
@onready var controls_panel: VBoxContainer = $SettingsPanel/VBoxContainer/ControlsPanel
@onready var general_audio_container: VBoxContainer = $SettingsPanel/VBoxContainer/AudioPanel/GeneralAudioContainer
@onready var music_audio_container: VBoxContainer = $SettingsPanel/VBoxContainer/AudioPanel/MusicAudioContainer

# Audio sliders - General
@onready var master_slider: HSlider = $SettingsPanel/VBoxContainer/AudioPanel/GeneralAudioContainer/MasterVolumeContainer/MasterSlider
@onready var sfx_slider: HSlider = $SettingsPanel/VBoxContainer/AudioPanel/GeneralAudioContainer/SFXVolumeContainer/SFXSlider
@onready var ambient_slider: HSlider = $SettingsPanel/VBoxContainer/AudioPanel/GeneralAudioContainer/AmbientVolumeContainer/AmbientSlider

# Audio sliders - Music
@onready var music_slider: HSlider = $SettingsPanel/VBoxContainer/AudioPanel/MusicAudioContainer/MusicVolumeContainer/MusicSlider

# Value labels - General
@onready var master_value_label: Label = $SettingsPanel/VBoxContainer/AudioPanel/GeneralAudioContainer/MasterVolumeContainer/MasterValueLabel
@onready var sfx_value_label: Label = $SettingsPanel/VBoxContainer/AudioPanel/GeneralAudioContainer/SFXVolumeContainer/SFXValueLabel
@onready var ambient_value_label: Label = $SettingsPanel/VBoxContainer/AudioPanel/GeneralAudioContainer/AmbientVolumeContainer/AmbientValueLabel

# Value labels - Music
@onready var music_value_label: Label = $SettingsPanel/VBoxContainer/AudioPanel/MusicAudioContainer/MusicVolumeContainer/MusicValueLabel

# Control buttons
@onready var apply_button: Button = $SettingsPanel/VBoxContainer/ButtonContainer/ApplyButton
@onready var reset_button: Button = $SettingsPanel/VBoxContainer/ButtonContainer/ResetButton
@onready var close_button: Button = $SettingsPanel/VBoxContainer/ButtonContainer/CloseButton

# Default audio levels
const DEFAULT_MASTER_VOLUME: float = 0.8
const DEFAULT_MUSIC_VOLUME: float = 0.6
const DEFAULT_SFX_VOLUME: float = 0.8
const DEFAULT_AMBIENT_VOLUME: float = 0.4

# Current menu state
enum MenuState { MAIN, AUDIO, CONTROLS }
enum AudioSubState { GENERAL, MUSIC }
var current_menu_state: MenuState = MenuState.AUDIO
var current_audio_sub_state: AudioSubState = AudioSubState.GENERAL

func _ready():
	# Connect main menu buttons
	audio_button.pressed.connect(_on_audio_button_pressed)
	controls_button.pressed.connect(_on_controls_button_pressed)
	
	# Connect audio sub-menu buttons
	general_audio_button.pressed.connect(_on_general_audio_button_pressed)
	music_audio_button.pressed.connect(_on_music_audio_button_pressed)
	
	# Connect slider signals
	master_slider.value_changed.connect(_on_master_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	ambient_slider.value_changed.connect(_on_ambient_slider_changed)
	
	# Connect button signals
	apply_button.pressed.connect(_on_apply_button_pressed)
	reset_button.pressed.connect(_on_reset_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	
	# Set initial state
	_show_audio_menu()
	_show_general_audio()
	
	# Update value labels initially
	_update_value_labels()

func _show_audio_menu():
	current_menu_state = MenuState.AUDIO
	audio_panel.visible = true
	controls_panel.visible = false
	_update_main_button_styles()

func _show_controls_menu():
	current_menu_state = MenuState.CONTROLS
	audio_panel.visible = false
	controls_panel.visible = true
	_update_main_button_styles()

func _show_general_audio():
	current_audio_sub_state = AudioSubState.GENERAL
	general_audio_container.visible = true
	music_audio_container.visible = false
	_update_audio_button_styles()

func _show_music_audio():
	current_audio_sub_state = AudioSubState.MUSIC
	general_audio_container.visible = false
	music_audio_container.visible = true
	_update_audio_button_styles()

func _update_main_button_styles():
	# Simple visual feedback - could be enhanced with different styles
	audio_button.disabled = (current_menu_state == MenuState.AUDIO)
	controls_button.disabled = (current_menu_state == MenuState.CONTROLS)

func _update_audio_button_styles():
	# Simple visual feedback for audio sub-menu
	general_audio_button.disabled = (current_audio_sub_state == AudioSubState.GENERAL)
	music_audio_button.disabled = (current_audio_sub_state == AudioSubState.MUSIC)

func _on_audio_button_pressed():
	AudioManager.play_button_click()
	_show_audio_menu()

func _on_controls_button_pressed():
	AudioManager.play_button_click()
	_show_controls_menu()

func _on_general_audio_button_pressed():
	AudioManager.play_button_click()
	_show_general_audio()

func _on_music_audio_button_pressed():
	AudioManager.play_button_click()
	_show_music_audio()

func _load_settings():
	# Load saved audio settings from AudioManager
	if AudioManager:
		master_slider.value = AudioManager.master_volume
		music_slider.value = AudioManager.music_volume
		sfx_slider.value = AudioManager.sfx_volume
		ambient_slider.value = AudioManager.ambient_volume

func _on_master_slider_changed(value: float):
	_update_master_label(value)
	# Apply immediately for real-time feedback
	if AudioManager:
		AudioManager.set_master_volume(value)

func _on_music_slider_changed(value: float):
	_update_music_label(value)
	if AudioManager:
		AudioManager.set_music_volume(value)

func _on_sfx_slider_changed(value: float):
	_update_sfx_label(value)
	if AudioManager:
		AudioManager.set_sfx_volume(value)

func _on_ambient_slider_changed(value: float):
	_update_ambient_label(value)
	if AudioManager:
		AudioManager.set_ambient_volume(value)

func _update_value_labels():
	_update_master_label(master_slider.value)
	_update_music_label(music_slider.value)
	_update_sfx_label(sfx_slider.value)
	_update_ambient_label(ambient_slider.value)

func _update_master_label(value: float):
	master_value_label.text = str(int(value * 100)) + "%"

func _update_music_label(value: float):
	music_value_label.text = str(int(value * 100)) + "%"

func _update_sfx_label(value: float):
	sfx_value_label.text = str(int(value * 100)) + "%"

func _update_ambient_label(value: float):
	ambient_value_label.text = str(int(value * 100)) + "%"

func _on_apply_button_pressed():
	# Save settings to persistent storage
	if AudioManager:
		AudioManager.save_audio_settings()
	
	# Close the settings menu
	_close_settings()

func _on_reset_button_pressed():
	# Reset all sliders to default values
	master_slider.value = DEFAULT_MASTER_VOLUME
	music_slider.value = DEFAULT_MUSIC_VOLUME
	sfx_slider.value = DEFAULT_SFX_VOLUME
	ambient_slider.value = DEFAULT_AMBIENT_VOLUME
	
	# Update labels
	_update_value_labels()
	
	# Apply the default settings immediately
	if AudioManager:
		AudioManager.set_master_volume(DEFAULT_MASTER_VOLUME)
		AudioManager.set_music_volume(DEFAULT_MUSIC_VOLUME)
		AudioManager.set_sfx_volume(DEFAULT_SFX_VOLUME)
		AudioManager.set_ambient_volume(DEFAULT_AMBIENT_VOLUME)

func _on_close_button_pressed():
	_close_settings()

func _close_settings():
	# Hide the settings menu
	hide()
	
	# Resume the game if it was paused
	get_tree().paused = false

func show_settings():
	# Show the settings menu
	show()
	
	# Load current settings
	_load_settings()
	
	# Pause the game while in settings (after loading to ensure UI is ready)
	get_tree().paused = true
