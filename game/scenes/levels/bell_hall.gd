extends StoryLevel
## 第 2 章「城主的飯桌」：鐘院（白盒，D-157；08-chapter2-3.md）。
## 第 1 章在白晝城街尾的鐘院門口結束 → 第 2 章章節卡 → 這裡。鐘院另開一個關卡：
## 第 2 章幾乎都在這座建築裡（城主的飯廳 → 鐘院內室的主椅與鐘盤 → 牆上的紋路 → 窗簾後面的眼睛），之後的段落往北接。
## 段落 1 飯桌：三盤煮豆、一鍋稀粥、四個缺口不一樣的碗。走到桌邊 → 伊薩替諾恩拉椅子（右腿的金屬支架吱一聲）→
## 他先問席菈的手、再問彌夏的弟弟 →「他為什麼進了鐘院？」伊薩沒有立刻回答 → 對伊薩按住看穿：攻略的稱號一個字一個字被劃掉（D-158）→
## 段落 2「他自願的。」「那你讓他現在出來。」「我做不到。」（諾恩可以先開口道歉，記 ch2.noen_apologized）→ 湯慢慢涼了 →
## 段落 3 鐘院內室（D-159）：走到北牆的門前，伊薩推開門 → 黑一下 → 內室：黎歐坐在銅椅（主椅）上，背後十幾條細管接進牆上的巨大鐘盤；
## 全章唯一的暖光（細管裡的光團慢慢往鐘盤流＝被抽走的壽命）→ 過場 ch2_leo（可跳過）「妳剪頭髮了。」→ 彌夏一巴掌、捧住他的臉 →
## 檢查點 ch2_inner → 牆上的紋路（段落 4）待續。
## 還在白晝城裡：照第 1 章的規則，屋裡一盞不投影子的白燈，只有諾恩的油燈投影子；接地陰影也拿掉。
##
## 房間：東西 10 m（x -5～5）、南北 10 m（z -5～5），從南牆的門進來；北牆正中是通往鐘院內室的門。
## 內室：北牆後面 x -4.5～4.5、z -5.3～-14.3、高 6.5 m；鐘盤在最北的牆上、主椅面向門。

const QUEST: String = "ch2_main"
const STAGES: PackedStringArray = ["isa_table", "isa_volunteer", "inner_room", "meet_leo", "wall_carvings", "curtain"]
const ROOM_HALF: Vector2 = Vector2(5.0, 5.0)
const WALL_H: float = 3.8
const WALL_T: float = 0.3
const SPAWN: Vector3 = Vector3(0.6, 0.0, 3.0)
## 伊薩一開始面向門口（看著諾恩走進來）
## 長桌：中心、大小、桌面高度
const TABLE_POS: Vector3 = Vector3(0.0, 0.0, -0.9)
const TABLE_SIZE: Vector2 = Vector2(2.6, 1.1)
const TABLE_TOP: float = 0.76
## 伊薩替諾恩拉的那張椅子（桌子南邊靠東）：走到這麼近就坐下
const CHAIR_POS: Vector3 = Vector3(0.55, 0.0, -0.05)
const SEAT_RANGE: float = 1.7
## 拉椅子：往後拉多遠、多久
const CHAIR_PULL: float = 0.4
const CHAIR_PULL_SEC: float = 0.35
## 每個人在桌邊的位置（諾恩坐下後站在椅子後面一點，過肩鏡頭看得到整張桌子）；
## 伊薩在桌子北邊面向鏡頭（站在西端會被席菈擋住——第 42 輪截圖）
const SEATS: Dictionary = {
	"noen": Vector3(1.05, 0.0, 0.85),
	"sheila": Vector3(-0.9, 0.0, 0.35),
	"misha": Vector3(1.9, 0.0, -0.4),
	"isa": Vector3(-0.45, 0.0, -1.85),
}
## 伊薩一開始站的地方（拉椅子之前）
const ISA_START: Vector3 = Vector3(0.1, 0.0, 0.2)
const TABLE_TALK: String = "ch2_table"
## 段落 2「他自願的」（D-158）：看穿伊薩劃完、放開之後開始；沒去看穿的話，坐著沉默這麼久也會開始（伊薩沒有立刻回答）
const VOLUNTEER_TALK: String = "ch2_volunteer"
const SILENCE_SEC: float = 12.0
## 「桌上的湯慢慢涼了」（08 段落 2 的時間流逝）：粥鍋上的熱氣在坐下之後這麼多秒內從 1 淡到 STEAM_COLD；他自願的講完就是涼的
const COOL_SEC: float = 24.0
const STEAM_COLD: float = 0.12
const INNER_DOOR_POS: Vector3 = Vector3(0.0, 0.0, -4.9)
## 鐘院內室（段落 3，D-159）
const INNER_HALF_X: float = 4.5
const INNER_Z_NEAR: float = -5.3
const INNER_Z_FAR: float = -14.3
const INNER_H: float = 6.5
const DOOR_W: float = 1.6
const DOOR_H: float = 2.8
## 走到門前這麼近（門的南邊）→ 伊薩推開門、進內室
const ENTER_RANGE: float = 1.6
const LEO_CUTSCENE: String = "ch2_leo"
## 主椅（銅椅）：面向門（+Z），椅背朝鐘盤
const MAIN_SEAT_POS: Vector3 = Vector3(0.0, 0.0, -10.8)
const SEAT_TOP: float = 0.44
const DIAL_CENTER: Vector3 = Vector3(0.0, 3.4, -14.15)
const DIAL_RADIUS: float = 2.5
## 細管：從椅背接進鐘盤的條數（原作「十幾條」）
const TUBE_COUNT: int = 12
## 進內室之後每個人站的地方；彌夏一開始站在門口（「一步都沒有走」），過場裡走到黎歐旁邊
const INNER_SPOTS: Dictionary = {
	"noen": Vector3(1.6, 0.0, -6.9),
	## 過場之後諾恩往裡站一點：過肩鏡頭才不會卡在門洞裡（第 43 輪截圖）
	"noen_after": Vector3(1.3, 0.0, -8.4),
	"sheila": Vector3(-1.7, 0.0, -7.1),
	"isa": Vector3(-2.3, 0.0, -9.9),
	"misha_door": Vector3(0.0, 0.0, -5.8),
	"misha": Vector3(0.85, 0.0, -10.7),
}
## 牆上的紋路（段落 4 用；先擺 4 塊浮雕的白盒）：西牆，從門口往裡
const CARVING_ZS: Array[float] = [-7.2, -8.8, -10.4, -12.0]
## 段落 4：站在浮雕前這麼近按互動 → 看那一塊（伊薩解說）；4 塊都看完 → 諾恩的獨白 → 攻略筆記「焚城路線最快」被推翻
const CARVING_X: float = -4.42
const READ_RANGE: float = 1.5
const CARVING_END_TALK: String = "ch2_carvings_end"
## 內室的氣氛（0＝飯廳的白光，1＝內室的暖光）：諾恩走進內室就慢慢換過去，走回飯廳就換回來
const MOOD_RATE: float = 1.6
const HALL_BG: Color = Color(0.7, 0.72, 0.75)
const HALL_AMBIENT: Color = Color(0.9, 0.93, 1.0)
const HALL_AMBIENT_ENERGY: float = 0.85
const INNER_BG: Color = Color(0.1, 0.075, 0.06)
const INNER_AMBIENT: Color = Color(1.0, 0.76, 0.52)
const INNER_AMBIENT_ENERGY: float = 0.16
const COPPER: Color = Color(0.72, 0.44, 0.27)
const BRONZE: Color = Color(0.6, 0.42, 0.22)
const BRONZE_DARK: Color = Color(0.3, 0.2, 0.12)
const WARM: Color = Color(1.0, 0.6, 0.3)
## 段落 5 窗簾（D-161）：內室東牆的高窗（窗簾拉著）。牆上的紋路看完，伊薩走到窗邊等；諾恩走到他旁邊 → 對話（撤離？毀掉鐘？援軍？
## 每一條都被現實擋下）→ 伊薩拉開窗簾 → 過場 ch2_eye：玻璃外一堵黑牆動了一下＝一隻眼睛（吞日獸）→ 第 2 章完成。
const WINDOW_Z: float = -9.6
const WINDOW_W: float = 2.8
const WINDOW_SILL: float = 1.2
const WINDOW_TOP: float = 4.6
const ISA_WINDOW: Vector3 = Vector3(3.7, 0.0, -7.6)
const CURTAIN_TALK_RANGE: float = 2.2
## 過場時諾恩站在窗的北邊一點（從大家背後看窗的鏡頭不會被他擋住）
const NOEN_WINDOW: Vector3 = Vector3(2.4, 0.0, -10.6)
const CURTAIN_TALK: String = "ch2_curtain"
const EYE_CUTSCENE: String = "ch2_eye"
## 窗外：屏障的冷光網格、後面那面「黑牆」（眼睛）；都不受燈光影響
const BARRIER_X: float = 5.4
const EYE_X: float = 8.5
const EYE_Y: float = 3.0
const EYE_PLANE: Vector2 = Vector2(20.0, 13.0)
const BARRIER_PLANE: Vector2 = Vector2(12.0, 9.0)
## 瞳孔收到多窄（0＝一道縫）
const PUPIL_NARROW: float = 0.15
const COLD: Color = Color(0.55, 0.78, 1.0)
const BARRIER_LIGHT_ENERGY: float = 1.3
const CURTAIN_CLOTH: Color = Color(0.3, 0.11, 0.09)
## 看穿伊薩（段落 1，D-158）：離他多近、按住看穿才會跳出攻略的小卡
const ISA_INSIGHT_RANGE: float = 9.0
const LAMP_RANGE: float = 7.0
const LAMP_ENERGY: float = 3.0

