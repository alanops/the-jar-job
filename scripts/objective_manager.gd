extends Node

signal objective_updated(objective: Objective)
signal objective_completed(objective: Objective)

class Objective:
	var id: String
	var title: String
	var description: String
	var target_position: Vector3
	var target_node: Node3D
	var is_completed: bool = false
	var is_active: bool = false
	var icon: String = "📍"
	
	func _init(p_id: String, p_title: String, p_desc: String, p_icon: String = "📍") -> void:
		id = p_id
		title = p_title
		description = p_desc
		icon = p_icon

var objectives: Dictionary = {}
var current_objective: Objective

func _ready() -> void:
	# Set up initial objectives
	call_deferred("_setup_objectives")
	
	# Connect to game events
	call_deferred("_connect_signals")

func _connect_signals() -> void:
	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.has_signal("jar_collected"):
		game_manager.jar_collected.connect(_on_jar_collected)

func _setup_objectives() -> void:
	# Find the biscuit jar
	var find_jar = Objective.new(
		"find_jar",
		"Find the Biscuit Jar",
		"Locate and steal the precious biscuit jar",
		"🍪"
	)
	
	# Get jar position
	var jar = get_tree().get_first_node_in_group("biscuit_jar")
	if jar:
		find_jar.target_node = jar
		find_jar.target_position = jar.global_position
	
	objectives[find_jar.id] = find_jar
	
	# Escape objective (not active initially)
	var escape = Objective.new(
		"escape",
		"Escape!",
		"Get back to the elevator to make your escape",
		"🚪"
	)
	
	var exit_door = get_tree().get_first_node_in_group("exit_door")
	if exit_door:
		escape.target_node = exit_door
		escape.target_position = exit_door.global_position
	
	objectives[escape.id] = escape
	
	# Set initial objective
	set_current_objective("find_jar")

func set_current_objective(objective_id: String) -> void:
	if objective_id in objectives:
		if current_objective:
			current_objective.is_active = false
		
		current_objective = objectives[objective_id]
		current_objective.is_active = true
		objective_updated.emit(current_objective)

func complete_objective(objective_id: String) -> void:
	if objective_id in objectives:
		var objective = objectives[objective_id]
		objective.is_completed = true
		objective.is_active = false
		objective_completed.emit(objective)
		
		# Handle objective completion logic
		match objective_id:
			"find_jar":
				set_current_objective("escape")

func _on_jar_collected() -> void:
	complete_objective("find_jar")

func get_active_objectives() -> Array:
	var active = []
	for obj in objectives.values():
		if obj.is_active and not obj.is_completed:
			active.append(obj)
	return active

func get_all_objectives() -> Array:
	var all = []
	for obj in objectives.values():
		all.append(obj)
	return all
