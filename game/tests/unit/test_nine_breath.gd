extends TestCase
## 九息狀態還原與記憶代價。

var _breaths: Array[int] = []
var _finished: int = 0


func _make() -> NineBreath:
	_breaths.clear()
	_finished = 0
	var nb := NineBreath.new("south_arch", "arch_father_last_talk")
	nb.breath.connect(func(i: int) -> void: _breaths.append(i))
	nb.finished.connect(func() -> void: _finished += 1)
	return nb


func test_full_cycle_pays_once_and_ends_spent() -> void:
	var state := GameState.new()
	var nb: NineBreath = _make()
	assert_true(nb.can_activate())
	assert_true(nb.activate(state))
	assert_true(state.has_paid_memory("arch_father_last_talk"))
	assert_false(nb.activate(state), "重現中不能再發動")
	assert_eq(nb.remaining(), 9.0)
	for i: int in 30:
		nb.tick(0.3, state)  # 9.0 秒
	assert_eq(nb.phase, NineBreath.Phase.SPENT)
	assert_eq(_breaths, [1, 2, 3, 4, 5, 6, 7, 8, 9] as Array[int], "九息各一次")
	assert_eq(_finished, 1)
	assert_eq(state.get_flag("ninebreath.south_arch"), "spent")
	assert_eq(state.memories_paid.size(), 1)
	nb.tick(5.0, state)
	assert_eq(_finished, 1, "結束後不再發出事件")


func test_large_delta_still_emits_every_breath() -> void:
	var state := GameState.new()
	var nb: NineBreath = _make()
	nb.activate(state)
	nb.tick(100.0, state)
	assert_eq(_breaths.size(), 9)
	assert_eq(nb.phase, NineBreath.Phase.SPENT)


func test_save_mid_restoration_loads_as_spent_without_double_charge() -> void:
	var state := GameState.new()
	var nb: NineBreath = _make()
	nb.activate(state)
	nb.tick(4.5, state)
	var reloaded: GameState = SaveCodec.decode(SaveCodec.encode(state))["state"]
	var nb2 := NineBreath.new("south_arch", "arch_father_last_talk")
	nb2.load_from(reloaded)
	assert_eq(nb2.phase, NineBreath.Phase.SPENT, "不會停在九息中間")
	assert_false(nb2.can_activate())
	assert_eq(reloaded.memories_paid.size(), 1, "代價只付一次")


func test_fresh_load_is_broken() -> void:
	var nb := NineBreath.new("south_arch", "arch_father_last_talk")
	nb.load_from(GameState.new())
	assert_eq(nb.phase, NineBreath.Phase.BROKEN)
	assert_true(nb.can_activate())
