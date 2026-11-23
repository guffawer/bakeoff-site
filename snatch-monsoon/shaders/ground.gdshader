shader_type spatial;
render_mode cull_disabled;
// Vertex colour = flat low-poly albedo; alpha = roughness. Low-roughness areas collect puddles.
uniform float t = 0.0;
void fragment() {
	vec3 c = COLOR.rgb;
	float r = COLOR.a;
	vec2 w = UV;
	float p = sin(w.x * 1.9 + sin(w.y * 1.3) * 1.7) * sin(w.y * 2.3 + sin(w.x * 1.1) * 2.1);
	float puddle = smoothstep(0.42, 0.6, p) * (1.0 - smoothstep(0.3, 0.4, r));
	// Rain rings in the puddles.
	vec2 cell = floor(w * 1.6); vec2 f = fract(w * 1.6) - 0.5;
	float ph = fract(t * 0.9 + fract(sin(dot(cell, vec2(12.9, 78.2))) * 43758.5));
	float ring = smoothstep(0.05, 0.0, abs(length(f) - ph * 0.45)) * (1.0 - ph) * puddle;
	ALBEDO = mix(c, c * 0.7, puddle) + ring * 0.05;
	ROUGHNESS = mix(r, 0.015, puddle);
	SPECULAR = 0.65;
}
