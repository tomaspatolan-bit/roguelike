shader_type spatial;
// Ground of the diorama (visual prototype, phase 2): a calm meadow. The colour comes from the world position, not
// from the triangles: large soft patches of two greens, a few darker ones, a worn path, and sand where the land
// drops to the river (by height, with a slightly wavy edge). Smooth normals, same soft light as env.gdshader.
render_mode specular_disabled, cull_disabled;

uniform vec4 grass_a : source_color = vec4(0.46, 0.64, 0.29, 1.0);
uniform vec4 grass_b : source_color = vec4(0.42, 0.60, 0.27, 1.0);
uniform vec4 grass_dark : source_color = vec4(0.31, 0.48, 0.24, 1.0);
uniform vec4 bank : source_color = vec4(0.85, 0.76, 0.54, 1.0);
uniform vec4 path : source_color = vec4(0.78, 0.68, 0.50, 1.0);
uniform float water_y = -0.32;
uniform float dark_amount : hint_range(0.0, 1.0) = 0.3;
uniform float path_strength : hint_range(0.0, 1.0) = 0.0;
uniform float path_x = 0.0;
uniform float path_width = 1.15;
uniform float wrap : hint_range(0.0, 1.0) = 0.45;

varying vec3 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// Gradient noise (round blobs, no square cells like value noise), two octaves turned against each other.
vec2 grad(vec2 i) {
	float a = hash(i) * 6.2831853;
	return vec2(cos(a), sin(a));
}
float gnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(grad(i), f);
	float b = dot(grad(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(grad(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(grad(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return clamp(0.5 + 0.75 * mix(mix(a, b, u.x), mix(c, d, u.x), u.y), 0.0, 1.0);
}
float soft(vec2 p) {
	const mat2 r1 = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	return gnoise(p) * 0.68 + gnoise(r1 * p * 2.1 + 7.1) * 0.32;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = soft(wp.xz * 0.06 + 3.0);
	vec3 col = mix(grass_a.rgb, grass_b.rgb, smoothstep(0.36, 0.64, n));
	float n2 = soft(wp.xz * 0.11 + 11.0);
	col = mix(col, grass_dark.rgb, smoothstep(0.55, 0.78, n2) * dark_amount);
	// worn path towards the crossing
	float pd = abs(wp.x - (path_x + sin(wp.z * 0.21) * 0.7));
	float pt = (1.0 - smoothstep(path_width * 0.25, path_width, pd + (soft(wp.xz * 0.35 + 5.0) - 0.5) * 0.7)) * path_strength;
	col = mix(col, path.rgb, pt);
	// sand where the land drops to the water, darker when wet
	// (the meadow itself undulates down to about -0.10, so the sand starts below that)
	float hh = wp.y + (soft(wp.xz * 0.5) - 0.5) * 0.05;
	col = mix(col, bank.rgb, 1.0 - smoothstep(-0.185, -0.125, hh));
	col = mix(col, bank.rgb * vec3(0.72, 0.78, 0.80), 1.0 - smoothstep(water_y - 0.28, water_y + 0.05, wp.y));
	ALBEDO = col;
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float d = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * d / PI;
}
