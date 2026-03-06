shader_type spatial;
render_mode depth_prepass_alpha, cull_disabled, world_vertex_coords;

uniform sampler2D texture_albedo : source_color, filter_nearest_mipmap_anisotropic;
uniform vec4 transmission : source_color;
uniform vec4 albedo_color : source_color;
uniform vec4 backlight : source_color;
uniform sampler2D texture_backlight : hint_default_black, filter_nearest_mipmap_anisotropic, repeat_enable;

uniform float sway_speed = 3.0;
uniform float sway_strength = 0.05;
uniform float sway_phase_len = 8.0;

void vertex() {
    float strength = COLOR.r * sway_strength;
    VERTEX.x += sin(VERTEX.x * sway_phase_len * 2.0 + TIME * sway_speed) * strength;
    VERTEX.y += sin(VERTEX.y * sway_phase_len + TIME * sway_speed * 2.0) * strength;
    VERTEX.z += sin(VERTEX.z * sway_phase_len * 2.0 + TIME * sway_speed * 2.0) * strength;
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
