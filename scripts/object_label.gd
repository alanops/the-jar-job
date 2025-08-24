extends Node3D

class_name ObjectLabel

@export var label_text: String = "Object":
	set(value):
		label_text = value
		if label_3d:
			label_3d.text = value

@export var show_always: bool = false
@export var show_distance: float = 5.0

@onready var label_3d: Label3D = $Label3D
var player: Node3D

func _ready() -> void:
	# Find the player
	player = get_tree().get_first_node_in_group("player")
	
	# Set initial text
	if label_3d:
		label_3d.text = label_text
	
	# Hide by default unless show_always is true
	if not show_always:
		visible = false

func _process(_delta: float) -> void:
	if not player or show_always:
		return
	
	var distance := global_position.distance_to(player.global_position)
	visible = distance <= show_distance