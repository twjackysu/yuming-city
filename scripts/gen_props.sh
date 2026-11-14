#!/usr/bin/env bash
# Tripo 產的武器、物件與沒有骨架的怪物（art-inbox/tripo/<名字>/<名字>_model.glb）：用 tools/blender/tripo_prop.py 擺正、縮到實際大小，
# 產物放 build/art/props/<名字>.glb，再複製到 game/assets/props/tripo/（不進 git）。scripts/gen-assets.sh 會呼叫。
# 來源或腳本沒改就跳過；裝不了 bpy 或失敗：印出原因、回傳 0（遊戲退回程式拼的替身）。
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY="${ART_PYTHON:-python3}"
OUT="$ROOT/build/art/props"
DEST="$ROOT/game/assets/props/tripo"
TOOL="$ROOT/tools/blender/tripo_prop.py"
# 名字 → 給 tripo_prop.py 的參數
declare -A ARGS=(
  [weapon_rusty_miasma_sword]="--kind weapon --like sword --head far_from_wide"
  [weapon_ominous_split_blade]="--kind weapon --like sword --head far_from_wide"
  [weapon_longsword]="--kind weapon --like sword --head far_from_wide"
  [weapon_staff]="--kind weapon --like staff --head wide"
  [weapon_shortsword]="--kind weapon --head far_from_wide --length 0.60 --grip 0.14"
  [weapon_axe]="--kind weapon --head wide --length 0.85 --grip 0.15"
  [weapon_hammer]="--kind weapon --head wide --length 0.85 --grip 0.15"
  [weapon_bow]="--kind weapon --head keep --length 1.20 --grip 0.50"
  [enemy_poison_slime]="--kind prop --height 0.80"
  [enemy_mold_slime]="--kind prop --height 0.80"
  [prop_corrupt_tree]="--kind prop --height 6.50"
  [prop_glow_toxic_mushroom]="--kind prop --height 1.10"
  [prop_rotten_fruit_bush]="--kind prop --height 1.60"
  [prop_cursed_chest]="--kind prop --height 0.75"
  [prop_campfire_v2]="--kind prop --height 1.10"
  [prop_ruined_altar]="--kind prop --height 1.40"
  [prop_guild_quest_board]="--kind prop --height 2.30"
  [prop_guild_signboard]="--kind prop --height 2.40"
  [prop_guild_counter_v2]="--kind prop --height 1.15"
  [prop_aptitude_crystal]="--kind prop --height 0.60"
)
mkdir -p "$OUT" "$DEST"
have_bpy=""
for name in "${!ARGS[@]}"; do
  src="$ROOT/art-inbox/tripo/$name/${name}_model.glb"
  [[ -s "$src" ]] || continue
  stamp="$(cat "$TOOL" "$src" | sha256sum | cut -d' ' -f1) ${ARGS[$name]}"
  if [[ "${ART_FORCE:-0}" != "1" && -s "$OUT/$name.glb" && "$(cat "$OUT/$name.stamp" 2>/dev/null)" == "$stamp" ]]; then
    :
  else
    if [[ -z "$have_bpy" ]]; then
      "$PY" -I -c "import bpy" 2>/dev/null && have_bpy=1 || { echo "[props] 沒有 bpy，這次不處理 Tripo 的武器與物件"; break; }
    fi
    # shellcheck disable=SC2086
    if "$PY" -I "$TOOL" --src "$src" --out "$OUT/$name.new.glb" ${ARGS[$name]} > "$OUT/$name.log" 2>&1 && [[ -s "$OUT/$name.new.glb" ]]; then
      mv -f "$OUT/$name.new.glb" "$OUT/$name.glb"
      echo "$stamp" > "$OUT/$name.stamp"
      grep "^\[$name" "$OUT/$name.log" | sed 's/^/[props] /'
    else
      echo "[props] $name 失敗，最後幾行："; tail -n 8 "$OUT/$name.log"
      continue
    fi
  fi
  cmp -s "$OUT/$name.glb" "$DEST/$name.glb" || cp -f "$OUT/$name.glb" "$DEST/$name.glb"
done
exit 0
