"""把現成的 VRM 0.x 角色（VRoid 的 CC0 範例，見 docs/design/12-ready-made-characters.md）變成遊戲用的角色 glb。

    python3 -I tools/blender/vrm_character.py --src <角色.vrm> --out <id.glb> [--name sheila] [--tint Tops=0.3,0.22,0.18]…

做的事：確認檔案裡寫的授權是 CC0（不是就停）→ 用 VRM 自己的人形對照表把骨頭改成 Godot 人形骨架的名字
（Hips、LeftUpperArm…）→ 套 common.py 的動作（idle／walk／run／light_attack_01／release）→ 匯出 glb →
每個材質補一張平的 Normal 與固定值的 ORM（收件檢查 scripts/check_character_glb.py 要求；不受光的材質用不到，畫面不變）
→ 照 --tint 改色（材質名稱含這個字的，底色乘上這個顏色；可以給很多個）。臉、頭髮、身體、貼圖都照原檔。
--scarf r,g,b（0～255 的 sRGB）：加一條自製的圍巾——脖子上繞一圈＋背後垂一條尾巴（玩家的鏡頭看的是背面），
跟著上胸與脖子的骨頭動；材質跟人物一樣不受光，亮面與暗面是畫在貼圖上的（D-254）。
--cape r,g,b [--cape-trim r,g,b]（0～255 的 sRGB）：加一件自製的短斗篷——領口一圈、搭在肩膀上、背後垂到腰，
底色＋滾邊；同時把領結（材質 AccessoryNeck）的面拿掉（D-259：冒險者裝備的第一樣）。

由 scripts/gen_art.sh 呼叫（D-253；哪個角色用哪個檔、改什麼顏色寫在那裡）。
glb 裡的材質照原檔是「不受光」（KHR_materials_unlit）；遊戲載入時由 Puppet.make_lit() 換成吃場景的光、平塗的複本（D-255）。
"""
import argparse
import json
import shutil
import struct
import sys
import tempfile
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as c  # noqa: E402  （common 會先 import bpy）
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402
import math  # noqa: E402

SCARF_MATERIAL = "Scarf"
CAPE_MATERIAL = "Cape"
CAPE_CLASP = (196, 158, 84)  # 胸前扣子的顏色（黃銅）
CAPE_FOLDS = 9  # 短斗篷一圈有幾道褶子（幾何的波浪與貼圖的陰影同一個相位）


def humanoid_map(src: Path):
    """VRM 0.x：extensions.VRM.humanoid.humanBones＝人形骨頭名（leftUpperArm…）→ 節點名。"""
    raw = src.read_bytes()
    jlen = struct.unpack_from("<I", raw, 12)[0]
    data = json.loads(raw[20:20 + jlen])
    vrm = data["extensions"]["VRM"]
    meta = vrm.get("meta", {})
    print(f"[vrm] {meta.get('title')}：授權 {meta.get('licenseName')}、商用 {meta.get('commercialUssageName')}")
    if meta.get("licenseName") != "CC0":  # 只用檔案裡自己寫 CC0 的（design/12：同一個 repo 裡有 Other 授權的）
        raise SystemExit(f"[vrm] {src.name} 的授權不是 CC0（{meta.get('licenseName')}），不用")
    return {b["bone"]: data["nodes"][b["node"]]["name"] for b in vrm["humanoid"]["humanBones"]}


def _png(rgb, size=4):
    """單色的小 PNG（標準函式庫）。"""
    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)
    rows = (b"\x00" + bytes(rgb) * size) * size
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))


def _png_rows(rows):
    """rows：一列一列的 (r, g, b) → PNG（標準函式庫）。"""
    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + bytes(v for px in row for v in px) for row in rows)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", len(rows[0]), len(rows), 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


def scarf_texture(rgb, size=64):
    """圍巾的貼圖（不受光，所以明暗畫在貼圖上）：u＝沿著圍巾的長度、v＝繞斷面一圈（0＝最外側、0.25＝朝上、0.75＝朝下）。
    朝上的一半亮、朝下的一半暗（兩階，漫畫的平塗）；沿長度每隔一段一條深色的褶線。"""
    rows = []
    for y in range(size):
        v = (y + 0.5) / size
        tone = 1.0 if 0.02 < v < 0.52 else 0.62
        row = []
        for x in range(size):
            u = (x + 0.5) / size
            fold = 0.72 if (u * 8.0 + 0.35 * math.sin(v * math.tau)) % 1.0 < 0.09 else 1.0
            row.append(tuple(max(0, min(255, int(ch * tone * fold))) for ch in rgb))
        rows.append(row)
    return _png_rows(rows)


