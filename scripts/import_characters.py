"""把 art-inbox/characters/<id>/<id>.glb 收件檢查後複製進 Godot 專案（game/assets/characters/<id>/<id>.glb）。

- 收件檢查用 scripts/check_character_glb.py（純標準函式庫、不執行模型裡的任何東西）
- 還沒下載的 Git LFS 指標檔直接略過（雲端 session 沒有 git lfs pull 時）
- 檢查不過：印出原因、刪掉專案裡舊的複本 → 遊戲退回程序人偶
- 只在內容不同時才複製（避免每次都重新 import）
由 scripts/gen-assets.sh 呼叫；遊戲端見 game/src/world/character_models.gd。
"""
import filecmp
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
INBOX = ROOT / 'art-inbox' / 'characters'
DEST = ROOT / 'game' / 'assets' / 'characters'
CHECKER = ROOT / 'scripts' / 'check_character_glb.py'
KNOWN = ('noen', 'sheila', 'undertaker', 'ashwalker')


def is_lfs_pointer(path):
    with path.open('rb') as f:
        return f.read(40).startswith(b'version https://git-lfs')


def main():
    imported = []
    for cid in KNOWN:
        src = INBOX / cid / f'{cid}.glb'
        dst = DEST / cid / f'{cid}.glb'
        if not src.exists():
            continue
        if is_lfs_pointer(src):
            print(f'[characters] {cid}: 還是 LFS 指標檔（沒有 git lfs pull），略過')
            continue
        r = subprocess.run([sys.executable, '-I', str(CHECKER), str(src), '--character', cid],
                           capture_output=True, text=True)
        try:
            report = json.loads(r.stdout)
        except json.JSONDecodeError:
            report = {'static_gate_pass': False, 'errors': [r.stdout.strip() or r.stderr.strip()]}
        if not report.get('static_gate_pass'):
            print(f'[characters] {cid}: 收件檢查沒過，用程序人偶')
            for e in report.get('errors', []):
                print(f'  - {e}')
            if dst.exists():
                dst.unlink()
            continue
        dst.parent.mkdir(parents=True, exist_ok=True)
        if not dst.exists() or not filecmp.cmp(src, dst, shallow=False):
            shutil.copyfile(src, dst)
        imported.append(cid)
        print(f'[characters] {cid}: 通過收件檢查（{report.get("triangles")} 面），已接入')
    if not imported:
        print('[characters] 沒有可用的正式模型，全部用程序人偶')


if __name__ == '__main__':
    main()
