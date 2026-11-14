#!/usr/bin/env python3
"""在 Jacky 的本機（Windows）用 Tripo 把 loop 排進佇列的 3D 模型產出來（D-259）。

為什麼在本機：雲端 loop 的網路連不到 Tripo，API 憑證也不該放進雲端；所以分工是
  loop 寫 art-inbox/tripo/queue.json → Jacky 本機跑這支 → 產物縮小後放進 art-inbox/tripo/<id>/ 推上去 → loop 下一輪接手。

用法（在 repo 根目錄，PowerShell 或任何終端機）：
  python scripts/tripo_queue.py              # 先只做 dry-run：列出要產的項目與估計點數，不扣點
  python scripts/tripo_queue.py --run        # 真的產（受 queue.json 的 budget_credits_per_run 限制）
  python scripts/tripo_queue.py --run --push # 產完自動 git add / commit / push
  python scripts/tripo_queue.py --compact-only art-work/tripo/x/model.glb  # 只測縮小貼圖

需要：
- Tripo CLI 已登入（tripo login --region ov 或 cn；tripo doctor 檢查）。找 CLI 的順序：環境變數 TRIPO_CLI → PATH 上的 tripo
  → C:\\Users\\jacky\\Tools\\tripo-cli\\node_modules\\.bin\\tripo.cmd。
- Pillow（pip install pillow），用來把 GLB 裡的貼圖縮成 1024 的 JPEG。

這支腳本不讀、不印、不存 API key；憑證只在 Tripo CLI 自己的設定裡。
原始下載放在被 git 忽略的 art-work/tripo/；只有縮過的 GLB、預覽圖與 SOURCE 進 art-inbox/tripo/。
"""
from __future__ import annotations

import argparse
import datetime as _dt
import io
import json
import os
import shutil
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUEUE = os.path.join(ROOT, "art-inbox", "tripo", "queue.json")
INBOX = os.path.join(ROOT, "art-inbox", "tripo")
WORK = os.path.join(ROOT, "art-work", "tripo")
DEFAULT_CLI_WIN = r"C:\Users\jacky\Tools\tripo-cli\node_modules\.bin\tripo.cmd"

# 沒有公開價目的步驟（綁骨、套動作）先用保守猜測算預算；真正扣多少看 tripo balance。
GUESS_RIG = 25  # 官方價目：auto rig 25 點、每段動作 10 點（developers.tripo3d.ai/en/pricing）
GUESS_PER_ANIMATION = 10
MAX_FILE_MB = 6.0  # 單檔超過就再縮一次（512）；art-inbox/tripo 不走 LFS，要讓雲端 loop 拿得到


# ---------------------------------------------------------------- CLI
def find_cli() -> list[str]:
    env = os.environ.get("TRIPO_CLI")
    if env:
        return [env]
    found = shutil.which("tripo")
    if found:
        return [found]
    if os.path.exists(DEFAULT_CLI_WIN):
        return [DEFAULT_CLI_WIN]
    sys.exit("找不到 Tripo CLI：請 npm install -g tripo-cli，或設定環境變數 TRIPO_CLI 指到 tripo(.cmd)。")


def run_cli(cli: list[str], args: list[str], *, want_json: bool = True, timeout: int = 1800):
    cmd = cli + args
    print("  $ tripo " + " ".join(_quote(a) for a in args), flush=True)
    proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                          errors="replace", timeout=timeout, shell=(os.name == "nt" and cmd[0].lower().endswith(".cmd")))
    if proc.returncode != 0:
        tail = (proc.stderr or proc.stdout).strip().splitlines()[-15:]
        raise RuntimeError("tripo 失敗（exit %d）：\n    %s" % (proc.returncode, "\n    ".join(tail)))
    if not want_json:
        return proc.stdout
    out = proc.stdout.strip()
    # --json 的結果在 stdout 最後一個 JSON 物件
    start = out.rfind("\n{")
    start = 0 if start < 0 else start + 1
    try:
        return json.loads(out[start:])
    except json.JSONDecodeError:
        return json.loads(out)


