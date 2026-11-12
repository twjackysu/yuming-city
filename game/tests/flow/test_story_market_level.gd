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
	# 走到街底的藥店門口：檢查點；門開著，還沒進去就不會有事
	_stand(level, UndergroundMarket.SHOP_DOOR + Vector3(0.4, 0.0, -1.4))
	await _frames(6)
	assert_eq(story.stage(), "test_board")
	assert_eq(s.state.checkpoint, "rb2_shop")
	assert_eq(s.objective_key(), "Q_RB2_OBJ_TEST_BOARD")
	assert_false(story.ending, "門口不再是結尾")
	assert_false(bool(_game().call("is_in_dialogue")))
	assert_false(story.board_ready())
	# 走進店裡到櫃台前：彌夏開口；生命是滿的，她多一句「先扎一針」
	var hp0: float = player.health.hp
	assert_true(hp0 >= player.health.max_hp - 0.5, "這個測試從滿的生命開始")
	_stand(level, UndergroundMarket.BOARD_POS + Vector3(-0.3, 0.0, -1.0))
	await _frames(4)
	assert_true(bool(_game().call("is_in_dialogue")), "彌夏開口")
	assert_eq(bool(s.state.get_flag("rb2.full_health", false)), true)
	await _run_dialogue(level)
	assert_true(bool(s.state.get_flag("rb2.misha_met", false)))
	await _frames(4)
	assert_true(absf(player.health.hp - (hp0 - UndergroundMarketStory.NEEDLE_PRICK)) < 0.01, "扎一針：直接傷害 3 點（%.1f → %.1f）" % [hp0, player.health.hp])
	assert_false(player.status_effects.has("poison"), "還沒碰板子")
	assert_true(story.board_ready(), "可以把手放上去了")
	var hint: Dictionary = story.interact_hint()
	assert_eq(str(hint.get("action", "")), "interact")
	assert_true(absf(float(hint.get("progress", -1.0))) < 0.001, "按住的進度條從 0 開始")
	# 按一下就放開：不算；指針回到中間
	Input.action_press("interact")
	await _frames(40)
	assert_true(story.board_hold > 0.5 and story.board_hold < 1.0, "按住在累計（%.2f）" % story.board_hold)
	assert_true(level.board_target_deg < -5.0, "按著的時候指針往「受傷」那邊偏（%.1f）" % level.board_target_deg)
	assert_true(float(story.interact_hint().get("progress", 0.0)) > 0.2, "進度條在長")
	Input.action_release("interact")
	await _frames(3)
	assert_eq(story.board_hold, 0.0, "放開就歸零")
	assert_false(player.status_effects.has("poison"))
	assert_false(bool(s.state.get_flag("rb2.board_done", false)))
	# 走開再按：也不算
	_stand(level, UndergroundMarket.BOARD_POS + Vector3(0.0, 0.0, -2.2))
	Input.action_press("interact")
	await _frames(30)
	assert_eq(story.board_hold, 0.0, "離太遠按沒有用")
	Input.action_release("interact")
	# 按滿 2 秒：板子下一個弱的中毒（1／秒、6 秒），反轉 → 回血；指針甩到「回復」、綠燈亮
	_stand(level, UndergroundMarket.BOARD_POS + Vector3(-0.3, 0.0, -1.0))
	Input.action_press("interact")
	await _frames(int(UndergroundMarketStory.BOARD_HOLD_SEC * 60.0) + 6)
	Input.action_release("interact")
	assert_true(bool(s.state.get_flag("rb2.board_done", false)), "按滿了")
	assert_true(player.status_effects.has("poison"), "板子下的毒")
	var effects: Array = player.status_effects.to_array()
	assert_eq(effects.size(), 1, "只有一個中毒")
	assert_eq(str((effects[0] as Dictionary).get("source", "")), UndergroundMarketStory.BOARD_SOURCE)
	assert_true(absf(float((effects[0] as Dictionary).get("rate", 0.0)) - 1.0) < 0.01, "很弱：每秒 1 點")
	assert_eq(player.status_effects.apply_source(UndergroundMarketStory.BOARD_SOURCE), "refresh", "同一個來源再來一次只是更新，不疊加")
	assert_eq(player.status_effects.to_array().size(), 1)
	assert_true(story.interact_hint().is_empty(), "測過了，提示收掉")
	assert_true(level.board_lamp_on, "綠燈亮")
	assert_eq(level.board_target_deg, UndergroundMarket.BOARD_HEAL_DEG, "指針往「回復」")
	await _frames(60)
	assert_true(level.board_needle_deg() > 30.0, "指針真的擺過去了（%.1f）" % level.board_needle_deg())
	assert_true(level.board_lamp_light.light_energy > 0.5, "燈真的亮了")
	assert_true(player.health.hp > hp0 - UndergroundMarketStory.NEEDLE_PRICK + 0.5, "生命往上（%.1f）" % player.health.hp)
	assert_true(player.health.hp <= player.health.max_hp, "不會超過上限")
	assert_false(level.has_node("ChapterCard"), "她還沒講完")
	# 讀數出來幾秒之後她才開口；談完 → 藥店這一段做完 → 接黑市示範場（任務 rb_demo，D-232），櫃台前不再是結尾
	await _frames(int(UndergroundMarketStory.BOARD_READ_SEC * 60.0))
	assert_true(bool(_game().call("is_in_dialogue")), "彌夏願意談了")
	await _run_dialogue(level)
	assert_true(bool(s.state.get_flag("rb2.first_shop_done", false)))
	assert_true(s.quests.is_done("rb_market"))
	assert_eq(bool(s.state.get_flag("rb2.market_a_done", false)), true)
	assert_eq(s.quests.stage_of("rb_demo"), "go_demo", "下一條任務自己開始")
	assert_eq(s.main_quest(), "rb_demo")
	assert_eq(s.state.checkpoint, "rb2_demo")
	assert_eq(s.objective_key(), "Q_RB2_OBJ_GO_DEMO")
	await _frames(6)
	assert_false(story.ending, "櫃台前不再是結尾")
	assert_false(level.has_node("ChapterCard"))
	# 席菈先到門外等：不會站在門洞裡把人堵在店裡
	var sheila: Node3D = level.get_node("Sheila") as Node3D
	assert_true(sheila.global_position.z < UndergroundMarket.SHOP_Z - 1.0, "席菈在門外（%s）" % sheila.global_position)
	assert_true(absf(sheila.global_position.x - UndergroundMarket.SHOP_DOOR.x) > 1.0, "不在門的正前面")
	# 隔著牆（人還在店裡）離示範台再近也不算；走出店門、還離得遠：沒有事
	assert_false(story.near_demo(Vector3(UndergroundMarket.DEMO_POS.x, 0.0, UndergroundMarket.SHOP_INNER_Z + 1.0)))
	_stand(level, UndergroundMarket.DEMO_POS + Vector3(3.5, 0.0, UndergroundMarketStory.DEMO_RANGE + 3.0))
	await _frames(6)
	assert_false(bool(_game().call("is_in_dialogue")), "離示範台還遠")
	# 走到示範台前：商人的叫賣（兩句）→ 諾恩看出他賣的是解藥 → 席菈「這個我會」→ 下一個階段（守衛戰，還沒做）
	_stand(level, UndergroundMarket.DEMO_POS + Vector3(3.0, 0.0, 2.0))
	await _frames(4)
	assert_true(bool(_game().call("is_in_dialogue")), "商人開始叫賣")
	assert_false(bool(s.state.get_flag("rb2.pitch_heard", false)), "還沒聽完")
	await _run_dialogue(level)
	assert_true(bool(s.state.get_flag("rb2.pitch_heard", false)))
	assert_eq(s.quests.stage_of("rb_demo"), "stop_demo")
	assert_eq(s.state.checkpoint, "rb2_demo_fight")
	assert_eq(s.objective_key(), "Q_RB2_OBJ_STOP_DEMO")
	assert_false(s.quests.is_done("rb_demo"), "守衛還沒打：這條任務沒做完")
	# 守衛戰（D-233）：聽完還站在台前 → 開打，不是「待續」。席菈喊一句、布景的兩個守衛換成真的敵人、看熱鬧的人退到街的北邊
	var crowd_z: float = UndergroundMarket.DEMO_Z + UndergroundMarket.DEMO_CROWD[0].z
	await _frames(4)
	assert_true(story.fight_started, "走近就開打")
	assert_false(story.ending, "不是待續")
	assert_false(level.has_node("ChapterCard"))
	assert_eq(story.guards.size(), 2, "兩個守衛")
	for dg: DemoGuard in story.guards:
		dg.set_physics_process(false)
		assert_eq(dg.health.hp, dg.health.max_hp, "滿血")
		assert_true(dg.is_in_group("enemies"))
		assert_true(dg.global_position.x > UndergroundMarket.DEMO_STAGE_FRONT_X and absf(dg.global_position.x) < UndergroundMarket.STREET_HALF, "在街上（%s）" % dg.global_position)
	assert_true(story.guards[0].is_bracer(), "台上那個戴護腕")
	assert_false(story.guards[1].is_bracer(), "台下那個拿棍子")
	assert_false(level.demo_guards[0].visible or level.demo_guards[1].visible, "布景的守衛收起來了（不會有四個）")
	assert_eq(level.demo_blocks[0].collision_layer, 0, "台下守衛原本的碰撞盒關掉")
	assert_eq((level.get_node("Sheila") as Sheila).line_text(), tr("RB2_SHEILA_DEMO_CALL"), "席菈：再示範一次")
	for i: int in level.demo_crowd.size():
		var block: StaticBody3D = level.demo_blocks[i + 1]
		assert_true(block.position.z < UndergroundMarket.DEMO_Z - 5.0, "看熱鬧的人的碰撞盒搬到北邊（%s）" % block.position)
		assert_true(absf(block.position.x) < UndergroundMarket.STREET_HALF, "還在街上")
	await _frames(int((UndergroundMarket.DEMO_FLEE_SEC + 1.0) * 60.0))
	for i: int in level.demo_crowd.size():
		var who: Puppet = level.demo_crowd[i]
		assert_true(who.position.distance_to(level.demo_blocks[i + 1].position) < 0.05, "人跑到碰撞盒那裡了")
		assert_eq(who.move_speed, 0.0, "停下來")
	assert_true(level.demo_crowd[0].position.z < crowd_z - 4.0, "離台子遠了")
	assert_true(level.demo_seller.position.x < UndergroundMarket.DEMO_STAGE_FRONT_X - 1.0, "商人縮到台子後面")
	assert_eq(story.guards.size(), 2, "開打只會開始一次")
	story.start_demo_fight()
	assert_eq(story.guards.size(), 2)
	# 只倒一個不算贏；兩個都倒才算
	story.guards[1].health.apply_damage(9999.0, {"source": player})
	await _frames(4)
	assert_false(bool(s.state.get_flag("rb2.demo_won", false)), "還有一個站著")
	assert_false(s.quests.is_done("rb_demo"))
	story.guards[0].health.apply_damage(9999.0, {"source": player})
	await _frames(4)
	assert_true(bool(s.state.get_flag("rb2.demo_won", false)), "兩個都倒下")
	assert_true(s.quests.is_done("rb_demo"), "這一段做完")
	assert_true(bool(s.state.get_flag("rb2.market_b_done", false)))
	assert_false(bool(_game().call("is_in_dialogue")), "隔一下商人才開口")
	assert_eq(s.state.grants.count(UndergroundMarketStory.BRACER_GRANT), 0, "還沒拿到護腕")
	await _frames(int(UndergroundMarketStory.WON_TALK_SEC * 60.0) + 12)
	assert_true(bool(_game().call("is_in_dialogue")), "商人認輸")
	await _run_dialogue(level)
	assert_true(bool(s.state.get_flag("rb2.bracer_taken", false)))
	await _frames(4)
	assert_eq(s.state.grants.count(UndergroundMarketStory.BRACER_GRANT), 1, "護腕拿到一個")
	# 試戴護腕（D-234）：拿到護腕不是結尾——任務 rb_bracer 開始，走回藥店
	assert_false(story.ending, "拿到護腕不是待續")
	assert_false(level.has_node("ChapterCard"))
	assert_eq(s.quests.stage_of("rb_bracer"), "back_to_shop")
	assert_eq(s.main_quest(), "rb_bracer")
	assert_eq(s.state.checkpoint, "rb2_bracer")
	assert_eq(tr(s.objective_key()), tr("Q_RB2_OBJ_BRACER_BACK"))
	assert_false(player.reversal.unlocked.has("paralysis"), "還沒試過：麻痺沒有解鎖")
	assert_eq(player.reversal.equipped[1], "", "第二格是空的")
	assert_true(player.puppet().joint("elbow_R").get_node_or_null("NoenBracer") == null, "護腕還沒戴上")
	# 走回櫃台前 → 彌夏：先在板子上試
	_stand(level, UndergroundMarket.BOARD_POS + Vector3(-0.3, 0.0, -1.0))
	await _frames(4)
	assert_true(bool(_game().call("is_in_dialogue")), "彌夏開口")
	await _run_dialogue(level)
	await _frames(2)
	assert_eq(s.quests.stage_of("rb_bracer"), "test_bracer")
	assert_eq(s.state.checkpoint, "rb2_bracer_board")
	assert_true(story.bracer_ready())
	assert_eq(str(story.interact_hint().get("action", "")), "interact", "按住互動的提示")
	assert_true(str(story.interact_hint().get("fmt", "")).contains(tr("RB2_BRACER_HINT").split("{key}")[1]), "是護腕的那一句")
	# 按一下就放：歸零、什麼都沒發生
	Input.action_press("interact")
	await _frames(40)
	assert_true(story.board_hold > 0.4, "按住在累計")
	Input.action_release("interact")
	await _frames(2)
	assert_eq(story.board_hold, 0.0, "放開就歸零")
	assert_false(player.status_effects.has("paralysis"))
	# 按滿 2 秒：麻痺解鎖、裝進第二格、從第一幀起就是反轉的（出手加速）；生命不會因為麻痺掉
	var hp_before: float = player.health.hp
	Input.action_press("interact")
	await _frames(int(UndergroundMarketStory.BOARD_HOLD_SEC * 60.0) + 6)
	Input.action_release("interact")
	assert_true(bool(s.state.get_flag("rb2.bracer_tested", false)), "按滿了")
	assert_true(player.reversal.unlocked.has("paralysis"), "麻痺解鎖")
	assert_eq(player.reversal.equipped[0], "poison", "第一格還是中毒")
	assert_eq(player.reversal.equipped[1], "paralysis", "麻痺裝進第二格")
	assert_true(player.status_effects.has("paralysis"))
	assert_true(player.status_effects.is_reversed("paralysis"))
	assert_eq(player.status_effects.source_of("paralysis"), UndergroundMarketStory.BRACER_SOURCE)
	assert_true(absf(player.status_effects.attack_speed() - 1.35) < 0.001, "出手 1.35 倍")
	assert_false(player.status_effects.blocks_attack(), "反轉了：不會擋出手")
	assert_true(player.health.hp >= hp_before - 0.001, "麻痺不扣血")
	assert_not_null(player.puppet().joint("elbow_R").get_node_or_null("NoenBracer"), "護腕戴在右前臂")
	assert_true(story.interact_hint().is_empty(), "試過了，提示收掉")
	assert_true(level.board_lamp_on, "板子的綠燈亮")
	var hud: Hud = level.get_node_or_null("Hud") as Hud
	var status_hud: StatusHud = hud.find_child("StatusHud", true, false) as StatusHud
	assert_not_null(status_hud)
	await _frames(2)
	var shown: bool = false
	for i: int in status_hud.rows.size():
		if str(status_hud.rows[i]["id"]) == "paralysis":
			shown = true
			assert_true(bool(status_hud.rows[i]["reversed"]), "HUD 上是反轉的那一種")
			assert_true(status_hud.line_text(i).begins_with(tr("RB_STATUS_PARALYSIS_REVERSED")), status_hud.line_text(i))
	assert_true(shown, "HUD 上看得到麻痺 → 出手加速")
	assert_true(absf(player.puppet().attack_speed - 1.35) < 0.001, "人偶的出手真的調快了（%s）" % player.puppet().attack_speed)
	# 出手一次：比原本的 0.55 秒早收招
	player.start_attack()
	var swing_frames: int = 0
	while player.puppet().action == "attack" and swing_frames < 120:
		await tree.physics_frame
		swing_frames += 1
	assert_true(swing_frames < int(float(Puppet.ACTION_TIME["attack"]) * 60.0) - 4, "出手比原本快（%d 幀）" % swing_frames)
	# 再叫一次（同一來源）：不會多一份、不會更快、不會多一格、護腕還是一個
	story.reverse_paralysis()
	var para: int = 0
	for e: Variant in player.status_effects.to_array():
		if str((e as Dictionary).get("id", "")) == "paralysis":
			para += 1
	assert_eq(para, 1, "同一來源不疊加")
	assert_true(absf(player.status_effects.attack_speed() - 1.35) < 0.001)
	assert_eq(player.reversal.equipped.count("paralysis"), 1)
	assert_eq(player.reversal.slots, 2)
	var worn: int = 0
	for c: Node in player.puppet().joint("elbow_R").get_children():
		if str(c.name).begins_with("NoenBracer"):
			worn += 1
	assert_eq(worn, 1, "手上只有一個護腕")
	# 板子讀幾秒 → 彌夏講結果 → 任務做完 →「待續／兩格一起用」
	assert_false(bool(_game().call("is_in_dialogue")), "隔幾秒彌夏才開口")
	await _frames(int(UndergroundMarketStory.BOARD_READ_SEC * 60.0) + 8)
	assert_true(bool(_game().call("is_in_dialogue")), "彌夏講結果")
	await _run_dialogue(level)
	await _frames(4)
	assert_true(s.quests.is_done("rb_bracer"), "這一段做完")
	assert_true(bool(s.state.get_flag("rb2.market_c1_done", false)))
	assert_true(story.ending)
	var card: ChapterCard = level.get_node_or_null("ChapterCard") as ChapterCard
	assert_not_null(card, "待續的卡")
	assert_eq(card.title_text(), tr("RB2_END5_TITLE"))
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
	# 到了藥店門口的存檔：回到門口前幾步；走到門口、走進店裡都不會黑掉，彌夏的話從頭講（講話在檢查點之後）
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
	assert_false(level3.has_node("ChapterCard"), "門口不是結尾了")
	# 生命不是滿的時候進店：不扎針，台詞也沒有那一句
	p3.health.hp = p3.health.max_hp - 20.0
	_stand(level3, UndergroundMarket.BOARD_POS + Vector3(-0.3, 0.0, -1.0))
	await _frames(4)
	assert_true(bool(_game().call("is_in_dialogue")))
	assert_eq(bool(s3.state.get_flag("rb2.full_health", true)), false)
	await _run_dialogue(level3)
	await _frames(4)
	assert_true(absf(p3.health.hp - (p3.health.max_hp - 20.0)) < 0.01, "有傷就不扎針（%.1f）" % p3.health.hp)
	assert_true(level3.story.board_ready())
	level3.queue_free()
	await tree.process_frame
	# 整段做完會自動存檔：重開遊戲讀檔，任務是做完的、回到藥店前；走進店裡到櫃台前才再看到「待續」，彌夏不會從頭再講
	var s4 := _session_at("shop")
	s4.set_flag("rb2.misha_met", true)
	s4.set_flag("rb2.pricked", true)
	s4.set_flag("rb2.board_done", true)
	s4.set_flag("rb2.first_shop_done", true)
	assert_true(s4.quests.is_done("rb_market"))
	var done_again := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", done_again)
	assert_eq(done_again.load_story_slot(), SaveCodec.Status.OK)
	assert_true(done_again.quests.is_done("rb_market"), "做完的那一刻存過檔")
	assert_eq(done_again.quests.stage_of("rb_demo"), "go_demo")
	assert_eq(done_again.state.checkpoint, "rb2_demo")
	assert_eq(str(_game().call("level_for_checkpoint", done_again.state.checkpoint)), "market")
	var level4: UndergroundMarket = await _load()
	level4.story.end_done = func() -> void: pass
	var p4: PlayerController = level4.get_node("Player") as PlayerController
	await _frames(6)
	assert_false(level4.has_node("ChapterCard"), "讀檔回來不會馬上黑掉")
	assert_false(bool(_game().call("is_in_dialogue")), "也不會馬上開始叫賣")
	assert_true(p4.global_position.z < UndergroundMarket.SHOP_Z - 1.0, "站在藥店門外（%s）" % p4.global_position)
	assert_true(absf(p4.rotation_degrees.y) < 1.0, "面向街上（北）")
	var sheila4: Node3D = level4.get_node("Sheila") as Node3D
	assert_true(sheila4.global_position.z < p4.global_position.z, "席菈在他前面（往街上那一邊）")
	assert_true(level4.board_lamp_on, "板子上的燈還亮著")
	_stand(level4, UndergroundMarket.BOARD_POS + Vector3(-0.3, 0.0, -1.0))
	await _frames(6)
	assert_false(bool(_game().call("is_in_dialogue")), "回店裡彌夏不會從頭再講")
	assert_false(level4.has_node("ChapterCard"), "櫃台前不再是待續")
	level4.queue_free()
	await tree.process_frame
	# 聽完叫賣的存檔（守衛戰的檢查點）：回到示範台南邊幾步，不會一讀檔就開打；走近才開打，商人不會從頭再喊
	var s5 := _session_at("demo_end")
	assert_eq(s5.quests.stage_of("rb_demo"), "stop_demo")
	# 帶著傷到這裡（存檔裡的生命是 63；讀檔最低補到一半，所以用比一半高的數字）：讀檔、倒下重試都不補滿
	s5.state.vitals["hp"] = 63.0
	assert_eq(s5.save(GameSession.AUTO_SLOT), OK)
	var heard := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", heard)
	assert_eq(heard.load_story_slot(), SaveCodec.Status.OK)
	assert_eq(heard.state.checkpoint, "rb2_demo_fight")
	assert_eq(str(_game().call("level_for_checkpoint", heard.state.checkpoint)), "market")
	var level5: UndergroundMarket = await _load()
	level5.story.end_done = func() -> void: pass
	var p5: PlayerController = level5.get_node("Player") as PlayerController
	await _frames(6)
	assert_false(level5.has_node("ChapterCard"), "讀檔回來不會馬上黑掉")
	assert_false(level5.story.fight_started, "也不會一讀檔就開打")
	assert_true(absf(p5.health.hp - 63.0) < 0.01, "生命照存檔，不補滿（%s）" % p5.health.hp)
	assert_true(FrostbridgeOpening.flat_distance(p5.global_position, UndergroundMarket.DEMO_POS) > UndergroundMarketStory.DEMO_RANGE, "出生點在觸發範圍外")
	assert_true(FrostbridgeOpening.flat_distance(p5.global_position, UndergroundMarket.DEMO_POS) < 10.0, "但是看得到台子")
	_stand(level5, UndergroundMarket.DEMO_POS + Vector3(3.0, 0.0, 2.0))
	await _frames(6)
	assert_false(bool(_game().call("is_in_dialogue")), "不會從頭再喊")
	assert_false(level5.has_node("ChapterCard"), "走近不再是待續")
	assert_true(level5.story.fight_started, "走近就開打")
	assert_eq(level5.story.guards.size(), 2)
	for dg: DemoGuard in level5.story.guards:
		dg.set_physics_process(false)
	# 打到一半（一個倒了、另一個剩一半）倒下重試：整個關卡重來——兩個守衛都回來、滿血；諾恩的生命還是存檔的 63、沒有護腕
	level5.story.guards[1].health.apply_damage(9999.0, {"source": p5})
	level5.story.guards[0].health.apply_damage(50.0, {"source": p5})
	p5.health.hp = 7.0
	await _frames(3)
	assert_false(bool(heard.state.get_flag("rb2.demo_won", false)), "還沒贏")
	level5.queue_free()
	await tree.process_frame
	_game().call("retry", false)
	var retried: GameSession = _game().get("session") as GameSession
	assert_eq(retried.state.checkpoint, "rb2_demo_fight")
	assert_false(bool(retried.state.get_flag("rb2.demo_won", false)))
	assert_eq(retried.state.grants.count(UndergroundMarketStory.BRACER_GRANT), 0)
	var level6: UndergroundMarket = await _load()
	level6.story.end_done = func() -> void: pass
	var p6: PlayerController = level6.get_node("Player") as PlayerController
	await _frames(6)
	assert_true(absf(p6.health.hp - 63.0) < 0.01, "倒下重試不補滿血（%s）" % p6.health.hp)
	assert_false(level6.story.fight_started, "重來也是走近才開打")
	assert_true(level6.demo_guards[0].visible and level6.demo_guards[1].visible, "布景的守衛站回去")
	assert_false(level6.demo_fight_begun)
	_stand(level6, UndergroundMarket.DEMO_POS + Vector3(3.0, 0.0, 2.0))
	await _frames(6)
	assert_eq(level6.story.guards.size(), 2, "兩個守衛都回來")
	for dg: DemoGuard in level6.story.guards:
		dg.set_physics_process(false)
		assert_eq(dg.health.hp, dg.health.max_hp, "滿血重來")
	# 打贏 → 講完 → 護腕只有一個
	for dg: DemoGuard in level6.story.guards:
		dg.health.apply_damage(9999.0, {"source": p6})
	await _frames(int(UndergroundMarketStory.WON_TALK_SEC * 60.0) + 16)
	assert_true(bool(_game().call("is_in_dialogue")), "商人認輸")
	await _run_dialogue(level6)
	await _frames(4)
	assert_eq(retried.state.grants.count(UndergroundMarketStory.BRACER_GRANT), 1)
	assert_false(level6.has_node("ChapterCard"), "拿到護腕不是待續（D-234）：接著回藥店試戴")
	assert_eq(retried.quests.stage_of("rb_bracer"), "back_to_shop")
	level6.queue_free()
	await tree.process_frame
	# 打贏之後的存檔（「繼續」）：場上是打完的樣子，不會再打一次、不會再講一次、不會再拿一次；走近才是「待續」
	var after := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", after)
	assert_eq(after.load_story_slot(), SaveCodec.Status.OK)
	assert_true(after.quests.is_done("rb_demo"))
	assert_true(bool(after.state.get_flag("rb2.bracer_taken", false)), "拿到護腕的那一刻存過檔")
	assert_eq(after.state.checkpoint, "rb2_bracer", "回藥店試戴的那個檢查點")
	assert_eq(str(_game().call("level_for_checkpoint", after.state.checkpoint)), "market")
	var level7: UndergroundMarket = await _load()
	level7.story.end_done = func() -> void: pass
	await _frames(6)
	assert_true(level7.demo_fight_begun, "打完的樣子")
	assert_false(level7.demo_guards[0].visible or level7.demo_guards[1].visible, "守衛不在了")
	assert_true(level7.demo_crowd[0].position.distance_to(UndergroundMarket.DEMO_CROWD_FLEE[0]) < 0.05, "看熱鬧的人在遠處")
	assert_false(level7.has_node("ChapterCard"), "不會一讀檔就黑掉")
	_stand(level7, UndergroundMarket.DEMO_POS + Vector3(3.0, 0.0, 2.0))
	await _frames(6)
	assert_eq(level7.story.guards.size(), 0, "不會再打一次")
	assert_false(bool(_game().call("is_in_dialogue")), "不會再講一次")
	assert_false(level7.has_node("ChapterCard"), "示範台前不再是待續")
	assert_eq(after.state.grants.count(UndergroundMarketStory.BRACER_GRANT), 1, "護腕還是一個")
	# 試戴護腕（D-234）：讀檔站在示範台南邊、面向南；走回櫃台前 → 彌夏答應 → 檢查點換成櫃台前
	var p7: PlayerController = level7.get_node("Player") as PlayerController
	_stand(level7, UndergroundMarket.BOARD_POS + Vector3(-0.3, 0.0, -1.0))
	await _frames(4)
	assert_true(bool(_game().call("is_in_dialogue")), "彌夏開口")
	await _run_dialogue(level7)
	await _frames(2)
	assert_eq(after.state.checkpoint, "rb2_bracer_board")
	# 手放上去、還沒聽完結果就關遊戲（或倒下重試）：回到櫃台前、還沒試過——麻痺沒有解鎖、第二格是空的、不會再聽一次彌夏的規矩
	Input.action_press("interact")
	await _frames(int(UndergroundMarketStory.BOARD_HOLD_SEC * 60.0) + 6)
	Input.action_release("interact")
	assert_eq(p7.reversal.equipped[1], "paralysis")
	level7.queue_free()
	await tree.process_frame
	var mid := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", mid)
	assert_eq(mid.load_story_slot(), SaveCodec.Status.OK)
	assert_eq(mid.state.checkpoint, "rb2_bracer_board")
	assert_eq(mid.quests.stage_of("rb_bracer"), "test_bracer")
	assert_false(bool(mid.state.get_flag("rb2.bracer_tested", false)), "試到一半沒有存")
	var level8: UndergroundMarket = await _load()
	level8.story.end_done = func() -> void: pass
	var p8: PlayerController = level8.get_node("Player") as PlayerController
	await _frames(6)
	assert_true(p8.global_position.z > UndergroundMarket.SHOP_INNER_Z, "站在店裡")
	assert_true(FrostbridgeOpening.flat_distance(p8.global_position, UndergroundMarket.BOARD_POS) < 1.6, "櫃台前")
	assert_false(bool(_game().call("is_in_dialogue")), "不會再講一次規矩")
	assert_false(p8.reversal.unlocked.has("paralysis"), "讀檔：麻痺沒有白拿")
	assert_eq(p8.reversal.equipped[1], "")
	assert_false(p8.status_effects.has("paralysis"))
	assert_true(level8.story.bracer_ready(), "可以直接再試")
	Input.action_press("interact")
	await _frames(int(UndergroundMarketStory.BOARD_HOLD_SEC * 60.0) + 6)
	Input.action_release("interact")
	assert_eq(p8.reversal.equipped[1], "paralysis")
	await _frames(int(UndergroundMarketStory.BOARD_READ_SEC * 60.0) + 8)
	await _run_dialogue(level8)
	await _frames(4)
	assert_true(mid.quests.is_done("rb_bracer"))
	assert_not_null(level8.get_node_or_null("ChapterCard"), "試完才是待續")
	level8.queue_free()
	await tree.process_frame
	# 做完之後的存檔（「繼續」）：第二格的麻痺存進去了、不會多一格；站在藥店外面，不會一讀檔就黑掉；走到櫃台前才是「待續」
	var last := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", last)
	assert_eq(last.load_story_slot(), SaveCodec.Status.OK)
	assert_true(last.quests.is_done("rb_bracer"))
	var level9: UndergroundMarket = await _load()
	level9.story.end_done = func() -> void: pass
	var p9: PlayerController = level9.get_node("Player") as PlayerController
	await _frames(6)
	assert_eq(p9.reversal.slots, 2)
	assert_eq(p9.reversal.equipped[1], "paralysis", "第二格的麻痺存下來了")
	assert_eq(p9.reversal.equipped.count("paralysis"), 1, "只佔一格")
	assert_eq(p9.reversal.equipped[0], "", "這個存檔是直接跳到示範場的（沒中過毒）：第一格還是空的，麻痺不會跑去佔第一格")
	assert_true(p9.global_position.z < UndergroundMarket.SHOP_Z, "站在藥店外面")
	assert_false(level9.has_node("ChapterCard"), "不會一讀檔就黑掉")
	assert_not_null(p9.puppet().joint("elbow_R").get_node_or_null("NoenBracer"), "護腕還戴著")
	assert_eq(last.state.grants.count(UndergroundMarketStory.BRACER_GRANT), 1)
	_stand(level9, UndergroundMarket.BOARD_POS + Vector3(-0.3, 0.0, -1.0))
	await _frames(6)
	assert_false(bool(_game().call("is_in_dialogue")), "不會再講一次")
	assert_not_null(level9.get_node_or_null("ChapterCard"), "走到櫃台前才是待續")
	level9.queue_free()
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