const PLASTER: Color = Color(0.8, 0.79, 0.75)
const FLOOR: Color = Color(0.5, 0.48, 0.45)
const WOOD: Color = Color(0.32, 0.24, 0.16)
const IRON: Color = Color(0.22, 0.2, 0.19)
const CLAY: Color = Color(0.62, 0.5, 0.38)
const BEANS: Color = Color(0.45, 0.33, 0.2)
const PORRIDGE: Color = Color(0.86, 0.83, 0.74)

var _isa: Puppet
var _misha: Puppet
var _chair: Node3D
var _seated: bool = false
var _continued_shown: bool = false
var _strike: StrikeCard
var _leo: Puppet
var _door: Node3D
var _door_block: CollisionShape3D
var _env: Environment
var _ceiling_lamp: OmniLight3D
## 內室的氣氛（0～1，見 MOOD_RATE）
var mood: float = 0.0
var _carving_grooves: Array[StandardMaterial3D] = []
## 坐下之後、沒按看穿的沉默秒數
var silence: float = 0.0
## 粥鍋上的熱氣（1＝剛端上來，STEAM_COLD＝涼了）
var steam_level: float = 1.0
var _steam: CPUParticles3D
## 截圖用：小卡停在指定的按住秒數
var _dev_insight: bool = false
## 段落 5：窗簾兩半、窗外的眼睛與屏障、屏障照進來的冷光
var _curtain_halves: Array[Node3D] = []
var _eye_mat: ShaderMaterial
var _eye_wall: MeshInstance3D
var _barrier: MeshInstance3D
var _barrier_light: OmniLight3D
var curtain_open: bool = false
## 眼睛：0＝閉著（一堵牆）～1＝睜開；瞳孔 1＝放大～PUPIL_NARROW；整面牆「動了一下」往上移多少
var eye_open: float = 0.0
var pupil: float = 1.0
var wall_shift: float = 0.0
## 截圖用：過場事件直接跳到結果（不等補間）
var _dev_instant: bool = false
## 窗簾、冷光、眼睛的補間（跳過過場時全部停掉、直接到結果）
var _window_tweens: Array[Tween] = []


func _ready() -> void:
	_rng.seed = 2005
	# 開發用：`-- --level=bell_hall` 直接進來 → 照正式流程把第 1 章走完、開始第 2 章
	if not Game.session.state.quests.has(QUEST):
		dev_start_chapter2(Game.session)
	_build_environment()
	_build_room()
	_build_table()
	_build_inner_room()
	_build_cutscene_cameras()
	_init_story()
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player != null:
		_put(player, SPAWN, 0.0)
	_set_up_lamp()
	_build_people()
	_build_leo()
	_build_isa_insight()
	_hide_contact_shadows.call_deferred()
	Game.dialogue_ended.connect(_on_dialogue_ended)
	add_to_group("interact_prompts")
	# 截圖用：`--hall-at=table` 直接走到桌邊（伊薩拉椅子、飯桌的對話第一句）；
	# `--hall-at=seated` 飯桌的對話講完、坐在桌邊；再加 `--hall-insight=秒` 停在看穿伊薩按住那麼久的樣子
	var dev_args: Dictionary = App.parse_user_args(OS.get_cmdline_user_args())
	var at: String = str(dev_args.get("hall-at", ""))
	if at == "seated":
		Game.session.set_flag("ch2.table_seated", true)
	# `--hall-at=inner` 走進內室、過場開始（再加 `--hall-shot=N` 停在第 N 個鏡頭）；`--hall-at=leo` 過場看完、站在內室
	# `--hall-at=carved` 牆上的紋路也都看完了（刻痕亮著）
	# `--hall-at=curtain` 紋路看完、伊薩在窗邊（窗簾還拉著）；`--hall-at=eye [--hall-shot=N]` 窗簾的對話講完、過場開始；
	# `--hall-at=eye-after` 過場看完（窗簾開著、眼睛睜開）
	var carved: bool = at in ["carved", "curtain", "eye", "eye-after"]
	if at in ["inner", "leo"] or carved:
		dev_reach_inner_room(Game.session, at != "inner")
	if carved:
		for i: int in CARVING_ZS.size():
			Game.session.state.set_flag("ch2.carving_%d" % i, true)
		Game.session.set_flag("ch2.read_wall_carvings", true)
		_update_carvings()
	if at in ["eye", "eye-after"]:
		Game.session.state.set_flag("ch2.plan_break", true)
		Game.session.state.set_flag("ch2.plan_aid", true)
		Game.session.set_flag("ch2.curtain_talked", true)
		_dev_instant = true
	if at == "eye-after":
		Game.session.set_flag("ch2.curtain_opened", true)
	# 已經坐下過（重來、讀檔）：直接在桌邊
	if bool(Game.session.state.get_flag("ch2.table_seated", false)):
		_seat_everyone()
	if at == "table" and Game.session.quests.stage_of(QUEST) == "isa_table":
		take_seat.call_deferred()
	# 已經進過內室（重來、讀檔、開發旗標）：大家在內室；過場還沒看完就重新播
	if bool(Game.session.state.get_flag("ch2.inner_room_entered", false)):
		_place_inner(bool(Game.session.state.get_flag("ch2.leo_met", false)))
		if Game.session.quests.stage_of(QUEST) == "meet_leo":
			_play_leo_cutscene.call_deferred(int(str(dev_args.get("hall-shot", "0"))))
	# 窗簾：已經看過眼睛（第 2 章完成、重來、讀檔）→ 窗簾開著、眼睛睜開、待續；對話講完但過場沒看完 → 重新播
	if bool(Game.session.state.get_flag("ch2.curtain_opened", false)):
		_reveal_eye()
		_continued_shown = true
		_banner.call_deferred("CH1_TO_BE_CONTINUED", 6.0)
	elif Game.session.quests.stage_of(QUEST) == "curtain" and bool(Game.session.state.get_flag("ch2.curtain_talked", false)):
		_play_eye_cutscene.call_deferred(int(str(dev_args.get("hall-shot", "0"))))
	if dev_args.has("hall-insight") and _strike != null and not _strike.is_done():
		_dev_insight = true
		_strike.held = float(str(dev_args["hall-insight"]))


## 開發旗標與測試用：照正式流程把第 1 章走完（第 2 章跟著開始）。已經開始第 2 章就不動。
static func dev_start_chapter2(s: GameSession) -> void:
	if s.state.quests.has(QUEST):
		return
	var ach: AchievementTracker = s.achievements
	s.achievements = null
	if not s.quests.is_done("ch1_main"):
		load("res://scenes/levels/daylight.gd").call("dev_start_daylight", s)
		s.state.set_flag("ch1.daylight_intro", true)
		s.set_flag("ch1.saw_empty_furnace", true)
		s.state.set_flag("ch1.mara_traded", true)
		s.set_flag("ch1.saw_stele_trade", true)
		s.state.set_flag("ch1.sheila_shared", true)
		s.set_flag("ch1.kord_dinner_done", true)
		s.state.set_flag("ch1.rabbit_seen", true)
		s.set_flag("ch1.reached_bell_yard", true)
	s.attach_achievements(ach)


## 開發旗標用：照正式流程推到進內室（leo_met＝過場也看完）。
static func dev_reach_inner_room(s: GameSession, leo_met: bool) -> void:
	s.set_flag("ch2.table_seated", true)
	s.set_flag("ch2.usurper_crossed_out", true)
	s.state.set_flag("ch2.noen_apologized", true)
	s.set_flag("ch2.volunteer_talked", true)
	s.set_flag("ch2.inner_room_entered", true)
	if leo_met:
		s.set_flag("ch2.leo_met", true)


func _put(node: Node3D, p: Vector3, yaw: float) -> void:
	node.global_position = p + Vector3(0, 0.05, 0)
	node.rotation.y = yaw
	if node is PlayerController:
		(node as PlayerController).yaw = yaw
		(node as PlayerController).velocity = Vector3.ZERO
		(node as PlayerController).snap_camera()


func _set_up_lamp() -> void:
	var light: OmniLight3D = lamp_light()
	if light != null:
		light.omni_range = LAMP_RANGE
		light.light_energy = LAMP_ENERGY
		light.shadow_enabled = true


func lamp_light() -> OmniLight3D:
	var player: Node3D = get_node_or_null("Player") as Node3D
	return player.find_child("LanternLight", true, false) as OmniLight3D if player != null else null


func _hide_contact_shadows() -> void:
	for n: Node in find_children(ContactShadow.NODE_NAME, "", true, false):
		(n as Node3D).visible = false


# ---------------------------------------------------------------- 流程

