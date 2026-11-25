import math
import bpy
from mathutils import Vector

from .kit_common import (
    RiggedMeshBuilder,
    elliptical_ring_godot,
    export_kit_glb,
    godot_to_blender,
    make_kit_materials,
    reset_scene,
    tube_ring_godot,
)


def _arena_mat_slots(mats: dict[str, bpy.types.Material]) -> tuple[list[bpy.types.Material], dict[str, int]]:
    order = [
        "stone",       # 0
        "dark_stone",  # 1
        "black_steel", # 2
        "gold",        # 3
        "emit_blue",   # 4
        "emit_cinder", # 5
    ]
    return [mats[k] for k in order], {k: i for i, k in enumerate(order)}


def _add_clustered_pier(
    mb: RiggedMeshBuilder,
    cx: float,
    cz: float,
    y_bot: float,
    y_top: float,
    core_r: float,
    stone_m: int,
    trim_m: int,
    band_ys: list[float],
) -> None:
    # Central octagonal shaft.
    mb.add_loft(
        [
            elliptical_ring_godot(cx, y_bot, cz, core_r, core_r, 8, twist=math.pi / 8.0),
            elliptical_ring_godot(cx, y_top, cz, core_r * 0.96, core_r * 0.96, 8, twist=math.pi / 8.0),
        ],
        mat_index=stone_m,
        bevel_width=0.018,
    )
    # 4 engaged gothic colonnette shafts + 4 slender corner ribs.
    for k in range(4):
        ang = k * (math.pi * 0.5)
        ox = cx + math.cos(ang) * core_r * 0.88
        oz = cz + math.sin(ang) * core_r * 0.88
        mb.add_loft(
            [
                elliptical_ring_godot(ox, y_bot, oz, core_r * 0.30, core_r * 0.30, 8),
                elliptical_ring_godot(ox, y_top, oz, core_r * 0.28, core_r * 0.28, 8),
            ],
            mat_index=stone_m,
            bevel_width=0.010,
        )
        da = ang + math.pi * 0.25
        dx = cx + math.cos(da) * core_r * 0.94
        dz = cz + math.sin(da) * core_r * 0.94
        mb.add_loft(
            [
                elliptical_ring_godot(dx, y_bot, dz, core_r * 0.16, core_r * 0.16, 6),
                elliptical_ring_godot(dx, y_top, dz, core_r * 0.15, core_r * 0.15, 6),
            ],
            mat_index=trim_m,
        )

    # Molded shaft-rings interrupting the clustered pier.
    for by in band_ys:
        prof = [
            (by - 0.10, core_r * 1.16),
            (by - 0.04, core_r * 1.32),
            (by + 0.04, core_r * 1.32),
            (by + 0.10, core_r * 1.16),
        ]
        mb.add_loft(
            [elliptical_ring_godot(cx, y, cz, r, r, 8, twist=math.pi / 8.0) for (y, r) in prof],
            mat_index=trim_m,
            bevel_width=0.012,
        )


