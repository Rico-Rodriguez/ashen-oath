shader_type sky;

uniform vec3 vault_color : source_color = vec3(0.014, 0.017, 0.028);
uniform vec3 clerestory_color : source_color = vec3(0.45, 0.62, 1.0);
uniform float clerestory_hdr : hint_range(0.2, 6.0) = 2.2;
uniform vec3 brazier_color : source_color = vec3(1.0, 0.50, 0.16);
uniform float brazier_hdr : hint_range(0.2, 8.0) = 3.2;
uniform vec3 floor_bounce_color : source_color = vec3(0.08, 0.07, 0.06);
uniform vec3 horizon_color : source_color = vec3(0.032, 0.038, 0.056);
uniform float direct_bg_scale : hint_range(0.1, 1.0) = 0.42;

void sky() {
	vec3 d = normalize(EYEDIR);
	float el = d.y;
	float az = atan(d.x, d.z);

	float upper_t = smoothstep(-0.04, 0.58, el);
	vec3 upper_col = mix(horizon_color, vault_color, upper_t);

	float bay_wave = abs(cos(az * 4.0));
	float rib_arch = smoothstep(0.90, 0.99, bay_wave) * smoothstep(0.12, 0.72, el);
	upper_col *= mix(1.0, 0.52, rib_arch);

	float el_norm = clamp((el - 0.20) / 0.50, 0.0, 1.0);
	float arch_taper = mix(0.64, 0.96, pow(el_norm, 1.45));
	float bay_sin = abs(sin(az * 4.0));
	float win_x = smoothstep(arch_taper, min(0.995, arch_taper + 0.07), bay_sin);
	float win_y = smoothstep(0.18, 0.24, el) * (1.0 - smoothstep(0.62, 0.72, el));
	float lancet = win_x * win_y;
	float lancet_halo = smoothstep(0.46, 0.94, bay_sin) * smoothstep(0.10, 0.26, el) * (1.0 - smoothstep(0.56, 0.78, el)) * 0.22;
	float oculus_glow = smoothstep(0.76, 0.97, el) * 0.28;
	upper_col += clerestory_color * clerestory_hdr * (lancet + lancet_halo + oculus_glow);

	float side_bank = pow(clamp(abs(d.x), 0.0, 1.0), 1.65);
	float fire_band_y = exp(-pow((el - 0.07) / 0.14, 2.0));
	float fire_core_y = exp(-pow((el - 0.06) / 0.055, 2.0));
	float lobe = 0.58 + 0.42 * pow(abs(sin(az * 2.0)), 2.0);
	float fire_bank = side_bank * (fire_band_y * 0.52 + fire_core_y * 0.78) * lobe;
	upper_col += brazier_color * brazier_hdr * fire_bank;

	float lower_t = smoothstep(0.06, -0.45, el);
	vec3 lower_col = mix(floor_bounce_color, floor_bounce_color * 0.45, smoothstep(-0.08, -0.95, el));
	lower_col += brazier_color * (side_bank * 0.14 * (1.0 - smoothstep(0.0, -0.55, el)));

	vec3 sky_col = mix(upper_col, lower_col, lower_t);
	if (!AT_CUBEMAP_PASS) {
		sky_col *= direct_bg_scale;
	}
	COLOR = sky_col;
}