## 店內（D-231）：門洞走得過去、櫃台與彌夏在裡面、測試板是會動的節點、彩色的燈沒有變多。
func test_shop_interior_has_counter_misha_and_a_working_board() -> void:
	var s := _session_at("shop")
	assert_eq(s.state.checkpoint, "rb2_shop")
	var level: UndergroundMarket = await _load()
	# 這個測試只看場景：劇情停住（不然走到櫃台前彌夏會開口，對話會留到下一個測試）
	level.story.set_physics_process(false)
	assert_not_null(level.misha, "彌夏")
	assert_eq(level.misha.get_parent(), level)
	assert_true(level.misha.global_position.z > UndergroundMarket.COUNTER_Z, "她在櫃台後面")
	assert_true(level.shop_bottle_count >= 60, "藥架上的瓶子（%d）" % level.shop_bottle_count)
	var marker: Node3D = level.get_node_or_null("MishaTestBoard") as Node3D
	assert_not_null(marker, "任務標記指到測試板")
	assert_not_null(level.get_node_or_null("TestBoard/Dial/Needle"), "指針")
	assert_not_null(level.get_node_or_null("TestBoard/Dial/Lamp"), "綠燈")
	assert_eq(level.board_lamp_light.light_energy, 0.0, "一開始燈是暗的")
	assert_true(absf(level.board_needle_deg()) < 0.01, "指針在中間")
	for light_name: String in ["ShopCounterLamp", "ShopShelfGlow", "ShopBenchGlow"]:
		var l: OmniLight3D = level.get_node_or_null(light_name) as OmniLight3D
		assert_not_null(l, light_name)
		if l != null:
			assert_false(l.shadow_enabled, "店裡的燈不投影（投影的大燈上限照舊）")
	# 從門外直直走進去：門洞不擋人（真的用物理走，不是瞬移）
	var player: PlayerController = level.get_node("Player") as PlayerController
	_stand(level, UndergroundMarket.SHOP_DOOR + Vector3(0.0, 0.0, -0.8))
	for i: int in 240:
		if player.global_position.z > UndergroundMarket.SHOP_INNER_Z + 1.0:
			break
		player.velocity = Vector3(0.0, player.velocity.y, 3.0)
		player.move_and_slide()
		await tree.physics_frame
	assert_true(player.global_position.z > UndergroundMarket.SHOP_INNER_Z + 1.0, "走得進店裡（停在 %s）" % player.global_position)
	assert_true(absf(player.global_position.y) < 0.2, "地板是平的（y＝%.2f）" % player.global_position.y)
	# 門的兩邊還是牆
	_stand(level, UndergroundMarket.SHOP_DOOR + Vector3(2.4, 0.0, -0.8))
	for i: int in 90:
		player.velocity = Vector3(0.0, player.velocity.y, 3.0)
		player.move_and_slide()
		await tree.physics_frame
	assert_true(player.global_position.z < UndergroundMarket.SHOP_INNER_Z, "門旁邊的牆擋得住（%s）" % player.global_position)
	# 店的最裡面（洞的岩盤以外）也有地板
	_stand(level, Vector3(-3.6, 0.0, UndergroundMarket.SHOP_ROOM_S - 0.6))
	await _frames(30)
	assert_true(absf(player.global_position.y) < 0.2, "最裡面不會掉下去（y＝%.2f）" % player.global_position.y)
	level.queue_free()
	await tree.process_frame


