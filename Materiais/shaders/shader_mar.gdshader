shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;

// ============================================================
// CORES E PROFUNDIDADE
// ============================================================
uniform vec4 shallow_color : source_color = vec4(0.05, 0.45, 0.65, 1.0);
uniform vec4 deep_color    : source_color = vec4(0.0,  0.08, 0.2,  1.0);
uniform float depth_fade_distance = 8.0;
uniform float transparency : hint_range(0.0, 1.0) = 0.92;

// ============================================================
// NORMAL MAPS (detalhes de superfície)
// ============================================================
uniform sampler2D normal_map_1 : hint_normal;
uniform vec2  wave1_direction = vec2(1.0, 0.0);
uniform float wave1_speed     = 0.04;
uniform float wave1_scale     = 0.6;

uniform sampler2D normal_map_2 : hint_normal;
uniform vec2  wave2_direction = vec2(0.6, 0.8);
uniform float wave2_speed     = 0.03;
uniform float wave2_scale     = 1.2;

// ============================================================
// ONDAS GERSTNER — grupo A (ondas longas dominantes)
// ============================================================
group_uniforms GerstnerA;
uniform vec2  gA_dir        = vec2(1.0, 0.3);
uniform float gA_amplitude  : hint_range(0.0, 5.0)  = 1.2;
uniform float gA_wavelength : hint_range(1.0, 200.0) = 60.0;
uniform float gA_steepness  : hint_range(0.0, 1.0)  = 0.5;
group_uniforms;

// ============================================================
// ONDAS GERSTNER — grupo B (ondas médias cruzadas)
// ============================================================
group_uniforms GerstnerB;
uniform vec2  gB_dir        = vec2(-0.6, 1.0);
uniform float gB_amplitude  : hint_range(0.0, 5.0)  = 0.6;
uniform float gB_wavelength : hint_range(1.0, 200.0) = 30.0;
uniform float gB_steepness  : hint_range(0.0, 1.0)  = 0.45;
group_uniforms;

// ============================================================
// ONDAS GERSTNER — grupo C (chop pequeno)
// ============================================================
group_uniforms GerstnerC;
uniform vec2  gC_dir        = vec2(0.3, -1.0);
uniform float gC_amplitude  : hint_range(0.0, 5.0)  = 0.25;
uniform float gC_wavelength : hint_range(1.0, 200.0) = 12.0;
uniform float gC_steepness  : hint_range(0.0, 1.0)  = 0.3;
group_uniforms;

// ============================================================
// ESPUMA
// ============================================================
uniform sampler2D foam_texture;

// Camada A — espuma de arrasto (move com o vento)
uniform vec2  foam_dir_a   = vec2(1.0, 0.4);
uniform float foam_speed_a = 0.06;
uniform float foam_scale_a = 2.0;

// Camada B — espuma cruzada (cria padrão de rede)
uniform vec2  foam_dir_b   = vec2(-0.5, 1.0);
uniform float foam_speed_b = 0.04;
uniform float foam_scale_b = 3.5;

// Controles gerais
uniform float foam_amount    : hint_range(0.0, 2.0)  = 1.2;
uniform float foam_contrast  : hint_range(1.0, 8.0)  = 3.5;
uniform float shore_foam_width = 1.2;
uniform float shore_foam_soft  : hint_range(0.01, 1.0) = 0.3;

// Cristas
uniform float crest_foam_threshold : hint_range(0.0, 1.0)  = 0.6;
uniform float crest_foam_sharpness : hint_range(1.0, 20.0) = 4.0;
uniform float crest_turbulence     : hint_range(0.0, 1.0)  = 0.6;

// ============================================================
// ILUMINAÇÃO / SSR
// ============================================================
uniform float refraction_strength = 0.04;
uniform float roughness       : hint_range(0.0, 1.0) = 0.04;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.7;

