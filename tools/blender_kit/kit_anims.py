import math
import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

from .kit_common import godot_to_blender


def _gd_euler_quat(pitch_x_deg: float = 0.0, yaw_y_deg: float = 0.0, roll_z_deg: float = 0.0) -> Quaternion:
    # Build rotation in Godot anatomical space (+X left, +Y up, +Z front), then conjugate into Blender space.
    q_gd = Euler(
        (math.radians(pitch_x_deg), math.radians(yaw_y_deg), math.radians(roll_z_deg)),
        "YXZ",
    ).to_quaternion()
    # Since godot_to_blender is +90deg around X: axis_bl = godot_to_blender(axis_gd)
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


def _aim_bone_world(
    arm_obj: bpy.types.Object,
    bone_name: str,
    target_dir_gd: Vector,
    hint_axis_gd: Vector,
    align_axis: str = "Z",
) -> None:
    pb = arm_obj.pose.bones[bone_name]
    y_bl = godot_to_blender(target_dir_gd.x, target_dir_gd.y, target_dir_gd.z).normalized()
    h_bl = godot_to_blender(hint_axis_gd.x, hint_axis_gd.y, hint_axis_gd.z).normalized()
    if abs(y_bl.dot(h_bl)) > 0.98:
        h_bl = godot_to_blender(1.0, 0.0, 0.0)
    if align_axis == "Z":
        x_bl = y_bl.cross(h_bl).normalized()
        z_bl = x_bl.cross(y_bl).normalized()
    else:
        z_bl = h_bl.cross(y_bl).normalized()
        x_bl = y_bl.cross(z_bl).normalized()

    m_target = Matrix((x_bl, y_bl, z_bl)).transposed()
    m_parent_posed = pb.parent.matrix.to_3x3() if pb.parent is not None else Matrix.Identity(3)
    if pb.parent is not None:
        m_rest_local = pb.parent.bone.matrix_local.to_3x3().inverted() @ pb.bone.matrix_local.to_3x3()
    else:
        m_rest_local = pb.bone.matrix_local.to_3x3()
    m_basis = (m_parent_posed @ m_rest_local).inverted() @ m_target
    pb.rotation_quaternion = m_basis.to_quaternion()


def _solve_leg_ik(
    arm_obj: bpy.types.Object,
    side: str,
    scale: float,
    ankle_target_gd: Vector,
    foot_fwd_gd: Vector,
    knee_out_bias: float = 0.08,
) -> None:
    thigh_name = f"thigh_{side}"
    shin_name = f"shin_{side}"
    foot_name = f"foot_{side}"

    bpy.context.view_layer.update()
    pb_thigh = arm_obj.pose.bones[thigh_name]
    pb_shin = arm_obj.pose.bones[shin_name]
    hip_bl = pb_thigh.head
    hip_gd = Vector((hip_bl.x, hip_bl.z, -hip_bl.y))

    l1 = (pb_thigh.bone.tail_local - pb_thigh.bone.head_local).length
    l2 = (pb_shin.bone.tail_local - pb_shin.bone.head_local).length

    to_ankle = ankle_target_gd - hip_gd
    dist = to_ankle.length
    max_reach = (l1 + l2) * 0.992
    min_reach = abs(l1 - l2) + 0.05 * scale
    if dist > max_reach:
        to_ankle = to_ankle.normalized() * max_reach
        dist = max_reach
    elif dist < min_reach:
        to_ankle = to_ankle.normalized() * min_reach
        dist = min_reach

    dir_norm = to_ankle.normalized()
    side_sign = 1.0 if side == "l" else -1.0
    fwd_flat = Vector((foot_fwd_gd.x, 0.0, foot_fwd_gd.z))
    if fwd_flat.length < 1e-4:
        fwd_flat = Vector((0.0, 0.0, 1.0))
    fwd_flat.normalize()
    left_flat = Vector((0.0, 1.0, 0.0)).cross(fwd_flat).normalized()
    knee_hint = (fwd_flat + left_flat * (side_sign * knee_out_bias) + Vector((0.0, 0.15, 0.0))).normalized()
    ortho = (knee_hint - dir_norm * knee_hint.dot(dir_norm))
    if ortho.length < 1e-4:
        ortho = fwd_flat
    ortho.normalize()

    cos_a = max(-1.0, min(1.0, (l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist)))
    sin_a = math.sqrt(max(0.0, 1.0 - cos_a * cos_a))
    knee_gd = hip_gd + dir_norm * (l1 * cos_a) + ortho * (l1 * sin_a)
    actual_ankle_gd = hip_gd + to_ankle

    _aim_bone_world(arm_obj, thigh_name, knee_gd - hip_gd, left_flat * side_sign, "X")
    bpy.context.view_layer.update()
    _aim_bone_world(arm_obj, shin_name, actual_ankle_gd - knee_gd, left_flat * side_sign, "X")
    bpy.context.view_layer.update()

    f_dir = Vector((foot_fwd_gd.x, foot_fwd_gd.y, foot_fwd_gd.z)).normalized()
    _aim_bone_world(arm_obj, foot_name, f_dir, Vector((0.0, 1.0, 0.0)), "Z")


