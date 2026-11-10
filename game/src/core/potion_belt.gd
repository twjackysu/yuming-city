class_name PotionBelt
extends RefCounted
## 可攜藥劑（新版，D-202）：數量存在 GameState.items；喝下去就是對自己 StatusEffects.apply。
## 滿血時不直接喝：回傳 "confirm_full"，UI 問「現在滿血，看不出效果。還是要喝嗎？」（喝／先收著），
## 玩家選喝才帶 confirmed=true 再呼叫一次——不強迫自殘、也不浪費。
## 藥劑是虛構道具，只標效果（status_rules 的 desc_key），不寫任何配方。

var state: GameState
var rules: StatusRules


func _init(p_state: GameState, p_rules: StatusRules = null) -> void:
	state = p_state
	rules = p_rules if p_rules != null else StatusRules.load_default()


func count(item_id: String) -> int:
	return int(state.items.get(item_id, 0))


## 一次性發放（藥箱、欠薪）：同一個 grant_id 只給一次，讀檔重試也不會重複領。回傳這次有沒有給。
func grant_once(grant_id: String, item_id: String, amount: int = 1) -> bool:
	if not state.grant_once(grant_id):
		return false
	state.items[item_id] = count(item_id) + amount
	return true


## 回傳 "used"／"none_left"／"confirm_full"／"unknown"
func use(item_id: String, effects: StatusEffects, health: Health, confirmed: bool = false) -> String:
	var def: Dictionary = rules.item(item_id)
	if def.is_empty():
		return "unknown"
	if count(item_id) <= 0:
		return "none_left"
	if health != null and health.is_full() and not confirmed:
		return "confirm_full"
	state.items[item_id] = count(item_id) - 1
	effects.apply(str(def["status"]), float(def["rate"]), float(def["duration"]), item_id)
	return "used"
