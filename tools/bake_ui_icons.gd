extends SceneTree

const PORTRAIT_DIR := "res://assets/sprites/ui/portraits"
const ITEM_DIR := "res://assets/sprites/ui/items"
const SKILL_DIR := "res://assets/sprites/ui/skills"

const SKILL_ICON_SHADER := """
shader_type canvas_item;

uniform int icon_id = 0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += noise2(p) * a;
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + vec2(7.1, 11.3);
		a *= 0.5;
	}
	return v;
}

float sd_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-5), 0.0, 1.0);
	return length(pa - ba * h);
}

float sd_crescent(vec2 p, float r, float w, float ang_start, float ang_end) {
	float a = atan(p.y, p.x);
	float d_ang = mod(a - ang_start + 6.2831853, 6.2831853);
	float span = mod(ang_end - ang_start + 6.2831853, 6.2831853);
	float t = clamp(d_ang / max(span, 0.001), 0.0, 1.0);
	float arc_clip = max(0.0, max(ang_start - a, a - ang_end));
	if (d_ang <= span) {
		float taper = sin(t * 3.14159265);
		float half_w = w * (0.14 + 0.86 * pow(taper, 0.65));
		return abs(length(p) - r) - half_w;
	}
	vec2 p0 = vec2(cos(ang_start), sin(ang_start)) * r;
	vec2 p1 = vec2(cos(ang_end), sin(ang_end)) * r;
	return min(length(p - p0), length(p - p1));
}

float sd_tri_seg(vec2 p, vec2 a, vec2 b, float r0, float r1) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-5), 0.0, 1.0);
	return length(pa - ba * h) - mix(r0, r1, h);
}

void fragment() {
	vec2 uv = (UV - 0.5) * 2.0;
	float r = length(uv);
	float outer_mask = 1.0 - smoothstep(0.955, 0.985, r);

	vec3 bg = mix(vec3(0.082, 0.092, 0.120), vec3(0.028, 0.032, 0.044), smoothstep(0.0, 0.92, r));
	float grain = noise2(uv * 16.0) * 0.028;
	bg += grain;

	float inner_ring = smoothstep(0.014, 0.0, abs(r - 0.80));
	bg = mix(bg, vec3(0.26, 0.21, 0.14), inner_ring * 0.55);

	vec3 col = bg;

	if (icon_id == 0) {
		float glow_ring = exp(-abs(r - 0.54) * 9.0) * 0.42;
		col += vec3(0.88, 0.36, 0.08) * glow_ring;

		float d1 = sd_crescent(uv, 0.52, 0.115, -0.35, 2.35);
		float d2 = sd_crescent(uv, 0.52, 0.115, 2.79, 5.49);
		float d_blade = min(d1, d2);
		float blade_fill = 1.0 - smoothstep(-0.010, 0.010, d_blade);
		float blade_edge = exp(-max(d_blade, 0.0) * 28.0);
		float radial_mid = abs(r - 0.52);
		float fuller = 1.0 - smoothstep(0.015, 0.055, radial_mid);
		float outer_edge = smoothstep(0.54, 0.63, r) * blade_fill;
		float spec = clamp(0.42 + 0.58 * (uv.x * -0.6 + uv.y * -0.8), 0.15, 1.0);
		vec3 steel = mix(vec3(0.24, 0.28, 0.36), vec3(0.76, 0.82, 0.90), spec);
		steel = mix(steel, vec3(0.14, 0.16, 0.22), fuller * 0.55);
		steel = mix(steel, vec3(0.98, 0.99, 1.0), outer_edge * 0.85);
		col = mix(col, steel, blade_fill);
		col += vec3(1.0, 0.52, 0.12) * blade_edge * 0.62;

		float d_inner = sd_crescent(uv, 0.28, 0.048, 0.5, 2.8);
		float d_inner2 = sd_crescent(uv, 0.28, 0.048, 3.64, 5.94);
		float inner_b = 1.0 - smoothstep(-0.01, 0.01, min(d_inner, d_inner2));
		col = mix(col, vec3(0.70, 0.76, 0.86), inner_b * 0.88);

		float hub = 1.0 - smoothstep(0.105, 0.128, r);
		float hub_rim = smoothstep(0.018, 0.0, abs(r - 0.115));
		col = mix(col, vec3(0.11, 0.12, 0.16), hub);
		col = mix(col, vec3(0.92, 0.72, 0.34), hub_rim);
		col += vec3(1.0, 0.72, 0.28) * (1.0 - smoothstep(0.0, 0.045, r)) * 0.85;

		for (int i = 0; i < 8; i++) {
			float fi = float(i);
			float ang = fi * 0.7854 + 0.32;
			vec2 sp = vec2(cos(ang), sin(ang)) * (0.44 + 0.22 * fract(fi * 0.37));
			float sd = length(uv - sp);
			col += vec3(1.0, 0.72, 0.24) * exp(-sd * 36.0) * 0.95;
		}
	} else if (icon_id == 1) {
		float py = uv.y + 0.05;
		float px = uv.x;
		float turb = fbm(vec2(px * 4.4, py * 3.8 + 1.7));
		float height_t = clamp((0.52 - py) / 1.18, 0.0, 1.0);
		float tip_fade = smoothstep(-0.68, -0.34, py);
		float flame_w = (mix(0.45, 0.015, pow(height_t, 0.82)) + (turb - 0.46) * 0.19 * (0.28 + height_t * 0.65)) * tip_fade;
		float flame_dist = abs(px) - flame_w;
		if (py > 0.46) flame_dist = max(flame_dist, py - 0.46);
		if (py < -0.66) flame_dist = max(flame_dist, -0.66 - py);

		float outer_f = 1.0 - smoothstep(-0.02, 0.035, flame_dist);
		float mid_f = 1.0 - smoothstep(-0.02, 0.03, flame_dist + 0.095);
		float core_f = 1.0 - smoothstep(-0.015, 0.025, flame_dist + 0.20);
		float halo = exp(-max(flame_dist, 0.0) * 6.8) * smoothstep(-0.74, -0.45, py);

		col += vec3(0.95, 0.30, 0.06) * halo * 0.72;
		vec3 soot = vec3(0.035, 0.028, 0.045);
		vec3 rim_ember = vec3(1.0, 0.42, 0.07);
		vec3 core_gold = vec3(1.0, 0.90, 0.52);
		col = mix(col, soot, outer_f * 0.92);
		float rim_band = clamp(outer_f - mid_f * 0.72, 0.0, 1.0);
		col += rim_ember * rim_band * 1.45;
		col = mix(col, mix(rim_ember, vec3(1.0, 0.64, 0.14), height_t * 0.45 + 0.30), mid_f * 0.90);
		col = mix(col, core_gold, core_f * (1.0 - height_t * 0.45));

		for (int i = 0; i < 4; i++) {
			float fi = float(i);
			vec2 ep = vec2((fi - 1.5) * 0.18, -0.48 - 0.06 * sin(fi * 2.1));
			col += vec3(1.0, 0.68, 0.20) * exp(-length(uv - ep) * 28.0);
		}

		float d_bowl = max(abs(uv.y - 0.54) - 0.085, abs(uv.x) - mix(0.44, 0.28, (uv.y - 0.45) * 4.0));
		float bowl_m = 1.0 - smoothstep(-0.01, 0.015, d_bowl);
		col = mix(col, vec3(0.16, 0.17, 0.21), bowl_m);
		col = mix(col, vec3(0.88, 0.68, 0.30), (1.0 - smoothstep(-0.01, 0.01, max(abs(uv.y - 0.46) - 0.022, abs(uv.x) - 0.45))));
	} else if (icon_id == 2) {
		float ring_arc = exp(-abs(r - 0.66) * 16.0) * (0.45 + 0.55 * sin(atan(uv.y, uv.x) * 6.0));
		col += vec3(0.14, 0.64, 1.0) * max(ring_arc, 0.0) * 0.45;

		vec2 p0 = vec2(0.32, -0.64);
		vec2 p1 = vec2(-0.22, -0.06);
		vec2 p2 = vec2(0.12, -0.04);
		vec2 p3 = vec2(-0.34, 0.64);

		float d_bolt = min(
			sd_tri_seg(uv, p0, p1, 0.012, 0.072),
			min(sd_tri_seg(uv, p1, p2, 0.064, 0.058), sd_tri_seg(uv, p2, p3, 0.068, 0.008))
		);
		float b1 = sd_tri_seg(uv, p1, vec2(-0.56, 0.20), 0.026, 0.005);
		float b2 = sd_tri_seg(uv, p2, vec2(0.50, 0.20), 0.028, 0.005);
		float b3 = sd_tri_seg(uv, mix(p0, p1, 0.48), vec2(0.38, -0.22), 0.022, 0.004);
		float d_all = min(d_bolt, min(b1, min(b2, b3)));

		float corona = exp(-max(d_all, 0.0) * 10.0);
		float outer_glow = exp(-max(d_all, 0.0) * 28.0);
		float core = 1.0 - smoothstep(-0.010, 0.010, d_all);
		float spine = 1.0 - smoothstep(-0.028, 0.0, d_bolt);

		col += vec3(0.08, 0.46, 0.98) * corona * 0.92;
		col += vec3(0.28, 0.85, 1.0) * outer_glow * 1.05;
		col = mix(col, vec3(0.45, 0.92, 1.0), core);
		col = mix(col, vec3(0.97, 0.99, 1.0), spine);
	} else if (icon_id == 3) {
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			float yo = (fi - 1.0) * 0.21;
			float d_streak = sd_tri_seg(uv, vec2(-0.62, yo), vec2(-0.18 + fi * 0.04, yo), 0.004, 0.020);
			col += vec3(0.58, 0.82, 1.0) * exp(-max(d_streak, 0.0) * 24.0) * 0.72;
			col += vec3(1.0, 0.68, 0.28) * exp(-max(d_streak, 0.0) * 34.0) * 0.45;
		}

		for (int c = 0; c < 2; c++) {
			float ox = (c == 0) ? -0.14 : 0.22;
			float sc = (c == 0) ? 0.88 : 1.06;
			vec2 q = uv - vec2(ox, 0.0);
			float ax = abs(q.y);
			float x_edge = 0.24 * sc - ax * 1.25;
			float d_chev = max(max(q.x - x_edge, (x_edge - 0.16 * sc) - q.x), ax - 0.34 * sc);
			float fill = 1.0 - smoothstep(-0.010, 0.010, d_chev);
			float rim = exp(-max(d_chev, 0.0) * 28.0);
			vec3 facet = (q.y < 0.0) ? vec3(0.84, 0.89, 0.96) : vec3(0.36, 0.40, 0.48);
			if (c == 1) {
				float ridge = 1.0 - smoothstep(0.0, 0.045, abs(q.x - (x_edge - 0.08 * sc)));
				facet = mix(facet, vec3(0.96, 0.76, 0.34), ridge * 0.72);
			}
			col += vec3(0.95, 0.68, 0.26) * rim * 0.65;
			col = mix(col, facet, fill);
		}
	} else if (icon_id == 4) {
		vec2 orig = vec2(-0.26, 0.0);
		vec2 dp = uv - orig;
		float dr = length(dp);
		float flash_glow = exp(-dr * 3.8) * 0.95;
		float star_x = exp(-abs(dp.y) * 26.0) * exp(-abs(dp.x) * 3.2);
		float star_y = exp(-abs(dp.x) * 26.0) * exp(-abs(dp.y) * 3.2);
		float diag1 = exp(-abs(dp.x + dp.y) * 24.0) * exp(-dr * 4.5);
		float diag2 = exp(-abs(dp.x - dp.y) * 24.0) * exp(-dr * 4.5);
		float ring_rift = exp(-abs(dr - 0.34) * 22.0) * smoothstep(0.15, -0.35, dp.x);
		col += vec3(0.08, 0.44, 0.98) * (flash_glow * 0.85 + ring_rift * 0.65);
		col += vec3(0.45, 0.88, 1.0) * (star_x + star_y) * 0.85;
		col += vec3(0.65, 0.94, 1.0) * (diag1 + diag2) * 0.55;
		col += vec3(0.95, 0.99, 1.0) * exp(-dr * 14.0) * 0.95;

		for (int i = 0; i < 6; i++) {
			float fi = float(i);
			float yo = (fi - 2.5) * 0.17;
			float xo = -0.58 + fract(fi * 0.37) * 0.24;
			float d_cinder = sd_tri_seg(uv, vec2(xo, yo), vec2(xo + 0.24, yo * 0.82), 0.004, 0.018);
			col += vec3(0.28, 0.78, 1.0) * exp(-max(d_cinder, 0.0) * 28.0) * 0.78;
			col += vec3(0.85, 0.97, 1.0) * exp(-length(uv - vec2(xo + 0.04, yo)) * 34.0) * 0.65;
		}

		for (int c = 0; c < 2; c++) {
			float ox = (c == 0) ? -0.06 : 0.28;
			float sc = (c == 0) ? 0.84 : 1.04;
			vec2 q = uv - vec2(ox, 0.0);
			float ax = abs(q.y);
			float x_edge = 0.24 * sc - ax * 1.22;
			float d_chev = max(max(q.x - x_edge, (x_edge - 0.14 * sc) - q.x), ax - 0.35 * sc);
			float fill = 1.0 - smoothstep(-0.010, 0.010, d_chev);
			float rim = exp(-max(d_chev, 0.0) * 24.0);
			if (c == 0) {
				col += vec3(0.18, 0.68, 1.0) * rim * 0.85;
				col = mix(col, vec3(0.26, 0.72, 0.98), fill * 0.52);
			} else {
				vec3 facet = (q.y < 0.0) ? vec3(0.76, 0.95, 1.0) : vec3(0.22, 0.56, 0.92);
				float ridge = 1.0 - smoothstep(0.0, 0.040, abs(q.x - (x_edge - 0.07 * sc)));
				facet = mix(facet, vec3(0.96, 0.99, 1.0), ridge * 0.82);
				col += vec3(0.25, 0.80, 1.0) * rim * 0.92;
				col = mix(col, facet, fill);
			}
		}
	} else if (icon_id == 5) {
		vec2 ap = uv - vec2(-0.04, 0.02);
		float d_arc = sd_crescent(ap, 0.50, 0.145, -1.85, 1.75);
		float arc_aura = exp(-max(d_arc, 0.0) * 11.0);
		float arc_rim = exp(-max(d_arc, 0.0) * 30.0);
		float arc_fill = 1.0 - smoothstep(-0.010, 0.010, d_arc);
		col += vec3(0.86, 0.10, 0.14) * arc_aura * 0.78;

		float ar = length(ap);
		float fuller = 1.0 - smoothstep(0.016, 0.062, abs(ar - 0.48));
		float outer_edge = smoothstep(0.54, 0.63, ar) * arc_fill;
		float inner_crim = smoothstep(0.42, 0.36, ar) * arc_fill;
		float spec = clamp(0.45 + 0.55 * (-ap.x * 0.55 - ap.y * 0.75), 0.16, 1.0);
		vec3 steel = mix(vec3(0.22, 0.24, 0.30), vec3(0.78, 0.82, 0.88), spec);
		steel = mix(steel, vec3(0.12, 0.13, 0.18), fuller * 0.58);
		steel = mix(steel, vec3(0.96, 0.18, 0.22), inner_crim * 0.68);
		steel = mix(steel, vec3(1.0, 0.94, 0.94), outer_edge * 0.90);
		col = mix(col, steel, arc_fill);
		col += vec3(1.0, 0.16, 0.20) * arc_rim * 0.88;

		float d_shaft = sd_tri_seg(uv, vec2(-0.56, 0.54), vec2(0.22, -0.24), 0.030, 0.024);
		float d_spike = sd_tri_seg(uv, vec2(0.18, -0.20), vec2(0.38, -0.40), 0.032, 0.004);
		float d_beak = sd_tri_seg(uv, vec2(0.06, -0.08), vec2(-0.14, -0.28), 0.034, 0.006);
		float shaft_m = 1.0 - smoothstep(-0.008, 0.010, d_shaft);
		float head_m = 1.0 - smoothstep(-0.008, 0.010, min(d_spike, d_beak));
		col = mix(col, vec3(0.18, 0.14, 0.12), shaft_m);
		col = mix(col, vec3(0.76, 0.79, 0.86), head_m);
		float d_collar = sd_seg(uv, vec2(0.02, -0.04), vec2(0.10, -0.12)) - 0.038;
		col = mix(col, vec3(0.84, 0.64, 0.28), 1.0 - smoothstep(-0.008, 0.008, d_collar));

		for (int i = 0; i < 6; i++) {
			float fi = float(i);
			float ang = -1.45 + fi * 0.56;
			vec2 sp = vec2(-0.04, 0.02) + vec2(cos(ang), sin(ang)) * (0.64 + 0.08 * fract(fi * 0.43));
			col += vec3(1.0, 0.22, 0.24) * exp(-length(uv - sp) * 32.0) * 0.95;
		}
	} else if (icon_id == 6) {
		vec2 origin = vec2(-0.48, 0.46);
		col += vec3(0.78, 0.08, 0.14) * exp(-length(uv - origin) * 3.8) * 0.72;

		for (int i = 0; i < 5; i++) {
			float fi = float(i) - 2.0;
			float ang = -0.7854 + fi * 0.245;
			vec2 dir = vec2(cos(ang), sin(ang));
			float len = 1.06 - abs(fi) * 0.08;
			vec2 p_tail = origin + dir * 0.14;
			vec2 p_neck = origin + dir * (len - 0.28);
			vec2 p_tip = origin + dir * len;

			float d_shaft = sd_tri_seg(uv, p_tail, p_neck, 0.005, 0.015);
			float d_blade_a = sd_tri_seg(uv, p_neck, p_neck + dir * 0.07, 0.014, 0.042);
			float d_blade_b = sd_tri_seg(uv, p_neck + dir * 0.07, p_tip, 0.042, 0.003);
			float d_lance = min(d_shaft, min(d_blade_a, d_blade_b));

			float corona = exp(-max(d_lance, 0.0) * 14.0);
			float glow = exp(-max(d_lance, 0.0) * 32.0);
			float fill = 1.0 - smoothstep(-0.008, 0.008, d_lance);
			float spine = 1.0 - smoothstep(-0.016, 0.004, sd_tri_seg(uv, p_tail + dir * 0.08, p_tip, 0.003, 0.010));
			float boost = 1.0 - abs(fi) * 0.08;

			col += vec3(0.86, 0.08, 0.16) * corona * 0.56 * boost;
			col += vec3(1.0, 0.30, 0.36) * glow * 0.65 * boost;
			col = mix(col, vec3(0.95, 0.42, 0.48), fill * 0.92);
			col = mix(col, vec3(1.0, 0.94, 0.95), spine * 0.94);
		}
		col += vec3(1.0, 0.50, 0.52) * exp(-length(uv - origin) * 12.0) * 0.70;
	} else {
		float smoke_n = fbm(vec2(uv.x * 4.0 + 2.3, uv.y * 5.2 + 0.9));
		float wake_band = smoothstep(0.45, -0.58, uv.x) * exp(-abs(uv.y + (smoke_n - 0.5) * 0.32) * 3.4);
		float wake_edge = wake_band * smoothstep(0.32, 0.68, smoke_n);
		col = mix(col, vec3(0.04, 0.025, 0.045), wake_edge * 0.72);
		col += vec3(0.82, 0.10, 0.16) * wake_edge * 0.78;

		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			float yo = (fi - 1.0) * 0.22;
			float d_wisp = sd_tri_seg(uv, vec2(-0.68, yo * 1.15), vec2(-0.08 + fi * 0.03, yo * 0.72), 0.006, 0.026);
			col += vec3(0.86, 0.10, 0.18) * exp(-max(d_wisp, 0.0) * 20.0) * 0.85;
			col += vec3(1.0, 0.52, 0.48) * exp(-max(d_wisp, 0.0) * 36.0) * 0.42;
		}

		for (int c = 0; c < 2; c++) {
			float ox = (c == 0) ? -0.18 : 0.22;
			float sc = (c == 0) ? 0.88 : 1.08;
			vec2 q = uv - vec2(ox, 0.0);
			float ax = abs(q.y);
			float x_edge = 0.28 * sc - ax * 1.12;
			float d_chev = max(max(q.x - x_edge, (x_edge - 0.16 * sc) - q.x), ax - 0.38 * sc);
			float fill = 1.0 - smoothstep(-0.010, 0.010, d_chev);
			float rim = exp(-max(d_chev, 0.0) * 24.0);
			if (c == 0) {
				col += vec3(0.84, 0.10, 0.18) * rim * 0.82;
				col = mix(col, vec3(0.11, 0.05, 0.08), fill * 0.85);
			} else {
				vec3 facet = (q.y < 0.0) ? vec3(0.28, 0.16, 0.22) : vec3(0.10, 0.08, 0.12);
				float ridge = 1.0 - smoothstep(0.0, 0.042, abs(q.x - (x_edge - 0.06 * sc)));
				facet = mix(facet, vec3(1.0, 0.26, 0.28), ridge * 0.92);
				col += vec3(1.0, 0.16, 0.22) * rim * 0.95;
				col = mix(col, facet, fill);
			}
		}

		for (int i = 0; i < 5; i++) {
			float fi = float(i);
			vec2 ep = vec2(-0.56 + fi * 0.14, sin(fi * 2.4) * 0.34);
			col += vec3(1.0, 0.34, 0.26) * exp(-length(uv - ep) * 32.0) * 0.85;
		}
	}

	float gold_ring = smoothstep(0.875, 0.895, r) * (1.0 - smoothstep(0.955, 0.975, r));
	float bevel_hl = clamp(0.55 + 0.45 * (-uv.x * 0.7 - uv.y * 0.7), 0.2, 1.0);
	float ring_arch = sin(clamp((r - 0.88) / 0.085, 0.0, 1.0) * 3.14159265);
	vec3 gold_col = mix(vec3(0.40, 0.29, 0.13), vec3(0.96, 0.80, 0.44), bevel_hl * (0.45 + 0.55 * ring_arch));
	col = mix(col, gold_col, gold_ring);

	float dark_in_rim = smoothstep(0.855, 0.875, r) * (1.0 - smoothstep(0.875, 0.892, r));
	col = mix(col, vec3(0.03, 0.03, 0.04), dark_in_rim * 0.85);

	COLOR = vec4(col, outer_mask);
}
"""

