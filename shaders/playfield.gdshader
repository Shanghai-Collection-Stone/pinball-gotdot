shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Procedural carnival playfield art: night-sky base, a big red & cream
// sunburst behind the centre, circus-tent rays at the top, polka dots and
// twinkling stars. Everything is computed from world XZ, so no textures.

uniform vec4 red : source_color = vec4(0.7, 0.05, 0.11, 1.0);
uniform vec4 cream : source_color = vec4(0.93, 0.8, 0.6, 1.0);
uniform vec4 gold : source_color = vec4(1.0, 0.7, 0.18, 1.0);
uniform vec4 navy : source_color = vec4(0.05, 0.035, 0.16, 1.0);
uniform vec4 plum : source_color = vec4(0.2, 0.05, 0.27, 1.0);
uniform vec4 teal : source_color = vec4(0.0, 0.42, 0.48, 1.0);
uniform vec2 burst_center = vec2(0.0, 2.6);
uniform float party = 0.0; // 0..1, pulses during multiball / jackpots

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float band(float x, float a, float b) {
	float w = max(fwidth(x), 0.0005);
	return smoothstep(a - w, a + w, x) * (1.0 - smoothstep(b - w, b + w, x));
}

float stripe(float x) {
	float tri = abs(fract(x) - 0.5) * 2.0;
	float w = clamp(fwidth(x) * 1.5, 0.002, 0.3);
	return smoothstep(0.5 - w, 0.5 + w, tri);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float star(vec2 p, float r) {
	// soft 4-point twinkle star
	vec2 a = abs(p);
	float d = min(a.x * 6.0 + a.y, a.y * 6.0 + a.x);
	return 1.0 - smoothstep(r * 0.6, r, d);
}

void fragment() {
	vec2 p = wpos.xz;
	float gy = clamp((p.y + 11.0) / 21.5, 0.0, 1.0);
	vec3 col = mix(plum.rgb, navy.rgb, smoothstep(0.0, 0.8, gy));

	// polka dots everywhere on the dark base
	vec2 g = p * 1.6;
	vec2 cell = floor(g);
	vec2 off = vec2(mod(cell.y, 2.0) * 0.5, 0.0);
	vec2 q = fract(g + off) - 0.5;
	float dot_d = length(q);
	float dots = 1.0 - smoothstep(0.1, 0.1 + fwidth(dot_d) * 1.5, dot_d);
	col = mix(col, mix(col, gold.rgb, 0.28), dots);

	// twinkling stars
	vec2 sg = p * 0.9;
	vec2 sc = floor(sg);
	float h = hash21(sc);
	if (h > 0.78) {
		vec2 sp = fract(sg) - vec2(hash21(sc + 3.1), hash21(sc + 7.7)) * 0.6 - 0.2;
		float tw = 0.6 + 0.4 * sin(TIME * (1.5 + h * 3.0) + h * 40.0);
		col += vec3(1.0, 0.9, 0.7) * star(sp, 0.16) * tw * 0.9;
	}

	// circus tent rays fanning down from the top of the table
	vec2 tc = p - vec2(0.4, -12.5);
	float ta = atan(tc.x, tc.y);
	float tr = length(tc);
	float tent = stripe(ta / 6.2831853 * 34.0);
	vec3 tent_col = mix(red.rgb * 0.75, cream.rgb * 0.7, tent);
	float tent_mask = (1.0 - smoothstep(5.0, 9.5, tr)) * smoothstep(1.0, 2.0, tr);
	col = mix(col, tent_col, tent_mask * 0.55);

	// big sunburst behind the centre medallion
	vec2 c = p - burst_center;
	float r = length(c);
	float ang = atan(c.x, -c.y);
	float rays = stripe(ang / 6.2831853 * 28.0 + TIME * 0.01 * party);
	vec3 burst = mix(red.rgb, cream.rgb, rays);
	float burst_mask = (1.0 - smoothstep(3.6, 6.6, r)) * smoothstep(2.3, 2.45, r);
	col = mix(col, burst, burst_mask * 0.92);

	// medallion: gold rings and a deep blue centre for the CARNIVAL title
	float ring = band(r, 2.18, 2.42) + band(r, 1.9, 1.98) * 0.8;
	vec3 centre = mix(navy.rgb * 1.4, teal.rgb * 0.6, smoothstep(1.9, 0.0, r) * 0.5);
	col = mix(col, centre, 1.0 - smoothstep(2.17, 2.19 + fwidth(r), r));
	col = mix(col, gold.rgb, clamp(ring, 0.0, 1.0));

	// scalloped gold border around the sunburst
	float sc_wave = 6.55 + 0.12 * sin(ang * 28.0);
	col = mix(col, gold.rgb * 0.85, band(r, sc_wave - 0.06, sc_wave + 0.06) * step(p.y, 8.0));

	// inlane / outlane strips
	float lanes = band(abs(p.x), 3.45, 4.25) * band(p.y, 3.4, 7.2);
	col = mix(col, teal.rgb, lanes * 0.55);
	float outl = band(abs(p.x), 4.33, 5.1) * band(p.y, 3.4, 9.0);
	col = mix(col, red.rgb * 0.7, outl * 0.55);

	// checker band in the shooter lane
	if (p.x > 5.05) {
		float ck = mod(floor(p.y * 2.0) + floor(p.x * 2.0), 2.0);
		col = mix(red.rgb * 0.8, cream.rgb * 0.8, ck);
	}

	// vignette toward the table edges
	float vx = smoothstep(4.0, 5.2, abs(p.x - 0.4));
	col *= 1.0 - vx * 0.35;
	col *= 1.0 + party * 0.25 * (0.5 + 0.5 * sin(TIME * 8.0 + r * 2.0));

	ALBEDO = col;
	ROUGHNESS = 0.28;
	SPECULAR = 0.55;
}
