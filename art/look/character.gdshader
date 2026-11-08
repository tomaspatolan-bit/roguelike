shader_type spatial;
// Character (hero or enemy) on a battlefield with the diorama look (style test 2.0s).
// Same palette and role rows as art/knight/knight_palette.gdshader, but lit like the environment (env.gdshader):
// soft wrapped Lambert divided by PI, so characters sit in the scene at the same brightness as the ground and trees.
// Metal is not physically metallic here (the scene has no reflections, PBR metal would turn black or glare);
// instead smooth cells (low roughness in the ORM texture: steel, gold) get a small highlight.

uniform sampler2D palette_albedo : source_color, filter_nearest, repeat_disable;
uniform sampler2D palette_orm : hint_default_white, filter_nearest, repeat_disable;
uniform float role_row = 0.0;
uniform float palette_rows = 8.0;
uniform vec4 flash : source_color = vec4(0.0);
uniform float wrap : hint_range(0.0, 1.0) = 0.3;
uniform float shine : hint_range(0.0, 2.0) = 0.25;

void fragment() {
	vec2 uv = UV + vec2(0.0, role_row / palette_rows);
	vec3 base = texture(palette_albedo, uv).rgb;
	vec3 orm = texture(palette_orm, uv).rgb;
	ALBEDO = mix(base, flash.rgb, flash.a);
	EMISSION = flash.rgb * flash.a * 0.6;
	AO = orm.r;
	ROUGHNESS = orm.g;
	METALLIC = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float d = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * d / PI;
	float smooth_cell = clamp(1.0 - ROUGHNESS, 0.0, 1.0);
	vec3 h = normalize(LIGHT + VIEW);
	float spec = pow(max(dot(NORMAL, h), 0.0), mix(6.0, 48.0, smooth_cell)) * smooth_cell * smooth_cell;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * spec * shine * step(0.0, ndl) / PI;
}