var _preview_sheet_path: String = ""

const HERO_SPECS := [
	{
		"id": "oathbreaker",
		"scene": "res://scenes/actors/heroes/oathbreaker.tscn",
		"tier": 3,
		"wpn": "zweihander",
		"off": "",
		"plume": true,
		"lantern": Color(1.0, 0.68, 0.22),
		"cam_pos": Vector3(-0.62, 1.62, -2.26),
		"look_at": Vector3(0.0, 1.48, 0.0),
		"dist_mult": 1.00,
		"look_y": 0.77,
		"fov": 29.0,
		"rim_col": Color(1.0, 0.56, 0.20),
	},
	{
		"id": "battlemage",
		"scene": "res://scenes/actors/heroes/battlemage.tscn",
		"tier": 1,
		"wpn": "runed_staff",
		"off": "",
		"plume": false,
		"lantern": Color(0.26, 0.68, 1.0),
		"cam_pos": Vector3(-0.52, 1.50, -2.28),
		"look_at": Vector3(0.0, 1.40, 0.0),
		"dist_mult": 1.06,
		"look_y": 0.72,
		"fov": 29.0,
		"rim_col": Color(0.35, 0.75, 1.0),
	},
	{
		"id": "revenant",
		"scene": "res://scenes/actors/heroes/revenant.tscn",
		"tier": 1,
		"wpn": "halberd",
		"off": "",
		"plume": false,
		"lantern": Color(0.95, 0.22, 0.24),
		"cam_pos": Vector3(-0.58, 1.52, -2.54),
		"look_at": Vector3(0.0, 1.40, 0.0),
		"dist_mult": 1.18,
		"look_y": 0.72,
		"fov": 30.0,
		"rim_col": Color(0.95, 0.28, 0.32),
	},
]

