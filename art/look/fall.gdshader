shader_type spatial;
// Water falling off the edge of the diorama (style test 2.0s): streaks running down, fading into the fog.
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform vec4 water : source_color = vec4(0.55, 0.80, 0.82, 1.0);
uniform vec4 foam : source_color = vec4(0.97, 0.98, 0.96, 1.0);
uniform float speed = 1.6;

float hash(float x) { return fract(sin(x * 91.7) * 43758.5453); }

void fragment() {
	float col = floor(UV.x * 18.0);
	float t = fract(UV.y * 1.5 - TIME * speed * (0.7 + hash(col) * 0.6) + hash(col + 3.0));
	float streak = smoothstep(0.55, 0.6, t) * (1.0 - smoothstep(0.85, 0.95, t));
	vec3 c = mix(water.rgb, foam.rgb, streak * 0.8 + (1.0 - UV.y) * 0.0);
	ALBEDO = c;
	ALPHA = (1.0 - smoothstep(0.35, 1.0, UV.y)) * 0.95;
}
