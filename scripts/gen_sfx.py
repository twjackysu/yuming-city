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
- daylight_ambience：白晝城的環境音（第 1 章段落 7，可循環 8 秒）。鐘走得很慢的「喀、答」（每秒一下、木頭共鳴）＋遠處低低的水聲與幾滴水；頭尾交叉淡化，循環時沒有接縫。
- brace_creak：伊薩右腿金屬支架的「吱」一聲（第 2 章）。生鏽的鉸鏈：基頻從 620 Hz 往上滑到 900 Hz 再掉回來的摩擦音（調頻＋顆粒），帶一點金屬泛音，0.5 秒。
- deep_rumble：窗外那堵黑牆「動了一下」（第 2 章段落 5）。很低的隆隆聲：30～70 Hz 的低通噪音＋兩個慢慢拍頻的低音，0.4 秒湧上來、2.6 秒退掉，像隔著石牆感覺到的震動。
- cloth_knock：席菈用布包著的小石頭隔著銅片敲（第 3 章段落 2）。悶悶的「咚」：200 Hz 往下滑的短正弦＋很淡的銅片泛音（1.3／2.9 kHz，快速衰減，被布蓋住），0.25 秒。
- chain_creak：掛著的送葬者要轉頭之前，鏈子先響（第 3 章段落 2 的觀察提示音）。三下很輕的鐵環碰撞「喀啦」＋一聲低低的摩擦，0.7 秒。
- canal_ambience：乾運河的環境音（第 3 章，可循環 10 秒）。地底空空的低風聲（很低的低通噪音、慢慢起伏）＋遠處幾滴水（帶石牆的回音）＋吊樑很輕的一聲木頭嘎吱；頭尾交叉淡化，循環時沒有接縫。
- slap：彌夏打黎歐的那一巴掌（第 2 章段落 3）。不重：很短的一聲帶通噪音「啪」（1～4 kHz、60 毫秒內衰減）＋一點點低頻的肉聲，0.2 秒。
- frost_wind：霜橋鎮冬夜的風雪（可循環 12 秒，D-180）。低低的風（低通噪音）＋一道慢慢滑動的帶通「呼——」（中心 260～720 Hz）＋細細的雪粒沙沙聲（高通噪音），三層都跟著陣風的包絡起伏；頭尾交叉淡化。
- frost_wind_indoor：同一段風從屋裡聽（酒館、柯德家）：再低通兩次、去掉雪粒，只剩牆外悶悶的呼呼聲。
- hearth_crackle：酒館壁爐的柴火（可循環 7 秒，D-180）。低低的火焰呼嚕（低通噪音、快速閃爍的起伏）＋隨機的細小劈啪（每秒約 9 下，帶通 1.5～5 kHz 的極短噪音）＋幾聲比較大的爆裂（多一點低頻的「啵」）；頭尾交叉淡化。
- title_theme：標題畫面的配樂（可循環 24 秒，D-181；走 Music 匯流排）。低低的長音鋪底（D2＋A2＋D3，每個音兩個微微走音的聲部互相拍頻，12 秒一次慢慢漲落）＋霧裡遠遠的鐘聲動機：D4、C4、A3 往下走三聲，十二秒後 D4、C4 再往下落到 F3（第二次停在更低的地方）；鐘聲低通、帶三個越來越悶的回音。
- step_snow／step_stone／step_wood：諾恩的腳步聲（D-182，各約 0.12～0.16 秒；播放時音高與音量隨機一點）。雪：一串很密的細小「喀嚓」（壓實雪粒，顆粒噪音、低通）＋很輕的悶聲；石：很短的低頻「咚」＋一點砂粒的高頻擦聲；木：中空的「叩」（180／420 Hz 兩個共鳴快速衰減）＋一點木板的吱。
- part_end_theme：第一部前半的收尾配樂（可循環 28 秒，D-188；結尾卡＋感謝試玩頁，走 Music 匯流排）。回答標題的鐘聲：標題是往下走（D4、C4、A3，第二次落到 F3），這裡從 F3 往上走（F3、A3、C4），第二次 A3、C4 停在 D4＝標題開頭那個音。底下是 F2＋C3 的長音（比收束的小三度暖一點）＋很小聲的 A3，14 秒一次漲落；鐘聲帶三個越來越悶的回音。
- step_heavy：送葬者的拖步（D-187，約 0.65 秒；不分地面）。很重的低頻「咚」（72 → 38 Hz 往下掉、加一個高八度的泛音讓小喇叭也聽得到）＋落地的悶悶碎響＋拖在後面的鐵鏈擦地（高通噪音、斷斷續續地抖）＋三下鐵環碰撞。
- stair_ambience：一百七十二階的環境音（可循環 9 秒，D-180）。很深的石井裡空空的低風（比乾運河更低更悶）＋上面某處的滴水，每一滴後面跟著四個越來越悶的長回音（井很高）；頭尾交叉淡化。
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


