shader_type spatial;

render_mode blend_mix, depth_draw_never, cull_back;

uniform vec4 shallow_color : source_color = vec4(0.25, 0.65, 0.9, 1.0);
uniform vec4 deep_color : source_color = vec4(0.0, 0.1, 0.25, 1.0);
uniform float depth_fade_distance = 3.0;
uniform float transparency : hint_range(0.0, 1.0) = 0.8;

uniform sampler2D normal_map_1 : hint_normal;
uniform vec2 wave1_direction = vec2(1.0, 0.0);
uniform float wave1_speed = 0.02;
uniform float wave1_scale = 1.0;

uniform sampler2D normal_map_2 : hint_normal;
uniform vec2 wave2_direction = vec2(0.0, 1.0);
uniform float wave2_speed = 0.03;
uniform float wave2_scale = 1.5;

uniform sampler2D noise_texture : hint_default_black;
uniform float noise_scale = 1.0;
uniform float wave_height = 0.1;

uniform vec2 flow_direction = vec2(1.0, 0.0);
uniform float flow_speed_base : hint_range(0.0, 5.0) = 1.0;
uniform float flow_directional_influence : hint_range(0.0, 1.0) = 0.6;

uniform sampler2D foam_texture;
uniform vec2 foam_direction = vec2(1.0, 0.5);
uniform float foam_speed = 0.04;
uniform float foam_scale = 2.0;
uniform float foam_sharpness = 0.5;
uniform float foam_amount : hint_range(0.0, 2.0) = 1.0;
uniform float surface_foam_cutoff : hint_range(0.0, 1.0) = 0.85;

group_uniforms Waterfall_Settings;
uniform float slope_foam_threshold : hint_range(0.0, 1.0) = 0.25;
uniform float slope_foam_intensity : hint_range(0.0, 3.0) = 2.0;
uniform float slope_speed_multiplier : hint_range(1.0, 10.0) = 4.0;
uniform float slope_foam_scale_factor : hint_range(0.1, 1.0) = 0.4;
uniform sampler2D waterfall_mask : hint_default_black;
uniform float waterfall_mask_strength : hint_range(0.0, 1.0) = 0.0;
group_uniforms;

uniform float refraction_strength = 0.03;
uniform float roughness : hint_range(0.0, 1.0) = 0.05;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.5;

group_uniforms SSR_Settings;
uniform float ssr_wave_smoothness : hint_range(0.0, 1.0, 0.01) = 0.7;
uniform int ssr_max_steps = 64;
uniform int ssr_binary_steps = 4;
uniform float ssr_max_travel : hint_range(0.0, 200.0, 0.1) = 50.0;
uniform float ssr_max_diff : hint_range(0.1, 10.0, 0.1) = 1.5;
uniform float ssr_mix_strength : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float ssr_color_boost : hint_range(1.0, 2.0, 0.01) = 1.1;
uniform float ssr_screen_border_fadeout : hint_range(0.0, 1.0, 0.1) = 0.2;
uniform float ssr_dither_amount : hint_range(0.0, 0.2) = 0.05;
group_uniforms;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

const float EPSILON = 1e-5;

// --- VARYINGS ---
// Passamos do vertex() para o fragment() para evitar recalcular
// e para ter acesso à normal geométrica ANTES de qualquer perturbação
varying vec3 world_position;
varying vec3 geometry_normal_world; // normal da mesh, não do normal map

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

vec3 get_view_position_from_depth(vec2 uv, float d, mat4 inv_proj) {
    vec3 ndc = vec3(uv * 2.0 - 1.0, d);
    vec4 view = inv_proj * vec4(ndc, 1.0);
    return view.xyz / view.w;
}

vec2 get_uv_from_view_position(vec3 pos, mat4 proj) {
    vec4 clip = proj * vec4(pos.xyz, 1.0);
    vec2 ndc = clip.xy / clip.w;
    return ndc.xy * 0.5 + 0.5;
}

float get_screen_border_alpha(vec2 pos, float fadeout) {
    vec2 s = 4.0 * pos * (1.0 - pos);
    float m = s.x * s.y;
    return clamp(m / (fadeout + EPSILON), 0.0, 1.0);
}

float get_flow_speed_multiplier(vec2 wave_dir, vec2 flow_dir_normalized) {
    float alignment = dot(normalize(wave_dir), flow_dir_normalized);
    float factor = abs(alignment);
    return mix(1.0 - flow_directional_influence, 1.0 + flow_directional_influence, factor) * flow_speed_base;
}

float get_slope_factor(vec3 geom_normal) {
    // geom_normal.y == 1.0 → plano horizontal (rio normal)
    // geom_normal.y == 0.0 → parede vertical (cachoeira)
    float flatness = clamp(geom_normal.y, 0.0, 1.0);
    float raw_slope = 1.0 - flatness;
    return clamp((raw_slope - slope_foam_threshold) / (1.0 - slope_foam_threshold + EPSILON), 0.0, 1.0);
}

