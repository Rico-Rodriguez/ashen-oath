import math
import os
import bpy
import bmesh
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "models", "forged")


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_pbr_mat(
    name: str,
    base_color: tuple[float, float, float, float],
    metallic: float,
    roughness: float,
    emission_color: tuple[float, float, float, float] | None = None,
    emission_strength: float = 0.0,
    use_vertex_color: bool = False,
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name=name)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf is None:
        bsdf = mat.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = base_color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if use_vertex_color:
        vcol = mat.node_tree.nodes.new("ShaderNodeVertexColor")
        vcol.layer_name = "Color"
        mat.node_tree.links.new(vcol.outputs["Color"], bsdf.inputs["Base Color"])
    if emission_color is not None:
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = emission_color
        elif "Emission" in bsdf.inputs:
            bsdf.inputs["Emission"].default_value = emission_color
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def godot_to_blender(x: float, y: float, z: float) -> Vector:
    # Blender glTF export with export_yup=True maps (X_bl, Y_bl, Z_bl) -> (X_gd, Z_bl, -Y_bl).
    return Vector((x, -z, y))


def blender_to_godot_y(co: Vector) -> float:
    return float(co.z)


def blender_to_godot_z(co: Vector) -> float:
    return float(-co.y)


def add_loft(
    bm: bmesh.types.BMesh,
    rings: list[list[Vector]],
    mat_index: int = 0,
    cap_start: bool = True,
    cap_end: bool = True,
    closed_ring: bool = True,
) -> list[bmesh.types.BMFace]:
    vert_rings: list[list[bmesh.types.BMVert]] = []
    for r in rings:
        vert_rings.append([bm.verts.new(p) for p in r])
    faces: list[bmesh.types.BMFace] = []
    for i in range(len(vert_rings) - 1):
        r0 = vert_rings[i]
        r1 = vert_rings[i + 1]
        n = len(r0)
        limit = n if closed_ring else n - 1
        for j in range(limit):
            jn = (j + 1) % n
            pts = [r0[j], r0[jn], r1[jn], r1[j]]
            unique = []
            for v in pts:
                if v not in unique:
                    unique.append(v)
            if len(unique) >= 3:
                try:
                    f = bm.faces.new(unique)
                    f.material_index = mat_index
                    faces.append(f)
                except ValueError:
                    pass
    if closed_ring and cap_start and len(vert_rings[0]) >= 3:
        try:
            f = bm.faces.new(list(reversed(vert_rings[0])))
            f.material_index = mat_index
            faces.append(f)
        except ValueError:
            pass
    if closed_ring and cap_end and len(vert_rings[-1]) >= 3:
        try:
            f = bm.faces.new(vert_rings[-1])
            f.material_index = mat_index
            faces.append(f)
        except ValueError:
            pass
    return faces


def circle_ring_godot(cx: float, cy: float, cz: float, rx: float, rz: float, sides: int, twist: float = 0.0) -> list[Vector]:
    pts: list[Vector] = []
    for i in range(sides):
        ang = (2.0 * math.pi * i) / sides + twist
        pts.append(godot_to_blender(cx + math.cos(ang) * rx, cy, cz + math.sin(ang) * rz))
    return pts


def diamond_blade_ring_godot(y: float, half_w: float, half_t: float, fuller: float = 0.0) -> list[Vector]:
    fw = half_w * 0.36
    ft = half_t * (1.0 - fuller * 0.38)
    coords = [
        (half_w, y, 0.0),
        (fw, y, ft),
        (0.0, y, half_t * (1.0 - fuller * 0.55)),
        (-fw, y, ft),
        (-half_w, y, 0.0),
        (-fw, y, -ft),
        (0.0, y, -half_t * (1.0 - fuller * 0.55)),
        (fw, y, -ft),
    ]
    return [godot_to_blender(x, yy, z) for (x, yy, z) in coords]


