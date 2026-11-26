import argparse
import math
import os
import sys
import tempfile

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Quaternion, Vector

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_TOOLS_DIR = os.path.dirname(_SCRIPT_DIR)
if _TOOLS_DIR not in sys.path:
    sys.path.insert(0, _TOOLS_DIR)

from blender_kit.kit_common import blender_to_godot, godot_to_blender

# 21-bone arachnid skeleton hierarchy: (bone_name, parent_name)
SCORPION_HIERARCHY: list[tuple[str, str | None]] = [
    ("root", None),
    ("body", "root"),
    ("head", "body"),
    ("abdomen", "body"),
    ("pincer_l_0", "head"),
    ("pincer_l_1", "pincer_l_0"),
    ("pincer_r_0", "head"),
    ("pincer_r_1", "pincer_r_0"),
    ("tail_0", "abdomen"),
    ("tail_1", "tail_0"),
    ("tail_2", "tail_1"),
    ("tail_3", "tail_2"),
    ("stinger", "tail_3"),
    ("leg_l_0", "body"),
    ("leg_l_1", "body"),
    ("leg_l_2", "body"),
    ("leg_l_3", "body"),
    ("leg_r_0", "body"),
    ("leg_r_1", "body"),
    ("leg_r_2", "body"),
    ("leg_r_3", "body"),
]

DEFORM_BONES: list[str] = [name for name, _ in SCORPION_HIERARCHY if name != "root"]


def _parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="CPU-only Ash Scorpion Auto-Rigging & NLA Animation Pipeline")
    parser.add_argument("--input", required=True, help="Path to baked Ash Scorpion GLB")
    parser.add_argument("--output", required=True, help="Output path for rigged Godot-ready GLB")
    parser.add_argument("--height", type=float, default=1.45, help="Target height in meters along Godot +Y")
    parser.add_argument("--target_tris", type=int, default=12000, help="Target triangle budget")
    parser.add_argument("--yaw_deg", type=float, default=None, help="Optional explicit yaw override in degrees around Godot +Y")
    parser.add_argument("--albedo_max_res", type=int, default=1024, help="Max resolution for sRGB albedo/emission maps")
    parser.add_argument("--maps_max_res", type=int, default=1024, help="Max resolution for normal/ORM data maps")
    parser.add_argument("--image_format", choices=["AUTO", "WEBP", "JPEG"], default="WEBP")
    parser.add_argument("--image_quality", type=int, default=90)
    return parser.parse_args(argv)


def _reset_cpu_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.fps = 60


def _count_tris(obj: bpy.types.Object) -> int:
    return sum(max(1, len(p.vertices) - 2) for p in obj.data.polygons)


def _vertices_godot_np(obj: bpy.types.Object) -> np.ndarray:
    mesh = obj.data
    n = len(mesh.vertices)
    coords = np.empty(n * 3, dtype=np.float64)
    mesh.vertices.foreach_get("co", coords)
    bl = coords.reshape((n, 3))
    gd = np.empty_like(bl)
    gd[:, 0] = bl[:, 0]
    gd[:, 1] = bl[:, 2]
    gd[:, 2] = -bl[:, 1]
    return gd


def _compute_auto_yaw_rad(pts_gd: np.ndarray) -> tuple[float, dict[str, float]]:
    # 2D PCA on Godot XZ to align the elongated scorpion body axis along Z.
    xz = pts_gd[:, [0, 2]]
    xz_c = xz - xz.mean(axis=0)
    cov = (xz_c.T @ xz_c) / float(max(1, len(xz_c)))
    _, eigvecs = np.linalg.eigh(cov)
    major = eigvecs[:, 1]
    base_yaw = math.atan2(-float(major[0]), float(major[1]))

    ca = math.cos(base_yaw)
    sa = math.sin(base_yaw)
    rx = pts_gd[:, 0] * ca + pts_gd[:, 2] * sa
    ry = pts_gd[:, 1]
    rz = -pts_gd[:, 0] * sa + pts_gd[:, 2] * ca

    y_min = float(ry.min())
    y_max = float(ry.max())
    raw_h = max(1e-4, y_max - y_min)
    y_norm = (ry - y_min) / raw_h

    x_span = max(1e-4, float(rx.max() - rx.min()))
    z_min = float(rz.min())
    z_max = float(rz.max())
    z_mid = 0.5 * (z_min + z_max)
    z_span = max(1e-4, z_max - z_min)

    # Upper 35% height holds the arched rear tail rising from -Z; lower 45% holds wide forward pincers at +Z.
    upper_z = rz[y_norm >= 0.65]
    upper_z_rel = (float(upper_z.mean()) - z_mid) / z_span if len(upper_z) >= 4 else 0.0

    lower_mask = y_norm <= 0.45
    lx = rx[lower_mask]
    lz = rz[lower_mask]
    n_lower = max(1, len(lz))

    pos_mask = lz >= z_mid + 0.15 * z_span
    neg_mask = lz <= z_mid - 0.15 * z_span
    pos_w = float(np.percentile(np.abs(lx[pos_mask]), 90)) / x_span if int(pos_mask.sum()) >= 8 else 0.0
    neg_w = float(np.percentile(np.abs(lx[neg_mask]), 90)) / x_span if int(neg_mask.sum()) >= 8 else 0.0
    pos_mass = float(pos_mask.sum()) / float(n_lower)
    neg_mass = float(neg_mask.sum()) / float(n_lower)

    lower_front_score = (pos_w - neg_w) + 0.6 * (pos_mass - neg_mass)
    score = -1.2 * upper_z_rel + lower_front_score

    final_yaw = base_yaw + (math.pi if score < 0.0 else 0.0)
    # Normalize to (-pi, pi]
    final_yaw = math.atan2(math.sin(final_yaw), math.cos(final_yaw))
    diag = {
        "pca_yaw_deg": math.degrees(base_yaw),
        "upper_z_rel": upper_z_rel,
        "pos_w": pos_w,
        "neg_w": neg_w,
        "score": score,
        "flipped_180": 1.0 if score < 0.0 else 0.0,
        "final_yaw_deg": math.degrees(final_yaw),
    }
    return final_yaw, diag