vec4 get_ssr_color(vec2 screen_uv, vec3 surface_pos, vec3 normal_view, mat4 proj, mat4 inv_proj) {
    vec3 view_dir = normalize(surface_pos);
    vec3 reflect_dir = normalize(reflect(view_dir, normal_view));

    if (reflect_dir.z > 0.0) return vec4(0.0);

    float dither = hash(screen_uv) * ssr_dither_amount;
    vec3 current_pos = surface_pos;
    float step_size = ssr_max_travel / float(ssr_max_steps);
    current_pos += reflect_dir * step_size * dither;

    vec3 resulting_color = vec3(0.0);
    float alpha = 0.0;
    bool hit = false;
    float dynamic_tolerance = max(ssr_max_diff, step_size * 0.5);

    for (int i = 0; i < ssr_max_steps; i++) {
        current_pos += reflect_dir * step_size;
        vec2 sample_uv = get_uv_from_view_position(current_pos, proj);
        if (sample_uv.x < 0.0 || sample_uv.x > 1.0 || sample_uv.y < 0.0 || sample_uv.y > 1.0) break;

        float depth_sample = texture(DEPTH_TEXTURE, sample_uv).r;
        vec3 depth_pos = get_view_position_from_depth(sample_uv, depth_sample, inv_proj);
        float depth_diff = current_pos.z - depth_pos.z;

        if (depth_diff > 0.0 && depth_diff < dynamic_tolerance) {
            hit = true;
            current_pos -= reflect_dir * step_size;
            step_size /= 2.0;
            break;
        }
    }

    if (hit) {
        for (int i = 0; i < ssr_binary_steps; i++) {
            current_pos += reflect_dir * step_size;
            vec2 sample_uv = get_uv_from_view_position(current_pos, proj);
            float depth_sample = texture(DEPTH_TEXTURE, sample_uv).r;
            vec3 depth_pos = get_view_position_from_depth(sample_uv, depth_sample, inv_proj);
            float depth_diff = current_pos.z - depth_pos.z;
            if (depth_diff > 0.0 && depth_diff < dynamic_tolerance) {
                current_pos -= reflect_dir * step_size;
            }
            step_size /= 2.0;
        }
        vec2 final_uv = get_uv_from_view_position(current_pos, proj);
        resulting_color = texture(SCREEN_TEXTURE, final_uv).rgb;
        alpha = get_screen_border_alpha(final_uv, ssr_screen_border_fadeout);
    }
    return vec4(resulting_color * ssr_color_boost, alpha);
}

void vertex() {
    // Salva posição e normal geométrica em world space ANTES de qualquer modificação
    // Isso garante que o fragment() receba a inclinação real da mesh
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    geometry_normal_world = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);

    vec2 flow_dir_norm = normalize(flow_direction);
    vec2 dir1_norm = normalize(wave1_direction);
    float vertex_flow_mult = get_flow_speed_multiplier(dir1_norm, flow_dir_norm);
    vec2 uv_offset1 = flow_dir_norm * wave1_speed * vertex_flow_mult * TIME;
    float noise_val = texture(noise_texture, UV * noise_scale + uv_offset1).r;
    VERTEX.y += noise_val * wave_height;
}

