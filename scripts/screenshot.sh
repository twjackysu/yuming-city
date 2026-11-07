#!/usr/bin/env bash
# 用 xvfb（軟體 Vulkan）跑遊戲並截圖，給畫面驗證與 README 使用。
# 用法：scripts/screenshot.sh <輸出.png> [幀數] [額外 user 參數...]
# 需要：xvfb、mesa-vulkan-drivers（apt）。Vulkan 不行時改用 opengl3。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$(realpath -m "${1:?需要輸出路徑}")"
FRAMES="${2:-30}"
shift $(( $# >= 2 ? 2 : 1 ))

GODOT="$("$ROOT/scripts/get-godot.sh")"
mkdir -p "$(dirname "$OUT")"

run() {
  timeout 120 xvfb-run -a -s "-screen 0 1920x1080x24" \
    "$GODOT" --path "$ROOT/game" --resolution 1600x900 "$@" \
    -- --screenshot="$OUT" --frames="$FRAMES" "${EXTRA[@]}"
}

EXTRA=("$@")
rm -f "$OUT"
run || true
if [[ ! -s "$OUT" ]]; then
  echo "Vulkan 截圖失敗，改用 opengl3" >&2
  run --rendering-driver opengl3 || true
fi
test -s "$OUT"
echo "截圖：$OUT"
