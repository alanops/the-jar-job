extends StaticBody3D

class_name FadeableWall

@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")

var original_material: Material
var fade_material: ShaderMaterial
var is_faded: bool = false
var fade_tween: Tween

func _ready() -> void:
	if mesh_instance and mesh_instance.get_surface_override_material_count() > 0:
		original_material = mesh_instance.get_surface_override_material(0)
	elif mesh_instance and mesh_instance.mesh:
		original_material = mesh_instance.mesh.surface_get_material(0)
	
	# Create fade shader material
	_create_fade_material()

func _create_fade_material() -> void:
	fade_material = ShaderMaterial.new()
	
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	ALPHA = alpha;
}
"""
	
	fade_material.shader = shader
	
	# Copy properties from original material if it exists
	if original_material is StandardMaterial3D:
		var std_mat := original_material as StandardMaterial3D
		fade_material.set_shader_parameter("albedo", std_mat.albedo_color)
		if std_mat.albedo_texture:
			fade_material.set_shader_parameter("texture_albedo", std_mat.albedo_texture)

func set_fade(fade: bool, target_alpha: float = 0.3) -> void:
	if is_faded == fade:
		return
	
	is_faded = fade
	
	# Kill existing tween
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	if not mesh_instance:
		return
	
	# Apply fade material
	if fade:
		mesh_instance.set_surface_override_material(0, fade_material)
		fade_material.set_shader_parameter("alpha", 1.0)
		
		# Tween to target alpha
		fade_tween = create_tween()
		fade_tween.tween_method(_set_alpha, 1.0, target_alpha, 0.3)
	else:
		# Tween back to full alpha then restore original material
		fade_tween = create_tween()
		fade_tween.tween_method(_set_alpha, fade_material.get_shader_parameter("alpha"), 1.0, 0.3)
		fade_tween.tween_callback(_restore_original_material)

func _set_alpha(value: float) -> void:
	if fade_material:
		fade_material.set_shader_parameter("alpha", value)

func _restore_original_material() -> void:
	if mesh_instance and original_material:
		mesh_instance.set_surface_override_material(0, original_material)
