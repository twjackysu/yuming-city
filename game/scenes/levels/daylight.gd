extends StoryLevel
## 第 1 章段落 7：沒有影子的城（白盒，D-154；07-chapter1-door.md「關卡與美術」）。
## 一百七十二階底下的門是白晝城的後門：柯德一家在門房裡吃飯（樓梯底看到的桌子、孩子），
## 門房旁邊就是攻略說「入口有一座淨化爐」的那座爐子——空的、冷了很多年、上面晾著小孩的衣服、爐腳一盆種在半個頭盔裡的蔥。
## 穹頂鑲著數千盞白燈（一個 MultiMesh），沒有太陽、環境光很高：整座城沒有影子，
## **只有諾恩手上的油燈會投影子**（場景斷言測試擋住之後加的燈）。人物腳下的接地陰影也拿掉。
## 路口立著壽命石碑（Residents）：名字＋「還能活 N 天」；看到瑪菈用一天換半壺水（19 → 18）。
## 諾恩按在石碑上只會得到「上面沒有你的名字」。柯德帶路，走到他家門口 → 黑一下換到屋裡（段落 8 晚餐，D-155）：
## 柯德把自己那份切成五片、自己喝水；小女兒問「你們買東西不會變老？」；席菈把乾糧放到桌子中央，玩家可以跟著放。
## 吃完回到街上，柯德往街尾的鐘院走（段落 9 兔子，D-156）：路上一個小女孩摸了席菈背上的斷劍 → 劍柄上的兔子 →
## 「看路，攻略先生。」→ 街中間一根通到穹頂的石柱，諾恩真的會撞上去（碰撞＋彌夏的笑聲）→
## 鐘院門口：第 1 章結束 → 第 2 章章節卡 → 鐘院關卡（D-157）。
## 柯德家的屋內蓋在街區外面（HOUSE_ORIGIN，x = 40），不另開關卡：同一個環境（沒有影子）、同一盞油燈。
##
## 座標：門在南邊（z = GATE_Z），街往 -Z 走到底（z = END_Z）；兩個路口各一塊石碑。

const QUEST: String = "ch1_main"
const STAGES: PackedStringArray = ["daylight_furnace", "daylight_stele", "kord_home", "bell_yard"]
const GATE_Z: float = 20.5
const SQUARE_Z: float = 10.0
const SQUARE_HALF: float = 7.5
const STREET_HALF: float = 3.0
const END_Z: float = -31.0
const CROSSINGS: Array[Vector2] = [Vector2(2.5, -2.5), Vector2(-17.0, -21.0)]
const CROSS_HALF: float = 10.0
const CEILING_Y: float = 16.0
const SPAWN: Vector3 = Vector3(0.0, 0.0, 16.2)
const FURNACE_POS: Vector3 = Vector3(4.2, 0.0, 14.0)
const FURNACE_RANGE: float = 3.6
const ONION_POS: Vector3 = Vector3(3.0, 0.0, 12.9)
## 截圖 `--daylight-at=gate`：站在廣場中間回頭看後門（右）與門房（左）
const GATE_VIEW_POS: Vector3 = Vector3(1.6, 0.0, 11.2)
const GATE_VIEW_YAW: float = 160.0
## 石碑 id -> 位置（面朝 +Z：從門那邊走過來正好看得到字）
const STELES: Dictionary = {
	"stele_gate": Vector3(2.3, 0.0, 3.2),
	"stele_bakery": Vector3(-2.3, 0.0, -16.2),
}
const TRADE_STELE: String = "stele_gate"
const TRADE_RESIDENT: String = "mara"
const TRADE_LINE: String = "DLG_CH1_STELE_002"
const TRADE_RANGE: float = 6.5
const TOUCH_RANGE: float = 2.0
const KORD_HOME: Vector3 = Vector3(-2.9, 0.0, -24.0)
const HOME_RANGE: float = 2.2
## 柯德每個階段站的地方
const KORD_STOPS: Dictionary = {
	"daylight_furnace": Vector3(2.4, 0.0, 15.2),
	"daylight_stele": Vector3(0.9, 0.0, 4.6),
	"kord_home": Vector3(-1.6, 0.0, -23.2),
	"bell_yard": Vector3(1.4, 0.0, -28.6),
}
const KORD_SPEED: float = 2.4
const MISHA_GAP: float = 3.0
const MISHA_SPEED: float = 4.0
## 油燈：這一章唯一投影子的光。四周很亮，要夠強才看得出影子
const LAMP_RANGE: float = 7.0
const LAMP_ENERGY: float = 3.0
## 吃完飯走出門站的地方（柯德家門口往街中央一點，面向街尾）
const AFTER_DINNER_OFFSET: Vector3 = Vector3(1.7, 0.0, 0.3)
## 鐘院門口（街尾）：走到這裡顯示「待續」
const BELL_YARD_POS: Vector3 = Vector3(0.0, 0.0, -29.8)
const BELL_YARD_RANGE: float = 1.8
## 段落 9（D-156）：小女孩與母親站的地方、走過這條線（z）就開「兔子」的對話
const RABBIT_GIRL_POS: Vector3 = Vector3(1.6, 0.0, -25.5)
const RABBIT_Z: float = -24.9
const RABBIT: String = "ch1_rabbit"
## 街中間通到穹頂的石柱：「看路，攻略先生。」之後走過去會撞上（真的擋人；靠到這個距離就算撞到）
const PILLAR_POS: Vector3 = Vector3(-0.8, 0.0, -27.0)
const PILLAR_RADIUS: float = 0.3
const BUMP_REACH: float = 0.42
const PILLAR_TALK: String = "ch1_pillar"

## 柯德家（段落 8，D-155）：一間小室內，蓋在街區外面；屋內 x ±HOUSE_HALF.x、z ±HOUSE_HALF.y，門在南牆
const HOUSE_ORIGIN: Vector3 = Vector3(40.0, 0.0, -24.0)
const HOUSE_HALF: Vector2 = Vector2(3.5, 3.0)
const HOUSE_HEIGHT: float = 3.2
## 桌子（相對 HOUSE_ORIGIN）：桌面中心、大小、高度
const TABLE_POS: Vector3 = Vector3(0.0, 0.0, -0.7)
const TABLE_SIZE: Vector2 = Vector2(1.8, 1.0)
const TABLE_TOP: float = 0.76
## 每個人在桌邊站的地方（相對 HOUSE_ORIGIN）。諾恩站在桌子東南角斜看整張桌子（站正中間會擋住桌面）；
## 席菈、彌夏站在諾恩前面兩側（站在後面會擋住過肩鏡頭）
const SEATS: Dictionary = {
	"noen": Vector3(0.95, 0.0, 0.7),
	"sheila": Vector3(-0.85, 0.0, 0.25),
	"misha": Vector3(2.05, 0.0, 0.35),
	"kord": Vector3(-1.45, 0.0, -0.75),
	"wife": Vector3(1.45, 0.0, -0.75),
	"daughter": Vector3(-0.4, 0.0, -1.6),
	"son": Vector3(0.4, 0.0, -1.6),
}
const DINNER: String = "ch1_kord_dinner"
const CUT_FADE_SEC: float = 0.7
## 吃完飯走在往鐘院的路上的配樂（D-190）：說完話、安靜下來的地方（照 03「配樂放在哪裡」）。
## 淡入很慢、很小聲（比切片收束還小聲）；鐘擺聲同時壓一點，還聽得到。走到鐘院門口（章節卡）淡出。
const AFTER_DINNER_MUSIC: String = "after_dinner_theme"
const AFTER_DINNER_MUSIC_DB: float = -18.0
const AFTER_DINNER_MUSIC_FADE: float = 6.0
const AFTER_DINNER_MUSIC_OUT_SEC: float = 3.5
const AFTER_DINNER_AMBIENCE_DB: float = -15.0
const AMBIENCE_DB: float = -12.0

const PLASTER: Color = Color(0.83, 0.82, 0.78)
const STONE: Color = Color(0.56, 0.54, 0.5)
const PAVING: Color = Color(0.64, 0.62, 0.58)
const SHUTTER: Color = Color(0.3, 0.33, 0.36)
const WOOD: Color = Color(0.32, 0.24, 0.16)
const IRON: Color = Color(0.2, 0.18, 0.16)
const DOME_WHITE: Color = Color(0.93, 0.96, 1.0)

var residents: Residents
var _labels: Dictionary = {}
var _kord: Puppet
var _misha: Puppet
var _mara: Puppet
var _water: MeshInstance3D
var _home_inside: bool = false
## 吃完飯之後的配樂（D-190）；走到鐘院門口開始淡出時 after_dinner_music_out 變 true
var after_dinner_music: AudioStreamPlayer
var after_dinner_music_out: bool = false
var _yard_inside: bool = false
## 諾恩現在在柯德家屋裡（晚餐）
var in_house: bool = false
var _rations_sheila: Node3D
var _rations_noen: Node3D
var _plaster_mat: Material
var _stone_mat: Material
var _shutter_mat: Material
var _wood_mat: StandardMaterial3D
## 街上的小細節（窗台、窗楣、門框、門楣、穹頂的拱肋）：合併成每種材質一個 draw call（第 56 輪，D-174）
var _trim := StaticBatch.new()


## 腳步聲（D-184）：街上是石板（預設），柯德家是木板地。
func footstep_surface(p: Vector3) -> String:
	return "wood" if in_kord_house(p) else "stone"


## 這個位置在柯德家屋內。
static func in_kord_house(p: Vector3) -> bool:
	var d: Vector3 = p - HOUSE_ORIGIN
	return absf(d.x) <= HOUSE_HALF.x + 0.1 and absf(d.z) <= HOUSE_HALF.y + 0.1