def _add_pointed_arch_voussoirs(
    mb: RiggedMeshBuilder,
    half_span: float,
    spring_y: float,
    apex_y: float,
    depth_z: float,
    arch_thick: float,
    stone_m: int,
    trim_m: int,
) -> None:
    # Continuous smooth pointed gothic lancet arch rib + radial bevel stone voussoirs + carved keystone.
    h = apex_y - spring_y
    segs = 10
    for sgn in (-1.0, 1.0):
        inner_rings = []
        outer_rings = []
        for i in range(segs + 1):
            t = i / segs
            x = sgn * half_span * (1.0 - t)
            y = spring_y + h * (math.sin(t * math.pi * 0.5) ** 0.78)
            dt = 0.02
            t2 = min(1.0, t + dt) if t < 1.0 else t
            t1 = max(0.0, t - dt) if t > 0.0 else t
            dx = sgn * half_span * ((1.0 - t2) - (1.0 - t1))
            dy = h * ((math.sin(t2 * math.pi * 0.5) ** 0.78) - (math.sin(t1 * math.pi * 0.5) ** 0.78))
            tang = Vector((dx, dy, 0.0)).normalized()
            out_n = Vector((tang.y, -tang.x, 0.0)) if sgn < 0 else Vector((-tang.y, tang.x, 0.0))
            if out_n.y < 0.0:
                out_n = -out_n

            c_inner = Vector((x, y, 0.0)) + out_n * (arch_thick * 0.12)
            c_outer = Vector((x, y, 0.0)) + out_n * (arch_thick * 0.56)
            inner_rings.append(tube_ring_godot((c_inner.x, c_inner.y, 0.0), (tang.x, tang.y, 0.0), depth_z * 0.52, arch_thick * 0.18, 6))
            outer_rings.append(tube_ring_godot((c_outer.x, c_outer.y, 0.0), (tang.x, tang.y, 0.0), depth_z * 0.45, arch_thick * 0.34, 8))

        mb.add_loft(inner_rings, mat_index=trim_m)
        mb.add_loft(outer_rings, mat_index=stone_m)

        # Individual flush beveled voussoir ribs aligned tangent to curve.
        for i in range(segs):
            tm = (i + 0.5) / segs
            xm = sgn * half_span * (1.0 - tm)
            ym = spring_y + h * (math.sin(tm * math.pi * 0.5) ** 0.78)
            dx = -sgn * half_span * 0.08
            dy = h * ((math.sin(min(1.0, tm + 0.04) * math.pi * 0.5) ** 0.78) - (math.sin(max(0.0, tm - 0.04) * math.pi * 0.5) ** 0.78))
            ang = math.atan2(dy, dx)
            out_n = Vector((math.sin(ang), -math.cos(ang), 0.0))
            if out_n.y < 0.0:
                out_n = -out_n
            c_v = Vector((xm, ym, 0.0)) + out_n * (arch_thick * 0.50)
            mb.add_beveled_box_godot(
                (c_v.x, c_v.y, 0.0),
                (0.52, arch_thick * 0.44, depth_z * 0.96),
                mat_index=trim_m if i % 2 == 0 else stone_m,
                bevel_width=0.022,
                rot_euler_godot=(0.0, 0.0, ang),
            )

    # Proud carved gothic keystone at pointed apex!
    mb.add_beveled_box_godot(
        (0.0, apex_y + arch_thick * 0.38, 0.0),
        (arch_thick * 0.78, arch_thick * 1.38, depth_z * 1.18),
        mat_index=trim_m,
        bevel_width=0.032,
    )


def build_gothic_pillar() -> str:
    reset_scene()
    mats = make_kit_materials()
    mat_list, m = _arena_mat_slots(mats)
    mb = RiggedMeshBuilder("GothicPillar", mat_list)

    # Stepped octagonal plinth (Y = 0.0..0.80)
    plinth = [
        (0.00, 0.92),
        (0.28, 0.90),
        (0.32, 0.78),
        (0.56, 0.75),
        (0.62, 0.62),
        (0.80, 0.58),
    ]
    mb.add_loft(
        [elliptical_ring_godot(0.0, y, 0.0, r, r, 8, twist=math.pi / 8.0) for (y, r) in plinth],
        mat_index=m["stone"],
        bevel_width=0.022,
    )

    _add_clustered_pier(mb, 0.0, 0.0, 0.80, 5.65, 0.44, m["stone"], m["dark_stone"], [2.35, 4.25])

    # Flared gothic foliate capital + octagonal abacus (5.65..6.45).
    cap = [
        (5.65, 0.54),
        (5.95, 0.74),
        (6.22, 0.86),
        (6.45, 0.88),
    ]
    mb.add_loft(
        [elliptical_ring_godot(0.0, y, 0.0, r, r, 8, twist=math.pi / 8.0, flute_amp=0.06, flute_freq=8) for (y, r) in cap],
        mat_index=m["stone"],
        bevel_width=0.022,
    )

    # Fractured weathered ruin top (6.45..7.00).
    mb.add_beveled_box_godot((-0.18, 6.72, 0.10), (0.85, 0.54, 0.85), mat_index=m["dark_stone"], bevel_width=0.035, rot_euler_godot=(0.08, 0.3, -0.05))
    mb.add_beveled_box_godot((0.26, 6.64, -0.18), (0.62, 0.38, 0.64), mat_index=m["stone"], bevel_width=0.030, rot_euler_godot=(-0.06, -0.4, 0.08))

    obj = mb.finalize(smooth_angle_deg=32.0)
    return export_kit_glb([obj], "kit_gothic_pillar.glb", rigged=False)


