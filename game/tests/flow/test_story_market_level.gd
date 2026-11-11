extends TestCase
## 地下市場（第二段 A，docs/design/10-reboot-underground-market.md）：貨梯下來的高台 → 坡道 → 攤販街 → 藥店門口。
## 這一輪做到「走到藥店門口 → 待續」：三個檢查點的位置、席菈的規矩只講一次、待續卡與配樂、讀檔回到檢查點、
## 檢查點只寫在劇情的存檔資料夾；場景本身（高台、坡道、攤子、燈、綠窗）有蓋出來、彩色的燈只有三處。

const PATH: String = "res://scenes/levels/underground_market.tscn"

var _dir: String = ""
var _original: GameSession


func before_each() -> void:
	_dir = "user://test_rb2_market_%d" % Time.get_ticks_usec()
	_original = tree.root.get_node("Game").get("session") as GameSession


func after_each() -> void:
	tree.paused = false
	tree.root.get_node("Game").set("session", _original)
	for d: String in [_dir, _dir + "_reboot"]:
		if DirAccess.dir_exists_absolute(d):
			for f: String in DirAccess.get_files_at(d):
				DirAccess.remove_absolute(d.path_join(f))
			DirAccess.remove_absolute(d)


func _session_at(at: String) -> GameSession:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", s)
	s.new_game()
	UndergroundMarketStory.dev_advance(s, at)
	return s


func _load() -> UndergroundMarket:
	var level: UndergroundMarket = (load(PATH) as PackedScene).instantiate() as UndergroundMarket
	tree.root.add_child(level)
	await tree.physics_frame
	await tree.process_frame
	var sheila: Node3D = level.get_node_or_null("Sheila") as Node3D
	if sheila != null:
		sheila.set_physics_process(false)
	return level


func _game() -> Node:
	return tree.root.get_node("Game")


func _run_dialogue(level: Node) -> void:
	var box: DialogueBox = level.get_node("DialogueBox") as DialogueBox
	for i: int in 80:
		if not bool(_game().call("is_in_dialogue")):
			break
		box.press_continue()
		await tree.process_frame


func _frames(n: int) -> void:
	for i: int in n:
		await tree.physics_frame


func _stand(level: StoryLevel, at: Vector3) -> void:
	var player: PlayerController = level.get_node("Player") as PlayerController
	player.global_position = Vector3(at.x, level.ground_y(at) + 0.05, at.z)
	player.velocity = Vector3.ZERO


