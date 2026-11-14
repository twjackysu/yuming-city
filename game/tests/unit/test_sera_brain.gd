extends TestCase
## 席菈要做什麼（SeraBrain，純邏輯）：跟在諾恩後面的距離、射藥的節奏。場上的席菈在 tests/flow/test_chapter1.gd。

const DT: float = 1.0 / 60.0


func _n(key: String) -> float:
	return CombatTuning.num("sera." + key)


func test_follows_past_far_and_keeps_walking_until_near() -> void:
	var b := SeraBrain.new()
	var mid: float = (_n("follow_near") + _n("follow_far")) * 0.5
	assert_true(_n("follow_near") >= 4.0 and _n("follow_far") <= 6.0, "跟在後面 4～6 m")
	assert_eq(b.follow_speed(mid), 0.0, "一開始就在範圍裡：站著")
	assert_eq(b.follow_speed(_n("follow_far") + 0.5), _n("walk_speed"), "諾恩走遠了就跟上")
	assert_eq(b.follow_speed(mid), _n("walk_speed"), "走到一半不停（不會一步一停）")
	assert_eq(b.follow_speed(_n("follow_near") - 0.1), 0.0, "夠近了停下")
	assert_eq(b.follow_speed(mid), 0.0, "停下之後，諾恩沒走遠就不動")
	assert_eq(b.follow_speed(_n("follow_far") + _n("run_extra") + 1.0), _n("run_speed"), "落後太多用跑的")


func test_no_enemy_no_vial() -> void:
	var b := SeraBrain.new()
	for i: int in 900:
		assert_false(b.tick(DT, false), "附近沒有敵人不射")
	assert_false(b.is_aiming())


func test_first_vial_comes_quickly_then_one_every_interval() -> void:
	var b := SeraBrain.new()
	var times: Array[float] = []
	var stood_still_while_aiming: bool = false
	var t: float = 0.0
	while t < 30.0 and times.size() < 2:
		t += DT
		if b.tick(DT, true):
			times.append(t)
		if b.is_aiming():
			stood_still_while_aiming = b.follow_speed(100.0) == 0.0
	assert_eq(times.size(), 2)
	assert_true(absf(times[0] - (_n("first_vial_delay") + _n("aim_time"))) < 0.05, "開打後很快來第一瓶（含舉弩瞄準）")
	assert_true(absf(times[1] - times[0] - (_n("vial_interval") + _n("aim_time"))) < 0.05, "之後固定間隔")
	assert_true(stood_still_while_aiming, "瞄準的時候不走路")
	assert_true(_n("vial_interval") < float(StatusRules.load_default().source(Sera.VIAL_SOURCE)["duration"]),
		"下一瓶在上一瓶的效果結束前就到：打架時增益不會斷")


func test_fight_over_resets_to_the_quick_first_vial() -> void:
	var b := SeraBrain.new()
	var t: float = 0.0
	while not b.tick(DT, true) and t < 10.0:
		t += DT
	assert_true(absf(b.shot_left - (_n("vial_interval"))) < 0.001)
	b.tick(DT, false)
	assert_true(absf(b.shot_left - (_n("first_vial_delay"))) < 0.001, "敵人都倒了：下一場的第一瓶一樣很快")


func test_a_requested_vial_comes_without_any_enemy() -> void:
	var b := SeraBrain.new()
	b.request()
	assert_false(b.tick(DT, false))
	assert_true(b.is_aiming(), "要了就馬上舉弩")
	var t: float = 0.0
	while not b.tick(DT, false) and t < 5.0:
		t += DT
	assert_true(absf(t - _n("aim_time")) < 0.05, "瞄完就射")
	for i: int in 300:
		assert_false(b.tick(DT, false), "只射要的那一瓶")
