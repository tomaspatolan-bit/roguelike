shader_type spatial;
// Character shader of the visual prototype (phase 2): one shader for every map.
// Palette v2 (art/chars/T_Char_Palette_*.png, 32 x 16 cells; the old 16 x 8 palette works too, see palette_rows),
// role_row shifts the UV by rows. Lit like the diorama environment (wrapped Lambert / PI), on top of that each
// material answers the light in its own way, read from the ORM cell (G = roughness, B = metal):
//   metal    darker in shadow, a broad soft highlight and a sky-coloured edge; no reflections (the scene has none)
//   painted  armour and smooth leather: a small highlight
//   cloth    matte, the light wraps around it more
// The vertex colour carries occlusion baked in Blender (char_kit.finish); models without it are white.
// A soft rim against the camera separates the character from the ground.

uniform sampler2D palette_albedo : source_color, filter_nearest, repeat_disable;
uniform sampler2D palette_orm : hint_default_white, filter_nearest, repeat_disable;
uniform float role_row = 0.0;
uniform float palette_rows = 16.0;
uniform vec4 flash : source_color = vec4(0.0);
uniform float ao_strength : hint_range(0.0, 1.0) = 0.85;
uniform float wrap_cloth : hint_range(0.0, 1.0) = 0.45;
uniform float wrap_metal : hint_range(0.0, 1.0) = 0.12;
uniform float metal_dark : hint_range(0.0, 1.0) = 0.18;
uniform float metal_shine : hint_range(0.0, 4.0) = 1.5;
uniform float gloss_shine : hint_range(0.0, 2.0) = 0.45;
uniform vec3 rim_color : source_color = vec3(0.80, 0.90, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.22;
uniform float saturation : hint_range(0.5, 1.5) = 1.0;

varying float v_metal;
varying float v_gloss;

void fragment() {
	vec2 uv = UV + vec2(0.0, role_row / palette_rows);
	vec3 base = texture(palette_albedo, uv).rgb;
	vec3 orm = texture(palette_orm, uv).rgb;
	v_metal = orm.b;
	v_gloss = clamp(1.0 - orm.g, 0.0, 1.0);
	float ao = mix(1.0, pow(COLOR.r, 1.0 / 2.2), ao_strength);   // glTF stores the colour linear; back to what was painted
	float grey = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(vec3(grey), base, saturation);
	base *= mix(1.0, 1.0 - metal_dark, v_metal) * ao;
	ALBEDO = mix(base, flash.rgb, flash.a);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = flash.rgb * flash.a * 0.6 + rim_color * fres * rim_strength * mix(0.6, 1.4, v_metal) * ao;
	ROUGHNESS = orm.g;
	METALLIC = 0.0;
	AO = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wrap = mix(wrap_cloth, wrap_metal, max(v_metal, v_gloss * 0.6));
	float d = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * d / PI;
	vec3 h = normalize(LIGHT + VIEW);
	float nh = max(dot(NORMAL, h), 0.0);
	float spec = pow(nh, mix(10.0, 34.0, v_gloss)) * v_gloss;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * spec * mix(gloss_shine, metal_shine, v_metal) * step(0.0, ndl) / PI;
}