const ENEMY_SPECS := [
	{
		"id": "hollow_ghoul",
		"scene": "res://scenes/actors/enemies/hollow_ghoul.tscn",
		"cam_rel": Vector3(-0.32, 0.72, -0.96),
		"look_y": 0.78,
		"dist_mult": 1.06,
		"fov": 30.0,
		"rim_col": Color(1.0, 0.45, 0.16),
	},
	{
		"id": "crypt_batlord",
		"scene": "res://scenes/actors/enemies/crypt_batlord.tscn",
		"cam_rel": Vector3(-0.34, 0.76, -0.98),
		"look_y": 0.78,
		"dist_mult": 1.03,
		"fov": 31.0,
		"rim_col": Color(1.0, 0.36, 0.12),
	},
	{
		"id": "ash_scorpion",
		"scene": "res://scenes/actors/enemies/ash_scorpion.tscn",
		"cam_rel": Vector3(-0.46, 0.96, -1.04),
		"look_y": 0.44,
		"dist_mult": 1.58,
		"fov": 32.0,
		"rim_col": Color(1.0, 0.45, 0.14),
	},
	{
		"id": "stone_gargoyle",
		"scene": "res://scenes/actors/enemies/stone_gargoyle.tscn",
		"cam_rel": Vector3(-0.36, 0.74, -0.96),
		"look_y": 0.68,
		"dist_mult": 1.08,
		"fov": 31.0,
		"rim_col": Color(1.0, 0.52, 0.18),
	},
	{
		"id": "dread_golem",
		"scene": "res://scenes/actors/enemies/dread_golem.tscn",
		"cam_rel": Vector3(-0.36, 0.74, -0.96),
		"look_y": 0.70,
		"dist_mult": 1.14,
		"fov": 30.0,
		"rim_col": Color(1.0, 0.52, 0.16),
	},
	{
		"id": "infernal_minotaur",
		"scene": "res://scenes/actors/enemies/infernal_minotaur.tscn",
		"cam_rel": Vector3(-0.34, 0.80, -0.96),
		"look_y": 0.74,
		"dist_mult": 1.26,
		"fov": 30.0,
		"rim_col": Color(1.0, 0.42, 0.10),
	},
	{
		"id": "barrow_troll",
		"scene": "res://scenes/actors/enemies/barrow_troll.tscn",
		"cam_rel": Vector3(-0.36, 0.78, -0.96),
		"look_y": 0.76,
		"dist_mult": 1.04,
		"fov": 31.0,
		"rim_col": Color(1.0, 0.38, 0.10),
	},
	{
		"id": "blight_werewolf",
		"scene": "res://scenes/actors/enemies/blight_werewolf.tscn",
		"cam_rel": Vector3(-0.36, 0.80, -0.96),
		"look_y": 0.72,
		"dist_mult": 1.12,
		"fov": 30.0,
		"rim_col": Color(0.22, 0.56, 0.20),
	},
]

