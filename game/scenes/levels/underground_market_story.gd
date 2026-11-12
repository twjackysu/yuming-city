class_name UndergroundMarketStory
extends Node
## 地下市場的劇情（第二段 A，docs/design/10-reboot-underground-market.md）：任務 rb_market。
## arrive：貨梯下來 → 走下坡道到街上（席菈說這裡的規矩）→ find_shop：走到街底的藥店門口 →
## test_board（D-231）：走進店裡到櫃台前 → 彌夏以為他來鬧事（rb2_misha_meet）→ 生命是滿的話她先扎一針 →
## 按住互動 2 秒把手放上測試板（弱的中毒：1／秒、6 秒）→ 指針甩到「回復」、綠燈亮 → 她願意談（rb2_misha_deal）
## → 任務 rb_demo（第二段 B，D-232）：go_demo：走出藥店、往北走到街中段的示範台 → 商人當眾賣「高速護腕」
## （rb2_demo_pitch：諾恩看出他賣的其實是解藥）→ stop_demo（D-233）：再走近 → 席菈「再示範一次。這次不准喝解藥。」
## → 兩個守衛（DemoGuard：台下拿棍子的、台上戴護腕的）打過來，看熱鬧的人退開、商人縮到台子後面 → 兩個都倒下
## → rb2.demo_won（任務做完）→ 對話 rb2_demo_won（商人把護腕丟過來）→ rb2.bracer_taken、拿到護腕（一次）
## 倒下重試回 rb2_demo_fight：守衛滿血重來，諾恩的生命照存檔、不補滿。
## → 任務 rb_bracer（第二段 C 的前半，D-234）：back_to_shop：走回藥店的櫃台前 → 彌夏要他先在板子上試（rb2_bracer_ask）
## → test_bracer：按住互動 2 秒 → 麻痺解鎖、裝進第二格（麻痺 → 出手加速）→ 彌夏講結果（rb2_bracer_result）
## → 任務 rb_trial（第二段 C 的後半第一輪，D-235）：leave_shop：走出藥店 → 護腕商人帶了三個人堵在街上（兩個拿棍子的、
## 一個丟毒瓶的；rb2_trial_ambush）→ trial_fight：三個都倒下（毒霧＝回血、戴著護腕打中人＝繼續出手加速）
## → rb2.trial_won（任務做完）→ 席菈、彌夏各一句（rb2_trial_won）→ 「待續／乾運河」→ 回標題。
## 掛在 UndergroundMarket 底下（`Game.session.in_story()` 時）。