def build_gothic_arch() -> str:
    reset_scene()
    mats = make_kit_materials()
    mat_list, m = _arena_mat_slots(mats)
    mb = RiggedMeshBuilder("GothicArch", mat_list)

    # Twin piers at X = +-3.65 (outer span ~8.5m, total height 7.5m).
    for sgn in (-1.0, 1.0):
        px = sgn * 3.65
        base = [(0.00, 0.88), (0.34, 0.84), (0.40, 0.70), (0.72, 0.66)]
        mb.add_loft([elliptical_ring_godot(px, y, 0.0, r, r, 8, twist=math.pi / 8.0) for (y, r) in base], mat_index=m["stone"], bevel_width=0.022)
        _add_clustered_pier(mb, px, 0.0, 0.72, 4.10, 0.46, m["stone"], m["dark_stone"], [2.25])
        cap = [(4.10, 0.56), (4.35, 0.78), (4.55, 0.82)]
        mb.add_loft([elliptical_ring_godot(px, y, 0.0, r, r, 8, twist=math.pi / 8.0) for (y, r) in cap], mat_index=m["dark_stone"], bevel_width=0.020)
        # Upper outer ruin spandrel buttresses.
        mb.add_beveled_box_godot((px, 5.45, 0.0), (1.15, 1.80, 1.05), mat_index=m["stone"], bevel_width=0.035)
        mb.add_beveled_box_godot((px + sgn * 0.12, 6.60, 0.0), (0.75, 0.70, 0.85), mat_index=m["dark_stone"], bevel_width=0.030, rot_euler_godot=(0.0, 0.0, -0.08 * sgn))

    _add_pointed_arch_voussoirs(mb, 3.65, 4.45, 7.15, 1.02, 0.68, m["stone"], m["dark_stone"])

    # Wrought-iron gothic tie-bar & hanging torch ring at springline.
    mb.add_beveled_box_godot((0.0, 4.42, 0.0), (6.50, 0.07, 0.07), mat_index=m["black_steel"], bevel_width=0.01)

    obj = mb.finalize(smooth_angle_deg=32.0)
    return export_kit_glb([obj], "kit_gothic_arch.glb", rigged=False)


