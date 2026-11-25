import math
import bpy
from mathutils import Vector

from .kit_anims import bake_master_animations
from .kit_common import (
    RiggedMeshBuilder,
    build_master_armature,
    diamond_blade_ring_godot,
    elliptical_ring_godot,
    export_kit_glb,
    godot_to_blender,
    hex_to_srgb,
    make_kit_materials,
    make_pbr_mat,
    reset_scene,
    tube_ring_godot,
)


def _mat_slots(mats: dict[str, bpy.types.Material]) -> tuple[list[bpy.types.Material], dict[str, int]]:
    order = [
        "gunmetal",      # 0
        "black_steel",   # 1
        "honed_steel",   # 2
        "gold",          # 3
        "cloth",         # 4
        "crimson_cloth", # 5
        "ash_cloth",     # 6
        "leather",       # 7
        "bone",          # 8
        "emit_amber",    # 9
        "emit_blue",     # 10
        "emit_cinder",   # 11
    ]
    return [mats[k] for k in order], {k: i for i, k in enumerate(order)}


def _oathbreaker_mat_slots() -> tuple[list[bpy.types.Material], dict[str, int]]:
    mats = {
        "ArmorPlate": make_pbr_mat("ArmorPlate", (0.38, 0.42, 0.48), 0.88, 0.32, "brushed", 11),
        "ArmorTrim": make_pbr_mat("ArmorTrim", hex_to_srgb("#C49A48"), 0.90, 0.28, "brushed", 44),
        "ArmorUnder": make_pbr_mat("ArmorUnder", (0.24, 0.26, 0.31), 0.78, 0.42, "hammered", 22),
        "CapeCloth": make_pbr_mat("CapeCloth", hex_to_srgb("#181B25"), 0.0, 0.92, "cloth", 55),
        "TabardCloth": make_pbr_mat("TabardCloth", hex_to_srgb("#1D1F2A"), 0.0, 0.91, "cloth", 61),
        "HelmPlume": make_pbr_mat("HelmPlume", hex_to_srgb("#948B7B"), 0.0, 0.84, "bone", 99),
        "HelmEye": make_pbr_mat("HelmEye", (0.95, 0.62, 0.22), 0.0, 0.25, emission_srgb=(0.94, 0.54, 0.14), emission_strength=1.7),
        "LanternCore": make_pbr_mat("LanternCore", (0.18, 0.52, 0.88), 0.0, 0.18, emission_srgb=(0.20, 0.58, 0.96), emission_strength=1.2),
        "WeaponSteel": make_pbr_mat("WeaponSteel", (0.66, 0.69, 0.75), 0.95, 0.20, "brushed", 33),
        "WeaponGuard": make_pbr_mat("WeaponGuard", (0.24, 0.27, 0.32), 0.90, 0.28, "hammered", 27),
        "WeaponGrip": make_pbr_mat("WeaponGrip", hex_to_srgb("#2C2018"), 0.0, 0.78, "leather", 88),
    }
    order = list(mats.keys())
    return [mats[k] for k in order], {k: i for i, k in enumerate(order)}


def _add_torso_core(
    mb: RiggedMeshBuilder,
    s: float,
    w_scale: float,
    plate_m: int,
    under_m: int,
    trim_m: int,
    leather_m: int,
    ember_m: int | None = None,
) -> None:
    trunk_spec = [
        (0.95, 0.140 * w_scale, 0.105, {"hips": 0.9, "spine": 0.1}),
        (1.06, 0.130 * w_scale, 0.100, {"hips": 0.6, "spine": 0.4}),
        (1.20, 0.126 * w_scale, 0.098, {"spine": 0.8, "hips": 0.2}),
        (1.36, 0.166 * w_scale, 0.120, {"chest": 0.85, "spine": 0.15}),
        (1.52, 0.194 * w_scale, 0.126, {"chest": 0.95, "neck": 0.05}),
        (1.62, 0.080 * w_scale, 0.078, {"neck": 0.7, "chest": 0.3}),
        (1.70, 0.070 * w_scale, 0.072, {"head": 0.45, "neck": 0.55}),
    ]
    rings = [elliptical_ring_godot(0.0, y * s, 0.0, rx * s, rz * s, 14) for (y, rx, rz, _) in trunk_spec]
    mb.add_loft(rings, mat_index=under_m, weights=[w for (_, _, _, w) in trunk_spec])

    # Articulated wasp-waist fluted gothic cuirass (lower plackart + sculpted chest keel).
    cuirass_spec = [
        (1.12, 0.144 * w_scale, 0.114, 0.016, {"spine": 0.65, "hips": 0.35}),
        (1.22, 0.138 * w_scale, 0.116, 0.024, {"spine": 0.80, "chest": 0.20}),
        (1.34, 0.184 * w_scale, 0.142, 0.038, {"chest": 0.88, "spine": 0.12}),
        (1.46, 0.214 * w_scale, 0.152, 0.040, {"chest": 0.95, "spine": 0.05}),
        (1.56, 0.188 * w_scale, 0.130, 0.022, {"chest": 0.95, "neck": 0.05}),
    ]
    c_rings = [
        elliptical_ring_godot(0.0, y * s, 0.005 * s, rx * s, rz * s, 16, keel_front=kf * s, keel_back=0.014 * s, flute_amp=0.024, flute_freq=6)
        for (y, rx, rz, kf, _) in cuirass_spec
    ]
    mb.add_loft(c_rings, mat_index=plate_m, weights=[w for (_, _, _, _, w) in cuirass_spec], bevel_width=0.003 * s)

    # Gorget collar & V-shaped pectoral trim ridge.
    gorget_rings = [
        elliptical_ring_godot(0.0, 1.54 * s, 0.01 * s, 0.138 * w_scale * s, 0.116 * s, 14, keel_front=0.022 * s),
        elliptical_ring_godot(0.0, 1.60 * s, 0.01 * s, 0.110 * w_scale * s, 0.098 * s, 14, keel_front=0.016 * s),
        elliptical_ring_godot(0.0, 1.64 * s, 0.01 * s, 0.092 * w_scale * s, 0.086 * s, 14, keel_front=0.012 * s),
    ]
    mb.add_loft(gorget_rings, mat_index=trim_m, weights={"chest": 0.65, "neck": 0.35})

    # Sculpted waist belt + beveled buckle shield.
    belt_rings = [
        elliptical_ring_godot(0.0, 1.04 * s, 0.0, 0.156 * w_scale * s, 0.122 * s, 16, keel_front=0.012 * s),
        elliptical_ring_godot(0.0, 1.11 * s, 0.0, 0.154 * w_scale * s, 0.120 * s, 16, keel_front=0.012 * s),
    ]
    mb.add_loft(belt_rings, mat_index=leather_m, weights={"hips": 0.75, "spine": 0.25})
    mb.add_beveled_box_godot(
        (0.0, 1.075 * s, 0.125 * s),
        (0.070 * s, 0.066 * s, 0.028 * s),
        mat_index=trim_m,
        weights={"hips": 0.80, "spine": 0.20},
        bevel_width=0.006 * s,
    )

    # Cross-chest leather baldric strap wrapping torso cleanly.
    strap_rings = []
    strap_wts = []
    for i in range(11):
        t = i / 10.0
        sx = (0.155 - 0.310 * t) * w_scale * s
        sy = (1.54 - 0.44 * t) * s
        sz = (0.132 * math.sin(t * math.pi) + 0.026) * s
        w = {"chest": 0.9, "spine": 0.1} if t < 0.45 else ({"chest": 0.4, "spine": 0.6} if t < 0.75 else {"spine": 0.5, "hips": 0.5})
        strap_rings.append(tube_ring_godot((sx, sy, sz), (-0.6, -0.8, 0.0), 0.020 * s, 0.010 * s, 6))
        strap_wts.append(w)
    mb.add_loft(strap_rings, mat_index=leather_m, weights=strap_wts)

    if ember_m is not None:
        for ry in (1.28, 1.37, 1.46):
            r0 = elliptical_ring_godot(0.0, ry * s, 0.008 * s, 0.170 * w_scale * s, 0.143 * s, 14, keel_front=0.036 * s)
            r1 = elliptical_ring_godot(0.0, (ry + 0.013) * s, 0.008 * s, 0.172 * w_scale * s, 0.145 * s, 14, keel_front=0.038 * s)
            mb.add_loft([r0, r1], mat_index=ember_m, weights={"chest": 0.85, "spine": 0.15})


