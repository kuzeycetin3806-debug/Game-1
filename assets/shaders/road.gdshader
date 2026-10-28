shader_type spatial;
// Road tile on an 8x8 m plane. INSTANCE_CUSTOM.x: 0 = runs along X, 1 = along Z, 2 = intersection.

uniform vec3 asphalt : source_color = vec3(0.36, 0.37, 0.42);
uniform vec3 sidewalk : source_color = vec3(0.78, 0.76, 0.73);
uniform vec3 marking : source_color = vec3(0.96, 0.94, 0.86);
uniform vec3 bike_lane : source_color = vec3(0.55, 0.72, 0.62);
uniform float tile_size = 8.0;

varying vec2 v_uv;
varying float v_kind;

void vertex() {
	v_uv = UV;
	v_kind = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec2 p = (v_uv - 0.5) * tile_size; // metres, centered
	vec3 col = asphalt;
	float across = v_kind < 0.5 ? p.y : p.x;
	float along = v_kind < 0.5 ? p.x : p.y;
	if (v_kind < 1.5) {
		float a = abs(across);
		if (a > 3.0) {
			col = sidewalk;
		} else if (a > 2.35) {
			col = bike_lane;
		} else if (a < 0.08 && fract(along / 2.0 + 0.25) < 0.5) {
			col = marking;
		}
	} else {
		// Intersection: sidewalk corners + zebra crossings.
		vec2 a = abs(p);
		if (a.x > 3.0 && a.y > 3.0) {
			col = sidewalk;
		} else if ((a.x > 2.3 && a.x < 3.0 && a.y < 2.3 && fract(p.y * 1.4) < 0.5)
				|| (a.y > 2.3 && a.y < 3.0 && a.x < 2.3 && fract(p.x * 1.4) < 0.5)) {
			col = marking;
		}
	}
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
