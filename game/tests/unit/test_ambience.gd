extends TestCase
## 關卡的循環環境音：整段循環、不改到共用的音檔、走 SFX 匯流排、缺檔安靜跳過。


func test_looped_copy_does_not_touch_shared_stream() -> void:
	for n: String in ["frost_wind", "market_murmur", "title_theme", "part_end_theme"]:
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
	var fire: AudioStreamPlayer3D = Ambience.play_at(root, "frost_wind", Vector3(1, 0.4, -2), -6.0, 3.0, "WindGap")
	assert_not_null(fire)
	if fire != null:
		assert_eq(fire.bus, &"SFX")
		assert_eq(fire.global_position, Vector3(1, 0.4, -2), "從指定的位置發出來")
		assert_eq(fire.unit_size, 3.0)
		assert_eq(Ambience.sfx_of(fire), "frost_wind")
	assert_eq(Ambience.play(root, "no_such_sound", 0.0), null, "缺檔不建播放器")
	assert_eq(Ambience.sfx_of(null), "")
	assert_eq(Ambience.sfx_of(root), "", "不是 Ambience 建的節點")
	for p: Node in [flat, fire]:
		if p != null:
			p.call("stop")
	root.queue_free()
	await tree.process_frame


func test_title_music_on_music_bus_fades_in() -> void:
	var boot: Control = (load("res://scenes/boot/boot.tscn") as PackedScene).instantiate() as Control
	tree.root.add_child(boot)
	await tree.process_frame
	var p: AudioStreamPlayer = boot.get_node_or_null("TitleMusic") as AudioStreamPlayer
	assert_not_null(p, "標題畫面有配樂")
	if p != null:
		assert_eq(Ambience.sfx_of(p), "title_theme")
		assert_eq(p.bus, &"Music", "走 Music 匯流排：設定頁的「音樂」音量管得到")
		assert_true(p.playing, "一進標題就開始播")
		assert_eq((p.stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD, "會循環")
		assert_true(p.volume_db < float(boot.get("MUSIC_DB")) - 10.0, "剛開始是淡入（還很小聲）")
		assert_true((p.stream as AudioStreamWAV).get_length() >= 20.0, "循環夠長，不會一下就聽出重複")
		p.stop()
	boot.queue_free()
	await tree.process_frame


func test_music_helper() -> void:
	var root := Node.new()
	tree.root.add_child(root)
	var p: AudioStreamPlayer = Ambience.music(root, "title_theme", -4.0, 0.0, "Music")
	assert_not_null(p)
	if p != null:
		assert_eq(p.bus, &"Music")
		assert_eq(p.volume_db, -4.0, "不淡入就直接是目標音量")
		p.stop()
	assert_eq(Ambience.music(root, "no_such_sound", 0.0, 1.0, "Music2"), null, "缺檔安靜跳過")
	root.queue_free()
	await tree.process_frame


## 腳步聲：人偶的腳落地才踏一步（聲音跟畫面上的腳對得上）、跑得快步子比較密、站著不踏、騰空與閃避不出聲；
## 聲音照關卡的地面，沒有就當石頭。
func test_footsteps_follow_the_puppets_feet_and_surface() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(player)
	player.set_physics_process(false)
	var puppet: Puppet = player.puppet()
	puppet.set_process(false)
	var falls: Array[int] = [0]
	puppet.footfall.connect(func() -> void: falls[0] += 1)
	var jog: int = _count_footfalls(puppet, PlayerController.WALK_SPEED, falls)
	assert_true(jog >= 6 and jog <= 10, "小跑 3 秒踏 6～10 步（每秒兩三步），踏了 %d 步" % jog)
	assert_eq(player.step_count, 0, "人不在地上（這裡沒有地板）：腳落地也不出聲")
	var sprint: int = _count_footfalls(puppet, PlayerController.SPRINT_SPEED, falls)
	assert_true(sprint > jog, "跑得快步子比較密（%d > %d）" % [sprint, jog])
	assert_eq(_count_footfalls(puppet, 0.0, falls), 0, "站著不動不踏步")
	assert_true(player.footfall(true), "在地上：腳落地就踏一步")
	assert_eq(player.step_count, 1)
	assert_eq(player.last_step_surface, "stone", "關卡沒說地面是什麼 → 石頭")
	assert_false(player.footfall(false), "騰空、閃避、被推開時不踏步")
	assert_eq(player.step_count, 1)
	for surface: String in PlayerController.STEP_SURFACES:
		assert_not_null(Sfx.stream("step_" + surface), "有 step_%s" % surface)
	root.queue_free()
	await tree.process_frame


## 用這個速度走 3 秒，回傳腳落地幾次。用模型時動作是 AnimationPlayer 在播：這裡自己推進它。
func _count_footfalls(puppet: Puppet, speed: float, falls: Array[int]) -> int:
	puppet.set_move_speed(speed)
	puppet.advance(0.0)
	falls[0] = 0
	for i: int in 180:
		if puppet.anim != null:
			puppet.anim.advance(1.0 / 60.0)
		puppet.advance(1.0 / 60.0)
	return falls[0]
