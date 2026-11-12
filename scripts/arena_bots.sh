#!/usr/bin/env bash
# 戰鬥場的機器人對打（docs/design/11-combat-first.md 第 4 節，D-238）：
#   scripts/arena_bots.sh              # 四波 × 三種機器人，各 20 場，印一張 Markdown 表
#   RUNS=5 WAVES="1 3" BOTS="mash skilled" scripts/arena_bots.sh
# 無頭、--fixed-fps 60（不等真實時間；一場約 0.3～3 秒）。每場的明細在 build/arena/<波>-<機器人>.log。
# 先跑過一次 scripts/check.sh（或 --import）再用。這些數字量得出難度與節奏，量不出好不好玩。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
GODOT="$(scripts/get-godot.sh)"
RUNS="${RUNS:-20}"
WAVES="${WAVES:-1 2 3 4}"
BOTS="${BOTS:-idle mash skilled}"
OUT="$ROOT/build/arena"
mkdir -p "$OUT"

for w in $WAVES; do
  for b in $BOTS; do
    log="$OUT/$w-$b.log"
    timeout 900 "$GODOT" --headless --fixed-fps 60 --path game -- --arena --wave="$w" --bot="$b" --runs="$RUNS" > "$log" 2>&1 || true
    if grep -q "SCRIPT ERROR" "$log"; then
      echo "第 $w 波 $b：有 SCRIPT ERROR（見 $log）" >&2
      grep -n "SCRIPT ERROR" -A3 "$log" | head -12 >&2
      exit 1
    fi
    if ! grep -q "^ARENA_SUMMARY" "$log"; then
      echo "第 $w 波 $b：沒有跑完（見 $log）" >&2
      exit 1
    fi
  done
done

python3 - "$OUT" "$WAVES" "$BOTS" <<'PY'
import re, sys, pathlib
out, waves, bots = pathlib.Path(sys.argv[1]), sys.argv[2].split(), sys.argv[3].split()
names = {"idle": "站著不動", "mash": "亂按", "skilled": "會打的"}
print("| 波 | 機器人 | 場數 | 勝率 | 打不完 | 贏的平均秒數 | 輸的平均秒數 | 被打中幾下 | 諾恩傷害占比 |")
print("|---|---|---|---|---|---|---|---|---|")
for w in waves:
    for b in bots:
        line = [l for l in (out / f"{w}-{b}.log").read_text(encoding="utf-8").splitlines() if l.startswith("ARENA_SUMMARY")][-1]
        f = dict(re.findall(r"(\w+)=(\S+)", line))
        wins = float(f["win_rate"])
        win_sec = f["avg_win_sec"] if wins > 0 else "—"
        lose_sec = f["avg_lose_sec"] if wins < 100 and float(f["avg_lose_sec"]) > 0 else "—"
        print(f"| {w} | {names.get(b, b)} | {f['runs']} | {wins:.0f}% | {f['timeout']} | {win_sec} | {lose_sec} | {f['avg_hits_taken']} | {f['noen_share']}% |")
PY
