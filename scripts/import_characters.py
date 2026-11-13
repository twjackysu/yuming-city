"""把角色模型收件檢查後複製進 Godot 專案（game/assets/characters/<id>/<id>.glb）。

來源依序找：art-inbox/characters/<id>/<id>.glb（Jacky 交的，優先）→ build/art/characters/<id>/<id>.glb
（scripts/gen_art.sh 用 bpy 自製的，D-249）。

- 收件檢查用 scripts/check_character_glb.py（純標準函式庫、不執行模型裡的任何東西）
- 還沒下載的 Git LFS 指標檔直接略過（雲端 session 沒有 git lfs pull 時）
- 檢查不過：印出原因、刪掉專案裡舊的複本 → 遊戲退回程序人偶
- 只在內容不同時才複製（避免每次都重新 import）
- HELD 裡的角色：自製的模型先不接（遊戲端還沒接完）；環境變數 ART_USE=<id> 可以在本機打開
由 scripts/gen-assets.sh 呼叫；遊戲端見 game/src/world/character_models.gd。
"""
import filecmp
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
INBOX = ROOT / 'art-inbox' / 'characters'
SELF_MADE = ROOT / 'build' / 'art' / 'characters'
DEST = ROOT / 'game' / 'assets' / 'characters'
CHECKER = ROOT / 'scripts' / 'check_character_glb.py'
KNOWN = ('noen', 'sheila', 'undertaker', 'ashwalker')
# 自製的模型做好了、但遊戲端還沒接完的角色：先不接進遊戲（D-251：諾恩換成模型之後 12 個劇情／戰鬥場的測試不過）。
# 本機要看模型：ART_USE=noen python3 -I scripts/import_characters.py（多個用逗號分開）。Jacky 放進 art-inbox 的不受影響。
HELD = ('noen',)


def is_lfs_pointer(path):
    with path.open('rb') as f:
        return f.read(40).startswith(b'version https://git-lfs')


def drop(dst):
    """把專案裡的複本拿掉，連 Godot 的 .import 一起（只剩 .import 的話 ResourceLoader 還是會說模型在）。"""
    for f in (dst, dst.with_name(dst.name + '.import')):
        if f.exists():
            f.unlink()


def main():
    imported = []
    for cid in KNOWN:
        src = INBOX / cid / f'{cid}.glb'
        dst = DEST / cid / f'{cid}.glb'
        source = 'art-inbox'
        if src.exists() and is_lfs_pointer(src):
            print(f'[characters] {cid}: art-inbox 的還是 LFS 指標檔（沒有 git lfs pull），略過')
        if not src.exists() or is_lfs_pointer(src):
            src = SELF_MADE / cid / f'{cid}.glb'
            source = '自製'
            if cid in HELD and cid not in os.environ.get('ART_USE', '').split(','):
                if src.exists():
                    print(f'[characters] {cid}: 自製的模型做好了，但遊戲端還沒接完，先用程序人偶（本機要看：ART_USE={cid}）')
                src = SELF_MADE / cid / 'held'  # 當成沒有來源：下面會把專案裡的複本拿掉
        if not src.exists():
            drop(dst)  # 來源沒了（例如自製腳本失敗）：不要留著舊的複本
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
            drop(dst)
            continue
        dst.parent.mkdir(parents=True, exist_ok=True)
        if not dst.exists() or not filecmp.cmp(src, dst, shallow=False):
            shutil.copyfile(src, dst)
        imported.append(cid)
        print(f'[characters] {cid}: 通過收件檢查（{source}，{report.get("triangles")} 面），已接入')
    if not imported:
        print('[characters] 沒有可用的正式模型，全部用程序人偶')


if __name__ == '__main__':
    main()
