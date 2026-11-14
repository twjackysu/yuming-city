"""把 Tripo 產的角色（art-inbox/tripo/<id>/<id>_rig.glb，Mixamo 骨名、T 字站姿）轉成遊戲用的 glb（D-271）。

跟 vrm_character.py 一樣的出口：骨頭改成 Godot 人形骨架的名字、臉朝 Blender 的 +Y（匯出後＝Godot 的 −Z）、
腳底在原點、身高縮到指定的公尺數，再用 common.py 的 Animator 做 idle／walk／run／light_attack_01／release。
Tripo 自己附的動作（<id>_anim.glb）不用：只有 idle／walk／run，沒有出手與釋放，而且兩套動作混著用站姿會跳。

用法：python3 -I tools/blender/tripo_character.py --src art-inbox/tripo/sheila_rank_f/sheila_rank_f_rig.glb \
        --out build/art/characters/sheila/sheila.glb --name sheila --height 1.62
來源檔是外來的資料：只讀它的幾何、骨架與貼圖，不執行裡面的任何東西。
"""
import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as c  # noqa: E402

# Mixamo 的骨名（去掉 "mixamorig:"）→ Godot SkeletonProfileHumanoid
RENAME = {"Hips": "Hips", "Spine": "Spine", "Spine1": "Chest", "Spine2": "UpperChest", "Neck": "Neck", "Head": "Head"}
for _side in ("Left", "Right"):
    RENAME.update({_side + "Shoulder": _side + "Shoulder", _side + "Arm": _side + "UpperArm",
                   _side + "ForeArm": _side + "LowerArm", _side + "Hand": _side + "Hand",
                   _side + "UpLeg": _side + "UpperLeg", _side + "Leg": _side + "LowerLeg",
                   _side + "Foot": _side + "Foot", _side + "ToeBase": _side + "Toes"})
NEEDED = ("Hips", "Spine", "Chest", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
          "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg",
          "RightLowerLeg", "RightFoot")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--name", default="character")
    ap.add_argument("--height", type=float, default=1.65, help="腳底到頭頂（公尺）")
    ap.add_argument("--attack", choices=("swing", "thrust"), default="swing")
    args = ap.parse_args()

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(args.src))
    arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    meshes = [o for o in bpy.context.scene.objects
              if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers)]
    for o in list(bpy.context.scene.objects):  # 沒綁骨架的網格（骨頭的顯示用形狀）、空物件
        if o is not arm and o not in meshes:
            bpy.data.objects.remove(o)
    if arm.animation_data is not None:
        arm.animation_data_clear()
    for act in list(bpy.data.actions):
        bpy.data.actions.remove(act)
    arm.name = args.name.capitalize()
    for bone in arm.data.bones:
        short = bone.name.split(":")[-1]
        if short in RENAME:
            bone.name = RENAME[short]  # 頂點群組跟著改名
    missing = [b for b in NEEDED if b not in arm.data.bones]
    if missing:
        raise SystemExit(f"[tripo] 缺骨頭：{missing}")

    # 朝向、比例、原點：直接改網格與骨架的資料（不靠物件的變形，匯出後根節點是乾淨的）
    def world_head(bone):
        return arm.matrix_world @ arm.data.bones[bone].head_local

    left = world_head("LeftUpperArm") - world_head("RightUpperArm")
    forward = Vector((left.x, left.y, 0.0)).cross(Vector((0, 0, 1)))  # 左 × 上＝前
    turn = Matrix.Rotation(math.atan2(forward.x, forward.y), 4, "Z")  # 把「前」轉到 +Y
    pts = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
    z_lo, z_hi = min(p.z for p in pts), max(p.z for p in pts)
    hips = world_head("Hips")
    scale = args.height / (z_hi - z_lo)
    fix = Matrix.Scale(scale, 4) @ turn @ Matrix.Translation((-hips.x, -hips.y, -z_lo))
    for o in meshes:
        o.data.transform(fix @ o.matrix_world)
        o.parent = arm
        o.matrix_parent_inverse = Matrix.Identity(4)
        o.matrix_basis = Matrix.Identity(4)
    arm.data.transform(fix @ arm.matrix_world)
    arm.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()

    def head(bone):
        return arm.matrix_world @ arm.data.bones[bone].head_local

    face = (head("LeftUpperArm") - head("RightUpperArm")).cross(Vector((0, 0, 1))).normalized()
    segs = {}
    for side in ("Left", "Right"):
        segs[side + "UpperArm"] = (head(side + "UpperArm"), head(side + "LowerArm"))
        segs[side + "LowerArm"] = (head(side + "LowerArm"), head(side + "Hand"))
    tris = sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons)
    print(f"[tripo] {len(meshes)} 個網格、{tris} 個三角面、{len(arm.data.bones)} 根骨頭、"
          f"原本高 {z_hi - z_lo:.2f} → {args.height:.2f} m、臉朝 ({face.x:+.2f}, {face.y:+.2f})（要 +Y）、"
          f"骨盆高 {head('Hips').z:.2f}、頭的骨頭高 {head('Head').z:.2f}")

    a = c.Animator(arm, segs)
    c.standard_actions(a, args.attack)
    c.release_action(a)
    c.activate(meshes[0])
    for o in meshes:
        o.select_set(True)
    arm.select_set(True)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(args.out), export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="NLA_TRACKS", export_skins=True,
                              export_yup=True, export_image_format="AUTO", export_force_sampling=True)
    c.patch_orm(args.out)
    print(f"[{args.name}] 已匯出 {args.out.name}（Tripo）：{tris} 個三角面、身高 {args.height:.2f} m、"
          f"{args.out.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