def daylight_ambience(seconds=8.0, seed=29):
    """白晝城：很慢的鐘擺聲＋遠處的水聲（07「鐘走得很慢的滴答＋遠處的水聲」）。頭尾交叉淡化成可循環。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    fade = int(0.6 * RATE)
    total = n + fade
    # 遠處的水：低通噪音，慢慢起伏
    bed = onepole_lp(onepole_lp(hp(noise(total, rng), 60), 700), 900)
    out = []
    for i in range(total):
        t = i / RATE
        swell = 0.55 + 0.25 * math.sin(2 * math.pi * 0.23 * t) + 0.12 * math.sin(2 * math.pi * 0.61 * t + 1.3)
        out.append(bed[i] * swell * 0.9)
    # 鐘擺：每 2 秒一下，一下「喀」一下「答」（第二下低一點），木頭共鳴約 1.1 kHz
    for k in range(int(seconds / 1.0)):
        start = int((0.25 + k * 1.0) * RATE)
        f = 1150.0 if k % 2 == 0 else 930.0
        amp = 0.55 if k % 2 == 0 else 0.4
        for j in range(int(0.09 * RATE)):
            if start + j >= total:
                break
            tt = j / RATE
            click = rng.uniform(-1, 1) * math.exp(-tt * 900) * 0.6
            ring = math.sin(2 * math.pi * f * tt) * math.exp(-tt * 55)
            out[start + j] += amp * (ring + click)
    # 幾滴水（很遠）
    for _ in range(4):
        start = int(rng.uniform(0.3, seconds - 0.2) * RATE)
        f = rng.uniform(1300, 1900)
        for j in range(int(0.06 * RATE)):
            tt = j / RATE
            out[start + j] += 0.12 * math.sin(2 * math.pi * (f + 1800 * tt) * tt) * math.exp(-tt * 60)
    # 頭尾交叉淡化：最後 fade 個樣本疊回開頭
    looped = out[:n]
    for i in range(fade):
        w = i / fade
        looped[i] = out[i] * w + out[n + i] * (1.0 - w)
    return looped


def brace_creak(seconds=0.5, seed=31):
    """金屬支架的吱聲：滑動的摩擦音（基頻上滑再回落）＋顆粒（黏滑）＋兩個金屬泛音。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    out = []
    phase = 0.0
    stick = 0.0
    for i in range(n):
        t = i / RATE
        u = t / seconds
        f = 620 + 280 * math.sin(math.pi * min(u * 1.3, 1.0)) + 25 * math.sin(2 * math.pi * 31 * t)
        phase += 2 * math.pi * f / RATE
        if rng.random() < 0.02:
            stick = rng.uniform(0.4, 1.0)
        stick *= 0.996
        tone = math.sin(phase) + 0.45 * math.sin(phase * 2.01) + 0.2 * math.sin(phase * 3.7)
        env = min(t / 0.03, 1.0) * max(0.0, 1.0 - u) ** 1.5
        out.append(0.5 * tone * env * (0.5 + 0.5 * stick))
    grit = onepole_lp(hp(noise(n, rng), 1200), 5000)
    for i in range(n):
        u = i / n
        out[i] += 0.12 * grit[i] * max(0.0, 1.0 - u)
    return out


