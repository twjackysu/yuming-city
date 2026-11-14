class_name BarTrail
extends RefCounted
## 生命條的「變化段」：回血時剛長出來的那一段先畫成綠色（往上的段），
## 直接傷害時剛扣掉的那一段先留成紅色（往下的段），過一下才併回原本的顏色。
## 純邏輯：每幀 step(目前比例, delta)，畫的時候讀 base_ratio()／heal_span()／loss_span()。

## 綠色段追上來的時間常數：持續回血時，段的寬度 ≈ 每秒回血的比例 × 這個秒數
const HEAL_LAG_SEC: float = 2.5
## 還在回血時至少這麼寬（260 px 的條上約 6 px）：回血很慢時也看得到
const HEAL_MIN_SPAN: float = 0.024
## 最後一次回血之後多久還算「正在回血」
const HEAL_HOLD_SEC: float = 0.45
## 紅色段先停一下再縮
const LOSS_HOLD_SEC: float = 0.35
const LOSS_DRAIN_PER_SEC: float = 0.6
const EPS: float = 0.00005

## 目前的比例（0～1）
var ratio: float = 1.0
var _heal_trail: float = 1.0
var _loss_trail: float = 1.0
var _loss_hold: float = 0.0
var _since_gain: float = 99.0
var _started: bool = false


func step(now: float, delta: float) -> void:
	now = clampf(now, 0.0, 1.0)
	if not _started:
		# 第一幀（或讀檔後）：直接對齊，不演「從 0 回滿」
		reset(now)
		return
	_since_gain += delta
	if now > ratio + EPS:
		_since_gain = 0.0
	elif now < ratio - EPS:
		_loss_hold = LOSS_HOLD_SEC
	ratio = now
	# 綠色段：落後的那條線慢慢追上來；被打就切到目前的位置
	if _heal_trail > now:
		_heal_trail = now
	else:
		_heal_trail += (now - _heal_trail) * (1.0 - exp(-delta / HEAL_LAG_SEC))
		if now - _heal_trail < 0.0005:
			_heal_trail = now
	# 紅色段：先停一下再縮回來；回血超過它就消失
	if _loss_trail < now:
		_loss_trail = now
	elif _loss_hold > 0.0:
		_loss_hold = maxf(_loss_hold - delta, 0.0)
	else:
		_loss_trail = move_toward(_loss_trail, now, LOSS_DRAIN_PER_SEC * delta)


## 直接對齊（換場景、讀檔、重來）：沒有任何變化段
func reset(now: float) -> void:
	ratio = clampf(now, 0.0, 1.0)
	_heal_trail = ratio
	_loss_trail = ratio
	_loss_hold = 0.0
	_since_gain = 99.0
	_started = true


func is_healing() -> bool:
	return _since_gain < HEAL_HOLD_SEC


## 綠色段的寬度（比例）：畫在 [ratio - heal_span, ratio]
func heal_span() -> float:
	var span: float = ratio - _heal_trail
	if is_healing():
		span = maxf(span, HEAL_MIN_SPAN)
	return clampf(span, 0.0, ratio)


## 原本顏色的那一段：[0, base_ratio]
func base_ratio() -> float:
	return ratio - heal_span()


## 紅色段的寬度（比例）：畫在 [ratio, ratio + loss_span]
func loss_span() -> float:
	return clampf(_loss_trail - ratio, 0.0, 1.0 - ratio)
