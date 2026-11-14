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
# Godot 4.7.2 偶爾在第一次 import 重新匯入翻譯 CSV 時崩潰（signal 4／double free，第 47、53 輪的 CI 各一次，
# 同樣內容重跑就過）：第一次失敗重試一次；第二次 import 照舊嚴格檢查錯誤
"$GODOT" --headless --path game --import > "$LOG_DIR/import-first.log" 2>&1 || {
  echo "第一次 import 失敗（多半是引擎偶發崩潰），重試一次" >&2
  "$GODOT" --headless --path game --import > "$LOG_DIR/import-first.log" 2>&1 || {
    cat "$LOG_DIR/import-first.log"; echo "import 失敗" >&2; exit 1; }
}
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
  "$GODOT" --headless --path game --export-release "Windows Desktop" ../build/windows/CursesTooUseful.exe 2>&1 | tee "$LOG_DIR/export-windows.log"
  "$GODOT" --headless --path game --export-release "Linux" ../build/linux/CursesTooUseful.x86_64 2>&1 | tee "$LOG_DIR/export-linux.log"
  test -s build/windows/CursesTooUseful.exe || { echo "Windows 匯出失敗" >&2; exit 1; }
  test -s build/linux/CursesTooUseful.x86_64 || { echo "Linux 匯出失敗" >&2; exit 1; }
  echo "== package"
  # 打包驗證：.pck 裡有場景、翻譯、資料、字型子集與全部程序音效（M1.4）
  python3 -I scripts/verify_package.py build/windows --exe CursesTooUseful.exe
  python3 -I scripts/verify_package.py build/linux --exe CursesTooUseful.x86_64
  ls -la build/windows build/linux
fi

echo "== 全部通過"
