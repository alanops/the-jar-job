extends StaticBody3D

@export var points_value: int = 50
@export var float_amplitude: float = 0.3
@export var float_speed: float = 2.0
@export var rotate_speed: float = 90.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var timer: Timer = $Timer

var collected: bool = false
var original_position: Vector3
var time_elapsed: float = 0.0

signal biscuit_collected(points: int)

func _ready() -> void:
	original_position = mesh_instance.position
	timer.timeout.connect(_on_timer_timeout)
	
	# Add to interactables group
	add_to_group("interactables")

func _process(delta: float) -> void:
	if collected:
		return
	
	time_elapsed += delta
	
	# Floating animation
	var float_offset = sin(time_elapsed * float_speed) * float_amplitude
	mesh_instance.position.y = original_position.y + float_offset
	
	# Rotation animation
	mesh_instance.rotation.y += deg_to_rad(rotate_speed) * delta

func _on_timer_timeout() -> void:
	# Pulse emission for visibility
	var material = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	if material:
		var pulse = (sin(time_elapsed * 3.0) + 1.0) * 0.5
		material.emission_energy = 0.2 + pulse * 0.4

func interact_with_player(player: Node) -> void:
	if collected:
		return
	
	collect()

func collect() -> void:
	if collected:
		return
	
	collected = true
	
	# Update GameManager stats
	if GameManager:
		GameManager.track_biscuit_collected()
		GameManager.score += points_value
	
	# Play collection sound
	if AudioManager:
		AudioManager.play_item_pickup()
	
	# Emit signal
	biscuit_collected.emit(points_value)
	
	# Visual feedback - quick scale up then fade out
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Vector3(1.5, 1.5, 1.5), 0.2)
	tween.parallel().tween_property(self, "modulate", Color.TRANSPARENT, 0.5)
	tween.tween_callback(queue_free)
	
	print("Biscuit collected! Points: ", points_value)
