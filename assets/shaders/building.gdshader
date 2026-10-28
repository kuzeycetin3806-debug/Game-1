shader_type spatial;
// Placeholder low-poly building on a unit box (MultiMesh instance).
// Instance color = facade tint. INSTANCE_CUSTOM: x = random seed, y = window style
// (0 none, 1 residential, 2 office glass), z = roof garden (0/1).
// Windows are procedural so one mesh serves every building size.

global uniform float window_light;

uniform vec3 glass_day : source_color = vec3(0.42, 0.55, 0.66);
uniform vec3 glass_night : source_color = vec3(0.09, 0.11, 0.17);
uniform vec3 lit_warm : source_color = vec3(1.0, 0.78, 0.48);
uniform vec3 lit_cool : source_color = vec3(0.92, 0.9, 0.82);
uniform vec3 roof_garden : source_color = vec3(0.47, 0.66, 0.42);
uniform float floor_height = 3.2;
uniform float window_width = 2.4;
uniform float emission_strength = 1.5;

varying vec3 v_local;
varying vec3 v_normal_local;
varying vec3 v_custom;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	vec3 size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	v_local = (VERTEX + 0.5) * size;
	v_normal_local = NORMAL;
	v_custom = INSTANCE_CUSTOM.xyz;
}

void fragment() {
	vec3 base = COLOR.rgb;
	float style = v_custom.y;
	// Baked-looking AO: darker towards the ground, slightly darker at the top edge.
	float ao = mix(0.68, 1.0, smoothstep(0.0, 4.0, v_local.y));
	vec3 albedo = base * ao;
	vec3 emission = vec3(0.0);
	float rough = 0.85;

	bool side = abs(v_normal_local.y) < 0.5;
	if (style > 2.5) {
		// Under construction: concrete core wrapped in orange safety netting.
		float u = abs(v_normal_local.x) > 0.5 ? v_local.z : v_local.x;
		float stripe = step(0.5, fract((u + v_local.y) * 0.25));
		float floor_line = 1.0 - step(0.12, fract(v_local.y / floor_height));
		vec3 net = mix(vec3(0.95, 0.55, 0.25), vec3(0.98, 0.9, 0.75), stripe);
		albedo = side ? mix(net, vec3(0.45), floor_line) : vec3(0.62, 0.6, 0.57);
		rough = 0.95;
	} else if (!side) {
		// Roof: lighter slab, optional garden with a border.
		albedo = base * 1.08;
		if (v_custom.z > 0.5 && v_normal_local.y > 0.5) {
			albedo = roof_garden * (0.85 + 0.3 * hash12(floor(v_local.xz * 0.7) + v_custom.x * 17.0));
		}
	} else if (style > 0.5) {
		float u = abs(v_normal_local.x) > 0.5 ? v_local.z : v_local.x;
		vec2 cell_size = vec2(window_width, floor_height);
		vec2 g = vec2(u, v_local.y - 1.0) / cell_size;
		vec2 cell = floor(g);
		vec2 f = fract(g);
		vec2 w = fwidth(g) * 1.5;
		float ix = style > 1.5 ? 0.06 : 0.24;
		float iy = style > 1.5 ? 0.12 : 0.28;
		float mask = smoothstep(ix - w.x, ix + w.x, f.x) * (1.0 - smoothstep(1.0 - ix - w.x, 1.0 - ix + w.x, f.x))
			* smoothstep(iy - w.y, iy + w.y, f.y) * (1.0 - smoothstep(0.92 - w.y, 0.92 + w.y, f.y));
		mask *= step(0.0, v_local.y - 1.0);
		// Fade window detail at distance to avoid shimmering.
		mask *= 1.0 - smoothstep(0.35, 0.6, max(w.x, w.y));
		vec2 face_id = cell + vec2(floor(v_normal_local.x * 2.0 + v_normal_local.z * 5.0) * 31.0, v_custom.x * 97.0);
		float r = hash12(face_id);
		// Offices empty out at night: far fewer lit panes than homes.
		float lit = step(r, window_light * (style > 1.5 ? 0.35 : 1.0));
		vec3 glass = mix(glass_day, glass_night, clamp(window_light * 1.6, 0.0, 1.0));
		vec3 light_col = style > 1.5 ? lit_cool : lit_warm;
		light_col *= 0.75 + 0.5 * hash12(face_id + 3.1);
		albedo = mix(albedo, glass, mask);
		emission = light_col * mask * lit * emission_strength;
		rough = mix(rough, 0.25, mask);
	}
	ALBEDO = albedo;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	EMISSION = emission;
}
