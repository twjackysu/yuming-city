"""席菈（sheila）：短披肩、兜帽似的黑髮、厚布上衣＋下襬、護臂手套、長褲、靴子、腰帶。共用的部分在 common.py。

    python3 -I tools/blender/sheila.py --mh <makehuman/data> --out <sheila.glb> [--preview <png>]

動作：idle、walk、run、light_attack_01。身高 1.70。
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I 不會把腳本的資料夾放進 sys.path
import common as c  # noqa: E402


class Sheila(c.Spec):
    name = "sheila"


if __name__ == "__main__":
    c.run(Sheila())
