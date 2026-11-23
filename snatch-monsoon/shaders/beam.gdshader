shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Fake volumetric headlight cone. The mesh is a cone along -Y of the given height.
uniform vec3 colour : source_color = vec3(1.0, 0.9, 0.7);
uniform float strength = 0.12;
uniform float height = 16.0;
varying float along;
void vertex() { along = clamp(0.5 - VERTEX.y / height, 0.0, 1.0); }
void fragment() {
	float f = abs(dot(NORMAL, VIEW));
	ALBEDO = colour * strength * pow(1.0 - along, 1.6) * f * f * f * f;
}
