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
# 自製角色模型（tools/blender/*.py 用 bpy 產生 → build/art/characters；裝不了 bpy 或失敗就略過，D-249）
"$ROOT/scripts/gen_art.sh"
# 角色模型（Jacky 的 art-inbox/characters 優先，沒有就用自製的 build/art/characters → game/assets/characters，收件檢查不過就用程序人偶）
python3 -P "$ROOT/scripts/import_characters.py"