func test_market_is_built_terrace_ramp_street_and_green_shop() -> void:
	# 沒有開新遊戲的 session：只有空的市場（不掛劇情）
	var s := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", s)
	var level: UndergroundMarket = await _load()
	assert_true(level.story == null, "沒有劇情的 session 不掛控制器")
	assert_false(level.has_node("Sheila"))
	# 地面：高台 → 坡道一路往下 → 街面
	assert_eq(level.ground_y(Vector3(0.0, 0.0, -5.0)), UndergroundMarket.TERRACE_Y)
	var mid: float = level.ground_y(Vector3(0.0, 0.0, (UndergroundMarket.TERRACE_S + UndergroundMarket.RAMP_S) * 0.5))
	assert_true(absf(mid - UndergroundMarket.TERRACE_Y * 0.5) < 0.01, "坡道中間是一半高（%.2f）" % mid)
	assert_eq(level.ground_y(Vector3(0.0, 0.0, 20.0)), 0.0)
	assert_eq(level.ground_y(Vector3(3.5, 0.0, 3.0)), 0.0, "坡道兩旁是街面的高度")
	assert_eq(level.footstep_surface(Vector3(0.0, 0.0, 3.0)), "wood", "坡道是木板")
	assert_eq(level.footstep_surface(Vector3(0.0, 0.0, 20.0)), "stone")
	# 諾恩站得住：高台上不會掉下去
	var player: PlayerController = level.get_node("Player") as PlayerController
	await _frames(20)
	assert_true(absf(player.global_position.y - UndergroundMarket.TERRACE_Y) < 0.2, "站在高台上（%s）" % player.global_position)
	# 走下坡道：腳一路踩在坡面上，不會穿過去也不會卡住
	_stand(level, Vector3(0.0, 0.0, 3.5))
	await _frames(20)
	var want: float = level.ground_y(Vector3(0.0, 0.0, 3.5))
	assert_true(absf(player.global_position.y - want) < 0.25, "站在坡道上（y %.2f，坡面 %.2f）" % [player.global_position.y, want])
	# 攤子、布棚、燈
	assert_eq(level.stall_count, 14, "兩側各八格、各空一格")
	assert_eq(level.awning_count, level.stall_count, "每個攤子一頂布棚")
	assert_eq(level.vendors.size(), 6, "六個顧攤的人")
	for v: Puppet in level.vendors:
		assert_true(v.hand("R").get_node_or_null("BellHammer") == null, "不拿敲鐘的槌子")
	assert_true(level.paper_lantern_count >= 18, "繩上的紙燈籠（%d）" % level.paper_lantern_count)
	var swarm: MultiMeshInstance3D = level.get_node_or_null("PaperLanterns") as MultiMeshInstance3D
	assert_not_null(swarm, "紙燈籠是一個 MultiMesh")
	assert_eq(swarm.multimesh.instance_count, level.paper_lantern_count)
	assert_true(level.shadow_light_count <= 4, "投影的大燈最多四盞（%d）" % level.shadow_light_count)
	# 彩色的光只有三處：街底的綠、詛咒物攤的紫、鐵匠的橘紅；其他都是暖色
	var coloured: Dictionary = {}
	for c: Node in level.get_children():
		var l: OmniLight3D = c as OmniLight3D
		if l == null:
			continue
		var col: Color = l.light_color
		if col.r < 0.9 or col.g < 0.4:
			coloured[col.to_html(false)] = true
	assert_eq(coloured.size(), 3, "彩色的燈只有三種（%s）" % str(coloured.keys()))
	assert_not_null(level.shop_light, "藥店窗前的綠光")
	assert_true(level.shop_light.light_color.g > level.shop_light.light_color.r, "是綠的")
	assert_true(level.shop_light.position.z > UndergroundMarket.SHOP_Z - 3.0, "在街底")
	# D-229：綠光只照亮窗前幾步（遠看的綠靠窗的發光與霧），站在門口畫面不會整個被染綠
	assert_true(level.shop_light.light_energy <= 3.0 and level.shop_light.omni_range <= 9.0, "綠光不照亮半條街（%.1f／%.1f m）" % [level.shop_light.light_energy, level.shop_light.omni_range])
	# D-229：岩壁是不規則的岩面（不是砌的石塊牆）；布棚上面有幾盞掛燈照出岩面，高台門架旁有一盞燈
	var rock_found: bool = false
	for mi: Node in level.get_node("Market").find_children("*", "MeshInstance3D", true, false):
		var m: ShaderMaterial = (mi as MeshInstance3D).material_override as ShaderMaterial
		if m != null and m.shader != null and m.shader.resource_path.ends_with("cave_rock.gdshader"):
			rock_found = true
	assert_true(rock_found, "合併的場景裡有岩面材質")
	var wall_lamps: int = 0
	for c: Node in level.get_children():
		var wl: OmniLight3D = c as OmniLight3D
		if wl == null or not String(wl.name).begins_with("WallLamp"):
			continue
		wall_lamps += 1
		assert_true(wl.position.y > UndergroundMarket.AWNING_BACK_Y.y + 0.8, "掛燈在布棚上面（%.1f m）" % wl.position.y)
		assert_true(absf(wl.position.x) > UndergroundMarket.WALL_X - 1.0, "貼著岩壁")
		assert_false(wl.shadow_enabled, "不投影")
	assert_eq(wall_lamps, UndergroundMarket.WALL_LAMPS.size(), "岩壁上的掛燈")
	assert_not_null(level.get_node_or_null("GatePostLamp"), "高台門架旁的燈")
	# D-230：高台的西半邊不是空的——欄杆前兩個看街的人（背對貨梯、面向街）、靠牆的行李上一盞提燈、西牆靠高台那一段有掛燈
	assert_eq(level.watchers.size(), UndergroundMarket.WATCHERS.size(), "高台上看街的人")
	for w: Puppet in level.watchers:
		assert_true(w.position.x < -UndergroundMarket.RAMP_HALF - 1.0, "站在西半邊，不擋坡道口（x %.1f）" % w.position.x)
		assert_true(w.position.z < UndergroundMarket.TERRACE_S - 0.3 and w.position.z > UndergroundMarket.TERRACE_S - 1.5, "站在欄杆後面（z %.1f）" % w.position.z)
		assert_true(absf(w.position.y - UndergroundMarket.TERRACE_Y) < 0.01, "腳踩在高台上")
		assert_true(-w.global_transform.basis.z.z > 0.5, "面向街（南）")
		assert_true(w.hand("R").get_node_or_null("BellHammer") == null, "不拿敲鐘的槌子")
	var rest_lamp: OmniLight3D = level.get_node_or_null("TerraceRestLamp") as OmniLight3D
	assert_not_null(rest_lamp, "行李上的提燈")
	assert_true(rest_lamp.position.x < -3.0 and rest_lamp.position.z < UndergroundMarket.TERRACE_S, "在高台的西半邊")
	assert_false(rest_lamp.shadow_enabled, "不投影")
	var west_near: int = 0
	for spec: Vector3 in UndergroundMarket.WALL_LAMPS:
		if spec.x < 0.0 and spec.y < 4.0:
			west_near += 1
	assert_true(west_near >= 1, "西牆靠高台的那一段有掛燈（從高台看的畫面右邊）")
	# D-230：藥店的門面幾乎整片是綠色的玻璃（以前 4×3 格約 7.3 平方公尺，從高台看是一個小方塊）
	assert_true(level.shop_glass_area >= 16.0, "綠窗至少是以前的兩倍大（%.1f 平方公尺）" % level.shop_glass_area)
	# 藥店前面兩條繩子上的紙燈籠是綠的（其他的照舊是暖色）；綠色不是用燈打的，所以彩色的燈還是只有三種（上面驗過）
	assert_true(level.shop_paper_count >= 6 and level.shop_paper_count <= 10, "藥店前面的綠燈籠（%d）" % level.shop_paper_count)
	assert_true(level.shop_paper_count < level.paper_lantern_count / 2, "大部分的紙燈籠還是暖色")
	# （headless 讀不回 MultiMesh 每一盞的顏色，所以驗「編號 → 顏色」這一步）
	var shop_paper: Color = UndergroundMarket.paper_color(-1.0)
	assert_true(shop_paper.g > shop_paper.r and shop_paper.g > shop_paper.b, "藥店前面的是綠的")
	for i: int in UndergroundMarket.PAPER_COLORS.size():
		var warm: Color = UndergroundMarket.paper_color(float(i))
		assert_true(warm.r > warm.g and warm.g > warm.b, "其他的是暖色（%d）" % i)
	# D-230：市場有自己的底噪（遠處的人聲），不是霜橋鎮的風
	var murmur: AudioStreamPlayer = level.get_node_or_null("Ambience") as AudioStreamPlayer
	assert_not_null(murmur, "市場的底噪")
	if murmur != null:
		assert_eq(Ambience.sfx_of(murmur), "market_murmur")
		assert_eq(murmur.bus, &"SFX", "跟著音效音量走")
		assert_true(murmur.volume_db <= -12.0 and murmur.volume_db >= -24.0, "聽得到、不蓋過對話（%.0f dB）" % murmur.volume_db)
	# 高台上卸下來的貨不擋路：從貨梯走到坡道口是直的
	_stand(level, Vector3(0.0, 0.0, -6.0))
	player.yaw = PI
	await _frames(10)
	var from_z: float = player.global_position.z
	Input.action_press("move_forward")
	await _frames(90)
	Input.action_release("move_forward")
	await _frames(5)
	assert_true(player.global_position.z > from_z + 2.0, "從貨梯往坡道口走得過去（z %.1f → %.1f）" % [from_z, player.global_position.z])
	# 任務標記的兩個點
	assert_not_null(level.get_node_or_null("MarketStreetTop"))
	var door: Node3D = level.get_node_or_null("MishaShopDoor") as Node3D
	assert_not_null(door)
	assert_true(FrostbridgeOpening.flat_distance(door.global_position, UndergroundMarket.SHOP_DOOR) < 0.1)
	# 粒子都有圓形貼圖（D-056）；蒸氣是常駐的
	assert_eq(ParticleLook.untextured(level), [] as Array[String])
	level.queue_free()
	await tree.process_frame