def _add_pauldrons(
    mb: RiggedMeshBuilder,
    s: float,
    w_scale: float,
    style: str,
    plate_m: int,
    trim_m: int,
    mantle_m: int | None = None,
) -> None:
    xz_broad = 1.16 if style in ("sovereign", "boss_spiked") else 1.0
    for side, sgn in (("l", 1.0), ("r", -1.0)):
        if style == "thrall" and sgn > 0.0:
            continue
        tiers = [
            (0.00, 0.118 * xz_broad, 0.125 * xz_broad, 0.092, {"chest": 0.30, f"shoulder_{side}": 0.50, f"upper_arm_{side}": 0.20}, True),
            (-0.055, 0.106 * xz_broad, 0.115 * xz_broad, 0.072, {f"shoulder_{side}": 0.30, f"upper_arm_{side}": 0.70}, False),
            (-0.105, 0.096 * xz_broad, 0.104 * xz_broad, 0.058, {f"shoulder_{side}": 0.20, f"upper_arm_{side}": 0.80}, False),
        ]
        x_shoulder_base = (0.216 if xz_broad > 1.0 else 0.205) * w_scale
        for idx, (dy, rx, rz, h, wts, is_top) in enumerate(tiers):
            rows = 5
            cols = 11
            grid: list[list[Vector]] = []
            for r in range(rows):
                vr = r / (rows - 1)
                row_pts: list[Vector] = []
                for c in range(cols):
                    uc = -1.0 + 2.0 * (c / (cols - 1))
                    ang = uc * 1.35
                    flare = 1.0 + (0.14 if (style in ("boss_spiked", "halberdier") and r == 0) else 0.0)
                    px = sgn * (x_shoulder_base + math.sin(vr * 1.45) * rx * flare + 0.012 * idx)
                    py = 1.595 + dy - (vr ** 1.35) * h + (0.048 * (1.0 - vr) if (is_top and abs(uc) < 0.35 and style != "thrall") else 0.0)
                    if style in ("boss_spiked", "halberdier") and is_top and r == 0 and abs(uc) < 0.22:
                        py += 0.075
                    pz = math.sin(ang) * rz * (0.72 + 0.35 * vr)
                    row_pts.append(godot_to_blender(px * s, py * s, pz * s))
                grid.append(row_pts)
            mb.add_grid_sheet(grid, mat_index=plate_m, row_weights=[wts] * rows, thickness=0.011 * s)

            if style in ("sovereign", "boss_spiked", "halberdier"):
                rim_pts = [
                    tube_ring_godot(
                        (
                            sgn * (x_shoulder_base + math.sin(1.45) * rx + 0.012 * idx) * s,
                            (1.595 + dy - h) * s,
                            math.sin((-1.0 + 2.0 * (c / 10.0)) * 1.35) * rz * 1.07 * s,
                        ),
                        (0.0, 0.0, 1.0),
                        0.007 * s,
                        0.007 * s,
                        6,
                    )
                    for c in range(11)
                ]
                mb.add_loft(rim_pts, mat_index=trim_m, weights=wts)

        if style in ("sovereign", "boss_spiked"):
            flange_pts = []
            for r in range(3):
                vr = r / 2.0
                row = []
                for c in range(5):
                    uc = -1.0 + 2.0 * (c / 4.0)
                    fx = sgn * (0.145 * w_scale + 0.028 * xz_broad * vr) * s
                    fy = (1.57 + 0.078 * vr - 0.022 * (uc * uc)) * s
                    fz = (uc * 0.088 * xz_broad) * s
                    row.append(godot_to_blender(fx, fy, fz))
                flange_pts.append(row)
            mb.add_grid_sheet(
                flange_pts,
                mat_index=trim_m if style == "sovereign" else plate_m,
                row_weights=[{"chest": 0.65, f"shoulder_{side}": 0.35}] * 3,
                thickness=0.009 * s,
            )

        if mantle_m is not None and sgn > 0.0:
            m_grid: list[list[Vector]] = []
            for r in range(6):
                vr = r / 5.0
                row = []
                for c in range(11):
                    uc = -1.0 + 2.0 * (c / 10.0)
                    mx = (0.04 + 0.25 * vr) * sgn * s
                    my = (1.62 - 0.16 * vr + 0.012 * math.sin(c * 2.1)) * s
                    mz = (math.sin(uc * 1.45) * (0.13 + 0.04 * vr) - 0.02 * vr) * s
                    row.append(godot_to_blender(mx, my, mz))
                m_grid.append(row)
            mb.add_grid_sheet(
                m_grid,
                mat_index=mantle_m,
                row_weights=[{"chest": 0.70, f"shoulder_{side}": 0.30}] * 6,
                thickness=0.016 * s,
            )


def _add_joint_cop(
    mb: RiggedMeshBuilder,
    center: tuple[float, float, float],
    tang_front: tuple[float, float, float],
    rx: float,
    ry: float,
    rz: float,
    s: float,
    sgn: float,
    plate_m: int,
    trim_m: int,
    weights: dict[str, float],
    wing_side: bool = True,
) -> None:
    # Sculpted almond-shell gothic couter/poleyn cop wrapping cleanly over joints (replaces boxy cubes!).
    cx, cy, cz = center
    fx, fy, fz = tang_front
    rows = 5
    cols = 9
    grid: list[list[Vector]] = []
    for r in range(rows):
        vr = -1.0 + 2.0 * (r / (rows - 1))
        row: list[Vector] = []
        for c in range(cols):
            uc = -1.0 + 2.0 * (c / (cols - 1))
            ang = uc * 1.45
            arch = math.cos(vr * 1.25)
            wing = 0.024 * s if (wing_side and uc * sgn > 0.45 and abs(vr) < 0.55) else 0.0
            px = cx + (math.sin(ang) * rx + sgn * wing) * s * (0.65 + 0.35 * arch)
            py = cy + vr * ry * s
            pz = cz + (math.cos(ang) * rz * arch + 0.018 * (1.0 - vr * vr)) * s * (1.0 if fz >= 0 else -1.0)
            row.append(godot_to_blender(px, py, pz))
        grid.append(row)
    mb.add_grid_sheet(grid, mat_index=plate_m, row_weights=[weights] * rows, thickness=0.010 * s)
    # Trim ridge crest along center of cop.
    mb.add_loft(
        [
            elliptical_ring_godot(cx + sgn * rx * 0.6 * s, (cy - ry * 0.35 * s), cz + (0.01 * s if fz >= 0 else -0.01 * s), 0.012 * s, 0.012 * s, 6),
            elliptical_ring_godot(cx + sgn * (rx + 0.022) * s, cy, cz + (0.015 * s if fz >= 0 else -0.015 * s), 0.016 * s, 0.016 * s, 6),
            elliptical_ring_godot(cx + sgn * rx * 0.6 * s, (cy + ry * 0.35 * s), cz + (0.01 * s if fz >= 0 else -0.01 * s), 0.012 * s, 0.012 * s, 6),
        ],
        mat_index=trim_m,
        weights=weights,
    )


