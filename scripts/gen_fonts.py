#!/usr/bin/env python3
"""下載 Noto CJK TC（SIL OFL 1.1），依遊戲實際用到的字元子集化，輸出到 game/assets/generated/fonts/。

- 來源：github.com/notofonts/noto-cjk 的 release（版本與 SHA-256 固定在下面）。
- 產物不進 git（.gitignore 已排除 game/assets/generated/），CI 與本機用同一支腳本產生。
- 字元集合：game/i18n/*.csv 與 game/data/ 下所有文字檔用到的字，加上 ASCII 與常用中文標點。
"""
from __future__ import annotations

import hashlib
import io
import os
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
OUT_DIR = GAME / "assets" / "generated" / "fonts"
CACHE = Path(os.environ.get("YUMING_ASSET_CACHE", Path.home() / ".cache" / "yuming-assets"))

SOURCES = {
    "serif": (
        "https://github.com/notofonts/noto-cjk/releases/download/Serif2.003/10_NotoSerifCJKtc.zip",
        "b4aa07b217532c5859b3674d53588671e7e4f340054fc30e9bf417ee3b1aa4d4",
    ),
    "sans": (
        "https://github.com/notofonts/noto-cjk/releases/download/Sans2.004/09_NotoSansCJKtc.zip",
        "8ea0d6feb8e092c250710cdc75c138090832ddaa98d8ccb37cd89b03b72c331b",
    ),
}

# 輸出檔名 -> (來源, zip 內路徑)
OUTPUTS = {
    "title_serif_tc.otf": ("serif", "OTF/TraditionalChinese/NotoSerifCJKtc-SemiBold.otf"),
    "ui_sans_tc.otf": ("sans", "NotoSansCJKtc-Regular.otf"),
    "ui_sans_tc_medium.otf": ("sans", "NotoSansCJKtc-Medium.otf"),
}

EXTRA_CHARS = "，。、；：？！「」『』（）《》〈〉—…·～－０１２３４５６７８９％／　"


def fetch(name: str) -> Path:
    url, sha = SOURCES[name]
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / url.rsplit("/", 1)[1]
    if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest() != sha:
        print(f"下載 {url}", file=sys.stderr)
        tmp = path.with_suffix(".part")
        with urllib.request.urlopen(url) as resp, open(tmp, "wb") as f:
            while chunk := resp.read(1 << 20):
                f.write(chunk)
        digest = hashlib.sha256(tmp.read_bytes()).hexdigest()
        if digest != sha:
            tmp.unlink()
            raise SystemExit(f"SHA-256 不符：{url}（{digest}）")
        tmp.replace(path)
    return path


def collect_chars() -> str:
    chars = set(chr(c) for c in range(0x20, 0x7F))
    chars.update(EXTRA_CHARS)
    files = list((GAME / "i18n").glob("*.csv"))
    data_dir = GAME / "data"
    if data_dir.exists():
        files += [p for p in data_dir.rglob("*") if p.suffix in {".csv", ".json", ".txt", ".po"}]
    for p in files:
        chars.update(p.read_text(encoding="utf-8"))
    chars.discard("\n")
    chars.discard("\r")
    return "".join(sorted(chars))


def main() -> None:
    from fontTools import subset  # 延後匯入，讓缺套件時錯誤訊息清楚

    text = collect_chars()
    stamp = hashlib.sha256((text + repr(SOURCES) + repr(OUTPUTS)).encode()).hexdigest()
    stamp_file = OUT_DIR / ".stamp"
    if stamp_file.exists() and stamp_file.read_text() == stamp and all((OUT_DIR / n).exists() for n in OUTPUTS):
        print("字型已是最新", file=sys.stderr)
        return
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    zips = {name: zipfile.ZipFile(fetch(name)) for name in SOURCES}
    for out_name, (src, member) in OUTPUTS.items():
        font_bytes = zips[src].read(member)
        options = subset.Options()
        options.layout_features = ["*"]
        options.name_IDs = ["*"]
        options.notdef_outline = True
        font = subset.load_font(io.BytesIO(font_bytes), options)
        subsetter = subset.Subsetter(options)
        subsetter.populate(text=text)
        subsetter.subset(font)
        out = OUT_DIR / out_name
        subset.save_font(font, str(out), options)
        print(f"{out_name}: {out.stat().st_size // 1024} KB（{len(text)} 字）", file=sys.stderr)
    (OUT_DIR / "LICENSE-OFL.txt").write_bytes(zips["sans"].read("LICENSE"))
    stamp_file.write_text(stamp)


if __name__ == "__main__":
    main()
