extends TestCase
## 條件與效果（StoryLogic）。


func _state() -> GameState:
	var s := GameState.new()
	s.set_flag("a", true)
	s.set_flag("count", 3)
	s.set_flag("name", "ada")
	s.quests["q"] = "middle"
	return s


func test_basic_conditions() -> void:
	var s: GameState = _state()
	assert_true(StoryLogic.check({}, s), "空條件永遠成立")
	assert_true(StoryLogic.check({"flag": "a"}, s))
	assert_false(StoryLogic.check({"flag": "missing"}, s), "不存在的旗標為假")
	assert_true(StoryLogic.check({"flag": "count", "gte": 3}, s))
	assert_false(StoryLogic.check({"flag": "count", "gt": 3}, s))
	assert_true(StoryLogic.check({"flag": "count", "lt": 4}, s))
	assert_true(StoryLogic.check({"flag": "name", "eq": "ada"}, s))
	assert_true(StoryLogic.check({"flag": "name", "ne": "mia"}, s))
	assert_true(StoryLogic.check({"flag": "missing", "lte": 0}, s), "不存在的數字旗標視為 0")
	assert_true(StoryLogic.check({"quest": "q", "stage": "middle"}, s))
	assert_true(StoryLogic.check({"quest": "q", "done": false}, s))
	assert_false(StoryLogic.check({"quest": "q", "done": true}, s))


func test_compound_conditions() -> void:
	var s: GameState = _state()
	assert_true(StoryLogic.check({"all": [{"flag": "a"}, {"flag": "count", "eq": 3}]}, s))
	assert_false(StoryLogic.check({"all": [{"flag": "a"}, {"flag": "missing"}]}, s))
	assert_true(StoryLogic.check({"any": [{"flag": "missing"}, {"flag": "a"}]}, s))
	assert_true(StoryLogic.check({"not": {"flag": "missing"}}, s))


func test_json_float_compares_as_number() -> void:
	# 存讀檔後整數會變成 float（JSON），比較結果不能改變。
	var s := GameState.new()
	s.set_flag("ch1.barrels_hit", 9.0)
	assert_true(StoryLogic.check({"flag": "ch1.barrels_hit", "gte": 9}, s))
	assert_true(StoryLogic.check({"flag": "ch1.barrels_hit", "eq": 9}, s))


func test_effects() -> void:
	var s := GameState.new()
	StoryLogic.apply({"set": {"x": true}, "add": {"n": 2}}, s)
	StoryLogic.apply({"add": {"n": 1}}, s)
	assert_eq(s.get_flag("x"), true)
	assert_eq(s.get_flag("n"), 3, "add 保持整數")
	s.set_flag("f", 1.0)
	StoryLogic.apply({"add": {"f": 1}}, s)
	assert_eq(s.get_flag("f"), 2, "float 整數值加完變回 int")


func test_validation() -> void:
	assert_eq(StoryLogic.validate_condition({"flag": "a", "gte": 1}), "")
	assert_eq(StoryLogic.validate_condition({"all": [{"flag": "a"}, {"quest": "q", "done": true}]}), "")
	assert_ne(StoryLogic.validate_condition({"memory_paid": "m"}), "", "記憶代價的條件拿掉了：資料裡再出現要報錯")
	assert_ne(StoryLogic.validate_condition({"all": []}), "", "空的 all")
	assert_ne(StoryLogic.validate_condition({"flag": "a", "gte": 1, "lte": 2}), "", "兩個比較")
	assert_ne(StoryLogic.validate_condition({"script": "OS.execute()"}), "", "不允許任意程式")
	assert_ne(StoryLogic.validate_condition({"quest": "q"}), "", "quest 需要 stage 或 done")
	assert_ne(StoryLogic.validate_condition("flag"), "", "必須是物件")
	assert_eq(StoryLogic.validate_effects({"set": {}, "add": {}, "start_quest": []}), "")
	assert_ne(StoryLogic.validate_effects({"call": "quit"}), "", "未知效果")
