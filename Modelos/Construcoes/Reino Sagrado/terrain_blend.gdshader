shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

// ============================================================
//  MATERIAL BASE
// ============================================================
group_uniforms Base_Material;
uniform vec4  base_color_tint    : source_color = vec4(1.0);
uniform sampler2D base_albedo    : source_color,         filter_linear_mipmap_anisotropic;
uniform sampler2D base_normal    : hint_normal,           filter_linear_mipmap_anisotropic;
uniform sampler2D base_roughness : hint_default_white,   filter_linear_mipmap_anisotropic;
uniform sampler2D base_height    : hint_default_black,   filter_linear_mipmap_anisotropic;
uniform float base_uv_scale      = 1.0;
uniform float base_depth_scale   : hint_range(0.0, 0.2)  = 0.05;
uniform int   base_pom_min_layers: hint_range(1,  64)    = 8;
uniform int   base_pom_max_layers: hint_range(1,  64)    = 32;

// ============================================================
//  MATERIAL OVERLAY
// ============================================================
group_uniforms Overlay_Material;
uniform vec4  overlay_color_tint    : source_color = vec4(1.0);
uniform sampler2D overlay_albedo    : source_color,         filter_linear_mipmap_anisotropic;
uniform sampler2D overlay_normal    : hint_normal,           filter_linear_mipmap_anisotropic;
uniform sampler2D overlay_roughness : hint_default_white,   filter_linear_mipmap_anisotropic;
uniform sampler2D overlay_height    : hint_default_black,   filter_linear_mipmap_anisotropic;
uniform float overlay_uv_scale      = 1.0;
uniform float overlay_depth_scale   : hint_range(0.0, 0.2)  = 0.05;
uniform int   overlay_pom_min_layers: hint_range(1,  64)    = 8;
uniform int   overlay_pom_max_layers: hint_range(1,  64)    = 32;

// ============================================================
//  MÁSCARA / BLEND
// ============================================================
group_uniforms Masking;
uniform sampler2D noise_texture    : hint_default_white, filter_linear_mipmap;
uniform float noise_scale          = 1.0;
uniform float blend_sharpness      : hint_range(0.0, 1.0)   = 0.5;
uniform float height_blend_contrast: hint_range(0.001, 1.0) = 0.1;

// ============================================================
//  LÓGICA – CONTACT
// ============================================================
group_uniforms Logic_Contact;
uniform bool  use_contact        = true;
uniform float contact_distance   : hint_range(0.0, 2.0) = 0.5;
uniform float contact_intensity  : hint_range(0.0, 5.0) = 1.0;
uniform sampler2D DEPTH_TEXTURE  : hint_depth_texture, filter_linear_mipmap;

// ============================================================
//  LÓGICA – TOP (superfície superior)
// ============================================================
group_uniforms Logic_Top;
uniform bool  use_top        = true;
uniform float top_threshold  : hint_range(-1.0, 1.0) = 0.5;
uniform float top_softness   : hint_range(0.0,  1.0) = 0.2;

// ============================================================
//  VARYING
// ============================================================
varying vec3 world_normal;

// ============================================================
//  FUNÇÃO AUXILIAR – Parallax Occlusion Mapping (POM)
// ============================================================
vec2 apply_pom(
	sampler2D height_map,
	vec2      uv,
	vec3      view_dir_ts,
	float     depth_scale,
	int       min_layers,
	int       max_layers
) {
	// Número de camadas varia com o ângulo de visão (mais camadas = mais preciso)
	float n_dot_v    = abs(dot(vec3(0.0, 0.0, 1.0), view_dir_ts));
	float num_layers = mix(float(max_layers), float(min_layers), n_dot_v);

	float layer_depth   = 1.0 / num_layers;
	float current_depth = 0.0;
	vec2  delta_uv      = (view_dir_ts.xy * depth_scale) / num_layers;

	vec2  cur_uv    = uv;
	float cur_h     = texture(height_map, cur_uv).r;

	// Raymarching
	for (int i = 0; i < max_layers; i++) {
		if (current_depth >= cur_h) break;
		cur_uv      -= delta_uv;
		cur_h        = texture(height_map, cur_uv).r;
		current_depth += layer_depth;
	}

	// Interpolação linear entre as duas últimas camadas (parallax refinado)
	vec2  prev_uv   = cur_uv + delta_uv;
	float next_h    = cur_h  - current_depth;
	float prev_h    = texture(height_map, prev_uv).r - current_depth + layer_depth;
	float weight    = next_h / (next_h - prev_h);

	return mix(cur_uv, prev_uv, weight);
}

