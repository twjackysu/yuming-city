class_name FrostbridgeOpening
extends Node
## 前十分鐘（D-201～D-204，docs/design/09-reboot-first-ten-minutes.md）在霜橋鎮的劇情控制器。
## frostbridge.gd 在 Game.session.in_story() 時掛上這個節點（沒有開新遊戲的 session 只有空的鎮）。
## 流程：開場（雷德在鐵門後、波克在推車上、生命 55）→ 推車到北街轉角 → 藥桶破了、主街上一片毒霧 →
## 第一次中毒自動覺醒（畫面中間兩行字）→ 離開、毒效結束 → 再踏回去確認 → 霧散了 → 推車到南街口。
## 席菈接應 → 南街守衛戰（D-207：單階段送葬者＋噴毒）→ 倒下、席菈問名字。藥箱、艾妲、貨梯是下一步。

const QUEST: String = GameSession.MAIN_QUEST
## 跟 frostbridge.gd 的 RISE 一樣（北街台地高度）
const RISE: float = 0.9
## 開場短演出把諾恩打到這麼多（鐵架擦過背），自由操作開始時生命穩定
const OPENING_HP: float = 55.0

## 鐵門在北街北端（雷德在門後）
const GATE_Z: float = -45.6
const GATE_HALF: float = 3.4
const RED_POS: Vector3 = Vector3(0.6, RISE, -46.8)
## 推車路線：鐵門前 → 北街轉角（石階頂）→ 石階中段（等霧散）→ 主街 → 廣場 → 南街口
## （最後停在南街口西側、麵包店門邊：街心留給守衛戰，推車不擋路、不擋鏡頭，D-207）
const CART_ROUTE_XZ: Array[Vector2] = [
	Vector2(-0.8, -42.6), Vector2(-0.6, -31.0), Vector2(-0.5, -29.2), Vector2(-0.5, -27.4),
	Vector2(-0.4, -25.2), Vector2(-0.2, -16.0), Vector2(0.4, -6.0), Vector2(0.9, 3.0), Vector2(-1.6, 10.8),
]
## 路線上第幾個點＝北街轉角（推車到這裡藥桶就破了）、在霧散之前停在哪一點（石階中段，高處）
const CORNER_POINT: int = 2
## 諾恩沒等推車、自己走到這裡（石階中段）也算到了轉角
const PLAYER_CORNER_Z: float = -27.8
const HOLD_POINT: int = 3
## 推車跟著諾恩走：諾恩在這個距離內才往前推
const ESCORT_RANGE: float = 6.0
const ESCORT_SPEED: float = 1.7

## 破藥桶與毒霧（毒霧整個蓋住主街：半徑大於街的半寬，繞不過去）
const BARREL_SPOTS: Array[Vector3] = [Vector3(-2.7, 0.0, -23.6), Vector3(-1.7, 0.0, -24.0), Vector3(2.9, 0.0, -23.8)]
const MIST_CENTER: Vector3 = Vector3(0.0, 0.0, -18.6)
const MIST_RADIUS: float = 4.4
## 再踏回去確認之後，霧這麼久散掉（推車才過得去）
const MIST_CLEAR_SEC: float = 5.0
## 測試可以調短
var mist_clear_sec: float = MIST_CLEAR_SEC

## 追擊的送葬者（D-205）：開場對話一結束，牠從鐵門邊的屋頂跳下來（踩斷門邊的燈柱、手上拖著折下來的那一截），
## 照自己的腳跟在推車後面（比推車慢一點，諾恩停下來牠就逼近）。推車到北街轉角，牠把那截燈柱扔過來——
## 沒打中人，砸破了石階下的藥桶。之後牠堵在北街（回頭路沒了），不進毒霧。追擊期間不出招、打不動（開場生命只有 55）。
const PURSUER_SPAWN: Vector3 = Vector3(2.5, RISE, -43.8)
const PURSUER_DROP: float = 5.5
## 從東側屋簷邊跳出來：起跳點比落地點靠牆這麼多，下墜時往街心飄（一道弧線，不是直直掉下來）
const PURSUER_LEAP: float = 0.8
const PURSUER_LEAP_SPEED: float = 1.3
const PURSUER_SPEED: float = 1.45
## 跟在推車／諾恩（取比較北邊的那個）後面這麼遠
const PURSUER_GAP: float = 5.5
## 丟完之後堵在這裡（北街中段，面向南）；不走下石階
const PURSUER_BLOCK: Vector3 = Vector3(0.3, RISE, -33.2)
const PURSUER_STOP_Z: float = -33.2
const THROW_WINDUP_SEC: float = 0.9
const THROW_FLIGHT_SEC: float = 0.7
const THROW_ARC: float = 2.4
## 那截燈柱落在藥桶中間
const THROW_TARGET: Vector3 = Vector3(-1.6, 0.35, -23.8)
## 門邊被踩斷的燈柱剩下的那一截
const LAMP_STUMP: Vector3 = Vector3(3.35, RISE, -44.6)
## 那截燈柱拖在牠左手外側的姿勢（相對上身）：桿子往左下斜，燈頭剛好碰到地
## （左手：牠面向諾恩時燈在畫面右邊，不會被過肩鏡頭裡的諾恩擋住）
const LAMP_CARRY_POS: Vector3 = Vector3(-0.7, 0.03, 0.02)
const LAMP_CARRY_ROT: Vector3 = Vector3(14.0, 0.0, 124.0)
## 測試可以調短
var throw_windup_sec: float = THROW_WINDUP_SEC
var throw_flight_sec: float = THROW_FLIGHT_SEC

## 席菈從南街西側的側門出來（推車停在南街口），走近就開始接應的對話
const SHEILA_DOOR: Vector3 = Vector3(-2.3, 0.0, 13.2)
const SHEILA_TALK_RANGE: float = 3.4
## 南街守衛戰（D-207）：席菈接應的對話一結束，牠從南街南端（石拱那一頭）走過來——北街繞過來的那一隻。
## 走到離諾恩 GUARDIAN_ENGAGE_RANGE 以內（或走到定點）就開打：單階段（Undertaker.begin_guardian()：橫掃、下砸、噴毒）。
## 噴毒在地上留一團 3 秒的毒霧：諾恩站進去回血、席菈繞開；爪子和下砸照常扣血。倒下 → rb.guardian_down → 對話 rb_guardian_down。
const GUARDIAN_SPAWN: Vector3 = Vector3(0.4, 0.0, 27.0)
const GUARDIAN_MEET: Vector3 = Vector3(0.3, 0.0, 17.5)
const GUARDIAN_WALK_SPEED: float = 2.0
const GUARDIAN_ENGAGE_RANGE: float = 8.5
## 牠倒下之後隔這麼久，席菈才開口（等牠倒地的那一下）
const GUARDIAN_DOWN_TALK_SEC: float = 2.2
## 截圖旗標 `--rb-at=` 裡屬於守衛戰的四個（hit＝諾恩貼在牠面前、剛打中弱點的那一下：霜屑、火星、閃光，D-217）
const GUARDIAN_SHOTS: PackedStringArray = ["guardian", "spray", "sprayed", "hit", "slam"]
## 截圖旗標 `--rb-at=` 裡屬於「試用毒劑」的兩個：potion＝站在藥箱前（兩瓶還在）、drank＝拿了、剛喝一口（HUD：生命條、中毒 → 回血、藥 ×1）
const POTION_SHOTS: PackedStringArray = ["potion", "drank"]
## 藥箱（D-209）：牠背上的箱子摔在牠倒下的地方旁邊（往街心那一側 CRATE_SIDE 公尺）；位置記在旗標裡，讀檔照樣在那裡
const CRATE_SIDE: float = 1.5
## 存檔裡沒有位置時（截圖旗標直接跳到這一段）擺在這裡：街心偏西
const CRATE_DEFAULT: Vector3 = Vector3(-0.6, 0.0, 17.5)
const CRATE_X_LIMIT: float = 2.4
const CRATE_Z_MIN: float = 12.0
const CRATE_Z_MAX: float = 25.5
## 牠跪下、往前倒到一半時箱子才甩出去（Undertaker.FALL_KNEEL_SEC＋FALL_HOLD_SEC＋倒下的前半）
const CRATE_DROP_DELAY: float = 1.2
## 喝下去之後隔多久席菈才開口（先讓玩家看到生命條往上爬）
const POTION_TALK_SEC: float = 2.6
## 選了「先收著」之後隔多久席菈開口
const POTION_KEPT_TALK_SEC: float = 0.5
## 撿了藥、沒喝就走開這麼遠＝先收著（不強迫喝：09 第 5 節）
const POTION_KEEP_RANGE: float = 9.0
## 梨攤（frostbridge.gd 的 STALL_POS／CELLAR_POS；那支腳本沒有 class_name，這裡照抄，測試會比對）
const STALL_POS: Vector3 = Vector3(4.5, 0.0, -1.0)
## 貨梯＝梨攤後面的地窖口上方那座吊架（去地下市場，前十分鐘的終點）
const LIFT_POS: Vector3 = Vector3(7.6, 0.0, -4.2)
## 艾妲站在攤子的西南角（攤燈照得到、從南街走過來第一眼看得到）
const ADA_POS: Vector3 = Vector3(3.3, 0.0, 0.1)
const ADA_YAW_DEG: float = 165.0
const ADA_TALK_RANGE: float = 3.2
## 諾恩走到這麼近她才抬頭看人
const ADA_NOTICE_RANGE: float = 9.0
## 站上貨梯平台＝離平台中心這麼近
const LIFT_RANGE: float = 1.25
## 雷德寄存的一半工錢（一次性發放：GameState.grants 的 WAGES_GRANT，讀檔重試不重複領）
const WAGES: int = 12
const WAGES_GRANT: String = "rb.ada_wages"
const WAGES_ITEM: String = "coins"
const MARKET_SHOTS: PackedStringArray = ["market", "lift"]
## 席菈接應之後的階段（她在場、波克已經進店）
const AFTER_SHEILA_STAGES: PackedStringArray = ["guardian_fight", "portable_poison", "market_lead"]

## 檢查點 → 諾恩出生的位置與朝向（度；180＝面向南）
const SPAWNS: Dictionary = {
	# 開場面向北：鐵門與門後的雷德在眼前（對話結束後自己轉身往南）
	"rb_start": [Vector3(0.6, RISE + 0.05, -40.4), 0.0],
	"rb_before_mist": [Vector3(0.9, 0.5, -27.6), 180.0],
	"rb_sheila": [Vector3(0.9, 0.05, 9.6), 180.0],
	"rb_guardian": [Vector3(0.9, 0.05, 9.6), 180.0],
	"rb_portable": [Vector3(0.9, 0.05, 9.6), 180.0],
	"rb_market": [Vector3(0.9, 0.05, 9.6), 0.0],
}

