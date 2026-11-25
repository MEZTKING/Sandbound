// Sand shader. Everything it draws comes from hand-painted PNGs in
// res://textures/ plus the settings in res://materials/sand_material.tres
// (double-click that file in Godot to tweak everything with sliders).
//
// Layers, from big to small:
//   1. Physics ruts (25 cm detail): the terrain mesh itself, plus vertex
//      colours telling the shader where sand is PACKED (red) or PILED (green).
//   2. Track map (1.6 cm detail): tyre treads, beetle feet and crate dents
//      stamped on the GPU by SandTracks (red = pressed, green = pushed up).
//   3. Tiling textures (sub-mm detail): loose and packed sand colour + height.
//   4. Glints: individual grains catching the sun.
//
// Bumps come from GREY height images: the shader measures their slope and
// tilts the lighting. You never paint a normal map by hand.
shader_type spatial;

group_uniforms Textures;
/** Colour of loose, wind-blown sand. */
uniform sampler2D sand_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
/** Height of loose sand (the ripples). White = high, black = low. */
uniform sampler2D sand_height : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
/** Colour of sand pressed down by wheels. */
uniform sampler2D packed_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
/** Height of packed sand. Keep it subtle. */
uniform sampler2D packed_height : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
/** Colour of hardpan: the firm, cracked crust between dunes. */
uniform sampler2D hardpan_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
/** Height of hardpan. Dark lines = cracks. */
uniform sampler2D hardpan_height : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
/** Huge soft blotches. Mid-grey = no change, lighter/darker = lighter/darker sand. */
uniform sampler2D variation : hint_default_white, filter_linear_mipmap, repeat_enable;

group_uniforms Size;
/** Metres covered by one repeat of the textures. */
uniform float tile_size_m : hint_range(0.25, 8.0) = 1.5;
/** Direction the wind blew, which sets which way the ripples run. */
uniform float wind_angle_deg : hint_range(-180.0, 180.0) = 20.0;
/** Metres covered by one repeat of the hardpan textures. */
uniform float hardpan_tile_m : hint_range(0.5, 10.0) = 1.0;
/** Metres covered by one repeat of the variation texture. */
uniform float variation_size_m : hint_range(4.0, 100.0) = 23.0;
uniform float variation_strength : hint_range(0.0, 1.0) = 0.35;

group_uniforms Bumps;
/** How tall the ripples are, white vs black in sand_height. */
uniform float ripple_height_cm : hint_range(0.0, 5.0) = 1.2;
uniform float packed_height_cm : hint_range(0.0, 3.0) = 0.4;
uniform float hardpan_height_cm : hint_range(0.0, 3.0) = 0.6;
/** How much ripples survive on the piled-up ridges beside ruts. */
uniform float ripples_on_ridges : hint_range(0.0, 1.0) = 0.3;
/** Ripples can't form on steep dune faces: sand there is smooth. Slope where they start to fade (0 = flat, 1 = vertical). */
uniform float slip_face_start : hint_range(0.0, 1.0) = 0.12;
uniform float slip_face_end : hint_range(0.0, 1.0) = 0.3;

group_uniforms Tracks;
/** Filled in by the game: the GPU track map. */
uniform sampler2D track_map : hint_default_black, filter_linear, repeat_disable;
/** Filled in by the game: metres covered by the track map. */
uniform float track_map_size_m = 64.0;
/** Filled in by the game: the world x/z at the middle of this tile's track map. */
uniform vec2 track_map_origin = vec2(0.0);
/** How deep a full-strength tyre tread presses. */
uniform float track_depth_cm : hint_range(0.0, 5.0) = 1.5;
/** How high sand is pushed up beside tracks. */
uniform float track_rim_cm : hint_range(0.0, 5.0) = 0.8;
/** How much the coarse physics ruts colour the sand (the track map adds the fine detail). */
uniform float coarse_packing : hint_range(0.0, 1.0) = 0.6;

group_uniforms Glints;
/** Filled in by the game: direction TOWARD the sun. */
uniform vec3 sun_direction = vec3(0.4, 0.75, 0.5);
uniform vec4 glint_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float glint_strength : hint_range(0.0, 20.0) = 6.0;
/** Fraction of grains that can sparkle. */
uniform float glint_density : hint_range(0.0, 1.0) = 0.25;
/** Size of a sparkling grain, in mm. */
uniform float glint_grain_mm : hint_range(1.0, 20.0) = 6.0;

