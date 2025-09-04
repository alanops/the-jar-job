shader_type canvas_item;

uniform float dirt_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float grain_scale : hint_range(0.1, 10.0) = 2.0;
uniform vec4 base_color : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform vec4 dirt_color : source_color = vec4(0.3, 0.25, 0.2, 1.0);
uniform float noise_speed : hint_range(0.0, 2.0) = 0.5;

// Simple noise function
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
    
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(pos * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value;
}

void fragment() {
    vec2 uv = UV;
    
    // Create grain pattern
    float grain = fbm(uv * grain_scale + TIME * noise_speed);
    
    // Create dirt streaks
    float streaks = fbm(vec2(uv.x * 0.5, uv.y * 4.0));
    
    // Combine noise patterns
    float dirt_mask = grain * 0.7 + streaks * 0.3;
    dirt_mask = smoothstep(0.3, 0.8, dirt_mask);
    
    // Mix base color with dirt
    vec3 final_color = mix(base_color.rgb, dirt_color.rgb, dirt_mask * dirt_intensity);
    
    COLOR = vec4(final_color, base_color.a);
}