func _ready() -> void:
	_rng.seed = 1704
	residents = Residents.load_default()
	_plaster_mat = street_wall_mat()
	_stone_mat = ashlar_mat()
	_shutter_mat = shutter_mat()
	_wood_mat = _mat(WOOD, 0.85)
	var dev_args: Dictionary = App.parse_user_args(OS.get_cmdline_user_args())
	# 開發用：`-- --level=daylight` 直接進來 → 照正式流程走到進城（段落 6 結束）
	# 第 1 章已經完成（開發旗標從後面的章節直接進來）就不動
	if not (Game.session.quests.stage_of(QUEST) in STAGES) and not Game.session.quests.is_done(QUEST):
		dev_start_daylight(Game.session)
	# 截圖用：`--daylight-at=stele` 看完爐子、站在第一塊石碑前（瑪菈換水之前）；
	# `--daylight-at=gate` 看完爐子、回頭看後門與門房；`backdoor` 站在後門口看通道裡；`laundry` 看淨化爐與晾衣繩（第 57 輪）
	var at: String = str(dev_args.get("daylight-at", ""))
	if at in ["stele", "gate", "backdoor", "laundry", "home", "dinner", "yard"]:
		Game.session.state.set_flag("ch1.daylight_intro", true)
		Game.session.set_flag("ch1.saw_empty_furnace", true)
		Game.session.state.set_flag("ch1.furnace_talked", true)
	if at in ["home", "dinner", "yard"]:
		Game.session.set_flag("ch1.saw_stele_trade", true)
		Game.session.state.set_flag("ch1.mara_traded", true)
		Game.session.set_flag(Residents.FLAG_PREFIX + TRADE_RESIDENT, residents.days_left(Game.session.state, TRADE_RESIDENT) - 1)
	# 截圖用：`--daylight-at=yard` 吃完飯站在柯德家門口（往鐘院的路：小女孩、石柱）
	if at == "yard":
		Game.session.state.set_flag("ch1.sheila_shared", true)
		Game.session.set_flag("ch1.kord_dinner_done", true)
	_build_environment()
	_build_ground_and_dome()
	_build_square()
	_build_street()
	_build_steles()
	_build_dome_ribs()
	_trim.build(self, "StreetTrim")
	_build_house()
	_init_story()
	_place_player(at)
	_set_up_lamp()
	_build_people()
	_hide_contact_shadows.call_deferred()
	_start_ambience()
	# 從檢查點 ch1_after_dinner 重來：一進來就在往鐘院的路上
	if Game.session.quests.stage_of(QUEST) == "bell_yard":
		_start_after_dinner_music()
	Game.dialogue_started.connect(_on_dialogue_started)
	Game.dialogue_ended.connect(_on_dialogue_ended)
	add_to_group("interact_prompts")
	# 截圖用：`--daylight-at=dinner` 直接坐到柯德家的桌邊（晚餐對話第一句）
	if at == "dinner" and Game.session.quests.stage_of(QUEST) == "kord_home":
		enter_home.call_deferred(false)


## 開發旗標與測試用：照正式流程推到「走進白晝城」（段落 7 開頭）。已經在白晝城的階段就不動。
static func dev_start_daylight(s: GameSession) -> void:
	if s.quests.stage_of(QUEST) in STAGES:
		return
	if not (s.quests.stage_of(QUEST) in ["stairs", "daylight_gate", "daylight_city"]):
		load("res://scenes/levels/frostbridge.gd").call("dev_start_day", s, "stairs")
	s.state.set_flag("ch1.stair_warned", true)
	s.set_flag("ch1.stair_trap_sprung", true)
	s.state.set_flag("ch1.stair_trap_talked", true)
	s.set_flag("ch1.stairs_bottom", true)
	s.set_flag("ch1.door_opened", true)
	if s.state.get_flag("ch1.kord_first", null) == null:
		s.state.set_flag("ch1.kord_first", "help")
	s.set_flag("ch1.met_kord", true)
	s.set_flag("ch1.entered_daylight", true)


func _place_player(at: String) -> void:
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player == null:
		return
	var p: Vector3 = SPAWN
	var yaw: float = 0.0
	if at == "stele":
		p = (STELES[TRADE_STELE] as Vector3) + Vector3(-2.6, 0.0, 6.0)
		yaw = deg_to_rad(18.0)
	elif at == "gate":
		p = GATE_VIEW_POS
		yaw = deg_to_rad(GATE_VIEW_YAW)
	elif at == "laundry":
		p = Vector3(1.6, 0.0, 19.2)
		yaw = deg_to_rad(-42.0)
	elif at == "backdoor":
		p = Vector3(0.5, 0.0, GATE_Z - 2.2)
		yaw = deg_to_rad(172.0)
	elif at == "home":
		p = KORD_HOME + Vector3(2.4, 0.0, 4.5)
		yaw = deg_to_rad(28.0)
	elif Game.session.quests.stage_of(QUEST) == "bell_yard":
		# 吃完飯（檢查點 ch1_after_dinner）：站在柯德家門口，面向街尾的鐘院
		p = KORD_HOME + AFTER_DINNER_OFFSET
	_put_player(player, p, yaw)


func _put_player(player: Node3D, p: Vector3, yaw: float) -> void:
	player.global_position = p + Vector3(0, 0.05, 0)
	player.rotation.y = yaw
	if player is PlayerController:
		(player as PlayerController).yaw = yaw
		(player as PlayerController).velocity = Vector3.ZERO
		(player as PlayerController).snap_camera()


## 油燈是這一章唯一投影子的光（07）：照遠一點、亮一點，四周的白光裡才讀得出影子。
func _set_up_lamp() -> void:
	var light: OmniLight3D = lamp_light()
	if light != null:
		light.omni_range = LAMP_RANGE
		light.light_energy = LAMP_ENERGY
		light.shadow_enabled = true


func lamp_light() -> OmniLight3D:
	var player: Node3D = get_node_or_null("Player") as Node3D
	return player.find_child("LanternLight", true, false) as OmniLight3D if player != null else null


## 環境音（07）：鐘走得很慢的「喀、答」＋遠處的水聲，循環播放。
func _start_ambience() -> void:
	Ambience.play(self, "daylight_ambience", AMBIENCE_DB)


## 吃完飯、走出柯德家（D-190）：配樂慢慢漲起來，鐘擺聲壓一點。只開一次。
func _start_after_dinner_music() -> void:
	if after_dinner_music != null:
		return
	after_dinner_music = Ambience.music(self, AFTER_DINNER_MUSIC, AFTER_DINNER_MUSIC_DB, AFTER_DINNER_MUSIC_FADE, "AfterDinnerMusic")
	var clock: AudioStreamPlayer = get_node_or_null("Ambience") as AudioStreamPlayer
	if clock != null:
		clock.create_tween().tween_property(clock, "volume_db", AFTER_DINNER_AMBIENCE_DB, AFTER_DINNER_MUSIC_FADE)


## 走到鐘院門口：配樂在章節卡底下淡出（鐘院一開始只有環境音），鐘擺聲回到原本的音量。
func _end_after_dinner_music() -> void:
	if after_dinner_music == null or after_dinner_music_out:
		return
	after_dinner_music_out = true
	var t: Tween = after_dinner_music.create_tween()
	t.tween_property(after_dinner_music, "volume_db", Ambience.MUTED_DB, AFTER_DINNER_MUSIC_OUT_SEC)
	t.tween_callback(after_dinner_music.stop)
	var clock: AudioStreamPlayer = get_node_or_null("Ambience") as AudioStreamPlayer
	if clock != null:
		clock.create_tween().tween_property(clock, "volume_db", AMBIENCE_DB, AFTER_DINNER_MUSIC_OUT_SEC)


## 人物腳下的接地陰影（D-108）在這裡也拿掉：整座城沒有影子。
func _hide_contact_shadows() -> void:
	for n: Node in find_children(ContactShadow.NODE_NAME, "", true, false):
		(n as Node3D).visible = false


# ---------------------------------------------------------------- 流程

func _physics_process(delta: float) -> void:
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player == null:
		return
	_update_people(delta, player)
	_update_table()
	if Game.is_player_locked():
		return
	var st: GameState = Game.session.state
	var stage: String = Game.session.quests.stage_of(QUEST)
	var pos: Vector3 = player.global_position
	# 一進來：白晝城沒有天空（第一眼）
	if not bool(st.get_flag("ch1.daylight_intro", false)):
		Game.start_dialogue("ch1_daylight_enter")
		return
	match stage:
		"daylight_furnace":
			if _flat(pos, FURNACE_POS) <= FURNACE_RANGE:
				see_furnace()
				return
		"daylight_stele":
			if _flat(pos, STELES[TRADE_STELE] as Vector3) <= TRADE_RANGE:
				Game.start_dialogue("ch1_daylight_stele")
				return
	var at_home: bool = _flat(pos, KORD_HOME) <= HOME_RANGE
	if at_home and not _home_inside and stage == "kord_home" and not in_house:
		enter_home()
		return
	_home_inside = at_home
	# 段落 9（D-156）：往鐘院的路上——兔子、撞柱子
	if stage == "bell_yard" and not in_house:
		if not bool(st.get_flag("ch1.rabbit_seen", false)) and pos.z <= RABBIT_Z:
			Game.start_dialogue(RABBIT)
			return
		if bool(st.get_flag("ch1.rabbit_seen", false)) and not bool(st.get_flag("ch1.bumped_pillar", false)) \
				and _flat(pos, PILLAR_POS) <= PILLAR_RADIUS + BUMP_REACH:
			bump_pillar()
			return
	# 吃完飯：跟著柯德走到街尾的鐘院門口 → 第 1 章結束 → 第 2 章章節卡 → 鐘院（D-157）
	var at_yard: bool = _flat(pos, BELL_YARD_POS) <= BELL_YARD_RANGE
	if at_yard and not _yard_inside and stage == "bell_yard":
		reach_bell_yard()
	_yard_inside = at_yard
	if Input.is_action_just_pressed("interact") and nearest_stele() != "":
		touch_stele()


## 走到鐘院門口（測試也用）：第 1 章完成（ch1_main 的 on_complete 開第 2 章、檢查點 ch2_start 自動存檔）→
## 第 2 章章節卡 → 換到檢查點對應的關卡（鐘院）。只做一次。
func reach_bell_yard() -> void:
	if has_node("ChapterCard"):
		return
	Game.session.set_flag("ch1.reached_bell_yard", true)
	_end_after_dinner_music()
	var next_level: String = Game.level_for_checkpoint(Game.session.state.checkpoint)
	if next_level != "daylight" and Game.LEVELS.has(next_level):
		ChapterCard.play(self, "CH2_CARD_NUMBER", "CH2_CARD_TITLE", Game.go_to_level.bind(next_level))
	else:
		_banner("CH1_TO_BE_CONTINUED", 6.0)


## 走到爐子旁邊（測試也用）：攻略筆記「入口的淨化爐」被推翻 → 對話。
func see_furnace() -> void:
	Game.session.set_flag("ch1.saw_empty_furnace", true)
	Game.start_dialogue("ch1_daylight_furnace")


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## 離諾恩最近、按得到的石碑 id（沒有就是空字串）。
func nearest_stele() -> String:
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player == null or Game.is_player_locked():
		return ""
	for id: String in STELES.keys():
		if _flat(player.global_position, STELES[id] as Vector3) <= TOUCH_RANGE:
			return id
	return ""


func interact_hint() -> Dictionary:
	if nearest_stele() == "":
		return {}
	return {"fmt": TranslationServer.translate("CH1_STELE_TOUCH_HINT"), "action": "interact", "progress": -1.0}


## 諾恩把手按在石碑上：上面沒有他的名字（07 系統 2：不讓玩家用壽命換東西）。
func touch_stele() -> void:
	Game.session.state.set_flag("ch1.stele_touched", true)
	Sfx.play_flat(self, "ui_tick", -10.0)
	_banner("CH1_STELE_NO_NAME", 3.5)


