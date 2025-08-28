extends StaticBody3D

@onready var door_left: MeshInstance3D = $Doors/DoorLeft
@onready var door_right: MeshInstance3D = $Doors/DoorRight
@onready var call_button: MeshInstance3D = $CallButton/ButtonMesh
@onready var door_timer: Timer = $DoorOpenTimer

var doors_open: bool = false
var player_nearby: bool = false
var player_inside: bool = false
var door_tween: Tween

# Door animation properties
@export var door_open_distance: float = 1.5
@export var door_animation_speed: float = 0.8
@export var auto_close_delay: float = 3.0

# Original door positions
var left_door_closed_pos: Vector3
var right_door_closed_pos: Vector3
var left_door_open_pos: Vector3
var right_door_open_pos: Vector3

# Button materials
var button_material_normal: StandardMaterial3D
var button_material_active: StandardMaterial3D

func _ready() -> void:
	# Store original positions
	left_door_closed_pos = door_left.position
	right_door_closed_pos = door_right.position
	
	# Calculate open positions (doors slide apart)
	left_door_open_pos = left_door_closed_pos + Vector3(-door_open_distance, 0, 0)
	right_door_open_pos = right_door_closed_pos + Vector3(door_open_distance, 0, 0)
	
	# Set up timer
	door_timer.wait_time = auto_close_delay
	
	# Set up button materials
	setup_button_materials()
	
	# Ensure doors start closed
	doors_open = false
	
	# Connect to button interaction if it's an interactable
	var button_node = get_node("CallButton")
	if button_node and button_node.is_in_group("interactables"):
		# The interaction will be handled by the player controller
		pass

func setup_button_materials() -> void:
	# Normal button (yellow)
	button_material_normal = StandardMaterial3D.new()
	button_material_normal.albedo_color = Color.YELLOW
	button_material_normal.emission_enabled = true
	button_material_normal.emission = Color.YELLOW
	button_material_normal.emission_energy_multiplier = 0.5
	
	# Active button (green)
	button_material_active = StandardMaterial3D.new()
	button_material_active.albedo_color = Color.GREEN
	button_material_active.emission_enabled = true
	button_material_active.emission = Color.GREEN
	button_material_active.emission_energy_multiplier = 0.8

func _on_proximity_detection_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_nearby = true
		open_doors()

func _on_proximity_detection_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		# Start timer to close doors after delay
		door_timer.start()

func _on_inside_detection_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		print("Player entered elevator - checking objectives...")
		_check_exit_conditions()

func _on_inside_detection_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		print("Player exited elevator")

func _on_door_open_timer_timeout() -> void:
	if not player_nearby:
		close_doors()

func open_doors() -> void:
	if doors_open:
		return
		
	doors_open = true
	
	# Stop existing tween
	if door_tween:
		door_tween.kill()
	
	# Create new tween
	door_tween = create_tween()
	door_tween.set_parallel(true)
	
	# Animate doors opening
	door_tween.tween_property(door_left, "position", left_door_open_pos, door_animation_speed)
	door_tween.tween_property(door_right, "position", right_door_open_pos, door_animation_speed)
	
	# Change button color to indicate active state
	call_button.material_override = button_material_active
	
	# Play door opening sound
	if AudioManager:
		AudioManager.play_button_click()  # Using button click as elevator ding

func close_doors() -> void:
	if not doors_open:
		return
		
	doors_open = false
	
	# Stop existing tween
	if door_tween:
		door_tween.kill()
	
	# Create new tween
	door_tween = create_tween()
	door_tween.set_parallel(true)
	
	# Animate doors closing
	door_tween.tween_property(door_left, "position", left_door_closed_pos, door_animation_speed)
	door_tween.tween_property(door_right, "position", right_door_closed_pos, door_animation_speed)
	
	# Change button back to normal color
	call_button.material_override = button_material_normal
	
	# Play door closing sound
	if AudioManager:
		AudioManager.play_button_click()  # Using button click as elevator sound

func force_open_doors() -> void:
	# Public method to force doors open (e.g., when interacting with button)
	door_timer.stop()
	open_doors()

func force_close_doors() -> void:
	# Public method to force doors closed
	door_timer.stop()
	close_doors()

# Handle interaction from player controller

func interact() -> void:
	# This method can be called by the player when interacting with the button
	toggle_doors()

func toggle_doors() -> void:
	if doors_open:
		force_close_doors()
	else:
		force_open_doors()
		# Reset the timer to keep doors open longer
		door_timer.start()

func _check_exit_conditions() -> void:
	# Check if player has completed the biscuit jar objective
	if ObjectiveManager and ObjectiveManager.objectives.has("find_jar"):
		var jar_objective = ObjectiveManager.objectives["find_jar"]
		if jar_objective.is_completed:
			print("All objectives completed! Player can exit.")
			# Wait a moment, then trigger game completion
			await get_tree().create_timer(1.0).timeout
			_trigger_game_exit()
		else:
			print("Player needs to find the biscuit jar first!")

func _trigger_game_exit() -> void:
	print("Congratulations! You successfully stole the biscuit jar and escaped!")
	
	# Trigger victory through GameManager
	if GameManager:
		GameManager.trigger_victory()
	else:
		# Fallback if GameManager is not available
		await get_tree().create_timer(3.0).timeout
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")