func test_awning_sags_and_hangs_a_scalloped_edge() -> void:
	var back: Vector3 = UndergroundMarket.awning_point(1.6, 2.6, 3.2, 2.3, 0.25, 0.5, 0.0)
	var mid: Vector3 = UndergroundMarket.awning_point(1.6, 2.6, 3.2, 2.3, 0.25, 0.5, 0.5)
	var front: Vector3 = UndergroundMarket.awning_point(1.6, 2.6, 3.2, 2.3, 0.25, 0.5, 1.0)
	assert_true(back.y > front.y, "靠牆高、臨街低")
	assert_true(mid.y < (back.y + front.y) * 0.5 - 0.15, "中間往下垂（%.2f）" % mid.y)
	var corner: Vector3 = UndergroundMarket.awning_point(1.6, 2.6, 3.2, 2.3, 0.25, 0.0, 0.0)
	assert_true(absf(corner.y - 3.2) < 0.001, "四個角綁在竿子上，不垂")
	var mesh: ArrayMesh = UndergroundMarket.awning_mesh(1.6, 2.6, 3.2, 2.3, 0.25)
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var lowest: float = INF
	for v: Vector3 in verts:
		lowest = minf(lowest, v.y)
	assert_true(lowest < 2.3 - 0.25, "前緣有一條垂下來的波浪邊（最低 %.2f）" % lowest)
	assert_true((mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV) != 0, "有 UV（條紋）")


