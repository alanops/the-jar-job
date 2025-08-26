# This script adds the elevator to the game scene
# Run this in Godot editor to add the elevator at the correct position

@tool
extends EditorScript

func _run():
	var scene = load("res://scenes/game.tscn")
	var game = scene.instantiate()
	
	# Load elevator scene
	var elevator_scene = load("res://environment/elevator.tscn")
	var elevator_instance = elevator_scene.instantiate()
	
	# Find the Office node
	var office = game.find_child("Office")
	if not office:
		print("Error: Could not find Office node")
		return
		
	# Add elevator container
	var elevator_container = Node3D.new()
	elevator_container.name = "Elevator"
	elevator_container.transform.origin = Vector3(-9, 0, -9)
	office.add_child(elevator_container)
	elevator_container.owner = game
	
	# Add elevator instance
	elevator_instance.name = "Elevator"
	elevator_container.add_child(elevator_instance)
	elevator_instance.owner = game
	
	# Add elevator label
	var label_scene = load("res://environment/object_label.tscn")
	if label_scene:
		var label = label_scene.instantiate()
		label.name = "ElevatorLabel"
		label.set("label_text", "🔽 LIFT")
		label.set("show_distance", 6.0)
		elevator_container.add_child(label)
		label.owner = game
	
	# Save the modified scene
	var packed_scene = PackedScene.new()
	packed_scene.pack(game)
	ResourceSaver.save(packed_scene, "res://scenes/game.tscn")
	
	print("Elevator added successfully at position (-9, 0, -9)")