shader_type spatial;
render_mode depth_prepass_alpha, cull_disabled, world_vertex_coords;

uniform sampler2D texture_albedo : source_color, filter_nearest_mipmap_anisotropic, repeat_disable;
uniform vec4 transmission : source_color;
uniform vec4 albedo_color : source_color;
uniform vec4 backlight : source_color;
uniform sampler2D texture_backlight : hint_default_black, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform float backlight_intensity : hint_range(0.0, 10.0) = 1.0;

// Parâmetros para o fade baseado na distância
uniform float fade_start_distance : hint_range(5.0, 500.0) = 20.0;
uniform float fade_end_distance : hint_range(10.0, 500.0) = 40.0;

// Parâmetros para controle do vento
uniform float wind_strength : hint_range(0.0, 2.0) = 0.5;        // Força geral do vento
uniform float wind_speed : hint_range(0.0, 10.0) = 1.0;          // Velocidade do vento
uniform vec2 wind_direction = vec2(1.0, 0.5);                    // Direção do vento
uniform float wind_turbulence : hint_range(0.0, 5.0) = 1.0;      // Turbulência do vento
uniform float wind_gust_strength : hint_range(0.0, 3.0) = 0.3;   // Força das rajadas
uniform float wind_gust_frequency : hint_range(0.0, 5.0) = 0.2;  // Frequência das rajadas

varying float vertex_distance;

// Função para gerar ruído pseudo-aleatório baseado em uma posição
float random(vec2 pos) {
    return fract(sin(dot(pos.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

// Função de ruído simplex para movimentos orgânicos do vento
vec2 simplex_noise(vec2 pos) {
    float n1 = random(pos);
    float n2 = random(pos * 1.5 + vec2(4.0, 2.3));
    return vec2(n1, n2) * 2.0 - 1.0;
}

void vertex() {
    NORMAL = vec3(0.0, 1.0, 0.0);

    // Normaliza a direção do vento
    vec2 wind_dir = normalize(wind_direction);

    // Posição da base da grama no mundo para variação espacial
    vec2 world_pos = vec2(NODE_POSITION_WORLD.x, NODE_POSITION_WORLD.z);

    // Fase de tempo com velocidade do vento
    float time_phase = TIME * wind_speed;

    // Cálculo da turbulência variando em diferentes frequências
    vec2 turbulence = simplex_noise(world_pos * 0.1 + time_phase * 0.2);
    turbulence += simplex_noise(world_pos * 0.2 - time_phase * 0.15) * 0.5;
    turbulence *= wind_turbulence;

    // Rajadas de vento - variação temporal mais ampla
    float gust = sin(time_phase * 0.3 + turbulence.x) * 0.5 + 0.5;
    gust = pow(gust, 1.5) * wind_gust_strength; // Afiar as rajadas

    // Variação local para quebrar uniformidade (baseada na posição mundial)
    float local_variation = random(world_pos * 0.05) * 0.5 + 0.5;

    // Direção principal do vento com turbulência
    vec2 wind_movement = wind_dir + turbulence * 0.3;

    // Aplicar vento baseado na altura da lâmina (UV.y)
    // Quanto mais alto na lâmina (menor UV.y), mais dobra
    float bend_factor = (1.0 - UV.y);
    bend_factor = pow(bend_factor, 1.5); // Fator de curvatura não linear

    // Força total do vento com rajadas e variações
    float total_wind_strength = wind_strength * (1.0 + gust) * (0.8 + local_variation * 0.4);

    // Movimento oscilatório principal
    float wave_x = sin(world_pos.x * 0.5 + time_phase + UV.y * 2.0);
    float wave_z = cos(world_pos.y * 0.4 + time_phase * 0.8 + UV.y * 1.5);

    // Aplica o movimento ao vértice
    VERTEX.x += (wave_x * wind_movement.x + turbulence.x * 0.2) * bend_factor * total_wind_strength;
    VERTEX.z += (wave_z * wind_movement.y + turbulence.y * 0.2) * bend_factor * total_wind_strength;

    // Movimento sutil adicional para dar mais vida
    VERTEX.y -= bend_factor * bend_factor * 0.05 * total_wind_strength; // Pequena compressão

    // Calcular a distância no vértice e passar para o fragment shader
    vertex_distance = length(VERTEX - CAMERA_POSITION_WORLD);
}

void fragment() {
    vec4 albedo_tex = texture(texture_albedo, UV);
    albedo_tex *= COLOR;
    ALBEDO = albedo_color.rgb * albedo_tex.rgb;

    // Aplica o fade baseado na distância calculada no vertex shader
    float fade_factor = 1.0;
    if (vertex_distance > fade_start_distance) {
        fade_factor = 1.0 - smoothstep(fade_start_distance, fade_end_distance, vertex_distance);
    }

    // Aplica o fade ao alpha
    ALPHA = albedo_tex.a * fade_factor;

    METALLIC = 0.0;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;

    // Usando a textura de backlight separada
    vec3 backlight_tex = texture(texture_backlight, UV).rgb;
    // Versão melhorada com curva de potência e valor base maior
    BACKLIGHT = backlight.rgb * pow(backlight_tex * backlight_intensity, vec3(0.7)) + vec3(0.15);
}