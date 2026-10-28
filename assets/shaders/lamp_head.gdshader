shader_type spatial;
// Street lamp pole + head. Vertex color alpha marks the bulb (1) vs pole (0).

global uniform float street_lamp;
uniform vec3 pole_color : source_color = vec3(0.25, 0.27, 0.32);
uniform vec3 bulb_color : source_color = vec3(1.0, 0.82, 0.55);

void fragment() {
	float bulb = COLOR.a;
	ALBEDO = mix(pole_color, vec3(0.9), bulb);
	EMISSION = bulb_color * bulb * street_lamp * 4.0;
	ROUGHNESS = 0.6;
}
