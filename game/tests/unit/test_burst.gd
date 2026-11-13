extends TestCase
## 連拍（docs/design/11-combat-first.md 第 4 節，D-238）：哪幾幀要存。動作驗收看的是這一條，不是停住姿勢的單張圖。


func test_burst_index_picks_every_nth_frame_from_the_start() -> void:
	var app: Node = tree.root.get_node("App")
	var picked: Array[int] = []
	for f: int in 200:
		var i: int = int(app.call("burst_index", f, 100, 6, 8))
		if i >= 0:
			assert_eq(i, picked.size(), "照順序編號")
			picked.append(f)
	assert_eq(picked.size(), 8, "剛好 8 張")
	assert_eq(picked[0], 100, "從指定的那一幀開始")
	assert_eq(picked[7], 142, "每 6 幀一張（60 fps＝每 0.1 秒）")
	assert_eq(int(app.call("burst_index", 99, 100, 6, 8)), -1, "還沒到不存")
	assert_eq(int(app.call("burst_index", 148, 100, 6, 8)), -1, "存滿了不再存")


func test_burst_wait_counts_frames_to_the_next_shot() -> void:
	var app: Node = tree.root.get_node("App")
	assert_eq(int(app.call("burst_wait", 90, 100, 6)), 10, "還沒開始：離第一張幾幀")
	assert_eq(int(app.call("burst_wait", 100, 100, 6)), 0, "要存的那一幀是 0")
	assert_eq(int(app.call("burst_wait", 101, 100, 6)), 5)
	assert_eq(int(app.call("burst_wait", 105, 100, 6)), 1)
	assert_eq(int(app.call("burst_wait", 106, 100, 6)), 0)
	# 每一張要存的幀，burst_wait 都是 0（兩個函式講的是同一件事）
	for f: int in range(100, 148):
		var shot: bool = int(app.call("burst_index", f, 100, 6, 8)) >= 0
		assert_eq(int(app.call("burst_wait", f, 100, 6)) == 0, shot, "第 %d 幀" % f)