## 瑪菈用一天換半壺水（測試也用）：石碑上的數字 19 → 18、壺裡有水。只換一次。
func mara_trade() -> void:
	var st: GameState = Game.session.state
	if bool(st.get_flag("ch1.mara_traded", false)):
		return
	st.set_flag("ch1.mara_traded", true)
	residents.spend(Game.session, TRADE_RESIDENT, 1)
	refresh_steles()
	if _water != null:
		_water.visible = true
	Sfx.play_at(self, "water_splash", STELES[TRADE_STELE] as Vector3 + Vector3(0, 1.0, 0), -16.0)


func _on_dialogue_started(r: DialogueRunner) -> void:
	r.line_shown.connect(_on_line_shown)


func _on_line_shown(_speaker: String, text_key: String) -> void:
	if text_key == TRADE_LINE:
		mara_trade()


func _on_dialogue_ended(dialogue_id: String) -> void:
	# 跳過對話時沒有那一句：照樣換掉
	if dialogue_id == "ch1_daylight_stele":
		mara_trade()
	elif dialogue_id == DINNER and in_house:
		leave_home()
	elif dialogue_id == RABBIT:
		# 跳過對話也照樣算看過兔子
		Game.session.state.set_flag("ch1.rabbit_seen", true)


## 諾恩撞上石柱（測試也用）：咚的一聲＋彌夏的笑聲 → 一句旁白。只撞一次。
func bump_pillar() -> void:
	var st: GameState = Game.session.state
	if bool(st.get_flag("ch1.bumped_pillar", false)):
		return
	st.set_flag("ch1.bumped_pillar", true)
	Sfx.play_at(self, "blunt_weak", PILLAR_POS + Vector3(0, 1.6, 0), -6.0)
	var laugh_at: Vector3 = _misha.global_position if _misha != null else PILLAR_POS
	Sfx.play_at(self, "child_laugh", laugh_at + Vector3(0, 1.4, 0), -8.0)
	Game.start_dialogue(PILLAR_TALK)


# ---------------------------------------------------------------- 段落 8：柯德家的晚餐（D-155）

## 走到柯德家門口（測試也用）：黑一下 → 屋裡，每個人站到桌邊 → 晚餐對話。
func enter_home(fade: bool = true) -> void:
	if in_house:
		return
	in_house = true
	_seat_everyone()
	if fade:
		_cut_from_black(CUT_FADE_SEC)
	Game.start_dialogue(DINNER)


## 吃完飯（晚餐對話結束時；測試也用）：黑一下 → 回到柯德家門口，柯德往鐘院走。
func leave_home() -> void:
	if not in_house:
		return
	in_house = false
	var s: GameSession = Game.session
	# 跳過對話也照樣有：席菈放了乾糧、晚餐吃完了
	s.state.set_flag("ch1.sheila_shared", true)
	if not bool(s.state.get_flag("ch1.kord_dinner_done", false)):
		s.set_flag("ch1.kord_dinner_done", true)
	var player: Node3D = get_node_or_null("Player") as Node3D
	var out: Vector3 = KORD_HOME + AFTER_DINNER_OFFSET
	if player != null:
		_put_player(player, out, 0.0)
	_home_inside = true
	var ally: Node3D = get_node_or_null("Sheila") as Node3D
	if ally != null:
		ally.global_position = out + Vector3(-1.5, 0.05, -0.9)
	if _misha != null:
		_misha.global_position = out + Vector3(1.0, -0.05, -1.3)
	if _kord != null:
		_kord.global_position = KORD_HOME + Vector3(0.6, 0.0, -0.4)
	_cut_from_black(CUT_FADE_SEC)
	_start_after_dinner_music()


func _seat_everyone() -> void:
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player != null:
		var seat: Vector3 = SEATS["noen"] as Vector3
		var to: Vector3 = TABLE_POS - seat
		_put_player(player, HOUSE_ORIGIN + seat, atan2(-to.x, -to.z))
	var ally: Node3D = get_node_or_null("Sheila") as Node3D
	if ally != null:
		ally.global_position = HOUSE_ORIGIN + (SEATS["sheila"] as Vector3) + Vector3(0, 0.05, 0)
	if _misha != null:
		_misha.global_position = HOUSE_ORIGIN + (SEATS["misha"] as Vector3) + Vector3(0, -0.05, 0)
		_face_table(_misha)
	if _kord != null:
		_kord.global_position = HOUSE_ORIGIN + (SEATS["kord"] as Vector3)
		_face_table(_kord)


## 人偶轉向桌子中央。
func _face_table(p: Node3D) -> void:
	var to: Vector3 = HOUSE_ORIGIN + TABLE_POS - p.global_position
	p.rotation.y = atan2(-to.x, -to.z)


## 換地方時黑一下再亮回來（白盒的轉場，不擋輸入）。
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
	# tween 綁在這一層上：連續換兩次地方時舊的一層連同 tween 一起拿掉
	var tw: Tween = layer.create_tween()
	tw.tween_interval(seconds * 0.3)
	tw.tween_property(rect, "modulate:a", 0.0, seconds * 0.7)
	tw.tween_callback(layer.queue_free)


## 桌上的乾糧跟著旗標出現：席菈放的（`ch1.sheila_shared`）、諾恩跟著放的（`ch1.shared_rations`）。
func _update_table() -> void:
	var st: GameState = Game.session.state
	if _rations_sheila != null:
		_rations_sheila.visible = bool(st.get_flag("ch1.sheila_shared", false))
	if _rations_noen != null:
		_rations_noen.visible = st.get_flag("ch1.shared_rations", false) == true


## 段落 9（D-156）：往鐘院的路上——小女孩與母親（縮小的程序人偶）、街中間一根通到穹頂的石柱（真的擋人）。
func _build_rabbit_street() -> void:
	var girl: Puppet = _puppet("RabbitGirl", Color(0.6, 0.44, 0.38), Color(0.76, 0.74, 0.7))
	girl.scale = Vector3.ONE * 0.55
	girl.global_position = RABBIT_GIRL_POS
	girl.rotation.y = deg_to_rad(60.0)
	var mother: Puppet = _puppet("RabbitMother", Color(0.4, 0.4, 0.44), Color(0.72, 0.7, 0.66))
	mother.global_position = RABBIT_GIRL_POS + Vector3(0.6, 0.0, -0.35)
	mother.rotation.y = deg_to_rad(70.0)
	var h: float = CEILING_Y
	var pillar := MeshInstance3D.new()
	pillar.name = "StreetPillar"
	var pm := CylinderMesh.new()
	pm.top_radius = PILLAR_RADIUS
	pm.bottom_radius = PILLAR_RADIUS
	pm.height = h
	pm.radial_segments = 16
	pillar.mesh = pm
	pillar.material_override = _stone_mat
	pillar.position = PILLAR_POS + Vector3(0, h * 0.5, 0)
	add_child(pillar)
	_solid("StreetPillarBase", Vector3(0.8, 0.3, 0.8), PILLAR_POS + Vector3(0, 0.15, 0), trim_mat(), false)
	var body := StaticBody3D.new()
	body.name = "StreetPillarBody"
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = PILLAR_RADIUS
	shape.height = h
	cs.shape = shape
	body.add_child(cs)
	body.position = PILLAR_POS + Vector3(0, h * 0.5, 0)
	add_child(body)


## 柯德家的屋內：木地板、白灰牆、關著的窗板、一盞不投影子的白燈；桌上五片麵包（孩子各兩片、太太一片）、柯德面前只有一杯水。
## 柯德家的室內材質（第 53 輪，D-171，InteriorLook）：木板地、牆腳石塊＋舊灰泥（沒有木框：地底城的房子是石頭砌的，
## 灰泥上只有髒污、雨痕與天花板下的煙燻）、天花板木板、桌面、門板與櫥櫃直排木板。
const HOUSE_STONE_H: float = 0.5
var interior := InteriorLook.new()


func house_wall_mat() -> ShaderMaterial:
	return interior.wall("kord", PLASTER, STONE, HOUSE_STONE_H, {
		"floor_height": 99.0, "post_spacing": 99.0, "brace_chance": 0.0, "beam_width": 0.1,
		"block_scale": 0.7, "soot": 0.65, "soot_top": HOUSE_HEIGHT, "soot_depth": 1.4,
	})