def _aim_weapon_tip_to_y(
    arm_obj: bpy.types.Object,
    scale: float,
    weapon_len: float,
    desired_dir_gd: Vector,
    target_tip_y_gd: float | None = None,
) -> None:
    bpy.context.view_layer.update()
    pb_w = arm_obj.pose.bones["weapon_r"]
    hand_bl = pb_w.head
    hand_gd = Vector((hand_bl.x, hand_bl.z, -hand_bl.y))
    d = desired_dir_gd.normalized()

    if target_tip_y_gd is not None and weapon_len > 0.05:
        dy_needed = (target_tip_y_gd - hand_gd.y) / weapon_len
        dy_clamped = max(-0.94, min(0.94, dy_needed))
        horiz = Vector((d.x, 0.0, d.z))
        if horiz.length < 1e-4:
            horiz = Vector((-0.35, 0.0, -0.94))
        horiz.normalize()
        horiz_scale = math.sqrt(max(0.01, 1.0 - dy_clamped * dy_clamped))
        d = Vector((horiz.x * horiz_scale, dy_clamped, horiz.z * horiz_scale)).normalized()

    _aim_bone_world(arm_obj, "weapon_r", d, Vector((0.0, 1.0, 0.0)), "Z")


def _reset_pose(arm_obj: bpy.types.Object) -> None:
    for pb in arm_obj.pose.bones:
        pb.location = (0.0, 0.0, 0.0)
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)


def _key_all_bones(arm_obj: bpy.types.Object, frame: int) -> None:
    for pb in arm_obj.pose.bones:
        if pb.name in ("root", "hips"):
            pb.keyframe_insert(data_path="location", frame=frame)
        pb.keyframe_insert(data_path="rotation_quaternion", frame=frame)


def _set_hips_offset_gd(arm_obj: bpy.types.Object, scale: float, dx: float, dy: float, dz: float) -> None:
    pb = arm_obj.pose.bones["hips"]
    q_rest = pb.bone.matrix_local.to_3x3().to_quaternion()
    v_bl = godot_to_blender(dx * scale, dy * scale, dz * scale)
    pb.location = q_rest.inverted() @ v_bl