var level: StoryLevel
var player: PlayerController
var cart: Caravan
var mist: PoisonMist
var barrels: Array[Node3D] = []
var red: Puppet
## 第一次覺醒之後，諾恩已經離開毒霧、毒效也結束了（之後再踏進去才算「確認」）
var left_mist_after_awaken: bool = false
var _mist_clearing: bool = false
var _hold_traveled: float = 0.0
var _corner_traveled: float = 0.0
var pursuer: Undertaker
## 牠手上那截折下來的燈柱（丟出去之後躺在藥桶旁）
var lamp_chunk: Node3D
## 0＝還沒丟、1＝舉起來、2＝在空中、3＝砸到了
var throw_phase: int = 0
var _throw_t: float = 0.0
var _throw_from: Vector3 = Vector3.ZERO
var _pursuer_landed: bool = true
## 截圖用（`--rb-at=throw|flight`）：把丟燈柱停在某一刻——"windup"＝舉到最高、"flight"＝飛到三分之一
var debug_hold_throw: String = ""
## 南街的守衛（節點名 RbGuardian＝任務標記）；倒下、沉進雪裡之後是 null
var guardian: Undertaker
## 牠開打了沒（走過來的那一段不出招、打不動）
var guardian_engaged: bool = false
## >0＝牠倒下了，倒數到 0 就播 rb_guardian_down
var _guardian_down_t: float = -1.0
## 測試可以調短
var guardian_down_talk_sec: float = GUARDIAN_DOWN_TALK_SEC
## 截圖用（`--rb-at=guardian|spray|sprayed|hit|slam`）："walk"＝站在街上盯著人、"telegraph"＝噴毒前兆停在八成、"jet"＝剛噴出去、
## "hit"＝每 DEV_HIT_EVERY 個物理幀重打一次（一次性粒子只活半秒，拍的那一幀一定有一把在飛）、
## "slam"＝停在下砸打下去的姿勢，每 DEV_SLAM_EVERY 個物理幀重砸一次（雪塵、碎石只活一秒）
var debug_hold_guardian: String = ""
const DEV_HIT_EVERY: int = 14
const DEV_SLAM_EVERY: int = 26
var _dev_hit_frames: int = 0
## 守衛的藥箱（節點名 RbPotionCrate＝任務標記）；牠倒下之後才有
var crate: PotionCrate
## >0＝喝過或選了先收著，倒數到 0 就播 rb_potion_tried／rb_potion_kept
var _potion_talk_t: float = -1.0
## 測試可以調短
var potion_talk_sec: float = POTION_TALK_SEC
## 梨攤的艾妲（節點名 Ada）
var ada: Puppet
## 站上貨梯、「貨梯往下」那張卡出來了（之後不再觸發任何東西）
var ending: bool = false
## 卡播完之後做什麼；空的＝換到地下市場。測試換成自己的（不要真的換場景）
var end_done: Callable = Callable()


func _ready() -> void:
	level = get_parent() as StoryLevel
	player = level.get_node_or_null("Player") as PlayerController
	_build_markers()
	_build_gate()
	_build_bakery_lantern()
	_build_south_lantern()
	_build_ada()
	_build_lift()
	_build_barrels()
	_build_cart()
	var st: GameState = Game.session.state
	if st.get_flag("rb.barrels_broken", false):
		_break_barrels(false)
	if player != null:
		_place_player(st.checkpoint)
		# 新遊戲（還沒存過生命）：開場被鐵架擦傷
		if not st.vitals.has("hp"):
			player.health.hp = OPENING_HP
		player.reversal.awakened.connect(_on_awakened)
		player.snap_camera()
	Game.dialogue_ended.connect(_on_dialogue_ended)
	Game.session.stage_changed.connect(_on_stage_changed)
	var now: String = stage()
	if now == "meet_sheila":
		_spawn_sheila(SHEILA_DOOR)
	elif now in AFTER_SHEILA_STAGES or Game.session.quests.is_done(QUEST):
		_pok_into_shop()
		if player != null:
			_spawn_sheila(player.global_position + Vector3(-1.4, 0.0, 1.2))
	if not st.get_flag("rb.opening_done", false):
		_begin_opening.call_deferred()
	elif now == "escape":
		_spawn_pursuer(false)
	elif now == "poison_discovery":
		_spawn_pursuer_blocking()
	elif now == "guardian_fight":
		if st.get_flag("rb.guardian_down", false):
			_guardian_down_t = 0.4
		else:
			_spawn_guardian()
	# 牠已經倒下（讀檔、死亡重試）：藥箱本來就在地上
	if st.get_flag("rb.guardian_down", false):
		_spawn_crate(false)
	# 截圖用：`--rb-at=mist` 一進場就站在毒霧裡（第一次覺醒的兩行字）
	var shot_at: String = str(App.parse_user_args(OS.get_cmdline_user_args()).get("rb-at", ""))
	if player != null and shot_at == "mist":
		player.global_position = MIST_CENTER + Vector3(0.9, 0.05, -2.6)
		player.snap_camera()
	# `--rb-at=pursuer`：對話剛結束，回頭看見門邊的送葬者（手上拖著那截燈柱）
	if player != null and shot_at == "pursuer":
		player.global_position = Vector3(-1.2, RISE + 0.05, -40.4)
		player.rotation.y = deg_to_rad(-30.0)
		player.yaw = player.rotation.y
		player.snap_camera()
	# `--rb-at=throw|flight`：推車到了轉角，諾恩在石階上回頭——牠把那截燈柱舉過頭／燈柱飛在半空
	if player != null and shot_at in ["throw", "flight"] and pursuer != null and cart != null:
		debug_hold_throw = "windup" if shot_at == "throw" else "flight"
		pursuer.global_position = Vector3(0.3, RISE, -35.2)
		cart.runner.traveled = _corner_traveled
		cart._sync()
		var at := Vector3(-1.8, 0.0, -28.4)
		player.global_position = Vector3(at.x, level.ground_y(at) + 0.05, at.z)
		player.rotation.y = 0.0
		player.yaw = 0.0
		player.snap_camera()
	# `--rb-at=impact`（配 `--frames=6` 左右）：站在石階下面向南，燈柱馬上砸在藥桶上——看那一下的閃光、木屑、綠霧
	if player != null and shot_at == "impact" and pursuer != null and cart != null:
		throw_windup_sec = 0.05
		throw_flight_sec = 0.1
		pursuer.global_position = Vector3(0.3, RISE, -35.2)
		cart.runner.traveled = _corner_traveled
		cart._sync()
		var spot := Vector3(0.9, 0.0, -27.4)
		player.global_position = Vector3(spot.x, level.ground_y(spot) + 0.05, spot.z)
		player.rotation.y = deg_to_rad(180.0)
		player.yaw = player.rotation.y
		player.snap_camera()
	# `--rb-at=guardian|spray|sprayed`：南街守衛戰（牠站在街上／噴毒前兆／剛噴出去，諾恩站在毒霧邊）
	if shot_at in GUARDIAN_SHOTS:
		_dev_stage_guardian(shot_at)
	# `--rb-at=potion|drank`：牠已經倒下，諾恩站在藥箱前（兩瓶還在、提示亮著）／拿了、剛喝一口
	if shot_at in POTION_SHOTS:
		_dev_stage_potion(shot_at == "drank")
	# `--rb-at=market|lift`：藥的事講完了，諾恩站在梨攤前（艾妲抱著帳本）／艾妲講完了，站在貨梯前
	if shot_at in MARKET_SHOTS:
		_dev_stage_market(shot_at == "lift")


## 截圖用（`--rb-at=`）：照正式流程設旗標，推到那一段。start＝開場對話；mist＝藥桶破了、第一次進霧前；
## guardian／spray／sprayed＝南街守衛戰（席菈已經接應）
static func dev_advance(s: GameSession, at: String) -> void:
	var after_sheila: bool = at in GUARDIAN_SHOTS or at in POTION_SHOTS or at in MARKET_SHOTS
	if at in ["mist", "pursuer", "throw", "flight", "impact"] or after_sheila:
		s.set_flag("rb.opening_done", true)
	if at in ["mist"] or after_sheila:
		s.set_flag("rb.barrels_broken", true)
	if after_sheila:
		for flag: String in ["rb.reversal_awakened", "rb.mist_reentered", "rb.reached_south", "rb.sheila_met"]:
			s.set_flag(flag, true)
	if at in POTION_SHOTS or at in MARKET_SHOTS:
		for flag: String in ["rb.guardian_down", "rb.guardian_talked"]:
			s.set_flag(flag, true)
	if at in MARKET_SHOTS:
		PotionBelt.new(s.state).grant_once(PotionCrate.GRANT_ID, PotionCrate.ITEM, PotionCrate.AMOUNT)
		for flag: String in [PotionCrate.FOUND_FLAG, "rb.potion_kept", "rb.potion_talked"]:
			s.set_flag(flag, true)
	if at == "lift":
		s.state.grant_once(WAGES_GRANT)
		s.state.items[WAGES_ITEM] = WAGES
		for flag: String in ["rb.ada_talked", "rb.wages_paid"]:
			s.set_flag(flag, true)


## 截圖用：守衛站在南街中段（不開打），諾恩在牠北邊、面向牠；席菈在旁邊。
func _dev_stage_guardian(at: String) -> void:
	if guardian == null or player == null:
		return
	var holds: Dictionary = {"guardian": "walk", "spray": "telegraph", "sprayed": "jet", "hit": "hit", "slam": "slam"}
	debug_hold_guardian = str(holds.get(at, "walk"))
	# slam：諾恩剛退到下砸範圍外（落點在牠前面 1.9 m、半徑 2 m）
	var gaps: Dictionary = {"guardian": 5.2, "hit": 1.6, "slam": 4.5}
	var gap: float = float(gaps.get(at, 3.6))
	var boss_at := Vector3(0.0, 0.0, 18.4)
	guardian.global_position = Vector3(boss_at.x, level.ground_y(boss_at) + 0.05, boss_at.z)
	guardian.set_physics_process(false)
	guardian.set_facing(0.0)
	var me := Vector3(1.4 if at == "slam" else 1.1, 0.0, boss_at.z - gap)
	player.global_position = Vector3(me.x, level.ground_y(me) + 0.05, me.z)
	# hit、slam：面向正南，牠在畫面中間偏右，命中點／落點不被諾恩自己擋住
	player.rotation.y = deg_to_rad(180.0 if at in ["hit", "slam"] else 168.0)
	player.yaw = player.rotation.y
	# 逆轉體質已經覺醒（不再跳中間那兩行字）
	player.reversal.awakened_once = true
	player.reversal.unlock("poison")
	player.reversal.equip("poison")
	var sheila: Node3D = level.get_node_or_null("Sheila") as Node3D
	if sheila != null:
		sheila.set_physics_process(false)
		sheila.global_position = Vector3(-1.7, level.ground_y(me), me.z + 0.6)
		if at == "slam":
			# 她站在另一邊（畫面左邊），落點那一側留空
			sheila.global_position = Vector3(2.5, level.ground_y(me), me.z + 2.2)
	if at == "sprayed":
		guardian.debug_hold_jet = true
		guardian.brain._set_move("spray")
		guardian._spray()
	player.snap_camera()


