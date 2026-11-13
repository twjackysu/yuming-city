"""冒險者服裝第二版（D-263、D-264）：在現成角色身上長出衣服與甲片——布為主、甲片是點綴、大色塊＋金邊。
由 vrm_character.py 的 --outfit sheila|noen 呼叫（第 107 輪從試作 armor_proto.py 搬過來，幾何沒有改）。

- 席菈：貼身的白色胸甲、小肩甲、深藍色到小腿的長下襬（前面開衩）、金邊、合腳的白色長靴、皮帶。
- 諾恩：黑色連帽外套（原本的連帽上衣改色）、黑色長下襬、斜背的皮帶、只有右手有護甲、皮靴。
量法跟短斗篷一樣：從骨頭的軸往外打射線、取限制距離內最遠的一次打中（VRoid 的衣服是單層的面、底下的身體是挖掉的），
抹平之後再往外推一點。整套是一個網格、一個材質（MATERIAL）、一張色票貼圖（texture_rows()）。
底下原本的衣服不刪，照明暗重新上色（recolor()：直接重畫貼圖，不是乘一個顏色）。
原創的同類設計：不照抄任何作品的角色；全年齡。
"""
import math

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

MATERIAL = "Outfit"
GOLD = (0.83, 0.64, 0.22)
# 色票（sRGB 0～1）：(底色, 邊, 邊旁的細線)。貼圖一欄一個色票；v 靠近 0 或 1 是邊、往內一點是細線、中間是底色
PAL = {
    "plate": ((0.93, 0.93, 0.91), GOLD, (0.50, 0.38, 0.14)),
    "blue": ((0.11, 0.18, 0.40), GOLD, (0.93, 0.93, 0.91)),
    "leather": ((0.30, 0.19, 0.11), (0.16, 0.10, 0.06), GOLD),
    "gold": (GOLD, (0.60, 0.44, 0.12), (0.95, 0.85, 0.50)),
    "black": ((0.075, 0.075, 0.095), (0.42, 0.09, 0.07), (0.80, 0.80, 0.78)),   # 不要全黑：吃場景的光之後還看得出褶子
    "iron": ((0.20, 0.21, 0.25), (0.66, 0.50, 0.20), (0.10, 0.10, 0.12)),
}
ORDER = list(PAL)
SWATCH_W, TEX_H = 16, 128   # 一個色票 16 px 寬（UV 取在正中間，線性取樣與 mipmap 都不會沾到隔壁）
# 底下的衣服重新上色：材質名稱含這個字的，貼圖照「線性亮度 → 顏色」查表重畫（停點的顏色是線性值）。
RECOLOR = {
    "sheila": [
        # 百褶裙 → 跟長下襬同一個藍（PAL["blue"] 的 sRGB (0.11, 0.18, 0.40) 換成線性；試作寫成 sRGB 的數字，裙子比下襬淺一截）
        ("Bottoms", [(0.0, (0.006, 0.014, 0.070)), (0.25, (0.0116, 0.0273, 0.133))]),
        ("Shoes", [(0.0, (0.55, 0.57, 0.62)), (0.25, (0.92, 0.92, 0.91))]),       # 棕色皮鞋 → 白靴
        ("Tops", [(0.0, (0.70, 0.72, 0.78)), (0.3, (0.88, 0.88, 0.89)), (0.8, (0.93, 0.93, 0.92))]),   # 背心 → 白（從胸甲邊上露出來才不會是一塊藍）
    ],
    "noen": [
        ("Shoes", [(0.0, (0.06, 0.04, 0.03)), (0.6, (0.26, 0.17, 0.10))]),        # → 深棕皮靴
        # 連帽上衣 → 黑色外套（最亮的地方跟下襬的黑差不多：sRGB 0.2 左右；試作的 0.075 在遊戲裡是灰的）
        ("Tops", [(0.0, (0.004, 0.004, 0.007)), (0.6, (0.016, 0.016, 0.022)), (1.0, (0.034, 0.034, 0.044))]),
    ],
}
TAU = math.tau
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))


