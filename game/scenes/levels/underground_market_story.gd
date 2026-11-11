class_name UndergroundMarketStory
extends Node
## 地下市場的劇情（第二段 A，docs/design/10-reboot-underground-market.md）：任務 rb_market。
## arrive：貨梯下來 → 走下坡道到街上（席菈說這裡的規矩）→ find_shop：走到街底的藥店門口 →
## test_board（D-231）：走進店裡到櫃台前 → 彌夏以為他來鬧事（rb2_misha_meet）→ 生命是滿的話她先扎一針 →
## 按住互動 2 秒把手放上測試板（弱的中毒：1／秒、6 秒）→ 指針甩到「回復」、綠燈亮 → 她願意談（rb2_misha_deal）
## → 「待續／黑市示範場」→ 回標題。
## 掛在 UndergroundMarket 底下（`Game.session.in_story()` 時）。沒有戰鬥，不會倒下；讀檔回到三個檢查點之一。

const QUEST: String = GameSession.MARKET_QUEST
## 檢查點 → 諾恩出生的位置與朝向（度；180＝面向南）
const SPAWNS: Dictionary = {
	"rb2_arrive": [Vector3(0.0, 0.0, -2.6), 180.0],
	"rb2_street": [Vector3(0.0, 0.0, UndergroundMarket.RAMP_S + 1.6), 180.0],
	"rb2_shop": [Vector3(-0.9, 0.0, UndergroundMarket.SHOP_Z - 7.0), 180.0],
	# 截圖用（--rb-at=board）：站在櫃台前、測試板的東邊半步（鏡頭在他右後方＝西邊，板子與彌夏才不會被他擋住）
	"dev_board": [Vector3(UndergroundMarket.BOARD_POS.x + 0.55, 0.0, UndergroundMarket.COUNTER_Z - 1.2), 180.0],
}
## 走過這條線＝到街上了
const STREET_LINE_Z: float = UndergroundMarket.RAMP_S + 0.6
## 離藥店的門多近算「到了」
const SHOP_RANGE: float = 2.4
## 「待續」的配樂（D-219）：卡出來時慢慢進來，回標題時跟著關卡一起收掉
const END_MUSIC: String = "part_end_theme"
const END_MUSIC_DB: float = -14.0
const END_MUSIC_FADE: float = 2.5
## 截圖旗標 `--level=market --rb-at=arrive|street|shop`：就是三個檢查點的出生位置（arrive＝貨梯下來的第一眼，固定鏡頭 60）；
## `board`＝已經跟彌夏講過話、站在測試板前（固定鏡頭 63）；`board_read`＝手放過了，指針在「回復」、綠燈亮
## --- 店內（test_board 階段）
## 離測試板多近彌夏開口／可以把手放上去
const MEET_RANGE: float = 2.3
const BOARD_RANGE: float = 1.5
## 手要按住多久（秒）；放開就歸零
const BOARD_HOLD_SEC: float = 2.0
## 指針甩過去之後，隔多久彌夏開口（讓人看得到生命條的綠色段）
const BOARD_READ_SEC: float = 3.0
## 生命是滿的時候她先用採樣針扎一下（直接傷害）：不然中毒回血補不到東西，什麼都看不到（D-213）
const NEEDLE_PRICK: float = 3.0
const BOARD_SOURCE: String = "test_board"
const BOARD_HINT_KEY: String = "RB2_BOARD_HINT"
const END_TITLE_KEY: String = "RB2_END2_TITLE"

var level: UndergroundMarket
var player: PlayerController
## 「待續」那張卡出來了（之後不再觸發任何東西）
var ending: bool = false
## 「待續」播完之後做什麼；空的＝回標題。測試換成自己的（不要真的換場景）
var end_done: Callable = Callable()
var end_music: AudioStreamPlayer
## 手按在測試板上幾秒了、板子讀了幾秒
var board_hold: float = 0.0
var board_read: float = 0.0


func _ready() -> void:
	add_to_group("interact_prompts")
	level = get_parent() as UndergroundMarket
	player = level.get_node_or_null("Player") as PlayerController
	# 前十分鐘做完的舊存檔在 GameSession.load_slot 已經補開這條任務；這裡再保險一次（已經開了就不動）
	if Game.session.quests.is_done(GameSession.MAIN_QUEST):
		Game.session.quests.start(QUEST)
	if player != null:
		var st: GameState = Game.session.state
		_place_player(str(st.get_flag("rb2.dev_spawn", st.checkpoint)))
		if bool(st.get_flag("rb2.board_done", false)):
			level.set_board_healing(true)
		# 席菈站在他斜前方（已經在往街上看）：不擋在鏡頭與街之間；人在店裡的話她站在門的西邊（不擋鏡頭）
		if player.global_position.z > UndergroundMarket.SHOP_INNER_Z:
			_spawn_sheila(Vector3(UndergroundMarket.SHOP_DOOR.x - 1.5, 0.0, UndergroundMarket.SHOP_INNER_Z + 1.3))
		else:
			_spawn_sheila(player.global_position + Vector3(1.7, 0.0, 1.1))
		player.snap_camera()


## 截圖、測試用：照正式流程設旗標，推到地下市場的那一段。arrive＝剛下貨梯；street＝走到街上了；shop＝到藥店門口了。
static func dev_advance(s: GameSession, at: String) -> void:
	FrostbridgeOpening.dev_advance(s, "lift")
	s.set_flag("rb.market_reached", true)
	if at in ["street", "shop"]:
		s.set_flag("rb2.street_reached", true)
		s.set_flag("rb2.rules_heard", true)
	if at in ["shop", "board", "board_read"]:
		s.set_flag("rb2.shop_reached", true)
	if at in ["board", "board_read"]:
		s.set_flag("rb2.misha_met", true)
		s.set_flag("rb2.pricked", true)
		s.set_flag("rb2.dev_spawn", "dev_board")
	if at == "board_read":
		s.set_flag("rb2.board_done", true)


