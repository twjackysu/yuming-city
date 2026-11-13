"""把現成的 VRM 0.x 角色（VRoid 的 CC0 範例，見 docs/design/12-ready-made-characters.md）變成遊戲用的角色 glb。

    python3 -I tools/blender/vrm_character.py --src <角色.vrm> --out <id.glb> [--name sheila] [--tint Tops=0.3,0.22,0.18]…

做的事：確認檔案裡寫的授權是 CC0（不是就停）→ 用 VRM 自己的人形對照表把骨頭改成 Godot 人形骨架的名字
（Hips、LeftUpperArm…）→ 套 common.py 的動作（idle／walk／run／light_attack_01／release）→ 匯出 glb →
每個材質補一張平的 Normal 與固定值的 ORM（收件檢查 scripts/check_character_glb.py 要求；不受光的材質用不到，畫面不變）
→ 照 --tint 改色（材質名稱含這個字的，底色乘上這個顏色；可以給很多個）。臉、頭髮、身體、貼圖都照原檔。

由 scripts/gen_art.sh 呼叫（D-253；哪個角色用哪個檔、改什麼顏色寫在那裡）。
材質是「不受光」（KHR_materials_unlit）：在暗的場景裡人物是亮的、不吃場景的光。
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


def patch_materials(path: Path, tints):
    """匯出後直接改 glb：每個材質補平的 Normal 與固定值的 ORM（occlusion 與 metallicRoughness 同一張）、照 tints 改底色。
    回傳 (材質數, 改了色的材質名)。"""
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--name", default="character")
    ap.add_argument("--tint", type=parse_tint, action="append", default=[])
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
    count, tinted = patch_materials(args.out, args.tint)
    print(f"[{args.name}] 已匯出 {args.out.name}：{tris} 個三角面、{count} 個材質（補了 Normal／ORM"
          f"{'；改色 ' + '、'.join(tinted) if tinted else ''}）、身高 {height:.2f} m、{args.out.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
