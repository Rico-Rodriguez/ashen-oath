shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D metal_tex : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D emission_tex : source_color, hint_default_black, filter_linear_mipmap_anisotropic;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool has_normal = false;
uniform bool has_rough_tex = false;
uniform bool has_metal_tex = false;
uniform bool has_emission_tex = false;
uniform vec4 rough_channel = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 metal_channel = vec4(0.0, 0.0, 1.0, 0.0);
uniform float base_roughness : hint_range(0.0, 1.0) = 0.65;
uniform float base_metallic : hint_range(0.0, 1.0) = 0.25;
uniform float normal_scale : hint_range(0.0, 2.5) = 1.0;

uniform int armor_tier : hint_range(1, 4) = 1;
uniform vec3 ember_color : source_color = vec3(1.0, 0.34, 0.06);
uniform vec3 rim_tint : source_color = vec3(0.22, 0.28, 0.38);
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;

const int TIER_WORN_IRON = 1;
const int TIER_BLACKENED_STEEL = 2;
const int TIER_SOVEREIGN_PLATE = 3;
const int TIER_ASHEN_BARROWS = 4;

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash22(i).x;
	float b = hash22(i + vec2(1.0, 0.0)).x;
	float c = hash22(i + vec2(0.0, 1.0)).x;
	float d = hash22(i + vec2(1.0, 1.0)).x;
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec2 voronoi_fissure(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	float cell_id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash22(n + g);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mr = r;
				mg = g;
				cell_id = o.x * 5.17 + o.y * 9.31;
			}
		}
	}
	md = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 o = hash22(n + g);
			vec2 r = g + o - f;
			if (dot(mr - r, mr - r) > 0.00001) {
				md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
			}
		}
	}
	return vec2(md, cell_id);
}

