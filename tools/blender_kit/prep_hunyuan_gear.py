import argparse
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_TOOLS_DIR = os.path.dirname(_SCRIPT_DIR)
if _TOOLS_DIR not in sys.path:
    sys.path.insert(0, _TOOLS_DIR)

from blender_kit.kit_common import blender_to_godot, godot_to_blender


def _parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="CPU-only Hunyuan3D Gear & Weapon Optimizer")
    parser.add_argument("--input", required=True, help="Path to baked Hunyuan3D GLB")
    parser.add_argument("--output", required=True, help="Output path for optimized Godot-ready GLB")
    parser.add_argument("--kind", choices=["weapon", "shield", "helm", "lantern", "prop"], default="weapon")
    parser.add_argument("--height", type=float, default=1.65, help="Target height in meters along Godot +Y")
    parser.add_argument("--target_tris", type=int, default=6400, help="Target triangle budget")
    parser.add_argument("--grip_frac", type=float, default=-1.0, help="Weapon grip pivot Y fraction [0..1] from bottom")
    parser.add_argument("--grip_y_m", type=float, default=-1.0, help="Weapon grip pivot Y distance in meters from bottom")
    parser.add_argument("--pivot_y_frac", type=float, default=-1.0, help="Optional Y pivot fraction [0..1] from bottom for helm/lantern")
    parser.add_argument("--pivot_z_offset", type=float, default=0.0, help="Optional Z offset in final meters along Godot +Z")
    parser.add_argument("--yaw_deg", type=float, default=0.0, help="Optional rotation around Godot +Y in degrees")
    parser.add_argument("--mesh_name", default="", help="Optional output mesh/object name")
    parser.add_argument("--mat_name", default="", help="Optional clean PBR material name")
    parser.add_argument(
        "--extract_emission",
        choices=["none", "runes", "censer", "lantern", "visor", "warm"],
        default="none",
        help="Extract emissive texture from glowing albedo regions",
    )
    parser.add_argument("--emission_strength", type=float, default=0.0, help="Override emission strength (0 = mode default)")
    parser.add_argument("--debug_emission_png", default="", help="Optional PNG path to save extracted emission mask for inspection")
    parser.add_argument("--tex_res", type=int, default=1024, help="Max texture resolution (Lanczos-3 CPU)")
    parser.add_argument("--image_format", choices=["WEBP", "AUTO", "JPEG"], default="WEBP")
    parser.add_argument("--image_quality", type=int, default=88)
    return parser.parse_args(argv)


def _reset_cpu_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.engine = "BLENDER_WORKBENCH"
    bpy.context.scene.render.fps = 60


def _count_tris(obj: bpy.types.Object) -> int:
    return sum(max(1, len(p.vertices) - 2) for p in obj.data.polygons)


def _import_joined_mesh(input_path: str, mesh_name: str) -> bpy.types.Object:
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

    prop = bpy.context.view_layer.objects.active
    clean_name = mesh_name if mesh_name else os.path.splitext(os.path.basename(input_path))[0]
    prop.name = clean_name
    prop.data.name = f"{clean_name}Mesh"

    for obj in list(bpy.context.scene.objects):
        if obj != prop:
            bpy.data.objects.remove(obj, do_unlink=True)

    bpy.ops.object.select_all(action="DESELECT")
    prop.select_set(True)
    bpy.context.view_layer.objects.active = prop
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return prop


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
        ratio = max(0.04, min(1.0, float(target_tris) / float(cur_tris)))
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