def slap(seconds=0.2, seed=37):
    """一巴掌（不重）：極快起音的帶通噪音＋很短的 180 Hz 肉聲，尾巴是一點點房間的回聲。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    burst = onepole_lp(hp(noise(n, rng), 1000), 4200)
    out = []
    for i in range(n):
        t = i / RATE
        env = min(t / 0.0015, 1.0) * math.exp(-t / 0.018)
        body = math.sin(2 * math.pi * 180 * t) * math.exp(-t / 0.025)
        room = 0.18 * math.exp(-t / 0.07)
        out.append(burst[i] * (env + room * 0.5) + 0.35 * body)
    return out


def deep_rumble(seconds=3.0, seed=41):
    """窗外的牆動了一下：低通噪音（很低）＋38／41 Hz 兩個拍頻的低音，慢起慢收。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    rumble = onepole_lp(onepole_lp(noise(n, rng), 90), 70)
    out = []
    for i in range(n):
        t = i / RATE
        env = min(t / 0.4, 1.0) * math.exp(-max(t - 0.4, 0.0) / 0.9)
        tone = 0.5 * math.sin(2 * math.pi * 38 * t) + 0.4 * math.sin(2 * math.pi * 41 * t + 0.7)
        out.append(env * (rumble[i] * 6.0 + tone * 0.55))
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak * 0.85 for v in out]


def cloth_knock(seconds=0.25, seed=43):
    """布包的小石頭敲銅片：悶的低音「咚」＋被布蓋住的一點銅泛音。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    nz = onepole_lp(noise(n, rng), 700)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = 120 + 80 * math.exp(-t * 40)
        phase += 2 * math.pi * f / RATE
        env = min(t / 0.002, 1.0) * math.exp(-t * 22)
        ring = 0.12 * math.sin(2 * math.pi * 1310 * t) * math.exp(-t * 28) + 0.06 * math.sin(2 * math.pi * 2930 * t) * math.exp(-t * 40)
        out.append(0.85 * env * math.sin(phase) + 0.35 * nz[i] * math.exp(-t * 60) + ring)
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak * 0.8 for v in out]


def chain_creak(seconds=0.7, seed=47):
    """鏈子先響：三下鐵環碰撞（短的非諧波泛音）＋一聲低低的摩擦（低通噪音、慢慢起落）。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    rub = onepole_lp(hp(noise(n, rng), 300), 1400)
    out = [0.0] * n
    for i in range(n):
        t = i / RATE
        env = math.sin(math.pi * min(t / seconds, 1.0)) ** 2
        out[i] = 0.5 * rub[i] * env
    for k, (at, f) in enumerate([(0.05, 2100.0), (0.21, 2650.0), (0.33, 1870.0)]):
        start = int(at * RATE)
        for j in range(int(0.12 * RATE)):
            if start + j >= n:
                break
            t = j / RATE
            v = math.sin(2 * math.pi * f * t) + 0.6 * math.sin(2 * math.pi * f * 2.76 * t)
            out[start + j] += 0.28 * v * math.exp(-t * 55)
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak * 0.7 for v in out]