func _physics_process(delta: float) -> void:
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	if player == null or Game.is_player_locked():
		return
	var stage: String = Game.session.quests.stage_of(QUEST)
	if stage == "isa_table" and not _seated and _flat(player.global_position, CHAIR_POS) <= SEAT_RANGE:
		take_seat()
		return
	# 段落 2：看穿劃完、放開看穿 → 伊薩開口；沒去看穿就等一段沉默
	if stage == "isa_volunteer" and not player.insight_active:
		silence += delta
		if bool(Game.session.state.get_flag("ch2.usurper_crossed_out", false)) or silence >= SILENCE_SEC:
			Game.start_dialogue(VOLUNTEER_TALK)
			return
	# 段落 3：走到內室的門前 → 伊薩推開門
	if stage == "inner_room" and _flat(player.global_position, INNER_DOOR_POS + Vector3(0, 0, 0.6)) <= ENTER_RANGE:
		enter_inner_room()
		return
	# 段落 4：站在浮雕前按互動 → 看那一塊
	if stage == "wall_carvings" and Input.is_action_just_pressed("interact") and nearest_carving() >= 0:
		read_carving(nearest_carving())
		return
	# 段落 5：走到窗邊的伊薩旁邊 → 窗簾的對話
	if stage == "curtain" and _flat(player.global_position, ISA_WINDOW) <= CURTAIN_TALK_RANGE:
		talk_curtain()


## 看穿伊薩（D-158）：攻略的稱號一個字一個字被劃掉 → 真的伊薩。劃完設 ch2.usurper_crossed_out（攻略筆記「城主＝食歲的僭王」被推翻）。
func _build_isa_insight() -> void:
	var layer := CanvasLayer.new()
	layer.name = "IsaInsight"
	layer.layer = 9
	add_child(layer)
	_strike = StrikeCard.new()
	layer.add_child(_strike)
	var done: bool = bool(Game.session.state.get_flag("ch2.usurper_crossed_out", false))
	_strike.setup(PackedStringArray([tr("INSIGHT_USURPER_NAME"), tr("INSIGHT_USURPER_WEAK")]), tr("GUIDE_USURPER_WRONG"), done)
	_strike.finished.connect(_on_usurper_crossed_out)


func _process(delta: float) -> void:
	_update_steam(delta)
	_update_mood(delta)
	_update_eye()
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	if _dev_insight:
		update_isa_insight(0.0, true)
		return
	update_isa_insight(delta, player != null and player.insight_active)


## 每幀（測試也直接呼叫）：按住看穿、伊薩在附近 → 小卡往前劃；放開就藏起來（停在劃到的地方）。
func update_isa_insight(delta: float, active: bool) -> void:
	if _strike == null:
		return
	var player: Node3D = get_node_or_null("Player") as Node3D
	var on: bool = active and player != null and _isa != null and _flat(player.global_position, _isa.global_position) <= ISA_INSIGHT_RANGE
	if not on:
		_strike.visible = false
		return
	_strike.advance(delta)
	_strike.place(get_viewport().get_camera_3d(), _isa.global_position + Vector3(0, 1.9, 0))


## 互動提示（D-065）：坐下之後、還沒看穿過伊薩 → 「按住 V 看穿伊薩」；按住的時候不顯示（不擋小卡）。
func interact_hint() -> Dictionary:
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	if player == null or _isa == null or not _seated or Game.is_player_locked():
		return {}
	if nearest_carving() >= 0:
		return {"fmt": TranslationServer.translate("CH2_CARVING_HINT"), "action": "interact", "progress": -1.0}
	# 看穿伊薩只在飯桌那時候提示（進了內室就不再提示）
	if Game.session.quests.stage_of(QUEST) not in ["isa_table", "isa_volunteer"]:
		return {}
	if bool(Game.session.state.get_flag("ch2.usurper_crossed_out", false)) or player.insight_active:
		return {}
	if _flat(player.global_position, _isa.global_position) > ISA_INSIGHT_RANGE:
		return {}
	return {"fmt": TranslationServer.translate("CH2_ISA_INSIGHT_HINT"), "action": "insight", "progress": -1.0}


## 湯慢慢涼了：坐下之後熱氣一直變淡；「他自願的」講完（或讀檔時已經講完）就是涼的。
func _update_steam(delta: float) -> void:
	var st: GameState = Game.session.state
	if bool(st.get_flag("ch2.volunteer_talked", false)):
		steam_level = STEAM_COLD
	elif _seated:
		steam_level = maxf(STEAM_COLD, steam_level - delta * (1.0 - STEAM_COLD) / COOL_SEC)
	if _steam != null:
		_steam.color = Color(1.0, 1.0, 1.0, steam_level)


func strike_card() -> StrikeCard:
	return _strike


func _on_usurper_crossed_out() -> void:
	Game.session.set_flag("ch2.usurper_crossed_out", true)


## 走到桌邊（測試也用）：伊薩替諾恩拉椅子（支架吱一聲）→ 每個人站到桌邊 → 飯桌的對話。
func take_seat() -> void:
	if _seated:
		return
	_seated = true
	if _chair != null:
		var tw: Tween = _chair.create_tween()
		tw.tween_property(_chair, "position:z", _chair.position.z + CHAIR_PULL, CHAIR_PULL_SEC)
	Sfx.play_at(self, "brace_creak", (_isa.global_position if _isa != null else CHAIR_POS) + Vector3(0, 0.5, 0), -4.0)
	_seat_everyone()
	Game.start_dialogue(TABLE_TALK)


func is_seated() -> bool:
	return _seated


func _seat_everyone() -> void:
	_seated = true
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player != null:
		var seat: Vector3 = SEATS["noen"] as Vector3
		var to: Vector3 = TABLE_POS - seat
		_put(player, seat, atan2(-to.x, -to.z))
	var ally: Node3D = get_node_or_null("Sheila") as Node3D
	if ally != null:
		ally.global_position = (SEATS["sheila"] as Vector3) + Vector3(0, 0.05, 0)
	if _misha != null:
		_misha.global_position = SEATS["misha"] as Vector3
		_face_table(_misha)
	if _isa != null:
		_isa.global_position = SEATS["isa"] as Vector3
		_face_table(_isa)


func _face_table(p: Node3D) -> void:
	var to: Vector3 = TABLE_POS - p.global_position
	p.rotation.y = atan2(-to.x, -to.z)


func _on_dialogue_ended(dialogue_id: String) -> void:
	# 跳過對話也照樣算坐下吃過了
	if dialogue_id == TABLE_TALK and not bool(Game.session.state.get_flag("ch2.table_seated", false)):
		Game.session.set_flag("ch2.table_seated", true)
	elif dialogue_id == VOLUNTEER_TALK and not bool(Game.session.state.get_flag("ch2.volunteer_talked", false)):
		Game.session.set_flag("ch2.volunteer_talked", true)
	elif dialogue_id.begins_with("ch2_carving_"):
		# 4 塊都看完 → 諾恩的獨白（下一幀開，讓這段對話先收乾淨）
		if carvings_read() == CARVING_ZS.size() and not bool(Game.session.state.get_flag("ch2.read_wall_carvings", false)):
			Game.start_dialogue.call_deferred(CARVING_END_TALK)
	elif dialogue_id == CARVING_END_TALK and not bool(Game.session.state.get_flag("ch2.read_wall_carvings", false)):
		# 跳過也算看完：攻略筆記「焚城路線最快」被推翻（諾恩自己寫的那條）
		Game.session.set_flag("ch2.read_wall_carvings", true)
		# 伊薩走到窗邊等（段落 5）
		_isa_to_window(true)
	elif dialogue_id == CURTAIN_TALK and not bool(Game.session.state.get_flag("ch2.curtain_talked", false)):
		Game.session.set_flag("ch2.curtain_talked", true)
		_play_eye_cutscene(0)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------------------------------------------------------------- 場景

func _mat(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


## 跟白晝城一樣：無方向的白光、沒有太陽、不開 SSAO。
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.7, 0.72, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.93, 1.0)
	env.ambient_light_energy = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = false
	env.ssao_intensity = 0.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	_env = env


