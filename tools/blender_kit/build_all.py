import json
import os
import struct
import sys

import bpy

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TOOLS_DIR = os.path.dirname(SCRIPT_DIR)
if TOOLS_DIR not in sys.path:
    sys.path.insert(0, TOOLS_DIR)

from blender_kit.kit_arena import build_all_arena_props
from blender_kit.kit_characters import build_all_characters


def _audit_glb(path: str) -> tuple[int, list[str], int]:
    with open(path, "rb") as f:
        data = f.read()
    chunk_len = struct.unpack("<I", data[12:16])[0]
    gltf = json.loads(data[20 : 20 + chunk_len])
    anims = [a.get("name", "") for a in gltf.get("animations", [])]
    tris = 0
    accessors = gltf.get("accessors", [])
    for mesh in gltf.get("meshes", []):
        for prim in mesh.get("primitives", []):
            if "indices" in prim:
                tris += accessors[prim["indices"]]["count"] // 3
            elif "attributes" in prim and "POSITION" in prim["attributes"]:
                tris += accessors[prim["attributes"]["POSITION"]]["count"] // 3

    bad_verts = 0
    if anims:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=path)
        arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
        mesh_obj = [o for o in bpy.data.objects if o.type == "MESH" and "Icosphere" not in o.name][0]
        head_b = arm.data.bones["head"]
        scale = max(0.5, (arm.matrix_world @ head_b.head_local).z / 1.66)
        for v in mesh_obj.data.vertices:
            if not v.groups:
                bad_verts += 1
                continue
            g = max(v.groups, key=lambda x: x.weight)
            bname = mesh_obj.vertex_groups[g.group].name
            if bname in ("weapon_r", "cape_0", "cape_1", "cape_2"):
                continue
            b = arm.data.bones[bname]
            vw = mesh_obj.matrix_world @ v.co
            d = min((vw - (arm.matrix_world @ b.head_local)).length, (vw - (arm.matrix_world @ b.tail_local)).length)
            limit = 0.72 * scale if bname == "hips" else 0.52 * scale
            if d > limit:
                bad_verts += 1
    return tris, anims, bad_verts


def main() -> None:
    char_paths = build_all_characters()
    prop_paths = build_all_arena_props()
    all_paths = char_paths + prop_paths
    print("\n=== DARK-MEDIEVAL KIT BUILD SUMMARY ===")
    for p in all_paths:
        tris, anims, bad = _audit_glb(p)
        kb = os.path.getsize(p) / 1024.0
        anim_info = f" | anims({len(anims)}): {','.join(anims)} | bad_verts={bad}" if anims else ""
        print(f"  {os.path.basename(p):26s} | {tris:6d} tris | {kb:7.1f} KB{anim_info}")
        if bad > 0:
            raise RuntimeError(f"Skinning audit failed on {p}: {bad} stray vertices")
    print(f"Total GLBs exported: {len(all_paths)}")


if __name__ == "__main__":
    main()
