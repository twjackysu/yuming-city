#!/usr/bin/env python3
"""程序生成音效（不進 git），輸出到 game/assets/generated/sfx/*.wav。

只用標準函式庫（wave、math、random），固定亂數種子，每次產生的檔案相同。
- bell / bell_ninth：鐘聲。非諧波泛音（鐘的典型比例），各自指數衰減；第九聲更低、更長、帶一點拍頻。
- blunt / blunt_weak：鐘錘鈍擊。低頻下滑正弦＋短噪音；打中弱點多一層高頻「喀」。
- claw：爪擊。高通噪音快掃。
- slash：席菈斷劍。帶通噪音＋金屬泛音。
- whoosh：閃避風聲。慢起慢落的低通噪音。
- ui_tick：選單切換值。很小的一聲高音鐘「叮」（兩個非諧波泛音快速衰減）＋極短的木頭「喀」。
- water_splash：一桶髒水從天花板倒下來（第 1 章一百七十二階）。木桶「咚」＋一陣低通噪音的嘩啦，尾巴是幾聲滴水。
- child_laugh：樓梯深處小孩的笑聲（第 1 章）。高音的「哈、哈、哈」：脈衝串經過兩個母音共振峰，加長的回音當作「很遠、在石階下面」。
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


def heartbeat(seconds=0.9):
    """九息倒數：低沉的「咚—咚」（lub-dub），尾巴帶一點空間感。"""
    a = thump(0.22, 75, 38, seed=7)
    b = thump(0.2, 68, 34, seed=8)
    n = int(seconds * RATE)
    out = [0.0] * n
    off = int(0.17 * RATE)
    for i, v in enumerate(a):
        out[i] += 0.95 * v
    for i, v in enumerate(b):
        if off + i < n:
            out[off + i] += 0.7 * v
    return onepole_lp(out, 420)


def scrape(seconds=0.42, seed=9):
    """搬瓦礫：石頭互相刮、碎石滾落（帶顆粒的中頻雜訊＋幾下小碰撞）。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    band = onepole_lp(hp(noise(n, rng), 280), 2600)
    out = []
    grain = 0.0
    for i in range(n):
        t = i / RATE
        if rng.random() < 0.004:
            grain = rng.uniform(0.6, 1.0)
        grain *= 0.9993
        env = min(t / 0.04, 1.0) * math.exp(-max(t - 0.12, 0.0) * 7)
        out.append(band[i] * env * (0.35 + grain))
    for k in range(3):
        start = int(rng.uniform(0.05, seconds - 0.12) * RATE)
        hit = thump(0.1, rng.uniform(220, 320), 90, crack=0.4, seed=seed + k + 1)
        for j, v in enumerate(hit):
            if start + j < n:
                out[start + j] += 0.35 * v
    return out


def clang(seconds=1.1, seed=11):
    """鐵架撞上石拱：不和諧的金屬泛音（快速衰減）＋一下沉重的撞擊。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    partials = [(410, 1.0, 5.0), (1130, 0.6, 7.0), (1870, 0.45, 9.0), (2930, 0.3, 12.0), (4410, 0.18, 16.0)]
    out = [0.0] * n
    for f, a, d in partials:
        f *= rng.uniform(0.98, 1.02)
        for i in range(n):
            t = i / RATE
            out[i] += a * math.exp(-t * d) * math.sin(2 * math.pi * f * t)
    hit = thump(0.35, 120, 45, crack=1.0, seed=seed + 1)
    for i, v in enumerate(hit):
        out[i] = 0.35 * out[i] + 0.9 * v
    return out


def ignite(seconds=0.9, seed=13):
    """燃燒劍點火：低頻「轟」一聲往上衝，接著火星的劈啪聲。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    roar = onepole_lp(hp(noise(n, rng), 90), 1400)
    out = []
    for i in range(n):
        t = i / RATE
        env = min(t / 0.06, 1.0) * math.exp(-max(t - 0.1, 0.0) * 4.5)
        out.append(roar[i] * env * 1.3)
    for k in range(14):
        start = int(rng.uniform(0.04, seconds - 0.05) * RATE)
        amp = rng.uniform(0.2, 0.55)
        for j in range(int(0.006 * RATE)):
            if start + j < n:
                out[start + j] += amp * rng.uniform(-1, 1) * math.exp(-j / RATE * 900)
    return out