def _add_arms_and_gauntlets(
    mb: RiggedMeshBuilder,
    s: float,
    w_scale: float,
    plate_m: int,
    under_m: int,
    trim_m: int,
    spiked_cuffs: bool = False,
    gaunt: bool = False,
) -> None:
    r_mul = 0.80 if gaunt else (1.16 if w_scale > 1.1 else 1.0)
    for side, sgn in (("l", 1.0), ("r", -1.0)):
        sx = 0.230 * s
        ex = 0.295 * s
        wx = 0.315 * s
        hx = 0.320 * s

        # Continuous inner arming sleeve from shoulder to wrist.
        sleeve = [
            tube_ring_godot((sx * sgn, 1.53 * s, 0.0), (0.065 * sgn, -0.31, -0.02), 0.048 * r_mul * s, 0.048 * r_mul * s, 10),
            tube_ring_godot((ex * sgn, 1.23 * s, -0.02 * s), (0.03 * sgn, -0.30, 0.03), 0.042 * r_mul * s, 0.042 * r_mul * s, 10),
            tube_ring_godot((wx * sgn, 0.94 * s, 0.05 * s), (0.02 * sgn, -0.29, 0.07), 0.036 * r_mul * s, 0.036 * r_mul * s, 10),
        ]
        mb.add_loft(
            sleeve,
            mat_index=under_m,
            weights=[
                {f"upper_arm_{side}": 0.90, f"shoulder_{side}": 0.10},
                {f"upper_arm_{side}": 0.50, f"forearm_{side}": 0.50},
                {f"forearm_{side}": 0.90, f"hand_{side}": 0.10},
            ],
        )

        # Smoothly tapered upper-arm rerebrace overlapping elbow.
        rere = [
            tube_ring_godot((0.244 * sgn * s, 1.48 * s, -0.004 * s), (0.065 * sgn, -0.31, -0.02), 0.055 * r_mul * s, 0.052 * r_mul * s, 12, flute_amp=0.03, flute_freq=4),
            tube_ring_godot((0.270 * sgn * s, 1.36 * s, -0.012 * s), (0.065 * sgn, -0.31, -0.02), 0.051 * r_mul * s, 0.049 * r_mul * s, 12, flute_amp=0.03, flute_freq=4),
            tube_ring_godot((0.290 * sgn * s, 1.25 * s, -0.019 * s), (0.065 * sgn, -0.31, -0.02), 0.046 * r_mul * s, 0.044 * r_mul * s, 12),
        ]
        mb.add_loft(rere, mat_index=plate_m, weights={f"upper_arm_{side}": 0.90, f"forearm_{side}": 0.10})

        # Sculpted gothic elbow couter shell.
        _add_joint_cop(
            mb,
            (ex * sgn, 1.23 * s, -0.025 * s),
            (0.0, 0.0, -1.0),
            0.056 * r_mul,
            0.054,
            0.052 * r_mul,
            s,
            sgn,
            plate_m,
            trim_m,
            {f"upper_arm_{side}": 0.50, f"forearm_{side}": 0.50},
        )

        # Sleek fluted gothic vambrace with flared elbow cuff & tapered wrist.
        vam = [
            tube_ring_godot((0.296 * sgn * s, 1.21 * s, -0.014 * s), (0.02 * sgn, -0.29, 0.07), 0.054 * r_mul * s, 0.050 * r_mul * s, 12, flute_amp=0.05, flute_freq=4),
            tube_ring_godot((0.308 * sgn * s, 1.07 * s, 0.018 * s), (0.02 * sgn, -0.29, 0.07), 0.046 * r_mul * s, 0.043 * r_mul * s, 12, flute_amp=0.05, flute_freq=4),
            tube_ring_godot((0.315 * sgn * s, 0.94 * s, 0.050 * s), (0.02 * sgn, -0.29, 0.07), 0.038 * r_mul * s, 0.036 * r_mul * s, 12, flute_amp=0.04, flute_freq=4),
        ]
        mb.add_loft(vam, mat_index=plate_m, weights={f"forearm_{side}": 0.95, f"hand_{side}": 0.05})

        if spiked_cuffs:
            mb.add_loft(
                [
                    tube_ring_godot((0.312 * sgn * s, 1.19 * s, -0.02 * s), (0.0, -1.0, 0.0), 0.018 * s, 0.014 * s, 6),
                    tube_ring_godot((0.352 * sgn * s, 1.12 * s, -0.03 * s), (0.0, -1.0, 0.0), 0.004 * s, 0.004 * s, 6),
                ],
                mat_index=trim_m,
                weights={f"forearm_{side}": 1.0},
            )

        # Sleek tapered gothic gauntlet cuff + knuckle ridge + curled armored fingers fixed at exact hand bone!
        gaunt_w = {f"hand_{side}": 0.95, f"forearm_{side}": 0.05}
        gaunt_cuff = [
            elliptical_ring_godot(hx * sgn, 0.94 * s, 0.052 * s, 0.044 * r_mul * s, 0.042 * s, 10),
            elliptical_ring_godot(hx * sgn, 0.89 * s, 0.064 * s, 0.036 * r_mul * s, 0.038 * s, 10, keel_front=0.008 * s),
            elliptical_ring_godot(hx * sgn, 0.85 * s, 0.068 * s, 0.032 * r_mul * s, 0.036 * s, 10),
        ]
        mb.add_loft(gaunt_cuff, mat_index=plate_m, weights=gaunt_w)

        # Curled armored fingers wrapping cleanly around weapon grip ((hx - 0.010*s)*sgn, 0.855*s, 0.068*s).
        fgx = (hx - 0.010 * s) * sgn
        curl_rings = [
            elliptical_ring_godot(fgx, 0.854 * s, 0.068 * s, 0.033 * r_mul * s, 0.044 * s, 10),
            elliptical_ring_godot(fgx, 0.822 * s, 0.068 * s, 0.028 * r_mul * s, 0.038 * s, 10),
        ]
        mb.add_loft(curl_rings, mat_index=plate_m, weights={f"hand_{side}": 1.0})


def _add_legs_tassets_tabard(
    mb: RiggedMeshBuilder,
    s: float,
    w_scale: float,
    plate_m: int,
    under_m: int,
    trim_m: int,
    cloth_m: int,
    tasset_style: str = "layered",
    has_tabard: bool = True,
    gaunt: bool = False,
) -> None:
    r_mul = 0.80 if gaunt else (1.16 if w_scale > 1.1 else 1.0)

    skirt_rings = [
        elliptical_ring_godot(0.0, 1.05 * s, 0.0, 0.154 * w_scale * s, 0.124 * s, 14),
        elliptical_ring_godot(0.0, 0.90 * s, 0.0, 0.174 * w_scale * s, 0.138 * s, 14),
        elliptical_ring_godot(0.0, 0.76 * s, 0.0, 0.192 * w_scale * s, 0.152 * s, 14),
    ]
    mb.add_loft(
        skirt_rings,
        mat_index=under_m,
        weights=[{"hips": 1.0}, {"hips": 0.7, "thigh_l": 0.15, "thigh_r": 0.15}, {"hips": 0.4, "thigh_l": 0.3, "thigh_r": 0.3}],
    )

    if tasset_style != "none":
        tiers = 4 if tasset_style in ("layered", "spiked") else 2
        for side, sgn in (("l", 1.0), ("r", -1.0)):
            for t_idx in range(tiers):
                y_top = (1.03 - 0.088 * t_idx) * s
                y_bot = y_top - 0.098 * s
                flare = 0.015 * t_idx * s
                rows = 3
                cols = 9
                grid: list[list[Vector]] = []
                for r in range(rows):
                    vr = r / (rows - 1)
                    y = y_top + (y_bot - y_top) * vr
                    if tasset_style == "spiked" and r == rows - 1:
                        y -= 0.026 * s
                    row: list[Vector] = []
                    for c in range(cols):
                        uc = -1.0 + 2.0 * (c / (cols - 1))
                        ang = uc * 1.15
                        rad_x = (0.172 * w_scale + 0.024 * vr) * s + flare
                        rad_z = (0.144 + 0.020 * vr) * s + flare * 0.7
                        px = sgn * (0.045 * s + math.cos(ang * 0.45) * rad_x)
                        pz = math.sin(ang) * rad_z
                        py = y - (0.016 * s if (tasset_style == "spiked" and r == rows - 1 and abs(uc) < 0.3) else 0.0)
                        row.append(godot_to_blender(px, py, pz))
                    grid.append(row)
                tw = {"hips": 0.72 - 0.10 * t_idx, f"thigh_{side}": 0.28 + 0.10 * t_idx}
                mb.add_grid_sheet(grid, mat_index=plate_m, row_weights=[tw] * rows, thickness=0.009 * s)

                if tasset_style == "layered" and t_idx == tiers - 1:
                    trim_pts = [
                        tube_ring_godot(
                            (
                                sgn * (0.045 * s + math.cos((-1.0 + 2.0 * (c / 8.0)) * 1.15 * 0.45) * ((0.172 * w_scale + 0.024) * s + flare)),
                                y_bot,
                                math.sin((-1.0 + 2.0 * (c / 8.0)) * 1.15) * ((0.144 + 0.020) * s + flare * 0.7),
                            ),
                            (0.0, 0.0, 1.0),
                            0.006 * s,
                            0.006 * s,
                            6,
                        )
                        for c in range(9)
                    ]
                    mb.add_loft(trim_pts, mat_index=trim_m, weights=tw)

    if has_tabard:
        t_rows = 8
        t_cols = 7
        t_grid: list[list[Vector]] = []
        t_wts: list[dict[str, float]] = []
        for r in range(t_rows):
            vr = r / (t_rows - 1)
            y = (1.03 - 0.66 * vr) * s
            z = (0.140 + 0.044 * vr) * s
            half_w = (0.088 + 0.032 * vr) * s
            row = []
            for c in range(t_cols):
                uc = -1.0 + 2.0 * (c / (t_cols - 1))
                row.append(godot_to_blender(uc * half_w, y - (0.035 * s if (r == t_rows - 1 and abs(uc) < 0.2) else 0.0), z + 0.005 * math.cos(uc * 3.0) * s))
            t_grid.append(row)
            t_wts.append({"hips": max(0.35, 1.0 - 0.65 * vr), "thigh_l": 0.32 * vr, "thigh_r": 0.32 * vr})
        mb.add_grid_sheet(t_grid, mat_index=cloth_m, row_weights=t_wts, thickness=0.008 * s)

    for side, sgn in (("l", 1.0), ("r", -1.0)):
        hx = 0.105 * sgn * s
        kx = 0.125 * sgn * s
        ax = 0.125 * sgn * s

        # Inner continuous leg mail/leather tube across knee.
        leg_inner = [
            elliptical_ring_godot(hx, 0.98 * s, 0.0, 0.072 * r_mul * s, 0.074 * r_mul * s, 10),
            elliptical_ring_godot(kx, 0.54 * s, 0.015 * s, 0.056 * r_mul * s, 0.058 * r_mul * s, 10),
            elliptical_ring_godot(ax, 0.12 * s, -0.012 * s, 0.042 * r_mul * s, 0.044 * r_mul * s, 10),
        ]
        mb.add_loft(leg_inner, mat_index=under_m, weights=[{f"thigh_{side}": 1.0}, {f"thigh_{side}": 0.5, f"shin_{side}": 0.5}, {f"shin_{side}": 1.0}])

        # Sculpted thigh cuisse.
        cuisse = [
            elliptical_ring_godot(hx, 0.96 * s, 0.0, 0.084 * r_mul * s, 0.086 * r_mul * s, 12, keel_front=0.012 * s),
            elliptical_ring_godot((hx + kx) * 0.5, 0.76 * s, 0.01 * s, 0.075 * r_mul * s, 0.078 * r_mul * s, 12, keel_front=0.014 * s),
            elliptical_ring_godot(kx, 0.57 * s, 0.015 * s, 0.064 * r_mul * s, 0.068 * r_mul * s, 12, keel_front=0.012 * s),
        ]
        mb.add_loft(cuisse, mat_index=plate_m if not gaunt else under_m, weights={f"thigh_{side}": 0.92, "hips": 0.08})

        # Sculpted winged gothic knee poleyn shell (NO square box!).
        _add_joint_cop(
            mb,
            (kx, 0.54 * s, 0.022 * s),
            (0.0, 0.0, 1.0),
            0.064 * r_mul,
            0.068,
            0.066 * r_mul,
            s,
            sgn,
            plate_m,
            trim_m,
            {f"thigh_{side}": 0.50, f"shin_{side}": 0.50},
        )

        # Sleek contoured fluted greaves tapering cleanly into ankle.
        greave = [
            elliptical_ring_godot(kx, 0.51 * s, 0.012 * s, 0.068 * r_mul * s, 0.074 * r_mul * s, 14, keel_front=0.024 * s, flute_amp=0.04, flute_freq=4),
            elliptical_ring_godot(ax, 0.34 * s, 0.0 * s, 0.065 * r_mul * s, 0.072 * r_mul * s, 14, keel_front=0.024 * s, flute_amp=0.04, flute_freq=4),
            elliptical_ring_godot(ax, 0.13 * s, -0.012 * s, 0.048 * r_mul * s, 0.052 * r_mul * s, 14, keel_front=0.016 * s),
        ]
        mb.add_loft(greave, mat_index=plate_m, weights={f"shin_{side}": 0.94, f"foot_{side}": 0.06})

        # Articulated gothic sabaton resting cleanly at Y = 0.0.
        sab_spec = [
            (-0.045, 0.048 * r_mul, 0.042, 0.004),
            (0.040, 0.054 * r_mul, 0.044, 0.006),
            (0.130, 0.046 * r_mul, 0.036, 0.008),
            (0.215, 0.024 * r_mul, 0.020, 0.012),
            (0.260, 0.006 * r_mul, 0.008, 0.003),
        ]
        sab_rings = []
        for z_off, rx, ry, arch in sab_spec:
            cy = (ry + 0.003) * s
            pts = []
            for k in range(10):
                ang = 2.0 * math.pi * k / 10
                px = ax + math.cos(ang) * rx * s
                py = max(0.002 * s, cy + math.sin(ang) * ry * s + (arch * s if math.sin(ang) > 0 else 0.0))
                pz = (-0.015 + z_off) * s
                pts.append(godot_to_blender(px, py, pz))
            sab_rings.append(pts)
        mb.add_loft(sab_rings, mat_index=plate_m, weights={f"foot_{side}": 0.92, f"shin_{side}": 0.08})