group_uniforms SSR_Settings;
uniform float ssr_wave_smoothness       : hint_range(0.0, 1.0, 0.01) = 0.75;
uniform int   ssr_max_steps             = 64;
uniform int   ssr_binary_steps          = 5;
uniform float ssr_max_travel            : hint_range(0.0, 200.0, 0.1) = 60.0;
uniform float ssr_max_diff              : hint_range(0.1, 10.0, 0.1)  = 1.8;
uniform float ssr_mix_strength          : hint_range(0.0, 2.0, 0.01)  = 1.0;
uniform float ssr_color_boost           : hint_range(1.0, 2.0, 0.01)  = 1.1;
uniform float ssr_screen_border_fadeout : hint_range(0.0, 1.0, 0.1)   = 0.2;
uniform float ssr_dither_amount         : hint_range(0.0, 0.2)         = 0.05;
group_uniforms;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D DEPTH_TEXTURE  : hint_depth_texture,  filter_linear_mipmap;

// ============================================================
// VARYINGS
// ============================================================
varying float v_crest;
varying vec3  v_gerstner_normal;

const float EPSILON = 1e-5;

// ============================================================
// FUNÇÕES AUXILIARES
// ============================================================
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 get_view_position_from_depth(vec2 uv, float d, mat4 inv_proj) {
    vec3 ndc  = vec3(uv * 2.0 - 1.0, d);
    vec4 view = inv_proj * vec4(ndc, 1.0);
    return view.xyz / view.w;
}

vec2 get_uv_from_view_position(vec3 pos, mat4 proj) {
    vec4 clip = proj * vec4(pos.xyz, 1.0);
    vec2 ndc  = clip.xy / clip.w;
    return ndc.xy * 0.5 + 0.5;
}

float get_screen_border_alpha(vec2 pos, float fadeout) {
    vec2  s = 4.0 * pos * (1.0 - pos);
    float m = s.x * s.y;
    return clamp(m / (fadeout + EPSILON), 0.0, 1.0);
}

// fBm de 3 oitavas usando a foam_texture como base
float foam_fbm(sampler2D tex, vec2 uv, float time, vec2 dir, float speed) {
    float v     = 0.0;
    float a     = 0.5;
    vec2  shift = dir * speed * time;
    for (int i = 0; i < 3; i++) {
        v     += a * texture(tex, uv + shift).r;
        uv    *= 2.1;
        shift *= 1.7;
        a     *= 0.45;
    }
    return v;
}

vec4 gerstner_wave(vec3 world_pos, vec2 dir, float amplitude, float wavelength,
                   float steepness, float time, out vec3 out_normal) {
    dir = normalize(dir);
    float k  = 2.0 * PI / wavelength;
    float c  = sqrt(9.8 / k);
    float f  = k * (dot(dir, world_pos.xz) - c * time);
    float Q  = steepness / (k * amplitude + EPSILON);

    float sinF = sin(f);
    float cosF = cos(f);
    float dx = Q * amplitude * dir.x * cosF;
    float dy =     amplitude * sinF;
    float dz = Q * amplitude * dir.y * cosF;

    out_normal = vec3(
        -dir.x * k * amplitude * cosF,
         Q * k * amplitude * sinF,
        -dir.y * k * amplitude * cosF
    );

    float crest = clamp((sinF + 1.0) * 0.5, 0.0, 1.0);
    return vec4(dx, dy, dz, crest);
}

