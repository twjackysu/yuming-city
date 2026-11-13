"""做好的角色 glb 的預覽圖：四個角度（正面兩張、背面兩張），Cycles，一次約 10 秒。改模型時先看這個，滿意了才進遊戲拍。

  python3 -I tools/blender/preview.py build/art/characters/sheila/sheila.glb <輸出.png>
  … --pose=run --frame=6 ／ --pose=light_attack_01 --frame=8      # 換動作看衣服會不會穿出來
  輸出 <輸出>_0.png～_3.png（600×1000）。人物的材質是不受光的，預覽看到的是貼圖本來的顏色，不是遊戲裡受光之後的樣子。
"""
import math
import sys

import bpy
from mathutils import Vector

args = [a for a in sys.argv[1:] if not a.startswith("-")]
src, out = args[-2], args[-1]
POSE = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--pose=")), "idle")
FRAME = int(next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--frame=")), "1"))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
scene = bpy.context.scene
arm = next(o for o in scene.objects if o.type == "ARMATURE")
for o in list(scene.objects):
    if o.type == "MESH" and not any(m.type == "ARMATURE" for m in o.modifiers):
        bpy.data.objects.remove(o)      # 匯入時多出來的骨頭顯示用形狀


def head(bone):
    return arm.matrix_world @ arm.data.bones[bone].head_local


FRONT = 1.0 if head("LeftToes").y > head("LeftFoot").y else -1.0   # 臉朝 +Y 還是 −Y
act = bpy.data.actions.get(POSE)
if act is not None and arm.animation_data is not None:
    arm.animation_data.action = act
    try:
        arm.animation_data.action_slot = act.slots[0]
    except Exception:
        pass
scene.frame_set(FRAME)
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.20, 0.20, 0.22, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.6
scene.render.engine = "CYCLES"
scene.cycles.samples = 12
scene.cycles.use_denoising = False
scene.view_settings.view_transform = "Standard"
scene.render.resolution_x, scene.render.resolution_y = 600, 1000
target = Vector((0, 0, 0.86))
for i, ang in enumerate((20, 160, 200, 340)):
    cd = bpy.data.cameras.new(f"c{i}")
    cam = bpy.data.objects.new(f"c{i}", cd)
    scene.collection.objects.link(cam)
    cd.lens = 70
    a = math.radians(ang)
    cam.location = Vector((math.sin(a) * 3.55, math.cos(a) * 3.55 * FRONT, 1.05))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = out.replace(".png", f"_{i}.png")
    bpy.ops.render.render(write_still=True)
print("[preview] RENDERED")
