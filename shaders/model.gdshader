// The look of every Blender model (truck, parts, creatures, cargo...).
//
// Where each value comes from:
//   colour      palette.png            (one square per colour: repaint it!)
//   roughness,  palette_material.png   (same grid: red = roughness,
//   metal, glow                          green = metalness, blue = glow)
//   occlusion   vertex colour green    (baked in Blender by make_models.py:
//                                        dark in corners and crevices)
//   dust, grime grime.png + the world  (sand settles on upward faces; a
//                                        cloudy noise breaks up clean colours)
//
// This is the "PBR" (physically based rendering) way of describing a
// surface: not just a colour, but how rough and how metallic it is. The
// renderer then works out the shine and reflections for you.
shader_type spatial;

uniform sampler2D palette : source_color, filter_nearest_mipmap;
uniform sampler2D material_palette : hint_default_black, filter_nearest_mipmap;
uniform sampler2D grime : hint_default_white, filter_linear_mipmap, repeat_enable;

group_uniforms Occlusion;
/** How much the baked corner shading darkens. 0 = off. */
uniform float ao_strength : hint_range(0.0, 1.0) = 0.8;
/** Below 1 lightens the shading's mid-tones (softer), above 1 darkens them. */
uniform float ao_curve : hint_range(0.3, 2.0) = 0.7;

group_uniforms Wear;
/** Sand colour that settles on top of things. */
uniform vec4 dust_color : source_color = vec4(0.78, 0.64, 0.45, 1.0);
/** How much dust gathers on upward-facing surfaces. */
uniform float dust_amount : hint_range(0.0, 1.0) = 0.3;
/** Grime: blotchy darkening that makes colours look used, not plastic. */
uniform float grime_amount : hint_range(0.0, 1.0) = 0.25;
/** Metres covered by one repeat of the grime texture. */
uniform float grime_scale_m : hint_range(0.05, 4.0) = 0.6;
uniform float glow_strength : hint_range(0.0, 10.0) = 3.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Grime sampled from three sides and blended by the surface direction
// ("triplanar"), so it works on any model without needing extra UVs.
float triplanar_grime(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(grime, p.zy / grime_scale_m).r * w.x
		+ texture(grime, p.xz / grime_scale_m).r * w.y
		+ texture(grime, p.xy / grime_scale_m).r * w.z;
}

void fragment() {
	vec3 base = texture(palette, UV).rgb;
	vec3 mat = texture(material_palette, UV).rgb;   // roughness, metal, glow
	float ao = mix(1.0, pow(clamp(COLOR.g, 0.0, 1.0), ao_curve), ao_strength);
	float g = triplanar_grime(world_pos, world_normal);
	// Dust: on surfaces facing up, thicker in the grime's blotches and in
	// sheltered spots (sand settles where the wind can't blow it away).
	float up = smoothstep(0.35, 0.95, world_normal.y);
	float dust = clamp(up * dust_amount * (0.4 + g * 1.2) * (1.4 - ao * 0.6), 0.0, 1.0);
	dust *= 1.0 - mat.b;                             // lamps stay clean
	vec3 col = base * mix(1.0, 0.75 + g * 0.5, grime_amount);
	col = mix(col, dust_color.rgb, dust);
	ALBEDO = col * ao;
	ROUGHNESS = mix(clamp(mat.r + (g - 0.5) * 0.15, 0.03, 1.0), 0.95, dust);
	METALLIC = mat.g * (1.0 - dust);
	SPECULAR = 0.5 * ao;
	EMISSION = base * mat.b * glow_strength;
	// Occlusion also dims the reflections in corners (not just the colour).
	AO = ao;
}