func _build_house() -> void:
	var o: Vector3 = HOUSE_ORIGIN
	var hx: float = HOUSE_HALF.x
	var hz: float = HOUSE_HALF.y
	var floor_mat := interior.plank("kord_floor", Color(0.36, 0.28, 0.2), 0.17, 2.0, {"wear": 0.7, "seam_dark": 0.7})
	_solid("HouseFloor", Vector3(hx * 2.0 + 0.6, 0.4, hz * 2.0 + 0.6), o + Vector3(0, -0.2, 0), floor_mat)
	var ceiling := interior.plank("kord_ceiling", Color(0.3, 0.24, 0.18), 0.15, 2.6, {"along_z": true, "seam_dark": 0.5})
	_solid("HouseCeiling", Vector3(hx * 2.0 + 0.6, 0.3, hz * 2.0 + 0.6), o + Vector3(0, HOUSE_HEIGHT + 0.15, 0), ceiling)
	var wall := house_wall_mat()
	_solid("HouseWallN", Vector3(hx * 2.0 + 0.6, HOUSE_HEIGHT, 0.3), o + Vector3(0, HOUSE_HEIGHT * 0.5, -hz - 0.15), wall)
	_solid("HouseWallS", Vector3(hx * 2.0 + 0.6, HOUSE_HEIGHT, 0.3), o + Vector3(0, HOUSE_HEIGHT * 0.5, hz + 0.15), wall)
	_solid("HouseWallW", Vector3(0.3, HOUSE_HEIGHT, hz * 2.0), o + Vector3(-hx - 0.15, HOUSE_HEIGHT * 0.5, 0), wall)
	_solid("HouseWallE", Vector3(0.3, HOUSE_HEIGHT, hz * 2.0), o + Vector3(hx + 0.15, HOUSE_HEIGHT * 0.5, 0), wall)
	# 屋裡不要穹頂下的白霧（全域的體積霧在小房間裡像起霧）：一個負密度的 FogVolume 把它扣掉
	var clear := FogVolume.new()
	clear.name = "HouseFogClear"
	clear.size = Vector3(hx * 2.0, HOUSE_HEIGHT, hz * 2.0)
	clear.position = o + Vector3(0, HOUSE_HEIGHT * 0.5, 0)
	var fm := FogMaterial.new()
	fm.density = -1.0
	clear.material = fm
	add_child(clear)
	# 牆腳一圈石砌、南牆的門（關著）、西牆關著的窗板、東牆的櫥櫃
	for side: int in [-1, 1]:
		_solid("HousePlinth", Vector3(0.06, HOUSE_STONE_H, hz * 2.0), o + Vector3(side * (hx - 0.03), HOUSE_STONE_H * 0.5, 0), wall, false)
	var boards := interior.plank("kord_door", WOOD, 0.22, 4.0, {"vertical_planks": true, "seam_dark": 0.8})
	_solid("HouseInnerDoor", Vector3(1.0, 2.1, 0.08), o + Vector3(-1.6, 1.05, hz - 0.04), boards, false)
	_solid("HouseShutter", Vector3(0.08, 1.0, 1.2), o + Vector3(-hx + 0.04, 1.6, -1.2),
		interior.plank("kord_shutter", SHUTTER, 0.2, 4.0, {"vertical_planks": true, "seam_dark": 0.8}), false)
	_solid("HouseCupboard", Vector3(0.6, 1.8, 1.4), o + Vector3(hx - 0.3, 0.9, -1.8), boards)
	# 白晝城的燈：天花板上一顆小白燈（不是光源；屋裡一樣沒有影子，只有油燈）
	var bulb := MeshInstance3D.new()
	bulb.name = "HouseLamp"
	var bm := SphereMesh.new()
	bm.radius = 0.12
	bm.height = 0.2
	bulb.mesh = bm
	bulb.material_override = _glow_mat(DOME_WHITE, 5.0)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bulb.position = o + Vector3(0, HOUSE_HEIGHT - 0.12, TABLE_POS.z)
	add_child(bulb)
	# 桌子：桌面＋四隻腳
	var t: Vector3 = o + TABLE_POS
	var table_top := interior.plank("kord_table", WOOD.lightened(0.1), 0.25, 3.0, {"base_roughness": 0.62, "seam_dark": 0.6})
	_solid("DinnerTable", Vector3(TABLE_SIZE.x, 0.08, TABLE_SIZE.y), t + Vector3(0, TABLE_TOP - 0.04, 0), table_top)
	for leg: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var lp := Vector3(leg.x * (TABLE_SIZE.x * 0.5 - 0.08), (TABLE_TOP - 0.08) * 0.5, leg.y * (TABLE_SIZE.y * 0.5 - 0.08))
		_solid("DinnerTableLeg", Vector3(0.07, TABLE_TOP - 0.08, 0.07), t + lp, _wood_mat, false)
	var top: float = TABLE_TOP
	# 麵包：孩子各兩片、太太一片（每個人面前一塊木盤）；柯德面前只有一杯水
	var crumb := _mat(Color(0.78, 0.64, 0.42), 0.95)
	var crust := _mat(Color(0.5, 0.33, 0.18), 0.9)
	var plate_mat := _mat(Color(0.5, 0.4, 0.3), 0.8)
	var slices: Dictionary = {"daughter": 2, "son": 2, "wife": 1}
	for who: String in slices.keys():
		var seat: Vector3 = o + (SEATS[who] as Vector3)
		var at: Vector3 = Vector3(t.x + (seat.x - t.x) * 0.55, 0.0, t.z + (seat.z - t.z) * 0.55)
		at.x = clampf(at.x, t.x - TABLE_SIZE.x * 0.5 + 0.18, t.x + TABLE_SIZE.x * 0.5 - 0.18)
		at.z = clampf(at.z, t.z - TABLE_SIZE.y * 0.5 + 0.16, t.z + TABLE_SIZE.y * 0.5 - 0.16)
		_solid("Plate_" + who, Vector3(0.26, 0.02, 0.2), Vector3(at.x, top + 0.01, at.z), plate_mat, false)
		for k: int in int(slices[who]):
			var sl := _solid("BreadSlice_" + who, Vector3(0.09, 0.025, 0.08), Vector3(at.x - 0.05 + 0.1 * float(k), top + 0.035, at.z), crumb, false)
			sl.rotation.y = 0.3 * float(k) - 0.15
	var kord_seat: Vector3 = o + (SEATS["kord"] as Vector3)
	var cup := MeshInstance3D.new()
	cup.name = "KordWater"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.045
	cm.bottom_radius = 0.04
	cm.height = 0.1
	cup.mesh = cm
	cup.material_override = _mat(Color(0.6, 0.6, 0.58), 0.4)
	cup.position = Vector3(t.x - TABLE_SIZE.x * 0.5 + 0.2, top + 0.05, kord_seat.z)
	add_child(cup)
	# 切剩的麵包頭（切成五片的那一條）
	var loaf := _solid("BreadLoafEnd", Vector3(0.12, 0.09, 0.1), Vector3(t.x - 0.45, top + 0.045, t.z - 0.1), crust, false)
	loaf.rotation.y = 0.4
	# 乾糧：席菈掰開放到桌子中央的兩半；諾恩跟著放的一塊（旗標控制，_update_table）
	var hardtack := _mat(Color(0.46, 0.36, 0.24), 0.95)
	_rations_sheila = Node3D.new()
	_rations_sheila.name = "RationsSheila"
	_rations_sheila.position = t + Vector3(-0.08, top, 0.02)
	add_child(_rations_sheila)
	for k: int in 2:
		var half := MeshInstance3D.new()
		var hb := BoxMesh.new()
		hb.size = Vector3(0.1, 0.04, 0.12)
		half.mesh = hb
		half.material_override = hardtack
		half.position = Vector3(-0.06 + 0.13 * float(k), 0.02, 0.0)
		half.rotation.y = -0.2 + 0.5 * float(k)
		_rations_sheila.add_child(half)
	_rations_noen = Node3D.new()
	_rations_noen.name = "RationsNoen"
	_rations_noen.position = t + Vector3(0.2, top, 0.12)
	add_child(_rations_noen)
	var mine := MeshInstance3D.new()
	var mb := BoxMesh.new()
	mb.size = Vector3(0.2, 0.045, 0.12)
	mine.mesh = mb
	mine.material_override = hardtack
	mine.position = Vector3(0, 0.0225, 0)
	mine.rotation.y = 0.25
	_rations_noen.add_child(mine)
	_update_table()
	_build_rabbit_street()
	# 柯德的太太、兩個孩子（小女兒、兒子：縮小的程序人偶）
	var family: Dictionary = {
		"KordWife": ["wife", Color(0.44, 0.38, 0.34), 1.0],
		"KordDaughter": ["daughter", Color(0.55, 0.4, 0.36), 0.58],
		"KordSon": ["son", Color(0.32, 0.38, 0.44), 0.64],
	}
	for node_name: String in family.keys():
		var row: Array = family[node_name] as Array
		var member: Puppet = _puppet(node_name, row[1] as Color, Color(0.74, 0.72, 0.68))
		member.scale = Vector3.ONE * float(row[2])
		member.global_position = o + (SEATS[str(row[0])] as Vector3)
		_face_table(member)


# ---------------------------------------------------------------- 人：柯德帶路、彌夏跟著、瑪菈在石碑前

func _build_people() -> void:
	_kord = _puppet("Kord", Color(0.36, 0.33, 0.28), Color(0.7, 0.68, 0.62))
	var stage: String = Game.session.quests.stage_of(QUEST)
	_kord.global_position = KORD_STOPS.get(stage, KORD_STOPS["daylight_furnace"]) as Vector3
	_kord.rotation.y = PI
	_misha = _puppet("Misha", Color(0.16, 0.27, 0.21), Color(0.3, 0.26, 0.2))
	var player: Node3D = get_node_or_null("Player") as Node3D
	# 彌夏、席菈站在諾恩前面兩側（站在後面會擋住過肩鏡頭）
	_misha.global_position = (player.global_position if player != null else SPAWN) + Vector3(1.9, -0.05, -1.4)
	var ally := Sheila.new()
	ally.name = "Sheila"
	ally.position = (player.global_position if player != null else SPAWN) + Vector3(-1.7, 0.0, -0.9)
	add_child(ally)
	# 瑪菈：站在第一塊石碑前，左手一個壺
	var stele: Vector3 = STELES[TRADE_STELE] as Vector3
	_mara = _puppet("Mara", Color(0.42, 0.36, 0.4), Color(0.72, 0.7, 0.66))
	_mara.global_position = stele + Vector3(-0.35, 0.0, 0.85)
	_mara.rotation.y = deg_to_rad(-20.0)
	var jug := MeshInstance3D.new()
	jug.name = "Jug"
	var jm := CylinderMesh.new()
	jm.top_radius = 0.07
	jm.bottom_radius = 0.1
	jm.height = 0.26
	jug.mesh = jm
	jug.material_override = _mat(Color(0.55, 0.42, 0.3), 0.7)
	if _mara.hand("L") != null:
		_mara.hand("L").add_child(jug)
		jug.position = Vector3(0, -0.16, 0)
		_water = MeshInstance3D.new()
		_water.name = "JugWater"
		var wm := CylinderMesh.new()
		wm.top_radius = 0.066
		wm.bottom_radius = 0.066
		wm.height = 0.01
		_water.mesh = wm
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.5, 0.62, 0.7)
		wmat.roughness = 0.05
		_water.material_override = wmat
		jug.add_child(_water)
		_water.position = Vector3(0, 0.13, 0)
		_water.visible = bool(Game.session.state.get_flag("ch1.mara_traded", false))


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


func _update_people(delta: float, player: Node3D) -> void:
	if _kord != null:
		var stage: String = Game.session.quests.stage_of(QUEST)
		var want: Vector3 = KORD_STOPS.get(stage, _kord.global_position) as Vector3
		# 屋裡：站在桌邊不動（KORD_STOPS 是街上的位置）
		if in_house:
			want = HOUSE_ORIGIN + (SEATS["kord"] as Vector3)
		var to: Vector3 = Vector3(want.x - _kord.global_position.x, 0.0, want.z - _kord.global_position.z)
		var step: float = minf(to.length(), KORD_SPEED * delta)
		if step > 0.01:
			_kord.global_position += to.normalized() * step
			_kord.rotation.y = atan2(-to.x, -to.z)
		else:
			# 站定了就看著諾恩
			var face: Vector3 = player.global_position - _kord.global_position
			_kord.rotation.y = lerp_angle(_kord.rotation.y, atan2(-face.x, -face.z), minf(delta * 3.0, 1.0))
		_kord.set_move_speed(step / maxf(delta, 0.0001))
	if _misha != null:
		var gap: Vector3 = Vector3(_misha.global_position.x - player.global_position.x, 0.0, _misha.global_position.z - player.global_position.z)
		var dist: float = gap.length()
		var mstep: float = clampf(dist - MISHA_GAP, 0.0, MISHA_SPEED * delta)
		if dist - MISHA_GAP > 10.0:
			mstep = dist - MISHA_GAP
		if mstep > 0.001 and dist > 0.001:
			_misha.global_position -= gap / dist * mstep
			_misha.rotation.y = atan2(gap.x, gap.z)
		_misha.set_move_speed(mstep / maxf(delta, 0.0001))


# ---------------------------------------------------------------- 場景

func _mat(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func _glow_mat(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.BLACK
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


## 沒有太陽、沒有月光：無方向的白光（環境光很高），平得讓人不舒服。不開 SSAO（連角落的暗都不要）。
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.78, 0.8, 0.83)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.93, 1.0)
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.0
	# 畫質設定（QualityPreset）會照等級開關 SSAO 與體積霧：SSAO 強度歸零（連角落的暗都不要），
	# 體積霧是會發光的白（不然沒有燈打進霧裡，遠處會變成一片暗褐色——第 40 輪截圖）；低畫質換成同色的深度霧
	env.ssao_enabled = false
	env.ssao_intensity = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.008
	env.volumetric_fog_albedo = Color(0.9, 0.92, 0.95)
	env.volumetric_fog_emission = Color(0.4, 0.42, 0.45)
	env.volumetric_fog_emission_energy = 1.0
	env.volumetric_fog_length = 64.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)


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


