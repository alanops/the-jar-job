extends Control

class_name PerformanceSettings

@onready var vsync_option: OptionButton = $Panel/VBoxContainer/VSyncContainer/VSyncOption
@onready var shadow_quality_slider: HSlider = $Panel/VBoxContainer/ShadowContainer/ShadowQualitySlider
@onready var shadow_quality_label: Label = $Panel/VBoxContainer/ShadowContainer/ShadowQualityLabel
@onready var msaa_option: OptionButton = $Panel/VBoxContainer/MSAAContainer/MSAAOption
@onready var fxaa_checkbox: CheckBox = $Panel/VBoxContainer/FXAAContainer/FXAACheckbox
@onready var lod_bias_slider: HSlider = $Panel/VBoxContainer/LODContainer/LODBiasSlider
@onready var lod_bias_label: Label = $Panel/VBoxContainer/LODContainer/LODBiasLabel
@onready var max_fps_slider: HSlider = $Panel/VBoxContainer/MaxFPSContainer/MaxFPSSlider
@onready var max_fps_label: Label = $Panel/VBoxContainer/MaxFPSContainer/MaxFPSLabel
@onready var apply_button: Button = $Panel/VBoxContainer/ButtonContainer/ApplyButton
@onready var reset_button: Button = $Panel/VBoxContainer/ButtonContainer/ResetButton

# Performance presets
var performance_presets := {
	"low": {
		"vsync": 0,  # Disabled
		"shadow_quality": 0,  # Low
		"msaa": 0,  # Disabled
		"fxaa": false,
		"lod_bias": 2.0,  # Higher LOD bias = lower quality
		"max_fps": 30
	},
	"medium": {
		"vsync": 1,  # Enabled
		"shadow_quality": 1,  # Medium
		"msaa": 1,  # 2x
		"fxaa": false,
		"lod_bias": 1.0,
		"max_fps": 60
	},
	"high": {
		"vsync": 1,  # Enabled
		"shadow_quality": 2,  # High
		"msaa": 2,  # 4x
		"fxaa": true,
		"lod_bias": 0.5,
		"max_fps": 0  # Unlimited
	}
}

func _ready() -> void:
	# Set up UI connections
	vsync_option.item_selected.connect(_on_setting_changed)
	shadow_quality_slider.value_changed.connect(_on_shadow_quality_changed)
	msaa_option.item_selected.connect(_on_setting_changed)
	fxaa_checkbox.toggled.connect(_on_setting_changed)
	lod_bias_slider.value_changed.connect(_on_lod_bias_changed)
	max_fps_slider.value_changed.connect(_on_max_fps_changed)
	apply_button.pressed.connect(_apply_settings)
	reset_button.pressed.connect(_reset_to_defaults)
	
	# Initialize UI
	_setup_options()
	_load_current_settings()
	
	# Hide initially
	visible = false

func _setup_options() -> void:
	# VSync options
	vsync_option.add_item("Disabled")
	vsync_option.add_item("Enabled")
	vsync_option.add_item("Adaptive")
	
	# MSAA options
	msaa_option.add_item("Disabled")
	msaa_option.add_item("2x")
	msaa_option.add_item("4x")
	msaa_option.add_item("8x")
	
	# Shadow quality slider
	shadow_quality_slider.min_value = 0
	shadow_quality_slider.max_value = 2
	shadow_quality_slider.step = 1
	
	# LOD bias slider
	lod_bias_slider.min_value = 0.25
	lod_bias_slider.max_value = 4.0
	lod_bias_slider.step = 0.25
	lod_bias_slider.value = 1.0
	
	# Max FPS slider
	max_fps_slider.min_value = 0
	max_fps_slider.max_value = 144
	max_fps_slider.step = 1
	max_fps_slider.value = 60

func _load_current_settings() -> void:
	# Load from project settings or set defaults
	var current_vsync := DisplayServer.window_get_vsync_mode()
	vsync_option.selected = int(current_vsync)
	
	# Shadow quality (simplified mapping)
	var shadow_size := 2048  # Default medium shadow size
	var shadow_quality := 1  # Default medium
	if shadow_size <= 1024:
		shadow_quality = 0  # Low
	elif shadow_size >= 4096:
		shadow_quality = 2  # High
	
	shadow_quality_slider.value = shadow_quality
	_on_shadow_quality_changed(shadow_quality)
	
	# Get current viewport for MSAA
	var viewport := get_viewport()
	if viewport:
		var msaa := viewport.msaa_3d
		msaa_option.selected = int(msaa)
	
	# FXAA (get from viewport)
	if viewport:
		fxaa_checkbox.button_pressed = viewport.use_fxaa
	
	# LOD bias (simplified)
	lod_bias_slider.value = 1.0  # Default value
	_on_lod_bias_changed(lod_bias_slider.value)
	
	# Max FPS
	var current_max_fps := Engine.max_fps
	max_fps_slider.value = current_max_fps
	_on_max_fps_changed(current_max_fps)

