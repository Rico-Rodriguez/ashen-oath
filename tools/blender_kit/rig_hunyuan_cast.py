import argparse
import math
import os
import sys
import tempfile

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_TOOLS_DIR = os.path.dirname(_SCRIPT_DIR)
if _TOOLS_DIR not in sys.path:
    sys.path.insert(0, _TOOLS_DIR)

from blender_kit.kit_anims import bake_master_animations
from blender_kit.kit_common import (
    MASTER_BONES,
    blender_to_godot,
    godot_to_blender,
    hex_to_srgb,
    make_pbr_mat,
)

NON_BODY_DEFORM_BONES = {
    "root",
    "cape_0",
    "cape_1",
    "cape_2",
    "lantern_bone",
    "weapon_r",
    "offhand_l",
}

WEAPON_DEFAULT_LENGTHS = {
    "greatsword": 1.46,
    "halberd": 1.55,
    "staff": 1.35,
    "cleaver": 1.18,
}


def _parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="CPU-only Hunyuan3D Auto-Rigging & Modular Slot Pipeline")
    parser.add_argument("--input", required=True, help="Path to baked Hunyuan3D GLB")
    parser.add_argument("--output", required=True, help="Output path for rigged Godot-ready GLB")
    parser.add_argument("--role", choices=["hero", "enemy", "boss"], default="hero")
    parser.add_argument("--height", type=float, default=1.95)
    parser.add_argument("--target_tris", type=int, default=0)
    parser.add_argument("--weapon_style", choices=["greatsword", "halberd", "staff", "cleaver"], default="greatsword")
    parser.add_argument("--weapon_glb", default="", help="Optional weapon GLB baked onto weapon_r")
    parser.add_argument("--add_cloak", action="store_true")
    parser.add_argument("--cloak_style", choices=["dark", "crimson"], default="dark")
    parser.add_argument("--split_modular", action="store_true")
    parser.add_argument("--fix_plume", action="store_true")
    parser.add_argument("--extract_ember_emission", choices=["", "none", "torso", "head"], default="")
    parser.add_argument("--rest_arm_roll_deg", type=float, default=None)
    parser.add_argument("--tex_max_res", type=int, default=0)
    parser.add_argument("--albedo_max_res", type=int, default=2048)
    parser.add_argument("--maps_max_res", type=int, default=2048)
    parser.add_argument("--image_format", choices=["AUTO", "WEBP", "JPEG"], default="WEBP")
    parser.add_argument("--image_quality", type=int, default=90)
    args = parser.parse_args(argv)
    if args.tex_max_res > 0:
        args.albedo_max_res = args.tex_max_res
        args.maps_max_res = args.tex_max_res
    if args.target_tris <= 0:
        args.target_tris = 12000 if args.role == "enemy" else 20000
    return args


def _reset_cpu_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.fps = 60


def _import_and_normalize_mesh(input_path: str, target_height: float) -> bpy.types.Object:
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
    body.name = "BodyWhole"

    # Remove non-mesh helper nodes imported from glTF.
    for obj in list(bpy.context.scene.objects):
        if obj != body:
            bpy.data.objects.remove(obj, do_unlink=True)

    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Check facing direction via feet in Godot space (toes extend toward +Z).
    pts_gd = [blender_to_godot(v.co) for v in body.data.vertices]
    min_y = min(p.y for p in pts_gd)
    max_y = max(p.y for p in pts_gd)
    raw_h = max(1e-4, max_y - min_y)
    feet_pts = [p for p in pts_gd if p.y <= min_y + raw_h * 0.10]
    if feet_pts:
        f_min_z = min(p.z for p in feet_pts)
        f_max_z = max(p.z for p in feet_pts)
        if abs(f_min_z) > abs(f_max_z) * 1.25:
            body.rotation_euler = (0.0, 0.0, math.pi)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
            pts_gd = [blender_to_godot(v.co) for v in body.data.vertices]

    min_x = min(p.x for p in pts_gd)
    max_x = max(p.x for p in pts_gd)
    min_y = min(p.y for p in pts_gd)
    max_y = max(p.y for p in pts_gd)
    raw_h = max(1e-4, max_y - min_y)

    # Compute torso Z centroid (ignore outer limbs/plume) so hips/spine center cleanly on Z=0.
    torso_pts = [
        p for p in pts_gd
        if (min_y + raw_h * 0.45) <= p.y <= (min_y + raw_h * 0.72)
        and abs(p.x - 0.5 * (min_x + max_x)) <= raw_h * 0.14
    ]
    cx_raw = 0.5 * (min_x + max_x)
    cz_raw = sum(p.z for p in torso_pts) / len(torso_pts) if torso_pts else 0.0

    scale_f = target_height / raw_h
    for v in body.data.vertices:
        gp = blender_to_godot(v.co)
        nx = (gp.x - cx_raw) * scale_f
        ny = (gp.y - min_y) * scale_f
        nz = (gp.z - cz_raw) * scale_f
        v.co = godot_to_blender(nx, ny, nz)
    body.data.update()
    return body


def _count_tris(obj: bpy.types.Object) -> int:
    return sum(max(1, len(p.vertices) - 2) for p in obj.data.polygons)


def _decimate_uv_preserving(obj: bpy.types.Object, target_tris: int) -> int:
    # Weld coincident UV-split glTF vertices first (loops keep exact UVs) so decimation cannot tear open cracks along UV seams.
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
    if cur_tris > target_tris:
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


def _rasterize_region_uv_mask(
    body: bpy.types.Object,
    height: float,
    region: str,
    tex_w: int,
    tex_h: int,
) -> np.ndarray:
    mesh = body.data
    uv_layer = mesh.uv_layers.active
    mask = np.zeros((tex_h, tex_w), dtype=np.float32)
    if uv_layer is None:
        return mask

    s = height / 1.95
    uv_data = uv_layer.data
    tris: list[tuple[tuple[float, float], tuple[float, float], tuple[float, float]]] = []
    for poly in mesh.polygons:
        c = blender_to_godot(poly.center)
        if region == "torso":
            in_reg = (0.50 * height <= c.y <= 0.84 * height) and (abs(c.x) <= 0.28 * s)
        else:
            in_reg = (c.y >= 0.84 * height) and (abs(c.x) <= 0.10 * s) and (c.z >= 0.05 * s)
        if not in_reg:
            continue
        lidxs = list(poly.loop_indices)
        uv0 = uv_data[lidxs[0]].uv
        for k in range(1, len(lidxs) - 1):
            uv1 = uv_data[lidxs[k]].uv
            uv2 = uv_data[lidxs[k + 1]].uv
            tris.append(((uv0.x * tex_w, uv0.y * tex_h), (uv1.x * tex_w, uv1.y * tex_h), (uv2.x * tex_w, uv2.y * tex_h)))

    for (x0, y0), (x1, y1), (x2, y2) in tris:
        xmin = max(0, int(math.floor(min(x0, x1, x2))) - 1)
        xmax = min(tex_w - 1, int(math.ceil(max(x0, x1, x2))) + 1)
        ymin = max(0, int(math.floor(min(y0, y1, y2))) - 1)
        ymax = min(tex_h - 1, int(math.ceil(max(y0, y1, y2))) + 1)
        if xmax < xmin or ymax < ymin:
            continue
        ys = np.arange(ymin, ymax + 1, dtype=np.float32)[:, None] + 0.5
        xs = np.arange(xmin, xmax + 1, dtype=np.float32)[None, :] + 0.5
        denom = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
        if abs(denom) < 1e-6:
            mask[ymin : ymax + 1, xmin : xmax + 1] = 1.0
            continue
        inv_d = 1.0 / denom
        l0 = ((y1 - y2) * (xs - x2) + (x2 - x1) * (ys - y2)) * inv_d
        l1 = ((y2 - y0) * (xs - x2) + (x0 - x2) * (ys - y2)) * inv_d
        l2 = 1.0 - l0 - l1
        inside = (l0 >= -0.04) & (l1 >= -0.04) & (l2 >= -0.04)
        sub = mask[ymin : ymax + 1, xmin : xmax + 1]
        sub[inside] = 1.0

    # Dilate region mask by ~4px so UV seam padding pixels around crevices stay included cleanly.
    dil_rad = max(2, int(round(4.0 * tex_w / 2048.0)))
    dil = _gaussian_blur_2d(mask, sigma=float(dil_rad) * 0.6)
    return (dil > 0.04).astype(np.float32)


