class_name FrameStats
extends RefCounted
## 幀時間統計（環形緩衝）。給效能 overlay 與 benchmark 共用，純計算、可測試。
## 1% low：最慢的 1% 幀的平均幀時間換算成 FPS（至少取 1 幀）。

var capacity: int
var _samples: PackedFloat32Array = []
var _next: int = 0
var _count: int = 0


func _init(p_capacity: int = 1000) -> void:
	capacity = maxi(p_capacity, 1)
	_samples.resize(capacity)


func push(frame_ms: float) -> void:
	_samples[_next] = frame_ms
	_next = (_next + 1) % capacity
	_count = mini(_count + 1, capacity)


func count() -> int:
	return _count


func clear() -> void:
	_next = 0
	_count = 0


func _values() -> PackedFloat32Array:
	return _samples.slice(0, _count) if _count < capacity else _samples.duplicate()


func average_ms() -> float:
	if _count == 0:
		return 0.0
	var total: float = 0.0
	for v: float in _values():
		total += v
	return total / float(_count)


func max_ms() -> float:
	var m: float = 0.0
	for v: float in _values():
		m = maxf(m, v)
	return m


func average_fps() -> float:
	var avg: float = average_ms()
	return 0.0 if avg <= 0.0 else 1000.0 / avg


func one_percent_low_fps() -> float:
	if _count == 0:
		return 0.0
	var sorted: PackedFloat32Array = _values()
	sorted.sort()
	var n: int = maxi(1, int(ceil(float(_count) * 0.01)))
	var total: float = 0.0
	for i: int in n:
		total += sorted[_count - 1 - i]
	var worst_avg: float = total / float(n)
	return 0.0 if worst_avg <= 0.0 else 1000.0 / worst_avg


## 超過預算（預設 16.7 ms＝60 fps）的幀比例。
func over_budget_ratio(budget_ms: float = 16.7) -> float:
	if _count == 0:
		return 0.0
	var over: int = 0
	for v: float in _values():
		if v > budget_ms:
			over += 1
	return float(over) / float(_count)


func to_dict() -> Dictionary:
	return {
		"frames": _count,
		"avg_ms": snappedf(average_ms(), 0.01),
		"max_ms": snappedf(max_ms(), 0.01),
		"avg_fps": snappedf(average_fps(), 0.1),
		"low1_fps": snappedf(one_percent_low_fps(), 0.1),
		"over_16_7ms_ratio": snappedf(over_budget_ratio(), 0.0001),
	}
