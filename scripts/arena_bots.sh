#!/usr/bin/env bash
# 戰鬥場的機器人對打（docs/design/11-combat-first.md 第 4 節，D-238）：
#   scripts/arena_bots.sh              # 四波 × 四種機器人，各 20 場，印一張 Markdown 表（約 7 分鐘）
#   RUNS=5 WAVES="1 3" BOTS="mash skilled" scripts/arena_bots.sh
#   BOTS=skilled EXTRA="--no-release" TAG="-norelease" scripts/arena_bots.sh   # 會打的機器人不找毒、不釋放（量「放與不放」差多少，D-245）
# 無頭、--fixed-fps 60（不等真實時間；一場約 0.3～3 秒）。每場的明細在 build/arena/<波>-<機器人>.log。
# 先跑過一次 scripts/check.sh（或 --import）再用。這些數字量得出難度與節奏，量不出好不好玩。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
GODOT="$(scripts/get-godot.sh)"
RUNS="${RUNS:-20}"
WAVES="${WAVES:-1 2 3 4}"
BOTS="${BOTS:-idle mash circle skilled}"
# EXTRA＝多給遊戲的旗標；TAG＝明細檔名後面加的字（不同設定的明細才不會互相蓋掉）
EXTRA="${EXTRA:-}"
TAG="${TAG:-}"
OUT="$ROOT/build/arena"
mkdir -p "$OUT"

for w in $WAVES; do
  for b in $BOTS; do
    log="$OUT/$w-$b$TAG.log"
    # shellcheck disable=SC2086
    timeout 900 "$GODOT" --headless --fixed-fps 60 --path game -- --arena --wave="$w" --bot="$b" --runs="$RUNS" $EXTRA > "$log" 2>&1 || true
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

python3 - "$OUT" "$WAVES" "$BOTS" "$TAG" <<'PY'
import re, sys, pathlib
out, waves, bots, tag = pathlib.Path(sys.argv[1]), sys.argv[2].split(), sys.argv[3].split(), sys.argv[4]
names = {"idle": "站著不動", "mash": "亂按", "circle": "繞著按", "skilled": "會打的"}
# 最後三欄（D-241）：每場平均打斷敵人的前兆幾次、敵人「硬撐」（整個人變紅＝該閃了）幾次、失衡跪下幾次——從每場那一行算
# 最後一欄（D-242）：每場平均打倒幾個／這一波總共幾個（一波的人分批進場；輸的時候看得出撐到第幾個）
# 再後面兩欄（D-245）：每場平均按了幾次「釋放」、毒爆扣的血占諾恩全部傷害的幾成
# 再一欄（D-246）：每場平均丟毒瓶的愣住幾次（諾恩站在毒霧裡不出來的時候）
# 最後一欄（D-247）：他愣住的時候手一滑、被自己的毒嗆到，每場平均扣了多少血（生命 70）
print("| 波 | 機器人 | 場數 | 勝率 | 打不完 | 贏的平均秒數 | 輸的平均秒數 | 被打中幾下 | 諾恩傷害占比 | 打斷前兆 | 敵人變紅 | 敵人跪下 | 打倒／總共 | 釋放幾次 | 毒爆占諾恩傷害 | 丟毒瓶的愣住 | 他被自己的毒扣的血 |")
print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
for w in waves:
    for b in bots:
        line = [l for l in (out / f"{w}-{b}{tag}.log").read_text(encoding="utf-8").splitlines() if l.startswith("ARENA_SUMMARY")][-1]
        f = dict(re.findall(r"(\w+)=(\S+)", line))
        fights = [dict(re.findall(r"(\w+)=(\S+)", l)) for l in (out / f"{w}-{b}{tag}.log").read_text(encoding="utf-8").splitlines() if l.startswith("ARENA wave=")]
        avg = lambda k: (sum(float(x.get(k, 0)) for x in fights) / len(fights)) if fights else 0.0
        dealt = sum(float(x.get("noen_dmg", 0)) for x in fights)
        burst = 100.0 * sum(float(x.get("burst_dmg", 0)) for x in fights) / dealt if dealt > 0 else 0.0
        wins = float(f["win_rate"])
        win_sec = f["avg_win_sec"] if wins > 0 else "—"
        lose_sec = f["avg_lose_sec"] if wins < 100 and float(f["avg_lose_sec"]) > 0 else "—"
        print(f"| {w} | {names.get(b, b)} | {f['runs']} | {wins:.0f}% | {f['timeout']} | {win_sec} | {lose_sec} | {f['avg_hits_taken']} | {f['noen_share']}% | {avg('interrupts'):.1f} | {avg('braces'):.1f} | {avg('kneels'):.1f} | {avg('downed'):.1f}／{avg('total'):.0f} | {avg('releases'):.1f} | {burst:.0f}% | {avg('gawks'):.1f} | {avg('self_dmg'):.0f} |")
PY
