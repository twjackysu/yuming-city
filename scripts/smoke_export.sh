#!/usr/bin/env bash
# 匯出版 smoke test（M1.4）：用「匯出的 Linux 執行檔」（不是編輯器）在 xvfb 裡開到霜橋鎮並截圖。
# 確認匯出版本身能啟動、載入 PCK、進到關卡、畫出東西，而且沒有 SCRIPT ERROR。
# 用法：scripts/smoke_export.sh [執行檔，預設 build/linux/YumingCity.x86_64] [輸出.png]
# 需要：xvfb、mesa-vulkan-drivers（apt）。Vulkan 不行時改用 opengl3。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$(realpath -m "${1:-$ROOT/build/linux/YumingCity.x86_64}")"
OUT="$(realpath -m "${2:-$ROOT/build/smoke-export.png}")"
LOG="${OUT%.png}.log"
# 均勻一片（黑畫面、只有清除色）的 1280x720 PNG 壓縮後只有幾 KB；霜橋鎮的夜景遠大於這個
MIN_BYTES=60000

test -x "$BIN" || { echo "找不到匯出的執行檔：$BIN" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"

run() {
  # `++` 之後是遊戲自己的參數（匯出版與 Windows PowerShell 都用這個分隔）
  timeout 120 xvfb-run -a -s "-screen 0 1920x1080x24" \
    "$BIN" --resolution 1280x720 "$@" \
    ++ --screenshot="$OUT" --frames=40 --level=frostbridge --rb-at=market --at=main > "$LOG" 2>&1
}

rm -f "$OUT"
run || true
if [[ ! -s "$OUT" ]]; then
  echo "Vulkan 失敗，改用 opengl3" >&2
  run --rendering-driver opengl3 || true
fi

if grep -nE "SCRIPT ERROR|Parse Error|Failed to load|Cannot open file" "$LOG"; then
  echo "匯出版執行時有錯誤（見上，完整紀錄 $LOG）" >&2
  exit 1
fi
if [[ ! -s "$OUT" ]]; then
  tail -30 "$LOG" >&2
  echo "匯出版沒有產生截圖" >&2
  exit 1
fi
size=$(stat -c %s "$OUT")
if (( size < MIN_BYTES )); then
  echo "截圖只有 $size bytes，畫面可能是黑的或沒進到霜橋鎮（$OUT）" >&2
  exit 1
fi
echo "匯出版 smoke test 通過：$OUT（$size bytes）"
