extends StoryLevel
## 第 1 章段落 1～3：霜橋鎮酒館（白盒，D-149；美術在階段 2 後段，07-chapter1-door.md）。
## 隔天中午傷者安置在這裡 → 入夜跟席菈、彌夏吃飯（左手灑湯）→ 把攻略畫成地圖 → 出門去地窖（換到白天的霜橋鎮，D-151）。
## 劇情觸發照霜橋鎮的席菈：依任務階段輪詢諾恩離「說話點」多近，到了就開對話；每個對話的每條路線最後都設那個階段的完成旗標。
##
## 房間：南北 10 m（z -5～5）、東西 14 m（x -7～7），門在南牆正中；諾恩從門口往北走進來。

const QUEST: String = "ch1_main"
const ROOM_HALF: Vector2 = Vector2(7.0, 5.0)
const WALL_H: float = 3.4
const WALL_T: float = 0.3
## 說話點的半徑（諾恩走到這麼近就開對話）
const TALK_RANGE: float = 1.9
## 階段 -> [說話點節點名, 對話 id]
const STAGE_TALKS: Dictionary = {
	"tavern_noon": ["Sheila", "ch1_noon"],
	"dinner": ["DinnerTable", "ch1_dinner"],
	"draw_map": ["MapTable", "ch1_map"],
}
const SPAWN_POS: Vector3 = Vector3(0.0, 0.05, 2.8)
const DOOR_POS: Vector3 = Vector3(0.0, 0.0, 4.6)

const FLOOR: Color = Color(0.32, 0.24, 0.17)
const WALL: Color = Color(0.46, 0.4, 0.33)
const BEAM: Color = Color(0.2, 0.14, 0.1)
const TABLE: Color = Color(0.36, 0.25, 0.16)
const HEARTH: Color = Color(1.0, 0.62, 0.32)

var _door_inside: bool = false
var _leaving: bool = false
var _hearth_light: OmniLight3D
var _window_light: OmniLight3D
var _window_mat: StandardMaterial3D


func _ready() -> void:
	_rng.seed = 31
	_build_environment()
	_build_room()
	_build_furniture()
	_build_people()
	_init_story()
	# 開發用：`-- --level=tavern` 直接進來時還在切片 → 把切片走完、開始第 1 章；
	# `--ch1-stage=dinner|draw_map|to_cellar` 再往後推（截圖用）
	var dev_args: Dictionary = App.parse_user_args(OS.get_cmdline_user_args())
	if not Game.session.state.quests.has(QUEST):
		dev_start_chapter(Game.session, str(dev_args.get("ch1-stage", "")))
	# 截圖用：`--ch1-stage=draw_map --guide-mark` 直接打開標記畫面（射箭陷阱先標我不確定）
	if dev_args.has("guide-mark") and Game.session.quests.stage_of(QUEST) == "draw_map":
		GuideNotes.set_unsure(Game.session.state, "stair_arrows", true)
		Game.session.state.set_flag("ch1.guide_marking", true)
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player != null:
		player.global_position = SPAWN_POS
		player.rotation.y = 0.0
	_apply_time_of_day()
	Game.session.stage_changed.connect(_on_stage_changed)


## 開發用：照正式流程設旗標，把切片走完（第 1 章跟著開始），再推到 stage（空字串＝第 1 章開頭）。
static func dev_start_chapter(s: GameSession, stage: String) -> void:
	# 跳著設旗標不算成就（不然截圖右上角會跳出切片的成就小卡）
	var ach: AchievementTracker = s.achievements
	s.achievements = null
	if not s.is_slice_complete():
		StoryLevel.dev_advance_to_convoy(s)
		s.set_flag("slice.convoy_through", true)
		s.set_flag("slice.ada_talked_aftermath", true)
		s.set_flag("slice.cellar_entered", true)
	var order: PackedStringArray = ["tavern_noon", "dinner", "draw_map", "to_cellar"]
	var flags: PackedStringArray = ["ch1.noon_talked", "ch1.dinner_done", "ch1.map_drawn"]
	var target: int = order.find(stage)
	for i: int in maxi(target, 0):
		s.set_flag(flags[i], true)
	# 畫地圖的對話一開始就寫下攻略筆記
	if target >= 2:
		StoryLogic.apply({"guide_write": Array(s.guide.remembered_ids())}, s.state)
	s.attach_achievements(ach)


