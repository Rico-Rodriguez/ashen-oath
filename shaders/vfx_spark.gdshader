shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 spark_hdr = vec4(5.5, 2.3, 0.45, 1.0);

void fragment() {
	float x_taper = clamp(1.0 - abs(UV.x * 2.0 - 1.0), 0.0, 1.0);
	float y_profile = smoothstep(0.0, 0.18, UV.y) * pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.15);
	float body = pow(x_taper, 1.35) * y_profile * 1.85;
	float hot_spine = pow(x_taper, 3.5) * smoothstep(0.04, 0.25, UV.y) * (1.0 - smoothstep(0.25, 0.85, UV.y));

	vec3 base_c = spark_hdr.rgb * COLOR.rgb;
	vec3 col = mix(base_c, base_c * 1.35 + vec3(2.4, 2.1, 1.6), clamp(hot_spine, 0.0, 1.0));
	float alpha = clamp(body * COLOR.a * spark_hdr.a, 0.0, 1.0);
	ALBEDO = col;
	ALPHA = alpha;
}