def _quote(a: str) -> str:
    return '"%s"' % a if (" " in a or not a) else a


# ---------------------------------------------------------------- queue
def load_queue() -> dict:
    with open(QUEUE, encoding="utf-8") as f:
        q = json.load(f)
    q.setdefault("budget_credits_per_run", 300)
    q.setdefault("items", [])
    return q


def is_done(item_id: str) -> bool:
    # _unused/：產過但暫時沒用到的（不重產、不刪）
    return any(os.path.exists(os.path.join(INBOX, sub, item_id, "SOURCE.json")) for sub in ("", "_unused"))


def make_args(item: dict, *, dry: bool) -> list[str]:
    if item.get("image"):
        src = item["image"]
        if not os.path.exists(os.path.join(ROOT, src)):
            raise RuntimeError("找不到參考圖 %s" % src)
        args = ["make", src]
    elif item.get("images"):
        args = ["make"] + list(item["images"])
    else:
        args = ["make", item["prompt"]]
    args += ["--model", item.get("model", "tripo-v3.1"), "--json", "--yes", "--no-open", "--quiet",
             "--name", item["id"], "-o", os.path.join("art-work", "tripo", item["id"])]
    if item.get("seed") is not None:
        args += ["--seed", str(item["seed"])]
    params = {"texture": True, "pbr": True, "texture_quality": "standard"}
    params.update(item.get("params", {}))
    if item.get("negative_prompt"):
        params["negative_prompt"] = item["negative_prompt"]
    for k, v in params.items():
        if isinstance(v, bool):
            v = "true" if v else "false"
        args += ["-p", "%s=%s" % (k, v)]
    if dry:
        args.append("--dry-run")
    return args


def estimate(cli, item) -> int:
    plan = run_cli(cli, make_args(item, dry=True))
    if not plan.get("valid", True) or plan.get("errors"):
        raise RuntimeError("dry-run 不通過：%s" % plan.get("errors"))
    gen = plan.get("generation_credits_estimate") or 40
    rig = item.get("rig")
    extra = (GUESS_RIG if rig else 0) + GUESS_PER_ANIMATION * len(item.get("animations", []) if rig else [])
    return int(gen) + extra


