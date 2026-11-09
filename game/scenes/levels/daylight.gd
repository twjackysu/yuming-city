extends StoryLevel
## 第 1 章段落 7：沒有影子的城（白盒，D-154；07-chapter1-door.md「關卡與美術」）。
## 一百七十二階底下的門是白晝城的後門：柯德一家在門房裡吃飯（樓梯底看到的桌子、孩子），
## 門房旁邊就是攻略說「入口有一座淨化爐」的那座爐子——空的、冷了很多年、上面晾著小孩的衣服、爐腳一盆種在半個頭盔裡的蔥。
## 穹頂鑲著數千盞白燈（一個 MultiMesh），沒有太陽、環境光很高：整座城沒有影子，
## **只有諾恩手上的油燈會投影子**（場景斷言測試擋住之後加的燈）。人物腳下的接地陰影也拿掉。
## 路口立著壽命石碑（Residents）：名字＋「還能活 N 天」；看到瑪菈用一天換半壺水（19 → 18）。
## 諾恩按在石碑上只會得到「上面沒有你的名字」。柯德帶路，走到他家門口顯示「待續」（段落 8 晚餐下一輪做）。
##
## 座標：門在南邊（z = GATE_Z），街往 -Z 走到底（z = END_Z）；兩個路口各一塊石碑。

const QUEST: String = "ch1_main"
const STAGES: PackedStringArray = ["daylight_furnace", "daylight_stele", "kord_home"]
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
}
const KORD_SPEED: float = 2.4
const MISHA_GAP: float = 3.0
const MISHA_SPEED: float = 4.0
## 油燈：這一章唯一投影子的光。四周很亮，要夠強才看得出影子
const LAMP_RANGE: float = 7.0
const LAMP_ENERGY: float = 3.0

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
var _plaster_mat: StandardMaterial3D
var _stone_mat: StandardMaterial3D
var _shutter_mat: StandardMaterial3D
var _wood_mat: StandardMaterial3D


