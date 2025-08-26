extends Camera3D

@export var follow_distance: float = 30.0
@export var minimap_size: float = 50.0

var player: Node3D

func _ready() -> void:
	position.y = follow_distance
	rotation_degrees.x = -90
	projection = PROJECTION_ORTHOGONAL
	size = minimap_size
	
	# Find the player
	player = get_tree().get_first_node_in_group("player")

func _process(_delta: float) -> void:
	if player:
		global_position = Vector3(player.global_position.x, follow_distance, player.global_position.z)