// ============================================================
//  VERTEX
// ============================================================
void vertex() {
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

// ============================================================
//  FRAGMENT
// ============================================================
void fragment() {
	// ----- Direção de visão no Tangent Space -----
	// view_dir_ts aponta da superfície para a câmera, em espaço tangente
	vec3 view_dir_ts = normalize(normalize(-VERTEX) * mat3(TANGENT, BINORMAL, NORMAL));

	// ----- POM para cada camada -----
	vec2 uv_base = apply_pom(
		base_height,
		UV * base_uv_scale,
		view_dir_ts,
		base_depth_scale,
		base_pom_min_layers,
		base_pom_max_layers
	);

	vec2 uv_over = apply_pom(
		overlay_height,
		UV * overlay_uv_scale,
		view_dir_ts,
		overlay_depth_scale,
		overlay_pom_min_layers,
		overlay_pom_max_layers
	);

	// ----- Leitura das texturas (UVs pós-POM) -----
	vec3  col_base  = texture(base_albedo,    uv_base).rgb * base_color_tint.rgb;
	vec3  norm_base = texture(base_normal,    uv_base).rgb;
	float rgh_base  = texture(base_roughness, uv_base).r;
	float h_base    = texture(base_height,    uv_base).r;

	vec3  col_over  = texture(overlay_albedo,    uv_over).rgb * overlay_color_tint.rgb;
	vec3  norm_over = texture(overlay_normal,    uv_over).rgb;
	float rgh_over  = texture(overlay_roughness, uv_over).r;
	float h_over    = texture(overlay_height,    uv_over).r;

	// Ruído usa UV original para não "nadar" junto com o parallax
	float noise = texture(noise_texture, UV * noise_scale).r;

	// ----- Máscara final -----
	float final_mask = 0.0;

	// -- Máscara de Contato (proximity ao chão / outras meshes) --
	if (use_contact) {
		float raw_depth   = texture(DEPTH_TEXTURE, SCREEN_UV).x;
		vec3  ndc         = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
		vec4  view_pos    = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		view_pos.xyz     /= view_pos.w;

		float scene_depth  = -view_pos.z;
		float frag_depth   = -VERTEX.z;
		float depth_diff   = scene_depth - frag_depth;

		float contact_mask = 1.0 - smoothstep(0.0, contact_distance, depth_diff);
		final_mask = max(final_mask, contact_mask * contact_intensity);
	}

	// -- Máscara de Topo (superfícies que apontam para cima) --
	if (use_top) {
		float top_dot  = dot(normalize(world_normal), vec3(0.0, 1.0, 0.0));
		float top_mask = smoothstep(
			top_threshold - top_softness,
			top_threshold + top_softness,
			top_dot
		);
		final_mask = max(final_mask, top_mask);
	}

	// Adiciona ruído para bordas orgânicas
	float combined_mask = clamp(final_mask + (noise - 0.5) * blend_sharpness, 0.0, 1.0);

	// ----- Height Blending -----
	// Favorece a camada mais alta em cada ponto, com transição suave
	float h1 = h_base + (1.0 - combined_mask);
	float h2 = h_over + combined_mask;

	float mix_factor = clamp((h2 - h1) / height_blend_contrast + 0.5, 0.0, 1.0);

	// ----- Saída final -----
	ALBEDO     = mix(col_base,  col_over,  mix_factor);
	ROUGHNESS  = mix(rgh_base,  rgh_over,  mix_factor);
	NORMAL_MAP = mix(norm_base, norm_over, mix_factor);
}