## 截圖用：牠已經倒下。諾恩站在藥箱北邊偏東、面向南（藥箱在畫面中間偏右），生命沒滿；席菈在另一邊看著。
## drank＝兩瓶已經拿了、剛喝下一口（還沒輪到席菈開口）。
func _dev_stage_potion(drank: bool = false) -> void:
	if crate == null or player == null:
		return
	var c: Vector3 = crate.global_position
	var me := Vector3(c.x + 0.95, 0.0, c.z - 1.7)
	player.global_position = Vector3(me.x, level.ground_y(me) + 0.05, me.z)
	player.rotation.y = deg_to_rad(180.0)
	player.yaw = player.rotation.y
	player.health.hp = 68.0
	player.reversal.awakened_once = true
	player.reversal.unlock("poison")
	player.reversal.equip("poison")
	var sheila: Node3D = level.get_node_or_null("Sheila") as Node3D
	if sheila != null:
		sheila.set_physics_process(false)
		var her := Vector3(c.x - 1.7, 0.0, c.z + 1.1)
		sheila.global_position = Vector3(her.x, level.ground_y(her), her.z)
		sheila.rotation.y = deg_to_rad(70.0)
	if drank:
		PotionBelt.new(Game.session.state).grant_once(PotionCrate.GRANT_ID, PotionCrate.ITEM, PotionCrate.AMOUNT)
		crate.taken = true
		crate._show_taken(false)
		Game.session.set_flag(PotionCrate.FOUND_FLAG, true)
		potion_talk_sec = 600.0
		player.use_potion()
	player.snap_camera()


## 截圖用：每幀把守衛停在那一刻（physics_process 關掉了，姿勢與管口的光自己更新）
func _dev_hold_guardian() -> void:
	if guardian == null or not is_instance_valid(guardian):
		return
	match debug_hold_guardian:
		"telegraph":
			guardian.brain._set_move("spray")
			guardian.brain.state = EnemyBrain.State.TELEGRAPH
			guardian.brain.time_in_state = guardian.brain.telegraph_sec * 0.85
		"hit":
			_dev_hit_frames -= 1
			if _dev_hit_frames <= 0:
				_dev_hit_frames = DEV_HIT_EVERY
				if guardian.last_hit_fx != null and is_instance_valid(guardian.last_hit_fx):
					guardian.last_hit_fx.queue_free()
				guardian.debug_hold_hit = true
				guardian._hit_fx({"source": player, "weak": "frame_joint"})
		"slam":
			guardian.brain._set_move("slam")
			guardian.brain.state = EnemyBrain.State.STRIKE
			_dev_hit_frames -= 1
			if _dev_hit_frames <= 0:
				_dev_hit_frames = DEV_SLAM_EVERY
				if guardian.last_slam_fx != null and is_instance_valid(guardian.last_slam_fx):
					guardian.last_slam_fx.queue_free()
				guardian.debug_hold_slam = true
				guardian._slam_fx(guardian.slam_center(), guardian.brain.move_num("slam", "radius", 2.0))
		"jet":
			guardian.brain.state = EnemyBrain.State.STRIKE
			if guardian.last_spray != null and is_instance_valid(guardian.last_spray) and guardian.last_spray.zone != null:
				guardian.last_spray.zone.life = 2.4
	guardian._update_look()


func stage() -> String:
	return Game.session.quests.stage_of(QUEST)


# ---------------------------------------------------------------- 開場

func _begin_opening() -> void:
	if not is_inside_tree() or Game.session.state.get_flag("rb.opening_done", false):
		return
	Game.start_dialogue("rb_opening")


func _on_dialogue_ended(dialogue_id: String) -> void:
	match dialogue_id:
		"rb_opening":
			_red_runs_off()
			_spawn_pursuer(true)
		"rb_mist_confirmed":
			_clear_mist()
		"rb_sheila_meet":
			_pok_into_shop()
			if stage() == "guardian_fight":
				_spawn_guardian()
		"rb_ada_wages":
			pay_wages()


## 雷德頭也不回地往北跑掉（鐵門照樣鎖著）
func _red_runs_off() -> void:
	if red == null or not is_instance_valid(red):
		return
	red.move_speed = 4.0
	red.rotation_degrees.y = 0.0
	var t := red.create_tween()
	t.tween_property(red, "position:z", RED_POS.z - 4.0, 1.4)
	t.tween_callback(red.queue_free)
	red = null


# ---------------------------------------------------------------- 每幀

func _physics_process(delta: float) -> void:
	if player == null or Game.session == null or not Game.session.in_story():
		return
	_update_cart(delta)
	_update_pursuer()
	_update_throw(delta)
	_update_guardian(delta)
	var st: GameState = Game.session.state
	_pin_potion_hud(st)
	_update_ada(delta)
	match stage():
		"escape":
			# 推車推到北街轉角（或諾恩自己先走下石階）→ 送葬者把那截燈柱扔過來，砸破藥桶
			if (cart != null and cart.runner.traveled >= _corner_traveled - 0.01) or player.global_position.z >= PLAYER_CORNER_Z:
				_begin_barrel_throw()
		"poison_discovery":
			_update_mist_test(st)
		"portable_poison":
			_update_potion(delta, st)
		"market_lead":
			_update_market(st)
		"meet_sheila":
			var sheila: Node3D = level.get_node_or_null("Sheila") as Node3D
			if sheila != null and not Game.is_player_locked() and not st.get_flag("rb.sheila_met", false) \
					and sheila.global_position.distance_to(player.global_position) <= SHEILA_TALK_RANGE:
				Game.start_dialogue("rb_sheila_meet")


func _update_cart(delta: float) -> void:
	if cart == null:
		return
	var r: CaravanRunner = cart.runner
	var near: bool = player.global_position.distance_to(cart.global_position) <= ESCORT_RANGE
	r.speed = ESCORT_SPEED if near and not Game.is_player_locked() and not r.is_arrived else 0.0
	# 霧散之前推車停在石階上（高處，波克不進毒霧）
	if not Game.session.state.get_flag("rb.mist_reentered", false) or _mist_clearing or mist != null:
		if r.traveled >= _hold_traveled:
			r.traveled = _hold_traveled
			r.speed = 0.0
	# 藥桶還沒破：推到轉角就停（下一幀破桶）
	if not Game.session.state.get_flag("rb.barrels_broken", false) and r.traveled >= _corner_traveled:
		r.traveled = _corner_traveled
		r.speed = 0.0


func _update_mist_test(st: GameState) -> void:
	if not st.get_flag("rb.reversal_awakened", false) or st.get_flag("rb.mist_reentered", false):
		return
	if Game.is_player_locked() or mist == null:
		return
	var inside: bool = mist.contains(player.global_position)
	if not left_mist_after_awaken:
		if not inside and not player.status_effects.has("poison"):
			left_mist_after_awaken = true
			if not st.get_flag("rb.mist_test_hinted", false):
				Game.start_dialogue("rb_mist_test")
		return
	if inside:
		Game.session.set_flag("rb.mist_reentered", true)
		Game.start_dialogue("rb_mist_confirmed")


## 第一次中毒 → 逆轉體質（ReversalSlots 自動裝進第一格）：畫面中間兩行字，不暫停
func _on_awakened(_status_id: String) -> void:
	var hud: Hud = level.get_node_or_null("Hud") as Hud
	if hud != null:
		hud.show_center_lines("RB_AWAKEN_LINE1", "RB_AWAKEN_LINE2", 4.5)
	Game.session.set_flag("rb.reversal_awakened", true)


func _on_stage_changed(quest_id: String, _from: String, to_stage: String) -> void:
	if quest_id == QUEST and to_stage == "meet_sheila":
		_spawn_sheila(SHEILA_DOOR)
		# 牠繞去南街了（南街守衛戰就是牠，下一步）：北街那隻這時已經在霧後面看不到
		if pursuer != null and is_instance_valid(pursuer):
			pursuer.queue_free()
		pursuer = null


func _spawn_sheila(pos: Vector3) -> void:
	if level.has_node("Sheila"):
		return
	var ally := Sheila.new()
	ally.name = "Sheila"
	ally.position = Vector3(pos.x, level.ground_y(pos), pos.z)
	ally.rotation_degrees.y = 90.0
	level.add_child(ally)


## 席菈接手：波克被扶進店裡（車上沒人了）
func _pok_into_shop() -> void:
	if cart == null:
		return
	for part: String in ["Cart/Wounded0", "Cart/Blanket0"]:
		var n: Node3D = cart.get_node_or_null(part) as Node3D
		if n != null:
			n.visible = false


func _on_cart_arrived() -> void:
	if Game.session.in_story() and stage() == "poison_discovery":
		Game.session.set_flag("rb.reached_south", true)


# ---------------------------------------------------------------- 南街守衛戰（D-207）

## 牠從南街南端走過來（新遊戲、讀檔、死亡重試都一樣：滿血、從頭走）
func _spawn_guardian() -> void:
	if guardian != null or level.has_node("RbGuardian") or Game.session.state.get_flag("rb.guardian_down", false):
		return
	guardian = Undertaker.new()
	guardian.name = "RbGuardian"
	guardian.position = Vector3(GUARDIAN_SPAWN.x, level.ground_y(GUARDIAN_SPAWN) + 0.05, GUARDIAN_SPAWN.z)
	level.add_child(guardian)
	guardian.begin_guardian()
	guardian.set_facing(0.0)
	guardian.scripted_walk(GUARDIAN_MEET, 0.0)
	guardian.health.died.connect(_on_guardian_died)
	guardian_engaged = false


func _update_guardian(delta: float) -> void:
	if _guardian_down_t > 0.0 and not Game.is_player_locked():
		_guardian_down_t = maxf(_guardian_down_t - delta, 0.0)
		if _guardian_down_t == 0.0:
			_guardian_down_t = -1.0
			if not Game.session.state.get_flag("rb.guardian_talked", false):
				Game.start_dialogue("rb_guardian_down")
	if debug_hold_guardian != "":
		_dev_hold_guardian()
		return
	if guardian == null or not is_instance_valid(guardian) or guardian_engaged or guardian.health.is_dead():
		return
	guardian.scripted_walk(GUARDIAN_MEET, 0.0 if Game.is_player_locked() else GUARDIAN_WALK_SPEED)
	guardian.scripted_look_at(player.global_position)
	if Game.is_player_locked():
		return
	var gap: Vector3 = player.global_position - guardian.global_position
	gap.y = 0.0
	if gap.length() <= GUARDIAN_ENGAGE_RANGE or guardian.scripted_arrived():
		_engage_guardian()


