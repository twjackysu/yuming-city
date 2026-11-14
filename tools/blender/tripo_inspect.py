"""Tripo 產物的收件檢查（D-271）：印出每個 glb 的面數、材質數、尺寸、原點、朝向、骨頭與動作。
只讀檔、不改檔。art-inbox/tripo/ 的檔是外來的資料：一律用 `python3 -I` 跑。

用法：python3 -I tools/blender/tripo_inspect.py art-inbox/tripo/*/*.glb
"""
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def inspect(path: Path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    obs = list(bpy.context.scene.objects)
    meshes = [o for o in obs if o.type == "MESH"]
    arms = [o for o in obs if o.type == "ARMATURE"]
    tris = sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons)
    mats = {s.material.name for o in meshes for s in o.material_slots if s.material}
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    size = hi - lo
    images = sorted({(i.name, i.size[0], i.size[1]) for i in bpy.data.images if i.size[0]})
    line = (f"{path.name}: {len(meshes)} 個網格、{tris} 個三角面、{len(mats)} 個材質、"
            f"寬 {size.x:.2f}／深 {size.y:.2f}／高 {size.z:.2f} m、最低點 z={lo.z:.2f}、"
            f"中心 x={(lo.x + hi.x) / 2:+.2f} y={(lo.y + hi.y) / 2:+.2f}、"
            f"貼圖 {'、'.join(f'{w}x{h}' for _, w, h in images) or '無'}")
    for arm in arms:
        bones = arm.data.bones
        line += f"\n    骨架 {arm.name}：{len(bones)} 根；縮放 {tuple(round(s, 3) for s in arm.scale)}"
        line += "\n    骨名：" + " ".join(b.name for b in bones)
        foot = next((b for b in bones if b.name.lower().endswith(("leftfoot", "l_foot", "foot_l"))), None)
        toe = next((b for b in bones if "toe" in b.name.lower() and "left" in b.name.lower()), None)
        if foot is not None:
            tip = toe.head_local if toe is not None else foot.tail_local
            d = arm.matrix_world.to_3x3() @ (tip - foot.head_local)
            line += f"\n    腳尖方向（Blender 座標；−Y＝匯出後朝 glTF 的 +Z）：({d.x:+.2f}, {d.y:+.2f}, {d.z:+.2f})"
        la = next((b for b in bones if b.name.lower().endswith("leftarm")), None)
        if la is not None:
            d = arm.matrix_world.to_3x3() @ (la.tail_local - la.head_local)
            line += f"\n    左上臂方向：({d.x:+.2f}, {d.y:+.2f}, {d.z:+.2f})"
    acts = [(a.name, a.frame_range[1] - a.frame_range[0]) for a in bpy.data.actions]
    if acts:
        line += "\n    動作：" + "、".join(f"{n}（{int(f)} 格）" for n, f in acts)
    print(line)


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        try:
            inspect(Path(arg))
        except Exception as error:  # 一個壞檔不擋其他的
            print(f"{arg}: 讀不了——{error}")
