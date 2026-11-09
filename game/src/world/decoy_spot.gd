class_name DecoySpot
extends Node3D
## 第 3 章段落 3：東岸上放假心臟的點（D-165）。目標指引的 `nearest:DecoySpot` 只指向現在能動手的點
## （假心臟在手上 → 送葬者還沒走到過的點；垂下去了 → 垂著的那一點）。判斷交給關卡的 `spot_actionable(index)`。

var index: int = 0
var level: Node


func is_available() -> bool:
	return level != null and bool(level.call("spot_actionable", index))
