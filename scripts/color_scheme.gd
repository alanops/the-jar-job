extends Node
class_name ColorScheme

# Centralized color scheme for the game
# Based on a cohesive architectural/interior design palette

# Environment colors
static var wall_color    = Color("#F5F5F5")  # Off-white/Light gray walls
static var floor_color   = Color("#D6CFC7")  # Warm beige flooring
static var desk_color    = Color("#A89F91")  # Muted brown furniture
static var jar_color     = Color("#D2691E")  # Chocolate orange accent

# Character colors  
static var player_color  = Color("#007ACC")  # Professional blue
static var npc_color     = Color("#C0392B")  # Alert red for guards

# UI colors
static var ui_alert      = Color("#FFB400")  # Warning amber

# Apply colors to various game elements
static func apply_color_scheme():
	print("ColorScheme: Applying game color palette...")

static func get_wall_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = wall_color
	material.metallic = 0.1
	material.roughness = 0.8
	return material

static func get_floor_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new() 
	material.albedo_color = floor_color
	material.metallic = 0.0
	material.roughness = 0.9
	return material

static func get_desk_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = desk_color
	material.metallic = 0.2
	material.roughness = 0.7
	return material

static func get_jar_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = jar_color
	material.metallic = 0.1
	material.roughness = 0.6
	material.emission_enabled = true
	material.emission = jar_color * 0.2  # Slight glow
	return material

static func get_player_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = player_color
	material.metallic = 0.0
	material.roughness = 0.8
	return material

static func get_npc_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = npc_color
	material.metallic = 0.0
	material.roughness = 0.8
	return material