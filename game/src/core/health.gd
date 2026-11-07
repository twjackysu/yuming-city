class_name Health
extends Node
## 生命值元件：掛在角色或木樁底下。受傷回傳是否真的扣到（無敵、已死亡時不扣）。
## invulnerable_check 由擁有者提供（例如玩家閃避的無敵時間），避免元件反過來讀角色。

signal damaged(amount: float, info: Dictionary)
signal died
signal revived

@export var max_hp: float = 100.0
var hp: float = 100.0
var invulnerable_check: Callable = Callable()


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
	hp = maxf(hp - amount, 0.0)
	damaged.emit(amount, info)
	if is_dead():
		died.emit()
	return true


func reset() -> void:
	var was_dead: bool = is_dead()
	hp = max_hp
	if was_dead:
		revived.emit()
