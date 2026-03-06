shader_type spatial;
render_mode cull_disabled;

// --- CONFIGURAÇÕES GERAIS ---
group_uniforms Base_Material;
uniform vec4 base_color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D base_albedo : source_color, filter_linear_mipmap;
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap;
uniform sampler2D base_roughness : hint_default_white, filter_linear_mipmap;
uniform sampler2D base_height : hint_default_black, filter_linear_mipmap;
uniform float base_uv_scale = 1.0;

group_uniforms Overlay_Material;
uniform vec4 overlay_color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D overlay_albedo : source_color, filter_linear_mipmap;
uniform sampler2D overlay_normal : hint_normal, filter_linear_mipmap;
uniform sampler2D overlay_roughness : hint_default_white, filter_linear_mipmap;
uniform sampler2D overlay_height : hint_default_black, filter_linear_mipmap;
uniform float overlay_uv_scale = 1.0;

group_uniforms Masking;
uniform sampler2D noise_texture : hint_default_white, filter_linear_mipmap; 
uniform float noise_scale = 1.0;
uniform float blend_sharpness : hint_range(0.0, 1.0) = 0.5;
uniform float height_blend_contrast : hint_range(0.001, 1.0) = 0.1; 

group_uniforms Logic_Contact;
uniform bool use_contact = true;
uniform float contact_distance : hint_range(0.0, 2.0) = 0.5;
uniform float contact_intensity : hint_range(0.0, 5.0) = 1.0;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear;

group_uniforms Logic_Top;
uniform bool use_top = true;
uniform float top_threshold : hint_range(-1.0, 1.0) = 0.5;
uniform float top_softness : hint_range(0.0, 1.0) = 0.2;

// --- VARIÁVEIS PARA COMUNICAÇÃO VERTEX -> FRAGMENT ---
varying vec3 world_normal;

// --- FUNÇÕES ---
void vertex() {
	// Necessário apenas para saber qual é a direção "para cima" na lógica Top
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	// Coordenadas UV Padrão
	vec2 uv_base = UV * base_uv_scale;
	vec2 uv_over = UV * overlay_uv_scale;

	// Ler Texturas e APLICAR A COR
	vec3 col_base = texture(base_albedo, uv_base).rgb * base_color_tint.rgb; 
	vec3 norm_base = texture(base_normal, uv_base).rgb;
	float rgh_base = texture(base_roughness, uv_base).r;
	float h_base = texture(base_height, uv_base).r; 

	vec3 col_over = texture(overlay_albedo, uv_over).rgb * overlay_color_tint.rgb; 
	vec3 norm_over = texture(overlay_normal, uv_over).rgb;
	float rgh_over = texture(overlay_roughness, uv_over).r;
	float h_over = texture(overlay_height, uv_over).r; 
	
	// Ruído agora usa o UV padrão em vez do mundo real
	float noise = texture(noise_texture, UV * noise_scale).r;

	// --- LÓGICA DE MÁSCARA BASE ---
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

	// Mistura o ruído com a máscara calculada
	float combined_mask = clamp(final_mask + (noise - 0.5) * blend_sharpness, 0.0, 1.0);

	// --- HEIGHT BLENDING ---
	float h1 = h_base + (1.0 - combined_mask);
	float h2 = h_over + combined_mask;
	float height_diff = h2 - h1;
	
	float mix_factor = clamp((height_diff / height_blend_contrast) + 0.5, 0.0, 1.0);

	// Mistura Final
	ALBEDO = mix(col_base, col_over, mix_factor);
	ROUGHNESS = mix(rgh_base, rgh_over, mix_factor);
	NORMAL_MAP = mix(norm_base, norm_over, mix_factor);
}