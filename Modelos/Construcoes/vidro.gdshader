shader_type spatial;

// Configurações para vidros que brilham
render_mode blend_mix, depth_draw_always, cull_back;

// --- Configurações Visuais ---
group_uniforms Vidro;
uniform vec4 cor_vidro : source_color = vec4(0.1, 0.3, 0.5, 0.2);
uniform float rugosidade : hint_range(0.0, 1.0) = 0.05;
uniform float metalico : hint_range(0.0, 1.0) = 0.1;

group_uniforms Emissao;
uniform vec4 cor_emissiva : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float forca_brilho : hint_range(0.0, 16.0) = 2.0; // Valores > 1.0 ativam o Glow
uniform sampler2D textura_emissiva : source_color; // Para vidros com desenhos/padrões neon

group_uniforms Refracao;
uniform float forca_refracao : hint_range(0.0, 0.2) = 0.05;
uniform float aberracao_cromatica : hint_range(0.0, 1.0) = 0.1;
uniform sampler2D mapa_normal : hint_normal;
uniform float forca_normal : hint_range(0.0, 5.0) = 0.5;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	// 1. Normais
	vec3 n_tex = texture(mapa_normal, UV).rgb;
	NORMAL_MAP = n_tex;
	NORMAL_MAP_DEPTH = forca_normal;

	// 2. Fresnel (Importante para o brilho ser mais forte nas bordas ou no centro)
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);

	// 3. Refração
	vec2 offset_uv = NORMAL.xy * forca_refracao;
	float aberracao = aberracao_cromatica * 0.02;
	float nivel_blur = rugosidade * 4.0;

	float r = textureLod(screen_texture, SCREEN_UV + offset_uv - vec2(aberracao, 0.0), nivel_blur).r;
	float g = textureLod(screen_texture, SCREEN_UV + offset_uv, nivel_blur).g;
	float b = textureLod(screen_texture, SCREEN_UV + offset_uv + vec2(aberracao, 0.0), nivel_blur).b;
	vec3 cor_refratada = vec3(r, g, b);

	// 4. Lógica de Emissão
	vec4 tex_emissiva = texture(textura_emissiva, UV);
	// Multiplicamos a cor pela força e pela textura (se houver)
	vec3 emissao_final = cor_emissiva.rgb * tex_emissiva.rgb * forca_brilho;

	// 5. Mix Final
	// O Albedo mantém a base do vidro e reflexão
	ALBEDO = mix(cor_refratada, cor_vidro.rgb, cor_vidro.a + (fresnel * 0.5));
	
	// A mágica acontece aqui: somamos o brilho no canal EMISSION
	EMISSION = emissao_final;

	METALLIC = metalico;
	ROUGHNESS = rugosidade;
	ALPHA = 1.0; 
}