## 交給狀態機：開打。一行提示把規則講白（毒＝回血，直接打擊照樣會痛）。
func _engage_guardian() -> void:
	guardian_engaged = true
	guardian.end_scripted()
	var hud: Hud = level.get_node_or_null("Hud") as Hud
	if hud != null:
		hud.show_banner("RB_GUARDIAN_START", 5.0)


func _on_guardian_died() -> void:
	# 藥箱摔在牠旁邊：趁牠還沒沉下去，先把位置記下來（讀檔時照這個位置擺）
	if guardian != null and is_instance_valid(guardian):
		var at: Vector3 = crate_spot(guardian.global_position, guardian.forward())
		Game.session.state.set_flag("rb.crate_x", at.x)
		Game.session.state.set_flag("rb.crate_z", at.z)
	Game.session.set_flag("rb.guardian_down", true)
	_guardian_down_t = guardian_down_talk_sec
	_spawn_crate(true)
	# 牠噴在地上的毒霧跟著散掉（倒下之後這一帶是安全區：下一步的藥箱在這裡試）
	for n: Node in get_tree().get_nodes_in_group("poison_mist"):
		var m: PoisonMist = n as PoisonMist
		if m != null and m.zone != null and m.zone.life > 0.6:
			m.zone.life = 0.6


# ---------------------------------------------------------------- 藥箱與可攜毒劑（D-209）

## 牠倒在 body（面向 facing）：箱子落在牠側邊 CRATE_SIDE 公尺、靠街心的那一側，不出街道的範圍
static func crate_spot(body: Vector3, facing: Vector3) -> Vector3:
	var f := Vector3(facing.x, 0.0, facing.z)
	f = f.normalized() if f.length() > 0.01 else Vector3(0.0, 0.0, -1.0)
	var side: Vector3 = f.cross(Vector3.UP)
	var a: Vector3 = body + side * CRATE_SIDE
	var b: Vector3 = body - side * CRATE_SIDE
	var at: Vector3 = a if absf(a.x) <= absf(b.x) else b
	return Vector3(clampf(at.x, -CRATE_X_LIMIT, CRATE_X_LIMIT), 0.0, clampf(at.z, CRATE_Z_MIN, CRATE_Z_MAX))


## drop＝牠剛倒下，箱子從牠背上摔下來；false＝讀檔／重試，本來就在地上
func _spawn_crate(drop: bool) -> void:
	if crate != null or level.has_node(PotionCrate.NODE_NAME):
		return
	var st: GameState = Game.session.state
	var at := Vector3(float(st.get_flag("rb.crate_x", CRATE_DEFAULT.x)), 0.0, float(st.get_flag("rb.crate_z", CRATE_DEFAULT.z)))
	crate = PotionCrate.new()
	crate.position = Vector3(at.x, level.ground_y(at), at.z)
	# 開口（摔斷木板的那一面）朝北偏一點：諾恩從北邊走過來，一眼看到裡面的瓶子
	crate.rotation.y = deg_to_rad(197.0)
	level.add_child(crate)
	if drop:
		crate.drop_in(CRATE_DROP_DELAY)


## 剛撿到藥、還沒決定喝不喝的那一段：藥的數量與生命條釘在畫面上（看得到「現在沒滿血，喝了會回」）
func _pin_potion_hud(st: GameState) -> void:
	var hud: Hud = level.get_node_or_null("Hud") as Hud
	if hud == null or hud.potion == null:
		return
	hud.potion.pinned = stage() == "portable_poison" and bool(st.get_flag("rb.potion_found", false)) \
		and not bool(st.get_flag("rb.potion_talked", false))


## 試用毒劑：喝過（rb.potion_tried，PlayerController.use_potion）→ 等生命往上爬一下 → 席菈「你在喝什麼？」；
## 滿血時選「先收著」、或沒喝就走遠（rb.potion_kept）→ 席菈「你要留著那個？」。兩條路都設 rb.potion_talked → 下一階段。
func _update_potion(delta: float, st: GameState) -> void:
	if not bool(st.get_flag("rb.potion_found", false)) or bool(st.get_flag("rb.potion_talked", false)) or Game.is_player_locked():
		return
	var tried: bool = bool(st.get_flag("rb.potion_tried", false))
	var kept: bool = bool(st.get_flag("rb.potion_kept", false))
	if not tried and not kept and crate != null and is_instance_valid(crate):
		var gap: Vector3 = player.global_position - crate.global_position
		gap.y = 0.0
		if gap.length() > POTION_KEEP_RANGE:
			Game.session.set_flag("rb.potion_kept", true)
			kept = true
	if not tried and not kept:
		return
	if _potion_talk_t < 0.0:
		_potion_talk_t = potion_talk_sec if tried else minf(POTION_KEPT_TALK_SEC, potion_talk_sec)
	_potion_talk_t = maxf(_potion_talk_t - delta, 0.0)
	if _potion_talk_t == 0.0:
		_potion_talk_t = -1.0
		Game.start_dialogue("rb_potion_tried" if tried else "rb_potion_kept")


# ---------------------------------------------------------------- 艾妲與貨梯（D-210）

static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## 去地下市場：走近梨攤 → 艾妲給一半工錢、說貨梯（rb_ada_wages）→ 站上貨梯 → rb.market_reached →
## rb_main 做完、rb_market 開始（檢查點 rb2_arrive，自動存檔）→ 黑一下「貨梯往下／地下市場」→ 換到地下市場。
## 每幀量距離、不用 Area3D：上一段對話結束時諾恩可能已經站在攤子前（body_entered 不會再響一次）。
func _update_market(st: GameState) -> void:
	if ending or Game.is_player_locked():
		return
	if not bool(st.get_flag("rb.ada_talked", false)):
		if flat_distance(player.global_position, ADA_POS) <= ADA_TALK_RANGE:
			Game.start_dialogue("rb_ada_wages")
		return
	if flat_distance(player.global_position, LIFT_POS) <= LIFT_RANGE:
		Game.session.set_flag("rb.market_reached", true)
		ride_lift()


## 雷德寄存的一半工錢：只給一次（讀檔、死亡重試回到檢查點時跟著退回，再聽一次也只拿一次）。回傳這次有沒有給。
func pay_wages() -> bool:
	var st: GameState = Game.session.state
	if not st.grant_once(WAGES_GRANT):
		return false
	st.items[WAGES_ITEM] = int(st.items.get(WAGES_ITEM, 0)) + WAGES
	var hud: Hud = level.get_node_or_null("Hud") as Hud
	if hud != null:
		hud.show_banner("RB_WAGES_PAID", 4.0)
	return true


## 站上貨梯：畫面淡成黑 →「貨梯往下／地下市場」→ 換到地下市場（關卡 market）。諾恩停住（黑幕底下不會被按鍵推著走）。
## 「待續」那張卡與配樂搬到地下市場目前做到的地方（UndergroundMarketStory.play_end_card）。
func ride_lift() -> ChapterCard:
	if ending:
		return level.get_node_or_null("ChapterCard") as ChapterCard
	ending = true
	if player != null:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	return ChapterCard.play(level, "RB_LIFT_NUMBER", "RB_END_TITLE", _on_lift_card_done)


func _on_lift_card_done() -> void:
	if end_done.is_valid():
		end_done.call()
	else:
		Game.go_to_level(Game.level_for_checkpoint(Game.session.state.checkpoint))


## 艾妲在攤子前等人：諾恩走近了才抬頭轉過來
func _update_ada(delta: float) -> void:
	if ada == null or not is_instance_valid(ada):
		return
	var to: Vector3 = player.global_position - ada.global_position
	to.y = 0.0
	var want: float = deg_to_rad(ADA_YAW_DEG)
	if to.length() > 0.4 and to.length() < ADA_NOTICE_RANGE:
		want = atan2(-to.x, -to.z)
	ada.rotation.y = lerp_angle(ada.rotation.y, want, minf(delta * 4.0, 1.0))


## 梨攤的艾妲（新版：父親活著、她管帳）。夜裡的攤子原本只有一個剪影，新版換成人偶：暗紅外套、左手夾著帳本。
## 任務標記 PearSellerTrigger 在她身上（名字照舊版的觸發點，rb_main.json 在找）。
func _build_ada() -> void:
	if level.has_node("Ada"):
		ada = level.get_node("Ada") as Puppet
		return
	ada = Puppet.new()
	ada.name = "Ada"
	ada.coat_color = Color(0.36, 0.2, 0.17)
	ada.trim_color = Color(0.62, 0.55, 0.42)
	ada.position = Vector3(ADA_POS.x, level.ground_y(ADA_POS), ADA_POS.z)
	ada.rotation_degrees.y = ADA_YAW_DEG
	level.add_child(ada)
	var hammer: Node = ada.hand("R").get_node_or_null("BellHammer") if ada.hand("R") != null else null
	if hammer != null:
		hammer.queue_free()
	var hand: Node3D = ada.hand("L")
	if hand != null:
		var book := Node3D.new()
		book.name = "Ledger"
		book.position = Vector3(0.0, -0.1, 0.04)
		book.rotation_degrees = Vector3(8.0, 0.0, 6.0)
		var cover := StandardMaterial3D.new()
		cover.albedo_color = Color(0.2, 0.12, 0.08)
		cover.roughness = 0.7
		var pages := StandardMaterial3D.new()
		pages.albedo_color = Color(0.78, 0.72, 0.6)
		pages.roughness = 0.9
		_box_part(book, Vector3(0.05, 0.3, 0.22), Vector3.ZERO, cover)
		_box_part(book, Vector3(0.036, 0.28, 0.2), Vector3(0.0, 0.0, 0.016), pages)
		hand.add_child(book)
	_marker("PearSellerTrigger", ADA_POS + Vector3(0.0, 1.0, 0.0))