func _build_ground_and_dome() -> void:
	var span_x: float = CROSS_HALF * 2.0 + 8.0
	var z0: float = END_Z - 3.0
	var z1: float = GATE_Z + 2.0
	var mid_z: float = (z0 + z1) * 0.5
	_solid("Ground", Vector3(span_x, 0.4, z1 - z0), Vector3(0, -0.2, mid_z), paving_mat())
	# 穹頂：一大片淡灰白，鑲著數千盞白燈（一個 MultiMesh）
	var dome_mat := _mat(Color(0.7, 0.72, 0.75), 1.0)
	dome_mat.emission_enabled = true
	dome_mat.emission = Color(0.55, 0.57, 0.6)
	dome_mat.emission_energy_multiplier = 0.5
	var dome := _solid("Dome", Vector3(span_x, 0.4, z1 - z0), Vector3(0, CEILING_Y + 0.2, mid_z), dome_mat, false)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.09
	lamp_mesh.height = 0.12
	lamp_mesh.radial_segments = 6
	lamp_mesh.rings = 3
	lamp_mesh.material = _glow_mat(DOME_WHITE, 6.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = lamp_mesh
	var spacing: float = 0.9
	var nx: int = int(span_x / spacing)
	var nz: int = int((z1 - z0) / spacing)
	mm.instance_count = nx * nz
	var i: int = 0
	for ix: int in nx:
		for iz: int in nz:
			var jitter := Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.05, 0.05), _rng.randf_range(-0.2, 0.2))
			var p := Vector3(-span_x * 0.5 + (float(ix) + 0.5) * spacing, CEILING_Y - 0.06, z0 + (float(iz) + 0.5) * spacing) + jitter
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
			i += 1
	var lamps := MultiMeshInstance3D.new()
	lamps.name = "DomeLamps"
	lamps.multimesh = mm
	lamps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lamps)


## 入口的小廣場：後門（暗的樓梯）、柯德一家的門房（桌子、兩個孩子）、空的淨化爐＋晾衣繩＋蔥盆。
func _build_square() -> void:
	var depth: float = GATE_Z - SQUARE_Z
	var mid_z: float = (GATE_Z + SQUARE_Z) * 0.5
	# 南牆＋後門（門洞裡是暗的樓梯）
	_solid("GateWallW", Vector3(SQUARE_HALF - 0.6, 7.0, 0.6), Vector3(-(SQUARE_HALF + 0.6) * 0.5, 3.5, GATE_Z + 0.3), _plaster_mat)
	_solid("GateWallE", Vector3(SQUARE_HALF - 0.6, 7.0, 0.6), Vector3((SQUARE_HALF + 0.6) * 0.5, 3.5, GATE_Z + 0.3), _plaster_mat)
	_solid("GateLintel", Vector3(1.2, 4.8, 0.6), Vector3(0, 4.6, GATE_Z + 0.3), _plaster_mat)
	_build_back_door()
	# 東西兩側的牆
	_solid("SquareWallW", Vector3(0.6, 7.0, depth), Vector3(-SQUARE_HALF - 0.3, 3.5, mid_z), _plaster_mat)
	_solid("SquareWallE", Vector3(0.6, 7.0, depth), Vector3(SQUARE_HALF + 0.3, 3.5, mid_z), _plaster_mat)
	# 門房（西邊，開口朝東）：桌子、兩個孩子、空碗
	var gx: float = -SQUARE_HALF + 2.0
	_build_gatehouse()
	_solid("GateTable", Vector3(1.4, 0.08, 0.8), Vector3(gx + 0.2, 0.76, 17.0), _wood_mat)
	for leg: Vector2 in [Vector2(-0.6, -0.32), Vector2(0.6, -0.32), Vector2(-0.6, 0.32), Vector2(0.6, 0.32)]:
		_solid("GateTableLeg", Vector3(0.06, 0.72, 0.06), Vector3(gx + 0.2 + leg.x, 0.36, 17.0 + leg.y), _wood_mat, false)
	for k: int in 2:
		var kid: Puppet = _puppet("GateChild%d" % k, Color(0.4, 0.34, 0.3) if k == 0 else Color(0.3, 0.36, 0.42), Color(0.74, 0.72, 0.68))
		kid.scale = Vector3.ONE * 0.6
		kid.global_position = Vector3(gx + 0.2 + (-0.45 if k == 0 else 0.4), 0.0, 17.0 + (0.62 if k == 0 else -0.62))
		kid.rotation.y = 0.0 if k == 0 else PI
	# 空的淨化爐：鐵爐身＋爐門（冷的，不發光）＋一路通到穹頂的煙管
	var iron := _mat(IRON, 0.7)
	iron.metallic = 0.55
	var furnace := Node3D.new()
	furnace.name = "Furnace"
	furnace.position = FURNACE_POS
	add_child(furnace)
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.95
	cyl.bottom_radius = 1.15
	cyl.height = 2.1
	body.mesh = cyl
	body.material_override = iron
	body.position = Vector3(0, 1.05, 0)
	furnace.add_child(body)
	var cap := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.25
	cone.bottom_radius = 1.0
	cone.height = 0.6
	cap.mesh = cone
	cap.material_override = iron
	cap.position = Vector3(0, 2.4, 0)
	furnace.add_child(cap)
	var pipe := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.2
	pm.bottom_radius = 0.2
	pm.height = CEILING_Y - 2.6
	pipe.mesh = pm
	pipe.material_override = iron
	pipe.position = Vector3(0, 2.6 + pm.height * 0.5, 0)
	furnace.add_child(pipe)
	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.12, 0.8, 0.9)
	door.mesh = dm
	door.material_override = _mat(Color(0.12, 0.11, 0.1), 0.6)
	door.position = Vector3(-1.08, 0.75, 0)
	furnace.add_child(door)
	_furnace_detail(furnace, cyl, pm.height)
	var furnace_body := StaticBody3D.new()
	var fcs := CollisionShape3D.new()
	var fshape := CylinderShape3D.new()
	fshape.radius = 1.15
	fshape.height = 2.7
	fcs.shape = fshape
	fcs.position = Vector3(0, 1.35, 0)
	furnace_body.add_child(fcs)
	furnace.add_child(furnace_body)
	_build_laundry()
	# 爐腳邊的蔥盆：種在半個頭盔裡
	var pot := Node3D.new()
	pot.name = "OnionPot"
	pot.position = ONION_POS
	add_child(pot)
	var helmet := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.2
	hm.height = 0.2
	hm.is_hemisphere = true
	helmet.mesh = hm
	var steel := _mat(Color(0.45, 0.46, 0.47), 0.45)
	steel.metallic = 0.7
	helmet.material_override = steel
	helmet.rotation_degrees.x = 180.0
	helmet.position = Vector3(0, 0.2, 0)
	pot.add_child(helmet)
	var green := _mat(Color(0.32, 0.5, 0.24), 0.8)
	for s: int in 7:
		var stalk := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.006
		sm.bottom_radius = 0.012
		sm.height = 0.22 + 0.06 * float(s % 3)
		sm.radial_segments = 5
		stalk.mesh = sm
		stalk.material_override = green
		var a: float = float(s) / 7.0 * TAU
		stalk.position = Vector3(cos(a) * 0.08, 0.2 + sm.height * 0.5, sin(a) * 0.08)
		stalk.rotation_degrees = Vector3(sin(a) * 10.0, 0, cos(a) * 10.0)
		pot.add_child(stalk)


## 一條往北的街，兩側石砌＋白灰的房子、窗戶全關；兩個路口，盡頭一道牆（鐘院在後面，第 2 章）。
func _build_street() -> void:
	for side: int in [-1, 1]:
		var z: float = SQUARE_Z
		while z > END_Z + 0.5:
			var gap: Vector2 = _crossing_at(z)
			if gap != Vector2.ZERO:
				z = gap.y
				continue
			var length: float = _rng.randf_range(4.5, 7.5)
			# 柯德家：第二個路口之後左手邊第一棟，門正對 KORD_HOME
			var is_kord: bool = side == -1 and z <= CROSSINGS[1].y and z > CROSSINGS[1].y - 1.0
			if is_kord:
				length = (CROSSINGS[1].y - KORD_HOME.z) * 2.0
			var next_gap: float = _next_gap_start(z)
			length = minf(length, z - maxf(next_gap, END_Z))
			if length < 2.0:
				z -= length
				continue
			_house(side, z, length, is_kord)
			z -= length
	# 路口兩頭擋起來
	for c: Vector2 in CROSSINGS:
		var w: float = c.x - c.y
		for side: int in [-1, 1]:
			_solid("CrossEnd", Vector3(0.6, 9.0, w), Vector3(side * CROSS_HALF, 4.5, (c.x + c.y) * 0.5), _plaster_mat)
			_solid("CrossBack", Vector3(CROSS_HALF - STREET_HALF, 9.0, 0.6), Vector3(side * (CROSS_HALF + STREET_HALF) * 0.5, 4.5, c.y - 0.3), _plaster_mat)
	_solid("EndWall", Vector3(STREET_HALF * 2.0 + 2.0, 11.0, 0.8), Vector3(0, 5.5, END_Z - 0.4), _stone_mat)
	_solid("BellYardGate", Vector3(2.6, 3.6, 0.2), Vector3(0, 1.8, END_Z + 0.05), door_mat(), false)
	# 鐘院大門的木框＋上面一塊淺色石楣
	for side: int in [-1, 1]:
		_trim.add_box_at(Vector3(0.22, 3.75, 0.34), Vector3(side * 1.41, 1.875, END_Z + 0.07), timber_mat(), false)
	_trim.add_box_at(Vector3(3.4, 0.4, 0.4), Vector3(0, 3.95, END_Z + 0.1), trim_mat(), false)


func _crossing_at(z: float) -> Vector2:
	for c: Vector2 in CROSSINGS:
		if z <= c.x + 0.01 and z > c.y:
			return c
	return Vector2.ZERO


func _next_gap_start(z: float) -> float:
	var best: float = -INF
	for c: Vector2 in CROSSINGS:
		if c.x < z - 0.01:
			best = maxf(best, c.x)
	return best