def _extract_ember_emission_map(
    body: bpy.types.Object,
    height: float,
    region: str,
    strength: float = 1.8,
) -> int:
    if region not in ("torso", "head"):
        return 0
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

    region_mask = _rasterize_region_uv_mask(body, height, region, w, h)

    # Soft-threshold warm ember pixels (centered on R > 0.42, R - B > 0.24, R > G * 1.15).
    m_r = np.clip((r - 0.36) / 0.14, 0.0, 1.0)
    m_rb = np.clip(((r - b) - 0.20) / 0.10, 0.0, 1.0)
    m_rg = np.clip((r / np.maximum(g, 1e-4) - 1.12) / 0.16, 0.0, 1.0)
    raw_ember = m_r * m_rb * m_rg * region_mask

    sigma = max(1.5, 2.8 * (w / 2048.0))
    halo = _gaussian_blur_2d(raw_ember, sigma=sigma) * region_mask
    ember_weight = np.clip(0.88 * raw_ember + 0.55 * halo, 0.0, 1.0)

    tint = np.array([1.0, 0.44, 0.10], dtype=np.float32) if region == "torso" else np.array([1.0, 0.62, 0.14], dtype=np.float32)
    src_warm = np.stack([np.clip(r * 1.25, 0.0, 1.0), np.clip(g * 0.90, 0.0, 1.0), np.clip(b * 0.35, 0.0, 1.0)], axis=2)
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
        f"[rig_hunyuan] Extracted ember emission ({region}): {emissive_px} lit px "
        f"({100.0 * emissive_px / float(w * h):.3f}% of {w}x{h}), strength={strength}"
    )
    return emissive_px


