extends TestCase
## Benchmark 計時與報告。

const BenchScript: GDScript = preload("res://scenes/bench/benchmark.gd")


func test_warmup_not_counted_and_spikes_recorded() -> void:
	var run := BenchmarkRun.new(2.0, 1.0)
	run.push(0.1)  # 暖機中的 100ms 尖峰：記為尖峰，但不計入統計
	var finished: bool = false
	var frames: int = 1
	while not finished and frames < 10000:
		finished = run.push(1.0 / 60.0)
		frames += 1
	assert_true(finished, "跑完會結束")
	assert_eq(run.spikes.size(), 1, "尖峰紀錄")
	assert_true(absf(run.stats.average_fps() - 60.0) < 0.5, "暖機不計入：平均 %.2f" % run.stats.average_fps())
	var d: Dictionary = run.to_dict({"adapter": "test"})
	assert_eq(d["adapter"], "test", "保留 meta")
	assert_true(d["meets_target"] as bool, "60 fps 達標")
	assert_true(run.push(0.016), "結束後再 push 仍回傳 true")


func test_progress_goes_zero_to_one() -> void:
	var run := BenchmarkRun.new(1.0, 0.0)
	assert_eq(run.progress(), 0.0)
	run.push(0.5)
	assert_true(is_equal_approx(run.progress(), 0.5))
	run.push(1.0)
	assert_eq(run.progress(), 1.0)


func test_camera_path_endpoints() -> void:
	var first: Vector3 = BenchScript.call("sample_path", 0.0)
	var last: Vector3 = BenchScript.call("sample_path", 1.0)
	var pts: Array[Vector3] = BenchScript.get("PATH_POINTS")
	assert_true(first.is_equal_approx(pts[0]), "起點")
	assert_true(last.is_equal_approx(pts[pts.size() - 1]), "終點")