def _import_and_normalize_scorpion(
    input_path: str,
    target_height: float,
    yaw_deg_override: float | None = None,
) -> bpy.types.Object:
    bpy.ops.import_scene.gltf(filepath=input_path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh objects found in {input_path}")

    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()

    body = bpy.context.view_layer.objects.active
    body.name = "AshScorpion"
    body.data.name = "AshScorpionMesh"

    for obj in list(bpy.context.scene.objects):
        if obj != body:
            bpy.data.objects.remove(obj, do_unlink=True)

    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    pts_gd = _vertices_godot_np(body)
    if yaw_deg_override is None:
        yaw_rad, diag = _compute_auto_yaw_rad(pts_gd)
        print(
            f"[rig_ash_scorpion] Auto-orient PCA={diag['pca_yaw_deg']:.1f} deg | "
            f"upper_z={diag['upper_z_rel']:+.3f} | pos_w={diag['pos_w']:.3f} vs neg_w={diag['neg_w']:.3f} | "
            f"score={diag['score']:+.3f} -> yaw={diag['final_yaw_deg']:.1f} deg"
        )
    else:
        yaw_rad = math.radians(yaw_deg_override)
        print(f"[rig_ash_scorpion] Explicit yaw override: {yaw_deg_override:.1f} deg")

    if abs(yaw_rad) > 1e-6:
        # Godot +Y rotation maps to Blender +Z rotation.
        rot_bl = Matrix.Rotation(yaw_rad, 4, "Z")
        for v in body.data.vertices:
            v.co = rot_bl @ v.co
        body.data.update()

    pts_gd = _vertices_godot_np(body)
    min_x, max_x = float(pts_gd[:, 0].min()), float(pts_gd[:, 0].max())
    min_y, max_y = float(pts_gd[:, 1].min()), float(pts_gd[:, 1].max())
    min_z, max_z = float(pts_gd[:, 2].min()), float(pts_gd[:, 2].max())
    raw_h = max(1e-4, max_y - min_y)

    cx = 0.5 * (min_x + max_x)
    cz = 0.5 * (min_z + max_z)
    scale_f = target_height / raw_h

    for v in body.data.vertices:
        gp = blender_to_godot(v.co)
        nx = (gp.x - cx) * scale_f
        ny = (gp.y - min_y) * scale_f
        nz = (gp.z - cz) * scale_f
        v.co = godot_to_blender(nx, ny, nz)
    body.data.update()

    final_w = (max_x - min_x) * scale_f
    final_h = raw_h * scale_f
    final_l = (max_z - min_z) * scale_f
    print(f"[rig_ash_scorpion] Normalized bounds (Godot m): W={final_w:.3f}, H={final_h:.3f}, L={final_l:.3f}")
    return body


def _decimate_uv_preserving(obj: bpy.types.Object, target_tris: int) -> int:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    uv_layer = bm.loops.layers.uv.active
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    if uv_layer is not None:
        for e in bm.edges:
            if len(e.link_faces) == 2:
                f0, f1 = e.link_faces[0], e.link_faces[1]
                v0, v1 = e.verts[0], e.verts[1]
                uv0_a = next((l[uv_layer].uv for l in f0.loops if l.vert == v0), None)
                uv0_b = next((l[uv_layer].uv for l in f0.loops if l.vert == v1), None)
                uv1_a = next((l[uv_layer].uv for l in f1.loops if l.vert == v0), None)
                uv1_b = next((l[uv_layer].uv for l in f1.loops if l.vert == v1), None)
                if (
                    uv0_a is not None
                    and uv0_b is not None
                    and uv1_a is not None
                    and uv1_b is not None
                    and ((uv0_a - uv1_a).length > 1e-4 or (uv0_b - uv1_b).length > 1e-4)
                ):
                    e.seam = True
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()

    cur_tris = _count_tris(obj)
    if target_tris > 0 and cur_tris > target_tris:
        ratio = max(0.05, min(1.0, float(target_tris) / float(cur_tris)))
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        mod = obj.modifiers.new(name="DecimateUV", type="DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = ratio
        mod.use_collapse_triangulate = True
        mod.delimit = {"UV", "SEAM"}
        bpy.ops.object.modifier_apply(modifier=mod.name)

    mesh = obj.data
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    if hasattr(bpy.ops.mesh, "customdata_custom_splitnormals_clear"):
        try:
            bpy.ops.mesh.customdata_custom_splitnormals_clear()
        except RuntimeError:
            pass
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    mesh.validate(verbose=False)
    mesh.update()
    return _count_tris(obj)


def _srgb_to_linear(arr: np.ndarray) -> np.ndarray:
    a = np.clip(arr, 0.0, 1.0)
    return np.where(a <= 0.04045, a / 12.92, np.power((a + 0.055) / 1.055, 2.4))


def _linear_to_srgb(arr: np.ndarray) -> np.ndarray:
    a = np.clip(arr, 0.0, 1.0)
    return np.where(a <= 0.0031308, a * 12.92, 1.055 * np.power(a, 1.0 / 2.4) - 0.055)


def _lanczos_weights_1d(src_len: int, dst_len: int, a: float = 3.0) -> tuple[np.ndarray, np.ndarray]:
    scale = float(src_len) / float(dst_len)
    support = a * max(1.0, scale)
    centers = (np.arange(dst_len, dtype=np.float32) + 0.5) * scale - 0.5
    half_w = int(math.ceil(support))
    offsets = np.arange(-half_w, half_w + 1, dtype=np.int32)
    base_idx = np.floor(centers).astype(np.int32)[:, None] + offsets[None, :]
    d = (centers[:, None] - base_idx.astype(np.float32)) / max(1.0, scale)
    x = np.abs(d)
    w = np.where(
        x < 1e-6,
        1.0,
        np.where(x < a, np.sinc(x) * np.sinc(x / a), 0.0),
    ).astype(np.float32)
    w_sum = np.maximum(w.sum(axis=1, keepdims=True), 1e-6)
    w /= w_sum
    idx = np.clip(base_idx, 0, src_len - 1)
    return idx, w


def _lanczos_resize_rgba(
    rgba: np.ndarray,
    new_w: int,
    new_h: int,
    is_srgb: bool = False,
    is_normal: bool = False,
) -> np.ndarray:
    src_h, src_w, _ = rgba.shape
    work = rgba.astype(np.float32, copy=True)
    if is_srgb:
        work[:, :, :3] = _srgb_to_linear(work[:, :, :3])
    elif is_normal:
        work[:, :, :3] = work[:, :, :3] * 2.0 - 1.0

    idx_y, w_y = _lanczos_weights_1d(src_h, new_h, a=3.0)
    tmp = np.einsum("ij,ijkc->ikc", w_y, work[idx_y])
    idx_x, w_x = _lanczos_weights_1d(src_w, new_w, a=3.0)
    out = np.einsum("ij,kijc->kic", w_x, tmp[:, idx_x, :])

    if is_srgb:
        out[:, :, :3] = _linear_to_srgb(out[:, :, :3])
        out[:, :, 3] = np.clip(out[:, :, 3], 0.0, 1.0)
    elif is_normal:
        nrm = out[:, :, :3]
        nlen = np.maximum(np.linalg.norm(nrm, axis=2, keepdims=True), 1e-6)
        out[:, :, :3] = np.clip((nrm / nlen) * 0.5 + 0.5, 0.0, 1.0)
        out[:, :, 3] = 1.0
    else:
        out = np.clip(out, 0.0, 1.0)
    return out.astype(np.float32)


def _resize_blender_image_lanczos(
    img: bpy.types.Image,
    max_res: int,
    is_srgb: bool = False,
    is_normal: bool = False,
) -> None:
    w, h = img.size[0], img.size[1]
    if w <= 0 or h <= 0 or max(w, h) <= max_res:
        return
    sc = max_res / float(max(w, h))
    new_w = max(64, int(round(w * sc)))
    new_h = max(64, int(round(h * sc)))
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    resized = _lanczos_resize_rgba(
        px.reshape((h, w, 4)),
        new_w,
        new_h,
        is_srgb=is_srgb,
        is_normal=is_normal,
    )
    img.scale(new_w, new_h)
    img.pixels.foreach_set(resized.ravel())
    img.update()
    img.pack()


def _gaussian_blur_2d(field: np.ndarray, sigma: float) -> np.ndarray:
    radius = max(1, int(math.ceil(sigma * 3.0)))
    xs = np.arange(-radius, radius + 1, dtype=np.float32)
    kernel = np.exp(-0.5 * (xs / max(sigma, 1e-3)) ** 2)
    kernel /= kernel.sum()
    padded_y = np.pad(field, ((radius, radius), (0, 0)), mode="edge")
    acc_y = np.zeros_like(field, dtype=np.float32)
    h = field.shape[0]
    for k, wt in enumerate(kernel):
        acc_y += padded_y[k : k + h, :] * wt
    padded_x = np.pad(acc_y, ((0, 0), (radius, radius)), mode="edge")
    acc_x = np.zeros_like(field, dtype=np.float32)
    w = field.shape[1]
    for k, wt in enumerate(kernel):
        acc_x += padded_x[:, k : k + w] * wt
    return acc_x


def _extract_scorpion_ember_emission(body: bpy.types.Object, strength: float = 2.0) -> int:
    if not body.data.materials:
        return 0
    mat = body.data.materials[0]
    if mat is None or not mat.node_tree:
        return 0
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return 0
    bc_inp = bsdf.inputs.get("Base Color")
    if bc_inp is None or not bc_inp.is_linked:
        return 0
    src_node = bc_inp.links[0].from_node
    if src_node.type != "TEX_IMAGE" or src_node.image is None:
        return 0

    alb_img = src_node.image
    w, h = alb_img.size[0], alb_img.size[1]
    if w <= 0 or h <= 0:
        return 0

    px = np.empty(w * h * 4, dtype=np.float32)
    alb_img.pixels.foreach_get(px)
    rgb = px.reshape((h, w, 4))[:, :, :3]
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]

    # Isolate molten ember fissures, clustered eyes, and molten stinger tip (R > 0.34, R - B > 0.16, R / G > 1.15).
    m_r = np.clip((r - 0.34) / 0.12, 0.0, 1.0)
    m_rb = np.clip(((r - b) - 0.16) / 0.10, 0.0, 1.0)
    m_rg = np.clip((r / np.maximum(g, 1e-4) - 1.15) / 0.15, 0.0, 1.0)
    raw_ember = m_r * m_rb * m_rg

    sigma = max(1.2, 2.0 * (w / 1024.0))
    halo = _gaussian_blur_2d(raw_ember, sigma=sigma)
    ember_weight = np.clip(0.90 * raw_ember + 0.45 * halo, 0.0, 1.0)

    tint = np.array([1.0, 0.44, 0.10], dtype=np.float32)
    src_warm = np.stack(
        [np.clip(r * 1.25, 0.0, 1.0), np.clip(g * 0.90, 0.0, 1.0), np.clip(b * 0.35, 0.0, 1.0)],
        axis=2,
    )
    emit_rgb = (0.55 * tint[None, None, :] + 0.45 * src_warm) * ember_weight[:, :, None]
    emit_rgba = np.ones((h, w, 4), dtype=np.float32)
    emit_rgba[:, :, :3] = np.clip(emit_rgb, 0.0, 1.0)

    emit_img = bpy.data.images.new(name=f"{mat.name}_EmberEmission", width=w, height=h, alpha=False)
    emit_img.colorspace_settings.name = "sRGB"
    emit_img.pixels.foreach_set(emit_rgba.ravel())
    emit_img.update()
    emit_img.pack()

    tex_node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex_node.name = "EmberEmissionTex"
    tex_node.image = emit_img
    tex_node.location = (bsdf.location.x - 360, bsdf.location.y - 320)
    emit_col_inp = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
    if emit_col_inp is not None:
        mat.node_tree.links.new(tex_node.outputs["Color"], emit_col_inp)
    emit_str_inp = bsdf.inputs.get("Emission Strength")
    if emit_str_inp is not None:
        emit_str_inp.default_value = strength

    emissive_px = int((ember_weight > 0.08).sum())
    print(
        f"[rig_ash_scorpion] Extracted molten ember emission: {emissive_px} lit px "
        f"({100.0 * emissive_px / float(w * h):.3f}% of {w}x{h}), strength={strength}"
    )
    return emissive_px


def _prepare_textures_for_glb(
    albedo_max_res: int = 1024,
    maps_max_res: int = 1024,
    image_format: str = "WEBP",
) -> None:
    srgb_imgs: set[bpy.types.Image] = set()
    normal_imgs: set[bpy.types.Image] = set()
    data_imgs: set[bpy.types.Image] = set()
    for mat in bpy.data.materials:
        if not mat.node_tree:
            continue
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None:
            continue
        for inp_name in ("Base Color", "Emission Color", "Emission"):
            inp = bsdf.inputs.get(inp_name)
            if inp and inp.is_linked:
                src = inp.links[0].from_node
                if src.type == "TEX_IMAGE" and src.image is not None:
                    srgb_imgs.add(src.image)
        nrm_inp = bsdf.inputs.get("Normal")
        if nrm_inp and nrm_inp.is_linked:
            nmap_node = nrm_inp.links[0].from_node
            if nmap_node.type == "NORMAL_MAP":
                c_inp = nmap_node.inputs.get("Color")
                if c_inp and c_inp.is_linked and c_inp.links[0].from_node.type == "TEX_IMAGE":
                    if c_inp.links[0].from_node.image is not None:
                        normal_imgs.add(c_inp.links[0].from_node.image)
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image is not None:
                if n.image not in srgb_imgs and n.image not in normal_imgs:
                    if "normal" in n.image.name.lower():
                        normal_imgs.add(n.image)
                    else:
                        data_imgs.add(n.image)

    if image_format == "WEBP":
        for img in srgb_imgs:
            _resize_blender_image_lanczos(img, albedo_max_res, is_srgb=True, is_normal=False)
            img.colorspace_settings.name = "sRGB"
        for img in normal_imgs:
            _resize_blender_image_lanczos(img, maps_max_res, is_srgb=False, is_normal=True)
            img.colorspace_settings.name = "Non-Color"
        for img in data_imgs:
            _resize_blender_image_lanczos(img, maps_max_res, is_srgb=False, is_normal=False)
            img.colorspace_settings.name = "Non-Color"
        return

    remap: dict[bpy.types.Image, bpy.types.Image] = {}
    with tempfile.TemporaryDirectory(prefix="cc_scorp_tex_") as tmpdir:
        for img in list(srgb_imgs):
            if img.size[0] == 0 or img.size[1] == 0:
                continue
            work = img.copy()
            _resize_blender_image_lanczos(work, albedo_max_res, is_srgb=True, is_normal=False)
            out_jpg = os.path.join(tmpdir, f"{img.name}_alb.jpg")
            work.filepath_raw = out_jpg
            work.file_format = "JPEG"
            work.save(quality=90)
            bpy.data.images.remove(work)
            new_img = bpy.data.images.load(out_jpg, check_existing=False)
            new_img.name = f"{img.name}_packed"
            new_img.colorspace_settings.name = "sRGB"
            new_img.pack()
            remap[img] = new_img

        for img in list(normal_imgs | data_imgs):
            if img.size[0] == 0 or img.size[1] == 0:
                continue
            work = img.copy()
            _resize_blender_image_lanczos(work, maps_max_res, is_srgb=False, is_normal=(img in normal_imgs))
            out_png = os.path.join(tmpdir, f"{img.name}_map.png")
            work.filepath_raw = out_png
            work.file_format = "PNG"
            work.save()
            bpy.data.images.remove(work)
            new_img = bpy.data.images.load(out_png, check_existing=False)
            new_img.name = f"{img.name}_packed"
            new_img.colorspace_settings.name = "Non-Color"
            new_img.pack()
            remap[img] = new_img

    for mat in bpy.data.materials:
        if not mat.node_tree:
            continue
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image in remap:
                n.image = remap[n.image]

    for old_img in list(remap.keys()):
        if old_img.users == 0:
            bpy.data.images.remove(old_img)


def _measure_scorpion_anatomy(body: bpy.types.Object, height: float) -> dict:
    pts = _vertices_godot_np(body)
    min_x, max_x = float(pts[:, 0].min()), float(pts[:, 0].max())
    min_y, max_y = float(pts[:, 1].min()), float(pts[:, 1].max())
    min_z, max_z = float(pts[:, 2].min()), float(pts[:, 2].max())

    W = max(0.4 * height, max_x - min_x)
    H = max(1e-4, max_y - min_y)
    L = max(0.6 * height, max_z - min_z)

    # Core carapace band near sagittal plane and lower-mid elevation.
    core_mask = (np.abs(pts[:, 0]) <= 0.16 * W) & (pts[:, 1] >= 0.08 * H) & (pts[:, 1] <= 0.50 * H)
    core_pts = pts[core_mask]
    if len(core_pts) >= 24:
        body_y = float(np.median(core_pts[:, 1]))
        body_y = max(0.18 * H, min(0.36 * H, body_y))
        carapace_top_y = float(np.percentile(core_pts[:, 1], 95))
        core_z_min = float(np.percentile(core_pts[:, 2], 8))
        core_z_max = float(np.percentile(core_pts[:, 2], 92))
    else:
        body_y = 0.27 * H
        carapace_top_y = 0.40 * H
        core_z_min = -0.30 * L
        core_z_max = 0.24 * L

    body_z_center = max(-0.12 * L, min(0.12 * L, 0.5 * (core_z_min + core_z_max)))
    head_z_front = max(body_z_center + 0.12 * L, min(max_z - 0.12 * L, core_z_max))
    abd_z_rear = min(body_z_center - 0.12 * L, max(min_z + 0.05 * L, core_z_min))

    body_head = Vector((0.0, body_y, body_z_center - 0.05 * L))
    body_tail = Vector((0.0, body_y, body_z_center + 0.08 * L))
    head_tail = Vector((0.0, body_y + 0.02 * H, head_z_front))
    abd_tail = Vector((0.0, body_y + 0.05 * H, abd_z_rear))

    # Trace arched tail centerline in YZ via polar sweep around an interior arch center.
    z_c = 0.5 * (abd_z_rear + body_z_center) + 0.04 * L
    y_c = body_y + 0.26 * H
    tail_mask = (
        (np.abs(pts[:, 0]) <= 0.15 * W)
        & ((pts[:, 1] >= max(carapace_top_y + 0.03 * H, body_y + 0.14 * H)) | (pts[:, 2] <= abd_z_rear + 0.03 * L))
        & ~((pts[:, 1] < 0.62 * H) & (pts[:, 2] > head_z_front))
    )
    tail_pts = pts[tail_mask]

    p0 = abd_tail.copy()
    ang0 = math.atan2(p0.y - y_c, -(p0.z - z_c))
    # Analytical fallback C-arch in case sculpted tail vertices are sparse in any slice.
    rx_fallback = max(0.24 * L, z_c - min_z - 0.04 * L)
    ry_fallback = max(0.32 * H, H - y_c - 0.04 * H)

    def _fallback_arch_pt(frac: float) -> Vector:
        ang = ang0 + frac * (2.55 - ang0)
        py = max(body_y + 0.05 * H, min(H - 0.02 * H, y_c + math.sin(ang) * ry_fallback))
        pz = z_c - math.cos(ang) * rx_fallback
        return Vector((0.0, py, pz))

    tail_chain: list[Vector] = [p0]
    if len(tail_pts) >= 24:
        angs = np.arctan2(tail_pts[:, 1] - y_c, -(tail_pts[:, 2] - z_c))
        valid_tail = (angs >= ang0 - 0.15) & (angs <= 2.98)
        t_pts = tail_pts[valid_tail]
        t_angs = angs[valid_tail]
        if len(t_pts) >= 16:
            ang_max = max(ang0 + 1.1, float(np.percentile(t_angs, 98.5)))
            stations = [0.20, 0.42, 0.64, 0.84, 1.00]
            half_win = 0.13 * (ang_max - ang0)
            for idx, frac in enumerate(stations):
                target_ang = ang0 + frac * (ang_max - ang0)
                if idx == len(stations) - 1:
                    sub = t_pts[t_angs >= ang_max - 0.14]
                else:
                    sub = t_pts[np.abs(t_angs - target_ang) <= half_win]
                if len(sub) >= 4:
                    py = float(np.median(sub[:, 1]))
                    pz = float(np.median(sub[:, 2]))
                    tail_chain.append(Vector((0.0, py, pz)))
                else:
                    tail_chain.append(_fallback_arch_pt(frac))
        else:
            for frac in (0.20, 0.42, 0.64, 0.84, 1.00):
                tail_chain.append(_fallback_arch_pt(frac))
    else:
        for frac in (0.20, 0.42, 0.64, 0.84, 1.00):
            tail_chain.append(_fallback_arch_pt(frac))

    # Enforce strictly non-degenerate tail segment lengths.
    min_seg = 0.06 * H
    for i in range(1, len(tail_chain)):
        seg = tail_chain[i] - tail_chain[i - 1]
        if seg.length < min_seg:
            fb = _fallback_arch_pt(i / 5.0)
            d = fb - tail_chain[i - 1]
            if d.length < min_seg:
                d = Vector((0.0, min_seg, 0.0))
            tail_chain[i] = tail_chain[i - 1] + d.normalized() * min_seg

    # Measure adaptive elevation gap between dorsal carapace and overhanging upper tail/stinger.
    over_tail = tail_pts[tail_pts[:, 2] > abd_z_rear + 0.03 * L] if len(tail_pts) > 0 else np.empty((0, 3))
    if len(over_tail) >= 8:
        over_low_y = float(np.percentile(over_tail[:, 1], 10))
        y_tail_clear = 0.5 * (carapace_top_y + over_low_y)
    else:
        y_tail_clear = carapace_top_y + 0.08 * H
    y_tail_clear = max(body_y + 0.14 * H, min(0.58 * H, y_tail_clear))

    # Measure front pincers bilaterally and symmetrize.
    def _measure_pincer(sign: float) -> tuple[Vector, Vector, Vector]:
        p_mask = (
            (sign * pts[:, 0] >= 0.07 * W)
            & (pts[:, 2] >= head_z_front - 0.08 * L)
            & (pts[:, 1] <= 0.68 * H)
        )
        p_pts = pts[p_mask]
        base_def = Vector((0.14 * W, body_y + 0.01 * H, head_z_front - 0.02 * L))
        mid_def = Vector((0.34 * W, body_y + 0.03 * H, head_z_front + 0.42 * (max_z - head_z_front)))
        tip_def = Vector((0.26 * W, body_y + 0.05 * H, max_z - 0.02 * L))
        if len(p_pts) < 16:
            return base_def, mid_def, tip_def

        p_z_max = float(np.percentile(p_pts[:, 2], 97))
        p_span = max(0.10 * L, p_z_max - head_z_front)
        tip_sub = p_pts[p_pts[:, 2] >= p_z_max - 0.16 * p_span]
        mid_sub = p_pts[
            (p_pts[:, 2] >= head_z_front + 0.30 * p_span)
            & (p_pts[:, 2] <= head_z_front + 0.62 * p_span)
        ]
        tip_pt = (
            Vector((float(np.median(np.abs(tip_sub[:, 0]))), float(np.median(tip_sub[:, 1])), float(np.median(tip_sub[:, 2]))))
            if len(tip_sub) >= 6
            else tip_def
        )
        mid_pt = (
            Vector((float(np.percentile(np.abs(mid_sub[:, 0]), 65)), float(np.median(mid_sub[:, 1])), float(np.median(mid_sub[:, 2]))))
            if len(mid_sub) >= 6
            else mid_def
        )
        base_x = max(0.10 * W, min(0.22 * W, mid_pt.x * 0.48))
        base_pt = Vector((base_x, body_y + 0.01 * H, head_z_front - 0.02 * L))
        return base_pt, mid_pt, tip_pt

    pl_b, pl_m, pl_t = _measure_pincer(1.0)
    pr_b, pr_m, pr_t = _measure_pincer(-1.0)
    pincer_base = 0.5 * (pl_b + pr_b)
    pincer_mid = 0.5 * (pl_m + pr_m)
    pincer_tip = 0.5 * (pl_t + pr_t)
    if (pincer_mid - pincer_base).length < 0.06 * H:
        pincer_mid = pincer_base + Vector((0.18 * W, 0.02 * H, 0.14 * L))
    if (pincer_tip - pincer_mid).length < 0.06 * H:
        pincer_tip = pincer_mid + Vector((-0.06 * W, 0.02 * H, 0.18 * L))

    # Measure 4 symmetric lateral leg pairs spanning Z from front to rear thorax.
    leg_z_front = head_z_front - 0.04 * L
    leg_z_rear = abd_z_rear + 0.02 * L
    if leg_z_front <= leg_z_rear + 0.12 * L:
        leg_z_front = body_z_center + 0.16 * L
        leg_z_rear = body_z_center - 0.18 * L

    leg_band = pts[
        (np.abs(pts[:, 0]) >= 0.16 * W)
        & (pts[:, 1] <= 0.45 * H)
        & (pts[:, 2] >= leg_z_rear - 0.14 * L)
        & (pts[:, 2] <= leg_z_front + 0.08 * L)
    ]
    z_splay_offsets = [0.09 * L, 0.03 * L, -0.04 * L, -0.11 * L]
    x_reach_defaults = [0.44 * W, 0.48 * W, 0.48 * W, 0.42 * W]
    legs_sym: list[tuple[Vector, Vector]] = []
    for i in range(4):
        frac = i / 3.0
        hip_z = leg_z_front + frac * (leg_z_rear - leg_z_front)
        hip_x = (0.14 + 0.02 * math.sin(frac * math.pi)) * W
        hip_pt = Vector((hip_x, max(0.14 * H, body_y - 0.02 * H), hip_z))

        # Slice lateral leg points near expected outer foot Z position.
        exp_z = hip_z + z_splay_offsets[i]
        slice_half = 0.09 * L
        sl = leg_band[np.abs(leg_band[:, 2] - exp_z) <= slice_half] if len(leg_band) > 0 else np.empty((0, 3))
        if len(sl) >= 10:
            abs_x = np.abs(sl[:, 0])
            x_thresh = float(np.percentile(abs_x, 72))
            outer = sl[abs_x >= x_thresh]
            tip_x = max(hip_x + 0.16 * W, min(0.52 * W, float(np.median(np.abs(outer[:, 0])))))
            tip_y = max(0.02 * H, min(0.12 * H, float(np.percentile(outer[:, 1], 25))))
            tip_z = float(np.median(outer[:, 2]))
        else:
            tip_x = x_reach_defaults[i]
            tip_y = 0.03 * H
            tip_z = exp_z

        tip_pt = Vector((tip_x, tip_y, tip_z))
        legs_sym.append((hip_pt, tip_pt))

    return {
        "W": W,
        "H": H,
        "L": L,
        "body_y": body_y,
        "head_z_front": head_z_front,
        "abd_z_rear": abd_z_rear,
        "y_tail_clear": y_tail_clear,
        "body_head": body_head,
        "body_tail": body_tail,
        "head_tail": head_tail,
        "abd_tail": abd_tail,
        "tail_chain": tail_chain,
        "pincer_base": pincer_base,
        "pincer_mid": pincer_mid,
        "pincer_tip": pincer_tip,
        "legs_sym": legs_sym,
    }


def _build_scorpion_armature(lm: dict, name: str = "Armature") -> bpy.types.Object:
    H = lm["H"]
    pb = lm["pincer_base"]
    pm = lm["pincer_mid"]
    pt = lm["pincer_tip"]
    tc = lm["tail_chain"]
    legs = lm["legs_sym"]

    bone_coords: dict[str, tuple[tuple[float, float, float], tuple[float, float, float]]] = {
        "root": ((0.0, 0.0, 0.0), (0.0, 0.14 * H, 0.0)),
        "body": (tuple(lm["body_head"]), tuple(lm["body_tail"])),
        "head": (tuple(lm["body_tail"]), tuple(lm["head_tail"])),
        "abdomen": (tuple(lm["body_head"]), tuple(lm["abd_tail"])),
        "pincer_l_0": ((pb.x, pb.y, pb.z), (pm.x, pm.y, pm.z)),
        "pincer_l_1": ((pm.x, pm.y, pm.z), (pt.x, pt.y, pt.z)),
        "pincer_r_0": ((-pb.x, pb.y, pb.z), (-pm.x, pm.y, pm.z)),
        "pincer_r_1": ((-pm.x, pm.y, pm.z), (-pt.x, pt.y, pt.z)),
        "tail_0": (tuple(tc[0]), tuple(tc[1])),
        "tail_1": (tuple(tc[1]), tuple(tc[2])),
        "tail_2": (tuple(tc[2]), tuple(tc[3])),
        "tail_3": (tuple(tc[3]), tuple(tc[4])),
        "stinger": (tuple(tc[4]), tuple(tc[5])),
    }
    for i, (hip_pt, tip_pt) in enumerate(legs):
        bone_coords[f"leg_l_{i}"] = ((hip_pt.x, hip_pt.y, hip_pt.z), (tip_pt.x, tip_pt.y, tip_pt.z))
        bone_coords[f"leg_r_{i}"] = ((-hip_pt.x, hip_pt.y, hip_pt.z), (-tip_pt.x, tip_pt.y, tip_pt.z))

    arm_data = bpy.data.armatures.new(f"{name}Data")
    arm_obj = bpy.data.objects.new(name, arm_data)
    bpy.context.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")

    created: dict[str, bpy.types.EditBone] = {}
    for bname, parent_name in SCORPION_HIERARCHY:
        head_gd, tail_gd = bone_coords[bname]
        eb = arm_data.edit_bones.new(bname)
        eb.head = godot_to_blender(*head_gd)
        eb.tail = godot_to_blender(*tail_gd)
        if (eb.tail - eb.head).length < 0.02:
            eb.tail = eb.head + Vector((0.0, 0.0, 0.05))
        eb.use_deform = True
        if parent_name is not None:
            eb.parent = created[parent_name]
        eb.use_connect = False
        b_dir = (eb.tail - eb.head).normalized()
        ref_up = Vector((0.0, 0.0, 1.0)) if abs(b_dir.z) < 0.92 else Vector((0.0, -1.0, 0.0))
        eb.align_roll(ref_up)
        created[bname] = eb

    bpy.ops.object.mode_set(mode="OBJECT")
    for pbone in arm_obj.pose.bones:
        pbone.rotation_mode = "QUATERNION"
    return arm_obj


def _bind_scorpion_weights(body: bpy.types.Object, arm_obj: bpy.types.Object, lm: dict) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    arm_obj.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.parent_set(type="ARMATURE_NAME")

    vg_map: dict[str, bpy.types.VertexGroup] = {}
    for bname, _ in SCORPION_HIERARCHY:
        vg = body.vertex_groups.get(bname)
        if vg is None:
            vg = body.vertex_groups.new(name=bname)
        vg_map[bname] = vg

    W, H, L = lm["W"], lm["H"], lm["L"]
    head_z_front = lm["head_z_front"]
    abd_z_rear = lm["abd_z_rear"]
    y_tail_clear = lm["y_tail_clear"]

    # Build segment endpoints and anatomical radii in Godot space for the 20 deforming bones.
    seg_a = np.zeros((len(DEFORM_BONES), 3), dtype=np.float64)
    seg_b = np.zeros((len(DEFORM_BONES), 3), dtype=np.float64)
    sigmas = np.zeros(len(DEFORM_BONES), dtype=np.float64)

    is_left = np.zeros(len(DEFORM_BONES), dtype=bool)
    is_right = np.zeros(len(DEFORM_BONES), dtype=bool)
    is_core = np.zeros(len(DEFORM_BONES), dtype=bool)
    is_tail = np.zeros(len(DEFORM_BONES), dtype=bool)
    is_upper_tail = np.zeros(len(DEFORM_BONES), dtype=bool)
    is_pincer_tip = np.zeros(len(DEFORM_BONES), dtype=bool)
    is_rear_leg = np.zeros(len(DEFORM_BONES), dtype=bool)
    is_abdomen = np.zeros(len(DEFORM_BONES), dtype=bool)

    for bi, bname in enumerate(DEFORM_BONES):
        bone = arm_obj.data.bones[bname]
        a_gd = blender_to_godot(bone.head_local)
        b_gd = blender_to_godot(bone.tail_local)
        seg_a[bi] = (a_gd.x, a_gd.y, a_gd.z)
        seg_b[bi] = (b_gd.x, b_gd.y, b_gd.z)

        if bname in ("body", "head", "abdomen"):
            sigmas[bi] = 0.115 * H
            is_core[bi] = True
            if bname == "abdomen":
                is_abdomen[bi] = True
        elif bname.startswith("tail_") or bname == "stinger":
            sigmas[bi] = 0.068 * H
            is_tail[bi] = True
            if bname != "tail_0":
                is_upper_tail[bi] = True
        elif bname.startswith("pincer_"):
            sigmas[bi] = 0.075 * H
            if bname.startswith("pincer_l"):
                is_left[bi] = True
            else:
                is_right[bi] = True
            if bname.endswith("_1"):
                is_pincer_tip[bi] = True
        elif bname.startswith("leg_"):
            sigmas[bi] = 0.052 * H
            if bname.startswith("leg_l"):
                is_left[bi] = True
            else:
                is_right[bi] = True
            if not bname.endswith("_0"):
                is_rear_leg[bi] = True

    pts = _vertices_godot_np(body)
    n_verts = len(pts)

    ab = seg_b - seg_a
    ab_len_sq = np.maximum(np.sum(ab * ab, axis=1), 1e-10)
    ap = pts[:, None, :] - seg_a[None, :, :]
    t = np.clip(np.sum(ap * ab[None, :, :], axis=2) / ab_len_sq[None, :], 0.0, 1.0)
    proj = seg_a[None, :, :] + t[:, :, None] * ab[None, :, :]
    dist = np.sqrt(np.sum((pts[:, None, :] - proj) ** 2, axis=2))

    # Build anatomical isolation mask so overhanging stinger never pulls dorsal carapace and sides never cross-bleed.
    eligible = np.ones((n_verts, len(DEFORM_BONES)), dtype=bool)
    eligible[(pts[:, 0] > 0.02 * W)[:, None] & is_right[None, :]] = False
    eligible[(pts[:, 0] < -0.02 * W)[:, None] & is_left[None, :]] = False

    d_tail_min = dist[:, is_tail].min(axis=1)
    d_core_min = dist[:, is_core].min(axis=1)
    elevated_tail = (pts[:, 1] >= y_tail_clear) & (np.abs(pts[:, 0]) <= 0.24 * W) & (d_tail_min < d_core_min * 1.40)
    high_tail = elevated_tail & (pts[:, 1] >= y_tail_clear + 0.08 * H)

    eligible[elevated_tail[:, None] & (~is_tail & ~is_abdomen)[None, :]] = False
    eligible[high_tail[:, None] & is_abdomen[None, :]] = False

    lower_front = (pts[:, 1] < y_tail_clear) & (pts[:, 2] > abd_z_rear + 0.03 * L)
    eligible[lower_front[:, None] & is_upper_tail[None, :]] = False

    behind_pincers = pts[:, 2] < head_z_front - 0.06 * L
    eligible[behind_pincers[:, None] & is_pincer_tip[None, :]] = False

    in_front_of_legs = pts[:, 2] > head_z_front + 0.04 * L
    eligible[in_front_of_legs[:, None] & is_rear_leg[None, :]] = False

    u = dist / sigmas[None, :]
    raw_w = 1.0 / np.power(u * u + 0.04, 2.2)
    masked_w = np.where(eligible, raw_w, 0.0)

    # Fallback to unmasked segment distance if any vertex had all candidates masked out.
    zero_rows = masked_w.sum(axis=1) <= 1e-12
    if np.any(zero_rows):
        masked_w[zero_rows] = raw_w[zero_rows]

    # Top-4 bone influences per vertex, pruned of noise < 2.5% of primary weight, strictly normalized.
    vgroups = [vg_map[bname] for bname in DEFORM_BONES]
    for vi in range(n_verts):
        row = masked_w[vi]
        top_idx = np.argpartition(row, -4)[-4:]
        top_idx = top_idx[np.argsort(row[top_idx])[::-1]]
        w_max = float(row[top_idx[0]])
        chosen: list[tuple[int, float]] = []
        for bi in top_idx:
            wv = float(row[bi])
            if wv > 1e-8 and (not chosen or wv >= 0.025 * w_max):
                chosen.append((int(bi), wv))
        if not chosen:
            best_bi = int(np.argmin(dist[vi]))
            chosen = [(best_bi, 1.0)]
        tot = sum(w for _, w in chosen)
        for bi, wv in chosen:
            vgroups[bi].add([vi], wv / tot, "REPLACE")

    print(f"[rig_ash_scorpion] Bound anatomical segment weights across {n_verts} verts and {len(DEFORM_BONES)} deform bones")


def _gd_euler_quat(pitch_x_deg: float = 0.0, yaw_y_deg: float = 0.0, roll_z_deg: float = 0.0) -> Quaternion:
    q_gd = Euler(
        (math.radians(pitch_x_deg), math.radians(yaw_y_deg), math.radians(roll_z_deg)),
        "YXZ",
    ).to_quaternion()
    axis_gd, ang = q_gd.to_axis_angle()
    axis_bl = godot_to_blender(axis_gd.x, axis_gd.y, axis_gd.z)
    if axis_bl.length < 1e-6:
        return Quaternion((1.0, 0.0, 0.0, 0.0))
    return Quaternion(axis_bl.normalized(), ang)


def _set_anat_rot(
    arm_obj: bpy.types.Object,
    bone_name: str,
    pitch_x_deg: float = 0.0,
    yaw_y_deg: float = 0.0,
    roll_z_deg: float = 0.0,
) -> None:
    pb = arm_obj.pose.bones[bone_name]
    q_rest = pb.bone.matrix_local.to_3x3().to_quaternion()
    q_anat = _gd_euler_quat(pitch_x_deg, yaw_y_deg, roll_z_deg)
    pb.rotation_quaternion = q_rest.inverted() @ q_anat @ q_rest


def _set_body_offset_gd(arm_obj: bpy.types.Object, dx: float, dy: float, dz: float) -> None:
    pb = arm_obj.pose.bones["body"]
    q_rest = pb.bone.matrix_local.to_3x3().to_quaternion()
    v_bl = godot_to_blender(dx, dy, dz)
    pb.location = q_rest.inverted() @ v_bl


def _reset_pose(arm_obj: bpy.types.Object) -> None:
    for pb in arm_obj.pose.bones:
        pb.location = (0.0, 0.0, 0.0)
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)