def build_scarf(arm, body_meshes, face, tail=0.44, seg=28):
    """圍巾：脖子上粗粗的一圈＋背後垂一條尾巴。回傳一個綁在骨架上的網格（材質 SCARF_MATERIAL、有 UV）。
    半徑從身體的網格量（VRoid 的衣服是單層的面、底下的身體是挖掉的，所以取「限制距離內最遠的一次打中」，再把整圈抹平）。"""
    verts, polys = [], []
    for o in body_meshes:
        base = len(verts)
        verts.extend(o.matrix_world @ v.co for v in o.data.vertices)
        polys.extend([base + i for i in p.vertices] for p in o.data.polygons)
    bvh = BVHTree.FromPolygons(verts, polys)
    neck = arm.matrix_world @ arm.data.bones["Neck"].head_local
    head_pos = arm.matrix_world @ arm.data.bones["Head"].head_local
    face_y = sum((face.matrix_world @ v.co).y for v in face.data.vertices) / max(1, len(face.data.vertices))
    front = 1.0 if face_y > head_pos.y else -1.0  # 臉朝 +Y 還是 -Y
    centre = Vector((0.0, neck.y, neck.z + 0.03))

    def reach(direction, limit=0.13):
        far, start, travelled = 0.0, centre.copy(), 0.0
        for _ in range(8):
            hit = bvh.ray_cast(start, direction, limit - travelled)
            if hit[0] is None:
                break
            travelled += hit[3] + 1e-4
            far = travelled
            start = centre + direction * travelled
        return min(max(far, 0.05), 0.115)

    radii = [reach(Vector((math.cos(math.tau * i / seg), math.sin(math.tau * i / seg), 0.0))) for i in range(seg)]
    radii = [sum(radii[(i + k) % seg] for k in (-2, -1, 0, 1, 2)) / 5.0 for i in range(seg)]
    P, F, UV, groups = [], [], [], []  # 頂點、面、每個面每個角的 UV、每個頂點的 {骨頭: 權重}
    ring_n = 8
    for i in range(seg + 1):
        th = math.tau * (i % seg) / seg
        d = Vector((math.cos(th), math.sin(th), 0.0))
        lump = 1.0 + 0.14 * math.sin(th * 5.0 + 0.7)
        droop = -0.03 * max(0.0, d.y * front)  # 前面垂低一點
        for k in range(ring_n + 1):
            ph = math.tau * (k % ring_n) / ring_n
            P.append(centre + Vector((0, 0, droop + math.sin(ph) * 0.05 * lump))
                     + d * (radii[i % seg] + 0.026 + math.cos(ph) * 0.034 * lump))
            groups.append({"Neck": 0.35, "UpperChest": 0.65})
    cols = ring_n + 1
    for i in range(seg):
        for k in range(ring_n):
            F.append([i * cols + k, (i + 1) * cols + k, (i + 1) * cols + k + 1, i * cols + k + 1])
            UV.append([(i / seg * 2.0, k / ring_n), ((i + 1) / seg * 2.0, k / ring_n),
                       ((i + 1) / seg * 2.0, (k + 1) / ring_n), (i / seg * 2.0, (k + 1) / ring_n)])
    # 尾巴：從後頸往下，貼著背、離開一點；越往下越寬一點
    rows, half, x0 = 12, 0.06, -0.05
    base = len(P)
    for r in range(rows + 1):
        t = r / rows
        z = centre.z + 0.02 - tail * t
        sway = 0.014 * math.sin(t * 5.0)
        for dx, thick in ((-half, 0.0), (half, 0.0), (half, 0.016), (-half, 0.016), (-half, 0.0)):
            x = x0 + dx * (1.0 + 0.3 * t) + sway
            hit = bvh.ray_cast(Vector((x, neck.y - front * 0.5, z)), Vector((0.0, front, 0.0)), 0.6)
            back = hit[0].y if hit[0] is not None else neck.y - front * 0.09
            P.append(Vector((x, back - front * (0.03 + 0.03 * t + thick), z)))
            groups.append({"UpperChest": 1.0 - 0.6 * t, "Chest": 0.6 * t})
    v_of = (0.75, 0.75, 0.6, 0.25, 0.25)  # 貼著背的那一面是暗的、朝外的那一面是亮的
    for r in range(rows):
        for k in range(4):
            a0, a1 = base + r * 5 + k, base + r * 5 + k + 1
            F.append([a0, a1, a1 + 5, a0 + 5] if front > 0 else [a0, a0 + 5, a1 + 5, a1])
            quad = [(r / rows * 1.5, v_of[k]), (r / rows * 1.5, v_of[k + 1]),
                    ((r + 1) / rows * 1.5, v_of[k + 1]), ((r + 1) / rows * 1.5, v_of[k])]
            UV.append(quad if front > 0 else [quad[0], quad[3], quad[2], quad[1]])
    ob = c.new_object("Scarf", P, F)
    uv = ob.data.uv_layers.new(name="UVMap")
    for poly, quad in zip(ob.data.polygons, UV):
        for loop, st in zip(poly.loop_indices, quad):
            uv.data[loop].uv = st
    for poly in ob.data.polygons:
        poly.use_smooth = True
    mat = bpy.data.materials.new(SCARF_MATERIAL)
    ob.data.materials.append(mat)
    have = {b.name for b in arm.data.bones}
    for i, weights in enumerate(groups):
        for bone, w in weights.items():
            name = bone if bone in have else "Chest" if "Chest" in have else "Spine"
            g = ob.vertex_groups.get(name) or ob.vertex_groups.new(name=name)
            g.add([i], w, "ADD")
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    return ob


