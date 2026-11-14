class_name SeraBrain
extends RefCounted
## 席菈在場上要做什麼（純邏輯；數值在 data/combat/tuning.json 的 sera）。
## 跟：離諾恩超過 follow_far 就跟上，走到 follow_near 以內才停（兩個數字之間不改主意，才不會一步一停）。
## 射：諾恩附近有敵人時倒數，時間到先舉弩瞄準 aim_time 秒再擊發；沒有敵人就把倒數退回「第一瓶」。

enum State { READY, AIM }

var state: State = State.READY
## 正在往諾恩走
var following: bool = false
## 離開始瞄準還有幾秒（只在附近有敵人時倒數）
var shot_left: float = 0.0
## 舉著弩還要瞄幾秒
var aim_left: float = 0.0
var _requested: bool = false


func _init() -> void:
	shot_left = CombatTuning.num("sera.first_vial_delay", 1.5)


## 這一幀要往諾恩走多快（m/s；0＝站著）。dist＝跟諾恩的水平距離。瞄準中不走。
func follow_speed(dist: float) -> float:
	var far: float = CombatTuning.num("sera.follow_far", 6.0)
	if dist > far:
		following = true
	elif dist <= CombatTuning.num("sera.follow_near", 4.5):
		following = false
	if not following or state == State.AIM:
		return 0.0
	if dist > far + CombatTuning.num("sera.run_extra", 3.0):
		return CombatTuning.num("sera.run_speed", 5.6)
	return CombatTuning.num("sera.walk_speed", 3.2)


## 每幀呼叫一次。threat＝諾恩附近有活著的敵人。回傳 true＝這一幀擊發。
func tick(delta: float, threat: bool) -> bool:
	if state == State.AIM:
		aim_left -= delta
		if aim_left > 0.0:
			return false
		state = State.READY
		shot_left = CombatTuning.num("sera.vial_interval", 9.0)
		return true
	if _requested:
		shot_left = 0.0
	elif not threat:
		shot_left = CombatTuning.num("sera.first_vial_delay", 1.5)
		return false
	shot_left -= delta
	if shot_left <= 0.0:
		_requested = false
		state = State.AIM
		aim_left = CombatTuning.num("sera.aim_time", 0.6)
	return false


## 現在就要一瓶：不管附近有沒有敵人，下一幀就開始瞄準（之後玩家按鍵向她要藥也走這裡；現在只有連拍工具在用）。
func request() -> void:
	_requested = true


func is_aiming() -> bool:
	return state == State.AIM
