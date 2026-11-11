extends TestCase
## 關卡的循環環境音（D-180）：整段循環、不改到共用的音檔、走 SFX 匯流排、缺檔安靜跳過。


func test_looped_copy_does_not_touch_shared_stream() -> void:
	for n: String in ["frost_wind", "title_theme", "part_end_theme"]:
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


## 腳步聲（D-182）：每走一個步幅踏一步、跑步步幅比較大、閃避與騰空不算；聲音照關卡的地面，沒有就當石頭。
func test_footsteps_follow_distance_and_surface() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(player)
	player.set_physics_process(false)
	var steps: int = 0
	for i: int in 100:  # 走 10 公尺
		if player.footstep_tick(0.1, false, true):
			steps += 1
	assert_eq(steps, int(10.0 / PlayerController.STRIDE), "走 10 m 踏 %d 步" % int(10.0 / PlayerController.STRIDE))
	assert_eq(player.step_count, steps)
	assert_eq(player.last_step_surface, "stone", "關卡沒說地面是什麼 → 石頭")
	var run_steps: int = 0
	for i: int in 100:
		if player.footstep_tick(0.1, true, true):
			run_steps += 1
	assert_true(run_steps < steps, "跑步的步幅比較大（%d < %d）" % [run_steps, steps])
	var air: int = 0
	for i: int in 100:
		if player.footstep_tick(0.1, false, false):
			air += 1
	assert_eq(air, 0, "騰空、閃避時不踏步")
	assert_false(player.footstep_tick(0.0, false, true), "站著不動不踏步")
	for surface: String in PlayerController.STEP_SURFACES:
		assert_not_null(Sfx.stream("step_" + surface), "有 step_%s" % surface)
	root.queue_free()
	await tree.process_frame


## 席菈的腳步聲（D-184）：同一套 Footsteps，步子短一點、小聲一點；真的走動才踏步（撞牆原地踏不算）。
func test_sheila_footsteps_when_she_moves() -> void:
	assert_true(Sheila.STEP_DB < PlayerController.STEP_DB, "席菈比諾恩小聲")
	assert_true(Sheila.STRIDE < PlayerController.STRIDE, "步子短一點")
	var root := Node3D.new()
	tree.root.add_child(root)
	var floor_body := CSGBox3D.new()
	floor_body.size = Vector3(60, 1, 60)
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.use_collision = true
	root.add_child(floor_body)
	var leader := Node3D.new()
	root.add_child(leader)
	leader.position = Vector3(0, 0, -12)
	var sheila := Sheila.new()
	sheila.position = Vector3(0, 0.05, 0)
	root.add_child(sheila)
	sheila.leader = leader
	for i: int in 60:
		await tree.physics_frame
	var walked: float = sheila.global_position.distance_to(Vector3(0, 0.05, 0))
	assert_true(walked > 2.0, "她跟上去了（%.1f m）" % walked)
	assert_true(sheila.footsteps.count >= 2, "一路有腳步聲（%d 步、%.1f m）" % [sheila.footsteps.count, walked])
	assert_eq(sheila.footsteps.last_surface, "stone", "關卡沒說 → 石頭")
	root.queue_free()
	await tree.process_frame


