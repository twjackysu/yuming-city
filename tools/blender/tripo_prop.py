"""把 Tripo 產的武器與物件（art-inbox/tripo/<id>/<id>_model.glb）擺正、縮到實際大小、原點放好，輸出遊戲用的 glb。

Tripo 的產物塞在邊長 1 的方塊裡、朝向隨意（武器常常是斜的），不能直接用。
  武器（--kind weapon）：長軸轉到 Blender 的 +Z（匯出後＝Godot 的 +Y）、扁的那一面朝 X；--head 決定哪一頭朝上；
      縮到 --length；原點在握的地方（從底端算 --grip 比例）。
      --like staff／sword：尺寸與原點照 KayKit 的法杖／雙手劍（遊戲裡原本用的），可以直接替換、不用改握法的數字。
  物件（--kind prop）：照原本的上下，底部中心放在原點，縮到 --height 公尺。
用法：python3 -I tools/blender/tripo_prop.py --src <glb> --out <glb> --kind weapon --like staff
來源檔是外來的資料：只讀幾何與貼圖，不執行裡面的任何東西。
"""
import argparse
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix

# 照 KayKit 模型的量法（Blender 座標）：(底端 z, 頂端 z)
LIKE = {"staff": (-0.90, 1.25), "sword": (-0.40, 1.96)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--kind", choices=("weapon", "prop"), required=True)
    ap.add_argument("--like", choices=tuple(LIKE), default=None)
    ap.add_argument("--head", choices=("wide", "far_from_wide", "keep", "flip"), default="wide",
                    help="哪一頭朝上：wide＝比較粗的那一頭（杖頭、斧頭、槌頭）；far_from_wide＝離最粗的地方（護手）遠的那一頭（劍尖）")
    ap.add_argument("--length", type=float, default=1.0)
    ap.add_argument("--grip", type=float, default=0.15)
    ap.add_argument("--height", type=float, default=1.0)
    ap.add_argument("--turn", type=float, default=0.0, help="物件繞上下軸多轉幾度")
    args = ap.parse_args()

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(args.src))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in list(bpy.context.scene.objects):
        if o not in meshes:
            bpy.data.objects.remove(o)
    pts = np.array([o.matrix_world @ v.co for o in meshes for v in o.data.vertices], dtype=float)

    if args.kind == "weapon":
        mid = (pts.max(0) + pts.min(0)) / 2.0
        w, v = np.linalg.eigh(np.cov((pts - mid).T))
        long_axis, flat_axis = v[:, 2], v[:, 1]  # 最長的方向、第二長的方向（刃的寬）
        thin = np.cross(long_axis, flat_axis)
        rot = np.array([flat_axis, thin, long_axis])  # 列＝新的 X、Y、Z
        if np.linalg.det(rot) < 0:
            rot[1] *= -1
        q = (pts - mid) @ rot.T
        z = q[:, 2]
        radius = np.hypot(q[:, 0], q[:, 1])
        bins = np.linspace(z.min(), z.max(), 11)
        r = np.array([radius[(z >= bins[i]) & (z <= bins[i + 1])].mean() if ((z >= bins[i]) & (z <= bins[i + 1])).any() else 0.0
                      for i in range(10)])
        flip = False
        if args.head == "wide":
            flip = r[:3].mean() > r[7:].mean()
        elif args.head == "far_from_wide":
            flip = int(np.argmax(r)) >= 5
        elif args.head == "flip":
            flip = True
        if flip:
            rot[2] *= -1
            rot[0] *= -1
            q = (pts - mid) @ rot.T
        lo, hi = q[:, 2].min(), q[:, 2].max()
        if args.like:
            z0, z1 = LIKE[args.like]
            scale = (z1 - z0) / (hi - lo)
            shift_z = z0 - lo * scale
        else:
            scale = args.length / (hi - lo)
            shift_z = -(lo + (hi - lo) * args.grip) * scale
        m = Matrix.Translation((0, 0, shift_z)) @ Matrix.Scale(scale, 4) @ Matrix([list(rot[0]) + [0], list(rot[1]) + [0], list(rot[2]) + [0], [0, 0, 0, 1]]) @ Matrix.Translation(tuple(-mid))
        size = f"長 {(hi - lo) * scale:.2f}"
    else:
        lo, hi = pts.min(0), pts.max(0)
        scale = args.height / (hi[2] - lo[2])
        m = Matrix.Rotation(np.radians(args.turn), 4, "Z") @ Matrix.Scale(scale, 4) @ Matrix.Translation((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))
        size = f"高 {args.height:.2f}、寬 {(hi[0] - lo[0]) * scale:.2f}×{(hi[1] - lo[1]) * scale:.2f}"
    for o in meshes:
        o.data.transform(m @ o.matrix_world)
        o.matrix_basis = Matrix.Identity(4)
        o.parent = None
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    args.out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(args.out), export_format="GLB", use_selection=True,
                              export_animations=False, export_yup=True, export_image_format="AUTO")
    tris = sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons)
    print(f"[{args.out.stem}] 已匯出（Tripo）：{tris} 個三角面、{size} m、{args.out.stat().st_size // 1024} KB")


if __name__ == "__main__":
    sys.exit(main())
