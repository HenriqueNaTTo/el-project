shader_type spatial;

render_mode blend_mix, depth_draw_never, cull_back;



// --- UNIFORMES DE CORES E ONDAS ---

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



// --- UNIFORMES DE ESPUMA ---

uniform sampler2D foam_texture;

uniform vec2 foam_direction = vec2(1.0, 0.5);

uniform float foam_speed = 0.04;

uniform float foam_scale = 2.0;

uniform float foam_sharpness = 0.5;

uniform float foam_amount : hint_range(0.0, 2.0) = 1.0; // Intensidade visual da espuma

// NOVO: Controla a quantidade de espuma no meio do mar (0.7 a 0.9 é bom)

// Valores mais altos = MENOS espuma na superfície.

uniform float surface_foam_cutoff : hint_range(0.0, 1.0) = 0.85; 



// --- UNIFORMES DE ILUMINAÇÃO E SSR ---

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

uniform float ssr_screen_border_fadeout: hint_range(0.0, 1.0, 0.1) = 0.2;

uniform float ssr_dither_amount : hint_range(0.0, 0.2) = 0.05; 

group_uniforms;



uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;



const float EPSILON = 1e-5;



// --- FUNÇÕES AUXILIARES ---

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



// BUSCA LINEAR

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



// BUSCA BINÁRIA

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

vec2 dir1_norm = normalize(wave1_direction);

vec2 uv_offset1 = dir1_norm * wave1_speed * TIME;

float noise = texture(noise_texture, UV * noise_scale + uv_offset1).r;

VERTEX.y += noise * wave_height;

}



void fragment() {

vec2 screen_uv = FRAGCOORD.xy / VIEWPORT_SIZE;



// --- NORMAIS ---

vec2 dir1_norm = normalize(wave1_direction);

vec2 dir2_norm = normalize(wave2_direction);

vec3 n1 = texture(normal_map_1, UV * wave1_scale + dir1_norm * wave1_speed * TIME).rgb;

vec3 n2 = texture(normal_map_2, UV * wave2_scale + dir2_norm * wave2_speed * TIME).rgb;

vec3 blended_n = mix(n1, n2, 0.5);

vec3 world_space_normal = normalize(TANGENT * (blended_n.x * 2.0-1.0) + BINORMAL * (blended_n.y * 2.0-1.0) + NORMAL * (blended_n.z * 2.0-1.0));

NORMAL = world_space_normal;



// --- PROFUNDIDADE E COR BASE ---

float scene_depth = texture(DEPTH_TEXTURE, screen_uv).r;

float linear_scene_depth = PROJECTION_MATRIX[3][2] / (scene_depth - PROJECTION_MATRIX[2][2]);

float linear_surface_depth = PROJECTION_MATRIX[3][2] / (FRAGCOORD.z - PROJECTION_MATRIX[2][2]);

float water_depth = max(0.0, linear_scene_depth - linear_surface_depth);

float depth_blend = clamp(water_depth / depth_fade_distance, 0.0, 1.0);


vec4 water_color = mix(shallow_color, deep_color, depth_blend);



// --- CÁLCULO DA ESPUMA (ATUALIZADO) ---

float foam_noise_val = texture(foam_texture, UV * foam_scale + normalize(foam_direction) * foam_speed * TIME).r;


// 1. Espuma da Costa (Baseada na profundidade)

float shore_mask = clamp(1.0 - (water_depth / 0.8), 0.0, 1.0); // 0.8 controla a largura da faixa na areia

float shore_foam = smoothstep(foam_sharpness, foam_sharpness + 0.1, foam_noise_val) * shore_mask;


// 2. Espuma de Superfície (No meio do mar, baseada no Cutoff)

// Se o ruído for maior que o cutoff, gera espuma

float surface_mask = smoothstep(surface_foam_cutoff, surface_foam_cutoff + 0.05, foam_noise_val);

// Corta a espuma da superfície onde a água é muito rasa para evitar sobreposição excessiva

surface_mask *= clamp(water_depth, 0.0, 1.0); 


// 3. Combinação das espumas

float combined_foam_intensity = max(shore_foam, surface_mask) * foam_amount;


// Garante que não ultrapasse 1.0

combined_foam_intensity = clamp(combined_foam_intensity, 0.0, 1.0);



// --- REFRAÇÃO ---

vec2 refraction_uv = screen_uv - (blended_n.xy - 0.5) * refraction_strength * (1.0 - depth_blend);

vec3 refracted_color = texture(SCREEN_TEXTURE, refraction_uv).rgb;


// --- SSR ---

float fresnel = pow(1.0 - dot(world_space_normal, VIEW), 3.0);

fresnel = clamp(fresnel, 0.0, 1.0);


vec3 final_color = mix(refracted_color, water_color.rgb, water_color.a);



// Calcula SSR (agora bloqueado pelo combined_foam_intensity)

if (fresnel > 0.05 && combined_foam_intensity < 0.9) {

vec3 surface_view_position = get_view_position_from_depth(screen_uv, FRAGCOORD.z, INV_PROJECTION_MATRIX);


vec3 flat_world_normal = vec3(0.0, 1.0, 0.0);

vec3 ssr_stabilized_normal = normalize(mix(world_space_normal, flat_world_normal, ssr_wave_smoothness));

vec3 normal_view_space = (VIEW_MATRIX * vec4(ssr_stabilized_normal, 0.0)).xyz;


vec4 ssr_result = get_ssr_color(screen_uv, surface_view_position, normal_view_space, PROJECTION_MATRIX, INV_PROJECTION_MATRIX);


float foam_block = clamp(1.0 - (combined_foam_intensity * 3.0), 0.0, 1.0);


final_color = mix(final_color, ssr_result.rgb, ssr_result.a * fresnel * ssr_mix_strength * foam_block);

}



// Adiciona a espuma visualmente (Branca)

ALBEDO = final_color + (vec3(1.0) * combined_foam_intensity); 

METALLIC = 0.0;

ROUGHNESS = roughness;

SPECULAR = specular_amount;

ALPHA = transparency;

}