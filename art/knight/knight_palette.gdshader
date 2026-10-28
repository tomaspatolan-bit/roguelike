shader_type spatial;
// Rytíř s paletovou texturou. Každý díl má UV ve středu barevné buňky v řádku 0.
// role_row posune UV o celé řádky, takže stejný model dostane barvu látky jiné role.
// Řádky: 0 rod Vlka, 1 tank, 2 lučištník, 3 kněz, 4 jezdec, 5 praporečník.

uniform sampler2D palette_albedo : source_color, filter_nearest, repeat_disable;
uniform sampler2D palette_orm : hint_default_white, filter_nearest, repeat_disable;
uniform float role_row = 0.0;
uniform float palette_rows = 8.0;
uniform vec4 flash : source_color = vec4(0.0);

void fragment() {
	vec2 uv = UV + vec2(0.0, role_row / palette_rows);
	vec3 base = texture(palette_albedo, uv).rgb;
	vec3 orm = texture(palette_orm, uv).rgb;
	ALBEDO = mix(base, flash.rgb, flash.a);
	EMISSION = flash.rgb * flash.a * 0.6;
	AO = orm.r;
	ROUGHNESS = orm.g;
	METALLIC = orm.b;
}
