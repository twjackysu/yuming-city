class_name StoryLevel
extends Node3D
## 關卡的共用基底：地面高度、腳步聲材質。霜橋鎮（scenes/levels/frostbridge.gd）繼承這個。
## （舊劇情的敲鐘、北街陷落、車隊戰第 77 輪拿掉了，D-220。）

var _rng := RandomNumberGenerator.new()
## 北街的房子（每棟一個 Node3D，meta "height"）
var _north_houses: Array[Node3D] = []
var _bell: Node3D
var _bell_light: OmniLight3D
## 南街的斷拱（單純的場景物件，霜橋鎮的 `_build_south_arch()`）
var south_arch: Node3D


## 地面高度（平地關卡是 0；霜橋鎮覆寫：北街台地與石階）。
func ground_y(_p: Vector3) -> float:
	return 0.0


## 腳下是什麼（腳步聲，D-182）：snow、stone、wood。預設石頭；霜橋鎮是雪、酒館是木板。
func footstep_surface(_p: Vector3) -> String:
	return "stone"
