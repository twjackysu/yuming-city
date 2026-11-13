"""冒險者服裝的試作（D-262、D-263）：在「做好的角色 glb」上長出衣服與甲片，算四個角度的預覽圖。
**還沒有接進遊戲**——獨立的試作；Jacky 說方向可以之後，再把各段搬進 vrm_character.py（docs/NEXT.md「0000」最上面）。

  python3 -I tools/blender/armor_proto.py build/art/characters/sheila/sheila.glb <輸出.png>            # 席菈
  python3 -I tools/blender/armor_proto.py build/art/characters/noen/noen.glb <輸出.png> --noen        # 諾恩
  … --pose=run --frame=6 ／ --pose=light_attack_01 --frame=8                                          # 換動作看會不會穿出來
  輸出 <輸出>_0.png～_3.png（正面兩張、背面兩張；一次約 15 秒）。先跑 scripts/gen_art.sh 才有 glb。

第二版的方向（Jacky 看了第一版「全身白色鐵筒」說還是很醜之後）：**布為主、甲片是點綴；大色塊＋金色的邊線；要有腰身。**
- 席菈：貼身的白色胸甲、小肩甲、深藍色到小腿的長下襬（前面開衩）、金邊、合腳的白色長靴、皮帶。
- 諾恩：黑色連帽外套（原本的連帽上衣改色）、黑色長下襬、斜背的皮帶、只有右手有護甲、皮靴、紅圍巾。
量法跟短斗篷一樣：從骨頭的軸往外打射線、取限制距離內最遠的一次打中（衣服是單層的面），抹平之後再往外推一點。
底下衣服的重新上色這裡只是預覽（材質上接一個 ColorRamp）；真的要用得把對照表寫進貼圖。
"""
import math
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