def build_wrought_brazier() -> str:
    reset_scene()
    mats = make_kit_materials()
    mat_list, m = _arena_mat_slots(mats)
    mb = RiggedMeshBuilder("WroughtBrazier", mat_list)

    # 3 S-curved wrought-iron tripod legs sweeping from clawed ground feet (R=0.52, Y=0) to bowl (Y=0.94).
    for k in range(3):
        ang = (2.0 * math.pi * k) / 3.0
        ca, sa = math.cos(ang), math.sin(ang)
        leg_pts = [
            (0.52, 0.02, 0.042),
            (0.46, 0.18, 0.030),
            (0.32, 0.48, 0.028),
            (0.24, 0.76, 0.028),
            (0.36, 0.96, 0.032),
        ]
        rings = []
        for idx, (rr, yy, rad) in enumerate(leg_pts):
            tang = (0.0, 1.0, 0.0) if idx in (0, 4) else (ca * (leg_pts[idx + 1][0] - leg_pts[idx - 1][0]), leg_pts[idx + 1][1] - leg_pts[idx - 1][1], sa * (leg_pts[idx + 1][0] - leg_pts[idx - 1][0]))
            rings.append(tube_ring_godot((ca * rr, yy, sa * rr), tang, rad, rad, 6))
        mb.add_loft(rings, mat_index=m["black_steel"])
        # Claw foot pad resting at Y=0.
        mb.add_beveled_box_godot((ca * 0.52, 0.03, sa * 0.52), (0.14, 0.06, 0.14), mat_index=m["black_steel"], bevel_width=0.015, rot_euler_godot=(0.0, -ang, 0.0))

    # Lower structural iron ring at Y = 0.44.
    ring_segs = []
    for i in range(17):
        a = (2.0 * math.pi * i) / 16.0
        ring_segs.append(tube_ring_godot((math.cos(a) * 0.34, 0.44, math.sin(a) * 0.34), (-math.sin(a), 0.0, math.cos(a)), 0.022, 0.022, 6))
    mb.add_loft(ring_segs, mat_index=m["black_steel"], cap_start=False, cap_end=False)

    # Deep octagonal riveted fire-bowl (Y = 0.88..1.34).
    bowl = [
        (0.88, 0.14),
        (0.98, 0.34),
        (1.16, 0.46),
        (1.28, 0.50),
        (1.34, 0.52),
        (1.34, 0.42),
        (1.20, 0.36),
    ]
    mb.add_loft([elliptical_ring_godot(0.0, y, 0.0, r, r, 8, twist=math.pi / 8.0) for (y, r) in bowl], mat_index=m["black_steel"], bevel_width=0.012)

    # Gold/bronze rivets around bowl rim.
    for k in range(8):
        a = (2.0 * math.pi * k) / 8.0 + math.pi / 8.0
        mb.add_beveled_box_godot((math.cos(a) * 0.50, 1.30, math.sin(a) * 0.50), (0.04, 0.04, 0.04), mat_index=m["gold"], bevel_width=0.008, rot_euler_godot=(0.0, -a, 0.0))

    # 6 curved wrought-iron fire-cage bars rising to 1.65m.
    for k in range(6):
        a = (2.0 * math.pi * k) / 6.0
        ca, sa = math.cos(a), math.sin(a)
        cage_rings = [
            tube_ring_godot((ca * 0.45, 1.32, sa * 0.45), (0.0, 1.0, 0.0), 0.018, 0.018, 6),
            tube_ring_godot((ca * 0.48, 1.48, sa * 0.48), (-ca * 0.3, 1.0, -sa * 0.3), 0.015, 0.015, 6),
            tube_ring_godot((ca * 0.32, 1.65, sa * 0.32), (-ca * 0.6, 1.0, -sa * 0.6), 0.006, 0.006, 6),
        ]
        mb.add_loft(cage_rings, mat_index=m["black_steel"])

    # Sculpted jagged mound of dark charcoal lumps sitting over glowing ember crevices (NO flat yellow cone!).
    coal_bed = [
        elliptical_ring_godot(0.0, 1.22, 0.0, 0.38, 0.38, 12),
        elliptical_ring_godot(0.0, 1.32, 0.0, 0.28, 0.28, 12, flute_amp=0.14, flute_freq=6),
        elliptical_ring_godot(0.0, 1.38, 0.0, 0.14, 0.14, 12, flute_amp=0.16, flute_freq=6),
        elliptical_ring_godot(0.0, 1.41, 0.0, 0.02, 0.02, 12),
    ]
    mb.add_loft(coal_bed, mat_index=m["emit_cinder"])
    for k in range(11):
        a = (2.0 * math.pi * k) / 11.0
        rr = 0.08 + 0.16 * ((k % 3) / 2.0)
        mb.add_beveled_box_godot(
            (math.cos(a) * rr, 1.34 + 0.03 * (1.0 - rr / 0.25), math.sin(a) * rr),
            (0.15, 0.09, 0.13),
            mat_index=m["dark_stone"],
            bevel_width=0.020,
            rot_euler_godot=(0.35 * k, 0.8 * k, 0.25 * k),
        )

    obj = mb.finalize(smooth_angle_deg=35.0)
    return export_kit_glb([obj], "kit_wrought_brazier.glb", rigged=False)