vec4 get_ssr_color(vec2 screen_uv, vec3 surface_pos, vec3 normal_view,
                   mat4 proj, mat4 inv_proj) {
    vec3 view_dir    = normalize(surface_pos);
    vec3 reflect_dir = normalize(reflect(view_dir, normal_view));

    if (reflect_dir.z > 0.0) return vec4(0.0);

    float dither      = hash(screen_uv) * ssr_dither_amount;
    vec3  current_pos = surface_pos;
    float step_size   = ssr_max_travel / float(ssr_max_steps);
    current_pos += reflect_dir * step_size * dither;

    vec3  resulting_color   = vec3(0.0);
    float alpha             = 0.0;
    bool  hit               = false;
    float dynamic_tolerance = max(ssr_max_diff, step_size * 0.5);

    for (int i = 0; i < ssr_max_steps; i++) {
        current_pos += reflect_dir * step_size;
        vec2 sample_uv = get_uv_from_view_position(current_pos, proj);
        if (sample_uv.x < 0.0 || sample_uv.x > 1.0 ||
            sample_uv.y < 0.0 || sample_uv.y > 1.0) break;

        float depth_sample = texture(DEPTH_TEXTURE, sample_uv).r;
        vec3  depth_pos    = get_view_position_from_depth(sample_uv, depth_sample, inv_proj);
        float depth_diff   = current_pos.z - depth_pos.z;

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
            vec2  sample_uv    = get_uv_from_view_position(current_pos, proj);
            float depth_sample = texture(DEPTH_TEXTURE, sample_uv).r;
            vec3  depth_pos    = get_view_position_from_depth(sample_uv, depth_sample, inv_proj);
            float depth_diff   = current_pos.z - depth_pos.z;
            if (depth_diff > 0.0 && depth_diff < dynamic_tolerance)
                current_pos -= reflect_dir * step_size;
            step_size /= 2.0;
        }
        vec2 final_uv   = get_uv_from_view_position(current_pos, proj);
        resulting_color = texture(SCREEN_TEXTURE, final_uv).rgb;
        alpha           = get_screen_border_alpha(final_uv, ssr_screen_border_fadeout);
    }
    return vec4(resulting_color * ssr_color_boost, alpha);
}

// ============================================================
// VERTEX
// ============================================================
void vertex() {
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    vec3 nA, nB, nC;
    vec4 wA = gerstner_wave(world_pos, gA_dir, gA_amplitude, gA_wavelength, gA_steepness, TIME, nA);
    vec4 wB = gerstner_wave(world_pos, gB_dir, gB_amplitude, gB_wavelength, gB_steepness, TIME, nB);
    vec4 wC = gerstner_wave(world_pos, gC_dir, gC_amplitude, gC_wavelength, gC_steepness, TIME, nC);

    vec3 total_disp = vec3(wA.x + wB.x + wC.x,
                           wA.y + wB.y + wC.y,
                           wA.z + wB.z + wC.z);
    VERTEX += (inverse(MODEL_MATRIX) * vec4(total_disp, 0.0)).xyz;

    // Pondera cada crest pela amplitude relativa — ondas grandes dominam
    float total_amp  = gA_amplitude + gB_amplitude + gC_amplitude + EPSILON;
    float combined_crest = (wA.w * gA_amplitude +
                            wB.w * gB_amplitude * 0.4 +
                            wC.w * gC_amplitude * 0.1) / total_amp;
    v_crest = combined_crest;

    vec3 gerstner_n = normalize(vec3(0.0, 1.0, 0.0) + nA + nB + nC);
    v_gerstner_normal = gerstner_n;
}

