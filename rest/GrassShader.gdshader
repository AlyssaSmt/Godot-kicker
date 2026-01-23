shader_type spatial;

uniform vec3 grass_light : source_color = vec3(0.35, 0.8, 0.35);
uniform vec3 grass_dark  : source_color = vec3(0.05, 0.4, 0.05);
uniform float height_scale : hint_range(0.0, 50.0) = 20.0;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.25;

float rand(vec2 co) {
    return fract(sin(dot(co.xy , vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float h = clamp(VERTEX.y / height_scale, 0.0, 1.0);

	float n = rand(UV * 200.0) * noise_strength;

	vec3 col = mix(grass_dark, grass_light, h + n);

	ALBEDO = col;
}
