class_name Health
extends Node
## 生命值元件：掛在角色或木樁底下。受傷回傳是否真的扣到（無敵、已死亡時不扣）。
## invulnerable_check 由擁有者提供（例如玩家閃避的無敵時間），避免元件反過來讀角色。
## 生命的三種變化分開（D-202，新版反轉）：直接傷害 apply_damage、狀態傷害 apply_status_damage、治療 heal。
## 不用負數傷害代表治療。

signal damaged(amount: float, info: Dictionary)
## 狀態造成的持續傷害（中毒等）：不觸發受擊演出，所以跟 damaged 分開
signal status_damaged(amount: float, info: Dictionary)
## 治療（含中毒被反轉成的回血）：amount 是實際補到的量
signal healed(amount: float, info: Dictionary)
signal died
signal revived

@export var max_hp: float = 100.0
var hp: float = 100.0
var invulnerable_check: Callable = Callable()
## 受傷之前先問擁有者這一下打幾折（回傳 0～1；沒設＝照扣）。例：硬撐中的敵人只扣四分之一（D-242）。
## 擁有者可以在 info 裡留記號（例如 info["braced"] = true），收 damaged 的人看得到。
var damage_scale: Callable = Callable()


func _init(maximum: float = 100.0) -> void:
	max_hp = maximum
	hp = maximum


func is_dead() -> bool:
	return hp <= 0.0


func ratio() -> float:
	return clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0


## info 例：{"source": 攻擊者, "stagger": 20, "kind": "blunt"}
func apply_damage(amount: float, info: Dictionary = {}) -> bool:
	if is_dead() or amount <= 0.0:
		return false
	if invulnerable_check.is_valid() and bool(invulnerable_check.call()):
		return false
	if damage_scale.is_valid():
		amount *= clampf(float(damage_scale.call(info)), 0.0, 1.0)
		if amount <= 0.0:
			return false
	hp = maxf(hp - amount, 0.0)
	damaged.emit(amount, info)
	if is_dead():
		died.emit()
	return true


## 狀態傷害（中毒每幀扣的量）：不被閃避無敵擋、不發 damaged。回傳實際扣到的量。
func apply_status_damage(amount: float, info: Dictionary = {}) -> float:
	if is_dead() or amount <= 0.0:
		return 0.0
	var dealt: float = minf(amount, hp)
	hp -= dealt
	status_damaged.emit(dealt, info)
	if is_dead():
		died.emit()
	return dealt


## 治療：死了不能補、不超過上限。回傳實際補到的量（滿血時是 0，不發訊號）。
func heal(amount: float, info: Dictionary = {}) -> float:
	if is_dead() or amount <= 0.0:
		return 0.0
	var gained: float = minf(amount, max_hp - hp)
	if gained <= 0.0:
		return 0.0
	hp += gained
	healed.emit(gained, info)
	return gained


func is_full() -> bool:
	return hp >= max_hp


func reset() -> void:
	var was_dead: bool = is_dead()
	hp = max_hp
	if was_dead:
		revived.emit()
