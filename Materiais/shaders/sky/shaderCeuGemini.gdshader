// Shader para Godot 4.5 (Mapeamento Planar)
shader_type sky;

// --- Uniforms (parâmetros que você pode ajustar no Inspector) ---

// Cores
uniform vec4 sky_color_top : source_color = vec4(0.2, 0.5, 0.9, 1.0);
uniform vec4 sky_color_horizon : source_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform vec4 cloud_color_primary : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cloud_color_secondary : source_color = vec4(0.8, 0.8, 0.85, 1.0);

// Sol
uniform float sun_size : hint_range(0.0, 1.0) = 0.03;
uniform float sun_sharpness : hint_range(1.0, 50.0) = 20.0;
uniform float sun_bloom : hint_range(0.0, 1000.0) = 2.5;

// Nuvens
uniform sampler2D cloud_noise : source_color, hint_default_white;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_sharpness : hint_range(0.0, 1.0) = 0.5;

// Camada 1
// NOTA: Você precisará usar valores BEM MENORES aqui, como 0.05 ou 0.1
uniform float scroll_speed_layer1 = 0.01;
uniform float cloud_scale_layer1 = 0.05;

// Camada 2
// NOTA: Você precisará usar valores BEM MENORES aqui, como 0.15 ou 0.2
uniform float scroll_speed_layer2 = 0.025;
uniform float cloud_scale_layer2 = 0.15;


void sky() {
	// --- Gradiente do Céu (Sem alteração) ---
	float sky_factor = smoothstep(0.0, 0.4, EYEDIR.y);
	vec3 sky_color = mix(sky_color_horizon.rgb, sky_color_top.rgb, sky_factor);

	// --- Desenho do Sol (Sem alteração) ---
	float sun_dist = distance(EYEDIR, LIGHT0_DIRECTION);
	float sun_disk = smoothstep(sun_size, sun_size - (sun_size * 0.9), sun_dist);
	sun_disk = pow(sun_disk, sun_sharpness);
	
	vec3 bright_sun_color = sun_color.rgb * (1.0 + sun_bloom); 
	
	vec3 color_before_clouds = mix(sky_color, bright_sun_color, sun_disk);
	
	// --- Desenho das Nuvens (COM ALTERAÇÃO) ---
	
	// <-- ALTERADO: Calcula a projeção planar
	// Usamos EYEDIR (direção do olhar) para projetar as coordenadas em um plano
	// Dividimos XZ por Y para obter a perspectiva de um plano.
	// max(EYEDIR.y, 0.001) evita divisão por zero no horizonte.
	float view_y = max(EYEDIR.y, 0.001); 
	vec2 planar_uv = EYEDIR.xz / view_y;

	// <-- ALTERADO: Usa 'planar_uv' em vez de 'SKY_COORDS'
	vec2 uv_layer1 = planar_uv * cloud_scale_layer1 + vec2(TIME * scroll_speed_layer1, TIME * scroll_speed_layer1 * 0.5);
	vec2 uv_layer2 = planar_uv * cloud_scale_layer2 + vec2(TIME * scroll_speed_layer2, 0.0);
	
	float noise1 = texture(cloud_noise, uv_layer1).r;
	float noise2 = texture(cloud_noise, uv_layer2).r;
	
	float combined_noise = noise1 * noise2;
	
	float cloud_mask = smoothstep(1.0 - cloud_coverage, (1.0 - cloud_coverage) + cloud_sharpness, combined_noise);
	
	// <-- NOVO: Adiciona um fade (desvanecimento) no horizonte
	// Isso faz as nuvens desaparecerem suavemente quando EYEDIR.y (altura) se aproxima de 0
	float horizon_fade = smoothstep(0.0, 0.1, EYEDIR.y);
	cloud_mask *= horizon_fade; // Multiplica a máscara de nuvem pelo fade
	
	
	vec3 cloud_final_color = mix(cloud_color_secondary.rgb, cloud_color_primary.rgb, noise1);
	
	// --- Composição Final (Sem alteração) ---
	vec3 final_color = mix(color_before_clouds, cloud_final_color, cloud_mask);
	
	COLOR = final_color;
}