def canal_ambience(seconds=10.0, seed=53):
    """乾運河：空洞的低風＋有回音的滴水＋吊樑一聲嘎吱。頭尾交叉淡化成可循環。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    fade = int(0.8 * RATE)
    total = n + fade
    wind = onepole_lp(onepole_lp(hp(noise(total, rng), 40), 260), 320)
    out = []
    for i in range(total):
        t = i / RATE
        swell = 0.6 + 0.3 * math.sin(2 * math.pi * 0.11 * t) + 0.15 * math.sin(2 * math.pi * 0.37 * t + 2.1)
        out.append(wind[i] * swell * 2.2)
    # 滴水：三個回音（石牆），越後面越小越悶
    for at in (1.3, 4.6, 7.9):
        f = rng.uniform(1100, 1500)
        for echo, (delay, amp) in enumerate([(0.0, 0.2), (0.19, 0.08), (0.41, 0.04)]):
            start = int((at + delay) * RATE)
            for j in range(int(0.07 * RATE)):
                if start + j >= total:
                    break
                tt = j / RATE
                out[start + j] += amp * math.sin(2 * math.pi * (f - echo * 150 + 1500 * tt) * tt) * math.exp(-tt * 55)
    # 吊樑：很輕的一聲木頭嘎吱（低頻摩擦，慢慢滑上去）
    start = int(5.8 * RATE)
    m = int(0.9 * RATE)
    grain = onepole_lp(noise(m, rng), 2500)
    phase = 0.0
    for j in range(m):
        tt = j / RATE
        f = 210 + 120 * (tt / 0.9)
        phase += 2 * math.pi * f / RATE
        env = math.sin(math.pi * tt / 0.9) ** 2
        saw = (phase / math.pi) % 2.0 - 1.0
        out[start + j] += 0.07 * env * (0.6 * saw + 0.4 * grain[j]) * (0.7 + 0.3 * math.sin(2 * math.pi * 17 * tt))
    looped = out[:n]
    for i in range(fade):
        w = i / fade
        looped[i] = out[i] * w + out[n + i] * (1.0 - w)
    peak = max(abs(v) for v in looped) or 1.0
    return [v / peak * 0.6 for v in looped]


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


def frost_wind(seconds=12.0, seed=59, indoor=False):
    """霜橋鎮的風雪：低風底＋滑動的帶通呼嘯＋雪粒沙沙，跟著陣風起伏。indoor＝隔著牆聽。"""
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
        v = bed[i] * (0.5 + 0.7 * g) * 1.6 + howl[i] * (g ** 2) * 0.55
        if not indoor:
            v += hiss[i] * (g ** 3) * 0.05
        out.append(v)
    if indoor:
        out = onepole_lp(onepole_lp(out, 300), 380)
    looped = _loop_crossfade(out, n, fade)
    peak = max(abs(v) for v in looped) or 1.0
    return [v / peak * 0.7 for v in looped]


def hearth_crackle(seconds=7.0, seed=61):
    """壁爐的柴火：低低的火焰呼嚕＋隨機的細小劈啪＋幾聲比較大的爆裂。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    fade = int(0.5 * RATE)
    total = n + fade
    roar_src = onepole_lp(onepole_lp(hp(noise(total, rng), 40), 180), 240)
    flicker = onepole_lp([rng.uniform(0.3, 1.0) for _ in range(total)], 6)
    out = [roar_src[i] * (0.6 + 1.4 * flicker[i]) * 2.4 for i in range(total)]
    # 細小劈啪：每秒約 9 下，強度大多很小、偶爾大一點
    t = rng.uniform(0.0, 0.1)
    while t < seconds + 0.4:
        start = int(t * RATE)
        amp = min(1.0, rng.expovariate(4.0)) * 0.5 + 0.04
        f = rng.uniform(1500, 5000)
        m = int(rng.uniform(0.004, 0.014) * RATE)
        burst = svf_band(noise(m, rng), lambda _i: f, 0.5)
        for j in range(m):
            if start + j >= total:
                break
            out[start + j] += amp * burst[j] * math.exp(-j / RATE * rng.uniform(300, 700))
        t += rng.expovariate(9.0)
    # 幾聲比較大的爆裂：高頻「啪」＋低頻「啵」
    for at in (1.1, 3.7, 5.6):
        start = int(at * RATE)
        for j in range(int(0.08 * RATE)):
            tt = j / RATE
            pop = rng.uniform(-1, 1) * math.exp(-tt * 260) * 0.9 + math.sin(2 * math.pi * (180 - 600 * tt) * tt) * math.exp(-tt * 45) * 0.5
            out[start + j] += pop
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


