extends Control

@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var tip_label: Label = $TipsContainer/TipLabel
@onready var fade_overlay: ColorRect = $FadeOverlay

var scene_path: String = ""
var loading_thread: Thread
var resource_loader_status: ResourceLoader.ThreadLoadStatus = ResourceLoader.THREAD_LOAD_IN_PROGRESS
var progress: Array = []

# Loading tips that cycle randomly
var loading_tips: Array[String] = [
	"Tip: Crouch to move quietly and avoid detection!",
	"Tip: NPCs have limited vision cones - stay out of their line of sight!",
	"Tip: Running makes noise that alerts nearby guards!",
	"Tip: Press Tab to switch camera views!",
	"Tip: The elevator is your escape route after getting the jar!",
	"Tip: Guards investigate suspicious sounds - use this to distract them!",
	"Tip: Press E to interact with objects!",
	"Tip: Stay in the shadows and move carefully!",
	"Tip: Guards have different patrol patterns - study their movements!",
	"Tip: The biscuit jar is somewhere in the office!"
]

# Loading status messages
var loading_statuses: Array[String] = [
	"Preparing stealth mission...",
	"Loading office environment...",
	"Initializing security guards...",
	"Setting up patrol routes...",
	"Hiding the biscuit jar...",
	"Calibrating vision cones...",
	"Testing elevator doors...",
	"Polishing flashlights...",
	"Almost ready..."
]

var current_status_index: int = 0
var status_timer: float = 0.0
var tip_timer: float = 0.0
var minimum_load_time: float = 2.0  # Minimum time to show loading screen
var elapsed_time: float = 0.0
var is_loaded: bool = false
var loaded_scene: PackedScene = null

func _ready() -> void:
	# Set random tip
	_update_tip()
	
	# Reset progress
	progress_bar.value = 0
	
	# Hide by default
	visible = false

func start_loading(path: String) -> void:
	scene_path = path
	visible = true
	progress_bar.value = 0.0
	progress_bar.max_value = 1.0
	current_status_index = 0
	status_timer = 0.0
	tip_timer = 0.0
	elapsed_time = 0.0
	is_loaded = false
	loaded_scene = null
	_update_status()
	
	# Start loading the scene in the background
	ResourceLoader.load_threaded_request(scene_path)
	
	print("Loading screen started for: ", scene_path)
	
	# Set initial progress to show bar is active
	progress_bar.value = 0.05

func _process(delta: float) -> void:
	if not visible:
		return
	
	# Update timers
	status_timer += delta
	tip_timer += delta
	elapsed_time += delta
	
	# Update status message every 0.8 seconds
	if status_timer >= 0.8:
		status_timer = 0.0
		current_status_index = min(current_status_index + 1, loading_statuses.size() - 1)
		_update_status()
	
	# Update tip every 3 seconds
	if tip_timer >= 3.0:
		tip_timer = 0.0
		_update_tip()
	
	# Check loading progress if not already loaded
	if not is_loaded:
		var load_progress = []
		var status = ResourceLoader.load_threaded_get_status(scene_path, load_progress)
		
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			# Loading complete! But don't transition yet
			is_loaded = true
			loaded_scene = ResourceLoader.load_threaded_get(scene_path)
			print("Scene loaded, waiting for minimum time...")
			
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			status_label.text = "Loading failed!"
			print("ERROR: Failed to load scene: ", scene_path)
			return
	
	# Calculate progress based on both actual loading and minimum time
	var time_progress = min(elapsed_time / minimum_load_time, 1.0)
	var load_progress = []
	var status = ResourceLoader.load_threaded_get_status(scene_path, load_progress)
	var actual_progress = 0.0
	
	if load_progress.size() > 0:
		actual_progress = load_progress[0]
	elif is_loaded:
		actual_progress = 1.0
	
	# Use whichever is lower to ensure smooth progress
	var combined_progress = min(time_progress, actual_progress) if not is_loaded else time_progress
	
	# Smooth progress bar animation
	progress_bar.value = lerp(progress_bar.value, combined_progress, delta * 5.0)
	
	# Check if we can transition
	if is_loaded and elapsed_time >= minimum_load_time:
		progress_bar.value = 1.0
		status_label.text = "Loading complete!"
		
		# Start cinematic fade transition
		await _start_cinematic_transition()
		
		print("Loading complete, transitioning to scene")

func _update_status() -> void:
	if current_status_index < loading_statuses.size():
		status_label.text = loading_statuses[current_status_index]

func _update_tip() -> void:
	tip_label.text = loading_tips[randi() % loading_tips.size()]

func set_custom_tip(tip: String) -> void:
	tip_label.text = tip

func set_custom_status(status: String) -> void:
	status_label.text = status

func _start_cinematic_transition() -> void:
	# Brief pause for dramatic effect
	await get_tree().create_timer(0.3).timeout
	
	# Create fade to black tween
	var fade_tween = create_tween()
	fade_tween.set_ease(Tween.EASE_IN)
	fade_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Fade to black over 1.5 seconds
	fade_tween.tween_property(fade_overlay, "color:a", 1.0, 1.5)
	
	# Wait for fade to complete
	await fade_tween.finished
	
	# Change to the loaded scene
	if loaded_scene:
		get_tree().change_scene_to_packed(loaded_scene)
	
	# The scene transition is now complete
	# Note: The new scene should handle fading in from black