def _add_tattered_cape(
    mb: RiggedMeshBuilder,
    s: float,
    cloth_m: int,
    w_top: float = 0.25,
    w_bot: float = 0.52,
    length_y: float = 1.38,
    jagged: float = 0.16,
    collar_scarf: bool = True,
) -> None:
    if collar_scarf:
        c_rings = [
            elliptical_ring_godot(0.0, 1.56 * s, 0.0, 0.148 * s, 0.132 * s, 14, flute_amp=0.05, flute_freq=6),
            elliptical_ring_godot(0.0, 1.63 * s, 0.0, 0.125 * s, 0.118 * s, 14, flute_amp=0.05, flute_freq=6),
            elliptical_ring_godot(0.0, 1.68 * s, 0.005 * s, 0.104 * s, 0.100 * s, 14, flute_amp=0.04, flute_freq=6),
        ]
        mb.add_loft(c_rings, mat_index=cloth_m, weights={"chest": 0.65, "neck": 0.35})

    rows = 16
    cols = 19
    # Organic asymmetric tatter offsets (irregular worn hem rather than uniform sawtooth!).
    tatter_profile = [
        0.00, 0.08, 0.14, 0.04, 0.01, 0.11, 0.18, 0.06, 0.02, 0.00,
        0.05, 0.16, 0.09, 0.02, 0.13, 0.17, 0.05, 0.09, 0.00,
    ]
    grid: list[list[Vector]] = []
    wts: list[dict[str, float]] = []
    for r in range(rows):
        v = r / (rows - 1)
        row: list[Vector] = []
        for c in range(cols):
            u = -1.0 + 2.0 * (c / (cols - 1))
            hw = w_top + (w_bot - w_top) * (v ** 0.85)
            x = (math.sin(u * 1.15) * hw * (1.0 - 0.45 * v) + u * hw * 0.45 * v) * s
            pleat = math.sin(u * math.pi * 3.5) * (0.010 + 0.032 * v) * s
            notch = (tatter_profile[c] / 0.18) * jagged * (max(0.0, (v - 0.72) / 0.28) ** 1.35) * s
            y = (1.57 - length_y * v + 0.03 * (1.0 - u * u) * max(0.0, 1.0 - v * 3.5)) * s + notch
            shoulder_wrap = 0.095 * (u * u) * max(0.0, 1.0 - v * 2.5)
            z = (-0.13 - 0.16 * (v ** 0.85) + shoulder_wrap) * s + pleat
            row.append(godot_to_blender(x, y, z))
        grid.append(row)

        if v < 0.22:
            w = {"chest": 0.70, "cape_0": 0.30}
        elif v < 0.52:
            t = (v - 0.22) / 0.30
            w = {"cape_0": 1.0 - t, "cape_1": t}
        elif v < 0.80:
            t = (v - 0.52) / 0.28
            w = {"cape_1": 1.0 - t, "cape_2": t}
        else:
            w = {"cape_2": 1.0}
        wts.append(w)

    mb.add_grid_sheet(grid, mat_index=cloth_m, row_weights=wts, thickness=0.011 * s)


def _add_plume(mb: RiggedMeshBuilder, s: float, mount_m: int, hair_m: int) -> None:
    comb = [
        elliptical_ring_godot(0.0, 1.94 * s, (-0.04 + 0.10 * (i / 4.0)) * s, 0.014 * s, 0.025 * s, 6)
        for i in range(5)
    ]
    mb.add_loft(comb, mat_index=mount_m, weights={"head": 1.0})

    locks = [
        (0.0, 1.95, 2.11, 1.54, -0.36, 0.036),
        (-0.024, 1.93, 2.05, 1.60, -0.32, 0.027),
        (0.024, 1.93, 2.05, 1.60, -0.32, 0.027),
        (0.0, 1.91, 2.00, 1.48, -0.40, 0.024),
    ]
    for x0, y0, y_peak, y_end, z_end, base_r in locks:
        p0 = Vector((x0 * 0.4, y0, -0.02)) * s
        p1 = Vector((x0 * 0.9, y_peak, -0.10)) * s
        p2 = Vector((x0 * 1.2, (y_peak + y_end) * 0.55, z_end * 0.72)) * s
        p3 = Vector((x0 * 1.1, y_end, z_end)) * s
        rings = []
        for i in range(13):
            t = i / 12.0
            omt = 1.0 - t
            c = (omt ** 3) * p0 + 3.0 * (omt ** 2) * t * p1 + 3.0 * omt * (t ** 2) * p2 + (t ** 3) * p3
            prev_t = max(0.0, (i - 1) / 12.0)
            op = 1.0 - prev_t
            prev = (op ** 3) * p0 + 3.0 * (op ** 2) * prev_t * p1 + 3.0 * op * (prev_t ** 2) * p2 + (prev_t ** 3) * p3
            tang = c - prev if i > 0 else Vector((0.0, 0.1, -0.1))
            swell = math.sin(min(1.0, t * 0.90 + 0.10) * math.pi)
            r = max(0.002 * s, base_r * s * (0.45 + 0.72 * swell) * (1.0 - 0.85 * (t ** 2.2)))
            rings.append(tube_ring_godot((c.x, c.y, c.z), (tang.x, tang.y, tang.z), r, r * 1.25, 8, flute_amp=0.12, flute_freq=3))
        mb.add_loft(rings, mat_index=hair_m, weights={"head": 1.0})


