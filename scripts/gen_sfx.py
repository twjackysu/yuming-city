#!/usr/bin/env python3
"""程序生成音效（不進 git），輸出到 game/assets/generated/sfx/*.wav。

只用標準函式庫（wave、math、random），固定亂數種子，每次產生的檔案相同。
- （bell() 沒有自己的音檔了：鐘聲的合成只給 title_theme／part_end_theme 裡遠遠的鐘用。非諧波泛音、各自指數衰減。）
- blunt / blunt_weak：鐘錘鈍擊。低頻下滑正弦＋短噪音；打中弱點多一層高頻「喀」。
- claw：爪擊。高通噪音快掃。
- slash：席菈斷劍。帶通噪音＋金屬泛音。
- whoosh：閃避風聲。慢起慢落的低通噪音。
- ui_tick：選單切換值。很小的一聲高音鐘「叮」（兩個非諧波泛音快速衰減）＋極短的木頭「喀」。
- market_murmur：地下市場的底噪（可循環 12 秒，D-230）。六個遠處的人聲（鋸齒波聲帶＋一個共振峰，音節一個個起伏、句子之間停頓）疊成聽不出內容的嗡嗡聲＋岩洞的空氣聲＋兩道短回音＋偶爾很小的碰撞聲。
- frost_wind：霜橋鎮冬夜的風雪（可循環 12 秒，D-180）。低低的風（低通噪音）＋一道慢慢滑動的帶通「呼——」（中心 260～720 Hz）＋細細的雪粒沙沙聲（高通噪音），三層都跟著陣風的包絡起伏；頭尾交叉淡化。
- title_theme：標題畫面的配樂（可循環 24 秒，D-181；走 Music 匯流排）。低低的長音鋪底（D2＋A2＋D3，每個音兩個微微走音的聲部互相拍頻，12 秒一次慢慢漲落）＋霧裡遠遠的鐘聲動機：D4、C4、A3 往下走三聲，十二秒後 D4、C4 再往下落到 F3（第二次停在更低的地方）；鐘聲低通、帶三個越來越悶的回音。
- step_snow／step_stone／step_wood：諾恩的腳步聲（D-182，各約 0.12～0.16 秒；播放時音高與音量隨機一點）。雪：一串很密的細小「喀嚓」（壓實雪粒，顆粒噪音、低通）＋很輕的悶聲；石：很短的低頻「咚」＋一點砂粒的高頻擦聲；木：中空的「叩」（180／420 Hz 兩個共鳴快速衰減）＋一點木板的吱。
- part_end_theme：第一部前半的收尾配樂（可循環 28 秒，D-188；結尾卡＋感謝試玩頁，走 Music 匯流排）。回答標題的鐘聲：標題是往下走（D4、C4、A3，第二次落到 F3），這裡從 F3 往上走（F3、A3、C4），第二次 A3、C4 停在 D4＝標題開頭那個音。底下是 F2＋C3 的長音（比收束的小三度暖一點）＋很小聲的 A3，14 秒一次漲落；鐘聲帶三個越來越悶的回音。
- step_heavy：送葬者的拖步（D-187，約 0.65 秒；不分地面）。很重的低頻「咚」（72 → 38 Hz 往下掉、加一個高八度的泛音讓小喇叭也聽得到）＋落地的悶悶碎響＋拖在後面的鐵鏈擦地（高通噪音、斷斷續續地抖）＋三下鐵環碰撞。
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


def svf_band(xs, freq_at, damping):
    """狀態變數濾波器的帶通輸出；freq_at(i) 回傳第 i 個樣本的中心頻率（可以隨時間滑動）。"""
    low = band = 0.0
    out = []
    for i, x in enumerate(xs):
        fc = 2.0 * math.sin(math.pi * min(freq_at(i), RATE / 6.0) / RATE)
        high = x - low - damping * band
        band += fc * high
        low += fc * band
        out.append(band)
    return out


def _loop_crossfade(out, n, fade):
    looped = out[:n]
    for i in range(fade):
        w = i / fade
        looped[i] = out[i] * w + out[n + i] * (1.0 - w)
    return looped


def _gust(t):
    """陣風包絡（0.25～1.0）：幾個不成整數比的慢正弦疊起來，偶爾一陣比較強。"""
    g = 0.5 + 0.22 * math.sin(2 * math.pi * 0.071 * t) + 0.16 * math.sin(2 * math.pi * 0.173 * t + 1.7) \
        + 0.1 * math.sin(2 * math.pi * 0.29 * t + 0.4)
    return max(0.25, min(1.0, g))


def frost_wind(seconds=12.0, seed=59):
    """霜橋鎮的風雪：低風底＋滑動的帶通呼嘯＋雪粒沙沙，跟著陣風起伏。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    fade = int(1.2 * RATE)
    total = n + fade
    white = noise(total, rng)
    bed = onepole_lp(onepole_lp(hp(white, 50), 420), 520)
    howl = svf_band(onepole_lp(white, 2000),
                    lambda i: 490 + 230 * math.sin(2 * math.pi * 0.053 * i / RATE + 0.6)
                    + 60 * math.sin(2 * math.pi * 0.21 * i / RATE), 0.16)
    hiss = hp(hp(noise(total, rng), 3200), 3200)
    out = []
    for i in range(total):
        g = _gust(i / RATE)
        out.append(bed[i] * (0.5 + 0.7 * g) * 1.6 + howl[i] * (g ** 2) * 0.55 + hiss[i] * (g ** 3) * 0.05)
    looped = _loop_crossfade(out, n, fade)
    peak = max(abs(v) for v in looped) or 1.0
    return [v / peak * 0.7 for v in looped]


