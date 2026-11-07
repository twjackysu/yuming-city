#!/usr/bin/env bash
# 本機與 CI 共用的檢查流程：
#   scripts/check.sh            # import + 腳本載入檢查 + 單元／流程測試
#   scripts/check.sh --export   # 另外匯出 Windows 與 Linux（需要 export templates）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DO_EXPORT=0
[[ "${1:-}" == "--export" ]] && DO_EXPORT=1

if [[ "$DO_EXPORT" == "1" ]]; then
  GODOT="$(scripts/get-godot.sh --templates)"
else
  GODOT="$(scripts/get-godot.sh)"
fi

LOG_DIR="$ROOT/build/logs"
mkdir -p "$LOG_DIR"

# 程序生成素材（音效等）在 import 之前產生，不進 git
if [[ -x scripts/gen-assets.sh ]]; then
  scripts/gen-assets.sh
fi

echo "== import"
# 乾淨 clone 第一次 import 時，翻譯 CSV 產生的 .translation 還不存在，編輯器載入專案設定會先報
# 「Cannot open file *.translation」。所以第一次只負責產生匯入結果，第二次才檢查錯誤。
"$GODOT" --headless --path game --import > "$LOG_DIR/import-first.log" 2>&1 || {
  cat "$LOG_DIR/import-first.log"; echo "import 失敗" >&2; exit 1; }
"$GODOT" --headless --path game --import > "$LOG_DIR/import.log" 2>&1 || {
  cat "$LOG_DIR/import.log"; echo "import 失敗" >&2; exit 1; }
if grep -E "^(ERROR|SCRIPT ERROR|USER ERROR)" "$LOG_DIR/import.log"; then
  echo "import 有錯誤（見上）" >&2
  exit 1
fi

echo "== tests"
"$GODOT" --headless --path game -s res://tests/run_tests.gd 2>&1 | tee "$LOG_DIR/tests.log"
status="${PIPESTATUS[0]}"
if [[ "$status" != "0" ]]; then
  echo "測試失敗（exit $status）" >&2
  exit 1
fi
# GDScript 執行期錯誤會讓測試函式中途結束、卻不留下失敗紀錄，所以一律視為失敗
if grep -n "SCRIPT ERROR" "$LOG_DIR/tests.log"; then
  echo "測試中有 SCRIPT ERROR（見上）" >&2
  exit 1
fi

if [[ "$DO_EXPORT" == "1" ]]; then
  echo "== export"
  mkdir -p build/windows build/linux
  "$GODOT" --headless --path game --export-release "Windows Desktop" ../build/windows/YumingCity.exe 2>&1 | tee "$LOG_DIR/export-windows.log"
  "$GODOT" --headless --path game --export-release "Linux" ../build/linux/YumingCity.x86_64 2>&1 | tee "$LOG_DIR/export-linux.log"
  test -s build/windows/YumingCity.exe || { echo "Windows 匯出失敗" >&2; exit 1; }
  test -s build/linux/YumingCity.x86_64 || { echo "Linux 匯出失敗" >&2; exit 1; }
  ls -la build/windows build/linux
fi

echo "== 全部通過"
