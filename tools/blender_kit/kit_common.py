import math
import os
import random
from typing import Callable

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
KIT_OUT_DIR = os.path.join(ROOT, "assets", "models", "kit")

# Master rig bone definitions in Godot space (scale=1.0 -> 1.95m hero height).
# +Y up, +Z front, -Z back, +X character left, -X character right.
MASTER_BONES: list[tuple[str, str | None, tuple[float, float, float], tuple[float, float, float]]] = [
    ("root", None, (0.0, 0.0, 0.0), (0.0, 0.24, 0.0)),
    ("hips", "root", (0.0, 1.02, 0.0), (0.0, 1.13, 0.0)),
    ("spine", "hips", (0.0, 1.13, 0.0), (0.0, 1.31, 0.0)),
    ("chest", "spine", (0.0, 1.31, 0.0), (0.0, 1.56, 0.0)),
    ("neck", "chest", (0.0, 1.56, 0.0), (0.0, 1.66, 0.01)),
    ("head", "neck", (0.0, 1.66, 0.01), (0.0, 1.93, 0.01)),
    ("shoulder_l", "chest", (0.06, 1.49, 0.0), (0.23, 1.54, 0.0)),
    ("upper_arm_l", "shoulder_l", (0.23, 1.54, 0.0), (0.295, 1.23, -0.02)),
    ("forearm_l", "upper_arm_l", (0.295, 1.23, -0.02), (0.315, 0.94, 0.05)),
    ("hand_l", "forearm_l", (0.315, 0.94, 0.05), (0.320, 0.81, 0.07)),
    ("offhand_l", "hand_l", (0.322, 0.855, 0.068), (0.322, 0.855, 0.30)),
    ("shoulder_r", "chest", (-0.06, 1.49, 0.0), (-0.23, 1.54, 0.0)),
    ("upper_arm_r", "shoulder_r", (-0.23, 1.54, 0.0), (-0.295, 1.23, -0.02)),
    ("forearm_r", "upper_arm_r", (-0.295, 1.23, -0.02), (-0.315, 0.94, 0.05)),
    ("hand_r", "forearm_r", (-0.315, 0.94, 0.05), (-0.320, 0.81, 0.07)),
    ("weapon_r", "hand_r", (-0.322, 0.855, 0.068), (-0.322, 0.855, 0.36)),
    ("thigh_l", "hips", (0.105, 0.99, 0.0), (0.125, 0.54, 0.015)),
    ("shin_l", "thigh_l", (0.125, 0.54, 0.015), (0.125, 0.10, -0.015)),
    ("foot_l", "shin_l", (0.125, 0.10, -0.015), (0.125, 0.02, 0.16)),
    ("thigh_r", "hips", (-0.105, 0.99, 0.0), (-0.125, 0.54, 0.015)),
    ("shin_r", "thigh_r", (-0.125, 0.54, 0.015), (-0.125, 0.10, -0.015)),
    ("foot_r", "shin_r", (-0.125, 0.10, -0.015), (-0.125, 0.02, 0.16)),
    ("cape_0", "chest", (0.0, 1.53, -0.14), (0.0, 1.12, -0.21)),
    ("cape_1", "cape_0", (0.0, 1.12, -0.21), (0.0, 0.65, -0.25)),
    ("cape_2", "cape_1", (0.0, 0.65, -0.25), (0.0, 0.14, -0.29)),
    ("lantern_bone", "hips", (0.205, 0.96, 0.085), (0.205, 0.72, 0.085)),
]


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30


def godot_to_blender(x: float, y: float, z: float) -> Vector:
    # Blender glTF export with export_yup=True maps (X_bl, Y_bl, Z_bl) -> (X_gd, Z_bl, -Y_bl).
    return Vector((x, -z, y))


def blender_to_godot(co: Vector) -> Vector:
    return Vector((float(co.x), float(co.z), float(-co.y)))


def hex_to_srgb(hex_str: str) -> tuple[float, float, float]:
    h = hex_str.lstrip("#")
    return (int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0)


