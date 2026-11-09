class_name HangRope
extends RefCounted
## 第 3 章段落 5「倒吊」（08-chapter2-3.md、D-167）：席菈腰上綁著繩子、倒吊下去切開送葬者的胸口，諾恩在岸上抓著繩子。
## 玩家：按住互動鍵＝拉住（放開她就往下滑、進度慢慢退）；左右（A／D、左搖桿）＝把她往那一邊推，修正擺盪。
## 擺盪是有阻尼的單擺＋固定的外力（壓在煤堆下的牠在掙扎）；離正中 CUT_WINDOW 以內她才切得到 → 進度往上。
## 擺過 LIMIT → 她撞到鐵架：進度扣 BUMP_LOSS、反彈一半。不會失敗重來（簡單但吃技巧）。
## 純邏輯：每一幀給 hold／steer，關卡只負責演；外力是固定的函式，測試可以重現。

## 擺盪 -1～1（±1＝撞到鐵架）
const LIMIT: float = 1.0
## 離正中多近才切得到
const CUT_WINDOW: float = 0.35
## 一直穩住要切多久（秒）
const CUT_SEC: float = 5.0
## 放開的時候每秒退多少進度
const SLIP_RATE: float = 0.2
## 撞到鐵架扣多少進度
const BUMP_LOSS: float = 0.12
## 回到正中的力（單擺：自然週期約 3.5 秒）
const STIFFNESS: float = 3.2
const DAMPING: float = 0.6
## 左右輸入的力（比外力最大值大，穩得住）
const STEER: float = 4.5
## 外力的大小（牠在煤堆下掙扎）
const DRIFT: float = 2.4

var sway: float = 0.0
var sway_vel: float = 0.0
var progress: float = 0.0
var bumps: int = 0
var holding: bool = false
var done: bool = false
var t: float = 0.0


## 第 t 秒的外力：兩個不同週期的晃動疊在一起，玩家抓得到節奏但不會完全一樣。
static func drift_at(time: float) -> float:
	return DRIFT * (0.65 * sin(time * 1.3) + 0.35 * sin(time * 2.7 + 1.1))


## 往前一幀。hold：有沒有按住拉住；steer：-1～1（左右）。回傳這一幀有沒有撞到鐵架。
func step(delta: float, hold: bool, steer: float) -> bool:
	if done:
		return false
	t += delta
	holding = hold
	var force: float = -STIFFNESS * sway - DAMPING * sway_vel + drift_at(t) + STEER * clampf(steer, -1.0, 1.0)
	sway_vel += force * delta
	sway += sway_vel * delta
	var bumped: bool = false
	if absf(sway) > LIMIT:
		sway = signf(sway) * LIMIT
		sway_vel = -sway_vel * 0.5
		bumps += 1
		progress = maxf(progress - BUMP_LOSS, 0.0)
		bumped = true
	if hold and absf(sway) <= CUT_WINDOW:
		progress = minf(progress + delta / CUT_SEC, 1.0)
	elif not hold:
		progress = maxf(progress - SLIP_RATE * delta, 0.0)
	if progress >= 1.0:
		done = true
	return bumped


## 照著擺盪往反方向推（自動測試、截圖用；也是玩家自己會做的事：看她往右晃就往左拉）。只給 -1／0／1，跟鍵盤一樣。
static func counter_steer(r: HangRope) -> float:
	var want: float = -(1.6 * r.sway + 0.9 * r.sway_vel)
	if absf(want) < 0.15:
		return 0.0
	return signf(want)


## 她現在切得到嗎（按住、而且在正中附近）。
func cutting() -> bool:
	return holding and not done and absf(sway) <= CUT_WINDOW
