#!/usr/bin/env python3
"""Steam 成就圖示「替代版」（D-147）：每個成就一張 256×256 PNG，程序畫的暖金色小圖案。

用法：python3 -P scripts/achievement_icons.py <輸出資料夾>
讀 game/data/achievements.json 的 id，產生（命名照 Steamworks 批次上傳的規則）：
  <ID>_ACHIEVED.png    彩色（暗藍底、暖金色雙圈＋圖案）
  <ID>_UNACHIEVED.png  灰階、暗一點（Steamworks 也能自動產生，這裡先給一套一致的）
  achievement-icons.zip  上面全部（Jacky 在 Steamworks 後台「批次上傳圖示」直接用）
  achievements_sheet.png 一張總覽（看構圖用）
規格（docs/steam/asset-specs.md）：建議 256×256 PNG、正方形；圖示上不放字。
這是替代版：正式圖示由 Jacky 決定（docs/ART_REQUESTS.md），圖檔不進 git，由 CI 產生後附在 release。
"""
from __future__ import annotations

import json
import math
import sys
import zipfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "game/data/achievements.json"
SIZE = 256
SS = 4  # 超取樣：畫 1024 再縮，邊緣平滑
GOLD = (240, 196, 122)
GOLD_DIM = (170, 128, 70)
FROST = (150, 215, 255)
FLAME = (255, 150, 60)
BG_IN = (28, 36, 54)
BG_OUT = (8, 10, 16)


def ids() -> list[str]:
    root = json.loads(DATA.read_text(encoding="utf-8"))
    return [str(a["id"]) for a in root.get("achievements", [])]


def background() -> Image.Image:
    n = SIZE * SS
    img = Image.new("RGB", (n, n), BG_OUT)
    px = img.load()
    c = n / 2
    for y in range(0, n, 2):
        for x in range(0, n, 2):
            t = min(1.0, math.hypot(x - c, y - c) / (n * 0.62))
            col = tuple(int(BG_IN[i] * (1 - t) + BG_OUT[i] * t) for i in range(3))
            px[x, y] = col
            if x + 1 < n:
                px[x + 1, y] = col
            if y + 1 < n:
                px[x, y + 1] = col
                if x + 1 < n:
                    px[x + 1, y + 1] = col
    d = ImageDraw.Draw(img)
    r1, r2 = n * 0.46, n * 0.41
    d.ellipse([c - r1, c - r1, c + r1, c + r1], outline=GOLD_DIM, width=int(n * 0.012))
    d.ellipse([c - r2, c - r2, c + r2, c + r2], outline=GOLD, width=int(n * 0.02))
    return img


def S(v: float) -> float:
    """0..1 的相對座標 → 超取樣像素。"""
    return v * SIZE * SS


def poly(d: ImageDraw.ImageDraw, pts: list[tuple[float, float]], fill) -> None:
    d.polygon([(S(x), S(y)) for x, y in pts], fill=fill)


def bell(d: ImageDraw.ImageDraw) -> None:
    pts = []
    for i in range(13):
        a = math.pi + math.pi * i / 12
        pts.append((0.5 + math.cos(a) * 0.13, 0.36 + math.sin(a) * 0.1))
    pts += [(0.64, 0.56), (0.71, 0.64), (0.29, 0.64), (0.36, 0.56)]
    poly(d, pts, GOLD)
    d.rectangle([S(0.47), S(0.22), S(0.53), S(0.27)], fill=GOLD)
    d.ellipse([S(0.46), S(0.65), S(0.54), S(0.73)], fill=GOLD)
    for i in range(9):  # 九下
        a = math.pi * (0.15 + 0.7 * i / 8) + math.pi
        x, y = 0.5 + math.cos(a) * 0.3, 0.5 - math.sin(a) * 0.3 * -1
        r = 0.016
        d.ellipse([S(x - r), S(y - r), S(x + r), S(y + r)], fill=GOLD if i < 8 else FROST)


def figures(d: ImageDraw.ImageDraw) -> None:
    for i, x in enumerate((0.36, 0.5, 0.64)):
        y = 0.47 if i == 1 else 0.5
        d.ellipse([S(x - 0.045), S(y - 0.11), S(x + 0.045), S(y - 0.02)], fill=GOLD)
        d.rounded_rectangle([S(x - 0.06), S(y), S(x + 0.06), S(y + 0.2)], radius=S(0.05), fill=GOLD)
    for x, y in ((0.3, 0.27), (0.42, 0.22), (0.6, 0.25), (0.7, 0.32), (0.25, 0.4), (0.76, 0.45)):
        d.ellipse([S(x - 0.01), S(y - 0.01), S(x + 0.01), S(y + 0.01)], fill=(225, 235, 250))


def eye(d: ImageDraw.ImageDraw) -> None:
    top = [(0.22 + 0.56 * t, 0.5 - math.sin(math.pi * t) * 0.15) for t in [i / 16 for i in range(17)]]
    bot = [(0.78 - 0.56 * t, 0.5 + math.sin(math.pi * t) * 0.15) for t in [i / 16 for i in range(17)]]
    poly(d, top + bot, GOLD)
    d.ellipse([S(0.41), S(0.41), S(0.59), S(0.59)], fill=BG_IN)
    d.ellipse([S(0.45), S(0.45), S(0.55), S(0.55)], fill=FROST)


