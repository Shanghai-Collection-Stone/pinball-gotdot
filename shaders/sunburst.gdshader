shader_type spatial;
render_mode unshaded, cull_disabled;
// Rotating carnival sunburst used behind the backbox title.

uniform vec4 color_a : source_color = vec4(0.86, 0.09, 0.16, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.82, 0.45, 1.0);
uniform float rays = 18.0;
uniform float spin = 0.12;
uniform float energy = 1.0;
uniform float flash = 0.0;

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float a = atan(p.y, p.x) + TIME * spin;
	float x = a / 6.2831853 * rays;
	float tri = abs(fract(x) - 0.5) * 2.0;
	float w = clamp(fwidth(x) * 1.5, 0.002, 0.25);
	float s = smoothstep(0.5 - w, 0.5 + w, tri);
	vec3 c = mix(color_a.rgb, color_b.rgb, s);
	c *= 1.0 - smoothstep(0.55, 1.0, r) * 0.75;
	ALBEDO = c * (energy + flash * 1.5);
	ALPHA = 1.0 - smoothstep(0.96, 1.0, r);
}
