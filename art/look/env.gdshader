shader_type spatial;
// Environment look "medieval diorama" (style test 2.0s): flat-shaded low-poly, soft wrap lighting,
// colour from the material and/or vertex colours, cool shadows come from the ambient light.
render_mode diffuse_lambert_wrap, specular_disabled, cull_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
uniform bool flat_normals = true;     // facets of low-poly shapes even on smooth meshes
uniform float wrap : hint_range(0.0, 1.0) = 0.45;
uniform float ground_darken : hint_range(0.0, 1.0) = 0.0;   // darker towards the ground (fake contact shading)
uniform float ground_height = 1.5;
uniform float sway = 0.0;             // foliage sway amplitude (m at the top)

varying vec3 world_pos;
varying float local_y;

void vertex() {
	local_y = VERTEX.y;
	if (sway > 0.0) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float k = max(VERTEX.y, 0.0);
		VERTEX.x += sin(TIME * 1.3 + wp.x * 0.7 + wp.z * 0.4) * sway * k * 0.25;
		VERTEX.z += cos(TIME * 1.1 + wp.z * 0.6) * sway * k * 0.15;
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = albedo.rgb;
	if (use_vertex_color) {
		c *= pow(COLOR.rgb, vec3(2.2));   // vertex colours are sRGB, ALBEDO is linear (without this the ground was washed out)
	}
	if (ground_darken > 0.0) {
		c *= mix(1.0 - ground_darken, 1.0, clamp(world_pos.y / ground_height, 0.0, 1.0));
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	if (flat_normals) {
		vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		NORMAL = dot(n, VIEW) < 0.0 ? -n : n;   // the derivative cross product came out inverted (faces lit from behind)
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float d = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * d / PI;
}
