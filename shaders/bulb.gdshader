shader_type spatial;
// Marquee light bulbs drawn with a MultiMesh. INSTANCE_CUSTOM.r holds the
// bulb index; the pattern is computed on the GPU.
// mode 0 = chase, 1 = alternate blink, 2 = all on, 3 = sparkle, 4 = off

uniform vec4 color_a : source_color = vec4(1.0, 0.78, 0.3, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.25, 0.32, 1.0);
uniform float mode = 0.0;
uniform float speed = 6.0;
uniform float energy = 4.0;
uniform float flash = 0.0;
uniform float group_size = 3.0;

varying float idx;

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	idx = INSTANCE_CUSTOM.r;
}

void fragment() {
	float t = TIME * speed;
	float on;
	if (mode < 0.5) {
		on = step(mod(idx - floor(t), group_size), 0.5);
	} else if (mode < 1.5) {
		on = step(0.5, mod(idx + floor(t * 0.5), 2.0));
	} else if (mode < 2.5) {
		on = 1.0;
	} else if (mode < 3.5) {
		on = step(0.55, hash(idx * 7.0 + floor(t)));
	} else {
		on = 0.0;
	}
	on = max(on, flash);
	vec3 c = mod(idx, 2.0) < 1.0 ? color_a.rgb : color_b.rgb;
	ALBEDO = c * (0.2 + 0.5 * on);
	EMISSION = c * energy * (0.04 + on);
	ROUGHNESS = 0.25;
}