## D-229：布棚在頭頂上、不伸到街上——過肩鏡頭（支點 1.6 m、鏡頭約 2 m 高）走在街上不會被一片布擋住。
func test_awnings_stay_above_the_camera_and_off_the_street() -> void:
	assert_true(UndergroundMarket.AWNING_FRONT_OUT.x >= 0.0, "前緣不伸到街上")
	assert_true(UndergroundMarket.AWNING_FRONT_OUT.y <= 0.3, "前緣還蓋得到攤桌外緣")
	assert_true(UndergroundMarket.AWNING_BACK_Y.x > UndergroundMarket.AWNING_FRONT_Y.y, "靠牆那邊一定比臨街高")
	# 最低的情況：前緣最低、垂最多（_stall 裡 sag 最大 0.3）
	var mesh: ArrayMesh = UndergroundMarket.awning_mesh(1.9, 2.3, UndergroundMarket.AWNING_BACK_Y.x, UndergroundMarket.AWNING_FRONT_Y.x, 0.3)
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var lowest: float = INF
	for v: Vector3 in verts:
		lowest = minf(lowest, v.y)
	assert_true(lowest > PlayerController.CAMERA_HEIGHT + 0.6, "垂邊最低的地方也在鏡頭上面（%.2f m）" % lowest)
	assert_true(UndergroundMarket.AWNING_FRONT_Y.x - UndergroundMarket.STALL_LAMP_DROP > PlayerController.CAMERA_HEIGHT + 0.4, "攤子的燈不掛在鏡頭的高度")


