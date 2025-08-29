extends Node

enum LogLevel {
	DEBUG,
	INFO,
	WARNING,
	ERROR
}

@export var log_level: LogLevel = LogLevel.INFO
@export var log_to_file: bool = true
@export var show_timestamps: bool = true
@export var show_source: bool = true

var log_file: FileAccess
var log_file_path: String = "user://game_debug.log"

func _ready() -> void:
	name = "DebugLogger"
	
	if log_to_file:
		log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
		if log_file:
			log_file.store_line("=== Game Debug Log Started ===")
			log_file.flush()

func _exit_tree() -> void:
	if log_file:
		log_file.store_line("=== Game Debug Log Ended ===")
		log_file.close()

func debug(message: String, source: String = "") -> void:
	_log(LogLevel.DEBUG, message, source)

func info(message: String, source: String = "") -> void:
	_log(LogLevel.INFO, message, source)

func warning(message: String, source: String = "") -> void:
	_log(LogLevel.WARNING, message, source)

func error(message: String, source: String = "") -> void:
	_log(LogLevel.ERROR, message, source)

func _log(level: LogLevel, message: String, source: String = "") -> void:
	if level < log_level:
		return
	
	var log_message := _format_message(level, message, source)
	
	# Print to console if in debug mode or level is warning/error
	if OS.is_debug_build() or level >= LogLevel.WARNING:
		print(log_message)
	
	# Write to file if enabled
	if log_to_file and log_file:
		log_file.store_line(log_message)
		log_file.flush()

func _format_message(level: LogLevel, message: String, source: String = "") -> String:
	var result := ""
	
	if show_timestamps:
		var time := Time.get_datetime_string_from_system()
		result += "[%s] " % time
	
	result += "[%s] " % _get_level_string(level)
	
	if show_source and source != "":
		result += "[%s] " % source
	
	result += message
	return result

func _get_level_string(level: LogLevel) -> String:
	match level:
		LogLevel.DEBUG: return "DEBUG"
		LogLevel.INFO: return "INFO"
		LogLevel.WARNING: return "WARN"
		LogLevel.ERROR: return "ERROR"
		_: return "UNKNOWN"

func set_log_level_from_string(level_string: String) -> void:
	match level_string.to_upper():
		"DEBUG": log_level = LogLevel.DEBUG
		"INFO": log_level = LogLevel.INFO
		"WARNING", "WARN": log_level = LogLevel.WARNING
		"ERROR": log_level = LogLevel.ERROR

func clear_log_file() -> void:
	if log_file:
		log_file.close()
	
	log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if log_file:
		log_file.store_line("=== Game Debug Log Cleared ===")
		log_file.flush()