def _key_all_bones(arm_obj: bpy.types.Object, frame: int) -> None:
    for pb in arm_obj.pose.bones:
        if pb.name in ("root", "body"):
            pb.keyframe_insert(data_path="location", frame=frame)
        pb.keyframe_insert(data_path="rotation_quaternion", frame=frame)


def _smoothstep(t: float) -> float:
    x = max(0.0, min(1.0, t))
    return x * x * (3.0 - 2.0 * x)


def _lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def _lerp3(a: tuple[float, float, float], b: tuple[float, float, float], t: float) -> tuple[float, float, float]:
    return (_lerp(a[0], b[0], t), _lerp(a[1], b[1], t), _lerp(a[2], b[2], t))


def _apply_scorpion_pose(arm_obj: bpy.types.Object, clip: str, u: float, height: float) -> None:
    _reset_pose(arm_obj)
    tau = 2.0 * math.pi

    body_off = (0.0, 0.0, 0.0)
    body_rot = (0.0, 0.0, 0.0)
    head_rot = (0.0, 0.0, 0.0)
    abd_rot = (0.0, 0.0, 0.0)
    pl0 = (-6.0, 4.0, 0.0)
    pl1 = (-4.0, -6.0, 0.0)
    pr0 = (-6.0, -4.0, 0.0)
    pr1 = (-4.0, 6.0, 0.0)
    tail_rots = [(0.0, 0.0, 0.0)] * 5  # tail_0, tail_1, tail_2, tail_3, stinger
    leg_l_rots = [(0.0, 0.0, 0.0)] * 4
    leg_r_rots = [(0.0, 0.0, 0.0)] * 4

    if clip == "idle":
        s1 = math.sin(tau * u)
        c1 = math.cos(tau * u)
        s2 = math.sin(2.0 * tau * u)
        body_off = (0.0, 0.016 * height * s1, 0.0)
        body_rot = (2.2 * s1, 1.8 * c1, 1.2 * s1)
        head_rot = (-3.0 + 2.5 * s1, 4.5 * s1, 0.0)
        abd_rot = (2.5 * s1, -2.0 * s1, 0.0)

        pl0 = (-8.0 + 4.5 * s1, 6.0 + 5.0 * c1, 2.5 * s1)
        pl1 = (-5.0 + 3.5 * s1, -8.0 - 6.0 * c1, 0.0)
        pr0 = (-8.0 - 4.5 * s1, -6.0 + 5.0 * c1, -2.5 * s1)
        pr1 = (-5.0 - 3.5 * s1, 8.0 - 6.0 * c1, 0.0)

        for i in range(5):
            ph = tau * u - i * 0.48
            pitch = (3.5 + 1.4 * i) * math.sin(ph)
            yaw = (2.5 + 1.1 * i) * math.cos(ph)
            roll = 2.0 * s2 if i == 4 else 0.0
            tail_rots[i] = (pitch, yaw, roll)

        leg_comp = -4.0 * s1
        for i in range(4):
            leg_l_rots[i] = (0.0, 0.0, leg_comp)
            leg_r_rots[i] = (0.0, 0.0, -leg_comp)

    elif clip == "walkForward":
        s1 = math.sin(tau * u)
        c1 = math.cos(tau * u)
        s2 = math.sin(2.0 * tau * u)
        body_off = (0.0, 0.022 * height * abs(s1), 0.012 * height * s2)
        body_rot = (3.5 + 2.5 * s2, 5.5 * s1, 3.8 * c1)
        head_rot = (-3.0, -4.5 * s1, -2.5 * c1)
        abd_rot = (3.0 * s2, -4.5 * s1, -2.0 * c1)

        pl0 = (-4.0 + 4.0 * s1, 4.0 - 7.0 * s1, 2.0 * c1)
        pl1 = (-2.0, -8.0 + 4.0 * c1, 0.0)
        pr0 = (-4.0 - 4.0 * s1, -4.0 - 7.0 * s1, -2.0 * c1)
        pr1 = (-2.0, 8.0 - 4.0 * c1, 0.0)

        for i in range(5):
            ph = tau * u - i * 0.40
            tail_rots[i] = (4.0 * math.sin(2.0 * ph), -5.0 * math.sin(ph), 2.5 * math.cos(ph))

        # Alternating arachnid tetrapod gait: (L0, R1, L2, R3) vs (R0, L1, R2, L3).
        for i in range(4):
            ph_l = u if (i % 2 == 0) else (u + 0.5) % 1.0
            ph_r = (u + 0.5) % 1.0 if (i % 2 == 0) else u

            # -cos sweeps backward->forward while lifted (ph in [0, 0.5]) and pushes backward on stance (ph in [0.5, 1]).
            stride_l = -math.cos(tau * ph_l)
            lift_l = max(0.0, math.sin(tau * ph_l))
            # Left leg (+X): -yaw swings forward (+Z), +roll lifts foot (+Y).
            leg_l_rots[i] = (3.0 * lift_l, -18.0 * stride_l, 17.0 * lift_l)

            stride_r = -math.cos(tau * ph_r)
            lift_r = max(0.0, math.sin(tau * ph_r))
            # Right leg (-X): +yaw swings forward (+Z), -roll lifts foot (+Y).
            leg_r_rots[i] = (3.0 * lift_r, 18.0 * stride_r, -17.0 * lift_r)

    elif clip in ("clawAttackLeft", "clawAttackRight"):
        # Mirror cleanly across X for right pincer strike; +yaw pulls left (+X) shoulder back, -yaw whips it forward.
        sgn = 1.0 if clip == "clawAttackLeft" else -1.0
        if u < 0.34:
            k = _smoothstep(u / 0.34)
            body_off = (0.0, _lerp(0.0, -0.025 * height, k), _lerp(0.0, -0.08 * height, k))
            body_rot = (_lerp(0.0, -8.0, k), _lerp(0.0, 16.0 * sgn, k), _lerp(0.0, 6.0 * sgn, k))
            head_rot = (_lerp(0.0, -6.0, k), _lerp(0.0, 8.0 * sgn, k), 0.0)
            atk0 = _lerp3((-6.0, 4.0 * sgn, 0.0), (-28.0, 30.0 * sgn, 14.0 * sgn), k)
            atk1 = _lerp3((-4.0, -6.0 * sgn, 0.0), (-14.0, 22.0 * sgn, 0.0), k)
            off0 = _lerp3((-6.0, -4.0 * sgn, 0.0), (4.0, -14.0 * sgn, -4.0 * sgn), k)
            off1 = _lerp3((-4.0, 6.0 * sgn, 0.0), (4.0, 12.0 * sgn, 0.0), k)
            tail_pitch = _lerp(0.0, -8.0, k)
            tail_yaw = _lerp(0.0, -10.0 * sgn, k)
        elif u < 0.56:
            k = _smoothstep((u - 0.34) / 0.22)
            body_off = (0.0, _lerp(-0.025 * height, -0.01 * height, k), _lerp(-0.08 * height, 0.16 * height, k))
            body_rot = (_lerp(-8.0, 10.0, k), _lerp(16.0 * sgn, -22.0 * sgn, k), _lerp(6.0 * sgn, -8.0 * sgn, k))
            head_rot = (_lerp(-6.0, 8.0, k), _lerp(8.0 * sgn, -12.0 * sgn, k), 0.0)
            atk0 = _lerp3((-28.0, 30.0 * sgn, 14.0 * sgn), (14.0, -38.0 * sgn, -12.0 * sgn), k)
            atk1 = _lerp3((-14.0, 22.0 * sgn, 0.0), (12.0, -34.0 * sgn, 0.0), k)
            off0 = _lerp3((4.0, -14.0 * sgn, -4.0 * sgn), (-10.0, -20.0 * sgn, -8.0 * sgn), k)
            off1 = _lerp3((4.0, 12.0 * sgn, 0.0), (-6.0, 16.0 * sgn, 0.0), k)
            tail_pitch = _lerp(-8.0, 11.0, k)
            tail_yaw = _lerp(-10.0 * sgn, 14.0 * sgn, k)
        else:
            k = _smoothstep((u - 0.56) / 0.44)
            body_off = (0.0, _lerp(-0.01 * height, 0.0, k), _lerp(0.16 * height, 0.0, k))
            body_rot = (_lerp(10.0, 0.0, k), _lerp(-22.0 * sgn, 0.0, k), _lerp(-8.0 * sgn, 0.0, k))
            head_rot = (_lerp(8.0, 0.0, k), _lerp(-12.0 * sgn, 0.0, k), 0.0)
            atk0 = _lerp3((14.0, -38.0 * sgn, -12.0 * sgn), (-6.0, 4.0 * sgn, 0.0), k)
            atk1 = _lerp3((12.0, -34.0 * sgn, 0.0), (-4.0, -6.0 * sgn, 0.0), k)
            off0 = _lerp3((-10.0, -20.0 * sgn, -8.0 * sgn), (-6.0, -4.0 * sgn, 0.0), k)
            off1 = _lerp3((-6.0, 16.0 * sgn, 0.0), (-4.0, 6.0 * sgn, 0.0), k)
            tail_pitch = _lerp(11.0, 0.0, k)
            tail_yaw = _lerp(14.0 * sgn, 0.0, k)

        if clip == "clawAttackLeft":
            pl0, pl1, pr0, pr1 = atk0, atk1, off0, off1
        else:
            pr0, pr1, pl0, pl1 = atk0, atk1, off0, off1

        abd_rot = (0.4 * tail_pitch, 0.4 * tail_yaw, 0.0)
        for i in range(5):
            tail_rots[i] = (tail_pitch * (0.7 + 0.15 * i), tail_yaw * (0.6 + 0.12 * i), 0.0)
        for i in range(4):
            brace = -body_rot[1] * 0.45
            leg_l_rots[i] = (0.0, brace, 4.0 if i == 0 else 0.0)
            leg_r_rots[i] = (0.0, brace, -4.0 if i == 0 else 0.0)

    elif clip == "stingerAttack":
        # Telegraph coil-back -> explosive overhead tail whip forward -> hold -> recovery.
        if u < 0.40:
            k = _smoothstep(u / 0.40)
            body_off = (0.0, _lerp(0.0, 0.048 * height, k), _lerp(0.0, -0.10 * height, k))
            body_rot = (_lerp(0.0, -15.0, k), 0.0, 0.0)
            head_rot = (_lerp(0.0, -10.0, k), 0.0, 0.0)
            abd_rot = (_lerp(0.0, -10.0, k), 0.0, 0.0)
            pl0 = _lerp3((-6.0, 4.0, 0.0), (-22.0, 26.0, 10.0), k)
            pl1 = _lerp3((-4.0, -6.0, 0.0), (-12.0, 12.0, 0.0), k)
            pr0 = _lerp3((-6.0, -4.0, 0.0), (-22.0, -26.0, -10.0), k)
            pr1 = _lerp3((-4.0, 6.0, 0.0), (-12.0, -12.0, 0.0), k)
            coil = [-12.0, -15.0, -16.0, -14.0, -10.0]
            tail_rots = [(_lerp(0.0, c, k), 0.0, 0.0) for c in coil]
            leg_l_rots[0] = (0.0, -12.0 * k, 18.0 * k)
            leg_r_rots[0] = (0.0, 12.0 * k, -18.0 * k)
        elif u < 0.62:
            k = _smoothstep((u - 0.40) / 0.22)
            body_off = (0.0, _lerp(0.048 * height, -0.042 * height, k), _lerp(-0.10 * height, 0.20 * height, k))
            body_rot = (_lerp(-15.0, 12.0, k), 0.0, 0.0)
            head_rot = (_lerp(-10.0, 8.0, k), 0.0, 0.0)
            abd_rot = (_lerp(-10.0, 12.0, k), 0.0, 0.0)
            pl0 = _lerp3((-22.0, 26.0, 10.0), (10.0, 22.0, -6.0), k)
            pl1 = _lerp3((-12.0, 12.0, 0.0), (6.0, -8.0, 0.0), k)
            pr0 = _lerp3((-22.0, -26.0, -10.0), (10.0, -22.0, 6.0), k)
            pr1 = _lerp3((-12.0, -12.0, 0.0), (6.0, 8.0, 0.0), k)
            coil = [-12.0, -15.0, -16.0, -14.0, -10.0]
            whip = [22.0, 28.0, 30.0, 26.0, 22.0]
            tail_rots = [(_lerp(c, w, k), 0.0, 0.0) for c, w in zip(coil, whip)]
            leg_l_rots[0] = (0.0, _lerp(-12.0, 10.0, k), _lerp(18.0, 0.0, k))
            leg_r_rots[0] = (0.0, _lerp(12.0, -10.0, k), _lerp(-18.0, 0.0, k))
        elif u < 0.76:
            k = _smoothstep((u - 0.62) / 0.14)
            body_off = (0.0, _lerp(-0.042 * height, -0.025 * height, k), _lerp(0.20 * height, 0.14 * height, k))
            body_rot = (_lerp(12.0, 8.0, k), 0.0, 0.0)
            head_rot = (_lerp(8.0, 5.0, k), 0.0, 0.0)
            abd_rot = (_lerp(12.0, 8.0, k), 0.0, 0.0)
            pl0 = (10.0, 22.0, -6.0)
            pl1 = (6.0, -8.0, 0.0)
            pr0 = (10.0, -22.0, 6.0)
            pr1 = (6.0, 8.0, 0.0)
            whip = [22.0, 28.0, 30.0, 26.0, 22.0]
            hold = [16.0, 20.0, 22.0, 18.0, 14.0]
            tail_rots = [(_lerp(w, h, k), 0.0, 0.0) for w, h in zip(whip, hold)]
        else:
            k = _smoothstep((u - 0.76) / 0.24)
            body_off = (0.0, _lerp(-0.025 * height, 0.0, k), _lerp(0.14 * height, 0.0, k))
            body_rot = (_lerp(8.0, 0.0, k), 0.0, 0.0)
            head_rot = (_lerp(5.0, 0.0, k), 0.0, 0.0)
            abd_rot = (_lerp(8.0, 0.0, k), 0.0, 0.0)
            pl0 = _lerp3((10.0, 22.0, -6.0), (-6.0, 4.0, 0.0), k)
            pl1 = _lerp3((6.0, -8.0, 0.0), (-4.0, -6.0, 0.0), k)
            pr0 = _lerp3((10.0, -22.0, 6.0), (-6.0, -4.0, 0.0), k)
            pr1 = _lerp3((6.0, 8.0, 0.0), (-4.0, 6.0, 0.0), k)
            hold = [16.0, 20.0, 22.0, 18.0, 14.0]
            tail_rots = [(_lerp(h, 0.0, k), 0.0, 0.0) for h in hold]

    elif clip == "jump":
        # Crouch anticipation -> forward pounce lunge -> landing cushion.
        if u < 0.22:
            k = _smoothstep(u / 0.22)
            body_off = (0.0, _lerp(0.0, -0.068 * height, k), _lerp(0.0, -0.08 * height, k))
            body_rot = (_lerp(0.0, -10.0, k), 0.0, 0.0)
            head_rot = (_lerp(0.0, 6.0, k), 0.0, 0.0)
            pl0 = _lerp3((-6.0, 4.0, 0.0), (8.0, 18.0, 0.0), k)
            pr0 = _lerp3((-6.0, -4.0, 0.0), (8.0, -18.0, 0.0), k)
            tail_rots = [(_lerp(0.0, -9.0, k), 0.0, 0.0)] * 5
            for i in range(4):
                leg_l_rots[i] = (0.0, 8.0 * k, 16.0 * k)
                leg_r_rots[i] = (0.0, -8.0 * k, -16.0 * k)
        elif u < 0.70:
            t_air = (u - 0.22) / 0.48
            arc = math.sin(math.pi * t_air)
            k = _smoothstep(t_air)
            body_off = (0.0, -0.068 * height * (1.0 - arc) + 0.22 * height * arc, _lerp(-0.08 * height, 0.22 * height, k))
            body_rot = (_lerp(-14.0, 12.0, k), 0.0, 0.0)
            head_rot = (-6.0 * arc, 0.0, 0.0)
            abd_rot = (-8.0 * arc, 0.0, 0.0)
            pl0 = (-12.0 * arc, -10.0 * arc, 6.0 * arc)
            pl1 = (-6.0 * arc, -14.0 * arc, 0.0)
            pr0 = (-12.0 * arc, 10.0 * arc, -6.0 * arc)
            pr1 = (-6.0 * arc, 14.0 * arc, 0.0)
            tail_rots = [(-12.0 * arc, 0.0, 0.0)] * 5
            for i in range(4):
                # Sweep legs back & down during midair pounce.
                leg_l_rots[i] = (6.0 * arc, 22.0 * arc, -14.0 * arc)
                leg_r_rots[i] = (6.0 * arc, -22.0 * arc, 14.0 * arc)
        else:
            k = _smoothstep((u - 0.70) / 0.30)
            squash = math.sin(math.pi * k)
            body_off = (0.0, -0.045 * height * squash, _lerp(0.22 * height, 0.0, k))
            body_rot = (_lerp(12.0, 0.0, k), 0.0, 0.0)
            tail_rots = [(10.0 * squash, 0.0, 0.0)] * 5
            for i in range(4):
                leg_l_rots[i] = (0.0, 0.0, 12.0 * squash)
                leg_r_rots[i] = (0.0, 0.0, -12.0 * squash)

    elif clip == "buff1":
        # Brief armored flinch / recoil for hit reaction.
        if u < 0.28:
            k = _smoothstep(u / 0.28)
        else:
            k = 1.0 - _smoothstep((u - 0.28) / 0.72)
        body_off = (0.0, -0.028 * height * k, -0.10 * height * k)
        body_rot = (-14.0 * k, 8.0 * k, 9.0 * k)
        head_rot = (-10.0 * k, -6.0 * k, 0.0)
        abd_rot = (-6.0 * k, 0.0, 0.0)
        pl0 = _lerp3((-6.0, 4.0, 0.0), (-20.0, 22.0, 10.0), k)
        pl1 = _lerp3((-4.0, -6.0, 0.0), (-12.0, 10.0, 0.0), k)
        pr0 = _lerp3((-6.0, -4.0, 0.0), (-16.0, -24.0, -10.0), k)
        pr1 = _lerp3((-4.0, 6.0, 0.0), (-10.0, -12.0, 0.0), k)
        tail_rots = [(-10.0 * k, -6.0 * k, -4.0 * k)] * 5
        for i in range(4):
            leg_l_rots[i] = (0.0, -8.0 * k, 10.0 * k if i < 2 else 0.0)
            leg_r_rots[i] = (0.0, 8.0 * k, -10.0 * k if i < 2 else 0.0)

    elif clip == "death":
        # Shock rear-up -> violent curl-inward arachnid collapse onto floor.
        if u < 0.22:
            k = _smoothstep(u / 0.22)
            body_off = (0.0, 0.038 * height * k, -0.06 * height * k)
            body_rot = (-18.0 * k, 8.0 * k, -8.0 * k)
            head_rot = (-12.0 * k, 0.0, 0.0)
            abd_rot = (-10.0 * k, 0.0, 0.0)
            pl0 = _lerp3((-6.0, 4.0, 0.0), (-26.0, 28.0, 12.0), k)
            pl1 = _lerp3((-4.0, -6.0, 0.0), (-14.0, 14.0, 0.0), k)
            pr0 = _lerp3((-6.0, -4.0, 0.0), (-26.0, -28.0, -12.0), k)
            pr1 = _lerp3((-4.0, 6.0, 0.0), (-14.0, -14.0, 0.0), k)
            tail_rots = [(-14.0 * k, 6.0 * k, 0.0)] * 5
            for i in range(4):
                leg_l_rots[i] = (0.0, -10.0 * k, 18.0 * k)
                leg_r_rots[i] = (0.0, 10.0 * k, -18.0 * k)
        elif u < 0.78:
            k = _smoothstep((u - 0.22) / 0.56)
            body_off = (0.0, _lerp(0.038 * height, -0.145 * height, k), _lerp(-0.06 * height, -0.02 * height, k))
            body_rot = (_lerp(-18.0, 11.0, k), _lerp(8.0, -10.0, k), _lerp(-8.0, 15.0, k))
            head_rot = (_lerp(-12.0, 16.0, k), _lerp(0.0, 8.0, k), 0.0)
            abd_rot = (_lerp(-10.0, 14.0, k), _lerp(0.0, -12.0, k), _lerp(0.0, 16.0, k))
            pl0 = _lerp3((-26.0, 28.0, 12.0), (22.0, -28.0, -16.0), k)
            pl1 = _lerp3((-14.0, 14.0, 0.0), (18.0, -32.0, 0.0), k)
            pr0 = _lerp3((-26.0, -28.0, -12.0), (24.0, 28.0, 16.0), k)
            pr1 = _lerp3((-14.0, -14.0, 0.0), (18.0, 32.0, 0.0), k)
            # Tail collapses sideways & forward onto the ground.
            t_end = [
                (18.0, -10.0, 24.0),
                (22.0, -12.0, 22.0),
                (24.0, -10.0, 18.0),
                (20.0, -8.0, 14.0),
                (16.0, -6.0, 10.0),
            ]
            tail_rots = [_lerp3((-14.0, 6.0, 0.0), te, k) for te in t_end]
            # Dead arachnid legs fold sharply upward and inward.
            for i in range(4):
                curl_y = -14.0 + 9.0 * i
                leg_l_rots[i] = _lerp3((0.0, -10.0, 18.0), (10.0, curl_y, 46.0 + 4.0 * i), k)
                leg_r_rots[i] = _lerp3((0.0, 10.0, -18.0), (10.0, -curl_y, -(46.0 + 4.0 * i)), k)
        else:
            k = _smoothstep((u - 0.78) / 0.22)
            twitch = math.sin(math.pi * k) * 3.0
            body_off = (0.0, -0.145 * height, -0.02 * height)
            body_rot = (11.0, -10.0, 15.0 + 0.5 * twitch)
            head_rot = (16.0, 8.0, 0.0)
            abd_rot = (14.0, -12.0, 16.0)
            pl0 = (22.0, -28.0 + twitch, -16.0)
            pl1 = (18.0, -32.0, 0.0)
            pr0 = (24.0, 28.0 - twitch, 16.0)
            pr1 = (18.0, 32.0, 0.0)
            tail_rots = [
                (18.0, -10.0, 24.0),
                (22.0, -12.0, 22.0),
                (24.0, -10.0, 18.0),
                (20.0, -8.0, 14.0),
                (16.0 + twitch, -6.0, 10.0),
            ]
            for i in range(4):
                curl_y = -14.0 + 9.0 * i
                leg_l_rots[i] = (10.0, curl_y, 46.0 + 4.0 * i + twitch)
                leg_r_rots[i] = (10.0, -curl_y, -(46.0 + 4.0 * i + twitch))

    _set_body_offset_gd(arm_obj, *body_off)
    _set_anat_rot(arm_obj, "body", *body_rot)
    _set_anat_rot(arm_obj, "head", *head_rot)
    _set_anat_rot(arm_obj, "abdomen", *abd_rot)
    _set_anat_rot(arm_obj, "pincer_l_0", *pl0)
    _set_anat_rot(arm_obj, "pincer_l_1", *pl1)
    _set_anat_rot(arm_obj, "pincer_r_0", *pr0)
    _set_anat_rot(arm_obj, "pincer_r_1", *pr1)
    for bname, rot in zip(("tail_0", "tail_1", "tail_2", "tail_3", "stinger"), tail_rots):
        _set_anat_rot(arm_obj, bname, *rot)
    for i in range(4):
        _set_anat_rot(arm_obj, f"leg_l_{i}", *leg_l_rots[i])
        _set_anat_rot(arm_obj, f"leg_r_{i}", *leg_r_rots[i])