def ui_tick(seconds=0.14, seed=17):
    """選單切換值：很小的一聲高音鐘「叮」＋極短的木頭「喀」，跟遊戲的鐘同一個語彙、不搶戲。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    click = onepole_lp(hp(noise(int(0.004 * RATE), rng), 1500), 6000)
    out = []
    for i in range(n):
        t = i / RATE
        ping = (math.sin(2 * math.pi * 1568.0 * t) * 0.55 + math.sin(2 * math.pi * 1568.0 * 2.41 * t) * 0.2) * math.exp(-t * 38.0)
        attack = min(1.0, t / 0.0015)
        c = click[i] * 0.5 if i < len(click) else 0.0
        out.append(ping * attack + c)
    return out


def water_splash(seconds=1.6, seed=19):
    """一桶髒水倒下來：木桶翻倒的悶響＋嘩啦（低通噪音，快起慢落）＋幾滴水。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    gush = onepole_lp(hp(noise(n, rng), 120), 2600)
    out = []
    for i in range(n):
        t = i / RATE
        env = min(t / 0.03, 1.0) * math.exp(-max(t - 0.15, 0.0) * 3.2)
        # 水一波一波落下：慢速的幅度起伏
        wob = 0.75 + 0.25 * math.sin(2 * math.pi * 7.0 * t + rng.uniform(-0.2, 0.2))
        out.append(gush[i] * env * wob * 1.2)
    knock = thump(0.25, 110, 60, seed=seed + 1)
    for i, v in enumerate(knock):
        out[i] += 0.5 * v
    for k in range(6):
        start = int(rng.uniform(0.7, seconds - 0.08) * RATE)
        f = rng.uniform(900, 1500)
        for j in range(int(0.05 * RATE)):
            if start + j < n:
                tt = j / RATE
                out[start + j] += 0.18 * math.sin(2 * math.pi * (f + 2400 * tt) * tt) * math.exp(-tt * 70)
    return out


def child_laugh(seconds=1.9, seed=23):
    """遠處小孩的笑聲：五聲「哈」（音高略往下）、聲門脈衝經過 /a/ 的兩個共振峰，加三道回音（石階深處）。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    dry = [0.0] * n
    beats = [0.0, 0.17, 0.33, 0.5, 0.7]
    for b, start_t in enumerate(beats):
        f0 = 430.0 - b * 18.0 + rng.uniform(-8, 8)
        length = 0.12 + rng.uniform(0.0, 0.03)
        phase = 0.0
        start = int(start_t * RATE)
        for j in range(int(length * RATE)):
            i = start + j
            if i >= n:
                break
            t = j / RATE
            env = math.sin(math.pi * t / length) ** 1.5
            phase += f0 * (1.0 - 0.15 * t / length) / RATE
            # 聲門脈衝：幾個諧波，強度往高頻遞減
            v = sum(math.sin(2 * math.pi * h * phase) / h for h in range(1, 9))
            dry[i] += v * env + 0.25 * rng.uniform(-1, 1) * env  # 一點氣音
    # 母音 /a/ 共振峰（約 1000 Hz、1600 Hz）：兩個簡單的帶通疊起來
    def bandpass(xs, f, q):
        w = 2 * math.pi * f / RATE
        r = math.exp(-w / (2 * q))
        a1, a2 = -2 * r * math.cos(w), r * r
        y1 = y2 = 0.0
        out = []
        for x in xs:
            y = (1 - r) * x - a1 * y1 - a2 * y2
            y2, y1 = y1, y
            out.append(y)
        return out
    voiced = [a + 0.6 * b for a, b in zip(bandpass(dry, 1000, 5), bandpass(dry, 1600, 6))]
    voiced = onepole_lp(voiced, 3000)
    out = [v * 0.35 for v in voiced]
    for delay, gain in [(0.11, 0.45), (0.23, 0.3), (0.37, 0.18)]:
        d = int(delay * RATE)
        for i in range(n - d):
            out[i + d] += voiced[i] * gain * 0.35
    return onepole_lp(out, 2400)


def main():
    made = [
        write("bell", bell(196.0, 3.0)),
        write("bell_ninth", bell(146.8, 6.0, beat=1.3)),
        write("blunt", thump(0.3, 140, 55, seed=2)),
        write("blunt_weak", thump(0.38, 170, 50, crack=0.8, seed=3)),
        write("claw", swish(0.22, 1800, 9000, seed=4, rise=0.2)),
        write("slash", swish(0.28, 900, 7000, seed=5, rise=0.3, metal=0.25)),
        write("whoosh", swish(0.35, 200, 1600, seed=6, rise=0.45)),
        write("heartbeat", heartbeat()),
        write("rubble_scrape", scrape()),
        write("iron_clang", clang()),
        write("ignite", ignite()),
        write("ui_tick", ui_tick()),
        write("water_splash", water_splash()),
        write("child_laugh", child_laugh()),
    ]
    for p in made:
        print(f"{p.name}: {p.stat().st_size // 1024} KB")


if __name__ == "__main__":
    sys.exit(main())
