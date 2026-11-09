class_name SteamBridge
extends RefCounted
## Steam 後端轉接（D-147）：有 GodotSteam（GDExtension 註冊的 "Steam" singleton）時把成就同步上去，
## 沒有時什麼都不做。現在 repo 裡沒有 GodotSteam，等 Jacky 拿到 App ID 再放（docs/steam/）；
## steam_appid.txt 不進 git。成就的 API 名稱＝data/achievements.json 的 id。

const SINGLETON: String = "Steam"


static func available() -> bool:
	return Engine.has_singleton(SINGLETON)


static func _steam() -> Object:
	return Engine.get_singleton(SINGLETON) if available() else null


## 有 Steam 時由 Steam 自己的通知取代遊戲內的解鎖小卡。
static func shows_own_toast() -> bool:
	return available()


## 解鎖一個成就並上傳。沒有 Steam 時回傳 false。
static func set_achievement(achievement_id: String) -> bool:
	var steam: Object = _steam()
	if steam == null:
		return false
	steam.call("setAchievement", achievement_id)
	steam.call("storeStats")
	return true


## 啟動時把本機已解鎖的補上去（離線時解鎖、或 Steam 版之前就解鎖的）。回傳補了幾個。
static func sync(unlocked: PackedStringArray) -> int:
	var steam: Object = _steam()
	if steam == null:
		return 0
	for id: String in unlocked:
		steam.call("setAchievement", id)
	if not unlocked.is_empty():
		steam.call("storeStats")
	return unlocked.size()
