shader_type canvas_item;
// Frosted glass: blurred backdrop (screen mip), tint, rounded corners, soft rim.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 rect_size = vec2(200.0, 100.0);
uniform float corner_radius = 28.0;
uniform float blur_lod = 3.5;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.28);
uniform vec4 rim : source_color = vec4(1.0, 1.0, 1.0, 0.55);

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * rect_size;
	float d = rounded_box(p, rect_size * 0.5, corner_radius);
	float inside = 1.0 - smoothstep(-1.0, 0.5, d);
	vec3 backdrop = textureLod(screen_tex, SCREEN_UV, blur_lod).rgb;
	vec3 col = mix(backdrop, tint.rgb, tint.a);
	float edge = 1.0 - smoothstep(0.0, 2.0, abs(d + 1.0));
	col = mix(col, rim.rgb, edge * rim.a);
	COLOR = vec4(col, inside);
}
