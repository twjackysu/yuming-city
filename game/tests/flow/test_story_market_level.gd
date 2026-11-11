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