## 一棟房子：z_start 往 -Z 長 length；臨街那面在 x = side × STREET_HALF。
func _house(side: int, z_start: float, length: float, is_kord: bool) -> void:
	var depth: float = 6.0
	var height: float = _rng.randf_range(5.5, 8.5)
	var cz: float = z_start - length * 0.5
	var cx: float = float(side) * (STREET_HALF + depth * 0.5)
	var house := _solid("House", Vector3(depth, height, length - 0.1), Vector3(cx, height * 0.5, cz), _plaster_mat)
	house.set_meta("height", height)
	_solid("HouseBase", Vector3(depth + 0.16, STREET_STONE_H, length), Vector3(cx, STREET_STONE_H * 0.5, cz), _plaster_mat, false)
	var face_x: float = float(side) * (STREET_HALF - 0.04)
	# 門（柯德家的門正對 KORD_HOME）
	var door_z: float = KORD_HOME.z if is_kord else cz + _rng.randf_range(-length * 0.25, length * 0.25)
	_solid("HouseDoor", Vector3(0.1, 2.1, 1.0), Vector3(face_x, 1.05, door_z), door_mat(), false)
	_door_casing(side, door_z)
	_plinth_cap(side, z_start, length, door_z)
	# 窗：每層幾扇，全部關著（灰藍的木窗板）
	var floors: int = int((height - 1.4) / 2.3)
	var per_floor: int = maxi(int(length / 2.2), 1)
	for f: int in floors:
		for w: int in per_floor:
			var wz: float = z_start - (float(w) + 0.5) * length / float(per_floor)
			if f == 0 and absf(wz - door_z) < 1.0:
				continue
			var sy: float = 1.9 + float(f) * 2.3 + 0.55
			_solid("Shutter", Vector3(0.08, 1.1, 0.8), Vector3(face_x, sy, wz), _shutter_mat, false)
			_window_trim(side, sy, wz)
	if is_kord:
		var m := Marker3D.new()
		m.name = "KordHome"
		m.position = KORD_HOME + Vector3(0, 1.0, 0)
		add_child(m)


