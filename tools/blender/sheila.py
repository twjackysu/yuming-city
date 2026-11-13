"""席菈（sheila）角色模型：用 bpy（Blender 當 Python 模組）無頭產生，不進 git，由 scripts/gen_art.sh 呼叫。

    python3 -I tools/blender/sheila.py --mh <makehuman/data> --out <sheila.glb> [--preview <png>]

- 人體基底：MakeHuman base.obj＋macrodetails target（CC0，見 docs/CREDITS.md）；只讀頂點資料，不用它的程式碼。
- 服裝：兜帽、短披肩、厚布上衣＋下襬、護臂手套、長褲、靴子、腰帶——都從身體表面長出來（擠出／射線量半徑），臉以外都遮住。
- 骨架：骨名對齊 Godot SkeletonProfileHumanoid；權重＝身體自動權重，再照最近點轉給服裝。
- 貼圖：程序材質 → Cycles 烘成 BaseColor／Normal／ORM（一個材質），通過 scripts/check_character_glb.py。
- 動作：idle、walk、run、light_attack_01（程式關鍵影格；名稱照 game/src/world/character_models.gd 的 ANIM_MAP）。
座標：Blender 裡 Z 朝上、角色面向 +Y（匯出成 glTF 後是 Y 朝上、面向 -Z）、公尺、身高 1.70。
"""
import argparse
import json
import math
import struct
import sys
import tempfile
from pathlib import Path

import bpy  # 一定要先 import bpy，bmesh／mathutils 才找得到
import bmesh
import numpy as np
from mathutils import Quaternion, Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

HEIGHT = 1.70
TEX = 1024
TARGETS = (("universal-female-young-averagemuscle-averageweight", 1.0),
           ("asian-female-young", 0.34), ("caucasian-female-young", 0.33), ("african-female-young", 0.33))
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
# 面的區域
SKIN, HOOD, TUNIC, BRACER, GLOVE, TROUSER, BOOT, SCLERA, IRIS, CAPE, BELT, METAL = range(12)


# ---------- 讀 MakeHuman ----------
def load_base(mh: Path):
    verts, faces, group = [], [], ""
    for line in (mh / "3dobjs" / "base.obj").read_text().splitlines():
        if line.startswith("v "):
            p = line.split()
            verts.append([float(p[1]), float(p[2]), float(p[3])])
        elif line.startswith("g "):
            group = line.split()[1]
        elif line.startswith("f "):
            faces.append((group, [int(p.split("/")[0]) - 1 for p in line.split()[1:]]))
    v = np.array(verts)
    for name, w in TARGETS:
        for line in (mh / "targets" / "macrodetails" / f"{name}.target").read_text().splitlines():
            if not line or line[0] == "#":
                continue
            p = line.split()
            v[int(p[0])] += w * np.array([float(p[1]), float(p[2]), float(p[3])])
    # MakeHuman：Y 朝上、面向 +Z、公寸 → Blender：Z 朝上、面向 +Y（x 反號保持右手系）
    v = np.stack([-v[:, 0], v[:, 2], v[:, 1]], axis=1) * 0.1
    body_ids = sorted({i for g, f in faces if g == "body" for i in f})
    zmin = v[body_ids, 2].min()
    scale = HEIGHT / (v[body_ids, 2].max() - zmin)
    v[:, 2] -= zmin
    v *= scale
    joints = {}
    for g, f in faces:
        if g.startswith("joint-"):
            joints.setdefault(g[6:], set()).update(f)
    joints = {k: Vector(v[sorted(ids)].mean(axis=0)) for k, ids in joints.items()}
    return v, faces, joints


def new_object(name, verts, faces):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(p) for p in verts], [], faces)
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def sub_mesh(v, faces, groups):
    used = sorted({i for g, f in faces if g in groups for i in f})
    remap = {old: new for new, old in enumerate(used)}
    return v[used], [[remap[i] for i in f] for g, f in faces if g in groups], [g for g, f in faces if g in groups]


def activate(ob):
    for o in bpy.context.scene.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length, t


