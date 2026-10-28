shader_type spatial;
// Faceted low-poly foliage with gentle wind sway. Instance color = leaf tint.

uniform float sway_strength = 0.18;
uniform float sway_speed = 1.3;

void vertex() {
	vec3 world_origin = MODEL_MATRIX[3].xyz;
	float phase = world_origin.x * 0.13 + world_origin.z * 0.17;
	float h = max(VERTEX.y, 0.0);
	VERTEX.x += sin(TIME * sway_speed + phase) * sway_strength * h;
	VERTEX.z += cos(TIME * sway_speed * 0.8 + phase) * sway_strength * 0.6 * h;
}

void fragment() {
	// Flat shading from screen-space derivatives gives the faceted look.
	NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
