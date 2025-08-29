extends Node

# Performance optimization system
# Automatically adjusts game settings based on performance metrics

signal performance_adjusted(setting: String, old_value: Variant, new_value: Variant)

var target_fps: float = 60.0
var min_acceptable_fps: float = 30.0
var fps_samples: Array[float] = []
var sample_count: int = 60  # 1 second of samples at 60fps
var current_sample_index: int = 0

var frame_time_samples: Array[float] = []
var max_frame_time: float = 16.67  # Target 60fps (16.67ms per frame)

# Performance settings that can be adjusted
var current_vision_quality: int = 2  # 0=Low, 1=Medium, 2=High
var current_audio_quality: int = 2
var current_particle_quality: int = 2

# Optimization thresholds
var vision_optimization_threshold: float = 45.0  # FPS
var audio_optimization_threshold: float = 35.0
var particle_optimization_threshold: float = 40.0

var optimization_cooldown: float = 5.0  # Wait 5 seconds between adjustments
var last_optimization_time: float = 0.0

func _ready() -> void:
	name = "PerformanceOptimizer"
	
	# Initialize FPS sampling array
	fps_samples.resize(sample_count)
	fps_samples.fill(60.0)  # Start optimistically
	
	frame_time_samples.resize(sample_count)
	frame_time_samples.fill(16.67)
	
	DebugLogger.info("Performance optimizer initialized", "PerformanceOptimizer")

func _process(delta: float) -> void:
	if not GameConfig.enable_performance_monitoring:
		return
	
	_sample_performance(delta)
	_check_optimization_needs()

func _sample_performance(delta: float) -> void:
	# Sample FPS
	var current_fps = 1.0 / delta if delta > 0 else 60.0
	fps_samples[current_sample_index] = current_fps
	
	# Sample frame time in milliseconds
	var frame_time_ms = delta * 1000.0
	frame_time_samples[current_sample_index] = frame_time_ms
	
	current_sample_index = (current_sample_index + 1) % sample_count

func _check_optimization_needs() -> void:
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_optimization_time < optimization_cooldown:
		return
	
	var avg_fps = _get_average_fps()
	var avg_frame_time = _get_average_frame_time()
	
	# Only optimize if performance is consistently poor
	if _is_performance_consistently_poor(avg_fps):
		_optimize_performance(avg_fps)
		last_optimization_time = current_time

func _get_average_fps() -> float:
	var sum: float = 0.0
	for fps in fps_samples:
		sum += fps
	return sum / float(fps_samples.size())

func _get_average_frame_time() -> float:
	var sum: float = 0.0
	for frame_time in frame_time_samples:
		sum += frame_time
	return sum / float(frame_time_samples.size())

func _is_performance_consistently_poor(avg_fps: float) -> bool:
	# Check if at least 80% of recent samples are below threshold
	var poor_samples = 0
	for fps in fps_samples:
		if fps < min_acceptable_fps:
			poor_samples += 1
	
	var poor_ratio = float(poor_samples) / float(fps_samples.size())
	return poor_ratio >= 0.8

func _optimize_performance(avg_fps: float) -> void:
	DebugLogger.info("Performance optimization triggered - FPS: %.2f" % avg_fps, "PerformanceOptimizer")
	
	# Optimize in order of impact
	if avg_fps < vision_optimization_threshold and current_vision_quality > 0:
		_optimize_vision_system()
	elif avg_fps < particle_optimization_threshold and current_particle_quality > 0:
		_optimize_particle_system()
	elif avg_fps < audio_optimization_threshold and current_audio_quality > 0:
		_optimize_audio_system()

func _optimize_vision_system() -> void:
	var old_quality = current_vision_quality
	current_vision_quality = max(0, current_vision_quality - 1)
	
	match current_vision_quality:
		0:  # Low quality
			GameConfig.vision_check_intervals.very_far = 0.5
			GameConfig.vision_check_intervals.far = 0.3
			GameConfig.vision_check_intervals.medium = 0.15
			GameConfig.vision_check_intervals.close = 0.1
			GameConfig.max_concurrent_vision_checks = 2
			_adjust_vision_detection_points(2)  # Fewer detection points
			
		1:  # Medium quality
			GameConfig.vision_check_intervals.very_far = 0.3
			GameConfig.vision_check_intervals.far = 0.15
			GameConfig.vision_check_intervals.medium = 0.08
			GameConfig.vision_check_intervals.close = 0.05
			GameConfig.max_concurrent_vision_checks = 2
			_adjust_vision_detection_points(3)  # Standard detection points
	
	performance_adjusted.emit("vision_quality", old_quality, current_vision_quality)
	DebugLogger.info("Vision system optimized: %d -> %d" % [old_quality, current_vision_quality], "PerformanceOptimizer")

