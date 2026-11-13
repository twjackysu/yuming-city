"""盔甲試作（D-262）：在「做好的角色 glb」上長出脛甲、手甲、肩甲、胸甲、腰帶與裙甲，算四個角度的預覽圖。
**還沒有接進遊戲**——這支是獨立的試作，下一步是把甲片那幾段搬進 vrm_character.py（docs/NEXT.md「0000」第 0 項）。

  python3 -I tools/blender/armor_proto.py build/art/characters/sheila/sheila.glb <輸出.png>            # 席菈：白＋藍
  python3 -I tools/blender/armor_proto.py build/art/characters/noen/noen.glb <輸出.png> --noen        # 諾恩：深鐵＋暗紅，只有右肩
  … --pose=run --frame=6 ／ --pose=light_attack_01 --frame=8                                          # 換動作看會不會穿出來
  輸出 <輸出>_0.png～_3.png（正面兩張、背面兩張；一次約 13 秒）。先跑 scripts/gen_art.sh 才有 glb。

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
if STYLE == "sheila":
    BASE = (0.90, 0.90, 0.88)     # 白色甲片
    TRIM = (0.20, 0.30, 0.52)     # 藍色滾邊
    STEEL = (0.55, 0.58, 0.63)    # 邊上一條鋼色的細線
else:
    BASE = (0.115, 0.12, 0.14)    # 深色的鐵
    TRIM = (0.40, 0.085, 0.07)    # 暗紅滾邊（跟圍巾同色）
    STEEL = (0.42, 0.36, 0.25)    # 一條舊黃銅色的細線
POSE = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--pose=")), "idle")
FRAME = int(next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--frame=")), "1"))
TAU = math.tau
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
scene = bpy.context.scene
arm = next(o for o in scene.objects if o.type == "ARMATURE")
for o in list(scene.objects):
    if o.type == "MESH" and not any(m.type == "ARMATURE" for m in o.modifiers):
        bpy.data.objects.remove(o)
body = bpy.data.objects["Body"]
bvh = BVHTree.FromPolygons([body.matrix_world @ v.co for v in body.data.vertices],
                           [list(p.vertices) for p in body.data.polygons])


def head(bone):
    return arm.matrix_world @ arm.data.bones[bone].head_local


FRONT = 1.0 if head("LeftToes").y > head("LeftFoot").y else -1.0   # 臉朝 +Y 還是 −Y


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


P, F, UV, G = [], [], [], []


def add_grid(rows, vs, weights, closed=True):
    """rows[j][i]＝第 j 圈第 i 個點；vs[j]＝那一圈的貼圖 v；weights[j]＝那一圈的骨頭權重。"""
    base, n = len(P), len(rows[0])
    for j, ring in enumerate(rows):
        for p in ring:
            P.append(p)
            G.append(weights[j] if isinstance(weights, list) else weights)
    span = n if closed else n - 1
    for j in range(len(rows) - 1):
        for i in range(span):
            i2 = (i + 1) % n
            F.append([base + j * n + i, base + j * n + i2, base + (j + 1) * n + i2, base + (j + 1) * n + i])
            u0, u1 = i / span, (i + 1) / span
            UV.append([(u0, vs[j]), (u1, vs[j]), (u1, vs[j + 1]), (u0, vs[j + 1])])


def limb(a, b, ts, seg, e1, e2, limit, offset, w, shift=None):
    """沿著 a→b 這根骨頭的一段管狀甲片。offset(t, d)＝離身體表面多遠；shift(j, d)＝那一圈的點再沿骨頭方向挪多少。"""
    rows, radii = [], []
    for t in ts:
        c = a + (b - a) * t
        raw = [reach(c, e1 * math.cos(TAU * i / seg) + e2 * math.sin(TAU * i / seg), limit, 0.02) for i in range(seg)]
        radii.append([max(a_, b_) for a_, b_ in zip(raw, smooth_ring(raw))])
    for j in range(len(ts)):   # 沿著長度也抹平一次
        lo, hi = radii[max(0, j - 1)], radii[min(len(ts) - 1, j + 1)]
        radii[j] = [max(radii[j][i], (lo[i] + 2 * radii[j][i] + hi[i]) / 4.0) for i in range(seg)]
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
    add_grid(rows, [j / n for j in range(len(ts))], w)


for side, sx in (("Left", -1.0 if head("LeftUpperArm").x < 0 else 1.0), ("Right", 1.0 if head("LeftUpperArm").x < 0 else -1.0)):
    out_dir = X * sx
    # 脛甲：膝蓋上面一點到腳踝；上緣往外張、正面高起來蓋住膝蓋，正面一條稜線
    knee, ankle = head(side + "LowerLeg"), head(side + "Foot")
    limb(knee, ankle, [-0.02, 0.06, 0.2, 0.4, 0.6, 0.8, 0.94, 1.02], 20, X, Y, 0.092,
         lambda t, d: 0.011 + 0.014 * max(0.0, 1.0 - t / 0.14) + 0.012 * max(0.0, (t - 0.86) / 0.16) + 0.006 * max(0.0, d.y * FRONT) ** 4,
         {side + "LowerLeg": 1.0},
         shift=lambda j, d: -0.07 * max(0.0, d.y * FRONT) ** 2 * max(0.0, 1.0 - j / 2.0))
    # 手甲：手肘下面到手腕；手肘那一端往外張、外側往手肘伸出一個尖
    elbow, wrist = head(side + "LowerArm"), head(side + "Hand")
    limb(elbow, wrist, [0.1, 0.2, 0.4, 0.6, 0.8, 0.95], 16, Y, Z, 0.07,
         lambda t, d: 0.009 + 0.013 * max(0.0, 1.0 - (t - 0.1) / 0.2) + 0.004 * max(0.0, d.z) ** 3,
         {side + "LowerArm": 1.0},
         shift=lambda j, d: -0.045 * max(0.0, d.z) ** 2 * max(0.0, 1.0 - j / 2.0))
    # 肩甲：兩層。上層固定在肩（鎖骨），下層一半跟著上臂
    joint = head(side + "UpperArm")
    if STYLE == "noen" and side == "Left":
        continue
    for layer, (scale, centre, a_in, wts) in enumerate((
            (1.0, joint + out_dir * 0.014 + Z * 0.016, 58.0, {side + "Shoulder": 1.0}),
            (0.86, joint + out_dir * 0.062 - Z * 0.018, 28.0, {side + "Shoulder": 0.55, side + "UpperArm": 0.45}))):
        pole = (out_dir * 0.55 + Z * 0.83).normalized()
        e2 = (out_dir * 0.83 - Z * 0.55).normalized()   # 往外往下
        seg, rings, rows = 20, 6, []
        for j in range(rings + 1):
            ring = []
            for i in range(seg):
                bb = TAU * i / seg
                outward = 0.5 + 0.5 * math.sin(bb)                 # 1＝往外往下那一側、0＝靠脖子那一側
                a_max = math.radians(a_in + (104.0 - a_in) * outward ** 0.8)
                aa = a_max * j / rings
                d = pole * math.cos(aa) + (Y * math.cos(bb) + e2 * math.sin(bb)) * math.sin(aa)
                ring.append(centre + Vector((d.x * 0.108, d.y * 0.102, d.z * 0.080)) * scale)
            rows.append(ring)
        add_grid(rows, [0.12 + 0.88 * j / rings for j in range(rings + 1)], wts)

# 胸甲：腰到鎖骨下面；兩側的上緣在腋下（留出手臂），正面一條稜線
sp, ch, uc, shz = head("Spine"), head("Chest"), head("UpperChest"), head("LeftUpperArm").z
y0, seg, nrow = 0.5 * (sp.y + uc.y), 40, 11
z_bot, z_top, z_side = sp.z - 0.03, uc.z + 0.07, shz - 0.088
cols = []
for i in range(seg):
    th = TAU * i / seg
    d = Vector((math.cos(th), math.sin(th), 0.0))
    top = z_side + (z_top - z_side) * (1.0 - abs(d.x) ** 1.6)
    zs = [z_bot + (top - z_bot) * j / (nrow - 1) for j in range(nrow)]
    cols.append((d, zs, [min(reach(Vector((0.0, y0, z)), d, 0.2, 0.06), 0.165) for z in zs]))
for j in range(nrow):
    ring = smooth_ring([c[2][j] for c in cols], 3)
    for i in range(seg):
        cols[i][2][j] = ring[i]
for d, zs, rr in cols:      # 沿著高度抹平；正面往下不准一下子縮回去（做成一整片往腰收的胸甲，不是貼身的）
    for _ in range(2):
        rr[:] = [(rr[max(0, j - 1)] + 2 * rr[j] + rr[min(nrow - 1, j + 1)]) / 4.0 for j in range(nrow)]
    if d.y * FRONT > 0.2:
        for j in range(nrow - 2, -1, -1):
            rr[j] = max(rr[j], rr[j + 1] - 0.011)
rows, wts = [], []
for j in range(nrow):
    ring = []
    for d, zs, rr in cols:
        ring.append(Vector((0.0, y0, zs[j])) + d * (rr[j] + 0.013 + 0.007 * max(0.0, d.y * FRONT) ** 8))
    rows.append(ring)
    z = sum(c[1][j] for c in cols) / seg
    if z < ch.z:
        k = max(0.0, min(1.0, (z - sp.z) / (ch.z - sp.z)))
        wts.append({"Spine": 1.0 - k, "Chest": k})
    else:
        k = max(0.0, min(1.0, (z - ch.z) / (uc.z - ch.z)))
        wts.append({"Chest": 1.0 - k, "UpperChest": k})
add_grid(rows, [j / (nrow - 1) for j in range(nrow)], wts)
waist = [(c[0], c[2][0] + 0.013) for c in cols]

# 腰帶：胸甲下緣一圈藍色的寬帶
hips = head("Hips")
belt_top, belt_bot = z_bot + 0.012, z_bot - 0.04
rows = []
for z, grow in ((belt_top, 0.012), (0.5 * (belt_top + belt_bot), 0.016), (belt_bot, 0.012)):
    rows.append([Vector((0.0, y0, z)) + d * (max(r, reach(Vector((0.0, y0, z)), d, 0.22, 0.07) + 0.004) + grow) for d, r in waist])
add_grid(rows, [0.02, 0.03, 0.04], {"Hips": 0.6, "Spine": 0.4})

# 裙甲：腰帶底下掛五片（前兩片、左右各一片、後面一片），蓋在裙子外面，下緣是尖的
for centre_deg, width_deg, length in ((-24, 40, 0.215), (24, 40, 0.215), (-92, 56, 0.185), (92, 56, 0.185), (180, 76, 0.25)):
    ncol, nrow2, rows = 6, 6, []
    base_th = math.radians(90.0 * FRONT + centre_deg)
    for j in range(nrow2):
        t = j / (nrow2 - 1)
        ring = []
        zrow = belt_bot + 0.01 - length * t
        radius = 0.0
        for i in range(ncol):
            th = base_th + math.radians(width_deg) * (i / (ncol - 1) - 0.5)
            radius = max(radius, reach(Vector((0.0, hips.y, zrow)), Vector((math.cos(th), math.sin(th), 0.0)), 0.3, 0.09))
        for i in range(ncol):
            c = i / (ncol - 1) - 0.5
            th = base_th + math.radians(width_deg) * c * (1.0 - 0.25 * t)
            point = 0.05 * t * t * (1.0 - abs(c) * 2.0)                       # 下緣中間往下尖
            ring.append(Vector((0.0, hips.y, zrow - point)) + Vector((math.cos(th), math.sin(th), 0.0)) * (radius + 0.014 + 0.016 * t))
        rows.append(ring)
    add_grid(rows, [0.12 + 0.88 * j / (nrow2 - 1) for j in range(nrow2)], {"Hips": 1.0}, closed=False)

me = bpy.data.meshes.new("Armor")
me.from_pydata([tuple(p) for p in P], [], F)
me.update()
ob = bpy.data.objects.new("Armor", me)
scene.collection.objects.link(ob)
uv = me.uv_layers.new(name="UVMap")
for poly, quad in zip(me.polygons, UV):
    poly.use_smooth = True
    for loop, st in zip(poly.loop_indices, quad):
        uv.data[loop].uv = st
have = {b.name for b in arm.data.bones}
for i, weights in enumerate(G):
    for bone, w in weights.items():
        name = bone if bone in have else "UpperChest"
        (ob.vertex_groups.get(name) or ob.vertex_groups.new(name=name)).add([i], w, "ADD")
ob.parent = arm
ob.modifiers.new("Armature", "ARMATURE").object = arm
print(f"[armor] {len(P)} 個點、{len(F) * 2} 個三角面")

# 貼圖：v 靠近 0 或 1 的地方是藍色滾邊（旁邊一條鋼色細線），中間是白色
img = bpy.data.images.new("armor", 8, 64)
px = []
for yy in range(64):
    v = (yy + 0.5) / 64          # 圖的 y 往上＝uv 的 v
    edge = min(v, 1.0 - v)
    col = TRIM if edge < 0.09 else STEEL if edge < 0.125 else BASE
    px.extend([col[0], col[1], col[2], 1.0] * 8)
img.pixels = px
mat = bpy.data.materials.new("Armor")
mat.use_nodes = True
bsdf = mat.node_tree.nodes["Principled BSDF"]
tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = img
tex.interpolation = "Closest"
mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.55
me.materials.append(mat)


def ramp(material, stops):
    """預覽用：把這個材質的貼圖照明暗重新上色（之後在匯出那一步用同樣的對照表重畫貼圖）。"""
    nt = material.node_tree
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
            ramp(m, [(0.0, (0.05, 0.045, 0.045)), (0.6, (0.20, 0.16, 0.13))])
        continue
    if "Bottoms" in m.name:
        ramp(m, [(0.0, (0.40, 0.46, 0.60)), (0.16, (0.92, 0.92, 0.91))])       # 深藍百褶裙 → 白色戰裙、褶子的暗處帶藍灰
    elif "Shoes" in m.name:
        ramp(m, [(0.0, (0.52, 0.55, 0.62)), (0.25, (0.90, 0.90, 0.90))])       # 棕色皮鞋 → 白靴
    elif "Tops" in m.name:
        ramp(m, [(0.0, (0.10, 0.15, 0.30)), (0.25, (0.22, 0.32, 0.55)), (0.75, (0.93, 0.93, 0.92))])   # 背心 → 藍色襯墊，襯衫照舊白

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
    print("[armor] RENDERED")
