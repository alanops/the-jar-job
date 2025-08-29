extends StaticBody3D

@export var secret_name: String = "Secret Item"
@export var points_value: int = 100
@export var rarity: String = "Common"  # Common, Rare, Legendary
@export var float_amplitude: float = 0.2
@export var float_speed: float = 1.5
@export var rotate_speed: float = 45.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var timer: Timer = $Timer

var collected: bool = false
var original_position: Vector3
var time_elapsed: float = 0.0

signal secret_collected(secret_name: String, points: int, rarity: String)

func _ready() -> void:
	original_position = mesh_instance.position
	timer.timeout.connect(_on_timer_timeout)
	
	# Add to interactables group
	add_to_group("interactables")
	
	# Adjust visual effects based on rarity
	_setup_rarity_effects()

func _setup_rarity_effects() -> void:
	var material = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	if not material:
		return
	
	match rarity:
		"Common":
			float_speed = 1.5
			rotate_speed = 45.0
			material.emission_energy = 0.2
		"Rare":
			float_speed = 2.0
			rotate_speed = 90.0
			material.emission_energy = 0.4
		"Legendary":
			float_speed = 3.0
			rotate_speed = 180.0
			material.emission_energy = 0.6

func _process(delta: float) -> void:
	if collected:
		return
	
	time_elapsed += delta
	
	# Floating animation
	var float_offset = sin(time_elapsed * float_speed) * float_amplitude
	mesh_instance.position.y = original_position.y + float_offset
	
	# Rotation animation - more dramatic for rarer items
	mesh_instance.rotation.y += deg_to_rad(rotate_speed) * delta

func _on_timer_timeout() -> void:
	# Pulse emission for visibility - more intense for rarer items
	var material = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	if material:
		var pulse_speed = 3.0 if rarity == "Common" else (4.0 if rarity == "Rare" else 6.0)
		var pulse = (sin(time_elapsed * pulse_speed) + 1.0) * 0.5
		var base_energy = 0.2 if rarity == "Common" else (0.4 if rarity == "Rare" else 0.6)
		material.emission_energy = base_energy + pulse * base_energy

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
		GameManager.track_secret_collected(secret_name, rarity)
		GameManager.score += points_value
	
	# Play collection sound based on rarity
	if AudioManager:
		match rarity:
			"Common":
				AudioManager.play_item_pickup()
			"Rare":
				AudioManager.play_item_pickup()  # Could add special rare sound
			"Legendary":
				AudioManager.play_victory()  # Special sound for legendary items
	
	# Emit signal
	secret_collected.emit(secret_name, points_value, rarity)
	
	# Visual feedback - more dramatic for rarer items
	var tween = create_tween()
	var scale_factor = 1.5 if rarity == "Common" else (2.0 if rarity == "Rare" else 2.5)
	var duration = 0.3 if rarity == "Common" else (0.5 if rarity == "Rare" else 0.7)
	
	tween.parallel().tween_property(self, "scale", Vector3(scale_factor, scale_factor, scale_factor), duration * 0.4)
	tween.parallel().tween_property(self, "modulate", Color.TRANSPARENT, duration)
	tween.tween_callback(queue_free)
	
	# Show special message for rare items
	var rarity_color = Color.WHITE
	match rarity:
		"Rare":
			rarity_color = Color.BLUE
		"Legendary":
			rarity_color = Color.GOLD
	
	print("SECRET FOUND! [%s] %s - %d points" % [rarity, secret_name, points_value])