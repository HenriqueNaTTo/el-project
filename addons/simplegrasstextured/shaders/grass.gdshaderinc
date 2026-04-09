

// render_mode: depth_draw_opaque é necessário para a grama ter sombra e ordem
render_mode depth_draw_opaque, cull_disabled, specular_schlick_ggx;

// --- Texturas ---
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec4 transmission : source_color = vec4(0.5, 0.5, 0.5, 1.0);

// --- Configuração do Vento ---
group_uniforms Vento_Suave;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec2 wind_direction = vec2(1.0, 0.0);
uniform float wind_speed : hint_range(0.0, 2.0) = 0.5;
uniform float wind_strength : hint_range(0.0, 2.0) = 0.5;
uniform float turbulence_scale : hint_range(0.1, 10.0) = 1.0;

// --- Fade ---
group_uniforms Distancia;
uniform float fade_start_distance : hint_range(5.0, 500.0) = 40.0;
uniform float fade_end_distance : hint_range(10.0, 500.0) = 60.0;

void vertex() {
	// Lógica de Fade (Mantida igual)
	float dist = distance(CAMERA_POSITION_WORLD, NODE_POSITION_WORLD);
	float scale_factor = 1.0;
	if (dist > fade_start_distance) {
		scale_factor = 1.0 - smoothstep(fade_start_distance, fade_end_distance, dist);
	}
	
	if (scale_factor <= 0.01) {
		VERTEX = vec3(0.0);
	} else {
		// --- Lógica de Vento (Mantida igual) ---
		float height = 1.0 - UV.y;
		float bend_intensity = height * height; 

		vec2 wind_dir_norm = normalize(wind_direction);
		float time_offset = TIME * wind_speed;
		vec2 world_pos = NODE_POSITION_WORLD.xz;
		
		vec2 noise_uv = (world_pos / (10.0 * turbulence_scale)) + (wind_dir_norm * time_offset * 0.05);
		float noise_val = texture(noise_tex, noise_uv).r;
		
		vec2 turbulence_uv = (world_pos / (2.0 * turbulence_scale)) + vec2(time_offset * 0.1);
		float turbulence_val = texture(noise_tex, turbulence_uv).r;

		float combined_wind = mix(noise_val, turbulence_val, 0.3);
		float wind_force = (combined_wind * 2.0 - 0.5) * wind_strength;

		VERTEX.x += wind_dir_norm.x * wind_force * bend_intensity;
		VERTEX.z += wind_dir_norm.y * wind_force * bend_intensity;
		
		float side_sway = sin(TIME * wind_speed + world_pos.x) * (wind_strength * 0.3);
		VERTEX.x += wind_dir_norm.y * side_sway * bend_intensity; 
		VERTEX.z -= wind_dir_norm.x * side_sway * bend_intensity; 

		float displacement = length(vec2(wind_force, side_sway)) * bend_intensity;
		VERTEX.y -= displacement * 0.3;

		VERTEX *= scale_factor;
	}
}

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	ALBEDO = albedo_color.rgb * albedo_tex.rgb;
	
	// ALPHA SCISSOR
	ALPHA = albedo_tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	
	// --- CORREÇÃO PARA REMOVER SSAO E SSIL ---
	
	// 1. Oclusão de Ambiente (AO)
	// Forçamos o canal de AO para 1.0 (branco total). 
	// Isso diz ao renderizador que esta superfície recebe luz ambiente máxima.
	AO = 1.0; 
	AO_LIGHT_AFFECT = 0.0; // Garante que o AO não afete a cor final

	// 2. Normais (O Segredo)
	// Em vez de mix(NORMAL, ..., 0.5), forçamos 100% para CIMA.
	// O SSAO só gera sombra quando vê ângulos entre normais. 
	// Se tudo aponta para cima, o SSAO acha que é um chão plano e não gera sombra "suja" na grama.
	NORMAL = vec3(0.0, 1.0, 0.0);

	// 3. Rugosidade (Para evitar SSIL/SSR)
	// Se a rugosidade for baixa, o SSIL tenta calcular reflexos de luz indireta.
	// Aumentar para 1.0 (fosco total) elimina o ruído do SSIL.
	ROUGHNESS = 0.65; 
	METALLIC = 0.0;
	SPECULAR = 0.1; // Remove brilho especular que também pode gerar ruído SSIL

	// Backlight (Mantido)
	vec3 backlight_color = transmission.rgb * (1.0 - albedo_tex.rgb);
	BACKLIGHT = backlight_color * 1.5;
}