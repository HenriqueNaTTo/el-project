shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

// --- CONFIGURAÇÕES GERAIS ---
group_uniforms Base_Material;
uniform vec4 base_color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D base_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D base_roughness : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D base_height : hint_default_black, filter_linear_mipmap_anisotropic;
uniform float base_uv_scale = 1.0;

// Opções de Parallax para a Base
uniform float base_depth_scale : hint_range(0.0, 0.2) = 0.05;
uniform int base_pom_min_layers : hint_range(1, 64) = 16;
uniform int base_pom_max_layers : hint_range(1, 64) = 32;

group_uniforms Overlay_Material;
uniform vec4 overlay_color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D overlay_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D overlay_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D overlay_roughness : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D overlay_height : hint_default_black, filter_linear_mipmap_anisotropic; // Atualizado o filtro
uniform float overlay_uv_scale = 1.0;

// NOVAS Opções de Parallax para o Overlay
uniform float overlay_depth_scale : hint_range(0.0, 0.2) = 0.05;
uniform int overlay_pom_min_layers : hint_range(1, 64) = 16;
uniform int overlay_pom_max_layers : hint_range(1, 64) = 32;

group_uniforms Masking;
uniform sampler2D noise_texture : hint_default_white, filter_linear_mipmap; 
uniform float noise_scale = 1.0;
uniform float blend_sharpness : hint_range(0.0, 1.0) = 0.5;
uniform float height_blend_contrast : hint_range(0.001, 1.0) = 0.1; 

group_uniforms Logic_Contact;
uniform bool use_contact = true;
uniform float contact_distance : hint_range(0.0, 2.0) = 0.5;
uniform float contact_intensity : hint_range(0.0, 5.0) = 1.0;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

group_uniforms Logic_Top;
uniform bool use_top = true;
uniform float top_threshold : hint_range(-1.0, 1.0) = 0.5;
uniform float top_softness : hint_range(0.0, 1.0) = 0.2;

// --- VARIÁVEIS PARA COMUNICAÇÃO VERTEX -> FRAGMENT ---
varying vec3 world_normal;

// --- FUNÇÕES ---
void vertex() {
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	// Inicialização das coordenadas UV
	vec2 current_base_uv = UV * base_uv_scale;
	vec2 current_over_uv = UV * overlay_uv_scale;
	
	// Calcula a direção da câmera no Tangent Space (compartilhado por ambas as camadas)
	vec3 view_dir_ts = normalize(normalize(-VERTEX) * mat3(TANGENT, BINORMAL, NORMAL));
	float dot_view_up = abs(dot(vec3(0.0, 0.0, 1.0), view_dir_ts)); // Auxiliar para camadas dinâmicas

	// --- 1. POM - SOMENTE PARA A BASE ---
	{
		float num_layers = mix(float(base_pom_max_layers), float(base_pom_min_layers), dot_view_up);
		float layer_depth = 1.0 / num_layers;
		float current_layer_depth = 0.0;
		vec2 p = view_dir_ts.xy * base_depth_scale / num_layers;
		float h_base = texture(base_height, current_base_uv).r;

		// Loop do Raymarching Base
		int safety_break = int(base_pom_max_layers);
		for (int i = 0; i < safety_break; i++) {
			if (current_layer_depth >= h_base) break;
			current_base_uv -= p;
			h_base = texture(base_height, current_base_uv).r;
			current_layer_depth += layer_depth;
		}
		// Interpolação Base
		vec2 prev_uv = current_base_uv + p;
		float next_depth = h_base - current_layer_depth;
		float prev_depth = texture(base_height, prev_uv).r - current_layer_depth + layer_depth;
		float weight = next_depth / (next_depth - prev_depth);
		current_base_uv = mix(current_base_uv, prev_uv, weight);
	}

	// --- 2. POM - SOMENTE PARA O OVERLAY ---
	{
		float num_layers = mix(float(overlay_pom_max_layers), float(overlay_pom_min_layers), dot_view_up);
		float layer_depth = 1.0 / num_layers;
		float current_layer_depth = 0.0;
		vec2 p = view_dir_ts.xy * overlay_depth_scale / num_layers;
		float h_over = texture(overlay_height, current_over_uv).r;

		// Loop do Raymarching Overlay
		int safety_break = int(overlay_pom_max_layers);
		for (int i = 0; i < safety_break; i++) {
			if (current_layer_depth >= h_over) break;
			current_over_uv -= p;
			h_over = texture(overlay_height, current_over_uv).r;
			current_layer_depth += layer_depth;
		}
		// Interpolação Overlay
		vec2 prev_uv = current_over_uv + p;
		float next_depth = h_over - current_layer_depth;
		float prev_depth = texture(overlay_height, prev_uv).r - current_layer_depth + layer_depth;
		float weight = next_depth / (next_depth - prev_depth);
		current_over_uv = mix(current_over_uv, prev_uv, weight);
	}

	// -----------------------------------------------------------------

	// Ler Alturas Finais (nos UVs deslocados) para o Height Blending
	float h_base_final = texture(base_height, current_base_uv).r;
	float h_over_final = texture(overlay_height, current_over_uv).r;

	// Ler Texturas de Cor, Normal e Roughness (nos UVs deslocados)
	vec3 col_base = texture(base_albedo, current_base_uv).rgb * base_color_tint.rgb; 
	vec3 norm_base = texture(base_normal, current_base_uv).rgb;
	float rgh_base = texture(base_roughness, current_base_uv).r;

	vec3 col_over = texture(overlay_albedo, current_over_uv).rgb * overlay_color_tint.rgb; 
	vec3 norm_over = texture(overlay_normal, current_over_uv).rgb;
	float rgh_over = texture(overlay_roughness, current_over_uv).r;
	
	// Ruído (usa o UV original para não "nadar" com a profundidade)
	float noise = texture(noise_texture, UV * noise_scale).r;

	// --- LÓGICA DE MÁSCARA DE MISTURA ---
	float final_mask = 0.0;

	if (use_contact) {
		float depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
		vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		view.xyz /= view.w;
		float linear_depth = -view.z;
		float object_depth = -VERTEX.z; 
		float depth_diff = linear_depth - object_depth;
		float contact_mask = 1.0 - smoothstep(0.0, contact_distance, depth_diff);
		final_mask = max(final_mask, contact_mask * contact_intensity);
	}

	if (use_top) {
		vec3 w_norm = normalize(world_normal);
		float top_dot = dot(w_norm, vec3(0.0, 1.0, 0.0));
		float top_mask = smoothstep(top_threshold - top_softness, top_threshold + top_softness, top_dot);
		final_mask = max(final_mask, top_mask);
	}

	float combined_mask = clamp(final_mask + (noise - 0.5) * blend_sharpness, 0.0, 1.0);

	// --- HEIGHT BLENDING (Combinando Máscaras com Alturas Reais Deslocadas) ---
	float h1 = h_base_final + (1.0 - combined_mask);
	float h2 = h_over_final + combined_mask;
	float height_diff = h2 - h1;
	
	float mix_factor = clamp((height_diff / height_blend_contrast) + 0.5, 0.0, 1.0);

	// Mistura Final
	ALBEDO = mix(col_base, col_over, mix_factor);
	ROUGHNESS = mix(rgh_base, rgh_over, mix_factor);
	NORMAL_MAP = mix(norm_base, norm_over, mix_factor); 
}