func test_arrive_street_shop_then_to_be_continued() -> void:
	var s := _session_at("arrive")
	assert_true(s.quests.is_done("rb_main"))
	assert_eq(s.quests.stage_of("rb_market"), "arrive")
	assert_eq(s.state.checkpoint, "rb2_arrive")
	assert_eq(s.main_quest(), "rb_market")
	assert_eq(s.objective_key(), "Q_RB2_OBJ_ARRIVE")
	assert_true(FileAccess.file_exists((_dir + "_reboot").path_join("auto.json")), "檢查點寫在劇情的存檔資料夾")
	assert_false(FileAccess.file_exists(_dir.path_join("auto.json")), "不寫到另一個資料夾")
	var level: UndergroundMarket = await _load()
	var story: UndergroundMarketStory = level.story
	assert_not_null(story)
	var player: PlayerController = level.get_node("Player") as PlayerController
	assert_true(absf(player.global_position.y - UndergroundMarket.TERRACE_Y) < 0.3, "從貨梯的高台開始")
	assert_not_null(level.get_node_or_null("Sheila"), "席菈跟著下來")
	var done: Array[int] = [0]
	story.end_done = func() -> void: done[0] += 1
	# 還在高台上：什麼都不會發生
	await _frames(6)
	assert_eq(story.stage(), "arrive")
	assert_false(bool(_game().call("is_in_dialogue")))
	# 走下坡道到街上：下一個檢查點、席菈說這裡的規矩
	_stand(level, Vector3(0.0, 0.0, UndergroundMarket.RAMP_S + 1.2))
	await _frames(6)
	assert_eq(story.stage(), "find_shop")
	assert_eq(s.state.checkpoint, "rb2_street")
	assert_eq(s.objective_key(), "Q_RB2_OBJ_FIND_SHOP")
	assert_true(bool(_game().call("is_in_dialogue")), "席菈開口")
	await _run_dialogue(level)
	assert_true(bool(s.state.get_flag("rb2.rules_heard", false)))
	await _frames(6)
	assert_false(bool(_game().call("is_in_dialogue")), "只講一次")
	assert_false(level.has_node("ChapterCard"))
	assert_false(level.has_node("RbEndMusic"), "配樂等卡出來才進")
	# 走到街底的藥店門口：檢查點、「待續」
	_stand(level, UndergroundMarket.SHOP_DOOR + Vector3(0.4, 0.0, -1.4))
	await _frames(6)
	assert_eq(story.stage(), "test_board")
	assert_eq(s.state.checkpoint, "rb2_shop")
	assert_eq(s.objective_key(), "Q_RB2_OBJ_TEST_BOARD")
	assert_true(story.ending)
	var card: ChapterCard = level.get_node_or_null("ChapterCard") as ChapterCard
	assert_not_null(card, "待續的卡")
	assert_eq(card.title_text(), tr("RB2_END_TITLE"))
	assert_eq(player.process_mode, Node.PROCESS_MODE_DISABLED, "黑幕底下諾恩停住")
	assert_eq(done[0], 0, "卡還沒播完")
	assert_eq(story.play_end_card(), card, "不會疊第二張")
	# 「待續」不是無聲的（D-219）：卡出來時配樂從無聲慢慢進來，走音樂匯流排、會循環，只有一個
	var music: AudioStreamPlayer = level.get_node_or_null("RbEndMusic") as AudioStreamPlayer
	assert_not_null(music, "待續的配樂")
	assert_eq(music, story.end_music)
	assert_eq(Ambience.sfx_of(music), UndergroundMarketStory.END_MUSIC)
	if music != null:
		assert_eq(music.bus, &"Music", "跟著「音樂」音量")
		assert_true(music.playing, "在播")
		assert_true(music.volume_db < UndergroundMarketStory.END_MUSIC_DB, "從小聲慢慢進來，不是突然響起")
		var stream: AudioStreamWAV = music.stream as AudioStreamWAV
		assert_true(stream != null and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "卡停多久都不會斷")
	var players: int = 0
	for c: Node in level.get_children():
		if str(c.name).begins_with("RbEndMusic"):
			players += 1
	assert_eq(players, 1, "按兩次也只有一個配樂")
	card.finish()
	assert_eq(done[0], 1, "播完（或跳過）→ 回標題")
	level.queue_free()
	await tree.process_frame