def _align_and_scale_prop(
    obj: bpy.types.Object,
    kind: str,
    target_height: float,
    grip_frac: float,
    grip_y_m: float,
    yaw_deg: float,
    pivot_y_frac: float = -1.0,
    pivot_z_offset: float = 0.0,
) -> dict:
    if abs(yaw_deg) > 1e-4:
        # Godot +Y corresponds to Blender +Z.
        rot_bl = Matrix.Rotation(math.radians(yaw_deg), 4, "Z")
        for v in obj.data.vertices:
            v.co = rot_bl @ v.co
        obj.data.update()

    pts = [blender_to_godot(v.co) for v in obj.data.vertices]
    min_x = min(p.x for p in pts)
    max_x = max(p.x for p in pts)
    min_y = min(p.y for p in pts)
    max_y = max(p.y for p in pts)
    min_z = min(p.z for p in pts)
    max_z = max(p.z for p in pts)
    raw_w = max(1e-5, max_x - min_x)
    raw_h = max(1e-5, max_y - min_y)
    scale_f = target_height / raw_h

    cx_raw = 0.5 * (min_x + max_x)
    cy_raw = min_y
    cz_raw = 0.5 * (min_z + max_z)

    if kind == "weapon":
        if grip_y_m >= 0.0:
            eff_grip_m = max(0.0, min(target_height, grip_y_m))
            eff_frac = eff_grip_m / target_height
        elif grip_frac >= 0.0:
            eff_frac = max(0.0, min(1.0, grip_frac))
            eff_grip_m = eff_frac * target_height
        else:
            eff_frac = 0.22
            eff_grip_m = eff_frac * target_height

        cy_raw = min_y + eff_frac * raw_h
        # Center X/Z on the actual handle/shaft slice around the grip so asymmetric axe heads never pull the grip off-center.
        band = 0.05 * raw_h
        grip_pts = [p for p in pts if abs(p.y - cy_raw) <= band]
        if len(grip_pts) >= 12:
            cx_raw = 0.5 * (min(p.x for p in grip_pts) + max(p.x for p in grip_pts))
            cz_raw = 0.5 * (min(p.z for p in grip_pts) + max(p.z for p in grip_pts))

    elif kind == "shield":
        cy_raw = 0.5 * (min_y + max_y)
        # Ensure hammered convex shield face points toward +Z and rear leather arm-straps sit at Z = 0.
        mid_pts = [p for p in pts if (min_y + 0.34 * raw_h) <= p.y <= (min_y + 0.66 * raw_h)]
        center_pts = [p for p in mid_pts if abs(p.x - cx_raw) <= 0.12 * raw_w]
        edge_pts = [p for p in mid_pts if abs(p.x - cx_raw) >= 0.35 * raw_w]
        if center_pts and edge_pts:
            c_mean_z = sum(p.z for p in center_pts) / len(center_pts)
            e_mean_z = sum(p.z for p in edge_pts) / len(edge_pts)
            if c_mean_z < e_mean_z:
                rot_180 = Matrix.Rotation(math.pi, 4, "Z")
                for v in obj.data.vertices:
                    v.co = rot_180 @ v.co
                obj.data.update()
                pts = [blender_to_godot(v.co) for v in obj.data.vertices]
                min_x = min(p.x for p in pts)
                max_x = max(p.x for p in pts)
                min_y = min(p.y for p in pts)
                max_y = max(p.y for p in pts)
                cx_raw = 0.5 * (min_x + max_x)
                cy_raw = 0.5 * (min_y + max_y)
                mid_pts = [p for p in pts if (min_y + 0.34 * raw_h) <= p.y <= (min_y + 0.66 * raw_h)]

        strap_pts = [p for p in mid_pts if 0.10 * raw_w <= abs(p.x - cx_raw) <= 0.34 * raw_w]
        if strap_pts:
            zs_sorted = sorted(p.z for p in strap_pts)
            # Place forearm cradle inside the rear leather strap loop at Z = 0 so steel front projects cleanly along +Z.
            cz_raw = zs_sorted[max(0, int(len(zs_sorted) * 0.10))]
        else:
            cz_raw = min(p.z for p in pts)

    elif kind == "lantern":
        # Anchor top circular hanging ring center at (0, 0, 0) so body hangs downward along -Y.
        ring_pts = [p for p in pts if p.y >= (min_y + 0.875 * raw_h)]
        if pivot_y_frac >= 0.0:
            cy_raw = min_y + max(0.0, min(1.0, pivot_y_frac)) * raw_h
        elif len(ring_pts) >= 12:
            cy_raw = 0.5 * (min(p.y for p in ring_pts) + max(p.y for p in ring_pts))
        else:
            cy_raw = max_y
        if len(ring_pts) >= 12:
            cx_raw = 0.5 * (min(p.x for p in ring_pts) + max(p.x for p in ring_pts))
            cz_raw = 0.5 * (min(p.z for p in ring_pts) + max(p.z for p in ring_pts))

    elif kind == "helm":
        skull_pts = [p for p in pts if (min_y + 0.20 * raw_h) <= p.y <= (min_y + 0.72 * raw_h)]
        if skull_pts:
            cx_raw = 0.5 * (min(p.x for p in skull_pts) + max(p.x for p in skull_pts))
            cz_raw = 0.5 * (min(p.z for p in skull_pts) + max(p.z for p in skull_pts))
        if pivot_y_frac >= 0.0:
            cy_raw = min_y + max(0.0, min(1.0, pivot_y_frac)) * raw_h
        else:
            cy_raw = min_y

    for v in obj.data.vertices:
        gp = blender_to_godot(v.co)
        nx = (gp.x - cx_raw) * scale_f
        ny = (gp.y - cy_raw) * scale_f
        nz = (gp.z - cz_raw) * scale_f + pivot_z_offset
        v.co = godot_to_blender(nx, ny, nz)
    obj.data.update()

    final_pts = [blender_to_godot(v.co) for v in obj.data.vertices]
    f_min = Vector((min(p.x for p in final_pts), min(p.y for p in final_pts), min(p.z for p in final_pts)))
    f_max = Vector((max(p.x for p in final_pts), max(p.y for p in final_pts), max(p.z for p in final_pts)))
    return {
        "min": f_min,
        "max": f_max,
        "size": f_max - f_min,
    }


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
    w /= np.maximum(w.sum(axis=1, keepdims=True), 1e-6)
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


