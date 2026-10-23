shader_type canvas_item;
// Main-menu backdrop: a slow sonar sweep over a hidden station floor plan.

uniform vec2 centre = vec2(0.68, 0.52);
uniform vec4 tint : source_color = vec4(0.18, 0.85, 1.0, 1.0);
uniform float aspect = 1.7778;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - centre) * vec2(aspect, 1.0);
	float r = length(p);
	float ang = atan(p.y, p.x);
	float sweep = mod(TIME * 0.7, 6.28318);
	float behind = mod(sweep - ang + 6.28318, 6.28318);
	float trail = exp(-behind * 2.2) * smoothstep(1.1, 0.05, r);

	float rf = fract(r * 6.0);
	float rings = (1.0 - smoothstep(0.0, 0.025, min(rf, 1.0 - rf))) * smoothstep(1.2, 0.0, r);

	// Blocky "rooms": walls are the edges of a coarse random grid.
	vec2 g = UV * vec2(aspect, 1.0) * 14.0;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float solid = step(0.62, hash(cell));
	float edge = solid * (1.0 - step(0.08, min(min(f.x, f.y), min(1.0 - f.x, 1.0 - f.y))));

	float pulse_r = fract(TIME * 0.18) * 1.3;
	float pulse = (1.0 - smoothstep(0.0, 0.012, abs(r - pulse_r))) * (1.0 - pulse_r / 1.3);

	float v = rings * 0.06 + trail * 0.10 + edge * (trail * 0.9 + pulse * 0.0) + pulse * 0.25;
	v += edge * smoothstep(0.04, 0.0, abs(r - pulse_r)) * 0.8;
	COLOR = vec4(tint.rgb * v, 1.0);
}
