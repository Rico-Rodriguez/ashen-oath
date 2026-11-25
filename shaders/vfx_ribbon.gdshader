shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 ribbon_tint : source_color = vec4(0.85, 0.88, 0.96, 0.85);
uniform vec3 edge_hdr = vec3(3.6, 2.6, 1.5);
uniform vec3 wake_smoke : source_color = vec3(0.025, 0.02, 0.03);
uniform float hdr_intensity = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void fragment() {
	float age = clamp(UV.x, 0.0, 1.0);
	float span = clamp(UV.y, 0.0, 1.0);

	vec2 flow_uv = vec2(age * 7.5 - TIME * 6.0, span * 5.5);
	float n = noise2d(flow_uv) * 0.65 + noise2d(flow_uv * 2.4 + 7.1) * 0.35;
	float streak = smoothstep(0.35, 0.82, noise2d(vec2(age * 3.5 - TIME * 8.0, span * 14.0)));

	float lead_edge = exp(-age * 13.0);
	float cutting_rim = smoothstep(0.80, 0.99, span);
	float inner_fade = smoothstep(0.0, 0.28, span);
	float tail_erode = smoothstep(1.0, 0.22, age + (n - 0.5) * 0.45 * age);

	vec3 mid_steel = ribbon_tint.rgb * (0.42 + 0.52 * streak) * (1.0 - age * 0.65);
	vec3 hot_rim = edge_hdr * (cutting_rim * (1.0 - age * 0.70) + lead_edge * 0.72) * hdr_intensity;
	vec3 blade_col = mid_steel + hot_rim;

	float smoke_mix = smoothstep(0.14, 0.55, age) * (1.0 - cutting_rim * 0.75);
	vec3 col = mix(blade_col, wake_smoke, smoke_mix);

	float alpha = clamp((tail_erode * inner_fade * mix(0.48, 1.0, cutting_rim) + lead_edge * 0.55 * inner_fade) * ribbon_tint.a * COLOR.a, 0.0, 0.95);
	ALBEDO = col * COLOR.rgb;
	ALPHA = alpha;
}
