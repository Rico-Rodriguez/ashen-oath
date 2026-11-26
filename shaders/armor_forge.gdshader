shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap;
uniform sampler2D metal_tex : hint_default_white, filter_linear_mipmap;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap;
uniform sampler2D emission_tex : source_color, hint_default_black, filter_linear_mipmap;
uniform sampler2D voronoi_tex : hint_default_black, filter_linear_mipmap, repeat_enable;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool has_normal_tex = false;
uniform bool has_orm_tex = false;
uniform bool has_rough_tex = false;
uniform bool has_metal_tex = false;
uniform bool has_ao_tex = false;
uniform bool has_emission_tex = false;
uniform vec4 rough_channel = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 metal_channel = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 ao_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform float base_roughness : hint_range(0.0, 1.0) = 0.42;
uniform float base_metallic : hint_range(0.0, 1.0) = 0.85;
uniform float normal_scale : hint_range(0.0, 2.5) = 1.0;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.85;

uniform int armor_tier : hint_range(1, 4) = 1;
uniform bool is_armor_plate = true;
uniform vec3 ember_color : source_color = vec3(1.0, 0.34, 0.06);
uniform vec3 rim_tint : source_color = vec3(0.22, 0.28, 0.38);
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;

const int TIER_WORN_IRON = 1;
const int TIER_BLACKENED_STEEL = 2;
const int TIER_SOVEREIGN_PLATE = 3;
const int TIER_ASHEN_BARROWS = 4;

