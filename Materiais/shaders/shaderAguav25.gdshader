shader_type spatial;
// Adicionado para ativar a transparência (alpha blending)
render_mode blend_mix, depth_draw_opaque; 

uniform vec3 albedo : source_color;
uniform vec3 albedo2 : source_color;
uniform float metalic : hint_range(0.0, 1.0);
uniform float roughness : hint_range(0.0, 1.0);
uniform float alpha : hint_range(0.0, 1.0) = 1.0; // Valor padrão 1.0 (opaco)
uniform sampler2D texture_normal_1;
uniform sampler2D texture_normal_2;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture;
uniform sampler2D SCREEN_TEXTURE: hint_screen_texture;
uniform sampler2D wave;
uniform float noise_scale = 1.0;
uniform float height_scale = 1.0;
uniform vec2 wave_direction = vec2(1.0, 0.0);
uniform vec2 wave_direction2 = vec2(0.0, 1.0);
uniform float time_scale : hint_range(0.0, 0.2) = 0.005;
varying float height;
varying vec3 world_pos;
uniform vec4 color_deep : source_color;
uniform vec4 color_shallow : source_color;
uniform float beers_law : hint_range(0.0, 1.0);
uniform float depth_offset : hint_range(-1.0, 1.0);

// Foam uniforms
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float foam_distance : hint_range(0.0, 1.0) = 0.04;
uniform float foam_max_distance : hint_range(0.0, 1.0) = 0.4;
uniform float foam_min_distance : hint_range(0.0, 1.0) = 0.04;
uniform float foam_cutoff : hint_range(0.0, 1.0) = 0.166;
uniform sampler2D foam_texture;
uniform float foam_tiling : hint_range(0.1, 10.0) = 1.0;
uniform float foam_wave_cutoff : hint_range(0.0, 1.0) = 0.777;
uniform float foam_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float edge_transparency_strength : hint_range(0.0, 10.0) = 1.0; // Aumentei o range para mais controle

float fresnel(float amount, vec3 normal, vec3 view) {
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0)), amount);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	height = texture(wave, world_pos.xz / noise_scale + TIME * time_scale).r;
	VERTEX.y += height * height_scale;
}

void fragment() {
	vec2 time = (TIME * wave_direction) * time_scale;
	vec2 time2 = (TIME * wave_direction2) * time_scale;
	vec3 normal_blend = mix(texture(texture_normal_1, UV + time).rgb, texture(texture_normal_2, UV + time2).rgb, 0.5);
	float fresnel = fresnel(5.0, NORMAL, VIEW);
	vec3 surface_color = mix(albedo, albedo2, fresnel);
	
	// Depth calculations
	float depth_texture = texture(DEPTH_TEXTURE, SCREEN_UV).r * 2.0 - 1.0;
	float depth = PROJECTION_MATRIX[3][2] / (depth_texture + PROJECTION_MATRIX[2][2]);
	float depth_blend = exp((depth + VERTEX.z + depth_offset) * -beers_law);
	depth_blend = clamp(1.0 - depth_blend, 0.0, 1.0);
	float depth_blend_power = clamp(pow(depth_blend, 2.5), 0.0, 1.0);
	
	// Edge transparency calculation (Proximity Fade)
	float scene_depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	float water_depth = FRAGCOORD.z;
	float depth_difference = scene_depth - water_depth;
	float edge_fade = clamp(depth_difference / foam_max_distance, 0.0, 1.0);
	
	// Foam calculation based on intersection
	float foam_intersection = smoothstep(foam_max_distance, foam_min_distance, depth_difference);
	
	// Foam based on wave height
	float wave_foam = step(foam_wave_cutoff, height);
	
	// Sample foam texture
	vec2 foam_uv = UV * foam_tiling + time * 0.5;
	float foam_texture_sample = texture(foam_texture, foam_uv).r;
	
	// Combine foam sources
	float foam_factor = max(foam_intersection, wave_foam * 0.7) * foam_texture_sample * foam_intensity;
	foam_factor = clamp(foam_factor, 0.0, 1.0);
	
	// Screen and depth color
	vec3 screen_color = textureLod(SCREEN_TEXTURE, SCREEN_UV, depth_blend_power * 2.5).rgb;
	vec3 depth_color = mix(color_shallow.rgb, color_deep.rgb, depth_blend_power);
	vec3 color = mix(screen_color * depth_color, depth_color * 0.25, depth_blend_power * 0.5);
	
	// Mix water color with surface color
	vec3 base_color = mix(surface_color, color, 0.75);
	
	// Apply foam
	ALBEDO = mix(base_color, foam_color.rgb, foam_factor);
	METALLIC = metalic * (1.0 - foam_factor); // Foam reduces metallic
	ROUGHNESS = mix(roughness, 1.0, foam_factor); // Foam increases roughness
	
	// Aplicar a transparência na borda
	//ALPHA = alpha * edge_fade;
	// A espuma deve permanecer opaca sobre a água transparente
	ALPHA = mix(ALPHA, 1.0, foam_factor);
	
	NORMAL_MAP = normal_blend;
}