def _far_voice(total, rng, f0, formant_lo, formant_hi):
    """遠處一個人在講話（聽不出內容）：鋸齒波的聲帶（每個音節音高滑一點）→ 一個共振峰（每個音節換一個母音）。
    音節一個個起伏，一句 3～9 個音節，句子之間停下來換氣、聽別人講。"""
    env = [0.0] * total
    form = [0.0] * total
    pitch = [0.0] * total
    cur_f = rng.uniform(formant_lo, formant_hi)
    cur_p = f0
    i = int(rng.uniform(0.0, 1.4) * RATE)
    while i < total:
        for _ in range(rng.randint(3, 9)):
            dur = int(rng.uniform(0.11, 0.26) * RATE)
            amp = rng.uniform(0.45, 1.0)
            nf = rng.uniform(formant_lo, formant_hi)
            npitch = f0 * rng.uniform(0.86, 1.2)
            for k in range(min(dur, total - i)):
                w = k / dur
                env[i + k] = amp * math.sin(math.pi * w)
                form[i + k] = cur_f + (nf - cur_f) * w
                pitch[i + k] = cur_p + (npitch - cur_p) * w
            cur_f, cur_p = nf, npitch
            i += dur + int(rng.uniform(0.0, 0.05) * RATE)
            if i >= total:
                break
        i += int(rng.uniform(0.35, 1.5) * RATE)
    out = []
    phase = 0.0
    low = band = 0.0
    fc = 2.0 * math.pi * cur_f / RATE
    for j in range(total):
        e = env[j]
        src = 0.0
        if e > 0.0:
            fc = 2.0 * math.pi * form[j] / RATE
            phase += pitch[j] / RATE
            phase -= int(phase)
            src = (2.0 * phase - 1.0) * e
        high = src - low - 0.3 * band
        band += fc * high
        low += fc * band
        out.append(band)
    return out


