shader_type spatial;

render_mode cull_disabled;

uniform sampler2D rock_texture : filter_nearest_mipmap;
uniform sampler2D grass_texture : filter_nearest_mipmap;
uniform sampler2D mask_texture;

uniform sampler2D rock_normal_texture : filter_nearest_mipmap; // Mapa normal da rocha
uniform sampler2D grass_normal_texture : filter_nearest_mipmap; // Mapa normal da grama

uniform vec3 rock_scale = vec3(1.0);
uniform vec3 grass_scale = vec3(1.0);

uniform float contrast = 1.5; // Fator de contraste
uniform float brightness = 1.2; // Fator de claridade (brilho)
uniform float normal_intensity = 1.0; // Intensidade dos normais

// Função para ajustar o contraste
vec3 applyContrast(vec3 color, float contrast_value) {
    return (color - 0.5) * contrast_value + 0.5;
}

// Função para ajustar o brilho
vec3 applyBrightness(vec3 color, float brightness_value) {
    return color * brightness_value;
}

void fragment() {
    vec2 rock_uv = UV * rock_scale.xy;
    vec2 grass_uv = UV * grass_scale.xy;

    // Cores das texturas
    vec3 rock_color = texture(rock_texture, rock_uv).rgb;
    vec3 grass_color = texture(grass_texture, grass_uv).rgb;

    // Aplicar contraste e brilho às cores
    rock_color = applyContrast(rock_color, contrast);
    rock_color = applyBrightness(rock_color, brightness);

    grass_color = applyContrast(grass_color, contrast);
    grass_color = applyBrightness(grass_color, brightness);

    // Normais das texturas
    vec3 rock_normal = texture(rock_normal_texture, rock_uv).rgb;
    vec3 grass_normal = texture(grass_normal_texture, grass_uv).rgb;

    // Converter normais de [0, 1] para [-1, 1] e ajustar a intensidade
    rock_normal = normalize((rock_normal * 2.0 - 1.0) * vec3(normal_intensity, normal_intensity, 1.0));
    grass_normal = normalize((grass_normal * 2.0 - 1.0) * vec3(normal_intensity, normal_intensity, 1.0));

    // Misturar normais com base na máscara
    float mask_value = texture(mask_texture, UV).r;
    vec3 final_normal = mix(rock_normal, grass_normal, mask_value);

    // Misturar cores com base na máscara
    vec3 final_color = mix(rock_color, grass_color, mask_value);

    // Propriedades do material
    ALBEDO = final_color;
    ROUGHNESS = mix(0.7, 0.15, mask_value); // Rugosidade misturada
    SPECULAR = 0.1;
    //NORMAL_MAP = final_normal; // Aplicar o normal misturado
}