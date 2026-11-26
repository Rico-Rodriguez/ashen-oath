shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

void vertex() {
	mat4 mat_world = mat4(
		normalize(INV_VIEW_MATRIX[0]) * length(MODEL_MATRIX[0]),
		normalize(INV_VIEW_MATRIX[1]) * length(MODEL_MATRIX[1]),
		normalize(INV_VIEW_MATRIX[2]) * length(MODEL_MATRIX[2]),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float soft = pow(clamp(1.0 - d, 0.0, 1.0), 3.1);
	ALBEDO = COLOR.rgb * 1.45;
	ALPHA = soft * COLOR.a;
}