def finalize_and_export(
    obj: bpy.types.Object,
    out_name: str,
    smooth_angle_deg: float = 42.0,
    sway_weight_fn=None,
) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    uv_layer = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in f.loops:
            co = loop.vert.co
            if ay >= ax and ay >= az:
                u, v = co.x * 1.5 + 0.5, co.z * 0.75 + 0.5
            elif ax >= ay and ax >= az:
                u, v = co.y * 1.5 + 0.5, co.z * 0.75 + 0.5
            else:
                u, v = co.x * 1.5 + 0.5, co.y * 1.5 + 0.5
            loop[uv_layer].uv = (u, v)

    sharp_cos = math.cos(math.radians(smooth_angle_deg))
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if len(e.link_faces) == 2:
            d = e.link_faces[0].normal.dot(e.link_faces[1].normal)
            e.smooth = d >= sharp_cos
    bm.to_mesh(obj.data)
    bm.free()

    if sway_weight_fn is not None:
        while len(obj.data.color_attributes) > 0:
            obj.data.color_attributes.remove(obj.data.color_attributes[0])
        col_attr = obj.data.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
        obj.data.color_attributes.active_color = col_attr
        obj.data.color_attributes.render_color_index = 0
        for idx, v in enumerate(obj.data.vertices):
            w = float(max(0.0, min(1.0, sway_weight_fn(v.co))))
            col_attr.data[idx].color = (w, 0.0, 0.0, 1.0)

    os.makedirs(OUT_DIR, exist_ok=True)
    out_path = os.path.join(OUT_DIR, out_name)
    export_kwargs = dict(
        filepath=out_path,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_normals=True,
        export_texcoords=True,
        export_materials="EXPORT",
    )
    if sway_weight_fn is not None:
        export_kwargs["export_all_vertex_colors"] = True
        export_kwargs["export_active_vertex_color_when_no_material"] = True
    bpy.ops.export_scene.gltf(**export_kwargs)
    print(f"Exported {out_path}")