def _add_helm_barbute(
    mb: RiggedMeshBuilder,
    s: float,
    plate_m: int,
    trim_m: int,
    dark_m: int,
    eye_m: int,
    crowned: bool = False,
    horned: bool = False,
) -> None:
    hw = {"head": 1.0}
    inner_spec = [
        (1.66, 0.072, 0.082),
        (1.78, 0.084, 0.094),
        (1.90, 0.068, 0.078),
    ]
    mb.add_loft([elliptical_ring_godot(0.0, y * s, 0.012 * s, rx * s, rz * s, 12) for (y, rx, rz) in inner_spec], mat_index=dark_m, weights=hw)

    for sgn in (-1.0, 1.0):
        mb.add_loft(
            [
                elliptical_ring_godot(sgn * 0.030 * s, 1.800 * s, 0.095 * s, 0.011 * s, 0.006 * s, 6),
                elliptical_ring_godot(sgn * 0.030 * s, 1.812 * s, 0.098 * s, 0.011 * s, 0.006 * s, 6),
            ],
            mat_index=eye_m,
            weights=hw,
        )

    skull_spec = [
        (1.65, 0.084, 0.092, 0.028),
        (1.72, 0.090, 0.106, 0.038),
        (1.79, 0.094, 0.116, 0.042),
        (1.86, 0.097, 0.122, 0.034),
        (1.92, 0.084, 0.108, 0.024),
        (1.96, 0.045, 0.064, 0.012),
        (1.98, 0.011, 0.016, 0.004),
    ]
    s_rings = []
    for y, rx, rz, kf in skull_spec:
        pts = []
        for i in range(16):
            ang = (2.0 * math.pi * i) / 16.0
            ca = math.cos(ang)
            sa = math.sin(ang)
            lx = ca * rx
            lz = sa * rz
            if sa > 0.0:
                lz += kf * (sa ** 2.0)
                if 1.71 <= y <= 1.825 and abs(ca) < 0.38:
                    lz *= 0.78
            pts.append(godot_to_blender(lx * s, y * s, (lz + 0.012) * s))
        s_rings.append(pts)
    mb.add_loft(s_rings, mat_index=plate_m, weights=hw)

    nasal = [
        elliptical_ring_godot(0.0, 1.71 * s, 0.120 * s, 0.007 * s, 0.018 * s, 6),
        elliptical_ring_godot(0.0, 1.805 * s, 0.132 * s, 0.009 * s, 0.022 * s, 6),
        elliptical_ring_godot(0.0, 1.865 * s, 0.124 * s, 0.008 * s, 0.017 * s, 6),
    ]
    mb.add_loft(nasal, mat_index=plate_m, weights=hw)

    visor_brow_rings = []
    for i in range(9):
        u = -1.0 + 2.0 * (i / 8.0)
        vx = math.sin(u * 0.72) * 0.096 * s
        vy = (1.826 + 0.012 * abs(u)) * s
        vz = (math.cos(u * 0.72) * 0.124 + 0.008) * s
        visor_brow_rings.append(tube_ring_godot((vx, vy, vz), (1.0, 0.0, -u * 0.6), 0.0045 * s, 0.0055 * s, 6))
    mb.add_loft(visor_brow_rings, mat_index=trim_m, weights=hw)
    mb.add_loft(
        [
            elliptical_ring_godot(0.0, 1.718 * s, 0.126 * s, 0.004 * s, 0.009 * s, 6),
            elliptical_ring_godot(0.0, 1.808 * s, 0.138 * s, 0.005 * s, 0.010 * s, 6),
            elliptical_ring_godot(0.0, 1.862 * s, 0.130 * s, 0.004 * s, 0.008 * s, 6),
        ],
        mat_index=trim_m,
        weights=hw,
    )

    crest = [
        elliptical_ring_godot(0.0, 1.94 * s, (0.09 - 0.18 * (i / 6.0)) * s, 0.009 * s, 0.022 * s, 6)
        for i in range(7)
    ]
    mb.add_loft(crest, mat_index=trim_m, weights=hw)

    for sgn in (-1.0, 1.0):
        wing = [
            tube_ring_godot((sgn * 0.092 * s, 1.82 * s, 0.02 * s), (0.2 * sgn, 1.0, -0.5), 0.010 * s, 0.024 * s, 6),
            tube_ring_godot((sgn * 0.110 * s, 1.91 * s, -0.04 * s), (0.2 * sgn, 1.0, -0.5), 0.004 * s, 0.006 * s, 6),
        ]
        mb.add_loft(wing, mat_index=trim_m if not crowned else plate_m, weights=hw)

    if crowned:
        c_ring = elliptical_ring_godot(0.0, 1.90 * s, 0.012 * s, 0.094 * s, 0.114 * s, 14)
        c_ring2 = elliptical_ring_godot(0.0, 1.935 * s, 0.012 * s, 0.098 * s, 0.118 * s, 14)
        mb.add_loft([c_ring, c_ring2], mat_index=trim_m, weights=hw)
        for idx, (ang_deg, h_pt) in enumerate([(0, 0.14), (-38, 0.10), (38, 0.10), (-92, 0.09), (92, 0.09)]):
            ar = math.radians(ang_deg)
            px = math.sin(ar) * 0.092 * s
            pz = (math.cos(ar) * 0.112 + 0.012) * s
            spike = [
                elliptical_ring_godot(px, 1.92 * s, pz, 0.020 * s, 0.016 * s, 6),
                elliptical_ring_godot(px * 1.12, (1.92 + h_pt) * s, pz * 1.12, 0.004 * s, 0.004 * s, 6),
            ]
            mb.add_loft(spike, mat_index=plate_m if idx % 2 == 0 else trim_m, weights=hw)

    if horned:
        for sgn in (-1.0, 1.0):
            mb.add_loft(
                [
                    elliptical_ring_godot(sgn * 0.090 * s, 1.86 * s, 0.01 * s, 0.022 * s, 0.022 * s, 6),
                    elliptical_ring_godot(sgn * 0.160 * s, 1.96 * s, 0.04 * s, 0.014 * s, 0.014 * s, 6),
                    elliptical_ring_godot(sgn * 0.190 * s, 2.08 * s, 0.07 * s, 0.004 * s, 0.004 * s, 6),
                ],
                mat_index=trim_m,
                weights=hw,
            )


def _add_waist_lantern(mb: RiggedMeshBuilder, s: float, iron_m: int, emit_m: int) -> None:
    lx, ly, lz = 0.205 * s, 0.96 * s, 0.085 * s
    lw = {"lantern_bone": 1.0}
    cap_prof = [
        (0.000, 0.012),
        (-0.022, 0.022),
        (-0.052, 0.064),
        (-0.064, 0.068),
        (-0.072, 0.052),
    ]
    mb.add_loft([elliptical_ring_godot(lx, ly + dy * s, lz, r * s, r * s, 6) for (dy, r) in cap_prof], mat_index=iron_m, weights=lw)
    base_prof = [
        (-0.172, 0.050),
        (-0.184, 0.060),
        (-0.198, 0.042),
        (-0.232, 0.004),
    ]
    mb.add_loft([elliptical_ring_godot(lx, ly + dy * s, lz, r * s, r * s, 6) for (dy, r) in base_prof], mat_index=iron_m, weights=lw)
    for k in range(6):
        ang = 2.0 * math.pi * k / 6.0
        cx = lx + math.cos(ang) * 0.052 * s
        cz = lz + math.sin(ang) * 0.052 * s
        mb.add_loft(
            [
                elliptical_ring_godot(cx, ly - 0.065 * s, cz, 0.005 * s, 0.005 * s, 6),
                elliptical_ring_godot(cx, ly - 0.175 * s, cz, 0.005 * s, 0.005 * s, 6),
            ],
            mat_index=iron_m,
            weights=lw,
        )
    mb.add_loft(
        [
            elliptical_ring_godot(lx, ly - 0.072 * s, lz, 0.038 * s, 0.038 * s, 6),
            elliptical_ring_godot(lx, ly - 0.122 * s, lz, 0.042 * s, 0.042 * s, 6),
            elliptical_ring_godot(lx, ly - 0.172 * s, lz, 0.036 * s, 0.036 * s, 6),
        ],
        mat_index=emit_m,
        weights=lw,
    )


def _weapon_pt(s: float, wx: float, wy: float, wz: float) -> tuple[float, float, float]:
    return (-0.322 * s + wx * s, 0.855 * s + wy * s, 0.068 * s + wz * s)