func stage() -> String:
	return Game.session.quests.stage_of(QUEST)


func _physics_process(delta: float) -> void:
	if player == null or ending or Game.is_player_locked():
		return
	var st: GameState = Game.session.state
	var pos: Vector3 = player.global_position
	# 這一段做完了（剛談完，或讀檔回來再走進店裡）：站在櫃台前就是「待續」
	if Game.session.quests.is_done(QUEST):
		if at_counter(pos):
			play_end_card()
		return
	match stage():
		"arrive":
			if pos.z >= STREET_LINE_Z:
				Game.session.set_flag("rb2.street_reached", true)
		"find_shop":
			# 第一次走到街上：席菈說這裡的規矩（讀檔回來不會再講一次）
			if not bool(st.get_flag("rb2.rules_heard", false)):
				Game.start_dialogue("rb2_sheila_rules")
			elif FrostbridgeOpening.flat_distance(pos, UndergroundMarket.SHOP_DOOR) <= SHOP_RANGE:
				Game.session.set_flag("rb2.shop_reached", true)
		"test_board":
			_tick_test_board(delta, st, pos)


## 在店裡、而且走到櫃台前了
func at_counter(pos: Vector3) -> bool:
	return pos.z > UndergroundMarket.SHOP_INNER_Z and FrostbridgeOpening.flat_distance(pos, UndergroundMarket.BOARD_POS) <= MEET_RANGE


## 現在可以把手放上測試板（講過話了、還沒測、人在板子前）
func board_ready() -> bool:
	if player == null or ending or stage() != "test_board":
		return false
	var st: GameState = Game.session.state
	if not bool(st.get_flag("rb2.pricked", false)) or bool(st.get_flag("rb2.board_done", false)):
		return false
	var pos: Vector3 = player.global_position
	return pos.z > UndergroundMarket.SHOP_INNER_Z and FrostbridgeOpening.flat_distance(pos, UndergroundMarket.BOARD_POS) <= BOARD_RANGE


func interact_hint() -> Dictionary:
	if not board_ready():
		return {}
	return {"fmt": TranslationServer.translate(BOARD_HINT_KEY), "action": "interact", "progress": clampf(board_hold / BOARD_HOLD_SEC, 0.0, 1.0)}


func _tick_test_board(delta: float, st: GameState, pos: Vector3) -> void:
	if not bool(st.get_flag("rb2.misha_met", false)):
		if at_counter(pos):
			# 生命是滿的：她的台詞多一句「先扎一針」（text_if），講完真的扎
			Game.session.set_flag("rb2.full_health", player.health.hp >= player.health.max_hp - 0.5)
			Game.start_dialogue("rb2_misha_meet")
		return
	if not bool(st.get_flag("rb2.pricked", false)):
		if bool(st.get_flag("rb2.full_health", false)):
			player.health.apply_damage(NEEDLE_PRICK, {"kind": "needle"})
		Game.session.set_flag("rb2.pricked", true)
		return
	if not bool(st.get_flag("rb2.board_done", false)):
		# 按住互動鍵：手放在板子上；放開或走開就歸零
		var holding: bool = board_ready() and Input.is_action_pressed("interact")
		board_hold = board_hold + delta if holding else 0.0
		level.set_board_progress(board_hold / BOARD_HOLD_SEC)
		if board_hold >= BOARD_HOLD_SEC:
			board_hold = 0.0
			# 同一個來源不疊加（StatusEffects）；反轉欄位裡有中毒 → 每秒回 1 點
			player.status_effects.apply_source(BOARD_SOURCE)
			Game.session.set_flag("rb2.board_done", true)
			level.set_board_healing(true)
		return
	# 板子在讀：指針甩到「回復」那一邊、綠燈亮；過幾秒彌夏才開口
	level.set_board_healing(true)
	board_read += delta
	if board_read >= BOARD_READ_SEC:
		Game.start_dialogue("rb2_misha_deal")


## 目前做到的地方的結尾：畫面淡成黑 →「待續／黑市示範場」→ 回標題。諾恩停住（黑幕底下不會被按鍵推著走）。
func play_end_card() -> ChapterCard:
	if ending:
		return level.get_node_or_null("ChapterCard") as ChapterCard
	ending = true
	if player != null:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	end_music = Ambience.music(level, END_MUSIC, END_MUSIC_DB, END_MUSIC_FADE, "RbEndMusic")
	return ChapterCard.play(level, "RB_END_NUMBER", END_TITLE_KEY, _on_end_card_done)


func _on_end_card_done() -> void:
	if end_done.is_valid():
		end_done.call()
	else:
		Game.back_to_title()


func _place_player(checkpoint: String) -> void:
	var spec: Array = SPAWNS.get(checkpoint, SPAWNS["rb2_arrive"]) as Array
	var pos: Vector3 = spec[0] as Vector3
	pos.y = level.ground_y(pos) + 0.05
	player.global_position = pos
	player.rotation.y = deg_to_rad(float(spec[1]))
	player.yaw = player.rotation.y


func _spawn_sheila(pos: Vector3) -> void:
	if level.has_node("Sheila"):
		return
	var ally := Sheila.new()
	ally.name = "Sheila"
	ally.position = Vector3(pos.x, level.ground_y(pos), pos.z)
	ally.rotation_degrees.y = 180.0
	level.add_child(ally)