func _physics_process(_delta: float) -> void:
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player == null:
		return
	var stage: String = Game.session.quests.stage_of(QUEST)
	var marking: bool = bool(Game.session.state.get_flag("ch1.guide_marking", false))
	# 畫地圖的對話講完（等著標記）之後不要再從頭講一次
	if STAGE_TALKS.has(stage) and not (stage == "draw_map" and marking) and not Game.is_player_locked():
		var spot: Array = STAGE_TALKS[stage] as Array
		var n: Node3D = get_node_or_null(str(spot[0])) as Node3D
		if n != null and _flat_dist(player.global_position, n.global_position) <= TALK_RANGE:
			Game.start_dialogue(str(spot[1]))
	# 段落 3：席菈說「把你不確定的地方也標出來」之後打開標記畫面（D-150）
	if stage == "draw_map" and marking and not has_node("GuideMarkView") and not Game.is_player_locked():
		open_guide_marking()
	# 出門 → 段落 4：白天的霜橋鎮（D-151）。旗標推進到 day_north（檢查點 ch1_day_town、自動存檔），再換關卡
	var at_door: bool = _flat_dist(player.global_position, DOOR_POS) <= 1.2
	if at_door and not _door_inside and stage == "to_cellar" and not Game.is_player_locked():
		leave_tavern()
	_door_inside = at_door


## 走出酒館門（測試也用）：設 ch1.left_tavern，換到檢查點對應的關卡（白天的霜橋鎮）。
func leave_tavern() -> void:
	if _leaving:
		return
	_leaving = true
	Game.session.set_flag("ch1.left_tavern", true)
	Game.go_to_level.call_deferred(Game.level_for_checkpoint(Game.session.state.checkpoint))


## 標記畫面（測試也用）：已經開著就回傳那一個。
func open_guide_marking() -> GuideMarkView:
	var existing: GuideMarkView = get_node_or_null("GuideMarkView") as GuideMarkView
	if existing != null:
		return existing
	var view: GuideMarkView = GuideMarkView.open_on(self, Game.session.state, Game.session.guide)
	view.confirmed.connect(_on_guide_marked)
	return view


func _on_guide_marked(_unsure: PackedStringArray) -> void:
	Game.start_dialogue("ch1_map_end")


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## 說話點：任務目前階段要走去的地方（測試用）。沒有就回傳 null。
func talk_spot() -> Node3D:
	var stage: String = Game.session.quests.stage_of(QUEST)
	if not STAGE_TALKS.has(stage):
		return null
	return get_node_or_null(str((STAGE_TALKS[stage] as Array)[0])) as Node3D


func _on_stage_changed(quest_id: String, _from: String, _to: String) -> void:
	if quest_id == QUEST:
		_apply_time_of_day()


## 中午：窗外的冷白光；入夜（晚餐之後）：窗外暗藍、壁爐變成主光。
func is_night() -> bool:
	var stage: String = Game.session.quests.stage_of(QUEST)
	return stage != "tavern_noon" and stage != ""


func _apply_time_of_day() -> void:
	var night: bool = is_night()
	if _window_light != null:
		_window_light.light_color = Color(0.36, 0.44, 0.62) if night else Color(0.86, 0.9, 1.0)
		_window_light.light_energy = 0.5 if night else 2.2
	if _hearth_light != null:
		_hearth_light.light_energy = 3.2 if night else 1.6
	# 窗玻璃：中午是外面的雪光（自己發亮），入夜只剩一點暗藍
	if _window_mat != null:
		_window_mat.albedo_color = Color(0.06, 0.08, 0.13) if night else Color(0.75, 0.82, 0.95)
		_window_mat.emission = Color(0.05, 0.07, 0.14) if night else Color(0.8, 0.86, 1.0)
		_window_mat.emission_energy_multiplier = 0.4 if night else 1.6


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.36, 0.3)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.2
	env.ssao_enabled = true
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.8, 0.7, 0.6)
	env.volumetric_fog_length = 24.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)


func _box(node_name: String, size: Vector3, pos: Vector3, color: Color, collide: bool = true) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.name = node_name
	b.size = size
	b.position = pos
	b.use_collision = collide
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	b.material = m
	add_child(b)
	return b