const SKILL_KEYS := [
	{"id": "iron_tempest", "shader_id": 0},
	{"id": "blackflame_pyre", "shader_id": 1},
	{"id": "stormbrand_arc", "shader_id": 2},
	{"id": "iron_roll", "shader_id": 3},
	{"id": "phase_blink", "shader_id": 4},
	{"id": "reaping_sweep", "shader_id": 5},
	{"id": "wraith_lances", "shader_id": 6},
	{"id": "shadow_step", "shader_id": 7},
]

const ITEM_KEYS := [
	"zweihander",
	"halberd",
	"bastardsword",
	"blade_oarimaar",
	"runed_staff",
	"shield_round",
	"shield_heater",
	"shield_tower",
	"helm_iron",
	"helm_plume",
	"helm_t2",
	"helm_t3",
	"helm_t4",
	"cuirass_plate",
	"waist_lantern",
	"waist_lantern_soul",
	"waist_lantern_blight",
	"waist_lantern_blood",
]


func _init() -> void:
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty() and str(user_args[0]).strip_edges() != "":
		var arg := str(user_args[0]).strip_edges()
		_preview_sheet_path = arg if arg.to_lower().ends_with(".png") else arg.path_join("baked_icons_sheet.png")
	else:
		_preview_sheet_path = ProjectSettings.globalize_path("user://shots").path_join("baked_icons_sheet.png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PORTRAIT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ITEM_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SKILL_DIR))
	DirAccess.make_dir_recursive_absolute(_preview_sheet_path.get_base_dir())
	call_deferred("_bake_all")


func _bake_all() -> void:
	await process_frame
	await process_frame

	var portrait_jobs: Array[Dictionary] = []
	for hspec in HERO_SPECS:
		portrait_jobs.append(_build_hero_portrait_stage(hspec))
	for espec in ENEMY_SPECS:
		portrait_jobs.append(_build_enemy_portrait_stage(espec))

	var item_jobs: Array[Dictionary] = []
	for key in ITEM_KEYS:
		item_jobs.append(_build_item_stage(key))

	var skill_jobs: Array[Dictionary] = []
	for sspec in SKILL_KEYS:
		skill_jobs.append(_build_skill_icon_stage(str(sspec["id"]), int(sspec["shader_id"])))

	for _f in range(8):
		await RenderingServer.frame_post_draw

	var total_tiles := portrait_jobs.size() + item_jobs.size() + skill_jobs.size()
	var sheet_cols := 6
	var sheet_rows := maxi(1, ceili(float(total_tiles) / float(sheet_cols)))
	var sheet := Image.create(256 * sheet_cols, 256 * sheet_rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.04, 0.04, 0.05, 1.0))
	var sheet_idx := 0

	for job in portrait_jobs:
		var vp: SubViewport = job["vp"]
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(256, 256, Image.INTERPOLATE_LANCZOS)
		_apply_vignette_and_frame(img, Color(0.04, 0.045, 0.06), 0.52)
		var out_path := "%s/%s.png" % [PORTRAIT_DIR, str(job["id"])]
		var err := img.save_png(ProjectSettings.globalize_path(out_path))
		if err != OK:
			printerr("Failed saving portrait: ", out_path)
		else:
			print("Baked portrait: ", out_path)
		var sx := (sheet_idx % 6) * 256
		var sy := (sheet_idx / 6) * 256
		sheet.blit_rect(img, Rect2i(0, 0, 256, 256), Vector2i(sx, sy))
		sheet_idx += 1
		vp.queue_free()

	for job in item_jobs:
		var vp: SubViewport = job["vp"]
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(128, 128, Image.INTERPOLATE_LANCZOS)
		_apply_vignette_and_frame(img, Color(0.035, 0.04, 0.052), 0.58)
		var out_path := "%s/%s.png" % [ITEM_DIR, str(job["id"])]
		var err := img.save_png(ProjectSettings.globalize_path(out_path))
		if err != OK:
			printerr("Failed saving item icon: ", out_path)
		else:
			print("Baked item icon: ", out_path)
		var preview_up := img.duplicate() as Image
		preview_up.resize(256, 256, Image.INTERPOLATE_BILINEAR)
		var sx := (sheet_idx % 6) * 256
		var sy := (sheet_idx / 6) * 256
		if sy + 256 <= sheet.get_height():
			sheet.blend_rect(preview_up, Rect2i(0, 0, 256, 256), Vector2i(sx, sy))
		sheet_idx += 1
		vp.queue_free()

	for job in skill_jobs:
		var vp: SubViewport = job["vp"]
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(128, 128, Image.INTERPOLATE_LANCZOS)
		var out_path := "%s/%s.png" % [SKILL_DIR, str(job["id"])]
		var err := img.save_png(ProjectSettings.globalize_path(out_path))
		if err != OK:
			printerr("Failed saving skill icon: ", out_path)
		else:
			print("Baked skill icon: ", out_path)
		var preview_up := img.duplicate() as Image
		preview_up.resize(256, 256, Image.INTERPOLATE_BILINEAR)
		var sx := (sheet_idx % 6) * 256
		var sy := (sheet_idx / 6) * 256
		if sy + 256 <= sheet.get_height():
			sheet.blend_rect(preview_up, Rect2i(0, 0, 256, 256), Vector2i(sx, sy))
		sheet_idx += 1
		vp.queue_free()

	sheet.save_png(_preview_sheet_path)
	print("Saved preview contact sheet: ", _preview_sheet_path)
	await process_frame
	quit(0)


