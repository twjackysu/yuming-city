class_name ReversalCue
extends RefCounted
## 吃到異常狀態那一下的回饋時間軸（docs/design/02-gameplay.md「反轉的回饋」）。純邏輯：畫面、圖示、聲音都照這裡的數字。
## 畫面邊緣紫紅亮起來 → CURSE_SEC 秒 → 碎裂（shattered 只發一次）→ 金光慢慢退。
## 只有諾恩有（落在他身上的狀態全部反轉）；每種狀態都走這一條：新上身就 start()，每幀 step(delta)。

signal shattered

## 從吃到狀態到碎裂
const CURSE_SEC: float = 0.3
## 紫紅多快亮到最滿
const CURSE_RISE_SEC: float = 0.12
## 碎片多久掉完
const SHATTER_SEC: float = 0.4
## 金光從碎裂那一刻起多久退完
const GOLD_SEC: float = 1.3
## 狀態列的圖示翻面要多久（碎裂那一刻開始翻）
const FLIP_SEC: float = 0.24

## 開始之後過了幾秒；負的＝沒在播
var t: float = -1.0


func start() -> void:
	t = 0.0


func step(delta: float) -> void:
	if t < 0.0 or delta <= 0.0:
		return
	var before: float = t
	t += delta
	if before < CURSE_SEC and t >= CURSE_SEC:
		shattered.emit()
	if t >= total_sec():
		t = -1.0


func is_playing() -> bool:
	return t >= 0.0


func total_sec() -> float:
	return CURSE_SEC + GOLD_SEC


## 紫紅的強度 0～1
func curse() -> float:
	if t < 0.0:
		return 0.0
	if t < CURSE_SEC:
		return clampf(t / CURSE_RISE_SEC, 0.0, 1.0)
	return 1.0 if t < CURSE_SEC + SHATTER_SEC else 0.0


## 碎裂的進度：0＝還沒碎，1＝碎片掉完
func shatter() -> float:
	if t < CURSE_SEC:
		return 0.0
	return clampf((t - CURSE_SEC) / SHATTER_SEC, 0.0, 1.0)


## 金光的強度 0～1：碎裂那一刻最亮，之後先快後慢地退
func gold() -> float:
	if t < CURSE_SEC:
		return 0.0
	var k: float = clampf((t - CURSE_SEC) / GOLD_SEC, 0.0, 1.0)
	return (1.0 - k) * (1.0 - k)


## 狀態列圖示的那一面：age＝狀態上身之後幾秒。正的＝還是紅的那一面、負的＝已經翻成金的；絕對值＝圖示的寬度比例（翻到一半是 0）。
static func icon_face(age: float) -> float:
	if age < CURSE_SEC:
		return 1.0
	if age >= CURSE_SEC + FLIP_SEC:
		return -1.0
	return cos(PI * (age - CURSE_SEC) / FLIP_SEC)
