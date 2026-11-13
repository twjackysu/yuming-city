#!/usr/bin/env python3
"""把一包現成小物（glTF＋.bin＋貼圖）縮成放得進 git 的大小（D-258）。

  python3 -P scripts/compact_props.py art-inbox/props/Exports/glTF            # 真的做
  python3 -P scripts/compact_props.py art-inbox/props/Exports/glTF --check    # 只檢查，不改檔

做的事：
- 每張 PNG 貼圖縮到最長邊 MAX_SIDE（預設 1024；NOISE 開頭列的那幾張縮到 512），存成 JPEG（4:4:4，不做色度抽樣）。
  有用到透明度的（alpha 不是全 255）不轉，保留 PNG 只縮尺寸。
- 每個 .gltf 的 images[].uri／mimeType 改成指到新檔；.bin 不動。
- 最後檢查：每個 .gltf 讀得進來、它指到的貼圖與 .bin 都在。

為什麼：小物在畫面上只有一兩百個像素，2048² 的貼圖用不到；原檔 38 MB 的貼圖縮完不到 3 MB。
原檔還在 git 歷史裡（art-inbox/props 是 e4fdaa3 放進來的），要拿回來：
  git checkout e4fdaa3 -- art-inbox/props && git lfs pull --include="art-inbox/props/**"
需要 Pillow。
"""
import glob
import json
import os
import sys

from PIL import Image

MAX_SIDE = 1024
SMALL_SIDE = 512
# 只是雜訊的貼圖（原檔 4096²）：縮更小
SMALL = ("T_Page_Noise",)
QUALITY = 90
# 法線貼圖品質高一點（壓縮的方塊會變成表面的凹凸）
QUALITY_NORMAL = 92


def convert_texture(path: str) -> str:
    """回傳新的檔名（同一個資料夾）。"""
    stem = os.path.splitext(os.path.basename(path))[0]
    im = Image.open(path)
    side = SMALL_SIDE if stem.startswith(SMALL) else MAX_SIDE
    has_alpha = False
    if im.mode in ("RGBA", "LA"):
        lo, _hi = im.getchannel("A").getextrema()
        has_alpha = lo < 255
    if max(im.size) > side:
        scale = side / max(im.size)
        im = im.resize((round(im.size[0] * scale), round(im.size[1] * scale)), Image.LANCZOS)
    folder = os.path.dirname(path)
    if has_alpha:
        out = stem + ".png"
        im.save(os.path.join(folder, out), "PNG", optimize=True)
        return out
    out = stem + ".jpg"
    quality = QUALITY_NORMAL if stem.endswith("_Normal") else QUALITY
    im.convert("RGB").save(os.path.join(folder, out), "JPEG", quality=quality, subsampling=0, optimize=True)
    os.remove(path)
    return out


def check(folder: str) -> int:
    errs = 0
    gltfs = sorted(glob.glob(os.path.join(folder, "*.gltf")))
    for g in gltfs:
        try:
            doc = json.load(open(g, encoding="utf-8"))
        except (OSError, ValueError) as e:
            print(f"讀不進來：{g}（{e}）")
            errs += 1
            continue
        refs = [i.get("uri", "") for i in doc.get("images", [])] + [b.get("uri", "") for b in doc.get("buffers", [])]
        for uri in refs:
            if uri == "" or uri.startswith("data:"):
                continue
            if not os.path.isfile(os.path.join(folder, uri)):
                print(f"{os.path.basename(g)} 指到的 {uri} 不在")
                errs += 1
    total = sum(os.path.getsize(os.path.join(folder, f)) for f in os.listdir(folder))
    print(f"檢查 {len(gltfs)} 個模型，問題 {errs} 個；資料夾 {total / 1e6:.1f} MB")
    return errs


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 1 or not os.path.isdir(args[0]):
        print(__doc__)
        return 2
    folder = args[0]
    if "--check" in sys.argv:
        return 1 if check(folder) else 0
    renamed = {}
    for p in sorted(glob.glob(os.path.join(folder, "*.png"))):
        before = os.path.getsize(p)
        if before < 300:
            print(f"{os.path.basename(p)} 還是 LFS 的指標檔：先 git lfs pull --include=\"{folder}/**\"")
            return 1
        out = convert_texture(p)
        renamed[os.path.basename(p)] = out
        after = os.path.getsize(os.path.join(folder, out))
        print(f"{os.path.basename(p)} {before / 1e6:.2f} MB → {out} {after / 1e6:.2f} MB")
    for g in sorted(glob.glob(os.path.join(folder, "*.gltf"))):
        doc = json.load(open(g, encoding="utf-8"))
        changed = False
        for img in doc.get("images", []):
            new = renamed.get(img.get("uri", ""))
            if new is not None and new != img["uri"]:
                img["uri"] = new
                if "mimeType" in img:
                    img["mimeType"] = "image/jpeg" if new.endswith(".jpg") else "image/png"
                changed = True
        if changed:
            with open(g, "w", encoding="utf-8", newline="\n") as f:
                json.dump(doc, f, ensure_ascii=False, separators=(",", ":"))
                f.write("\n")
    return 1 if check(folder) else 0


if __name__ == "__main__":
    sys.exit(main())
