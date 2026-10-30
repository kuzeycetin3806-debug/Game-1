shader_type spatial;
// Cars and tram. INSTANCE_CUSTOM.rgb = paint colour. Vertex colour masks:
// r = cabin glass, g = headlight, b = taillight. Lights glow with the street lamps.

global uniform float street_lamp;

varying vec3 v_paint;

void vertex() {
	v_paint = INSTANCE_CUSTOM.rgb;
}

void fragment() {
	float glass = COLOR.r;
	float head = COLOR.g;
	float tail = COLOR.b;
	vec3 col = mix(v_paint, vec3(0.16, 0.2, 0.27), glass);
	col = mix(col, vec3(1.0, 0.96, 0.85), head);
	col = mix(col, vec3(0.75, 0.12, 0.1), tail);
	ALBEDO = col;
	ROUGHNESS = mix(0.45, 0.12, glass);
	SPECULAR = 0.5;
	EMISSION = vec3(1.0, 0.9, 0.7) * head * street_lamp * 3.0 + vec3(1.0, 0.15, 0.1) * tail * street_lamp * 2.0
		+ vec3(1.0, 0.85, 0.6) * glass * street_lamp * 0.25;
}