## 貨梯（去地下市場）：地窖口上方的木吊架——兩根柱子、橫樑、滑輪、四條繩子吊著一塊貨板、柱上一盞燈。
## 灰盒的地窖口只是一塊貼地的木板，夜裡從梨攤看過去什麼都沒有；吊架＋燈讓「往那裡走」一眼看得到。
## 柱子很細、不擋人；任務標記 CellarTrigger 在平台上方。
func _build_lift() -> void:
	if level.has_node("RbLift"):
		return
	var n := Node3D.new()
	n.name = "RbLift"
	n.position = Vector3(LIFT_POS.x, level.ground_y(LIFT_POS), LIFT_POS.z)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.2, 0.15, 0.11)
	wood.roughness = 0.88
	var plank := StandardMaterial3D.new()
	plank.albedo_color = Color(0.27, 0.2, 0.14)
	plank.roughness = 0.9
	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color(0.42, 0.35, 0.24)
	rope.roughness = 1.0
	var iron: Material = Undertaker.frame_iron_material()
	# 兩根柱子＋橫樑＋斜撐
	for sx: float in [-1.0, 1.0]:
		_box_part(n, Vector3(0.2, 3.0, 0.2), Vector3(sx * 1.05, 1.5, 0.0), wood)
		_box_part(n, Vector3(0.5, 0.1, 0.5), Vector3(sx * 1.05, 0.05, 0.0), wood)
		_beam(n, Vector3(sx * 1.05, 2.2, 0.0), Vector3(sx * 0.45, 2.92, 0.0), 0.06, wood)
	_box_part(n, Vector3(2.6, 0.22, 0.22), Vector3(0.0, 3.0, 0.0), wood)
	# 滑輪（鐵輪，軸沿著南北）與主繩
	var wheel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.17
	cyl.bottom_radius = 0.17
	cyl.height = 0.07
	cyl.radial_segments = 16
	wheel.mesh = cyl
	wheel.material_override = iron
	wheel.rotation_degrees.x = 90.0
	wheel.position = Vector3(0.0, 2.72, 0.0)
	n.add_child(wheel)
	_box_part(n, Vector3(0.04, 0.22, 0.12), Vector3(0.0, 2.84, 0.0), iron)
	var ring := Vector3(0.0, 1.75, 0.0)
	_beam(n, Vector3(0.0, 2.6, 0.0), ring, 0.022, rope)
	_box_part(n, Vector3(0.1, 0.06, 0.1), ring, iron)
	# 繞過滑輪、拉到西柱上的繫繩樁
	_beam(n, Vector3(-0.16, 2.72, 0.0), Vector3(-0.95, 1.15, 0.0), 0.018, rope)
	_box_part(n, Vector3(0.1, 0.05, 0.3), Vector3(-0.94, 1.12, 0.0), iron)
	# 貨板：四條繩子收到吊環
	var deck_y: float = 0.3
	_box_part(n, Vector3(1.5, 0.07, 1.1), Vector3(0.0, deck_y, 0.0), plank)
	for i: int in 5:
		_box_part(n, Vector3(0.26, 0.02, 1.1), Vector3(-0.6 + i * 0.3, deck_y + 0.045, 0.0), wood)
	for cx: float in [-0.7, 0.7]:
		for cz: float in [-0.5, 0.5]:
			_beam(n, Vector3(cx, deck_y + 0.04, cz), ring, 0.016, rope)
	# 貨板上兩口封好的木箱（地下市場的貨）
	_box_part(n, Vector3(0.56, 0.5, 0.5), Vector3(0.34, deck_y + 0.3, -0.2), plank)
	_box_part(n, Vector3(0.6, 0.04, 0.54), Vector3(0.34, deck_y + 0.57, -0.2), wood)
	_box_part(n, Vector3(0.6, 0.05, 0.06), Vector3(0.34, deck_y + 0.3, 0.06), wood)
	_box_part(n, Vector3(0.4, 0.34, 0.4), Vector3(0.44, deck_y + 0.22, 0.32), plank)
	_box_part(n, Vector3(0.36, 0.3, 0.36), Vector3(0.36, deck_y + 0.76, -0.22), plank)
	_build_shaft_mouth(n, wood, plank, iron)
	# 西柱上的提燈（面向梨攤那一側）
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.35, 0.25, 0.14)
	glass.roughness = 0.3
	glass.emission_enabled = true
	glass.emission = FrostbridgeLook.LAMP
	glass.emission_energy_multiplier = 4.5
	_box_part(n, Vector3(0.34, 0.04, 0.04), Vector3(-1.26, 2.2, 0.0), iron)
	_box_part(n, Vector3(0.02, 0.12, 0.02), Vector3(-1.4, 2.13, 0.0), iron)
	_box_part(n, Vector3(0.18, 0.03, 0.18), Vector3(-1.4, 2.07, 0.0), iron)
	_box_part(n, Vector3(0.13, 0.2, 0.13), Vector3(-1.4, 1.96, 0.0), glass)
	_box_part(n, Vector3(0.16, 0.03, 0.16), Vector3(-1.4, 1.85, 0.0), iron)
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = FrostbridgeLook.LAMP
	light.light_energy = 2.3
	light.omni_range = 7.5
	light.omni_attenuation = 1.2
	light.light_specular = 0.3
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 0.9
	light.position = Vector3(-1.1, 1.9, 0.5)
	n.add_child(light)
	level.add_child(n)
	_marker("CellarTrigger", LIFT_POS + Vector3(0.0, 1.0, 0.0))


## 貨梯底下打開的井口（D-214）：一圈石框（柱子就立在框上）、裡面是黑的、底下有暖光往上照到貨板底與繩子；
## 兩片掀開的木門（北邊那片立著、南邊那片整片翻開躺在雪上）；橫樑、石框、木箱上有積雪。
## 地面挖不了洞：黑的那一塊是不受光的面，靠石框的高度與框內側的暖光讓它讀成「往下的洞」。
const SHAFT_HALF: Vector2 = Vector2(0.95, 0.75)
const SHAFT_CURB_H: float = 0.26
const SHAFT_CURB_T: float = 0.22
const SHAFT_GLOW_ENERGY: float = 2.8


func _build_shaft_mouth(n: Node3D, wood: Material, plank: Material, iron: Material) -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.3, 0.31, 0.34)
	stone.roughness = 0.96
	var snow := StandardMaterial3D.new()
	snow.albedo_color = FrostbridgeLook.SNOW
	snow.roughness = 0.9
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.006, 0.005, 0.005)
	var hx: float = SHAFT_HALF.x
	var hz: float = SHAFT_HALF.y
	var t: float = SHAFT_CURB_T
	var h: float = SHAFT_CURB_H
	# 洞：不受光的黑面（比地面高一點點，避免跟石板閃爍）
	var hole := MeshInstance3D.new()
	hole.name = "ShaftDark"
	var hm := BoxMesh.new()
	hm.size = Vector3(hx * 2.0, 0.02, hz * 2.0)
	hole.mesh = hm
	hole.material_override = dark
	hole.position = Vector3(0.0, 0.02, 0.0)
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(hole)
	# 石框：南北兩條長的、東西兩條短的（柱子立在短的上面）；每條切成兩三塊、高低差一點，不是一整條方塊
	for sz: float in [-1.0, 1.0]:
		for i: int in 3:
			var w: float = (hx * 2.0 + t * 2.0) / 3.0
			var dh: float = [0.0, 0.03, -0.02][i] * sz
			_box_part(n, Vector3(w - 0.02, h + dh, t), Vector3(-hx - t + w * (float(i) + 0.5), (h + dh) * 0.5, sz * (hz + t * 0.5)), stone)
	for sx: float in [-1.0, 1.0]:
		for i: int in 2:
			var d: float = hz
			var dh2: float = [0.02, -0.02][i] * sx
			_box_part(n, Vector3(t, h + dh2, d - 0.02), Vector3(sx * (hx + t * 0.5), (h + dh2) * 0.5, -hz + d * (float(i) + 0.5)), stone)
	# 框上的積雪（南邊那條靠人走的地方踩掉了一段）
	_box_part(n, Vector3(hx * 2.0 + t * 2.0, 0.05, t + 0.04), Vector3(0.0, h + 0.035, -(hz + t * 0.5)), snow)
	_box_part(n, Vector3(0.8, 0.045, t + 0.03), Vector3(-0.75, h + 0.03, hz + t * 0.5), snow)
	_box_part(n, Vector3(0.45, 0.04, t + 0.02), Vector3(0.85, h + 0.045, hz + t * 0.5), snow)
	# 兩片掀開的木門：北邊那片立著（往後靠一點），南邊那片整片翻開躺在雪上
	var north := Node3D.new()
	north.name = "HatchNorth"
	north.position = Vector3(0.0, h, -(hz + t + 0.03))
	north.rotation_degrees.x = 76.0
	_hatch_leaf(north, hx * 2.0, hz, wood, plank, iron)
	n.add_child(north)
	var south := Node3D.new()
	south.name = "HatchSouth"
	south.position = Vector3(0.06, 0.07, hz + t + 0.08)
	south.rotation_degrees = Vector3(176.0, 3.0, 0.0)
	_hatch_leaf(south, hx * 2.0, hz, wood, plank, iron)
	n.add_child(south)
	_box_part(n, Vector3(0.7, 0.04, 0.4), Vector3(-0.5, 0.115, hz + t + 0.45), snow)
	# 橫樑、柱頂、木箱上的積雪（跟旁邊的屋頂一致）
	_box_part(n, Vector3(2.66, 0.07, 0.28), Vector3(0.0, 3.145, 0.0), snow)
	_box_part(n, Vector3(0.62, 0.035, 0.56), Vector3(0.34, 0.3 + 0.607, -0.2), snow)
	# 底下的暖光：往上照到石框內側、貨板底、繩子。不投影、不打高光。
	var glow := OmniLight3D.new()
	glow.name = "ShaftGlow"
	glow.light_color = Color(1.0, 0.62, 0.3)
	glow.light_energy = SHAFT_GLOW_ENERGY
	glow.light_specular = 0.0
	glow.omni_range = 2.7
	glow.omni_attenuation = 1.4
	glow.shadow_enabled = false
	glow.light_volumetric_fog_energy = 1.6
	glow.position = Vector3(0.0, 0.14, 0.0)
	n.add_child(glow)


## 一片木門（原點在鉸鏈那一邊，往 -z 伸出去 depth 公尺）：底板＋三條木條＋兩條鐵帶＋拉環
func _hatch_leaf(leaf: Node3D, width: float, depth: float, wood: Material, plank: Material, iron: Material) -> void:
	_box_part(leaf, Vector3(width, 0.05, depth), Vector3(0.0, 0.0, -depth * 0.5), plank)
	for i: int in 3:
		_box_part(leaf, Vector3(width * 0.3, 0.012, depth - 0.04), Vector3(-width * 0.33 + width * 0.33 * i, 0.03, -depth * 0.5), wood)
	for sx: float in [-1.0, 1.0]:
		_box_part(leaf, Vector3(0.07, 0.016, depth + 0.02), Vector3(sx * width * 0.36, 0.036, -depth * 0.5), iron)
	_box_part(leaf, Vector3(0.16, 0.03, 0.05), Vector3(0.0, 0.045, -depth + 0.1), iron)