group_uniforms Look;
uniform vec4 tint : source_color = vec4(1.0);
/** How fast loose sand turns into packed sand at the edge of a rut. */
uniform float rut_edge_softness : hint_range(0.05, 1.0) = 0.3;
/** Piled-up sand is loose and fluffy: slightly lighter. */
uniform float ridge_brighten : hint_range(0.0, 0.5) = 0.08;
uniform float sand_roughness : hint_range(0.0, 1.0) = 0.95;
uniform float packed_roughness : hint_range(0.0, 1.0) = 0.8;
uniform float hardpan_roughness : hint_range(0.0, 1.0) = 0.85;
/** How far loose sand drifts over the edges of the hardpan. */
uniform float hardpan_edge_drift : hint_range(0.0, 1.0) = 0.35;

group_uniforms SaltCrust;
/** Thick salt crust (Ring 1): bright and white. Uses the hardpan textures, tinted. */
uniform vec4 salt_thick_tint : source_color = vec4(1.0, 0.99, 0.96, 1.0);
/** Thin crust that cracks easily: greyer and damp-looking. Learn to spot it! */
uniform vec4 salt_thin_tint : source_color = vec4(0.62, 0.64, 0.66, 1.0);
/** How bright the salt is compared to the hardpan texture. */
uniform float salt_brightness : hint_range(0.5, 2.5) = 1.45;
/** Below this crust strength, crust counts as "thin". Matches the physics. */
uniform float salt_thin_below : hint_range(0.0, 1.0) = 0.5;

group_uniforms GlassDesert;
/** Ring 2 fades in between these distances from the world centre (match sand_tile.gd). */
uniform float ring2_start = 86.0;
uniform float ring2_end = 100.0;
/** Ring 2 sand is dark and iron-rich (that's why it's magnetic). */
uniform vec4 black_sand_tint : source_color = vec4(0.46, 0.45, 0.5, 1.0);
/** Glass sheets: sand melted by lightning. */
uniform vec4 glass_tint : source_color = vec4(0.22, 0.4, 0.3, 1.0);
uniform float glass_roughness : hint_range(0.0, 1.0) = 0.16;
/** Shard rubble around the sheets sparkles this much more than sand. */
uniform float rubble_sparkle : hint_range(0.0, 10.0) = 5.0;

group_uniforms Drift;
/** Ring 3 fades in between these distances from the world centre (match sand_tile.gd). */
uniform float ring3_start = 160.0;
uniform float ring3_end = 174.0;
/** Ring 3 sand: pale and strange. */
uniform vec4 drift_tint : source_color = vec4(0.88, 0.8, 1.0, 1.0);
/** Flowing sand rivers: colour, and how fast the ripples move (match FLOW_SPEED). */
uniform vec4 river_tint : source_color = vec4(1.18, 1.22, 1.45, 1.0);
uniform float river_speed = 2.2;
/** Seconds before the scrolling ripples swap (the "flow map" trick). */
uniform float river_cycle_s : hint_range(0.5, 8.0) = 2.0;

group_uniforms Terrain;
/** Filled in by the game: the sand's data, one pixel per grid point (see sand_tile.gd). */
uniform sampler2D height_map : filter_nearest, repeat_disable;
uniform sampler2D original_map : filter_nearest, repeat_disable;
uniform sampler2D surface_map : filter_nearest, repeat_disable;
uniform sampler2D flow_map : filter_nearest, repeat_disable;
uniform vec2 tile_origin = vec2(0.0);
uniform float cell_size = 0.25;
uniform float half_cells = 128.0;
/** Set per mesh by the game: grid spacing in cells (1 near, 4 far). */
instance uniform float lod_step = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec2 flow_vec;
varying vec4 sand_data;   // packed, piled, hardness, crust (what vertex COLOR used to hold)
varying float glass_v;

float h_at(ivec2 g) {
	ivec2 last = textureSize(height_map, 0) - 1;
	return texelFetch(height_map, clamp(g, ivec2(0), last), 0).r;
}