def _bake_scorpion_animations(arm_obj: bpy.types.Object, height: float) -> list[str]:
    bpy.context.scene.render.fps = 60
    arm_obj.animation_data_create()
    while len(arm_obj.animation_data.nla_tracks) > 0:
        arm_obj.animation_data.nla_tracks.remove(arm_obj.animation_data.nla_tracks[0])

    # Exact 8 clips mapped by ActorVisual.RIG_CLIP_MAP["ash_scorpion"]: (name, duration_sec, frame_step, is_loop)
    clips: list[tuple[str, float, int, bool]] = [
        ("idle", 1.80, 4, True),
        ("walkForward", 0.56, 2, True),
        ("clawAttackLeft", 0.55, 2, False),
        ("clawAttackRight", 0.55, 2, False),
        ("stingerAttack", 0.72, 2, False),
        ("jump", 0.45, 2, False),
        ("buff1", 0.30, 2, False),
        ("death", 0.90, 3, False),
    ]

    exported_names: list[str] = []
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="POSE")

    for name, dur_sec, step, is_loop in clips:
        total_frames = max(4, round(dur_sec * 60.0))
        act = bpy.data.actions.new(name=name)
        arm_obj.animation_data.action = act

        frames = list(range(1, total_frames + 1, step))
        if frames[-1] != total_frames + 1:
            frames.append(total_frames + 1)

        for f in frames:
            u = min(1.0, max(0.0, (f - 1) / float(total_frames)))
            if is_loop and f == total_frames + 1:
                u = 0.0
            _apply_scorpion_pose(arm_obj, name, u, height)
            _key_all_bones(arm_obj, f)

        # Blender 5.3 NLA slot binding so glTF NLA_TRACKS exports every clip cleanly.
        slot = arm_obj.animation_data.action_slot
        track = arm_obj.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 1, act)
        strip.action_slot = slot
        exported_names.append(name)

    arm_obj.animation_data.action = None
    _reset_pose(arm_obj)
    bpy.ops.object.mode_set(mode="OBJECT")
    return exported_names


