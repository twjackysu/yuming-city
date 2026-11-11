extends TestCase
## 新版前十分鐘（劇情重寫，D-204）在霜橋鎮的開場：鐵門後的雷德、推車上的波克、生命 55 →
## 推車到北街轉角、藥桶破了、主街一片毒霧 → 第一次中毒自動覺醒（中間兩行字、生命往上）→
## 離開、毒效結束 → 再踏回去確認 → 霧散 → 推車到南街口 → 跟上席菈（rb_sheila 檢查點）。
## 舊版切片的觸發點、石拱不在新版出現；死亡重試回到第一次進霧前（生命不補滿）。

const PATH: String = "res://scenes/levels/frostbridge.tscn"

var _dir: String = ""
var _original: GameSession


func before_each() -> void:
	_dir = "user://test_rb_open_%d" % Time.get_ticks_usec()
	_original = tree.root.get_node("Game").get("session") as GameSession


func after_each() -> void:
	tree.root.get_node("Game").set("session", _original)
	for d: String in [_dir, _dir + "_reboot"]:
		if DirAccess.dir_exists_absolute(d):
			for f: String in DirAccess.get_files_at(d):
				DirAccess.remove_absolute(d.path_join(f))
			DirAccess.remove_absolute(d)


func _session() -> GameSession:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", s)
	s.new_reboot_game()
	return s


func _load() -> StoryLevel:
	var level: StoryLevel = (load(PATH) as PackedScene).instantiate() as StoryLevel
	tree.root.add_child(level)
	await tree.physics_frame
	return level


func _game() -> Node:
	return tree.root.get_node("Game")


func _run_dialogue(level: Node, choice: int = 0) -> void:
	var box: DialogueBox = level.get_node("DialogueBox") as DialogueBox
	var choices: Node = box.find_child("Choices", true, false)
	for i: int in 60:
		if not bool(_game().call("is_in_dialogue")):
			break
		if choices.get_child_count() > 0:
			(choices.get_child(choice) as Button).pressed.emit()
		else:
			box.press_continue()
		await tree.process_frame


func _frames(n: int) -> void:
	for i: int in n:
		await tree.physics_frame


func test_opening_sets_up_gate_cart_and_hurt_noen() -> void:
	var s := _session()
	var level: StoryLevel = await _load()
	await tree.process_frame
	var rb: RebootOpening = level.get_node_or_null("RebootOpening") as RebootOpening
	assert_not_null(rb, "新版：霜橋鎮掛上 RebootOpening")
	# 第 72 輪（D-210）起新版有同名的任務標記（Marker3D，指向艾妲），但不是切片那個會開對話的觸發區
	assert_false(level.get_node_or_null("PearSellerTrigger") is Area3D, "新版不跑切片的梨販觸發點")
	assert_false(level.get_node_or_null("CellarTrigger") is Area3D, "也不跑切片的地窖觸發點")
	assert_false(bool(Game.session.state.get_flag("slice.met_pear_seller", false)), "切片的梨販對話沒有被觸發")
	assert_false(level.has_node("ArchMemoryTrigger"), "新版不跑石拱回憶")
	assert_true(level.south_arch != null and level.south_arch.get_script() == null, "南街的斷拱只是場景，沒有行為（沒有重現）")
	assert_false(InputMap.has_action("nine_breath"), "也沒有「重現」這個按鍵")
	assert_true(level.has_node("RbGate") and level.has_node("Red") and level.has_node("RbCart"), "鐵門、門後的雷德、推車")
	assert_eq(level.get_node("RbBarrel0").get_node("Toxic").get("text"), "RB_BARREL_TOXIC", "藥桶上寫著有毒")
	var player: PlayerController = level.get_node("Player") as PlayerController
	assert_eq(player.health.hp, RebootOpening.OPENING_HP, "開場被鐵架擦傷：生命 55")
	assert_true(player.global_position.z < -40.0, "從北街鐵門前開始")
	assert_true(bool(_game().call("is_in_dialogue")), "開場對話（可跳過）")
	await _run_dialogue(level)
	assert_eq(s.state.get_flag("rb.opening_done"), true)
	assert_eq(s.quests.stage_of("rb_main"), "escape")
	assert_eq(s.objective_key(), "Q_RB_OBJ_ESCAPE", "第一個目標：把波克帶到南街")
	# 自由操作時生命穩定（沒有持續掉血）
	await _frames(20)
	assert_eq(player.health.hp, RebootOpening.OPENING_HP, "自由操作時生命不再掉")
	# 諾恩離推車太遠：推車不動
	var cart: Caravan = level.get_node("RbCart") as Caravan
	var before: float = cart.runner.traveled
	player.global_position = Vector3(3.0, RebootOpening.RISE + 0.05, -36.0)
	await _frames(10)
	assert_eq(cart.runner.traveled, before, "離太遠推車不走")
	player.global_position = cart.global_position + Vector3(1.0, 0.05, 1.2)
	await _frames(10)
	assert_true(cart.runner.traveled > before, "諾恩在旁邊：推車往南走")
	level.queue_free()
	await tree.process_frame


