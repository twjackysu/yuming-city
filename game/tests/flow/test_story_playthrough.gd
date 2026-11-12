extends TestCase
## 新版《這些詛咒對我太有用了》前十分鐘一條龍（D-212）：從標題按「新遊戲」一路走到貨梯的「待續」。
## 每一段的細節各有測試（opening／guardian／potion／market）；這裡只驗「接得起來」：
## 標題 → 開場對話 → 送葬者追擊、藥桶破 → 毒霧覺醒 → 再踏回去確認 → 推車到南街口 → 席菈接應 →
## 南街守衛倒下 → 藥箱兩瓶 → 喝一瓶回血 → 艾妲的一半工錢 → 貨梯 → 地下市場（另一個關卡）→ 走下坡道、席菈說規矩 →
## 走到街底的藥店門口 → 待續卡 → 回標題。
## 中間倒下重來兩次：第一次進霧前（生命不補滿）、拿了藥之後（藥不重複領）——重來之後直接從檢查點接著走完。
## 另一個測試只用手把事件走一小段：左搖桿走到藥箱 → A 拿藥、A 讀完對話 → 十字鍵左喝藥。

const BOOT: String = "res://scenes/boot/boot.tscn"
const PATH: String = "res://scenes/levels/frostbridge.tscn"
const MARKET_PATH: String = "res://scenes/levels/underground_market.tscn"
const PAD: int = 0

var _dir: String = ""
var _original: GameSession
var _original_device: int = 0


func before_each() -> void:
	_dir = "user://test_rb_run_%d" % Time.get_ticks_usec()
	_original = tree.root.get_node("Game").get("session") as GameSession
	_original_device = int(App.last_device)


func after_each() -> void:
	tree.paused = false
	_stick(Vector2.ZERO)
	_pad_button(JOY_BUTTON_A, false)
	_pad_button(JOY_BUTTON_DPAD_LEFT, false)
	App.set_device(_original_device)
	tree.root.get_node("Game").set("session", _original)
	for d: String in [_dir, _dir + "_reboot"]:
		if DirAccess.dir_exists_absolute(d):
			for f: String in DirAccess.get_files_at(d):
				DirAccess.remove_absolute(d.path_join(f))
			DirAccess.remove_absolute(d)


func _session() -> GameSession:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", s)
	return s


func _game() -> Node:
	return tree.root.get_node("Game")


func _load() -> StoryLevel:
	var level: StoryLevel = (load(PATH) as PackedScene).instantiate() as StoryLevel
	tree.root.add_child(level)
	await tree.physics_frame
	await tree.process_frame
	return level


func _talking() -> bool:
	return bool(_game().call("is_in_dialogue"))


func _run_dialogue(level: Node, choice: int = 0) -> void:
	var box: DialogueBox = level.get_node("DialogueBox") as DialogueBox
	var choices: Node = box.find_child("Choices", true, false)
	for i: int in 80:
		if not _talking():
			break
		if choices.get_child_count() > 0:
			(choices.get_child(mini(choice, choices.get_child_count() - 1)) as Button).pressed.emit()
		else:
			box.press_continue()
		await tree.process_frame


func _frames(n: int) -> void:
	for i: int in n:
		await tree.physics_frame


func _park_sheila(level: Node) -> void:
	var sheila: Node3D = level.get_node_or_null("Sheila") as Node3D
	if sheila != null:
		sheila.set_physics_process(false)
		sheila.global_position = Vector3(-3.0, 0.05, 6.0)


func _stand(level: StoryLevel, at: Vector3) -> void:
	var player: PlayerController = level.get_node("Player") as PlayerController
	player.global_position = Vector3(at.x, level.ground_y(at) + 0.05, at.z)
	player.velocity = Vector3.ZERO


func _potions(s: GameSession) -> int:
	return int(s.state.items.get(PlayerController.PORTABLE_ITEM, 0))


func _coins(s: GameSession) -> int:
	return int(s.state.items.get(FrostbridgeOpening.WAGES_ITEM, 0))


func _stick(v: Vector2) -> void:
	for axis: int in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var ev := InputEventJoypadMotion.new()
		ev.device = PAD
		ev.axis = axis as JoyAxis
		ev.axis_value = v.x if axis == JOY_AXIS_LEFT_X else v.y
		Input.parse_input_event(ev)


