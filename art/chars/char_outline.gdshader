shader_type spatial;
// Character outline (visual prototype, phase 2): the mesh drawn once more, back faces only, pushed out along the
// normal by a constant number of pixels. The colour is the darkened local palette colour, so a blue cloak gets a
// dark blue line and steel a dark grey one; `tint` (selection) blends over it. Used as next_pass of the character material.
render_mode unshaded, cull_front, shadows_disabled, fog_disabled;

uniform sampler2D palette_albedo : source_color, filter_nearest, repeat_disable;
uniform float role_row = 0.0;
uniform float palette_rows = 16.0;
uniform float width_px : hint_range(0.0, 6.0) = 2.0;     // at 1080p, scales with the viewport height
uniform float darken : hint_range(0.0, 1.0) = 0.32;
uniform vec4 tint : source_color = vec4(0.0);

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 n_view = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 dir = (PROJECTION_MATRIX * vec4(n_view, 0.0)).xy;
	float l = length(dir);
	if (l > 1e-5) {
		dir /= l;
		clip.xy += dir * (width_px * (VIEWPORT_SIZE.y / 1080.0)) / VIEWPORT_SIZE * 2.0 * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec2 uv = UV + vec2(0.0, role_row / palette_rows);
	vec3 base = texture(palette_albedo, uv).rgb;
	ALBEDO = mix(base * darken, tint.rgb, tint.a);
}