# ---------- 骨架 ----------
def build_armature(J):
    spine = sorted([J["pelvis"]] + [J[f"spine-{i}"] for i in range(1, 5)], key=lambda p: p.z)
    head_top = J["head"] + Vector((0, 0, 0.17))
    bones = [("Hips", spine[0], spine[1], None), ("Spine", spine[1], spine[2], "Hips"),
             ("Chest", spine[2], spine[3], "Spine"), ("UpperChest", spine[3], J["neck"], "Chest"),
             ("Neck", J["neck"], J["head"], "UpperChest"), ("Head", J["head"], head_top, "Neck")]
    for s, side in (("l", "Left"), ("r", "Right")):
        hand_tip = J[f"{s}-hand"] + (J[f"{s}-hand"] - J[f"{s}-elbow"]).normalized() * 0.08
        toe0 = J[f"{s}-toe-3-1"]
        toe1 = toe0 + Vector((0, 0.07, 0))
        bones += [(side + "Shoulder", J[f"{s}-clavicle"], J[f"{s}-shoulder"], "UpperChest"),
                  (side + "UpperArm", J[f"{s}-shoulder"], J[f"{s}-elbow"], side + "Shoulder"),
                  (side + "LowerArm", J[f"{s}-elbow"], J[f"{s}-hand"], side + "UpperArm"),
                  (side + "Hand", J[f"{s}-hand"], hand_tip, side + "LowerArm"),
                  (side + "UpperLeg", J[f"{s}-upper-leg"], J[f"{s}-knee"], "Hips"),
                  (side + "LowerLeg", J[f"{s}-knee"], J[f"{s}-ankle"], side + "UpperLeg"),
                  (side + "Foot", J[f"{s}-ankle"], toe0, side + "LowerLeg"),
                  (side + "Toes", toe0, toe1, side + "Foot")]
    arm_data = bpy.data.armatures.new("SheilaRig")
    arm = bpy.data.objects.new("Sheila", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    activate(arm)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, head, tail, parent in bones:
        b = arm_data.edit_bones.new(name)
        b.head, b.tail = head, tail
        if parent:
            b.parent = arm_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm, {n: (h, t) for n, h, t, _ in bones}


def fallback_weights(ob, segs):
    """自動權重失敗時：照到骨頭線段的距離分兩根骨頭。"""
    for name in segs:
        if name not in ob.vertex_groups:
            ob.vertex_groups.new(name=name)
    for vtx in ob.data.vertices:
        d = sorted((seg_dist(vtx.co, h, t)[0], n) for n, (h, t) in segs.items())[:2]
        w0, w1 = 1.0 / (d[0][0] + 1e-4) ** 4, 1.0 / (d[1][0] + 1e-4) ** 4
        ob.vertex_groups[d[0][1]].add([vtx.index], w0 / (w0 + w1), "REPLACE")
        ob.vertex_groups[d[1][1]].add([vtx.index], w1 / (w0 + w1), "REPLACE")


# ---------- 服裝 ----------
def classify(center, J):
    """身體的面屬於哪一件衣服（看面中心）。"""
    z = center.z
    crotch = min(J["l-upper-leg"].z, J["r-upper-leg"].z) - 0.075
    for s in ("l", "r") if z > crotch else ():
        sh, el, ha = J[f"{s}-shoulder"], J[f"{s}-elbow"], J[f"{s}-hand"]
        tip = ha + (ha - el).normalized() * 0.22
        if abs(center.x) > abs(sh.x) + 0.015:
            if seg_dist(center, ha, tip)[0] < 0.075 and (center - ha).dot(ha - el) > -0.004:
                return GLOVE
            d, t = seg_dist(center, el, ha)
            if d < 0.075 and t > 0.12:
                return BRACER
            return TUNIC
    if z > J["head"].z - 0.005:
        brow = J["l-eye"].z + 0.035
        back = center.y < J["head"].y + 0.012
        return HOOD if (z > brow or back) and not (center.y > J["head"].y + 0.06 and z < brow + 0.03) else SKIN
    if z > J["neck"].z + 0.02:
        return SKIN
    if z > crotch:
        return TUNIC
    if z < J["l-knee"].z - 0.07:
        return BOOT
    return TROUSER


def dress_body(body, J):
    """把身體的面分區，衣服的區塊往外擠出一層（邊緣自然成為袖口、靴口、帽緣）；腳換成凸包做的靴頭。"""
    bm = bmesh.new()
    bm.from_mesh(body.data)
    region = bm.faces.layers.int.new("region")
    for f in bm.faces:
        f[region] = classify(f.calc_center_median(), J)
    # 腳：腳踝以下的面拿掉，換成凸包（腳趾不見、變成靴頭）
    ankle = J["l-ankle"].z
    foot_faces = [f for f in bm.faces if f[region] == BOOT and all(v.co.z < ankle - 0.012 for v in f.verts)]
    hull_pts = {-1: [], 1: []}
    for f in bm.faces:
        if f[region] == BOOT:
            for v in f.verts:
                if v.co.z < ankle + 0.02:
                    hull_pts[1 if v.co.x > 0 else -1].append(v.co.copy())
    bmesh.ops.delete(bm, geom=foot_faces, context="FACES")
    for thick, reg in ((0.03, HOOD), (0.013, TUNIC), (0.011, BRACER), (0.012, BOOT)):
        faces = [f for f in bm.faces if f[region] == reg]
        if not faces:
            continue
        geom = set(faces)
        for f in faces:  # 連邊與頂點一起給，原本的面才會被換掉、邊緣才長出一圈牆（袖口、靴口、帽緣）
            geom.update(f.edges)
            geom.update(f.verts)
        res = bmesh.ops.extrude_face_region(bm, geom=list(geom))
        new_verts = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
        bm.normal_update()
        for v in new_verts:
            v.co += v.normal * thick
        if reg == HOOD:  # 兜帽：把耳朵、後腦的起伏抹平，才像布不像泳帽
            for _ in range(10):
                bmesh.ops.smooth_vert(bm, verts=new_verts, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
            bm.normal_update()
            for v in new_verts:
                v.co += v.normal * 0.012
    for v in bm.verts:  # 手套、長褲只是薄薄一層
        regs = {f[region] for f in v.link_faces}
        if regs == {GLOVE} or regs == {TROUSER}:
            v.co += v.normal * 0.003
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    for side, pts in hull_pts.items():
        cx = sum(p.x for p in pts) / len(pts)
        cy = sum(p.y for p in pts) / len(pts)
        vs = []
        for p in pts:
            q = Vector((cx + (p.x - cx) * 1.14, cy + (p.y - cy) * 1.07 + 0.004, max(p.z, 0.0) * 1.06))
            vs.append(bm.verts.new(q))
        out = bmesh.ops.convex_hull(bm, input=vs)
        junk = [g for g in out["geom_interior"] if isinstance(g, bmesh.types.BMVert)]
        for g in out["geom"]:
            if isinstance(g, bmesh.types.BMFace):
                g[region] = BOOT
        bmesh.ops.delete(bm, geom=junk, context="VERTS")
    bm.normal_update()
    bm.to_mesh(body.data)
    bm.free()


def radius_from(bvh, origin, direction, limit):
    """從身體裡面的點往外看，最後一次穿出表面的距離（還在身體裡就回 limit）。"""
    start, travelled, last, inside = origin.copy(), 0.0, 0.0, True
    for _ in range(12):
        hit = bvh.ray_cast(start, direction, limit - travelled)
        if hit[0] is None:
            break
        travelled += hit[3] + 1e-4
        if inside:
            last = travelled
        inside = not inside
        start = origin + direction * travelled
    return limit if inside and last == 0.0 else (limit if inside else last)


def grid_object(name, rings, region_id, close=True):
    """rings：一圈一圈的點（每圈點數一樣）→ 四邊面。"""
    n = len(rings[0])
    verts = [p for ring in rings for p in ring]
    faces = []
    for r in range(len(rings) - 1):
        for i in range(n if close else n - 1):
            j = (i + 1) % n
            faces.append([r * n + i, r * n + j, (r + 1) * n + j, (r + 1) * n + i])
    ob = new_object(name, verts, faces)
    layer = ob.data.attributes.new("region", "INT", "FACE")
    layer.data.foreach_set("value", [region_id] * len(faces))
    return ob


def resample(path, n):
    """把一條折線照弧長重新取 n+1 個點。"""
    lens = [0.0]
    for i in range(1, len(path)):
        lens.append(lens[-1] + (path[i] - path[i - 1]).length)
    out, j = [], 0
    for k in range(n + 1):
        target = lens[-1] * k / n
        while j < len(path) - 2 and lens[j + 1] < target:
            j += 1
        span = lens[j + 1] - lens[j]
        u = 0.0 if span < 1e-9 else (target - lens[j]) / span
        out.append(path[j].lerp(path[j + 1], max(0.0, min(1.0, u))))
    return out


def build_cape(bvh, J, seg=72, rings_n=14):
    """短披肩：領口貼著脖子，往外蓋在肩膀與上臂上（沿著身體表面），蓋到邊就垂下來。"""
    c = Vector((0, J["neck"].y - 0.004, 0))
    z_top = J["neck"].z + 0.07
    hem0 = J["neck"].z - 0.26

    def inside(p):
        loc, nrm, _, _ = bvh.find_nearest(p)
        return (p - loc).dot(nrm) < 0.0

    cols = []
    for i in range(seg):
        th = math.tau * i / seg
        d = Vector((math.cos(th), math.sin(th), 0))
        side = abs(d.x)
        fold = math.sin(th * 13 + 1.3) * 0.6 + math.sin(th * 7 + 0.4) * 0.4
        cloth = 0.25 + 0.085 * side + 0.012 * math.sin(th * 3 + 1.0) + 0.008 * fold
        rho = 0.035
        while rho < 0.2 and inside(c + d * rho + Z * z_top):
            rho += 0.006
        rho += 0.016
        path = [c + d * (rho - 0.004) + Z * (z_top + 0.022), c + d * rho + Z * (z_top + 0.004)]
        last, fell, used = None, False, 0.0
        while used < cloth and rho < 0.5:
            hit = bvh.ray_cast(c + d * rho + Z * z_top, -Z, 0.5)
            if hit[0] is None or (last is not None and hit[0].z < last.z - 0.06):
                fell = True
                break
            n = hit[1] if hit[1].z > 0 else -hit[1]
            pt = hit[0] + n * 0.03
            if last is not None:
                used += (pt - path[-1]).length
            path.append(pt)
            last = hit[0]
            rho += 0.014
        end = path[-1]
        if fell and cloth - used > 0.02:
            rem = cloth - used
            for k in range(1, 6):
                u = k / 5
                path.append(end - Z * (rem * u) + d * ((0.03 + 0.012 * fold) * u * min(1.0, rem / 0.1)))
        else:
            path.append(end + d * 0.012 - Z * 0.022)
        cols.append(resample(path, rings_n))
    for it in range(7):  # 沿著圓周抹平（射線打到的是一片一片的面）；越下面的圈抹越多次，下緣才不會像鋸齒
        first = 0 if it < 2 else 5
        cols = [[cols[i][k] if k < first else cols[i][k] * 0.5 + (cols[i - 1][k] + cols[(i + 1) % seg][k]) * 0.25
                 for k in range(rings_n + 1)] for i in range(seg)]
    rings = [[cols[i][k] for i in range(seg)] for k in range(rings_n + 1)]
    return grid_object("Cape", rings, CAPE)


def build_skirt_and_belt(bvh, J, seg=56):
    """上衣下襬（腰到大腿中段、往外張、有摺）＋腰帶與帶扣。"""
    cy = J["pelvis"].y
    crotch = min(J["l-upper-leg"].z, J["r-upper-leg"].z) - 0.075
    waist = J["pelvis"].z + 0.115
    z_ref = crotch + 0.045
    rows, rings, belt = 9, [], []
    for r in range(rows + 1):
        t = r / rows
        z = waist + (crotch - 0.10 - waist) * t
        ring = []
        for i in range(seg):
            th = math.tau * i / seg
            d = Vector((math.cos(th), math.sin(th), 0))
            zz = max(z, z_ref)
            rad = radius_from(bvh, Vector((0, cy, zz)), d, 0.32)
            fold = math.sin(th * 11 + 0.5) * 0.7 + math.sin(th * 5) * 0.3
            flare = 0.018 + 0.04 * t + 0.012 * fold * t
            ring.append(Vector((0, cy, z + 0.008 * fold * t * t)) + d * (rad + flare))
        rings.append(ring)
    skirt = grid_object("Skirt", rings, TUNIC)
    zb, h = waist - 0.015, 0.026
    for dz, dr in ((h + 0.004, 0.012), (h, 0.03), (-h, 0.03), (-h - 0.004, 0.012)):
        ring = []
        for i in range(seg):
            th = math.tau * i / seg
            d = Vector((math.cos(th), math.sin(th), 0))
            ring.append(Vector((0, cy, zb + dz)) + d * (radius_from(bvh, Vector((0, cy, zb)), d, 0.32) + dr))
        belt.append(ring)
    belt_ob = grid_object("Belt", belt, BELT)
    front = radius_from(bvh, Vector((0, cy, zb)), Y, 0.32)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, cy + front + 0.036, zb))
    buckle = bpy.context.active_object
    buckle.scale = (0.062, 0.014, 0.07)
    bpy.ops.object.transform_apply(scale=True)
    bev = buckle.modifiers.new("Bevel", "BEVEL")
    bev.width, bev.segments = 0.006, 2
    bpy.ops.object.modifier_apply(modifier=bev.name)
    layer = buckle.data.attributes.new("region", "INT", "FACE")
    layer.data.foreach_set("value", [METAL] * len(buckle.data.polygons))
    return [skirt, belt_ob, buckle]


