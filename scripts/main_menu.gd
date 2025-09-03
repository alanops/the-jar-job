extends Control

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var loading_screen: Control = $LoadingScreen

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Ensure game manager is in menu state
	GameManager.current_state = GameManager.GameState.MENU
	
	# Start ambient menu music
	AudioManager.play_ambient()

func _on_play_pressed() -> void:
	AudioManager.play_button_click()
	
	# Hide buttons during loading
	play_button.visible = false
	quit_button.visible = false
	
	# Start loading screen
	loading_screen.start_loading("res://scenes/game.tscn")

func _on_quit_pressed() -> void:
	AudioManager.play_button_click()
	get_tree().quit()
