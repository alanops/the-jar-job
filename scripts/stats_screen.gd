extends Control

@onready var result_label: Label = $Panel/VBoxContainer/ResultLabel
@onready var time_label: Label = $Panel/VBoxContainer/StatsContainer/TimeLabel
@onready var score_label: Label = $Panel/VBoxContainer/StatsContainer/ScoreLabel
@onready var distance_label: Label = $Panel/VBoxContainer/StatsContainer/DistanceLabel
@onready var speed_label: Label = $Panel/VBoxContainer/StatsContainer/SpeedLabel
@onready var spotted_label: Label = $Panel/VBoxContainer/StatsContainer/SpottedLabel
@onready var suspected_label: Label = $Panel/VBoxContainer/StatsContainer/SuspectedLabel
@onready var camera_switch_label: Label = $Panel/VBoxContainer/StatsContainer/CameraSwitchLabel
@onready var interactions_label: Label = $Panel/VBoxContainer/StatsContainer/InteractionsLabel
@onready var resets_label: Label = $Panel/VBoxContainer/StatsContainer/ResetsLabel
@onready var play_again_button: Button = $Panel/VBoxContainer/ButtonContainer/PlayAgainButton
@onready var menu_button: Button = $Panel/VBoxContainer/ButtonContainer/MenuButton

func _ready() -> void:
	# Connect button signals
	play_again_button.pressed.connect(_on_play_again_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	
	# Load and display stats
	_display_stats()
	
	# Make sure mouse cursor is visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _display_stats() -> void:
	var stats = GameManager.get_stats()
	var completion_time = stats.get("completion_time", 0.0)
	
	# Format time
	var minutes: int = int(completion_time) / 60
	var seconds: int = int(completion_time) % 60
	var time_str = "%02d:%02d" % [minutes, seconds]
	
	# Calculate speed
	var distance = stats.get("distance_traveled", 0.0)
	var speed = distance / max(completion_time, 0.1)
	
	# Update result
	if stats.get("victory_achieved", false):
		result_label.text = "🎯 VICTORY!"
		result_label.modulate = Color.GREEN
	else:
		result_label.text = "💀 DEFEAT"
		result_label.modulate = Color.RED
	
	# Update all stat labels
	time_label.text = "⏱️ Time: %s" % time_str
	score_label.text = "🏆 Score: %d" % stats.get("final_score", 0)
	distance_label.text = "📏 Distance: %.1fm" % distance
	speed_label.text = "🚶 Speed: %.1fm/s" % speed
	spotted_label.text = "👁️ Times Spotted: %d" % stats.get("times_spotted", 0)
	suspected_label.text = "🤐 Times Suspected: %d" % stats.get("times_suspected", 0)
	
	# Show collectibles info
	var biscuits = stats.get("biscuits_collected", 0)
	var secrets = stats.get("secrets_found", 0)
	var secrets_by_rarity = stats.get("secrets_by_rarity", {})
	
	if secrets > 0:
		camera_switch_label.text = "🗝️ Secrets: %d (C:%d R:%d L:%d)" % [
			secrets,
			secrets_by_rarity.get("Common", 0),
			secrets_by_rarity.get("Rare", 0),
			secrets_by_rarity.get("Legendary", 0)
		]
	else:
		camera_switch_label.text = "🔄 Camera Switches: %d" % stats.get("camera_switches", 0)
	
	interactions_label.text = "🍪 Biscuits: %d | 🎮 Interactions: %d" % [biscuits, stats.get("interactions", 0)]
	resets_label.text = "♻️ Resets Used: %d" % stats.get("game_resets", 0)
	
	# Color code some important stats
	if stats.get("times_spotted", 0) == 0:
		spotted_label.modulate = Color.GREEN
	elif stats.get("times_spotted", 0) > 2:
		spotted_label.modulate = Color.RED
	else:
		spotted_label.modulate = Color.YELLOW
	
	if stats.get("game_resets", 0) == 0:
		resets_label.modulate = Color.GREEN
	elif stats.get("game_resets", 0) > 3:
		resets_label.modulate = Color.RED
	else:
		resets_label.modulate = Color.YELLOW

func _on_play_again_pressed() -> void:
	GameManager.reset_game()

func _on_menu_pressed() -> void:
	GameManager.return_to_menu()

func _input(event: InputEvent) -> void:
	# Allow closing with escape
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_menu_pressed()
		elif event.keycode == KEY_R:
			_on_play_again_pressed()