def build_clasp(J, bvh):
    """披肩的銀扣（之後換成三劍徽記）。"""
    origin = Vector((0, J["neck"].y, J["neck"].z - 0.045))
    front = radius_from(bvh, origin, Y, 0.3)
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.026, depth=0.012,
                                        location=origin + Y * (front + 0.045), rotation=(math.radians(78), 0, 0))
    clasp = bpy.context.active_object
    bev = clasp.modifiers.new("Bevel", "BEVEL")
    bev.width, bev.segments = 0.004, 2
    bpy.ops.object.modifier_apply(modifier=bev.name)
    layer = clasp.data.attributes.new("region", "INT", "FACE")
    layer.data.foreach_set("value", [METAL] * len(clasp.data.polygons))
    return clasp


# ---------- 材質 ----------
def make_material(name, color, rough, metal=0.0, bump="noise", bump_scale=60.0, strength=0.3, vary=0.12):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    coord = nt.nodes.new("ShaderNodeTexCoord")
    big = nt.nodes.new("ShaderNodeTexNoise")
    big.inputs["Scale"].default_value = 9.0
    big.inputs["Detail"].default_value = 5.0
    nt.links.new(coord.outputs["Object"], big.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeMix")
    ramp.data_type = "RGBA"
    ramp.inputs[6].default_value = (*[c * (1 - vary * 2.2) for c in color], 1)
    ramp.inputs[7].default_value = (*[min(1.0, c * (1 + vary)) for c in color], 1)
    nt.links.new(big.outputs["Fac"], ramp.inputs[0])
    nt.links.new(ramp.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = metal
    rmap = nt.nodes.new("ShaderNodeMapRange")
    rmap.inputs["To Min"].default_value = max(0.05, rough - 0.12)
    rmap.inputs["To Max"].default_value = min(1.0, rough + 0.1)
    nt.links.new(big.outputs["Fac"], rmap.inputs["Value"])
    nt.links.new(rmap.outputs["Result"], bsdf.inputs["Roughness"])
    if bump == "weave":
        tex = nt.nodes.new("ShaderNodeTexWave")
        tex.inputs["Scale"].default_value = bump_scale
        tex.inputs["Distortion"].default_value = 1.5
        tex.inputs["Detail"].default_value = 2.0
        tex2 = nt.nodes.new("ShaderNodeTexWave")
        tex2.bands_direction = "Z"
        tex2.inputs["Scale"].default_value = bump_scale
        tex2.inputs["Distortion"].default_value = 1.5
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "ADD"
        nt.links.new(coord.outputs["Object"], tex.inputs["Vector"])
        nt.links.new(coord.outputs["Object"], tex2.inputs["Vector"])
        nt.links.new(tex.outputs["Fac"], mul.inputs[0])
        nt.links.new(tex2.outputs["Fac"], mul.inputs[1])
        height = mul.outputs[0]
    elif bump == "quilt":
        tex = nt.nodes.new("ShaderNodeTexWave")
        tex.inputs["Scale"].default_value = bump_scale
        tex.inputs["Distortion"].default_value = 0.4
        nt.links.new(coord.outputs["Object"], tex.inputs["Vector"])
        height = tex.outputs["Fac"]
    elif bump == "strand":  # 髮絲：沿著垂直方向拉長的雜訊
        mapping = nt.nodes.new("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = (22.0, 22.0, 1.0)
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = bump_scale
        tex.inputs["Detail"].default_value = 8.0
        nt.links.new(coord.outputs["Object"], mapping.inputs["Vector"])
        nt.links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
        height = tex.outputs["Fac"]
    elif bump == "leather":
        tex = nt.nodes.new("ShaderNodeTexVoronoi")
        tex.feature = "DISTANCE_TO_EDGE"
        tex.inputs["Scale"].default_value = bump_scale
        nt.links.new(coord.outputs["Object"], tex.inputs["Vector"])
        height = tex.outputs["Distance"]
    else:
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = bump_scale
        tex.inputs["Detail"].default_value = 6.0
        nt.links.new(coord.outputs["Object"], tex.inputs["Vector"])
        height = tex.outputs["Fac"]
    bnode = nt.nodes.new("ShaderNodeBump")
    bnode.inputs["Strength"].default_value = strength
    bnode.inputs["Distance"].default_value = 0.004
    nt.links.new(height, bnode.inputs["Height"])
    nt.links.new(bnode.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def region_materials():
    cloth = (0.60, 0.57, 0.51)  # 米灰（暖燈下不會變成發亮的白塊）
    return {
        SKIN: make_material("skin", (0.62, 0.44, 0.35), 0.55, bump_scale=140, strength=0.06, vary=0.05),
        HOOD: make_material("hair", (0.06, 0.042, 0.032), 0.42, bump="strand", bump_scale=9, strength=0.6, vary=0.25),
        CAPE: make_material("cape", cloth, 0.9, bump="noise", bump_scale=420, strength=0.14),
        TUNIC: make_material("tunic", (0.085, 0.11, 0.155), 0.82, bump="quilt", bump_scale=22, strength=0.5),
        BRACER: make_material("bracer", (0.10, 0.058, 0.035), 0.5, bump="leather", bump_scale=95, strength=0.4),
        GLOVE: make_material("glove", (0.075, 0.045, 0.03), 0.58, bump="leather", bump_scale=130, strength=0.3),
        TROUSER: make_material("trouser", (0.05, 0.047, 0.05), 0.88, bump="weave", bump_scale=260, strength=0.25),
        BOOT: make_material("boot", (0.07, 0.042, 0.028), 0.46, bump="leather", bump_scale=80, strength=0.45),
        SCLERA: make_material("sclera", (0.78, 0.76, 0.72), 0.25, strength=0.0, vary=0.0),
        IRIS: make_material("iris", (0.03, 0.045, 0.06), 0.12, strength=0.0, vary=0.0),
        BELT: make_material("belt", (0.055, 0.032, 0.022), 0.42, bump="leather", bump_scale=110, strength=0.35),
        METAL: make_material("metal", (0.62, 0.63, 0.66), 0.34, metal=1.0, bump_scale=180, strength=0.12, vary=0.08),
    }


def bake(ob, tmp: Path):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 4
    scene.cycles.use_denoising = False
    activate(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    images = {}
    metal_of = {s.material.name: s.material.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value
                for s in ob.material_slots}
    for key, kind, colorspace in (("color", "DIFFUSE", "sRGB"), ("rough", "ROUGHNESS", "Non-Color"),
                                  ("normal", "NORMAL", "Non-Color"), ("ao", "AO", "Non-Color"),
                                  ("metal", "EMIT", "Non-Color")):
        img = bpy.data.images.new(f"sheila_{key}", TEX, TEX, alpha=False)
        img.colorspace_settings.name = colorspace
        for slot in ob.material_slots:
            nt = slot.material.node_tree
            node = nt.nodes.get("BakeTarget") or nt.nodes.new("ShaderNodeTexImage")
            node.name = "BakeTarget"
            node.image = img
            nt.nodes.active = node
            if key == "metal":  # 金屬度：把材質換成發光＝金屬度，烘 EMIT
                out = nt.nodes["Material Output"]
                em = nt.nodes.new("ShaderNodeEmission")
                v = metal_of[slot.material.name]
                em.inputs["Color"].default_value = (v, v, v, 1)
                nt.links.new(em.outputs[0], out.inputs["Surface"])
        scene.cycles.samples = 24 if key == "ao" else 4
        if kind == "DIFFUSE":
            bpy.ops.object.bake(type=kind, pass_filter={"COLOR"}, margin=6)
        else:
            bpy.ops.object.bake(type=kind, margin=6)
        images[key] = img
    def px(img):
        a = np.empty(TEX * TEX * 4, dtype=np.float32)
        img.pixels.foreach_get(a)
        return a.reshape(-1, 4)
    orm = bpy.data.images.new("sheila_orm", TEX, TEX, alpha=False)
    orm.colorspace_settings.name = "Non-Color"
    data = np.ones((TEX * TEX, 4), dtype=np.float32)
    data[:, 0] = np.clip(px(images["ao"])[:, 0] * 0.75 + 0.25, 0, 1)
    data[:, 1] = px(images["rough"])[:, 0]
    data[:, 2] = px(images["metal"])[:, 0]
    orm.pixels.foreach_set(data.ravel())
    out = {}
    for key, img in (("color", images["color"]), ("normal", images["normal"]), ("orm", orm)):
        img.filepath_raw = str(tmp / f"sheila_{key}.png")
        img.file_format = "PNG"
        img.save()
        out[key] = img
    final = bpy.data.materials.new("M_Sheila")
    final.use_nodes = True
    final.use_backface_culling = False  # 披肩、下襬看得到裡面
    nt = final.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexImage")
    tc.image = out["color"]
    nt.links.new(tc.outputs["Color"], bsdf.inputs["Base Color"])
    to = nt.nodes.new("ShaderNodeTexImage")
    to.image = out["orm"]
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(to.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = out["normal"]
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    ob.data.materials.clear()
    ob.data.materials.append(final)
    for p in ob.data.polygons:
        p.material_index = 0


# ---------- 動作 ----------
class Animator:
    def __init__(self, arm, segs):
        self.arm, self.segs = arm, segs
        self.rest = {b.name: b.matrix_local.to_3x3().to_quaternion() for b in arm.data.bones}
        arm.animation_data_create()
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
        self.drop = {}
        for side in ("Left", "Right"):
            h, t = segs[side + "UpperArm"]
            d = (t - h).normalized()
            self.drop[side] = math.degrees(math.acos(max(-1.0, min(1.0, -d.z))))  # 手臂離「垂直往下」幾度

    def rot(self, bone, frame, *steps):
        """steps：(世界座標的軸, 角度)，依序套用；相對於父骨頭帶著走的休息姿勢。"""
        q = Quaternion()
        for axis, deg in steps:
            q = Quaternion(axis, math.radians(deg)) @ q
        r = self.rest[bone]
        pb = self.arm.pose.bones[bone]
        pb.rotation_quaternion = r.inverted() @ q @ r
        pb.keyframe_insert("rotation_quaternion", frame=frame)

    def move(self, bone, frame, offset):
        pb = self.arm.pose.bones[bone]
        pb.location = self.rest[bone].inverted() @ Vector(offset)
        pb.keyframe_insert("location", frame=frame)

    def arm_pose(self, side, frame, hang=10.0, swing=0.0, elbow=15.0, twist=0.0):
        """hang：手臂離垂直幾度（往外）；swing：往前擺；elbow：手肘往前彎。"""
        sgn = 1.0 if side == "Right" else -1.0
        self.rot(side + "UpperArm", frame, (Y, sgn * (self.drop[side] - hang)), (X, swing), (Z, twist))
        h, t = self.segs[side + "LowerArm"]
        self.rot(side + "LowerArm", frame, ((t - h).normalized().cross(Y), elbow))

    def leg_pose(self, side, frame, thigh=0.0, knee=0.0, foot=0.0):
        self.rot(side + "UpperLeg", frame, (X, thigh))
        self.rot(side + "LowerLeg", frame, (X, -knee))
        self.rot(side + "Foot", frame, (X, foot))

    def action(self, name, frames, fn, step=1):
        act = bpy.data.actions.new(name)
        self.arm.animation_data.action = act
        for f in range(0, frames + 1, step):
            fn(f, f / frames)
        track = self.arm.animation_data.nla_tracks.new()
        track.name = name
        self.arm.animation_data.action = None
        strip = track.strips.new(name, 0, act)
        strip.name = name
        track.mute = True
        for pb in self.arm.pose.bones:
            pb.rotation_quaternion = Quaternion()
            pb.location = Vector((0, 0, 0))
        return act


def animate(arm, segs):
    a = Animator(arm, segs)

    def idle(f, t):
        b = math.sin(t * math.tau)
        a.rot("Hips", f, (Z, -6.0))
        a.move("Hips", f, (0, 0, -0.012 + 0.003 * b))
        a.rot("Spine", f, (X, -1.5 + 0.8 * b), (Z, 4.0))
        a.rot("Chest", f, (X, -1.0 + 1.0 * b), (Z, 6.0))
        a.rot("Head", f, (X, 3.0 - 0.6 * b), (Z, -4.0))
        a.arm_pose("Left", f, hang=9 + 0.8 * b, swing=-3, elbow=14 + b)
        a.arm_pose("Right", f, hang=13 + 0.8 * b, swing=12, elbow=38 + 1.5 * b)
        a.leg_pose("Left", f, thigh=9, knee=10, foot=-2)
        a.leg_pose("Right", f, thigh=-5, knee=6, foot=4)

    def gait(thigh_amp, knee_amp, arm_amp, lean, bob, elbow_l, elbow_r):
        def fn(f, t):
            p = t * math.tau
            s, c = math.sin(p), math.cos(p)
            a.rot("Hips", f, (X, -lean * 0.3), (Z, 5.0 * s))
            a.move("Hips", f, (0, 0, -bob + bob * 0.8 * math.cos(2 * p)))
            a.rot("Spine", f, (X, -lean * 0.4), (Z, -4.0 * s))
            a.rot("Chest", f, (X, -lean * 0.3), (Z, -5.0 * s))
            a.rot("Head", f, (X, lean * 0.6), (Z, 3.0 * s))
            a.leg_pose("Left", f, thigh=thigh_amp * s + lean * 0.5, knee=5 + knee_amp * max(0.0, c),
                       foot=-10 * s)
            a.leg_pose("Right", f, thigh=-thigh_amp * s + lean * 0.5, knee=5 + knee_amp * max(0.0, -c),
                       foot=10 * s)
            a.arm_pose("Left", f, hang=9, swing=-arm_amp * s, elbow=elbow_l + 8 * max(0.0, -s))
            a.arm_pose("Right", f, hang=13, swing=arm_amp * 0.55 * s + 8, elbow=elbow_r)
        return fn

    def attack(f, t):
        # 0～0.3 舉劍往後拉、0.3～0.55 往前劈、之後收回
        def k(keys):
            for i in range(len(keys) - 1):
                (t0, v0), (t1, v1) = keys[i], keys[i + 1]
                if t0 <= t <= t1:
                    u = (t - t0) / (t1 - t0)
                    u = u * u * (3 - 2 * u)
                    return v0 + (v1 - v0) * u
            return keys[-1][1]
        twist = k([(0, 0), (0.3, 28), (0.55, -32), (1, 0)])
        lean = k([(0, 0), (0.3, -4), (0.55, 14), (1, 0)])
        a.rot("Hips", f, (Z, twist * 0.35 - 6))
        a.move("Hips", f, (0, k([(0, 0), (0.55, 0.05), (1, 0)]), -0.012 - k([(0, 0), (0.55, 0.05), (1, 0)])))
        a.rot("Spine", f, (X, -lean * 0.5), (Z, twist * 0.35 + 4))
        a.rot("Chest", f, (X, -lean * 0.5), (Z, twist * 0.3 + 6))
        a.rot("Head", f, (X, 3), (Z, -twist * 0.6 - 4))
        a.arm_pose("Right", f, hang=k([(0, 13), (0.3, 55), (0.55, 30), (1, 13)]),
                   swing=k([(0, 12), (0.3, 150), (0.55, 55), (1, 12)]),
                   elbow=k([(0, 38), (0.3, 85), (0.55, 8), (1, 38)]))
        a.arm_pose("Left", f, hang=k([(0, 9), (0.3, 25), (0.55, 30), (1, 9)]),
                   swing=k([(0, -3), (0.3, 20), (0.55, -35), (1, -3)]), elbow=k([(0, 14), (0.55, 45), (1, 14)]))
        a.leg_pose("Left", f, thigh=k([(0, 9), (0.55, 32), (1, 9)]), knee=k([(0, 10), (0.55, 38), (1, 10)]), foot=-2)
        a.leg_pose("Right", f, thigh=k([(0, -5), (0.55, -18), (1, -5)]), knee=k([(0, 6), (0.55, 14), (1, 6)]), foot=6)

    a.action("idle", 72, idle, step=6)
    a.action("walk", 30, gait(27, 48, 20, 3, 0.012, 18, 34), step=2)
    a.action("run", 18, gait(42, 78, 38, 11, 0.03, 70, 62), step=1)
    a.action("light_attack_01", 16, attack, step=1)
    return a


# ---------- 匯出 ----------
def patch_orm(path: Path):
    """glTF 的 occlusionTexture 指到同一張 ORM（收件檢查要求；Blender 匯出時不會自己加）。"""
    raw = path.read_bytes()
    jlen = struct.unpack_from("<I", raw, 12)[0]
    data = json.loads(raw[20:20 + jlen])
    rest = raw[20 + jlen:]
    for m in data.get("materials", []):
        mr = m.get("pbrMetallicRoughness", {}).get("metallicRoughnessTexture")
        if mr is not None:
            m["occlusionTexture"] = {"index": mr["index"]}
    js = json.dumps(data, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + len(rest)) + struct.pack("<II", len(js), 0x4E4F534A) + js + rest
    path.write_bytes(out)


def render_preview(arm, ob, path: Path, frame_action="idle"):
    scene = bpy.context.scene
    track = arm.animation_data.nla_tracks[frame_action]
    arm.animation_data.action = track.strips[0].action
    scene.frame_set(0)
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.09, 0.1, 0.12, 1)
    scene.world = world
    for name, loc, energy, color, size in (("Key", (2.2, 2.8, 2.6), 170, (1.0, 0.86, 0.7), 1.6),
                                           ("Fill", (-2.6, 1.6, 1.4), 45, (0.6, 0.72, 1.0), 2.5),
                                           ("Rim", (-1.2, -2.6, 2.4), 150, (0.75, 0.85, 1.0), 1.0)):
        light = bpy.data.lights.new(name, "AREA")
        light.energy, light.color, light.size = energy, color, size
        lo = bpy.data.objects.new(name, light)
        lo.location = loc
        lo.rotation_euler = (Vector((0, 0, 1.0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(lo)
    bpy.ops.mesh.primitive_plane_add(size=12)
    floor = bpy.context.active_object
    fm = bpy.data.materials.new("floor")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.05, 0.05, 0.055, 1)
    floor.data.materials.append(fm)
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 40
    scene.cycles.use_denoising = False
    scene.render.resolution_x, scene.render.resolution_y = 1100, 760
    scene.view_settings.view_transform = "Standard"
    cams = []
    for i, (loc, target) in enumerate((((0.9, 3.3, 1.25), (0, 0, 0.9)), ((-2.6, -2.2, 1.4), (0, 0, 0.9)),
                                       ((0.35, 1.05, 1.56), (0, 0, 1.5)))):
        cam = bpy.data.cameras.new(f"Cam{i}")
        cam.lens = 50
        co = bpy.data.objects.new(f"Cam{i}", cam)
        co.location = loc
        co.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(co)
        cams.append(co)
    scene.render.resolution_x, scene.render.resolution_y = 420, 760
    for i, co in enumerate(cams):
        scene.camera = co
        scene.render.filepath = str(path.with_name(f"{path.stem}_{i}.png"))
        bpy.ops.render.render(write_still=True)
    arm.animation_data.action = None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mh", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--preview", type=Path)
    args = ap.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else None)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    v, faces, J = load_base(args.mh)

    # 1. 參考身體（完整、封閉）：只用來算權重與量半徑
    rv, rf, _ = sub_mesh(v, faces, {"body"})
    ref = new_object("BodyRef", rv, rf)
    arm, segs = build_armature(J)
    activate(ref)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    weighted = sum(1 for vt in ref.data.vertices if vt.groups)
    if weighted < len(ref.data.vertices) * 0.95:
        print(f"[sheila] 自動權重只蓋到 {weighted}/{len(ref.data.vertices)} 個頂點，改用距離權重")
        fallback_weights(ref, segs)
    bvh = BVHTree.FromPolygons([tuple(p) for p in rv], rf)

    # 2. 穿衣服的身體＋眼睛
    bv, bf, bg = sub_mesh(v, faces, {"body", "helper-l-eye", "helper-r-eye"})
    body = new_object("Body", bv, bf)
    eye_faces = {i for i, g in enumerate(bg) if g != "body"}
    dress_src = new_object("Dress", rv, rf)
    dress_body(dress_src, J)
    eyes_v, eyes_f, eyes_g = sub_mesh(v, faces, {"helper-l-eye", "helper-r-eye"})
    eyes = new_object("Eyes", eyes_v, eyes_f)
    layer = eyes.data.attributes.new("region", "INT", "FACE")
    vals = []
    for p in eyes.data.polygons:
        side = "l" if p.center.x < 0 else "r"
        front = J[f"{side}-eye"] + Y * 0.0125
        vals.append(IRIS if (p.center - front).length < 0.0068 else SCLERA)
    layer.data.foreach_set("value", vals)
    bpy.data.objects.remove(body)
    parts = [dress_src, eyes, build_cape(bvh, J)] + build_skirt_and_belt(bvh, J) + [build_clasp(J, bvh)]

    # 3. 合併、材質、平滑
    mats = region_materials()
    for ob in parts:
        for rid in range(12):
            ob.data.materials.append(mats[rid])
        reg = ob.data.attributes["region"]
        vals = [0] * len(ob.data.polygons)
        reg.data.foreach_get("value", vals)
        for p, rid in zip(ob.data.polygons, vals):
            p.material_index = rid
    activate(parts[0])
    for ob in parts:
        ob.select_set(True)
    bpy.ops.object.join()
    mesh = bpy.context.active_object
    mesh.name = "SheilaMesh"
    bpy.ops.object.shade_smooth()
    tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
    print(f"[sheila] 三角面 {tris}")

    # 4. 權重：照參考身體最近的三個頂點
    kd = KDTree(len(ref.data.vertices))
    for vt in ref.data.vertices:
        kd.insert(vt.co, vt.index)
    kd.balance()
    names = [g.name for g in ref.vertex_groups]
    groups = {n: mesh.vertex_groups.new(name=n) for n in names if n in segs}
    for vt in mesh.data.vertices:
        acc = {}
        for co, idx, dist in kd.find_n(vt.co, 3):
            w = 1.0 / (dist + 1e-3)
            for g in ref.data.vertices[idx].groups:
                n = names[g.group]
                acc[n] = acc.get(n, 0.0) + g.weight * w
        top = sorted(acc.items(), key=lambda kv: -kv[1])[:4]
        total = sum(w for _, w in top) or 1.0
        for n, w in top:
            if n in groups and w / total > 0.01:
                groups[n].add([vt.index], w / total, "REPLACE")
    bpy.data.objects.remove(ref)
    mesh.parent = arm
    mod = mesh.modifiers.new("Armature", "ARMATURE")
    mod.object = arm

    # 5. 貼圖、動作、匯出
    with tempfile.TemporaryDirectory() as tmp:
        bake(mesh, Path(tmp))
        animate(arm, segs)
        args.out.parent.mkdir(parents=True, exist_ok=True)
        activate(mesh)
        arm.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(args.out), export_format="GLB", use_selection=True,
                                  export_animations=True, export_animation_mode="NLA_TRACKS",
                                  export_skins=True, export_yup=True, export_tangents=False,
                                  export_image_format="AUTO", export_force_sampling=True)
        patch_orm(args.out)
        print(f"[sheila] 已匯出 {args.out}（{args.out.stat().st_size // 1024} KB）")
        if args.preview:
            render_preview(arm, mesh, args.preview)


if __name__ == "__main__":
    main()