# ---------------------------------------------------------------- GLB 貼圖縮小
def compact_glb(path: str, max_side: int = 1024) -> tuple[int, int]:
    """把 GLB 內嵌的貼圖縮到 max_side、能轉 JPEG 的轉 JPEG。回傳（原大小, 新大小）。網格／骨架／動畫不動。"""
    from PIL import Image  # noqa: WPS433

    data = open(path, "rb").read()
    magic, version, _length = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67 or version != 2:
        raise RuntimeError("%s 不是 glTF 2 binary" % path)
    off = 12
    gltf, binchunk = None, b""
    while off < len(data):
        clen, ctype = struct.unpack_from("<II", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == 0x4E4F534A:
            gltf = json.loads(chunk.decode("utf-8"))
        elif ctype == 0x004E4942:
            binchunk = chunk
        off += 8 + clen
    if gltf is None:
        raise RuntimeError("GLB 沒有 JSON chunk")
    if len(gltf.get("buffers", [])) != 1 or "uri" in gltf["buffers"][0]:
        raise RuntimeError("只支援單一內嵌 buffer 的 GLB")

    views = gltf.get("bufferViews", [])
    blobs = [binchunk[v.get("byteOffset", 0): v.get("byteOffset", 0) + v["byteLength"]] for v in views]

    normal_imgs = set()
    tex = gltf.get("textures", [])
    for m in gltf.get("materials", []):
        nt = m.get("normalTexture")
        if nt is not None and nt["index"] < len(tex) and "source" in tex[nt["index"]]:
            normal_imgs.add(tex[nt["index"]]["source"])

    for i, img in enumerate(gltf.get("images", [])):
        if "bufferView" not in img:
            continue
        bv = img["bufferView"]
        orig_blob, orig_mime = blobs[bv], img.get("mimeType")
        im = Image.open(io.BytesIO(orig_blob))
        im.load()
        orig_size = im.size
        has_alpha = False
        if im.mode in ("RGBA", "LA", "P"):
            im = im.convert("RGBA")
            lo, _hi = im.getchannel("A").getextrema()
            has_alpha = lo < 255
        if max(im.size) > max_side:
            s = max_side / max(im.size)
            im = im.resize((max(1, round(im.size[0] * s)), max(1, round(im.size[1] * s))), Image.LANCZOS)
        buf = io.BytesIO()
        if has_alpha:
            im.save(buf, "PNG", optimize=True)
            img["mimeType"] = "image/png"
        else:
            q = 94 if i in normal_imgs else 88
            im.convert("RGB").save(buf, "JPEG", quality=q, subsampling=0, optimize=True)
            img["mimeType"] = "image/jpeg"
        if im.size == orig_size and len(buf.getvalue()) >= len(orig_blob) and orig_mime in ("image/png", "image/jpeg"):
            img["mimeType"] = orig_mime  # 已經夠小：原樣保留
            continue
        blobs[bv] = buf.getvalue()
    # webp 擴充不再需要
    for key in ("extensionsUsed", "extensionsRequired"):
        if key in gltf:
            gltf[key] = [e for e in gltf[key] if e != "EXT_texture_webp"]
            if not gltf[key]:
                del gltf[key]

    newbin = bytearray()
    for v, blob in zip(views, blobs):
        while len(newbin) % 4:
            newbin.append(0)
        v["byteOffset"] = len(newbin)
        v["byteLength"] = len(blob)
        newbin += blob
    while len(newbin) % 4:
        newbin.append(0)
    gltf["buffers"][0]["byteLength"] = len(newbin)

    js = json.dumps(gltf, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(newbin))
    out += struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(newbin), 0x004E4942) + bytes(newbin)
    tmp = path + ".tmp"
    with open(tmp, "wb") as f:
        f.write(out)
    os.replace(tmp, path)
    return len(data), len(out)


