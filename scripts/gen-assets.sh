#!/usr/bin/env bash
# 產生不進 git 的程序素材（字型子集等），輸出到 game/assets/generated/。
# scripts/check.sh 會在 import 前自動呼叫；Windows 上用 Godot 編輯器開專案前，
# 可在 Git Bash / WSL 執行一次（沒執行也能開，只是會用系統字型）。
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! python3 -c "import fontTools" 2>/dev/null; then
  python3 -m pip install --quiet --user --break-system-packages "fonttools==4.67.0" \
    || python3 -m pip install --quiet --user "fonttools==4.67.0"
fi
# -P：不把腳本目錄放進 sys.path（保留 user site，pip --user 裝的 fonttools 才找得到）
python3 -P "$ROOT/scripts/gen_fonts.py"
# 音效（標準函式庫即可，不需安裝套件）
python3 -P "$ROOT/scripts/gen_sfx.py"
