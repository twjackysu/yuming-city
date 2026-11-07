class_name CaravanRunner
extends RefCounted
## 傷者車隊（送葬者戰的目標，docs/design/02-gameplay.md）：沿路線點等速推進，
## 被打中停下 stop_sec 秒並多一名傷者（停下期間再被打不重複計），走完全程＝抵達。
## 純邏輯，不碰場景；Caravan 節點每幀把 position() 套到推車上。數值：caravan.*（tuning.json）。

signal hit_taken(injured: int)
signal arrived

var points: PackedVector3Array = []
var speed: float = 1.1
var stop_sec: float = 2.0
var traveled: float = 0.0
var injured: int = 0
var stop_left: float = 0.0
var is_arrived: bool = false
var _length: float = 0.0


func _init(route: PackedVector3Array = PackedVector3Array()) -> void:
	speed = CombatTuning.num("caravan.speed", speed)
	stop_sec = CombatTuning.num("caravan.stop_sec", stop_sec)
	set_route(route)


func set_route(route: PackedVector3Array) -> void:
	points = route
	_length = 0.0
	for i: int in range(1, points.size()):
		_length += points[i - 1].distance_to(points[i])


func length() -> float:
	return _length


## 0..1
func progress() -> float:
	return clampf(traveled / _length, 0.0, 1.0) if _length > 0.0 else 1.0


func is_stopped() -> bool:
	return stop_left > 0.0


func tick(delta: float) -> void:
	if is_arrived:
		return
	if stop_left > 0.0:
		stop_left = maxf(stop_left - delta, 0.0)
		return
	traveled = minf(traveled + speed * delta, _length)
	if traveled >= _length:
		is_arrived = true
		arrived.emit()


## 被打中。回傳是否算一次（停下中或已抵達就不算）。
func hit() -> bool:
	if is_arrived or stop_left > 0.0:
		return false
	injured += 1
	stop_left = stop_sec
	hit_taken.emit(injured)
	return true


## 路線上目前的位置。
func position() -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	var left: float = traveled
	for i: int in range(1, points.size()):
		var seg: float = points[i - 1].distance_to(points[i])
		if left <= seg and seg > 0.0:
			return points[i - 1].lerp(points[i], left / seg)
		left -= seg
	return points[points.size() - 1]


## 目前前進方向（水平）。
func heading() -> Vector3:
	if points.size() < 2:
		return Vector3.FORWARD
	var left: float = traveled
	for i: int in range(1, points.size()):
		var seg: float = points[i - 1].distance_to(points[i])
		if left < seg or i == points.size() - 1:
			var d: Vector3 = points[i] - points[i - 1]
			d.y = 0.0
			return d.normalized() if d.length() > 0.001 else Vector3.FORWARD
		left -= seg
	return Vector3.FORWARD


## 存檔用（戰鬥中不能手動存檔，這是給檢查點與測試的）。
func to_dict() -> Dictionary:
	return {"traveled": traveled, "injured": injured, "arrived": is_arrived}


func from_dict(d: Dictionary) -> void:
	traveled = clampf(float(d.get("traveled", 0.0)), 0.0, _length)
	injured = int(d.get("injured", 0))
	is_arrived = bool(d.get("arrived", false))
	stop_left = 0.0
