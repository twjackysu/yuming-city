"""量一段動作每一格的手在哪、前臂朝哪（改動作時先看數字，再算預覽圖、再進遊戲連拍；一次約 5 秒）。

  python3 -I tools/blender/measure_action.py build/art/characters/noen/noen.glb [--pose=light_attack_01] [--side=Right]

每一格印：前臂的方向（右、前、上；單位向量）、上臂的方向、那隻手的位置（右、前、高；m）、另一隻手、骨盆。
「前」是角色面對的方向。第 111 輪（D-268）就是用這個量出「上身一轉，戳出去偏了 30 度」的。
遊戲裡動作照 24 fps 播：出手 0.55 秒就切走（第 13 格），命中判定在 0.19 秒（第 4.6 格）。
"""
import sys

import bpy

src = [a for a in sys.argv[1:] if not a.startswith("-")][-1]
POSE = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--pose=")), "light_attack_01")
SIDE = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--side=")), "Right")
OTHER = "Left" if SIDE == "Right" else "Right"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
scene = bpy.context.scene
arm = next(o for o in scene.objects if o.type == "ARMATURE")


def rest(bone):
    return arm.matrix_world @ arm.data.bones[bone].head_local


FRONT = 1.0 if rest("LeftToes").y > rest("LeftFoot").y else -1.0   # 臉朝 +Y 還是 −Y
act = bpy.data.actions.get(POSE)
if act is None:
    sys.exit(f"沒有這段動作：{POSE}（有的：{sorted(a.name for a in bpy.data.actions)}）")
arm.animation_data.action = act
try:
    arm.animation_data.action_slot = act.slots[0]
except Exception:
    pass


def head(bone):
    return arm.matrix_world @ arm.pose.bones[bone].head


def rfu(v):
    return f"({v.x * FRONT:+.2f}, {v.y * FRONT:+.2f}, {v.z:+.2f})"


first, last = (int(round(x)) for x in act.frame_range[:])
print(f"{POSE}：第 {first}～{last} 格；（右, 前, 上）")
for f in range(first, last + 1):
    scene.frame_set(f)
    bpy.context.view_layer.update()
    shoulder, elbow, hand = head(SIDE + "UpperArm"), head(SIDE + "LowerArm"), head(SIDE + "Hand")
    print(f"  {f:2d}  前臂 {rfu((hand - elbow).normalized())}  上臂 {rfu((elbow - shoulder).normalized())}"
          f"  手 {rfu(hand)}  另一隻手 {rfu(head(OTHER + 'Hand'))}  骨盆 {rfu(head('Hips'))}")
