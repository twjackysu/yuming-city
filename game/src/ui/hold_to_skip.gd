class_name HoldToSkip
extends RefCounted
## 「按住跳過」的計時（對話框與過場共用）。每幀呼叫 update(按著與否, delta)，滿了回傳 true 一次。

var duration: float = 0.6
var held: float = 0.0


func _init(seconds: float = 0.6) -> void:
	duration = maxf(seconds, 0.01)


func update(pressed: bool, delta: float) -> bool:
	if not pressed:
		held = 0.0
		return false
	held += delta
	if held >= duration:
		held = 0.0
		return true
	return false


func progress() -> float:
	return clampf(held / duration, 0.0, 1.0)


func reset() -> void:
	held = 0.0