void fragment() {
    vec2 screen_uv = FRAGCOORD.xy / VIEWPORT_SIZE;
    vec2 flow_dir_norm = normalize(flow_direction);

    // --- NORMAIS (normal map, para iluminação e refração) ---
    vec2 dir1_norm = normalize(wave1_direction);
    vec2 dir2_norm = normalize(wave2_direction);

    float speed_mult_1 = get_flow_speed_multiplier(dir1_norm, flow_dir_norm);
    float speed_mult_2 = get_flow_speed_multiplier(dir2_norm, flow_dir_norm);

    vec3 n1 = texture(normal_map_1, UV * wave1_scale + dir1_norm * wave1_speed * speed_mult_1 * TIME).rgb;
    vec3 n2 = texture(normal_map_2, UV * wave2_scale + dir2_norm * wave2_speed * speed_mult_2 * TIME).rgb;

    vec3 blended_n = mix(n1, n2, 0.5);
    vec3 world_space_normal = normalize(
        TANGENT  * (blended_n.x * 2.0 - 1.0) +
        BINORMAL * (blended_n.y * 2.0 - 1.0) +
        NORMAL   * (blended_n.z * 2.0 - 1.0)
    );
    NORMAL = world_space_normal;

    // --- SLOPE FACTOR ---
    // Usa geometry_normal_world vindo do vertex() — imune à câmera e ao normal map
    float slope = get_slope_factor(geometry_normal_world);
    float mask_val = texture(waterfall_mask, UV).r * waterfall_mask_strength;
    float waterfall_factor = clamp(slope + mask_val, 0.0, 1.0);

    // --- PROFUNDIDADE ---
    float scene_depth = texture(DEPTH_TEXTURE, screen_uv).r;
    float linear_scene_depth   = PROJECTION_MATRIX[3][2] / (scene_depth   - PROJECTION_MATRIX[2][2]);
    float linear_surface_depth = PROJECTION_MATRIX[3][2] / (FRAGCOORD.z   - PROJECTION_MATRIX[2][2]);
    float water_depth = max(0.0, linear_scene_depth - linear_surface_depth);
    float depth_blend = clamp(water_depth / depth_fade_distance, 0.0, 1.0);

    vec4 water_color = mix(shallow_color, deep_color, depth_blend);

    // --- FOAM COM COORDENADAS WORLD SPACE ---
    // Usa world_position.xz em vez de UV para que a textura não mude com a câmera.
    // Em superfícies verticais (cachoeiras), usa .xy para que o foam "caia" corretamente.
    vec2 foam_dir_norm = normalize(foam_direction);
    float foam_flow_mult = get_flow_speed_multiplier(foam_dir_norm, flow_dir_norm);

    float effective_foam_speed = foam_speed * foam_flow_mult * mix(1.0, slope_speed_multiplier, waterfall_factor);
    float effective_foam_scale = foam_scale * mix(1.0, slope_foam_scale_factor, waterfall_factor);

    // Mistura coordenadas XZ (horizontal) com XY (vertical) baseado no slope
    // Assim em cachoeiras o foam se move para baixo ao longo da queda
    vec2 foam_coord_horizontal = world_position.xz;
    vec2 foam_coord_vertical   = world_position.xy;
    vec2 foam_coord = mix(foam_coord_horizontal, foam_coord_vertical, waterfall_factor);

    float foam_noise_val = texture(
        foam_texture,
        foam_coord * effective_foam_scale + foam_dir_norm * effective_foam_speed * TIME
    ).r;

    float shore_mask   = clamp(1.0 - (water_depth / 0.8), 0.0, 1.0);
    float shore_foam   = smoothstep(foam_sharpness, foam_sharpness + 0.1, foam_noise_val) * shore_mask;

    float surface_mask = smoothstep(surface_foam_cutoff, surface_foam_cutoff + 0.05, foam_noise_val);
    surface_mask      *= clamp(water_depth, 0.0, 1.0);

    float waterfall_cutoff = mix(surface_foam_cutoff, 0.05, waterfall_factor);
    float waterfall_foam   = smoothstep(waterfall_cutoff, waterfall_cutoff + 0.1, foam_noise_val);
    waterfall_foam        *= mix(1.0, slope_foam_intensity, waterfall_factor);

    float combined_foam_intensity = clamp(
        max(max(shore_foam, surface_mask), waterfall_foam) * foam_amount,
        0.0, 1.0
    );

    // --- REFRAÇÃO ---
    float effective_refraction = refraction_strength * (1.0 - waterfall_factor * 0.8);
    vec2 refraction_uv   = screen_uv - (blended_n.xy - 0.5) * effective_refraction * (1.0 - depth_blend);
    vec3 refracted_color = texture(SCREEN_TEXTURE, refraction_uv).rgb;

    // --- SSR ---
    float fresnel    = clamp(pow(1.0 - dot(world_space_normal, VIEW), 3.0), 0.0, 1.0);
    vec3 final_color = mix(refracted_color, water_color.rgb, water_color.a);

    float ssr_waterfall_block = 1.0 - waterfall_factor;
    if (fresnel > 0.05 && combined_foam_intensity < 0.9 && ssr_waterfall_block > 0.05) {
        vec3 surface_view_position = get_view_position_from_depth(screen_uv, FRAGCOORD.z, INV_PROJECTION_MATRIX);
        vec3 flat_world_normal     = vec3(0.0, 1.0, 0.0);
        vec3 ssr_stabilized_normal = normalize(mix(world_space_normal, flat_world_normal, ssr_wave_smoothness));
        vec3 normal_view_space     = (VIEW_MATRIX * vec4(ssr_stabilized_normal, 0.0)).xyz;

        vec4 ssr_result  = get_ssr_color(screen_uv, surface_view_position, normal_view_space, PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
        float foam_block = clamp(1.0 - (combined_foam_intensity * 3.0), 0.0, 1.0);

        final_color = mix(final_color, ssr_result.rgb,
            ssr_result.a * fresnel * ssr_mix_strength * foam_block * ssr_waterfall_block);
    }

    ALBEDO    = final_color + (vec3(1.0) * combined_foam_intensity);
    METALLIC  = 0.0;
    ROUGHNESS = mix(roughness, 1.0, waterfall_factor * 0.8);
    SPECULAR  = specular_amount * (1.0 - waterfall_factor * 0.7);
    ALPHA     = transparency;
}