shader_type canvas_item;
// Tilt-shift substitute: the Compatibility renderer has no depth of field. Blur grows above and
// below a sharp band, using the mipmapped screen texture (one pass, five taps).
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
uniform float focus = 0.55;
uniform float band = 0.17;
uniform float max_lod = 3.4;
uniform float saturation = 1.12;
uniform float t = 0.0;
uniform float rain = 0.07;
float h1(float n) { return fract(sin(n) * 43758.5453); }
void fragment() {
	float d = abs(SCREEN_UV.y - focus);
	float b = smoothstep(band, band + 0.28, d);
	float lod = b * max_lod;
	vec2 o = SCREEN_PIXEL_SIZE * (0.75 + b * 5.0);
	vec3 c = textureLod(scr, SCREEN_UV, lod).rgb * 0.36;
	c += textureLod(scr, SCREEN_UV + vec2(o.x, o.y), lod).rgb * 0.16;
	c += textureLod(scr, SCREEN_UV + vec2(-o.x, o.y), lod).rgb * 0.16;
	c += textureLod(scr, SCREEN_UV + vec2(o.x, -o.y), lod).rgb * 0.16;
	c += textureLod(scr, SCREEN_UV + vec2(-o.x, -o.y), lod).rgb * 0.16;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	// Screen-space rain: slanted streak columns sliding down, very faint.
	vec2 ru = SCREEN_UV * vec2(90.0, 1.0); ru.x += SCREEN_UV.y * 9.0;
	float col = floor(ru.x);
	float sp = 1.6 + h1(col) * 1.2;
	float y = fract(SCREEN_UV.y * (2.0 + h1(col + 3.1)) - t * sp + h1(col + 7.7));
	float streak = smoothstep(0.0, 0.02, y) * (1.0 - smoothstep(0.02, 0.11, y)) * step(0.55, h1(col + 1.3));
	streak *= 1.0 - smoothstep(0.08, 0.5, abs(fract(ru.x) - 0.5));
	c += vec3(0.55, 0.6, 0.66) * streak * rain;
	vec2 q = SCREEN_UV - 0.5;
	c *= 1.0 - dot(q, q) * 0.55;
	COLOR = vec4(c, 1.0);
}