func _solid(node_name: String, size: Vector3, pos: Vector3, mat: Material, collide: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.name = node_name + "Body"
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		cs.shape = box
		body.add_child(cs)
		body.position = pos
		add_child(body)
	return mi


func _cylinder(node_name: String, parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius * 0.85
	cm.height = height
	cm.radial_segments = 20
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## 石地板、白灰牆、兩扇門（南：進來的門；北：鐘院內室，關著）、天花板一盞不投影子的白燈。
func _build_room() -> void:
	var hx: float = ROOM_HALF.x
	var hz: float = ROOM_HALF.y
	var plaster: StandardMaterial3D = _mat(PLASTER, 0.93)
	var wood: StandardMaterial3D = _mat(WOOD, 0.85)
	_solid("Floor", Vector3(hx * 2.0 + 1.0, 0.4, hz * 2.0 + 1.0), Vector3(0, -0.2, 0), _mat(FLOOR, 0.9))
	_solid("Ceiling", Vector3(hx * 2.0 + 1.0, 0.3, hz * 2.0 + 1.0), Vector3(0, WALL_H + 0.15, 0), plaster, false)
	# 北牆中間留內室的門洞（段落 3）：左右兩段＋門楣；門洞平常由 InnerDoorBlock 擋住，伊薩推開門才拿掉
	var side_w: float = hx - DOOR_W * 0.5
	for sx: float in [-1.0, 1.0]:
		_solid("WallNorth" + ("W" if sx < 0.0 else "E"), Vector3(side_w, WALL_H, WALL_T),
				Vector3(sx * (DOOR_W * 0.5 + side_w * 0.5), WALL_H * 0.5, -hz - WALL_T * 0.5), plaster)
	_solid("WallNorthLintel", Vector3(DOOR_W, WALL_H - DOOR_H, WALL_T), Vector3(0, DOOR_H + (WALL_H - DOOR_H) * 0.5, -hz - WALL_T * 0.5), plaster)
	_solid("WallSouth", Vector3(hx * 2.0, WALL_H, WALL_T), Vector3(0, WALL_H * 0.5, hz + WALL_T * 0.5), plaster)
	_solid("WallWest", Vector3(WALL_T, WALL_H, hz * 2.0), Vector3(-hx - WALL_T * 0.5, WALL_H * 0.5, 0), plaster)
	_solid("WallEast", Vector3(WALL_T, WALL_H, hz * 2.0), Vector3(hx + WALL_T * 0.5, WALL_H * 0.5, 0), plaster)
	# 進來的門（南牆，關上了）與鐘院內室的門（北牆正中，比一般的門高、鐵條釘著）
	_solid("HallDoor", Vector3(1.2, 2.2, 0.08), Vector3(0, 1.1, hz - 0.05), wood, false)
	# 內室的門：鉸鏈在西邊（InnerDoor 是轉軸），往內室那邊（-Z）推開
	_door = Node3D.new()
	_door.name = "InnerDoor"
	_door.position = INNER_DOOR_POS + Vector3(-DOOR_W * 0.5, 0, 0)
	add_child(_door)
	var slab := MeshInstance3D.new()
	slab.name = "Slab"
	var sm := BoxMesh.new()
	sm.size = Vector3(DOOR_W, DOOR_H, 0.1)
	slab.mesh = sm
	slab.material_override = wood
	slab.position = Vector3(DOOR_W * 0.5, DOOR_H * 0.5, 0)
	_door.add_child(slab)
	var iron: StandardMaterial3D = _mat(IRON, 0.6)
	for y: float in [0.5, 1.4, 2.3]:
		var band := MeshInstance3D.new()
		band.name = "Band%d" % int(y * 10.0)
		var bm := BoxMesh.new()
		bm.size = Vector3(DOOR_W + 0.06, 0.08, 0.04)
		band.mesh = bm
		band.material_override = iron
		band.position = Vector3(DOOR_W * 0.5, y, 0.07)
		_door.add_child(band)
	var block := StaticBody3D.new()
	block.name = "InnerDoorBlock"
	_door_block = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(DOOR_W, DOOR_H, WALL_T)
	_door_block.shape = bs
	block.add_child(_door_block)
	block.position = Vector3(0, DOOR_H * 0.5, -hz - WALL_T * 0.5)
	add_child(block)
	# 牆腳一圈深色的石條（白盒裡讀得出地板與牆的交界）
	var skirting: StandardMaterial3D = _mat(Color(0.44, 0.42, 0.4), 0.9)
	_solid("SkirtNorth", Vector3(hx * 2.0, 0.18, 0.06), Vector3(0, 0.09, -hz + 0.03), skirting, false)
	_solid("SkirtWest", Vector3(0.06, 0.18, hz * 2.0), Vector3(-hx + 0.03, 0.09, 0), skirting, false)
	_solid("SkirtEast", Vector3(0.06, 0.18, hz * 2.0), Vector3(hx - 0.03, 0.09, 0), skirting, false)
	var lamp := OmniLight3D.new()
	lamp.name = "CeilingLamp"
	lamp.light_color = Color(0.92, 0.95, 1.0)
	lamp.light_energy = 0.6
	lamp.omni_range = 8.0
	lamp.shadow_enabled = false
	lamp.position = Vector3(0, WALL_H - 0.4, -0.6)
	add_child(lamp)
	_ceiling_lamp = lamp


## 長桌：三盤煮豆、一鍋稀粥、四個缺口不一樣的碗；桌邊的木椅（伊薩替諾恩拉的那張是 IsaChair）。
func _build_table() -> void:
	var wood: StandardMaterial3D = _mat(WOOD, 0.8)
	_solid("DinnerTable", Vector3(TABLE_SIZE.x, 0.06, TABLE_SIZE.y), TABLE_POS + Vector3(0, TABLE_TOP - 0.03, 0), wood)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_solid("TableLeg%d%d" % [int(sx + 1.0), int(sz + 1.0)], Vector3(0.08, TABLE_TOP - 0.06, 0.08),
					TABLE_POS + Vector3(sx * (TABLE_SIZE.x * 0.5 - 0.1), (TABLE_TOP - 0.06) * 0.5, sz * (TABLE_SIZE.y * 0.5 - 0.1)), wood, false)
	var top: Vector3 = TABLE_POS + Vector3(0, TABLE_TOP, 0)
	var clay: StandardMaterial3D = _mat(CLAY, 0.7)
	var beans: StandardMaterial3D = _mat(BEANS, 0.6)
	# 三盤煮豆（桌子中線上）
	for i: int in 3:
		var p: Vector3 = top + Vector3(-0.75 + i * 0.75, 0.0, -0.05)
		_cylinder("BeanPlate%d" % i, self, 0.17, 0.025, p + Vector3(0, 0.0125, 0), clay)
		var mound: MeshInstance3D = _cylinder("Beans%d" % i, self, 0.12, 0.04, p + Vector3(0, 0.04, 0), beans)
		mound.scale = Vector3(1.0, 1.0, 0.85)
	# 一鍋稀粥（桌子北邊、伊薩伸手拿得到；從諾恩這邊看得到熱氣）
	var pot: MeshInstance3D = _cylinder("PorridgePot", self, 0.16, 0.2, top + Vector3(0.4, 0.1, -0.37), _mat(IRON, 0.5))
	_cylinder("Porridge", pot, 0.145, 0.01, Vector3(0, 0.095, 0), _mat(PORRIDGE, 0.4))
	_steam = _build_steam(pot)
	# 四個碗，缺口在不同的地方（碗緣一小塊深色）
	var bowl_at: Array[Vector3] = [Vector3(0.55, 0, 0.35), Vector3(-0.55, 0, 0.35), Vector3(1.05, 0, -0.3), Vector3(-0.45, 0, -0.38)]
	var chip_mat: StandardMaterial3D = _mat(Color(0.3, 0.24, 0.18), 0.9)
	for i: int in bowl_at.size():
		var bowl: MeshInstance3D = _cylinder("Bowl%d" % i, self, 0.075, 0.06, top + bowl_at[i] + Vector3(0, 0.03, 0), clay)
		var a: float = TAU * (0.15 + 0.23 * float(i))
		var chip := MeshInstance3D.new()
		chip.name = "Chip"
		var cb := BoxMesh.new()
		cb.size = Vector3(0.035, 0.022, 0.02)
		chip.mesh = cb
		chip.material_override = chip_mat
		chip.position = Vector3(cos(a) * 0.072, 0.025, sin(a) * 0.072)
		chip.rotation.y = -a
		bowl.add_child(chip)
	# 椅子：諾恩的（IsaChair）、席菈、彌夏、伊薩
	_chair = _build_chair("IsaChair", CHAIR_POS, 0.0)
	_build_chair("SheilaChair", Vector3(-0.55, 0.0, -0.05), 0.0)
	_build_chair("MishaChair", Vector3(1.6, 0.0, -0.9), PI * 0.5)
	_build_chair("IsaOwnChair", Vector3(-0.45, 0.0, -1.55), PI)


## 粥鍋上的熱氣：幾縷很淡的白煙往上飄（粒子材質照 D-056 用 ParticleLook）；濃淡由 steam_level 控制。
func _build_steam(pot: Node3D) -> CPUParticles3D:
	var steam := CPUParticles3D.new()
	steam.name = "PorridgeSteam"
	steam.amount = 10
	steam.lifetime = 2.4
	steam.preprocess = 3.0
	steam.position = Vector3(0, 0.12, 0)
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	steam.emission_sphere_radius = 0.08
	steam.direction = Vector3(0, 1, 0)
	steam.spread = 10.0
	steam.initial_velocity_min = 0.12
	steam.initial_velocity_max = 0.2
	steam.gravity = Vector3(0.0, 0.04, 0.0)
	steam.damping_min = 0.02
	steam.damping_max = 0.04
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.3))
	grow.add_point(Vector2(1.0, 1.0))
	steam.scale_amount_curve = grow
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)
	quad.material = ParticleLook.material(Color(0.95, 0.96, 0.98, 1.0), false, BaseMaterial3D.BILLBOARD_PARTICLES)
	steam.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	ramp.add_point(0.15, Color(1.0, 1.0, 1.0, 0.32))
	ramp.add_point(0.6, Color(1.0, 1.0, 1.0, 0.14))
	steam.color_ramp = ramp
	pot.add_child(steam)
	return steam


## 一張木椅（座面＋靠背＋四隻腳），靠背朝 +Z（yaw 轉向）。
func _build_chair(node_name: String, pos: Vector3, yaw: float) -> Node3D:
	var chair := Node3D.new()
	chair.name = node_name
	chair.position = pos
	chair.rotation.y = yaw
	add_child(chair)
	var wood: StandardMaterial3D = _mat(Color(0.36, 0.27, 0.18), 0.85)
	var parts: Array[Array] = [
		[Vector3(0.42, 0.04, 0.4), Vector3(0, 0.45, 0)],
		[Vector3(0.42, 0.5, 0.04), Vector3(0, 0.72, 0.19)],
	]
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			parts.append([Vector3(0.04, 0.45, 0.04), Vector3(sx * 0.18, 0.225, sz * 0.17)])
	for part: Array in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[0] as Vector3
		mi.mesh = bm
		mi.material_override = wood
		mi.position = part[1] as Vector3
		chair.add_child(mi)
	return chair