func _build_skill_icon_stage(skill_id: String, shader_id: int) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 512)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var sh := Shader.new()
	sh.code = SKILL_ICON_SHADER
	var smat := ShaderMaterial.new()
	smat.shader = sh
	smat.set_shader_parameter("icon_id", shader_id)

	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	rect.position = Vector2.ZERO
	rect.size = Vector2(512, 512)
	rect.material = smat
	vp.add_child(rect)

	return {"vp": vp, "id": skill_id}


func _make_studio_viewport(vp_size: Vector2i, bg_col: Color, rim_col: Color, key_energy: float = 2.45) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = vp_size
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg_col
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.24, 0.27, 0.35)
	env.ambient_light_energy = 1.08
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.14

	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color(1.0, 0.92, 0.80)
	key_light.light_energy = key_energy
	key_light.shadow_enabled = true
	key_light.look_at_from_position(Vector3(-2.6, 3.8, -3.4), Vector3(0.0, 1.2, 0.0), Vector3.UP)
	vp.add_child(key_light)

	var cool_rim := DirectionalLight3D.new()
	cool_rim.light_color = Color(0.52, 0.68, 0.98)
	cool_rim.light_energy = 1.65
	cool_rim.shadow_enabled = false
	cool_rim.look_at_from_position(Vector3(2.8, 2.9, 3.0), Vector3(0.0, 1.3, 0.0), Vector3.UP)
	vp.add_child(cool_rim)

	var accent_rim := OmniLight3D.new()
	accent_rim.light_color = rim_col
	accent_rim.light_energy = 2.2
	accent_rim.omni_range = 6.5
	accent_rim.position = Vector3(-1.35, 1.55, 1.15)
	vp.add_child(accent_rim)

	var cam := Camera3D.new()
	cam.current = true
	vp.add_child(cam)

	return {
		"vp": vp,
		"cam": cam,
		"key": key_light,
		"cool_rim": cool_rim,
		"accent_rim": accent_rim,
	}


func _get_actor_bone_world(actor: ActorVisual, bone_name: String, fallback: Vector3) -> Vector3:
	if actor == null or actor.skeleton == null:
		return fallback
	var idx := actor.skeleton.find_bone(bone_name)
	if idx < 0:
		return fallback
	return actor.skeleton.global_transform * actor.skeleton.get_bone_global_pose(idx).origin


