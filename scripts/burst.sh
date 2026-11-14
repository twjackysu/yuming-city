#!/usr/bin/env bash
# 連拍：會動的東西（出手、命中、受擊、閃避）不能用停住姿勢的單張圖驗收（docs/design/11-combat-first.md 第 4 節，D-238）。
# 用法：scripts/burst.sh <輸出.png> <從第幾幀> [額外 user 參數…]
#   scripts/burst.sh build/burst/forest.png 100 --level=corrupt_forest --locale=zh_TW
# → 第 N 幀起每 0.1 秒一張、共 8 張（--fixed-fps 60：遊戲裡的時間固定，跟這台機器畫得多慢無關），
#   每張裁中間那一塊、排成 4×2 的一張圖（960 px 寬）。讀圖只讀這一張。
# 環境變數：BURST_EVERY（幾幀一張，預設 6）、BURST_COUNT（預設 8）、BURST_CROP（裁哪一塊，比例 "x0,y0,x1,y1"，預設 "0.2,0.12,0.8,0.92"）、
#          BURST_RES（預設 1280x720）、BURST_TIMEOUT（秒，預設 420）。需要 xvfb、mesa-vulkan-drivers。
#          BURST_LAZY=1：只畫要存的那幾幀（等 --burst-on 觸發的時候不用一幀一幀畫，快很多；每張的霧會粗一點）。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$(realpath -m "${1:?需要輸出路徑}")"
FROM="${2:?需要從第幾幀開始}"
shift 2
EXTRA=("$@")
[[ "${BURST_LAZY:-0}" == "1" ]] && EXTRA+=("--burst-lazy")
EVERY="${BURST_EVERY:-6}"
COUNT="${BURST_COUNT:-8}"
GODOT="$("$ROOT/scripts/get-godot.sh")"
TMP="$(dirname "$OUT")/.burst-$(basename "$OUT" .png)"
rm -rf "$TMP"; mkdir -p "$TMP"
rm -f "$OUT"

run() {
  timeout "${BURST_TIMEOUT:-420}" xvfb-run -a -s "-screen 0 1920x1080x24" \
    "$GODOT" --path "$ROOT/game" --fixed-fps 60 --resolution "${BURST_RES:-1280x720}" "$@" \
    -- --burst="$TMP/f" --burst-from="$FROM" --burst-every="$EVERY" --burst-count="$COUNT" "${EXTRA[@]}"
}

run > "$TMP/run.log" 2>&1 || true
if [[ ! -s "$TMP/f-$((COUNT - 1)).png" ]]; then
  echo "Vulkan 連拍失敗，改用 opengl3" >&2
  run --rendering-driver opengl3 > "$TMP/run.log" 2>&1 || true
fi
test -s "$TMP/f-$((COUNT - 1)).png" || { tail -5 "$TMP/run.log" >&2; echo "連拍失敗" >&2; exit 1; }

python3 -P - "$TMP" "$OUT" "$COUNT" "${BURST_CROP:-0.2,0.12,0.8,0.92}" <<'PY'
import sys
from PIL import Image
tmp, out, count = sys.argv[1], sys.argv[2], int(sys.argv[3])
x0, y0, x1, y1 = (float(v) for v in sys.argv[4].split(","))
cols = 4 if count > 4 else count
rows = (count + cols - 1) // cols
tile_w = 960 // cols
tiles = []
for i in range(count):
    im = Image.open(f"{tmp}/f-{i}.png").convert("RGB")
    w, h = im.size
    im = im.crop((int(w * x0), int(h * y0), int(w * x1), int(h * y1)))
    tiles.append(im.resize((tile_w, round(im.height * tile_w / im.width)), Image.LANCZOS))
th = tiles[0].height
sheet = Image.new("RGB", (tile_w * cols, th * rows))
for i, t in enumerate(tiles):
    sheet.paste(t, ((i % cols) * tile_w, (i // cols) * th))
sheet.save(out)
print(f"連拍：{out}（{count} 張，{sheet.width}x{sheet.height}）")
PY
