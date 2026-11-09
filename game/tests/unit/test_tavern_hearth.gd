extends TestCase
## 酒館的壁爐（第 52 輪）：火光閃動在 ±13% 內、平均不變（不會讓整個房間變暗或變亮）。


func test_hearth_flicker_range() -> void:
	var Tavern: GDScript = load("res://scenes/levels/tavern.gd") as GDScript
	var lo: float = 10.0
	var hi: float = 0.0
	var total: float = 0.0
	var n: int = 2000
	for i: int in n:
		var f: float = float(Tavern.call("hearth_flicker", i * 0.013))
		lo = minf(lo, f)
		hi = maxf(hi, f)
		total += f
	assert_true(lo >= 0.87 and hi <= 1.13, "閃動在 ±13%% 內（%.3f～%.3f）" % [lo, hi])
	assert_true(hi - lo > 0.12, "看得出在閃")
	assert_true(absf(total / n - 1.0) < 0.02, "平均亮度不變")
