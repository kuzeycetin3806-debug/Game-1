shader_type spatial;
// Diorama plinth: grass on top, layered soil on the sides.

uniform vec3 grass : source_color = vec3(0.56, 0.71, 0.47);
uniform vec3 soil_top : source_color = vec3(0.55, 0.42, 0.33);
uniform vec3 soil_bottom : source_color = vec3(0.36, 0.27, 0.23);

varying vec3 v_local;
varying vec3 v_n;

void vertex() {
	v_local = VERTEX;
	v_n = NORMAL;
}

void fragment() {
	if (v_n.y > 0.5) {
		ALBEDO = grass;
	} else {
		float t = clamp(-v_local.y / 6.0, 0.0, 1.0);
		float band = step(0.5, fract(v_local.y * 0.6)) * 0.04;
		ALBEDO = mix(soil_top, soil_bottom, t) + band;
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.05;
}
