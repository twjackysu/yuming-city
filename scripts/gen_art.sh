#!/usr/bin/env bash
# 自製美術（D-249）：用 bpy（Blender 當 Python 模組）跑 tools/blender/*.py，
# 產物放在 build/art/characters/<id>/<id>.glb（不進 git），再由 scripts/import_characters.py 收件檢查後接進遊戲。
# scripts/gen-assets.sh 會呼叫；本機與 CI 都跑。
#   - 產物已經有、腳本沒改 → 跳過
#   - 裝不了 bpy、抓不到人體基底、腳本失敗 → 印出原因、回傳 0（遊戲退回程序人偶，不擋測試）
# 環境變數：ART_PYTHON（預設 python3；bpy 5.3.0 的 wheel 只有 Python 3.13）、ART_CACHE、ART_FORCE=1 強制重做、
#           ART_PREVIEW=<png> 另外用 Cycles 算三張預覽圖（<png>_0～2.png）。
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY="${ART_PYTHON:-python3}"
CACHE="${ART_CACHE:-$HOME/.cache/yuming-art}"
OUT="$ROOT/build/art/characters"
BPY_VERSION="5.3.0"
# MakeHuman 素材（CC0，見 docs/CREDITS.md）：固定在這個 commit
MH_REPO="https://github.com/makehumancommunity/makehuman"
MH_SHA="a8bc2d54ff0ac92e78ff71431b1023eda42bf482"
MH_DIR="$CACHE/makehuman-$MH_SHA"
MH_FILES=(
  makehuman/data/3dobjs/base.obj
  makehuman/data/targets/macrodetails/universal-female-young-averagemuscle-averageweight.target
  makehuman/data/targets/macrodetails/asian-female-young.target
  makehuman/data/targets/macrodetails/caucasian-female-young.target
  makehuman/data/targets/macrodetails/african-female-young.target
)

stamp="$(cat "$ROOT/tools/blender/sheila.py" "${BASH_SOURCE[0]}" | sha256sum | cut -d' ' -f1)"
glb="$OUT/sheila/sheila.glb"
if [[ "${ART_FORCE:-0}" != "1" && -s "$glb" && "$(cat "$OUT/sheila/.stamp" 2>/dev/null)" == "$stamp" ]]; then
  echo "[art] sheila：腳本沒改，沿用 build/art/characters/sheila/sheila.glb"
  exit 0
fi

if ! "$PY" -I -c "import bpy" 2>/dev/null; then
  echo "[art] 安裝 bpy $BPY_VERSION（約 430 MB）…"
  "$PY" -m pip install --quiet --break-system-packages "bpy==$BPY_VERSION" 2>/dev/null \
    || "$PY" -m pip install --quiet "bpy==$BPY_VERSION" \
    || { echo "[art] 裝不了 bpy（$("$PY" --version 2>&1)；需要 Python 3.13），這次不產生模型、用程序人偶"; exit 0; }
fi

have_all=1
for f in "${MH_FILES[@]}"; do [[ -s "$MH_DIR/$f" ]] || have_all=0; done
if [[ "$have_all" != "1" ]]; then
  echo "[art] 下載 MakeHuman 人體基底（CC0）…"
  rm -rf "$MH_DIR"
  mkdir -p "$MH_DIR"
  (
    cd "$MH_DIR" && git init -q && git remote add origin "$MH_REPO" \
      && git sparse-checkout set --no-cone "${MH_FILES[@]/#//}" \
      && { git fetch -q --depth 1 --filter=blob:none origin "$MH_SHA" || git fetch -q --depth 1 --filter=blob:none origin; } \
      && git checkout -q FETCH_HEAD
  ) || { echo "[art] 抓不到 MakeHuman 人體基底，這次不產生模型、用程序人偶"; rm -rf "$MH_DIR"; exit 0; }
fi

mkdir -p "$OUT/sheila"
args=(--mh "$MH_DIR/makehuman/data" --out "$glb")
[[ -n "${ART_PREVIEW:-}" ]] && args+=(--preview "$ART_PREVIEW")
if "$PY" -I "$ROOT/tools/blender/sheila.py" "${args[@]}" > "$OUT/sheila/gen.log" 2>&1; then
  echo "$stamp" > "$OUT/sheila/.stamp"
  grep '^\[sheila\]' "$OUT/sheila/gen.log" | sed 's/^/[art] /'
else
  echo "[art] tools/blender/sheila.py 失敗，用程序人偶；最後幾行："
  tail -n 15 "$OUT/sheila/gen.log"
  rm -f "$glb" "$OUT/sheila/.stamp"
fi
exit 0