func test_mist_awakening_test_and_cart_to_south() -> void:
	var s := _session()
	var level: StoryLevel = await _load()
	await tree.process_frame
	await _run_dialogue(level)
	var rb: RebootOpening = level.get_node("RebootOpening") as RebootOpening
	var player: PlayerController = level.get_node("Player") as PlayerController
	var cart: Caravan = level.get_node("RbCart") as Caravan
	var hud: Hud = level.get_node("Hud") as Hud
	# 推車推到北街轉角 → 藥桶破了、毒霧、第一次進霧前的檢查點
	cart.runner.traveled = rb._corner_traveled - 0.3
	cart._sync()
	player.global_position = cart.global_position + Vector3(1.0, 0.05, 0.5)
	# 送葬者舉起那截燈柱（0.9 秒）＋飛過來（0.7 秒），D-205
	await _frames(130)
	assert_eq(s.state.get_flag("rb.barrels_broken"), true, "推車到轉角：藥桶被砸破")
	assert_eq(s.quests.stage_of("rb_main"), "poison_discovery")
	assert_eq(s.state.checkpoint, "rb_before_mist", "第一次進霧前的檢查點")
	assert_true(s.has_save("auto"), "新版自動存檔")
	assert_eq(float(s.state.vitals.get("hp", -1.0)), RebootOpening.OPENING_HP, "存檔記下開場後的生命")
	assert_not_null(rb.mist, "主街上一片毒霧")
	assert_true(bool(level.get_node("RbBarrel0").get_meta("broken", false)), "藥桶倒了")
	# 推車停在石階上（高處），不進毒霧
	await _frames(30)
	assert_true(cart.runner.traveled <= rb._hold_traveled + 0.001, "霧散之前推車停在石階上")
	assert_false(rb.mist.contains(cart.global_position), "波克不在毒霧裡")
	# 走進毒霧 → 中毒、自動覺醒、生命往上
	var hp0: float = player.health.hp
	player.global_position = RebootOpening.MIST_CENTER + Vector3(0.0, 0.05, 0.0)
	await _frames(40)
	assert_true(player.status_effects.has("poison"), "在霧裡中毒")
	assert_true(player.reversal.is_reversed("poison"), "第一次中毒：逆轉體質自動裝上")
	assert_eq(s.state.get_flag("rb.reversal_awakened"), true)
	assert_eq(hud.center_lines(), PackedStringArray(["RB_AWAKEN_LINE1", "RB_AWAKEN_LINE2"]), "畫面中間兩行字")
	assert_true(player.health.hp > hp0, "生命往上爬（%s → %s）" % [hp0, player.health.hp])
	assert_eq(s.objective_key(), "Q_RB_OBJ_MIST_TEST", "目標換成：再踏回去確認一次")
	# 離開、毒效結束 → 一句提示
	player.global_position = Vector3(0.9, 0.05, -12.0)
	await _frames(3)
	player.status_effects.clear("poison")
	await _frames(3)
	assert_true(rb.left_mist_after_awaken, "離開毒霧、毒效結束")
	assert_true(bool(_game().call("is_in_dialogue")), "「再踏回去一次」")
	await _run_dialogue(level)
	assert_eq(s.state.get_flag("rb.mist_reentered", false), false, "還沒踏回去")
	# 再踏回去 → 確認
	rb.mist_clear_sec = 0.1
	player.global_position = RebootOpening.MIST_CENTER + Vector3(1.0, 0.05, 2.0)
	await _frames(3)
	assert_eq(s.state.get_flag("rb.mist_reentered"), true, "再踏回去確認")
	assert_true(bool(_game().call("is_in_dialogue")), "「真的。不是只有一次。」")
	await _run_dialogue(level)
	for i: int in 30:
		if rb.mist == null:
			break
		await tree.process_frame
	assert_eq(rb.mist, null, "確認完霧散了")
	# 推車往南街口：越過石階上停的那一點
	cart.runner.traveled = rb._hold_traveled
	cart._sync()
	player.global_position = cart.global_position + Vector3(1.0, 0.05, 0.5)
	await _frames(10)
	assert_true(cart.runner.traveled > rb._hold_traveled, "霧散之後推車往下走")
	cart.runner.traveled = cart.runner.length() - 0.2
	cart._sync()
	player.global_position = cart.global_position + Vector3(1.0, 0.05, -0.5)
	await _frames(20)
	assert_eq(s.state.get_flag("rb.reached_south"), true, "推車到南街口")
	assert_eq(s.quests.stage_of("rb_main"), "meet_sheila", "→ 跟上席菈")
	assert_eq(s.state.checkpoint, "rb_sheila")
	# 席菈從南街側門出來 → 走近 → 接應的對話 → 波克進店
	var sheila: Node3D = level.get_node_or_null("Sheila") as Node3D
	assert_not_null(sheila, "席菈從側門出來")
	assert_true((cart.get_node("Cart/Wounded0") as Node3D).visible, "波克還在車上")
	assert_false((cart.get_node("Cart/Wounded1") as Node3D).visible, "車上只有波克一個人")
	if sheila != null:
		sheila.set_physics_process(false)
		player.global_position = sheila.global_position + Vector3(1.2, 0.05, 0.6)
		await _frames(3)
		assert_true(bool(_game().call("is_in_dialogue")), "走近席菈 → 對話")
		await _run_dialogue(level, 1)
		assert_eq(s.state.get_flag("rb.sheila_met"), true)
		assert_eq(s.quests.stage_of("rb_main"), "guardian_fight", "→ 和席菈打倒守衛")
		assert_eq(s.state.checkpoint, "rb_guardian")
		assert_false((cart.get_node("Cart/Wounded0") as Node3D).visible, "波克進店了")
	level.queue_free()
	await tree.process_frame


