extends TestCase
## 第 3 章段落 5「倒吊」的拉繩子（HangRope）：按住拉住＋左右修正擺盪；
## 不按 → 進度不會往上；不修正 → 一直撞鐵架；照著擺盪往反方向推 → 切得完。

const DT: float = 1.0 / 60.0


static func _counter(r: HangRope) -> float:
	return HangRope.counter_steer(r)


func test_holding_and_steering_finishes() -> void:
	var r := HangRope.new()
	var sec: float = 0.0
	while not r.done and sec < 30.0:
		r.step(DT, true, _counter(r))
		sec += DT
	assert_true(r.done, "按住＋往反方向推：切得完")
	assert_true(sec < 12.0, "12 秒內（實際 %.1f 秒）" % sec)
	assert_true(sec >= HangRope.CUT_SEC, "至少要 CUT_SEC 秒")
	assert_true(r.bumps <= 1, "幾乎不撞鐵架（撞了 %d 次）" % r.bumps)


func test_not_holding_never_progresses() -> void:
	var r := HangRope.new()
	for i: int in 60 * 20:
		r.step(DT, false, _counter(r))
	assert_eq(r.progress, 0.0, "沒按住：她只會往下滑")
	assert_false(r.done)


func test_without_steering_she_swings_into_the_frame() -> void:
	var r := HangRope.new()
	for i: int in 60 * 20:
		r.step(DT, true, 0.0)
	assert_true(r.bumps >= 3, "不修正：一直撞到鐵架（%d 次）" % r.bumps)
	assert_false(r.done, "不修正：20 秒切不完（進度 %.2f）" % r.progress)


func test_letting_go_slips_back() -> void:
	var r := HangRope.new()
	for i: int in 60 * 3:
		r.step(DT, true, _counter(r))
	var before: float = r.progress
	assert_true(before > 0.2, "穩住 3 秒：有進度")
	for i: int in 60:
		r.step(DT, false, _counter(r))
	assert_true(r.progress < before, "放開一秒：往下滑")
	assert_false(r.cutting(), "放開的時候切不到")


func test_bump_is_clamped_and_bounces() -> void:
	var r := HangRope.new()
	r.progress = 0.5
	r.sway = 0.99
	r.sway_vel = 3.0
	assert_true(r.step(DT, true, 1.0), "擺過頭：撞到")
	assert_eq(r.sway, HangRope.LIMIT)
	assert_true(r.sway_vel < 0.0, "反彈")
	assert_true(absf(r.progress - (0.5 - HangRope.BUMP_LOSS)) < 0.001, "扣進度")


func test_drift_is_deterministic() -> void:
	assert_eq(HangRope.drift_at(2.0), HangRope.drift_at(2.0))
	var peak: float = 0.0
	for i: int in 600:
		peak = maxf(peak, absf(HangRope.drift_at(i * 0.05)))
	assert_true(peak < HangRope.STEER, "外力比玩家推的力小：穩得住")
