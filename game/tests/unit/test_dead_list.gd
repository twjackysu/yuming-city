extends TestCase
## 第 1 章白天的霜橋鎮（D-170）：死者名單的張數跟切片結果一致（跟艾妲收束那句同一套條件）、
## 名單的對話依結果換句、紙的 mesh、蓋在沒救出來的人身上的布。


## [救出人數, 車隊被打幾次, 死亡人數]
const CASES: Array = [[3, 0, 31], [4, 0, 29], [4, 1, 30], [3, 3, 33], [4, 3, 33], [3, 1, 31]]


func _state(rescued: int, injured: int) -> GameState:
	var st := GameState.new()
	st.set_flag("slice.rescued_count", rescued)
	st.set_flag("slice.convoy_injured", injured)
	return st


func test_dead_count_matches_ada_aftermath() -> void:
	for c: Array in CASES:
		var st: GameState = _state(int(c[0]), int(c[1]))
		var n: int = DeadListBoard.dead_count(st)
		assert_eq(n, int(c[2]), "救出 %d、車隊被打 %d 次" % [c[0], c[1]])
		# 收束時艾妲說的人數＝名單的張數
		var r := DialogueRunner.new(Game.dialogues, st)
		assert_true(r.start("slice_ada_aftermath"))
		assert_eq(r.current_text(), "DLG_AFTER_DEAD_%d" % n, "艾妲說的人數跟名單一樣（%d）" % n)
		# 名單的對話：數到的張數、跟攻略比
		var list := DialogueRunner.new(Game.dialogues, st)
		assert_true(list.start(DeadListBoard.DIALOGUE), "有名單的對話")
		assert_eq(list.current_text(), "DLG_CH1_LIST_COUNT_%d" % n)
		list.advance()
		assert_eq(list.current_text(), "DLG_CH1_LIST_GUIDE", "攻略上寫三十一人")
		list.advance()
		assert_eq(list.current_text(), "DLG_CH1_LIST_DIFF_%d" % n)
		list.advance()
		var north: String = "DLG_CH1_LIST_NORTH_NONE" if int(c[0]) >= 4 else "DLG_CH1_LIST_NORTH_ONE"
		assert_eq(list.current_text(), north, "北街那幾張")
		list.advance()
		assert_eq(list.current_text(), "DLG_CH1_LIST_SHEILA")
		list.advance()
		assert_eq(st.get_flag(DeadListBoard.READ_FLAG), true, "講完記得看過名單")


func test_north_unrescued_and_many() -> void:
	assert_eq(DeadListBoard.north_unrescued(_state(4, 0)), 0)
	assert_eq(DeadListBoard.north_unrescued(_state(3, 0)), 1)
	# 開發捷徑（slice.rescue_done，一個都沒救）：四個人都在名單上
	var st := GameState.new()
	assert_eq(DeadListBoard.north_unrescued(st), 4)
	var r := DialogueRunner.new(Game.dialogues, st)
	assert_true(r.start(DeadListBoard.DIALOGUE))
	for i: int in 3:
		r.advance()
	assert_eq(r.current_text(), "DLG_CH1_LIST_NORTH_MANY", "沒救出好幾個 →「最下面那幾張」")


func test_paper_mesh_one_sheet_per_name() -> void:
	for n: int in [29, 33]:
		var m: ArrayMesh = DeadListBoard.papers_mesh(n)
		assert_eq(m.get_surface_count(), 2, "紙＋墨兩個 surface")
		var paper: Array = m.surface_get_arrays(0)
		assert_eq((paper[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), n * 6, "%d 張紙" % n)
		var ink: Array = m.surface_get_arrays(1)
		assert_true((ink[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() >= n * 3 * 6, "每張至少三道墨痕")
		# 都貼在木板正面的範圍裡
		var box: AABB = m.get_aabb()
		assert_true(box.size.x <= DeadListBoard.BOARD_W + 0.05, "紙不超出木板寬")
		assert_true(box.position.y >= DeadListBoard.BOARD_BOTTOM - 0.03, "紙不低於木板")
		assert_true(box.end.y <= DeadListBoard.BOARD_BOTTOM + DeadListBoard.BOARD_H + 0.03, "紙不高於木板")
		# 正面朝 +Z（法線往外，從廣場看得到）
		var normals: PackedVector3Array = paper[Mesh.ARRAY_NORMAL] as PackedVector3Array
		assert_true(normals[0].z > 0.9, "紙的法線朝 +Z")


func test_shroud_mesh_shape() -> void:
	var m: ArrayMesh = RescueSite.shroud_mesh()
	var box: AABB = m.get_aabb()
	assert_true(absf(box.size.x - 1.1) < 0.02 and absf(box.size.z - 2.24) < 0.02, "布 1.1 × 2.24 m")
	assert_true(box.end.y > 0.2 and box.end.y < 0.3, "人形撐起來最高 0.2～0.3 m")
	assert_true(box.position.y >= 0.0, "布不會沉到地面下")
	var arrays: Array = m.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var up: int = 0
	for nm: Vector3 in normals:
		if nm.y > 0.0:
			up += 1
	assert_eq(up, normals.size(), "法線都朝上（從上面看得到）")
	# 胸口比腳邊高、四個角貼地
	var chest: float = 0.0
	var corner: float = 1.0
	for v: Vector3 in verts:
		if absf(v.x) < 0.03 and absf(v.z + 0.36) < 0.03:
			chest = maxf(chest, v.y)
		if absf(absf(v.x) - 0.55) < 0.01 and absf(absf(v.z) - 1.12) < 0.01:
			corner = minf(corner, v.y)
	assert_true(chest > 0.2, "胸口撐起來")
	assert_true(corner < 0.03, "角落貼地")