## 舊存檔的遷移（D-232）：第 85 輪的存檔——藥店那一段做完了、還沒有黑市示範場這條任務。讀檔時補開，「繼續」從藥店門外開始。
func test_old_save_that_finished_the_shop_continues_to_the_demo() -> void:
	var s := _session_at("shop")
	for flag: String in ["rb2.misha_met", "rb2.pricked", "rb2.board_done", "rb2.first_shop_done"]:
		s.set_flag(flag, true)
	assert_true(s.quests.is_done("rb_market"))
	# 模擬舊資料：把 rb_demo 從存檔裡拿掉、檢查點退回藥店門口
	s.state.quests.erase("rb_demo")
	s.state.checkpoint = "rb2_shop"
	assert_eq(s.save(GameSession.AUTO_SLOT), OK)
	var again := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", again)
	assert_eq(again.load_story_slot(), SaveCodec.Status.OK)
	assert_true(again.quests.is_done("rb_market"))
	assert_eq(again.quests.stage_of("rb_demo"), "go_demo", "補開了")
	assert_eq(again.main_quest(), "rb_demo")
	assert_eq(again.state.checkpoint, "rb2_demo")
	assert_eq(str(_game().call("level_for_checkpoint", again.state.checkpoint)), "market")
	# 再讀一次不會重開、進度不會退回去
	again.set_flag("rb2.pitch_heard", true)
	assert_eq(again.save(GameSession.AUTO_SLOT), OK)
	var third := GameSession.new(QuestDB.load_default(), _dir)
	assert_eq(third.load_story_slot(), SaveCodec.Status.OK)
	assert_eq(third.quests.stage_of("rb_demo"), "stop_demo")


