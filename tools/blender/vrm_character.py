"""把現成的 VRM 0.x 角色（VRoid 的 CC0 範例，見 docs/design/12-ready-made-characters.md）變成遊戲用的角色 glb。

    python3 -I tools/blender/vrm_character.py --src <角色.vrm> --out <id.glb> [--name sheila]

做的事：用 VRM 自己的人形對照表把骨頭改成 Godot 人形骨架的名字（Hips、LeftUpperArm…）→ 套 common.py 的動作
（idle／walk／run／light_attack_01／release）→ 匯出 glb。臉、頭髮、身體、貼圖都照原檔。

**還沒接進 scripts/gen_art.sh**（D-252 之後的下一步）：材質沒有 Normal／ORM，過不了 scripts/check_character_glb.py；
材質是「不受光」（KHR_materials_unlit），在暗的場景裡人物是亮的、不吃場景的光。
"""
import argparse
import json
import shutil
import struct
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as c  # noqa: E402  （common 會先 import bpy）
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402


def humanoid_map(src: Path):
    """VRM 0.x：extensions.VRM.humanoid.humanBones＝人形骨頭名（leftUpperArm…）→ 節點名。"""
    raw = src.read_bytes()
    jlen = struct.unpack_from("<I", raw, 12)[0]
    data = json.loads(raw[20:20 + jlen])
    vrm = data["extensions"]["VRM"]
    meta = vrm.get("meta", {})
    print(f"[vrm] {meta.get('title')}：授權 {meta.get('licenseName')}、商用 {meta.get('commercialUssageName')}")
    return {b["bone"]: data["nodes"][b["node"]]["name"] for b in vrm["humanoid"]["humanBones"]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--name", default="character")
    args = ap.parse_args()
    human = humanoid_map(args.src)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    with tempfile.TemporaryDirectory() as tmp:
        glb = Path(tmp) / "src.glb"  # Blender 的 glTF 匯入只認 .glb／.gltf
        shutil.copyfile(args.src, glb)
        bpy.ops.import_scene.gltf(filepath=str(glb))
    arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    meshes = [o for o in bpy.context.scene.objects
              if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers)]
    for o in list(bpy.context.scene.objects):  # 匯入時多出來、沒綁骨架的網格（骨頭的顯示用形狀）
        if o.type == "MESH" and o not in meshes:
            bpy.data.objects.remove(o)
    arm.name = args.name.capitalize()
    for vrm_name, node in human.items():
        bone = arm.data.bones.get(node)
        if bone is not None:
            bone.name = vrm_name[0].upper() + vrm_name[1:]  # leftUpperArm → LeftUpperArm（頂點群組跟著改名）

    def head(bone):
        return arm.matrix_world @ arm.data.bones[bone].head_local

    # 動作只需要上臂與前臂的方向（T 字站姿或 A 字站姿都可以：手臂垂下的角度從這裡算）
    segs = {}
    for side in ("Left", "Right"):
        segs[side + "UpperArm"] = (head(side + "UpperArm"), head(side + "LowerArm"))
        segs[side + "LowerArm"] = (head(side + "LowerArm"), head(side + "Hand"))
    height = max((o.matrix_world @ Vector(corner)).z for o in meshes for corner in o.bound_box)
    tris = sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons)
    print(f"[vrm] {len(meshes)} 個網格、{tris} 個三角面、{len(arm.data.bones)} 根骨頭、身高 {height:.2f} m")

    a = c.Animator(arm, segs)
    c.standard_actions(a)
    c.release_action(a)
    c.activate(meshes[0])
    for o in meshes:
        o.select_set(True)
    arm.select_set(True)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(args.out), export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="NLA_TRACKS", export_skins=True,
                              export_yup=True, export_image_format="AUTO", export_force_sampling=True)
    print(f"[vrm] 已匯出 {args.out}（{args.out.stat().st_size // 1024} KB）")


if __name__ == "__main__":
    main()
