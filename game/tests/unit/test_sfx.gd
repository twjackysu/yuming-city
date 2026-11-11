extends TestCase
## 程序生成音效：每個名字都產生了、讀得到，播放走 SFX 匯流排、播完自動釋放；缺檔安靜跳過。


func test_all_sfx_generated_and_loadable() -> void:
	for n: String in Sfx.NAMES:
		var s: AudioStream = Sfx.stream(n)
		assert_not_null(s, "缺音效 %s（scripts/gen_sfx.py）" % n)
		if s != null:
			assert_true(s.get_length() > 0.1, "%s 長度" % n)
	assert_true(Sfx.stream("poison_charge").get_length() > Sfx.stream("poison_hiss").get_length(), "蓄力那一聲比噴出來的長")
	for gone: String in ["bell", "bell_ninth", "hearth_crackle", "frost_wind_indoor"]:
		assert_false(Sfx.NAMES.has(gone), "%s 已經沒有人播，不再產生" % gone)


func test_play_uses_sfx_bus_and_missing_is_silent() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var p: AudioStreamPlayer3D = Sfx.play_at(root, "blunt", Vector3(1, 2, 3))
	assert_not_null(p)
	if p != null:
		assert_eq(p.bus, &"SFX")
		assert_eq(p.global_position, Vector3(1, 2, 3))
	assert_eq(Sfx.play_at(root, "no_such_sound", Vector3.ZERO), null, "缺檔回傳 null，不報錯")
	var flat: AudioStreamPlayer = Sfx.play_flat(root, "ui_tick")
	assert_not_null(flat)
	root.queue_free()
	await tree.process_frame