def _apply_pose_sample(
    arm_obj: bpy.types.Object,
    clip: str,
    u: float,
    scale: float,
    weapon_style: str,
    weapon_len: float,
) -> None:
    _reset_pose(arm_obj)
    tau = 2.0 * math.pi

    # Default upright combat guard values; every clip overrides explicitly.
    hips_off = (0.0, -0.075, 0.0)
    hips_rot = (4.0, -14.0, 0.0)
    spine_rot = (6.0, 10.0, 0.0)
    chest_rot = (8.0, 14.0, 0.0)
    neck_rot = (-6.0, -8.0, 0.0)
    head_rot = (-4.0, -8.0, 0.0)

    sh_l = (0.0, 10.0, 4.0)
    ua_l = (-28.0, 12.0, 20.0)
    fa_l = (-48.0, 0.0, -8.0)
    hd_l = (0.0, -15.0, 0.0)

    sh_r = (0.0, -10.0, -4.0)
    ua_r = (14.0, -10.0, -24.0)
    fa_r = (-18.0, 0.0, 4.0)
    hd_r = (8.0, 0.0, 0.0)

    cape0 = (10.0, 0.0, 0.0)
    cape1 = (6.0, 0.0, 0.0)
    cape2 = (4.0, 0.0, 0.0)
    lantern_rot = (6.0, 0.0, 6.0)

    foot_l = Vector((0.18, 0.10, 0.22)) * scale
    foot_r = Vector((-0.20, 0.10, -0.18)) * scale
    foot_fwd_l = Vector((0.15, 0.0, 1.0))
    foot_fwd_r = Vector((-0.22, 0.0, 0.95))

    weapon_dir = Vector((-0.30, -0.60, -0.74))
    weapon_tip_y: float | None = None
    if weapon_style in ("staff", "halberd"):
        weapon_dir = Vector((-0.24, 0.56, 0.78))

    if clip == "idle":
        br = math.sin(u * tau)
        br2 = math.sin(u * tau - 0.7)
        hips_off = (0.0, -0.075 + 0.012 * br, 0.0)
        hips_rot = (4.0, -16.0, 0.0)
        spine_rot = (5.0 + 1.5 * br, 8.0, 0.0)
        chest_rot = (7.0 + 2.2 * br, 16.0, 0.0)
        head_rot = (-5.0 - 2.0 * br, -10.0, 0.0)

        ua_l = (-12.0 - 2.0 * br, 2.0, -2.0 - 1.5 * br)
        fa_l = (-26.0 + 3.0 * br, -8.0, -8.0)
        hd_l = (0.0, -6.0, 0.0)
        ua_r = (-6.0 + 2.0 * br, -8.0, -10.0 - 1.5 * br)
        fa_r = (-22.0 + 2.5 * br, 0.0, 2.0)
        hd_r = (44.0, -20.0, 0.0)
        foot_fwd_l = Vector((0.15, -0.462, 1.0))
        foot_fwd_r = Vector((-0.22, -0.446, 0.95))

        cape0 = (12.0 + 3.5 * br2, 0.0, 2.0 * math.cos(u * tau))
        cape1 = (7.0 + 4.5 * math.sin(u * tau - 1.4), 0.0, 3.0 * math.cos(u * tau - 0.8))
        cape2 = (5.0 + 5.5 * math.sin(u * tau - 2.2), 0.0, 3.5 * math.cos(u * tau - 1.6))
        lantern_rot = (6.0 + 2.0 * br2, 0.0, 6.0 + 2.5 * math.cos(u * tau))

        if weapon_style == "greatsword":
            weapon_dir = Vector((-0.44, -0.76, 0.46))
            weapon_tip_y = (0.14 + 0.02 * br) * scale
        elif weapon_style == "cleaver":
            weapon_dir = Vector((-0.56, -0.64, 0.52))
            weapon_tip_y = (0.24 + 0.02 * br) * scale
        elif weapon_style == "staff":
            ua_r = (-24.0 + 2.0 * br, -8.0, -22.0)
            fa_r = (-46.0 + 3.0 * br, 0.0, 4.0)
            hd_r = (8.0, 0.0, 0.0)
            weapon_dir = Vector((-0.26, 0.72, 0.64))
        elif weapon_style == "halberd":
            ua_r = (-18.0 + 2.0 * br, -10.0, -24.0)
            fa_r = (-44.0 + 3.0 * br, 0.0, 4.0)
            hd_r = (8.0, 0.0, 0.0)
            weapon_dir = Vector((-0.22, 0.78, 0.58))

    elif clip == "run":
        ph = u * tau
        s = math.sin(ph)
        c = math.cos(ph)
        bob = abs(math.sin(ph))
        hips_off = (0.02 * s, -0.11 + 0.045 * (1.0 - bob), 0.04)
        hips_rot = (10.0, -10.0 * s - 8.0, -3.0 * s)
        spine_rot = (12.0, 6.0 * s, 0.0)
        chest_rot = (14.0, 14.0 * s + 10.0, 2.0 * s)
        neck_rot = (-12.0, -6.0 * s, 0.0)
        head_rot = (-12.0, -6.0 * s, 0.0)

        ua_l = (-25.0 - 38.0 * s, 10.0, 20.0)
        fa_l = (-68.0 - 14.0 * s, 0.0, -10.0)

        if weapon_style in ("greatsword", "cleaver"):
            ua_r = (36.0 + 5.0 * c, -16.0, -28.0)
            fa_r = (-10.0, 0.0, 4.0)
            weapon_dir = Vector((-0.26, -0.52, -0.81))
            weapon_tip_y = 0.04 * scale
        elif weapon_style == "staff":
            ua_r = (20.0 + 18.0 * s, -12.0, -24.0)
            fa_r = (-38.0, 0.0, 4.0)
            weapon_dir = Vector((-0.28, 0.50, 0.82))
        else:
            ua_r = (26.0 + 10.0 * c, -14.0, -26.0)
            fa_r = (-32.0, 0.0, 4.0)
            weapon_dir = Vector((-0.26, 0.58, 0.77))

        stride_z = 0.44
        lift_l = max(0.0, math.sin(ph)) * 0.22
        lift_r = max(0.0, -math.sin(ph)) * 0.22
        z_l = math.cos(ph) * stride_z
        z_r = -math.cos(ph) * stride_z
        foot_l = Vector((0.14, 0.10 + lift_l, z_l)) * scale
        foot_r = Vector((-0.14, 0.10 + lift_r, z_r)) * scale
        foot_fwd_l = Vector((0.0, -0.35 * max(0.0, -math.sin(ph)), 1.0))
        foot_fwd_r = Vector((0.0, -0.35 * max(0.0, math.sin(ph)), 1.0))

        cape0 = (32.0 + 6.0 * c, 0.0, 4.0 * s)
        cape1 = (18.0 + 8.0 * math.sin(ph - 0.8), 0.0, 6.0 * math.cos(ph - 0.6))
        cape2 = (12.0 + 10.0 * math.sin(ph - 1.6), 0.0, 8.0 * math.cos(ph - 1.2))
        lantern_rot = (18.0 + 8.0 * c, 0.0, 10.0 * s)

    elif clip == "attack_1":
        # Wide right-to-left horizontal/diagonal cleave (0.55s).
        if u < 0.28:
            t = u / 0.28
            ease = t * t * (3.0 - 2.0 * t)
            hips_off = (-0.03 * ease, -0.09 - 0.03 * ease, -0.04 * ease)
            hips_rot = (6.0, -16.0 - 30.0 * ease, 0.0)
            chest_rot = (6.0, 14.0 - 56.0 * ease, -8.0 * ease)
            head_rot = (-4.0, 32.0 * ease, 0.0)
            ua_l = (-35.0 - 15.0 * ease, 25.0, 26.0)
            fa_l = (-65.0, 0.0, -12.0)
            ua_r = (-20.0 * ease, -42.0 * ease, -78.0 * ease - 18.0)
            fa_r = (-28.0, 0.0, 0.0)
            weapon_dir = Vector((-0.82, 0.38 * ease - 0.10, -0.35 + 0.15 * ease))
        elif u < 0.64:
            t = (u - 0.28) / 0.36
            ease = 1.0 - (1.0 - t) ** 3
            hips_off = (-0.03 + 0.07 * ease, -0.12, -0.04 + 0.14 * ease)
            hips_rot = (8.0 + 6.0 * ease, -46.0 + 82.0 * ease, 0.0)
            chest_rot = (14.0, -42.0 + 96.0 * ease, 8.0 * ease)
            head_rot = (-8.0, -28.0 * ease, 0.0)
            ua_l = (-50.0 + 55.0 * ease, -10.0, 32.0)
            fa_l = (-50.0, 0.0, -10.0)
            # Swing right arm straight out & across front at shoulder/chest height!
            az = math.radians(-105.0 + 185.0 * ease)
            arm_dir = Vector((math.sin(az), -0.04 + 0.10 * math.sin(t * math.pi), math.cos(az))).normalized()
            _aim_bone_world(arm_obj, "upper_arm_r", arm_dir, Vector((0.0, 1.0, 0.0)), "Z")
            ua_r = None
            fa_r = (-10.0, 0.0, 0.0)
            weapon_dir = Vector((math.sin(az + 0.35), 0.10 * math.sin(t * math.pi) - 0.06, math.cos(az + 0.35))).normalized()
        else:
            t = (u - 0.64) / 0.36
            ease = t * t * (3.0 - 2.0 * t)
            hips_off = (0.04 * (1.0 - ease), -0.12 + 0.045 * ease, 0.10 * (1.0 - ease))
            hips_rot = (14.0 - 10.0 * ease, 36.0 - 52.0 * ease, 0.0)
            chest_rot = (14.0 - 7.0 * ease, 54.0 - 38.0 * ease, 8.0 * (1.0 - ease))
            head_rot = (-8.0 + 3.0 * ease, -28.0 + 18.0 * ease, 0.0)
            ua_l = (5.0 - 37.0 * ease, 10.0, 22.0)
            fa_l = (-52.0, 0.0, -10.0)
            ua_r = (-76.0 + 92.0 * ease, 55.0 - 69.0 * ease, 12.0 - 38.0 * ease)
            fa_r = (-10.0 - 10.0 * ease, 0.0, 4.0)
            if weapon_style in ("greatsword", "cleaver"):
                weapon_dir = Vector((0.72 * (1.0 - ease) - 0.32 * ease, -0.10 - 0.48 * ease, 0.62 * (1.0 - ease) - 0.75 * ease))
            else:
                weapon_dir = Vector((0.35 * (1.0 - ease) - 0.25 * ease, 0.30 + 0.42 * ease, 0.60))

        foot_l = Vector((0.20, 0.10, 0.28)) * scale
        foot_r = Vector((-0.22, 0.10, -0.24)) * scale
        cape0 = (24.0, -24.0 * math.sin(u * math.pi), 8.0)
        cape1 = (14.0, -16.0 * math.sin(u * math.pi), 6.0)
        cape2 = (10.0, -10.0 * math.sin(u * math.pi), 4.0)

    elif clip == "attack_2":
        # Sweeping left-to-right reverse slash chaining from attack_1.
        if u < 0.26:
            t = u / 0.26
            ease = t * t * (3.0 - 2.0 * t)
            hips_off = (0.04 * ease, -0.11, 0.06 * ease)
            hips_rot = (8.0, 32.0 * ease, 0.0)
            chest_rot = (12.0, 46.0 * ease, 5.0 * ease)
            head_rot = (-6.0, -22.0 * ease, 0.0)
            ua_l = (-10.0, -10.0, 28.0)
            fa_l = (-48.0, 0.0, -8.0)
            ua_r = (-46.0, 58.0 * ease, 14.0 * ease - 10.0)
            fa_r = (-18.0, 0.0, 0.0)
            weapon_dir = Vector((0.72, -0.38, 0.45))
        elif u < 0.62:
            t = (u - 0.26) / 0.36
            ease = 1.0 - (1.0 - t) ** 3
            hips_off = (0.04 - 0.06 * ease, -0.11, 0.06 + 0.06 * ease)
            hips_rot = (8.0, 32.0 - 72.0 * ease, 0.0)
            chest_rot = (10.0, 46.0 - 92.0 * ease, -6.0 * ease)
            head_rot = (-5.0, 24.0 * ease, 0.0)
            ua_l = (-10.0 - 32.0 * ease, 20.0, 24.0)
            fa_l = (-58.0, 0.0, -8.0)
            ua_r = (-46.0 - 14.0 * ease, 58.0 - 118.0 * ease, 4.0 - 66.0 * ease)
            fa_r = (-10.0, 0.0, 0.0)
            az = math.radians(75.0 - 185.0 * ease)
            arm_dir = Vector((math.sin(az), -0.05 + 0.32 * ease, math.cos(az))).normalized()
            weapon_dir = (arm_dir + Vector((0.0, 0.12 * ease, 0.15))).normalized()
        else:
            t = (u - 0.62) / 0.38
            ease = t * t * (3.0 - 2.0 * t)
            hips_off = (-0.02 * (1.0 - ease), -0.11 + 0.035 * ease, 0.12 * (1.0 - ease))
            hips_rot = (8.0 - 4.0 * ease, -40.0 + 24.0 * ease, 0.0)
            chest_rot = (10.0 - 3.0 * ease, -46.0 + 62.0 * ease, -6.0 * (1.0 - ease))
            head_rot = (-5.0, 24.0 - 34.0 * ease, 0.0)
            ua_l = (-42.0 + 10.0 * ease, 16.0, 22.0)
            fa_l = (-54.0, 0.0, -10.0)
            ua_r = (-60.0 + 76.0 * ease, -60.0 + 46.0 * ease, -62.0 + 36.0 * ease)
            fa_r = (-10.0 - 10.0 * ease, 0.0, 4.0)
            if weapon_style in ("greatsword", "cleaver"):
                weapon_dir = Vector((-0.78 * (1.0 - ease) - 0.32 * ease, 0.20 * (1.0 - ease) - 0.58 * ease, -0.35 - 0.40 * ease))
            else:
                weapon_dir = Vector((-0.55 * (1.0 - ease) - 0.25 * ease, 0.55, 0.55))

        foot_l = Vector((0.20, 0.10, 0.24)) * scale
        foot_r = Vector((-0.22, 0.10, -0.22)) * scale
        cape0 = (24.0, 22.0 * math.sin(u * math.pi), -6.0)
        cape1 = (14.0, 14.0 * math.sin(u * math.pi), -4.0)
        cape2 = (10.0, 10.0 * math.sin(u * math.pi), 0.0)

    elif clip == "attack_whirl":
        # Full 360deg crouched spin.
        spin_deg = -360.0 * u
        _set_anat_rot(arm_obj, "root", 0.0, spin_deg, 0.0)
        hips_off = (0.0, -0.15, 0.0)
        hips_rot = (10.0, -18.0, 0.0)
        spine_rot = (10.0, -10.0, 0.0)
        chest_rot = (12.0, -16.0, -6.0)
        head_rot = (-12.0, 28.0, 0.0)
        ua_l = (-20.0, 20.0, 42.0)
        fa_l = (-48.0, 0.0, -10.0)
        ua_r = (-18.0, -20.0, -78.0)
        fa_r = (-8.0, 0.0, 0.0)
        weapon_dir = Vector((-0.94, -0.14, 0.28))
        foot_l = Vector((0.24, 0.10, 0.18)) * scale
        foot_r = Vector((-0.24, 0.10, -0.18)) * scale
        cape0 = (40.0, 26.0, 0.0)
        cape1 = (24.0, 20.0, 0.0)
        cape2 = (16.0, 16.0, 0.0)

    elif clip == "skill_slam":
        # Overhead raise + crushing downward slam into the stone!
        if u < 0.40:
            t = u / 0.40
            ease = t * t * (3.0 - 2.0 * t)
            hips_off = (0.0, -0.05 + 0.04 * ease, -0.05 * ease)
            hips_rot = (-6.0 * ease, -8.0, 0.0)
            spine_rot = (-10.0 * ease, 4.0, 0.0)
            chest_rot = (-14.0 * ease, 8.0, 0.0)
            head_rot = (12.0 * ease, -6.0, 0.0)
            ua_l = (-32.0 - 115.0 * ease, 14.0 * (1.0 - ease), 18.0 * (1.0 - ease))
            fa_l = (-40.0 + 18.0 * ease, 0.0, -18.0 * ease)
            ua_r = (16.0 - 165.0 * ease, -14.0 * (1.0 - ease), -26.0 + 18.0 * ease)
            fa_r = (-24.0, 0.0, 10.0 * ease)
            weapon_dir = Vector((-0.12, 0.65 * ease - 0.15, -0.74))
        elif u < 0.64:
            t = (u - 0.40) / 0.24
            ease = t * t * t
            hips_off = (0.0, -0.01 - 0.18 * ease, -0.05 + 0.18 * ease)
            hips_rot = (-6.0 + 26.0 * ease, -8.0, 0.0)
            spine_rot = (-10.0 + 30.0 * ease, 4.0, 0.0)
            chest_rot = (-14.0 + 36.0 * ease, 8.0, 0.0)
            head_rot = (12.0 - 28.0 * ease, -6.0, 0.0)
            ua_l = (-147.0 + 95.0 * ease, 0.0, 12.0 * ease)
            fa_l = (-22.0, 0.0, -12.0)
            ua_r = (-149.0 + 98.0 * ease, 0.0, -12.0 * ease)
            fa_r = (-16.0, 0.0, 8.0)
            weapon_dir = Vector((-0.06, -0.52 * ease + 0.35 * (1.0 - ease), 0.85))
            if ease > 0.7:
                weapon_tip_y = 0.03 * scale
        else:
            t = (u - 0.64) / 0.36
            ease = t * t * (3.0 - 2.0 * t)
            hips_off = (0.0, -0.19 + 0.115 * ease, 0.13 * (1.0 - ease))
            hips_rot = (20.0 - 16.0 * ease, -8.0 - 8.0 * ease, 0.0)
            spine_rot = (20.0 - 15.0 * ease, 4.0 + 4.0 * ease, 0.0)
            chest_rot = (22.0 - 15.0 * ease, 8.0 + 8.0 * ease, 0.0)
            head_rot = (-16.0 + 11.0 * ease, -6.0 - 4.0 * ease, 0.0)
            ua_l = (-52.0 + 20.0 * ease, 16.0 * ease, 22.0 * ease)
            fa_l = (-22.0 - 32.0 * ease, 0.0, -10.0)
            ua_r = (-51.0 + 67.0 * ease, -14.0 * ease, -12.0 - 14.0 * ease)
            fa_r = (-16.0 - 4.0 * ease, 0.0, 4.0)
            if weapon_style in ("greatsword", "cleaver"):
                weapon_dir = Vector((-0.06 - 0.26 * ease, -0.52 - 0.06 * ease, 0.85 * (1.0 - ease) - 0.75 * ease))
            else:
                weapon_dir = Vector((-0.10 - 0.15 * ease, -0.25 + 0.90 * ease, 0.75))

        foot_l = Vector((0.20, 0.10, 0.30)) * scale
        foot_r = Vector((-0.20, 0.10, -0.26)) * scale
        cape0 = (26.0, 0.0, 0.0)
        cape1 = (18.0, 0.0, 0.0)
        cape2 = (12.0, 0.0, 0.0)

    elif clip == "skill_cast":
        # Raised left gauntlet summoning Stormbrand lightning / caster spell bolt!
        rise = math.sin(min(1.0, u / 0.45) * (math.pi * 0.5)) if u < 0.70 else 1.0 - ((u - 0.70) / 0.30)
        hips_off = (0.0, -0.06 + 0.03 * rise, 0.0)
        hips_rot = (2.0, -24.0 * rise, 0.0)
        spine_rot = (-4.0 * rise, 12.0 * rise, 0.0)
        chest_rot = (-10.0 * rise, 22.0 * rise, -6.0 * rise)
        head_rot = (-14.0 * rise, -18.0 * rise, 0.0)
        ua_l = (-32.0 - 118.0 * rise, 10.0, 26.0 * rise + 18.0)
        fa_l = (-54.0 + 42.0 * rise, 0.0, -6.0)
        hd_l = (-25.0 * rise, 0.0, 0.0)
        if weapon_style == "staff":
            ua_r = (-20.0 - 70.0 * rise, -12.0, -26.0)
            fa_r = (-46.0 + 28.0 * rise, 0.0, 4.0)
            weapon_dir = Vector((-0.24, 0.76 + 0.16 * rise, 0.58))
        else:
            ua_r = (22.0 * rise + 14.0, -14.0, -30.0)
            fa_r = (-18.0, 0.0, 4.0)
            weapon_dir = Vector((-0.34, -0.58, -0.74))
        cape0 = (22.0 * rise + 10.0, 0.0, 0.0)
        cape1 = (16.0 * rise + 6.0, 0.0, 0.0)

    elif clip == "dash":
        lunge = math.sin(min(1.0, u * 1.15) * math.pi)
        hips_off = (0.0, -0.18 * lunge - 0.06, 0.08 * lunge)
        hips_rot = (18.0 * lunge + 4.0, -14.0, 0.0)
        spine_rot = (18.0 * lunge + 6.0, 8.0, 0.0)
        chest_rot = (22.0 * lunge + 8.0, 12.0, 0.0)
        head_rot = (-28.0 * lunge - 4.0, -10.0, 0.0)
        ua_l = (-20.0 - 28.0 * lunge, 14.0, 24.0)
        fa_l = (-70.0, 0.0, -10.0)
        ua_r = (42.0 * lunge + 16.0, -14.0, -30.0)
        fa_r = (-12.0, 0.0, 4.0)
        if weapon_style in ("greatsword", "cleaver"):
            weapon_dir = Vector((-0.30, -0.45, -0.84))
            weapon_tip_y = 0.08 * scale
        else:
            weapon_dir = Vector((-0.28, 0.35, 0.88))
        foot_l = Vector((0.18, 0.10, 0.36 * lunge + 0.18)) * scale
        foot_r = Vector((-0.18, 0.10 + 0.10 * lunge, -0.34 * lunge - 0.14)) * scale
        cape0 = (48.0 * lunge + 14.0, 0.0, 0.0)
        cape1 = (30.0 * lunge + 8.0, 0.0, 0.0)
        cape2 = (22.0 * lunge + 6.0, 0.0, 0.0)

    elif clip == "hit":
        snap = math.sin(min(1.0, u * 1.25) * math.pi)
        hips_off = (0.0, -0.075 - 0.03 * snap, -0.05 * snap)
        hips_rot = (-6.0 * snap + 4.0, -14.0, 0.0)
        spine_rot = (-14.0 * snap + 4.0, 6.0, 0.0)
        chest_rot = (-18.0 * snap + 6.0, 8.0, 0.0)
        head_rot = (-20.0 * snap, -8.0, 0.0)
        ua_l = (-32.0 - 20.0 * snap, 12.0, 36.0 * snap + 22.0)
        ua_r = (16.0 + 18.0 * snap, -14.0, -40.0 * snap - 26.0)
        cape0 = (10.0 - 8.0 * snap, 0.0, 0.0)

    elif clip == "death":
        # Heavy knee drop -> collapse forward onto the stone (Y >= 0).
        if u < 0.42:
            t = u / 0.42
            ease = t * t * (3.0 - 2.0 * t)
            hips_off = (0.0, -0.075 - 0.40 * ease, -0.04 * ease)
            hips_rot = (10.0 * ease + 4.0, -10.0 * (1.0 - ease), 0.0)
            spine_rot = (16.0 * ease + 5.0, 0.0, 0.0)
            chest_rot = (20.0 * ease + 6.0, 0.0, 0.0)
            head_rot = (22.0 * ease, 0.0, 0.0)
            ua_l = (-25.0 + 15.0 * ease, 10.0, 22.0)
            ua_r = (16.0 + 12.0 * ease, -10.0, -28.0)
            foot_l = Vector((0.17, 0.10, 0.06)) * scale
            foot_r = Vector((-0.17, 0.10, -0.08)) * scale
            cape0 = (16.0 + 14.0 * ease, 0.0, 0.0)
            cape1 = (12.0, 0.0, 0.0)
            cape2 = (8.0, 0.0, 0.0)
        else:
            t = min(1.0, max(0.0, (u - 0.42) / 0.58))
            ease = 1.0 - max(0.0, 1.0 - t) ** 2.5
            hips_off = (0.0, -0.475 - 0.365 * ease, -0.04 + 0.16 * ease)
            hips_rot = (14.0 + 62.0 * ease, 0.0, 0.0)
            spine_rot = (21.0 - 8.0 * ease, 0.0, 0.0)
            chest_rot = (26.0 - 12.0 * ease, 0.0, 0.0)
            head_rot = (22.0 - 18.0 * ease, 14.0 * ease, 0.0)
            ua_l = (-10.0 - 45.0 * ease, 10.0, 38.0 * ease + 22.0)
            fa_l = (-35.0, 0.0, -8.0)
            ua_r = (28.0 - 65.0 * ease, -14.0, -42.0 * ease - 26.0)
            fa_r = (-18.0, 0.0, 4.0)
            weapon_dir = Vector((-0.55, 0.02, 0.83))
            foot_l = Vector((0.17, 0.08, -0.18 * ease)) * scale
            foot_r = Vector((-0.17, 0.08, -0.22 * ease)) * scale
            cape0 = (30.0 - 22.0 * ease, 0.0, 0.0)
            cape1 = (12.0 - 8.0 * ease, 0.0, 0.0)
            cape2 = (8.0 - 6.0 * ease, 0.0, 0.0)

    _set_hips_offset_gd(arm_obj, scale, *hips_off)
    _set_anat_rot(arm_obj, "hips", *hips_rot)
    _set_anat_rot(arm_obj, "spine", *spine_rot)
    _set_anat_rot(arm_obj, "chest", *chest_rot)
    _set_anat_rot(arm_obj, "neck", *neck_rot)
    _set_anat_rot(arm_obj, "head", *head_rot)

    _set_anat_rot(arm_obj, "shoulder_l", *sh_l)
    _set_anat_rot(arm_obj, "upper_arm_l", *ua_l)
    _set_anat_rot(arm_obj, "forearm_l", *fa_l)
    _set_anat_rot(arm_obj, "hand_l", *hd_l)

    _set_anat_rot(arm_obj, "shoulder_r", *sh_r)
    if ua_r is not None:
        _set_anat_rot(arm_obj, "upper_arm_r", *ua_r)
    else:
        # Aim upper_arm_r in world space during mid-cleave so arm stays level across chest!
        bpy.context.view_layer.update()
        _aim_bone_world(arm_obj, "upper_arm_r", arm_dir, Vector((0.0, 1.0, 0.0)), "Z")
    _set_anat_rot(arm_obj, "forearm_r", *fa_r)
    _set_anat_rot(arm_obj, "hand_r", *hd_r)

    _set_anat_rot(arm_obj, "cape_0", *cape0)
    _set_anat_rot(arm_obj, "cape_1", *cape1)
    _set_anat_rot(arm_obj, "cape_2", *cape2)
    _set_anat_rot(arm_obj, "lantern_bone", *lantern_rot)

    if clip == "attack_whirl":
        # Rotate leg targets and weapon_dir with root spin yaw so the crouched knight spins cleanly as a unit.
        spin_rad = math.radians(-360.0 * u)
        cs, sn = math.cos(spin_rad), math.sin(spin_rad)

        def _rot_y(v: Vector) -> Vector:
            return Vector((v.x * cs + v.z * sn, v.y, -v.x * sn + v.z * cs))

        foot_l = _rot_y(foot_l)
        foot_r = _rot_y(foot_r)
        foot_fwd_l = _rot_y(foot_fwd_l)
        foot_fwd_r = _rot_y(foot_fwd_r)
        weapon_dir = _rot_y(weapon_dir)

    if clip == "death" and u >= 0.42:
        t = min(1.0, max(0.0, (u - 0.42) / 0.58))
        ease = 1.0 - max(0.0, 1.0 - t) ** 2.5
        _set_anat_rot(arm_obj, "thigh_l", -72.0 + 48.0 * ease, 4.0, 4.0)
        _set_anat_rot(arm_obj, "shin_l", 96.0 - 70.0 * ease, 0.0, 0.0)
        _set_anat_rot(arm_obj, "foot_l", 20.0, 0.0, 0.0)
        _set_anat_rot(arm_obj, "thigh_r", -72.0 + 48.0 * ease, -4.0, -4.0)
        _set_anat_rot(arm_obj, "shin_r", 96.0 - 70.0 * ease, 0.0, 0.0)
        _set_anat_rot(arm_obj, "foot_r", 20.0, 0.0, 0.0)
    else:
        _solve_leg_ik(arm_obj, "l", scale, foot_l, foot_fwd_l, knee_out_bias=0.10)
        _solve_leg_ik(arm_obj, "r", scale, foot_r, foot_fwd_r, knee_out_bias=0.10)

    _aim_weapon_tip_to_y(arm_obj, scale, weapon_len, weapon_dir, target_tip_y_gd=weapon_tip_y)


def bake_master_animations(
    arm_obj: bpy.types.Object,
    scale: float = 1.0,
    weapon_style: str = "greatsword",
    weapon_len: float = 1.35,
) -> list[str]:
    bpy.context.scene.render.fps = 60
    arm_obj.animation_data_create()
    while len(arm_obj.animation_data.nla_tracks) > 0:
        arm_obj.animation_data.nla_tracks.remove(arm_obj.animation_data.nla_tracks[0])

    # (name, duration_sec, keyframe_step, is_loop)
    clips: list[tuple[str, float, int, bool]] = [
        ("idle", 1.80, 6, True),
        ("run", 0.65, 3, True),
        ("attack_1", 0.55, 2, False),
        ("attack_2", 0.55, 2, False),
        ("attack_whirl", 0.75, 3, True),
        ("skill_slam", 0.70, 3, False),
        ("skill_cast", 0.55, 3, False),
        ("dash", 0.35, 2, False),
        ("hit", 0.28, 2, False),
        ("death", 0.85, 3, False),
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
            _apply_pose_sample(arm_obj, name, u, scale, weapon_style, weapon_len)
            _key_all_bones(arm_obj, f)

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