void fragment() {
	vec4 tex_col = texture(albedo_tex, UV) * albedo_color;
	vec3 alb = tex_col.rgb;

	vec3 orm_sample = has_orm_tex ? texture(orm_tex, UV).rgb : vec3(1.0);
	float rgh = has_orm_tex
		? clamp(orm_sample.g * base_roughness, 0.04, 1.0)
		: (has_rough_tex ? clamp(dot(texture(rough_tex, UV), rough_channel) * base_roughness, 0.04, 1.0) : base_roughness);
	float met = has_orm_tex
		? clamp(orm_sample.b * base_metallic, 0.0, 1.0)
		: (has_metal_tex ? clamp(dot(texture(metal_tex, UV), metal_channel) * base_metallic, 0.0, 1.0) : base_metallic);
	float ao = has_ao_tex
		? mix(1.0, clamp(dot(texture(ao_tex, UV), ao_channel), 0.0, 1.0), ao_strength)
		: 1.0;
	vec3 nrm_sample = has_normal_tex ? texture(normal_tex, UV).rgb : vec3(0.5, 0.5, 1.0);

	float luma = dot(alb, vec3(0.299, 0.587, 0.114));
	float plate_w = 0.0;
	if (is_armor_plate) {
		if (has_orm_tex || has_metal_tex) {
			plate_w = smoothstep(0.22, 0.62, met);
		} else {
			plate_w = max(smoothstep(0.25, 0.65, base_metallic), smoothstep(0.20, 0.50, luma) * 0.85);
		}
	}

	vec3 emit = has_emission_tex ? texture(emission_tex, UV).rgb * 1.6 : vec3(0.0);

	if (armor_tier == TIER_WORN_IRON) {
		alb = mix(alb, pow(max(alb, vec3(0.0001)), vec3(1.12)) * 0.92, plate_w * 0.55);
		rgh = clamp(rgh, 0.08, 0.96);
		met = clamp(met, 0.0, 1.0);
	} else if (armor_tier == TIER_BLACKENED_STEEL) {
		alb *= mix(vec3(1.0), vec3(0.76, 0.81, 0.90), plate_w * 0.72);
		rgh = mix(rgh, clamp(rgh * 0.84, 0.22, 0.56), plate_w * 0.82);
		met = mix(met, max(met, 0.90), plate_w * 0.65);
	} else if (armor_tier == TIER_SOVEREIGN_PLATE) {
		float ndv_g = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float graze = pow(1.0 - ndv_g, 2.5);
		float n_curv = clamp(length(fwidth(NORMAL)) * 2.4, 0.0, 1.0);
		float nm_curv = has_normal_tex ? clamp(length(fwidth(nrm_sample.rg)) * 2.8, 0.0, 1.0) : 0.0;
		float a_edge = clamp(length(fwidth(alb)) * 3.6, 0.0, 1.0);
		float edge_sig = max(n_curv, max(nm_curv * 0.85, a_edge * 0.75));
		float patina_mask = clamp((smoothstep(0.24, 0.64, edge_sig) * 0.68 + graze * 0.44), 0.0, 0.82) * plate_w;
		vec3 antique_gold = vec3(0.88, 0.66, 0.24) * (0.62 + 0.50 * clamp(luma * 1.4, 0.0, 1.0));
		alb = mix(alb * mix(vec3(1.0), vec3(0.90, 0.89, 0.92), plate_w * 0.40), antique_gold, patina_mask);
		rgh = mix(rgh, clamp(rgh, 0.22, 0.62), plate_w * 0.85);
		rgh = mix(rgh, 0.25, patina_mask * 0.72);
		met = mix(met, max(met, 0.93), patina_mask * 0.80);
		emit += antique_gold * patina_mask * 0.07;
	} else {
		alb *= mix(vec3(1.0), vec3(0.24, 0.23, 0.28), plate_w);
		rgh = mix(rgh, clamp(rgh * 0.88, 0.22, 0.52), plate_w * 0.76);
		met = mix(met, max(met, 0.88), plate_w * 0.72);

		if (is_armor_plate && plate_w > 0.05) {
			vec3 vor = texture(voronoi_tex, UV * 1.15).rgb;
			float vein_patch = smoothstep(0.35, 0.72, vor.b);
			float crack_core = vor.r;
			float crack_web = vor.g;
			float fissure = clamp(crack_core + crack_web * 0.45, 0.0, 1.0) * vein_patch * plate_w;
			float pulse = 0.78 + 0.22 * sin(TIME * 3.1 + vor.b * 6.28318);
			vec3 hot_core = mix(ember_color, vec3(1.0, 0.78, 0.30), crack_core * 0.56);
			alb = mix(alb, hot_core * 0.45, fissure * 0.75);
			rgh = mix(rgh, 0.80, fissure * 0.42);
			emit += hot_core * fissure * (2.45 * pulse);
		}
	}

	if (has_normal_tex) {
		NORMAL_MAP = nrm_sample;
		NORMAL_MAP_DEPTH = normal_scale;
	}

	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - ndv, 3.4);
	vec3 tier_rim = rim_tint * (0.20 + 0.80 * plate_w);
	float rim_str = 0.18;
	if (armor_tier == TIER_BLACKENED_STEEL) {
		tier_rim = mix(rim_tint, vec3(0.32, 0.44, 0.62), 0.65) * (0.25 + 0.75 * plate_w);
		rim_str = 0.28;
	} else if (armor_tier == TIER_SOVEREIGN_PLATE) {
		tier_rim = mix(rim_tint, vec3(0.72, 0.54, 0.22), 0.65) * (0.20 + 0.80 * plate_w);
		rim_str = 0.28;
	} else if (armor_tier == TIER_ASHEN_BARROWS) {
		tier_rim = mix(rim_tint, ember_color * 0.68, 0.65) * plate_w;
		rim_str = 0.32;
	}
	emit += tier_rim * fresnel * rim_str;

	float hf = clamp(hit_flash, 0.0, 1.0);
	alb = mix(alb, vec3(1.0, 0.94, 0.86), hf * 0.72);
	emit += vec3(1.0, 0.88, 0.72) * (hf * 2.2);

	ALBEDO = alb;
	ROUGHNESS = rgh;
	METALLIC = met;
	AO = ao;
	AO_LIGHT_AFFECT = 0.75;
	EMISSION = emit;
}
