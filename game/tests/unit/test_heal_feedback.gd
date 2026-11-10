extends TestCase
## 回血的畫面回饋（D-213）：生命條的綠色段／紅色段（BarTrail，純邏輯）＋身邊的綠色光點（HealMotes）。


func _steps(t: BarTrail, ratio: float, seconds: float) -> void:
	for i: int in int(seconds * 60.0):
		t.step(ratio, 1.0 / 60.0)


func test_bar_trail_first_frame_snaps_without_fake_heal() -> void:
	var t := BarTrail.new()
	t.step(0.55, 1.0 / 60.0)
	assert_eq(t.ratio, 0.55)
	assert_eq(t.heal_span(), 0.0, "讀檔後的第一幀不演「從 0 回上來」")
	assert_eq(t.loss_span(), 0.0)
	assert_false(t.is_healing())
	assert_eq(t.base_ratio(), 0.55)


func test_bar_trail_heal_shows_green_segment_then_merges() -> void:
	var t := BarTrail.new()
	t.reset(0.5)
	# 每秒回 3%（可攜毒劑的速度）：綠色段跟著長，寬度有上限（不會整條變綠）
	var r: float = 0.5
	for i: int in 240:
		r += 0.03 / 60.0
		t.step(r, 1.0 / 60.0)
	assert_true(t.is_healing())
	assert_true(t.heal_span() >= BarTrail.HEAL_MIN_SPAN - 0.0001, "回血中：看得到綠色段（%.3f）" % t.heal_span())
	assert_true(t.heal_span() < 0.12, "只有剛長出來的那一段是綠的（%.3f）" % t.heal_span())
	assert_true(absf(t.base_ratio() + t.heal_span() - t.ratio) < 0.00001, "原色段＋綠色段＝目前的生命")
	assert_eq(t.loss_span(), 0.0, "回血時沒有紅色段")
	# 停止回血：綠色段慢慢併回原色
	_steps(t, r, 0.3)
	assert_true(t.is_healing(), "剛停的那一瞬間還亮著")
	_steps(t, r, 12.0)
	assert_false(t.is_healing())
	assert_eq(t.heal_span(), 0.0, "停了之後併回原本的顏色")
	assert_eq(t.base_ratio(), t.ratio)


func test_bar_trail_slow_heal_still_visible_and_never_exceeds_bar() -> void:
	var t := BarTrail.new()
	t.reset(0.01)
	t.step(0.012, 1.0 / 60.0)
	assert_true(t.heal_span() <= t.ratio + 0.00001, "綠色段不會比目前的生命還寬")
	assert_true(t.base_ratio() >= 0.0)
	t.reset(0.6)
	t.step(0.6005, 1.0 / 60.0)
	assert_true(absf(t.heal_span() - BarTrail.HEAL_MIN_SPAN) < 0.0001, "回得很慢也有最小寬度")


func test_bar_trail_damage_leaves_red_segment_that_drains() -> void:
	var t := BarTrail.new()
	t.reset(0.8)
	t.step(0.5, 1.0 / 60.0)
	assert_true(absf(t.loss_span() - 0.3) < 0.0001, "剛扣掉的那一段是紅的")
	assert_eq(t.heal_span(), 0.0)
	_steps(t, 0.5, 0.2)
	assert_true(absf(t.loss_span() - 0.3) < 0.0001, "先停一下")
	_steps(t, 0.5, 2.0)
	assert_eq(t.loss_span(), 0.0, "然後縮回去")
	# 被打之後回血：綠色段從被打後的位置長，不會把被扣掉的那段也算成回血
	t.step(0.52, 1.0 / 60.0)
	assert_true(t.heal_span() <= 0.03, "只算新回的（%.3f）" % t.heal_span())
	# 紅色段還在的時候回血超過它：紅色段消失
	t.reset(0.9)
	t.step(0.6, 1.0 / 60.0)
	t.step(0.95, 1.0 / 60.0)
	assert_eq(t.loss_span(), 0.0)
	# 夾在 0～1
	t.step(1.7, 1.0 / 60.0)
	assert_eq(t.ratio, 1.0)
	assert_true(t.loss_span() == 0.0 and t.heal_span() <= 1.0)


func test_heal_motes_follow_health_and_stop() -> void:
	var host := Node3D.new()
	tree.root.add_child(host)
	var health := Health.new(100.0)
	host.add_child(health)
	health.hp = 50.0
	var fx: HealMotes = HealMotes.attach(host, health)
	await tree.process_frame
	assert_false(fx.is_active(), "沒回血：沒有光點")
	assert_false(fx.motes().emitting)
	assert_eq(ParticleLook.untextured(fx).size(), 0, "光點有圓形貼圖（不是方塊）")
	assert_false(fx.motes().local_coords, "光點留在原地往上飄（不黏在身上）")
	health.heal(1.0)
	await tree.process_frame
	assert_true(fx.is_active() and fx.motes().emitting, "回血：光點往上飄")
	# 滿血時「回血」沒有實際補到：不亮
	health.hp = health.max_hp
	for i: int in 40:
		await tree.process_frame
		fx._process(0.05)
	assert_false(fx.is_active(), "停了就收掉")
	assert_false(fx.motes().emitting)
	health.heal(5.0)
	await tree.process_frame
	assert_false(fx.is_active(), "滿血沒有補到東西：不亮")
	host.queue_free()
	await tree.process_frame


func test_heal_burst_is_one_shot_at_chest_with_soft_light() -> void:
	var host := Node3D.new()
	tree.root.add_child(host)
	host.global_position = Vector3(40.0, 0.0, -7.0)
	var fx: HealMotes = HealMotes.attach(host, null)
	await tree.process_frame
	var ps: CPUParticles3D = fx.burst()
	assert_eq(fx.bursts, 1)
	assert_true(ps.one_shot and ps.emitting, "一次性")
	assert_true(ps.global_position.distance_to(host.global_position + Vector3(0.0, HealMotes.CHEST_Y, 0.0)) < 0.01, "從胸口噴（先擺好位置才開始噴）")
	assert_eq(ParticleLook.untextured(fx).size(), 0)
	assert_true(fx.light().visible, "一下綠光")
	assert_eq(fx.light().light_specular, 0.0, "不打高光")
	assert_false(fx.light().shadow_enabled)
	fx._process(0.1)
	assert_true(fx.light().light_energy > 0.2, "亮起來（%.2f）" % fx.light().light_energy)
	fx._process(HealMotes.BURST_LIGHT_SEC)
	assert_eq(fx.light().light_energy, 0.0, "很快就暗掉")
	assert_false(fx.light().visible)
	host.queue_free()
	await tree.process_frame
