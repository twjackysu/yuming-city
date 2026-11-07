extends TestCase
## 幀時間統計（效能 overlay／benchmark）。


func test_average_and_low() -> void:
	var s := FrameStats.new(100)
	for i: int in 99:
		s.push(10.0)
	s.push(50.0)
	assert_eq(s.count(), 100)
	assert_true(is_equal_approx(s.average_ms(), 10.4), "平均 %.3f" % s.average_ms())
	assert_true(is_equal_approx(s.one_percent_low_fps(), 20.0), "1%% low＝最慢 1 幀 50ms → 20 fps，實際 %.2f" % s.one_percent_low_fps())
	assert_true(is_equal_approx(s.max_ms(), 50.0))
	assert_true(is_equal_approx(s.over_budget_ratio(), 0.01), "超過 16.7ms 的比例")


func test_ring_buffer_drops_oldest() -> void:
	var s := FrameStats.new(4)
	for v: float in [100.0, 100.0, 10.0, 10.0, 10.0, 10.0]:
		s.push(v)
	assert_eq(s.count(), 4)
	assert_true(is_equal_approx(s.average_ms(), 10.0), "舊的 100ms 已被覆蓋")


func test_empty() -> void:
	var s := FrameStats.new()
	assert_eq(s.average_fps(), 0.0)
	assert_eq(s.one_percent_low_fps(), 0.0)
	assert_eq(s.to_dict()["frames"], 0)