def _find_metallic_map(mat: bpy.types.Material, bsdf: bpy.types.Node, w: int, h: int) -> np.ndarray | None:
    met_inp = bsdf.inputs.get("Metallic")
    if met_inp is None or not met_inp.is_linked:
        return None
    link = met_inp.links[0]
    src_node = link.from_node
    ch_idx = 0
    tex_node = None
    if src_node.type == "TEX_IMAGE":
        tex_node = src_node
        ch_idx = 0
    elif src_node.type in ("SEPARATE_COLOR", "SEPRGB"):
        out_name = link.from_socket.name.lower()
        ch_idx = 2 if out_name in ("blue", "b") else (1 if out_name in ("green", "g") else 0)
        c_inp = src_node.inputs.get("Color") or src_node.inputs.get("Image")
        if c_inp is not None and c_inp.is_linked and c_inp.links[0].from_node.type == "TEX_IMAGE":
            tex_node = c_inp.links[0].from_node
    if tex_node is None or tex_node.image is None:
        return None
    img = tex_node.image
    iw, ih = img.size[0], img.size[1]
    if iw <= 0 or ih <= 0:
        return None
    px = np.empty(iw * ih * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    rgba = px.reshape((ih, iw, 4))
    if iw != w or ih != h:
        rgba = _lanczos_resize_rgba(rgba, w, h, is_srgb=False, is_normal=False)
    return np.clip(rgba[:, :, ch_idx], 0.0, 1.0)


def _rasterize_uv_mask(
    obj: bpy.types.Object,
    bounds: dict,
    mode: str,
    tex_w: int,
    tex_h: int,
) -> np.ndarray:
    mesh = obj.data
    uv_layer = mesh.uv_layers.active
    mask = np.zeros((tex_h, tex_w), dtype=np.float32)
    if uv_layer is None:
        return mask

    min_y = float(bounds["min"].y)
    size_y = max(1e-5, float(bounds["size"].y))
    size_x = max(1e-5, float(bounds["size"].x))
    uv_data = uv_layer.data

    tris: list[tuple[tuple[float, float], tuple[float, float], tuple[float, float]]] = []
    for poly in mesh.polygons:
        c = blender_to_godot(poly.center)
        yn = (c.y - min_y) / size_y
        if mode == "runes":
            # Strictly blade center fuller above the gothic crown crossguard.
            in_reg = (0.37 <= yn <= 0.94) and (abs(c.x) <= 0.22 * size_x)
        elif mode == "censer":
            # Strictly upper gothic censer ember cage.
            in_reg = 0.72 <= yn <= 0.90
        elif mode == "lantern":
            in_reg = 0.21 <= yn <= 0.67
        elif mode == "visor":
            gn = blender_to_godot(poly.normal)
            # Restrict strictly to forward-facing inner recess behind the visor eye slit.
            in_reg = (0.44 <= yn <= 0.65) and (abs(c.x) <= 0.42 * size_x) and (gn.z > -0.15)
        else:
            in_reg = True
        if not in_reg:
            continue

        lidxs = list(poly.loop_indices)
        uv0 = uv_data[lidxs[0]].uv
        for k in range(1, len(lidxs) - 1):
            uv1 = uv_data[lidxs[k]].uv
            uv2 = uv_data[lidxs[k + 1]].uv
            tris.append(
                (
                    (uv0.x * tex_w, uv0.y * tex_h),
                    (uv1.x * tex_w, uv1.y * tex_h),
                    (uv2.x * tex_w, uv2.y * tex_h),
                )
            )

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

    dil_px = 1.5 if mode in ("lantern", "visor") else 3.5
    dil_rad = max(1, int(round(dil_px * tex_w / 2048.0)))
    dil = _gaussian_blur_2d(mask, sigma=float(dil_rad) * 0.6)
    return (dil > 0.08).astype(np.float32)


def _extract_prop_emission(
    obj: bpy.types.Object,
    bounds: dict,
    mode: str,
    strength_override: float,
    debug_png: str = "",
) -> tuple[int, float, float]:
    if mode == "none" or not obj.data.materials:
        return (0, 0.0, 0.0)
    mat = obj.data.materials[0]
    if mat is None or not mat.node_tree:
        return (0, 0.0, 0.0)
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return (0, 0.0, 0.0)
    bc_inp = bsdf.inputs.get("Base Color")
    if bc_inp is None or not bc_inp.is_linked:
        return (0, 0.0, 0.0)
    src_node = bc_inp.links[0].from_node
    if src_node.type != "TEX_IMAGE" or src_node.image is None:
        return (0, 0.0, 0.0)

    alb_img = src_node.image
    w, h = alb_img.size[0], alb_img.size[1]
    if w <= 0 or h <= 0:
        return (0, 0.0, 0.0)

    px = np.empty(w * h * 4, dtype=np.float32)
    alb_img.pixels.foreach_get(px)
    rgb = px.reshape((h, w, 4))[:, :, :3]
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]

    region_mask = _rasterize_uv_mask(obj, bounds, mode, w, h)
    met_map = _find_metallic_map(mat, bsdf, w, h) if mode in ("lantern", "visor") else None

    if mode == "runes":
        strength = strength_override if strength_override > 0.0 else 2.6
        m_r = np.clip((r - 0.16) / 0.14, 0.0, 1.0)
        m_rb = np.clip(((r - b) - 0.11) / 0.10, 0.0, 1.0)
        m_rg = np.clip((r / np.maximum(g, 1e-4) - 1.35) / 0.30, 0.0, 1.0)
        raw_w = m_r * m_rb * m_rg * region_mask
        halo = _gaussian_blur_2d(raw_w, sigma=max(1.2, 2.0 * (w / 2048.0))) * region_mask
        weight = np.clip(0.95 * raw_w + 0.55 * halo, 0.0, 1.0)
        core_hot = np.clip((r - 0.55) / 0.35, 0.0, 1.0) * raw_w
        tint_edge = np.array([1.0, 0.18, 0.02], dtype=np.float32)
        tint_hot = np.array([1.0, 0.52, 0.12], dtype=np.float32)
        emit_col = tint_edge[None, None, :] * (1.0 - core_hot[:, :, None]) + tint_hot[None, None, :] * core_hot[:, :, None]
        emit_rgb = emit_col * weight[:, :, None]
    elif mode == "visor":
        strength = strength_override if strength_override > 0.0 else 2.6
        max_gb = np.maximum(g, b)
        m_r = np.clip((r - 0.05) / 0.09, 0.0, 1.0)
        m_diff = np.clip(((r - max_gb) - 0.04) / 0.08, 0.0, 1.0)
        m_ratio = np.clip((r / np.maximum(max_gb, 1e-4) - 1.9) / 0.7, 0.0, 1.0)
        m_met = np.clip((0.35 - met_map) / 0.15, 0.0, 1.0) if met_map is not None else np.ones_like(r)
        weight = np.clip(m_r * m_diff * m_ratio * m_met * region_mask, 0.0, 1.0)
        core_hot = np.clip((r - 0.22) / 0.20, 0.0, 1.0) * weight
        tint_deep = np.array([0.96, 0.05, 0.03], dtype=np.float32)
        tint_hot = np.array([1.0, 0.22, 0.09], dtype=np.float32)
        emit_col = tint_deep[None, None, :] * (1.0 - core_hot[:, :, None]) + tint_hot[None, None, :] * core_hot[:, :, None]
        emit_rgb = emit_col * weight[:, :, None]
    elif mode == "lantern":
        strength = strength_override if strength_override > 0.0 else 3.2
        m_r = np.clip((r - 0.18) / 0.12, 0.0, 1.0)
        m_rb = np.clip(((r - b) - 0.14) / 0.10, 0.0, 1.0)
        m_rg = np.clip((r / np.maximum(g, 1e-4) - 1.18) / 0.22, 0.0, 1.0)
        m_gb = np.clip((g / np.maximum(b, 1e-4) - 1.55) / 0.45, 0.0, 1.0)
        m_met = np.clip((0.22 - met_map) / 0.12, 0.0, 1.0) if met_map is not None else np.ones_like(r)
        weight = np.clip(m_r * m_rb * m_rg * m_gb * m_met * region_mask, 0.0, 1.0)
        # Pure grayscale luminance mask so Godot EMISSION_OP_MULTIPLY tints cleanly to any LanternAspect color without orange muddying.
        lum = np.clip((r * 0.65 + g * 0.35) * 2.45, 0.35, 1.0)
        val = np.clip(weight * lum, 0.0, 1.0)
        emit_rgb = np.stack([val, val, val], axis=-1)
    else:
        strength = strength_override if strength_override > 0.0 else 2.8
        m_r = np.clip((r - 0.18) / 0.14, 0.0, 1.0)
        m_rb = np.clip(((r - b) - 0.13) / 0.10, 0.0, 1.0)
        m_rg = np.clip((r / np.maximum(g, 1e-4) - 1.22) / 0.22, 0.0, 1.0)
        raw_w = m_r * m_rb * m_rg * region_mask
        halo = _gaussian_blur_2d(raw_w, sigma=max(1.5, 2.8 * (w / 2048.0))) * region_mask
        weight = np.clip(0.92 * raw_w + 0.45 * halo, 0.0, 1.0)
        if mode == "censer":
            warm_tint = np.array([1.0, 0.80, 0.56], dtype=np.float32)
            lum = np.clip((r * 0.72 + g * 0.28) * 1.65, 0.35, 1.0)
            emit_rgb = warm_tint[None, None, :] * (weight * lum)[:, :, None]
        else:
            warm_tint = np.array([1.0, 0.48, 0.12], dtype=np.float32)
            emit_rgb = warm_tint[None, None, :] * weight[:, :, None]

    emit_rgba = np.ones((h, w, 4), dtype=np.float32)
    emit_rgba[:, :, :3] = np.clip(emit_rgb, 0.0, 1.0)

    emit_img = bpy.data.images.new(name=f"{mat.name}_Emission", width=w, height=h, alpha=False)
    emit_img.colorspace_settings.name = "sRGB"
    emit_img.pixels.foreach_set(emit_rgba.ravel())
    emit_img.update()
    if debug_png:
        os.makedirs(os.path.dirname(os.path.abspath(debug_png)), exist_ok=True)
        dbg_img = emit_img.copy()
        dbg_img.filepath_raw = debug_png
        dbg_img.file_format = "PNG"
        dbg_img.save()
        bpy.data.images.remove(dbg_img)
    emit_img.pack()

    tex_node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex_node.name = "PropEmissionTex"
    tex_node.image = emit_img
    tex_node.location = (bsdf.location.x - 360, bsdf.location.y - 320)
    emit_col_inp = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
    if emit_col_inp is not None:
        mat.node_tree.links.new(tex_node.outputs["Color"], emit_col_inp)
    emit_str_inp = bsdf.inputs.get("Emission Strength")
    if emit_str_inp is not None:
        emit_str_inp.default_value = strength

    lit_px = int((weight > 0.08).sum())
    pct = 100.0 * lit_px / float(w * h)
    return (lit_px, pct, strength)


