extends TestCase
## 重現期間的混音（D-183）：SFX 低通＋Music 壓低、心跳走 Heart 匯流排不被悶住；
## 進入快、放開慢；來源輪詢（石拱倒數中、乾運河按住重現）；暫停時放開。

const SettingsScript: GDScript = preload("res://autoload/settings.gd")


class FakeSource extends Node:
	var on: bool = true

	func restore_mix_active() -> bool:
		return on


func after_each() -> void:
	tree.paused = false
	RestoreMix.apply_amount(Game.restore_mix.amount if Game.restore_mix != null else 0.0)


func test_buses_and_effects() -> void:
	SettingsScript.ensure_buses()
	var heart: int = AudioServer.get_bus_index("Heart")
	assert_true(heart >= 0, "Heart 匯流排")
	assert_eq(AudioServer.get_bus_send(heart), &"Master", "心跳直接接 Master（不經過 SFX 的低通）")
	assert_not_null(RestoreMix.lowpass(), "SFX 匯流排有低通")
	assert_not_null(RestoreMix.music_duck(), "Music 匯流排有壓低用的 Amplify")
	# 再呼叫一次不會重複加效果
	SettingsScript.ensure_buses()
	assert_eq(AudioServer.get_bus_effect_count(AudioServer.get_bus_index("SFX")), 1, "SFX 只有一個效果")
	assert_eq(AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Music")), 1, "Music 只有一個效果")


func test_heart_volume_follows_sfx_slider() -> void:
	var before: float = Settings.volume("SFX")
	Settings.set_volume("SFX", 0.4)
	var heart: int = AudioServer.get_bus_index("Heart")
	assert_true(absf(AudioServer.get_bus_volume_db(heart) - linear_to_db(0.4)) < 0.01, "Heart 跟著「音效」音量")
	Settings.set_volume("SFX", 0.0)
	assert_true(AudioServer.is_bus_mute(heart), "音效關掉時心跳也關掉")
	Settings.set_volume("SFX", before)
	assert_false(AudioServer.is_bus_mute(heart))


func test_curve_endpoints() -> void:
	assert_true(absf(RestoreMix.cutoff_for(0.0) - RestoreMix.OPEN_HZ) < 1.0)
	assert_true(absf(RestoreMix.cutoff_for(1.0) - RestoreMix.CLOSED_HZ) < 1.0)
	var mid: float = RestoreMix.cutoff_for(0.5)
	assert_true(absf(mid - sqrt(RestoreMix.OPEN_HZ * RestoreMix.CLOSED_HZ)) < 1.0, "對數尺度的中點（%.0f Hz）" % mid)
	assert_eq(RestoreMix.duck_for(0.0), 0.0)
	assert_eq(RestoreMix.duck_for(1.0), RestoreMix.MUSIC_DUCK_DB)


func test_step_attack_fast_release_slow() -> void:
	var m := RestoreMix.new()
	m.step(RestoreMix.ATTACK_SEC * 0.5, true)
	assert_true(absf(m.amount - 0.5) < 0.001, "進入：%.3f" % m.amount)
	assert_true(RestoreMix.lowpass_enabled(), "重現中低通打開")
	m.step(1.0, true)
	assert_eq(m.amount, 1.0)
	assert_true(absf(RestoreMix.lowpass().cutoff_hz - RestoreMix.CLOSED_HZ) < 1.0, "完全悶住")
	assert_true(absf(RestoreMix.music_duck().volume_db - RestoreMix.MUSIC_DUCK_DB) < 0.01, "Music 壓低")
	m.step(RestoreMix.ATTACK_SEC * 0.5, false)
	assert_true(m.amount > 0.8, "放開比進入慢（%.3f）" % m.amount)
	m.step(RestoreMix.RELEASE_SEC, false)
	assert_eq(m.amount, 0.0)
	assert_false(RestoreMix.lowpass_enabled(), "平常整個關掉")
	assert_eq(RestoreMix.music_duck().volume_db, 0.0)
	m.free()


func test_sources_polling_and_pause() -> void:
	assert_not_null(Game.restore_mix, "Game 自動建一個")
	assert_eq(Game.restore_mix.process_mode, Node.PROCESS_MODE_ALWAYS)
	var src := FakeSource.new()
	tree.root.add_child(src)
	assert_false(Game.restore_mix.sources_active(), "不在群組裡不算")
	src.add_to_group(RestoreMix.GROUP)
	assert_true(Game.restore_mix.sources_active(), "群組裡有一個在重現")
	for i: int in 30:
		await tree.process_frame
	assert_true(Game.restore_mix.amount > 0.0, "Game 的混音跟著來源（%.3f）" % Game.restore_mix.amount)
	tree.paused = true
	assert_false(Game.restore_mix.sources_active(), "暫停時放開")
	tree.paused = false
	src.on = false
	assert_false(Game.restore_mix.sources_active())
	src.on = true
	src.queue_free()
	await tree.process_frame
	assert_false(Game.restore_mix.sources_active(), "來源消失（換關卡）就放開")
	Game.restore_mix.step(10.0, false)


func test_nine_breath_site_is_a_source_and_heart_bypasses_lowpass() -> void:
	var st := GameState.new()
	var root := Node3D.new()
	tree.root.add_child(root)
	var site := NineBreathSite.new()
	site.state = st
	root.add_child(site)
	assert_true(site.is_in_group(RestoreMix.GROUP), "石拱在混音的來源群組")
	assert_false(site.restore_mix_active(), "還沒重現")
	assert_true(site.activate(), "發動")
	assert_true(site.restore_mix_active(), "倒數中算重現")
	# 每一息的心跳走 Heart 匯流排
	site.nb.tick(1.01, st)
	var heart_players: int = 0
	for n: Node in site.get_children():
		var p: AudioStreamPlayer = n as AudioStreamPlayer
		if p != null and Sfx.stream("heartbeat") == p.stream:
			assert_eq(p.bus, Sfx.HEART_BUS, "心跳不經過 SFX 的低通")
			heart_players += 1
	assert_true(heart_players >= 1, "第一息有心跳（%d）" % heart_players)
	site.nb.tick(20.0, st)
	assert_false(site.restore_mix_active(), "化灰之後放開")
	root.queue_free()
	await tree.process_frame
	Game.restore_mix.step(10.0, false)
