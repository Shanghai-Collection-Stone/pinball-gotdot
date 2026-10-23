shader_type spatial;
// Candy / circus-tent stripes. mode 0: around local Y (tent, bumper caps),
// mode 1: horizontal bands along local Y, mode 2: diagonal in object space.

uniform vec4 color_a : source_color = vec4(0.86, 0.09, 0.16, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.93, 0.78, 1.0);
uniform float stripes = 8.0;
uniform int mode = 0;
uniform float emission_energy = 0.0;
uniform float flash = 0.0;
uniform float roughness_value = 0.32;
uniform float metallic_value = 0.0;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	float x;
	if (mode == 0) {
		x = (atan(lpos.x, lpos.z) / 6.2831853 + 0.5) * stripes;
	} else if (mode == 1) {
		x = lpos.y * stripes;
	} else {
		x = (lpos.x + lpos.y + lpos.z) * stripes;
	}
	float tri = abs(fract(x) - 0.5) * 2.0;
	float w = clamp(fwidth(x) * 1.5, 0.002, 0.25);
	float s = smoothstep(0.5 - w, 0.5 + w, tri);
	vec3 c = mix(color_a.rgb, color_b.rgb, s);
	ALBEDO = c;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	EMISSION = c * (emission_energy + flash * 3.0);
}