def build_dark_shrine() -> str:
    reset_scene()
    mats = make_kit_materials()
    mat_list, m = _arena_mat_slots(mats)
    mb = RiggedMeshBuilder("DarkShrineBase", mat_list)

    # Two-tier stepped octagonal stone dais (Y = 0.0..0.52).
    dais = [
        (0.00, 1.42),
        (0.24, 1.38),
        (0.26, 1.14),
        (0.50, 1.10),
        (0.52, 0.88),
    ]
    mb.add_loft([elliptical_ring_godot(0.0, y, 0.0, r, r, 8, twist=math.pi / 8.0) for (y, r) in dais], mat_index=m["stone"], bevel_width=0.022)

    # Fluted obsidian reliquary altar shaft (Y = 0.52..2.02).
    altar = [
        (0.52, 0.76),
        (0.75, 0.62),
        (1.75, 0.54),
        (2.02, 0.66),
    ]
    mb.add_loft([elliptical_ring_godot(0.0, y, 0.0, r, r, 8, twist=math.pi / 8.0, flute_amp=0.06, flute_freq=4) for (y, r) in altar], mat_index=m["dark_stone"], bevel_width=0.018)

    # 4 corner buttresses + pointed gothic niche arches + antique gold bands.
    for k in range(4):
        ang = k * (math.pi * 0.5) + math.pi * 0.25
        ca, sa = math.cos(ang), math.sin(ang)
        mb.add_beveled_box_godot((ca * 0.62, 1.26, sa * 0.62), (0.20, 1.45, 0.20), mat_index=m["stone"], bevel_width=0.020, rot_euler_godot=(0.0, -ang, 0.0))
        mb.add_beveled_box_godot((ca * 0.64, 1.85, sa * 0.64), (0.24, 0.09, 0.24), mat_index=m["gold"], bevel_width=0.012, rot_euler_godot=(0.0, -ang, 0.0))

    # Open wrought-iron gothic crown cage cradling the floating crystal (Y = 2.02..2.50).
    for k in range(4):
        ang = k * (math.pi * 0.5) + math.pi * 0.25
        ca, sa = math.cos(ang), math.sin(ang)
        rib = [
            tube_ring_godot((ca * 0.56, 2.00, sa * 0.56), (0.0, 1.0, 0.0), 0.030, 0.030, 6),
            tube_ring_godot((ca * 0.62, 2.25, sa * 0.62), (-ca * 0.3, 1.0, -sa * 0.3), 0.024, 0.024, 6),
            tube_ring_godot((ca * 0.36, 2.48, sa * 0.36), (-ca * 0.8, 1.0, -sa * 0.8), 0.018, 0.018, 6),
        ]
        mb.add_loft(rib, mat_index=m["black_steel"])
    cage_ring = []
    for i in range(17):
        a = (2.0 * math.pi * i) / 16.0
        cage_ring.append(tube_ring_godot((math.cos(a) * 0.36, 2.48, math.sin(a) * 0.36), (-math.sin(a), 0.0, math.cos(a)), 0.022, 0.022, 6))
    mb.add_loft(cage_ring, mat_index=m["black_steel"], cap_start=False, cap_end=False)

    base_obj = mb.finalize(smooth_angle_deg=34.0)

    # Separate named floating rune crystal child ("ShrineCrystal") reaching Y = 3.20m.
    cb = RiggedMeshBuilder("ShrineCrystal", mat_list)
    c_prof = [
        (2.38, 0.01),
        (2.60, 0.18),
        (2.86, 0.22),
        (3.20, 0.01),
    ]
    cb.add_loft([elliptical_ring_godot(0.0, y, 0.0, r, r, 6, twist=0.25 if i == 2 else 0.0) for i, (y, r) in enumerate(c_prof)], mat_index=m["emit_blue"])
    # Delicate gold rune halo around crystal.
    halo = []
    for i in range(21):
        a = (2.0 * math.pi * i) / 20.0
        px = math.cos(a) * 0.32
        py = 2.78 + math.sin(a) * 0.09
        pz = math.sin(a) * 0.32
        halo.append(tube_ring_godot((px, py, pz), (-math.sin(a), math.cos(a) * 0.25, math.cos(a)), 0.018, 0.018, 6))
    cb.add_loft(halo, mat_index=m["gold"], cap_start=False, cap_end=False)
    crystal_obj = cb.finalize(smooth_angle_deg=25.0)
    crystal_obj.parent = base_obj

    return export_kit_glb([base_obj, crystal_obj], "kit_dark_shrine.glb", rigged=False)


