shader_type spatial;
// Cheap fake light pool under street lamps: additive radial quad, no real light.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

global uniform float street_lamp;
uniform vec3 glow_color : source_color = vec3(1.0, 0.74, 0.42);
uniform float intensity = 0.55;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = pow(1.0 - clamp(d, 0.0, 1.0), 2.2);
	ALBEDO = glow_color * a * intensity * street_lamp;
}
