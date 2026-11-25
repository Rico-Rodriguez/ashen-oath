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
	} else {
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
		"fov": 29.0,
		"rim_col": Color(1.0, 0.56, 0.20),
	},
	{
		"id": "battlemage",
		"scene": "res://scenes/actors/heroes/battlemage.tscn",
		"tier": 2,
		"wpn": "runed_staff",
		"off": "",
		"plume": true,
		"lantern": Color(0.32, 0.74, 1.0),
		"cam_pos": Vector3(0.58, 1.68, -2.18),
		"look_at": Vector3(-0.04, 1.58, 0.0),
		"fov": 28.0,
		"rim_col": Color(0.35, 0.75, 1.0),
	},
	{
		"id": "revenant",
		"scene": "res://scenes/actors/heroes/revenant.tscn",
		"tier": 3,
		"wpn": "halberd",
		"off": "",
		"plume": true,
		"lantern": Color(0.96, 0.22, 0.28),
		"cam_pos": Vector3(-0.56, 1.70, -2.12),
		"look_at": Vector3(0.02, 1.60, 0.0),
		"fov": 28.0,
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
		"dist_mult": 1.14,
		"fov": 31.0,
		"rim_col": Color(1.0, 0.36, 0.12),
	},
	{
		"id": "ash_scorpion",
		"scene": "res://scenes/actors/enemies/ash_scorpion.tscn",
		"cam_rel": Vector3(-0.52, 0.68, -0.92),
		"look_y": 0.46,
		"dist_mult": 1.55,
		"fov": 32.0,
		"rim_col": Color(1.0, 0.48, 0.16),
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
		"look_y": 0.68,
		"dist_mult": 1.18,
		"fov": 30.0,
		"rim_col": Color(1.0, 0.52, 0.16),
	},
	{
		"id": "infernal_minotaur",
		"scene": "res://scenes/actors/enemies/infernal_minotaur.tscn",
		"cam_rel": Vector3(-0.34, 0.80, -0.96),
		"look_y": 0.74,
		"dist_mult": 1.16,
		"fov": 30.0,
		"rim_col": Color(1.0, 0.34, 0.12),
	},
	{
		"id": "barrow_troll",
		"scene": "res://scenes/actors/enemies/barrow_troll.tscn",
		"cam_rel": Vector3(-0.36, 0.78, -0.96),
		"look_y": 0.75,
		"dist_mult": 1.16,
		"fov": 31.0,
		"rim_col": Color(1.0, 0.38, 0.10),
	},
	{
		"id": "blight_werewolf",
		"scene": "res://scenes/actors/enemies/blight_werewolf.tscn",
		"cam_rel": Vector3(-0.36, 0.80, -0.96),
		"look_y": 0.74,
		"dist_mult": 1.04,
		"fov": 30.0,
		"rim_col": Color(0.52, 0.96, 0.28),
	},
]

