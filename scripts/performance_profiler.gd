extends Node

class_name PerformanceProfiler

signal frame_data_updated(frame_data: Dictionary)

var frame_times: Array[float] = []
var cpu_usage_history: Array[float] = []
var memory_usage_history: Array[float] = []
var draw_call_history: Array[int] = []
var max_samples: int = 300  # 5 seconds at 60fps

var profiling_enabled: bool = false
var detailed_profiling: bool = false

# Frame timing
var frame_start_time: int = 0
var last_frame_time: float = 0.0

# CPU profiling
var cpu_time_sections: Dictionary = {}
var section_start_times: Dictionary = {}

# Memory profiling  
var peak_memory_usage: float = 0.0
var memory_allocations: int = 0

# Rendering profiling
var peak_draw_calls: int = 0
var peak_vertices: int = 0

func _ready() -> void:
	# Enable detailed profiling in debug builds
	detailed_profiling = OS.is_debug_build()
	set_process(true)

func _process(_delta: float) -> void:
	if not profiling_enabled:
		return
	
	_collect_frame_data()
	
	# Limit history size
	if frame_times.size() > max_samples:
		frame_times.pop_front()
	if cpu_usage_history.size() > max_samples:
		cpu_usage_history.pop_front()
	if memory_usage_history.size() > max_samples:
		memory_usage_history.pop_front()
	if draw_call_history.size() > max_samples:
		draw_call_history.pop_front()

func start_profiling() -> void:
	profiling_enabled = true
	frame_times.clear()
	cpu_usage_history.clear()
	memory_usage_history.clear()
	draw_call_history.clear()
	_reset_peaks()

func stop_profiling() -> void:
	profiling_enabled = false

func _collect_frame_data() -> void:
	var current_time := Time.get_ticks_usec()
	
	# Frame timing
	if frame_start_time > 0:
		var frame_time_us := current_time - frame_start_time
		var frame_time_ms := frame_time_us / 1000.0
		frame_times.append(frame_time_ms)
		last_frame_time = frame_time_ms
	frame_start_time = current_time
	
	# Memory usage
	var static_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	var dynamic_memory := Performance.get_monitor(Performance.MEMORY_DYNAMIC)
	var total_memory := (static_memory + dynamic_memory) / 1048576.0  # Convert to MB
	memory_usage_history.append(total_memory)
	
	if total_memory > peak_memory_usage:
		peak_memory_usage = total_memory
	
	# Rendering metrics
	var draw_calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var vertices := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	
	draw_call_history.append(draw_calls)
	
	if draw_calls > peak_draw_calls:
		peak_draw_calls = draw_calls
	if vertices > peak_vertices:
		peak_vertices = vertices
	
	# Emit frame data
	var frame_data := {
		"frame_time_ms": last_frame_time,
		"memory_mb": total_memory,
		"draw_calls": draw_calls,
		"vertices": vertices,
		"fps": Engine.get_frames_per_second()
	}
	
	frame_data_updated.emit(frame_data)

func start_cpu_section(section_name: String) -> void:
	if not detailed_profiling:
		return
	section_start_times[section_name] = Time.get_ticks_usec()

func end_cpu_section(section_name: String) -> void:
	if not detailed_profiling or not section_start_times.has(section_name):
		return
	
	var end_time := Time.get_ticks_usec()
	var duration := (end_time - section_start_times[section_name]) / 1000.0  # Convert to ms
	
	if not cpu_time_sections.has(section_name):
		cpu_time_sections[section_name] = []
	
	cpu_time_sections[section_name].append(duration)
	
	# Keep only recent samples
	if cpu_time_sections[section_name].size() > 60:
		cpu_time_sections[section_name].pop_front()
	
	section_start_times.erase(section_name)

