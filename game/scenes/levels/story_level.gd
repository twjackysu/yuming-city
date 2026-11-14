class_name StoryLevel
extends Node3D
## 關卡的共用基底：地面高度、腳步聲材質。Game 只在 StoryLevel 裡累計遊戲時間。


## 地面高度（平地關卡是 0；有高低差的關卡覆寫）。
func ground_y(_p: Vector3) -> float:
	return 0.0


## 腳下是什麼（腳步聲）：Footsteps.SURFACES 裡的一個。預設石頭。
func footstep_surface(_p: Vector3) -> String:
	return "stone"