def _prepare_textures_for_glb(
    albedo_max_res: int = 2048,
    maps_max_res: int = 2048,
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
    with tempfile.TemporaryDirectory(prefix="cc_tex_") as tmpdir:
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


def _mean_pt(pts: list[Vector], default: Vector) -> Vector:
    if not pts:
        return default.copy()
    acc = Vector((0.0, 0.0, 0.0))
    for p in pts:
        acc += p
    return acc / float(len(pts))


def _measure_anatomical_landmarks(body: bpy.types.Object, height: float, split_modular: bool = False) -> dict:
    s = height / 1.95
    pts = [blender_to_godot(v.co) for v in body.data.vertices]

    # Neck collar: scan downward looking for symmetric shoulder widening (skip wide kettle brims/horns on non-modular rigs).
    y_neck = 1.56 * s
    step = 0.02 * s
    shoulder_half_w_thresh = 0.135 * s if split_modular else 0.175 * s
    y_neck_max_frac = 0.86 if split_modular else 0.88
    y_cur = (0.90 if split_modular else 0.92) * height
    while y_cur >= 0.65 * height:
        sl = [p for p in pts if y_cur - step <= p.y <= y_cur + step]
        if len(sl) >= 24:
            min_x = min(p.x for p in sl)
            max_x = max(p.x for p in sl)
            if min(abs(min_x), abs(max_x)) > shoulder_half_w_thresh:
                y_neck = y_cur + 0.015 * s
                break
        y_cur -= step
    y_neck = max(0.72 * height, min(y_neck_max_frac * height, y_neck))

    head_pts = [p for p in pts if p.y >= y_neck and abs(p.x) <= 0.14 * s]
    head_max_y = max((p.y for p in head_pts), default=height)
    head_front_pts = [p for p in head_pts if p.y <= y_neck + 0.22 * s and p.z >= -0.09 * s]
    head_cz = sum(p.z for p in head_front_pts) / len(head_front_pts) if head_front_pts else 0.01 * s
    head_half_w = min(0.125 * s, max(0.095 * s, max((abs(p.x) for p in head_front_pts if p.x < 0.0), default=0.098 * s) + 0.012 * s))

    # Legs (ankles, toes, knees, hips)
    leg_l_ankle = [p for p in pts if 0.05 * height <= p.y <= 0.11 * height and p.x > 0.02 * s]
    leg_r_ankle = [p for p in pts if 0.05 * height <= p.y <= 0.11 * height and p.x < -0.02 * s]
    ankle_x = 0.5 * (
        (_mean_pt(leg_l_ankle, Vector((0.15 * s, 0.105 * s, -0.02 * s))).x)
        + abs(_mean_pt(leg_r_ankle, Vector((-0.15 * s, 0.105 * s, -0.02 * s))).x)
    )
    ankle_z = 0.5 * (
        _mean_pt(leg_l_ankle, Vector((0.15 * s, 0.105 * s, -0.02 * s))).z
        + _mean_pt(leg_r_ankle, Vector((-0.15 * s, 0.105 * s, -0.02 * s))).z
    )
    y_ankle = 0.056 * height

    feet_pts = [p for p in pts if p.y <= 0.06 * height]
    toe_z = max((p.z for p in feet_pts), default=0.18 * s) - 0.045 * s
    toe_z = max(ankle_z + 0.12 * s, min(ankle_z + 0.22 * s, toe_z))

    leg_l_knee = [p for p in pts if 0.24 * height <= p.y <= 0.29 * height and p.x > 0.02 * s]
    leg_r_knee = [p for p in pts if 0.24 * height <= p.y <= 0.29 * height and p.x < -0.02 * s]
    knee_x = 0.5 * (
        _mean_pt(leg_l_knee, Vector((0.15 * s, 0.51 * s, 0.02 * s))).x
        + abs(_mean_pt(leg_r_knee, Vector((-0.15 * s, 0.51 * s, 0.02 * s))).x)
    )
    knee_z = 0.5 * (
        _mean_pt(leg_l_knee, Vector((0.15 * s, 0.51 * s, 0.02 * s))).z
        + _mean_pt(leg_r_knee, Vector((-0.15 * s, 0.51 * s, 0.02 * s))).z
    )
    y_knee = 0.262 * height

    thigh_l = [p for p in pts if 0.34 * height <= p.y <= 0.43 * height and p.x > 0.02 * s]
    thigh_r = [p for p in pts if 0.34 * height <= p.y <= 0.43 * height and p.x < -0.02 * s]
    hip_x = 0.78 * 0.5 * (
        _mean_pt(thigh_l, Vector((0.15 * s, 0.75 * s, 0.01 * s))).x
        + abs(_mean_pt(thigh_r, Vector((-0.15 * s, 0.75 * s, 0.01 * s))).x)
    )
    hip_x = max(0.095 * s, min(0.16 * s, hip_x))
    y_hip = 0.475 * height
    y_waist = y_hip + 0.24 * (y_neck - y_hip)
    y_chest = y_hip + 0.56 * (y_neck - y_hip)

    torso_mid_pts = [p for p in pts if y_hip <= p.y <= y_neck and abs(p.x) <= 0.14 * s]
    torso_z = sum(p.z for p in torso_mid_pts) / len(torso_mid_pts) if torso_mid_pts else 0.0

    # Trace both arms inward from outer hand tips so torso/tassets never contaminate arm joints.
    arm_band = [p for p in pts if 0.36 * height <= p.y <= y_neck + 0.02 * s]
    max_arm_x_l = max((p.x for p in arm_band), default=0.52 * s)
    max_arm_x_r = max((-p.x for p in arm_band), default=0.52 * s)
    max_arm_x = 0.5 * (max_arm_x_l + max_arm_x_r)

    def _trace_arm_side(sign: float) -> dict[str, Vector]:
        side_pts = [p for p in arm_band if sign * p.x >= 0.20 * s]
        outer_x = max((sign * p.x for p in side_pts), default=max_arm_x)
        # Start at hand tip (outer 6% of span)
        tip_pts = [p for p in side_pts if sign * p.x >= outer_x - 0.04 * s]
        tip_c = _mean_pt(tip_pts, Vector((sign * outer_x, 0.48 * height, 0.11 * s)))

        samples: list[tuple[float, Vector]] = [(outer_x, tip_c)]
        prev_y = tip_c.y
        step_x = 0.025 * s
        ax = outer_x - step_x
        while ax >= 0.22 * s:
            sl = [
                p for p in side_pts
                if (ax - step_x * 0.65) <= sign * p.x <= (ax + step_x * 0.65)
                and abs(p.y - prev_y) <= 0.18 * s
                and p.y >= prev_y - 0.06 * s
            ]
            if len(sl) >= 6:
                c = _mean_pt(sl, Vector((sign * ax, prev_y + 0.02 * s, tip_c.z)))
                samples.append((ax, c))
                prev_y = c.y
            ax -= step_x

        def _interp_at_x(target_x: float, fallback: Vector) -> Vector:
            if not samples:
                return fallback
            best = min(samples, key=lambda it: abs(it[0] - target_x))
            return best[1].copy()

        sh_x = max(0.18 * s, min(0.24 * s, outer_x * 0.39))
        sh_y = min(y_neck - 0.08 * s, max(y_chest + 0.06 * s, _interp_at_x(sh_x, Vector((sign * sh_x, y_neck - 0.11 * s, 0.0))).y))
        sh_pt = Vector((sign * sh_x, sh_y, torso_z))

        wrist_x = sh_x + (outer_x - sh_x) * 0.74
        elbow_x = sh_x + (outer_x - sh_x) * 0.39
        palm_x = sh_x + (outer_x - sh_x) * 0.86

        elbow_pt = _interp_at_x(elbow_x, sh_pt.lerp(tip_c, 0.44))
        wrist_pt = _interp_at_x(wrist_x, sh_pt.lerp(tip_c, 0.78))
        palm_pt = _interp_at_x(palm_x, wrist_pt.lerp(tip_c, 0.48))

        # Keep joints monotonically progressing down/out along arm chain.
        elbow_pt.x = sign * elbow_x
        elbow_pt.y = min(sh_pt.y - 0.08 * s, max(wrist_pt.y + 0.08 * s, elbow_pt.y))
        wrist_pt.x = sign * wrist_x
        palm_pt.x = sign * palm_x
        tip_pt = Vector((sign * outer_x, min(wrist_pt.y - 0.05 * s, tip_c.y), tip_c.z))

        return {
            "shoulder": sh_pt,
            "elbow": elbow_pt,
            "wrist": wrist_pt,
            "palm": palm_pt,
            "tip": tip_pt,
        }

    arm_l = _trace_arm_side(1.0)
    arm_r = _trace_arm_side(-1.0)

    # Symmetrize arm Y/Z and |X| cleanly so bilateral animations stay perfectly level.
    sym_arm: dict[str, Vector] = {}
    for k in ("shoulder", "elbow", "wrist", "palm", "tip"):
        al, ar = arm_l[k], arm_r[k]
        sym_arm[k] = Vector((0.5 * (abs(al.x) + abs(ar.x)), 0.5 * (al.y + ar.y), 0.5 * (al.z + ar.z)))

    # Measure back surface Z profile for anti-clipping cloak placement (wide enough to cover bulky fur mantles).
    back_profile: list[tuple[float, float]] = []
    for k in range(14):
        yy = (0.16 + 0.66 * (k / 13.0)) * height
        sl = [p for p in pts if abs(p.y - yy) <= 0.045 * s and abs(p.x) <= 0.30 * s]
        min_z_b = min((p.z for p in sl), default=-0.14 * s)
        back_profile.append((yy, min_z_b))

    def _back_z_at(yy: float) -> float:
        closest = min(back_profile, key=lambda it: abs(it[0] - yy))
        return closest[1]

    # Waist outer edge for lantern bone.
    waist_pts = [p for p in pts if abs(p.y - y_waist) <= 0.06 * s and 0.0 <= p.x <= 0.26 * s]
    lantern_x = max((p.x for p in waist_pts), default=0.19 * s) + 0.032 * s
    lantern_z = max((p.z for p in waist_pts), default=0.10 * s) * 0.55

    return {
        "scale": s,
        "height": height,
        "y_ankle": y_ankle,
        "ankle_x": ankle_x,
        "ankle_z": ankle_z,
        "toe_z": toe_z,
        "y_knee": y_knee,
        "knee_x": knee_x,
        "knee_z": knee_z,
        "y_hip": y_hip,
        "hip_x": hip_x,
        "y_waist": y_waist,
        "y_chest": y_chest,
        "y_neck": y_neck,
        "head_max_y": head_max_y,
        "head_cz": head_cz,
        "head_half_w": head_half_w,
        "torso_z": torso_z,
        "arm": sym_arm,
        "back_z_at": _back_z_at,
        "lantern_pos": Vector((lantern_x, y_waist - 0.04 * s, lantern_z)),
    }


def _build_fitted_armature(lm: dict, name: str = "Armature") -> bpy.types.Object:
    s = lm["scale"]
    arm = lm["arm"]
    sh = arm["shoulder"]
    el = arm["elbow"]
    wr = arm["wrist"]
    pa = arm["palm"]
    tp = arm["tip"]
    tz = lm["torso_z"]
    back_z_at = lm["back_z_at"]

    y_head_base = lm["y_neck"] + 0.05 * s
    y_head_top = min(lm["height"] - 0.02 * s, lm["y_neck"] + 0.25 * s)
    if y_head_top <= y_head_base + 0.08 * s:
        y_head_top = y_head_base + 0.16 * s

    y_cape_top = min(lm["y_neck"] - 0.02 * s, sh.y + 0.07 * s)
    y_cape_1 = y_cape_top - 0.42 * s
    y_cape_2 = y_cape_top - 0.88 * s
    y_cape_end = max(0.12 * s, y_cape_top - 1.36 * s)
    z_c0 = min(-0.14 * s, back_z_at(y_cape_top) - 0.032 * s)
    z_c1 = min(z_c0 - 0.04 * s, back_z_at(y_cape_1) - 0.045 * s)
    z_c2 = min(z_c1 - 0.03 * s, back_z_at(y_cape_2) - 0.055 * s)
    z_ce = z_c2 - 0.04 * s

    lpos = lm["lantern_pos"]

    bone_coords: dict[str, tuple[tuple[float, float, float], tuple[float, float, float]]] = {
        "root": ((0.0, 0.0, 0.0), (0.0, 0.24 * s, 0.0)),
        "hips": ((0.0, lm["y_hip"], tz), (0.0, lm["y_waist"], tz)),
        "spine": ((0.0, lm["y_waist"], tz), (0.0, lm["y_chest"], tz)),
        "chest": ((0.0, lm["y_chest"], tz), (0.0, lm["y_neck"], tz)),
        "neck": ((0.0, lm["y_neck"], tz), (0.0, y_head_base, lm["head_cz"])),
        "head": ((0.0, y_head_base, lm["head_cz"]), (0.0, y_head_top, lm["head_cz"])),
        "shoulder_l": ((0.055 * s, sh.y - 0.02 * s, tz), (sh.x, sh.y, sh.z)),
        "upper_arm_l": ((sh.x, sh.y, sh.z), (el.x, el.y, el.z)),
        "forearm_l": ((el.x, el.y, el.z), (wr.x, wr.y, wr.z)),
        "hand_l": ((wr.x, wr.y, wr.z), (tp.x, tp.y, tp.z)),
        "offhand_l": ((pa.x, pa.y, pa.z), (pa.x, pa.y, pa.z + 0.24 * s)),
        "shoulder_r": ((-0.055 * s, sh.y - 0.02 * s, tz), (-sh.x, sh.y, sh.z)),
        "upper_arm_r": ((-sh.x, sh.y, sh.z), (-el.x, el.y, el.z)),
        "forearm_r": ((-el.x, el.y, el.z), (-wr.x, wr.y, wr.z)),
        "hand_r": ((-wr.x, wr.y, wr.z), (-tp.x, tp.y, tp.z)),
        "weapon_r": ((-pa.x, pa.y, pa.z), (-pa.x, pa.y, pa.z + 0.28 * s)),
        "thigh_l": ((lm["hip_x"], lm["y_hip"], tz), (lm["knee_x"], lm["y_knee"], lm["knee_z"])),
        "shin_l": ((lm["knee_x"], lm["y_knee"], lm["knee_z"]), (lm["ankle_x"], lm["y_ankle"], lm["ankle_z"])),
        "foot_l": ((lm["ankle_x"], lm["y_ankle"], lm["ankle_z"]), (lm["ankle_x"], 0.022 * s, lm["toe_z"])),
        "thigh_r": ((-lm["hip_x"], lm["y_hip"], tz), (-lm["knee_x"], lm["y_knee"], lm["knee_z"])),
        "shin_r": ((-lm["knee_x"], lm["y_knee"], lm["knee_z"]), (-lm["ankle_x"], lm["y_ankle"], lm["ankle_z"])),
        "foot_r": ((-lm["ankle_x"], lm["y_ankle"], lm["ankle_z"]), (-lm["ankle_x"], 0.022 * s, lm["toe_z"])),
        "cape_0": ((0.0, y_cape_top, z_c0), (0.0, y_cape_1, z_c1)),
        "cape_1": ((0.0, y_cape_1, z_c1), (0.0, y_cape_2, z_c2)),
        "cape_2": ((0.0, y_cape_2, z_c2), (0.0, y_cape_end, z_ce)),
        "lantern_bone": ((lpos.x, lpos.y, lpos.z), (lpos.x, lpos.y - 0.24 * s, lpos.z)),
    }

    arm_data = bpy.data.armatures.new(f"{name}Data")
    arm_obj = bpy.data.objects.new(name, arm_data)
    bpy.context.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")

    created: dict[str, bpy.types.EditBone] = {}
    for bname, parent_name, _, _ in MASTER_BONES:
        head_gd, tail_gd = bone_coords[bname]
        eb = arm_data.edit_bones.new(bname)
        eb.head = godot_to_blender(*head_gd)
        eb.tail = godot_to_blender(*tail_gd)
        eb.use_deform = True
        if parent_name is not None:
            eb.parent = created[parent_name]
        eb.use_connect = False
        eb.align_roll(Vector((0.0, -1.0, 0.0)))
        created[bname] = eb

    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return arm_obj


def _point_to_segment_dist_sq(p: Vector, a: Vector, b: Vector) -> float:
    ab = b - a
    denom = ab.length_squared
    if denom <= 1e-10:
        return (p - a).length_squared
    t = max(0.0, min(1.0, (p - a).dot(ab) / denom))
    proj = a + ab * t
    return (p - proj).length_squared


def _bind_body_weights(body: bpy.types.Object, arm_obj: bpy.types.Object, lm: dict) -> None:
    # Disable non-body helper bones during bone-heat solving so cape/lantern/weapon bones never pull body mesh.
    for b in arm_obj.data.bones:
        b.use_deform = b.name not in NON_BODY_DEFORM_BONES

    # Weld UV-split vertices on a temporary 5x-scaled proxy so Blender's bone-heat solver succeeds cleanly.
    proxy = body.copy()
    proxy.data = body.data.copy()
    proxy.name = "HeatProxy"
    proxy.parent = None
    proxy.modifiers.clear()
    bpy.context.collection.objects.link(proxy)

    bm = bmesh.new()
    bm.from_mesh(proxy.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.002)
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(proxy.data)
    bm.free()
    proxy.data.update()

    proxy.scale = (5.0, 5.0, 5.0)
    arm_obj.scale = (5.0, 5.0, 5.0)
    bpy.context.view_layer.update()

    bpy.ops.object.select_all(action="DESELECT")
    proxy.select_set(True)
    arm_obj.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj
    heat_ok = True
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    except RuntimeError as exc:
        heat_ok = False
        print(f"[rig_hunyuan] HeatProxy ARMATURE_AUTO fallback: {exc}")

    # Restore scale=1 on armature before parenting body and transferring weights.
    proxy.parent = None
    proxy.scale = (1.0, 1.0, 1.0)
    arm_obj.scale = (1.0, 1.0, 1.0)
    bpy.context.view_layer.update()

    # Restore deform flags on all 26 MASTER_BONES for cloak/weapon skinning and Godot export.
    for b in arm_obj.data.bones:
        b.use_deform = True

    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    arm_obj.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.parent_set(type="ARMATURE_NAME")

    for b in arm_obj.data.bones:
        if body.vertex_groups.get(b.name) is None:
            body.vertex_groups.new(name=b.name)

    if heat_ok:
        bpy.ops.object.select_all(action="DESELECT")
        body.select_set(True)
        bpy.context.view_layer.objects.active = body
        dt = body.modifiers.new(name="TransferHeatWeights", type="DATA_TRANSFER")
        dt.object = proxy
        dt.use_vert_data = True
        dt.data_types_verts = {"VGROUP_WEIGHTS"}
        dt.vert_mapping = "NEAREST"
        bpy.ops.object.modifier_move_to_index(modifier=dt.name, index=0)
        bpy.ops.object.datalayout_transfer(modifier=dt.name)
        bpy.ops.object.modifier_apply(modifier=dt.name)

    bpy.data.objects.remove(proxy, do_unlink=True)

    # Precompute active body deform bone segments for disconnected-island fallback weighting.
    deform_segs = [
        (b.name, b.head_local.copy(), b.tail_local.copy())
        for b in arm_obj.data.bones
        if b.name not in NON_BODY_DEFORM_BONES
    ]

    mesh = body.data
    s = lm["scale"]
    y_neck_cut = lm["y_neck"] - 0.022 * s
    head_half_w = lm["head_half_w"]
    vg_head = body.vertex_groups["head"]
    vg_neck = body.vertex_groups["neck"]

    fallback_fixed = 0
    for v in mesh.vertices:
        gp = blender_to_godot(v.co)
        # Keep metal helmet, horns, kettle brims & plume strictly rigid on head (widen above shoulder line).
        allowed_head_w = max(head_half_w, 0.20 * s) if gp.y >= lm["y_neck"] + 0.04 * s else head_half_w
        if gp.y >= y_neck_cut and abs(gp.x) <= allowed_head_w:
            for g in list(v.groups):
                body.vertex_groups[g.group].remove([v.index])
            if gp.y < y_neck_cut + 0.03 * s:
                t_col = (gp.y - y_neck_cut) / (0.03 * s)
                w_head = 0.90 + 0.10 * t_col
                vg_head.add([v.index], w_head, "REPLACE")
                vg_neck.add([v.index], 1.0 - w_head, "REPLACE")
            else:
                vg_head.add([v.index], 1.0, "REPLACE")
            continue

        wsum = sum(g.weight for g in v.groups if not math.isnan(g.weight) and g.weight > 1e-5)
        if wsum <= 1e-4:
            # Side-aware nearest deform bone segment fallback for disconnected islands.
            side_cands = [
                seg for seg in deform_segs
                if not ((gp.x > 0.02 * s and seg[0].endswith("_r")) or (gp.x < -0.02 * s and seg[0].endswith("_l")))
            ] or deform_segs
            dists = sorted(
                ((_point_to_segment_dist_sq(v.co, a, b), bname) for bname, a, b in side_cands),
                key=lambda it: it[0],
            )
            b0_d, b0_name = dists[0]
            b1_d, b1_name = dists[1]
            inv0 = 1.0 / max(1e-5, b0_d)
            inv1 = 1.0 / max(1e-5, b1_d)
            if inv0 > inv1 * 4.0:
                body.vertex_groups[b0_name].add([v.index], 1.0, "REPLACE")
            else:
                tot = inv0 + inv1
                body.vertex_groups[b0_name].add([v.index], inv0 / tot, "REPLACE")
                body.vertex_groups[b1_name].add([v.index], inv1 / tot, "REPLACE")
            fallback_fixed += 1

    # Enforce strict <= 4 influences per vertex and exact normalization to 1.0.
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)

    # Hard-verify zero NaN / zero unweighted vertices.
    for v in mesh.vertices:
        valid = [(g.group, g.weight) for g in v.groups if math.isfinite(g.weight) and g.weight > 1e-6]
        if not valid:
            best_b = min(deform_segs, key=lambda it: _point_to_segment_dist_sq(v.co, it[1], it[2]))[0]
            body.vertex_groups[best_b].add([v.index], 1.0, "REPLACE")
        else:
            valid.sort(key=lambda it: it[1], reverse=True)
            keep = valid[:4]
            tot = sum(w for _, w in keep)
            for g in list(v.groups):
                body.vertex_groups[g.group].remove([v.index])
            for gid, w in keep:
                body.vertex_groups[gid].add([v.index], w / tot, "REPLACE")

    print(f"[rig_hunyuan] Bound heat weights on {len(mesh.vertices)} verts (fallback islands fixed: {fallback_fixed})")