def market_murmur(seconds=12.0, seed=131):
    """地下市場的底噪（可循環 12 秒，D-230）：六個遠處的人聲疊起來（聽不出內容的嗡嗡聲，有起伏、不會整片安靜）
    ＋岩洞裡低低的空氣聲＋兩道短回音（岩壁）＋偶爾一聲很小的鍋蓋／瓶子的碰撞。頭尾交叉淡化。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    fade = int(1.2 * RATE)
    total = n + fade
    crowd = [0.0] * total
    for f0 in (104.0, 127.0, 149.0, 183.0, 208.0, 236.0):
        gain = rng.uniform(0.5, 1.0)
        voice = _far_voice(total, rng, f0, 290.0, 820.0)
        for i in range(total):
            crowd[i] += voice[i] * gain
    # 遠、隔著攤子與布棚：高頻收掉
    crowd = onepole_lp(onepole_lp(crowd, 2400), 3200)
    room = onepole_lp(onepole_lp(hp(noise(total, rng), 60), 260), 340)
    out = [crowd[i] + room[i] * 2.2 for i in range(total)]
    # 岩壁的兩道短回音
    for delay, amount in ((int(0.083 * RATE), 0.3), (int(0.137 * RATE), 0.22)):
        for i in range(delay, total):
            out[i] += out[i - delay] * amount
    peak = max(abs(v) for v in out) or 1.0
    out = [v / peak for v in out]
    # 偶爾的小碰撞聲（鍋蓋、玻璃瓶）：很小聲，不落在交叉淡化的那一段
    for _ in range(4):
        at = int(rng.uniform(0.8, seconds - 1.0) * RATE)
        freq = rng.uniform(1900.0, 3300.0)
        amp = rng.uniform(0.05, 0.11)
        for k in range(int(0.22 * RATE)):
            tt = k / RATE
            out[at + k] += amp * math.exp(-tt * 34.0) * (math.sin(2 * math.pi * freq * tt) + 0.5 * math.sin(2 * math.pi * freq * 2.31 * tt))
    looped = _loop_crossfade(out, n, fade)
    peak = max(abs(v) for v in looped) or 1.0
    return [v / peak * 0.7 for v in looped]


def _wavetable(partials, size=2048):
    """一個週期的波形表（整數倍泛音），長音用查表比逐點算 sin 快得多。"""
    return [sum(a * math.sin(2 * math.pi * k * i / size) for k, a in partials) for i in range(size)]


def title_theme(seconds=24.0, seed=67):
    """標題畫面的配樂：長音鋪底＋霧裡遠遠的鐘聲動機（往下走的三聲，第二次落得更低）。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    fade = int(2.0 * RATE)
    total = n + fade
    table = _wavetable([(1, 1.0), (2, 0.45), (3, 0.22), (4, 0.1), (5, 0.05)])
    size = len(table)
    drone = [0.0] * total
    # D2、A2、D3；每個音兩個聲部差零點幾 Hz，慢慢拍頻
    for f, amp in [(73.42, 0.5), (73.61, 0.42), (110.0, 0.3), (110.21, 0.26), (146.83, 0.12), (146.6, 0.1)]:
        ph = rng.random() * size
        step = f * size / RATE
        for i in range(total):
            drone[i] += amp * table[int(ph) % size]
            ph += step
    for i in range(total):
        t = i / RATE
        drone[i] *= 0.68 + 0.32 * math.sin(2 * math.pi * t / 12.0 - 1.2)  # 12 秒一次漲落，24 秒剛好兩次
    drone = onepole_lp(onepole_lp(drone, 650), 900)
    dpeak = max(abs(v) for v in drone) or 1.0
    out = [v / dpeak * 0.42 for v in drone]
    # 鐘聲動機：同一個音只合成一次
    bells = {}
    motif = [(2.0, 293.66, 1.0), (3.6, 261.63, 0.82), (5.2, 220.0, 0.9),
             (14.0, 293.66, 0.75), (15.6, 261.63, 0.66), (17.6, 174.61, 1.0)]
    for at, f, gain in motif:
        if f not in bells:
            b = onepole_lp(bell(f, 4.5), 2400)
            bpeak = max(abs(v) for v in b) or 1.0
            bells[f] = [v / bpeak for v in b]
        b = bells[f]
        # 原聲＋三個越來越小、越來越晚的回音（霧裡、石牆之間）
        for delay, tap in [(0.0, 0.34), (0.43, 0.12), (1.01, 0.06), (1.67, 0.03)]:
            start = int((at + delay) * RATE)
            g = gain * tap
            for j, v in enumerate(b):
                if start + j >= total:
                    break
                out[start + j] += g * v
    looped = _loop_crossfade(out, n, fade)
    peak = max(abs(v) for v in looped) or 1.0
    return [v / peak * 0.7 for v in looped]