## 追擊的送葬者（D-205）：對話一結束從屋頂跳下來 → 不出招、打不動 → 用自己的腳跟在推車後面 →
## 推車到轉角，舉起那截燈柱扔過來、砸破藥桶（沒砸到人）→ 堵在北街、不下石階。
func test_pursuer_drops_follows_and_throws_lamp_at_barrels() -> void:
	var s := _session()
	var level: StoryLevel = await _load()
	await tree.process_frame
	assert_false(level.has_node("RbPursuer"), "開場對話中牠還沒出現")
	await _run_dialogue(level)
	var rb: RebootOpening = level.get_node("RebootOpening") as RebootOpening
	var player: PlayerController = level.get_node("Player") as PlayerController
	var cart: Caravan = level.get_node("RbCart") as Caravan
	var u: Undertaker = level.get_node_or_null("RbPursuer") as Undertaker
	assert_not_null(u, "對話一結束，送葬者出現")
	if u == null:
		level.queue_free()
		await tree.process_frame
		return
	assert_true(u.global_position.y > RebootOpening.RISE + 2.0, "從屋頂跳下來（不是憑空出現在地上）")
	assert_true(level.has_node("RbLampStump"), "門邊的燈柱被踩斷")
	await _frames(70)
	assert_true(u.is_on_floor() and u.global_position.y < RebootOpening.RISE + 0.6, "落地")
	assert_true(u.is_scripted(), "追擊期間不跑狀態機")
	assert_true(rb.lamp_chunk != null and rb.lamp_chunk.get_parent().name == "Torso", "手上拖著折下來的那截燈柱")
	# 打不動，牠也不出招（開場生命只有 55）
	var hp: float = u.health.hp
	assert_false(u.health.apply_damage(50.0), "追擊期間打不動")
	assert_eq(u.health.hp, hp)
	player.global_position = u.global_position + Vector3(-1.7, 0.05, 0.4)
	await _frames(60)
	assert_eq(player.health.hp, RebootOpening.OPENING_HP, "站在牠旁邊也不會被打")
	assert_eq(u.brain.state, EnemyBrain.State.IDLE, "狀態機沒有在跑")
	# 推車往南走了一段 → 牠用自己的腳跟上（不是瞬移、不是站著滑）
	cart.runner.traveled = 6.6
	cart._sync()
	player.global_position = Vector3(2.6, RebootOpening.RISE + 0.05, -29.6)
	var z0: float = u.global_position.z
	await _frames(50)
	var z1: float = u.global_position.z
	assert_true(z1 > z0 + 0.3 and z1 < z0 + 1.6, "牠往南走（每秒約 1.45 m，不是瞬移）：%.2f → %.2f" % [z0, z1])
	assert_true(u.get_real_velocity().length() > 0.5, "是用自己的速度在走")
	await _frames(110)
	assert_true(absf(u.global_position.z - (cart.global_position.z - RebootOpening.PURSUER_GAP)) < 0.6, "停在推車後面 5.5 m")
	# 推車到轉角 → 牠站住、舉起那截燈柱 → 扔過來砸破藥桶
	cart.runner.traveled = rb._corner_traveled - 0.2
	cart._sync()
	player.global_position = cart.global_position + Vector3(1.0, 0.05, 0.5)
	await _frames(12)
	assert_eq(rb.throw_phase, 1, "推車到轉角：牠舉起那截燈柱")
	assert_true(u.throw_windup > 0.0, "舉起來的前兆")
	assert_eq(s.state.get_flag("rb.barrels_broken", false), false, "還沒砸到")
	await _frames(60)
	assert_eq(rb.throw_phase, 2, "那截燈柱在空中")
	assert_true(rb.lamp_chunk.get_parent() == level, "離手了")
	await _frames(60)
	assert_eq(rb.throw_phase, 3)
	assert_eq(s.state.get_flag("rb.barrels_broken"), true, "砸破藥桶")
	assert_not_null(rb.mist, "毒霧")
	# 砸到的那一下：木屑與湧出來的藥霧噴在藥桶那裡（D-208：原本噴在牠腳下，離藥桶好幾公尺、在鏡頭外）
	var chips: CPUParticles3D = u.get_node_or_null("RbImpactChips") as CPUParticles3D
	var puff: CPUParticles3D = u.get_node_or_null("RbImpactPuff") as CPUParticles3D
	assert_true(chips != null and puff != null, "砸到的那一下有木屑與藥霧")
	if chips != null and puff != null:
		assert_true(u.global_position.distance_to(RebootOpening.THROW_TARGET) > 4.0, "牠自己離藥桶很遠")
		assert_true(chips.global_position.distance_to(RebootOpening.THROW_TARGET) < 1.0, "木屑在藥桶那裡")
		assert_true(puff.global_position.distance_to(RebootOpening.THROW_TARGET) < 1.0, "藥霧在藥桶那裡")
		assert_true(chips.one_shot and puff.one_shot, "一次性")
		assert_true(puff.scale_amount_max > chips.scale_amount_max * 3.0, "藥霧是大團的、木屑是小片的")
	assert_eq(ParticleLook.untextured(u).size(), 0, "粒子都有柔邊圓點貼圖")
	assert_true(rb.lamp_chunk.global_position.distance_to(RebootOpening.THROW_TARGET) < 1.0, "那截燈柱躺在藥桶旁")
	assert_eq(player.health.hp, RebootOpening.OPENING_HP, "沒砸到人")
	# 牠往前堵住北街，不下石階、不進毒霧
	await _frames(150)
	assert_true(u.global_position.z > z1 + 1.0, "丟完往前堵路")
	assert_true(u.global_position.z <= RebootOpening.PURSUER_STOP_Z + 0.4, "不走下石階")
	assert_false(rb.mist.contains(u.global_position), "不進毒霧")
	assert_true(u.is_scripted(), "還是不出招")
	level.queue_free()
	await tree.process_frame