func _pad_button(button: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = PAD
	ev.button_index = button
	ev.pressed = pressed
	ev.pressure = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


## 按一下：按下 → 等到物理幀跑過（拿藥、喝藥都在 _physics_process 裡看 just_pressed）→ 放開
func _tap(button: JoyButton) -> void:
	_pad_button(button, true)
	await tree.process_frame
	await tree.physics_frame
	await tree.physics_frame
	_pad_button(button, false)
	await tree.process_frame
	await tree.physics_frame


func test_new_game_to_lift_in_one_run() -> void:
	var s := _session()

	# --- 標題：「新遊戲」＝新版
	var boot: Control = (load(BOOT) as PackedScene).instantiate() as Control
	boot.set("load_levels", false)
	tree.root.add_child(boot)
	await tree.process_frame
	await tree.process_frame
	(boot.get_node("%NewGame") as Button).pressed.emit()
	assert_true(s.in_story(), "標題的新遊戲＝新版")
	assert_eq(s.state.checkpoint, "rb_start")
	assert_eq(str(_game().call("level_for_checkpoint", s.state.checkpoint)), "frostbridge", "從霜橋鎮開始")
	boot.queue_free()
	await tree.process_frame

	# --- 開場：鐵門、雷德、推車上的波克
	var level: StoryLevel = await _load()
	var rb: FrostbridgeOpening = level.get_node_or_null("FrostbridgeOpening") as FrostbridgeOpening
	assert_not_null(rb, "新版的霜橋鎮")
	if rb == null:
		level.queue_free()
		await tree.process_frame
		return
	var player: PlayerController = level.get_node("Player") as PlayerController
	var cart: Caravan = level.get_node("RbCart") as Caravan
	assert_true(_talking(), "開場對話")
	await _run_dialogue(level)
	assert_eq(s.quests.stage_of("rb_main"), "escape")
	assert_eq(player.health.hp, FrostbridgeOpening.OPENING_HP, "開場生命 55")
	await _frames(70)
	assert_true(level.has_node("RbPursuer"), "送葬者從屋頂跳下來追")

	# --- 推車到北街轉角：牠扔燈柱砸破藥桶、主街起毒霧、檢查點
	cart.runner.traveled = rb._corner_traveled - 0.3
	cart._sync()
	player.global_position = cart.global_position + Vector3(1.0, 0.05, 0.5)
	await _frames(130)
	assert_eq(s.state.get_flag("rb.barrels_broken"), true, "藥桶被砸破")
	assert_eq(s.state.checkpoint, "rb_before_mist", "第一次進霧前的檢查點")
	assert_not_null(rb.mist, "主街上一片毒霧")

	# --- 第一次重來：生命被打到 9 → 回到進霧前，生命照存檔（不是 9、也不是補滿）
	player.health.hp = 9.0
	level.queue_free()
	await tree.process_frame
	_game().call("retry", false)
	assert_true(s.in_story(), "重來之後還是新版")
	assert_eq(s.state.checkpoint, "rb_before_mist")
	level = await _load()
	rb = level.get_node("FrostbridgeOpening") as FrostbridgeOpening
	player = level.get_node("Player") as PlayerController
	cart = level.get_node("RbCart") as Caravan
	var hud: Hud = level.get_node("Hud") as Hud
	assert_false(_talking(), "開場對話不重播")
	assert_true(player.health.hp < player.health.max_hp, "重來不補滿血（%.0f）" % player.health.hp)
	assert_true(player.health.hp >= player.health.max_hp * PlayerController.RESTORE_MIN_HP_RATIO - 0.01, "至少一半（%.0f）" % player.health.hp)
	assert_not_null(rb.mist, "毒霧還在")
	assert_false(rb.mist.contains(player.global_position), "重來的位置不在霧裡")

	# --- 走進毒霧：中毒、自動覺醒、生命往上
	var hp0: float = player.health.hp
	player.global_position = FrostbridgeOpening.MIST_CENTER + Vector3(0.0, 0.05, 0.0)
	await _frames(40)
	assert_true(player.reversal.is_reversed("poison"), "第一次中毒：逆轉體質自動裝上")
	assert_eq(s.state.get_flag("rb.reversal_awakened"), true)
	assert_eq(hud.center_lines(), PackedStringArray(["RB_AWAKEN_LINE1", "RB_AWAKEN_LINE2"]), "畫面中間兩行字")
	assert_true(player.health.hp > hp0, "中毒卻回血（%.1f → %.1f）" % [hp0, player.health.hp])

	# --- 離開、毒效結束 → 再踏回去確認 → 霧散
	player.global_position = Vector3(0.9, 0.05, -12.0)
	await _frames(3)
	player.status_effects.clear("poison")
	await _frames(3)
	assert_true(_talking(), "「再踏回去一次」")
	await _run_dialogue(level)
	rb.mist_clear_sec = 0.1
	player.global_position = FrostbridgeOpening.MIST_CENTER + Vector3(1.0, 0.05, 2.0)
	await _frames(3)
	assert_eq(s.state.get_flag("rb.mist_reentered"), true, "再踏回去確認")
	await _run_dialogue(level)
	for i: int in 30:
		if rb.mist == null:
			break
		await tree.process_frame
	assert_eq(rb.mist, null, "確認完霧散了")

	# --- 推車到南街口 → 席菈接應 → 波克進店
	cart.runner.traveled = cart.runner.length() - 0.2
	cart._sync()
	player.global_position = cart.global_position + Vector3(1.0, 0.05, -0.5)
	await _frames(20)
	assert_eq(s.state.get_flag("rb.reached_south"), true, "推車到南街口")
	assert_eq(s.state.checkpoint, "rb_sheila")
	var sheila: Node3D = level.get_node_or_null("Sheila") as Node3D
	assert_not_null(sheila, "席菈從側門出來")
	if sheila == null:
		level.queue_free()
		await tree.process_frame
		return
	sheila.set_physics_process(false)
	player.global_position = sheila.global_position + Vector3(1.2, 0.05, 0.6)
	await _frames(3)
	assert_true(_talking(), "走近席菈 → 對話")
	await _run_dialogue(level, 1)
	assert_eq(s.quests.stage_of("rb_main"), "guardian_fight", "→ 和席菈打倒守衛")
	assert_eq(s.state.checkpoint, "rb_guardian")

	# --- 南街守衛：開打 → 倒下 → 席菈問名字
	_park_sheila(level)
	var g: Undertaker = level.get_node_or_null("RbGuardian") as Undertaker
	assert_not_null(g, "守衛從南街南端走過來")
	if g == null:
		level.queue_free()
		await tree.process_frame
		return
	rb.guardian_down_talk_sec = 0.2
	g.global_position = Vector3(0.2, 0.05, 17.0)
	player.global_position = Vector3(0.0, 0.05, 11.0)
	rb._engage_guardian()
	await _frames(2)
	g.health.apply_damage(g.health.hp, {"kind": "blunt", "stagger": 0.0})
	assert_eq(s.state.get_flag("rb.guardian_down"), true, "牠倒下")
	await _frames(30)
	assert_true(_talking(), "席菈：「名字。」")
	await _run_dialogue(level)
	assert_eq(s.quests.stage_of("rb_main"), "portable_poison", "→ 試用毒劑")
	assert_eq(s.state.checkpoint, "rb_portable", "撿藥之前的檢查點")

	# --- 藥箱落地 → 拿走兩瓶
	await _frames(int((FrostbridgeOpening.CRATE_DROP_DELAY + PotionCrate.DROP_SEC) * 60.0) + 12)
	var crate: PotionCrate = level.get_node_or_null("RbPotionCrate") as PotionCrate
	assert_not_null(crate, "牠背上的藥箱摔在旁邊")
	if crate == null:
		level.queue_free()
		await tree.process_frame
		return
	player.global_position = crate.global_position + Vector3(-0.6, 0.05, -1.3)
	await _frames(2)
	assert_true(crate.take(), "拿走藥瓶")
	assert_eq(_potions(s), 2, "兩瓶")
	await _run_dialogue(level)

	# --- 第二次重來：回到撿藥之前，藥跟著退回；再拿一次也只有兩瓶
	level.queue_free()
	await tree.process_frame
	_game().call("retry", false)
	assert_eq(s.state.checkpoint, "rb_portable")
	assert_eq(_potions(s), 0, "檢查點之後拿的藥跟著退回")
	level = await _load()
	_park_sheila(level)
	rb = level.get_node("FrostbridgeOpening") as FrostbridgeOpening
	player = level.get_node("Player") as PlayerController
	assert_false(level.has_node("RbGuardian"), "牠不會再站起來")
	crate = level.get_node_or_null("RbPotionCrate") as PotionCrate
	assert_not_null(crate, "藥箱還在原地")
	if crate == null:
		level.queue_free()
		await tree.process_frame
		return
	player.global_position = crate.global_position + Vector3(-0.6, 0.05, -1.3)
	await _frames(2)
	assert_true(crate.take())
	await _run_dialogue(level)
	assert_eq(_potions(s), 2, "再拿一次也只有兩瓶（不是四瓶）")
	assert_false(crate.take(), "不能重複領")

	# --- 喝一瓶：中毒＝回血 → 席菈「你在喝什麼？」→ 去貨梯
	rb.potion_talk_sec = 0.1
	player.health.hp = 60.0
	assert_eq(player.use_potion(), "used")
	assert_eq(_potions(s), 1)
	await _frames(20)
	assert_true(player.health.hp > 60.0, "喝毒回血（%.1f）" % player.health.hp)
	await _run_dialogue(level)
	assert_eq(s.quests.stage_of("rb_main"), "market_lead", "→ 去地下市場的貨梯")
	assert_eq(s.state.checkpoint, "rb_market")

	# --- 艾妲：一半工錢 → 貨梯 → 換到地下市場
	var done: Array[int] = [0]
	rb.end_done = func() -> void: done[0] += 1
	_stand(level, FrostbridgeOpening.ADA_POS + Vector3(-1.2, 0.0, 1.6))
	await _frames(6)
	assert_true(_talking(), "走近梨攤：艾妲開口")
	await _run_dialogue(level)
	await _frames(2)
	assert_eq(_coins(s), FrostbridgeOpening.WAGES, "一半的工錢")
	_stand(level, FrostbridgeOpening.LIFT_POS + Vector3(-0.3, 0.0, 0.4))
	await _frames(6)
	assert_true(bool(s.state.get_flag("rb.market_reached", false)), "站上貨梯")
	assert_true(s.quests.is_done("rb_main"), "前十分鐘走完了")
	assert_true(bool(s.state.get_flag("rb.first_ten_done", false)))
	var card: ChapterCard = level.get_node_or_null("ChapterCard") as ChapterCard
	assert_not_null(card, "貨梯往下的卡")
	if card != null:
		assert_eq(card.title_text(), tr("RB_END_TITLE"))
		card.finish()
	assert_eq(done[0], 1, "卡播完 → 換關卡")
	assert_eq(str(_game().call("level_for_checkpoint", s.state.checkpoint)), "market", "下一個關卡是地下市場")
	var hp_before: float = player.health.hp
	level.queue_free()
	await tree.process_frame

	# --- 地下市場：高台 → 坡道 → 街上（席菈說規矩）→ 藥店門口 → 進店、測試板 → 待續 → 回標題
	var market: UndergroundMarket = (load(MARKET_PATH) as PackedScene).instantiate() as UndergroundMarket
	tree.root.add_child(market)
	await tree.physics_frame
	await tree.process_frame
	_park_sheila(market)
	var story: UndergroundMarketStory = market.get_node_or_null("UndergroundMarketStory") as UndergroundMarketStory
	assert_not_null(story, "地下市場的劇情掛上了")
	var p2: PlayerController = market.get_node("Player") as PlayerController
	assert_true(absf(p2.global_position.y - UndergroundMarket.TERRACE_Y) < 0.3, "從貨梯的高台開始（%s）" % p2.global_position)
	# 存檔在站上貨梯的那一刻；卡播完之前身上的毒還在跳，所以差一兩點
	assert_true(absf(p2.health.hp - hp_before) < 3.0, "生命照帶過來（%.1f → %.1f）" % [hp_before, p2.health.hp])
	assert_true(p2.health.hp < p2.health.max_hp - 10.0, "換關卡不補滿（%.1f／%.1f）" % [p2.health.hp, p2.health.max_hp])
	assert_eq(_potions(s), 1, "藥照帶過來")
	assert_eq(s.objective_key(), "Q_RB2_OBJ_ARRIVE")
	var ended: Array[int] = [0]
	story.end_done = func() -> void: ended[0] += 1
	_stand(market, Vector3(0.0, 0.0, UndergroundMarket.RAMP_S + 1.4))
	await _frames(6)
	assert_eq(s.quests.stage_of("rb_market"), "find_shop", "走到街上")
	assert_eq(s.state.checkpoint, "rb2_street")
	assert_true(_talking(), "席菈說這裡的規矩")
	await _run_dialogue(market)
	await _frames(2)
	assert_false(market.has_node("ChapterCard"), "還沒到藥店")
	_stand(market, UndergroundMarket.SHOP_DOOR + Vector3(0.3, 0.0, -1.2))
	await _frames(6)
	assert_eq(s.quests.stage_of("rb_market"), "test_board", "到藥店門口")
	assert_eq(s.state.checkpoint, "rb2_shop")
	assert_false(market.has_node("ChapterCard"), "門口不是結尾：還要進店")
	# 進店 → 彌夏 → 按住互動 2 秒把手放上測試板 → 中毒回血、指針往「回復」→ 她願意談 → 待續
	var hp_shop: float = p2.health.hp
	_stand(market, UndergroundMarket.BOARD_POS + Vector3(-0.3, 0.0, -1.0))
	await _frames(4)
	assert_true(_talking(), "彌夏開口")
	await _run_dialogue(market)
	await _frames(4)
	assert_true(absf(p2.health.hp - hp_shop) < 3.0, "身上有傷：不扎針（%.1f → %.1f）" % [hp_shop, p2.health.hp])
	Input.action_press("interact")
	await _frames(int(UndergroundMarketStory.BOARD_HOLD_SEC * 60.0) + 6)
	Input.action_release("interact")
	assert_true(bool(s.state.get_flag("rb2.board_done", false)), "手放滿 2 秒")
	assert_true(p2.status_effects.has("poison"), "測試板下的毒")
	var hp_board: float = p2.health.hp
	await _frames(int(UndergroundMarketStory.BOARD_READ_SEC * 60.0) + 6)
	assert_true(p2.health.hp > hp_board + 1.5, "中毒 → 回血（%.1f → %.1f）" % [hp_board, p2.health.hp])
	assert_true(market.board_lamp_on and market.board_needle_deg() > 30.0, "指針在「回復」、綠燈亮")
	assert_true(_talking(), "彌夏願意談")
	await _run_dialogue(market)
	await _frames(4)
	assert_true(s.quests.is_done("rb_market"), "地下市場這一段做完")
	assert_false(market.has_node("ChapterCard"), "藥店不是結尾：還要去黑市示範場")
	assert_eq(s.quests.stage_of("rb_demo"), "go_demo")
	# 出店門往北走到示範台前 → 商人叫賣、諾恩看出他賣的是解藥 → 席菈「這個我會」→ 守衛戰 → 拿到護腕 → 待續
	_stand(market, UndergroundMarket.SHOP_DOOR + Vector3(0.0, 0.0, -2.0))
	await _frames(6)
	assert_false(_talking(), "店門外還聽不到叫賣")
	_stand(market, UndergroundMarket.DEMO_POS + Vector3(3.0, 0.0, 2.0))
	await _frames(4)
	assert_true(_talking(), "商人的叫賣")
	await _run_dialogue(market)
	await _frames(4)
	assert_eq(s.quests.stage_of("rb_demo"), "stop_demo", "聽完了")
	assert_eq(s.state.checkpoint, "rb2_demo_fight")
	# 守衛戰（D-233）：聽完還站在台前 → 開打（不是待續）→ 兩個守衛都倒下 → 商人把護腕丟過來 → 待續
	var mstory: UndergroundMarketStory = market.story
	assert_true(mstory.fight_started, "聽完就開打")
	assert_false(market.has_node("ChapterCard"), "還沒到結尾")
	assert_eq(mstory.guards.size(), 2, "兩個守衛")
	for dg: DemoGuard in mstory.guards:
		dg.set_physics_process(false)
		dg.health.apply_damage(dg.health.hp, {"source": p2})
	await _frames(4)
	assert_true(s.quests.is_done("rb_demo"), "兩個都倒下：這一段做完")
	assert_false(_talking(), "隔一下商人才開口")
	await _frames(int(UndergroundMarketStory.WON_TALK_SEC * 60.0) + 12)
	assert_true(_talking(), "商人認輸")
	await _run_dialogue(market)
	await _frames(4)
	assert_eq(s.state.grants.count(UndergroundMarketStory.BRACER_GRANT), 1, "拿到護腕，只有一個")
	var end_card: ChapterCard = market.get_node_or_null("ChapterCard") as ChapterCard
	assert_not_null(end_card, "待續的卡")
	if end_card != null:
		assert_eq(end_card.title_text(), tr("RB2_END4_TITLE"))
		end_card.finish()
	assert_eq(ended[0], 1, "卡播完 → 回標題")
	# 一路走完：狀態不會留一堆、藥還剩一瓶、工錢只有一份
	assert_true(p2.status_effects.to_array().size() <= 1, "身上最多只有一個中毒（不疊加）")
	assert_eq(_potions(s), 1)
	assert_eq(_coins(s), FrostbridgeOpening.WAGES)
	market.queue_free()
	await tree.process_frame


## 只用手把事件：左搖桿走到藥箱 → A 拿藥 → A 讀完諾恩那兩句 → 十字鍵左喝一瓶
func test_gamepad_walks_to_crate_takes_and_drinks() -> void:
	var s := _session()
	s.new_game()
	FrostbridgeOpening.dev_advance(s, "potion")
	var level: StoryLevel = await _load()
	_park_sheila(level)
	var rb: FrostbridgeOpening = level.get_node("FrostbridgeOpening") as FrostbridgeOpening
	var player: PlayerController = level.get_node("Player") as PlayerController
	var crate: PotionCrate = level.get_node_or_null("RbPotionCrate") as PotionCrate
	assert_not_null(crate, "藥箱在南街上")
	if crate == null:
		level.queue_free()
		await tree.process_frame
		return
	rb.potion_talk_sec = 30.0
	await _frames(5)
	assert_false(crate.is_near(), "一開始離藥箱還有一段（%s）" % player.global_position)

	# --- 左搖桿朝藥箱走（依鏡頭 yaw 換算方向），走到提示出現
	var start: Vector3 = player.global_position
	for i: int in 900:
		if crate.is_near():
			break
		var d := Vector3(crate.global_position.x - player.global_position.x, 0.0, crate.global_position.z - player.global_position.z)
		var local: Vector3 = Basis(Vector3.UP, -player.yaw) * d.normalized()
		_stick(Vector2(local.x, local.z))
		await tree.physics_frame
	_stick(Vector2.ZERO)
	await _frames(3)
	assert_true(crate.is_near(), "左搖桿走到藥箱旁（停在 %s）" % player.global_position)
	assert_true(FrostbridgeOpening.flat_distance(start, player.global_position) > 2.0, "是自己走過去的")
	assert_eq(int(App.last_device), int(InputGlyphs.Device.PAD), "動了搖桿 → 畫面提示換成手把")

	# --- A：拿藥；A：讀完對話
	await _tap(JOY_BUTTON_A)
	assert_true(crate.taken, "A 拿走藥瓶")
	assert_eq(_potions(s), 2)
	for i: int in 40:
		if not _talking():
			break
		await _tap(JOY_BUTTON_A)
	assert_false(_talking(), "A 把諾恩那兩句讀完")
	assert_eq(_potions(s), 2, "讀對話的 A 不會再拿一次")

	# --- 十字鍵左：喝一瓶
	player.health.hp = 60.0
	await _tap(JOY_BUTTON_DPAD_LEFT)
	assert_eq(_potions(s), 1, "十字鍵左喝一瓶")
	assert_true(player.status_effects.has("poison"), "喝下去＝中毒")
	assert_eq(s.state.get_flag("rb.potion_tried"), true)
	await _frames(20)
	assert_true(player.health.hp > 60.0, "回血（%.1f）" % player.health.hp)
	level.queue_free()
	await tree.process_frame
