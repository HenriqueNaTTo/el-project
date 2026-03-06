shader_type spatial;

uniform vec3 lava_color : source_color = vec3(1.0, 0.3, 0.0);
uniform vec3 rock_color : source_color = vec3(0.05, 0.05, 0.05);
uniform float speed : hint_range(0.0, 1.0) = 0.05;
uniform float emission_strength : hint_range(0.0, 10.0) = 5.0;
uniform sampler2D noise_texture;

void fragment() {
	// Cria movimento UV baseado no tempo
	vec2 moving_uv = UV + vec2(TIME * speed, TIME * speed * 0.5);
	
	// Lê a textura de ruído
	float noise_value = texture(noise_texture, moving_uv).r;
	
	// Define o limite entre rocha e lava (efeito de máscara)
	float mask = smoothstep(0.4, 0.6, noise_value);
	
	// Interpola entre a cor da rocha e a cor da lava
	vec3 final_color = mix(lava_color, rock_color, mask);
	
	ALBEDO = final_color;
	
	// Aplica emissão apenas nas partes de lava
	EMISSION = lava_color * (1.0 - mask) * emission_strength;
	
	// Brilho metálico para a rocha
	ROUGHNESS = mix(0.2, 0.8, mask);
}