## 兩點之間的一根圓桿（繩子、斜撐）
func _beam(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = a.distance_to(b)
	cm.radial_segments = 6
	cm.rings = 0
	mi.mesh = cm
	mi.material_override = mat
	mi.position = (a + b) * 0.5
	var dir: Vector3 = (b - a).normalized()
	if absf(dir.dot(Vector3.UP)) < 0.999:
		mi.basis = Basis(Quaternion(Vector3.UP, dir))
	parent.add_child(mi)


## 截圖用：藥的事講完了。諾恩站在梨攤西南、面向艾妲（攤燈、帳本、後面的貨梯都在畫面裡）；
## lift＝艾妲講完了，諾恩站在貨梯西南邊面向它。
func _dev_stage_market(at_lift: bool) -> void:
	if player == null:
		return
	var me := Vector3(2.5, 0.0, 2.1)
	var target := ADA_POS
	var her_off := Vector3(-1.5, 0.0, -0.5)
	if at_lift:
		# 攤子的東南邊：貨梯在正前方約 5 m，攤子不擋鏡頭
		me = Vector3(7.9, 0.0, 0.5)
		target = LIFT_POS
		her_off = Vector3(-2.3, 0.0, 0.2)
	player.global_position = Vector3(me.x, level.ground_y(me) + 0.05, me.z)
	player.rotation.y = atan2(-(target.x - me.x), -(target.z - me.z))
	player.yaw = player.rotation.y
	player.health.hp = 82.0
	player.reversal.awakened_once = true
	player.reversal.unlock("poison")
	player.reversal.equip("poison")
	var sheila: Node3D = level.get_node_or_null("Sheila") as Node3D
	if sheila != null:
		sheila.set_physics_process(false)
		var her: Vector3 = me + her_off
		sheila.global_position = Vector3(her.x, level.ground_y(her), her.z)
		sheila.rotation.y = player.rotation.y
	if crate != null and is_instance_valid(crate):
		crate.taken = true
		crate._show_taken(false)
	player.snap_camera()


# ---------------------------------------------------------------- 追擊的送葬者（D-205）

## drop＝對話剛結束，從屋頂跳下來；false＝讀檔／重試，已經站在門邊
func _spawn_pursuer(drop: bool) -> void:
	if pursuer != null or level.has_node("RbPursuer"):
		return
	_build_lamp_stump()
	pursuer = Undertaker.new()
	pursuer.name = "RbPursuer"
	pursuer.position = PURSUER_SPAWN + (Vector3(PURSUER_LEAP, PURSUER_DROP, 0.0) if drop else Vector3.ZERO)
	level.add_child(pursuer)
	pursuer.begin_pursuit()
	pursuer.set_facing(deg_to_rad(180.0))
	pursuer.scripted_walk(PURSUER_SPAWN, PURSUER_LEAP_SPEED if drop else 0.0)
	pursuer.scripted_look_at(player.global_position if player != null else PURSUER_BLOCK)
	_attach_lamp_chunk()
	_pursuer_landed = not drop
	if drop:
		Sfx.play_at(level, "whoosh", PURSUER_SPAWN + Vector3.UP * 3.0, 0.0, 0.0, 10.0)


## 讀檔／重試回到「第一次進霧前」：牠已經丟完，堵在北街
func _spawn_pursuer_blocking() -> void:
	if pursuer != null or level.has_node("RbPursuer") or Game.session.state.get_flag("rb.reached_south", false):
		return
	_build_lamp_stump()
	pursuer = Undertaker.new()
	pursuer.name = "RbPursuer"
	pursuer.position = PURSUER_BLOCK
	level.add_child(pursuer)
	pursuer.begin_pursuit()
	pursuer.set_facing(deg_to_rad(180.0))
	pursuer.scripted_walk(PURSUER_BLOCK, 0.0)
	throw_phase = 3
	_drop_chunk_at_barrels()


func _update_pursuer() -> void:
	if pursuer == null or not is_instance_valid(pursuer):
		return
	if not _pursuer_landed:
		if pursuer.is_on_floor():
			_pursuer_landed = true
			_on_pursuer_landed()
		return
	if throw_phase == 1 or throw_phase == 2:
		return
	if throw_phase == 3:
		# 堵在北街，盯著諾恩
		pursuer.scripted_walk(PURSUER_BLOCK, PURSUER_SPEED)
		pursuer.scripted_look_at(player.global_position)
		return
	# 跟在推車／諾恩後面：兩個裡面比較北邊的那個再往北 PURSUER_GAP
	var lead_z: float = player.global_position.z
	if cart != null:
		lead_z = minf(lead_z, cart.global_position.z)
	var z: float = clampf(lead_z - PURSUER_GAP, PURSUER_SPAWN.z, PURSUER_STOP_Z)
	var x: float = lerpf(PURSUER_SPAWN.x, PURSUER_BLOCK.x, inverse_lerp(PURSUER_SPAWN.z, PURSUER_SPAWN.z + 4.0, z))
	x = clampf(x, minf(PURSUER_SPAWN.x, PURSUER_BLOCK.x), maxf(PURSUER_SPAWN.x, PURSUER_BLOCK.x))
	pursuer.scripted_walk(Vector3(x, pursuer.global_position.y, z), 0.0 if Game.is_player_locked() else PURSUER_SPEED)
	pursuer.scripted_look_at(player.global_position)


## 落地：雪往外噴、燈柱斷掉的那一聲、鏡頭震一下
func _on_pursuer_landed() -> void:
	var at: Vector3 = pursuer.global_position
	Sfx.play_at(level, "blunt", at + Vector3.UP * 0.3, 3.0, 0.03, 12.0)
	Sfx.play_at(level, "iron_clang", LAMP_STUMP + Vector3.UP, 0.0, 0.03, 10.0)
	pursuer._ground_puff(at, Vector3(0.9, 0.05, 0.9), 40, Color(0.78, 0.8, 0.86, 0.7))
	if player != null:
		player.shake(0.7)


func _begin_barrel_throw() -> void:
	if throw_phase != 0:
		return
	if pursuer == null or not is_instance_valid(pursuer) or lamp_chunk == null or not is_instance_valid(lamp_chunk):
		_on_barrels_hit()
		return
	throw_phase = 1
	_throw_t = throw_windup_sec
	pursuer.scripted_walk(pursuer.global_position, 0.0)
	pursuer.scripted_look_at(THROW_TARGET)
	pursuer.begin_throw_windup(throw_windup_sec)
	# 那截燈柱舉過頭
	var t := lamp_chunk.create_tween().set_parallel(true)
	t.tween_property(lamp_chunk, "position", Vector3(-0.55, 1.55, 0.1), throw_windup_sec * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(lamp_chunk, "rotation_degrees", Vector3(-40.0, 0.0, -8.0), throw_windup_sec * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_throw(delta: float) -> void:
	if throw_phase == 1:
		_throw_t -= delta
		if debug_hold_throw == "windup" and pursuer != null and is_instance_valid(pursuer):
			_throw_t = maxf(_throw_t, 0.05)
			pursuer.throw_windup = maxf(pursuer.throw_windup, 0.05)
		if _throw_t <= 0.0:
			_release_chunk()
	elif throw_phase == 2:
		_throw_t += delta
		if debug_hold_throw == "flight":
			_throw_t = minf(_throw_t, throw_flight_sec * 0.33)
		var k: float = clampf(_throw_t / maxf(throw_flight_sec, 0.01), 0.0, 1.0)
		if lamp_chunk != null and is_instance_valid(lamp_chunk):
			lamp_chunk.global_position = _throw_from.lerp(THROW_TARGET, k) + Vector3.UP * (THROW_ARC * 4.0 * k * (1.0 - k))
			lamp_chunk.rotate_x(delta * 11.0)
		if k >= 1.0:
			_on_barrels_hit()


func _release_chunk() -> void:
	throw_phase = 2
	_throw_t = 0.0
	if lamp_chunk == null or not is_instance_valid(lamp_chunk):
		_on_barrels_hit()
		return
	lamp_chunk.reparent(level, true)
	_throw_from = lamp_chunk.global_position
	Sfx.play_at(level, "whoosh", _throw_from, 3.0, 0.03, 12.0)


func _on_barrels_hit() -> void:
	throw_phase = 3
	_impact_burst(THROW_TARGET)
	_drop_chunk_at_barrels()
	if player != null:
		player.shake(0.45)
	_break_barrels(true)
	Game.session.set_flag("rb.barrels_broken", true)


## 燈頭砸碎在藥桶上的那一下：一閃暖光（0.35 秒淡掉）、往上噴的木屑、從桶裡湧出來的綠色藥霧。
## 木屑與綠霧第 68 輪做過、怎麼拍都拍不到，拿掉了——原因是粒子其實噴在送葬者腳下（8 m 外、鏡頭後面），
## 不是藥桶這裡（D-208，EnemyActor.puff_build 的說明）。現在先擺好位置才開始噴。
func _impact_burst(at: Vector3) -> void:
	if pursuer != null and is_instance_valid(pursuer) and pursuer.is_inside_tree():
		# 木屑：細長的小片（不是圓點）、各轉各的、往上炸開、很快掉下來
		var chips: CPUParticles3D = pursuer.puff_build(Vector3(1.1, 0.25, 0.5), 46, Color(0.62, 0.47, 0.3, 1.0))
		chips.name = "RbImpactChips"
		var sliver := QuadMesh.new()
		sliver.size = Vector2(0.34, 0.075)
		sliver.material = ParticleLook.material(Color(0.62, 0.47, 0.3, 1.0), false, BaseMaterial3D.BILLBOARD_PARTICLES)
		chips.mesh = sliver
		chips.angle_min = 0.0
		chips.angle_max = 360.0
		chips.angular_velocity_min = -540.0
		chips.angular_velocity_max = 540.0
		chips.lifetime = 0.9
		chips.initial_velocity_min = 2.2
		chips.initial_velocity_max = 5.2
		chips.spread = 60.0
		chips.gravity = Vector3(0, -9.0, 0)
		chips.damping_min = 0.4
		chips.damping_max = 1.2
		chips.scale_amount_min = 0.5
		chips.scale_amount_max = 1.1
		pursuer.puff_start(chips, at + Vector3.UP * 0.5)
		# 藥霧：很多顆很淡的大圓點疊成一團（一顆一顆太實會像彩色泡泡），慢慢往上湧，接上破桶之後主街的那一團毒霧
		var puff: CPUParticles3D = pursuer.puff_build(Vector3(1.5, 0.3, 0.8), 56, Color(0.42, 0.88, 0.38, 0.24))
		puff.name = "RbImpactPuff"
		puff.lifetime = 1.6
		puff.initial_velocity_min = 0.6
		puff.initial_velocity_max = 2.0
		puff.gravity = Vector3(0, 0.4, 0)
		puff.scale_amount_min = 2.8
		puff.scale_amount_max = 5.2
		pursuer.puff_start(puff, at + Vector3.UP * 0.4)
	var flash := OmniLight3D.new()
	flash.name = "RbImpactFlash"
	flash.light_color = Color(1.0, 0.7, 0.4)
	flash.light_energy = 6.0
	flash.omni_range = 7.0
	flash.shadow_enabled = false
	flash.position = at + Vector3.UP * 0.5
	level.add_child(flash)
	var t := flash.create_tween()
	t.tween_property(flash, "light_energy", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(flash.queue_free)


## 那截燈柱躺在藥桶旁，燈熄了
func _drop_chunk_at_barrels() -> void:
	if lamp_chunk == null or not is_instance_valid(lamp_chunk):
		lamp_chunk = _build_lamp_chunk()
		level.add_child(lamp_chunk)
	elif lamp_chunk.get_parent() != level:
		lamp_chunk.reparent(level, true)
	lamp_chunk.position = Vector3(THROW_TARGET.x, level.ground_y(THROW_TARGET) + 0.07, THROW_TARGET.z)
	lamp_chunk.rotation_degrees = Vector3(90.0, 38.0, 0.0)
	var light: OmniLight3D = lamp_chunk.get_node_or_null("Glow") as OmniLight3D
	if light != null:
		light.light_energy = 0.0
	var glass: MeshInstance3D = lamp_chunk.get_node_or_null("Glass") as MeshInstance3D
	if glass != null:
		(glass.material_override as StandardMaterial3D).emission_energy_multiplier = 0.0


## 拖在牠左手外側：斷口在手上，燈頭拖在身旁的雪地上（還亮著，從正面、背面都看得到，暖光打在牠的袍子側面）
func _attach_lamp_chunk() -> void:
	var torso: Node3D = pursuer.get_node_or_null("Body/Torso") as Node3D
	if torso == null:
		return
	lamp_chunk = _build_lamp_chunk()
	torso.add_child(lamp_chunk)
	lamp_chunk.position = LAMP_CARRY_POS
	lamp_chunk.rotation_degrees = LAMP_CARRY_ROT


## 一截折斷的燈柱：鐵桿（斷口在原點，往 +Y 長）＋燈頭（鐵蓋、鐵底、還亮著的玻璃）
func _build_lamp_chunk() -> Node3D:
	var n := Node3D.new()
	n.name = "RbLampChunk"
	var iron: Material = Undertaker.frame_iron_material()
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.04
	pm.bottom_radius = 0.05
	pm.height = 1.45
	pm.radial_segments = 10
	pole.mesh = pm
	pole.material_override = iron
	pole.position.y = 0.725
	n.add_child(pole)
	for spec: Array in [[Vector3(0.3, 0.05, 0.3), 1.47], [Vector3(0.34, 0.06, 0.34), 1.8], [Vector3(0.16, 0.1, 0.16), 1.87]]:
		_box_part(n, spec[0] as Vector3, Vector3(0.0, float(spec[1]), 0.0), iron)
	for cx: float in [-0.12, 0.12]:
		for cz: float in [-0.12, 0.12]:
			_box_part(n, Vector3(0.025, 0.3, 0.025), Vector3(cx, 1.63, cz), iron)
	var glass := MeshInstance3D.new()
	glass.name = "Glass"
	var gm := BoxMesh.new()
	gm.size = Vector3(0.21, 0.28, 0.21)
	glass.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.35, 0.25, 0.14)
	gmat.roughness = 0.3
	gmat.emission_enabled = true
	gmat.emission = Color(1.0, 0.6, 0.24)
	gmat.emission_energy_multiplier = 4.5
	glass.material_override = gmat
	glass.position.y = 1.63
	n.add_child(glass)
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = Color(1.0, 0.66, 0.34)
	light.light_energy = 2.6
	light.omni_range = 5.0
	light.shadow_enabled = false
	light.position.y = 1.63
	n.add_child(light)
	return n


## 門邊被踩斷的燈柱：剩一截歪掉的鐵桿
func _build_lamp_stump() -> void:
	if level.has_node("RbLampStump"):
		return
	var stump := Node3D.new()
	stump.name = "RbLampStump"
	stump.position = Vector3(LAMP_STUMP.x, level.ground_y(LAMP_STUMP), LAMP_STUMP.z)
	stump.rotation_degrees = Vector3(0.0, 0.0, 14.0)
	var iron: Material = Undertaker.frame_iron_material()
	_box_part(stump, Vector3(0.22, 0.12, 0.22), Vector3(0.0, 0.06, 0.0), iron)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.05
	pm.bottom_radius = 0.06
	pm.height = 1.1
	pm.radial_segments = 10
	pole.mesh = pm
	pole.material_override = iron
	pole.position.y = 0.6
	stump.add_child(pole)
	level.add_child(stump)


# ---------------------------------------------------------------- 場景

func _build_markers() -> void:
	_marker("RbNorthCorner", Vector3(0.0, RISE + 1.0, -30.0))
	_marker("RbMistEdge", Vector3(0.0, 1.0, MIST_CENTER.z - MIST_RADIUS + 0.6))
	_marker("RbSouthGate", Vector3(-0.6, 1.0, 10.8))


func _marker(marker_name: String, pos: Vector3) -> void:
	if level.has_node(marker_name):
		return
	var m := Marker3D.new()
	m.name = marker_name
	m.position = pos
	level.add_child(m)


## 麵包店側門上的門燈（D-207）：南街口西側原本整面牆沒有光（近看是一片死黑）。一盞暖燈照亮門邊、推車與守衛戰的北半場，
## 跟牠噴出來的綠霧一暖一冷。不投影（多一盞投影燈太貴）。
const BAKERY_LANTERN: Vector3 = Vector3(-3.28, 2.35, 12.6)


func _build_bakery_lantern() -> void:
	var n := Node3D.new()
	n.name = "RbBakeryLantern"
	n.position = BAKERY_LANTERN
	var iron: Material = Undertaker.frame_iron_material()
	# 牆上的鐵架：一根橫桿＋吊著的燈
	_box_part(n, Vector3(0.5, 0.04, 0.04), Vector3(0.08, 0.3, 0.0), iron)
	_box_part(n, Vector3(0.03, 0.14, 0.03), Vector3(0.3, 0.22, 0.0), iron)
	_box_part(n, Vector3(0.22, 0.04, 0.22), Vector3(0.3, 0.14, 0.0), iron)
	_box_part(n, Vector3(0.2, 0.03, 0.2), Vector3(0.3, -0.13, 0.0), iron)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.35, 0.25, 0.14)
	glass.roughness = 0.3
	glass.emission_enabled = true
	glass.emission = FrostbridgeLook.LAMP
	glass.emission_energy_multiplier = 5.0
	_box_part(n, Vector3(0.15, 0.24, 0.15), Vector3(0.3, 0.0, 0.0), glass)
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = FrostbridgeLook.LAMP
	light.light_energy = 1.7
	light.omni_range = 7.5
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 0.7
	light.position = Vector3(0.45, 0.0, 0.0)
	n.add_child(light)
	level.add_child(n)


## 南街的吊燈（D-216）：守衛從南端走過來、站在街上的那一段，牠背後原本只有藍霧——牠跟霧同一個明度，輪廓不見
## （第 73 輪看 `45-rb-guardian` 的結論）。一條鐵鏈橫過街（兩邊牆上各一塊鐵座），中間垂下來吊一盞大燈：
## 照亮牠背後的石板與霧，牠變成亮背景前的黑剪影，影子往北（諾恩這邊）拉長。
## 鏈子的下垂用 SOUTH_LANTERN_SPANS 段直鏈接起來（拋物線）。這一盞投影子：守衛戰的主光，影子是畫面的一部分。
const SOUTH_LANTERN_Z: float = 23.6
const SOUTH_LANTERN_HALF: float = 3.46
## 兩邊的房子在這一段高 6.1 m／7.4 m：鐵座釘在二樓的牆上
const SOUTH_LANTERN_ANCHOR_Y: float = 5.4
const SOUTH_LANTERN_SAG: float = 0.42
## 燈從鏈子最低點再往下吊多少
const SOUTH_LANTERN_DROP: float = 0.26
const SOUTH_LANTERN_SPANS: int = 8
const SOUTH_LANTERN_LINK: Vector3 = Vector3(0.14, 0.085, 0.014)
const SOUTH_LANTERN_ENERGY: float = 5.0
const SOUTH_LANTERN_RANGE: float = 13.5
## 在體積霧裡的亮度：要亮到變成一團暖霧（牠的剪影靠這個）
const SOUTH_LANTERN_FOG: float = 3.2
## 燈底下、牠背後那一段多一團比較濃的霧（橢球，邊緣淡出）：背景更亮，牠跟鏡頭之間的霧不變 → 剪影更黑
const SOUTH_HAZE_SIZE: Vector3 = Vector3(7.5, 6.5, 9.0)
const SOUTH_HAZE_OFFSET: Vector3 = Vector3(0.0, 2.6, 1.8)
const SOUTH_HAZE_DENSITY: float = 0.05


## 鏈子上第 i 個節點的位置（i＝0～SOUTH_LANTERN_SPANS；吊燈節點的座標）
static func south_chain_point(i: int) -> Vector3:
	var t: float = float(i) / float(SOUTH_LANTERN_SPANS)
	var k: float = 2.0 * t - 1.0
	return Vector3(lerpf(-SOUTH_LANTERN_HALF, SOUTH_LANTERN_HALF, t), SOUTH_LANTERN_ANCHOR_Y - SOUTH_LANTERN_SAG * (1.0 - k * k), 0.0)


func _build_south_lantern() -> void:
	var n := Node3D.new()
	n.name = "RbSouthLantern"
	n.position = Vector3(0.0, 0.0, SOUTH_LANTERN_Z)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.07, 0.07, 0.08)
	iron.metallic = 0.55
	iron.roughness = 0.5
	# 兩邊牆上的鐵座＋橫過街的鏈子
	for side: float in [-1.0, 1.0]:
		_box_part(n, Vector3(0.08, 0.26, 0.2), Vector3(side * (SOUTH_LANTERN_HALF + 0.02), SOUTH_LANTERN_ANCHOR_Y, 0.0), iron)
	for i: int in SOUTH_LANTERN_SPANS:
		var a: Vector3 = south_chain_point(i)
		var b: Vector3 = south_chain_point(i + 1)
		var span := MeshInstance3D.new()
		span.name = "Chain%d" % i
		span.mesh = ChainMesh.build(a.distance_to(b), SOUTH_LANTERN_LINK.x, SOUTH_LANTERN_LINK.y, SOUTH_LANTERN_LINK.z)
		span.material_override = iron
		span.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		span.position = a
		# ChainMesh 從原點往 -Y 垂：把 -Y 轉到這一段的方向
		span.basis = Basis(Quaternion(Vector3.DOWN, (b - a).normalized()))
		n.add_child(span)
	# 中間垂下來的一小段鏈子＋燈
	var low: Vector3 = Vector3(0.0, SOUTH_LANTERN_ANCHOR_Y - SOUTH_LANTERN_SAG, 0.0)
	var drop := MeshInstance3D.new()
	drop.name = "Drop"
	drop.mesh = ChainMesh.build(SOUTH_LANTERN_DROP, 0.1, 0.06, 0.011)
	drop.material_override = iron
	drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	drop.position = low
	n.add_child(drop)
	var lamp := Node3D.new()
	lamp.name = "Lamp"
	lamp.position = low + Vector3(0.0, -SOUTH_LANTERN_DROP, 0.0)
	n.add_child(lamp)
	# 八角尖頂（上面一小片雪）、發光的玻璃、四角鐵條、底板
	_cone_part(lamp, 0.03, 0.27, 0.2, Vector3(0.0, -0.1, 0.0), iron)
	var snow := StandardMaterial3D.new()
	snow.albedo_color = FrostbridgeLook.SNOW
	snow.roughness = 0.9
	_cone_part(lamp, 0.065, 0.155, 0.07, Vector3(0.0, -0.055, 0.0), snow)
	_box_part(lamp, Vector3(0.36, 0.04, 0.36), Vector3(0.0, -0.22, 0.0), iron)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.35, 0.25, 0.14)
	glass.roughness = 0.3
	glass.emission_enabled = true
	glass.emission = FrostbridgeLook.LAMP
	glass.emission_energy_multiplier = 7.0
	_box_part(lamp, Vector3(0.27, 0.4, 0.27), Vector3(0.0, -0.44, 0.0), glass)
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			_box_part(lamp, Vector3(0.028, 0.42, 0.028), Vector3(cx * 0.145, -0.44, cz * 0.145), iron)
	_box_part(lamp, Vector3(0.34, 0.04, 0.34), Vector3(0.0, -0.66, 0.0), iron)
	for part: Node in lamp.get_children():
		(part as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = FrostbridgeLook.LAMP
	light.light_energy = SOUTH_LANTERN_ENERGY
	light.omni_range = SOUTH_LANTERN_RANGE
	light.omni_attenuation = 1.1
	light.light_specular = 0.35
	light.shadow_enabled = true
	light.shadow_bias = 0.06
	light.light_volumetric_fog_energy = SOUTH_LANTERN_FOG
	# 光源在玻璃正中間（燈本身不投影，不會擋到自己的光）
	light.position = lamp.position + Vector3(0.0, -0.44, 0.0)
	n.add_child(light)
	var haze := FogVolume.new()
	haze.name = "Haze"
	haze.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	haze.size = SOUTH_HAZE_SIZE
	var fog := FogMaterial.new()
	fog.density = SOUTH_HAZE_DENSITY
	fog.albedo = Color(0.9, 0.86, 0.8)
	fog.edge_fade = 0.5
	haze.material = fog
	haze.position = SOUTH_HAZE_OFFSET
	n.add_child(haze)
	level.add_child(n)


## 圓錐台（燈的尖頂、雪帽）：八邊
func _cone_part(parent: Node3D, top_r: float, bottom_r: float, height: float, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bottom_r
	cm.height = height
	cm.radial_segments = 8
	cm.rings = 0
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


## 北街北端的鐵門（灰盒：鐵條＋兩道橫槓，擋人）；雷德在門後
func _build_gate() -> void:
	var gate := StaticBody3D.new()
	gate.name = "RbGate"
	gate.position = Vector3(0.0, RISE, GATE_Z)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.16, 0.17)
	iron.metallic = 0.6
	iron.roughness = 0.45
	var bars: int = 13
	for i: int in bars:
		var x: float = lerpf(-GATE_HALF, GATE_HALF, float(i) / float(bars - 1))
		_box_part(gate, Vector3(0.05, 2.4, 0.05), Vector3(x, 1.2, 0.0), iron)
	for y: float in [0.25, 1.35, 2.35]:
		_box_part(gate, Vector3(GATE_HALF * 2.0 + 0.1, 0.07, 0.07), Vector3(0.0, y, 0.0), iron)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GATE_HALF * 2.0 + 0.4, 2.6, 0.3)
	shape.shape = box
	shape.position = Vector3(0.0, 1.3, 0.0)
	gate.add_child(shape)
	level.add_child(gate)
	if Game.session.state.get_flag("rb.opening_done", false):
		return
	red = Puppet.new()
	red.name = "Red"
	red.coat_color = Color(0.24, 0.2, 0.15)
	red.trim_color = Color(0.5, 0.42, 0.3)
	red.position = RED_POS
	red.rotation_degrees.y = 180.0
	level.add_child(red)
	# 程序人偶預設拿著鐘錘：雷德手上不拿東西
	var hammer: Node = red.hand("R").get_node_or_null("BellHammer") if red.hand("R") != null else null
	if hammer != null:
		hammer.queue_free()


