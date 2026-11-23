shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Each quad's vertices share a base position in [0,1]^3; UV.x = side (-1..1), UV.y = 0 top .. 1 bottom.
uniform float t = 0.0;
uniform vec3 centre = vec3(0.0);
uniform vec3 box = vec3(36.0, 26.0, 40.0);
uniform float speed = 16.0;
uniform vec3 wind = vec3(2.0, 0.0, 1.0);
uniform vec3 spot_pos[2];
uniform vec3 spot_dir[2];
varying float lit;
varying float edge;
void vertex() {
	vec3 b = VERTEX;
	vec3 p;
	p.y = (fract(b.y - t * speed / box.y) - 0.5) * box.y;
	p.xz = (b.xz - 0.5) * box.xz;
	vec3 vel = normalize(vec3(wind.x, -speed, wind.z));
	vec3 wp = centre + p;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 side = normalize(cross(vel, wp - cam));
	float len = 1.4;
	wp += side * UV.x * 0.07 + vel * UV.y * len;
	lit = 0.0;
	for (int i = 0; i < 2; i++) {
		vec3 d = wp - spot_pos[i];
		float k = dot(normalize(d), spot_dir[i]);
		lit += smoothstep(0.86, 0.97, k) * clamp(1.0 - length(d) / 26.0, 0.0, 1.0);
	}
	edge = 1.0 - abs(UV.x);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
}
void fragment() {
	ALBEDO = mix(vec3(0.42, 0.47, 0.52), vec3(1.0, 0.93, 0.78) * 1.6, clamp(lit, 0.0, 1.0));
	ALPHA = edge * (0.45 + lit * 0.55);
}