func test_reload_returns_to_each_checkpoint_without_repeating_or_regranting() -> void:
	var s := _session_at("arrive")
	var potions: int = int(s.state.items.get(PotionCrate.ITEM, 0))
	var coins: int = int(s.state.items.get(FrostbridgeOpening.WAGES_ITEM, 0))
	assert_eq(coins, FrostbridgeOpening.WAGES)
	var level: UndergroundMarket = await _load()
	_stand(level, Vector3(0.0, 0.0, UndergroundMarket.RAMP_S + 1.2))
	await _frames(6)
	await _run_dialogue(level)
	assert_eq(s.state.checkpoint, "rb2_street")
	level.queue_free()
	await tree.process_frame
	# 重開遊戲、讀檔：回到街口（不是高台），席菈那段話聽過了就不再講——話是在檢查點之後聽的，所以讀檔會再講一次、也只一次
	var again := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", again)
	assert_eq(again.load_story_slot(), SaveCodec.Status.OK)
	assert_eq(again.state.checkpoint, "rb2_street")
	assert_eq(str(_game().call("level_for_checkpoint", again.state.checkpoint)), "market")
	assert_eq(int(again.state.items.get(PotionCrate.ITEM, 0)), potions, "藥的數量照存檔")
	assert_eq(int(again.state.items.get(FrostbridgeOpening.WAGES_ITEM, 0)), coins, "工錢照存檔，不會多一份")
	var level2: UndergroundMarket = await _load()
	var p2: PlayerController = level2.get_node("Player") as PlayerController
	assert_true(p2.global_position.z > UndergroundMarket.RAMP_S and p2.global_position.y < 0.5, "回到街口（%s）" % p2.global_position)
	await _frames(6)
	await _run_dialogue(level2)
	await _frames(6)
	assert_false(bool(_game().call("is_in_dialogue")))
	assert_eq(again.quests.stage_of("rb_market"), "find_shop")
	level2.queue_free()
	await tree.process_frame
	# 到了藥店門口的存檔：回到門口前幾步，再走過去才是「待續」（不會一讀檔就黑掉）
	var s3 := _session_at("shop")
	assert_eq(s3.state.checkpoint, "rb2_shop")
	var level3: UndergroundMarket = await _load()
	var p3: PlayerController = level3.get_node("Player") as PlayerController
	assert_true(FrostbridgeOpening.flat_distance(p3.global_position, UndergroundMarket.SHOP_DOOR) > UndergroundMarketStory.SHOP_RANGE + 1.0,
			"出生點離門還有幾步（%s）" % p3.global_position)
	await _frames(6)
	assert_false(level3.has_node("ChapterCard"), "讀檔回來不會馬上黑掉")
	level3.story.end_done = func() -> void: pass
	_stand(level3, UndergroundMarket.SHOP_DOOR + Vector3(0.4, 0.0, -1.4))
	await _frames(6)
	assert_true(level3.has_node("ChapterCard"), "走到門口才是待續")
	level3.queue_free()
	await tree.process_frame


## 舊存檔的遷移：前十分鐘做完時還沒有地下市場這條任務（第 81 輪以前的存檔）——讀檔時補開，「繼續」直接到地下市場。
func test_old_save_that_finished_the_first_ten_minutes_continues_in_the_market() -> void:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", s)
	s.new_game()
	FrostbridgeOpening.dev_advance(s, "lift")
	s.set_flag("rb.market_reached", true)
	# 把存檔改回舊的樣子：沒有 rb_market、檢查點還是 rb_market（霜橋鎮）
	s.state.quests.erase("rb_market")
	s.state.checkpoint = "rb_market"
	assert_eq(s.save(GameSession.AUTO_SLOT), OK)
	var again := GameSession.new(QuestDB.load_default(), _dir)
	assert_eq(again.load_story_slot(), SaveCodec.Status.OK)
	assert_true(again.quests.is_done("rb_main"))
	assert_eq(again.quests.stage_of("rb_market"), "arrive", "補開地下市場的任務")
	assert_eq(again.state.checkpoint, "rb2_arrive")
	assert_eq(str(_game().call("level_for_checkpoint", again.state.checkpoint)), "market")
	assert_eq(int(again.state.items.get(FrostbridgeOpening.WAGES_ITEM, 0)), FrostbridgeOpening.WAGES, "工錢還在、沒有多一份")
	# 還沒做完前十分鐘的存檔不受影響
	var fresh := GameSession.new(QuestDB.load_default(), _dir + "_b")
	fresh.new_game()
	var reload := GameSession.new(QuestDB.load_default(), _dir + "_b")
	assert_eq(reload.load_story_slot(), SaveCodec.Status.OK)
	assert_false(reload.state.quests.has("rb_market"), "前十分鐘還沒做完：不會提早開")
	assert_eq(reload.main_quest(), "rb_main")
	for d: String in [_dir + "_b", _dir + "_b_reboot"]:
		if DirAccess.dir_exists_absolute(d):
			for f: String in DirAccess.get_files_at(d):
				DirAccess.remove_absolute(d.path_join(f))
			DirAccess.remove_absolute(d)
