extends StoryLevel
## 第 2 章「城主的飯桌」：鐘院（白盒，D-157；08-chapter2-3.md）。
## 第 1 章在白晝城街尾的鐘院門口結束 → 第 2 章章節卡 → 這裡。鐘院另開一個關卡：
## 第 2 章幾乎都在這座建築裡（城主的飯廳 → 鐘院內室的主椅與鐘盤 → 牆上的紋路 → 窗簾後面的眼睛），之後的段落往北接。
## 段落 1 飯桌：三盤煮豆、一鍋稀粥、四個缺口不一樣的碗。走到桌邊 → 伊薩替諾恩拉椅子（右腿的金屬支架吱一聲）→
## 他先問席菈的手、再問彌夏的弟弟 →「他為什麼進了鐘院？」伊薩沒有立刻回答 → 對伊薩按住看穿：攻略的稱號一個字一個字被劃掉（D-158）→
## 段落 2「他自願的。」「那你讓他現在出來。」「我做不到。」（諾恩可以先開口道歉，記 ch2.noen_apologized）→ 湯慢慢涼了 → 鐘院內室待續。
## 還在白晝城裡：照第 1 章的規則，屋裡一盞不投影子的白燈，只有諾恩的油燈投影子；接地陰影也拿掉。
##
## 房間：東西 10 m（x -5～5）、南北 10 m（z -5～5），從南牆的門進來；北牆正中是通往鐘院內室的門（之後的段落）。

const QUEST: String = "ch2_main"
const STAGES: PackedStringArray = ["isa_table", "isa_volunteer", "inner_room"]
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
const INNER_DOOR_POS: Vector3 = Vector3(0.0, 0.0, -4.9)
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
## 坐下之後、沒按看穿的沉默秒數
var silence: float = 0.0
## 截圖用：小卡停在指定的按住秒數
var _dev_insight: bool = false


func _ready() -> void:
	_rng.seed = 2005
	# 開發用：`-- --level=bell_hall` 直接進來 → 照正式流程把第 1 章走完、開始第 2 章
	if not Game.session.state.quests.has(QUEST):
		dev_start_chapter2(Game.session)
	_build_environment()
	_build_room()
	_build_table()
	_init_story()
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player != null:
		_put(player, SPAWN, 0.0)
	_set_up_lamp()
	_build_people()
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
	# 已經坐下過（重來、讀檔）：直接在桌邊
	if bool(Game.session.state.get_flag("ch2.table_seated", false)):
		_seat_everyone()
	if at == "table" and Game.session.quests.stage_of(QUEST) == "isa_table":
		take_seat.call_deferred()
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
	# 段落 3（鐘院內室）還沒做：伊薩說「跟我來」之後顯示「待續」
	if stage == "inner_room" and not _continued_shown:
		_continued_shown = true
		_banner("CH1_TO_BE_CONTINUED", 6.0)


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
	if bool(Game.session.state.get_flag("ch2.usurper_crossed_out", false)) or player.insight_active:
		return {}
	if _flat(player.global_position, _isa.global_position) > ISA_INSIGHT_RANGE:
		return {}
	return {"fmt": TranslationServer.translate("CH2_ISA_INSIGHT_HINT"), "action": "insight", "progress": -1.0}


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
	_solid("WallNorth", Vector3(hx * 2.0, WALL_H, WALL_T), Vector3(0, WALL_H * 0.5, -hz - WALL_T * 0.5), plaster)
	_solid("WallSouth", Vector3(hx * 2.0, WALL_H, WALL_T), Vector3(0, WALL_H * 0.5, hz + WALL_T * 0.5), plaster)
	_solid("WallWest", Vector3(WALL_T, WALL_H, hz * 2.0), Vector3(-hx - WALL_T * 0.5, WALL_H * 0.5, 0), plaster)
	_solid("WallEast", Vector3(WALL_T, WALL_H, hz * 2.0), Vector3(hx + WALL_T * 0.5, WALL_H * 0.5, 0), plaster)
	# 進來的門（南牆，關上了）與鐘院內室的門（北牆正中，比一般的門高、鐵條釘著）
	_solid("HallDoor", Vector3(1.2, 2.2, 0.08), Vector3(0, 1.1, hz - 0.05), wood, false)
	_solid("InnerDoor", Vector3(1.6, 2.8, 0.1), INNER_DOOR_POS + Vector3(0, 1.4, 0), wood, false)
	var iron: StandardMaterial3D = _mat(IRON, 0.6)
	for y: float in [0.5, 1.4, 2.3]:
		_solid("InnerDoorBand%d" % int(y * 10.0), Vector3(1.66, 0.08, 0.04), INNER_DOOR_POS + Vector3(0, y, 0.07), iron, false)
	# 牆腳一圈深色的石條（白盒裡讀得出地板與牆的交界）
	var skirting: StandardMaterial3D = _mat(Color(0.44, 0.42, 0.4), 0.9)
	_solid("SkirtNorth", Vector3(hx * 2.0, 0.18, 0.06), Vector3(0, 0.09, -hz + 0.03), skirting, false)
	_solid("SkirtWest", Vector3(0.06, 0.18, hz * 2.0), Vector3(-hx + 0.03, 0.09, 0), skirting, false)
	_solid("SkirtEast", Vector3(0.06, 0.18, hz * 2.0), Vector3(hx - 0.03, 0.09, 0), skirting, false)
	# 窗簾（西牆，拉著）：第 2 章最後伊薩會拉開它（段落 5）
	_solid("Curtain", Vector3(0.08, 2.6, 2.4), Vector3(-hx + 0.08, 1.55, -0.9), _mat(Color(0.36, 0.3, 0.3), 0.95), false)
	var lamp := OmniLight3D.new()
	lamp.name = "CeilingLamp"
	lamp.light_color = Color(0.92, 0.95, 1.0)
	lamp.light_energy = 0.6
	lamp.omni_range = 8.0
	lamp.shadow_enabled = false
	lamp.position = Vector3(0, WALL_H - 0.4, -0.6)
	add_child(lamp)


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
	# 一鍋稀粥（伊薩那一頭）
	var pot: MeshInstance3D = _cylinder("PorridgePot", self, 0.16, 0.2, top + Vector3(-1.05, 0.1, -0.15), _mat(IRON, 0.5))
	_cylinder("Porridge", pot, 0.145, 0.01, Vector3(0, 0.095, 0), _mat(PORRIDGE, 0.4))
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