# ---------------------------------------------------------------- 產一個項目
def find_task(folder: str, task_type: str) -> str | None:
    """在 folder 底下找 tripo-cli 存的 task.json（成功的、指定類型），回傳 task_id。"""
    if not os.path.isdir(folder):
        return None
    for dirpath, _dirs, files in os.walk(folder):
        if "task.json" in files:
            try:
                t = json.load(open(os.path.join(dirpath, "task.json"), encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            if t.get("type") == task_type and t.get("status") == "success":
                return t.get("task_id")
    return None


def _task_id(res) -> str | None:
    if not isinstance(res, dict):
        return None
    for key in ("task_id",):
        if res.get(key):
            return res[key]
    for sub in ("primary", "data", "result"):
        if isinstance(res.get(sub), dict) and res[sub].get("task_id"):
            return res[sub]["task_id"]
    return None


def produce(cli, item: dict) -> dict:
    iid = item["id"]
    work = os.path.join(WORK, iid)
    gen_dir = os.path.join(work, "gen")
    rig_dir = os.path.join(work, "rig")
    anim_dir = os.path.join(work, "anim")
    os.makedirs(work, exist_ok=True)
    tasks = {}

    # 已經產過（上次中途失敗）就沿用，不重複扣點。舊版把生成放在 work/tripo-out，也一起找。
    gen_id = find_task(gen_dir, "text_to_model") or find_task(gen_dir, "image_to_model") \
        or find_task(os.path.join(work, "tripo-out"), "text_to_model") \
        or find_task(os.path.join(work, "tripo-out"), "image_to_model")
    if gen_id:
        print("  沿用已產生的模型 %s" % gen_id)
    else:
        args = make_args(item, dry=False)
        args[args.index("-o") + 1] = os.path.join("art-work", "tripo", iid, "gen")
        res = run_cli(cli, args)
        gen_id = _task_id(res) or find_task(gen_dir, "text_to_model") or find_task(gen_dir, "image_to_model")
    if not gen_id:
        raise RuntimeError("%s：生成完成但找不到 task_id" % iid)
    tasks["generate"] = gen_id

    rig = item.get("rig")
    if rig:
        rig_id = find_task(rig_dir, "animate_rig") or find_task(rig_dir, "rig")
        if rig_id:
            print("  沿用已綁好的骨架 %s" % rig_id)
        else:
            r = run_cli(cli, ["anim", "rig", gen_id, "--rig-type", rig.get("type", "biped"),
                              "--spec", rig.get("spec", "mixamo"), "--out-format", "glb",
                              "--json", "--yes", "--no-open", "--quiet",
                              "-o", os.path.join("art-work", "tripo", iid, "rig")])
            rig_id = _task_id(r) or find_task(rig_dir, "animate_rig") or find_task(rig_dir, "rig")
        if not rig_id:
            raise RuntimeError("%s：綁骨完成但找不到 task_id" % iid)
        tasks["rig"] = rig_id
        anims = item.get("animations", [])
        if anims:
            have_anim = any(f.lower().endswith(".glb") for _d, _s, fs in os.walk(anim_dir) for f in fs)
            if have_anim:
                print("  沿用已套好的動作")
            else:
                a = run_cli(cli, ["anim", "retarget", rig_id, "--animation", *anims[:5],
                                  "--animate-in-place", "--out-format", "glb",
                                  "--json", "--yes", "--no-open", "--quiet",
                                  "-o", os.path.join("art-work", "tripo", iid, "anim")])
                tasks["retarget"] = _task_id(a)

    # 收成品：每一步各留一個 GLB（生成、綁骨、動作），外加預覽圖
    dst = os.path.join(INBOX, iid)
    os.makedirs(dst, exist_ok=True)
    produced, previewed = [], set()
    for dirpath, _dirs, files in os.walk(work):
        for fn in files:
            src = os.path.join(dirpath, fn)
            low = fn.lower()
            rel_parts = os.path.relpath(dirpath, work).split(os.sep)
            stage = "anim" if rel_parts[0] == "anim" else "rig" if rel_parts[0] == "rig" else "model"
            if low.endswith(".glb"):
                if rig and stage == "model":
                    continue  # 有綁骨的只留綁好的那一個（遊戲用的是它），省 repo 的空間（design/14）
                out = os.path.join(dst, "%s_%s.glb" % (iid, stage))
                shutil.copyfile(src, out)
                before, after = compact_glb(out)
                if after > MAX_FILE_MB * 1024 * 1024:
                    _b, after = compact_glb(out, 512)
                produced.append({"file": os.path.basename(out), "bytes_raw": before, "bytes": after})
            elif low.endswith((".png", ".jpg", ".jpeg", ".webp")) and stage not in previewed:
                previewed.add(stage)
                from PIL import Image
                im = Image.open(src).convert("RGB")
                im.thumbnail((768, 768))
                prev = os.path.join(dst, "%s_%s_preview.jpg" % (iid, stage))
                im.save(prev, "JPEG", quality=85)
                produced.append({"file": os.path.basename(prev)})
    if not any(p["file"].endswith(".glb") for p in produced):
        raise RuntimeError("%s：Tripo 回報成功但 art-work 裡找不到 GLB" % iid)

    source = {
        "id": iid,
        "tool": "Tripo (VAST AI) via tripo-cli",
        "ai_generated": True,
        "steam_disclosure": "Pre-Generated AI content（上架時要在 Steamworks 內容問卷申報）",
        "license": "Jacky 的付費 Tripo 帳號／API 產出，商用權依 Tripo 條款歸帳號持有人；不是 CC0，不得當素材再散布",
        "model": item.get("model", "tripo-v3.1"),
        "prompt": item.get("prompt"),
        "image": item.get("image") or item.get("images"),
        "params": item.get("params", {}),
        "rig": item.get("rig"),
        "animations": item.get("animations", []),
        "tasks": tasks,
        "files": produced,
        "generated_at": _dt.datetime.now().astimezone().isoformat(timespec="seconds"),
        "requested_by": item.get("note", ""),
    }
    with open(os.path.join(dst, "SOURCE.json"), "w", encoding="utf-8") as f:
        json.dump(source, f, ensure_ascii=False, indent=2)
        f.write("\n")
    return source


# ---------------------------------------------------------------- main
def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--run", action="store_true", help="真的送出生成（會扣點）")
    ap.add_argument("--push", action="store_true", help="產完 git add/commit/push art-inbox/tripo")
    ap.add_argument("--only", nargs="*", help="只處理這些 id")
    ap.add_argument("--budget", type=int, help="覆寫這次的點數上限")
    ap.add_argument("--compact-only", metavar="GLB", help="只縮一個 GLB 的貼圖（測試用）")
    a = ap.parse_args()

    if a.compact_only:
        b, n = compact_glb(a.compact_only)
        print("%s：%.2f MB → %.2f MB" % (a.compact_only, b / 1e6, n / 1e6))
        return 0
    try:
        import PIL  # noqa: F401
    except ImportError:
        sys.exit("需要 Pillow：python -m pip install pillow")

    cli = find_cli()
    q = load_queue()
    budget = a.budget if a.budget is not None else int(q["budget_credits_per_run"])
    todo = [it for it in q["items"] if not is_done(it["id"]) and (not a.only or it["id"] in a.only)]
    if not todo:
        print("佇列裡沒有待產的項目。")
        return 0

    print("== 估計（dry-run，不扣點）==")
    plan, total = [], 0
    for it in todo:
        try:
            c = estimate(cli, it)
        except Exception as e:  # noqa: BLE001
            print("  [跳過] %s：%s" % (it["id"], e))
            continue
        fits = total + c <= budget
        print("  %-28s ~%4d 點 %s" % (it["id"], c, "" if fits else "（超出這次預算，下次再產）"))
        if fits:
            plan.append(it)
            total += c
    print("這次預計 ~%d 點（上限 %d；綁骨／動作是猜的，實際以 tripo balance 為準）" % (total, budget))
    if not a.run:
        print("\n只是估計。確定要產就加 --run。")
        return 0

    print("\n== 餘額（開始前）==")
    print(run_cli(cli, ["balance"], want_json=False).strip())
    done, failed = [], []
    for it in plan:
        print("\n== %s ==" % it["id"])
        try:
            s = produce(cli, it)
            done.append(it["id"])
            for f in s["files"]:
                if "bytes" in f:
                    print("  %s  %.2f MB（原 %.2f MB）" % (f["file"], f["bytes"] / 1e6, f["bytes_raw"] / 1e6))
        except Exception as e:  # noqa: BLE001
            failed.append(it["id"])
            print("  失敗：%s" % e)
    print("\n== 餘額（結束後）==")
    print(run_cli(cli, ["balance"], want_json=False).strip())
    print("\n完成 %d 個，失敗 %d 個 %s" % (len(done), len(failed), failed or ""))

    if a.push and done:
        rel = os.path.relpath(INBOX, ROOT)
        subprocess.run(["git", "add", rel], cwd=ROOT, check=True)
        msg = "art: Tripo 產出 %s [tripo_queue]" % "、".join(done)
        subprocess.run(["git", "commit", "-m", msg], cwd=ROOT, check=True)
        subprocess.run(["git", "pull", "--rebase"], cwd=ROOT, check=True)
        subprocess.run(["git", "push"], cwd=ROOT, check=True)
    elif done:
        print("記得推上去：git add art-inbox/tripo && git commit -m \"art: Tripo 產出\" && git push")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
