extends Control

class_name AdvancedPerformanceMonitor

@onready var tabs: TabContainer = $Panel/TabContainer
@onready var fps_graph: Control = $Panel/TabContainer/Overview/VBoxContainer/FPSGraph
@onready var memory_graph: Control = $Panel/TabContainer/Overview/VBoxContainer/MemoryGraph
var cpu_list: ItemList
var summary_label: RichTextLabel

var graph_points: int = 120  # 2 seconds at 60fps
var update_timer: float = 0.0
var update_interval: float = 0.1

# Graph data
var fps_history: Array[float] = []
var memory_history: Array[float] = []

func _ready() -> void:
	# Use Godot's built-in performance monitoring
	
	# Set up UI
	z_index = 1000
	visible = false
	
	# Initialize graphs
	if fps_graph:
		fps_graph.custom_minimum_size = Vector2(300, 100)
		fps_graph.draw.connect(_draw_fps_graph)
	if memory_graph:
		memory_graph.custom_minimum_size = Vector2(300, 100)
		memory_graph.draw.connect(_draw_memory_graph)
	
	# Find other UI elements
	cpu_list = get_node_or_null("Panel/TabContainer/CPU/VBoxContainer/CPUList")
	summary_label = get_node_or_null("Panel/TabContainer/Summary/SummaryLabel")

func _process(delta: float) -> void:
	update_timer += delta
	if update_timer >= update_interval:
		update_timer = 0.0
		_update_displays()
		_collect_performance_data()

func _collect_performance_data() -> void:
	# Collect performance data using Godot's built-in monitoring
	var fps = Engine.get_frames_per_second()
	var memory_mb = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0
	
	# Update history
	fps_history.append(fps)
	memory_history.append(memory_mb)
	
	# Limit history size
	if fps_history.size() > graph_points:
		fps_history.pop_front()
	if memory_history.size() > graph_points:
		memory_history.pop_front()

func _update_displays() -> void:
	# Redraw graphs
	if fps_graph:
		fps_graph.queue_redraw()
	if memory_graph:
		memory_graph.queue_redraw()
	
	# Update CPU list
	if cpu_list:
		_update_cpu_list()
	
	# Update summary
	if summary_label:
		_update_summary()