def build_sanctum_plinth() -> str:
    reset_scene()
    mats = make_kit_materials()
    mat_list, m = _arena_mat_slots(mats)
    mb = RiggedMeshBuilder("SanctumPlinth", mat_list)

    # Two-tier 3.4m diameter (radius 1.70m) gothic stepped stone dais (Y = 0.0..0.34).
    tier1 = [
        (0.00, 1.70),
        (0.14, 1.66),
        (0.16, 1.56),
    ]
    mb.add_loft([elliptical_ring_godot(0.0, y, 0.0, r, r, 16) for (y, r) in tier1], mat_index=m["dark_stone"], bevel_width=0.018)

    tier2 = [
        (0.16, 1.38),
        (0.30, 1.34),
        (0.32, 1.24),
    ]
    mb.add_loft([elliptical_ring_godot(0.0, y, 0.0, r, r, 16) for (y, r) in tier2], mat_index=m["stone"], bevel_width=0.018)

    # 12 radial beveled stone rim curb blocks around outer top edge.
    for k in range(12):
        a = (2.0 * math.pi * k) / 12.0
        mb.add_beveled_box_godot(
            (math.cos(a) * 1.24, 0.325, math.sin(a) * 1.24),
            (0.24, 0.075, 0.56),
            mat_index=m["stone"],
            bevel_width=0.016,
            rot_euler_godot=(0.0, -a, 0.0),
        )

    # Worn gothic radial floor slab top.
    mb.add_loft(
        [
            elliptical_ring_godot(0.0, 0.29, 0.0, 1.18, 1.18, 16),
            elliptical_ring_godot(0.0, 0.33, 0.0, 1.15, 1.15, 16),
        ],
        mat_index=m["dark_stone"],
        bevel_width=0.012,
    )

    # Inlaid antique-bronze compass ring + cardinal rune markers.
    compass = []
    for i in range(25):
        a = (2.0 * math.pi * i) / 24.0
        compass.append(tube_ring_godot((math.cos(a) * 0.94, 0.332, math.sin(a) * 0.94), (-math.sin(a), 0.0, math.cos(a)), 0.026, 0.014, 6))
    mb.add_loft(compass, mat_index=m["gold"], cap_start=False, cap_end=False)

    for k in range(8):
        a = (2.0 * math.pi * k) / 8.0
        mb.add_beveled_box_godot(
            (math.cos(a) * 0.94, 0.338, math.sin(a) * 0.94),
            (0.14 if k % 2 == 0 else 0.08, 0.024, 0.06),
            mat_index=m["gold"],
            bevel_width=0.006,
            rot_euler_godot=(0.0, -a, 0.0),
        )

    obj = mb.finalize(smooth_angle_deg=34.0)
    return export_kit_glb([obj], "kit_sanctum_plinth.glb", rigged=False)