def build_zweihander() -> None:
    reset_scene()
    steel = make_pbr_mat("DarkFlutedSteel", (0.54, 0.56, 0.60, 1.0), metallic=0.92, roughness=0.27)
    iron = make_pbr_mat("BlackenedGuardIron", (0.20, 0.21, 0.24, 1.0), metallic=0.88, roughness=0.40)
    leather = make_pbr_mat("CordedGripLeather", (0.11, 0.075, 0.055, 1.0), metallic=0.05, roughness=0.78)

    mesh = bpy.data.meshes.new("ZweihanderMesh")
    obj = bpy.data.objects.new("Zweihander", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(steel)
    obj.data.materials.append(iron)
    obj.data.materials.append(leather)

    bm = bmesh.new()

    pommel_profile = [
        (-0.320, 0.011, 0.011),
        (-0.306, 0.030, 0.025),
        (-0.280, 0.034, 0.027),
        (-0.256, 0.021, 0.017),
        (-0.246, 0.017, 0.013),
    ]
    add_loft(bm, [circle_ring_godot(0.0, y, 0.0, rx, rz, 8) for (y, rx, rz) in pommel_profile], mat_index=1)

    grip_rings = []
    steps = 14
    for i in range(steps + 1):
        t = i / steps
        y = -0.25 + 0.27 * t
        waist = 1.0 + 0.15 * math.sin(t * math.pi) + (0.16 if abs(t - 0.52) < 0.06 else 0.0)
        cord = 1.0 + 0.04 * math.sin(t * math.pi * 18.0)
        grip_rings.append(circle_ring_godot(0.0, y, 0.0, 0.0175 * waist * cord, 0.013 * waist * cord, 10))
    add_loft(bm, grip_rings, mat_index=2)

    add_loft(
        bm,
        [circle_ring_godot(0.0, y, 0.0, r, r * 0.78, 8) for (y, r) in [(-0.132, 0.020), (-0.118, 0.024), (-0.104, 0.020)]],
        mat_index=1,
    )

    guard_rings = []
    qn = 18
    for i in range(qn + 1):
        u = -1.0 + 2.0 * (i / qn)
        x = u * 0.24
        arch_y = 0.024 + 0.026 * (u * u)
        s_z = 0.020 * math.sin(u * math.pi)
        rad = 0.0125 * (1.0 - 0.32 * abs(u)) + (0.009 if abs(u) > 0.90 else 0.0)
        ring = []
        for k in range(8):
            ang = 2.0 * math.pi * k / 8
            ring.append(godot_to_blender(x, arch_y + math.cos(ang) * rad, s_z + math.sin(ang) * rad * 0.85))
        guard_rings.append(ring)
    add_loft(bm, guard_rings, mat_index=1)

    for side_z in (-1.0, 1.0):
        ring_tube = []
        tn = 12
        for i in range(tn + 1):
            a = math.pi * (i / tn)
            cx = math.cos(a) * 0.050
            cz = side_z * (0.014 + math.sin(a) * 0.048)
            cy = 0.026 + math.sin(a) * 0.008
            pts = []
            for k in range(6):
                ka = 2.0 * math.pi * k / 6
                pts.append(godot_to_blender(cx + math.cos(ka) * 0.0055, cy + math.sin(ka) * 0.0055, cz))
            ring_tube.append(pts)
        add_loft(bm, ring_tube, mat_index=1)

    ricasso_rings = [
        diamond_blade_ring_godot(0.042, 0.038, 0.015, 0.0),
        diamond_blade_ring_godot(0.150, 0.037, 0.0145, 0.0),
        diamond_blade_ring_godot(0.260, 0.036, 0.0135, 0.0),
    ]
    add_loft(bm, ricasso_rings, mat_index=2)

    for sx in (-1.0, 1.0):
        lug_rings = []
        for t in (0.0, 0.35, 0.7, 1.0):
            lx = sx * (0.030 + 0.082 * t)
            ly = 0.265 + 0.070 * (t ** 1.15)
            hw = 0.017 * (1.0 - 0.78 * t) + 0.002
            ht = 0.010 * (1.0 - 0.75 * t) + 0.002
            lug_rings.append(circle_ring_godot(lx, ly, 0.0, hw, ht, 6))
        add_loft(bm, lug_rings, mat_index=1)

    blade_rings = []
    bn = 28
    for i in range(bn + 1):
        t = i / bn
        y = 0.26 + (1.46 - 0.26) * t
        if t < 0.85:
            taper = 1.0 - 0.30 * (t / 0.85)
            flam = 1.0 + (0.065 * math.sin(t * math.pi * 10.0) * (1.0 - t / 0.85) if t < 0.55 else 0.0)
            hw = 0.042 * taper * flam
            ht = 0.0135 * (1.0 - 0.35 * t)
            fuller = 1.0 if t < 0.72 else max(0.0, (0.85 - t) / 0.13)
        else:
            pt = (t - 0.85) / 0.15
            hw = max(0.0012, 0.042 * 0.70 * (1.0 - pt ** 1.25))
            ht = max(0.0010, 0.0088 * (1.0 - pt))
            fuller = 0.0
        blade_rings.append(diamond_blade_ring_godot(y, hw, ht, fuller))
    add_loft(bm, blade_rings, mat_index=0)

    bm.to_mesh(mesh)
    bm.free()
    finalize_and_export(obj, "zweihander.glb", smooth_angle_deg=35.0)


def build_halberd() -> None:
    reset_scene()
    ash_wood = make_pbr_mat("AshWoodShaft", (0.16, 0.11, 0.075, 1.0), metallic=0.04, roughness=0.76)
    dark_iron = make_pbr_mat("HalberdSocketIron", (0.20, 0.21, 0.24, 1.0), metallic=0.88, roughness=0.40)
    edge_steel = make_pbr_mat("HalberdEdgeSteel", (0.58, 0.60, 0.64, 1.0), metallic=0.94, roughness=0.25)
    brass = make_pbr_mat("CollarBrass", (0.62, 0.46, 0.20, 1.0), metallic=0.90, roughness=0.32)

    mesh = bpy.data.meshes.new("HalberdMesh")
    obj = bpy.data.objects.new("Halberd", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(ash_wood)
    obj.data.materials.append(dark_iron)
    obj.data.materials.append(edge_steel)
    obj.data.materials.append(brass)

    bm = bmesh.new()

    butt_profile = [(-0.50, 0.003), (-0.45, 0.017), (-0.41, 0.0195)]
    add_loft(bm, [circle_ring_godot(0.0, y, 0.0, r, r, 8) for (y, r) in butt_profile], mat_index=1)

    shaft_ys = [-0.41, -0.15, 0.0, 0.35, 0.72, 1.05]
    add_loft(bm, [circle_ring_godot(0.0, y, 0.0, 0.018, 0.018, 8) for y in shaft_ys], mat_index=0)

    for by in (-0.20, 0.18, 0.56, 0.84):
        add_loft(
            bm,
            [circle_ring_godot(0.0, by + dy, 0.0, r, r, 8) for (dy, r) in [(-0.015, 0.0195), (0.0, 0.0215), (0.015, 0.0195)]],
            mat_index=3 if by in (0.18, 0.84) else 1,
        )

    for sz in (-1.0, 1.0):
        langet_rings = []
        for y in (0.76, 1.06):
            pts = [
                godot_to_blender(-0.008, y, sz * 0.0165),
                godot_to_blender(0.008, y, sz * 0.0165),
                godot_to_blender(0.008, y, sz * 0.0215),
                godot_to_blender(-0.008, y, sz * 0.0215),
            ]
            langet_rings.append(pts)
        add_loft(bm, langet_rings, mat_index=1)

    socket_profile = [
        (1.03, 0.022, 0.022),
        (1.08, 0.026, 0.024),
        (1.20, 0.025, 0.023),
        (1.25, 0.021, 0.019),
    ]
    add_loft(bm, [circle_ring_godot(0.0, y, 0.0, rx, rz, 8) for (y, rx, rz) in socket_profile], mat_index=1)

    for cy in (1.05, 1.23):
        add_loft(
            bm,
            [circle_ring_godot(0.0, cy + dy, 0.0, r, r, 8) for (dy, r) in [(-0.011, 0.025), (0.0, 0.029), (0.011, 0.025)]],
            mat_index=3,
        )

    spike_rings = []
    for i in range(13):
        t = i / 12.0
        y = 1.24 + 0.31 * t
        hw = max(0.0012, 0.026 * ((1.0 - t) ** 1.15))
        ht = max(0.0012, 0.017 * ((1.0 - t) ** 1.10))
        spike_rings.append(diamond_blade_ring_godot(y, hw, ht, 0.35 * (1.0 - t)))
    add_loft(bm, spike_rings, mat_index=2)

    axe_cols = 8
    axe_rows = 11
    grid: list[list[tuple[float, float, float]]] = []
    for c in range(axe_cols + 1):
        u = c / axe_cols
        col_pts = []
        y_bot = 1.06 - 0.16 * (u ** 1.25)
        y_top = 1.22 + 0.12 * (u ** 1.25)
        for r in range(axe_rows + 1):
            v = r / axe_rows
            vy = y_bot + (y_top - y_bot) * v
            horn_flare = 1.0 + 0.24 * ((2.0 * v - 1.0) ** 2)
            x_edge = 0.25 * horn_flare
            x = 0.017 + (x_edge - 0.017) * (u ** 0.92)
            thick = (0.013 * (1.0 - 0.88 * (u ** 1.4)) + 0.0012) * (1.0 - 0.25 * ((2.0 * v - 1.0) ** 2))
            col_pts.append((x, vy, thick))
        grid.append(col_pts)

    v_pos = [[bm.verts.new(godot_to_blender(x, y, z)) for (x, y, z) in col] for col in grid]
    v_neg = [[bm.verts.new(godot_to_blender(x, y, -z)) for (x, y, z) in col] for col in grid]
    for c in range(axe_cols):
        m_idx = 2 if c >= axe_cols - 2 else 1
        for r in range(axe_rows):
            f1 = bm.faces.new([v_pos[c][r], v_pos[c + 1][r], v_pos[c + 1][r + 1], v_pos[c][r + 1]])
            f1.material_index = m_idx
            f2 = bm.faces.new([v_neg[c][r], v_neg[c][r + 1], v_neg[c + 1][r + 1], v_neg[c + 1][r]])
            f2.material_index = m_idx
    for r in range(axe_rows):
        fe = bm.faces.new([v_pos[axe_cols][r], v_neg[axe_cols][r], v_neg[axe_cols][r + 1], v_pos[axe_cols][r + 1]])
        fe.material_index = 2
        fi = bm.faces.new([v_neg[0][r], v_pos[0][r], v_pos[0][r + 1], v_neg[0][r + 1]])
        fi.material_index = 1
    for c in range(axe_cols):
        m_idx = 2 if c >= axe_cols - 2 else 1
        fb = bm.faces.new([v_neg[c][0], v_neg[c + 1][0], v_pos[c + 1][0], v_pos[c][0]])
        fb.material_index = m_idx
        ft = bm.faces.new([v_pos[c][axe_rows], v_pos[c + 1][axe_rows], v_neg[c + 1][axe_rows], v_neg[c][axe_rows]])
        ft.material_index = m_idx

    fluke_rings = []
    fn = 10
    for i in range(fn + 1):
        t = i / fn
        fx = -(0.017 + 0.22 * t)
        fy = 1.16 - 0.10 * (t ** 1.85)
        hw = max(0.0015, 0.026 * (1.0 - 0.90 * t))
        ht = max(0.0015, 0.012 * (1.0 - 0.88 * t))
        pts = [
            godot_to_blender(fx, fy + hw, 0.0),
            godot_to_blender(fx, fy, ht),
            godot_to_blender(fx, fy - hw, 0.0),
            godot_to_blender(fx, fy, -ht),
        ]
        fluke_rings.append(pts)
    add_loft(bm, fluke_rings, mat_index=2)

    bm.to_mesh(mesh)
    bm.free()
    finalize_and_export(obj, "halberd.glb", smooth_angle_deg=38.0)


def build_runed_staff() -> None:
    reset_scene()
    wrought_iron = make_pbr_mat("WroughtStaffIron", (0.15, 0.16, 0.19, 1.0), metallic=0.88, roughness=0.44)
    grip_wrap = make_pbr_mat("StaffLeatherWrap", (0.10, 0.08, 0.07, 1.0), metallic=0.05, roughness=0.80)
    crystal = make_pbr_mat(
        "CoreCrystal",
        (0.32, 0.72, 0.95, 1.0),
        metallic=0.10,
        roughness=0.14,
        emission_color=(0.24, 0.65, 0.96, 1.0),
        emission_strength=3.2,
    )

    mesh = bpy.data.meshes.new("RunedStaffMesh")
    obj = bpy.data.objects.new("RunedStaff", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(wrought_iron)
    obj.data.materials.append(grip_wrap)
    obj.data.materials.append(crystal)

    bm = bmesh.new()

    shaft_rings = []
    sn = 40
    for i in range(sn + 1):
        t = i / sn
        y = -0.50 + 1.46 * t
        if y < -0.42:
            u = (y - (-0.50)) / 0.08
            r = 0.003 + 0.0155 * u
        elif y > 0.88:
            u = (y - 0.88) / 0.08
            r = 0.0185 + 0.015 * u
        else:
            swell = 1.0 + 0.12 * max(0.0, y / 0.96)
            r = 0.017 * swell
        twist = y * 4.6
        shaft_rings.append(circle_ring_godot(0.0, y, 0.0, r, r, 6, twist=twist))
    add_loft(bm, shaft_rings, mat_index=0)

    wrap_rings = []
    for i in range(13):
        t = i / 12.0
        y = -0.16 + 0.36 * t
        r = 0.020 * (1.0 + 0.04 * math.sin(t * math.pi * 12.0))
        wrap_rings.append(circle_ring_godot(0.0, y, 0.0, r, r, 10))
    add_loft(bm, wrap_rings, mat_index=1)

    collar_profile = [(0.92, 0.023), (0.95, 0.040), (0.98, 0.034), (1.00, 0.021)]
    add_loft(bm, [circle_ring_godot(0.0, y, 0.0, r, r, 8) for (y, r) in collar_profile], mat_index=0)

    for p in range(4):
        base_ang = (math.pi * 0.5) * p + math.pi * 0.25
        prong_rings = []
        pn = 16
        for i in range(pn + 1):
            t = i / pn
            y = 0.96 + 0.39 * t
            arch = math.sin(t * math.pi * 0.92)
            rad = 0.022 + 0.090 * arch + (0.016 * (t - 0.85) / 0.15 if t > 0.85 else 0.0)
            pr = max(0.002, 0.0135 * (1.0 - 0.72 * t))
            cx = math.cos(base_ang) * rad
            cz = math.sin(base_ang) * rad
            ring = []
            for k in range(6):
                ka = 2.0 * math.pi * k / 6
                rx = math.cos(base_ang) * math.cos(ka) * pr - math.sin(base_ang) * math.sin(ka) * pr * 0.75
                rz = math.sin(base_ang) * math.cos(ka) * pr + math.cos(base_ang) * math.sin(ka) * pr * 0.75
                ring.append(godot_to_blender(cx + rx, y, cz + rz))
            prong_rings.append(ring)
        add_loft(bm, prong_rings, mat_index=0)

    halo_rings = []
    hn = 24
    for i in range(hn):
        a = 2.0 * math.pi * i / hn
        pts = []
        for k in range(6):
            ka = 2.0 * math.pi * k / 6
            rr = 0.090 + math.cos(ka) * 0.0065
            yy = 1.15 + math.sin(ka) * 0.0085
            pts.append(godot_to_blender(math.cos(a) * rr, yy, math.sin(a) * rr))
        halo_rings.append(pts)
    halo_rings.append(halo_rings[0])
    add_loft(bm, halo_rings, mat_index=0, cap_start=False, cap_end=False)

    crystal_profile = [
        (1.03, 0.002),
        (1.10, 0.040),
        (1.16, 0.050),
        (1.22, 0.036),
        (1.29, 0.002),
    ]
    add_loft(bm, [circle_ring_godot(0.0, y, 0.0, r, r, 6, twist=0.35 if idx == 2 else 0.0) for idx, (y, r) in enumerate(crystal_profile)], mat_index=2)

    bm.to_mesh(mesh)
    bm.free()
    finalize_and_export(obj, "runed_staff.glb", smooth_angle_deg=32.0)


def build_cloak_tattered() -> None:
    reset_scene()
    wool = make_pbr_mat("TatteredCloakWool", (0.12, 0.11, 0.13, 1.0), metallic=0.02, roughness=0.92, use_vertex_color=True)

    mesh = bpy.data.meshes.new("CloakTatteredMesh")
    obj = bpy.data.objects.new("CloakTattered", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(wool)

    bm = bmesh.new()

    cols = 28
    rows = 24
    verts: list[list[bmesh.types.BMVert]] = []

    notch_depths = [
        0.00, 0.11, 0.02, 0.16, 0.05, 0.00, 0.14, 0.03,
        0.19, 0.06, 0.01, 0.15, 0.04, 0.21, 0.08, 0.21,
        0.04, 0.15, 0.01, 0.06, 0.19, 0.03, 0.14, 0.00,
        0.05, 0.16, 0.02, 0.11, 0.00,
    ]

    for r in range(rows + 1):
        v = r / rows
        row_v: list[bmesh.types.BMVert] = []
        for c in range(cols + 1):
            u = -1.0 + 2.0 * (c / cols)
            half_w = 0.24 + 0.24 * (v ** 0.85)
            x = (1.0 - 0.55 * v) * (math.sin(u * 1.12) * half_w) + (0.55 * v) * (u * half_w * 1.12)
            pleat = math.sin(u * math.pi * 5.0) * (0.006 + 0.028 * v)
            shoulder_arch = 0.032 * (1.0 - u * u) * max(0.0, 1.0 - v * 4.5)
            notch = notch_depths[c] * (max(0.0, (v - 0.72) / 0.28) ** 1.4)
            y = -1.25 * v + shoulder_arch + notch

            shoulder_cup = -0.085 * (u * u) * max(0.0, 1.0 - v * 2.2)
            back_drape = 0.11 * math.sin(min(1.0, v * 1.15) * math.pi * 0.68) + 0.06 * v
            z = shoulder_cup + back_drape + pleat

            row_v.append(bm.verts.new(godot_to_blender(x, y, z)))
        verts.append(row_v)

    for r in range(rows):
        for c in range(cols):
            f = bm.faces.new([verts[r][c], verts[r + 1][c], verts[r + 1][c + 1], verts[r][c + 1]])
            f.material_index = 0

    collar_rings = []
    for c in range(cols + 1):
        u = -1.0 + 2.0 * (c / cols)
        cx = math.sin(u * 1.12) * 0.245
        cy = 0.022 * (1.0 - u * u)
        cz = -0.085 * (u * u) - 0.005
        pts = []
        for k in range(6):
            ka = 2.0 * math.pi * k / 6
            pts.append(godot_to_blender(cx, cy + math.sin(ka) * 0.024, cz + math.cos(ka) * 0.022))
        collar_rings.append(pts)
    add_loft(bm, collar_rings, mat_index=0, closed_ring=True)

    bm.to_mesh(mesh)
    bm.free()

    def cloak_weight(co: Vector) -> float:
        gy = blender_to_godot_y(co)
        if gy >= -0.04:
            return 0.0
        return min(1.0, max(0.0, (-gy - 0.04) / 1.16) ** 1.15)

    finalize_and_export(obj, "cloak_tattered.glb", smooth_angle_deg=55.0, sway_weight_fn=cloak_weight)


def build_helm_plume() -> None:
    reset_scene()
    crest_iron = make_pbr_mat("CrestMountIron", (0.20, 0.21, 0.24, 1.0), metallic=0.88, roughness=0.38)
    horsehair = make_pbr_mat("CrimsonAshenPlume", (0.36, 0.07, 0.07, 1.0), metallic=0.04, roughness=0.72, use_vertex_color=True)

    mesh = bpy.data.meshes.new("HelmPlumeMesh")
    obj = bpy.data.objects.new("HelmPlume", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(crest_iron)
    obj.data.materials.append(horsehair)

    bm = bmesh.new()

    comb_rings = []
    for i in range(9):
        t = i / 8.0
        z = -0.06 + 0.16 * t
        y = 0.032 * math.sin(t * math.pi)
        hw = 0.014 * (1.0 - 0.3 * abs(2.0 * t - 1.0))
        pts = [
            godot_to_blender(-hw, y, z),
            godot_to_blender(hw, y, z),
            godot_to_blender(hw * 0.75, y + 0.038, z),
            godot_to_blender(-hw * 0.75, y + 0.038, z),
        ]
        comb_rings.append(pts)
    add_loft(bm, comb_rings, mat_index=0)

    locks = [
        (0.0,    0.030, 0.16, 0.36, -0.14, 0.038),
        (-0.016, 0.022, 0.13, 0.31, -0.11, 0.028),
        (0.016,  0.022, 0.13, 0.31, -0.11, 0.028),
        (0.0,    0.040, 0.19, 0.28, -0.04, 0.030),
        (0.0,    0.015, 0.10, 0.40, -0.20, 0.026),
    ]
    for (x_off, y_start, arch_h, z_end, y_end, base_r) in locks:
        lock_rings = []
        ln = 16
        for i in range(ln + 1):
            t = i / ln
            p0 = Vector((x_off * 0.35, y_start + 0.02, -0.02 + 0.06 * (y_start / 0.04)))
            p1 = Vector((x_off * 0.9, y_start + arch_h, 0.08))
            p2 = Vector((x_off * 1.35, y_start + arch_h * 0.45, z_end * 0.72))
            p3 = Vector((x_off * 1.15, y_end, z_end))
            omt = 1.0 - t
            c = (omt ** 3) * p0 + 3.0 * (omt ** 2) * t * p1 + 3.0 * omt * (t ** 2) * p2 + (t ** 3) * p3
            swell = math.sin(min(1.0, t * 0.92 + 0.08) * math.pi)
            rx = max(0.0015, base_r * (0.45 + 0.75 * swell) * (1.0 - 0.85 * (t ** 2.2)))
            ry = max(0.0015, base_r * 1.25 * (0.45 + 0.75 * swell) * (1.0 - 0.85 * (t ** 2.2)))
            ring = []
            for k in range(8):
                ka = 2.0 * math.pi * k / 8
                flute = 1.0 + 0.12 * math.cos(ka * 3.0)
                ring.append(godot_to_blender(c.x + math.cos(ka) * rx * flute, c.y + math.sin(ka) * ry * flute, c.z))
            lock_rings.append(ring)
        add_loft(bm, lock_rings, mat_index=1)

    bm.to_mesh(mesh)
    bm.free()

    def plume_weight(co: Vector) -> float:
        gz = blender_to_godot_z(co)
        return min(1.0, max(0.0, (gz - 0.04) / 0.34))

    finalize_and_export(obj, "helm_plume.glb", smooth_angle_deg=48.0, sway_weight_fn=plume_weight)


def build_waist_lantern() -> None:
    reset_scene()
    wrought_iron = make_pbr_mat("WroughtIron", (0.15, 0.16, 0.18, 1.0), metallic=0.88, roughness=0.42)
    lantern_core = make_pbr_mat(
        "LanternCore",
        (1.0, 0.76, 0.34, 1.0),
        metallic=0.0,
        roughness=0.18,
        emission_color=(1.0, 0.72, 0.28, 1.0),
        emission_strength=4.0,
    )

    mesh = bpy.data.meshes.new("WaistLanternMesh")
    obj = bpy.data.objects.new("WaistLantern", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(wrought_iron)
    obj.data.materials.append(lantern_core)

    bm = bmesh.new()

    ring_segs = []
    rn = 16
    for i in range(rn):
        a = 2.0 * math.pi * i / rn
        pts = []
        for k in range(6):
            ka = 2.0 * math.pi * k / 6
            rr = 0.020 + math.cos(ka) * 0.004
            pts.append(godot_to_blender(math.cos(a) * rr, -0.010 + math.sin(a) * rr, math.sin(ka) * 0.004))
        ring_segs.append(pts)
    ring_segs.append(ring_segs[0])
    add_loft(bm, ring_segs, mat_index=0, cap_start=False, cap_end=False)

    cap_profile = [
        (-0.028, 0.012),
        (-0.048, 0.024),
        (-0.056, 0.022),
        (-0.082, 0.068),
        (-0.092, 0.072),
        (-0.098, 0.058),
    ]
    add_loft(bm, [circle_ring_godot(0.0, y, 0.0, r, r, 6) for (y, r) in cap_profile], mat_index=0)

    base_profile = [
        (-0.205, 0.056),
        (-0.214, 0.066),
        (-0.224, 0.052),
        (-0.242, 0.018),
        (-0.268, 0.002),
    ]
    add_loft(bm, [circle_ring_godot(0.0, y, 0.0, r, r, 6) for (y, r) in base_profile], mat_index=0)

    for k in range(6):
        ang = 2.0 * math.pi * k / 6
        rib_rings = []
        for y, rr in [(-0.090, 0.058), (-0.150, 0.061), (-0.210, 0.056)]:
            cx = math.cos(ang) * rr
            cz = math.sin(ang) * rr
            rib_rings.append(circle_ring_godot(cx, y, cz, 0.0055, 0.0055, 6))
        add_loft(bm, rib_rings, mat_index=0)

    core_profile = [
        (-0.098, 0.044),
        (-0.150, 0.048),
        (-0.205, 0.042),
    ]
    add_loft(bm, [circle_ring_godot(0.0, y, 0.0, r, r, 6) for (y, r) in core_profile], mat_index=1)

    bm.to_mesh(mesh)
    bm.free()
    finalize_and_export(obj, "waist_lantern.glb", smooth_angle_deg=35.0)


def main() -> None:
    build_zweihander()
    build_halberd()
    build_runed_staff()
    build_cloak_tattered()
    build_helm_plume()
    build_waist_lantern()
    print("All 6 forged dark-medieval attachments exported successfully.")


if __name__ == "__main__":
    main()
