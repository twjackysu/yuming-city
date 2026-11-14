#!/usr/bin/env bash
# 固定鏡頭組（省 token 的畫面前後對照）：一次拍完一個場景的 3～5 個固定鏡頭，
# 每張印一行數字（跟基準的像素差異、平均亮度、過曝、死黑），再拼成一張「基準｜這次」的對照圖（960 px 寬）。
# 先看數字：差異接近 0＝沒改到畫面，不用看圖；過曝／死黑超標直接當問題修；要判斷好不好看才 Read 那張對照圖。
# 用法：
#   scripts/shots.sh <組名>                    # 拍 scripts/shots/<組名>.txt 的每個鏡頭 → build/shots/<組名>/，跟基準比
#   scripts/shots.sh <組名> --save-baseline    # 拍完存成基準（build/shots-baseline/<組名>/，不進 git）：改畫面「之前」跑這個
#   scripts/shots.sh <組名> --fetch-baseline   # 基準沒有的鏡頭先從 screens release 下載同名的圖（CI 拍的）再比
#   SHOTS_ONLY=<名稱> scripts/shots.sh <組名>  # 只拍一個鏡頭（只改局部時）
# 需要：xvfb、mesa-vulkan-drivers（先 apt-get update）、Pillow。只有 2 核：不要跟 check.sh 同時跑。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SET="${1:?需要組名（scripts/shots/<組名>.txt）}"
MODE="${2:-}"
LIST="$ROOT/scripts/shots/$SET.txt"
OUT="$ROOT/build/shots/$SET"
BASE="$ROOT/build/shots-baseline/$SET"
RELEASE_URL="https://github.com/twjackysu/curses-too-useful/releases/download/screens"
test -f "$LIST" || { echo "沒有這一組：$LIST" >&2; exit 1; }
mkdir -p "$OUT" "$BASE"

while read -r name frames flags; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  [[ -n "${SHOTS_ONLY:-}" && "$name" != "$SHOTS_ONLY" ]] && continue
  if [[ "$MODE" == "--fetch-baseline" && ! -s "$BASE/$name.png" ]]; then
    curl -fsSL --retry 3 -o "$BASE/$name.png" "$RELEASE_URL/$name.png" || rm -f "$BASE/$name.png"
  fi
  # shellcheck disable=SC2086
  "$ROOT/scripts/screenshot.sh" "$OUT/$name.png" "$frames" $flags > /dev/null 2>&1 || echo "截圖 $name 失敗" >&2
done < "$LIST"

python3 -P "$ROOT/scripts/shots_metrics.py" "$OUT" "$BASE" "$ROOT/build/shots/$SET-sheet.png"

if [[ "$MODE" == "--save-baseline" ]]; then
  cp "$OUT"/*.png "$BASE"/
  echo "基準已更新：$BASE"
fi
