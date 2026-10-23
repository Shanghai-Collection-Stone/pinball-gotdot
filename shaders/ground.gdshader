shader_type spatial;
// Midway plaza: red & plum checker tiles with grout, scattered confetti, and a
// warm pool of light around the machine that fades into the night.

uniform vec4 tile_a : source_color = vec4(0.2, 0.035, 0.07, 1.0);
uniform vec4 tile_b : source_color = vec4(0.07, 0.025, 0.09, 1.0);
uniform vec2 centre = vec2(0.4, -2.0);

varying vec3 wpos;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * 0.42;
	float ck = mod(floor(p.x) + floor(p.y), 2.0);
	vec3 c = mix(tile_a.rgb, tile_b.rgb, ck);
	vec2 f = abs(fract(p) - 0.5);
	float w = fwidth(p.x) * 1.5;
	float grout = smoothstep(0.47 - w, 0.5, max(f.x, f.y));
	c = mix(c, vec3(0.9, 0.7, 0.35) * 0.18, grout * 0.6);
	// confetti flecks
	vec2 g = wpos.xz * 3.0;
	vec2 cell = floor(g);
	float h = hash21(cell);
	if (h > 0.93) {
		vec2 q = fract(g) - 0.5;
		float d = max(abs(q.x), abs(q.y) * 1.8);
		vec3 cc = 0.5 + 0.5 * cos(6.2831 * (h * 7.0 + vec3(0.0, 0.33, 0.67)));
		c = mix(c, cc, (1.0 - smoothstep(0.12, 0.16, d)) * 0.8);
	}
	float r = length(wpos.xz - centre);
	c *= 0.25 + 0.75 * (1.0 - smoothstep(12.0, 60.0, r));
	ALBEDO = c;
	ROUGHNESS = 0.45;
	SPECULAR = 0.6;
}
