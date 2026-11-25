shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

const int MODE_LOOT_BEAM = 0;
const int MODE_GROUND_RING = 1;

uniform int beam_mode = 0;
uniform vec4 energy_color : source_color = vec4(1.0, 0.72, 0.24, 1.0);
uniform float hdr_gain = 3.2;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	if (beam_mode == MODE_LOOT_BEAM) {
		float uv_from_top = clamp(UV.y, 0.0, 1.0);
		float x_center = 1.0 - abs(UV.x * 2.0 - 1.0);
		float core = pow(clamp(x_center, 0.0, 1.0), 2.4);
		float shimmer = 0.85 + 0.15 * sin(TIME * 4.2 + uv_from_top * 9.0 + UV.x * 6.28318);
		float vert_falloff = pow(uv_from_top, 1.85) * smoothstep(1.0, 0.90, uv_from_top);
		float base_flare = exp(-(1.0 - uv_from_top) * 8.5) * pow(clamp(x_center, 0.0, 1.0), 1.4);
		float intensity = (core * vert_falloff + base_flare * 0.75) * shimmer * fade_alpha;
		vec3 col = mix(energy_color.rgb, vec3(1.0, 0.96, 0.88), core * 0.45) * (hdr_gain * intensity);
		ALBEDO = col;
		ALPHA = clamp(intensity, 0.0, 1.0);
	} else {
		vec2 p = (UV - 0.5) * 2.0;
		float r = length(p);
		float ring = exp(-pow((r - 0.84) / 0.034, 2.0));
		float inner = exp(-pow((r - 0.58) / 0.022, 2.0)) * 0.55;
		float ang = atan(p.y, p.x) + TIME * 1.1;
		float runes = smoothstep(0.82, 0.96, abs(sin(ang * 8.0))) * step(0.62, r) * step(r, 0.80) * 0.48;
		float intensity = clamp(ring + inner + runes, 0.0, 1.0) * (1.0 - smoothstep(0.92, 1.0, r)) * fade_alpha;
		vec3 col = mix(energy_color.rgb, vec3(0.88, 0.94, 1.0), ring * 0.25) * (hdr_gain * intensity);
		ALBEDO = col;
		ALPHA = clamp(intensity * 0.92, 0.0, 0.92);
	}
}
