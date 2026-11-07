class_name NineBreath
extends RefCounted
## 九息：一個「可保存物件」的狀態機（純邏輯，場景節點只負責顯示與碰撞切換）。
##
## BROKEN（損壞）→ activate() 付出記憶 → RESTORED（重現，倒數九息）→ SPENT（化灰，最終狀態）
## 工程邊界見 docs/technical-direction.md：
## - 代價只付一次；讀檔後不會重複扣。
## - 存檔不會停在九息中間：讀檔時 RESTORED 一律視為 SPENT。

signal breath(index: int)  ## 每過一息發出一次，index = 1..9
signal finished

const BREATHS: int = 9
const BREATH_SEC: float = 1.0

enum Phase { BROKEN, RESTORED, SPENT }

var object_id: String
var memory_id: String
var phase: Phase = Phase.BROKEN
var elapsed: float = 0.0


func _init(p_object_id: String, p_memory_id: String) -> void:
	object_id = p_object_id
	memory_id = p_memory_id


func flag_key() -> String:
	return "ninebreath.%s" % object_id


func can_activate() -> bool:
	return phase == Phase.BROKEN


## 確認使用後呼叫。回傳 false 代表目前不能使用。
func activate(state: GameState) -> bool:
	if not can_activate():
		return false
	state.pay_memory(memory_id)  # 已付過（例如讀檔重來）就不會再扣
	phase = Phase.RESTORED
	elapsed = 0.0
	state.set_flag(flag_key(), "restored")
	return true


func remaining() -> float:
	if phase != Phase.RESTORED:
		return 0.0
	return maxf(float(BREATHS) * BREATH_SEC - elapsed, 0.0)


## 推進時間；倒數結束時把最終狀態寫回 state。
func tick(delta: float, state: GameState) -> void:
	if phase != Phase.RESTORED:
		return
	var before: int = int(floor(elapsed / BREATH_SEC))
	elapsed += delta
	var after: int = mini(int(floor(elapsed / BREATH_SEC)), BREATHS)
	for i: int in range(before + 1, after + 1):
		breath.emit(i)
	if elapsed >= float(BREATHS) * BREATH_SEC:
		_spend(state)


func _spend(state: GameState) -> void:
	phase = Phase.SPENT
	elapsed = float(BREATHS) * BREATH_SEC
	state.set_flag(flag_key(), "spent")
	finished.emit()


## 從存檔還原。九息中間存的檔一律視為已化灰（代價已付）。
func load_from(state: GameState) -> void:
	var v: String = str(state.get_flag(flag_key(), "broken"))
	if v == "restored" or v == "spent":
		phase = Phase.SPENT
		elapsed = float(BREATHS) * BREATH_SEC
		state.set_flag(flag_key(), "spent")
	else:
		phase = Phase.BROKEN
		elapsed = 0.0