def _classify_face_slot(
    poly: bpy.types.MeshPolygon,
    mesh: bpy.types.Mesh,
    lm: dict,
    split_modular: bool,
    fix_plume: bool,
) -> str:
    s = lm["scale"]
    c = blender_to_godot(poly.center)
    y_neck_cut = lm["y_neck"] - 0.022 * s
    head_half_w = lm["head_half_w"]

    if fix_plume and c.y >= y_neck_cut and abs(c.x) <= head_half_w + 0.015 * s:
        # Helmet skull ellipsoid centered at (0, y_neck + 0.088*s, head_cz + 0.02*s).
        y_dome_c = lm["y_neck"] + 0.095 * s
        z_dome_c = lm["head_cz"] + 0.020 * s
        y_helm_crown = lm["y_neck"] + 0.205 * s
        dy = (c.y - y_dome_c) / (0.116 * s)
        dz = (c.z - z_dome_c) / (0.124 * s)
        is_above_crown = c.y > y_helm_crown
        is_back_crest = c.z < (z_dome_c - 0.095 * s) and (dy * dy + dz * dz) > 0.96 and c.y >= lm["y_neck"] + 0.02 * s
        if is_above_crown or is_back_crest:
            return "Slot_Plume"

    if not split_modular:
        return "CharacterBody"

    # Dip front chin cut gently so sallet/barbute visor chins stay on Slot_Helm without notching the gorget collar.
    y_helm_cut = y_neck_cut - 0.014 * s if (c.z > 0.045 * s and abs(c.x) <= 0.090 * s) else y_neck_cut
    if c.y >= y_helm_cut and abs(c.x) <= head_half_w:
        return "Slot_Helm"

    # Greaves: thighs/knees/shins/sabatons below tasset skirt line.
    y_hip_cut = lm["y_hip"] - 0.105 * s
    if c.y < y_hip_cut:
        return "Slot_Greaves"

    # Check arm projection for gauntlets (lower forearm + hand) vs pauldrons (shoulders + upper arms).
    arm = lm["arm"]
    sh = arm["shoulder"]
    el = arm["elbow"]
    wr = arm["wrist"]
    abs_x = abs(c.x)

    if abs_x >= el.x + 0.015 * s and c.y <= el.y + 0.06 * s:
        return "Slot_Gauntlets"
    # More accurate forearm projection cut for angled A-pose arms.
    arm_dir = Vector((wr.x - el.x, wr.y - el.y, wr.z - el.z))
    arm_len = max(1e-4, arm_dir.length)
    arm_u = arm_dir / arm_len
    rel_el = Vector((abs_x - el.x, c.y - el.y, c.z - el.z))
    proj_fa = rel_el.dot(arm_u)
    perp_fa = (rel_el - arm_u * proj_fa).length
    if proj_fa >= 0.08 * arm_len and perp_fa <= 0.13 * s and abs_x >= 0.28 * s:
        return "Slot_Gauntlets"

    # Pauldrons: shoulder armor domes + upper arms + left wolf-fur mantle.
    if c.y >= lm["y_chest"] - 0.04 * s:
        if abs_x >= sh.x - 0.032 * s:
            return "Slot_Pauldrons"
        # Include left-shoulder wolf-fur mantle draping over clavicle/upper chest (+X side).
        if c.x >= 0.075 * s and c.y >= lm["y_neck"] - 0.19 * s:
            return "Slot_Pauldrons"

    return "Slot_Cuirass"