args = [a for a in sys.argv[1:] if not a.startswith("-")]
src, out = args[-2], args[-1]
STYLE = "noen" if "--noen" in sys.argv else "sheila"
POSE = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--pose=")), "idle")
FRAME = int(next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--frame=")), "1"))
GOLD = (0.83, 0.64, 0.22)
# 色票：(底色, 邊, 邊旁的細線)。貼圖一欄一個色票；v 靠近 0 或 1 是邊、往內一點是細線、中間是底色
PAL = {
    "plate": ((0.93, 0.93, 0.91), GOLD, (0.50, 0.38, 0.14)),
    "blue": ((0.11, 0.18, 0.40), GOLD, (0.93, 0.93, 0.91)),
    "leather": ((0.30, 0.19, 0.11), (0.16, 0.10, 0.06), GOLD),
    "gold": (GOLD, (0.60, 0.44, 0.12), (0.95, 0.85, 0.50)),
    "black": ((0.045, 0.045, 0.058), (0.42, 0.09, 0.07), (0.80, 0.80, 0.78)),
    "iron": ((0.20, 0.21, 0.25), (0.66, 0.50, 0.20), (0.10, 0.10, 0.12)),
}
ORDER = list(PAL)
TAU = math.tau
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
scene = bpy.context.scene
arm = next(o for o in scene.objects if o.type == "ARMATURE")
for o in list(scene.objects):
    if o.type == "MESH" and (o.name.startswith("Cape") and STYLE == "sheila" or not any(m.type == "ARMATURE" for m in o.modifiers)):
        bpy.data.objects.remove(o)      # 席菈第 106 輪的短斗篷從正面看像圍兜：這一版不用
body = bpy.data.objects["Body"]
bvh = BVHTree.FromPolygons([body.matrix_world @ v.co for v in body.data.vertices],
                           [list(p.vertices) for p in body.data.polygons])


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
    for dz, grow in ((0.0, 0.014),):
        ring_hi = torso_ring(lambda d: z_mid + amp * math.cos(math.atan2(d.y, d.x) - hi) + 0.022, limit=0.22, cap=0.19)
        ring_lo = torso_ring(lambda d: z_mid + amp * math.cos(math.atan2(d.y, d.x) - hi) - 0.022, limit=0.22, cap=0.19)
        rows = [[Vector((0.0, y0, z)) + d * (r + grow) for d, z, r in ring] for ring in (ring_hi, ring_lo)]
        add_grid(rows, [0.0, 1.0], torso_w, pal)


knee_z, ankle_z = head("LeftLowerLeg").z, head("LeftFoot").z
if STYLE == "sheila":
    boots("plate", "plate")
    for s in ("Left", "Right"):
        bracer(s, "plate")
        pauldron(s, "plate", 0.80)
    breastplate("plate")
    collar("blue")
    waist = belt("leather", sp.z - 0.012)
    tails("blue", sp.z - 0.03, ankle_z + 0.20, 34.0, 0.15, waist)
else:
    boots("leather", "leather", tight=0.012)
    bracer("Right", "iron")
    bracer("Left", "leather")
    pauldron("Right", "iron", 0.92)
    waist = belt("leather", sp.z - 0.03)
    strap("leather", 0.5 * (sp.z + uc.z) + 0.02, 0.105, Vector((-LEFT_X * 0.8, FRONT * 0.6, 0.0)))
    tails("black", sp.z - 0.05, knee_z - 0.12, 30.0, 0.10, waist)

me = bpy.data.meshes.new("Outfit")
me.from_pydata([tuple(p) for p in P], [], F)
me.update()
ob = bpy.data.objects.new("Outfit", me)
scene.collection.objects.link(ob)
uv = me.uv_layers.new(name="UVMap")
for poly, quad in zip(me.polygons, UV):
    poly.use_smooth = True
    for loop, st in zip(poly.loop_indices, quad):
        uv.data[loop].uv = st
have = {b.name for b in arm.data.bones}
for i, weights in enumerate(G):
    for bone, w in weights.items():
        if w > 0.0:
            name = bone if bone in have else "UpperChest"
            (ob.vertex_groups.get(name) or ob.vertex_groups.new(name=name)).add([i], w, "ADD")
ob.parent = arm
ob.modifiers.new("Armature", "ARMATURE").object = arm
print(f"[outfit] {STYLE}：{len(P)} 個點、{len(F) * 2} 個三角面")

# 貼圖：一欄一個色票；v 兩端 6% 是邊、再往內 3% 是細線、中間是底色
W8, H = 8 * len(ORDER), 128
px = []
for yy in range(H):
    v = (yy + 0.5) / H
    e = min(v, 1.0 - v)
    for xx in range(W8):
        base, trim, line = PAL[ORDER[xx // 8]]
        col = trim if e < 0.06 else line if e < 0.09 else base
        px.extend([col[0], col[1], col[2], 1.0])
img = bpy.data.images.new("outfit", W8, H)
img.pixels = px
mat = bpy.data.materials.new("Outfit")
mat.use_nodes = True
bsdf = mat.node_tree.nodes["Principled BSDF"]
tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = img
tex.interpolation = "Closest"
mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.6
me.materials.append(mat)


def ramp(material, stops):
    """預覽用：把這個材質的貼圖照明暗重新上色（之後在匯出那一步用同樣的對照表重畫貼圖）。原本乘在上面的顏色拿掉。"""
    nt = material.node_tree
    for node in nt.nodes:
        if node.type in ("MIX", "MIX_RGB"):
            for inp in node.inputs:
                if not inp.is_linked and getattr(inp, "type", "") == "RGBA":
                    inp.default_value = (1.0, 1.0, 1.0, 1.0)
    for node in [n for n in nt.nodes if n.type == "TEX_IMAGE"]:
        for link in list(node.outputs["Color"].links):
            cr = nt.nodes.new("ShaderNodeValToRGB")
            while len(cr.color_ramp.elements) < len(stops):
                cr.color_ramp.elements.new(0.5)
            for el, (pos, col) in zip(cr.color_ramp.elements, stops):
                el.position, el.color = pos, (*col, 1.0)
            to = link.to_socket
            nt.links.remove(link)
            nt.links.new(node.outputs["Color"], cr.inputs["Fac"])
            nt.links.new(cr.outputs["Color"], to)


for m in bpy.data.materials:
    if STYLE == "noen":
        if "Shoes" in m.name:
            ramp(m, [(0.0, (0.06, 0.04, 0.03)), (0.6, (0.26, 0.17, 0.10))])
        elif "Tops" in m.name:
            ramp(m, [(0.0, (0.008, 0.008, 0.012)), (0.6, (0.035, 0.035, 0.045)), (1.0, (0.075, 0.075, 0.09))])   # 連帽上衣 → 黑色外套
    elif "Bottoms" in m.name:
        ramp(m, [(0.0, (0.06, 0.10, 0.25)), (0.25, (0.11, 0.18, 0.40))])       # 百褶裙改成跟長下襬同一個藍（跑步時從下襬穿出來也看不出來）
    elif "Shoes" in m.name:
        ramp(m, [(0.0, (0.55, 0.57, 0.62)), (0.25, (0.92, 0.92, 0.91))])       # 棕色皮鞋 → 白靴
    elif "Tops" in m.name:
        ramp(m, [(0.0, (0.70, 0.72, 0.78)), (0.3, (0.88, 0.88, 0.89)), (0.8, (0.93, 0.93, 0.92))])   # 背心也改成白的（從胸甲邊上露出來才不會是一塊藍）

act = bpy.data.actions.get(POSE)
if act is not None and arm.animation_data is not None:
    arm.animation_data.action = act
    try:
        arm.animation_data.action_slot = act.slots[0]
    except Exception:
        pass
scene.frame_set(FRAME)
if "--no-render" not in sys.argv:
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.20, 0.20, 0.22, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.6
    for name, rot in (("key", (50, 0, 150 if FRONT > 0 else -30)), ("back", (55, 0, -40 if FRONT > 0 else 140))):
        ld = bpy.data.lights.new(name, "SUN")
        ld.energy = 2.2
        lo = bpy.data.objects.new(name, ld)
        scene.collection.objects.link(lo)
        lo.rotation_euler = tuple(math.radians(v) for v in rot)
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
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
    print("[outfit] RENDERED")
