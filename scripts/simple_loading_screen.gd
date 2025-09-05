extends Control

@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var status_label: Label = $VBoxContainer/StatusLabel

var target_scene: String = ""
var load_progress: float = 0.0
var displayed_progress: float = 0.0
var loading_complete: bool = false
var minimum_loading_time: float = 2.0  # Show loading for at least 2 seconds
var loading_start_time: float = 0.0

func _ready():
	visible = false

func start_loading(scene_path: String):
	target_scene = scene_path
	visible = true
	loading_complete = false
	load_progress = 0.0
	displayed_progress = 0.0
	progress_bar.value = 0.0
	status_label.text = "Loading game..."
	loading_start_time = Time.get_ticks_msec() / 1000.0
	
	# Start threaded loading
	ResourceLoader.load_threaded_request(scene_path)
	print("Started loading: ", scene_path)

func _process(delta):
	if not visible or target_scene.is_empty():
		return
		
	# Check loading progress
	var load_status = []
	var status = ResourceLoader.load_threaded_get_status(target_scene, load_status)
	
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if load_status.size() > 0:
				load_progress = load_status[0]
		
		ResourceLoader.THREAD_LOAD_LOADED:
			load_progress = 1.0
		
		ResourceLoader.THREAD_LOAD_FAILED:
			status_label.text = "Loading failed!"
			print("ERROR: Failed to load scene: ", target_scene)
			return
	
	# Smooth progress bar animation
	displayed_progress = move_toward(displayed_progress, load_progress, delta * 2.0)
	progress_bar.value = displayed_progress
	status_label.text = "Loading... " + str(int(displayed_progress * 100)) + "%"
	
	# Check if loading is complete and minimum time has passed
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_elapsed = current_time - loading_start_time
	
	if displayed_progress >= 1.0 and time_elapsed >= minimum_loading_time and not loading_complete:
		status_label.text = "Complete!"
		loading_complete = true
		# Short delay before transition
		await get_tree().create_timer(0.5).timeout
		_transition_to_scene()

func _transition_to_scene():
	var loaded_scene = ResourceLoader.load_threaded_get(target_scene)
	if loaded_scene:
		get_tree().change_scene_to_packed(loaded_scene)
	else:
		print("ERROR: Could not get loaded scene")