def cape_texture(base, trim, w=256, h=128):
    """短斗篷的貼圖：u＝繞身體一圈、v＝從領口（最上面一列）到下襬（最下面一列）。
    底色＋下襬一條寬的滾邊；褶子凹下去的那一半畫暗一點（越往下越明顯）。翻領與扣子用最左上角那一格的顏色（見 build_cape）。"""
    rows = []
    for y in range(h):
        v = (y + 0.5) / h
        band = v > 0.875  # 下襬一條寬的滾邊（不畫細線：兩條線會像水手服的領子）
        depth = min(1.0, max(0.0, (v - 0.35) / 0.45))
        row = []
        for x in range(w):
            u = (x + 0.5) / w
            fold = math.sin(u * math.tau * CAPE_FOLDS + 0.6)
            tone = 1.0 - 0.16 * max(0.0, -fold) * depth
            col = CAPE_CLASP if v < 0.035 else trim if band else base  # 最上面那一條壓在翻領底下，借給扣子用
            row.append(tuple(max(0, min(255, int(ch * tone))) for ch in col))
        rows.append(row)
    return _png_rows(rows)


def strip_material(obs, key):
    """把材質名稱含 key 的面刪掉（領結：會從斗篷的領口穿出來）。回傳刪了幾個面。"""
    import bmesh
    gone = 0
    for o in obs:
        idx = {i for i, m in enumerate(o.data.materials) if m is not None and key.lower() in m.name.lower()}
        if not idx:
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        doomed = [f for f in bm.faces if f.material_index in idx]
        gone += len(doomed)
        bmesh.ops.delete(bm, geom=doomed, context="FACES")
        bm.to_mesh(o.data)
        bm.free()
    return gone


