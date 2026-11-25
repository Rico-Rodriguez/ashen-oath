shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

const int SHAPE_CIRCLE = 0;
const int SHAPE_CONE = 1;
const int SHAPE_LINE = 2;

uniform int shape_kind = 0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float radius_m = 2.5;
uniform float cone_half_angle_rad = 0.5236;
uniform vec2 line_size = vec2(1.4, 6.0);
uniform vec4 base_color : source_color = vec4(0.92, 0.16, 0.12, 0.78);

varying vec2 v_xz;

void vertex() {
	v_xz = VERTEX.xz;
}

void fragment() {
	float p = clamp(progress, 0.0, 1.0);
	float inside = 0.0;
	float border = 0.0;
	float fill_wave = 0.0;
	float wave_edge = 0.0;
	float markings = 0.0;

	if (shape_kind == SHAPE_CIRCLE) {
		float r = length(v_xz);
		float aa = max(fwidth(r), 0.012);
		inside = 1.0 - smoothstep(radius_m - aa, radius_m + aa, r);
		border = (1.0 - smoothstep(0.045 - aa, 0.045 + aa, abs(r - radius_m))) * inside + (1.0 - smoothstep(0.035, 0.075, abs(r - radius_m))) * 0.45;

		float fill_r = max(radius_m * p, 0.02);
		fill_wave = (1.0 - smoothstep(fill_r - aa, fill_r + aa, r)) * inside;
		wave_edge = (1.0 - smoothstep(0.04 - aa, 0.04 + aa, abs(r - fill_r))) * inside;

		float ang = atan(v_xz.y, v_xz.x) + TIME * 0.4;
		float ticks = smoothstep(0.82, 0.95, abs( cos(ang * 8.0) )) * step(radius_m * 0.84, r) * inside;
		float inner_ring = (1.0 - smoothstep(0.02, 0.045, abs(r - radius_m * 0.86))) * inside;
		markings = max(ticks * 0.55, inner_ring * 0.4);
	} else if (shape_kind == SHAPE_CONE) {
		vec2 fwd_p = vec2(v_xz.x, -v_xz.y);
		float r = length(fwd_p);
		float ang = atan(abs(fwd_p.x), max(fwd_p.y, 0.0001));
		float aa_r = max(fwidth(r), 0.015);
		float side_dist = r * sin(max(ang - cone_half_angle_rad, -1.57));

		float in_r = (1.0 - smoothstep(radius_m - aa_r, radius_m + aa_r, r)) * smoothstep(0.04, 0.12, r);
		float in_ang = 1.0 - smoothstep(-0.015, 0.025, side_dist);
		inside = in_r * in_ang * step(0.0, fwd_p.y + 0.05);

		float arc_b = 1.0 - smoothstep(0.045, 0.09, abs(r - radius_m));
		float side_b = 1.0 - smoothstep(0.035, 0.08, abs(r * sin(ang - cone_half_angle_rad)));
		border = clamp(max(arc_b, side_b), 0.0, 1.0) * inside;

		float fill_r = max(radius_m * p, 0.05);
		fill_wave = (1.0 - smoothstep(fill_r - aa_r, fill_r + aa_r, r)) * inside;
		wave_edge = (1.0 - smoothstep(0.045, 0.09, abs(r - fill_r))) * inside;

		float sweep_arcs = smoothstep(0.85, 0.98, sin(r * 5.0 - TIME * 7.0)) * 0.25 * inside;
		markings = sweep_arcs;
	} else {
		float half_w = line_size.x * 0.5;
		float len_m = line_size.y;
		float along = -v_xz.y;
		float across = abs(v_xz.x);
		float aa = 0.02;

		float in_x = 1.0 - smoothstep(half_w - aa, half_w + aa, across);
		float in_z = smoothstep(-aa, aa, along) * (1.0 - smoothstep(len_m - aa, len_m + aa, along));
		inside = in_x * in_z;

		float edge_x = 1.0 - smoothstep(0.04, 0.085, abs(across - half_w));
		float edge_z = max(1.0 - smoothstep(0.04, 0.09, abs(along - len_m)), 1.0 - smoothstep(0.04, 0.09, abs(along)));
		border = max(edge_x, edge_z) * inside;

		float fill_z = len_m * p;
		fill_wave = (1.0 - smoothstep(fill_z - aa * 1.5, fill_z + aa * 1.5, along)) * inside;
		wave_edge = (1.0 - smoothstep(0.05, 0.11, abs(along - fill_z))) * inside;

		float chevron = smoothstep(0.76, 0.94, sin((along - across * 0.65) * 4.5 - TIME * 8.0)) * 0.32 * inside;
		markings = chevron;
	}

	float urgency = 0.85 + 0.15 * sin(TIME * (8.0 + p * 14.0));
	vec3 dark_crimson = base_color.rgb * 0.26;
	vec3 bright_border = mix(base_color.rgb * 2.5, vec3(2.8, 0.42, 0.20), 0.28 + p * 0.32) * urgency;
	vec3 charge_col = mix(base_color.rgb * 0.95, vec3(2.1, 0.26, 0.14), p * 0.55);

	float base_a = inside * 0.24;
	float charge_a = fill_wave * (0.28 + 0.26 * p);
	float mark_a = markings * 0.32;
	float rim_a = clamp(border * 0.95 + wave_edge * 0.85, 0.0, 1.0);

	vec3 col = dark_crimson;
	col = mix(col, charge_col, clamp(fill_wave * 0.85 + markings * 0.4, 0.0, 1.0));
	col = mix(col, bright_border, rim_a);

	float total_a = clamp((base_a + charge_a + mark_a + rim_a * 0.88) * base_color.a, 0.0, 0.94);
	ALBEDO = col;
	ALPHA = total_a;
}
