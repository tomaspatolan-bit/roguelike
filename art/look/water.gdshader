shader_type spatial;
// Stylised water (style test 2.0s): flat colour from shallow to deep, white foam along the banks and objects
// (from the depth difference) and slow drifting foam streaks in the direction of the current.
render_mode blend_mix, depth_draw_never, cull_back, specular_disabled, diffuse_lambert_wrap;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform vec4 shallow : source_color = vec4(0.42, 0.72, 0.74, 1.0);
uniform vec4 deep : source_color = vec4(0.20, 0.47, 0.57, 1.0);
uniform vec4 foam : source_color = vec4(0.97, 0.98, 0.96, 1.0);
uniform float depth_range = 1.0;
uniform float foam_width = 0.28;
uniform vec2 flow = vec2(1.0, 0.0);      // current direction (world xz)
uniform float flow_speed = 0.35;
uniform float streaks = 0.35;            // amount of drifting foam streaks

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float scene_depth = -v.z / v.w;
	float surf_depth = -VERTEX.z;
	float diff = max(scene_depth - surf_depth, 0.0);
	vec3 col = mix(shallow.rgb, deep.rgb, smoothstep(0.0, depth_range, diff));
	// foam at the edges: a broken band that wobbles
	float wob = noise(world_pos.xz * 2.2 + TIME * 0.4) * 0.12;
	float edge = 1.0 - smoothstep(foam_width * 0.6 + wob, foam_width + wob, diff);
	// streaks drifting with the current
	vec2 q = world_pos.xz;
	vec2 along = normalize(flow);
	vec2 sp = vec2(dot(q, along) * 0.35 - TIME * flow_speed, dot(q, vec2(-along.y, along.x)) * 2.6);
	float s = smoothstep(0.78, 0.86, noise(sp)) * streaks;
	col = mix(col, foam.rgb, max(step(0.5, edge), s));
	ALBEDO = col;
	ROUGHNESS = 0.6;
	ALPHA = mix(0.88, 1.0, max(edge, s));
}