func get_performance_summary() -> Dictionary:
	if frame_times.is_empty():
		return {}
	
	var summary := {}
	
	# Frame time statistics
	var avg_frame_time := _calculate_average(frame_times)
	var min_frame_time := _calculate_min(frame_times)
	var max_frame_time := _calculate_max(frame_times)
	var percentile_99 := _calculate_percentile(frame_times, 0.99)
	var percentile_95 := _calculate_percentile(frame_times, 0.95)
	
	summary["frame_times"] = {
		"average_ms": avg_frame_time,
		"min_ms": min_frame_time,
		"max_ms": max_frame_time,
		"p99_ms": percentile_99,
		"p95_ms": percentile_95,
		"avg_fps": 1000.0 / avg_frame_time if avg_frame_time > 0 else 0
	}
	
	# Memory statistics
	if not memory_usage_history.is_empty():
		summary["memory"] = {
			"current_mb": memory_usage_history[-1],
			"peak_mb": peak_memory_usage,
			"average_mb": _calculate_average(memory_usage_history)
		}
	
	# Rendering statistics
	if not draw_call_history.is_empty():
		summary["rendering"] = {
			"current_draw_calls": draw_call_history[-1],
			"peak_draw_calls": peak_draw_calls,
			"peak_vertices": peak_vertices,
			"avg_draw_calls": _calculate_average(draw_call_history.map(func(x): return float(x)))
		}
	
	# CPU section timings
	if detailed_profiling and not cpu_time_sections.is_empty():
		var cpu_summary := {}
		for section_name in cpu_time_sections:
			var times = cpu_time_sections[section_name]
			cpu_summary[section_name] = {
				"avg_ms": _calculate_average(times),
				"max_ms": _calculate_max(times),
				"total_ms": _calculate_sum(times)
			}
		summary["cpu_sections"] = cpu_summary
	
	return summary

func get_frame_time_graph_data() -> Array[float]:
	return frame_times.duplicate()

func get_memory_graph_data() -> Array[float]:
	return memory_usage_history.duplicate()

func _reset_peaks() -> void:
	peak_memory_usage = 0.0
	peak_draw_calls = 0
	peak_vertices = 0
	memory_allocations = 0

func _calculate_average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for value in values:
		sum += value
	return sum / values.size()

func _calculate_min(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var min_val = values[0]
	for value in values:
		if value < min_val:
			min_val = value
	return min_val

func _calculate_max(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var max_val = values[0]
	for value in values:
		if value > max_val:
			max_val = value
	return max_val

func _calculate_sum(values: Array) -> float:
	var sum := 0.0
	for value in values:
		sum += value
	return sum

func _calculate_percentile(values: Array, percentile: float) -> float:
	if values.is_empty():
		return 0.0
	
	var sorted_values = values.duplicate()
	sorted_values.sort()
	
	var index := int((sorted_values.size() - 1) * percentile)
	return sorted_values[index]

func log_performance_summary() -> void:
	var summary := get_performance_summary()
	print("=== Performance Summary ===")
	
	if summary.has("frame_times"):
		var ft = summary["frame_times"]
		print("Frame Times: avg=%.1fms, min=%.1fms, max=%.1fms, p99=%.1fms (%.1f FPS)" % 
			[ft.average_ms, ft.min_ms, ft.max_ms, ft.p99_ms, ft.avg_fps])
	
	if summary.has("memory"):
		var mem = summary["memory"]
		print("Memory: current=%.1fMB, peak=%.1fMB, avg=%.1fMB" % 
			[mem.current_mb, mem.peak_mb, mem.average_mb])
	
	if summary.has("rendering"):
		var rend = summary["rendering"]
		print("Rendering: draw_calls=%d, peak_draws=%d, peak_verts=%d" % 
			[rend.current_draw_calls, rend.peak_draw_calls, rend.peak_vertices])
	
	if summary.has("cpu_sections"):
		print("CPU Sections:")
		for section in summary["cpu_sections"]:
			var data = summary["cpu_sections"][section]
			print("  %s: avg=%.2fms, max=%.2fms" % [section, data.avg_ms, data.max_ms])