def part_end_theme(seconds=28.0, seed=97):
    """第一部前半的收尾配樂（D-188）：F2＋C3 的長音、往上走的鐘聲（回答標題往下走的那三聲），第二次停在 D4。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    fade = int(2.5 * RATE)
    total = n + fade
    table = _wavetable([(1, 1.0), (2, 0.38), (3, 0.16), (4, 0.06)])
    size = len(table)
    drone = [0.0] * total
    for f, amp in [(87.31, 0.5), (87.47, 0.42), (130.81, 0.32), (130.6, 0.27), (174.61, 0.12), (220.0, 0.07)]:
        ph = rng.random() * size
        step = f * size / RATE
        for i in range(total):
            drone[i] += amp * table[int(ph) % size]
            ph += step
    for i in range(total):
        t = i / RATE
        drone[i] *= 0.7 + 0.3 * math.sin(2 * math.pi * t / 14.0 - 1.0)  # 14 秒一次，28 秒剛好兩次
    drone = onepole_lp(onepole_lp(drone, 750), 950)
    dpeak = max(abs(v) for v in drone) or 1.0
    out = [v / dpeak * 0.42 for v in drone]
    bells = {}
    motif = [(2.5, 174.61, 0.85), (4.1, 220.0, 0.8), (5.9, 261.63, 0.9),
             (15.5, 220.0, 0.7), (17.1, 261.63, 0.75), (19.4, 293.66, 1.0)]
    for at, f, gain in motif:
        if f not in bells:
            b = onepole_lp(bell(f, 4.5), 2600)
            bpeak = max(abs(v) for v in b) or 1.0
            bells[f] = [v / bpeak for v in b]
        b = bells[f]
        for delay, tap in [(0.0, 0.32), (0.43, 0.11), (1.01, 0.055), (1.67, 0.028)]:
            start = int((at + delay) * RATE)
            g = gain * tap
            for j, v in enumerate(b):
                if start + j >= total:
                    break
                out[start + j] += g * v
    looped = _loop_crossfade(out, n, fade)
    peak = max(abs(v) for v in looped) or 1.0
    return [v / peak * 0.7 for v in looped]


def _step_env(n, attack, decay):
    return [min(1.0, (i / RATE) / attack) * math.exp(-(i / RATE) * decay) for i in range(n)]


def step_snow(seed=71):
    """踩在雪上：很密的細小顆粒「喀嚓」＋很輕的悶聲。"""
    rng = random.Random(seed)
    n = int(0.16 * RATE)
    out = [0.0] * n
    # 顆粒：0.13 秒內 60 個極短的噪音點，越後面越稀
    for _ in range(60):
        at = int(abs(rng.gauss(0.03, 0.035)) * RATE)
        amp = rng.uniform(0.2, 1.0)
        for j in range(int(0.0025 * RATE)):
            if at + j >= n:
                break
            out[at + j] += amp * rng.uniform(-1, 1) * (1 - j / (0.0025 * RATE))
    out = onepole_lp(hp(out, 900), 4200)
    thud = onepole_lp(noise(n, rng), 160)
    env = _step_env(n, 0.006, 32)
    return [(out[i] * 0.9 + thud[i] * 3.0) * env[i] for i in range(n)]


def step_stone(seed=73):
    """踩在石板上：很短的低頻「咚」＋一點砂粒的擦聲。"""
    rng = random.Random(seed)
    n = int(0.12 * RATE)
    out = []
    grit = hp(noise(n, rng), 2500)
    for i in range(n):
        t = i / RATE
        thump = math.sin(2 * math.pi * (130 - 300 * t) * t) * math.exp(-t * 60)
        out.append(thump * 0.9 + grit[i] * 0.25 * math.exp(-t * 90))
    env = _step_env(n, 0.002, 18)
    return [out[i] * env[i] for i in range(n)]


def step_wood(seed=79):
    """踩在木板地上：中空的「叩」＋一點木板的吱。"""
    rng = random.Random(seed)
    n = int(0.15 * RATE)
    out = []
    click = onepole_lp(noise(n, rng), 3000)
    for i in range(n):
        t = i / RATE
        body = math.sin(2 * math.pi * 182 * t) * math.exp(-t * 38) * 0.8 + math.sin(2 * math.pi * 421 * t) * math.exp(-t * 70) * 0.45
        creak = math.sin(2 * math.pi * (760 + 900 * t) * t) * math.exp(-((t - 0.05) / 0.025) ** 2) * 0.05
        out.append(body + click[i] * 0.3 * math.exp(-t * 200) + creak)
    env = _step_env(n, 0.002, 10)
    return [out[i] * env[i] for i in range(n)]


def step_heavy(seed=89):
    """送葬者的拖步：很重的「咚」＋落地碎響＋拖在後面的鐵鏈擦地＋三下鐵環碰撞。"""
    rng = random.Random(seed)
    n = int(0.66 * RATE)
    out = [0.0] * n
    body = onepole_lp(noise(n, rng), 320)
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = 38.0 + 34.0 * math.exp(-t * 14.0)
        phase += 2 * math.pi * f / RATE
        attack = min(1.0, t / 0.004)
        boom = (math.sin(phase) + 0.7 * math.sin(2.0 * phase)) * math.exp(-t * 8.5) * attack
        out[i] = boom + body[i] * 2.4 * math.exp(-t * 16.0) * attack
    crunch = onepole_lp(hp(noise(int(0.07 * RATE), rng), 400), 2400)
    for i, v in enumerate(crunch):
        out[i] += 0.32 * v * math.exp(-(i / RATE) * 55.0) * min(1.0, (i / RATE) / 0.004)
    # 鐵鏈擦地：0.08～0.62 秒，忽大忽小地抖（兩個不成比例的慢正弦相乘）
    drag = onepole_lp(hp(noise(n, rng), 1600), 5200)
    t0, t1 = 0.08, 0.62
    for i in range(int(t0 * RATE), min(n, int(t1 * RATE))):
        t = i / RATE
        w = math.sin(math.pi * (t - t0) / (t1 - t0)) ** 1.5
        flutter = 0.55 + 0.45 * math.sin(2 * math.pi * 23.0 * t + 0.7) * math.sin(2 * math.pi * 6.3 * t)
        out[i] += 0.17 * drag[i] * w * flutter
    for at, f in [(0.11, 1750.0), (0.27, 2320.0), (0.44, 1980.0)]:
        start = int(at * RATE)
        for j in range(int(0.09 * RATE)):
            if start + j >= n:
                break
            t = j / RATE
            v = math.sin(2 * math.pi * f * t) + 0.5 * math.sin(2 * math.pi * f * 2.71 * t)
            out[start + j] += 0.1 * v * math.exp(-t * 60.0)
    # 尾巴 20 ms 淡出，避免截斷的爆音
    fade = int(0.02 * RATE)
    for j in range(fade):
        out[n - 1 - j] *= j / fade
    return out


def poison_hiss(seconds=0.9, seed=107, charge=False):
    """守衛噴毒（D-207）：高頻的嘶聲（滑動的帶通噪音＋一點更高的氣聲）。
    charge＝前兆：慢慢變大、音高往上（跟舉手揮擊的「呼」分得出來）；否則是噴出去那一下：快起慢落＋一聲很短的低頻「噗」。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    src = noise(n, rng)
    if charge:
        band = svf_band(src, lambda i: 2600.0 + 2800.0 * (i / n), 0.35)
    else:
        band = svf_band(src, lambda i: 5200.0 - 1800.0 * (i / n), 0.45)
    air = hp(src, 6000)
    out = []
    for i in range(n):
        t = i / n
        if charge:
            env = t ** 1.6 * (1.0 if t < 0.93 else (1.0 - t) / 0.07)
        else:
            env = min(t / 0.04, 1.0) * math.exp(-t * 4.2)
        s = (band[i] * 0.9 + air[i] * 0.25) * env
        if not charge:
            s += 0.5 * math.sin(2 * math.pi * 95 * i / RATE) * math.exp(-t * 18)
        out.append(s)
    return out