func _build_room() -> void:
	var w: float = ROOM_HALF.x
	var d: float = ROOM_HALF.y
	_box("Floor", Vector3(w * 2.0 + 1.0, 0.2, d * 2.0 + 1.0), Vector3(0, -0.1, 0), FLOOR)
	_box("Ceiling", Vector3(w * 2.0 + 1.0, 0.2, d * 2.0 + 1.0), Vector3(0, WALL_H + 0.1, 0), BEAM, false)
	_box("WallN", Vector3(w * 2.0, WALL_H, WALL_T), Vector3(0, WALL_H * 0.5, -d), WALL)
	_box("WallW", Vector3(WALL_T, WALL_H, d * 2.0), Vector3(-w, WALL_H * 0.5, 0), WALL)
	_box("WallE", Vector3(WALL_T, WALL_H, d * 2.0), Vector3(w, WALL_H * 0.5, 0), WALL)
	# 南牆中間留門（1.6 m 寬、2.3 m 高）
	var side: float = (w * 2.0 - 1.6) * 0.5
	_box("WallS_W", Vector3(side, WALL_H, WALL_T), Vector3(-(0.8 + side * 0.5), WALL_H * 0.5, d), WALL)
	_box("WallS_E", Vector3(side, WALL_H, WALL_T), Vector3(0.8 + side * 0.5, WALL_H * 0.5, d), WALL)
	_box("WallS_Top", Vector3(1.6, WALL_H - 2.3, WALL_T), Vector3(0, 2.3 + (WALL_H - 2.3) * 0.5, d), WALL)
	_box("TavernDoorLeaf", Vector3(1.5, 2.25, 0.08), Vector3(0, 1.125, d + 0.12), BEAM)
	var door := Marker3D.new()
	door.name = "TavernDoor"
	door.position = DOOR_POS + Vector3(0, 1.0, 0)
	add_child(door)
	# 橫樑
	for i: int in 4:
		_box("Beam%d" % i, Vector3(w * 2.0, 0.22, 0.26), Vector3(0, WALL_H - 0.15, -3.6 + i * 2.4), BEAM, false)
	# 東牆的窗（中午的光從這裡進來）
	var window := _box("Window", Vector3(0.06, 1.1, 1.6), Vector3(w - 0.14, 1.7, -1.0), Color(0.75, 0.82, 0.95), false)
	_window_mat = window.material as StandardMaterial3D
	_window_mat.emission_enabled = true
	_window_light = OmniLight3D.new()
	_window_light.name = "WindowLight"
	_window_light.position = Vector3(w - 1.0, 1.9, -1.0)
	_window_light.omni_range = 8.0
	_window_light.shadow_enabled = true
	add_child(_window_light)
	# 西北角的壁爐（第 52 輪：原本是一塊發光的長方形 → 石砌爐框＋凹進去的爐膛＋柴＋火焰與火星粒子＋會閃的火光）
	_build_hearth(Vector3(-4.6, 0.0, -d + 0.45))
	_hearth_light = OmniLight3D.new()
	_hearth_light.name = "HearthLight"
	_hearth_light.light_color = HEARTH
	_hearth_light.position = Vector3(-4.6, 1.0, -d + 1.4)
	_hearth_light.omni_range = 9.0
	_hearth_light.shadow_enabled = true
	add_child(_hearth_light)
	# 吧台上方的油燈
	var lamp := OmniLight3D.new()
	lamp.name = "CounterLamp"
	lamp.light_color = Color(1.0, 0.74, 0.46)
	lamp.light_energy = 1.4
	lamp.omni_range = 6.0
	lamp.position = Vector3(4.2, 2.4, -2.6)
	add_child(lamp)


## 壁爐（爐框中心在 base，背靠北牆、開口朝 +Z）：左右兩柱＋上面的爐楣＋爐台，中間凹進去的黑爐膛，
## 兩根交叉的柴＋底下一層發亮的炭，火焰（加法混色、往上縮小變紅）與零星火星。
const HEARTH_OPENING: Vector2 = Vector2(1.1, 0.8)
var hearth_flames: CPUParticles3D
var hearth_sparks: CPUParticles3D
var _flicker_t: float = 0.0