def texture_rows():
    """色票貼圖，一列一列的 (r, g, b)（0～255）：v 兩端 6% 是邊、再往內 3% 是細線、中間是底色（上下對稱）。"""
    rows = []
    for yy in range(TEX_H):
        v = (yy + 0.5) / TEX_H
        e = min(v, 1.0 - v)
        row = []
        for xx in range(SWATCH_W * len(ORDER)):
            base, trim, line = PAL[ORDER[xx // SWATCH_W]]
            col = trim if e < 0.06 else line if e < 0.09 else base
            row.append(tuple(max(0, min(255, round(ch * 255.0))) for ch in col))
        rows.append(row)
    return rows


def recolor(style):
    """把底下衣服的貼圖照 RECOLOR 重畫（做成新的圖再接回材質——匯出器對沒改過的原圖會直接沿用原檔）。回傳改了的材質名。"""
    import numpy as np
    done, made = [], {}   # made：同一個材質裡同一張圖可能接了兩個節點（顏色、透明度），只重畫一次
    for m in bpy.data.materials:
        stops = next((s for key, s in RECOLOR.get(style, []) if key.lower() in m.name.lower()), None)
        if stops is None or m.node_tree is None:
            continue
        for node in m.node_tree.nodes:
            img = getattr(node, "image", None)
            if node.type != "TEX_IMAGE" or img is None or img.colorspace_settings.name == "Non-Color":
                continue
            w, h = img.size
            if w == 0 or h == 0:
                continue
            if (m.name, img.name) in made:
                node.image = made[(m.name, img.name)]
                continue
            px = np.empty(w * h * 4, dtype=np.float32)
            img.pixels.foreach_get(px)
            px = px.reshape(-1, 4)
            rgb = px[:, :3].astype(np.float64)
            lin = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
            lum = lin @ np.array([0.2126, 0.7152, 0.0722])
            pos = [s[0] for s in stops]
            out = np.stack([np.interp(lum, pos, [s[1][k] for s in stops]) for k in range(3)], axis=1)
            out = np.where(out <= 0.0031308, out * 12.92, 1.055 * np.maximum(out, 1e-9) ** (1.0 / 2.4) - 0.055)
            new = bpy.data.images.new(img.name.split(".")[0] + "_recolor", w, h, alpha=True)
            new.pixels.foreach_set(np.concatenate([out, px[:, 3:4]], axis=1).astype(np.float32).ravel())
            new.update()
            made[(m.name, img.name)] = new
            node.image = new
            done.append(m.name)
    return done


def build_outfit(arm, body_meshes, style):
    """回傳綁在骨架上的網格（材質 MATERIAL、有 UV）。body_meshes＝只給身體（不含臉、頭髮、圍巾）。骨架在休息姿勢。"""
    verts, polys = [], []
    for o in body_meshes:
        base = len(verts)
        verts.extend(o.matrix_world @ v.co for v in o.data.vertices)
        polys.extend([base + i for i in p.vertices] for p in o.data.polygons)
    bvh = BVHTree.FromPolygons(verts, polys)

    def head(bone):
        return arm.matrix_world @ arm.data.bones[bone].head_local

    FRONT = 1.0 if head("LeftToes").y > head("LeftFoot").y else -1.0   # 臉朝 +Y 還是 −Y
    LEFT_X = -1.0 if head("LeftUpperArm").x < 0 else 1.0
    sp, ch, uc, nk = head("Spine"), head("Chest"), head("UpperChest"), head("Neck")
    hips, shz = head("Hips"), head("LeftUpperArm").z
    y0 = 0.5 * (sp.y + uc.y)

    def reach(origin, d, limit, least=0.0):
        far, start, travelled = least, origin.copy(), 0.0
        for _ in range(12):
            hit = bvh.ray_cast(start, d, limit - travelled)
            if hit[0] is None:
                break
            travelled += hit[3] + 1e-4
            far = max(far, travelled)
            start = origin + d * travelled
        return far

    def smooth_ring(r, passes=2):
        n = len(r)
        for _ in range(passes):
            r = [(r[(i - 2) % n] + 2 * r[(i - 1) % n] + 3 * r[i] + 2 * r[(i + 1) % n] + r[(i + 2) % n]) / 9.0 for i in range(n)]
        return r

    def torso_w(p):
        if p.z < sp.z:
            k = max(0.0, min(1.0, (p.z - hips.z) / max(1e-4, sp.z - hips.z)))
            return {"Hips": 1.0 - k, "Spine": k}
        if p.z < ch.z:
            k = (p.z - sp.z) / (ch.z - sp.z)
            return {"Spine": 1.0 - k, "Chest": k}
        k = max(0.0, min(1.0, (p.z - ch.z) / (uc.z - ch.z)))
        return {"Chest": 1.0 - k, "UpperChest": k}

    P, F, UV, G = [], [], [], []

    def add_grid(rows, vs, weights, pal, closed=True, edge=False):
        """rows[j][i]＝第 j 圈第 i 個點；vs[j]＝那一圈的貼圖 v；weights＝一組權重、每圈一組、或 f(點)。edge＝沒接起來的兩邊各一條邊線。"""
        base, n, u = len(P), len(rows[0]), (ORDER.index(pal) + 0.5) / len(ORDER)
        for j, ring in enumerate(rows):
            for p in ring:
                P.append(p)
                G.append(weights(p) if callable(weights) else weights[j] if isinstance(weights, list) else weights)
        span = n if closed else n - 1
        for j in range(len(rows) - 1):
            for i in range(span):
                i2 = (i + 1) % n
                F.append([base + j * n + i, base + j * n + i2, base + (j + 1) * n + i2, base + (j + 1) * n + i])
                va, vb = (0.02, 0.02) if edge and i in (0, span - 1) else (vs[j], vs[j + 1])
                UV.append([(u, va), (u, va), (u, vb), (u, vb)])

    def limb(a, b, ts, seg, e1, e2, limit, offset, w, pal, vs=None, shift=None):
        """沿著 a→b 這根骨頭的一段管狀的東西（靴筒、護臂）。offset(t, d)＝離身體表面多遠；shift(j, d)＝那一圈的點沿骨頭方向挪多少。"""
        rows, radii = [], []
        for t in ts:
            c = a + (b - a) * t
            raw = [reach(c, e1 * math.cos(TAU * i / seg) + e2 * math.sin(TAU * i / seg), limit, 0.02) for i in range(seg)]
            radii.append([max(a_, b_) for a_, b_ in zip(raw, smooth_ring(raw))])   # 抹平之後不准比量到的小（小腿肚會穿出來）
        axis = (b - a).normalized()
        for j, t in enumerate(ts):
            c = a + (b - a) * t
            ring = []
            for i in range(seg):
                d = e1 * math.cos(TAU * i / seg) + e2 * math.sin(TAU * i / seg)
                p = c + d * (radii[j][i] + offset(t, d))
                if shift is not None:
                    p += axis * shift(j, d)
                ring.append(p)
            rows.append(ring)
        n = len(ts) - 1
        add_grid(rows, vs or [j / n for j in range(len(ts))], w, pal)

    def pauldron(side, pal, scale=0.86):
        """兩層肩甲：上層固定在肩（鎖骨），下層一半跟著上臂。只有外緣一圈邊線。"""
        out_dir = X * (LEFT_X if side == "Left" else -LEFT_X)
        joint = head(side + "UpperArm")
        for size, centre, a_in, wts in ((scale, joint + out_dir * 0.012 + Z * 0.012, 52.0, {side + "Shoulder": 1.0}),
                                        (scale * 0.84, joint + out_dir * 0.056 - Z * 0.02, 26.0, {side + "Shoulder": 0.55, side + "UpperArm": 0.45})):
            pole, e2 = (out_dir * 0.55 + Z * 0.83).normalized(), (out_dir * 0.83 - Z * 0.55).normalized()
            seg, rings, rows = 20, 6, []
            for j in range(rings + 1):
                ring = []
                for i in range(seg):
                    bb = TAU * i / seg
                    a_max = math.radians(a_in + (104.0 - a_in) * (0.5 + 0.5 * math.sin(bb)) ** 0.8)
                    aa = a_max * j / rings
                    d = pole * math.cos(aa) + (Y * math.cos(bb) + e2 * math.sin(bb)) * math.sin(aa)
                    ring.append(centre + Vector((d.x * 0.108, d.y * 0.102, d.z * 0.080)) * size)
                rows.append(ring)
            add_grid(rows, [0.5 + 0.5 * (j / rings) ** 1.6 for j in range(rings + 1)], wts, pal)

    def boots(pal, cuff_pal, tight=0.006):
        """合腳的長靴：膝下到腳踝貼著腿；靴口一圈反折（正面尖起來蓋住膝蓋）。"""
        for side in ("Left", "Right"):
            knee, ankle = head(side + "LowerLeg"), head(side + "Foot")
            limb(knee, ankle, [0.07, 0.2, 0.35, 0.5, 0.65, 0.8, 0.94, 1.07], 20, X, Y, 0.092,
                 lambda t, d: tight + 0.012 * max(0.0, (t - 0.85) / 0.2), {side + "LowerLeg": 1.0}, pal, vs=[0.5] * 8)
            limb(knee, ankle, [0.02, 0.045, 0.10, 0.155, 0.18], 20, X, Y, 0.092,
                 lambda t, d: tight + 0.012, {side + "LowerLeg": 1.0}, cuff_pal, vs=[0.0, 0.25, 0.5, 0.75, 1.0],
                 shift=lambda j, d: -0.065 * max(0.0, d.y * FRONT) ** 2 * max(0.0, 1.0 - j / 2.0))

    def bracer(side, pal, tight=0.006):
        elbow, wrist = head(side + "LowerArm"), head(side + "Hand")
        limb(elbow, wrist, [0.14, 0.19, 0.4, 0.6, 0.8, 0.9, 0.95], 16, Y, Z, 0.07,
             lambda t, d: tight + 0.008 * max(0.0, 1.0 - (t - 0.14) / 0.2) + 0.003 * max(0.0, d.z) ** 3,
             {side + "LowerArm": 1.0}, pal, vs=[0.0, 0.2, 0.5, 0.5, 0.5, 0.8, 1.0],
             shift=lambda j, d: -0.035 * max(0.0, d.z) ** 2 * max(0.0, 1.0 - j / 2.0))

    def torso_ring(z_of, seg=40, limit=0.2, cap=0.168):
        """繞身體一圈：每個方向在自己的高度量到的半徑（抹平過）。回傳 [(方向, 高度, 半徑)]。"""
        dirs = [Vector((math.cos(TAU * i / seg), math.sin(TAU * i / seg), 0.0)) for i in range(seg)]
        zs = [z_of(d) for d in dirs]
        rr = smooth_ring([min(reach(Vector((0.0, y0, z)), d, limit, 0.06), cap) for d, z in zip(dirs, zs)], 3)
        return list(zip(dirs, zs, rr))

    def breastplate(pal, tight=0.012):
        """貼身的胸甲：腰到鎖骨下面；兩側的上緣在腋下；下緣正面往下尖；正面一條稜線。"""
        nrow, z_top, z_side, z_bot = 11, uc.z + 0.068, shz - 0.088, sp.z + 0.005
        cols = []
        for d, _z, _r in torso_ring(lambda d: z_bot):
            top = z_side + (z_top - z_side) * (1.0 - abs(d.x) ** 1.6)
            bot = z_bot - 0.05 * max(0.0, d.y * FRONT) ** 5
            zs = [bot + (top - bot) * j / (nrow - 1) for j in range(nrow)]
            cols.append((d, zs, [min(reach(Vector((0.0, y0, z)), d, 0.2, 0.06), 0.165) for z in zs]))
        for j in range(nrow):
            ring = smooth_ring([c[2][j] for c in cols], 3)
            for i, c in enumerate(cols):
                c[2][j] = ring[i]
        for d, zs, rr in cols:
            for _ in range(2):
                rr[:] = [(rr[max(0, j - 1)] + 2 * rr[j] + rr[min(nrow - 1, j + 1)]) / 4.0 for j in range(nrow)]
            if d.y * FRONT > 0.2:           # 正面往下收腰，但不准一格縮超過 1.8 cm（一整片的胸甲，不是貼著身體的凹凸）
                for j in range(nrow - 2, -1, -1):
                    rr[j] = max(rr[j], rr[j + 1] - 0.018)
        rows = [[Vector((0.0, y0, zs[j])) + d * (rr[j] + tight + 0.006 * max(0.0, d.y * FRONT) ** 8) for d, zs, rr in cols] for j in range(nrow)]
        add_grid(rows, [j / (nrow - 1) for j in range(nrow)], torso_w, pal)

    def collar(pal):
        """立領：脖子根一圈往外張的領子，前面低一點。"""
        z_c, seg = nk.z + 0.006, 32
        rc = smooth_ring([min(max(reach(Vector((0.0, nk.y, z_c)), Vector((math.cos(TAU * i / seg), math.sin(TAU * i / seg), 0.0)), 0.1), 0.045), 0.085) for i in range(seg)])
        rows = []
        for dz, grow in ((-0.028, 0.022), (0.0, 0.016), (0.03, 0.026)):
            ring = []
            for i in range(seg):
                d = Vector((math.cos(TAU * i / seg), math.sin(TAU * i / seg), 0.0))
                ring.append(Vector((0.0, nk.y, z_c + dz - (0.02 if dz > 0 else 0.0) * max(0.0, d.y * FRONT))) + d * (rc[i] + grow))
            rows.append(ring)
        add_grid(rows, [0.5, 0.72, 1.0], {"Neck": 0.3, "UpperChest": 0.7}, pal)

    def belt(pal, z_mid, height=0.045, buckle=True):
        ring = torso_ring(lambda d: z_mid, limit=0.24, cap=0.2)
        rows = [[Vector((0.0, y0, z_mid + dz)) + d * (r + grow) for d, _z, r in ring] for dz, grow in ((height / 2, 0.019), (0.0, 0.023), (-height / 2, 0.019))]
        add_grid(rows, [0.3, 0.5, 0.7], torso_w, pal)
        if buckle:      # 正面一個金色的扣環
            d, _z, r = max(ring, key=lambda c: c[0].y * FRONT)
            c0 = Vector((0.0, y0, z_mid)) + d * (r + 0.031)
            rows = [[c0 + X * sx * 0.032 + Z * sz * 0.03 for sx in (-1.0, 0.0, 1.0)] for sz in (1.0, 0.0, -1.0)]
            add_grid(rows, [0.5, 0.5, 0.5], torso_w, "gold", closed=False)
        return ring

    def tails(pal, z_top, z_hem, open_deg, flare, waist):
        """長下襬：從腰帶垂到 z_hem，前面開衩 ±open_deg；越往下越張開、有褶子；下緣一條寬邊、開衩的兩邊各一條邊線。跟骨盆與兩條大腿。"""
        ncol = 40
        phis = [open_deg, open_deg + 2.5] + [open_deg + 2.5 + (355.0 - 2 * open_deg) * i / (ncol - 1) for i in range(1, ncol - 1)] + [360.0 - open_deg - 2.5, 360.0 - open_deg]
        ts = [0.0, 0.1, 0.22, 0.36, 0.5, 0.64, 0.76, 0.86, 0.93, 1.0]
        r0 = {}
        for phi in phis:
            th = math.pi / 2 * FRONT + math.radians(phi)
            d = Vector((math.cos(th), math.sin(th), 0.0))
            near = min(waist, key=lambda c: (c[0] - d).length)
            r0[phi] = near[2] + 0.018
        rows, wrows = [], []
        for t in ts:
            ring, wr = [], []
            for phi in phis:
                th = math.pi / 2 * FRONT + math.radians(phi)
                d = Vector((math.cos(th), math.sin(th), 0.0))
                back = max(0.0, -math.cos(math.radians(phi)))
                z = z_top + (z_hem - 0.05 * back - z_top) * t
                r = r0[phi] + flare * (0.75 + 0.25 * back) * t ** 0.85
                r = max(r, reach(Vector((0.0, hips.y, z)), d, 0.32) + 0.03)      # 底下的百褶裙不准穿出來
                r *= 1.0 + 0.055 * math.sin(math.radians(phi) * 9.0) * t ** 0.7     # 褶子
                ring.append(Vector((0.0, hips.y, z)) + d * r)
                f_left = 0.5 + 0.5 * max(-1.0, min(1.0, d.x * LEFT_X * 2.5))
                leg = 0.6 * t
                wr.append({"Hips": 1.0 - leg, "LeftUpperLeg": leg * f_left, "RightUpperLeg": leg * (1.0 - f_left)})
            rows.append(ring)
            wrows.append(wr)
        base = len(P)
        add_grid(rows, [0.5 + 0.5 * t for t in ts], {"Hips": 1.0}, pal, closed=False, edge=True)
        for j, wr in enumerate(wrows):
            for i, w in enumerate(wr):
                G[base + j * len(phis) + i] = w

    def strap(pal, z_mid, amp, toward):
        """斜背的皮帶：一圈斜的帶子（高的那一邊朝 toward）。"""
        hi = math.atan2(toward.y, toward.x)
        ring_hi = torso_ring(lambda d: z_mid + amp * math.cos(math.atan2(d.y, d.x) - hi) + 0.022, limit=0.22, cap=0.19)
        ring_lo = torso_ring(lambda d: z_mid + amp * math.cos(math.atan2(d.y, d.x) - hi) - 0.022, limit=0.22, cap=0.19)
        rows = [[Vector((0.0, y0, z)) + d * (r + 0.014) for d, z, r in ring] for ring in (ring_hi, ring_lo)]
        add_grid(rows, [0.0, 1.0], torso_w, pal)

    knee_z, ankle_z = head("LeftLowerLeg").z, head("LeftFoot").z
    if style == "sheila":
        boots("plate", "plate")
        for s in ("Left", "Right"):
            bracer(s, "plate")
            pauldron(s, "plate", 0.80)
        breastplate("plate")
        collar("blue")
        waist = belt("leather", sp.z - 0.012)
        tails("blue", sp.z - 0.03, ankle_z + 0.20, 34.0, 0.15, waist)
    elif style == "noen":
        boots("leather", "leather", tight=0.012)
        bracer("Right", "iron")
        bracer("Left", "leather")
        pauldron("Right", "iron", 0.92)
        waist = belt("leather", sp.z - 0.03)
        strap("leather", 0.5 * (sp.z + uc.z) + 0.02, 0.105, Vector((-LEFT_X * 0.8, FRONT * 0.6, 0.0)))
        tails("black", sp.z - 0.05, knee_z - 0.12, 30.0, 0.10, waist)
    else:
        raise SystemExit(f"[outfit] 沒有這一套：{style}")

    me = bpy.data.meshes.new("Outfit")
    me.from_pydata([tuple(p) for p in P], [], F)
    me.update()
    ob = bpy.data.objects.new("Outfit", me)
    bpy.context.scene.collection.objects.link(ob)
    uv = me.uv_layers.new(name="UVMap")
    for poly, quad in zip(me.polygons, UV):
        poly.use_smooth = True
        for loop, st in zip(poly.loop_indices, quad):
            uv.data[loop].uv = st
    me.materials.append(bpy.data.materials.new(MATERIAL))
    have = {b.name for b in arm.data.bones}
    for i, weights in enumerate(G):
        for bone, w in weights.items():
            if w > 0.0:
                name = bone if bone in have else "UpperChest" if "UpperChest" in have else "Chest"
                (ob.vertex_groups.get(name) or ob.vertex_groups.new(name=name)).add([i], w, "ADD")
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    print(f"[outfit] {style}：{len(P)} 個點、{len(F) * 2} 個三角面")
    return ob