def glass_clink(seconds=0.42, seed=113):
    """玻璃瓶互相碰到（D-209，藥箱）：三下很短的高音「叮」（玻璃的非諧波泛音，衰減快），最後一下最輕。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    out = [0.0] * n
    tick = onepole_lp(hp(noise(int(0.003 * RATE), rng), 2500), 9000)
    for at, f, gain in [(0.0, 3320.0, 1.0), (0.07, 4150.0, 0.7), (0.13, 2890.0, 0.4)]:
        start = int(at * RATE)
        for j in range(int(0.26 * RATE)):
            if start + j >= n:
                break
            t = j / RATE
            v = math.sin(2 * math.pi * f * t) + 0.5 * math.sin(2 * math.pi * f * 2.32 * t) + 0.25 * math.sin(2 * math.pi * f * 3.9 * t)
            c = tick[j] * 0.6 if j < len(tick) else 0.0
            out[start + j] += gain * (0.3 * v * math.exp(-t * 42) * min(1.0, t / 0.0008) + c)
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak * 0.6 for v in out]


def interrupt_crack(seconds=0.2, seed=137):
    """出手被打斷（D-241）：棍子被敲偏的一聲短「喀」——乾的高頻一下＋很短的木頭共鳴，沒有低頻
    （跟命中的「咚」分得開：聽到這一聲＝他那一招沒了）。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    click = onepole_lp(hp(noise(n, rng), 1800), 8000)
    out = []
    for i in range(n):
        t = i / RATE
        wood = math.sin(2 * math.pi * 620 * t) * math.exp(-t * 26) + 0.5 * math.sin(2 * math.pi * 1480 * t) * math.exp(-t * 42)
        out.append(0.8 * click[i] * math.exp(-t * 70) + 0.6 * wood * min(1.0, t / 0.001))
    return out