// ============================================================
// FRAGMENT
// ============================================================
void fragment() {
    vec2 screen_uv = FRAGCOORD.xy / VIEWPORT_SIZE;

    // --- Normal maps de detalhe ---
    vec2 d1 = normalize(wave1_direction);
    vec2 d2 = normalize(wave2_direction);
    vec3 n1 = texture(normal_map_1, UV * wave1_scale + d1 * wave1_speed * TIME).rgb;
    vec3 n2 = texture(normal_map_2, UV * wave2_scale + d2 * wave2_speed * TIME).rgb;
    vec3 detail_n = mix(n1, n2, 0.5);

    vec3 detail_world = normalize(
        TANGENT   * (detail_n.x * 2.0 - 1.0) +
        BINORMAL  * (detail_n.y * 2.0 - 1.0) +
        NORMAL    * (detail_n.z * 2.0 - 1.0)
    );

    vec3 world_space_normal = normalize(mix(detail_world, v_gerstner_normal, 0.5));
    NORMAL = world_space_normal;

    // --- Profundidade e cor base ---
    float scene_depth          = texture(DEPTH_TEXTURE, screen_uv).r;
    float linear_scene_depth   = PROJECTION_MATRIX[3][2] / (scene_depth - PROJECTION_MATRIX[2][2]);
    float linear_surface_depth = PROJECTION_MATRIX[3][2] / (FRAGCOORD.z  - PROJECTION_MATRIX[2][2]);
    float water_depth          = max(0.0, linear_scene_depth - linear_surface_depth);
    float depth_blend          = clamp(water_depth / depth_fade_distance, 0.0, 1.0);
    vec4  water_color          = mix(shallow_color, deep_color, depth_blend);

    // --- Espuma ---
    vec2 da = normalize(foam_dir_a);
    vec2 db = normalize(foam_dir_b);

    float fbm_a = foam_fbm(foam_texture, UV * foam_scale_a, TIME, da, foam_speed_a);
    float fbm_b = foam_fbm(foam_texture, UV * foam_scale_b, TIME, db, foam_speed_b);

    // Intersecção das duas camadas
    float foam_base = clamp(fbm_a * 0.6 + fbm_b * 0.6 - 0.15, 0.0, 1.0);
    foam_base = pow(foam_base, 1.0 / foam_contrast);

    // 1. Espuma de costa
    float shore_t    = clamp(1.0 - (water_depth / shore_foam_width), 0.0, 1.0);
    float shore_soft = smoothstep(0.0, shore_foam_soft, shore_t)
                     * smoothstep(1.0, 1.0 - shore_foam_soft * 0.5, shore_t);
    float shore_foam = foam_base * shore_soft;

    // 2. Espuma de crista — smoothstep concentra só no ápice real
    float crest_t    = smoothstep(crest_foam_threshold, 1.0, v_crest);
    crest_t          = pow(crest_t, crest_foam_sharpness);
    float turb       = mix(1.0, fbm_a, crest_turbulence);
    float crest_foam = crest_t * turb;

    // 3. Espuma de vale — sutil, mantém o mar "sujo"
    float trough_t    = clamp(1.0 - v_crest * 2.0, 0.0, 1.0) * 0.25;
    float trough_foam = trough_t * fbm_b;

    float combined_foam = clamp(
        max(shore_foam, max(crest_foam, trough_foam)) * foam_amount,
        0.0, 1.0
    );

    // --- Refração ---
    vec2 refraction_uv   = screen_uv - (detail_n.xy - 0.5) * refraction_strength * (1.0 - depth_blend);
    vec3 refracted_color = texture(SCREEN_TEXTURE, refraction_uv).rgb;

    // --- Fresnel ---
    float fresnel = pow(1.0 - clamp(dot(world_space_normal, VIEW), 0.0, 1.0), 3.0);

    // --- Cor final base ---
    vec3 final_color = mix(refracted_color, water_color.rgb, water_color.a);

    // --- SSR ---
    if (fresnel > 0.05 && combined_foam < 0.9) {
        vec3 surface_view_pos = get_view_position_from_depth(screen_uv, FRAGCOORD.z, INV_PROJECTION_MATRIX);

        vec3 flat_normal       = vec3(0.0, 1.0, 0.0);
        vec3 ssr_normal        = normalize(mix(world_space_normal, flat_normal, ssr_wave_smoothness));
        vec3 normal_view_space = (VIEW_MATRIX * vec4(ssr_normal, 0.0)).xyz;

        vec4 ssr_result = get_ssr_color(screen_uv, surface_view_pos,
                                        normal_view_space,
                                        PROJECTION_MATRIX, INV_PROJECTION_MATRIX);

        float foam_block = clamp(1.0 - combined_foam * 3.0, 0.0, 1.0);
        final_color = mix(final_color, ssr_result.rgb,
                          ssr_result.a * fresnel * ssr_mix_strength * foam_block);
    }

    // --- Saída ---
    ALBEDO    = final_color + vec3(1.0) * combined_foam;
    METALLIC  = 0.0;
    ROUGHNESS = roughness;
    SPECULAR  = specular_amount;
    ALPHA     = transparency;
}