## 敵人的腳步聲（D-187）：灰巡者照地面、音高壓低、比諾恩小聲；送葬者固定用很重的拖步，步幅大、遠遠就聽得到。
## 都是 move_and_slide 之後的實際距離（站著出招不踏步）。
func test_enemy_footsteps() -> void:
	assert_true(Ashwalker.STEP_DB < PlayerController.STEP_DB, "灰巡者比諾恩小聲")
	assert_true(Ashwalker.STEP_PITCH < 1.0, "灰巡者音高壓低")
	assert_true(Undertaker.STRIDE > PlayerController.SPRINT_STRIDE, "送葬者步幅比諾恩跑步還大")
	assert_true(Undertaker.STEP_DB > PlayerController.SPRINT_STEP_DB, "送葬者走路比諾恩跑步還響")
	assert_true(Sfx.NAMES.has(Undertaker.STEP_SOUND), "拖步登記在 Sfx.NAMES")
	assert_not_null(Sfx.stream(Undertaker.STEP_SOUND), "拖步的音檔在")
	var root := Node3D.new()
	tree.root.add_child(root)
	var floor_body := CSGBox3D.new()
	floor_body.size = Vector3(80, 1, 80)
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.use_collision = true
	root.add_child(floor_body)
	var hb := Node3D.new()
	hb.add_to_group("heartbeat")
	hb.position = Vector3(0, 0, -13)
	root.add_child(hb)
	var a := Ashwalker.new()
	a.position = Vector3(-2.0, 0.05, 0)
	root.add_child(a)
	var u := Undertaker.new()
	u.state = GameState.new()
	u.position = Vector3(2.0, 0.05, 0)
	root.add_child(u)
	for i: int in 90:
		await tree.physics_frame
	var a_walked: float = Vector2(a.global_position.x + 2.0, a.global_position.z).length()
	var u_walked: float = Vector2(u.global_position.x - 2.0, u.global_position.z).length()
	assert_true(a_walked > 2.0 and u_walked > 2.0, "兩隻都追上去了（%.1f m、%.1f m）" % [a_walked, u_walked])
	assert_true(a.footsteps.count >= 2, "灰巡者一路有腳步聲（%d 步）" % a.footsteps.count)
	assert_eq(a.footsteps.last_sound, "step_stone", "灰巡者照地面（關卡沒說 → 石頭）")
	assert_true(u.footsteps.count >= 1, "送葬者有腳步聲（%d 步）" % u.footsteps.count)
	assert_true(u.footsteps.count < a.footsteps.count, "送葬者步子大、步數少")
	assert_eq(u.footsteps.last_sound, Undertaker.STEP_SOUND, "送葬者固定用拖步")
	# 聲音掛在關卡（父節點）上：牠之後被停掉（掙脫戰撞回運河）或倒下被釋放，正在播的那一步照樣播完
	var steps_now: int = u.footsteps.count
	for i: int in 60:
		if u.footsteps.count > steps_now:
			break
		await tree.physics_frame
	var heavy_on_level: int = 0
	for c: Node in root.get_children():
		if c is AudioStreamPlayer3D and (c as AudioStreamPlayer3D).stream == Sfx.stream(Undertaker.STEP_SOUND):
			heavy_on_level += 1
	assert_true(heavy_on_level >= 1, "拖步掛在關卡上（%d 個）" % heavy_on_level)
	for actor: Node in [a, u]:
		for c: Node in actor.get_children():
			if c is AudioStreamPlayer3D:
				var st: AudioStream = (c as AudioStreamPlayer3D).stream
				assert_true(st != Sfx.stream("step_stone") and st != Sfx.stream(Undertaker.STEP_SOUND),
						"%s 身上沒有掛腳步聲（%s）" % [actor.get_class(), st.resource_path if st != null else "null"])
	# 走到面前停下來出招：不再踏步
	a.position = hb.position + Vector3(0, 0.05, 1.0)
	await tree.physics_frame
	var standing: int = a.footsteps.count
	for i: int in 20:
		await tree.physics_frame
	assert_eq(a.footsteps.count, standing, "站著出招不踏步")
	root.queue_free()
	await tree.process_frame
	await tree.process_frame