## 壽命石碑：黑色抛光石，正面浮著名字與「還能活 N 天」（Label3D、子集字型、翻譯 key）。
func _build_steles() -> void:
	var black := stele_stone_mat()
	var font: Font = UiFonts.load_font(UiFonts.UI_SANS)
	for id: String in STELES.keys():
		var pos: Vector3 = STELES[id] as Vector3
		var stele := _solid("Stele_" + id, Vector3(1.0, 2.3, 0.32), pos + Vector3(0, 1.15, 0), black)
		stele.set_meta("stele_id", id)
		_solid("SteleBase", Vector3(1.3, 0.2, 0.6), pos + Vector3(0, 0.1, 0), _stone_mat, false)
		# 石框（第 56 輪，D-174）：兩側方石立柱＋頂上一塊突出的淺色石蓋，黑石嵌在中間（之前是一塊黑方塊）
		for side: int in [-1, 1]:
			_trim.add_box_at(Vector3(0.12, 2.3, 0.42), pos + Vector3(float(side) * 0.56, 1.35, 0), _stone_mat, false)
		_trim.add_box_at(Vector3(1.36, 0.16, 0.5), pos + Vector3(0, 2.5 + 0.08, 0), trim_mat(), false)
		_trim.add_box_at(Vector3(1.16, 0.1, 0.4), pos + Vector3(0, 2.66 + 0.05, 0), trim_mat(), false)
		var label := Label3D.new()
		label.name = "SteleNames_" + id
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.font_size = 26
		label.pixel_size = 0.0036
		label.line_spacing = 6.0
		label.outline_size = 0
		label.modulate = Color(0.86, 0.92, 1.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if font != null:
			label.font = font
		label.position = pos + Vector3(0, 1.35, 0.2)
		add_child(label)
		_labels[id] = label
	refresh_steles()


## 壽命石碑的黑石：磨亮、映著穹頂的冷白光（上面亮一點、斜看邊緣亮一點；第 57 輪，D-175）
const POLISHED_STONE_SHADER: String = "res://src/world/polished_stone.gdshader"


func stele_stone_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(POLISHED_STONE_SHADER) as Shader
	m.set_shader_parameter("sheen_color", DOME_WHITE)
	m.set_shader_parameter("half_height", 1.15)
	return m


func refresh_steles() -> void:
	for id: String in _labels.keys():
		var lines: PackedStringArray = []
		for rid: String in residents.residents_on(id):
			lines.append(residents.line(Game.session.state, rid))
		(_labels[id] as Label3D).text = "\n".join(lines)


func stele_text(id: String) -> String:
	return (_labels[id] as Label3D).text if _labels.has(id) else ""


# ---------------------------------------------------------------- 街道的美術（第 56 輪，D-174）
# 白晝城的街：房子是石頭砌的（牆腳 STREET_STONE_H 的方石）、上面抹白灰泥，沒有木框；窗板與門是直排木板，
# 窗下一塊淺色石窗台、窗上一條石楣，門有深色木門框＋石門楣＋門檻石；地面是沿街鋪的石板；
# 盡頭的牆、門房、石柱是方石。穹頂的白燈之間每 RIB_SPACING 一道拱肋（看得出是蓋起來的天花板）。
# 白晝城的規則照舊：只有油燈投影子（這一節不加任何光）。

const STREET_STONE_H: float = 0.9
const TRIM_STONE: Color = Color(0.72, 0.7, 0.66)
const STREET_MORTAR: Color = Color(0.4, 0.39, 0.37)
## 整面方石的縫比較深（淺縫＋小塊會像水泥空心磚，第 56 輪截圖）
const ASHLAR_MORTAR: Color = Color(0.2, 0.195, 0.19)
## 門框中心離門中心（門寬 1.0、門框 0.12）
const DOOR_CASING_HALF: float = 0.56
const RIB_SPACING: float = 7.0
const RIB_SIZE: Vector2 = Vector2(0.45, 0.5)
const RIB_COLOR: Color = Color(0.5, 0.51, 0.53)


## 房子、廣場與路口的牆：牆腳方石（淺灰縫）＋白灰泥，沒有木框、不燻黑。
func street_wall_mat() -> ShaderMaterial:
	return interior.wall("daylight_street", PLASTER, STONE, STREET_STONE_H, {
		"floor_height": 99.0, "post_spacing": 99.0, "brace_chance": 0.0, "beam_width": 0.04,
		"block_scale": 0.8, "soot": 0.0, "mortar_color": STREET_MORTAR,
	})


## 整面方石：盡頭的牆、門房、石柱、石碑座。
func ashlar_mat() -> ShaderMaterial:
	return interior.wall("daylight_ashlar", STONE, STONE, 99.0, {
		"block_scale": 1.8, "soot": 0.0, "mortar_color": ASHLAR_MORTAR,
	})


## 地面：沿街（南北）鋪的石板，中間常走的地方磨亮一點。
func paving_mat() -> ShaderMaterial:
	return interior.flagstone("daylight_paving", PAVING, 0.6, {"along_z": true, "wear": 0.3, "seam_dark": 0.5})


## 窗台、窗楣、門楣、門檻、石柱座：比牆淺一點的條石。
func trim_mat() -> ShaderMaterial:
	return interior.flagstone("daylight_trim", TRIM_STONE, 0.45, {"seam_dark": 0.7, "base_roughness": 0.8})


func shutter_mat() -> ShaderMaterial:
	return interior.plank("daylight_shutter", SHUTTER, 0.2, 4.0, {"vertical_planks": true, "seam_dark": 0.45})


func door_mat() -> ShaderMaterial:
	return interior.plank("daylight_door", WOOD, 0.2, 4.0, {"vertical_planks": true, "seam_dark": 0.8})


func timber_mat() -> ShaderMaterial:
	return interior.timber(WOOD.darkened(0.3))


## 窗：下面一塊石窗台（往街上突出一點）、上面一條石楣。sy＝窗板中心高度。
func _window_trim(side: int, sy: float, wz: float) -> void:
	var s: float = float(side)
	_trim.add_box_at(Vector3(0.2, 0.07, 0.98), Vector3(s * (STREET_HALF - 0.1), sy - 0.55 - 0.035, wz), trim_mat(), false)
	_trim.add_box_at(Vector3(0.1, 0.16, 1.0), Vector3(s * (STREET_HALF - 0.05), sy + 0.55 + 0.08, wz), trim_mat(), false)


## 牆腳石的頂面蓋一條淺色壓頂石（不然半木構 shader 在 8 cm 寬的頂面畫出一條深色斜紋）；門的地方斷開。
func _plinth_cap(side: int, z_start: float, length: float, door_z: float) -> void:
	var gap: float = DOOR_CASING_HALF + 0.07
	var spans: Array[Vector2] = [Vector2(z_start, door_z + gap), Vector2(door_z - gap, z_start - length)]
	for sp: Vector2 in spans:
		var l: float = sp.x - sp.y
		if l > 0.05:
			_trim.add_box_at(Vector3(0.1, 0.05, l), Vector3(float(side) * (STREET_HALF - 0.05), STREET_STONE_H + 0.025, (sp.x + sp.y) * 0.5), trim_mat(), false)


## 門：兩根深色木門框、上面一塊石門楣、腳下一塊門檻石（都不擋人）。
func _door_casing(side: int, door_z: float) -> void:
	var s: float = float(side)
	for k: int in [-1, 1]:
		_trim.add_box_at(Vector3(0.14, 2.2, 0.12), Vector3(s * (STREET_HALF - 0.07), 1.1, door_z + float(k) * DOOR_CASING_HALF), timber_mat(), false)
	_trim.add_box_at(Vector3(0.18, 0.26, 1.5), Vector3(s * (STREET_HALF - 0.09), 2.33, door_z), trim_mat(), false)
	_trim.add_box_at(Vector3(0.35, 0.06, 1.3), Vector3(s * (STREET_HALF - 0.175), 0.03, door_z), trim_mat(), false)


## 穹頂的拱肋：橫跨整座城、每 RIB_SPACING 一道，壓在白燈之間（看得出是蓋起來的天花板，不是天空）。
func _build_dome_ribs() -> void:
	var span_x: float = CROSS_HALF * 2.0 + 8.0
	var rib := _mat(RIB_COLOR, 0.9)
	var z: float = GATE_Z
	while z > END_Z - 3.0:
		_trim.add_box_at(Vector3(span_x, RIB_SIZE.x, RIB_SIZE.y), Vector3(0, CEILING_Y - RIB_SIZE.x * 0.5, z), rib, false)
		z -= RIB_SPACING


func dome_rib_count() -> int:
	var n: int = 0
	var z: float = GATE_Z
	while z > END_Z - 3.0:
		n += 1
		z -= RIB_SPACING
	return n


## 淨化爐的細節（第 56 輪，D-174）：爐身三道鐵箍、底下一圈石座、爐門的鐵框與門閂、煙管每 FURNACE_PIPE_JOINT 一個接頭箍。
## 鐵箍與接頭比爐身亮一點、帶點鏽色（冷了很多年）；全部不發光。
const FURNACE_BANDS: PackedFloat32Array = [0.22, 1.05, 1.88]
const FURNACE_PIPE_JOINT: float = 2.4
const RUST_IRON: Color = Color(0.32, 0.24, 0.19)


func _furnace_detail(furnace: Node3D, body: CylinderMesh, pipe_h: float) -> void:
	var rust := _mat(RUST_IRON, 0.75)
	rust.metallic = 0.4
	for k: int in FURNACE_BANDS.size():
		var y: float = FURNACE_BANDS[k]
		var r: float = lerpf(body.bottom_radius, body.top_radius, y / body.height) + 0.035
		var band := MeshInstance3D.new()
		band.name = "FurnaceBand%d" % k
		var bm := CylinderMesh.new()
		bm.top_radius = r
		bm.bottom_radius = r
		bm.height = 0.1
		bm.radial_segments = 32
		band.mesh = bm
		band.material_override = rust
		band.position = Vector3(0, y, 0)
		furnace.add_child(band)
	var plinth := MeshInstance3D.new()
	plinth.name = "FurnacePlinth"
	var pl := CylinderMesh.new()
	pl.top_radius = body.bottom_radius + 0.18
	pl.bottom_radius = body.bottom_radius + 0.22
	pl.height = 0.16
	pl.radial_segments = 24
	plinth.mesh = pl
	plinth.material_override = trim_mat()
	plinth.position = Vector3(0, 0.08, 0)
	furnace.add_child(plinth)
	# 爐門：鐵框（上下左右四條）＋一根橫的門閂
	var door_x: float = -1.13
	var frame_parts: Array[Array] = [
		[Vector3(0.06, 0.08, 1.04), Vector3(door_x, 1.19, 0)], [Vector3(0.06, 0.08, 1.04), Vector3(door_x, 0.31, 0)],
		[Vector3(0.06, 0.96, 0.08), Vector3(door_x, 0.75, -0.48)], [Vector3(0.06, 0.96, 0.08), Vector3(door_x, 0.75, 0.48)],
		[Vector3(0.05, 0.05, 0.7), Vector3(door_x - 0.03, 0.8, 0.05)],
	]
	for i: int in frame_parts.size():
		var part := MeshInstance3D.new()
		part.name = "FurnaceDoorFrame%d" % i
		var fm := BoxMesh.new()
		fm.size = frame_parts[i][0] as Vector3
		part.mesh = fm
		part.material_override = rust
		part.position = frame_parts[i][1] as Vector3
		furnace.add_child(part)
	# 煙管的接頭箍
	var y0: float = 2.6 + FURNACE_PIPE_JOINT
	var j: int = 0
	while y0 < 2.6 + pipe_h - 0.5:
		var joint := MeshInstance3D.new()
		joint.name = "FurnacePipeJoint%d" % j
		var jm := CylinderMesh.new()
		jm.top_radius = 0.24
		jm.bottom_radius = 0.24
		jm.height = 0.12
		jm.radial_segments = 16
		joint.mesh = jm
		joint.material_override = rust
		joint.position = Vector3(0, y0, 0)
		furnace.add_child(joint)
		y0 += FURNACE_PIPE_JOINT
		j += 1


# ---------------------------------------------------------------- 後門與門房（第 57 輪，D-175）
# 後門：一百七十二階底下那扇門從這一側看是一個門洞——木門框＋石門楣＋門檻石，門洞裡是往上的石階，
# 柯德打開的門板靠在通道的西牆上。通道照不到穹頂的光（dark_passage shader 用 AO 壓掉環境光），
# 從門口往裡很快變黑；油燈的直接光照常照得到（諾恩走近時看得到台階）。門洞照舊不能走回去（看不見的擋板）。
# 門房：靠在廣場西牆上的開放式小屋（柯德一家吃飯的地方）——方石北牆開一扇小窗、前面（東）兩根石柱＋一根木樑、
# 前面一道矮牆（留一個入口靠近後門）、往東斜的木板屋頂＋往外伸的屋簷與石簷口。桌子與孩子照舊從廣場看得到。

const DARK_PASSAGE_SHADER: String = "res://src/world/dark_passage.gdshader"
const GATE_W: float = 1.2
const GATE_H: float = 2.2
## 牆後的平台（門板靠在這裡）＋往上的台階
const PASSAGE_LANDING: float = 1.1
const PASSAGE_STEPS: int = 6
const STEP_RISE: float = 0.17
const STEP_RUN: float = 0.3
const PASSAGE_CEILING: float = 2.9
## 從門洞往裡多遠環境光幾乎沒了
const PASSAGE_DARK: float = 2.6
## 最深處還留多少環境光
const PASSAGE_MIN_AMBIENT: float = 0.03
const PASSAGE_STONE: Color = Color(0.34, 0.33, 0.31)
const GATE_DOOR_LEAF: Vector2 = Vector2(1.0, 2.1)
## 門房：西牆（x = -SQUARE_HALF）到前面（GATEHOUSE_FRONT_X），北牆在 GATEHOUSE_N_Z、南邊靠著後門那道牆
const GATEHOUSE_FRONT_X: float = -3.5
const GATEHOUSE_N_Z: float = 14.6
const GATEHOUSE_WALL_H: float = 3.0
const GATEHOUSE_EAVE: float = 0.55
## 屋頂往東斜：靠牆那端高、屋簷那端低
const GATEHOUSE_ROOF_BACK_Y: float = 3.45
const GATEHOUSE_ROOF_FRONT_Y: float = 3.0
## 前面的矮牆（比桌面低：桌子與孩子從廣場看得到）、入口在靠後門那端
const GATEHOUSE_SILL_H: float = 0.55
const GATEHOUSE_ENTRY: Vector2 = Vector2(18.2, 19.9)
## 北牆的小窗（中心 x、底、寬、高）
const GATEHOUSE_WINDOW: Vector4 = Vector4(-5.6, 1.2, 0.8, 0.7)

var _passage_mats: Dictionary = {}


## 通道的石頭：同一個 shader，門洞位置與方向都一樣，顏色分幾種（台階、牆、天花板）
func passage_mat(color: Color) -> ShaderMaterial:
	var key: String = color.to_html()
	if _passage_mats.has(key):
		return _passage_mats[key] as ShaderMaterial
	var m := ShaderMaterial.new()
	m.shader = load(DARK_PASSAGE_SHADER) as Shader
	m.set_shader_parameter("albedo_color", color)
	m.set_shader_parameter("dark_origin", Vector3(0.0, 0.0, GATE_Z + 0.6))
	m.set_shader_parameter("dark_dir", Vector3(0.0, 0.0, 1.0))
	m.set_shader_parameter("dark_length", PASSAGE_DARK)
	m.set_shader_parameter("min_ambient", PASSAGE_MIN_AMBIENT)
	_passage_mats[key] = m
	return m


## 門洞後面的通道從牆背面（z = GATE_Z + 0.6）往 +Z：平台 → 台階往上。
static func passage_length() -> float:
	return PASSAGE_LANDING + float(PASSAGE_STEPS) * STEP_RUN


func _build_back_door() -> void:
	var back: float = GATE_Z + 0.6
	var half: float = GATE_W * 0.5
	var length: float = passage_length()
	var door := Node3D.new()
	door.name = "BackDoor"
	add_child(door)
	# 門框（廣場這一側）：兩根深色木柱＋石門楣＋門檻石
	for k: int in [-1, 1]:
		_trim.add_box_at(Vector3(0.14, GATE_H + 0.1, 0.14), Vector3(float(k) * (half + 0.07), (GATE_H + 0.1) * 0.5, GATE_Z - 0.07), timber_mat(), false)
	_trim.add_box_at(Vector3(GATE_W + 0.6, 0.3, 0.2), Vector3(0, GATE_H + 0.1 + 0.15, GATE_Z - 0.1), trim_mat(), false)
	_trim.add_box_at(Vector3(GATE_W + 0.2, 0.06, 0.9), Vector3(0, 0.03, GATE_Z + 0.25), trim_mat(), false)
	# 通道：地板、兩側的牆、天花板、最裡面一道牆（台階頂上再往上轉，看不到）
	var floor_c: Color = PASSAGE_STONE
	var wall_c: Color = PASSAGE_STONE.darkened(0.12)
	_passage_box(door, "PassageFloor", Vector3(GATE_W, 0.1, PASSAGE_LANDING), Vector3(0, -0.05, back + PASSAGE_LANDING * 0.5), floor_c)
	for k: int in [-1, 1]:
		_passage_box(door, "PassageWall%s" % ("W" if k < 0 else "E"), Vector3(0.2, PASSAGE_CEILING + 1.0, length + 0.2),
				Vector3(float(k) * (half + 0.1), (PASSAGE_CEILING + 1.0) * 0.5, back + length * 0.5), wall_c)
	_passage_box(door, "PassageCeiling", Vector3(GATE_W + 0.4, 0.2, length + 0.2), Vector3(0, PASSAGE_CEILING + float(PASSAGE_STEPS) * STEP_RISE * 0.5 + 0.1, back + length * 0.5), wall_c)
	_passage_box(door, "PassageBack", Vector3(GATE_W + 0.4, PASSAGE_CEILING + 1.4, 0.2), Vector3(0, (PASSAGE_CEILING + 1.4) * 0.5, back + length + 0.1), wall_c)
	for i: int in PASSAGE_STEPS:
		var top: float = float(i + 1) * STEP_RISE
		var z0: float = back + PASSAGE_LANDING + float(i) * STEP_RUN
		# 台階一階深一階淺（位置決定，不動 _rng）
		var c: Color = floor_c.lightened(0.06) if i % 2 == 0 else floor_c
		_passage_box(door, "PassageStep%d" % i, Vector3(GATE_W, top, STEP_RUN), Vector3(0, top * 0.5, z0 + STEP_RUN * 0.5), c)
	# 柯德打開的門板：往通道裡開，靠在西牆上（門軸在門洞那端）
	var leaf := MeshInstance3D.new()
	leaf.name = "BackDoorLeaf"
	var lm := BoxMesh.new()
	lm.size = Vector3(0.06, GATE_DOOR_LEAF.y, GATE_DOOR_LEAF.x)
	leaf.mesh = lm
	leaf.material_override = door_mat()
	leaf.position = Vector3(-half + 0.05, GATE_DOOR_LEAF.y * 0.5 + 0.02, back + 0.05 + GATE_DOOR_LEAF.x * 0.5)
	door.add_child(leaf)
	# 擋板：門洞走不回去（不畫）
	var block := StaticBody3D.new()
	block.name = "BackDoorBlock"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GATE_W, GATE_H, 0.1)
	cs.shape = box
	block.add_child(cs)
	block.position = Vector3(0, GATE_H * 0.5, GATE_Z + 0.55)
	door.add_child(block)


func _passage_box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = passage_mat(color)
	mi.position = pos
	parent.add_child(mi)


