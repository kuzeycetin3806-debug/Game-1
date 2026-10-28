shader_type sky;
// Soft three-stop gradient. Cheap and only drawn behind the diorama.

uniform vec3 top_color : source_color = vec3(0.55, 0.75, 0.95);
uniform vec3 horizon_color : source_color = vec3(0.9, 0.94, 0.97);
uniform vec3 bottom_color : source_color = vec3(0.78, 0.84, 0.88);

void sky() {
	float y = EYEDIR.y;
	vec3 c = y > 0.0
		? mix(horizon_color, top_color, smoothstep(0.0, 0.6, y))
		: mix(horizon_color, bottom_color, smoothstep(0.0, 0.35, -y));
	COLOR = c;
}