func _build_hero_portrait_stage(spec: Dictionary) -> Dictionary:
	var st := _make_studio_viewport(Vector2i(512, 512), Color(0.065, 0.072, 0.095), spec["rim_col"] as Color, 2.05)
	for ch in (st["vp"] as SubViewport).get_children():
		if ch is WorldEnvironment:
			var env := (ch as WorldEnvironment).environment
			if env != null:
				env.glow_intensity = 0.28
				env.glow_bloom = 0.05
				env.glow_hdr_threshold = 1.2
	var ps := load(str(spec["scene"])) as PackedScene
	var actor := ps.instantiate() as ActorVisual
	(st["vp"] as SubViewport).add_child(actor)
	actor.ensure_initialized()
	HeroRigDresser.dress(
		actor,
		str(spec["id"]),
		int(spec["tier"]),
		str(spec["wpn"]),
		str(spec["off"]),
		bool(spec["plume"]),
		spec["lantern"] as Color
	)
	actor.play_anim("idle", 1.0, true)
	if actor.anim_player != null:
		actor.anim_player.advance(0.05)

	var cam: Camera3D = st["cam"]
	cam.fov = float(spec["fov"])
	if actor.is_unified_kit():
		var h := maxf(1.2, actor.height_meters)
		var chest_p := _get_actor_bone_world(actor, "chest", Vector3(0.0, h * 0.64, 0.0))
		var head_p := _get_actor_bone_world(actor, "head", Vector3(0.0, h * 0.84, 0.0))
		var anchor := chest_p.lerp(head_p, 0.56)
		var look_y_val := float(spec.get("look_y", 0.76))
		var dist_mult := float(spec.get("dist_mult", 1.0))
		var look_target := Vector3(anchor.x, h * look_y_val, anchor.z)
		var fill_warm := OmniLight3D.new()
		fill_warm.light_color = Color(1.0, 0.68, 0.34)
		fill_warm.light_energy = 1.15
		fill_warm.omni_range = 5.0
		fill_warm.position = look_target + Vector3(0.85, 0.25, -1.15)
		(st["vp"] as SubViewport).add_child(fill_warm)
		var cam_offset := Vector3(-0.48, 0.02, -2.14) * dist_mult
		cam.look_at_from_position(look_target + cam_offset, look_target, Vector3.UP)
	else:
		cam.look_at_from_position(spec["cam_pos"] as Vector3, spec["look_at"] as Vector3, Vector3.UP)
	st["id"] = str(spec["id"])
	return st


func _build_enemy_portrait_stage(spec: Dictionary) -> Dictionary:
	var st := _make_studio_viewport(Vector2i(512, 512), Color(0.06, 0.065, 0.086), spec["rim_col"] as Color, 2.6)
	var ps := load(str(spec["scene"])) as PackedScene
	var actor := ps.instantiate() as ActorVisual
	(st["vp"] as SubViewport).add_child(actor)
	actor.ensure_initialized()
	actor.play_anim("idle", 1.0, true)
	if actor.anim_player != null:
		actor.anim_player.advance(0.08)

	var h := maxf(1.2, actor.height_meters)
	var cam: Camera3D = st["cam"]
	cam.fov = float(spec["fov"])

	if actor.is_unified_kit():
		var chest_p := _get_actor_bone_world(actor, "chest", Vector3(0.0, h * 0.64, 0.0))
		var head_p := _get_actor_bone_world(actor, "head", Vector3(0.0, h * 0.84, 0.0))
		var anchor := chest_p.lerp(head_p, 0.60)
		var look_target := Vector3(anchor.x, h * float(spec["look_y"]), anchor.z)
		var dist := h * 0.96 * float(spec["dist_mult"])
		var rel: Vector3 = spec["cam_rel"]
		var cam_pos := look_target + Vector3(rel.x * dist, (rel.y - 0.78) * dist * 0.5, rel.z * dist)

		(st["key"] as DirectionalLight3D).look_at_from_position(
			look_target + Vector3(-dist * 1.2, h * 0.8, -dist * 1.4),
			look_target,
			Vector3.UP
		)
		(st["cool_rim"] as DirectionalLight3D).look_at_from_position(
			look_target + Vector3(dist * 1.2, h * 0.6, dist * 1.3),
			look_target,
			Vector3.UP
		)
		(st["accent_rim"] as OmniLight3D).position = look_target + Vector3(-dist * 0.75, 0.25, dist * 0.65)
		(st["accent_rim"] as OmniLight3D).omni_range = maxf(6.5, h * 3.0)
		cam.look_at_from_position(cam_pos, look_target, Vector3.UP)
	else:
		var look_target := Vector3(0.0, h * float(spec["look_y"]), 0.0)
		var rel: Vector3 = spec["cam_rel"]
		var dist := h * 0.92 * float(spec["dist_mult"])
		var cam_pos := Vector3(rel.x * dist, h * rel.y, rel.z * dist)

		(st["key"] as DirectionalLight3D).look_at_from_position(
			Vector3(-dist * 1.2, h * 1.4, -dist * 1.4),
			look_target,
			Vector3.UP
		)
		(st["cool_rim"] as DirectionalLight3D).look_at_from_position(
			Vector3(dist * 1.2, h * 1.2, dist * 1.3),
			look_target,
			Vector3.UP
		)
		(st["accent_rim"] as OmniLight3D).position = Vector3(-dist * 0.75, h * 0.85, dist * 0.65)
		(st["accent_rim"] as OmniLight3D).omni_range = maxf(6.5, h * 3.0)
		cam.look_at_from_position(cam_pos, look_target, Vector3.UP)

	st["id"] = str(spec["id"])
	return st