## 乾運河裡送葬者的步態是關卡演的（D-187）：stomp() 不看距離直接踏一步，聲音掛在指定的節點（牠自己停著）。
func test_stomp_plays_on_given_parent() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var owner := Node3D.new()
	owner.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(owner)
	var f := Footsteps.new(1.3, 2.2, -7.0, -3.0)
	f.sound = Undertaker.STEP_SOUND
	f.pitch_base = 0.5
	f.stomp(owner, false, root)
	assert_eq(f.count, 1)
	assert_eq(f.last_sound, Undertaker.STEP_SOUND)
	var players: Array[AudioStreamPlayer3D] = []
	for c: Node in root.get_children():
		if c is AudioStreamPlayer3D:
			players.append(c as AudioStreamPlayer3D)
	assert_eq(players.size(), 1, "聲音掛在關卡上，不掛在停著的牠身上")
	if players.size() == 1:
		assert_true(players[0].pitch_scale < 0.6, "基準音高有套上（%.2f）" % players[0].pitch_scale)
		assert_true(players[0].playing, "有在播")
	assert_eq(owner.get_child_count(), 0)
	root.queue_free()
	await tree.process_frame
	await tree.process_frame


## 跪地的重音（D-191）：灰巡者是地面腳步聲壓低＋輕悶響，送葬者是更重的拖步＋鐵架的鐵響；
## 掛在關卡上、跪著再被逼跪不重播、致命的一擊不算（接著是倒下的聲音）；雪粉噴完就釋放。
func test_enemy_kneel_thud() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var a := Ashwalker.new()
	a.position = Vector3(-2.0, 0.05, 0)
	root.add_child(a)
	a.set_physics_process(false)
	var u := Undertaker.new()
	u.state = GameState.new()
	u.position = Vector3(3.0, 0.05, 0)
	root.add_child(u)
	u.set_physics_process(false)
	await tree.physics_frame
	assert_true(a.brain.add_stagger(9999.0), "灰巡者失衡滿了跪下")
	assert_eq(a.kneel_count, 1, "灰巡者跪下有聲音")
	assert_eq(a.last_kneel_sounds, PackedStringArray(["step_stone", "blunt"]), "照地面（關卡沒說 → 石頭）＋悶響")
	var low_step: int = 0
	for c: Node in root.get_children():
		if c is AudioStreamPlayer3D and (c as AudioStreamPlayer3D).stream == Sfx.stream("step_stone"):
			low_step += 1 if (c as AudioStreamPlayer3D).pitch_scale < 0.75 else 0
	assert_eq(low_step, 1, "膝蓋落地掛在關卡上、音高壓低")
	assert_not_null(a.get_node_or_null("KneelPuff"), "一小團雪粉")
	a.brain.force_kneel(1.0)
	assert_eq(a.kneel_count, 1, "跪著再被逼跪不重播")
	u.brain.force_kneel(1.2)
	assert_eq(u.kneel_count, 1, "送葬者撞牆跪下有聲音")
	assert_eq(u.last_kneel_sounds, PackedStringArray([Undertaker.STEP_SOUND, "iron_clang"]), "更重的拖步＋鐵架晃一下")
	var heavy: AudioStreamPlayer3D = null
	for c: Node in root.get_children():
		if c is AudioStreamPlayer3D and (c as AudioStreamPlayer3D).stream == Sfx.stream(Undertaker.STEP_SOUND):
			heavy = c as AudioStreamPlayer3D
	assert_not_null(heavy, "送葬者的跪地掛在關卡上")
	if heavy != null:
		assert_true(heavy.volume_db > Undertaker.STEP_DB, "比走路的拖步響")
		assert_true(heavy.pitch_scale < 0.85, "比走路的拖步低（%.2f）" % heavy.pitch_scale)
	# 致命的一擊：接著就倒下，不另外播跪地
	var b := Ashwalker.new()
	b.position = Vector3(0.0, 0.05, 3.0)
	root.add_child(b)
	b.set_physics_process(false)
	b.health.apply_damage(b.health.max_hp + 1.0, {"stagger": 9999.0})
	assert_eq(b.kneel_count, 0, "致命的一擊不算跪地")
	# 雪粉噴完就釋放（可能跪很多次，不能一直留在身上）
	for i: int in 180:
		if a.get_node_or_null("KneelPuff") == null:
			break
		await tree.physics_frame
	assert_true(a.get_node_or_null("KneelPuff") == null, "雪粉噴完就釋放")
	root.queue_free()
	await tree.process_frame
	await tree.process_frame
