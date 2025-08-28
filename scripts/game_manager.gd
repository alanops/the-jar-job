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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start_game() -> void:
	current_state = GameState.PLAYING
	has_jar = false
	game_timer = 0.0
	score = 0
	
	# Reset NPC systems if they exist
	_reset_npc_systems()
	
	game_started.emit()

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
	score += 1000
	jar_collected.emit()
	
	# Play pickup sound
	if AudioManager:
		AudioManager.play_item_pickup()
	
	print("Biscuit jar collected! Now escape!")

func trigger_game_over(reason: String = "You were spotted!") -> void:
	if current_state != GameState.PLAYING:
		return
	
	current_state = GameState.GAME_OVER
	game_over.emit(reason)
	
	# Play game over sound
	if AudioManager:
		AudioManager.play_game_over()
	
	print("Game Over: ", reason)

func trigger_victory() -> void:
	if current_state != GameState.PLAYING or not has_jar:
		return
	
	current_state = GameState.VICTORY
	var time_bonus: int = max(0, 1000 - int(game_timer * 10))
	score += time_bonus
	game_won.emit()
	
	# Play victory sound
	if AudioManager:
		AudioManager.play_victory()
	
	print("Victory! Final score: ", score)

func _process(delta: float) -> void:
	if current_state == GameState.PLAYING:
		game_timer += delta
	
	# Handle reset key
	if Input.is_action_just_pressed("reset"):
		reset_game()

func get_time_string() -> String:
	var minutes: int = int(game_timer) / 60
	var seconds: int = int(game_timer) % 60
	return "%02d:%02d" % [minutes, seconds]

func reset_game() -> void:
	# Reset systems before reloading scene
	_reset_npc_systems()
	get_tree().reload_current_scene()

func return_to_menu() -> void:
	current_state = GameState.MENU
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
