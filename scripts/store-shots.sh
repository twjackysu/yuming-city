#!/usr/bin/env bash
# Steam 商店截圖（D-145）：照 scripts/store_shots.txt 一張張拍。雲端只有軟體渲染，拿來確認構圖；
# 上架用的在 Windows 實機跑 store-shots.ps1（Windows 版 zip 裡就有）。
# 用法：scripts/store-shots.sh <輸出資料夾> [語言，預設 en] [只拍檔名含這段字的]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$(realpath -m "${1:?需要輸出資料夾}")"
LOCALE="${2:-en}"
ONLY="${3:-}"
mkdir -p "$OUT"
failed=0
while read -r name frames flags; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  [[ -n "$ONLY" && "$name" != *"$ONLY"* ]] && continue
  # shellcheck disable=SC2086
  if ! SHOT_RES="${SHOT_RES:-1920x1080}" "$ROOT/scripts/screenshot.sh" "$OUT/$name.png" "$frames" $flags "--locale=$LOCALE" < /dev/null > /dev/null 2>&1; then
    echo "商店截圖 $name 失敗" >&2
    failed=$((failed + 1))
  else
    echo "商店截圖：$OUT/$name.png"
  fi
done < "$ROOT/scripts/store_shots.txt"
exit "$failed"
