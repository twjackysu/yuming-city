#!/usr/bin/env python3
"""Steam 膠囊圖「替代版」（D-064）：遊戲內截圖＋標題字，讓商店頁在正式主視覺做好前先有東西可看。

用法：python3 scripts/steam_mock.py <背景截圖.png> <輸出資料夾> [--title-shot 標題畫面.png]
產生（尺寸照 docs/steam/asset-specs.md）：
  header_capsule.png  920×430   主街夜景＋「餘命城／Yuming City」
  small_capsule.png   462×174   只放大標題（小尺寸也讀得出來）
  main_capsule.png    1232×706  同 header，構圖較寬
  library_capsule.png 600×900   直式（優先用標題畫面截圖的鐘樓剪影）
規則：膠囊圖上只放遊戲名稱與美術（不放評價、獎項、特價字樣）。
字型用遊戲自己的子集字型（scripts/gen_fonts.py 產生，含「餘命城」）；找不到就用 PIL 預設字型並警告。
這是替代版：上架前要換成 Jacky 的正式主視覺（docs/ART_REQUESTS.md）。圖檔不進 git（png 走 LFS），由 CI 產生後附在 release。
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
TITLE_FONT = ROOT / "game/assets/generated/fonts/title_serif_tc.otf"
SUB_FONT = ROOT / "game/assets/generated/fonts/ui_sans_tc_medium.otf"

TITLE_ZH = "餘命城"
TITLE_EN = "YUMING CITY"
# 標題字色：鐘室暖燈（跟標題畫面一致）
WARM = (246, 222, 176)
SHADOW = (6, 8, 12)

# 標題畫面截圖裡鐘樓的水平位置（title_screen 的剪影，D-061）
TOWER_X = 0.72

SIZES = {
    "header_capsule": (920, 430),
    "small_capsule": (462, 174),
    "main_capsule": (1232, 706),
    "library_capsule": (600, 900),
}


def cover(img: Image.Image, size: tuple[int, int], focus: tuple[float, float] = (0.5, 0.5)) -> Image.Image:
    """等比放大填滿 size，照 focus（0..1）決定裁切中心。"""
    w, h = size
    scale = max(w / img.width, h / img.height)
    big = img.resize((max(w, round(img.width * scale)), max(h, round(img.height * scale))), Image.LANCZOS)
    cx = round(big.width * focus[0] - w / 2)
    cy = round(big.height * focus[1] - h / 2)
    cx = min(max(cx, 0), big.width - w)
    cy = min(max(cy, 0), big.height - h)
    return big.crop((cx, cy, cx + w, cy + h))


def grade(img: Image.Image) -> Image.Image:
    """壓暗一點、加暗角與底部漸層，讓標題字站得出來。"""
    img = ImageEnhance.Brightness(img.convert("RGB")).enhance(0.82)
    w, h = img.size
    shade = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(shade)
    # 底部 45% 的漸層（字放在下方）
    top = int(h * 0.45)
    for y in range(top, h):
        a = int(170 * ((y - top) / max(1, h - top)) ** 1.4)
        d.line([(0, y), (w, y)], fill=a)
    # 暗角
    vig = Image.new("L", (w, h), 0)
    ImageDraw.Draw(vig).ellipse((-w * 0.25, -h * 0.35, w * 1.25, h * 1.35), fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(min(w, h) * 0.12))
    shade = Image.composite(shade, Image.new("L", (w, h), 140), vig)
    black = Image.new("RGB", (w, h), SHADOW)
    return Image.composite(black, img, shade)


def font(path: Path, size: int) -> ImageFont.ImageFont:
    if path.exists():
        return ImageFont.truetype(str(path), size)
    print(f"警告：找不到字型 {path}（先跑 scripts/check.sh 產生），改用預設字型", file=sys.stderr)
    return ImageFont.load_default(size)


def draw_title(img: Image.Image, zh_px: int, en_px: int, anchor_y: float, align: str = "center", letter_space: float = 0.18) -> None:
    """中文大標＋英文副標。align：center 置中、left 靠左（距左緣 6%）。"""
    w, h = img.size
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    fz = font(TITLE_FONT, zh_px)
    fe = font(SUB_FONT, en_px)
    zw = d.textlength(TITLE_ZH, font=fz)
    en_chars = list(TITLE_EN)
    gap = en_px * letter_space
    ew = sum(d.textlength(c, font=fe) for c in en_chars) + gap * (len(en_chars) - 1)
    x_zh = (w - zw) / 2 if align == "center" else w * 0.06
    x_en = (w - ew) / 2 if align == "center" else w * 0.06 + 2
    y_zh = h * anchor_y - zh_px
    y_en = y_zh + zh_px * 1.18
    # 柔和的光暈＋陰影
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.text((x_zh, y_zh), TITLE_ZH, font=fz, fill=(255, 196, 120, 150))
    glow = glow.filter(ImageFilter.GaussianBlur(zh_px * 0.18))
    d.text((x_zh + 2, y_zh + 3), TITLE_ZH, font=fz, fill=SHADOW + (200,))
    d.text((x_zh, y_zh), TITLE_ZH, font=fz, fill=WARM + (255,))
    x = x_en
    for c in en_chars:
        d.text((x + 1, y_en + 2), c, font=fe, fill=SHADOW + (200,))
        d.text((x, y_en), c, font=fe, fill=(222, 228, 236, 235))
        x += d.textlength(c, font=fe) + gap
    img.paste(Image.alpha_composite(glow, layer), (0, 0), Image.alpha_composite(glow, layer))


def make(bg: Image.Image, tall_bg: Image.Image, out: Path) -> list[Path]:
    out.mkdir(parents=True, exist_ok=True)
    made: list[Path] = []
    for name, size in SIZES.items():
        w, h = size
        if name == "library_capsule":
            # 標題畫面：鐘樓在右邊 72% 處；切掉底部「原型版本」小字，也避開左邊原本的標題與選單
            src = tall_bg.crop((0, 0, tall_bg.width, int(tall_bg.height * 0.93)))
            img = grade(cover(src, size, (TOWER_X, 0.5)))
        else:
            img = grade(cover(bg, size, (0.5, 0.42)))
        if name == "small_capsule":
            draw_title(img, zh_px=int(h * 0.46), en_px=int(h * 0.13), anchor_y=0.62)
        elif name == "library_capsule":
            draw_title(img, zh_px=int(w * 0.2), en_px=int(w * 0.05), anchor_y=0.82)
        else:
            draw_title(img, zh_px=int(h * 0.24), en_px=int(h * 0.062), anchor_y=0.8, align="left")
        p = out / f"{name}.png"
        img.convert("RGB").save(p, optimize=True)
        made.append(p)
    return made


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("background", type=Path, help="背景截圖（建議主街夜景，--at=main --quality=2）")
    ap.add_argument("out", type=Path, help="輸出資料夾")
    ap.add_argument("--title-shot", type=Path, default=None, help="直式膠囊用的截圖（預設跟背景同一張）")
    a = ap.parse_args()
    if not a.background.is_file():
        print(f"找不到背景截圖：{a.background}", file=sys.stderr)
        return 1
    bg = Image.open(a.background).convert("RGB")
    tall = Image.open(a.title_shot).convert("RGB") if a.title_shot and a.title_shot.is_file() else bg
    for p in make(bg, tall, a.out):
        with Image.open(p) as im:
            print(f"{p}  {im.width}×{im.height}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