def _add_neck_undersuit_cap(cuirass_obj: bpy.types.Object, lm: dict) -> None:
    s = lm["scale"]
    y_cut = lm["y_neck"] - 0.022 * s
    head_half_w = lm["head_half_w"]
    cz = 0.45 * lm["torso_z"] + 0.55 * lm["head_cz"]

    mat = make_pbr_mat("NeckCapUndersuit", hex_to_srgb("#181A1F"), 0.32, 0.78, "hammered", 404)
    cuirass_obj.data.materials.append(mat)
    mat_idx = len(cuirass_obj.data.materials) - 1

    bm = bmesh.new()
    bm.from_mesh(cuirass_obj.data)
    dvert = bm.verts.layers.deform.verify()
    g_neck = cuirass_obj.vertex_groups["neck"].index
    g_chest = cuirass_obj.vertex_groups["chest"].index
    uv_layer = bm.loops.layers.uv.verify()

    # Flatten stray jagged collar-cut boundary vertices that poke above the gorget opening.
    for v in bm.verts:
        if any(len(e.link_faces) == 1 for e in v.link_edges):
            gp = blender_to_godot(v.co)
            rim_y = y_cut - 0.014 * s if (gp.z > 0.045 * s and abs(gp.x) <= 0.090 * s) else y_cut
            if abs(gp.x) <= head_half_w + 0.012 * s and rim_y < gp.y <= y_cut + 0.045 * s:
                v.co = godot_to_blender(gp.x, rim_y, gp.z)

    # Smoothly domed undersuit cap recessed ~1.2 cm inside the gorget opening (invisible under helms, clean when bare).
    y_cap_top = y_cut - 0.012 * s
    rings_spec = [
        (y_cap_top - 0.034 * s, 0.068 * s, 0.072 * s, 0.40, 0.60),
        (y_cap_top - 0.018 * s, 0.063 * s, 0.067 * s, 0.64, 0.36),
        (y_cap_top - 0.008 * s, 0.050 * s, 0.054 * s, 0.80, 0.20),
        (y_cap_top - 0.003 * s, 0.030 * s, 0.033 * s, 0.88, 0.12),
        (y_cap_top - 0.001 * s, 0.012 * s, 0.014 * s, 0.92, 0.08),
    ]
    sides = 20
    vrings: list[list[bmesh.types.BMVert]] = []
    for yy, rx, rz, wn, wc in rings_spec:
        ring: list[bmesh.types.BMVert] = []
        for i in range(sides):
            ang = 2.0 * math.pi * i / sides
            v = bm.verts.new(godot_to_blender(math.cos(ang) * rx, yy, cz + math.sin(ang) * rz))
            dv = v[dvert]
            dv[g_neck] = wn
            dv[g_chest] = wc
            ring.append(v)
        vrings.append(ring)

    new_faces: list[bmesh.types.BMFace] = []
    for ri in range(len(vrings) - 1):
        r0, r1 = vrings[ri], vrings[ri + 1]
        for i in range(sides):
            inext = (i + 1) % sides
            f = bm.faces.new([r0[i], r0[inext], r1[inext], r1[i]])
            f.material_index = mat_idx
            f.smooth = True
            new_faces.append(f)
    pole_v = bm.verts.new(godot_to_blender(0.0, y_cap_top, cz))
    pole_v[dvert][g_neck] = 0.92
    pole_v[dvert][g_chest] = 0.08
    last_ring = vrings[-1]
    for i in range(sides):
        inext = (i + 1) % sides
        tf = bm.faces.new([last_ring[i], last_ring[inext], pole_v])
        tf.material_index = mat_idx
        tf.smooth = True
        new_faces.append(tf)

    for f in new_faces:
        for loop in f.loops:
            loop[uv_layer].uv = (0.5, 0.5)

    bmesh.ops.recalc_face_normals(bm, faces=new_faces)
    bm.to_mesh(cuirass_obj.data)
    bm.free()
    cuirass_obj.data.update()