func test_retry_returns_before_mist_without_full_heal() -> void:
	var s := _session()
	var level: StoryLevel = await _load()
	await tree.process_frame
	await _run_dialogue(level)
	var rb: RebootOpening = level.get_node("RebootOpening") as RebootOpening
	var player: PlayerController = level.get_node("Player") as PlayerController
	var cart: Caravan = level.get_node("RbCart") as Caravan
	cart.runner.traveled = rb._corner_traveled - 0.3
	cart._sync()
	player.global_position = cart.global_position + Vector3(1.0, 0.05, 0.5)
	await _frames(130)
	assert_eq(s.state.checkpoint, "rb_before_mist")
	player.global_position = RebootOpening.MIST_CENTER + Vector3(0.0, 0.05, 0.0)
	await _frames(20)
	assert_eq(s.state.get_flag("rb.reversal_awakened"), true)
	level.queue_free()
	await tree.process_frame
	# 死亡重試（只重設狀態）：回到第一次進霧前，生命照存檔的 55（不補滿），還沒覺醒
	_game().call("retry", false)
	assert_true(s.is_reboot(), "重試之後還是新版")
	assert_eq(s.state.checkpoint, "rb_before_mist")
	assert_eq(s.state.get_flag("rb.reversal_awakened", false), false, "回到覺醒之前")
	var level2: StoryLevel = await _load()
	await tree.process_frame
	var p2: PlayerController = level2.get_node("Player") as PlayerController
	assert_eq(p2.health.hp, RebootOpening.OPENING_HP, "生命照存檔（不補滿）")
	assert_false(p2.reversal.is_reversed("poison"), "反轉欄位照存檔（空的）")
	assert_false(bool(_game().call("is_in_dialogue")), "開場對話不重播")
	var rb2: RebootOpening = level2.get_node("RebootOpening") as RebootOpening
	assert_not_null(rb2.mist, "毒霧還在")
	assert_true(bool(level2.get_node("RbBarrel0").get_meta("broken", false)), "藥桶照樣是破的")
	assert_true(p2.global_position.z > -29.5 and p2.global_position.z < -25.0, "諾恩在石階上（霧的北邊）")
	assert_false(rb2.mist.contains(p2.global_position), "重來的位置不在毒霧裡")
	# 送葬者已經丟完：堵在北街（回頭路），那截燈柱躺在藥桶旁，不會再丟一次
	var u2: Undertaker = level2.get_node_or_null("RbPursuer") as Undertaker
	assert_not_null(u2, "重來：送葬者堵在北街")
	assert_eq(rb2.throw_phase, 3, "不會再丟一次")
	assert_true(u2.global_position.z < RebootOpening.PLAYER_CORNER_Z - 3.0, "牠在諾恩北邊（不在石階下、不在霧裡）")
	assert_true(rb2.lamp_chunk != null and rb2.lamp_chunk.get_parent() == level2, "那截燈柱躺在藥桶旁")
	level2.queue_free()
	await tree.process_frame


## 沒有開新遊戲的 session（benchmark、只看鎮的測試）：只有鎮，不掛劇情控制器（舊劇情第 77 輪刪了，D-220）
func test_town_without_a_story_session_has_no_reboot_controller() -> void:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	_game().set("session", s)
	var level: StoryLevel = await _load()
	assert_false(level.has_node("RebootOpening"), "沒開新遊戲：不掛劇情控制器")
	assert_false(level.has_node("RbGate"), "也沒有鐵門")
	assert_false(level.has_node("ConvoyTrigger"), "舊劇情的觸發點已經拿掉")
	level.queue_free()
	await tree.process_frame
