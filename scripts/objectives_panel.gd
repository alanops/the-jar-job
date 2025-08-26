extends Control

@onready var objectives_list: VBoxContainer = $Content/ObjectivesList
@onready var template: Control = $ObjectiveTemplate

var objective_manager: Node
var objective_entries: Dictionary = {}

func _ready() -> void:
	# Get objective manager
	objective_manager = get_node("/root/ObjectiveManager")
	if objective_manager:
		objective_manager.objective_updated.connect(_on_objective_updated)
		objective_manager.objective_completed.connect(_on_objective_completed)
	
	# Initial refresh
	call_deferred("refresh_objectives")

func create_objective_entry(objective) -> Control:
	var entry = template.duplicate()
	entry.visible = true
	entry.name = "Objective_" + objective.id
	
	var icon_label = entry.get_node("Icon")
	var title_label = entry.get_node("Details/Title")
	var desc_label = entry.get_node("Details/Description")
	var status_label = entry.get_node("Status")
	
	icon_label.text = objective.icon
	title_label.text = objective.title
	desc_label.text = objective.description
	
	if objective.is_completed:
		status_label.text = "✅"
		status_label.add_theme_color_override("font_color", Color.GREEN)
		title_label.add_theme_color_override("font_color", Color.GRAY)
		desc_label.add_theme_color_override("font_color", Color.GRAY)
		# Add strikethrough effect for completed
		title_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		desc_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	elif objective.is_active:
		status_label.text = "🎯"
		status_label.add_theme_color_override("font_color", Color.YELLOW)
		title_label.add_theme_color_override("font_color", Color.YELLOW)
		desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	else:
		status_label.text = "⏳"
		status_label.add_theme_color_override("font_color", Color.GRAY)
		title_label.add_theme_color_override("font_color", Color.GRAY)
		desc_label.add_theme_color_override("font_color", Color.GRAY)
	
	objectives_list.add_child(entry)
	return entry

func refresh_objectives() -> void:
	if not objective_manager:
		return
	
	# Clear existing entries
	for child in objectives_list.get_children():
		child.queue_free()
	objective_entries.clear()
	
	# Add all objectives
	var all_objectives = objective_manager.get_all_objectives()
	for objective in all_objectives:
		var entry = create_objective_entry(objective)
		objective_entries[objective.id] = entry

func update_objective_entry(objective) -> void:
	if objective.id in objective_entries:
		var entry = objective_entries[objective.id]
		
		var status_label = entry.get_node("Status")
		var title_label = entry.get_node("Details/Title")
		var desc_label = entry.get_node("Details/Description")
		
		if objective.is_completed:
			status_label.text = "✅"
			status_label.add_theme_color_override("font_color", Color.GREEN)
			title_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
			desc_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		elif objective.is_active:
			status_label.text = "🎯"
			status_label.add_theme_color_override("font_color", Color.YELLOW)
			title_label.add_theme_color_override("font_color", Color.YELLOW)
			desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		else:
			status_label.text = "⏳"
			status_label.add_theme_color_override("font_color", Color.GRAY)
			title_label.add_theme_color_override("font_color", Color.GRAY)
			desc_label.add_theme_color_override("font_color", Color.GRAY)

func _on_objective_updated(objective) -> void:
	update_objective_entry(objective)

func _on_objective_completed(objective) -> void:
	update_objective_entry(objective)