def _add_zweihander(
    mb: RiggedMeshBuilder,
    s: float,
    blade_m: int,
    edge_m: int,
    guard_m: int,
    grip_m: int,
    trim_m: int,
    cinder_m: int | None = None,
    w_scale: float = 1.0,
) -> None:
    ww = {"weapon_r": 1.0}
    axis = (0.0, 0.0, 1.0)
    edge = (0.0, 1.0, 0.0)

    pom = [
        (-0.220, 0.008),
        (-0.200, 0.028 * w_scale),
        (-0.165, 0.032 * w_scale),
        (-0.135, 0.017 * w_scale),
    ]
    mb.add_loft([tube_ring_godot(_weapon_pt(s, 0.0, 0.0, wz), axis, r * s, r * 0.82 * s, 8) for (wz, r) in pom], mat_index=guard_m, weights=ww)

    g_rings = []
    for i in range(11):
        t = i / 10.0
        wz = -0.135 + 0.210 * t
        r = (0.0165 + 0.002 * math.sin(t * math.pi)) * w_scale
        g_rings.append(tube_ring_godot(_weapon_pt(s, 0.0, 0.0, wz), axis, r * 0.85 * s, r * s, 8))
    mb.add_loft(g_rings, mat_index=grip_m, weights=ww)

    q_rings = []
    for i in range(15):
        u = -1.0 + 2.0 * (i / 14.0)
        qy = u * 0.22 * w_scale
        qz = 0.088 + 0.032 * (u * u)
        qx = 0.016 * math.sin(u * math.pi)
        rad = (0.013 * (1.0 - 0.30 * abs(u)) + (0.009 if abs(u) > 0.88 else 0.0)) * w_scale
        q_rings.append(tube_ring_godot(_weapon_pt(s, qx, qy, qz), (0.0, 1.0, 0.25 * u), rad * s, rad * s, 8))
    mb.add_loft(q_rings, mat_index=guard_m, weights=ww)
    mb.add_beveled_box_godot(_weapon_pt(s, 0.0, 0.0, 0.090), (0.038 * w_scale * s, 0.056 * w_scale * s, 0.036 * s), mat_index=trim_m, weights=ww, bevel_width=0.005 * s)

    ric = [
        diamond_blade_ring_godot(_weapon_pt(s, 0.0, 0.0, 0.105), axis, edge, 0.036 * w_scale * s, 0.014 * w_scale * s, 0.0),
        diamond_blade_ring_godot(_weapon_pt(s, 0.0, 0.0, 0.265), axis, edge, 0.035 * w_scale * s, 0.013 * w_scale * s, 0.0),
    ]
    mb.add_loft(ric, mat_index=grip_m, weights=ww)
    for sy in (-1.0, 1.0):
        mb.add_loft(
            [
                tube_ring_godot(_weapon_pt(s, 0.0, sy * 0.028 * w_scale, 0.265), (0.0, sy, 0.7), 0.012 * s, 0.014 * s, 6),
                tube_ring_godot(_weapon_pt(s, 0.0, sy * 0.095 * w_scale, 0.335), (0.0, sy, 0.7), 0.003 * s, 0.004 * s, 6),
            ],
            mat_index=guard_m,
            weights=ww,
        )

    b_rings = []
    bn = 20
    for i in range(bn + 1):
        t = i / bn
        wz = 0.265 + (1.36 - 0.265) * t
        if t < 0.84:
            taper = 1.0 - 0.26 * (t / 0.84)
            notch = 1.0 - (0.28 if (cinder_m is not None and i in (5, 11, 15)) else 0.0)
            hw = 0.052 * w_scale * taper * notch
            ht = 0.016 * w_scale * (1.0 - 0.35 * t)
            fuller = 1.0 if t < 0.72 else 0.0
        else:
            pt = (t - 0.84) / 0.16
            hw = max(0.002, 0.052 * w_scale * 0.74 * (1.0 - pt ** 1.25))
            ht = max(0.0015, 0.0105 * w_scale * (1.0 - pt))
            fuller = 0.0
        b_rings.append(diamond_blade_ring_godot(_weapon_pt(s, 0.0, 0.0, wz), axis, edge, hw * s, ht * s, fuller))
    mb.add_loft(b_rings, mat_index=edge_m, weights=ww)

    if cinder_m is not None:
        f_rings = [
            diamond_blade_ring_godot(_weapon_pt(s, 0.0, 0.0, 0.30), axis, edge, 0.014 * w_scale * s, 0.010 * w_scale * s, 0.0),
            diamond_blade_ring_godot(_weapon_pt(s, 0.0, 0.0, 0.98), axis, edge, 0.010 * w_scale * s, 0.008 * w_scale * s, 0.0),
            diamond_blade_ring_godot(_weapon_pt(s, 0.0, 0.0, 1.12), axis, edge, 0.002 * w_scale * s, 0.002 * w_scale * s, 0.0),
        ]
        mb.add_loft(f_rings, mat_index=cinder_m, weights=ww)


def _add_cleaver(mb: RiggedMeshBuilder, s: float, iron_m: int, edge_m: int, grip_m: int) -> None:
    ww = {"weapon_r": 1.0}
    axis = (0.0, 0.0, 1.0)
    mb.add_loft([tube_ring_godot(_weapon_pt(s, 0.0, 0.0, wz), axis, 0.015 * s, 0.015 * s, 8) for wz in (-0.16, 0.09)], mat_index=grip_m, weights=ww)
    mb.add_beveled_box_godot(_weapon_pt(s, 0.0, 0.0, 0.10), (0.03 * s, 0.13 * s, 0.025 * s), mat_index=iron_m, weights=ww, bevel_width=0.004 * s)
    rows = 12
    c_rings = []
    for i in range(rows):
        t = i / (rows - 1)
        wz = 0.11 + 0.72 * t
        y_top = 0.018 * (1.0 - 0.4 * t)
        y_bot = -0.068 * (0.65 + 0.55 * math.sin(t * math.pi * 0.78))
        if i in (4, 8):
            y_bot += 0.022
        if i == rows - 1:
            y_bot = -0.004
            y_top = 0.004
        thick = 0.012 * (1.0 - 0.5 * t)
        pts = [
            godot_to_blender(*_weapon_pt(s, 0.0, y_top, wz)),
            godot_to_blender(*_weapon_pt(s, thick, (y_top + y_bot) * 0.4, wz)),
            godot_to_blender(*_weapon_pt(s, 0.002, y_bot, wz)),
            godot_to_blender(*_weapon_pt(s, -thick, (y_top + y_bot) * 0.4, wz)),
        ]
        c_rings.append(pts)
    mb.add_loft(c_rings, mat_index=edge_m, weights=ww)


def _add_brazier_staff(mb: RiggedMeshBuilder, s: float, iron_m: int, trim_m: int, grip_m: int, cinder_m: int) -> None:
    ww = {"weapon_r": 1.0}
    axis = (0.0, 0.0, 1.0)
    mb.add_loft([tube_ring_godot(_weapon_pt(s, 0.0, 0.0, wz), axis, 0.018 * s, 0.018 * s, 8) for wz in (-0.45, 0.96)], mat_index=iron_m, weights=ww)
    mb.add_loft([tube_ring_godot(_weapon_pt(s, 0.0, 0.0, wz), axis, 0.021 * s, 0.021 * s, 8) for wz in (-0.15, 0.10)], mat_index=grip_m, weights=ww)
    mb.add_loft([tube_ring_godot(_weapon_pt(s, 0.0, 0.0, wz), axis, 0.026 * s, 0.026 * s, 8) for wz in (0.93, 0.98)], mat_index=trim_m, weights=ww)
    crozier = []
    for i in range(15):
        a = -0.3 + 4.3 * (i / 14.0)
        qy = 0.05 + math.sin(a) * 0.14
        qz = 1.12 - math.cos(a) * 0.15
        rad = 0.016 * (1.0 - 0.55 * (i / 14.0))
        crozier.append(tube_ring_godot(_weapon_pt(s, 0.0, qy, qz), (0.0, math.cos(a), math.sin(a)), rad * s, rad * s, 6))
    mb.add_loft(crozier, mat_index=iron_m, weights=ww)
    c_prof = [(1.04, 0.005), (1.10, 0.052), (1.16, 0.048), (1.22, 0.005)]
    mb.add_loft([tube_ring_godot(_weapon_pt(s, 0.0, 0.02, wz), axis, r * s, r * s, 6) for (wz, r) in c_prof], mat_index=cinder_m, weights=ww)


