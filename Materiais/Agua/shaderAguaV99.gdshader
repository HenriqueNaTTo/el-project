shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

uniform vec4 shallow_color : source_color = vec4(0.25, 0.65, 0.9, 1.0);
uniform vec4 deep_color : source_color = vec4(0.0, 0.1, 0.25, 1.0);
uniform float depth_fade_distance = 3.0;
uniform float transparency = 0.8;

uniform sampler2D normal_map_1 : hint_normal;
uniform vec2 wave1_direction = vec2(1.0, 0.0);
uniform float wave1_speed = 0.02;
uniform float wave1_scale = 1.0;

uniform sampler2D normal_map_2 : hint_normal;
uniform vec2 wave2_direction = vec2(0.0, 1.0);
uniform float wave2_speed = 0.03;
uniform float wave2_scale = 1.5;

uniform sampler2D noise_texture : hint_default_black;
uniform float noise_scale = 10.0;
uniform float wave_height = 0.1;

uniform sampler2D foam_texture;
uniform vec2 foam_direction = vec2(1.0, 0.5);
uniform float foam_speed = 0.04;
uniform float foam_scale = 2.0;
uniform float foam_sharpness = 0.5;
uniform float foam_amount = 0.3;

uniform float refraction_strength = 0.03;
uniform float roughness : hint_range(0.0, 1.0) = 0.05;
uniform sampler2D reflection_texture : hint_default_white;
uniform float reflection_strength : hint_range(0.0, 2.0) = 1.0; // Novo uniforme para controlar a força do reflexo

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

void vertex() {
    vec2 dir1_norm = normalize(wave1_direction);
    vec2 dir2_norm = normalize(wave2_direction);

    vec2 uv_offset1 = dir1_norm * wave1_speed * TIME;
    vec2 uv_offset2 = dir2_norm * wave2_speed * TIME;

    float noise = texture(noise_texture, UV * noise_scale + uv_offset1).r;

    VERTEX.y += noise * wave_height;
}

void fragment() {
    vec2 dir1_norm = normalize(wave1_direction);
    vec2 dir2_norm = normalize(wave2_direction);
    vec2 foam_dir_norm = normalize(foam_direction);

    vec2 normal_offset1 = dir1_norm * wave1_speed * TIME;
    vec2 normal_offset2 = dir2_norm * wave2_speed * TIME;
    vec2 foam_offset = foam_dir_norm * foam_speed * TIME;

    vec3 normal1 = texture(normal_map_1, UV * wave1_scale + normal_offset1).rgb;
    vec3 normal2 = texture(normal_map_2, UV * wave2_scale + normal_offset2).rgb;

    vec3 blended_normal_map_value = mix(normal1, normal2, 0.5);
    vec3 blended_normal_ws = normalize(TANGENT * (blended_normal_map_value.x * 2.0 - 1.0) +
                                       BINORMAL * (blended_normal_map_value.y * 2.0 - 1.0) +
                                       NORMAL * (blended_normal_map_value.z * 2.0 - 1.0));
    NORMAL = blended_normal_ws;

    float scene_depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
    float surface_depth = FRAGCOORD.z;

    float linear_scene_depth = PROJECTION_MATRIX[3][2] / (scene_depth - PROJECTION_MATRIX[2][2]);
    float linear_surface_depth = PROJECTION_MATRIX[3][2] / (surface_depth - PROJECTION_MATRIX[2][2]);

    float water_depth = max(0.0, linear_scene_depth - linear_surface_depth);
    float depth_blend = clamp(water_depth / depth_fade_distance, 0.0, 1.0);

    vec4 water_color = mix(shallow_color, deep_color, depth_blend);

    float foam_cutoff = clamp(1.0 - depth_blend, 0.0, 1.0);
    float foam_noise = texture(foam_texture, UV * foam_scale + foam_offset).r;
    float foam = smoothstep(foam_sharpness - 0.1, foam_sharpness + 0.1, foam_cutoff) * foam_noise * foam_amount;

    vec2 refraction_offset = (blended_normal_map_value.xy - vec2(0.5)) * 2.0 * refraction_strength * (1.0 - depth_blend);
    vec2 refraction_uv = SCREEN_UV + refraction_offset;
    vec3 refracted_color = texture(SCREEN_TEXTURE, refraction_uv).rgb;

    vec3 view_vec = VIEW;
    vec3 reflect_vec = reflect(-view_vec, NORMAL);

    float phi = atan(reflect_vec.z, reflect_vec.x);
    float theta = acos(reflect_vec.y);
    vec2 reflection_uv = vec2(phi / (2.0 * PI) + 0.5, theta / PI);
    vec3 reflected_color = texture(reflection_texture, reflection_uv).rgb * reflection_strength; // Aplicando a força do reflexo

    float fresnel = pow(1.0 - dot(NORMAL, view_vec), 5.0); // Reduzido de 10.0 para 5.0 para aumentar o reflexo
    fresnel = clamp(fresnel, 0.1, 1.0); // Aumentado o mínimo de 0.05 para 0.1 para mais reflexo

    vec3 final_color = mix(refracted_color, water_color.rgb, water_color.a);
    final_color = mix(final_color, reflected_color, fresnel);
    final_color += foam;

    ALBEDO = final_color;
    METALLIC = 0.0;
    ROUGHNESS = roughness;
    ALPHA = transparency;
}