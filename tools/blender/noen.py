"""諾恩（noen）：玩家操作的人——整場都在畫面正中間、鏡頭看的是他的背。共用的部分在 common.py。

    python3 -I tools/blender/noen.py --mh <makehuman/data> --out <noen.glb> [--preview <png>]

輪廓照 docs/design/03：縫補過的長大衣（下襬到膝蓋、前面開衩）、圍巾（一條垂在背後）、右前臂的木板夾板。
配色：畫面是冬夜的街，大衣不能是黑的——暖的灰褐色＋深淺不一的補丁，圍巾是全身唯一鮮明的顏色（暗紅），從背後一眼找得到他。
動作：idle、walk、run、light_attack_01、release（「釋放」的那一下）。身高 1.74。
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I 不會把腳本的資料夾放進 sys.path
import common as c  # noqa: E402


class Noen(c.Spec):
    name = "noen"
    height = 1.74
    targets = (("universal-male-young-averagemuscle-averageweight", 1.0),
               ("asian-male-young", 0.34), ("caucasian-male-young", 0.33), ("african-male-young", 0.33))
    layers = ((0.014, c.HOOD), (0.021, c.TUNIC), (0.015, c.BRACER), (0.012, c.BOOT))
    bracer_sides = ("r",)  # 只有右前臂（夾板）
    short_hair = True
    skirt_rows = 14
    skirt_flare = 0.055
    skirt_slit = True

    def hem_z(self, J, crotch):
        return J["l-knee"].z - 0.03

    def materials(self):
        m = c.region_materials()
        coat = (0.165, 0.112, 0.072)  # 遊戲裡他站在燈下：0.25 的灰褐拍出來是米白色、像浴袍
        m[c.HOOD] = c.make_material("hair", (0.035, 0.03, 0.028), 0.5, bump="strand", bump_scale=9, strength=0.6, vary=0.25)
        m[c.TUNIC] = c.make_material("coat", coat, 0.86, bump="weave", bump_scale=55, strength=0.16, vary=0.16,
                                     patch=(0.25, 0.19, 0.125), patch_scale=10.0, patch_amount=0.22)
        m[c.SCARF] = c.make_material("scarf", (0.36, 0.062, 0.045), 0.92, bump="weave", bump_scale=120, strength=0.5, vary=0.15)
        m[c.SKIN] = c.make_material("skin", (0.50, 0.34, 0.26), 0.55, bump_scale=140, strength=0.06, vary=0.05)
        m[c.SCLERA] = c.make_material("sclera", (0.42, 0.40, 0.38), 0.3, strength=0.0, vary=0.0)
        m[c.BRACER] = c.make_material("splint", (0.60, 0.56, 0.47), 0.85, bump="quilt", bump_scale=60, strength=0.6, vary=0.18)  # 纏著繃帶的夾板
        m[c.GLOVE] = c.make_material("glove", (0.11, 0.075, 0.05), 0.6, bump="leather", bump_scale=130, strength=0.3)
        m[c.TROUSER] = c.make_material("trouser", (0.075, 0.07, 0.07), 0.88, bump="weave", bump_scale=260, strength=0.25)
        m[c.BOOT] = c.make_material("boot", (0.09, 0.055, 0.035), 0.5, bump="leather", bump_scale=80, strength=0.45)
        m[c.BELT] = c.make_material("belt", (0.07, 0.04, 0.026), 0.45, bump="leather", bump_scale=110, strength=0.35)
        m[c.METAL] = c.make_material("metal", (0.42, 0.36, 0.26), 0.45, metal=1.0, bump_scale=180, strength=0.12, vary=0.08)
        return m

    def extra_parts(self, bvh, J):
        return c.build_scarf(bvh, J)

    def animate(self, a):
        c.standard_actions(a)
        c.release_action(a)


if __name__ == "__main__":
    c.run(Noen())