func _build_barrels() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.34, 0.25, 0.17)
	wood.roughness = 0.85
	var band := StandardMaterial3D.new()
	band.albedo_color = Color(0.2, 0.2, 0.21)
	band.metallic = 0.5
	var label := StandardMaterial3D.new()
	label.albedo_color = Color(0.82, 0.8, 0.72)
	label.roughness = 0.9
	var i: int = 0
	for spot: Vector3 in BARREL_SPOTS:
		var b := Node3D.new()
		b.name = "RbBarrel%d" % i
		b.position = spot
		b.rotation.y = 0.7 * float(i)
		var body := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.3
		cyl.bottom_radius = 0.3
		cyl.height = 0.9
		body.mesh = cyl
		body.material_override = wood
		body.position.y = 0.45
		b.add_child(body)
		for y: float in [0.15, 0.75]:
			var ring := MeshInstance3D.new()
			var rc := CylinderMesh.new()
			rc.top_radius = 0.315
			rc.bottom_radius = 0.315
			rc.height = 0.05
			ring.mesh = rc
			ring.material_override = band
			ring.position.y = y
			b.add_child(ring)
		# 骷髏標與「有毒」（灰盒：一塊淺色標籤＋字）
		var tag := MeshInstance3D.new()
		var tq := QuadMesh.new()
		tq.size = Vector2(0.34, 0.3)
		tag.mesh = tq
		tag.material_override = label
		tag.position = Vector3(0.0, 0.5, 0.305)
		b.add_child(tag)
		var text := Label3D.new()
		text.name = "Toxic"
		text.text = "RB_BARREL_TOXIC"
		text.font_size = 40
		text.pixel_size = 0.004
		text.modulate = Color(0.55, 0.06, 0.05)
		text.outline_size = 0
		text.position = Vector3(0.0, 0.5, 0.31)
		b.add_child(text)
		barrels.append(b)
		level.add_child(b)
		i += 1