def brace_warn(seconds=0.6, seed=139):
    """硬撐（D-241）：「這一下打不斷了，該閃」的警告。兩段：往上滑的低吼（帶泛音的 105→230 Hz，越來越大），
    收在一聲短而亮的金屬音（非諧波，像鐵箍被燒紅繃緊）。跟所有命中聲、前兆的「呼」都不像——只在這個時候出現。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    breath = svf_band(noise(n, rng), lambda i: 700.0 + 1500.0 * (i / n), 0.5)
    out = []
    phase = 0.0
    ring_at = 0.36
    for i in range(n):
        t = i / RATE
        u = min(t / ring_at, 1.0)
        f = 105.0 + 125.0 * u * u
        phase += 2 * math.pi * f / RATE
        growl = sum(math.sin(phase * k) / k for k in (1, 2, 3, 4, 5, 7))
        # 一點顫（28 Hz）：聽起來像咬牙，不是合成器的滑音
        growl *= 1.0 + 0.35 * math.sin(2 * math.pi * 28 * t)
        env = (u ** 1.5) if t < ring_at else math.exp(-(t - ring_at) * 16)
        s = 0.5 * growl * env + 0.35 * breath[i] * env
        if t >= ring_at - 0.02:
            r = t - (ring_at - 0.02)
            ring = math.sin(2 * math.pi * 1660 * r) + 0.6 * math.sin(2 * math.pi * 2490 * 1.07 * r) + 0.35 * math.sin(2 * math.pi * 4210 * r)
            s += 0.55 * ring * math.exp(-r * 14) * min(1.0, r / 0.002)
        out.append(s)
    for i in range(int(0.004 * RATE)):
        out[i] *= i / (0.004 * RATE)
    return out


def main():
    made = [
        write("blunt", thump(0.3, 140, 55, seed=2)),
        write("blunt_weak", thump(0.38, 170, 50, crack=0.8, seed=3)),
        write("claw", swish(0.22, 1800, 9000, seed=4, rise=0.2)),
        write("slash", swish(0.28, 900, 7000, seed=5, rise=0.3, metal=0.25)),
        write("whoosh", swish(0.35, 200, 1600, seed=6, rise=0.45)),
        write("rubble_scrape", scrape()),
        write("iron_clang", clang()),
        write("ui_tick", ui_tick()),
        write("frost_wind", frost_wind()),
        write("market_murmur", market_murmur()),
        write("title_theme", title_theme()),
        write("part_end_theme", part_end_theme()),
        write("step_snow", step_snow()),
        write("step_stone", step_stone()),
        write("step_wood", step_wood()),
        write("step_heavy", step_heavy()),
        write("poison_charge", poison_hiss(1.1, seed=107, charge=True)),
        write("poison_hiss", poison_hiss(0.9, seed=109)),
        write("glass_clink", glass_clink()),
        write("interrupt", interrupt_crack()),
        write("brace_warn", brace_warn()),
    ]
    for p in made:
        print(f"{p.name}: {p.stat().st_size // 1024} KB")


if __name__ == "__main__":
    sys.exit(main())