def build_boss_gate() -> str:
    reset_scene()
    mats = make_kit_materials()
    mat_list, m = _arena_mat_slots(mats)

    # Gatehouse stone structure root (11.0m wide x 6.5m tall).
    mb = RiggedMeshBuilder("BossGate", mat_list)

    for sgn in (-1.0, 1.0):
        px = sgn * 3.70
        # Massive gatehouse piers (Y = 0.0..5.6).
        base = [(0.00, 1.05), (0.45, 0.98), (0.55, 0.84)]
        mb.add_loft([elliptical_ring_godot(px, y, 0.0, r, r, 8, twist=math.pi / 8.0) for (y, r) in base], mat_index=m["dark_stone"], bevel_width=0.025)
        _add_clustered_pier(mb, px, 0.0, 0.55, 5.20, 0.62, m["stone"], m["dark_stone"], [2.2, 3.9])
        # Pointed gothic pinnacle turret cap (5.20..6.50).
        cap = [(5.20, 0.78), (5.48, 0.86), (5.68, 0.62), (6.50, 0.04)]
        mb.add_loft([elliptical_ring_godot(px, y, 0.0, r, r, 8, twist=math.pi / 8.0) for (y, r) in cap], mat_index=m["dark_stone"], bevel_width=0.020)

        # Flanking wing buttress walls reaching X = +-5.5m (11.0m total width!).
        mb.add_beveled_box_godot((sgn * 4.80, 1.85, 0.0), (1.40, 3.70, 1.25), mat_index=m["stone"], bevel_width=0.035)
        mb.add_beveled_box_godot((sgn * 4.95, 3.88, 0.0), (1.50, 0.34, 1.38), mat_index=m["dark_stone"], bevel_width=0.028)
        # Iron torch bracket.
        mb.add_beveled_box_godot((px - sgn * 0.72, 3.25, 0.65), (0.16, 0.42, 0.28), mat_index=m["black_steel"], bevel_width=0.015)

    # Pointed lancet gateway arch + crenellated wing merlons.
    _add_pointed_arch_voussoirs(mb, 3.45, 4.15, 6.25, 1.22, 0.66, m["stone"], m["dark_stone"])
    for bx in (-5.20, -4.45, 4.45, 5.20):
        mb.add_beveled_box_godot((bx, 4.25, 0.0), (0.58, 0.45, 1.15), mat_index=m["dark_stone"], bevel_width=0.025)

    gate_obj = mb.finalize(smooth_angle_deg=32.0)

    # Separate named child mesh "PortcullisBars" so BarrowArenaBuilder can raise/lower it smoothly.
    pb = RiggedMeshBuilder("PortcullisBars", mat_list)
    for i in range(-4, 5):
        bx = i * 0.68
        # Vertical iron bar + downward spearhead tip at Y = 0.08.
        pb.add_loft(
            [
                elliptical_ring_godot(bx, 0.08, 0.0, 0.008, 0.008, 4),
                elliptical_ring_godot(bx, 0.38, 0.0, 0.082, 0.036, 4),
                elliptical_ring_godot(bx, 0.44, 0.0, 0.056, 0.056, 8),
                elliptical_ring_godot(bx, 5.10, 0.0, 0.052, 0.052, 8),
            ],
            mat_index=m["black_steel"],
            bevel_width=0.008,
        )
    for ry in (1.05, 2.55, 4.05):
        pb.add_beveled_box_godot((0.0, ry, 0.0), (5.95, 0.14, 0.16), mat_index=m["black_steel"], bevel_width=0.016)
        for i in range(-4, 5):
            pb.add_beveled_box_godot((i * 0.68, ry, 0.085), (0.09, 0.09, 0.04), mat_index=m["gold"], bevel_width=0.008)

    bars_obj = pb.finalize(smooth_angle_deg=35.0)
    bars_obj.parent = gate_obj

    return export_kit_glb([gate_obj, bars_obj], "kit_boss_gate.glb", rigged=False)


def build_all_arena_props() -> list[str]:
    return [
        build_gothic_pillar(),
        build_gothic_arch(),
        build_wrought_brazier(),
        build_dark_shrine(),
        build_sanctum_plinth(),
        build_boss_gate(),
    ]