def _add_halberd(mb: RiggedMeshBuilder, s: float, iron_m: int, edge_m: int, trim_m: int, grip_m: int) -> None:
    ww = {"weapon_r": 1.0}
    axis = (0.0, 0.0, 1.0)
    mb.add_loft([tube_ring_godot(_weapon_pt(s, 0.0, 0.0, wz), axis, 0.020 * s, 0.020 * s, 8) for wz in (-0.52, 1.08)], mat_index=grip_m, weights=ww)
    for wz in (1.05, 1.24):
        mb.add_loft([tube_ring_godot(_weapon_pt(s, 0.0, 0.0, wz + dz), axis, r * s, r * s, 8) for (dz, r) in [(-0.02, 0.024), (0.0, 0.030), (0.02, 0.024)]], mat_index=trim_m, weights=ww)
    mb.add_loft(
        [
            diamond_blade_ring_godot(_weapon_pt(s, 0.0, 0.0, 1.24), axis, (0.0, 1.0, 0.0), 0.030 * s, 0.018 * s, 0.2),
            diamond_blade_ring_godot(_weapon_pt(s, 0.0, 0.0, 1.65), axis, (0.0, 1.0, 0.0), 0.002 * s, 0.002 * s, 0.0),
        ],
        mat_index=edge_m,
        weights=ww,
    )
    axe_grid = []
    for c in range(7):
        u = c / 6.0
        z_bot = 1.04 - 0.14 * (u ** 1.2)
        z_top = 1.22 + 0.12 * (u ** 1.2)
        col = []
        for r in range(7):
            v = r / 6.0
            wz = z_bot + (z_top - z_bot) * v
            wy = 0.02 + 0.24 * u * (1.0 + 0.22 * ((2.0 * v - 1.0) ** 2))
            wx = 0.014 * (1.0 - 0.88 * (u ** 1.4)) + 0.002
            col.append(godot_to_blender(*_weapon_pt(s, wx, wy, wz)))
        axe_grid.append(col)
    mb.add_grid_sheet(axe_grid, mat_index=edge_m, row_weights=[ww] * 7, thickness=0.008 * s)
    mb.add_loft(
        [
            tube_ring_godot(_weapon_pt(s, 0.0, -0.02, 1.16), (0.0, -1.0, -0.3), 0.016 * s, 0.026 * s, 4),
            tube_ring_godot(_weapon_pt(s, 0.0, -0.22, 1.07), (0.0, -1.0, -0.4), 0.002 * s, 0.003 * s, 4),
        ],
        mat_index=iron_m,
        weights=ww,
    )


def build_oathbreaker_knight() -> str:
    reset_scene()
    s = 1.0
    arm = build_master_armature(scale=s, name="OathbreakerArmature")
    mat_list, m = _oathbreaker_mat_slots()
    mb = RiggedMeshBuilder("OathbreakerKnight", mat_list, arm)

    _add_torso_core(mb, s, 1.0, m["ArmorPlate"], m["ArmorUnder"], m["ArmorTrim"], m["WeaponGrip"])
    _add_pauldrons(mb, s, 1.0, "sovereign", m["ArmorPlate"], m["ArmorTrim"])
    _add_arms_and_gauntlets(mb, s, 1.0, m["ArmorPlate"], m["ArmorUnder"], m["ArmorTrim"], spiked_cuffs=True)
    _add_legs_tassets_tabard(mb, s, 1.0, m["ArmorPlate"], m["ArmorUnder"], m["ArmorTrim"], m["TabardCloth"], "layered", has_tabard=True)
    _add_tattered_cape(mb, s, m["CapeCloth"], w_top=0.25, w_bot=0.54, length_y=1.38, jagged=0.16, collar_scarf=True)
    _add_helm_barbute(mb, s, m["ArmorPlate"], m["ArmorTrim"], m["ArmorUnder"], m["HelmEye"])
    _add_plume(mb, s, m["ArmorTrim"], m["HelmPlume"])
    _add_waist_lantern(mb, s, m["WeaponGuard"], m["LanternCore"])
    _add_zweihander(mb, s, m["WeaponSteel"], m["WeaponSteel"], m["WeaponGuard"], m["WeaponGrip"], m["ArmorTrim"], w_scale=1.0)

    def _cloak_sway(co: Vector) -> float:
        gy = float(co.z)
        gz = float(-co.y)
        if gz > -0.10 or gy > 1.50:
            return 0.0
        return min(1.0, max(0.0, (1.50 - gy) / 1.35))

    mesh_obj = mb.finalize(smooth_angle_deg=44.0, sway_weight_fn=_cloak_sway)
    bake_master_animations(arm, scale=s, weapon_style="greatsword", weapon_len=1.36 * s)
    return export_kit_glb([arm, mesh_obj], "oathbreaker_knight.glb", rigged=True)


def build_ashen_thrall() -> str:
    reset_scene()
    mats = make_kit_materials()
    s = 1.72 / 1.95
    arm = build_master_armature(scale=s, name="AshenThrallArmature")
    mat_list, m = _mat_slots(mats)
    mb = RiggedMeshBuilder("AshenThrall", mat_list, arm)

    _add_torso_core(mb, s, 0.86, m["black_steel"], m["leather"], m["black_steel"], m["leather"])
    _add_pauldrons(mb, s, 0.86, "thrall", m["black_steel"], m["black_steel"])
    _add_arms_and_gauntlets(mb, s, 0.86, m["black_steel"], m["leather"], m["black_steel"], gaunt=True)
    _add_legs_tassets_tabard(mb, s, 0.86, m["black_steel"], m["leather"], m["black_steel"], m["ash_cloth"], "light", has_tabard=True, gaunt=True)
    _add_tattered_cape(mb, s, m["ash_cloth"], w_top=0.18, w_bot=0.34, length_y=1.05, jagged=0.22, collar_scarf=True)

    # Carved undead skull with dark recessed eye cavities & broad tilted kettle helm pulled low over brow.
    hw = {"head": 1.0}
    skull = [
        elliptical_ring_godot(0.0, 1.66 * s, 0.018 * s, 0.044 * s, 0.056 * s, 12, keel_front=0.022 * s),
        elliptical_ring_godot(0.0, 1.73 * s, 0.014 * s, 0.062 * s, 0.072 * s, 12, keel_front=0.012 * s, flute_amp=0.08, flute_freq=4),
        elliptical_ring_godot(0.0, 1.79 * s, 0.010 * s, 0.070 * s, 0.084 * s, 12, keel_front=0.018 * s),
        elliptical_ring_godot(0.0, 1.85 * s, 0.008 * s, 0.072 * s, 0.086 * s, 12),
    ]
    mb.add_loft(skull, mat_index=m["bone"], weights=hw)
    # Recessed nasal hollow + grim jaw shadow line so undead skull reads crisply.
    mb.add_loft(
        [
            elliptical_ring_godot(0.0, 1.69 * s, 0.068 * s, 0.032 * s, 0.012 * s, 8),
            elliptical_ring_godot(0.0, 1.71 * s, 0.070 * s, 0.034 * s, 0.012 * s, 8),
        ],
        mat_index=m["cloth"],
        weights=hw,
    )
    mb.add_loft(
        [
            elliptical_ring_godot(0.0, 1.735 * s, 0.080 * s, 0.011 * s, 0.012 * s, 6),
            elliptical_ring_godot(0.0, 1.762 * s, 0.084 * s, 0.006 * s, 0.010 * s, 6),
        ],
        mat_index=m["cloth"],
        weights=hw,
    )
    for sgn in (-1.0, 1.0):
        # Dark recessed orbital cavity + smoldering ember pupil.
        mb.add_loft(
            [
                elliptical_ring_godot(sgn * 0.028 * s, 1.755 * s, 0.078 * s, 0.018 * s, 0.014 * s, 8),
                elliptical_ring_godot(sgn * 0.028 * s, 1.785 * s, 0.082 * s, 0.018 * s, 0.014 * s, 8),
            ],
            mat_index=m["cloth"],
            weights=hw,
        )
        mb.add_loft(
            [
                elliptical_ring_godot(sgn * 0.028 * s, 1.768 * s, 0.090 * s, 0.009 * s, 0.007 * s, 6),
                elliptical_ring_godot(sgn * 0.028 * s, 1.780 * s, 0.092 * s, 0.009 * s, 0.007 * s, 6),
            ],
            mat_index=m["emit_cinder"],
            weights=hw,
        )
    kettle = [
        elliptical_ring_godot(0.0, 1.78 * s, 0.004 * s, 0.156 * s, 0.168 * s, 14, tilt_x=0.14),
        elliptical_ring_godot(0.0, 1.81 * s, 0.004 * s, 0.096 * s, 0.108 * s, 14, tilt_x=0.14),
        elliptical_ring_godot(0.0, 1.91 * s, 0.004 * s, 0.072 * s, 0.082 * s, 14, tilt_x=0.14),
        elliptical_ring_godot(0.0, 1.95 * s, 0.004 * s, 0.014 * s, 0.016 * s, 14, tilt_x=0.14),
    ]
    mb.add_loft(kettle, mat_index=m["black_steel"], weights=hw)
    _add_cleaver(mb, s, m["black_steel"], m["honed_steel"], m["leather"])

    mesh_obj = mb.finalize(smooth_angle_deg=44.0)
    bake_master_animations(arm, scale=s, weapon_style="cleaver", weapon_len=0.82 * s)
    return export_kit_glb([arm, mesh_obj], "ashen_thrall.glb", rigged=True)


