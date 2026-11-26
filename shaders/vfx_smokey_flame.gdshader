shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform bool billboard_mode = true;
uniform vec3 core_hdr = vec3(6.2, 2.8, 0.62);
uniform vec3 mid_flame = vec3(2.4, 0.55, 0.10);
uniform vec3 soot_color : source_color = vec3(0.055, 0.042, 0.052);
uniform float soot_dominance : hint_range(0.0, 1.0) = 0.48;
uniform float scroll_speed = 2.8;
uniform float noise_scale = 4.6;
uniform float alpha_boost = 1.22;

varying float v_life;
varying float v_seed;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.52;
	for (int i = 0; i < 4; i++) {
		v += noise2d(p) * a;
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + vec2(13.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	v_life = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
	v_seed = INSTANCE_CUSTOM.z;
	if (billboard_mode) {
		mat4 mat_world = mat4(
			normalize(INV_VIEW_MATRIX[0]) * length(MODEL_MATRIX[0]),
			normalize(INV_VIEW_MATRIX[1]) * length(MODEL_MATRIX[1]),
			normalize(INV_VIEW_MATRIX[2]) * length(MODEL_MATRIX[2]),
			MODEL_MATRIX[3]
		);
		float ang = INSTANCE_CUSTOM.x;
		mat_world = mat_world * mat4(
			vec4(cos(ang), -sin(ang), 0.0, 0.0),
			vec4(sin(ang), cos(ang), 0.0, 0.0),
			vec4(0.0, 0.0, 1.0, 0.0),
			vec4(0.0, 0.0, 0.0, 1.0)
		);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
	}
}

void fragment() {
	float height_01 = 1.0 - UV.y;
	vec2 warp_uv = UV * (noise_scale * 0.75) + vec2(v_seed * 5.1, TIME * scroll_speed * 0.85);
	vec2 warp = vec2(fbm(warp_uv) - 0.5, fbm(warp_uv + vec2(4.3, 8.1)) - 0.5) * (0.22 + 0.24 * height_01);

	vec2 centered = (UV + warp * 0.55) - vec2(0.5, 0.55);
	float pinch = mix(1.0, 1.75, height_01);
	float dist = length(vec2(centered.x * pinch * 2.15, centered.y * 1.95));

	vec2 n_uv = (UV + warp) * noise_scale + vec2(v_seed * 7.3, TIME * scroll_speed);
	float turb = fbm(n_uv);
	float wisps = noise2d(n_uv * 2.6 + vec2(-TIME * 1.4, TIME * 3.1));

	float shape = (1.0 - dist) + (turb - 0.48) * 0.86 + (wisps - 0.5) * 0.30;
	float erode = mix(0.10, 0.62, v_life);
	float uv_edge = smoothstep(0.0, 0.22, UV.x) * smoothstep(1.0, 0.78, UV.x) * smoothstep(0.0, 0.28, UV.y) * smoothstep(1.0, 0.88, UV.y);
	float alpha_mask = smoothstep(erode, erode + 0.50, shape) * uv_edge;

	float soot_zone = clamp(height_01 * 0.62 + v_life * 0.65 + soot_dominance * 0.72 + (1.0 - turb) * 0.22, 0.0, 1.0);
	float center_boost = (1.0 - smoothstep(0.05, 0.38, abs(centered.x * pinch))) * (1.0 - height_01 * 0.55) * (1.0 - soot_dominance);
	float heat = shape * mix(1.28, 0.18, soot_zone) + center_boost * 0.48;
	float core_w = smoothstep(0.54, 0.84, heat);
	float mid_w = smoothstep(0.26, 0.56, heat);

	vec3 col = mix(soot_color, mid_flame, mid_w);
	col = mix(col, core_hdr, core_w);

	float ember_vein = smoothstep(erode + 0.03, erode + 0.11, shape) * (1.0 - smoothstep(erode + 0.11, erode + 0.20, shape));
	col += mid_flame * ember_vein * (0.95 * (1.0 - soot_dominance * 0.55));

	float fire_w = clamp(max(mid_w, core_w), 0.0, 1.0);
	float max_alpha = mix(0.38, 0.92, fire_w);
	ALBEDO = col * COLOR.rgb;
	ALPHA = clamp(alpha_mask * max_alpha * alpha_boost * COLOR.a, 0.0, max_alpha);
}
