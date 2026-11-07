extends TestCase
## 目標指引（02-gameplay「目標指引」）：任務資料的 marker／marker_if、目標位置解析、畫面邊緣定位。


func _db_with(stage: Dictionary) -> QuestDB:
	var db := QuestDB.new()
	var st: Dictionary = {"id": "one", "objective": "O1", "done_when": {"flag": "f1"}}
	st.merge(stage, true)
	db.add_quest({"id": "main", "title": "T", "stages": [st]})
	return db


func test_validate_marker_forms() -> void:
	assert_eq(QuestDB.validate_marker("node:Bell"), "")
	assert_eq(QuestDB.validate_marker("nearest:Rescue_"), "")
	assert_eq(QuestDB.validate_marker([1, 2.5, -3]), "")
	assert_ne(QuestDB.validate_marker("Bell"), "", "沒有前綴")
	assert_ne(QuestDB.validate_marker("node:"), "", "空名稱")
	assert_ne(QuestDB.validate_marker([1, 2]), "", "座標要三個")
	assert_ne(QuestDB.validate_marker(["a", 1, 2]), "", "座標要是數字")
	var bad: QuestDB = _db_with({"marker": "Bell", "marker_if": [{"when": {"flag": "x"}}]})
	assert_eq(bad.quests.size(), 0, "marker 寫錯的任務不載入")
	assert_true(bad.errors.size() >= 2, "marker 與 marker_if 都要報錯（%d）" % bad.errors.size())


func test_marker_spec_uses_first_matching_alternative() -> void:
	var db: QuestDB = _db_with({"marker": "node:A", "marker_if": [
		{"when": {"flag": "b"}, "marker": "node:B"},
		{"when": {"flag": "c"}, "marker": [0, 0, 5]},
	]})
	assert_eq(db.errors, PackedStringArray())
	var s := GameState.new()
	var r := QuestRunner.new(db, s)
	assert_eq(r.marker_spec("main"), null, "任務還沒開始沒有目標")
	r.start("main")
	assert_eq(r.marker_spec("main"), "node:A")
	s.set_flag("c", true)
	assert_eq(r.marker_spec("main"), [0, 0, 5])
	s.set_flag("b", true)
	assert_eq(r.marker_spec("main"), "node:B", "第一個成立的優先")


func test_every_slice_stage_has_a_marker() -> void:
	var db := QuestDB.load_default()
	for st: Variant in db.stages(GameSession.MAIN_QUEST):
		assert_true((st as Dictionary).has("marker"), "階段 %s 有目標指引" % (st as Dictionary)["id"])


class Site extends Node3D:
	var available: bool = true

	func is_available() -> bool:
		return available


func test_resolve_target() -> void:
	var level := Node3D.new()
	tree.root.add_child(level)
	var a := Node3D.new()
	a.name = "Bell"
	a.position = Vector3(0, 3, -50)
	level.add_child(a)
	var near := Site.new()
	near.name = "Rescue_a"
	near.position = Vector3(0, 0, -10)
	level.add_child(near)
	var far := Site.new()
	far.name = "Rescue_b"
	far.position = Vector3(0, 0, -30)
	level.add_child(far)
	assert_eq(ObjectiveGuide.resolve_target(level, "node:Bell", Vector3.ZERO), Vector3(0, 3, -50))
	assert_eq(ObjectiveGuide.resolve_target(level, [1, 2, 3], Vector3.ZERO), Vector3(1, 2, 3))
	assert_false(ObjectiveGuide.resolve_target(level, "node:Nope", Vector3.ZERO).is_finite(), "找不到節點")
	assert_false(ObjectiveGuide.resolve_target(level, null, Vector3.ZERO).is_finite(), "沒有目標")
	assert_eq(ObjectiveGuide.resolve_target(level, "nearest:Rescue_", Vector3.ZERO), Vector3(0, 0, -10), "最近的")
	near.available = false
	assert_eq(ObjectiveGuide.resolve_target(level, "nearest:Rescue_", Vector3.ZERO), Vector3(0, 0, -30), "跳過已完成的")
	far.available = false
	assert_false(ObjectiveGuide.resolve_target(level, "nearest:Rescue_", Vector3.ZERO).is_finite(), "全部完成就沒有目標")
	level.queue_free()
	await tree.process_frame


func test_edge_placement_for_target_behind() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.global_position = Vector3(0, 1.6, 0)
	cam.look_at(Vector3(0, 1.6, -10))
	cam.make_current()
	var g := ObjectiveGuide.new()
	var layer := CanvasLayer.new()
	root.add_child(layer)
	layer.add_child(g)
	await tree.process_frame
	g._place(cam, Vector3(0, 1.6, -20))
	assert_true(g.on_screen, "正前方在畫面內")
	var rect: Rect2 = g.get_viewport_rect()
	assert_true(absf(g.screen_pos.x - rect.size.x * 0.5) < 2.0, "正前方在畫面中央")
	g._place(cam, Vector3(0, 1.6, 20))
	assert_false(g.on_screen, "身後不在畫面內")
	assert_true(g.screen_pos.y > rect.size.y * 0.5, "身後的目標貼在畫面下緣（y=%.0f）" % g.screen_pos.y)
	g._place(cam, Vector3(30, 1.6, -1))
	assert_false(g.on_screen, "右邊很遠")
	assert_true(g.screen_pos.x > rect.size.x * 0.75, "右邊的目標貼在右緣（x=%.0f）" % g.screen_pos.x)
	root.queue_free()
	await tree.process_frame