def aftermath_theme(seconds=32.0, seed=83):
    """切片收束的配樂（D-185）：車隊過去之後回到梨販攤。比標題更低、更空：
    D2＋F2 的長音（小三度，慢慢拍頻）、16 秒一次很淺的漲落，偶爾一聲很遠很悶的鐘（不成旋律）。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    fade = int(3.0 * RATE)
    total = n + fade
    table = _wavetable([(1, 1.0), (2, 0.3), (3, 0.12), (4, 0.04)])
    size = len(table)
    drone = [0.0] * total
    # 高八度的 D3／F3 小聲一點，筆電喇叭才聽得到
    for f, amp in [(73.42, 0.5), (73.55, 0.4), (87.31, 0.26), (87.12, 0.22), (110.0, 0.1), (146.83, 0.16), (174.61, 0.1)]:
        ph = rng.random() * size
        step = f * size / RATE
        for i in range(total):
            drone[i] += amp * table[int(ph) % size]
            ph += step
    for i in range(total):
        t = i / RATE
        drone[i] *= 0.75 + 0.25 * math.sin(2 * math.pi * t / 16.0 - 0.6)  # 16 秒一次，32 秒剛好兩次
    drone = onepole_lp(onepole_lp(drone, 700), 900)
    dpeak = max(abs(v) for v in drone) or 1.0
    out = [v / dpeak * 0.5 for v in drone]
    # 很遠的鐘：只有兩聲，音很低、很悶，回音比聲音本身長
    for at, f, gain in [(6.0, 146.83, 0.7), (21.5, 130.81, 0.55)]:
        b = onepole_lp(onepole_lp(bell(f, 6.0), 900), 1200)
        bpeak = max(abs(v) for v in b) or 1.0
        for delay, tap in [(0.0, 0.22), (0.61, 0.1), (1.43, 0.06), (2.4, 0.035)]:
            start = int((at + delay) * RATE)
            g = gain * tap / bpeak
            for j, v in enumerate(b):
                if start + j >= total:
                    break
                out[start + j] += g * v
    looped = _loop_crossfade(out, n, fade)
    peak = max(abs(v) for v in looped) or 1.0
    return [v / peak * 0.6 for v in looped]


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


def bell_far(seconds=8.0):
    """隔著石頭聽到的鐘（D-192）：地底城轉角的換班鐘聲。跟鐘樓同一口鐘（G3），高頻幾乎被濾掉、
    敲擊的金屬噪音聽不到，三個越來越晚、越來越悶的回音比聲音本身長——聽得出是那口鐘，但很遠、在上面。"""
    n = int(seconds * RATE)
    b = onepole_lp(onepole_lp(onepole_lp(bell(196.0, 5.5), 600), 800), 1100)
    bpeak = max(abs(v) for v in b) or 1.0
    out = [0.0] * n
    for delay, tap in [(0.0, 1.0), (0.47, 0.42), (1.13, 0.22), (1.98, 0.11)]:
        start = int(delay * RATE)
        for j, v in enumerate(b):
            if start + j >= n:
                break
            out[start + j] += tap * v / bpeak
    # 很慢的起音（聲音穿過石頭，沒有敲擊的「叮」）
    attack = int(0.06 * RATE)
    for i in range(attack):
        out[i] *= i / attack
    fade = int(1.5 * RATE)
    for i in range(fade):
        out[n - fade + i] *= 1.0 - i / fade
    return out


def _soft_pluck(f, seconds=4.0):
    """很輕的撥弦（加法合成，音準準確）：泛音越高衰減越快，5 毫秒的起音，聽起來像遠處的小豎琴。"""
    n = int(seconds * RATE)
    partials = [(1, 1.0, 1.1), (2, 0.5, 1.8), (3, 0.26, 2.7), (4, 0.13, 3.6), (5, 0.07, 4.6), (6, 0.035, 6.0)]
    out = [0.0] * n
    for k, amp, decay in partials:
        w = 2 * math.pi * k * f / RATE
        for i in range(n):
            out[i] += amp * math.sin(w * i) * math.exp(-(i / RATE) * decay)
    attack = int(0.005 * RATE)
    for i in range(attack):
        out[i] *= i / attack
    return onepole_lp(out, 3200)


def after_dinner_theme(seconds=24.0, seed=101):
    """第 1 章柯德家晚餐之後、走在白晝城往鐘院的路上（D-190）：B♭2＋F3 的長音（加一點 D3，大三度比較暖），
    上面很輕的撥弦——標題往下走的三聲（D4、C4、A3）在這裡變成 D4、C4、B♭3：同樣往下走，落在暖的那個音。
    第一句停在 C4（還沒說完），第二句往下到 F3 再回到 B♭3。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    fade = int(2.5 * RATE)
    total = n + fade
    table = _wavetable([(1, 1.0), (2, 0.3), (3, 0.1), (4, 0.03)])
    size = len(table)
    drone = [0.0] * total
    for f, amp in [(116.54, 0.5), (116.71, 0.42), (174.61, 0.3), (174.4, 0.25), (146.83, 0.1)]:
        ph = rng.random() * size
        step = f * size / RATE
        for i in range(total):
            drone[i] += amp * table[int(ph) % size]
            ph += step
    for i in range(total):
        t = i / RATE
        drone[i] *= 0.72 + 0.28 * math.sin(2 * math.pi * t / 12.0 - 0.9)  # 12 秒一次，24 秒剛好兩次
    drone = onepole_lp(onepole_lp(drone, 800), 1000)
    dpeak = max(abs(v) for v in drone) or 1.0
    out = [v / dpeak * 0.36 for v in drone]
    plucks = {}
    motif = [(2.0, 293.66, 0.8), (3.0, 261.63, 0.72), (4.0, 233.08, 0.78), (5.6, 261.63, 0.66),
             (13.0, 293.66, 0.74), (14.0, 261.63, 0.68), (15.0, 233.08, 0.74), (16.6, 174.61, 0.7), (18.2, 233.08, 0.85)]
    for at, f, gain in motif:
        if f not in plucks:
            p = _soft_pluck(f)
            ppeak = max(abs(v) for v in p) or 1.0
            plucks[f] = [v / ppeak for v in p]
        p = plucks[f]
        # 原聲＋兩個很淡的回音（石板街、兩側的白牆）
        for delay, tap in [(0.0, 0.3), (0.31, 0.08), (0.74, 0.035)]:
            start = int((at + delay) * RATE)
            g = gain * tap
            for j, v in enumerate(p):
                if start + j >= total:
                    break
                out[start + j] += g * v
    looped = _loop_crossfade(out, n, fade)
    peak = max(abs(v) for v in looped) or 1.0
    return [v / peak * 0.66 for v in looped]


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