def _verify_rig_integrity(arm_obj: bpy.types.Object, mesh_obj: bpy.types.Object) -> dict:
    total_tris = _count_tris(mesh_obj)
    total_verts = len(mesh_obj.data.vertices)
    unweighted = 0
    over_4 = 0
    nan_count = 0

    for v in mesh_obj.data.vertices:
        if not (math.isfinite(v.co.x) and math.isfinite(v.co.y) and math.isfinite(v.co.z)):
            nan_count += 1
        active = [g.weight for g in v.groups if g.weight > 1e-6]
        if any(not math.isfinite(w) for w in active):
            nan_count += 1
        if not active or abs(sum(active) - 1.0) > 1e-3:
            unweighted += 1
        if len(active) > 4:
            over_4 += 1

    if unweighted > 0 or over_4 > 0 or nan_count > 0:
        raise RuntimeError(
            f"Skinning verification failed: unweighted_or_unnorm={unweighted}, over_4_bones={over_4}, nan={nan_count}"
        )

    return {
        "bones": len(arm_obj.data.bones),
        "total_tris": total_tris,
        "total_verts": total_verts,
        "unweighted": unweighted,
        "over_4": over_4,
        "nan_count": nan_count,
    }


def _export_rigged_glb(
    arm_obj: bpy.types.Object,
    mesh_obj: bpy.types.Object,
    output_path: str,
    image_format: str = "WEBP",
    image_quality: int = 90,
) -> int:
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    arm_obj.select_set(True)
    mesh_obj.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj

    bpy.ops.export_scene.gltf(
        filepath=output_path,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_normals=True,
        export_tangents=True,
        export_texcoords=True,
        export_materials="EXPORT",
        export_image_format=image_format,
        export_image_quality=image_quality,
        export_apply=False,
        export_skins=True,
        export_def_bones=False,
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_nla_strips=True,
        export_anim_slide_to_zero=True,
        export_optimize_animation_size=True,
    )
    return os.path.getsize(output_path)


