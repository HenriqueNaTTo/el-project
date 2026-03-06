shader_type spatial;

// Parâmetros ajustáveis para o vento
uniform float wind_strength = 0.2;
uniform float wind_speed = 1.0;
uniform float wind_frequency = 2.0;
uniform float tree_height = 3.0;
uniform float wind_start = 1.5;

render_mode depth_prepass_alpha, cull_disabled, world_vertex_coords;

// Texturas
uniform sampler2D texture_albedo : source_color, filter_nearest_mipmap_anisotropic;
uniform sampler2D texture_normal : hint_normal, filter_nearest_mipmap_anisotropic; // ← Normal map

// Cores e iluminação
uniform vec4 transmission : source_color;
uniform vec4 albedo_color : source_color;
uniform vec4 backlight : source_color;
uniform sampler2D texture_backlight : hint_default_black, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform float backlight_strength = 0.5;
uniform vec4 backlight_color;

void vertex() {
    float mask = smoothstep(wind_start, tree_height, VERTEX.y);
    float wind_offset = sin(TIME * wind_speed + VERTEX.y * wind_frequency) * wind_strength * mask;
    VERTEX.x += wind_offset;
}

void fragment() {
    vec4 albedo_tex = texture(texture_albedo, UV);
    albedo_tex *= COLOR;

    ALBEDO = albedo_color.rgb * albedo_tex.rgb;
    ALPHA = albedo_tex.a;
    METALLIC = 0.0;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;

    // Normal Map: converte de [0,1] para [-1,1] e transforma para espaço do mundo
    vec3 normal_tex = texture(texture_normal, UV).rgb;
    normal_tex = normalize(normal_tex * 2.0 - 1.0); // Convert to [-1,1]
    NORMAL = normalize(TANGENT * normal_tex.x + BINORMAL * normal_tex.y + NORMAL * normal_tex.z);

    vec3 backlight_tex = texture(texture_albedo, UV).rgb;
    BACKLIGHT = (backlight.rgb + backlight_tex);
}
