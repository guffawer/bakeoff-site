shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
uniform float t = 0.0;
uniform float density = 0.35;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 uv = UV * vec2(3.0, 1.5);
	float n = noise(uv + vec2(t * 0.05, 0.0)) * 0.6 + noise(uv * 2.3 - vec2(t * 0.08, 0.0)) * 0.4;
	vec2 e = abs(UV - 0.5) * 2.0;
	float m = (1.0 - smoothstep(0.4, 1.0, e.x)) * (1.0 - smoothstep(0.2, 1.0, e.y));
	ALBEDO = vec3(0.36, 0.41, 0.45);
	ALPHA = clamp(n * m * density, 0.0, 1.0);
}
