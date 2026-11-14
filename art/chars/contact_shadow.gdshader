shader_type spatial;
// Soft contact shade under a unit (visual prototype, phase 2): grounds the figure where the sun shadow falls
// beside it. A tinted, soft-edged ellipse that darkens the ground (multiply), not a black blob.
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 shade : source_color = vec3(0.50, 0.58, 0.60);   // colour the ground is multiplied by at the centre
uniform float strength : hint_range(0.0, 1.0) = 0.75;
uniform float fade = 1.0;

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float a = (1.0 - smoothstep(0.25, 1.0, r)) * strength * fade;
	ALBEDO = mix(vec3(1.0), shade, a);
}
