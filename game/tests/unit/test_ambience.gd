extends TestCase
## 關卡的循環環境音（D-180）：整段循環、不改到共用的音檔、走 SFX 匯流排、缺檔安靜跳過。


func test_looped_copy_does_not_touch_shared_stream() -> void:
	for n: String in ["frost_wind", "frost_wind_indoor", "hearth_crackle", "daylight_ambience", "canal_ambience"]:
		var s: AudioStreamWAV = Ambience.looped(n)
		assert_not_null(s, "有 %s" % n)
		if s == null:
			continue
		assert_eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s 會循環" % n)
		assert_eq(s.loop_begin, 0, "%s 從頭循環" % n)
		assert_eq(s.loop_end, int(s.get_length() * float(s.mix_rate)), "%s 循環到最後" % n)
		assert_true(s.get_length() >= 6.0, "%s 夠長（短的循環一下就聽得出來）" % n)
		var shared: AudioStreamWAV = Sfx.stream(n) as AudioStreamWAV
		assert_eq(shared.loop_mode, AudioStreamWAV.LOOP_DISABLED, "%s 共用的那份不循環（一次性的播放不受影響）" % n)
	assert_eq(Ambience.looped("no_such_sound"), null, "缺檔回傳 null")


func test_play_flat_and_positional() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var flat: AudioStreamPlayer = Ambience.play(root, "frost_wind", -13.0)
	assert_not_null(flat)
	if flat != null:
		assert_eq(str(flat.name), "Ambience")
		assert_eq(flat.bus, &"SFX", "跟著「音效」音量")
		assert_eq(flat.volume_db, -13.0)
		assert_eq(Ambience.sfx_of(flat), "frost_wind")
		assert_true(flat.playing, "一放進場景就開始播")
	var fire: AudioStreamPlayer3D = Ambience.play_at(root, "hearth_crackle", Vector3(1, 0.4, -2), -6.0, 3.0, "HearthCrackle")
	assert_not_null(fire)
	if fire != null:
		assert_eq(fire.bus, &"SFX")
		assert_eq(fire.global_position, Vector3(1, 0.4, -2), "從壁爐的位置發出來")
		assert_eq(fire.unit_size, 3.0)
		assert_eq(Ambience.sfx_of(fire), "hearth_crackle")
	assert_eq(Ambience.play(root, "no_such_sound", 0.0), null, "缺檔不建播放器")
	assert_eq(Ambience.sfx_of(null), "")
	assert_eq(Ambience.sfx_of(root), "", "不是 Ambience 建的節點")
	for p: Node in [flat, fire]:
		if p != null:
			p.call("stop")
	root.queue_free()
	await tree.process_frame
