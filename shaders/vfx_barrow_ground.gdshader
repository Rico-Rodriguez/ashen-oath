shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D forest_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 ground_tint : source_color = vec3(0.28, 0.27, 0.25);

varying vec2 v_world_xz;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void vertex() {
	v_world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 w = v_world_xz;
	float n_macro = vnoise(w * 0.12) * 0.65 + vnoise(w * 0.37 + 11.3) * 0.35;
	float n_detail = vnoise(w * 1.15 + 4.7);

	float road_wobble = sin(w.y * 0.09) * 0.65 + (n_macro - 0.5) * 1.2;
	float road_d = abs(w.x - road_wobble);
	float road_mask = 1.0 - smoothstep(2.4, 5.4, road_d + (n_detail - 0.5) * 0.9);

	float c0 = 1.0 - smoothstep(7.2, 10.8, length(w - vec2(0.0, 22.0)) + (n_macro - 0.5) * 1.4);
	float c1 = 1.0 - smoothstep(8.2, 11.8, length(w - vec2(0.0, 2.0)) + (n_macro - 0.5) * 1.4);
	float c2 = 1.0 - smoothstep(8.6, 12.2, length(w - vec2(0.0, -19.0)) + (n_macro - 0.5) * 1.4);
	float shrine_c = 1.0 - smoothstep(3.2, 5.2, length(w - vec2(0.0, -8.5)));
	float boss_c = 1.0 - smoothstep(10.5, 14.5, length(w - vec2(0.0, -45.0)) + (n_macro - 0.5) * 1.2);

	float clearing_mask = max(max(c0, c1), max(c2, max(shrine_c, boss_c)));

	float ring0 = exp(-pow((length(w - vec2(0.0, 22.0)) - 8.6) / 1.1, 2.0));
	float ring1 = exp(-pow((length(w - vec2(0.0, 2.0)) - 9.6) / 1.1, 2.0));
	float ring2 = exp(-pow((length(w - vec2(0.0, -19.0)) - 10.2) / 1.1, 2.0));
	float ring_boss = exp(-pow((length(w - vec2(0.0, -45.0)) - 12.2) / 1.4, 2.0));
	float stone_weight = clamp(road_mask * 0.78 + max(max(ring0, ring1), max(ring2, ring_boss)) * 0.85 + boss_c * 0.52 + shrine_c * 0.85, 0.0, 1.0);
	stone_weight *= smoothstep(0.28, 0.68, n_detail * 0.55 + stone_weight * 0.65);

	float dirt_weight = clamp(max(clearing_mask * 0.88, road_mask * 0.95) - stone_weight * 0.65, 0.0, 1.0);
	float forest_weight = clamp(1.0 - max(stone_weight, dirt_weight), 0.0, 1.0);
	float w_sum = max(stone_weight + dirt_weight + forest_weight, 0.001);
	stone_weight /= w_sum;
	dirt_weight /= w_sum;
	forest_weight /= w_sum;

	vec2 uv_f = w * 0.22;
	vec2 uv_d = w * 0.26;
	vec2 uv_s = w * 0.30;

	vec3 f_col = texture(forest_albedo, uv_f).rgb * vec3(0.38, 0.41, 0.36);
	vec3 d_col = texture(dirt_albedo, uv_d).rgb * vec3(0.44, 0.40, 0.37);
	vec3 s_col = texture(stone_albedo, uv_s).rgb * vec3(0.46, 0.47, 0.52);

	vec3 alb = f_col * forest_weight + d_col * dirt_weight + s_col * stone_weight;
	vec3 tint_norm = clamp(ground_tint * 2.6, vec3(0.55), vec3(1.18));
	alb *= tint_norm * mix(0.80, 1.10, n_macro);

	float flank_dark = smoothstep(10.5, 19.0, abs(w.x));
	alb *= mix(1.0, 0.42, flank_dark);

	vec3 raw_n =
		(texture(forest_normal, uv_f).rgb * 2.0 - 1.0) * forest_weight +
		(texture(dirt_normal, uv_d).rgb * 2.0 - 1.0) * dirt_weight +
		(texture(stone_normal, uv_s).rgb * 2.0 - 1.0) * stone_weight;
	raw_n.xy *= 0.55;
	raw_n.z = max(raw_n.z, 0.45);
	vec3 nrm = normalize(raw_n);

	ALBEDO = alb;
	NORMAL_MAP = nrm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.65;
	ROUGHNESS = mix(0.94, 0.76, stone_weight);
	METALLIC = 0.04 * stone_weight;
}
