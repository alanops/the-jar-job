extends Node

# Game Manager - Handles global game state and systems
# This is a singleton (autoload) that persists across scenes

signal game_paused
signal game_unpaused

var is_paused: bool = false

func _ready():
	print("GameManager initialized")

func _input(event):
	if event.is_action_pressed("pause"):
		toggle_pause()

func toggle_pause():
	is_paused = !is_paused
	get_tree().paused = is_paused
	
	if is_paused:
		game_paused.emit()
		print("Game Paused")
	else:
		game_unpaused.emit()
		print("Game Unpaused")

func quit_game():
	get_tree().quit()