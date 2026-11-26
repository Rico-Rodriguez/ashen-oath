shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 ground_tint : source_color = vec3(0.28, 0.27, 0.25);

varying vec2 v_world_xz;

void vertex() {
	v_world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 w = v_world_xz;
	vec3 n1 = texture(noise_tex, w * 0.045).rgb;
	vec3 n2 = texture(noise_tex, w * 0.22 + vec2(0.37, 0.71)).rgb;
	float n_macro = n1.r;
	float n_detail = n2.g;

	vec2 flag_size = vec2(1.48, 0.96);
	float row_idx = floor(w.y / flag_size.y);
	vec2 f_uv = vec2((w.x + mod(row_idx, 2.0) * 0.5 * flag_size.x) / flag_size.x, w.y / flag_size.y);
	vec2 tile_id = floor(f_uv);
	vec2 cell = fract(f_uv);
	vec2 tp = fract(tile_id * vec2(0.3183099, 0.3678794)) + vec2(0.17, 0.31);
	float th = fract((tp.x + tp.y) * tp.x * 19.37);
	float th2 = fract((tp.x * 1.7 + tp.y) * tp.y * 23.11);

	float aspect = flag_size.x / flag_size.y;
	float d_left = cell.x * aspect;
	float d_right = (1.0 - cell.x) * aspect;
	float d_bot = cell.y;
	float d_top = 1.0 - cell.y;
	float edge_dist = min(min(d_left, d_right), min(d_bot, d_top));

	float chip = (n2.g - 0.5) * 0.022;
	float mortar = 1.0 - smoothstep(0.018, 0.042, edge_dist + chip);
	float ao_groove = smoothstep(0.022, 0.11, edge_dist + chip);
	float bevel = smoothstep(0.020, 0.052, edge_dist) * (1.0 - smoothstep(0.052, 0.135, edge_dist));

	float crack_field = abs(n2.r - 0.5);
	float crack_gate = step(0.42, th);
	float crack = (1.0 - smoothstep(0.008, 0.028, crack_field)) * crack_gate * (1.0 - mortar);

	float center_nave = 1.0 - smoothstep(5.8, 11.2, abs(w.x) + (n_detail - 0.5) * 0.9);
	float boss_court = 1.0 - smoothstep(11.5, 16.0, length(w - vec2(0.0, -45.0)) + (n_macro - 0.5) * 1.1);
	float shrine_court = 1.0 - smoothstep(3.6, 6.2, length(w - vec2(0.0, -8.5)));
	float nave_border = exp(-pow((abs(w.x) - 5.6) / 0.42, 2.0)) * step(-31.0, w.y);
	float stone_weight = clamp(max(center_nave, max(boss_court, shrine_court)) * 0.92 + 0.35, 0.0, 1.0);

	float flank_earth = smoothstep(9.5, 16.5, abs(w.x) + (n_macro - 0.5) * 1.6) * (1.0 - boss_court);
	float moss_w = clamp(flank_earth * 0.65 * (0.45 + 0.55 * n_detail), 0.0, 0.72);
	float flag_mask = clamp(1.0 - moss_w * 0.75, 0.25, 1.0);

	vec2 uv_s = w * 0.26;
	vec2 uv_f = w * 0.24;
	vec2 uv_d = w * 0.28;

	vec3 s_tex = texture(stone_albedo, uv_s).rgb;

	vec3 slab_tint = mix(vec3(0.14, 0.15, 0.18), vec3(0.27, 0.28, 0.33), th);
	slab_tint += vec3(0.022, 0.016, 0.010) * (th2 - 0.5);
	vec3 stone_col = s_tex * slab_tint * 1.38;
	stone_col *= mix(0.50, 1.04, ao_groove);
	stone_col *= mix(1.0, 1.24, bevel * (1.0 - crack));
	stone_col *= mix(1.0, 1.18, nave_border * 0.55);

	vec3 mortar_col = vec3(0.020, 0.022, 0.028) * mix(0.82, 1.18, n_detail);
	stone_col = mix(stone_col, mortar_col, clamp(mortar * 0.94 + crack * 0.78, 0.0, 1.0));

	vec3 alb = stone_col;
	if (moss_w > 0.02) {
		vec3 f_tex = texture(forest_albedo, uv_f).rgb;
		vec3 d_tex = texture(dirt_albedo, uv_d).rgb;
		vec3 outer_col = mix(d_tex * vec3(0.18, 0.17, 0.16), f_tex * vec3(0.14, 0.17, 0.15), n_detail);
		alb = mix(stone_col, outer_col, moss_w);
	}

	vec3 tint_norm = clamp(ground_tint * 2.35, vec3(0.52), vec3(1.18));
	alb *= tint_norm * mix(0.68, 1.12, n_macro);

	float flank_dark = smoothstep(11.5, 21.0, abs(w.x));
	alb *= mix(1.0, 0.34, flank_dark);

	vec2 bevel_grad = vec2(0.0);
	float bevel_str = bevel * 0.82 * flag_mask;
	if (d_left < 0.14) bevel_grad.x -= bevel_str;
	if (d_right < 0.14) bevel_grad.x += bevel_str;
	if (d_bot < 0.14) bevel_grad.y -= bevel_str;
	if (d_top < 0.14) bevel_grad.y += bevel_str;

	// Reconstruct Z from RG so RGTC/ASTC normal-map compression matches uncompressed maps identically.
	vec2 s_xy = texture(stone_normal, uv_s).rg * 2.0 - 1.0;
	vec3 raw_n = vec3(s_xy, sqrt(max(0.0, 1.0 - dot(s_xy, s_xy))));
	if (moss_w > 0.02) {
		vec2 f_xy = texture(forest_normal, uv_f).rg * 2.0 - 1.0;
		vec3 f_nrm = vec3(f_xy, sqrt(max(0.0, 1.0 - dot(f_xy, f_xy))));
		raw_n = mix(raw_n, f_nrm, moss_w);
	}
	raw_n.xy = raw_n.xy * 0.58 + bevel_grad;
	raw_n.z = max(raw_n.z, 0.45);
	vec3 nrm = normalize(raw_n);

	float wet_noise = n1.b * 0.65 + n1.r * 0.35;
	float moisture = smoothstep(0.42, 0.72, wet_noise) * (1.0 - mortar) * flag_mask;
	float puddle = smoothstep(0.66, 0.82, wet_noise + (th - 0.5) * 0.12) * (1.0 - mortar) * flag_mask;
	nrm = normalize(mix(nrm, vec3(0.0, 0.0, 1.0), puddle * 0.62));

	float base_rgh = mix(0.80, 0.96, clamp(mortar + moss_w * 0.5, 0.0, 1.0));
	float final_rgh = mix(base_rgh, 0.26, moisture * 0.78);
	final_rgh = mix(final_rgh, 0.11, puddle * 0.85);
	alb = mix(alb, alb * 0.66, clamp(moisture * 0.40 + puddle * 0.35, 0.0, 0.72));

	ALBEDO = alb;
	NORMAL_MAP = nrm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.96;
	ROUGHNESS = final_rgh;
	SPECULAR = mix(0.46, 0.78, clamp(moisture * 0.5 + puddle, 0.0, 1.0)) * (1.0 - mortar);
	METALLIC = 0.04 * stone_weight * (1.0 - mortar);
}
