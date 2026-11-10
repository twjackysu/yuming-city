class_name RebootOpening
extends Node
## 新版前十分鐘（劇情重寫，D-201～D-204，docs/design/09-reboot-first-ten-minutes.md）在霜橋鎮的控制器。
## frostbridge.gd 在 Game.session.is_reboot() 時掛上這個節點，不跑切片的觸發點、石拱（石拱停用）。
## 這一版做到：開場（雷德在鐵門後、波克在推車上、生命 55）→ 推車到北街轉角 → 藥桶破了、主街上一片毒霧 →
## 第一次中毒自動覺醒（畫面中間兩行字）→ 離開、毒效結束 → 再踏回去確認 → 霧散了 → 推車到南街口。
## 席菈接應 → 南街守衛戰（D-207：單階段送葬者＋噴毒）→ 倒下、席菈問名字。藥箱、艾妲、貨梯是下一步。

const QUEST: String = GameSession.REBOOT_MAIN_QUEST
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
## 截圖旗標 `--rb-at=` 裡屬於守衛戰的三個
const GUARDIAN_SHOTS: PackedStringArray = ["guardian", "spray", "sprayed"]
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
## 截圖用（`--rb-at=guardian|spray|sprayed`）："walk"＝站在街上盯著人、"telegraph"＝噴毒前兆停在八成、"jet"＝剛噴出去
var debug_hold_guardian: String = ""


func _ready() -> void:
	level = get_parent() as StoryLevel
	player = level.get_node_or_null("Player") as PlayerController
	_build_markers()
	_build_gate()
	_build_bakery_lantern()
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


## 截圖用（`--rb-at=`）：照正式流程設旗標，推到那一段。start＝開場對話；mist＝藥桶破了、第一次進霧前；
## guardian／spray／sprayed＝南街守衛戰（席菈已經接應）
static func dev_advance(s: GameSession, at: String) -> void:
	if at in ["mist", "pursuer", "throw", "flight", "impact"] or at in GUARDIAN_SHOTS:
		s.set_flag("rb.opening_done", true)
	if at in ["mist"] or at in GUARDIAN_SHOTS:
		s.set_flag("rb.barrels_broken", true)
	if at in GUARDIAN_SHOTS:
		for flag: String in ["rb.reversal_awakened", "rb.mist_reentered", "rb.reached_south", "rb.sheila_met"]:
			s.set_flag(flag, true)


## 截圖用：守衛站在南街中段（不開打），諾恩在牠北邊、面向牠；席菈在旁邊。
func _dev_stage_guardian(at: String) -> void:
	if guardian == null or player == null:
		return
	var holds: Dictionary = {"guardian": "walk", "spray": "telegraph", "sprayed": "jet"}
	debug_hold_guardian = str(holds.get(at, "walk"))
	var gap: float = 5.2 if at == "guardian" else 3.6
	var boss_at := Vector3(0.0, 0.0, 18.4)
	guardian.global_position = Vector3(boss_at.x, level.ground_y(boss_at) + 0.05, boss_at.z)
	guardian.set_physics_process(false)
	guardian.set_facing(0.0)
	var me := Vector3(1.1, 0.0, boss_at.z - gap)
	player.global_position = Vector3(me.x, level.ground_y(me) + 0.05, me.z)
	player.rotation.y = deg_to_rad(168.0)
	player.yaw = player.rotation.y
	# 逆轉體質已經覺醒（不再跳中間那兩行字）
	player.reversal.awakened_once = true
	player.reversal.unlock("poison")
	player.reversal.equip("poison")
	var sheila: Node3D = level.get_node_or_null("Sheila") as Node3D
	if sheila != null:
		sheila.set_physics_process(false)
		sheila.global_position = Vector3(-1.7, level.ground_y(me), me.z + 0.6)
	if at == "sprayed":
		guardian.debug_hold_jet = true
		guardian.brain._set_move("spray")
		guardian._spray()
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
	if player == null or Game.session == null or not Game.session.is_reboot():
		return
	_update_cart(delta)
	_update_pursuer()
	_update_throw(delta)
	_update_guardian(delta)
	var st: GameState = Game.session.state
	match stage():
		"escape":
			# 推車推到北街轉角（或諾恩自己先走下石階）→ 送葬者把那截燈柱扔過來，砸破藥桶
			if (cart != null and cart.runner.traveled >= _corner_traveled - 0.01) or player.global_position.z >= PLAYER_CORNER_Z:
				_begin_barrel_throw()
		"poison_discovery":
			_update_mist_test(st)
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
	if Game.session.is_reboot() and stage() == "poison_discovery":
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
	Game.session.set_flag("rb.guardian_down", true)
	_guardian_down_t = guardian_down_talk_sec
	# 牠噴在地上的毒霧跟著散掉（倒下之後這一帶是安全區：下一步的藥箱在這裡試）
	for n: Node in get_tree().get_nodes_in_group("poison_mist"):
		var m: PoisonMist = n as PoisonMist
		if m != null and m.zone != null and m.zone.life > 0.6:
			m.zone.life = 0.6


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
	pursuer.begin_struggle()
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
	pursuer.begin_struggle()
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