## 舊存檔的遷移：拿到護腕就「待續」的存檔（第 87 輪）——讀檔時補開「試戴護腕」，「繼續」從示範台往藥店走；
## 存檔裡沒有麻痺、反轉欄位只有中毒：讀得進來，第二格是空的。
func test_old_save_that_took_the_bracer_continues_to_trying_it_on() -> void:
	var s := _session_at("demo_won")
	s.set_flag("rb2.bracer_taken", true)
	s.state.grant_once(UndergroundMarketStory.BRACER_GRANT)
	assert_true(s.quests.is_done("rb_demo"))
	# 模擬舊資料：存檔裡沒有 rb_bracer、檢查點還是守衛戰那一個、反轉欄位只有中毒
	s.state.quests.erase("rb_bracer")
	s.state.checkpoint = "rb2_demo_fight"
	s.state.reversal = {"slots": 2, "unlocked": ["poison"], "equipped": ["poison", ""], "awakened_once": true}
	assert_eq(s.save(GameSession.AUTO_SLOT), OK)
	var again := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", again)
	assert_eq(again.load_story_slot(), SaveCodec.Status.OK)
	assert_eq(again.quests.stage_of("rb_bracer"), "back_to_shop", "補開了")
	assert_eq(again.main_quest(), "rb_bracer")
	assert_eq(again.state.checkpoint, "rb2_bracer")
	assert_eq(str(_game().call("level_for_checkpoint", again.state.checkpoint)), "market")
	assert_eq(again.state.grants.count(UndergroundMarketStory.BRACER_GRANT), 1, "護腕不會多給")
	var slots := ReversalSlots.from_dict(again.state.reversal)
	assert_eq(slots.slots, 2)
	assert_eq(slots.equipped[0], "poison")
	assert_eq(slots.equipped[1], "", "舊存檔：第二格是空的")
	assert_false(slots.unlocked.has("paralysis"))
	# 還沒拿到護腕的存檔（打贏了、商人還沒講完）不會補開
	var won := _session_at("demo_won")
	won.state.quests.erase("rb_bracer")
	assert_eq(won.save(GameSession.AUTO_SLOT), OK)
	var third := GameSession.new(QuestDB.load_default(), _dir)
	assert_eq(third.load_story_slot(), SaveCodec.Status.OK)
	assert_eq(third.quests.stage_of("rb_bracer"), "", "還沒拿到護腕：不開")
	# 再讀一次不會重開、進度不會退回去
	again.set_flag("rb2.bracer_asked", true)
	assert_eq(again.save(GameSession.AUTO_SLOT), OK)
	var fourth := GameSession.new(QuestDB.load_default(), _dir)
	assert_eq(fourth.load_story_slot(), SaveCodec.Status.OK)
	assert_eq(fourth.quests.stage_of("rb_bracer"), "test_bracer")


