shader_type canvas_item;
// Full-screen finish for the game world (the HUD sits above it, untouched):
// chromatic aberration kicked by pulses, a vignette that throbs red with the
// heartbeat, faint scanlines and film grain.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float aberration = 0.0;
uniform float heartbeat = 0.0;
uniform float danger = 0.0;
uniform float grain = 0.035;
uniform float scanlines = 0.05;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - vec2(0.5);
	vec2 off = dir * aberration * 0.012;
	vec3 col;
	col.r = texture(screen_tex, uv + off).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - off).b;

	float d = length(dir * vec2(1.0, 0.8));
	col *= mix(1.0, smoothstep(0.78, 0.25, d), 0.7);
	col += vec3(0.55, 0.02, 0.06) * heartbeat * danger * smoothstep(0.3, 0.75, d) * 0.6;

	col *= 1.0 - scanlines * (0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159));
	col += (hash(FRAGCOORD.xy + fract(TIME) * 91.7) - 0.5) * grain;
	COLOR = vec4(col, 1.0);
}
