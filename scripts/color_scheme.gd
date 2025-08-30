extends Node
class_name ColorScheme

# Centralized color scheme for the game
# Based on The Jar Job color palette: Concept art (stealth atmosphere) + Splash art (tension/drama)

# Environment colors
static var wall_color    = Color("#13171C")  # Charcoal gray walls
static var floor_color   = Color("#13161B")  # Charcoal blue tint flooring
static var desk_color    = Color("#615258")  # Dusky mauve-gray furniture
static var jar_color     = Color("#DC863F")  # Warm orange accent

# Character colors  
static var player_color  = Color("#394554")  # Muted blue-gray
static var npc_color     = Color("#87521A")  # Dark amber-brown for guards

# UI colors
static var ui_alert      = Color("#744812")  # Rich brown alert

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