def main() -> None:
    args = _parse_args()
    _reset_cpu_scene()

    body = _import_and_normalize_scorpion(args.input, args.height, yaw_deg_override=args.yaw_deg)
    raw_tris = _count_tris(body)
    dec_tris = _decimate_uv_preserving(body, args.target_tris)
    print(f"[rig_ash_scorpion] Decimated {raw_tris} -> {dec_tris} tris (target={args.target_tris})")

    _extract_scorpion_ember_emission(body, strength=2.0)
    _prepare_textures_for_glb(
        albedo_max_res=args.albedo_max_res,
        maps_max_res=args.maps_max_res,
        image_format=args.image_format,
    )

    lm = _measure_scorpion_anatomy(body, args.height)
    arm_obj = _build_scorpion_armature(lm, name="Armature")
    _bind_scorpion_weights(body, arm_obj, lm)
    anims = _bake_scorpion_animations(arm_obj, args.height)

    stats = _verify_rig_integrity(arm_obj, body)
    size_bytes = _export_rigged_glb(
        arm_obj,
        body,
        args.output,
        image_format=args.image_format,
        image_quality=args.image_quality,
    )
    size_mb = size_bytes / (1024.0 * 1024.0)
    print(
        f"[rig_ash_scorpion] Exported {args.output} | {size_mb:.2f} MB | "
        f"tris={stats['total_tris']} | bones={stats['bones']} | "
        f"unweighted={stats['unweighted']} | anims={len(anims)} {anims}"
    )


if __name__ == "__main__":
    main()
