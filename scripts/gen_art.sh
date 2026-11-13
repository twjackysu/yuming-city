#!/usr/bin/env bash
# 自製美術（D-249）：用 bpy（Blender 當 Python 模組）跑 tools/blender/*.py，
# 產物放在 build/art/characters/<id>/<id>.glb（不進 git），再由 scripts/import_characters.py 收件檢查後接進遊戲。
# scripts/gen-assets.sh 會呼叫；本機與 CI 都跑。
#   - 產物已經有、腳本沒改 → 跳過
#   - 裝不了 bpy、抓不到人體基底、腳本失敗 → 印出原因、回傳 0（沿用上一次做好的；沒有的話遊戲用程序人偶，不擋測試）
# 環境變數：ART_PYTHON（預設 python3；bpy 5.3.0 的 wheel 只有 Python 3.13）、ART_CACHE、ART_FORCE=1 強制重做、
#           ART_ONLY=<id> 只做一個角色、ART_PREVIEW=<x.png> 另外用 Cycles 算三張預覽圖（<x>_<id>_0～2.png：正面、背面、臉）。
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
MH_T="makehuman/data/targets/macrodetails"
MH_FILES=(makehuman/data/3dobjs/base.obj)
for sex in female male; do
  MH_FILES+=("$MH_T/universal-$sex-young-averagemuscle-averageweight.target" "$MH_T/asian-$sex-young.target"
             "$MH_T/caucasian-$sex-young.target" "$MH_T/african-$sex-young.target")
done
# 要做的角色（tools/blender/<id>.py；共用的部分在 tools/blender/common.py）。各自一個 .stamp：只重做腳本有改的。
CHARACTERS=(sheila noen)

todo=()
declare -A stamps
for id in "${CHARACTERS[@]}"; do
  stamps[$id]="$(cat "$ROOT/tools/blender/common.py" "$ROOT/tools/blender/$id.py" "${BASH_SOURCE[0]}" | sha256sum | cut -d' ' -f1)"
  [[ -n "${ART_ONLY:-}" && "${ART_ONLY}" != "$id" ]] && continue
  if [[ "${ART_FORCE:-0}" != "1" && -s "$OUT/$id/$id.glb" && "$(cat "$OUT/$id/.stamp" 2>/dev/null)" == "${stamps[$id]}" ]]; then
    echo "[art] $id：腳本沒改，沿用 build/art/characters/$id/$id.glb"
  else
    todo+=("$id")
  fi
done
[[ ${#todo[@]} -eq 0 ]] && exit 0

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

# 先做在 new/ 裡，成功才搬到定位並寫 .stamp；失敗就什麼都不動——上一次做好的照用（沒有的話遊戲用程序人偶），
# .stamp 對不上，下一次會再試。
for id in "${todo[@]}"; do
  mkdir -p "$OUT/$id/new"
  args=(--mh "$MH_DIR/makehuman/data" --out "$OUT/$id/new/$id.glb")
  [[ -n "${ART_PREVIEW:-}" ]] && args+=(--preview "${ART_PREVIEW%.png}_$id.png")
  if "$PY" -I "$ROOT/tools/blender/$id.py" "${args[@]}" > "$OUT/$id/gen.log" 2>&1 && [[ -s "$OUT/$id/new/$id.glb" ]]; then
    mv -f "$OUT/$id/new/$id.glb" "$OUT/$id/$id.glb"
    echo "${stamps[$id]}" > "$OUT/$id/.stamp"
    grep "^\[$id\]" "$OUT/$id/gen.log" | sed 's/^/[art] /'
  else
    echo "[art] tools/blender/$id.py 失敗：沿用上一次做好的 $id（沒有的話用程序人偶）；最後幾行："
    tail -n 15 "$OUT/$id/gen.log"
  fi
done
exit 0
