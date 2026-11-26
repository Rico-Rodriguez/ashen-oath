shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 cloth_color : source_color = vec3(0.11, 0.10, 0.13);
uniform vec3 hem_ash_color : source_color = vec3(0.05, 0.045, 0.05);
uniform vec3 trim_color : source_color = vec3(0.28, 0.22, 0.15);
uniform float move_speed_norm : hint_range(0.0, 1.0) = 0.0;
uniform float sway_amplitude : hint_range(0.0, 0.4) = 0.09;
uniform float billow_sign : hint_range(-1.0, 1.0) = 1.0;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;

varying float v_sway_weight;

void vertex() {
	float w = clamp(COLOR.r, 0.0, 1.0);
	v_sway_weight = w;

	float spd = clamp(move_speed_norm, 0.0, 1.0);
	float freq = mix(2.1, 6.8, spd);
	float phase = TIME * freq + VERTEX.y * 4.8 + VERTEX.x * 3.1;
	float secondary = sin(TIME * (freq * 1.63) - VERTEX.x * 6.4 + VERTEX.y * 2.7);

	float amp = sway_amplitude * mix(0.28, 1.15, spd) * (w * w);
	float billow_back = spd * 0.16 * (w * w) * billow_sign;

	VERTEX.z += billow_back + (sin(phase) * 0.72 + secondary * 0.28) * amp;
	VERTEX.x += cos(phase * 0.83 + 1.1) * amp * 0.38;
	VERTEX.y += spd * 0.035 * (w * w) * (0.5 + 0.5 * sin(phase));
}

void fragment() {
	if (dot(NORMAL, VIEW) < 0.0) {
		NORMAL = -NORMAL;
	}

	vec2 weave_uv = UV * 96.0;
	float warp = sin(weave_uv.x * 6.28318 + sin(weave_uv.y * 3.14159) * 0.6);
	float weft = sin(weave_uv.y * 6.28318 - sin(weave_uv.x * 3.14159) * 0.6);
	float weave = 0.92 + 0.08 * (warp * weft);

	float ash_fade = smoothstep(0.45, 0.98, v_sway_weight);
	vec3 col = mix(cloth_color, hem_ash_color, ash_fade * 0.68) * weave;

	float border_band = smoothstep(0.84, 0.88, v_sway_weight) * (1.0 - smoothstep(0.90, 0.94, v_sway_weight));
	col = mix(col, trim_color * weave, border_band * 0.45);

	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fuzz = pow(1.0 - ndv, 2.8);
	col += cloth_color * fuzz * 0.22;
	if (!FRONT_FACING) {
		col *= 0.62;
	}

	float hf = clamp(hit_flash, 0.0, 1.0);
	ALBEDO = mix(col, vec3(1.0, 0.94, 0.86), hf * 0.70);
	ROUGHNESS = 0.94;
	METALLIC = 0.0;
	SPECULAR = 0.10;
	EMISSION = vec3(1.0, 0.88, 0.72) * (hf * 2.0);
}
