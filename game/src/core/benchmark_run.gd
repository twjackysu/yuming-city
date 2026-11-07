class_name BenchmarkRun
extends RefCounted
## 一次 benchmark 的計時與統計（純邏輯）。暖機時間不計入；超過 SPIKE_MS 的幀記為尖峰
## （常見原因：第一次出現某材質時編譯 shader）。

const SPIKE_MS: float = 50.0
const MAX_SPIKES: int = 64

var duration_sec: float
var warmup_sec: float
var elapsed: float = 0.0
var stats: FrameStats
var spikes: Array[Dictionary] = []


func _init(p_duration_sec: float = 30.0, p_warmup_sec: float = 2.0) -> void:
	duration_sec = maxf(p_duration_sec, 1.0)
	warmup_sec = maxf(p_warmup_sec, 0.0)
	stats = FrameStats.new(int(ceil(duration_sec * 240.0)))


## 0～1，給鏡頭路徑用（含暖機）。
func progress() -> float:
	return clampf(elapsed / (warmup_sec + duration_sec), 0.0, 1.0)


func is_finished() -> bool:
	return elapsed >= warmup_sec + duration_sec


## 每幀呼叫；回傳是否已結束。
func push(delta_sec: float) -> bool:
	if is_finished():
		return true
	var frame_ms: float = delta_sec * 1000.0
	if frame_ms > SPIKE_MS and spikes.size() < MAX_SPIKES:
		spikes.append({"t": snappedf(elapsed, 0.01), "ms": snappedf(frame_ms, 0.1)})
	if elapsed >= warmup_sec:
		stats.push(frame_ms)
	elapsed += delta_sec
	return is_finished()


func to_dict(meta: Dictionary = {}) -> Dictionary:
	var d: Dictionary = meta.duplicate(true)
	d["duration_sec"] = duration_sec
	d["warmup_sec"] = warmup_sec
	d["stats"] = stats.to_dict()
	d["spikes"] = spikes.duplicate(true)
	d["target"] = {"fps": 60, "frame_ms": 16.7}
	d["meets_target"] = stats.count() > 0 and stats.average_fps() >= 60.0 and stats.one_percent_low_fps() >= 45.0
	return d