func _optimize_audio_system() -> void:
	var old_quality = current_audio_quality
	current_audio_quality = max(0, current_audio_quality - 1)
	
	match current_audio_quality:
		0:  # Low quality
			# Reduce audio sample rates, disable some effects
			_disable_non_essential_audio()
		1:  # Medium quality
			# Reduce some audio effects but keep essentials
			_reduce_audio_effects()
	
	performance_adjusted.emit("audio_quality", old_quality, current_audio_quality)
	DebugLogger.info("Audio system optimized: %d -> %d" % [old_quality, current_audio_quality], "PerformanceOptimizer")

func _optimize_particle_system() -> void:
	var old_quality = current_particle_quality
	current_particle_quality = max(0, current_particle_quality - 1)
	
	# Find particle systems and reduce their complexity
	var particle_systems = get_tree().get_nodes_in_group("particles")
	for particle_system in particle_systems:
		if particle_system.has_method("set_quality_level"):
			particle_system.set_quality_level(current_particle_quality)
	
	performance_adjusted.emit("particle_quality", old_quality, current_particle_quality)
	DebugLogger.info("Particle system optimized: %d -> %d" % [old_quality, current_particle_quality], "PerformanceOptimizer")

func _adjust_vision_detection_points(max_points: int) -> void:
	# Communicate to vision system to use fewer detection points
	var vision_system = get_node_or_null("/root/VisionSystem")
	if vision_system and vision_system.has_method("set"):
		vision_system.max_detection_points = max_points

func _disable_non_essential_audio() -> void:
	# Disable ambient sounds and some SFX to improve performance
	if AudioManager:
		AudioManager.stop_ambient()
		# Could add more audio optimizations here

func _reduce_audio_effects() -> void:
	# Reduce audio effects but keep essential gameplay sounds
	if AudioManager:
		# Reduce ambient volume
		AudioManager.set_ambient_volume(AudioManager.ambient_volume * 0.7)

func get_performance_metrics() -> Dictionary:
	return {
		"average_fps": _get_average_fps(),
		"average_frame_time": _get_average_frame_time(),
		"vision_quality": current_vision_quality,
		"audio_quality": current_audio_quality,
		"particle_quality": current_particle_quality,
		"last_optimization": last_optimization_time
	}

func reset_performance_settings() -> void:
	current_vision_quality = 2
	current_audio_quality = 2
	current_particle_quality = 2
	
	# Reset vision settings to high quality
	GameConfig.vision_check_intervals.very_far = 0.2
	GameConfig.vision_check_intervals.far = 0.1
	GameConfig.vision_check_intervals.medium = 0.05
	GameConfig.vision_check_intervals.close = 0.02
	GameConfig.max_concurrent_vision_checks = 3
	
	var vision_system = get_node_or_null("/root/VisionSystem")
	if vision_system and vision_system.has_method("set"):
		vision_system.max_detection_points = 8
	
	DebugLogger.info("Performance settings reset to high quality", "PerformanceOptimizer")

func force_optimization_level(level: int) -> void:
	level = clamp(level, 0, 2)
	
	if level != current_vision_quality:
		_force_vision_quality(level)
	if level != current_audio_quality:
		_force_audio_quality(level)
	if level != current_particle_quality:
		_force_particle_quality(level)

func _force_vision_quality(quality: int) -> void:
	current_vision_quality = quality
	_optimize_vision_system()

func _force_audio_quality(quality: int) -> void:
	current_audio_quality = quality
	_optimize_audio_system()

func _force_particle_quality(quality: int) -> void:
	current_particle_quality = quality
	_optimize_particle_system()