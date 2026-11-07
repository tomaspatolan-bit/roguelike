shader_type spatial;
// Knight with a palette texture. Every part has its UV in the centre of a colour cell in row 0.
// role_row shifts the UV by whole rows, so the same model gets the cloth colour of another role.
// Rows: 0 House of the Wolf, 1 tank, 2 archer, 3 priest, 4 cavalier, 5 assassin, 6 brigands, 7 brigand commanders.
// Column 13 is skin (same in every row).

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
