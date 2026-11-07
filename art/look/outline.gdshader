shader_type spatial;
// Thin dark outline around silhouettes and creases (style test 2.0s): a full-screen quad in front of the camera
// reads depth and normals and draws the line colour where they jump. Same language as the UI's dark outline.
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, blend_mix, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform vec4 line_color : source_color = vec4(0.10, 0.11, 0.13, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.75;
uniform float depth_threshold = 0.035;   // relative depth jump that counts as an edge
uniform float normal_threshold = 0.8;   // normals more different than this (1 - dot) count as a crease
uniform float thickness = 1.0;           // in pixels (at 1080p)
uniform float far_fade = 90.0;           // no lines beyond this distance (sky, fog)

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float lin_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec2 px = thickness / VIEWPORT_SIZE * (VIEWPORT_SIZE.y / 1080.0);
	vec2 uv = SCREEN_UV;
	float dc = lin_depth(uv, INV_PROJECTION_MATRIX);
	vec3 nc = texture(normal_tex, uv).xyz * 2.0 - 1.0;
	float edge = 0.0;
	vec2 offs[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	for (int i = 0; i < 4; i++) {
		vec2 o = uv + offs[i];
		float dn = lin_depth(o, INV_PROJECTION_MATRIX);
		// only the nearer side draws the line, so it stays one pixel thin on the object
		if (dn - dc > depth_threshold * dc) {
			edge = 1.0;
		}
		vec3 nn = texture(normal_tex, o).xyz * 2.0 - 1.0;
		if (abs(dn - dc) < 0.5 && 1.0 - dot(nc, nn) > normal_threshold) {
			edge = max(edge, 0.45);
		}
	}
	float fade = 1.0 - smoothstep(far_fade * 0.6, far_fade, dc);
	ALBEDO = line_color.rgb;
	ALPHA = edge * strength * fade;
}
