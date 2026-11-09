class_name MarkerPoint
extends Node3D
## 只給目標指引用的點（D-166）：`nearest:<前綴>` 會跳過 `is_available()` 回傳 false 的節點，
## 所以同一個任務階段可以依情況指向不同地方（例如第 3 章段落 4：假心臟在手上 → 指向放心臟的點；垂下去了 → 指向繩子）。
## 判斷交給關卡的 `marker_available(query)`。

var query: String = ""
var level: Node


func is_available() -> bool:
	return level != null and bool(level.call("marker_available", query))