void fragment() {
	vec4 tex_col = texture(albedo_tex, UV) * albedo_color;
	vec3 alb = tex_col.rgb;
	float rgh = has_rough_tex ? clamp(dot(texture(rough_tex, UV), rough_channel) * base_roughness, 0.04, 1.0) : base_roughness;
	float met = has_metal_tex ? clamp(dot(texture(metal_tex, UV), metal_channel) * max(base_metallic, 1.0), 0.0, 1.0) : base_metallic;

	float luma = dot(alb, vec3(0.299, 0.587, 0.114));
	float armor_mask = clamp(max(met * 1.35, smoothstep(0.16, 0.48, luma) * 0.72), 0.0, 1.0);
	vec2 grit_h = hash22(floor(UV * 128.0));
	float grit = grit_h.x * 2.0 - 1.0;

	vec3 emit = has_emission_tex ? texture(emission_tex, UV).rgb * 1.6 : vec3(0.0);

	if (armor_tier == TIER_WORN_IRON) {
		vec3 worn_iron = mix(vec3(0.28, 0.25, 0.22), vec3(0.54, 0.50, 0.46), luma);
		alb = mix(alb * 0.84, worn_iron + grit * 0.025, armor_mask * 0.62);
		rgh = clamp(rgh + 0.16 * armor_mask + grit * 0.04, 0.25, 0.96);
		met = clamp(met * 0.72 + 0.15 * armor_mask, 0.0, 0.78);
	} else if (armor_tier == TIER_BLACKENED_STEEL) {
		vec3 blued_steel = mix(vec3(0.11, 0.13, 0.17), vec3(0.38, 0.43, 0.52), pow(clamp(luma * 1.25, 0.0, 1.0), 0.9));
		alb = mix(alb * 0.72, blued_steel, armor_mask * 0.80);
		rgh = mix(rgh, 0.24, armor_mask * 0.75);
		met = max(met, 0.86 * armor_mask);
	} else if (armor_tier == TIER_SOVEREIGN_PLATE) {
		float plate_mask = has_metal_tex
			? clamp(max(met * 1.35, smoothstep(0.55, 0.85, luma) * 0.14), 0.0, 1.0)
			: smoothstep(0.55, 0.85, luma) * 0.14;
		float n_curv = clamp(length(fwidth(NORMAL)) * 2.1, 0.0, 1.0);
		float a_edge = clamp(length(fwidth(alb)) * 4.4, 0.0, 1.0);
		float edge_signal = has_metal_tex
			? max(n_curv, a_edge) * mix(0.72, 1.18, plate_mask) + smoothstep(0.74, 0.94, luma) * plate_mask * 0.38
			: max(n_curv * 0.95, a_edge * 0.88);
		float gold_trim = smoothstep(0.56, 0.84, edge_signal);

		vec3 royal_cloth = mix(vec3(0.009, 0.009, 0.013), vec3(0.026, 0.022, 0.032), luma);
		vec3 royal_steel = mix(vec3(0.09, 0.10, 0.13), vec3(0.32, 0.35, 0.42), clamp(luma * 1.2, 0.0, 1.0));
		vec3 royal_gold = vec3(0.92, 0.68, 0.22) * (0.78 + 0.34 * luma);

		float cloth_blend = (has_metal_tex && plate_mask > 0.35) ? 0.76 : 0.92;
		vec3 base_surface = mix(mix(alb * 0.18, royal_cloth, cloth_blend), royal_steel, plate_mask);
		alb = mix(base_surface, royal_gold, gold_trim);
		rgh = mix(mix(rgh, 0.86, 1.0 - plate_mask), 0.23, plate_mask);
		rgh = mix(rgh, 0.17, gold_trim);
		met = max(met * plate_mask, max(0.88 * plate_mask, 0.96 * gold_trim));
		emit += royal_gold * gold_trim * 0.08;
	} else {
		float metal_armor = has_metal_tex ? clamp(met * 1.35, 0.0, 1.0) : 0.0;
		vec3 charred_cloth = mix(vec3(0.007, 0.007, 0.009), vec3(0.022, 0.020, 0.024), luma);
		vec3 charred_plate = mix(vec3(0.045, 0.045, 0.055), vec3(0.16, 0.15, 0.17), luma);
		vec3 charred = mix(charred_cloth, charred_plate, metal_armor);
		alb = mix(alb * 0.14, charred, 0.92);
		rgh = mix(0.86, 0.27, metal_armor);
		met = mix(0.06, max(met, 0.86), metal_armor);

		vec2 v_coarse = voronoi_fissure(UV * 11.5 + vec2(0.17, 0.43));
		vec2 v_fine = voronoi_fissure(UV * 24.0 + vec2(1.31, 0.79));
		float patch_n = value_noise(UV * 4.2 + vec2(2.1, 0.7)) * 0.65 + value_noise(UV * 9.0 + vec2(5.4, 3.2)) * 0.35;
		float vein_patch = smoothstep(0.36, 0.66, patch_n);
		float crack_core = smoothstep(0.018, 0.002, v_coarse.x);
		float crack_web = smoothstep(0.013, 0.002, v_fine.x) * smoothstep(0.085, 0.008, v_coarse.x);
		float surface_gate = has_metal_tex ? mix(0.15, 1.0, armor_mask) : 0.22;
		if (has_metal_tex && metal_armor < 0.2) {
			surface_gate = 0.22;
		}
		float fissure = clamp(crack_core + crack_web * 0.65, 0.0, 1.0) * vein_patch * surface_gate;
		float pulse = 0.72 + 0.28 * sin(TIME * 3.1 + v_coarse.y);
		vec3 hot_core = mix(ember_color, vec3(1.0, 0.84, 0.38), crack_core * 0.62);
		alb = mix(alb, hot_core * 0.55, fissure * 0.80);
		rgh = mix(rgh, 0.85, fissure * 0.5);
		emit += hot_core * fissure * (4.4 * pulse);
	}

	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}

	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - ndv, 3.4);
	vec3 tier_rim = rim_tint;
	if (armor_tier == TIER_SOVEREIGN_PLATE) {
		tier_rim = mix(rim_tint, vec3(0.55, 0.42, 0.18), 0.55);
	} else if (armor_tier == TIER_ASHEN_BARROWS) {
		tier_rim = mix(rim_tint, ember_color * 0.65, 0.65);
	}
	emit += tier_rim * fresnel * 0.42;

	float hf = clamp(hit_flash, 0.0, 1.0);
	alb = mix(alb, vec3(1.0, 0.94, 0.86), hf * 0.72);
	emit += vec3(1.0, 0.88, 0.72) * (hf * 2.2);

	ALBEDO = alb;
	ROUGHNESS = rgh;
	METALLIC = met;
	EMISSION = emit;
}