def _resample_textures(tex_res: int) -> None:
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

    for img in srgb_imgs:
        _resize_blender_image_lanczos(img, tex_res, is_srgb=True, is_normal=False)
        img.colorspace_settings.name = "sRGB"
    for img in normal_imgs:
        _resize_blender_image_lanczos(img, tex_res, is_srgb=False, is_normal=True)
        img.colorspace_settings.name = "Non-Color"
    for img in data_imgs:
        _resize_blender_image_lanczos(img, tex_res, is_srgb=False, is_normal=False)
        img.colorspace_settings.name = "Non-Color"


def _export_prop_glb(
    obj: bpy.types.Object,
    output_path: str,
    image_format: str,
    image_quality: int,
) -> int:
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

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
        export_apply=True,
        export_animations=False,
    )
    return os.path.getsize(output_path)


def main() -> None:
    args = _parse_args()
    _reset_cpu_scene()

    prop = _import_joined_mesh(args.input, args.mesh_name)
    if args.mat_name and prop.data.materials:
        prop.data.materials[0].name = args.mat_name

    raw_tris = _count_tris(prop)
    dec_tris = _decimate_uv_preserving(prop, args.target_tris)
    bounds = _align_and_scale_prop(
        prop,
        kind=args.kind,
        target_height=args.height,
        grip_frac=args.grip_frac,
        grip_y_m=args.grip_y_m,
        yaw_deg=args.yaw_deg,
        pivot_y_frac=args.pivot_y_frac,
        pivot_z_offset=args.pivot_z_offset,
    )

    lit_px, lit_pct, emit_str = _extract_prop_emission(
        prop,
        bounds=bounds,
        mode=args.extract_emission,
        strength_override=args.emission_strength,
        debug_png=args.debug_emission_png,
    )

    _resample_textures(args.tex_res)

    out_bytes = _export_prop_glb(
        prop,
        output_path=args.output,
        image_format=args.image_format,
        image_quality=args.image_quality,
    )

    bmin, bmax, bsize = bounds["min"], bounds["max"], bounds["size"]
    print(
        f"[prep_hunyuan_gear] {os.path.basename(args.output)} | kind={args.kind} "
        f"| tris: {raw_tris} -> {dec_tris} | size: {out_bytes / 1024.0:.1f} KB "
        f"| AABB_gd X=[{bmin.x:+.3f},{bmax.x:+.3f}] Y=[{bmin.y:+.3f},{bmax.y:+.3f}] Z=[{bmin.z:+.3f},{bmax.z:+.3f}] "
        f"({bsize.x:.3f}x{bsize.y:.3f}x{bsize.z:.3f}m)"
    )
    if args.extract_emission != "none":
        print(
            f"[prep_hunyuan_gear]   emission={args.extract_emission} lit_px={lit_px} "
            f"({lit_pct:.3f}% @ src res), strength={emit_str:.2f}"
        )


if __name__ == "__main__":
    main()
