"""把幾個現成角色（.vrm）排成一排算一張正面圖，挑底模或看改色用（D-259）。

  python3 -I tools/blender/vrm_roster.py <放 .vrm 的資料夾> <輸出.png> [名字 …]

- 資料夾通常是 ~/.cache/yuming-art/vrm-samples-<commit>/files（scripts/gen_art.sh 抓的；其他 CC0 的範例用
  git show <commit>:vroid/beta/<名字>.vrm 抓進同一個資料夾，清單與授權在 docs/design/12 第 1、7 節）。
- 不給名字就全部算。8 個角色、4400 px 寬約 15 秒（Cycles、16 samples）。
- 鏡頭在 +Y 往 −Y 看（VRM 0.x 匯入 Blender 之後臉朝 +Y），所以**畫面由左到右是清單的反順序**。
- 匯入時多出來、沒有綁骨架的網格（骨頭的顯示用形狀）不算進圖裡。
"""
import math
import shutil
import sys
import tempfile
from pathlib import Path

import bpy
from mathutils import Vector

SPACING = 1.7


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [a for a in sys.argv[1:] if not a.startswith("-")]
    if len(argv) < 2:
        print(__doc__)
        raise SystemExit(2)
    src, out, names = Path(argv[0]), argv[1], argv[2:]
    if not names:
        names = sorted(p.stem for p in src.glob("*.vrm"))
    tmp = Path(tempfile.mkdtemp(prefix="vrm_roster_"))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    x = 0.0
    for name in names:
        glb = tmp / f"{name}.glb"   # .vrm 就是 glb，換副檔名 Blender 才認
        shutil.copyfile(src / f"{name}.vrm", glb)
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(glb))
        new = [o for o in bpy.data.objects if o not in before]
        for o in new:
            if o.type == "MESH" and not any(m.type == "ARMATURE" for m in o.modifiers):
                o.hide_render = True
        bpy.context.view_layer.update()
        lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
        for o in new:
            if o.type == "MESH" and not o.hide_render:
                for corner in o.bound_box:
                    w = o.matrix_world @ Vector(corner)
                    lo, hi = Vector(map(min, lo, w)), Vector(map(max, hi, w))
        for root in [o for o in new if o.parent is None]:
            root.location.x += x - (lo.x + hi.x) / 2
        print(f"[roster] {name}: 高 {hi.z - lo.z:.2f} m")
        x += SPACING
    scene = bpy.context.scene
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.20, 0.20, 0.22, 1)
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 16
    scene.cycles.use_denoising = False
    scene.view_settings.view_transform = "Standard"
    span = x - SPACING
    cam_data = bpy.data.cameras.new("c")
    cam = bpy.data.objects.new("c", cam_data)
    scene.collection.objects.link(cam)
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = span + 1.9
    cam.location = (span / 2, 10.0, 0.95)
    cam.rotation_euler = (math.radians(90), 0, math.radians(180))
    scene.camera = cam
    scene.render.resolution_x = min(4400, 550 * len(names))
    scene.render.resolution_y = int(scene.render.resolution_x * 2.1 / (span + 1.9))
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print(f"[roster] 已輸出 {out}（由左到右：{'、'.join(reversed(names))}）")


if __name__ == "__main__":
    main()