def _srgb_to_linear_ch(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_to_linear(hex_str: str) -> tuple[float, float, float, float]:
    r, g, b = hex_to_srgb(hex_str)
    return (_srgb_to_linear_ch(r), _srgb_to_linear_ch(g), _srgb_to_linear_ch(b), 1.0)


def _tileable_noise_grid(size: int, seed: int, octaves: int = 3) -> list[list[float]]:
    rng = random.Random(seed)
    grid = [[0.0] * size for _ in range(size)]
    amp = 1.0
    norm = 0.0
    freq = 4
    for _ in range(octaves):
        coarse = [[rng.random() for _ in range(freq)] for _ in range(freq)]
        for y in range(size):
            fy = (y / size) * freq
            y0 = int(fy) % freq
            y1 = (y0 + 1) % freq
            ty = fy - int(fy)
            ty = ty * ty * (3.0 - 2.0 * ty)
            for x in range(size):
                fx = (x / size) * freq
                x0 = int(fx) % freq
                x1 = (x0 + 1) % freq
                tx = fx - int(fx)
                tx = tx * tx * (3.0 - 2.0 * tx)
                v0 = coarse[y0][x0] * (1.0 - tx) + coarse[y0][x1] * tx
                v1 = coarse[y1][x0] * (1.0 - tx) + coarse[y1][x1] * tx
                grid[y][x] += (v0 * (1.0 - ty) + v1 * ty) * amp
        norm += amp
        amp *= 0.5
        freq *= 2
    for y in range(size):
        for x in range(size):
            grid[y][x] /= norm
    return grid


def _make_procedural_textures(
    key: str,
    base_srgb: tuple[float, float, float],
    metallic: float,
    roughness: float,
    pattern: str,
    seed: int,
) -> tuple[bpy.types.Image, bpy.types.Image]:
    size = 128
    noise = _tileable_noise_grid(size, seed, octaves=3)
    rng = random.Random(seed + 99)
    streak = [rng.uniform(-1.0, 1.0) for _ in range(size)]

    alb_pixels = [0.0] * (size * size * 4)
    orm_pixels = [0.0] * (size * size * 4)

    for y in range(size):
        for x in range(size):
            n = noise[y][x] - 0.5
            r_var = 0.0
            a_mul = 1.0
            if pattern == "brushed":
                s = streak[y] * 0.5 + streak[(y + 1) % size] * 0.5
                a_mul = 1.0 + n * 0.16 + s * 0.08
                r_var = -n * 0.06 + s * 0.03
            elif pattern == "hammered":
                pit = math.sin(x * 0.35 + n * 4.0) * math.cos(y * 0.35 - n * 4.0)
                a_mul = 1.0 + n * 0.22 + pit * 0.08
                r_var = -n * 0.08 + pit * 0.04
            elif pattern == "cloth":
                weave = math.sin(x * 1.5708) * math.sin(y * 1.5708)
                a_mul = 1.0 + n * 0.18 + weave * 0.10
                r_var = n * 0.05
            elif pattern == "leather":
                grain = math.sin(x * 0.7 + n * 5.0) * 0.5 + math.cos(y * 0.7 - n * 5.0) * 0.5
                a_mul = 1.0 + n * 0.20 + grain * 0.07
                r_var = -n * 0.08
            elif pattern == "stone":
                mortar = 1.0 if (y % 48 < 1 or ((x + (y // 48) * 24) % 64 < 1)) else 0.0
                a_mul = (0.86 if mortar > 0.5 else 1.0) * (1.0 + n * 0.24)
                r_var = 0.04 if mortar > 0.5 else n * 0.07
            elif pattern == "bone":
                striation = streak[x] * 0.08
                a_mul = 1.0 + n * 0.16 + striation
                r_var = n * 0.06

            ar = max(0.0, min(1.0, base_srgb[0] * a_mul))
            ag = max(0.0, min(1.0, base_srgb[1] * a_mul))
            ab = max(0.0, min(1.0, base_srgb[2] * a_mul))

            rg = max(0.04, min(0.99, roughness + r_var))
            mt = max(0.0, min(1.0, metallic))

            idx = (y * size + x) * 4
            alb_pixels[idx] = ar
            alb_pixels[idx + 1] = ag
            alb_pixels[idx + 2] = ab
            alb_pixels[idx + 3] = 1.0

            orm_pixels[idx] = 1.0
            orm_pixels[idx + 1] = rg
            orm_pixels[idx + 2] = mt
            orm_pixels[idx + 3] = 1.0

    alb_img = bpy.data.images.new(f"tex_{key}_alb", width=size, height=size, alpha=False)
    alb_img.colorspace_settings.name = "sRGB"
    alb_img.pixels.foreach_set(alb_pixels)
    alb_img.pack()

    orm_img = bpy.data.images.new(f"tex_{key}_orm", width=size, height=size, alpha=False)
    orm_img.colorspace_settings.name = "Non-Color"
    orm_img.pixels.foreach_set(orm_pixels)
    orm_img.pack()
    return alb_img, orm_img


def make_pbr_mat(
    name: str,
    base_srgb: tuple[float, float, float],
    metallic: float,
    roughness: float,
    pattern: str = "brushed",
    seed: int = 1,
    emission_srgb: tuple[float, float, float] | None = None,
    emission_strength: float = 0.0,
    use_vertex_color: bool = False,
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name=name)
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    if bsdf is None:
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")

    if emission_srgb is not None:
        lin_col = (
            _srgb_to_linear_ch(base_srgb[0]),
            _srgb_to_linear_ch(base_srgb[1]),
            _srgb_to_linear_ch(base_srgb[2]),
            1.0,
        )
        bsdf.inputs["Base Color"].default_value = lin_col
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        lin_emit = (
            _srgb_to_linear_ch(emission_srgb[0]),
            _srgb_to_linear_ch(emission_srgb[1]),
            _srgb_to_linear_ch(emission_srgb[2]),
            1.0,
        )
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = lin_emit
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = emission_strength
        return mat

    alb_img, orm_img = _make_procedural_textures(name, base_srgb, metallic, roughness, pattern, seed)

    tex_alb = nt.nodes.new("ShaderNodeTexImage")
    tex_alb.image = alb_img
    tex_orm = nt.nodes.new("ShaderNodeTexImage")
    tex_orm.image = orm_img

    sep = nt.nodes.new("ShaderNodeSeparateColor")
    sep.mode = "RGB"
    nt.links.new(tex_orm.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])

    if use_vertex_color:
        vcol = nt.nodes.new("ShaderNodeVertexColor")
        vcol.layer_name = "Color"
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 0.0
        nt.links.new(tex_alb.outputs["Color"], mix.inputs[6])
        nt.links.new(vcol.outputs["Color"], mix.inputs[7])
        nt.links.new(tex_alb.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        nt.links.new(tex_alb.outputs["Color"], bsdf.inputs["Base Color"])

    return mat


def make_kit_materials() -> dict[str, bpy.types.Material]:
    # Material palette calibrated for Godot 4.7 Mobile PBR + armor_forge.gdshader compatibility.
    return {
        "gunmetal": make_pbr_mat("GunmetalPlate", (0.38, 0.42, 0.48), 0.88, 0.32, "brushed", 11),
        "black_steel": make_pbr_mat("BlackenedSteel", (0.26, 0.29, 0.34), 0.90, 0.28, "hammered", 22),
        "honed_steel": make_pbr_mat("HonedBladeSteel", (0.62, 0.65, 0.70), 0.94, 0.22, "brushed", 33),
        "gold": make_pbr_mat("AntiqueGoldTrim", hex_to_srgb("#C49A48"), 0.90, 0.28, "brushed", 44),
        "cloth": make_pbr_mat("DarkWoolCloth", hex_to_srgb("#161A26"), 0.0, 0.92, "cloth", 55),
        "crimson_cloth": make_pbr_mat("TatteredCrimsonCloth", hex_to_srgb("#33151A"), 0.0, 0.91, "cloth", 66),
        "ash_cloth": make_pbr_mat("AshenRaggedCloth", hex_to_srgb("#2F3134"), 0.0, 0.93, "cloth", 77),
        "leather": make_pbr_mat("DarkStrapLeather", hex_to_srgb("#2C2018"), 0.0, 0.78, "leather", 88),
        "bone": make_pbr_mat("WeatheredBone", hex_to_srgb("#948B7B"), 0.0, 0.84, "bone", 99),
        "stone": make_pbr_mat("GothicAshlarStone", hex_to_srgb("#3B4048"), 0.0, 0.89, "stone", 110),
        "dark_stone": make_pbr_mat("ObsidianStone", hex_to_srgb("#242830"), 0.0, 0.86, "stone", 121),
        "emit_amber": make_pbr_mat("EmissiveAmber", (0.95, 0.62, 0.22), 0.0, 0.25, emission_srgb=(0.94, 0.54, 0.14), emission_strength=1.7),
        "emit_blue": make_pbr_mat("EmissiveSoulBlue", (0.18, 0.52, 0.88), 0.0, 0.18, emission_srgb=(0.20, 0.58, 0.96), emission_strength=1.2),
        "emit_cinder": make_pbr_mat("EmissiveCinder", (0.85, 0.24, 0.06), 0.0, 0.35, emission_srgb=(0.92, 0.28, 0.06), emission_strength=1.5),
    }


def build_master_armature(scale: float = 1.0, name: str = "Armature") -> bpy.types.Object:
    arm_data = bpy.data.armatures.new(f"{name}Data")
    arm_obj = bpy.data.objects.new(name, arm_data)
    bpy.context.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")

    created: dict[str, bpy.types.EditBone] = {}
    for bname, parent_name, head_gd, tail_gd in MASTER_BONES:
        eb = arm_data.edit_bones.new(bname)
        eb.head = godot_to_blender(head_gd[0] * scale, head_gd[1] * scale, head_gd[2] * scale)
        eb.tail = godot_to_blender(tail_gd[0] * scale, tail_gd[1] * scale, tail_gd[2] * scale)
        eb.use_deform = True
        if parent_name is not None:
            eb.parent = created[parent_name]
        eb.use_connect = False
        if bname.startswith(("shoulder_", "upper_arm_", "forearm_", "hand_")):
            eb.align_roll(Vector((0.0, -1.0, 0.0)))
        else:
            eb.align_roll(Vector((0.0, -1.0, 0.0)))
        created[bname] = eb

    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return arm_obj


class RiggedMeshBuilder:
    def __init__(
        self,
        name: str,
        materials: list[bpy.types.Material],
        armature_obj: bpy.types.Object | None = None,
    ) -> None:
        self.mesh = bpy.data.meshes.new(f"{name}Mesh")
        self.obj = bpy.data.objects.new(name, self.mesh)
        bpy.context.collection.objects.link(self.obj)
        for m in materials:
            self.obj.data.materials.append(m)

        self.bm = bmesh.new()
        self.dvert_lay = self.bm.verts.layers.deform.verify()
        self.bone_group_idx: dict[str, int] = {}

        if armature_obj is not None:
            self.obj.parent = armature_obj
            mod = self.obj.modifiers.new(name="Armature", type="ARMATURE")
            mod.object = armature_obj
            for b in armature_obj.data.bones:
                vg = self.obj.vertex_groups.new(name=b.name)
                self.bone_group_idx[b.name] = vg.index

    def _assign_weights(self, vert: bmesh.types.BMVert, weights: dict[str, float]) -> None:
        if not self.bone_group_idx or not weights:
            return
        total = sum(max(0.0, w) for w in weights.values())
        if total <= 1e-6:
            return
        dv = vert[self.dvert_lay]
        for bname, w in weights.items():
            if w > 1e-5 and bname in self.bone_group_idx:
                dv[self.bone_group_idx[bname]] = w / total

    def add_vert_godot(self, x: float, y: float, z: float, weights: dict[str, float] | None = None) -> bmesh.types.BMVert:
        v = self.bm.verts.new(godot_to_blender(x, y, z))
        if weights:
            self._assign_weights(v, weights)
        return v

    def add_loft(
        self,
        rings: list[list[Vector]],
        mat_index: int = 0,
        weights: dict[str, float] | list[dict[str, float]] | None = None,
        cap_start: bool = True,
        cap_end: bool = True,
        closed_ring: bool = True,
        bevel_width: float = 0.0,
    ) -> list[bmesh.types.BMFace]:
        vert_rings: list[list[bmesh.types.BMVert]] = []
        for idx, ring in enumerate(rings):
            ring_w = weights[idx] if isinstance(weights, list) else weights
            vr: list[bmesh.types.BMVert] = []
            for p in ring:
                v = self.bm.verts.new(p)
                if ring_w:
                    self._assign_weights(v, ring_w)
                vr.append(v)
            vert_rings.append(vr)

        faces: list[bmesh.types.BMFace] = []
        for i in range(len(vert_rings) - 1):
            r0 = vert_rings[i]
            r1 = vert_rings[i + 1]
            n = len(r0)
            limit = n if closed_ring else n - 1
            for j in range(limit):
                jn = (j + 1) % n
                pts = [r0[j], r0[jn], r1[jn], r1[j]]
                unique: list[bmesh.types.BMVert] = []
                for v in pts:
                    if v not in unique:
                        unique.append(v)
                if len(unique) >= 3:
                    try:
                        f = self.bm.faces.new(unique)
                        f.material_index = mat_index
                        faces.append(f)
                    except ValueError:
                        pass

        if closed_ring and cap_start and len(vert_rings[0]) >= 3:
            try:
                f = self.bm.faces.new(list(reversed(vert_rings[0])))
                f.material_index = mat_index
                faces.append(f)
            except ValueError:
                pass
        if closed_ring and cap_end and len(vert_rings[-1]) >= 3:
            try:
                f = self.bm.faces.new(vert_rings[-1])
                f.material_index = mat_index
                faces.append(f)
            except ValueError:
                pass

        if bevel_width > 0.0 and faces:
            edges = list({e for f in faces for e in f.edges if len(e.link_faces) == 2})
            sharp = [
                e for e in edges
                if e.link_faces[0].normal.dot(e.link_faces[1].normal) < 0.72
            ]
            if sharp:
                bmesh.ops.bevel(
                    self.bm,
                    geom=sharp,
                    offset=bevel_width,
                    segments=1,
                    affect="EDGES",
                    clamp_overlap=True,
                )
        return faces

    def add_grid_sheet(
        self,
        grid_pts: list[list[Vector]],
        mat_index: int = 0,
        row_weights: list[dict[str, float]] | None = None,
        thickness: float = 0.0,
    ) -> list[bmesh.types.BMFace]:
        rows = len(grid_pts)
        cols = len(grid_pts[0])
        vgrid: list[list[bmesh.types.BMVert]] = []
        for r in range(rows):
            rw = row_weights[r] if row_weights is not None else None
            row_v: list[bmesh.types.BMVert] = []
            for c in range(cols):
                v = self.bm.verts.new(grid_pts[r][c])
                if rw:
                    self._assign_weights(v, rw)
                row_v.append(v)
            vgrid.append(row_v)

        faces: list[bmesh.types.BMFace] = []
        for r in range(rows - 1):
            for c in range(cols - 1):
                f = self.bm.faces.new([vgrid[r][c], vgrid[r + 1][c], vgrid[r + 1][c + 1], vgrid[r][c + 1]])
                f.material_index = mat_index
                faces.append(f)

        if thickness > 0.0:
            self.bm.normal_update()
            bgrid: list[list[bmesh.types.BMVert]] = []
            for r in range(rows):
                rw = row_weights[r] if row_weights is not None else None
                brow: list[bmesh.types.BMVert] = []
                for c in range(cols):
                    fv = vgrid[r][c]
                    nrm = fv.normal if fv.normal.length > 1e-4 else Vector((0.0, 1.0, 0.0))
                    bv = self.bm.verts.new(fv.co - nrm * thickness)
                    if rw:
                        self._assign_weights(bv, rw)
                    brow.append(bv)
                bgrid.append(brow)
            for r in range(rows - 1):
                for c in range(cols - 1):
                    fb = self.bm.faces.new([bgrid[r][c], bgrid[r][c + 1], bgrid[r + 1][c + 1], bgrid[r + 1][c]])
                    fb.material_index = mat_index
                    faces.append(fb)
            for c in range(cols - 1):
                f_top = self.bm.faces.new([vgrid[0][c], vgrid[0][c + 1], bgrid[0][c + 1], bgrid[0][c]])
                f_top.material_index = mat_index
                f_bot = self.bm.faces.new([vgrid[-1][c + 1], vgrid[-1][c], bgrid[-1][c], bgrid[-1][c + 1]])
                f_bot.material_index = mat_index
                faces.extend([f_top, f_bot])
            for r in range(rows - 1):
                f_l = self.bm.faces.new([vgrid[r + 1][0], vgrid[r][0], bgrid[r][0], bgrid[r + 1][0]])
                f_l.material_index = mat_index
                f_r = self.bm.faces.new([vgrid[r][-1], vgrid[r + 1][-1], bgrid[r + 1][-1], bgrid[r][-1]])
                f_r.material_index = mat_index
                faces.extend([f_l, f_r])
        return faces

    def add_beveled_box_godot(
        self,
        center: tuple[float, float, float],
        size: tuple[float, float, float],
        mat_index: int = 0,
        weights: dict[str, float] | None = None,
        bevel_width: float = 0.012,
        rot_euler_godot: tuple[float, float, float] = (0.0, 0.0, 0.0),
    ) -> list[bmesh.types.BMFace]:
        hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
        rot_gd = Euler(rot_euler_godot, "YXZ").to_matrix()
        cx, cy, cz = center
        corners_gd = [
            Vector((-hx, -hy, -hz)),
            Vector((hx, -hy, -hz)),
            Vector((hx, -hy, hz)),
            Vector((-hx, -hy, hz)),
            Vector((-hx, hy, -hz)),
            Vector((hx, hy, -hz)),
            Vector((hx, hy, hz)),
            Vector((-hx, hy, hz)),
        ]
        verts: list[bmesh.types.BMVert] = []
        for c in corners_gd:
            cr = rot_gd @ c
            v = self.bm.verts.new(godot_to_blender(cx + cr.x, cy + cr.y, cz + cr.z))
            if weights:
                self._assign_weights(v, weights)
            verts.append(v)

        quads = [
            (0, 3, 2, 1),
            (4, 5, 6, 7),
            (0, 1, 5, 4),
            (1, 2, 6, 5),
            (2, 3, 7, 6),
            (3, 0, 4, 7),
        ]
        faces: list[bmesh.types.BMFace] = []
        for q in quads:
            f = self.bm.faces.new([verts[i] for i in q])
            f.material_index = mat_index
            faces.append(f)

        if bevel_width > 0.0:
            edges = list({e for f in faces for e in f.edges})
            bmesh.ops.bevel(
                self.bm,
                geom=edges,
                offset=bevel_width,
                segments=1,
                affect="EDGES",
                clamp_overlap=True,
            )
        return faces

    def finalize(
        self,
        smooth_angle_deg: float = 35.0,
        sway_weight_fn: Callable[[Vector], float] | None = None,
    ) -> bpy.types.Object:
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
        uv_layer = self.bm.loops.layers.uv.verify()
        for f in self.bm.faces:
            n = f.normal
            ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
            for loop in f.loops:
                co = loop.vert.co
                if ay >= ax and ay >= az:
                    u, v = co.x * 1.4 + 0.5, co.z * 1.4 + 0.5
                elif ax >= ay and ax >= az:
                    u, v = co.y * 1.4 + 0.5, co.z * 1.4 + 0.5
                else:
                    u, v = co.x * 1.4 + 0.5, co.y * 1.4 + 0.5
                loop[uv_layer].uv = (u, v)

        sharp_cos = math.cos(math.radians(smooth_angle_deg))
        for f in self.bm.faces:
            f.smooth = True
        for e in self.bm.edges:
            if len(e.link_faces) == 2:
                e.smooth = e.link_faces[0].normal.dot(e.link_faces[1].normal) >= sharp_cos

        self.bm.to_mesh(self.mesh)
        self.bm.free()

        if sway_weight_fn is not None:
            while len(self.mesh.color_attributes) > 0:
                self.mesh.color_attributes.remove(self.mesh.color_attributes[0])
            col_attr = self.mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
            self.mesh.color_attributes.active_color = col_attr
            self.mesh.color_attributes.render_color_index = 0
            for idx, v in enumerate(self.mesh.vertices):
                w = float(max(0.0, min(1.0, sway_weight_fn(v.co))))
                col_attr.data[idx].color = (w, 0.0, 0.0, 1.0)

        return self.obj


def elliptical_ring_godot(
    cx: float,
    cy: float,
    cz: float,
    rx: float,
    rz: float,
    sides: int = 12,
    keel_front: float = 0.0,
    keel_back: float = 0.0,
    flute_amp: float = 0.0,
    flute_freq: int = 6,
    twist: float = 0.0,
    tilt_x: float = 0.0,
) -> list[Vector]:
    pts: list[Vector] = []
    ct = math.cos(tilt_x)
    st = math.sin(tilt_x)
    for i in range(sides):
        ang = (2.0 * math.pi * i) / sides + twist
        ca = math.cos(ang)
        sa = math.sin(ang)
        flute = 1.0 + flute_amp * math.cos(ang * flute_freq) if flute_amp != 0.0 else 1.0
        lx = ca * rx * flute
        lz = sa * rz * flute
        if sa > 0.0 and keel_front > 0.0:
            lz += keel_front * (sa ** 2.6)
        elif sa < 0.0 and keel_back > 0.0:
            lz -= keel_back * ((-sa) ** 2.6)
        dy = -lz * st
        dz = lz * ct
        pts.append(godot_to_blender(cx + lx, cy + dy, cz + dz))
    return pts


def tube_ring_godot(
    center: tuple[float, float, float],
    tangent_gd: tuple[float, float, float],
    rx: float,
    ry: float,
    sides: int = 8,
    flute_amp: float = 0.0,
    flute_freq: int = 4,
) -> list[Vector]:
    t = Vector(tangent_gd)
    if t.length < 1e-6:
        t = Vector((0.0, 1.0, 0.0))
    t.normalize()
    up_hint = Vector((0.0, 0.0, 1.0)) if abs(t.z) < 0.90 else Vector((1.0, 0.0, 0.0))
    side_a = t.cross(up_hint).normalized()
    side_b = t.cross(side_a).normalized()
    c = Vector(center)
    pts: list[Vector] = []
    for i in range(sides):
        ang = 2.0 * math.pi * i / sides
        flute = 1.0 + flute_amp * math.cos(ang * flute_freq) if flute_amp != 0.0 else 1.0
        p = c + side_a * (math.cos(ang) * rx * flute) + side_b * (math.sin(ang) * ry * flute)
        pts.append(godot_to_blender(p.x, p.y, p.z))
    return pts


def diamond_blade_ring_godot(
    center: tuple[float, float, float],
    axis_gd: tuple[float, float, float],
    edge_axis_gd: tuple[float, float, float],
    half_w: float,
    half_t: float,
    fuller: float = 0.0,
) -> list[Vector]:
    e = Vector(edge_axis_gd).normalized()
    a = Vector(axis_gd).normalized()
    n = e.cross(a).normalized()
    c = Vector(center)
    fw = half_w * 0.36
    ft = half_t * (1.0 - fuller * 0.38)
    ct = half_t * (1.0 - fuller * 0.56)
    offsets = [
        e * half_w,
        e * fw + n * ft,
        n * ct,
        -e * fw + n * ft,
        -e * half_w,
        -e * fw - n * ft,
        -n * ct,
        e * fw - n * ft,
    ]
    return [godot_to_blender(c.x + o.x, c.y + o.y, c.z + o.z) for o in offsets]


def export_kit_glb(
    objects: list[bpy.types.Object],
    out_filename: str,
    rigged: bool = False,
) -> str:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]

    os.makedirs(KIT_OUT_DIR, exist_ok=True)
    out_path = os.path.join(KIT_OUT_DIR, out_filename)

    kwargs = dict(
        filepath=out_path,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_normals=True,
        export_texcoords=True,
        export_materials="EXPORT",
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=True,
        export_active_vertex_color_when_no_material=True,
        export_apply=not rigged,
        export_skins=rigged,
        export_def_bones=False,
        export_animations=rigged,
    )
    if rigged:
        kwargs.update(
            export_animation_mode="NLA_TRACKS",
            export_nla_strips=True,
            export_anim_slide_to_zero=True,
            export_optimize_animation_size=False,
        )

    bpy.ops.export_scene.gltf(**kwargs)

    total_tris = 0
    for obj in objects:
        if obj.type == "MESH":
            total_tris += sum(max(1, len(p.vertices) - 2) for p in obj.data.polygons)
    print(f"[kit] Exported {out_path} ({total_tris} tris)")
    return out_path