func _ready() -> void:
	_rng.seed = 1704
	residents = Residents.load_default()
	_plaster_mat = _mat(PLASTER, 0.93)
	_stone_mat = _mat(STONE, 0.95)
	_shutter_mat = _mat(SHUTTER, 0.85)
	_wood_mat = _mat(WOOD, 0.85)
	var dev_args: Dictionary = App.parse_user_args(OS.get_cmdline_user_args())
	# 開發用：`-- --level=daylight` 直接進來 → 照正式流程走到進城（段落 6 結束）
	if not (Game.session.quests.stage_of(QUEST) in STAGES):
		dev_start_daylight(Game.session)
	# 截圖用：`--daylight-at=stele` 看完爐子、站在第一塊石碑前（瑪菈換水之前）
	var at: String = str(dev_args.get("daylight-at", ""))
	if at in ["stele", "home"]:
		Game.session.state.set_flag("ch1.daylight_intro", true)
		Game.session.set_flag("ch1.saw_empty_furnace", true)
		Game.session.state.set_flag("ch1.furnace_talked", true)
	if at == "home":
		Game.session.set_flag("ch1.saw_stele_trade", true)
		Game.session.state.set_flag("ch1.mara_traded", true)
		Game.session.set_flag(Residents.FLAG_PREFIX + TRADE_RESIDENT, residents.days_left(Game.session.state, TRADE_RESIDENT) - 1)
	_build_environment()
	_build_ground_and_dome()
	_build_square()
	_build_street()
	_build_steles()
	_init_story()
	_place_player(at)
	_set_up_lamp()
	_build_people()
	_hide_contact_shadows.call_deferred()
	Game.dialogue_started.connect(_on_dialogue_started)
	Game.dialogue_ended.connect(_on_dialogue_ended)
	add_to_group("interact_prompts")


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
	elif at == "home":
		p = KORD_HOME + Vector3(2.4, 0.0, 4.5)
		yaw = deg_to_rad(28.0)
	player.global_position = p + Vector3(0, 0.05, 0)
	player.rotation.y = yaw
	if player is PlayerController:
		(player as PlayerController).yaw = yaw
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
	if at_home and not _home_inside and stage == "kord_home":
		_banner("CH1_TO_BE_CONTINUED", 6.0)
	_home_inside = at_home
	if Input.is_action_just_pressed("interact") and nearest_stele() != "":
		touch_stele()


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
	_solid("Ground", Vector3(span_x, 0.4, z1 - z0), Vector3(0, -0.2, mid_z), _mat(PAVING, 0.95))
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
	_solid("GateDark", Vector3(1.2, 2.2, 0.1), Vector3(0, 1.1, GATE_Z + 0.55), _mat(Color(0.02, 0.02, 0.02), 1.0))
	# 東西兩側的牆
	_solid("SquareWallW", Vector3(0.6, 7.0, depth), Vector3(-SQUARE_HALF - 0.3, 3.5, mid_z), _plaster_mat)
	_solid("SquareWallE", Vector3(0.6, 7.0, depth), Vector3(SQUARE_HALF + 0.3, 3.5, mid_z), _plaster_mat)
	# 門房（西邊，開口朝東）：桌子、兩個孩子、空碗
	var gx: float = -SQUARE_HALF + 2.0
	_solid("GatehouseN", Vector3(4.0, 3.0, 0.3), Vector3(gx, 1.5, 14.6), _stone_mat)
	_solid("GatehouseRoof", Vector3(4.0, 0.3, 5.6), Vector3(gx, 3.1, 17.25), _stone_mat, false)
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
	var furnace_body := StaticBody3D.new()
	var fcs := CollisionShape3D.new()
	var fshape := CylinderShape3D.new()
	fshape.radius = 1.15
	fshape.height = 2.7
	fcs.shape = fshape
	fcs.position = Vector3(0, 1.35, 0)
	furnace_body.add_child(fcs)
	furnace.add_child(furnace_body)
	# 晾衣繩：煙管 → 東牆，小孩的衣服
	var rope_from := FURNACE_POS + Vector3(0.0, 2.75, 0.0)
	var rope_to := Vector3(SQUARE_HALF, 2.6, FURNACE_POS.z + 2.4)
	var rope := MeshInstance3D.new()
	rope.name = "Clothesline"
	var rm := BoxMesh.new()
	rm.size = Vector3(0.015, 0.015, rope_from.distance_to(rope_to))
	rope.mesh = rm
	rope.material_override = _mat(Color(0.5, 0.46, 0.38), 1.0)
	add_child(rope)
	rope.transform = Transform3D(Basis.looking_at(rope_to - rope_from, Vector3.UP), (rope_from + rope_to) * 0.5)
	var cloth_colors: Array[Color] = [Color(0.62, 0.5, 0.42), Color(0.48, 0.55, 0.6), Color(0.7, 0.66, 0.58), Color(0.55, 0.42, 0.45)]
	for c: int in cloth_colors.size():
		var t: float = (float(c) + 1.0) / float(cloth_colors.size() + 1)
		var at: Vector3 = rope_from.lerp(rope_to, t)
		var cloth := MeshInstance3D.new()
		cloth.name = "Laundry%d" % c
		var cm := BoxMesh.new()
		cm.size = Vector3(0.02, 0.42 + 0.08 * float(c % 2), 0.34)
		cloth.mesh = cm
		cloth.material_override = _mat(cloth_colors[c], 1.0)
		add_child(cloth)
		cloth.transform = Transform3D(Basis.looking_at(rope_to - rope_from, Vector3.UP), at - Vector3(0, cm.size.y * 0.5, 0))
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
	_solid("BellYardGate", Vector3(2.6, 3.6, 0.2), Vector3(0, 1.8, END_Z + 0.05), _wood_mat, false)


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
	_solid("HouseBase", Vector3(depth + 0.16, 0.9, length), Vector3(cx, 0.45, cz), _stone_mat, false)
	var face_x: float = float(side) * (STREET_HALF - 0.04)
	# 門（柯德家的門正對 KORD_HOME）
	var door_z: float = KORD_HOME.z if is_kord else cz + _rng.randf_range(-length * 0.25, length * 0.25)
	_solid("HouseDoor", Vector3(0.1, 2.1, 1.0), Vector3(face_x, 1.05, door_z), _wood_mat, false)
	# 窗：每層幾扇，全部關著（灰藍的木窗板）
	var floors: int = int((height - 1.4) / 2.3)
	var per_floor: int = maxi(int(length / 2.2), 1)
	for f: int in floors:
		for w: int in per_floor:
			var wz: float = z_start - (float(w) + 0.5) * length / float(per_floor)
			if f == 0 and absf(wz - door_z) < 1.0:
				continue
			_solid("Shutter", Vector3(0.08, 1.1, 0.8), Vector3(face_x, 1.9 + float(f) * 2.3 + 0.55, wz), _shutter_mat, false)
	if is_kord:
		var m := Marker3D.new()
		m.name = "KordHome"
		m.position = KORD_HOME + Vector3(0, 1.0, 0)
		add_child(m)


## 壽命石碑：黑色抛光石，正面浮著名字與「還能活 N 天」（Label3D、子集字型、翻譯 key）。
func _build_steles() -> void:
	var black := _mat(Color(0.025, 0.025, 0.03), 0.12)
	black.metallic = 0.35
	var font: Font = UiFonts.load_font(UiFonts.UI_SANS)
	for id: String in STELES.keys():
		var pos: Vector3 = STELES[id] as Vector3
		var stele := _solid("Stele_" + id, Vector3(1.0, 2.3, 0.32), pos + Vector3(0, 1.15, 0), black)
		stele.set_meta("stele_id", id)
		_solid("SteleBase", Vector3(1.3, 0.2, 0.6), pos + Vector3(0, 0.1, 0), _stone_mat, false)
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


func refresh_steles() -> void:
	for id: String in _labels.keys():
		var lines: PackedStringArray = []
		for rid: String in residents.residents_on(id):
			lines.append(residents.line(Game.session.state, rid))
		(_labels[id] as Label3D).text = "\n".join(lines)


func stele_text(id: String) -> String:
	return (_labels[id] as Label3D).text if _labels.has(id) else ""
