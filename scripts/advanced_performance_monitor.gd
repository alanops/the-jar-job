extends Control

class_name AdvancedPerformanceMonitor

@onready var tabs: TabContainer = $Panel/TabContainer
@onready var fps_graph: Control = $Panel/TabContainer/Overview/VBoxContainer/FPSGraph
@onready var memory_graph: Control = $Panel/TabContainer/Overview/VBoxContainer/MemoryGraph
var cpu_list: ItemList
var summary_label: RichTextLabel

var profiler: PerformanceProfiler
var graph_points: int = 120  # 2 seconds at 60fps
var update_timer: float = 0.0
var update_interval: float = 0.1

# Graph data
var fps_history: Array[float] = []
var memory_history: Array[float] = []

func _ready() -> void:
	# Create profiler
	profiler = PerformanceProfiler.new()
	add_child(profiler)
	profiler.frame_data_updated.connect(_on_frame_data_updated)
	profiler.start_profiling()
	
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

func _on_frame_data_updated(frame_data: Dictionary) -> void:
	# Update history
	fps_history.append(frame_data.fps)
	memory_history.append(frame_data.memory_mb)
	
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
	
	var graph_size := fps_graph.size
	var points := PackedVector2Array()
	
	# Find min/max for scaling
	var min_fps := 0.0
	var max_fps := 60.0
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
	
	var graph_size := memory_graph.size
	var points := PackedVector2Array()
	
	# Find min/max for scaling
	var min_memory := memory_history[0]
	var max_memory := memory_history[0]
	for mem in memory_history:
		min_memory = min(min_memory, mem)
		max_memory = max(max_memory, mem)
	
	# Add some padding to the range
	var memory_range := max_memory - min_memory
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
	var summary := profiler.get_performance_summary()
	if not summary.has("cpu_sections"):
		return
	
	cpu_list.clear()
	var cpu_data = summary["cpu_sections"]
	
	# Sort by average time
	var sections := []
	for section_name in cpu_data:
		sections.append([section_name, cpu_data[section_name].avg_ms])
	sections.sort_custom(func(a, b): return a[1] > b[1])
	
	for section_data in sections:
		var section_name = section_data[0]
		var data = cpu_data[section_name]
		var text := "%s: %.2fms (max: %.2fms)" % [section_name, data.avg_ms, data.max_ms]
		cpu_list.add_item(text)

func _update_summary() -> void:
	var summary := profiler.get_performance_summary()
	var text := "[b]Performance Summary[/b]\n\n"
	
	if summary.has("frame_times"):
		var ft = summary["frame_times"]
		text += "[b]Frame Timing:[/b]\n"
		text += "• Average: %.1fms (%.1f FPS)\n" % [ft.average_ms, ft.avg_fps]
		text += "• Min/Max: %.1f/%.1fms\n" % [ft.min_ms, ft.max_ms]
		text += "• 95th percentile: %.1fms\n" % ft.p95_ms
		text += "• 99th percentile: %.1fms\n\n" % ft.p99_ms
	
	if summary.has("memory"):
		var mem = summary["memory"]
		text += "[b]Memory Usage:[/b]\n"
		text += "• Current: %.1f MB\n" % mem.current_mb
		text += "• Peak: %.1f MB\n" % mem.peak_mb
		text += "• Average: %.1f MB\n\n" % mem.average_mb
	
	if summary.has("rendering"):
		var rend = summary["rendering"]
		text += "[b]Rendering:[/b]\n"
		text += "• Draw calls: %d (peak: %d)\n" % [rend.current_draw_calls, rend.peak_draw_calls]
		text += "• Peak vertices: %d\n" % rend.peak_vertices
		text += "• Avg draw calls: %.1f\n\n" % rend.avg_draw_calls
	
	# Additional system info
	text += "[b]System Info:[/b]\n"
	text += "• Physics FPS: %d\n" % Engine.physics_ticks_per_second
	text += "• Active objects: %d\n" % Performance.get_monitor(Performance.OBJECT_COUNT)
	text += "• Active nodes: %d\n" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	text += "• Physics objects: %d\n" % Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	
	summary_label.text = text

func toggle_visibility() -> void:
	visible = !visible
	if visible:
		profiler.start_profiling()
	else:
		profiler.stop_profiling()

func profile_section_start(section_name: String) -> void:
	profiler.start_cpu_section(section_name)

func profile_section_end(section_name: String) -> void:
	profiler.end_cpu_section(section_name)

func log_performance_report() -> void:
	profiler.log_performance_summary()