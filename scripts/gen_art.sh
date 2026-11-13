#!/usr/bin/env bash
# 角色模型（D-249、D-252、D-253）：用 bpy（Blender 當 Python 模組）跑 tools/blender/*.py，
# 產物放在 build/art/characters/<id>/<id>.glb（不進 git），再由 scripts/import_characters.py 收件檢查後接進遊戲。
#   - 寫在 VRM_SRC 的角色：抓現成的 CC0 漫畫風角色（VRoid 的範例），用 tools/blender/vrm_character.py 轉成遊戲用的 glb
#   - 其他角色：自製的 tools/blender/<id>.py（MakeHuman 人體基底）
# scripts/gen-assets.sh 會呼叫；本機與 CI 都跑。
#   - 產物已經有、腳本沒改 → 跳過
#   - 裝不了 bpy、抓不到來源檔、腳本失敗 → 印出原因、回傳 0（沿用上一次做好的；沒有的話遊戲用程序人偶，不擋測試）
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
# 現成的 CC0 漫畫風角色（docs/design/12-ready-made-characters.md、docs/CREDITS.md）：VRoid 的範例角色，固定在這個 commit。
# vrm_character.py 會讀檔案裡自己寫的授權，不是 CC0 就不做。
VRM_REPO="https://github.com/madjin/vrm-samples"
VRM_SHA="e16eb187100149a315ad92c3c9968f1d5baa6c7d"
VRM_DIR="$CACHE/vrm-samples-$VRM_SHA"
# 角色 id → repo 裡的來源檔；寫在這裡的用現成的，沒寫的才跑自製的 tools/blender/<id>.py
declare -A VRM_SRC=([noen]="vroid/beta/HairSample_Male.vrm" [sheila]="vroid/beta/Sendagaya_Shino.vrm")
# 角色 id → 給 vrm_character.py 的其他參數（--tint <材質名稱的一部分>=r,g,b：底色乘上這個顏色）
#   諾恩：白色連帽上衣 → 深褐（他的舊大衣的顏色）。數值是線性的：0.17 拍出來大約是 sRGB 的 0.45
declare -A VRM_ARGS=([noen]="--tint Tops=0.17,0.115,0.085")
# 要做的角色。各自一個 .stamp：只重做腳本有改的（共用的部分在 tools/blender/common.py）。
CHARACTERS=(sheila noen)

script_for() { if [[ -n "${VRM_SRC[$1]:-}" ]]; then echo "$ROOT/tools/blender/vrm_character.py"; else echo "$ROOT/tools/blender/$1.py"; fi; }

# 把 repo 裡的一個檔抓到 $VRM_DIR/files/（一個一個拿；不要對這個 repo 跑 ls-tree -l，會把 460 MB 全部抓下來）
fetch_vrm() {
  local dst
  dst="$VRM_DIR/files/$(basename "$1")"
  [[ -s "$dst" ]] && return 0
  mkdir -p "$VRM_DIR/files" "$VRM_DIR/git"
  (
    cd "$VRM_DIR/git" || exit 1
    if [[ ! -d .git ]]; then git init -q && git remote add origin "$VRM_REPO" || exit 1; fi
    git cat-file -e "$VRM_SHA^{commit}" 2>/dev/null \
      || git fetch -q --depth 1 --filter=blob:none origin "$VRM_SHA" || exit 1
    git show "$VRM_SHA:$1" > "$dst.part" && mv -f "$dst.part" "$dst"
  )
}

todo=()
declare -A stamps
for id in "${CHARACTERS[@]}"; do
  stamps[$id]="$(cat "$ROOT/tools/blender/common.py" "$(script_for "$id")" "${BASH_SOURCE[0]}" | sha256sum | cut -d' ' -f1)"
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

need_mh=0  # 只有自製的角色才需要 MakeHuman 的人體基底
for id in "${todo[@]}"; do [[ -z "${VRM_SRC[$id]:-}" ]] && need_mh=1; done
have_all=1
for f in "${MH_FILES[@]}"; do [[ -s "$MH_DIR/$f" ]] || have_all=0; done
if [[ "$need_mh" == "1" && "$have_all" != "1" ]]; then
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
  if [[ -n "${VRM_SRC[$id]:-}" ]]; then
    if ! fetch_vrm "${VRM_SRC[$id]}"; then
      echo "[art] 抓不到 ${VRM_SRC[$id]}：沿用上一次做好的 $id（沒有的話用程序人偶）"
      continue
    fi
    # shellcheck disable=SC2206
    args=(--src "$VRM_DIR/files/$(basename "${VRM_SRC[$id]}")" --out "$OUT/$id/new/$id.glb" --name "$id" ${VRM_ARGS[$id]:-})
  else
    args=(--mh "$MH_DIR/makehuman/data" --out "$OUT/$id/new/$id.glb")
    [[ -n "${ART_PREVIEW:-}" ]] && args+=(--preview "${ART_PREVIEW%.png}_$id.png")
  fi
  if "$PY" -I "$(script_for "$id")" "${args[@]}" > "$OUT/$id/gen.log" 2>&1 && [[ -s "$OUT/$id/new/$id.glb" ]]; then
    mv -f "$OUT/$id/new/$id.glb" "$OUT/$id/$id.glb"
    echo "${stamps[$id]}" > "$OUT/$id/.stamp"
    grep "^\[$id\]" "$OUT/$id/gen.log" | sed 's/^/[art] /'
  else
    echo "[art] $(basename "$(script_for "$id")") 失敗（$id）：沿用上一次做好的 $id（沒有的話用程序人偶）；最後幾行："
    tail -n 15 "$OUT/$id/gen.log"
  fi
done
exit 0
