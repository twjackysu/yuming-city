#!/usr/bin/env python3
"""程序生成音效（不進 git），輸出到 game/assets/generated/sfx/*.wav。

只用標準函式庫（wave、math、random），固定亂數種子，每次產生的檔案相同。
- bell / bell_ninth：鐘聲。非諧波泛音（鐘的典型比例），各自指數衰減；第九聲更低、更長、帶一點拍頻。
- blunt / blunt_weak：鐘錘鈍擊。低頻下滑正弦＋短噪音；打中弱點多一層高頻「喀」。
- claw：爪擊。高通噪音快掃。
- slash：席菈斷劍。帶通噪音＋金屬泛音。
- whoosh：閃避風聲。慢起慢落的低通噪音。
授權：程序生成，無外部素材（docs/CREDITS.md）。
"""
import math
import random
import struct
import sys
import wave
from pathlib import Path

RATE = 44100
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "generated" / "sfx"


def write(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    k = 0.89 / peak
    path = OUT / f"{name}.wav"
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * k)) * 32767)) for s in samples))
    return path


def onepole_lp(xs, cutoff):
    a = math.exp(-2.0 * math.pi * cutoff / RATE)
    y = 0.0
    out = []
    for x in xs:
        y = (1 - a) * x + a * y
        out.append(y)
    return out


def hp(xs, cutoff):
    low = onepole_lp(xs, cutoff)
    return [x - l for x, l in zip(xs, low)]


def noise(n, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def bell(fundamental, seconds, beat=0.0):
    # 鐘的泛音比例（hum、prime、tierce、quint、nominal…）與相對強度、衰減
    partials = [(0.5, 0.35, 0.9), (1.0, 0.6, 1.4), (1.183, 0.4, 2.0), (1.506, 0.25, 2.6),
                (2.0, 0.45, 3.2), (2.514, 0.18, 4.5), (2.662, 0.15, 5.0), (3.011, 0.1, 6.0), (4.166, 0.06, 8.0)]
    n = int(seconds * RATE)
    out = [0.0] * n
    for ratio, amp, decay in partials:
        f = fundamental * ratio
        for i in range(n):
            t = i / RATE
            env = math.exp(-decay * t / seconds * 2.2)
            wob = 1.0 + (0.12 * math.sin(2 * math.pi * beat * t) if beat else 0.0)
            out[i] += amp * env * wob * math.sin(2 * math.pi * f * t)
    # 敲擊瞬間的金屬噪音
    rng = random.Random(9)
    strike = hp(noise(int(0.03 * RATE), rng), 2500)
    for i, s in enumerate(strike):
        out[i] += 0.5 * s * (1 - i / len(strike))
    # 起音 3 ms
    for i in range(int(0.003 * RATE)):
        out[i] *= i / (0.003 * RATE)
    return out


def thump(seconds, f0, f1, crack=0.0, seed=1):
    rng = random.Random(seed)
    n = int(seconds * RATE)
    out = []
    phase = 0.0
    nz = onepole_lp(noise(n, rng), 900)
    for i in range(n):
        t = i / RATE
        f = f1 + (f0 - f1) * math.exp(-t * 30)
        phase += 2 * math.pi * f / RATE
        env = math.exp(-t * 18)
        out.append(0.9 * env * math.sin(phase) + 0.6 * nz[i] * math.exp(-t * 40))
    if crack:
        c = hp(noise(int(0.04 * RATE), rng), 3000)
        for i, s in enumerate(c):
            out[i] += crack * s * math.exp(-i / RATE * 90)
    return out


def swish(seconds, lo, hi, seed, rise=0.35, metal=0.0):
    rng = random.Random(seed)
    n = int(seconds * RATE)
    band = onepole_lp(hp(noise(n, rng), lo), hi)
    out = []
    for i in range(n):
        t = i / seconds / RATE
        env = (t / rise) if t < rise else math.exp(-(t - rise) * 6)
        s = band[i] * env
        if metal:
            s += metal * env * math.sin(2 * math.pi * 3150 * i / RATE) * math.exp(-t * 4)
        out.append(s)
    return out


def main():
    made = [
        write("bell", bell(196.0, 3.0)),
        write("bell_ninth", bell(146.8, 6.0, beat=1.3)),
        write("blunt", thump(0.3, 140, 55, seed=2)),
        write("blunt_weak", thump(0.38, 170, 50, crack=0.8, seed=3)),
        write("claw", swish(0.22, 1800, 9000, seed=4, rise=0.2)),
        write("slash", swish(0.28, 900, 7000, seed=5, rise=0.3, metal=0.25)),
        write("whoosh", swish(0.35, 200, 1600, seed=6, rise=0.45)),
    ]
    for p in made:
        print(f"{p.name}: {p.stat().st_size // 1024} KB")


if __name__ == "__main__":
    sys.exit(main())