func _on_setting_changed(_value = null) -> void:
	# Settings changed, could enable apply button here
	pass

func _on_shadow_quality_changed(value: float) -> void:
	var quality_names := ["Low (1024)", "Medium (2048)", "High (4096)"]
	shadow_quality_label.text = "Shadow Quality: " + quality_names[int(value)]

func _on_lod_bias_changed(value: float) -> void:
	lod_bias_label.text = "LOD Bias: %.2f" % value

func _on_max_fps_changed(value: float) -> void:
	if value == 0:
		max_fps_label.text = "Max FPS: Unlimited"
	else:
		max_fps_label.text = "Max FPS: %d" % int(value)

func _apply_settings() -> void:
	# Apply VSync
	var vsync_mode := vsync_option.selected as DisplayServer.VSyncMode
	DisplayServer.window_set_vsync_mode(vsync_mode)
	
	# Apply shadow quality
	var shadow_sizes := [1024, 2048, 4096]
	if shadow_quality_slider:
		var shadow_index := clampi(int(shadow_quality_slider.value), 0, shadow_sizes.size() - 1)
		var shadow_size: int = shadow_sizes[shadow_index]
		RenderingServer.directional_shadow_atlas_set_size(shadow_size, true)
	
	# Apply MSAA
	var viewport := get_viewport()
	if viewport:
		var msaa_mode := msaa_option.selected as Viewport.MSAA
		viewport.msaa_3d = msaa_mode
	
	# Apply FXAA
	if viewport:
		viewport.use_fxaa = fxaa_checkbox.button_pressed
	
	# Apply LOD bias (simplified - store for future use)
	var lod_bias := lod_bias_slider.value
	# Note: LOD bias implementation would require custom LOD system
	
	# Apply max FPS
	Engine.max_fps = int(max_fps_slider.value)
	
	# Save settings to project settings
	_save_settings()
	
	print("Performance settings applied")

func _save_settings() -> void:
	# Save settings to user://settings.cfg
	var config := ConfigFile.new()
	
	config.set_value("performance", "vsync", vsync_option.selected)
	config.set_value("performance", "shadow_quality", int(shadow_quality_slider.value))
	config.set_value("performance", "msaa", msaa_option.selected)
	config.set_value("performance", "fxaa", fxaa_checkbox.button_pressed)
	config.set_value("performance", "lod_bias", lod_bias_slider.value)
	config.set_value("performance", "max_fps", int(max_fps_slider.value))
	
	config.save("user://performance_settings.cfg")

func _load_saved_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load("user://performance_settings.cfg")
	
	if err != OK:
		return  # No saved settings
	
	vsync_option.selected = config.get_value("performance", "vsync", 1)
	shadow_quality_slider.value = config.get_value("performance", "shadow_quality", 1)
	msaa_option.selected = config.get_value("performance", "msaa", 1)
	fxaa_checkbox.button_pressed = config.get_value("performance", "fxaa", false)
	lod_bias_slider.value = config.get_value("performance", "lod_bias", 1.0)
	max_fps_slider.value = config.get_value("performance", "max_fps", 60)
	
	_on_shadow_quality_changed(shadow_quality_slider.value)
	_on_lod_bias_changed(lod_bias_slider.value)
	_on_max_fps_changed(max_fps_slider.value)

func _reset_to_defaults() -> void:
	apply_preset("medium")

func apply_preset(preset_name: String) -> void:
	if not performance_presets.has(preset_name):
		return
	
	var preset = performance_presets[preset_name]
	
	vsync_option.selected = preset.vsync
	shadow_quality_slider.value = preset.shadow_quality
	msaa_option.selected = preset.msaa
	fxaa_checkbox.button_pressed = preset.fxaa
	lod_bias_slider.value = preset.lod_bias
	max_fps_slider.value = preset.max_fps
	
	_on_shadow_quality_changed(preset.shadow_quality)
	_on_lod_bias_changed(preset.lod_bias)
	_on_max_fps_changed(preset.max_fps)
	
	_apply_settings()

func show_settings() -> void:
	visible = true
	_load_current_settings()

func hide_settings() -> void:
	visible = false

func auto_detect_settings() -> void:
	# Simple auto-detection based on performance
	var current_fps := Engine.get_frames_per_second()
	var memory_usage := (Performance.get_monitor(Performance.MEMORY_STATIC) + 
						 Performance.get_monitor(Performance.MEMORY_MESSAGE_BUFFER_MAX)) / 1048576.0
	
	if current_fps < 30 or memory_usage > 512:
		apply_preset("low")
		print("Auto-detected: Low performance preset applied")
	elif current_fps >= 50 and memory_usage < 256:
		apply_preset("high")
		print("Auto-detected: High performance preset applied")
	else:
		apply_preset("medium")
		print("Auto-detected: Medium performance preset applied")