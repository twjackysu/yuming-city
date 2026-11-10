class_name MistZone
extends RefCounted
## 毒霧範圍（新版，D-202）：直立圓柱（中心在地面、半徑、高度）。站在裡面時每 REFRESH 秒用來源刷新一次狀態
## （破藥桶的霧：中毒 4 秒＝離開後 4 秒才結束；守衛噴的：3 秒）。life > 0 的霧（守衛噴的）時間到就散掉。
## 純邏輯；場景的 PoisonMist 節點負責畫霧、把角色位置餵進來。NPC 沒有反轉欄位，進來照樣掉血（不會跟著免疫）。

const REFRESH: float = 0.25

var center: Vector3
var radius: float
var height: float = 2.5
var source_id: String
## <0＝不會散；>0＝剩幾秒
var life: float = -1.0
## 角色 key（instance id）→ 距離下一次刷新還有幾秒
var _timers: Dictionary = {}


func _init(p_center: Vector3, p_radius: float, p_source: String, p_life: float = -1.0) -> void:
	center = p_center
	radius = p_radius
	source_id = p_source
	life = p_life


func contains(pos: Vector3) -> bool:
	if expired():
		return false
	var flat: Vector2 = Vector2(pos.x - center.x, pos.z - center.z)
	return flat.length() <= radius and pos.y >= center.y - 0.5 and pos.y <= center.y + height


func expired() -> bool:
	return life == 0.0


## 霧本身的時間（暫停時不呼叫）
func tick(delta: float) -> void:
	if life > 0.0:
		life = maxf(life - delta, 0.0)


## 某個角色這一幀在 pos：在霧裡就（照間隔）上狀態。回傳在不在霧裡。
func expose(key: int, pos: Vector3, effects: StatusEffects, delta: float) -> bool:
	if not contains(pos):
		_timers.erase(key)
		return false
	var t: float = float(_timers.get(key, 0.0)) - delta
	if t <= 0.0:
		effects.apply_source(source_id)
		t = maxf(t + REFRESH, 0.0) if t > -REFRESH else REFRESH
	_timers[key] = t
	return true