def _add_helm_crown_cap(helm_obj: bpy.types.Object, lm: dict) -> None:
    s = lm["scale"]
    y_base = lm["y_neck"]
    cz = lm["head_cz"] + 0.016 * s

    mat = make_pbr_mat("HelmCrownCap", hex_to_srgb("#25282E"), 0.82, 0.36, "brushed", 505)
    helm_obj.data.materials.append(mat)
    mat_idx = len(helm_obj.data.materials) - 1

    bm = bmesh.new()
    bm.from_mesh(helm_obj.data)
    dvert = bm.verts.layers.deform.verify()
    g_head = helm_obj.vertex_groups["head"].index
    uv_layer = bm.loops.layers.uv.verify()

    # Keep dome cap strictly tucked inside helmet crown so it closes the plume cutout cleanly without protruding.
    rings_spec = [
        (y_base + 0.132 * s, 0.062 * s, 0.080 * s),
        (y_base + 0.165 * s, 0.052 * s, 0.068 * s),
        (y_base + 0.186 * s, 0.032 * s, 0.044 * s),
        (y_base + 0.194 * s, 0.008 * s, 0.012 * s),
    ]
    sides = 14
    vrings: list[list[bmesh.types.BMVert]] = []
    for yy, rx, rz in rings_spec:
        ring: list[bmesh.types.BMVert] = []
        for i in range(sides):
            ang = 2.0 * math.pi * i / sides
            v = bm.verts.new(godot_to_blender(math.cos(ang) * rx, yy, cz + math.sin(ang) * rz))
            v[dvert][g_head] = 1.0
            ring.append(v)
        vrings.append(ring)

    new_faces: list[bmesh.types.BMFace] = []
    for ri in range(len(vrings) - 1):
        r0, r1 = vrings[ri], vrings[ri + 1]
        for i in range(sides):
            inext = (i + 1) % sides
            f = bm.faces.new([r0[i], r0[inext], r1[inext], r1[i]])
            f.material_index = mat_idx
            f.smooth = True
            new_faces.append(f)
    pole_v = bm.verts.new(godot_to_blender(0.0, y_base + 0.196 * s, cz))
    pole_v[dvert][g_head] = 1.0
    last_ring = vrings[-1]
    for i in range(sides):
        inext = (i + 1) % sides
        tf = bm.faces.new([last_ring[i], last_ring[inext], pole_v])
        tf.material_index = mat_idx
        tf.smooth = True
        new_faces.append(tf)

    for f in new_faces:
        for loop in f.loops:
            loop[uv_layer].uv = (0.5, 0.5)

    bmesh.ops.recalc_face_normals(bm, faces=new_faces)
    bm.to_mesh(helm_obj.data)
    bm.free()
    helm_obj.data.update()


def _refine_plume_object(plume_obj: bpy.types.Object, lm: dict) -> None:
    s = lm["scale"]
    plume_mat = make_pbr_mat(
        "HelmPlume",
        hex_to_srgb("#A6A29B"),
        metallic=0.0,
        roughness=0.88,
        pattern="bone",
        seed=909,
        use_vertex_color=True,
    )
    plume_obj.data.materials.clear()
    plume_obj.data.materials.append(plume_mat)
    for p in plume_obj.data.polygons:
        p.material_index = 0
        p.use_smooth = True

    # Sculpt subtle longitudinal horsehair ridges + author vertex color sway mask for Godot cloak_sway.gdshader.
    y_base = lm["y_neck"] + 0.19 * s
    z_front = lm["head_cz"] + 0.04 * s
    mesh = plume_obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    bm.normal_update()
    for v in bm.verts:
        gp = blender_to_godot(v.co)
        ang = math.atan2(gp.x, max(1e-3, abs(gp.y - y_base) + abs(gp.z - z_front)))
        crease = math.sin(ang * 22.0 + gp.x * 160.0) * 0.0022 * s
        v.co += v.normal * crease
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()

    while len(mesh.color_attributes) > 0:
        mesh.color_attributes.remove(mesh.color_attributes[0])
    col_attr = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    mesh.color_attributes.active_color = col_attr
    mesh.color_attributes.render_color_index = 0
    for idx, v in enumerate(mesh.vertices):
        gp = blender_to_godot(v.co)
        dist_back = max(0.0, (z_front - gp.z) / (0.26 * s))
        dist_up = max(0.0, (gp.y - y_base) / (0.18 * s))
        w = min(1.0, max(0.0, 0.55 * dist_back + 0.45 * dist_up))
        col_attr.data[idx].color = (w, 0.0, 0.0, 1.0)