func _build_item_stage(key: String) -> Dictionary:
	var accent := Color(0.95, 0.68, 0.28)
	var key_energy := 2.05
	match key:
		"runed_staff":
			accent = Color(0.35, 0.76, 1.0)
		"blade_oarimaar", "helm_t4":
			accent = Color(1.0, 0.30, 0.12)
		"waist_lantern":
			accent = GameEnums.lantern_color(GameEnums.LanternAspect.EMBER_GOLD)
		"waist_lantern_soul":
			accent = GameEnums.lantern_color(GameEnums.LanternAspect.SOUL_BLUE)
		"waist_lantern_blight":
			accent = GameEnums.lantern_color(GameEnums.LanternAspect.BLIGHT_GREEN)
		"waist_lantern_blood":
			accent = GameEnums.lantern_color(GameEnums.LanternAspect.BLOOD_CRIMSON)
		"helm_t2", "shield_heater":
			accent = Color(0.54, 0.74, 1.0)
		"helm_t3", "shield_tower", "cuirass_plate":
			accent = Color(1.0, 0.76, 0.30)
			key_energy = 2.15
		"helm_iron", "shield_round":
			accent = Color(0.84, 0.66, 0.44)
		"helm_plume":
			accent = Color(0.98, 0.56, 0.24)

	var st := _make_studio_viewport(Vector2i(512, 512), Color(0.065, 0.072, 0.092), accent, key_energy)
	var vp: SubViewport = st["vp"]
	var holder := Node3D.new()
	holder.name = "ItemHolder"
	vp.add_child(holder)

	var raw_node := _instantiate_item_model(key)
	holder.add_child(raw_node)

	var local_box := _compute_node_aabb(raw_node)
	if local_box.size.length() > 0.0001:
		var max_dim := maxf(local_box.size.x, maxf(local_box.size.y, local_box.size.z))
		var norm_scale := 1.0 / max_dim
		raw_node.scale *= norm_scale

	var orient := Node3D.new()
	orient.name = "Orient"
	holder.remove_child(raw_node)
	orient.add_child(raw_node)
	holder.add_child(orient)

	_orient_item_for_studio(key, orient, raw_node)

	var world_box := _compute_node_aabb(holder)
	if world_box.size.length() > 0.0001:
		var center := world_box.position + world_box.size * 0.5
		holder.position -= center
		if key in ["halberd", "runed_staff"]:
			holder.position -= Vector3(0.02, 0.02, 0.0)

	var final_box := _compute_node_aabb(holder)
	var span := maxf(0.15, maxf(final_box.size.x, final_box.size.y))
	var fov_deg := 26.0
	var fill_margin := 1.04
	var depth_pad := 0.55
	if key in ["halberd", "runed_staff"]:
		fill_margin = 1.02
	elif key in ["zweihander", "bastardsword", "blade_oarimaar"]:
		fill_margin = 0.96
	elif key in ["shield_round", "shield_heater", "shield_tower"]:
		fill_margin = 1.06
	elif key == "cuirass_plate":
		fill_margin = 0.96
		depth_pad = 0.45
	elif key.begins_with("waist_lantern"):
		fill_margin = 0.98
		depth_pad = 0.45
	elif key == "helm_plume":
		fill_margin = 0.98
		depth_pad = 0.42
	elif key in ["helm_iron", "helm_t2", "helm_t3", "helm_t4"]:
		fill_margin = 0.92
		depth_pad = 0.42
	var dist := (span * 0.5 * fill_margin) / tan(deg_to_rad(fov_deg * 0.5)) + final_box.size.z * depth_pad

	var cam: Camera3D = st["cam"]
	cam.fov = fov_deg
	cam.look_at_from_position(Vector3(0.0, 0.0, -dist), Vector3.ZERO, Vector3.UP)

	(st["key"] as DirectionalLight3D).look_at_from_position(Vector3(-2.2, 2.6, -3.2), Vector3.ZERO, Vector3.UP)
	(st["cool_rim"] as DirectionalLight3D).look_at_from_position(Vector3(2.4, 1.8, 2.4), Vector3.ZERO, Vector3.UP)
	var accent_light := st["accent_rim"] as OmniLight3D
	if key in ["zweihander", "blade_oarimaar", "bastardsword", "halberd", "runed_staff"]:
		accent_light.position = Vector3(-0.75, -0.65, -1.25)
		accent_light.light_energy = 1.55
	elif key == "helm_t4":
		accent_light.position = Vector3(0.85, -0.45, -1.25)
		accent_light.light_energy = 1.05
	else:
		accent_light.position = Vector3(0.85, -0.55, -1.1)
		accent_light.light_energy = 1.55
	accent_light.omni_range = 4.5

	st["id"] = key
	return st


func _instantiate_item_model(key: String) -> Node3D:
	var root_node := Node3D.new()
	match key:
		"zweihander":
			var ps := load("res://assets/models/forged/zweihander.glb") as PackedScene
			if ps != null:
				root_node.add_child(ps.instantiate())
		"halberd":
			var ps := load("res://assets/models/forged/halberd.glb") as PackedScene
			if ps != null:
				root_node.add_child(ps.instantiate())
		"runed_staff":
			var ps := load("res://assets/models/forged/runed_staff.glb") as PackedScene
			if ps != null:
				var inst := ps.instantiate() as Node3D
				HeroRigDresser._tint_staff_crystal(inst, Color(0.32, 0.82, 1.0))
				_boost_studio_emission(inst, 4.8)
				var staff_glow := OmniLight3D.new()
				staff_glow.light_color = Color(0.28, 0.80, 1.0)
				staff_glow.light_energy = 2.2
				staff_glow.omni_range = 1.8
				staff_glow.position = Vector3(0.0, 0.72, 0.0)
				inst.add_child(staff_glow)
				root_node.add_child(inst)
		"bastardsword":
			var ps := load("res://assets/models/forged/bastardsword.glb") as PackedScene
			if ps != null:
				root_node.add_child(ps.instantiate())
		"blade_oarimaar":
			var ps := load("res://assets/models/forged/warden_greatsword.glb") as PackedScene
			if ps != null:
				var inst := ps.instantiate() as Node3D
				HeroRigDresser._style_weapon_tier(inst, 4, true)
				_boost_studio_emission(inst, 3.8)
				root_node.add_child(inst)
		"shield_round", "shield_heater", "shield_tower":
			root_node.add_child(_build_sculpted_shield(key))
		"waist_lantern", "waist_lantern_soul", "waist_lantern_blight", "waist_lantern_blood":
			var ps := load("res://assets/models/forged/waist_lantern.glb") as PackedScene
			if ps != null:
				var inst := ps.instantiate() as Node3D
				var lcol := GameEnums.lantern_color(GameEnums.LanternAspect.EMBER_GOLD)
				match key:
					"waist_lantern_soul":
						lcol = GameEnums.lantern_color(GameEnums.LanternAspect.SOUL_BLUE)
					"waist_lantern_blight":
						lcol = GameEnums.lantern_color(GameEnums.LanternAspect.BLIGHT_GREEN)
					"waist_lantern_blood":
						lcol = GameEnums.lantern_color(GameEnums.LanternAspect.BLOOD_CRIMSON)
				HeroRigDresser._tint_lantern_core(inst, lcol, 4.4)
				var glow := OmniLight3D.new()
				glow.light_color = lcol
				glow.light_energy = 2.2
				glow.omni_range = 1.8
				glow.position = Vector3(0.0, -0.14, 0.0)
				inst.add_child(glow)
				root_node.add_child(inst)
		"helm_iron":
			root_node.add_child(_build_oathbreaker_slot_model(["Slot_Helm"], 1))
		"helm_plume":
			root_node.add_child(_build_oathbreaker_slot_model(["Slot_Helm", "Slot_Plume"], 3, Color(0.64, 0.56, 0.44)))
		"helm_t2":
			root_node.add_child(_build_sculpted_helm("res://assets/models/gear/helm_t2_sallet.glb", 2, false))
		"helm_t3":
			root_node.add_child(_build_sculpted_helm("res://assets/models/gear/helm_t3_sovereign.glb", 3, false))
		"helm_t4":
			root_node.add_child(_build_sculpted_helm("res://assets/models/gear/helm_t4_ashen.glb", 4, true))
		"cuirass_plate":
			root_node.add_child(_build_oathbreaker_slot_model(["Slot_Cuirass", "Slot_Pauldrons"], 3))
	return root_node