const QUEST: String = GameSession.MARKET_QUEST
const DEMO_QUEST: String = GameSession.DEMO_QUEST
const BRACER_QUEST: String = GameSession.BRACER_QUEST
const TRIAL_QUEST: String = GameSession.TRIAL_QUEST
## 檢查點 → 諾恩出生的位置與朝向（度；180＝面向南）
const SPAWNS: Dictionary = {
	"rb2_arrive": [Vector3(0.0, 0.0, -2.6), 180.0],
	"rb2_street": [Vector3(0.0, 0.0, UndergroundMarket.RAMP_S + 1.6), 180.0],
	"rb2_shop": [Vector3(-0.9, 0.0, UndergroundMarket.SHOP_Z - 7.0), 180.0],
	# 截圖用（--rb-at=board）：站在櫃台前、測試板的東邊半步（鏡頭在他右後方＝西邊，板子與彌夏才不會被他擋住）
	"dev_board": [Vector3(UndergroundMarket.BOARD_POS.x + 0.55, 0.0, UndergroundMarket.COUNTER_Z - 1.2), 180.0],
	# 黑市示範場（任務 rb_demo）：談完之後讀檔＝站在藥店門外、面向北（街的方向）
	"rb2_demo": [Vector3(UndergroundMarket.SHOP_DOOR.x, 0.0, UndergroundMarket.SHOP_Z - 2.2), 0.0],
	# 聽完叫賣之後讀檔＝示範台南邊幾步、街心偏西、斜對著台子（離台子比 DEMO_RANGE 遠：不會一讀檔就觸發；
	# 鏡頭在他右後方，要留在街上——再往東站鏡頭會跑進東側的攤子裡，被柱子擋住）
	"rb2_demo_fight": [Vector3(-0.8, 0.0, UndergroundMarket.DEMO_Z + 4.7), 28.0],
	# 試戴護腕（任務 rb_bracer，D-234）：拿到護腕之後讀檔＝示範台南邊幾步、面向南（藥店的方向）
	"rb2_bracer": [Vector3(-0.8, 0.0, UndergroundMarket.DEMO_Z + 4.7), 180.0],
	# 彌夏答應讓他試之後讀檔＝櫃台前、測試板的東邊半步（跟 dev_board 同一個站位，固定鏡頭 66 也用這裡）
	"rb2_bracer_board": [Vector3(UndergroundMarket.BOARD_POS.x + 0.55, 0.0, UndergroundMarket.COUNTER_Z - 1.2), 180.0],
	# 小戰檢驗（任務 rb_trial，D-235）：彌夏講完結果之後讀檔＝櫃台前（跟 rb2_bracer_board 同一個站位）
	"rb2_trial": [Vector3(UndergroundMarket.BOARD_POS.x + 0.55, 0.0, UndergroundMarket.COUNTER_Z - 1.2), 180.0],
	# 商人喊完話之後讀檔（倒下重試）＝藥店門外、面向北（他們從街上走過來）
	"rb2_trial_fight": [Vector3(UndergroundMarket.SHOP_DOOR.x, 0.0, UndergroundMarket.SHOP_Z - 2.2), 0.0],
	# 截圖用（--rb-at=trial_hold，固定鏡頭 67）：藥店門外幾步、街心偏西、面向北，站在一團毒霧裡
	"dev_trial": [Vector3(-1.3, 0.0, UndergroundMarket.SHOP_Z - 4.6), 6.0],
	# 截圖用（--rb-at=demo，固定鏡頭 64）：跟上面同一個站位，還沒聽叫賣
	"dev_demo": [Vector3(-0.8, 0.0, UndergroundMarket.DEMO_Z + 4.7), 28.0],
	# 截圖用（--rb-at=bracer_read，固定鏡頭 66）：櫃台前，剛試完護腕
	"dev_bracer_read": [Vector3(UndergroundMarket.BOARD_POS.x + 0.55, 0.0, UndergroundMarket.COUNTER_Z - 1.2), 180.0],
	# 截圖用（--rb-at=fight，固定鏡頭 65）：同一個站位，守衛戰打到一半（兩個守衛停在姿勢上）
	"dev_fight": [Vector3(-0.8, 0.0, UndergroundMarket.DEMO_Z + 4.7), 28.0],
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
## --- 黑市示範場（任務 rb_demo）
## 離示範台多近商人的叫賣聽得到（對話 rb2_demo_pitch）／「待續」
const DEMO_RANGE: float = 4.6
const END_TITLE_KEY: String = "RB2_END6_TITLE"
## --- 示範場的守衛戰（D-233）
const FIGHT_BANNER_KEY: String = "RB2_DEMO_FIGHT_START"
const FIGHT_BANNER_SEC: float = 6.0
const SHEILA_CALL_KEY: String = "RB2_SHEILA_DEMO_CALL"
## 兩個都倒下之後隔多久商人開口
const WON_TALK_SEC: float = 1.6
## 護腕只拿一次（GameState.grant_once）
const BRACER_GRANT: String = "rb2_demo_bracer"
## --- 試戴護腕（任務 rb_bracer，D-234）
const BRACER_HINT_KEY: String = "RB2_BRACER_HINT"
## 測試板上戴著護腕的那隻手：麻痺（出手 1.35 倍、12 秒；同一來源不疊加）
const BRACER_SOURCE: String = "bracer_test"
const PARALYSIS: String = StatusEffects.PARALYSIS
const SLOT2_LINE1_KEY: String = "RB2_SLOT2_LINE1"
const SLOT2_LINE2_KEY: String = "RB2_SLOT2_LINE2"
const SLOT2_LINES_SEC: float = 4.5
## 麻痺裝進哪一格（0 起算）
const SECOND_SLOT: int = 1
## --- 小戰檢驗：兩格一起用（任務 rb_trial，D-235）
## 戴著護腕打中人：麻痺重新計時（出手 1.35 倍、6 秒；同一來源只有一份）
const BRACER_HIT_SOURCE: String = "bracer_hit"
## 走出藥店的門多遠算「到街上了」（商人開口）
const TRIAL_DOOR_OUT: float = 0.9
const TRIAL_BANNER_KEY: String = "RB2_TRIAL_FIGHT_START"
const TRIAL_BANNER_SEC: float = 7.0
const SHEILA_TRIAL_KEY: String = "RB2_SHEILA_TRIAL_CALL"

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
var _sheila_sent_out: bool = false
## 守衛戰：開打了沒（不存檔——讀檔、倒下重試都從頭打）、場上的兩個守衛、打贏之後過了幾秒
var fight_started: bool = false
var guards: Array[DemoGuard] = []
var won_t: float = 0.0
## 試戴護腕：板子讀了幾秒（> 0＝這一次開機剛試完）；諾恩手上的護腕（戴上才有）
var bracer_read: float = 0.0
var worn_bracer: Node3D = null
## 截圖用：停在剛試完的那一刻（彌夏不開口）
var dev_hold_read: bool = false
## 小戰檢驗：商人帶來的人（站出來了沒、開打了沒——都不存檔，讀檔、倒下重試整個重來）、打贏之後過了幾秒
var trial_guards: Array[DemoGuard] = []
var trial_started: bool = false
var trial_won_t: float = 0.0


func _ready() -> void:
	add_to_group("interact_prompts")
	level = get_parent() as UndergroundMarket
	player = level.get_node_or_null("Player") as PlayerController
	# 前十分鐘做完的舊存檔在 GameSession.load_slot 已經補開這條任務；這裡再保險一次（已經開了就不動）
	if Game.session.quests.is_done(GameSession.MAIN_QUEST):
		Game.session.quests.start(QUEST)
	if player != null:
		var st: GameState = Game.session.state
		var spawn: String = str(st.get_flag("rb2.dev_spawn", st.checkpoint))
		_place_player(spawn)
		# 截圖、測試直接跳到小戰：兩格都裝好（正式流程是開場的毒霧＋測試板上試護腕）
		if bool(st.get_flag("rb2.dev_equip", false)):
			for sid: String in ["poison", PARALYSIS]:
				player.reversal.unlock(sid)
				player.reversal.equip(sid)
		if bool(st.get_flag("rb2.board_done", false)):
			level.set_board_healing(true)
		# 席菈站在他斜前方（已經在往街上看）：不擋在鏡頭與街之間；人在店裡的話她站在門的西邊（不擋鏡頭）
		if player.global_position.z > UndergroundMarket.SHOP_INNER_Z:
			_spawn_sheila(Vector3(UndergroundMarket.SHOP_DOOR.x - 1.5, 0.0, UndergroundMarket.SHOP_INNER_Z + 1.3))
		elif absf(player.rotation_degrees.y) < 90.0:
			# 面向北（示範場那兩個檢查點）：她在他右前方、靠街的東邊（站近一點會剛好擋在鏡頭與示範台中間）
			_spawn_sheila(player.global_position + Vector3(2.7, 0.0, -1.7))
		else:
			_spawn_sheila(player.global_position + Vector3(1.7, 0.0, 1.1))
		# 讀檔回來已經打贏了：場上直接是打完的樣子（守衛不在、看熱鬧的人在遠處、商人縮在台子後面）
		if bool(st.get_flag("rb2.demo_won", false)):
			level.begin_demo_fight(true)
		# 讀檔回來已經試戴過了：護腕在他手上
		if bool(st.get_flag("rb2.bracer_tested", false)):
			_wear_bracer()
		player.snap_camera()
		if str(st.get_flag("rb2.dev_spawn", "")) == "dev_fight":
			_dev_hold_fight()
		elif str(st.get_flag("rb2.dev_spawn", "")) == "dev_bracer_read":
			_dev_bracer_read()
		elif str(st.get_flag("rb2.dev_spawn", "")) == "dev_trial":
			_dev_hold_trial()


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
	# deal＝跟彌夏談完了（rb_market 做完、rb_demo 開始，站在藥店門外）；demo＝走到示範台前幾步、還沒聽叫賣（固定鏡頭 64）；
	# demo_end＝聽完了（現在的結尾：走近就是「待續」）
	# fight＝守衛戰打到一半（固定鏡頭 65：拿棍子的停在橫掃的前兆、戴護腕的剛打完一拳手麻了）；demo_won＝兩個都打倒了、還沒拿護腕
	# bracer＝拿到護腕了、站在示範台南邊（rb_bracer 剛開始）；bracer_ask＝彌夏答應了、站在櫃台前還沒試；
	# bracer_read＝剛試完（固定鏡頭 66：指針在綠色、第二格亮著、護腕在手上）
	# trial＝彌夏講完結果了、站在櫃台前（rb_trial 剛開始）；trial_fight＝商人喊完話了（藥店門外，一進場就開打）；
	# trial_hold＝打到一半停住（固定鏡頭 67）；trial_won＝三個都倒了、還沒講話
	var trial: bool = at in ["trial", "trial_fight", "trial_hold", "trial_won"]
	if trial or at in ["deal", "demo", "demo_end", "fight", "demo_won", "bracer", "bracer_ask", "bracer_read"]:
		for flag: String in ["rb2.street_reached", "rb2.rules_heard", "rb2.shop_reached", "rb2.misha_met", "rb2.pricked", "rb2.board_done", "rb2.first_shop_done"]:
			s.set_flag(flag, true)
	if at == "demo":
		s.set_flag("rb2.dev_spawn", "dev_demo")
	if trial or at in ["demo_end", "fight", "demo_won", "bracer", "bracer_ask", "bracer_read"]:
		s.set_flag("rb2.pitch_heard", true)
	if at == "fight":
		s.set_flag("rb2.dev_spawn", "dev_fight")
	if trial or at in ["demo_won", "bracer", "bracer_ask", "bracer_read"]:
		s.set_flag("rb2.demo_won", true)
	if trial or at in ["bracer", "bracer_ask", "bracer_read"]:
		s.set_flag("rb2.bracer_taken", true)
		s.state.grant_once(BRACER_GRANT)
		s.quests.start(BRACER_QUEST)
		s.advance()
	if trial or at in ["bracer_ask", "bracer_read"]:
		s.set_flag("rb2.bracer_asked", true)
	if at == "bracer_read":
		s.set_flag("rb2.dev_spawn", "dev_bracer_read")
	if trial:
		s.set_flag("rb2.bracer_tested", true)
		s.set_flag("rb2.dev_equip", true)
		s.set_flag("rb2.bracer_done", true)
	if at in ["trial_fight", "trial_hold", "trial_won"]:
		s.set_flag("rb2.trial_called", true)
	if at == "trial_hold":
		s.set_flag("rb2.dev_spawn", "dev_trial")
	if at == "trial_won":
		s.set_flag("rb2.trial_won", true)


func stage() -> String:
	return Game.session.quests.stage_of(QUEST)


func _physics_process(delta: float) -> void:
	if player == null or ending or Game.is_player_locked():
		return
	var st: GameState = Game.session.state
	var pos: Vector3 = player.global_position
	# 藥店那一段做完了：接黑市示範場（任務 rb_demo）
	if Game.session.quests.is_done(QUEST):
		_tick_demo(delta, pos)
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


## 黑市示範場（design/10「B 的流程」）。go_demo：走到示範台附近 → 商人的叫賣；stop_demo：守衛戰（D-233）。
func _tick_demo(delta: float, pos: Vector3) -> void:
	# 剛談完人還在店裡：席菈先到門外等（她是直線跟人，站在 1.3 m 寬的門洞裡會把人堵在店裡）
	if not _sheila_sent_out and pos.z > UndergroundMarket.SHOP_INNER_Z:
		_sheila_sent_out = true
		_send_sheila_outside()
	if Game.session.quests.is_done(DEMO_QUEST):
		_tick_demo_won(delta, pos)
		return
	match Game.session.quests.stage_of(DEMO_QUEST):
		"go_demo":
			if near_demo(pos):
				Game.start_dialogue("rb2_demo_pitch")
		"stop_demo":
			if not fight_started:
				if near_demo(pos):
					start_demo_fight()
			elif guards_down():
				Game.session.set_flag("rb2.demo_won", true)


## 打贏了：隔一下商人開口（rb2_demo_won，最後一句設 rb2.bracer_taken）→ 拿到護腕（只有一次）→「待續／試戴護腕」。
## 讀檔回來（已經打贏、還沒講完）：走近示範台才講，不會一讀檔就開口。
func _tick_demo_won(delta: float, pos: Vector3) -> void:
	var st: GameState = Game.session.state
	if not bool(st.get_flag("rb2.bracer_taken", false)):
		if fight_started:
			won_t += delta
			if won_t >= WON_TALK_SEC:
				Game.start_dialogue("rb2_demo_won")
		elif near_demo(pos):
			Game.start_dialogue("rb2_demo_won")
		return
	# 拿到護腕的那一刻：護腕只給一次、開下一條任務（回藥店試戴，D-234）、存一次——「繼續」回來不會再聽一次、也不會再拿一次
	if st.grant_once(BRACER_GRANT):
		Game.session.quests.start(BRACER_QUEST)
		Game.session.save(GameSession.AUTO_SLOT)
	_tick_bracer(delta, st, pos)


## 試戴護腕（design/10「C 的流程」前半，D-234）。back_to_shop：走回藥店的櫃台前 → 彌夏：先在板子上試（rb2_bracer_ask）
## → test_bracer：按住互動 2 秒把戴著護腕的手放上測試板 → 麻痺解鎖、裝進第二格（反轉：出手加速）→ 板子的指針翻到「回復」
## → 幾秒後 rb2_bracer_result（最後一句設 rb2.bracer_done＝任務做完、自動存檔）→「待續／兩格一起用」。
func _tick_bracer(delta: float, st: GameState, pos: Vector3) -> void:
	if Game.session.quests.is_done(BRACER_QUEST):
		_tick_trial(delta, st, pos)
		return
	match Game.session.quests.stage_of(BRACER_QUEST):
		"back_to_shop":
			if at_counter(pos):
				Game.start_dialogue("rb2_bracer_ask")
		"test_bracer":
			if not bool(st.get_flag("rb2.bracer_tested", false)):
				# 按住互動鍵：戴著護腕的手放在板子上（指針先往「受傷」那邊擺）；放開或走開就歸零
				var holding: bool = bracer_ready() and Input.is_action_pressed("interact")
				board_hold = board_hold + delta if holding else 0.0
				level.set_board_progress(board_hold / BOARD_HOLD_SEC)
				if board_hold >= BOARD_HOLD_SEC:
					board_hold = 0.0
					reverse_paralysis()
					Game.session.set_flag("rb2.bracer_tested", true)
				return
			level.set_board_healing(true)
			if dev_hold_read:
				return
			bracer_read += delta
			if bracer_read >= BOARD_READ_SEC:
				Game.start_dialogue("rb2_bracer_result")


## 安全測試的結果：麻痺解鎖、裝進第二格（已經裝了就不會再裝一次），板子給的麻痺從第一幀起就是反轉的（出手加速）。
## 同一個來源不疊加（StatusEffects）；畫面中央兩行字、護腕戴到他手上。
func reverse_paralysis() -> void:
	player.reversal.unlock(PARALYSIS)
	# 指定第二格（第一格是開場的中毒）；第二格被別的佔了才找其他空格。已經裝了就不會再裝
	var second_free: bool = player.reversal.slots > SECOND_SLOT and player.reversal.equipped[SECOND_SLOT] == ""
	player.reversal.equip(PARALYSIS, SECOND_SLOT if second_free else -1)
	player.status_effects.apply_source(BRACER_SOURCE)
	level.set_board_healing(true)
	_wear_bracer()
	var hud: Hud = level.get_node_or_null("Hud") as Hud
	if hud != null:
		hud.show_center_lines(SLOT2_LINE1_KEY, SLOT2_LINE2_KEY, SLOT2_LINES_SEC)


## 現在可以把戴著護腕的手放上測試板（彌夏答應了、還沒試、人在板子前）
func bracer_ready() -> bool:
	if player == null or ending or Game.session.quests.stage_of(BRACER_QUEST) != "test_bracer":
		return false
	if bool(Game.session.state.get_flag("rb2.bracer_tested", false)):
		return false
	var pos: Vector3 = player.global_position
	return pos.z > UndergroundMarket.SHOP_INNER_Z and FrostbridgeOpening.flat_distance(pos, UndergroundMarket.BOARD_POS) <= BOARD_RANGE


## 護腕戴到諾恩的右前臂上（冷光的兩圈；只有一個）
func _wear_bracer() -> void:
	if worn_bracer != null or player == null or player.puppet() == null:
		return
	var elbow: Node3D = player.puppet().joint("elbow_R")
	if elbow == null:
		return
	worn_bracer = level.worn_bracer()
	worn_bracer.name = "NoenBracer"
	elbow.add_child(worn_bracer)
	# 戴著它打中人：麻痺重新計時（裝在反轉欄位裡才會，D-235）
	player.on_hit_source = BRACER_HIT_SOURCE


## 截圖用（--rb-at=bracer_read，固定鏡頭 66）：剛試完——第二格亮著、麻痺 → 出手加速在計時、指針在綠色、護腕在手上
func _dev_bracer_read() -> void:
	reverse_paralysis()
	Game.session.set_flag("rb2.bracer_tested", true)
	bracer_read = 0.01
	dev_hold_read = true


## 小戰檢驗（design/10「C 的流程」後半第一輪，D-235）。leave_shop：商人帶來的三個人已經站在街上等（還不算敵人），
## 走出藥店的門 → rb2_trial_ambush（最後一句設 rb2.trial_called）→ trial_fight：開打 → 三個都倒下 → rb2.trial_won
## （任務做完、自動存檔）→ 隔一下 rb2_trial_won（最後一句設 rb2.trial_talked）→「待續／乾運河」。
## 倒下重試、讀檔：回 rb2_trial_fight（藥店門外），三個人滿血從街上走過來；諾恩的生命照存檔、最低補到一半。
func _tick_trial(delta: float, st: GameState, pos: Vector3) -> void:
	if Game.session.quests.is_done(TRIAL_QUEST):
		if not bool(st.get_flag("rb2.trial_talked", false)):
			trial_won_t += delta
			if trial_won_t >= WON_TALK_SEC:
				Game.start_dialogue("rb2_trial_won")
			return
		# 剛講完（這一次開機打贏的）：存一次、直接「待續」；讀檔回來走到櫃台前才是（不會一讀檔就黑掉）
		if trial_started:
			Game.session.save(GameSession.AUTO_SLOT)
			play_end_card()
		elif at_counter(pos):
			play_end_card()
		return
	match Game.session.quests.stage_of(TRIAL_QUEST):
		"leave_shop":
			if trial_guards.is_empty():
				_spawn_trial_gang(true)
			if outside_shop(pos):
				Game.start_dialogue("rb2_trial_ambush")
		"trial_fight":
			if not trial_started:
				start_trial_fight()
			elif trial_down():
				Game.session.set_flag("rb2.trial_won", true)
				level.place_trial_seller(true)


## 人已經走出藥店的門、站在街上了
func outside_shop(pos: Vector3) -> bool:
	return pos.z < UndergroundMarket.SHOP_Z - TRIAL_DOOR_OUT


## 商人帶來的人站到街上（waiting＝還沒開打：站著等，不算敵人）。只會生一次。
func _spawn_trial_gang(waiting: bool) -> void:
	if not trial_guards.is_empty():
		return
	level.begin_demo_fight(true)
	level.place_trial_seller()
	for spec: Array in UndergroundMarket.TRIAL_FIGHTERS:
		var g := DemoGuard.new()
		g.kind = str(spec[3])
		g.height = float(spec[2])
		g.focus_player = bool(spec[4])
		g.name = "TrialFighter%d" % trial_guards.size()
		var at: Vector3 = spec[0] as Vector3
		g.position = Vector3(at.x, level.ground_y(at) + 0.05, at.z)
		level.add_child(g)
		g.set_facing(deg_to_rad(float(spec[1])))
		g.set_waiting(waiting)
		trial_guards.append(g)


## 開打：三個人動起來、席菈喊一句、HUD 一行提示（兩格怎麼一起用）。只會開始一次。
func start_trial_fight() -> void:
	if trial_started:
		return
	trial_started = true
	_spawn_trial_gang(false)
	for g: DemoGuard in trial_guards:
		g.set_waiting(false)
	var ally: Sheila = level.get_node_or_null("Sheila") as Sheila
	if ally != null:
		ally.say(SHEILA_TRIAL_KEY)
	var hud: Hud = level.get_node_or_null("Hud") as Hud
	if hud != null:
		hud.show_banner(TRIAL_BANNER_KEY, TRIAL_BANNER_SEC)


## 商人帶來的人全部倒下了
func trial_down() -> bool:
	if trial_guards.is_empty():
		return false
	for g: DemoGuard in trial_guards:
		if is_instance_valid(g) and not g.health.is_dead():
			return false
	return true


## 截圖用（--rb-at=trial_hold，固定鏡頭 67）：小戰打到一半停住——諾恩站在一團毒霧裡（回血）、護腕亮著（剛打中人：出手加速），
## 拿棍子的在右前方舉棍、另一個在更遠處，丟毒瓶的在街心後面把瓶子舉過頭，席菈在右邊。
func _dev_hold_trial() -> void:
	_wear_bracer()
	start_trial_fight()
	if trial_guards.size() < 3:
		return
	var p: Vector3 = player.global_position
	var fwd := Vector3(-sin(player.rotation.y), 0.0, -cos(player.rotation.y))
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var club_a: DemoGuard = trial_guards[0]
	var club_b: DemoGuard = trial_guards[1]
	var thrower: DemoGuard = trial_guards[2]
	# 鏡頭在他右後方、街只有 5 m 寬：四個人從畫面中間往右排開、一個比一個遠，誰都不擋誰（第一版丟毒瓶的躲在拿棍子的後面）
	club_a.global_position = p + fwd * 2.3 + right * 0.9
	club_b.global_position = p + fwd * 3.8 + right * 3.3
	thrower.global_position = p + fwd * 6.0 + right * 2.6
	var ally: Sheila = level.get_node_or_null("Sheila") as Sheila
	var ally_at: Vector3 = p + fwd * 2.4 + right * 3.6
	if ally != null:
		ally.global_position = ally_at
		ally.set_physics_process(false)
		ally.rotation.y = atan2(-(club_b.global_position.x - ally_at.x), -(club_b.global_position.z - ally_at.z))
	club_a.hold_pose("swing", EnemyBrain.State.TELEGRAPH, 0.9, p)
	club_b.hold_pose("thrust", EnemyBrain.State.TELEGRAPH, 0.7, ally_at)
	thrower.hold_pose("toss", EnemyBrain.State.TELEGRAPH, 0.92, p)
	# 腳邊一團剛落地的毒霧（不會散）、生命掉了一截正在回、剛打中人
	var mist: PoisonMist = PoisonMist.create(2.0, DemoGuard.MIST_SOURCE)
	mist.name = "DevTrialMist"
	mist.position = Vector3(p.x + 0.3, level.ground_y(p), p.z - 0.4)
	level.add_child(mist)
	player.health.hp = player.health.max_hp * 0.55
	player.status_effects.apply_source(DemoGuard.MIST_SOURCE)
	player.status_effects.apply_source(BRACER_HIT_SOURCE)


## 開打：席菈喊一句、兩個守衛從布景換成真的敵人、看熱鬧的人退開。只會開始一次（倒下重試是整個關卡重來）。
func start_demo_fight() -> void:
	if fight_started:
		return
	fight_started = true
	level.begin_demo_fight()
	for spec: Array in UndergroundMarket.DEMO_FIGHTERS:
		var g := DemoGuard.new()
		g.kind = str(spec[3])
		g.height = float(spec[2])
		g.name = "DemoFighter%d" % guards.size()
		var at: Vector3 = spec[0] as Vector3
		g.position = Vector3(at.x, level.ground_y(at) + 0.05, at.z)
		level.add_child(g)
		g.set_facing(deg_to_rad(float(spec[1])))
		guards.append(g)
	# 戴護腕的那個是從台上跳下來的：身體從台子的高度落到地上
	if guards.size() > 0:
		guards[0].hop_down(UndergroundMarket.DEMO_STAGE_H, 0.28)
	var ally: Sheila = level.get_node_or_null("Sheila") as Sheila
	if ally != null:
		ally.say(SHEILA_CALL_KEY)
	var hud: Hud = level.get_node_or_null("Hud") as Hud
	if hud != null:
		hud.show_banner(FIGHT_BANNER_KEY, FIGHT_BANNER_SEC)


## 兩個守衛都倒下了
func guards_down() -> bool:
	if guards.is_empty():
		return false
	for g: DemoGuard in guards:
		if is_instance_valid(g) and not g.health.is_dead():
			return false
	return true


## 截圖用（--rb-at=fight）：一進場就開打，兩個守衛擺在諾恩前面、停在姿勢上——
## 拿棍子的在左前方、橫掃的前兆快到底（棍子拉到身後、銅箍亮著）；戴護腕的在右前方、剛打完一拳（右手垂著、護腕閃暗紅），席菈在他對面。
func _dev_hold_fight() -> void:
	start_demo_fight()
	if guards.size() < 2:
		return
	var p: Vector3 = player.global_position
	var fwd := Vector3(-sin(player.rotation.y), 0.0, -cos(player.rotation.y))
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var club: DemoGuard = guards[1]
	var bracer: DemoGuard = guards[0]
	# 鏡頭在他右後方：正前方的東西會被他自己擋住，所以三個人都擺在他的右前方、一個比一個遠
	club.global_position = p + fwd * 2.3 + right * 0.75
	bracer.global_position = p + fwd * 3.6 + right * 2.1
	var ally: Sheila = level.get_node_or_null("Sheila") as Sheila
	var ally_at: Vector3 = p + fwd * 2.5 + right * 3.4
	if ally != null:
		ally.global_position = ally_at
		ally.set_physics_process(false)
		ally.rotation.y = atan2(-(bracer.global_position.x - ally_at.x), -(bracer.global_position.z - ally_at.z))
	club.hold_pose("swing", EnemyBrain.State.TELEGRAPH, 0.9, p)
	bracer.hold_pose("jab", EnemyBrain.State.RECOVER, 0.4, ally_at)


## 走到示範台附近了（在街上，不是隔著牆在店裡）
func near_demo(pos: Vector3) -> bool:
	return pos.z < UndergroundMarket.SHOP_Z and FrostbridgeOpening.flat_distance(pos, UndergroundMarket.DEMO_POS) <= DEMO_RANGE


func _send_sheila_outside() -> void:
	var ally: Node3D = level.get_node_or_null("Sheila") as Node3D
	if ally == null or ally.global_position.z < UndergroundMarket.SHOP_Z - 0.8:
		return
	ally.global_position = Vector3(UndergroundMarket.SHOP_DOOR.x + 1.9, 0.0, UndergroundMarket.SHOP_Z - 2.6)
	ally.rotation_degrees.y = 180.0


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
	if bracer_ready():
		return {"fmt": TranslationServer.translate(BRACER_HINT_KEY), "action": "interact", "progress": clampf(board_hold / BOARD_HOLD_SEC, 0.0, 1.0)}
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


## 目前做到的地方的結尾：畫面淡成黑 →「待續／兩格一起用」→ 回標題。諾恩停住（黑幕底下不會被按鍵推著走）。
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
