// The tiny crew: palette colours, with the overalls (vertex colour red = 1)
// painted in a tint. Used for single figures (uniform tint) and, with
// use_instance_tint, for the 300-strong crowd (a different colour each).
shader_type spatial;

uniform sampler2D palette : source_color, filter_nearest_mipmap;
uniform vec4 tint : source_color = vec4(0.2, 0.5, 0.95, 1.0);
uniform bool crowd = false;
uniform float bob_speed = 6.0;
varying vec3 overall_tint;

void vertex() {
	overall_tint = tint.rgb;
	if (crowd) {
		float id = float(INSTANCE_ID);
		float h = fract(sin(id * 78.233) * 43758.5453);
		// Three muted overall colours (bright confetti looked cheap):
		// workwear blue, ochre, and off-white.
		overall_tint = mix(vec3(0.30, 0.45, 0.62), vec3(0.80, 0.62, 0.30), step(0.55, h));
		overall_tint = mix(overall_tint, vec3(0.78, 0.76, 0.70), step(0.85, h));
		float phase = fract(sin(id * 12.9898) * 43758.5453) * 6.28;
		VERTEX.y += max(0.0, sin(TIME * bob_speed + phase)) * 0.04;   // hopping
	}
}

void fragment() {
	vec3 base = texture(palette, UV).rgb;
	// Vertex green = corner shading baked in Blender (see model.gdshader).
	float ao = mix(1.0, pow(clamp(COLOR.g, 0.0, 1.0), 0.7), 0.75);
	ALBEDO = mix(base, base * overall_tint, step(0.5, COLOR.r)) * ao;
	ROUGHNESS = 0.75;
	AO = ao;
}
