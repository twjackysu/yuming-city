class_name ReversalSlots
extends RefCounted
## 反轉欄位（新版「逆轉體質」，D-202）：只有裝進欄位的負面狀態會反轉。
## 開場兩格；第一次中毒自動覺醒並裝進第一格（只發生一次，存檔記得）。其他狀態要研究、安全測試才解鎖。
## 反轉沒有代價：不扣記憶、不影響選項。

signal awakened(status_id: String)

## 開場覺醒的特例：只有這一種、只有第一次
const FIRST_AWAKEN: String = "poison"
const START_SLOTS: int = 2

var slots: int = START_SLOTS
var unlocked: PackedStringArray = []
## 長度永遠等於 slots；空格是 ""
var equipped: PackedStringArray = []
var awakened_once: bool = false


func _init() -> void:
	_fit_slots()


func is_reversed(status_id: String) -> bool:
	return status_id != "" and equipped.has(status_id)


## 狀態剛上身時呼叫：第一次中毒會自動解鎖＋裝進第一個空格。回傳這一次有沒有覺醒。
func on_status_applied(status_id: String) -> bool:
	if awakened_once or status_id != FIRST_AWAKEN:
		return false
	awakened_once = true
	unlock(status_id)
	equip(status_id)
	awakened.emit(status_id)
	return true


func unlock(status_id: String) -> void:
	if not unlocked.has(status_id):
		unlocked.append(status_id)


## 裝進第一個空格（或指定格）。沒解鎖、已經裝了、沒空格都回傳 false。戰鬥外才給玩家換（呼叫端負責）。
func equip(status_id: String, slot: int = -1) -> bool:
	if not unlocked.has(status_id) or equipped.has(status_id):
		return false
	if slot < 0:
		slot = equipped.find("")
	if slot < 0 or slot >= slots:
		return false
	equipped[slot] = status_id
	return true


func unequip(slot: int) -> void:
	if slot >= 0 and slot < slots:
		equipped[slot] = ""


func free_slots() -> int:
	return equipped.count("")


func to_dict() -> Dictionary:
	return {
		"slots": slots,
		"unlocked": Array(unlocked),
		"equipped": Array(equipped),
		"awakened_once": awakened_once,
	}


static func from_dict(d: Dictionary) -> ReversalSlots:
	var r := ReversalSlots.new()
	r.slots = maxi(int(d.get("slots", START_SLOTS)), 1)
	r.awakened_once = bool(d.get("awakened_once", false))
	r.unlocked = PackedStringArray()
	for v: Variant in (d.get("unlocked", []) as Array):
		r.unlock(str(v))
	r.equipped = PackedStringArray()
	for v: Variant in (d.get("equipped", []) as Array):
		var id: String = str(v)
		# 沒解鎖的、重複的不能裝（壞檔或手改存檔）
		r.equipped.append(id if (id == "" or (r.unlocked.has(id) and not r.equipped.has(id))) else "")
	r._fit_slots()
	return r


func _fit_slots() -> void:
	while equipped.size() < slots:
		equipped.append("")
	if equipped.size() > slots:
		equipped.resize(slots)
