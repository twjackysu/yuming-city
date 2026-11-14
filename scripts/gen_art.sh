#!/usr/bin/env bash
# 角色模型：把 Jacky 用 Tripo 產的人物（art-inbox/tripo/<來源>/<來源>_rig.glb，有 Mixamo 骨架）用 bpy
# （Blender 當 Python 模組）跑 tools/blender/tripo_character.py 轉成遊戲用的 glb——骨名換成 Godot 人形骨架、
# 轉向、縮到指定身高、做同一套動作（idle／walk／run／dodge／attack）。
# 產物放 build/art/characters/<id>/<id>.glb（不進 git），再由 scripts/import_characters.py 收件檢查後接進遊戲。
# scripts/gen-assets.sh 會呼叫；本機與 CI 都跑。
#   - 產物已經有、腳本與來源沒改 → 跳過
#   - 裝不了 bpy、腳本失敗 → 印出原因、回傳 0（沿用上一次做好的；沒有的話遊戲用程序人偶，不擋測試）
# 環境變數：ART_PYTHON（預設 python3；bpy 5.3.0 的 wheel 只有 Python 3.13）、ART_FORCE=1 強制重做、ART_ONLY=<id> 只做一個。
# 加一個角色：下面 SRC／ARGS 各加一行，scripts/import_characters.py 的 KNOWN 也加上 id。
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY="${ART_PYTHON:-python3}"
OUT="$ROOT/build/art/characters"
TOOL="$ROOT/tools/blender/tripo_character.py"
BPY_VERSION="5.3.0"
# 遊戲裡的角色 id → Tripo 的來源檔
declare -A SRC=(
  [noen]="art-inbox/tripo/noen_rank_f_v2/noen_rank_f_v2_rig.glb"
  [sheila]="art-inbox/tripo/sheila_rank_f/sheila_rank_f_rig.glb"
)
# 給 tripo_character.py 的參數：--height 身高（m）、--attack swing|thrust（出手的動作，預設 swing＝往下劈）
declare -A ARGS=(
  [noen]="--height 1.74"
  [sheila]="--height 1.65"
)

todo=()
declare -A stamps
for id in "${!SRC[@]}"; do
  src="$ROOT/${SRC[$id]}"
  [[ -s "$src" ]] || { echo "[art] $id：找不到 ${SRC[$id]}，略過"; continue; }
  [[ -n "${ART_ONLY:-}" && "${ART_ONLY}" != "$id" ]] && continue
  stamps[$id]="$(cat "$ROOT/tools/blender/common.py" "$TOOL" "$src" | sha256sum | cut -d' ' -f1) ${ARGS[$id]:-}"
  if [[ "${ART_FORCE:-0}" != "1" && -s "$OUT/$id/$id.glb" && "$(cat "$OUT/$id/.stamp" 2>/dev/null)" == "${stamps[$id]}" ]]; then
    echo "[art] $id：沒改，沿用 build/art/characters/$id/$id.glb"
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

# 先做在 new/ 裡，成功才搬到定位並寫 .stamp；失敗就什麼都不動（上一次做好的照用），下一次會再試。
for id in "${todo[@]}"; do
  mkdir -p "$OUT/$id/new"
  # shellcheck disable=SC2086
  if "$PY" -I "$TOOL" --src "$ROOT/${SRC[$id]}" --out "$OUT/$id/new/$id.glb" --name "$id" ${ARGS[$id]:-} > "$OUT/$id/gen.log" 2>&1 \
      && [[ -s "$OUT/$id/new/$id.glb" ]]; then
    mv -f "$OUT/$id/new/$id.glb" "$OUT/$id/$id.glb"
    echo "${stamps[$id]}" > "$OUT/$id/.stamp"
    grep "^\[$id\]" "$OUT/$id/gen.log" | sed 's/^/[art] /'
  else
    echo "[art] tripo_character.py 失敗（$id）：沿用上一次做好的（沒有的話用程序人偶）；最後幾行："
    tail -n 15 "$OUT/$id/gen.log"
  fi
done
exit 0