def stair_ambience(seconds=9.0, seed=83):
    """一百七十二階：深石井裡空空的低風＋上面某處的滴水（長回音）。"""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    fade = int(0.8 * RATE)
    total = n + fade
    wind = onepole_lp(onepole_lp(hp(noise(total, rng), 30), 180), 220)
    out = []
    for i in range(total):
        t = i / RATE
        swell = 0.6 + 0.25 * math.sin(2 * math.pi * t / 9.0) + 0.12 * math.sin(2 * math.pi * 0.41 * t + 0.8)
        out.append(wind[i] * swell * 2.4)
    for at in (0.9, 3.4, 5.1, 7.6):
        f = rng.uniform(1200, 1700)
        for echo, (delay, amp) in enumerate([(0.0, 0.16), (0.27, 0.08), (0.58, 0.05), (0.93, 0.03), (1.34, 0.015)]):
            start = int((at + delay) * RATE)
            for j in range(int(0.08 * RATE)):
                if start + j >= total:
                    break
                tt = j / RATE
                out[start + j] += amp * math.sin(2 * math.pi * (f - echo * 120 + 1400 * tt) * tt) * math.exp(-tt * (55 - echo * 6))
    looped = _loop_crossfade(out, n, fade)
    peak = max(abs(v) for v in looped) or 1.0
    return [v / peak * 0.6 for v in looped]


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
        write("daylight_ambience", daylight_ambience()),
        write("brace_creak", brace_creak()),
        write("slap", slap()),
        write("deep_rumble", deep_rumble()),
        write("cloth_knock", cloth_knock()),
        write("chain_creak", chain_creak()),
        write("canal_ambience", canal_ambience()),
        write("frost_wind", frost_wind()),
        write("frost_wind_indoor", frost_wind(indoor=True)),
        write("hearth_crackle", hearth_crackle()),
        write("title_theme", title_theme()),
        write("aftermath_theme", aftermath_theme()),
        write("part_end_theme", part_end_theme()),
        write("after_dinner_theme", after_dinner_theme()),
        write("bell_far", bell_far()),
        write("step_snow", step_snow()),
        write("step_stone", step_stone()),
        write("step_wood", step_wood()),
        write("step_heavy", step_heavy()),
        write("stair_ambience", stair_ambience()),
        write("poison_charge", poison_hiss(1.1, seed=107, charge=True)),
        write("poison_hiss", poison_hiss(0.9, seed=109)),
        write("glass_clink", glass_clink()),
    ]
    for p in made:
        print(f"{p.name}: {p.stat().st_size // 1024} KB")


if __name__ == "__main__":
    sys.exit(main())
