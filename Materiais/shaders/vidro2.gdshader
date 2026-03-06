shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;

// --- PROPRIEDADES BÁSICAS ---
group_uniforms Base_Properties;
uniform vec4 albedo_color : source_color = vec4(0.8, 0.9, 1.0, 0.15);
// Nova opção de textura para o Albedo (vitrais, adesivos, etc)
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;
// Roughness baixa = vidro polido e reflexivo. Aumente para vidro jateado.
uniform float base_roughness : hint_range(0.0, 1.0) = 0.02;
uniform float metallic : hint_range(0.0, 1.0) = 0.0; // Vidro geralmente não é metálico
uniform float specular : hint_range(0.0, 1.0) = 1.0; // Máximo reflexo especular

// --- NORMAL MAP (Relevo da Superfície) ---
group_uniforms Surface_Detail_NormalMap;
// Use hint_normal para que a Godot saiba tratar essa textura corretamente
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0; // Força do relevo

// --- REFRAÇÃO E DISTORÇÃO ---
group_uniforms Refraction_and_Distortion;
uniform float refraction_strength : hint_range(0.0, 0.2) = 0.08;
uniform float chromatic_aberration : hint_range(0.0, 0.1) = 0.02; 
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// --- IMPERFEIÇÕES (Sujeira/Manchas) ---
group_uniforms Imperfections;
uniform sampler2D smudge_texture : hint_default_black, filter_linear_mipmap;
uniform vec4 dirt_color : source_color = vec4(0.3, 0.25, 0.2, 1.0);
uniform float dirt_strength : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    // 0. LÊ A TEXTURA DE ALBEDO E MISTURA COM A COR BASE
    vec4 tex_albedo = texture(albedo_texture, UV);
    vec3 final_base_color = albedo_color.rgb * tex_albedo.rgb;
    float final_base_alpha = albedo_color.a * tex_albedo.a;

    // 1. APLICAÇÃO DO NORMAL MAP
    // Isso deve vir PRIMEIRO, pois afeta o cálculo da refração e do reflexo
    vec3 normal_map_color = texture(normal_texture, UV).rgb;
    NORMAL_MAP = normal_map_color;
    NORMAL_MAP_DEPTH = normal_strength;
    // NOTA: A Godot atualiza automaticamente a variável 'NORMAL' após essa linha
    // para considerar o relevo do mapa.

    // 2. LÊ A SUJEIRA
    float smudge = texture(smudge_texture, UV).r * dirt_strength;

    // 3. CALCULA REFRAÇÃO (Usando a nova NORMAL com relevo)
    // O offset agora segue as curvas do seu normal map
    vec2 refraction_offset = NORMAL.xy * refraction_strength;

    // 4. ABERRAÇÃO CROMÁTICA
    vec2 uv_r = SCREEN_UV - refraction_offset + vec2(chromatic_aberration, 0.0);
    vec2 uv_g = SCREEN_UV - refraction_offset;
    vec2 uv_b = SCREEN_UV - refraction_offset - vec2(chromatic_aberration, 0.0);

    float r = texture(screen_texture, uv_r).r;
    float g = texture(screen_texture, uv_g).g;
    float b = texture(screen_texture, uv_b).b;
    vec3 refracted_background = vec3(r, g, b);

    // 5. MISTURA CORES E SUJEIRA (agora usando a textura de albedo calculada no passo 0)
    vec3 current_glass_color = mix(final_base_color, dirt_color.rgb, smudge);
    float current_glass_alpha = mix(final_base_alpha, 1.0, smudge);

    // 6. SAÍDA FINAL
    ALBEDO = mix(refracted_background, current_glass_color, current_glass_alpha);
    ALPHA = 1.0;

    // 7. PROPRIEDADES FÍSICAS PARA REFLEXO
    // Onde tem sujeira, o reflexo fica embaçado (roughness alto)
    ROUGHNESS = mix(base_roughness, 1.0, smudge);
    METALLIC = metallic;
    SPECULAR = specular;
    // O Normal Map aplicado no passo 1 fará os reflexos se curvarem realisticamente.
}