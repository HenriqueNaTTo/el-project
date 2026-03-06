shader_type spatial;

// Parâmetros ajustáveis para o vento
uniform float wind_strength = 0.2;   // Intensidade do vento
uniform float wind_speed = 1.0;     // Velocidade do vento
uniform float wind_frequency = 2.0; // Frequência do vento
uniform float tree_height = 3.0;    // Altura máxima da árvore
uniform float wind_start = 1.5;     // Altura onde o vento começa a afetar

render_mode depth_prepass_alpha, cull_disabled, world_vertex_coords;

uniform sampler2D texture_albedo : source_color, filter_nearest_mipmap_anisotropic;
uniform vec4 transmission : source_color;
uniform vec4 albedo_color : source_color;
uniform vec4 backlight : source_color;
uniform sampler2D texture_backlight : hint_default_black, filter_nearest_mipmap_anisotropic, repeat_enable;
// Parâmetros de backlight
uniform float backlight_strength = 0.5; // Intensidade do backlight
uniform vec4 backlight_color; // Cor do backlight

void vertex() {
    // Máscara baseada na altura da árvore (tronco fixo, galhos móveis)
    float mask = smoothstep(wind_start, tree_height, VERTEX.y);

    // Cálculo do deslocamento do vento
    float wind_offset = sin(TIME * wind_speed + VERTEX.y * wind_frequency) * wind_strength * mask;

    // Aplica o vento apenas na parte superior da árvore
    VERTEX.x += wind_offset;
}

void fragment() {
    vec4 albedo_tex = texture(texture_albedo, UV);
	albedo_tex *= COLOR;

	ALBEDO = albedo_color.rgb * albedo_tex.rgb;
    //ALBEDO = albedo_tex.rgb;
    ALPHA = albedo_tex.a;
    METALLIC = 0.0;
    ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	vec3 backlight_tex = texture(texture_albedo, UV).rgb;
	BACKLIGHT = (backlight.rgb + backlight_tex);
}