func _build_hearth(base: Vector3) -> void:
	var stone := Color(0.3, 0.28, 0.26)
	var ow: float = HEARTH_OPENING.x
	var oh: float = HEARTH_OPENING.y
	var side: float = (2.2 - ow) * 0.5
	for sx: float in [-1.0, 1.0]:
		_box("HearthJamb", Vector3(side, oh, 0.8), base + Vector3(sx * (ow + side) * 0.5, oh * 0.5, 0), stone)
	_box("Hearth", Vector3(2.2, 1.4 - oh, 0.8), base + Vector3(0, oh + (1.4 - oh) * 0.5, 0), stone)
	# 爐台（突出一點的石板）與上面的木頭壁架
	_box("HearthMantel", Vector3(2.5, 0.12, 0.3), base + Vector3(0, 1.46, 0.3), BEAM, false)
	_box("HearthStep", Vector3(2.4, 0.06, 0.5), base + Vector3(0, 0.03, 0.62), Color(0.26, 0.24, 0.22), false)
	# 爐膛：燻黑的內壁（比外框凹 0.55 m）
	_box("HearthBack", Vector3(ow, oh, 0.12), base + Vector3(0, oh * 0.5, -0.32), Color(0.05, 0.04, 0.035), false)
	_box("HearthFloor", Vector3(ow, 0.04, 0.7), base + Vector3(0, 0.02, 0.0), Color(0.08, 0.06, 0.05), false)
	# 炭床：發亮的一層
	var embers := _box("HearthFire", Vector3(ow * 0.8, 0.06, 0.45), base + Vector3(0, 0.07, 0.02), HEARTH, false)
	var em := embers.material as StandardMaterial3D
	em.albedo_color = Color(0.25, 0.08, 0.03)
	em.emission_enabled = true
	em.emission = Color(1.0, 0.35, 0.08)
	em.emission_energy_multiplier = 2.4
	# 兩根柴交叉擱在炭上
	var log_mat := StandardMaterial3D.new()
	log_mat.albedo_color = Color(0.16, 0.1, 0.07)
	log_mat.roughness = 0.95
	log_mat.emission_enabled = true
	log_mat.emission = Color(0.9, 0.3, 0.06)
	log_mat.emission_energy_multiplier = 0.35
	for i: int in 2:
		var lg := MeshInstance3D.new()
		lg.name = "HearthLog%d" % i
		var cm := CylinderMesh.new()
		cm.top_radius = 0.07
		cm.bottom_radius = 0.08
		cm.height = 0.8
		lg.mesh = cm
		lg.material_override = log_mat
		lg.position = base + Vector3(0, 0.16 + i * 0.07, 0.02)
		lg.rotation = Vector3(0.0, (0.35 if i == 0 else -0.35), PI * 0.5)
		add_child(lg)
	# 火焰：加法混色的柔點，往上飄、變小、由黃轉紅
	hearth_flames = CPUParticles3D.new()
	hearth_flames.name = "HearthFlames"
	hearth_flames.amount = 40
	hearth_flames.lifetime = 0.7
	hearth_flames.position = base + Vector3(0, 0.2, 0.05)
	hearth_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	hearth_flames.emission_box_extents = Vector3(ow * 0.32, 0.03, 0.12)
	hearth_flames.direction = Vector3.UP
	hearth_flames.spread = 8.0
	hearth_flames.gravity = Vector3(0, 0.6, 0)
	hearth_flames.initial_velocity_min = 0.35
	hearth_flames.initial_velocity_max = 0.7
	hearth_flames.scale_amount_min = 0.7
	hearth_flames.scale_amount_max = 1.2
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 0.6))
	shrink.add_point(Vector2(0.25, 1.0))
	shrink.add_point(Vector2(1.0, 0.1))
	hearth_flames.scale_amount_curve = shrink
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.45, 0.9))
	ramp.set_color(1, Color(0.9, 0.2, 0.04, 0.0))
	ramp.add_point(0.45, Color(1.0, 0.5, 0.12, 0.7))
	hearth_flames.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.26, 0.34)
	quad.material = ParticleLook.material(Color.WHITE, true)
	hearth_flames.mesh = quad
	add_child(hearth_flames)
	# 火星：偶爾一顆往上竄
	hearth_sparks = CPUParticles3D.new()
	hearth_sparks.name = "HearthSparks"
	hearth_sparks.amount = 6
	hearth_sparks.lifetime = 1.4
	hearth_sparks.position = base + Vector3(0, 0.3, 0.05)
	hearth_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	hearth_sparks.emission_box_extents = Vector3(ow * 0.3, 0.05, 0.1)
	hearth_sparks.direction = Vector3.UP
	hearth_sparks.spread = 20.0
	hearth_sparks.gravity = Vector3(0, 0.2, 0)
	hearth_sparks.initial_velocity_min = 0.6
	hearth_sparks.initial_velocity_max = 1.1
	var spark_ramp := Gradient.new()
	spark_ramp.set_color(0, Color(1.0, 0.75, 0.35, 1.0))
	spark_ramp.set_color(1, Color(1.0, 0.3, 0.05, 0.0))
	hearth_sparks.color_ramp = spark_ramp
	var sq := QuadMesh.new()
	sq.size = Vector2(0.03, 0.03)
	sq.material = ParticleLook.material(Color.WHITE, true)
	hearth_sparks.mesh = sq
	add_child(hearth_sparks)


