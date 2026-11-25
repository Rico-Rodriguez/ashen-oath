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
	float n_macro = vnoise(w * 0.14) * 0.65 + vnoise(w * 0.42 + 11.3) * 0.35;
	float n_detail = vnoise(w * 1.45 + 4.7);

	vec2 flag_size = vec2(1.48, 0.96);
	float row_idx = floor(w.y / flag_size.y);
	vec2 f_uv = vec2((w.x + mod(row_idx, 2.0) * 0.5 * flag_size.x) / flag_size.x, w.y / flag_size.y);
	vec2 tile_id = floor(f_uv);
	vec2 cell = fract(f_uv);
	float th = hash12(tile_id);
	float th2 = hash12(tile_id + vec2(17.3, 9.1));

	float aspect = flag_size.x / flag_size.y;
	float d_left = cell.x * aspect;
	float d_right = (1.0 - cell.x) * aspect;
	float d_bot = cell.y;
	float d_top = 1.0 - cell.y;
	float edge_dist = min(min(d_left, d_right), min(d_bot, d_top));

	float chip = (vnoise(w * 4.6 + th * 13.7) - 0.5) * 0.024;
	float mortar = 1.0 - smoothstep(0.022, 0.056, edge_dist + chip);
	float bevel = smoothstep(0.024, 0.058, edge_dist) * (1.0 - smoothstep(0.058, 0.14, edge_dist));

	float crack_field = abs(vnoise(w * 2.25 + vec2(th * 9.7, th2 * 5.3)) - 0.5);
	float crack_gate = step(0.42, th);
	float crack = (1.0 - smoothstep(0.010, 0.032, crack_field)) * crack_gate * (1.0 - mortar);

	float center_nave = 1.0 - smoothstep(5.8, 11.2, abs(w.x) + (n_detail - 0.5) * 0.9);
	float boss_court = 1.0 - smoothstep(11.5, 16.0, length(w - vec2(0.0, -45.0)) + (n_macro - 0.5) * 1.1);
	float shrine_court = 1.0 - smoothstep(3.6, 6.2, length(w - vec2(0.0, -8.5)));
	float nave_border = exp(-pow((abs(w.x) - 5.6) / 0.42, 2.0)) * step(-31.0, w.y);
	float stone_weight = clamp(max(center_nave, max(boss_court, shrine_court)) * 0.92 + 0.35, 0.0, 1.0);

	float flank_earth = smoothstep(9.5, 16.5, abs(w.x) + (n_macro - 0.5) * 1.6) * (1.0 - boss_court);
	float moss_weight = clamp(flank_earth * 0.65 * (0.45 + 0.55 * n_detail), 0.0, 0.72);
	float flag_mask = clamp(1.0 - moss_weight * 0.75, 0.25, 1.0);

	vec2 uv_s = w * 0.26;
	vec2 uv_f = w * 0.24;
	vec2 uv_d = w * 0.28;

	vec3 s_tex = texture(stone_albedo, uv_s).rgb;
	vec3 f_tex = texture(forest_albedo, uv_f).rgb;
	vec3 d_tex = texture(dirt_albedo, uv_d).rgb;

	vec3 slab_tint = mix(vec3(0.24, 0.25, 0.28), vec3(0.36, 0.37, 0.41), th);
	slab_tint += vec3(0.025, 0.018, 0.010) * (th2 - 0.5);
	vec3 stone_col = s_tex * slab_tint * 1.45;
	stone_col *= mix(1.0, 1.16, bevel * (1.0 - crack));
	stone_col *= mix(1.0, 1.18, nave_border * 0.65);

	vec3 mortar_col = vec3(0.055, 0.058, 0.065) * mix(0.85, 1.15, n_detail);
	stone_col = mix(stone_col, mortar_col, clamp(mortar * 0.90 + crack * 0.72, 0.0, 1.0));

	vec3 outer_col = mix(d_tex * vec3(0.22, 0.21, 0.20), f_tex * vec3(0.18, 0.21, 0.19), n_detail);
	vec3 alb = mix(stone_col, outer_col, moss_weight);

	vec3 tint_norm = clamp(ground_tint * 2.45, vec3(0.58), vec3(1.22));
	alb *= tint_norm * mix(0.82, 1.10, n_macro);

	float flank_dark = smoothstep(11.5, 21.0, abs(w.x));
	alb *= mix(1.0, 0.38, flank_dark);

	vec2 bevel_grad = vec2(0.0);
	float bevel_str = bevel * 0.42 * flag_mask;
	if (d_left < 0.14) bevel_grad.x -= bevel_str;
	if (d_right < 0.14) bevel_grad.x += bevel_str;
	if (d_bot < 0.14) bevel_grad.y -= bevel_str;
	if (d_top < 0.14) bevel_grad.y += bevel_str;

	vec3 s_nrm = texture(stone_normal, uv_s).rgb * 2.0 - 1.0;
	vec3 f_nrm = texture(forest_normal, uv_f).rgb * 2.0 - 1.0;
	vec3 raw_n = mix(s_nrm, f_nrm, moss_weight);
	raw_n.xy = raw_n.xy * 0.52 + bevel_grad;
	raw_n.z = max(raw_n.z, 0.50);
	vec3 nrm = normalize(raw_n);

	float moisture = smoothstep(0.56, 0.78, vnoise(w * 0.22 + vec2(3.7, 8.2))) * (1.0 - mortar) * flag_mask;
	float base_rgh = mix(0.82, 0.96, clamp(mortar + moss_weight * 0.5, 0.0, 1.0));
	float final_rgh = mix(base_rgh, 0.34, moisture * 0.75);
	alb = mix(alb, alb * 0.74, moisture * 0.42);

	ALBEDO = alb;
	NORMAL_MAP = nrm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.72;
	ROUGHNESS = final_rgh;
	METALLIC = 0.06 * stone_weight * (1.0 - mortar);
}
