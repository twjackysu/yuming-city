class_name FrameThrowEvent
extends RefCounted
## 鐵架拋擲（送葬者第二階段，劇情觸發一次；docs/design/02-gameplay.md）：
## 送葬者舉起鐵架 windup 秒後擲向車隊。落下那一刻九息石拱是實體 → 石拱擋下（outcome "arch"）；
## 否則席菈提前燒薪火劍斬斷（outcome "kindling"，`sheila.kindling_used_early`，她的手傷之後更重）。
## 兩條路都能走完，代價由不同的人付。純邏輯：場景每幀餵「石拱現在是不是實體」。

signal resolved(outcome: String)

const WINDUP_SEC: float = 4.0

var time_left: float = WINDUP_SEC
var outcome: String = ""


func is_resolved() -> bool:
	return outcome != ""


func tick(delta: float, arch_solid: bool, state: GameState) -> void:
	if is_resolved():
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0:
		resolve("arch" if arch_solid else "kindling", state)


func resolve(how: String, state: GameState) -> void:
	if is_resolved():
		return
	outcome = how
	if state != null:
		state.set_flag("slice.frame_throw_outcome", how)
		if how == "kindling":
			state.set_flag("sheila.kindling_used_early", true)
	resolved.emit(how)