## 火光閃動：兩個不同頻率的正弦疊起來＋一點高頻，亮度在 ±12% 內晃（照在牆上與人身上才像火）。
static func hearth_flicker(t: float) -> float:
	return 1.0 + 0.07 * sin(t * 7.3) + 0.04 * sin(t * 13.1 + 1.7) + 0.02 * sin(t * 29.0 + 0.4)


func _process(delta: float) -> void:
	if _hearth_light == null:
		return
	_flicker_t += delta
	var base_energy: float = 3.2 if is_night() else 1.6
	_hearth_light.light_energy = base_energy * hearth_flicker(_flicker_t)


func _table(node_name: String, pos: Vector3, size: Vector2) -> Node3D:
	var t := _box(node_name, Vector3(size.x, 0.08, size.y), pos + Vector3(0, 0.76, 0), TABLE)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box(node_name + "Leg", Vector3(0.08, 0.72, 0.08),
				pos + Vector3(sx * (size.x * 0.5 - 0.1), 0.36, sz * (size.y * 0.5 - 0.1)), TABLE, false)
	return t


func _build_furniture() -> void:
	# 吧台（東北）
	_box("Counter", Vector3(0.7, 1.1, 3.6), Vector3(4.6, 0.55, -2.6), TABLE)
	# 晚餐的桌子（正中偏北）、畫地圖的小桌（東南）
	_table("DinnerTable", Vector3(-0.6, 0.0, -2.2), Vector2(2.2, 1.1))
	_table("MapTable", Vector3(3.4, 0.0, 2.2), Vector2(1.2, 0.9))
	# 地圖：一張紙
	_box("MapSheet", Vector3(0.7, 0.01, 0.5), Vector3(3.4, 0.81, 2.2), Color(0.86, 0.8, 0.66), false)
	# 西側安置傷者的長椅
	for i: int in 3:
		_box("Cot%d" % i, Vector3(0.8, 0.42, 2.0), Vector3(-5.8, 0.21, -1.6 + i * 2.4), Color(0.4, 0.34, 0.28))


func _puppet(node_name: String, pos: Vector3, yaw_deg: float, coat: Color, trim: Color, lying: String = "") -> Puppet:
	var p := Puppet.new()
	p.name = node_name
	p.coat_color = coat
	p.trim_color = trim
	p.lying = lying
	p.position = pos
	p.rotation_degrees.y = yaw_deg
	add_child(p)
	# 程序人偶預設右手拿鐘錘（諾恩的）；酒館裡的人不拿
	var hammer: Node = p.hand("R").get_node_or_null("BellHammer") if p.hand("R") != null else null
	if hammer != null:
		hammer.queue_free()
	return p


func _build_people() -> void:
	# 席菈：白短斗篷、灰藍滾邊（照 Sheila 的配色）；坐在傷者旁邊
	_puppet("Sheila", Vector3(-3.6, 0.0, 0.4), 90.0, Color(0.74, 0.74, 0.76), Color(0.36, 0.42, 0.5))
	# 彌夏：墨綠過長外衣，抱著沒有指針的鐘（先用小木箱代替）
	_puppet("Misha", Vector3(-1.8, 0.0, -1.2), 160.0, Color(0.16, 0.27, 0.21), Color(0.3, 0.26, 0.2))
	_box("ClocklessClock", Vector3(0.32, 0.36, 0.22), Vector3(-1.2, 0.98, -2.2), Color(0.42, 0.32, 0.2), false)
	# 酒館老闆：吧台後面
	_puppet("Keeper", Vector3(5.4, 0.0, -2.4), -90.0, Color(0.3, 0.22, 0.16), Color(0.5, 0.44, 0.36))
	# 傷者：躺在長椅上（仰躺，頭朝 +Z）
	for i: int in 2:
		_puppet("Wounded%d" % i, Vector3(-5.8, 0.62, -2.4 + i * 2.4), 0.0, Color(0.24, 0.24, 0.26), Color(0.5, 0.2, 0.18), "back")