def build_cape(arm, body_meshes, face, seg=48, over=5, hang=8):
    """短斗篷（D-259）：領口一圈 → 搭在肩膀上 → 垂下來。兩側（手臂上面）短、只蓋住肩頭，前面到胸口下面，
    背後最長、到腰（玩家的鏡頭看的是背面，要比背後的長頭髮長才看得到）。整件跟著上胸與胸的骨頭，不跟手臂——
    模型的休息姿勢是 T 字站姿，跟著手臂的話手一放下來布就被捲進身體裡。回傳綁在骨架上的網格（材質 CAPE_MATERIAL、有 UV）。"""
    verts, polys = [], []
    for o in body_meshes:
        base = len(verts)
        verts.extend(o.matrix_world @ v.co for v in o.data.vertices)
        polys.extend([base + i for i in p.vertices] for p in o.data.polygons)
    bvh = BVHTree.FromPolygons(verts, polys)

    def head(bone):
        return arm.matrix_world @ arm.data.bones[bone].head_local

    neck, head_pos, chest = head("Neck"), head("Head"), head("Chest")
    sh = head("RightUpperArm")
    face_y = sum((face.matrix_world @ v.co).y for v in face.data.vertices) / max(1, len(face.data.vertices))
    front = 1.0 if face_y > head_pos.y else -1.0  # 臉朝 +Y 還是 -Y
    cy = neck.y
    z_c = neck.z + 0.012                 # 領口
    z_side = sh.z - 0.115                # 兩側的下襬：肩關節下面一點
    z_front = chest.z - 0.03             # 前面：胸口下面（中間最低，往兩側斜上去）
    z_back = chest.z - 0.15              # 背後：過腰（比背後的長頭髮長）
    a = abs(sh.x) + 0.07                 # 肩膀那一圈的半寬

    def reach(z, d, limit, least=0.0):
        """從身體的中軸往 d 打出去，限制距離內最遠的一次打中（衣服是單層的面、底下的身體是挖掉的）。"""
        origin = Vector((0.0, cy, z))
        far, start, travelled = least, origin.copy(), 0.0
        for _ in range(10):
            hit = bvh.ray_cast(start, d, limit - travelled)
            if hit[0] is None:
                break
            travelled += hit[3] + 1e-4
            far = max(far, travelled)
            start = origin + d * travelled
        return far

    def depth(sign):
        """胸口到肩膀這一段，身體往前（sign=1）或往後（-1）最多凸出多少。"""
        far, z = 0.05, chest.z + 0.04
        while z < sh.z + 0.02:
            for k in range(-3, 4):
                hit = bvh.ray_cast(Vector((k * 0.03, cy + sign * front * 0.5, z)), Vector((0.0, -sign * front, 0.0)), 0.6)
                if hit[0] is not None:
                    far = max(far, (hit[0].y - cy) * sign * front)
            z += 0.02
        return far

    b_front, b_back = depth(1.0) + 0.03, depth(-1.0) + 0.032
    collar = [min(max(reach(z_c, Vector((math.cos(math.tau * i / seg), math.sin(math.tau * i / seg), 0.0)), 0.1), 0.045), 0.085) + 0.016
              for i in range(seg)]
    collar = [sum(collar[(i + k) % seg] for k in (-2, -1, 0, 1, 2)) / 5.0 for i in range(seg)]
    P, F, UV, groups = [], [], [], []
    cols = over + hang + 1
    for i in range(seg + 1):
        th = math.tau * (i % seg) / seg
        d = Vector((math.cos(th), math.sin(th), 0.0))
        sy = d.y * front                                   # +1＝正前方、−1＝正後方、0＝兩側
        b = b_front if sy > 0 else b_back
        edge = 1.0 / math.sqrt((d.x / a) ** 2 + (d.y / b) ** 2)   # 肩膀那一圈（橢圓）的半徑
        z_e = z_c - (0.03 + 0.075 * abs(sy) ** 1.2)        # 搭到那一圈時的高度：兩側幾乎是平的，前後往下斜
        z_h = z_side + ((z_front if sy > 0 else z_back) - z_side) * abs(sy) ** 1.4
        rc = collar[i % seg]
        for k in range(over + 1):                          # 搭在肩膀上的那一段：貼著肩膀與上胸，離開 1.2 cm
            t = k / over
            r = rc + (edge - rc) * t
            z = z_c + (z_e - z_c) * t ** 1.3
            hit = bvh.ray_cast(Vector((d.x * r, cy + d.y * r, neck.z + 0.05)), Vector((0.0, 0.0, -1.0)), 0.4)
            if hit[0] is not None and t > 0.0:
                z = max(z, hit[0].z + 0.012)
            P.append(Vector((d.x * r, cy + d.y * r, z)))
            groups.append({"Neck": 0.2, "UpperChest": 0.8} if k == 0 else {"UpperChest": 1.0})
        z_top, clear = P[-1].z, 0.0
        for k in range(1, hang + 1):                       # 垂下來的那一段：越往下越張開一點、有褶子、不貼進身體
            t = k / hang
            z = z_top + (z_h - z_top) * t
            r = edge * (1.0 + 0.1 * t) * (1.0 + 0.045 * math.sin(th * CAPE_FOLDS + 0.6) * t)
            if abs(sy) > 0.45 and z < sh.z - 0.07:         # 兩側不量：T 字站姿的手臂會被算成身體
                clear = max(clear, reach(z, d, 0.26) + 0.022)
            r = max(r, clear)
            P.append(Vector((d.x * r, cy + d.y * r, z)))
            groups.append({"UpperChest": 1.0 - 0.35 * t, "Chest": 0.35 * t})
    for i in range(seg):
        for k in range(cols - 1):
            a0, b0 = i * cols + k, (i + 1) * cols + k
            F.append([a0, a0 + 1, b0 + 1, b0])
            u0, u1, v0, v1 = i / seg, (i + 1) / seg, 1.0 - k / (cols - 1), 1.0 - (k + 1) / (cols - 1)
            UV.append([(u0, v0), (u0, v1), (u1, v1), (u1, v0)])
    # 翻領：脖子上厚厚的一圈布（像放下來的兜帽），背後比前面厚；顏色用滾邊的（貼圖最下面那一條）
    ring_n, base = 8, len(P)
    for i in range(seg + 1):
        th = math.tau * (i % seg) / seg
        d = Vector((math.cos(th), math.sin(th), 0.0))
        sy = d.y * front
        fat = 1.0 + 0.5 * max(0.0, -sy)                    # 背後堆得比較厚
        low = -0.022 * max(0.0, sy)                         # 前面低一點，露出脖子
        for k in range(ring_n + 1):
            ph = math.tau * (k % ring_n) / ring_n
            P.append(Vector((0.0, cy, z_c + 0.012 + low + math.sin(ph) * 0.03 * fat))
                     + d * (collar[i % seg] + 0.012 + math.cos(ph) * 0.024 * fat))
            groups.append({"Neck": 0.3, "UpperChest": 0.7})
    rc_cols = ring_n + 1
    for i in range(seg):
        for k in range(ring_n):
            a0, b0 = base + i * rc_cols + k, base + (i + 1) * rc_cols + k
            F.append([a0, b0, b0 + 1, a0 + 1])
            UV.append([(i / seg, 0.03)] * 4)
    # 扣子：胸前一個八角的金屬片（顏色在貼圖最上面那一條——見 cape_texture）
    base = len(P)
    mid = Vector((0.0, cy + front * (collar[seg // 4 if front > 0 else 3 * seg // 4] + 0.043), z_c - 0.012))
    P.append(mid + Vector((0.0, front * 0.008, 0.0)))
    groups.append({"UpperChest": 1.0})
    for k in range(8):
        ph = math.tau * k / 8
        P.append(mid + Vector((math.cos(ph) * 0.026, 0.0, math.sin(ph) * 0.026)))
        groups.append({"UpperChest": 1.0})
    for k in range(8):
        tri = [base, base + 1 + k, base + 1 + (k + 1) % 8]
        F.append(tri if front < 0 else tri[::-1])
        UV.append([(0.5, 0.985)] * 3)
    ob = c.new_object("Cape", P, F)
    uv = ob.data.uv_layers.new(name="UVMap")
    for poly, quad in zip(ob.data.polygons, UV):
        for loop, st in zip(poly.loop_indices, quad):
            uv.data[loop].uv = st
    for poly in ob.data.polygons:
        poly.use_smooth = True
    ob.data.materials.append(bpy.data.materials.new(CAPE_MATERIAL))
    have = {bn.name for bn in arm.data.bones}
    for i, weights in enumerate(groups):
        for bone, w in weights.items():
            name = bone if bone in have else "Chest" if "Chest" in have else "Spine"
            g = ob.vertex_groups.get(name) or ob.vertex_groups.new(name=name)
            g.add([i], w, "ADD")
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    print(f"[vrm] 短斗篷：半寬 {a:.3f}、前 {b_front:.3f}、後 {b_back:.3f}、下襬 前 {z_front:.2f}／側 {z_side:.2f}／後 {z_back:.2f}、{len(F) * 2} 個三角面")
    return ob


def patch_materials(path: Path, tints, scarf=None, cape=None):
    """匯出後直接改 glb：每個材質補平的 Normal 與固定值的 ORM（occlusion 與 metallicRoughness 同一張）、照 tints 改底色；
    有圍巾／短斗篷（cape＝(底色, 滾邊)）的話把它的材質換成畫好的貼圖、設成不受光。回傳 (材質數, 改了色的材質名)。"""
    raw = path.read_bytes()
    jlen = struct.unpack_from("<I", raw, 12)[0]
    data = json.loads(raw[20:20 + jlen])
    blen, kind = struct.unpack_from("<II", raw, 20 + jlen)
    if kind != 0x004E4942:
        raise SystemExit("[vrm] glb 沒有內嵌的 BIN 區塊")
    buf = bytearray(raw[28 + jlen:28 + jlen + blen])

    def add_texture(name, png):
        buf.extend(b"\x00" * (-len(buf) % 4))
        data["bufferViews"].append({"buffer": 0, "byteOffset": len(buf), "byteLength": len(png)})
        buf.extend(png)
        data.setdefault("images", []).append({"name": name, "mimeType": "image/png",
                                              "bufferView": len(data["bufferViews"]) - 1})
        data.setdefault("textures", []).append({"source": len(data["images"]) - 1})
        return len(data["textures"]) - 1

    normal = add_texture("flat_normal", _png((128, 128, 255)))
    orm = add_texture("flat_orm", _png((255, 235, 0)))  # 遮蔽 1、粗糙 0.92、金屬 0
    white = None
    tinted = []
    for m in data.get("materials", []):
        pbr = m.setdefault("pbrMetallicRoughness", {})
        made = None
        if scarf is not None and m.get("name") == SCARF_MATERIAL:
            made = add_texture("scarf", scarf_texture(scarf))
        elif cape is not None and m.get("name") == CAPE_MATERIAL:
            made = add_texture("cape", cape_texture(*cape))
        if made is not None:
            pbr["baseColorTexture"] = {"index": made}
            pbr["baseColorFactor"] = [1.0, 1.0, 1.0, 1.0]
            m.setdefault("extensions", {})["KHR_materials_unlit"] = {}
            m["doubleSided"] = True
            if "KHR_materials_unlit" not in data.setdefault("extensionsUsed", []):
                data["extensionsUsed"].append("KHR_materials_unlit")
        if "baseColorTexture" not in pbr:
            if white is None:
                white = add_texture("flat_white", _png((255, 255, 255)))
            pbr["baseColorTexture"] = {"index": white}
        pbr.setdefault("metallicRoughnessTexture", {"index": orm})
        m.setdefault("normalTexture", {"index": normal})
        m["occlusionTexture"] = {"index": pbr["metallicRoughnessTexture"]["index"]}
        for key, rgb in tints:
            if key.lower() in m.get("name", "").lower():
                old = pbr.get("baseColorFactor", [1.0, 1.0, 1.0, 1.0])
                pbr["baseColorFactor"] = [old[0] * rgb[0], old[1] * rgb[1], old[2] * rgb[2], old[3]]
                tinted.append(m.get("name", ""))
    buf.extend(b"\x00" * (-len(buf) % 4))
    data["buffers"][0]["byteLength"] = len(buf)
    js = json.dumps(data, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    path.write_bytes(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(buf))
                     + struct.pack("<II", len(js), 0x4E4F534A) + js
                     + struct.pack("<II", len(buf), 0x004E4942) + bytes(buf))
    return len(data.get("materials", [])), tinted


def parse_tint(text):
    key, _, rgb = text.partition("=")
    parts = [float(x) for x in rgb.split(",")]
    if not key or len(parts) != 3:
        raise argparse.ArgumentTypeError("--tint 的寫法：<材質名稱的一部分>=r,g,b")
    return key, parts


def parse_rgb255(text):
    parts = [int(x) for x in text.split(",")]
    if len(parts) != 3 or not all(0 <= x <= 255 for x in parts):
        raise argparse.ArgumentTypeError("--scarf 的寫法：r,g,b（0～255）")
    return parts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--name", default="character")
    ap.add_argument("--tint", type=parse_tint, action="append", default=[])
    ap.add_argument("--scarf", type=parse_rgb255, default=None)
    ap.add_argument("--cape", type=parse_rgb255, default=None)
    ap.add_argument("--cape-trim", type=parse_rgb255, default=[88, 112, 146])
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

    if args.scarf is not None:
        named = {o.name.split(".")[0]: o for o in meshes}
        body = [o for o in meshes if not o.name.startswith(("Face", "Hair"))]
        meshes.append(build_scarf(arm, body, named.get("Face", meshes[0])))
        tris = sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons)

    if args.cape is not None:
        named = {o.name.split(".")[0]: o for o in meshes}
        body = [o for o in meshes if not o.name.startswith(("Face", "Hair"))]
        gone = strip_material(body, "AccessoryNeck")  # 領結會從斗篷的領口穿出來
        print(f"[vrm] 拿掉領結：{gone} 個面")
        meshes.append(build_cape(arm, body, named.get("Face", meshes[0])))
        tris = sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons)

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
    count, tinted = patch_materials(args.out, args.tint, args.scarf,
                                    (args.cape, args.cape_trim) if args.cape is not None else None)
    print(f"[{args.name}] 已匯出 {args.out.name}：{tris} 個三角面、{count} 個材質（補了 Normal／ORM"
          f"{'；改色 ' + '、'.join(tinted) if tinted else ''}{'；加了圍巾' if args.scarf is not None else ''}{'；加了短斗篷' if args.cape is not None else ''}）、身高 {height:.2f} m、{args.out.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