def speech(d: ImageDraw.ImageDraw) -> None:
    d.rounded_rectangle([S(0.26), S(0.3), S(0.74), S(0.6)], radius=S(0.07), fill=GOLD)
    poly(d, [(0.36, 0.58), (0.46, 0.58), (0.34, 0.7)], GOLD)
    d.rectangle([S(0.34), S(0.43), S(0.66), S(0.47)], fill=BG_IN)


def arch(d: ImageDraw.ImageDraw) -> None:
    c, ro, ri, base = 0.5, 0.24, 0.14, 0.62
    d.pieslice([S(c - ro), S(base - ro), S(c + ro), S(base + ro)], 180, 360, fill=GOLD)
    d.pieslice([S(c - ri), S(base - ri), S(c + ri), S(base + ri)], 180, 360, fill=BG_IN)
    d.rectangle([S(c - ro), S(base), S(c - ri), S(0.74)], fill=GOLD)
    d.rectangle([S(c + ri), S(base), S(c + ro), S(0.74)], fill=GOLD)
    for i in range(1, 7):  # 拱石的放射縫
        a = math.pi + math.pi * i / 7
        d.line([S(c + math.cos(a) * ri), S(base + math.sin(a) * ri), S(c + math.cos(a) * ro), S(base + math.sin(a) * ro)],
               fill=BG_IN, width=int(S(0.012)))


def blade(d: ImageDraw.ImageDraw) -> None:
    glow = Image.new("L", d.im.size, 0)
    gd = ImageDraw.Draw(glow)
    gd.ellipse([S(0.36), S(0.18), S(0.64), S(0.66)], fill=200)
    poly(d, [(0.47, 0.62), (0.47, 0.26), (0.5, 0.2), (0.53, 0.26), (0.53, 0.62)], (255, 214, 160))
    d.rectangle([S(0.38), S(0.62), S(0.62), S(0.66)], fill=GOLD)
    d.rectangle([S(0.475), S(0.66), S(0.525), S(0.78)], fill=GOLD_DIM)
    for x, h in ((0.44, 0.3), (0.56, 0.34), (0.5, 0.16)):
        poly(d, [(x - 0.03, 0.6), (x, h), (x + 0.03, 0.6)], FLAME)


def wheel(d: ImageDraw.ImageDraw) -> None:
    c, r = 0.5, 0.2
    d.ellipse([S(c - r), S(c - r), S(c + r), S(c + r)], outline=GOLD, width=int(S(0.04)))
    for i in range(8):
        a = math.pi * i / 4
        d.line([S(c), S(c), S(c + math.cos(a) * r), S(c + math.sin(a) * r)], fill=GOLD, width=int(S(0.022)))
    d.ellipse([S(c - 0.045), S(c - 0.045), S(c + 0.045), S(c + 0.045)], fill=GOLD)


def door(d: ImageDraw.ImageDraw) -> None:
    d.pieslice([S(0.34), S(0.24), S(0.66), S(0.56)], 180, 360, fill=GOLD_DIM)
    d.rectangle([S(0.34), S(0.4), S(0.66), S(0.74)], fill=GOLD_DIM)
    d.rectangle([S(0.495), S(0.3), S(0.53), S(0.74)], fill=(255, 226, 170))  # 門縫透出的光
    d.ellipse([S(0.57), S(0.53), S(0.6), S(0.56)], fill=GOLD)
    d.rectangle([S(0.28), S(0.74), S(0.72), S(0.77)], fill=GOLD)


MOTIFS = {
    "ACH_NINTH_BELL": bell,
    "ACH_NO_ONE_LEFT": figures,
    "ACH_SEEN_THROUGH": eye,
    "ACH_THE_TRUTH": speech,
    "ACH_NINE_SECONDS": arch,
    "ACH_BURNING_BLADE": blade,
    "ACH_SAFE_PASSAGE": wheel,
    "ACH_CELLAR_DOOR": door,
}


def icon(ach_id: str) -> Image.Image:
    img = background()
    motif = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(motif)
    MOTIFS.get(ach_id, bell)(d)
    glow = motif.split()[3].filter(ImageFilter.GaussianBlur(S(0.03)))
    halo = Image.new("RGBA", img.size, GOLD + (0,))
    halo.putalpha(glow.point(lambda v: int(v * 0.45)))
    out = img.convert("RGBA")
    out.alpha_composite(halo)
    out.alpha_composite(motif)
    return out.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)


def locked(img: Image.Image) -> Image.Image:
    g = img.convert("L").point(lambda v: int(v * 0.62))
    return g.convert("RGB")


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    names = ids()
    missing = [i for i in names if i not in MOTIFS]
    if missing:
        print(f"[achievement-icons] 沒有圖案的成就（用小鐘代替）：{', '.join(missing)}", file=sys.stderr)
    sheet = Image.new("RGB", (SIZE * len(names), SIZE * 2), BG_OUT)
    files = []
    for i, ach_id in enumerate(names):
        on = icon(ach_id)
        off = locked(on)
        for suffix, im in (("ACHIEVED", on), ("UNACHIEVED", off)):
            p = out / f"{ach_id}_{suffix}.png"
            im.save(p)
            files.append(p)
        sheet.paste(on, (i * SIZE, 0))
        sheet.paste(off, (i * SIZE, SIZE))
    sheet.save(out / "achievements_sheet.png")
    with zipfile.ZipFile(out / "achievement-icons.zip", "w", zipfile.ZIP_DEFLATED) as z:
        for p in files:
            z.write(p, p.name)
    print(f"[achievement-icons] {len(names)} 個成就 × 2 張 → {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
