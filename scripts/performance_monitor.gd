extends Control

class_name PerformanceMonitor

@onready var fps_label: Label = $Panel/VBoxContainer/FPSLabel
@onready var frame_time_label: Label = $Panel/VBoxContainer/FrameTimeLabel
@onready var draw_calls_label: Label = $Panel/VBoxContainer/DrawCallsLabel
@onready var vertices_label: Label = $Panel/VBoxContainer/VerticesLabel
@onready var memory_label: Label = $Panel/VBoxContainer/MemoryLabel
@onready var objects_label: Label = $Panel/VBoxContainer/ObjectsLabel
@onready var nodes_label: Label = $Panel/VBoxContainer/NodesLabel
@onready var physics_label: Label = $Panel/VBoxContainer/PhysicsLabel

var update_timer: float = 0.0
var update_interval: float = 0.25  # Update 4 times per second
var frame_time_history: Array[float] = []
var max_history: int = 60

func _ready() -> void:
	# Make sure panel is on top
	z_index = 100
	
	# Initialize history
	for i in range(max_history):
		frame_time_history.append(0.0)

func _process(delta: float) -> void:
	update_timer += delta
	
	# Add to frame time history
	frame_time_history.append(delta * 1000.0)  # Convert to milliseconds
	if frame_time_history.size() > max_history:
		frame_time_history.pop_front()
	
	if update_timer >= update_interval:
		update_timer = 0.0
		_update_metrics()

func _update_metrics() -> void:
	# FPS
	var fps := Engine.get_frames_per_second()
	fps_label.text = "FPS: %d" % fps
	
	# Color code FPS
	if fps >= 55:
		fps_label.modulate = Color.GREEN
	elif fps >= 30:
		fps_label.modulate = Color.YELLOW
	else:
		fps_label.modulate = Color.RED
	
	# Frame time (average over history)
	var avg_frame_time: float = 0.0
	var max_frame_time: float = 0.0
	for time in frame_time_history:
		avg_frame_time += time
		max_frame_time = max(max_frame_time, time)
	avg_frame_time /= frame_time_history.size()
	frame_time_label.text = "Frame: %.1fms (max: %.1fms)" % [avg_frame_time, max_frame_time]
	
	# Rendering metrics
	var render_info := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var vertex_count := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	draw_calls_label.text = "Draw Calls: %d" % render_info
	vertices_label.text = "Vertices: %d" % vertex_count
	
	# Memory usage
	var static_memory := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var dynamic_memory := Performance.get_monitor(Performance.MEMORY_DYNAMIC) / 1048576.0
	memory_label.text = "Memory: %.1fMB (S:%.1f D:%.1f)" % [static_memory + dynamic_memory, static_memory, dynamic_memory]
	
	# Object counts
	var object_count := Performance.get_monitor(Performance.OBJECT_COUNT)
	var node_count := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	objects_label.text = "Objects: %d" % object_count
	nodes_label.text = "Nodes: %d" % node_count
	
	# Physics
	var physics_fps := Engine.physics_ticks_per_second
	var physics_objects := Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	physics_label.text = "Physics: %d Hz, %d objects" % [physics_fps, physics_objects]

func toggle_visibility() -> void:
	visible = !visible

func set_position_preset(preset: String) -> void:
	var viewport_size := get_viewport_rect().size
	var panel_size := $Panel.size
	
	match preset:
		"top_left":
			$Panel.position = Vector2(10, 10)
		"top_right":
			$Panel.position = Vector2(viewport_size.x - panel_size.x - 10, 10)
		"bottom_left":
			$Panel.position = Vector2(10, viewport_size.y - panel_size.y - 10)
		"bottom_right":
			$Panel.position = Vector2(viewport_size.x - panel_size.x - 10, viewport_size.y - panel_size.y - 10)