func _build_people() -> void:
	_isa = _puppet("Isa", Color(0.3, 0.32, 0.3), Color(0.62, 0.58, 0.5))
	_isa.global_position = ISA_START
	_isa.rotation.y = PI
	_add_leg_brace(_isa)
	_misha = _puppet("Misha", Color(0.16, 0.27, 0.21), Color(0.3, 0.26, 0.2))
	_misha.global_position = SPAWN + Vector3(1.6, -0.05, -1.0)
	var ally := Sheila.new()
	ally.name = "Sheila"
	ally.position = SPAWN + Vector3(-1.5, 0.0, -0.8)
	add_child(ally)


func _puppet(node_name: String, coat: Color, trim: Color) -> Puppet:
	var p := Puppet.new()
	p.name = node_name
	p.coat_color = coat
	p.trim_color = trim
	add_child(p)
	var hammer: Node = p.hand("R").get_node_or_null("BellHammer") if p.hand("R") != null else null
	if hammer != null:
		hammer.queue_free()
	return p


## 伊薩右腿的金屬支架：小腿外側兩根細鐵條＋膝蓋一個圓鉸鏈（拉椅子時吱一聲的那個）。
func _add_leg_brace(p: Puppet) -> void:
	var knee: Node3D = p.joint("knee_R")
	if knee == null:
		return
	var brace := Node3D.new()
	brace.name = "LegBrace"
	knee.add_child(brace)
	var iron: StandardMaterial3D = _mat(Color(0.5, 0.5, 0.52), 0.35)
	iron.metallic = 0.8
	for z: float in [-1.0, 1.0]:
		var rod := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.012
		cm.bottom_radius = 0.012
		cm.height = Puppet.SHIN_LEN * 0.9
		cm.radial_segments = 6
		rod.mesh = cm
		rod.material_override = iron
		rod.position = Vector3(0.075, -Puppet.SHIN_LEN * 0.45, z * 0.035)
		brace.add_child(rod)
	var hinge := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.035
	hm.bottom_radius = 0.035
	hm.height = 0.02
	hinge.mesh = hm
	hinge.material_override = iron
	hinge.rotation.z = PI * 0.5
	hinge.position = Vector3(0.08, 0.0, 0.0)
	brace.add_child(hinge)


func has_leg_brace() -> bool:
	return _isa != null and _isa.joint("knee_R") != null and _isa.joint("knee_R").has_node("LegBrace")


# ---------------------------------------------------------------- 段落 3：鐘院內室（D-159）

## 走到內室的門前（測試也用）：伊薩推開門 → 黑一下 → 大家在內室裡（彌夏停在門口）→ 過場「妳剪頭髮了。」
func enter_inner_room() -> void:
	if bool(Game.session.state.get_flag("ch2.inner_room_entered", false)):
		return
	Sfx.play_at(self, "brace_creak", INNER_DOOR_POS + Vector3(0, 1.0, 0), -9.0)
	Game.session.set_flag("ch2.inner_room_entered", true)
	_place_inner(false)
	_cut_from_black(0.9)
	_play_leo_cutscene(0)


## 過場 ch2_leo；shot＞0 是截圖用（直接跳到第 shot 個鏡頭）。
func _play_leo_cutscene(shot: int) -> void:
	if Game.is_in_cutscene() or bool(Game.session.state.get_flag("ch2.leo_met", false)):
		return
	if not Game.play_cutscene(LEO_CUTSCENE):
		return
	for i: int in shot:
		Game.cutscene.update(100.0)


## 大家在內室裡的位置；after＝過場看完（彌夏在黎歐旁邊），否則彌夏還站在門口。門開著、氣氛直接換成內室的暖光。
func _place_inner(after: bool) -> void:
	_open_door(false)
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player != null:
		var at: Vector3 = INNER_SPOTS["noen_after" if after else "noen"] as Vector3
		var to: Vector3 = MAIN_SEAT_POS - at
		_put(player, at, atan2(-to.x, -to.z))
	var ally: Node3D = get_node_or_null("Sheila") as Node3D
	if ally != null:
		ally.global_position = (INNER_SPOTS["sheila"] as Vector3) + Vector3(0, 0.05, 0)
	if _isa != null:
		_isa.global_position = INNER_SPOTS["isa"] as Vector3
		_face(_isa, MAIN_SEAT_POS)
		# 紋路看完之後伊薩在窗邊
		if bool(Game.session.state.get_flag("ch2.read_wall_carvings", false)):
			_isa_to_window(false)
	if _misha != null:
		_misha.global_position = INNER_SPOTS["misha" if after else "misha_door"] as Vector3
		_face(_misha, MAIN_SEAT_POS)
		_misha.set_move_speed(0.0)
	mood = 1.0
	_apply_mood()


func _face(p: Node3D, target: Vector3) -> void:
	var to: Vector3 = target - p.global_position
	p.rotation.y = atan2(-to.x, -to.z)


func _open_door(animate: bool) -> void:
	if _door_block != null:
		_door_block.disabled = true
	if _door == null:
		return
	if animate:
		_door.create_tween().tween_property(_door, "rotation:y", 1.75, 0.6).set_trans(Tween.TRANS_SINE)
	else:
		_door.rotation.y = 1.75


func is_door_open() -> bool:
	return _door_block != null and _door_block.disabled


## 諾恩在內室裡（門的北邊）。
func is_in_inner_room() -> bool:
	var player: Node3D = get_node_or_null("Player") as Node3D
	return player != null and player.global_position.z < INNER_Z_NEAR


## 內室的氣氛：諾恩走進內室 → 背景、環境光慢慢換成暗暖色，飯廳天花板的白燈關小（不投影子的光會穿牆）。
func _update_mood(delta: float) -> void:
	var target: float = 1.0 if is_in_inner_room() else 0.0
	if is_equal_approx(mood, target):
		return
	mood = move_toward(mood, target, delta * MOOD_RATE)
	_apply_mood()


func _apply_mood() -> void:
	if _env != null:
		_env.background_color = HALL_BG.lerp(INNER_BG, mood)
		_env.ambient_light_color = HALL_AMBIENT.lerp(INNER_AMBIENT, mood)
		_env.ambient_light_energy = lerpf(HALL_AMBIENT_ENERGY, INNER_AMBIENT_ENERGY, mood)
	if _ceiling_lamp != null:
		_ceiling_lamp.light_energy = 0.6 * (1.0 - mood)