## 示範台（D-232）：街中段西側的空位。台子、直條紋的背景布、聚光燈、商人與守衛、看熱鬧的人；街的東半邊還走得過去。
func test_demo_stage_is_built_and_the_street_stays_walkable() -> void:
	var s := _session_at("deal")
	assert_eq(s.state.checkpoint, "rb2_demo")
	var level: UndergroundMarket = await _load()
	level.story.set_physics_process(false)
	var marker: Node3D = level.get_node_or_null("DemoStage") as Node3D
	assert_not_null(marker, "任務標記")
	assert_true(absf(UndergroundMarket.DEMO_Z - level.stall_z(UndergroundMarket.DEMO_SLOT)) < 0.001, "就在西側那個空位")
	assert_eq(UndergroundMarket.WEST_KINDS[UndergroundMarket.DEMO_SLOT], UndergroundMarket.KIND_GAP)
	assert_true(marker.global_position.z > UndergroundMarket.RAMP_S + 4.0 and marker.global_position.z < UndergroundMarket.SHOP_Z - 8.0, "在街的中段")
	# 人：商人在台上、面向街；兩個守衛（台上示範的戴著護腕、台下的拿棍子）；看熱鬧的人在街的西半邊
	assert_not_null(level.demo_seller, "商人")
	assert_true(level.demo_seller.global_position.y > UndergroundMarket.DEMO_STAGE_H - 0.05, "站在台上")
	assert_true(level.demo_seller.global_position.x > UndergroundMarket.DEMO_STAGE_FRONT_X and level.demo_seller.global_position.x < UndergroundMarket.DEMO_STAGE_FRONT_X + UndergroundMarket.DEMO_TONGUE_OUT, "站在伸到街上的那一截（從街的南邊走過來看得到）")
	assert_true(level.demo_seller.hand("R").get_node_or_null("BellHammer") == null or level.demo_seller.hand("R").get_node("BellHammer").is_queued_for_deletion(), "商人不拿棍子")
	assert_not_null(level.demo_seller.hand("R").get_node_or_null("Bracer"), "手上舉著一個護腕")
	assert_not_null(level.demo_seller.get_node_or_null("PoseOverride"), "擺著叫賣的姿勢")
	await _frames(3)
	assert_true(level.demo_seller.joint("shoulder_R").rotation.x > 2.0, "右手真的舉著（%.2f）" % level.demo_seller.joint("shoulder_R").rotation.x)
	assert_eq(level.demo_guards.size(), 2, "兩個守衛")
	var shown: Puppet = level.demo_guards[0]
	assert_true(shown.global_position.y > UndergroundMarket.DEMO_STAGE_H - 0.05, "示範的那個在台上")
	assert_not_null(shown.joint("elbow_L").get_node_or_null("Bracer"), "左手戴著")
	assert_not_null(shown.joint("elbow_R").get_node_or_null("Bracer"), "右手戴著")
	assert_true(absf(shown.joint("shoulder_L").rotation.x) < 0.05, "左手垂著不動（諾恩注意到的那一點）")
	assert_true(level.demo_guards[1].global_position.y < 0.1, "另一個在台下")
	assert_true(level.demo_crowd.size() >= 3, "看熱鬧的人（%d）" % level.demo_crowd.size())
	for c: Puppet in level.demo_crowd:
		assert_true(c.global_position.x < -0.4 and c.global_position.x > UndergroundMarket.DEMO_STAGE_FRONT_X + UndergroundMarket.DEMO_TONGUE_OUT + 0.5, "在街的西半邊、不貼著台子（%s）" % c.global_position)
		assert_true(absf(c.global_position.z - UndergroundMarket.DEMO_Z) < UndergroundMarket.DEMO_STAGE_LEN * 0.5, "站在台子前面")
	assert_eq(level.demo_bracer_count, 3, "桌上三個護腕")
	assert_true(level.demo_drape_count >= 4, "背景布、垂簾、側幕、裙布（%d）" % level.demo_drape_count)
	# 燈：一盞投影的聚光燈（往下打、暖白色），投影的大燈總數還在上限內；彩色的燈沒有變多
	assert_not_null(level.demo_spot, "聚光燈")
	assert_true(level.demo_spot.shadow_enabled)
	assert_true(-level.demo_spot.global_transform.basis.z.y < -0.5, "往下打")
	assert_true(level.demo_spot.light_color.r >= 0.9 and level.demo_spot.light_color.g >= 0.6, "暖白，不是第四種彩色")
	assert_true(level.shadow_light_count <= 4, "投影的大燈最多四盞（%d）" % level.shadow_light_count)
	var coloured: Dictionary = {}
	for n: Node in level.get_children():
		var l: OmniLight3D = n as OmniLight3D
		if l != null and (l.light_color.r < 0.9 or l.light_color.g < 0.4):
			coloured[l.light_color.to_html(false)] = true
	assert_eq(coloured.size(), 3, "彩色的燈還是只有三種")
	# 用物理走：從藥店門外沿著街的東半邊往北，走得過示範台前面（看熱鬧的人沒有把街堵死）
	var player: PlayerController = level.get_node("Player") as PlayerController
	_stand(level, Vector3(1.0, 0.0, UndergroundMarket.DEMO_Z + 4.0))
	await _frames(2)
	for i: int in 200:
		player.velocity = Vector3(0.0, 0.0, -4.0)
		player.move_and_slide()
		await tree.physics_frame
		if player.global_position.z < UndergroundMarket.DEMO_Z - 4.0:
			break
	assert_true(player.global_position.z < UndergroundMarket.DEMO_Z - 4.0, "東半邊走得過去（停在 %s）" % player.global_position)
	# 台子是實心的：從街上往西直直走，會被台子前緣擋住（不會走進背景布裡）
	_stand(level, Vector3(0.6, 0.0, UndergroundMarket.DEMO_Z - 1.55))
	await _frames(2)
	for i: int in 120:
		player.velocity = Vector3(-4.0, 0.0, 0.0)
		player.move_and_slide()
		await tree.physics_frame
	assert_true(player.global_position.x > UndergroundMarket.DEMO_STAGE_FRONT_X - 0.2, "台子擋得住（停在 %s）" % player.global_position)
	level.queue_free()
	await tree.process_frame
