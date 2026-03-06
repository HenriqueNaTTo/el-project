shader_type spatial;
render_mode unshaded, depth_test_disabled, skip_vertex_transform;

// --- CONFIGURAÇÃO DE PIXELIZAÇÃO ---
// Defina a resolução vertical aqui (ex: 320 para estilo PS1, 1080 para HD)
uniform float pixel_factor : hint_range(64.0, 1080.0) = 320.0; 

// --- CONFIGURAÇÃO DO OUTLINE ---
uniform float outline_threshold : hint_range(0.0, 1.0) = 0.2;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0); // Cor da linha (Preto padrão)
uniform float outline_thickness : hint_range(0.0, 5.0) = 1.0;

// Texturas do Sistema (Não mude)
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

void vertex() {
	// Trava o Quad na tela inteira
	POSITION = vec4(VERTEX.x, VERTEX.y, 0.0, 1.0);
}

void fragment() {
	// 1. CÁLCULO DA GRID DE PIXELS
	float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	vec2 grid_size = vec2(pixel_factor * aspect, pixel_factor);
	
	// Arredonda a coordenada UV para criar o efeito "bloco"
	vec2 grid_uv = floor(SCREEN_UV * grid_size) / grid_size;
	
	// 2. COR ORIGINAL (Sem alterações)
	// Pegamos a cor direto da tela, mas usando a coordenada pixelada
	vec4 original_color = texture(screen_texture, grid_uv);
	
	// 3. CÁLCULO DO OUTLINE (Baseado em Profundidade)
	float depth_center = texture(depth_texture, grid_uv).r;
	vec2 pixel_size = (1.0 / grid_size) * outline_thickness;
	
	// Amostragem em cruz (Vizinhos)
	float d_left = texture(depth_texture, grid_uv + vec2(-pixel_size.x, 0.0)).r;
	float d_right = texture(depth_texture, grid_uv + vec2(pixel_size.x, 0.0)).r;
	float d_up = texture(depth_texture, grid_uv + vec2(0.0, -pixel_size.y)).r;
	float d_down = texture(depth_texture, grid_uv + vec2(0.0, pixel_size.y)).r;
	
	// Diferença de profundidade
	float depth_diff = abs(depth_center - d_left) + abs(depth_center - d_right) + 
					   abs(depth_center - d_up) + abs(depth_center - d_down);
	
	// Define onde é borda
	// O multiplicador 0.05 é um ajuste para o depth buffer logarítmico da Godot
	float edge = step(outline_threshold * 0.05, depth_diff); 
	
	// 4. MISTURA FINAL
	// Se for borda, pinta de outline_color. Se não, mostra a cor original.
	ALBEDO = mix(original_color.rgb, outline_color.rgb, edge);
}