func _on_cutscene_event(event: String, shot: Dictionary) -> void:
	match event:
		"misha_walk":
			if _misha != null:
				var to: Vector3 = INNER_SPOTS["misha"] as Vector3
				_face(_misha, to)
				_misha.set_move_speed(1.0)
				var tw: Tween = _misha.create_tween()
				tw.tween_property(_misha, "global_position", to, 2.2)
				tw.tween_callback(_misha_arrived)
		"slap":
			Sfx.play_at(self, "slap", MAIN_SEAT_POS + Vector3(0, 1.1, 0.3), -6.0, 0.02)
		"curtain_open":
			_set_curtain(true, not _dev_instant)
		"wall_shift":
			if _dev_instant:
				wall_shift = 0.0
			else:
				var tw: Tween = _window_tween(self)
				tw.tween_property(self, "wall_shift", 0.32, 0.5).set_trans(Tween.TRANS_SINE)
				tw.tween_property(self, "wall_shift", 0.0, 1.4).set_trans(Tween.TRANS_SINE)
			Sfx.play_at(self, "deep_rumble", Vector3(INNER_HALF_X, EYE_Y, WINDOW_Z), -2.0, 0.0, 12.0)
		"eye_open":
			if _dev_instant:
				eye_open = 1.0
			else:
				_window_tween(self).tween_property(self, "eye_open", 1.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		"pupil":
			if _dev_instant:
				pupil = PUPIL_NARROW
			else:
				_window_tween(self).tween_property(self, "pupil", PUPIL_NARROW, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_:
			super._on_cutscene_event(event, shot)


func _misha_arrived() -> void:
	if _misha != null:
		_misha.set_move_speed(0.0)
		_face(_misha, MAIN_SEAT_POS)


## 過場結束（跳過也一樣）：彌夏站在黎歐旁邊。
func _on_cutscene_ended(cutscene_id: String, skipped: bool) -> void:
	super._on_cutscene_ended(cutscene_id, skipped)
	if cutscene_id == LEO_CUTSCENE:
		_place_inner(true)
	elif cutscene_id == EYE_CUTSCENE:
		# 跳過也一樣：窗簾開著、眼睛睜開看著我們 → 第 2 章完成（ch2.curtain_opened 由過場的 on_end 設）→ 第 3 章待續
		_reveal_eye()
		if not _continued_shown:
			_continued_shown = true
			_banner("CH1_TO_BE_CONTINUED", 6.0)


func _cut_from_black(seconds: float) -> void:
	var old: Node = get_node_or_null("CutFade")
	if old != null:
		old.free()
	var layer := CanvasLayer.new()
	layer.name = "CutFade"
	layer.layer = 5
	var rect := ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	add_child(layer)
	var tw: Tween = layer.create_tween()
	tw.tween_interval(seconds * 0.3)
	tw.tween_property(rect, "modulate:a", 0.0, seconds * 0.7)
	tw.tween_callback(layer.queue_free)


## 過場鏡頭（CutsceneView 依名字找）。
func _build_cutscene_cameras() -> void:
	var seat: Vector3 = MAIN_SEAT_POS
	# 遠景從門口往裡看（彌夏站在鏡頭後面的門口、諾恩與席菈在兩側畫面外）
	_camera_marker("InnerCamWide", Vector3(0.6, 1.85, -6.3), Vector3(0.0, 2.2, -13.0))
	_camera_marker("InnerCamLeo", seat + Vector3(0.55, 1.3, 2.0), seat + Vector3(0.0, 1.05, 0.0))
	_camera_marker("InnerCamMisha", seat + Vector3(-0.5, 1.45, 0.9), (INNER_SPOTS["misha_door"] as Vector3) + Vector3(0, 1.35, 0))
	_camera_marker("InnerCamTwo", seat + Vector3(2.3, 1.45, 1.6), seat + Vector3(0.2, 1.05, 0.4))
	# 段落 5：從大家背後看窗（伊薩在窗邊）／貼近窗看外面的眼睛／從窗邊回頭看被冷光照到的大家
	_camera_marker("EyeCamWindow", Vector3(-1.4, 1.75, -8.0), Vector3(EYE_X, EYE_Y - 0.2, WINDOW_Z))
	_camera_marker("EyeCamClose", Vector3(2.9, 2.5, -8.9), Vector3(EYE_X, EYE_Y, WINDOW_Z - 0.2))
	_camera_marker("EyeCamGroup", Vector3(4.0, 1.85, -9.5), Vector3(1.2, 1.4, -10.9))


## 內室：石地板、高牆、牆上的巨大鐘盤、主椅（銅椅）、十二條細管、西牆 4 塊浮雕（段落 4）、三盞不投影子的暖光。
func _build_inner_room() -> void:
	var hx: float = INNER_HALF_X
	var near: float = INNER_Z_NEAR
	var far: float = INNER_Z_FAR
	var depth: float = near - far
	var mid: float = (near + far) * 0.5
	var stone: StandardMaterial3D = _mat(Color(0.34, 0.31, 0.29), 0.88)
	# 地板從飯廳地板的北緣（z -5.5）接起，不重疊
	var floor_from: float = -ROOM_HALF.y - 0.5
	_solid("InnerFloor", Vector3(hx * 2.0 + 0.6, 0.4, floor_from - far + 0.5), Vector3(0, -0.2, (floor_from + far - 0.5) * 0.5), _mat(Color(0.36, 0.32, 0.28), 0.85))
	_solid("InnerCeiling", Vector3(hx * 2.0 + 0.6, 0.3, depth + 0.6), Vector3(0, INNER_H + 0.15, mid), stone, false)
	_solid("InnerWallWest", Vector3(WALL_T, INNER_H, depth), Vector3(-hx - WALL_T * 0.5, INNER_H * 0.5, mid), stone)
	# 東牆中間留一扇高窗（段落 5，D-161）：窗的南邊、北邊、窗台下、窗楣上四段
	var wx: float = hx + WALL_T * 0.5
	var w_south: float = WINDOW_Z + WINDOW_W * 0.5
	var w_north: float = WINDOW_Z - WINDOW_W * 0.5
	_solid("InnerWallEastS", Vector3(WALL_T, INNER_H, near - w_south), Vector3(wx, INNER_H * 0.5, (near + w_south) * 0.5), stone)
	_solid("InnerWallEastN", Vector3(WALL_T, INNER_H, w_north - far), Vector3(wx, INNER_H * 0.5, (w_north + far) * 0.5), stone)
	_solid("InnerWallEastSill", Vector3(WALL_T, WINDOW_SILL, WINDOW_W), Vector3(wx, WINDOW_SILL * 0.5, WINDOW_Z), stone)
	_solid("InnerWallEastHead", Vector3(WALL_T, INNER_H - WINDOW_TOP, WINDOW_W), Vector3(wx, WINDOW_TOP + (INNER_H - WINDOW_TOP) * 0.5, WINDOW_Z), stone)
	_build_window()
	_solid("InnerWallNorth", Vector3(hx * 2.0 + 0.6, INNER_H, WALL_T), Vector3(0, INNER_H * 0.5, far - WALL_T * 0.5), stone)
	# 飯廳的北牆只有 3.8 m 高：上面補一段到內室的天花板
	_solid("InnerWallSouthUpper", Vector3(hx * 2.0, INNER_H - WALL_H, WALL_T), Vector3(0, WALL_H + (INNER_H - WALL_H) * 0.5, -ROOM_HALF.y - WALL_T * 0.5), stone, false)
	_build_dial()
	_build_main_seat()
	_build_tubes()
	_build_carvings()
	for spec: Array in [
		["DialGlow", Vector3(0, 3.0, -12.9), 2.4, 7.5],
		["SeatGlow", Vector3(0, 1.3, -11.8), 1.0, 3.6],
		["InnerFill", Vector3(0, 3.0, -8.2), 0.4, 4.2],
		["EastFill", Vector3(3.0, 2.5, -9.2), 0.35, 4.0],
	]:
		var l := OmniLight3D.new()
		l.name = str(spec[0])
		l.light_color = WARM
		l.position = spec[1] as Vector3
		l.light_energy = float(spec[2])
		l.omni_range = float(spec[3])
		l.shadow_enabled = false
		add_child(l)


func _metal(color: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = _mat(color, rough)
	m.metallic = metallic
	return m


## 牆上的巨大鐘盤（面向 +Z）：銅框、深色盤面、內圈、中心軸、九道刻痕（九聲，微微發光）。
func _build_dial() -> void:
	var dial := Node3D.new()
	dial.name = "BellDial"
	dial.position = DIAL_CENTER
	add_child(dial)
	var bronze: StandardMaterial3D = _metal(BRONZE, 0.85, 0.3)
	var face := MeshInstance3D.new()
	face.name = "Face"
	var fm := CylinderMesh.new()
	fm.top_radius = DIAL_RADIUS - 0.15
	fm.bottom_radius = DIAL_RADIUS - 0.15
	fm.height = 0.1
	fm.radial_segments = 48
	face.mesh = fm
	face.material_override = _metal(BRONZE_DARK, 0.7, 0.45)
	face.rotation.x = PI * 0.5
	dial.add_child(face)
	for ring: Array in [["Rim", DIAL_RADIUS - 0.2, DIAL_RADIUS, 0.04], ["InnerRing", 1.42, 1.52, 0.06]]:
		var mi := MeshInstance3D.new()
		mi.name = str(ring[0])
		var tm := TorusMesh.new()
		tm.inner_radius = float(ring[1])
		tm.outer_radius = float(ring[2])
		tm.rings = 48
		tm.ring_segments = 8
		mi.mesh = tm
		mi.material_override = bronze
		mi.rotation.x = PI * 0.5
		mi.position = Vector3(0, 0, float(ring[3]))
		dial.add_child(mi)
	var hub := MeshInstance3D.new()
	hub.name = "Hub"
	var hm := CylinderMesh.new()
	hm.top_radius = 0.3
	hm.bottom_radius = 0.34
	hm.height = 0.24
	hm.radial_segments = 24
	hub.mesh = hm
	hub.material_override = bronze
	hub.rotation.x = PI * 0.5
	hub.position = Vector3(0, 0, 0.1)
	dial.add_child(hub)
	var tick_mat: StandardMaterial3D = _metal(BRONZE, 0.6, 0.35)
	tick_mat.emission_enabled = true
	tick_mat.emission = WARM
	tick_mat.emission_energy_multiplier = 1.4
	for i: int in 9:
		var a: float = TAU * float(i) / 9.0
		var tick := MeshInstance3D.new()
		tick.name = "Tick%d" % i
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, 0.34, 0.05)
		tick.mesh = bm
		tick.material_override = tick_mat
		tick.position = Vector3(sin(a) * 1.95, cos(a) * 1.95, 0.07)
		tick.rotation.z = -a
		dial.add_child(tick)


## 主椅（銅椅）：比木椅大、高椅背、扶手；面向門（+Z），椅背朝鐘盤。黎歐坐在上面。
func _build_main_seat() -> void:
	var seat := Node3D.new()
	seat.name = "MainSeat"
	seat.position = MAIN_SEAT_POS
	add_child(seat)
	var copper: StandardMaterial3D = _metal(COPPER, 0.85, 0.28)
	var parts: Array[Array] = [
		["Seat", Vector3(0.66, 0.07, 0.58), Vector3(0, SEAT_TOP - 0.035, 0)],
		["Back", Vector3(0.7, 1.55, 0.08), Vector3(0, SEAT_TOP + 0.7, -0.3)],
		["Crest", Vector3(0.86, 0.1, 0.12), Vector3(0, SEAT_TOP + 1.5, -0.3)],
	]
	for sx: float in [-1.0, 1.0]:
		parts.append(["Arm", Vector3(0.07, 0.06, 0.56), Vector3(sx * 0.36, SEAT_TOP + 0.26, -0.02)])
		parts.append(["ArmPost", Vector3(0.06, 0.26, 0.06), Vector3(sx * 0.36, SEAT_TOP + 0.13, 0.22)])
		for sz: float in [-1.0, 1.0]:
			parts.append(["Leg", Vector3(0.07, SEAT_TOP - 0.07, 0.07), Vector3(sx * 0.29, (SEAT_TOP - 0.07) * 0.5, sz * 0.25)])
	var i: int = 0
	for part: Array in parts:
		var mi := MeshInstance3D.new()
		mi.name = "%s%d" % [str(part[0]), i]
		i += 1
		var bm := BoxMesh.new()
		bm.size = part[1] as Vector3
		mi.mesh = bm
		mi.material_override = copper
		mi.position = part[2] as Vector3
		seat.add_child(mi)


## 細管的兩端：椅背後面（往上排兩列）→ 鐘盤上（繞中心散開）。
func tube_ends(i: int) -> Array[Vector3]:
	var col: float = float(i % 6) / 5.0 - 0.5
	var row: int = floori(float(i) / 6.0)
	var from: Vector3 = MAIN_SEAT_POS + Vector3(col * 0.5, SEAT_TOP + 0.45 + 0.5 * float(row), -0.36)
	var a: float = TAU * (float(i) + 0.5) / float(TUBE_COUNT)
	var r: float = 0.55 + 0.35 * float(i % 3)
	var to: Vector3 = DIAL_CENTER + Vector3(sin(a) * r, cos(a) * r, 0.06)
	var out: Array[Vector3] = [from, to]
	return out


## 十二條細管：從椅背垂下、在地上方一點點繞、再往上接進鐘盤。一個 mesh（UV.y＝從椅背量起的公尺數、UV2.x＝每條的相位），
## shader 讓光團慢慢往鐘盤流（life_tube.gdshader）。
func _build_tubes() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base: int = 0
	for i: int in TUBE_COUNT:
		var ends: Array[Vector3] = tube_ends(i)
		var p0: Vector3 = ends[0]
		var p3: Vector3 = ends[1]
		var p1: Vector3 = p0 + Vector3(0, -0.55, -0.7)
		var p2: Vector3 = p3 + Vector3(0, -1.6 - 0.1 * float(i % 4), 1.3)
		base = _add_tube(st, base, [p0, p1, p2, p3], 0.022 + 0.006 * float(i % 3), float(i) * 0.37)
	var mi := MeshInstance3D.new()
	mi.name = "LifeTubes"
	mi.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/world/life_tube.gdshader") as Shader
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


static func _bezier(c: Array, t: float) -> Vector3:
	var u: float = 1.0 - t
	return (c[0] as Vector3) * u * u * u + (c[1] as Vector3) * 3.0 * u * u * t + (c[2] as Vector3) * 3.0 * u * t * t + (c[3] as Vector3) * t * t * t


## 一條沿著三次貝茲曲線的細管（6 邊形截面）；回傳下一條的頂點起點。
func _add_tube(st: SurfaceTool, base: int, c: Array, radius: float, phase: float) -> int:
	const SEGS: int = 28
	const SIDES: int = 6
	var along: float = 0.0
	var prev: Vector3 = _bezier(c, 0.0)
	for k: int in SEGS + 1:
		var t: float = float(k) / float(SEGS)
		var p: Vector3 = _bezier(c, t)
		along += p.distance_to(prev)
		prev = p
		var tangent: Vector3 = (_bezier(c, minf(t + 0.01, 1.0)) - _bezier(c, maxf(t - 0.01, 0.0))).normalized()
		var side: Vector3 = tangent.cross(Vector3.UP)
		if side.length() < 0.01:
			side = tangent.cross(Vector3.RIGHT)
		side = side.normalized()
		var up: Vector3 = side.cross(tangent).normalized()
		for j: int in SIDES:
			var a: float = TAU * float(j) / float(SIDES)
			var n: Vector3 = side * cos(a) + up * sin(a)
			st.set_normal(n)
			st.set_uv(Vector2(float(j) / float(SIDES), along))
			st.set_uv2(Vector2(phase, 0.0))
			st.add_vertex(p + n * radius)
	for k: int in SEGS:
		for j: int in SIDES:
			var a0: int = base + k * SIDES + j
			var a1: int = base + k * SIDES + (j + 1) % SIDES
			var b0: int = a0 + SIDES
			var b1: int = a1 + SIDES
			st.add_index(a0)
			st.add_index(b0)
			st.add_index(a1)
			st.add_index(a1)
			st.add_index(b0)
			st.add_index(b1)
	return base + (SEGS + 1) * SIDES


## 牆上的紋路（段落 4 才能互動；先擺 4 塊浮雕的白盒）：西牆上一排淺色石板，每塊上面幾道刻痕。
func _build_carvings() -> void:
	var root := Node3D.new()
	root.name = "WallCarvings"
	root.position = Vector3(CARVING_X, 0.0, (CARVING_ZS[0] + CARVING_ZS[CARVING_ZS.size() - 1]) * 0.5)
	add_child(root)
	var slab_mat: StandardMaterial3D = _mat(Color(0.56, 0.5, 0.43), 0.9)
	for i: int in CARVING_ZS.size():
		# 每塊自己的刻痕材質：看過的那塊刻痕亮起暖光（跟細管一樣的顏色）
		var groove: StandardMaterial3D = _mat(Color(0.26, 0.22, 0.19), 0.95)
		groove.emission = WARM
		_carving_grooves.append(groove)
		var panel := MeshInstance3D.new()
		panel.name = "Carving%d" % i
		var bm := BoxMesh.new()
		bm.size = Vector3(0.1, 1.5, 1.15)
		panel.mesh = bm
		panel.material_override = slab_mat
		panel.position = Vector3(0.0, 1.7, CARVING_ZS[i] - root.position.z)
		root.add_child(panel)
		for g: int in 3:
			var line := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.02, 0.05, 0.8 - 0.18 * float((g + i) % 3))
			line.mesh = lm
			line.material_override = groove
			line.position = Vector3(0.055, 0.35 - 0.35 * float(g), 0.0)
			panel.add_child(line)
	_update_carvings()


## 黎歐：坐在主椅上（程序人偶的坐姿），面向門。
func _build_leo() -> void:
	_leo = _puppet("Leo", Color(0.27, 0.29, 0.32), Color(0.56, 0.5, 0.42))
	_leo.sitting = true
	_leo.global_position = MAIN_SEAT_POS + Vector3(0, 0, -0.08)
	_leo.rotation.y = PI


func leo() -> Puppet:
	return _leo


# ---------------------------------------------------------------- 段落 4：牆上的紋路（D-160）

## 諾恩站在哪一塊浮雕前面（-1＝都不是）。只在牆上的紋路那個階段、沒有對話的時候。
func nearest_carving() -> int:
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player == null or Game.is_player_locked() or Game.session.quests.stage_of(QUEST) != "wall_carvings":
		return -1
	for i: int in CARVING_ZS.size():
		if _flat(player.global_position, Vector3(CARVING_X, 0.0, CARVING_ZS[i])) <= READ_RANGE:
			return i
	return -1


## 看一塊浮雕（測試也用）：伊薩解說那一塊（十七年前的封印／壽命轉成屏障／每三年一人坐主椅／敲滿九聲＝燒掉整座城），刻痕亮起來。
func read_carving(i: int) -> void:
	if i < 0 or i >= CARVING_ZS.size():
		return
	Game.session.state.set_flag("ch2.carving_%d" % i, true)
	_update_carvings()
	Sfx.play_flat(self, "ui_tick", -12.0)
	Game.start_dialogue("ch2_carving_%d" % i)


func carvings_read() -> int:
	var n: int = 0
	for i: int in CARVING_ZS.size():
		if bool(Game.session.state.get_flag("ch2.carving_%d" % i, false)):
			n += 1
	return n


func carving_lit(i: int) -> bool:
	return i < _carving_grooves.size() and _carving_grooves[i].emission_enabled


func _update_carvings() -> void:
	var all: bool = bool(Game.session.state.get_flag("ch2.read_wall_carvings", false))
	for i: int in _carving_grooves.size():
		var lit: bool = all or bool(Game.session.state.get_flag("ch2.carving_%d" % i, false))
		_carving_grooves[i].emission_enabled = lit
		_carving_grooves[i].emission_energy_multiplier = 1.2


# ---------------------------------------------------------------- 段落 5：窗簾與眼睛（D-161）

## 內室東牆的高窗：銅框＋十字窗櫺；裡面一幅厚窗簾（兩半）；窗外一層屏障的冷光網格，後面是那面「黑牆」（眼睛）。
func _build_window() -> void:
	var x_in: float = INNER_HALF_X
	var frame_mat: StandardMaterial3D = _metal(BRONZE_DARK, 0.6, 0.5)
	var cy: float = (WINDOW_SILL + WINDOW_TOP) * 0.5
	var wh: float = WINDOW_TOP - WINDOW_SILL
	var bars: Array[Array] = [
		["FrameTop", Vector3(0.14, 0.12, WINDOW_W + 0.12), Vector3(x_in + 0.02, WINDOW_TOP, WINDOW_Z)],
		["FrameBottom", Vector3(0.2, 0.1, WINDOW_W + 0.12), Vector3(x_in + 0.02, WINDOW_SILL, WINDOW_Z)],
		["FrameS", Vector3(0.14, wh, 0.1), Vector3(x_in + 0.02, cy, WINDOW_Z + WINDOW_W * 0.5)],
		["FrameN", Vector3(0.14, wh, 0.1), Vector3(x_in + 0.02, cy, WINDOW_Z - WINDOW_W * 0.5)],
		["Mullion", Vector3(0.06, wh, 0.05), Vector3(x_in + 0.15, cy, WINDOW_Z)],
		["Transom", Vector3(0.06, 0.05, WINDOW_W), Vector3(x_in + 0.15, WINDOW_SILL + wh * 0.62, WINDOW_Z)],
	]
	var frame := Node3D.new()
	frame.name = "WindowFrame"
	add_child(frame)
	for b: Array in bars:
		var mi := MeshInstance3D.new()
		mi.name = str(b[0])
		var bm := BoxMesh.new()
		bm.size = b[1] as Vector3
		mi.mesh = bm
		mi.material_override = frame_mat
		mi.position = b[2] as Vector3
		frame.add_child(mi)
	_build_curtain()
	# 窗外：屏障（疊加的冷光網格）與後面的黑牆（眼睛）；窗簾打開才顯示
	_barrier = _outside_plane("Barrier", BARRIER_PLANE, BARRIER_X, "res://src/world/barrier_grid.gdshader")
	(_barrier.material_override as ShaderMaterial).set_shader_parameter("plane_size", BARRIER_PLANE)
	_eye_wall = _outside_plane("EyeWall", EYE_PLANE, EYE_X, "res://src/world/deep_eye.gdshader")
	_eye_mat = _eye_wall.material_override as ShaderMaterial
	_eye_mat.set_shader_parameter("plane_size", EYE_PLANE)
	# 屏障照進來的冷光（打開窗簾才亮；不投影子，照第 1 章的規則）
	_barrier_light = OmniLight3D.new()
	_barrier_light.name = "BarrierLight"
	_barrier_light.light_color = COLD
	_barrier_light.light_energy = 0.0
	_barrier_light.omni_range = 7.5
	_barrier_light.shadow_enabled = false
	_barrier_light.position = Vector3(x_in - 0.5, cy + 0.3, WINDOW_Z)
	add_child(_barrier_light)
	_set_curtain(false, false)


## 窗外的一張四邊形（面向內室，-X）；UV 的 u 往 +Z、v 往下。
func _outside_plane(node_name: String, size: Vector2, x: float, shader_path: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	var mat := ShaderMaterial.new()
	mat.shader = load(shader_path) as Shader
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(x, EYE_Y, WINDOW_Z)
	mi.rotation.y = -PI * 0.5
	add_child(mi)
	return mi


## 厚窗簾：兩半，各自是一片有直褶的布（SurfaceTool；拉開時沿 Z 收窄，褶子跟著擠在一起）。
func _build_curtain() -> void:
	var root := Node3D.new()
	root.name = "Curtain"
	add_child(root)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = CURTAIN_CLOTH
	cloth.roughness = 0.95
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var half_w: float = WINDOW_W * 0.5 + 0.14
	var h: float = WINDOW_TOP - WINDOW_SILL + 0.55
	var mesh: ArrayMesh = curtain_mesh(half_w, h)
	for side: String in ["S", "N"]:
		var half := MeshInstance3D.new()
		half.name = "Curtain" + side
		half.mesh = mesh
		half.material_override = cloth
		root.add_child(half)
		_curtain_halves.append(half)
	var rod := MeshInstance3D.new()
	rod.name = "CurtainRod"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.025
	cm.bottom_radius = 0.025
	cm.height = WINDOW_W + 1.2
	rod.mesh = cm
	rod.material_override = _metal(BRONZE, 0.8, 0.35)
	rod.rotation.x = PI * 0.5
	rod.position = Vector3(INNER_HALF_X - 0.14, WINDOW_TOP + 0.3, WINDOW_Z)
	root.add_child(rod)


## 一片有直褶的布：寬 w（沿 Z）、高 h，中心在原點；褶子是沿 Z 的正弦起伏（往 -X 凸），底邊一點點不齊。
static func curtain_mesh(w: float, h: float) -> ArrayMesh:
	const COLS: int = 48
	const ROWS: int = 6
	const FOLD: float = 0.26
	const DEPTH: float = 0.05
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r: int in ROWS + 1:
		var v: float = float(r) / float(ROWS)
		for c: int in COLS + 1:
			var u: float = float(c) / float(COLS)
			var z: float = (u - 0.5) * w
			var x: float = -DEPTH * (0.5 + 0.5 * sin(z * TAU / FOLD))
			var y: float = (0.5 - v) * h
			if r == ROWS:
				y -= 0.03 * sin(z * 17.0) * sin(z * 5.3)
			st.set_uv(Vector2(u, v))
			st.add_vertex(Vector3(x, y, z))
	for r: int in ROWS:
		for c: int in COLS:
			var a: int = r * (COLS + 1) + c
			var b: int = a + COLS + 1
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(b + 1)
			st.add_index(b)
	st.generate_normals()
	return st.commit()


## 窗簾開／關：關著兩半在窗中間合起來；開著各自收到窗邊（變窄、褶子擠在一起），窗外的屏障與眼睛顯示、冷光照進來。
func _set_curtain(open: bool, animate: bool) -> void:
	curtain_open = open
	if not animate:
		for t: Tween in _window_tweens:
			if t.is_valid():
				t.kill()
		_window_tweens.clear()
	var half_w: float = WINDOW_W * 0.5 + 0.14
	var cy: float = (WINDOW_SILL + WINDOW_TOP) * 0.5 + 0.2
	for i: int in _curtain_halves.size():
		var half: Node3D = _curtain_halves[i]
		var sz: float = 1.0 if i == 0 else -1.0
		var closed_z: float = WINDOW_Z + sz * half_w * 0.5
		var open_z: float = WINDOW_Z + sz * (WINDOW_W * 0.5 + 0.12)
		var to_pos := Vector3(INNER_HALF_X - 0.2, cy, open_z if open else closed_z)
		var to_scale := Vector3(1.0, 1.0, 0.26 if open else 1.0)
		if animate:
			var tw: Tween = _window_tween(half).set_parallel(true)
			tw.tween_property(half, "position", to_pos, 1.1).set_trans(Tween.TRANS_SINE)
			tw.tween_property(half, "scale", to_scale, 1.1).set_trans(Tween.TRANS_SINE)
		else:
			half.position = to_pos
			half.scale = to_scale
	if _barrier != null:
		_barrier.visible = open
	if _eye_wall != null:
		_eye_wall.visible = open
	if _barrier_light != null:
		if animate and open:
			_window_tween(_barrier_light).tween_property(_barrier_light, "light_energy", BARRIER_LIGHT_ENERGY, 1.6)
		else:
			_barrier_light.light_energy = BARRIER_LIGHT_ENERGY if open else 0.0
	if animate and open:
		Sfx.play_at(self, "whoosh", Vector3(INNER_HALF_X, 2.6, WINDOW_Z), -14.0)


func _window_tween(node: Node) -> Tween:
	var tw: Tween = node.create_tween()
	_window_tweens.append(tw)
	return tw


func is_curtain_open() -> bool:
	return curtain_open


## 每幀把眼睛的狀態送進 shader（截圖、測試可以直接設 eye_open／pupil／wall_shift）。
func _update_eye() -> void:
	if _eye_mat == null:
		return
	_eye_mat.set_shader_parameter("eye_open", eye_open)
	_eye_mat.set_shader_parameter("pupil", pupil)
	_eye_mat.set_shader_parameter("shift", wall_shift)


## 看過眼睛之後的樣子（過場結束、跳過、重來、讀檔）：窗簾開著、眼睛睜開、瞳孔收窄、伊薩在窗邊。
func _reveal_eye() -> void:
	_set_curtain(true, false)
	eye_open = 1.0
	pupil = PUPIL_NARROW
	wall_shift = 0.0
	_isa_to_window(false)
	_noen_to_window()
	_update_eye()


## 諾恩站到窗前（窗的北邊一點、面向窗外的眼睛）：過場開始時、看過眼睛之後。
func _noen_to_window() -> void:
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player != null:
		var to: Vector3 = Vector3(EYE_X, 0.0, WINDOW_Z) - NOEN_WINDOW
		_put(player, NOEN_WINDOW, atan2(-to.x, -to.z))


## 伊薩走到窗邊（面向窗）；walk＝慢慢走過去（紋路看完那時），否則直接站好。
func _isa_to_window(walk: bool) -> void:
	if _isa == null:
		return
	var to: Vector3 = ISA_WINDOW
	if walk:
		_face(_isa, to)
		_isa.set_move_speed(1.0)
		var tw: Tween = _isa.create_tween()
		tw.tween_property(_isa, "global_position", to, maxf(0.8, _flat(_isa.global_position, to) / 1.4))
		tw.tween_callback(_isa_at_window)
	else:
		_isa.global_position = to
		_isa_at_window()


func _isa_at_window() -> void:
	if _isa == null:
		return
	_isa.set_move_speed(0.0)
	_face(_isa, Vector3(INNER_HALF_X + 1.0, 0.0, WINDOW_Z))


## 走到窗邊的伊薩旁邊（測試也用）：席菈「把人撤走。」→ 諾恩想得到的辦法一條條被擋下 → 伊薩拉開窗簾。
func talk_curtain() -> void:
	if Game.is_in_dialogue() or bool(Game.session.state.get_flag("ch2.curtain_talked", false)):
		return
	Game.start_dialogue(CURTAIN_TALK)


## 過場 ch2_eye；shot＞0 是截圖用（直接跳到第 shot 個鏡頭）。
func _play_eye_cutscene(shot: int) -> void:
	if Game.is_in_cutscene() or bool(Game.session.state.get_flag("ch2.curtain_opened", false)):
		return
	if not Game.play_cutscene(EYE_CUTSCENE):
		return
	_noen_to_window()
	for i: int in shot:
		Game.cutscene.update(100.0)