def _split_into_modular_slots(
    body: bpy.types.Object,
    arm_obj: bpy.types.Object,
    lm: dict,
    split_modular: bool,
    fix_plume: bool,
) -> list[bpy.types.Object]:
    if not split_modular and not fix_plume:
        return [body]

    # Preserve unsplit smooth normal reference for seamless boundary shading via DATA_TRANSFER.
    normal_ref = body.copy()
    normal_ref.data = body.data.copy()
    normal_ref.name = "BodyNormalRef"
    normal_ref.parent = None
    normal_ref.modifiers.clear()
    bpy.context.collection.objects.link(normal_ref)

    mesh = body.data
    slot_poly_indices: dict[str, list[int]] = {}
    for poly in mesh.polygons:
        sname = _classify_face_slot(poly, mesh, lm, split_modular, fix_plume)
        slot_poly_indices.setdefault(sname, []).append(poly.index)

    created_slots: list[bpy.types.Object] = []
    for sname, keep_polys in slot_poly_indices.items():
        if not keep_polys:
            continue
        keep_set = set(keep_polys)
        slot_obj = body.copy()
        slot_obj.data = body.data.copy()
        slot_obj.name = sname
        slot_obj.data.name = f"{sname}Mesh"
        bpy.context.collection.objects.link(slot_obj)

        bm = bmesh.new()
        bm.from_mesh(slot_obj.data)
        bm.faces.ensure_lookup_table()
        del_faces = [f for i, f in enumerate(bm.faces) if i not in keep_set]
        bmesh.ops.delete(bm, geom=del_faces, context="FACES")
        orphan_verts = [v for v in bm.verts if not v.link_faces]
        if orphan_verts:
            bmesh.ops.delete(bm, geom=orphan_verts, context="VERTS")
        bm.to_mesh(slot_obj.data)
        bm.free()
        slot_obj.data.update()

        # Re-bind Armature modifier cleanly to arm_obj.
        slot_obj.parent = arm_obj
        for mod in list(slot_obj.modifiers):
            if mod.type == "ARMATURE":
                mod.object = arm_obj

        if sname == "Slot_Plume":
            _refine_plume_object(slot_obj, lm)
        else:
            # Transfer continuous vertex normals from unsplit mesh so armor seams are invisible.
            bpy.ops.object.select_all(action="DESELECT")
            slot_obj.select_set(True)
            bpy.context.view_layer.objects.active = slot_obj
            dt = slot_obj.modifiers.new(name="SeamNormalTransfer", type="DATA_TRANSFER")
            dt.object = normal_ref
            dt.use_loop_data = True
            dt.data_types_loops = {"CUSTOM_NORMAL"}
            dt.loop_mapping = "NEAREST_POLYNOR"
            bpy.ops.object.modifier_move_to_index(modifier=dt.name, index=0)
            bpy.ops.object.modifier_apply(modifier=dt.name)

            if sname == "Slot_Cuirass":
                _add_neck_undersuit_cap(slot_obj, lm)
            elif sname == "Slot_Helm" and fix_plume:
                _add_helm_crown_cap(slot_obj, lm)

        created_slots.append(slot_obj)

    bpy.data.objects.remove(normal_ref, do_unlink=True)
    bpy.data.objects.remove(body, do_unlink=True)
    return created_slots


def _build_tattered_cloak_slot(
    arm_obj: bpy.types.Object,
    lm: dict,
    cloak_style: str = "dark",
) -> bpy.types.Object:
    s = lm["scale"]
    back_z_at = lm["back_z_at"]
    sh_y = lm["arm"]["shoulder"].y
    is_crimson = cloak_style == "crimson"
    if is_crimson:
        # Anchor sovereign cape neatly beneath bulky wolf-fur mantle with generous back clearance for combat poses.
        y_top = min(lm["y_neck"] - 0.15 * s, sh_y - 0.065 * s)
        y_bot = max(0.14 * s, y_top - 1.34 * s)
        cape_hex = "#5A1116"
        w_top = min(0.27 * s, lm["arm"]["shoulder"].x + 0.02 * s)
        w_bot = 0.48 * s
        back_clear_base = 0.072
        shoulder_cup_amp = 0.018
        flare_amp = 0.118
    else:
        y_top = min(lm["y_neck"] - 0.015 * s, sh_y + 0.075 * s)
        y_bot = max(0.14 * s, y_top - 1.36 * s)
        cape_hex = "#181B25"
        w_top = min(0.28 * s, lm["arm"]["shoulder"].x + 0.04 * s)
        w_bot = 0.44 * s
        back_clear_base = 0.036
        shoulder_cup_amp = 0.040
        flare_amp = 0.098
    length_y = y_top - y_bot

    cape_mat = make_pbr_mat(
        "CapeCloth",
        hex_to_srgb(cape_hex),
        metallic=0.0,
        roughness=0.92,
        pattern="cloth",
        seed=707 if not is_crimson else 719,
        use_vertex_color=True,
    )
    mesh = bpy.data.meshes.new("Slot_CloakMesh")
    obj = bpy.data.objects.new("Slot_Cloak", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(cape_mat)
    obj.parent = arm_obj
    mod = obj.modifiers.new(name="Armature", type="ARMATURE")
    mod.object = arm_obj

    vg_map: dict[str, int] = {}
    for b in arm_obj.data.bones:
        vg_map[b.name] = obj.vertex_groups.new(name=b.name).index

    rows = 22
    cols = 25
    tatter_profile = [
        0.00, 0.09, 0.02, 0.15, 0.04, 0.01, 0.13, 0.05, 0.18,
        0.03, 0.00, 0.14, 0.06, 0.20, 0.05, 0.13, 0.01, 0.04,
        0.17, 0.03, 0.12, 0.01, 0.15, 0.07, 0.00,
    ]

    bm = bmesh.new()
    dvert = bm.verts.layers.deform.verify()
    uv_layer = bm.loops.layers.uv.verify()

    vgrid: list[list[bmesh.types.BMVert]] = []
    sway_weights: list[float] = []

    for r in range(rows):
        v_norm = r / float(rows - 1)
        yy_base = y_top - length_y * v_norm
        z_clear = min(-0.14 * s, back_z_at(yy_base) - (back_clear_base + 0.025 * v_norm) * s)
        if v_norm < 0.26:
            t = v_norm / 0.26
            t_s = t * t * (3.0 - 2.0 * t)
            rw = {"chest": 1.0 - t_s, "cape_0": t_s}
        elif v_norm < 0.58:
            t = (v_norm - 0.26) / 0.32
            t_s = t * t * (3.0 - 2.0 * t)
            rw = {"cape_0": 1.0 - t_s, "cape_1": t_s}
        elif v_norm < 0.86:
            t = (v_norm - 0.58) / 0.28
            t_s = t * t * (3.0 - 2.0 * t)
            rw = {"cape_1": 1.0 - t_s, "cape_2": t_s}
        else:
            rw = {"cape_2": 1.0}

        row_v: list[bmesh.types.BMVert] = []
        for c in range(cols):
            u = -1.0 + 2.0 * (c / float(cols - 1))
            hw = w_top + (w_bot - w_top) * (v_norm ** 0.88)
            x = math.sin(u * 1.08) * hw * (1.0 - 0.48 * v_norm) + u * hw * 0.48 * v_norm
            pleat = (
                math.sin(u * math.pi * 4.0) * (0.008 + 0.026 * v_norm)
                + math.cos(u * math.pi * 7.0) * (0.003 + 0.010 * v_norm)
            ) * s
            notch = tatter_profile[c] * 0.16 * (max(0.0, (v_norm - 0.72) / 0.28) ** 1.35) * s
            top_arch = (-0.046 * (u * u) if is_crimson else 0.024 * (1.0 - u * u)) * max(0.0, 1.0 - v_norm * 3.8) * s
            y = yy_base + top_arch + notch
            # Gentle shoulder wrap strictly behind upper shoulder blades (zero chest/fur/back-plate clipping).
            shoulder_cup = shoulder_cup_amp * (u * u) * max(0.0, 1.0 - v_norm * 3.0) * s
            back_flare = -flare_amp * (v_norm ** 0.88) * s
            z = z_clear + shoulder_cup + back_flare + pleat

            bv = bm.verts.new(godot_to_blender(x, y, z))
            dv = bv[dvert]
            for bname, wval in rw.items():
                if wval > 1e-5:
                    dv[vg_map[bname]] = wval
            row_v.append(bv)
            sway_weights.append(min(1.0, max(0.0, ((v_norm - 0.06) / 0.94) ** 1.12)) if v_norm > 0.06 else 0.0)
        vgrid.append(row_v)

    for r in range(rows - 1):
        for c in range(cols - 1):
            f = bm.faces.new([vgrid[r][c], vgrid[r + 1][c], vgrid[r + 1][c + 1], vgrid[r][c + 1]])
            f.material_index = 0
            f.smooth = True
            uvs = [
                (c / float(cols - 1), r / float(rows - 1)),
                (c / float(cols - 1), (r + 1) / float(rows - 1)),
                ((c + 1) / float(cols - 1), (r + 1) / float(rows - 1)),
                ((c + 1) / float(cols - 1), r / float(rows - 1)),
            ]
            for loop, uv in zip(f.loops, uvs):
                loop[uv_layer].uv = uv

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()

    col_attr = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    mesh.color_attributes.active_color = col_attr
    mesh.color_attributes.render_color_index = 0
    for idx, w in enumerate(sway_weights):
        col_attr.data[idx].color = (w, 0.0, 0.0, 1.0)

    return obj


def _attach_baked_weapon(weapon_glb: str, arm_obj: bpy.types.Object, lm: dict) -> bpy.types.Object | None:
    if not weapon_glb or not os.path.exists(weapon_glb):
        return None
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=weapon_glb)
    imported = [o for o in bpy.context.scene.objects if o not in before and o.type == "MESH"]
    for o in [o for o in bpy.context.scene.objects if o not in before and o.type != "MESH"]:
        bpy.data.objects.remove(o, do_unlink=True)
    if not imported:
        return None

    bpy.ops.object.select_all(action="DESELECT")
    for o in imported:
        o.select_set(True)
    bpy.context.view_layer.objects.active = imported[0]
    if len(imported) > 1:
        bpy.ops.object.join()
    wobj = bpy.context.view_layer.objects.active
    wobj.name = "BakedWeapon"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    wb = arm_obj.data.bones["weapon_r"]
    # Align weapon +Y along weapon_r bone +Y (head->tail) and place grip at weapon_r head.
    m_bone = wb.matrix_local.copy()
    rot_edge = Matrix.Rotation(math.radians(90.0), 4, "Y")
    xf = m_bone @ rot_edge
    for v in wobj.data.vertices:
        v.co = xf @ v.co
    wobj.data.update()

    wobj.parent = arm_obj
    mod = wobj.modifiers.new(name="Armature", type="ARMATURE")
    mod.object = arm_obj
    vg = wobj.vertex_groups.new(name="weapon_r")
    vg.add([v.index for v in wobj.data.vertices], 1.0, "REPLACE")
    return wobj