// The grid mesh is flat: lift every point to the sand's height, and work out
// which way the surface faces from the heights around it.
void vertex() {
	vec3 flat_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ivec2 g = ivec2(round((flat_world.xz - tile_origin) / cell_size + half_cells));
	float h = h_at(g);
	VERTEX.y = h * cell_size;
	int s = int(lod_step);
	float hl = h_at(g - ivec2(s, 0));
	float hr = h_at(g + ivec2(s, 0));
	float hd = h_at(g - ivec2(0, s));
	float hu = h_at(g + ivec2(0, s));
	NORMAL = normalize(vec3(hl - hr, 2.0 * float(s), hd - hu));
	// Ruts (pressed below the original height) and ridges (piled above it).
	float disturbed = (texelFetch(original_map, g, 0).r - h) * cell_size;
	vec4 surf = texelFetch(surface_map, g, 0);
	sand_data = vec4(clamp(disturbed * 12.0, 0.0, 1.0), clamp(-disturbed * 8.0, 0.0, 1.0), surf.r, surf.g);
	glass_v = surf.b;
	flow_vec = texelFetch(flow_map, g, 0).rg;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Reads a height image and returns (height 0..1, slope along u, slope along v).
// The slope is measured over one texel up close and over a wider step in the
// distance, so far-away bumps fade out smoothly instead of shimmering.
vec3 height_and_slope(sampler2D tex, vec2 uv, float height_m, float metres_per_uv) {
	vec2 step_uv = max(fwidth(uv), vec2(1.0) / vec2(textureSize(tex, 0)));
	float h  = texture(tex, uv).r;
	float hx = texture(tex, uv + vec2(step_uv.x, 0.0)).r;
	float hz = texture(tex, uv + vec2(0.0, step_uv.y)).r;
	vec2 step_m = step_uv * metres_per_uv;
	return vec3(h, (hx - h) * height_m / step_m.x, (hz - h) * height_m / step_m.y);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// Ripple textures are rotated to follow the wind.
	float a = radians(wind_angle_deg);
	mat2 rot = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
	vec2 uv = rot * world_pos.xz / tile_size_m;

	// --- What has happened to the sand here?
	vec2 track_uv = (world_pos.xz - track_map_origin) / track_map_size_m + 0.5;
	vec2 track_texel = vec2(1.0) / vec2(textureSize(track_map, 0));
	vec4 tr = max(texture(track_map, track_uv), vec4(0.0));   // wind can erase below zero
	// The track map has no mipmaps, so fade its fine detail out in the distance.
	float track_detail = 1.0 - smoothstep(1.5, 4.0, length(fwidth(track_uv)) / track_texel.x);
	float pressed = clamp(tr.r, 0.0, 1.5);
	float rim = clamp(tr.g, 0.0, 1.0);
	// Glass (glass_v, from the terrain): ~0.5 = shard rubble, 1 = solid sheet.
	float sheet = smoothstep(0.7, 0.8, glass_v);
	float rubble = smoothstep(0.25, 0.4, glass_v) * (1.0 - sheet);
	float ring2 = smoothstep(ring2_start, ring2_end, max(abs(world_pos.x), abs(world_pos.z)));
	float ring3 = smoothstep(ring3_start, ring3_end, max(abs(world_pos.x), abs(world_pos.z)));
	// Sand rivers (flow_map = flow direction x strength).
	float river = smoothstep(0.05, 0.45, length(flow_vec));
	vec2 fdir = length(flow_vec) > 0.001 ? normalize(flow_vec) : vec2(1.0, 0.0);
	// The flow-map trick: two copies of the ripples scroll downstream, each
	// restarting every cycle; while one restarts the other is fully visible,
	// so the texture moves forever without stretching.
	float ph0 = fract(TIME / river_cycle_s);
	float ph1 = fract(TIME / river_cycle_s + 0.5);
	float wgt = abs(ph0 * 2.0 - 1.0);   // 1 = show copy 1, 0 = copy 0
	vec2 off0 = fdir * river_speed * river_cycle_s * ph0;
	vec2 off1 = fdir * river_speed * river_cycle_s * ph1 + vec2(0.37, 0.61);
	pressed *= 1.0 - river * 0.8;   // tracks wash away in a river
	rim *= 1.0 - river * 0.8;
	pressed *= 1.0 - sheet;     // glass never dents: no tracks on it
	rim *= 1.0 - sheet;
	float packed = max(sand_data.r * coarse_packing, min(pressed, 1.0) * 1.2);
	float piled = max(sand_data.g, rim);

	vec3 loose_h = height_and_slope(sand_height, uv, ripple_height_cm * 0.01, tile_size_m);
	vec3 packed_h = height_and_slope(packed_height, uv, packed_height_cm * 0.01, tile_size_m);
	vec2 hp_uv = world_pos.xz / hardpan_tile_m;
	vec3 hardpan_h = height_and_slope(hardpan_height, hp_uv, hardpan_height_cm * 0.01, hardpan_tile_m);
	// Cracks fade out with distance: far away, a repeating crack pattern
	// just looks like a texture (it's the first thing that reads "fake").
	float crack_fade = 1.0 - smoothstep(18.0, 30.0, length(CAMERA_POSITION_WORLD - world_pos));
	hardpan_h.yz *= crack_fade;
	// Rotate the ripple slopes back from texture space into world space.
	loose_h.yz = transpose(rot) * loose_h.yz;
	packed_h.yz = transpose(rot) * packed_h.yz;

	// Height-aware blend: ripple troughs turn packed first and crests last, so
	// the edge of a rut follows the ripples instead of being a smooth smear.
	float blend = clamp((packed - 0.15 - (loose_h.x - 0.5) * 0.6) / rut_edge_softness, 0.0, 1.0);
	// Hardpan (vertex blue). Ripple crests of loose sand drift over its edges.
	float hard = smoothstep(0.35, 0.65, sand_data.b + (loose_h.x - 0.5) * hardpan_edge_drift * 2.0);

	// --- Colour.
	vec3 loose_col = texture(sand_color, uv).rgb;
	vec3 packed_col = texture(packed_color, uv).rgb;
	vec3 hardpan_col = mix(textureLod(hardpan_color, hp_uv, 8.0).rgb, texture(hardpan_color, hp_uv).rgb, crack_fade);
	vec3 ground_col = mix(loose_col, hardpan_col, hard);
	// Salt crust (vertex alpha): the hardpan's cracked plates, bleached white.
	// Thin crust (weak, breaks easily) is greyer, so you can read it.
	float crust = sand_data.a;
	float salt = smoothstep(0.02, 0.12, crust);
	float thick = smoothstep(salt_thin_below - 0.1, salt_thin_below + 0.1, crust);
	vec3 salt_col = vec3(dot(hardpan_col, vec3(0.333))) * salt_brightness
			* mix(salt_thin_tint.rgb, salt_thick_tint.rgb, thick);
	ground_col = mix(ground_col, salt_col, salt);
	vec3 col = mix(ground_col, packed_col, blend);
	col *= 1.0 + piled * ridge_brighten;
	// Deep tread grooves sit in their own little shadow.
	col *= 1.0 - clamp(pressed - 0.8, 0.0, 0.7) * 0.25 * track_detail;
	float v = texture(variation, world_pos.xz / variation_size_m).r;
	col *= 1.0 + (v - 0.5) * 2.0 * variation_strength * (1.0 - 0.5 * ring2);   // calmer on dark and lilac sand
	// Ring 2: the same sand textures, darkened to iron-black.
	col = mix(col, vec3(dot(col, vec3(0.333))) * black_sand_tint.rgb * 1.5, ring2);
	// Glass sheets: dark green glass with the hardpan cracks running through.
	float cracks = (1.0 - smoothstep(0.2, 0.4, hardpan_h.x)) * crack_fade;
	// Cracks: dark lines (they also catch light differently: rougher).
	vec3 glass_col = glass_tint.rgb * (1.0 - cracks * 0.75) + vec3(0.08) * (1.0 - cracks);
	col = mix(col, glass_col, sheet);
	col = mix(col, col * 0.75 + glass_tint.rgb * 0.3, rubble);
	// Ring 3: pale lavender dunes; rivers lighter still, and moving.
	col = mix(col, vec3(dot(col, vec3(0.333))) * drift_tint.rgb * 1.35, ring3);
	vec3 river_h0 = height_and_slope(sand_height, rot * (world_pos.xz - off0) / tile_size_m, ripple_height_cm * 0.012, tile_size_m);
	vec3 river_h1 = height_and_slope(sand_height, rot * (world_pos.xz - off1) / tile_size_m, ripple_height_cm * 0.012, tile_size_m);
	vec3 river_h = mix(river_h0, river_h1, wgt);
	river_h.yz = transpose(rot) * river_h.yz;
	// Flowing sand: paler and bluish, with long streaks sliding downstream...
	vec2 across = vec2(-fdir.y, fdir.x);
	vec2 streak_uv = vec2(dot(world_pos.xz, fdir) * 0.3 - TIME * river_speed * 0.3, dot(world_pos.xz, across) * 2.5);
	float streak = texture(sand_height, streak_uv).r;
	col = mix(col, col * river_tint.rgb * (0.8 + river_h.x * 0.3 + streak * 0.2), river * ring3);
	// ...and a pale "foam" line where the flow meets still sand.
	float flow_len = length(flow_vec);
	float foam = smoothstep(0.04, 0.2, flow_len) * (1.0 - smoothstep(0.3, 0.55, flow_len));
	float foam_n = texture(variation, (world_pos.xz - fdir * TIME * 0.8) / 2.5).r;
	col = mix(col, vec3(0.93, 0.92, 1.0), foam * smoothstep(0.35, 0.65, foam_n) * 0.55 * ring3);
	ALBEDO = col * tint.rgb;
	ROUGHNESS = mix(mix(mix(sand_roughness, hardpan_roughness, hard), packed_roughness, blend), glass_roughness + cracks * 0.5, sheet);
	ROUGHNESS = mix(ROUGHNESS, 0.45, rubble);
	ROUGHNESS = mix(ROUGHNESS, 0.7, river * ring3);
	SPECULAR = mix(0.25, 0.6, max(sheet, rubble * 0.6));

	// --- Bumps.
	float slope = 1.0 - world_normal.y;
	float ripple_amount = (1.0 - blend) * (1.0 - hard) * mix(1.0, ripples_on_ridges, piled)
			* (1.0 - smoothstep(slip_face_start, slip_face_end, slope));
	vec2 bump = loose_h.yz * ripple_amount * (1.0 - salt) + packed_h.yz * blend
			+ hardpan_h.yz * max(hard, salt) * (1.0 - blend);
	// Track map bumps: pressed = lower, rim = higher.
	float th  = -tr.r * track_depth_cm + tr.g * track_rim_cm;
	vec4 trx = max(texture(track_map, track_uv + vec2(track_texel.x, 0.0)), vec4(0.0));
	vec4 trz = max(texture(track_map, track_uv + vec2(0.0, track_texel.y)), vec4(0.0));
	float thx = -trx.r * track_depth_cm + trx.g * track_rim_cm;
	float thz = -trz.r * track_depth_cm + trz.g * track_rim_cm;
	float texel_m = track_texel.x * track_map_size_m;
	bump += vec2(thx - th, thz - th) * 0.01 / texel_m * track_detail;
	// Glass is smooth apart from its cracks.
	bump = mix(bump, hardpan_h.yz * 1.5, sheet);
	// River ripples replace the still ones.
	bump = mix(bump, river_h.yz * (1.0 - blend), river * ring3);
	bump += across * (streak - 0.5) * 0.12 * river * ring3;
	vec3 n = normalize(world_normal - vec3(bump.x, 0.0, bump.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	// --- Glints: some grains are tiny mirrors pointing in random directions.
	// When one happens to reflect the sun into the camera, it sparkles.
	vec2 grain_uv = world_pos.xz / (glint_grain_mm * 0.001);
	vec2 cell = floor(grain_uv);
	float h1 = hash(cell);
	vec3 grain_n = normalize(n + vec3(hash(cell + 7.1) - 0.5, 0.0, hash(cell + 3.7) - 0.5) * 1.2);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - world_pos);
	float mirror = max(dot(reflect(-to_cam, grain_n), normalize(sun_direction)), 0.0);
	float glint = step(1.0 - glint_density, h1) * pow(mirror, 600.0);
	// Grains smaller than a pixel would just flicker: fade them out with distance.
	float grain_px = length(fwidth(grain_uv));
	glint *= 1.0 - smoothstep(0.4, 1.0, grain_px);
	glint *= (1.0 - blend) * (1.0 - hard * 0.7 * (1.0 - salt));   // packed sand barely sparkles
	glint *= 1.0 + salt * 2.0;                                   // salt crystals sparkle a lot
	glint *= (1.0 + rubble * rubble_sparkle) * (1.0 - sheet);    // broken glass glitters
	EMISSION = glint_color.rgb * glint * glint_strength;
}
