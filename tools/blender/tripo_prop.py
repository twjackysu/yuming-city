"""把 Tripo 產的武器與物件（art-inbox/tripo/<id>/<id>_model.glb）擺正、縮到實際大小、原點放好，輸出遊戲用的 glb。

Tripo 的產物塞在邊長 1 的方塊裡、朝向隨意（武器常常是斜的），不能直接用。
  武器（--kind weapon）：長軸轉到 Blender 的 +Z（匯出後＝Godot 的 +Y）、扁的那一面朝 X；--head 決定哪一頭朝上；
      縮到 --length；原點在握的地方（從底端算 --grip 比例）。
      --like staff／sword：尺寸與原點照 KayKit 的法杖／雙手劍（遊戲裡原本用的），可以直接替換、不用改握法的數字。
  物件（--kind prop）：照原本的上下，底部中心放在原點，縮到 --height 公尺。
      --sink：整個往下沉幾公尺（模型自帶一圈底座時，讓底座的邊緣埋進地面）。
      --moss-below：這個高度以下的面，貼圖上黃綠色（草皮）的地方改塗成 MOSS（跟關卡地面的苔一樣的暗色）；
          蘑菇、樹根這些不是黃綠色的不動。Tripo 的樹自帶一圈亮黃綠的土丘，放進暗紫的森林裡太搶眼。
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
# --moss-below 改塗的顏色（sRGB）：跟 game/src/world/forest_ground.gdshader 的 moss 同一個
MOSS = (0.12, 0.22, 0.18)


def repaint_grass(meshes, below):
    """高度 below 以下的面：貼圖上黃綠色的像素改塗成 MOSS（保留原本的明暗起伏）。回傳改了幾個像素。"""
    changed = 0
    for o in meshes:
        me = o.data
        uvs = me.uv_layers.active.data if me.uv_layers.active else None
        img = next((n.image for mat in me.materials if mat and mat.node_tree for n in mat.node_tree.nodes
                    if n.type == "TEX_IMAGE" and n.image and any(l.to_socket.name == "Base Color" for l in n.outputs[0].links)), None)
        if uvs is None or img is None:
            continue
        w, h = img.size
        px = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        px = px.reshape(h, w, 4)
        mask = np.zeros((h, w), dtype=bool)   # 低的面（土丘）蓋到的像素
        other = np.zeros((h, w), dtype=bool)  # 其他面（樹幹、樹枝上的黏液）蓋到的像素
        for p in me.polygons:
            into = other if any(me.vertices[i].co.z >= below for i in p.vertices) else mask
            t = np.array([uvs[li].uv for li in p.loop_indices], dtype=float) * (w, h)
            x0, y0 = np.floor(t.min(0)).astype(int) - 1
            x1, y1 = np.ceil(t.max(0)).astype(int) + 1
            x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, w - 1), min(y1, h - 1)
            if x1 < x0 or y1 < y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            for k in range(1, len(t) - 1):  # 多邊形拆成扇形的三角形
                a, b, c = t[0], t[k], t[k + 1]
                d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
                if abs(d) < 1e-9:
                    continue
                u = ((b[1] - c[1]) * (gx - c[0]) + (c[0] - b[0]) * (gy - c[1])) / d
                v = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / d
                into[y0:y1 + 1, x0:x1 + 1] |= (u >= 0.0) & (v >= 0.0) & (u + v <= 1.0)
        # 貼圖在每塊 UV 外面還多塗了一圈同色的邊（取樣時不漏底色）：土丘旁邊那一圈也要改，不然接縫會留一條亮綠
        for _ in range(16):
            grown = mask.copy()
            grown[1:] |= mask[:-1]
            grown[:-1] |= mask[1:]
            grown[:, 1:] |= mask[:, :-1]
            grown[:, :-1] |= mask[:, 1:]
            mask = grown & ~other
        r, g, b = px[..., 0], px[..., 1], px[..., 2]
        grass = mask & (g > b * 1.35) & (g > r * 0.85) & (g > 0.25)
        if not grass.any():
            continue
        luma = 0.3 * r + 0.6 * g + 0.1 * b
        shade = np.clip(luma / max(float(luma[grass].mean()), 1e-4), 0.6, 1.35)
        for ch in range(3):
            px[..., ch] = np.where(grass, MOSS[ch] * shade, px[..., ch])
        img.pixels.foreach_set(px.ravel())
        img.update()
        # 改過的圖匯出時會重新編碼。Blender 寫的 JPEG 帶 EXIF／ICC 區段，Godot 4.7 讀不了（整張貼圖會不見），所以存成 PNG：
        # 匯出器看檔名決定格式
        img.filepath_raw = "repainted.png"
        changed += int(grass.sum())
    return changed


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
    ap.add_argument("--sink", type=float, default=0.0, help="物件往下沉幾公尺")
    ap.add_argument("--moss-below", type=float, default=0.0, help="這個高度（公尺）以下的黃綠色草皮改塗成地面的苔色")
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
    note = ""
    if args.moss_below > 0.0:
        note = f"、草皮改塗 {repaint_grass(meshes, args.moss_below)} 像素"
    if args.sink != 0.0:
        for o in meshes:
            o.data.transform(Matrix.Translation((0, 0, -args.sink)))
    bpy.context.view_layer.objects.active = meshes[0]
    args.out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(args.out), export_format="GLB", use_selection=True,
                              export_animations=False, export_yup=True, export_image_format="AUTO")
    tris = sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons)
    print(f"[{args.out.stem}] 已匯出（Tripo）：{tris} 個三角面、{size} m{note}、{args.out.stat().st_size // 1024} KB")


if __name__ == "__main__":
    sys.exit(main())