## 藥桶破了：倒下、裂開（animate＝剛發生；讀檔時直接擺成破掉的樣子）
func _break_barrels(animate: bool) -> void:
	if barrels.is_empty() or bool(barrels[0].get_meta("broken", false)):
		return
	var i: int = 0
	for b: Node3D in barrels:
		b.set_meta("broken", true)
		var tilt := Vector3(deg_to_rad(84.0), 0.6 * float(i) - 0.5, 0.0)
		if animate and b.is_inside_tree():
			# 倒下去的同時才墊高到躺平的高度（原本一開始就墊高：還直立的桶子會先浮在半空 0.35 秒）
			var t := b.create_tween().set_parallel(true)
			t.tween_property(b, "rotation", tilt, 0.35).set_delay(0.08 * float(i)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_property(b, "position:y", 0.3, 0.35).set_delay(0.08 * float(i)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		else:
			b.rotation = tilt
			b.position.y = 0.3
		i += 1
	if animate:
		Sfx.play_at(level, "blunt", BARREL_SPOTS[0] + Vector3.UP, 4.0)
		Sfx.play_at(level, "rubble_scrape", BARREL_SPOTS[2] + Vector3.UP, 0.0)
		var hud: Hud = level.get_node_or_null("Hud") as Hud
		if hud != null:
			hud.show_banner("RB_BARRELS_BROKEN", 3.5)
	_spawn_mist()


func _spawn_mist() -> void:
	if mist != null or Game.session.state.get_flag("rb.mist_reentered", false):
		return
	mist = PoisonMist.create(MIST_RADIUS, "barrel_mist")
	mist.name = "RbBarrelMist"
	mist.position = MIST_CENTER
	level.add_child(mist)


## 確認完之後霧慢慢變薄、散掉（推車才過得去）
func _clear_mist() -> void:
	if mist == null or _mist_clearing:
		return
	_mist_clearing = true
	var m: PoisonMist = mist
	var t := m.create_tween()
	t.tween_method(func(r: float) -> void:
		if is_instance_valid(m) and m.zone != null:
			m.zone.radius = r
			m.scale = Vector3(r / MIST_RADIUS, 1.0, r / MIST_RADIUS), MIST_RADIUS, 0.05, mist_clear_sec)
	t.tween_callback(func() -> void:
		if is_instance_valid(m):
			m.queue_free()
		mist = null
		_mist_clearing = false)


func _build_cart() -> void:
	var route := PackedVector3Array()
	for p: Vector2 in CART_ROUTE_XZ:
		var v := Vector3(p.x, 0.0, p.y)
		v.y = level.ground_y(v)
		route.append(v)
	cart = Caravan.new()
	cart.name = "RbCart"
	cart.route = route
	level.add_child(cart)
	# 車上只有波克一個人（車隊的第二名傷者不放）
	for part: String in ["Cart/Wounded1", "Cart/Blanket1"]:
		var n: Node3D = cart.get_node_or_null(part) as Node3D
		if n != null:
			n.visible = false
	cart.runner.speed = 0.0
	_corner_traveled = _distance_to_point(route, CORNER_POINT)
	_hold_traveled = _distance_to_point(route, HOLD_POINT)
	cart.arrived.connect(_on_cart_arrived)
	var st: GameState = Game.session.state
	if st.get_flag("rb.reached_south", false):
		cart.runner.traveled = cart.runner.length()
		cart.runner.is_arrived = true
	elif st.get_flag("rb.barrels_broken", false):
		cart.runner.traveled = _hold_traveled
	cart._sync()


static func _distance_to_point(route: PackedVector3Array, index: int) -> float:
	var d: float = 0.0
	for i: int in range(1, mini(index + 1, route.size())):
		d += route[i - 1].distance_to(route[i])
	return d


func _place_player(checkpoint: String) -> void:
	var spec: Array = SPAWNS.get(checkpoint, SPAWNS["rb_start"]) as Array
	var pos: Vector3 = spec[0] as Vector3
	pos.y = level.ground_y(pos) + 0.05
	player.global_position = pos
	player.rotation.y = deg_to_rad(float(spec[1]))
	player.yaw = player.rotation.y


func _box_part(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
