extends Node3D

@export var light_tile_scene: PackedScene = preload("res://environment/office_floor.tscn")
@export var dark_tile_scene: PackedScene = preload("res://environment/office_floor_dark.tscn")
@export var grid_width: int = 6
@export var grid_height: int = 6
@export var tile_size: float = 4.0
@export var start_position: Vector3 = Vector3(-10, 0, -10)

func _ready():
	generate_checkered_floor()

func generate_checkered_floor():
	# Clear existing floor tiles
	for child in get_children():
		child.queue_free()
	
	# Generate checkered pattern
	for row in range(grid_height):
		for col in range(grid_width):
			var is_dark = (row + col) % 2 == 1
			var tile_scene = dark_tile_scene if is_dark else light_tile_scene
			
			if tile_scene:
				var tile = tile_scene.instantiate()
				add_child(tile)
				
				var x_pos = start_position.x + col * tile_size
				var z_pos = start_position.z + row * tile_size
				tile.position = Vector3(x_pos, 0, z_pos)