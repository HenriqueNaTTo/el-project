shader_type canvas_item;

// --- CONFIGURAÇÕES ---
uniform float pixel_factor : hint_range(64.0, 1080.0) = 320.0; // Resolução pixelada
uniform float outline_threshold : hint_range(0.0, 1.0) = 0.1; // Sensibilidade da borda
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// Na Godot 4, shaders 2D leem a tela usando este hint
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// Função para converter cor em escala de cinza (Luminância)
float get_luma(vec4 color) {
	return dot(color.rgb, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	// 1. CÁLCULO DA GRID DE PIXELS
	// Pega o tamanho da tela em pixels reais
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	
	// Calcula o aspecto para manter os pixels quadrados
	float aspect = screen_size.x / screen_size.y;
	vec2 virtual_grid = vec2(pixel_factor * aspect, pixel_factor);
	
	// Arredonda o UV para criar o pixelão
	vec2 grid_uv = floor(SCREEN_UV * virtual_grid) / virtual_grid;
	
	// 2. COR ORIGINAL PIXELIZADA
	vec4 original_color = texture(screen_texture, grid_uv);
	
	// 3. OUTLINE (Baseado em Contraste de Cor)
	// Como não temos Depth Buffer no ColorRect, comparamos a cor dos vizinhos.
	
	vec2 pixel_size = 1.0 / virtual_grid; // Tamanho de um pixel virtual
	
	// Pega a luminância (brilho) do pixel central
	float luma_center = get_luma(original_color);
	
	// Pega a luminância dos vizinhos (Cruz)
	float luma_left = get_luma(texture(screen_texture, grid_uv + vec2(-pixel_size.x, 0.0)));
	float luma_right = get_luma(texture(screen_texture, grid_uv + vec2(pixel_size.x, 0.0)));
	float luma_up = get_luma(texture(screen_texture, grid_uv + vec2(0.0, -pixel_size.y)));
	float luma_down = get_luma(texture(screen_texture, grid_uv + vec2(0.0, pixel_size.y)));
	
	// Calcula a diferença de brilho
	float luma_diff = abs(luma_center - luma_left) + abs(luma_center - luma_right) + 
					  abs(luma_center - luma_up) + abs(luma_center - luma_down);
	
	// Se a diferença de cor for grande, desenha a linha
	float edge = step(outline_threshold, luma_diff);
	
	// 4. SAÍDA
	COLOR = mix(original_color, outline_color, edge);
}