const SKILL_KEYS := [
	{"id": "iron_tempest", "shader_id": 0},
	{"id": "blackflame_pyre", "shader_id": 1},
	{"id": "stormbrand_arc", "shader_id": 2},
	{"id": "iron_roll", "shader_id": 3},
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
	"cuirass_plate",
	"waist_lantern",
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

	var sheet := Image.create(256 * 6, 256 * 5, false, Image.FORMAT_RGBA8)
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
			sheet.blit_rect(preview_up, Rect2i(0, 0, 256, 256), Vector2i(sx, sy))
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
			sheet.blit_rect(preview_up, Rect2i(0, 0, 256, 256), Vector2i(sx, sy))
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
	var st := _make_studio_viewport(Vector2i(512, 512), Color(0.065, 0.072, 0.095), spec["rim_col"] as Color, 2.55)
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
		var chest_p := _get_actor_bone_world(actor, "chest", Vector3(0.0, 1.32, 0.0))
		var head_p := _get_actor_bone_world(actor, "head", Vector3(0.0, 1.66, 0.0))
		var focus := chest_p.lerp(head_p, 0.56)
		var fill_warm := OmniLight3D.new()
		fill_warm.light_color = Color(1.0, 0.68, 0.34)
		fill_warm.light_energy = 1.65
		fill_warm.omni_range = 5.0
		fill_warm.position = focus + Vector3(0.85, 0.25, -1.15)
		(st["vp"] as SubViewport).add_child(fill_warm)
		cam.look_at_from_position(focus + Vector3(-0.48, 0.08, -2.14), focus + Vector3(0.0, 0.06, 0.0), Vector3.UP)
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
		var look_target := chest_p.lerp(head_p, 0.60)
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
	if key == "runed_staff":
		accent = Color(0.35, 0.76, 1.0)
	elif key == "blade_oarimaar":
		accent = Color(1.0, 0.36, 0.14)
	elif key == "waist_lantern":
		accent = Color(1.0, 0.68, 0.20)

	var st := _make_studio_viewport(Vector2i(512, 512), Color(0.065, 0.072, 0.092), accent, 1.95)
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
			holder.position -= Vector3(0.08, 0.08, 0.0)

	var final_box := _compute_node_aabb(holder)
	var span := maxf(0.15, maxf(final_box.size.x, final_box.size.y))
	var fov_deg := 26.0
	var fill_margin := 1.12
	if key in ["halberd", "runed_staff"]:
		fill_margin = 0.84
	elif key in ["zweihander", "bastardsword", "blade_oarimaar"]:
		fill_margin = 0.96
	var dist := (span * 0.5 * fill_margin) / tan(deg_to_rad(fov_deg * 0.5)) + final_box.size.z * 0.65

	var cam: Camera3D = st["cam"]
	cam.fov = fov_deg
	cam.look_at_from_position(Vector3(0.0, 0.0, -dist), Vector3.ZERO, Vector3.UP)

	(st["key"] as DirectionalLight3D).look_at_from_position(Vector3(-2.2, 2.6, -3.2), Vector3.ZERO, Vector3.UP)
	(st["cool_rim"] as DirectionalLight3D).look_at_from_position(Vector3(2.4, 1.8, 2.4), Vector3.ZERO, Vector3.UP)
	(st["accent_rim"] as OmniLight3D).position = Vector3(0.85, -0.55, -1.1)
	(st["accent_rim"] as OmniLight3D).light_energy = 1.65
	(st["accent_rim"] as OmniLight3D).omni_range = 4.5

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
				HeroRigDresser._tint_staff_crystal(inst, Color(0.34, 0.78, 1.0))
				root_node.add_child(inst)
		"bastardsword":
			var mesh := HeroRigDresser._get_bastardsword_mesh(null)
			if mesh != null:
				var mi := MeshInstance3D.new()
				mi.mesh = mesh
				root_node.add_child(mi)
		"blade_oarimaar":
			var mesh := load("res://assets/models/gear/blade_oarimaar.res") as Mesh
			if mesh != null:
				var mi := MeshInstance3D.new()
				mi.mesh = mesh
				for s in mesh.get_surface_count():
					var mat := mesh.surface_get_material(s)
					if mat is StandardMaterial3D:
						var dup := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
						dup.albedo_color = Color(0.55, 0.48, 0.46)
						dup.metallic = 0.85
						dup.roughness = 0.24
						dup.emission_enabled = true
						if dup.emission_texture == null:
							dup.emission_texture = load("res://assets/models/gear/tex/blade_oarimaar_0_emission.png") as Texture2D
						dup.emission = Color(1.0, 0.36, 0.10)
						dup.emission_energy_multiplier = 3.8
						mi.set_surface_override_material(s, dup)
				root_node.add_child(mi)
		"shield_round", "shield_heater", "shield_tower":
			var path := str(HeroRigDresser.GEAR_SHIELD_PATHS.get(key, ""))
			var mesh := load(path) as Mesh
			if mesh != null:
				var mi := MeshInstance3D.new()
				mi.mesh = mesh
				root_node.add_child(mi)
		"waist_lantern":
			var ps := load("res://assets/models/forged/waist_lantern.glb") as PackedScene
			if ps != null:
				var inst := ps.instantiate() as Node3D
				for n in inst.find_children("*", "MeshInstance3D", true, false):
					var mi := n as MeshInstance3D
					if mi.mesh == null:
						continue
					for s in mi.mesh.get_surface_count():
						var mat := mi.get_active_material(s)
						if mat != null and mat.resource_name == "LanternCore":
							var cmat := StandardMaterial3D.new()
							cmat.albedo_color = Color(1.0, 0.82, 0.42)
							cmat.roughness = 0.15
							cmat.emission_enabled = true
							cmat.emission = Color(1.0, 0.64, 0.16)
							cmat.emission_energy_multiplier = 4.2
							mi.set_surface_override_material(s, cmat)
				var glow := OmniLight3D.new()
				glow.light_color = Color(1.0, 0.68, 0.22)
				glow.light_energy = 2.2
				glow.omni_range = 2.0
				inst.add_child(glow)
				root_node.add_child(inst)
		"helm_iron":
			root_node.add_child(_build_forged_greathelm(false))
		"helm_plume":
			root_node.add_child(_build_forged_greathelm(true))
		"cuirass_plate":
			root_node.add_child(_build_forged_cuirass())
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
		orient.rotation_degrees = Vector3(-8.0, -24.0, 4.0)
	elif key in ["helm_iron", "helm_plume"]:
		orient.rotation_degrees = Vector3(8.0, 26.0, 0.0)
	elif key == "cuirass_plate":
		orient.rotation_degrees = Vector3(6.0, 20.0, 0.0)
	elif key == "waist_lantern":
		orient.rotation_degrees = Vector3(8.0, 28.0, -6.0)


func _build_forged_greathelm(with_plume: bool) -> Node3D:
	var helm := Node3D.new()

	var steel_mat := StandardMaterial3D.new()
	steel_mat.albedo_color = Color(0.24, 0.27, 0.33) if with_plume else Color(0.32, 0.33, 0.36)
	steel_mat.metallic = 0.88
	steel_mat.roughness = 0.26

	var dark_slit_mat := StandardMaterial3D.new()
	dark_slit_mat.albedo_color = Color(0.02, 0.02, 0.03)
	dark_slit_mat.roughness = 0.95

	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = Color(0.86, 0.66, 0.26) if with_plume else Color(0.58, 0.46, 0.28)
	trim_mat.metallic = 0.92
	trim_mat.roughness = 0.22

	var barrel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.205
	cyl.bottom_radius = 0.225
	cyl.height = 0.36
	cyl.radial_segments = 32
	barrel.mesh = cyl
	barrel.material_override = steel_mat
	helm.add_child(barrel)

	var dome := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.206
	sph.height = 0.22
	sph.is_hemisphere = true
	dome.mesh = sph
	dome.position = Vector3(0.0, 0.175, 0.0)
	dome.material_override = steel_mat
	helm.add_child(dome)

	var brow := MeshInstance3D.new()
	var brow_cyl := CylinderMesh.new()
	brow_cyl.top_radius = 0.218
	brow_cyl.bottom_radius = 0.220
	brow_cyl.height = 0.048
	brow_cyl.radial_segments = 32
	brow.mesh = brow_cyl
	brow.position = Vector3(0.0, 0.075, -0.008)
	brow.material_override = trim_mat
	helm.add_child(brow)

	var nasal := MeshInstance3D.new()
	var nasal_box := BoxMesh.new()
	nasal_box.size = Vector3(0.044, 0.29, 0.036)
	nasal.mesh = nasal_box
	nasal.position = Vector3(0.0, -0.02, -0.218)
	nasal.material_override = trim_mat
	helm.add_child(nasal)

	var eye_slit := MeshInstance3D.new()
	var slit_box := BoxMesh.new()
	slit_box.size = Vector3(0.28, 0.036, 0.06)
	eye_slit.mesh = slit_box
	eye_slit.position = Vector3(0.0, 0.035, -0.202)
	eye_slit.material_override = dark_slit_mat
	helm.add_child(eye_slit)

	for side in [-1.0, 1.0]:
		var cheek := MeshInstance3D.new()
		var cbox := BoxMesh.new()
		cbox.size = Vector3(0.11, 0.19, 0.045)
		cheek.mesh = cbox
		cheek.position = Vector3(side * 0.105, -0.085, -0.195)
		cheek.rotation_degrees = Vector3(0.0, side * -18.0, 0.0)
		cheek.material_override = steel_mat
		helm.add_child(cheek)

	var gorget := MeshInstance3D.new()
	var gcyl := CylinderMesh.new()
	gcyl.top_radius = 0.232
	gcyl.bottom_radius = 0.275
	gcyl.height = 0.08
	gcyl.radial_segments = 32
	gorget.mesh = gcyl
	gorget.position = Vector3(0.0, -0.20, 0.0)
	gorget.material_override = trim_mat if with_plume else steel_mat
	helm.add_child(gorget)

	var crest_ridge := MeshInstance3D.new()
	var cr_box := BoxMesh.new()
	cr_box.size = Vector3(0.038, 0.11, 0.34)
	crest_ridge.mesh = cr_box
	crest_ridge.position = Vector3(0.0, 0.24, 0.01)
	crest_ridge.material_override = trim_mat
	helm.add_child(crest_ridge)

	if with_plume:
		var plume_ps := load("res://assets/models/forged/helm_plume.glb") as PackedScene
		if plume_ps != null:
			var plume := plume_ps.instantiate() as Node3D
			plume.position = Vector3(0.0, 0.26, 0.02)
			plume.rotation_degrees = Vector3(0.0, 180.0, 0.0)
			plume.scale = Vector3.ONE * 1.35
			var pmat := StandardMaterial3D.new()
			pmat.albedo_color = Color(0.72, 0.14, 0.14)
			pmat.roughness = 0.68
			for n in plume.find_children("*", "MeshInstance3D", true, false):
				var pmi := n as MeshInstance3D
				if pmi.mesh != null:
					for s in pmi.mesh.get_surface_count():
						var m := pmi.get_active_material(s)
						if m != null and m.resource_name == "CrimsonAshenPlume":
							pmi.set_surface_override_material(s, pmat)
			helm.add_child(plume)

	return helm


func _build_forged_cuirass() -> Node3D:
	var root_armor := Node3D.new()

	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.26, 0.29, 0.35)
	plate_mat.metallic = 0.88
	plate_mat.roughness = 0.25

	var dark_under := StandardMaterial3D.new()
	dark_under.albedo_color = Color(0.11, 0.10, 0.12)
	dark_under.metallic = 0.35
	dark_under.roughness = 0.72

	var gold_trim := StandardMaterial3D.new()
	gold_trim.albedo_color = Color(0.84, 0.65, 0.26)
	gold_trim.metallic = 0.92
	gold_trim.roughness = 0.22

	var chest := MeshInstance3D.new()
	var chest_cyl := CylinderMesh.new()
	chest_cyl.top_radius = 0.285
	chest_cyl.bottom_radius = 0.215
	chest_cyl.height = 0.44
	chest_cyl.radial_segments = 32
	chest.mesh = chest_cyl
	chest.scale = Vector3(1.20, 1.0, 0.72)
	chest.position = Vector3(0.0, 0.12, 0.0)
	chest.material_override = plate_mat
	root_armor.add_child(chest)

	var breast_dome := MeshInstance3D.new()
	var bd_sph := SphereMesh.new()
	bd_sph.radius = 0.29
	bd_sph.height = 0.44
	breast_dome.mesh = bd_sph
	breast_dome.scale = Vector3(1.12, 0.92, 0.46)
	breast_dome.position = Vector3(0.0, 0.16, -0.105)
	breast_dome.material_override = plate_mat
	root_armor.add_child(breast_dome)

	for side in [-1.0, 1.0]:
		var v_rib := MeshInstance3D.new()
		var vr_box := BoxMesh.new()
		vr_box.size = Vector3(0.22, 0.032, 0.045)
		v_rib.mesh = vr_box
		v_rib.position = Vector3(side * 0.11, 0.09, -0.205)
		v_rib.rotation_degrees = Vector3(0.0, side * -18.0, side * -28.0)
		v_rib.material_override = gold_trim
		root_armor.add_child(v_rib)

	var keel := MeshInstance3D.new()
	var k_box := BoxMesh.new()
	k_box.size = Vector3(0.036, 0.40, 0.045)
	keel.mesh = k_box
	keel.position = Vector3(0.0, 0.13, -0.222)
	keel.material_override = gold_trim
	root_armor.add_child(keel)

	var collar := MeshInstance3D.new()
	var col_torus := TorusMesh.new()
	col_torus.inner_radius = 0.14
	col_torus.outer_radius = 0.21
	collar.mesh = col_torus
	collar.scale = Vector3(1.15, 0.65, 0.85)
	collar.position = Vector3(0.0, 0.34, 0.0)
	collar.material_override = gold_trim
	root_armor.add_child(collar)

	for i in range(3):
		var fauld := MeshInstance3D.new()
		var f_cyl := CylinderMesh.new()
		f_cyl.top_radius = 0.215 + float(i) * 0.022
		f_cyl.bottom_radius = 0.232 + float(i) * 0.024
		f_cyl.height = 0.075
		f_cyl.radial_segments = 28
		fauld.mesh = f_cyl
		fauld.scale = Vector3(1.16, 1.0, 0.76)
		fauld.position = Vector3(0.0, -0.11 - float(i) * 0.065, 0.0)
		fauld.material_override = gold_trim if i == 0 else plate_mat
		root_armor.add_child(fauld)

	for side in [-1.0, 1.0]:
		var tasset := MeshInstance3D.new()
		var t_box := BoxMesh.new()
		t_box.size = Vector3(0.18, 0.22, 0.045)
		tasset.mesh = t_box
		tasset.position = Vector3(side * 0.14, -0.34, -0.15)
		tasset.rotation_degrees = Vector3(-8.0, side * -12.0, side * -6.0)
		tasset.material_override = plate_mat
		root_armor.add_child(tasset)

	var pauldron_mesh: Mesh = load("res://assets/models/gear/pauldron_ancient.res") as Mesh if ResourceLoader.exists("res://assets/models/gear/pauldron_ancient.res") else null
	if pauldron_mesh != null:
		var p_box := pauldron_mesh.get_aabb()
		var p_max := maxf(0.001, maxf(p_box.size.x, maxf(p_box.size.y, p_box.size.z)))
		var p_scale := 0.34 / p_max
		var p_center := p_box.position + p_box.size * 0.5
		for side in [-1.0, 1.0]:
			var p_piv := Node3D.new()
			p_piv.position = Vector3(side * 0.34, 0.27, 0.0)
			p_piv.scale = Vector3(side, 1.0, 1.0)
			var p_mi := MeshInstance3D.new()
			p_mi.mesh = pauldron_mesh
			p_mi.scale = Vector3.ONE * p_scale
			p_mi.position = -p_center * p_scale
			p_piv.add_child(p_mi)
			root_armor.add_child(p_piv)
	else:
		for side in [-1.0, 1.0]:
			var sp := MeshInstance3D.new()
			var sp_sph := SphereMesh.new()
			sp_sph.radius = 0.16
			sp_sph.height = 0.22
			sp.mesh = sp_sph
			sp.position = Vector3(side * 0.33, 0.27, 0.0)
			sp.material_override = dark_under
			root_armor.add_child(sp)

	return root_armor


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