def _verify_rig_integrity(arm_obj: bpy.types.Object, mesh_objs: list[bpy.types.Object]) -> dict:
    total_tris = 0
    total_verts = 0
    unweighted = 0
    over_4 = 0
    nan_count = 0
    per_slot_tris: dict[str, int] = {}

    for obj in mesh_objs:
        tris = _count_tris(obj)
        total_tris += tris
        per_slot_tris[obj.name] = tris
        for v in obj.data.vertices:
            total_verts += 1
            if not (math.isfinite(v.co.x) and math.isfinite(v.co.y) and math.isfinite(v.co.z)):
                nan_count += 1
            active = [g.weight for g in v.groups if g.weight > 1e-6]
            if any(not math.isfinite(w) for w in active):
                nan_count += 1
            if not active or sum(active) < 1e-4:
                unweighted += 1
            if len(active) > 4:
                over_4 += 1

    if unweighted > 0 or over_4 > 0 or nan_count > 0:
        raise RuntimeError(
            f"Skinning verification failed: unweighted={unweighted}, over_4_bones={over_4}, nan={nan_count}"
        )

    return {
        "bones": len(arm_obj.data.bones),
        "total_tris": total_tris,
        "total_verts": total_verts,
        "unweighted": unweighted,
        "over_4": over_4,
        "nan_count": nan_count,
        "per_slot_tris": per_slot_tris,
    }


def _export_rigged_glb(
    arm_obj: bpy.types.Object,
    mesh_objs: list[bpy.types.Object],
    output_path: str,
    image_format: str = "WEBP",
    image_quality: int = 92,
) -> int:
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    arm_obj.select_set(True)
    for obj in mesh_objs:
        obj.select_set(True)
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
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=True,
        export_active_vertex_color_when_no_material=True,
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

    body = _import_and_normalize_mesh(args.input, args.height)
    raw_tris = _count_tris(body)
    dec_tris = _decimate_uv_preserving(body, args.target_tris)
    print(f"[rig_hunyuan] Decimated {raw_tris} -> {dec_tris} tris (target={args.target_tris})")

    if args.extract_ember_emission in ("torso", "head"):
        _extract_ember_emission_map(body, args.height, args.extract_ember_emission, strength=1.8)

    _prepare_textures_for_glb(
        albedo_max_res=args.albedo_max_res,
        maps_max_res=args.maps_max_res,
        image_format=args.image_format,
    )

    lm = _measure_anatomical_landmarks(body, args.height, split_modular=args.split_modular)
    arm_obj = _build_fitted_armature(lm, name="Armature")
    _bind_body_weights(body, arm_obj, lm)

    mesh_objs = _split_into_modular_slots(
        body,
        arm_obj,
        lm,
        split_modular=args.split_modular,
        fix_plume=args.fix_plume,
    )

    if args.add_cloak:
        cloak_obj = _build_tattered_cloak_slot(arm_obj, lm, cloak_style=args.cloak_style)
        mesh_objs.append(cloak_obj)

    if args.weapon_glb:
        wobj = _attach_baked_weapon(args.weapon_glb, arm_obj, lm)
        if wobj is not None:
            mesh_objs.append(wobj)

    scale = args.height / 1.95
    w_len = WEAPON_DEFAULT_LENGTHS.get(args.weapon_style, 1.46) * scale
    anims = bake_master_animations(
        arm_obj,
        scale=scale,
        weapon_style=args.weapon_style,
        weapon_len=w_len,
        rest_arm_roll_deg=args.rest_arm_roll_deg,
    )

    stats = _verify_rig_integrity(arm_obj, mesh_objs)
    size_bytes = _export_rigged_glb(
        arm_obj,
        mesh_objs,
        args.output,
        image_format=args.image_format,
        image_quality=args.image_quality,
    )
    size_mb = size_bytes / (1024.0 * 1024.0)

    print(
        f"[rig_hunyuan] Exported {args.output} | {size_mb:.2f} MB | "
        f"tris={stats['total_tris']} | bones={stats['bones']} | "
        f"unweighted={stats['unweighted']} | anims={len(anims)} {anims}"
    )
    print(f"[rig_hunyuan] Slots: {stats['per_slot_tris']}")


if __name__ == "__main__":
    main()