func _orient_item_for_studio(key: String, orient: Node3D, raw_node: Node3D) -> void:
	var box := _compute_node_aabb(raw_node)
	var sz := box.size

	if key in ["zweihander", "halberd", "bastardsword", "blade_oarimaar", "runed_staff"]:
		var axes := [0, 1, 2]
		axes.sort_custom(func(a: int, b: int) -> bool: return sz[a] > sz[b])
		var up_axis: int = axes[0]
		var width_axis: int = axes[1]
		var v_up := Vector3.ZERO
		v_up[up_axis] = 1.0
		var v_right := Vector3.ZERO
		v_right[width_axis] = 1.0
		var v_fwd := v_right.cross(v_up).normalized()
		v_right = v_up.cross(v_fwd).normalized()
		var align_basis := Basis(v_right, v_up, v_fwd).inverse()
		raw_node.basis = align_basis * raw_node.basis
		orient.rotation_degrees = Vector3(8.0, 14.0, -40.0)
	elif key in ["shield_round", "shield_heater", "shield_tower"]:
		var axes := [0, 1, 2]
		axes.sort_custom(func(a: int, b: int) -> bool: return sz[a] > sz[b])
		var up_axis: int = axes[0]
		var width_axis: int = axes[1]
		var thin_axis: int = axes[2]
		var v_up := Vector3.ZERO
		v_up[up_axis] = 1.0
		var v_right := Vector3.ZERO
		v_right[width_axis] = 1.0
		var v_front := Vector3.ZERO
		v_front[thin_axis] = -1.0
		if v_right.cross(v_up).dot(v_front) < 0.0:
			v_right = -v_right
		var align_basis := Basis(v_right, v_up, v_front).inverse()
		raw_node.basis = align_basis * raw_node.basis
		orient.rotation_degrees = Vector3(6.0, 22.0, -4.0)
	elif key in ["helm_iron", "helm_t3"]:
		# Sculpted helms face +Z in GLB space; rotate past 180 deg toward the -X/-Z studio key light.
		orient.rotation_degrees = Vector3(5.0, 206.0, 0.0)
	elif key == "helm_t4":
		orient.rotation_degrees = Vector3(-4.0, 196.0, 0.0)
	elif key in ["helm_plume", "helm_t2"]:
		orient.rotation_degrees = Vector3(5.0, 214.0, 0.0)
	elif key == "cuirass_plate":
		orient.rotation_degrees = Vector3(6.0, 202.0, 0.0)
	elif key.begins_with("waist_lantern"):
		orient.rotation_degrees = Vector3(10.0, 32.0, -5.0)


func _boost_studio_emission(root_node: Node3D, min_energy: float) -> void:
	for n in root_node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if mat is StandardMaterial3D and (mat as StandardMaterial3D).emission_texture != null:
				var dup := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				dup.emission_enabled = true
				dup.emission_energy_multiplier = maxf(dup.emission_energy_multiplier, min_energy)
				mi.set_surface_override_material(s, dup)


func _build_sculpted_shield(key: String) -> Node3D:
	var ps := load("res://assets/models/forged/gothic_shield.glb") as PackedScene
	if ps == null:
		return Node3D.new()
	var inst := ps.instantiate() as Node3D
	var tier := 1
	var tint := Color(0.84, 0.80, 0.76)
	var is_plate := false
	if key == "shield_heater":
		tier = 2
		tint = Color(0.70, 0.78, 0.92)
	elif key == "shield_tower":
		tier = 3
		tint = Color(1.08, 0.96, 0.76)
		is_plate = true

	var armor_shader := load(HeroRigDresser.ARMOR_SHADER_PATH) as Shader
	if armor_shader != null:
		for n in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var smat := HeroRigDresser._apply_armor_shader(mi, s, mi.get_active_material(s), armor_shader, tier, is_plate)
				smat.set_shader_parameter("albedo_color", tint)
	return inst


func _build_sculpted_helm(glb_path: String, tier: int, boost_visor_emission: bool) -> Node3D:
	var ps := load(glb_path) as PackedScene
	if ps == null:
		return Node3D.new()
	var inst := ps.instantiate() as Node3D
	if boost_visor_emission:
		_boost_studio_emission(inst, 6.2)
		return inst

	var armor_shader := load(HeroRigDresser.ARMOR_SHADER_PATH) as Shader
	if armor_shader != null:
		for n in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				HeroRigDresser._apply_armor_shader(mi, s, mi.get_active_material(s), armor_shader, tier, false)
	return inst


func _build_oathbreaker_slot_model(
	visible_slots: Array[String],
	armor_tier: int,
	plume_col: Color = Color(0.82, 0.76, 0.64)
) -> Node3D:
	var ps := load("res://assets/models/kit/oathbreaker_knight.glb") as PackedScene
	if ps == null:
		return Node3D.new()
	var inst := ps.instantiate() as Node3D
	var armor_shader := load(HeroRigDresser.ARMOR_SHADER_PATH) as Shader
	var cloak_shader := load(HeroRigDresser.CLOAK_SHADER_PATH) as Shader

	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nm := String(mi.name)
		var keep := false
		for slot_name in visible_slots:
			if nm == slot_name or nm.begins_with(slot_name + "_") or nm.begins_with(slot_name + "."):
				keep = true
				break
		mi.visible = keep
		if not keep or mi.mesh == null:
			continue

		if nm == "Slot_Plume" or nm.begins_with("Slot_Plume_"):
			if cloak_shader != null:
				var pmat := HeroRigDresser._make_cloak_shader_mat(cloak_shader, plume_col, plume_col.darkened(0.28), 0.0, -1.0)
				for s in mi.mesh.get_surface_count():
					mi.set_surface_override_material(s, pmat)
			continue

		if armor_shader != null:
			for s in mi.mesh.get_surface_count():
				var orig_mat := mi.get_active_material(s)
				var mname_low := orig_mat.resource_name.to_lower() if orig_mat != null else ""
				if "neckcap" in mname_low or "undersuit" in mname_low:
					continue
				HeroRigDresser._apply_armor_shader(mi, s, orig_mat, armor_shader, armor_tier, true)

	return inst


static func _compute_node_aabb(root_3d: Node3D) -> AABB:
	var has_any := false
	var min_pt := Vector3(INF, INF, INF)
	var max_pt := Vector3(-INF, -INF, -INF)

	var stack: Array[Node] = [root_3d]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		for ch in cur.get_children():
			stack.append(ch)
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if not mi.visible or mi.mesh == null:
				continue
			var rel_xf := Transform3D.IDENTITY
			var walk: Node = mi
			while walk != null and walk != root_3d:
				if walk is Node3D:
					rel_xf = (walk as Node3D).transform * rel_xf
				walk = walk.get_parent()
			var mbox := mi.mesh.get_aabb()
			for cx in [0.0, 1.0]:
				for cy in [0.0, 1.0]:
					for cz in [0.0, 1.0]:
						var pt := mbox.position + Vector3(mbox.size.x * cx, mbox.size.y * cy, mbox.size.z * cz)
						var wpt := rel_xf * pt
						min_pt = min_pt.min(wpt)
						max_pt = max_pt.max(wpt)
						has_any = true
	if not has_any:
		return AABB()
	return AABB(min_pt, max_pt - min_pt)


static func _apply_vignette_and_frame(img: Image, edge_col: Color, strength: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var cx := float(w - 1) * 0.5
	var cy := float(h - 1) * 0.5
	var inv_r := 1.0 / maxf(1.0, minf(cx, cy))
	for y in range(h):
		for x in range(w):
			var dx := (float(x) - cx) * inv_r
			var dy := (float(y) - cy) * inv_r
			var dist := sqrt(dx * dx + dy * dy)
			var vig := clampf((dist - 0.58) / 0.72, 0.0, 1.0)
			vig = vig * vig * strength
			var c := img.get_pixel(x, y)
			var out_c := c.lerp(edge_col, vig)
			out_c.a = 1.0
			img.set_pixel(x, y, out_c)