func _build_gatehouse() -> void:
	var x0: float = -SQUARE_HALF
	var x1: float = GATEHOUSE_FRONT_X
	var width: float = x1 - x0
	var nz: float = GATEHOUSE_N_Z
	var sz: float = GATE_Z
	var house := Node3D.new()
	house.name = "Gatehouse"
	add_child(house)
	# 北牆：方石，開一扇小窗（四塊：窗左、窗右、窗下、窗上）
	var w: Vector4 = GATEHOUSE_WINDOW
	var wl: float = w.x - w.z * 0.5
	var wr: float = w.x + w.z * 0.5
	var wt: float = w.y + w.w
	_solid("GatehouseN", Vector3(wl - x0, GATEHOUSE_WALL_H, 0.3), Vector3((x0 + wl) * 0.5, GATEHOUSE_WALL_H * 0.5, nz), _stone_mat)
	_solid("GatehouseN2", Vector3(x1 - wr, GATEHOUSE_WALL_H, 0.3), Vector3((wr + x1) * 0.5, GATEHOUSE_WALL_H * 0.5, nz), _stone_mat)
	_solid("GatehouseNSill", Vector3(w.z, w.y, 0.3), Vector3(w.x, w.y * 0.5, nz), _stone_mat)
	_solid("GatehouseNHead", Vector3(w.z, GATEHOUSE_WALL_H - wt, 0.3), Vector3(w.x, (GATEHOUSE_WALL_H + wt) * 0.5, nz), _stone_mat, false)
	_trim.add_box_at(Vector3(w.z + 0.16, 0.07, 0.44), Vector3(w.x, w.y - 0.035, nz), trim_mat(), false)
	_trim.add_box_at(Vector3(w.z + 0.3, 0.16, 0.36), Vector3(w.x, wt + 0.08, nz), trim_mat(), false)
	# 窗板關著（白晝城的窗都關著），往牆裡退一點
	_solid("GatehouseShutter", Vector3(w.z, w.w, 0.06), Vector3(w.x, w.y + w.w * 0.5, nz + 0.04), _shutter_mat, false)
	# 前面：北牆端一根、靠後門那端一根石柱，上面一根木樑
	for z: float in [nz + 0.05, sz - 0.25]:
		_solid("GatehousePost", Vector3(0.4, GATEHOUSE_ROOF_FRONT_Y, 0.4), Vector3(x1 - 0.2, GATEHOUSE_ROOF_FRONT_Y * 0.5, z), _stone_mat)
	var beam_len: float = sz - nz
	_trim.add_box_at(Vector3(0.3, 0.32, beam_len), Vector3(x1 - 0.2, GATEHOUSE_ROOF_FRONT_Y - 0.16, (nz + sz) * 0.5), timber_mat(), false)
	# 前面的矮牆＋壓頂石（入口在靠後門那端）
	var sill_z0: float = nz + 0.25
	var sill_z1: float = GATEHOUSE_ENTRY.x
	_solid("GatehouseSill", Vector3(0.35, GATEHOUSE_SILL_H, sill_z1 - sill_z0), Vector3(x1 - 0.2, GATEHOUSE_SILL_H * 0.5, (sill_z0 + sill_z1) * 0.5), _stone_mat)
	_trim.add_box_at(Vector3(0.45, 0.06, sill_z1 - sill_z0), Vector3(x1 - 0.2, GATEHOUSE_SILL_H + 0.03, (sill_z0 + sill_z1) * 0.5), trim_mat(), false)
	# 屋頂：木板，往東斜、伸出屋簷；簷口一條石
	var run: float = width + GATEHOUSE_EAVE
	var drop: float = GATEHOUSE_ROOF_BACK_Y - GATEHOUSE_ROOF_FRONT_Y
	var slope: float = atan2(drop, width)
	var roof_len: float = sz - nz + 0.6
	var roof := MeshInstance3D.new()
	roof.name = "GatehouseRoof"
	var rm := BoxMesh.new()
	rm.size = Vector3(run / cos(slope), 0.12, roof_len)
	roof.mesh = rm
	roof.material_override = roof_plank_mat()
	var mid_x: float = x0 + run * 0.5
	var mid_y: float = GATEHOUSE_ROOF_BACK_Y - tan(slope) * run * 0.5 + 0.06
	roof.transform = Transform3D(Basis(Vector3.BACK, -slope), Vector3(mid_x, mid_y, sz - roof_len * 0.5 + 0.3))
	house.add_child(roof)
	var eave_y: float = GATEHOUSE_ROOF_BACK_Y - tan(slope) * run
	_trim.add_box_at(Vector3(0.16, 0.2, roof_len + 0.1), Vector3(x0 + run, eave_y + 0.02, sz - roof_len * 0.5 + 0.3), trim_mat(), false)
	# 屋簷下的椽子（每 0.9 m 一根，從木樑伸到簷口）
	var z: float = nz + 0.3
	while z < sz - 0.3:
		_trim.add_box_at(Vector3(GATEHOUSE_EAVE + 0.3, 0.1, 0.08), Vector3(x1 + GATEHOUSE_EAVE * 0.5 - 0.15, GATEHOUSE_ROOF_FRONT_Y - 0.05 - tan(slope) * GATEHOUSE_EAVE * 0.5, z), timber_mat(), false)
		z += 0.9


## 門房屋頂：橫排木板（從底下看得到板縫）
func roof_plank_mat() -> ShaderMaterial:
	return interior.plank("daylight_roof", WOOD.lightened(0.08), 0.18, 4.0, {"seam_dark": 0.6})


# ---------------------------------------------------------------- 晾衣繩（第 57 輪，D-175）
# 從淨化爐的煙管拉到東牆的一條繩子，中間往下垂；掛著小孩的衣服（上衣、褲子、毛巾、小裙子），每件兩個木夾子。
# 衣服是薄薄一片、輕微起伏的布（雙面），不是方塊。地底沒有風：衣服靜止垂著。

const ROPE_FROM: Vector3 = FURNACE_POS + Vector3(0.0, 2.75, 0.0)
const ROPE_TO: Vector3 = Vector3(SQUARE_HALF, 2.6, FURNACE_POS.z + 2.4)
const ROPE_SAG: float = 0.2
const ROPE_SEGMENTS: int = 10
## 衣服的輪廓（u 沿繩子、v 往下，公尺）：上衣、褲子、毛巾、小裙子
static func garment_outlines() -> Array[PackedVector2Array]:
	return [
		# 上衣
		PackedVector2Array([Vector2(-0.21, 0.0), Vector2(0.21, 0.0), Vector2(0.23, -0.17), Vector2(0.14, -0.13), Vector2(0.14, -0.44), Vector2(-0.14, -0.44), Vector2(-0.14, -0.13), Vector2(-0.23, -0.17)]),
		# 褲子
		PackedVector2Array([Vector2(-0.15, 0.0), Vector2(0.15, 0.0), Vector2(0.17, -0.42), Vector2(0.03, -0.42), Vector2(0.0, -0.13), Vector2(-0.03, -0.42), Vector2(-0.17, -0.42)]),
		# 毛巾
		PackedVector2Array([Vector2(-0.17, 0.0), Vector2(0.17, 0.0), Vector2(0.17, -0.52), Vector2(-0.17, -0.52)]),
		# 小裙子
		PackedVector2Array([Vector2(-0.1, 0.0), Vector2(0.1, 0.0), Vector2(0.21, -0.47), Vector2(-0.21, -0.47)]),
	]


const GARMENT_COLORS: Array[Color] = [Color(0.62, 0.5, 0.42), Color(0.48, 0.55, 0.6), Color(0.7, 0.66, 0.58), Color(0.55, 0.42, 0.45)]


## 繩子上 t（0～1）的位置：直線往下垂成拋物線
static func rope_point(t: float) -> Vector3:
	return ROPE_FROM.lerp(ROPE_TO, t) - Vector3(0.0, ROPE_SAG * 4.0 * t * (1.0 - t), 0.0)


## 一件衣服的 mesh：輪廓三角化、每個頂點往法線方向起伏一點（布不是平的）
static func garment_mesh(outline: PackedVector2Array, seed_i: int) -> ArrayMesh:
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	# 把輪廓細分：三角形每條邊切一半再起伏，看得出布的皺
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(0, tris.size(), 3):
		var a: Vector2 = outline[tris[i]]
		var b: Vector2 = outline[tris[i + 1]]
		var c: Vector2 = outline[tris[i + 2]]
		var ab: Vector2 = (a + b) * 0.5
		var bc: Vector2 = (b + c) * 0.5
		var ca: Vector2 = (c + a) * 0.5
		for tri: Array in [[a, ab, ca], [ab, b, bc], [ca, bc, c], [ab, bc, ca]]:
			for p: Vector2 in tri:
				st.set_uv(p)
				st.add_vertex(_cloth_point(p, seed_i))
	st.generate_normals()
	return st.commit()


static func _cloth_point(p: Vector2, seed_i: int) -> Vector3:
	var k: float = float(seed_i) * 1.7
	# 夾子那條邊（v = 0）是平的，越往下起伏越大
	var depth: float = clampf(-p.y / 0.45, 0.0, 1.0)
	var z: float = (0.025 * sin(p.x * 21.0 + k) + 0.015 * sin(p.y * 17.0 - k * 0.6)) * (0.3 + 0.7 * depth)
	return Vector3(p.x, p.y, z)


func _build_laundry() -> void:
	var rope_mat := _mat(Color(0.5, 0.46, 0.38), 1.0)
	var line := Node3D.new()
	line.name = "Clothesline"
	add_child(line)
	for i: int in ROPE_SEGMENTS:
		var a: Vector3 = rope_point(float(i) / float(ROPE_SEGMENTS))
		var b: Vector3 = rope_point(float(i + 1) / float(ROPE_SEGMENTS))
		var seg := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.015, 0.015, a.distance_to(b) + 0.01)
		seg.mesh = rm
		seg.material_override = rope_mat
		line.add_child(seg)
		seg.transform = Transform3D(Basis.looking_at(b - a, Vector3.UP), (a + b) * 0.5)
	var along: Vector3 = Vector3(ROPE_TO.x - ROPE_FROM.x, 0.0, ROPE_TO.z - ROPE_FROM.z).normalized()
	var basis := Basis(along, Vector3.UP, along.cross(Vector3.UP))
	var outlines: Array[PackedVector2Array] = garment_outlines()
	for c: int in outlines.size():
		var t: float = (float(c) + 1.0) / float(outlines.size() + 1)
		var at: Vector3 = rope_point(t)
		var cloth := MeshInstance3D.new()
		cloth.name = "Laundry%d" % c
		cloth.mesh = garment_mesh(outlines[c], c)
		var m := _mat(GARMENT_COLORS[c], 1.0)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		cloth.material_override = m
		cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		cloth.transform = Transform3D(basis, at - Vector3(0.0, 0.01, 0.0))
		add_child(cloth)
		# 兩個木夾子（衣服上緣兩端往內一點）
		var top: PackedVector2Array = outlines[c]
		var half_w: float = absf(top[1].x - top[0].x) * 0.5 - 0.03
		for k: int in [-1, 1]:
			_trim.add_box_at(Vector3(0.022, 0.07, 0.022), at + along * (float(k) * half_w) + Vector3(0.0, -0.015, 0.0), _wood_mat, false)
