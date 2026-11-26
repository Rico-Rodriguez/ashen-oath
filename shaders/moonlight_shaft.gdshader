shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec3 shaft_color : source_color = vec3(0.44, 0.64, 1.0);
uniform float shaft_alpha : hint_range(0.0, 0.5) = 0.12;

void fragment() {
	float x_fade = pow(clamp(1.0 - abs(UV.x * 2.0 - 1.0), 0.0, 1.0), 2.3);
	float y_fade = smoothstep(0.0, 0.24, UV.y) * smoothstep(1.0, 0.16, UV.y);
	float view_fade = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.35);
	float shimmer = 0.88 + 0.12 * sin(UV.y * 12.0 + UV.x * 4.5 + TIME * 0.4);
	ALBEDO = shaft_color;
	ALPHA = x_fade * y_fade * view_fade * shimmer * shaft_alpha;
}
