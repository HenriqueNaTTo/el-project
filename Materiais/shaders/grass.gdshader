/*
 License type: CC BY

 Copyright (c) 2024 Almo Andrioli (ASAN Studio, @almusx, almoandrioli@gmail.com).

 Permission is granted, free of charge, to anyone who obtains a copy
 of this shader code and associated documentation files (the "Software"), to deal with
 in the Software without restriction, including, without limitation, the rights to use, copy,
 modify, merge, publish, distribute, sublicense and/or sell copies of the
 Software, and allow persons to whom the Software is provided to do so,
 subject to the following conditions:

 The above copyright notice and this permission notice must be included in all
 copies or substantial parts of the Software.

 You must give appropriate credit to the original author, provide a link to the license, and
 indicate if changes were made.

*/


shader_type spatial;

render_mode depth_draw_opaque, depth_prepass_alpha, alpha_to_coverage_and_one, cull_disabled, diffuse_lambert, specular_schlick_ggx;

global uniform float wind_direction_angle: hint_range(1.0, 360.0 , 0.5) = 0.0;
global uniform float wind_force: hint_range(0.0, 1.0, 0.1) = 0.5; // Go to -> Project Settings -> Globals ->

group_uniforms Texture;
uniform sampler2D texture_albedo: source_color;
uniform sampler2D texture_normal: hint_normal;
uniform sampler2D texture_roughness: hint_roughness_r;
uniform sampler2D texture_specular: hint_roughness_gray;
uniform sampler2D texture_transmission : hint_default_black;
group_uniforms;

group_uniforms Shading;
uniform float normal = 1.0;
uniform float roughness = 1.0;
uniform float specular = 0.5;
uniform bool invert_backface = true;
uniform float backlight_multiply: hint_range(0, 1, 0.1) = 0.5;
uniform vec3 color_tint : source_color = vec3(0.0);
uniform float color_factor : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float ao_height: hint_range(0.01, 2.0, 0.01) = 1.5;
uniform float ao_factor: hint_range(-5.0, 5.0, 0.01) = 0.0;
uniform bool show_colors = true;
uniform float red: hint_range(0.0, 1.0, 1.0) = 1.0;
uniform float green: hint_range(0.0, 1.0, 1.0) = 1.0;
uniform float blue: hint_range(0.0, 1.0, 1.0) = 1.0;
group_uniforms;

group_uniforms Grass_Sway;
	uniform float sway_frequency: hint_range(0.0, 1000.0, 0.01) = 0.5;
	uniform float sway_amplitude: hint_range(0.0, 10000000.0, 0.001) = 0.5;
	uniform float bend_amplitude: hint_range(0.0, 10000000.0, 0.001) = 0.5;
	uniform float height_factor: hint_range(0.5, 3.0, 0.1) = 1.5;
group_uniforms;

group_uniforms Grass_Waving;
	uniform float wave_amplitude: hint_range(0.0, 10000000.0, 0.01) = 0.5;
	uniform float wave_frequency: hint_range(0.0, 1000000.0, 0.01) = 0.5;
	uniform float wave_speed: hint_range(0.0, 1000.0, 0.1) = 0.5;
group_uniforms;


varying float v_height_factor;


float logFunction(float x, float a, float b) {
    return a * log(b * x + 1.0);
}

float quadFunction(float a, float b, float c, float x){
	return a * exp(x) + b * x + c;
}


vec3 leafWaving(vec3 vertex, float model_scale,  float wave_factor, float wind_variation, float wind_x, float wind_z){

	float leaf_factor = pow(wave_factor, 0.8);

	float waving_amplitude = (wave_amplitude / 100.0) * quadFunction(0.001, 0.8, 0.02, wind_force) - (wave_amplitude / 3700.0);
	waving_amplitude = clamp(waving_amplitude, wave_amplitude / 500000000.0, wave_amplitude / 200.0);

	float waving_frequency = (wave_frequency) / 100.0;

	float waving_speed = wave_speed + (wave_speed * wind_force);
	waving_speed = clamp(waving_speed, wave_speed / 100.0, wave_speed / 3.0);

	float amplitude = leaf_factor * waving_amplitude;
	vec3 waving = sin(vertex * waving_frequency + ((TIME - wind_variation) * (waving_speed) + (wind_x+wind_z))) * (amplitude);

	vertex.x += waving.x;
	vertex.z += waving.z;
	vertex.y += (waving.x + waving.z) / 1.5;

	return vertex;

}

