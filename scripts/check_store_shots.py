#!/usr/bin/env python3
"""檢查 scripts/store_shots.txt（Steam 商店截圖清單，D-145）：

- 每行至少有檔名、幀數，檔名不重複、幀數是正整數
- 每個旗標都是 `--名稱` 或 `--名稱=值`，而且名稱真的有在遊戲程式裡被讀（game/ 底下的 .gd 出現 "名稱"）
  ——旗標打錯字時截圖模式會默默忽略，拍出來的是別的畫面
- 清單至少 5 張（Steam 規定）

用法：python3 -P scripts/check_store_shots.py
"""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LIST = ROOT / "scripts" / "store_shots.txt"
FLAG = re.compile(r"^--([a-z][a-z0-9-]*)(=[^\s]+)?$")


def main() -> int:
    source = "\n".join(p.read_text(encoding="utf-8") for p in (ROOT / "game").rglob("*.gd"))
    problems: list[str] = []
    names: set[str] = set()
    count = 0
    for no, raw in enumerate(LIST.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) < 2:
            problems.append(f"第 {no} 行少了幀數：{line}")
            continue
        name, frames, flags = parts[0], parts[1], parts[2:]
        count += 1
        if name in names:
            problems.append(f"第 {no} 行檔名重複：{name}")
        names.add(name)
        if not frames.isdigit() or int(frames) <= 0:
            problems.append(f"第 {no} 行幀數不是正整數：{frames}")
        for flag in flags:
            m = FLAG.match(flag)
            if m is None:
                problems.append(f"第 {no} 行旗標格式不對：{flag}")
            elif f'"{m.group(1)}"' not in source:
                problems.append(f"第 {no} 行旗標 {flag}：遊戲程式裡沒有讀 \"{m.group(1)}\"")
    if count < 5:
        problems.append(f"只有 {count} 張，Steam 至少要 5 張")
    for p in problems:
        print(f"[store-shots] {p}", file=sys.stderr)
    if problems:
        return 1
    print(f"[store-shots] 清單 {count} 張，旗標都對得上")
    return 0


if __name__ == "__main__":
    sys.exit(main())
