extends StaticBody3D

@onready var door_left: MeshInstance3D = $Doors/DoorLeft
@onready var door_right: MeshInstance3D = $Doors/DoorRight
# CallButton removed - elevator operates automatically
@onready var door_timer: Timer = $DoorOpenTimer
@onready var elevator_light: OmniLight3D = $ElevatorWarmLight2

var doors_open: bool = false
var player_nearby: bool = false
var player_inside: bool = false
var door_tween: Tween

# Door animation properties
@export var door_open_distance: float = 1.5
@export var door_animation_speed: float = 0.8
@export var auto_close_delay: float = 3.0

# Light culling properties
@export var light_cull_distance: float = 25.0
var light_cull_timer: float = 0.0
var light_cull_interval: float = 0.5
var player_reference: PlayerController

# Original door positions
var left_door_closed_pos: Vector3
var right_door_closed_pos: Vector3
var left_door_open_pos: Vector3
var right_door_open_pos: Vector3

# Button removed - elevator operates on player proximity

func _ready() -> void:
	# Store original positions
	left_door_closed_pos = door_left.position
	right_door_closed_pos = door_right.position
	
	# Calculate open positions (doors slide apart)
	left_door_open_pos = left_door_closed_pos + Vector3(-door_open_distance, 0, 0)
	right_door_open_pos = right_door_closed_pos + Vector3(door_open_distance, 0, 0)
	
	# Set up timer
	door_timer.wait_time = auto_close_delay
	
	# Ensure doors start closed
	doors_open = false
	
	print("Elevator ready - door positions: closed_left=", left_door_closed_pos, " open_left=", left_door_open_pos)
	
	# Find player for light culling
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_reference = players[0]

# Button functions removed - automatic operation

func _process(delta: float) -> void:
	# Handle light culling
	if player_reference and elevator_light:
		light_cull_timer += delta
		if light_cull_timer >= light_cull_interval:
			light_cull_timer = 0.0
			_update_light_culling()

func _update_light_culling() -> void:
	var elevator_pos_2d = Vector2(global_position.x, global_position.z)
	var player_pos_2d = Vector2(player_reference.global_position.x, player_reference.global_position.z)
	var distance_2d = elevator_pos_2d.distance_to(player_pos_2d)
	
	var should_be_visible = distance_2d <= light_cull_distance
	if elevator_light.visible != should_be_visible:
		elevator_light.visible = should_be_visible

func _on_proximity_detection_body_entered(body: Node3D) -> void:
	print("Proximity detection triggered by: ", body.name, " (groups: ", body.get_groups(), ")")
	if body.is_in_group("player"):
		print("Player detected near elevator - opening doors")
		player_nearby = true
		open_doors()
	else:
		print("Body is not in player group")

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
		print("Doors already open")
		return
		
	print("Opening elevator doors...")
	doors_open = true
	
	# Stop existing tween
	if door_tween:
		door_tween.kill()
	
	# Create new tween
	door_tween = create_tween()
	door_tween.set_parallel(true)
	
	# Animate doors opening
	print("Animating door positions from ", door_left.position, " to ", left_door_open_pos)
	door_tween.tween_property(door_left, "position", left_door_open_pos, door_animation_speed)
	door_tween.tween_property(door_right, "position", right_door_open_pos, door_animation_speed)
	
	if has_node("ElevatorOpen"):
		$ElevatorOpen.play()
	# Change button color to indicate active state
	# Button removed - no visual feedback needed
	


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
	$ElevatorClose.play()
	# Change button back to normal color
	# Button removed - no visual feedback needed
	


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
	print("Elevator button pressed!")
	toggle_doors()
	
	# Play a button press sound
	if has_node("ElevatorOpen"):
		if not doors_open:
			$ElevatorOpen.play()
	
	# Visual feedback - make button flash
	_flash_button()

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

func _flash_button() -> void:
	# Create a quick flash effect for the button
	var flash_tween = create_tween()
	var bright_material = StandardMaterial3D.new()
	bright_material.albedo_color = Color.WHITE
	bright_material.emission_enabled = true
	bright_material.emission = Color.WHITE
	bright_material.emission_energy_multiplier = 2.0
	
	# Flash to white briefly
	# Button removed - no visual feedback needed
	flash_tween.tween_delay(0.1)
	# Button flashing removed - elevator operates automatically