def build_cinder_acolyte() -> str:
    reset_scene()
    mats = make_kit_materials()
    s = 1.82 / 1.95
    arm = build_master_armature(scale=s, name="CinderAcolyteArmature")
    mat_list, m = _mat_slots(mats)
    mb = RiggedMeshBuilder("CinderAcolyte", mat_list, arm)

    # Smooth crimson cultist cassock chest (no beveled grid facets!) + iron collar & leather straps.
    trunk_cassock = [
        (0.95, 0.145, 0.115, {"hips": 0.9, "spine": 0.1}),
        (1.10, 0.132, 0.106, {"spine": 0.7, "hips": 0.3}),
        (1.30, 0.162, 0.125, {"chest": 0.85, "spine": 0.15}),
        (1.50, 0.185, 0.132, {"chest": 0.95, "neck": 0.05}),
        (1.62, 0.088, 0.085, {"neck": 0.7, "chest": 0.3}),
    ]
    mb.add_loft(
        [elliptical_ring_godot(0.0, y * s, 0.0, rx * s, rz * s, 16, flute_amp=0.04, flute_freq=6) for (y, rx, rz, _) in trunk_cassock],
        mat_index=m["crimson_cloth"],
        weights=[w for (_, _, _, w) in trunk_cassock],
    )
    mb.add_loft(
        [
            elliptical_ring_godot(0.0, 1.54 * s, 0.01 * s, 0.142 * s, 0.120 * s, 14, keel_front=0.02 * s),
            elliptical_ring_godot(0.0, 1.62 * s, 0.01 * s, 0.104 * s, 0.094 * s, 14, keel_front=0.014 * s),
        ],
        mat_index=m["black_steel"],
        weights={"chest": 0.65, "neck": 0.35},
    )
    mb.add_loft(
        [
            elliptical_ring_godot(0.0, 1.04 * s, 0.0, 0.146 * s, 0.118 * s, 16),
            elliptical_ring_godot(0.0, 1.11 * s, 0.0, 0.144 * s, 0.116 * s, 16),
        ],
        mat_index=m["leather"],
        weights={"hips": 0.75, "spine": 0.25},
    )

    _add_pauldrons(mb, s, 0.90, "thrall", m["black_steel"], m["gold"], mantle_m=m["crimson_cloth"])
    _add_arms_and_gauntlets(mb, s, 0.90, m["black_steel"], m["crimson_cloth"], m["gold"], gaunt=True)
    _add_legs_tassets_tabard(mb, s, 0.90, m["black_steel"], m["cloth"], m["gold"], m["crimson_cloth"], "light", has_tabard=True, gaunt=True)
    _add_tattered_cape(mb, s, m["crimson_cloth"], w_top=0.24, w_bot=0.56, length_y=1.42, jagged=0.20, collar_scarf=True)

    # Forged iron funerary death-mask + tall pointed executioner's cowl hood.
    hw = {"head": 1.0}
    mask = [
        elliptical_ring_godot(0.0, 1.67 * s, 0.058 * s, 0.064 * s, 0.074 * s, 12, keel_front=0.024 * s),
        elliptical_ring_godot(0.0, 1.78 * s, 0.062 * s, 0.076 * s, 0.086 * s, 12, keel_front=0.026 * s),
        elliptical_ring_godot(0.0, 1.87 * s, 0.056 * s, 0.068 * s, 0.078 * s, 12, keel_front=0.014 * s),
    ]
    mb.add_loft(mask, mat_index=m["gunmetal"], weights=hw)
    mb.add_loft(
        [
            elliptical_ring_godot(0.0, 1.84 * s, 0.064 * s, 0.074 * s, 0.084 * s, 12),
            elliptical_ring_godot(0.0, 1.86 * s, 0.064 * s, 0.076 * s, 0.086 * s, 12),
        ],
        mat_index=m["gold"],
        weights=hw,
    )
    for sgn in (-1.0, 1.0):
        mb.add_loft(
            [
                elliptical_ring_godot(sgn * 0.028 * s, 1.785 * s, 0.144 * s, 0.012 * s, 0.006 * s, 6),
                elliptical_ring_godot(sgn * 0.028 * s, 1.797 * s, 0.146 * s, 0.012 * s, 0.006 * s, 6),
            ],
            mat_index=m["emit_cinder"],
            weights=hw,
        )
    cowl = [
        elliptical_ring_godot(0.0, 1.62 * s, -0.03 * s, 0.142 * s, 0.132 * s, 14),
        elliptical_ring_godot(0.0, 1.78 * s, -0.03 * s, 0.122 * s, 0.122 * s, 14),
        elliptical_ring_godot(0.0, 1.92 * s, -0.02 * s, 0.102 * s, 0.126 * s, 14, keel_front=0.055 * s),
        elliptical_ring_godot(0.0, 2.08 * s, -0.14 * s, 0.036 * s, 0.046 * s, 14),
        elliptical_ring_godot(0.0, 2.02 * s, -0.25 * s, 0.006 * s, 0.008 * s, 14),
    ]
    mb.add_loft(cowl, mat_index=m["crimson_cloth"], weights=hw)
    _add_brazier_staff(mb, s, m["black_steel"], m["gold"], m["leather"], m["emit_cinder"])

    mesh_obj = mb.finalize(smooth_angle_deg=48.0)
    bake_master_animations(arm, scale=s, weapon_style="staff", weapon_len=1.22 * s)
    return export_kit_glb([arm, mesh_obj], "cinder_acolyte.glb", rigged=True)


def build_barrow_halberdier() -> str:
    reset_scene()
    mats = make_kit_materials()
    s = 2.25 / 1.95
    arm = build_master_armature(scale=s, name="BarrowHalberdierArmature")
    mat_list, m = _mat_slots(mats)
    mb = RiggedMeshBuilder("BarrowHalberdier", mat_list, arm)

    _add_torso_core(mb, s, 1.15, m["gunmetal"], m["cloth"], m["gold"], m["leather"])
    _add_pauldrons(mb, s, 1.15, "halberdier", m["gunmetal"], m["gold"])
    _add_arms_and_gauntlets(mb, s, 1.15, m["gunmetal"], m["cloth"], m["gold"], spiked_cuffs=True)
    _add_legs_tassets_tabard(mb, s, 1.15, m["gunmetal"], m["cloth"], m["gold"], m["cloth"], "layered", has_tabard=True)
    _add_tattered_cape(mb, s, m["cloth"], w_top=0.28, w_bot=0.58, length_y=1.42, jagged=0.18, collar_scarf=True)
    _add_helm_barbute(mb, s, m["gunmetal"], m["gold"], m["black_steel"], m["emit_amber"], horned=True)
    _add_halberd(mb, s, m["black_steel"], m["honed_steel"], m["gold"], m["leather"])

    mesh_obj = mb.finalize(smooth_angle_deg=44.0)
    bake_master_animations(arm, scale=s, weapon_style="halberd", weapon_len=1.65 * s)
    return export_kit_glb([arm, mesh_obj], "barrow_halberdier.glb", rigged=True)


def build_ashen_warden_boss() -> str:
    reset_scene()
    mats = make_kit_materials()
    s = 3.15 / 1.95
    arm = build_master_armature(scale=s, name="AshenWardenArmature")
    mat_list, m = _mat_slots(mats)
    mb = RiggedMeshBuilder("AshenWardenBoss", mat_list, arm)

    _add_torso_core(mb, s, 1.18, m["black_steel"], m["crimson_cloth"], m["gold"], m["leather"], ember_m=m["emit_cinder"])
    _add_pauldrons(mb, s, 1.18, "boss_spiked", m["black_steel"], m["gold"], mantle_m=m["crimson_cloth"])
    _add_arms_and_gauntlets(mb, s, 1.18, m["black_steel"], m["crimson_cloth"], m["gold"], spiked_cuffs=True)
    _add_legs_tassets_tabard(mb, s, 1.18, m["black_steel"], m["crimson_cloth"], m["gold"], m["crimson_cloth"], "spiked", has_tabard=True)
    _add_tattered_cape(mb, s, m["crimson_cloth"], w_top=0.32, w_bot=0.72, length_y=1.46, jagged=0.24, collar_scarf=True)
    _add_helm_barbute(mb, s, m["black_steel"], m["gold"], m["black_steel"], m["emit_cinder"], crowned=True)
    _add_zweihander(mb, s, m["black_steel"], m["honed_steel"], m["black_steel"], m["leather"], m["gold"], cinder_m=m["emit_cinder"], w_scale=1.22)

    mesh_obj = mb.finalize(smooth_angle_deg=44.0)
    bake_master_animations(arm, scale=s, weapon_style="greatsword", weapon_len=1.36 * s)
    return export_kit_glb([arm, mesh_obj], "ashen_warden_boss.glb", rigged=True)


def build_all_characters() -> list[str]:
    return [
        build_oathbreaker_knight(),
        build_ashen_thrall(),
        build_cinder_acolyte(),
        build_barrow_halberdier(),
        build_ashen_warden_boss(),
    ]