func _draw_fps_graph() -> void:
	if fps_history.is_empty():
		return
	
	var graph_size: Vector2 = fps_graph.size
	var points := PackedVector2Array()
	
	# Find min/max for scaling
	var min_fps: float = 0.0
	var max_fps: float = 60.0
	for fps in fps_history:
		max_fps = max(max_fps, fps)
	
	# Generate points
	for i in range(fps_history.size()):
		var x := (float(i) / graph_points) * graph_size.x
		var normalized_fps := (fps_history[i] - min_fps) / (max_fps - min_fps)
		var y := graph_size.y - (normalized_fps * graph_size.y)
		points.append(Vector2(x, y))
	
	# Draw background
	fps_graph.draw_rect(Rect2(Vector2.ZERO, graph_size), Color.BLACK)
	
	# Draw grid lines
	for i in range(5):
		var y := (float(i) / 4) * graph_size.y
		fps_graph.draw_line(Vector2(0, y), Vector2(graph_size.x, y), Color.GRAY, 1)
	
	# Draw FPS line
	if points.size() > 1:
		for i in range(1, points.size()):
			var color := Color.GREEN if fps_history[i] >= 55 else (Color.YELLOW if fps_history[i] >= 30 else Color.RED)
			fps_graph.draw_line(points[i-1], points[i], color, 2)
	
	# Draw labels
	fps_graph.draw_string(get_theme_default_font(), Vector2(5, 15), "FPS: %.1f" % (fps_history[-1] if not fps_history.is_empty() else 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	fps_graph.draw_string(get_theme_default_font(), Vector2(5, graph_size.y - 5), "Max: %.1f" % max_fps, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

func _draw_memory_graph() -> void:
	if memory_history.is_empty():
		return
	
	var graph_size: Vector2 = memory_graph.size
	var points := PackedVector2Array()
	
	# Find min/max for scaling
	var min_memory: float = memory_history[0]
	var max_memory: float = memory_history[0]
	for mem in memory_history:
		min_memory = min(min_memory, mem)
		max_memory = max(max_memory, mem)
	
	# Add some padding to the range
	var memory_range: float = max_memory - min_memory
	if memory_range < 1.0:  # Minimum 1MB range
		memory_range = 1.0
		max_memory = min_memory + memory_range
	
	# Generate points
	for i in range(memory_history.size()):
		var x := (float(i) / graph_points) * graph_size.x
		var normalized_memory := (memory_history[i] - min_memory) / memory_range
		var y := graph_size.y - (normalized_memory * graph_size.y)
		points.append(Vector2(x, y))
	
	# Draw background
	memory_graph.draw_rect(Rect2(Vector2.ZERO, graph_size), Color.BLACK)
	
	# Draw grid lines
	for i in range(5):
		var y := (float(i) / 4) * graph_size.y
		memory_graph.draw_line(Vector2(0, y), Vector2(graph_size.x, y), Color.GRAY, 1)
	
	# Draw memory line
	if points.size() > 1:
		for i in range(1, points.size()):
			memory_graph.draw_line(points[i-1], points[i], Color.CYAN, 2)
	
	# Draw labels
	memory_graph.draw_string(get_theme_default_font(), Vector2(5, 15), "Memory: %.1fMB" % (memory_history[-1] if not memory_history.is_empty() else 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	memory_graph.draw_string(get_theme_default_font(), Vector2(5, graph_size.y - 5), "Range: %.1f-%.1fMB" % [min_memory, max_memory], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

func _update_cpu_list() -> void:
	if not cpu_list:
		return
		
	cpu_list.clear()
	# Use Godot's built-in performance monitoring
	var cpu_time = Performance.get_monitor(Performance.TIME_PROCESS)
	var physics_time = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var render_time = Performance.get_monitor(Performance.TIME_RENDER)
	
	cpu_list.add_item("Process: %.2fms" % (cpu_time * 1000))
	cpu_list.add_item("Physics: %.2fms" % (physics_time * 1000))
	cpu_list.add_item("Render: %.2fms" % (render_time * 1000))

func _update_summary() -> void:
	if not summary_label:
		return
		
	var text := "[b]Performance Summary[/b]\n\n"
	
	# Frame timing info using built-in monitoring
	var fps = Engine.get_frames_per_second()
	var frame_time = 1000.0 / fps if fps > 0 else 0
	text += "[b]Frame Timing:[/b]\n"
	text += "• Current FPS: %.1f\n" % fps
	text += "• Frame time: %.2fms\n\n" % frame_time
	
	# Memory info
	var memory_mb = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0
	text += "[b]Memory Usage:[/b]\n"
	text += "• Static memory: %.1fMB\n\n" % memory_mb
	
	# Rendering info using built-in performance monitoring
	text += "[b]Rendering:[/b]\n"
	text += "• Render objects: %d\n" % Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	text += "• Render primitives: %d\n\n" % Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	
	# Additional system info
	text += "[b]System Info:[/b]\n"
	text += "• Physics FPS: %d\n" % Engine.physics_ticks_per_second
	text += "• Active objects: %d\n" % Performance.get_monitor(Performance.OBJECT_COUNT)
	text += "• Active nodes: %d\n" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	text += "• Physics objects: %d\n" % Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	
	summary_label.text = text

func toggle_visibility() -> void:
	visible = !visible
	# Performance monitoring is always active with built-in system

func profile_section_start(section_name: String) -> void:
	# CPU section profiling not available with simplified system
	pass

func profile_section_end(section_name: String) -> void:
	# CPU section profiling not available with simplified system  
	pass

func log_performance_report() -> void:
	print("=== Performance Report ===")
	print("FPS: ", Engine.get_frames_per_second())
	print("Memory: %.1fMB" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0))
	print("Active Objects: ", Performance.get_monitor(Performance.OBJECT_COUNT))
	print("Active Nodes: ", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
