shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float dirt_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float grain_scale : hint_range(0.1, 20.0) = 8.0;
uniform vec4 base_color : source_color = vec4(0.75, 0.75, 0.7, 1.0);
uniform vec4 dirt_color : source_color = vec4(0.25, 0.2, 0.15, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform float dirt_roughness_boost : hint_range(0.0, 0.5) = 0.2;

varying vec3 world_position;
varying vec3 world_normal;

// Noise functions
float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 pos) {
    vec2 i = floor(pos);
    vec2 f = fract(pos);
    
    float a = rand(i);
    float b = rand(i + vec2(1.0, 0.0));
    float c = rand(i + vec2(0.0, 1.0));
    float d = rand(i + vec2(1.0, 1.0));
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 pos) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(pos * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value;
}

void vertex() {
    world_position = VERTEX;
    world_normal = NORMAL;
}

void fragment() {
    // Use world position for consistent texturing across surfaces
    vec2 uv_main = world_position.xz * 0.1;
    vec2 uv_vertical = world_position.yz * 0.1;
    
    // Blend based on normal direction
    float vertical_blend = abs(world_normal.y);
    vec2 final_uv = mix(uv_vertical, uv_main, vertical_blend);
    
    // Create grain pattern
    float fine_grain = fbm(final_uv * grain_scale);
    float coarse_grain = fbm(final_uv * grain_scale * 0.3);
    float grain = fine_grain * 0.7 + coarse_grain * 0.3;
    
    // Create dirt streaks and stains
    float vertical_streaks = fbm(vec2(final_uv.x * 2.0, final_uv.y * 8.0));
    float stains = fbm(final_uv * 3.0);
    
    // Create water damage patterns (more at bottom)
    float water_damage = smoothstep(0.3, 0.9, world_position.y + 2.0) * 
                        fbm(final_uv * 4.0 + vec2(0.0, world_position.y * 0.5));
    
    // Combine all dirt patterns
    float dirt_mask = grain * 0.4 + vertical_streaks * 0.3 + stains * 0.2 + water_damage * 0.1;
    dirt_mask = smoothstep(0.2, 0.8, dirt_mask);
    
    // Apply dirt intensity
    dirt_mask *= dirt_intensity;
    
    // Mix colors
    vec3 final_color = mix(base_color.rgb, dirt_color.rgb, dirt_mask);
    
    // Adjust material properties based on dirt
    float final_roughness = roughness + (dirt_mask * dirt_roughness_boost);
    
    ALBEDO = final_color;
    ROUGHNESS = final_roughness;
    METALLIC = metallic;
}