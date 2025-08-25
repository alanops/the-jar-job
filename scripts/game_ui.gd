extends Control

@onready var timer_label: Label = $HUD/TimerLabel
@onready var objective_label: Label = $HUD/ObjectiveLabel
@onready var alert_panel: Panel = $AlertPanel
@onready var alert_label: Label = $AlertPanel/AlertLabel
@onready var game_over_panel: Panel = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/VBoxContainer/GameOverLabel
@onready var retry_button: Button = $GameOverPanel/VBoxContainer/RetryButton
@onready var menu_button: Button = $GameOverPanel/VBoxContainer/MenuButton
@onready var victory_panel: Panel = $VictoryPanel
@onready var victory_time_label: Label = $VictoryPanel/VBoxContainer/TimeLabel
@onready var victory_score_label: Label = $VictoryPanel/VBoxContainer/ScoreLabel
@onready var victory_retry_button: Button = $VictoryPanel/VBoxContainer/RetryButton
@onready var victory_menu_button: Button = $VictoryPanel/VBoxContainer/MenuButton
@onready var interaction_prompt: Panel = $InteractionPrompt

# Debug console elements
@onready var debug_console: Panel = $DebugConsole
@onready var npc_state_label: Label = $DebugConsole/VBoxContainer/NPCStateLabel
@onready var suspicion_label: Label = $DebugConsole/VBoxContainer/SuspicionLabel
@onready var detection_label: Label = $DebugConsole/VBoxContainer/DetectionLabel
@onready var player_in_vision_label: Label = $DebugConsole/VBoxContainer/PlayerInVisionLabel
@onready var last_seen_label: Label = $DebugConsole/VBoxContainer/LastSeenLabel
@onready var patrol_label: Label = $DebugConsole/VBoxContainer/PatrolLabel

var alert_tween: Tween
var detection_progress: float = 0.0
var is_being_detected: bool = false

func _ready() -> void:
	# Connect signals
	GameManager.game_started.connect(_on_game_started)
	GameManager.game_over.connect(_on_game_over)
	GameManager.game_won.connect(_on_game_won)
	GameManager.jar_collected.connect(_on_jar_collected)
	
	# Connect buttons
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	victory_retry_button.pressed.connect(_on_retry_pressed)
	victory_menu_button.pressed.connect(_on_menu_pressed)
	
	# Hide panels initially
	alert_panel.visible = false
	game_over_panel.visible = false
	victory_panel.visible = false
	interaction_prompt.visible = false

var last_time_update: int = -1

func _process(_delta: float) -> void:
	if GameManager.current_state == GameManager.GameState.PLAYING:
		var current_seconds = int(GameManager.game_timer)
		if current_seconds != last_time_update:
			last_time_update = current_seconds
			timer_label.text = "Time: " + GameManager.get_time_string()

func _on_game_started() -> void:
	objective_label.text = "Sneak to the kitchen and steal the biscuit jar!"
	alert_panel.visible = false
	game_over_panel.visible = false
	victory_panel.visible = false

func _on_jar_collected() -> void:
	objective_label.text = "Get to the elevator with the jar!"
	show_alert("Got the biscuits!", Color.GREEN)

func _on_game_over(reason: String) -> void:
	game_over_label.text = reason
	game_over_panel.visible = true
	show_alert("SPOTTED!", Color.RED)

func _on_game_won() -> void:
	victory_time_label.text = "Time: " + GameManager.get_time_string()
	victory_score_label.text = "Score: " + str(GameManager.score)
	victory_panel.visible = true
	show_alert("SUCCESS!", Color.GREEN)

func show_alert(text: String, color: Color = Color.RED) -> void:
	alert_label.text = text
	alert_label.modulate = color
	alert_panel.visible = true
	
	# Animate alert
	if alert_tween:
		alert_tween.kill()
	
	alert_tween = create_tween()
	alert_tween.set_ease(Tween.EASE_OUT)
	alert_tween.set_trans(Tween.TRANS_ELASTIC)
	
	alert_panel.scale = Vector2(0, 1)
	alert_tween.tween_property(alert_panel, "scale", Vector2(1, 1), 0.5)
	alert_tween.tween_interval(2.0)
	alert_tween.tween_property(alert_panel, "modulate:a", 0.0, 0.5)
	alert_tween.tween_callback(func(): alert_panel.visible = false; alert_panel.modulate.a = 1.0)

func _on_retry_pressed() -> void:
	GameManager.reset_game()

func _on_menu_pressed() -> void:
	GameManager.return_to_menu()

func update_detection_progress(progress: float) -> void:
	print("UI received detection progress: ", progress)
	is_being_detected = progress > 0.0
	detection_progress = progress
	
	# Update debug console
	detection_label.text = "Detection: " + str(int(progress * 100)) + "%"
	
	if progress > 0.1:
		var percent := int((1.0 - progress) * 100)
		print("Showing alert: DETECTED! " + str(percent) + "%")
		show_alert("DETECTED! " + str(percent) + "%", Color.ORANGE)

# Debug console update functions
func update_npc_state(state: String) -> void:
	npc_state_label.text = "NPC State: " + state

func update_suspicion_level(level: int) -> void:
	suspicion_label.text = "Suspicion: " + str(level) + "%"

func update_player_in_vision(in_vision: bool) -> void:
	player_in_vision_label.text = "Player In Vision: " + ("Yes" if in_vision else "No")

func update_last_seen_position(position: Vector3) -> void:
	if position == Vector3.ZERO:
		last_seen_label.text = "Last Seen: Never"
	else:
		last_seen_label.text = "Last Seen: (" + str(int(position.x)) + ", " + str(int(position.z)) + ")"

func update_patrol_point(point: int) -> void:
	patrol_label.text = "Patrol Point: " + str(point)

func show_interaction_prompt(show: bool) -> void:
	interaction_prompt.visible = show
