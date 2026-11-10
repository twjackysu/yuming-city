#!/usr/bin/env python3
"""固定鏡頭組的數字與對照圖（scripts/shots.sh 呼叫）。

用法：shots_metrics.py <這次的資料夾> <基準資料夾> <對照圖輸出.png>
每張印一行：跟基準的像素差異比例（任一色版差超過 DIFF_STEP 才算變了）、平均亮度（0～255）、
過曝（亮度 ≥ 250）與死黑（亮度 ≤ 4）的像素百分比。超標的在行尾標出來。
對照圖：每個鏡頭一列「基準｜這次」，整張 960 px 寬；沒有基準的鏡頭左邊留黑。
"""
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

DIFF_STEP = 24  # 雪、霧、粒子每次都不一樣：小於這個差距不算
OVER_LIMIT = 1.5  # 過曝像素超過這個百分比＝要修
BLACK_LIMIT = 30.0  # 死黑像素超過這個百分比＝要修（夜景本來就暗，所以放寬）
CELL_W = 480


def metrics(img: Image.Image) -> tuple[float, float, float]:
    luma = img.convert("L").resize((480, 270))
    hist = luma.histogram()
    total = float(sum(hist))
    mean = sum(i * n for i, n in enumerate(hist)) / total
    over = 100.0 * sum(hist[250:]) / total
    black = 100.0 * sum(hist[:5]) / total
    return mean, over, black


def diff_ratio(a: Image.Image, b: Image.Image) -> float:
    size = (480, 270)
    d = ImageChops.difference(a.convert("RGB").resize(size), b.convert("RGB").resize(size))
    r, g, bl = d.split()
    worst = ImageChops.lighter(ImageChops.lighter(r, g), bl)
    hist = worst.histogram()
    return 100.0 * sum(hist[DIFF_STEP + 1:]) / float(sum(hist))


def main() -> int:
    out_dir, base_dir, sheet_path = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    shots = sorted(p for p in out_dir.glob("*.png"))
    if not shots:
        print("沒有拍到任何鏡頭", file=sys.stderr)
        return 1
    rows = []
    for p in shots:
        img = Image.open(p)
        mean, over, black = metrics(img)
        base_path = base_dir / p.name
        base = Image.open(base_path) if base_path.exists() else None
        diff = "基準:無" if base is None else "差異=%.1f%%" % diff_ratio(img, base)
        flags = []
        if over > OVER_LIMIT:
            flags.append("過曝超標")
        if black > BLACK_LIMIT:
            flags.append("死黑超標")
        print("%-22s %-12s 亮度=%5.1f 過曝=%4.2f%% 死黑=%5.2f%% %s" % (p.stem, diff, mean, over, black, " ".join(flags)))
        rows.append((p.stem, base, img))
    cell_h = CELL_W * 9 // 16
    sheet = Image.new("RGB", (CELL_W * 2, cell_h * len(rows)), (0, 0, 0))
    draw = ImageDraw.Draw(sheet)
    for i, (name, base, img) in enumerate(rows):
        if base is not None:
            sheet.paste(base.convert("RGB").resize((CELL_W, cell_h)), (0, i * cell_h))
        sheet.paste(img.convert("RGB").resize((CELL_W, cell_h)), (CELL_W, i * cell_h))
        draw.text((6, i * cell_h + 4), name + "  base | now", fill=(255, 255, 0))
    sheet_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(sheet_path)
    print("對照圖：%s（左＝基準、右＝這次）" % sheet_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