vec3 trunkSway(vec3 vertex, float model_scale, float height, float wind_x, float wind_z, vec3 world_pos){

	float delay = length(world_pos.x+world_pos.z);

	float trunk_motion = 0.001;
	float trunk_bend = 0.001;
	float frequency = (sway_frequency / wind_force) + wind_force;

	trunk_motion = max((sway_amplitude * 1000.0 *  wind_force) - sway_amplitude*140.0, 0.001);
	trunk_motion = clamp(trunk_motion, sway_amplitude / 10000000.0, sway_amplitude * 500.0);
	trunk_motion = trunk_motion * (height * sin((TIME-delay) * (frequency)));
	trunk_bend = height * bend_amplitude * 1000.0 *  wind_force;


	float sway_x = wind_x * trunk_motion;
	float sway_z = wind_z * trunk_motion;

	float bend_x = wind_x * trunk_bend;
	float bend_z = wind_z * trunk_bend;

	float thetaX = radians(sway_x+bend_x);
	float thetaZ = radians(sway_z+bend_z);

	mat3 rotationX = mat3(
    	vec3(1.0, 0.0, 0.0),
    	vec3(0.0, cos(thetaX), -sin(thetaX)),
    	vec3(0.0, sin(thetaX), cos(thetaX))
	);

	mat3 rotationZ = mat3(
	    vec3(cos(thetaZ), -sin(thetaZ), 0.0),
	    vec3(sin(thetaZ), cos(thetaZ), 0.0),
	    vec3(0.0, 0.0, 1.0)
	);

	mat3 rotationMatrix = rotationZ * rotationX;
	vec3 rotatedVertex = rotationMatrix * vertex.xyz;

	vertex.xyz = rotatedVertex;

	return vertex;
}

void vertex() {


	float height = max(pow(VERTEX.y, height_factor) / 5000.0, 0.0);
	float model_scale = max(length(VERTEX.y), 0.0);
	float branch_color = COLOR.b / 255.0;
	float leaf_color = COLOR.r / 255.0;
	float variation_color = COLOR.g;
	vec3 world_pos = NODE_POSITION_WORLD;

	float max_variation_deg = 45.0;
	float period_seconds = 9.0;
	float max_variation_rad = radians(max_variation_deg);
	float frequency = 2.0 * 3.14159265 / period_seconds;
	float angle_variation = max_variation_rad * sin(TIME * frequency);

	float wind_rad = radians(wind_direction_angle) + angle_variation;
	float wind_x = cos(wind_rad);
	float wind_z = sin(wind_rad);

	vec2 wind_dir = (inverse(MODEL_MATRIX) * vec4(wind_x, 0.0,wind_z,0.0)).xz;
	wind_dir = normalize(wind_dir);

	wind_x = wind_dir.x;
	wind_z = wind_dir.y;

	vec3 grassWaving = leafWaving(VERTEX, model_scale, leaf_color, variation_color, wind_x, wind_z);
	vec3 grassSway = trunkSway(grassWaving, model_scale, height, wind_x, wind_z, world_pos);

	VERTEX = grassSway;


	float shadow_h = ao_height - (wind_force);
	v_height_factor = height / shadow_h;
}


void fragment() {

	vec4 albedo_color = texture(texture_albedo, UV);
    vec4 normal_color = texture(texture_normal, UV);
    vec4 roughness_color = texture(texture_roughness, UV);
	vec4 specular_color = texture(texture_specular, UV);
	vec4 transmission = texture(texture_transmission, UV);
	float darken_factor = 1.0 - v_height_factor;
	darken_factor = 1.0 - mix(ao_factor, darken_factor, 0.7);
	vec3 mixed_color = mix(albedo_color.rgb, color_tint, color_factor);
	vec3 final_color = mixed_color * darken_factor;

	ALPHA = albedo_color.a;

	ALBEDO = final_color.rgb;
	ROUGHNESS = roughness_color.r * roughness;
	SPECULAR = specular_color.r * specular;
	BACKLIGHT = transmission.rgb * backlight_multiply;
	NORMAL_MAP = normalize(normal_color.rgb);
	NORMAL_MAP_DEPTH = normal;

	if (invert_backface)
	NORMAL = FRONT_FACING ? NORMAL: -NORMAL;



}