#!/usr/bin/env python3
"""打包驗證（M1.4）：檢查匯出的資料夾裡有遊戲需要的東西。

用法：python3 scripts/verify_package.py <匯出資料夾> [--exe 檔名]
  例：python3 scripts/verify_package.py build/windows --exe CursesTooUseful.exe

檢查：執行檔存在、PCK（獨立的 .pck，或 embed_pck 嵌在執行檔尾端）讀得到目錄（Godot 4.7 PCK 格式 v3／v4），
目錄裡有：專案設定、主選單與霜橋鎮場景、繁中與英文翻譯、任務／對話／日記資料、
程序生成的字型子集與全部音效（scripts/gen_sfx.py 產生、不進 git，最容易漏掉）。
Godot 匯出時會把圖片、音效等換成 .godot/imported 下的檔案，原路徑留下 .import／.remap，所以比對時兩種都認。
"""
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

REQUIRED = [
    "project.binary",
    "scenes/boot/boot.tscn",
    "scenes/levels/corrupt_forest.tscn",
    "i18n/strings.en.translation",
    "i18n/strings.zh_TW.translation",
    "data/status/statuses.json",
    "data/quests/ch1_main.json",
    "data/dialogue/ch1_forest_gate.json",
    "data/combat/tuning.json",
    "assets/generated/fonts/ui_sans_tc.otf",
    "assets/generated/fonts/title_serif_tc.otf",
]


def sfx_names() -> list[str]:
    """跟遊戲用同一份清單（src/core/sfx.gd 的 NAMES），新增音效時不用改這裡。"""
    src = (ROOT / "game/src/core/sfx.gd").read_text(encoding="utf-8")
    m = re.search(r"const NAMES: PackedStringArray = \[(.*?)\]", src)
    return re.findall(r'"([a-z0-9_]+)"', m.group(1)) if m else []


def pck_base(b: bytes) -> int:
    """PCK 在檔案裡的起點：獨立 .pck 是 0；嵌在執行檔裡（embed_pck）時，檔尾是 [u64 大小][GDPC]。"""
    if b[:4] == b"GDPC":
        return 0
    if len(b) >= 12 and b[-4:] == b"GDPC":
        (size,) = struct.unpack_from("<Q", b, len(b) - 12)
        base = len(b) - 12 - size
        if 0 <= base and b[base:base + 4] == b"GDPC":
            return base
    raise ValueError("找不到 PCK（開頭或檔尾沒有 GDPC）")


def read_pck_paths(b: bytes) -> list[str]:
    base = pck_base(b)
    version, _maj, _min, _pat, flags = struct.unpack_from("<IIIII", b, base + 4)
    if flags & 1:
        raise ValueError("PCK 目錄有加密，無法檢查")
    if version >= 3:
        _file_base, dir_offset = struct.unpack_from("<QQ", b, base + 24)
        # 目錄位置相對於 PCK 起點（嵌入時）；保險起見也試絕對位置
        candidates = [base + dir_offset, dir_offset]
    else:
        candidates = [base + 4 + 4 * 5 + 8 + 16 * 4]
    last_err: Exception = ValueError("讀不到目錄")
    for pos in candidates:
        try:
            return _read_dir(b, pos)
        except (ValueError, struct.error, UnicodeDecodeError) as err:
            last_err = err
    raise last_err


def _read_dir(b: bytes, pos: int) -> list[str]:
    (count,) = struct.unpack_from("<I", b, pos)
    if count == 0 or count > 100_000:
        raise ValueError(f"檔案數不合理（{count}）")
    pos += 4
    paths = []
    for _ in range(count):
        (n,) = struct.unpack_from("<I", b, pos)
        if n == 0 or n > 4096:
            raise ValueError("路徑長度不合理")
        pos += 4
        raw = b[pos:pos + n]
        pos += n
        pos += 8 + 8 + 16 + 4  # offset、size、md5、flags
        p = raw.rstrip(b"\0").decode("utf-8")
        paths.append(p[6:] if p.startswith("res://") else p)
    return paths


def has(paths: set[str], want: str) -> bool:
    return any(p in paths for p in (want, want + ".import", want + ".remap"))


def main() -> int:
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 2
    folder = Path(args[0])
    exe = args[args.index("--exe") + 1] if "--exe" in args else None
    problems = []
    if exe:
        e = folder / exe
        if not e.is_file() or e.stat().st_size < 1_000_000:
            problems.append(f"執行檔 {exe} 不存在或太小")
    # 獨立的 .pck 優先；沒有就找嵌在執行檔裡的（export_presets 的 embed_pck=true）
    holders = sorted(folder.glob("*.pck")) + ([folder / exe] if exe and (folder / exe).is_file() else [])
    if not holders:
        problems.append("找不到 .pck，也沒有可檢查的執行檔")
    else:
        holder = holders[0]
        data = holder.read_bytes()
        wanted = REQUIRED + [f"assets/generated/sfx/{n}.wav" for n in sfx_names()]
        try:
            paths = set(read_pck_paths(data))
            missing = [w for w in wanted if not has(paths, w)]
            how = f"{len(paths)} 個檔案"
        except (ValueError, struct.error, UnicodeDecodeError) as err:
            # 目錄格式讀不懂（引擎改版）時退回字串搜尋：路徑在 PCK 目錄裡是明文
            print(f"[package] 讀不到 {holder.name} 的 PCK 目錄（{err}），改用字串搜尋", file=sys.stderr)
            missing = [w for w in wanted if w.encode() not in data]
            how = "字串搜尋"
            if b"GDPC" not in data:
                problems.append(f"{holder.name} 裡沒有 PCK")
        for m in missing:
            problems.append(f"包裡少了 {m}")
        print(f"[package] {holder.name}（{how}）：必要檔案 {len(wanted) - len(missing)}/{len(wanted)}")
    if problems:
        for p in problems:
            print(f"[package] 問題：{p}", file=sys.stderr)
        return 1
    print("[package] 打包檢查通過")
    return 0


if __name__ == "__main__":
    sys.exit(main())
