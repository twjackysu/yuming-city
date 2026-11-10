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
## 室內材質（第 53 輪，D-171）：木板 plank_wood.gdshader（世界座標）、牆 half_timber.gdshader 的室內版
const PLANK_SHADER: String = "res://src/world/plank_wood.gdshader"
const PLASTER: Color = Color(0.56, 0.5, 0.42)
const WALL_STONE: Color = Color(0.34, 0.31, 0.28)
## 室內牆：牆腳石塊的高度、木框的層高與立柱間距（第一道橫樑在石塊上面，第二道貼著天花板）
const DADO_H: float = 0.95
const TIMBER_FLOOR_H: float = 2.4
const POST_SPACING: float = 1.6
## 門口的雪水（地板 wet_spot：中心 xz、半徑、強度）
const DOOR_WET: Vector4 = Vector4(0.0, 4.4, 1.7, 0.85)
## 東牆的窗：玻璃中心、玻璃大小（高、寬）
const WINDOW_CENTER: Vector3 = Vector3(6.86, 1.7, -1.0)
const WINDOW_SIZE: Vector2 = Vector2(1.1, 1.6)
const FROST_WINDOW_SHADER: String = "res://src/world/frost_window.gdshader"
## 中午從窗外斜照進來的光束（D-177）：東北方、窗外 SUN_DISTANCE 的聚光燈（放遠＝光線接近平行，像太陽），穿過窗洞
## （東牆拆成窗的上下左右四塊）、從吧台南端旁邊斜斜落到地圖桌那一帶（SUN_TARGET）；窗櫺的十字影子落在光斑裡。入夜換成很淡的藍。
const SUN_TARGET: Vector3 = Vector3(3.4, 0.0, 1.3)
const SUN_DISTANCE: float = 7.0
const SUN_ANGLE_DEG: float = 12.0
const SUN_NOON: Color = Color(1.0, 0.95, 0.86)
const SUN_NOON_ENERGY: float = 40.0
const SUN_NIGHT: Color = Color(0.42, 0.52, 0.78)
const SUN_NIGHT_ENERGY: float = 4.5
## 晚餐桌上的蠟燭（入夜才點）
const CANDLE_POS: Vector3 = Vector3(-0.5, 0.8, -2.25)
## 聲音（D-180）：壁爐的柴火從爐膛發出來（走近變大聲），牆外悶悶的風雪整片鋪著；入夜火燒得旺、風也大一點。
const HEARTH_SOUND_POS: Vector3 = Vector3(-4.6, 0.4, -4.3)
const HEARTH_DB_NOON: float = -10.0
const HEARTH_DB_NIGHT: float = -5.0
const WIND_INDOOR_DB_NOON: float = -26.0
const WIND_INDOOR_DB_NIGHT: float = -21.0

var _door_inside: bool = false
var _leaving: bool = false
var _hearth_light: OmniLight3D
var _window_light: OmniLight3D
var _sun_beam: SpotLight3D
var _window_mat: ShaderMaterial
var _look := InteriorLook.new()
var _candle_light: OmniLight3D
var _candle_flame: MeshInstance3D
var _dev_face: String = ""
var _dev_face_off: float = 0.0
var hearth_sound: AudioStreamPlayer3D
var wind_sound: AudioStreamPlayer


func _ready() -> void:
	_rng.seed = 31
	_build_environment()
	_build_room()
	_build_furniture()
	_build_people()
	hearth_sound = Ambience.play_at(self, "hearth_crackle", HEARTH_SOUND_POS, HEARTH_DB_NOON, 3.0, "HearthCrackle")
	wind_sound = Ambience.play(self, "frost_wind_indoor", WIND_INDOOR_DB_NOON, "Ambience")
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
	# 截圖用（第 53 輪）：`--pos=x,z` 把諾恩移到這裡；`--face=<節點名>`（DinnerTable、Hearth、Counter、BackShelf0、
	# WindowSill、Cot2…）諾恩與鏡頭每幀轉向那個節點；`--face-off=度` 再往左轉（目標落到畫面右側）
	if dev_args.has("pos"):
		dev_place_player(str(dev_args["pos"]))
	if dev_args.has("face"):
		_dev_face = str(dev_args["face"])
		_dev_face_off = float(str(dev_args.get("face-off", "0")))
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
	if _dev_face != "":
		_update_dev_face()
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


## 截圖用：諾恩移到 spec（"x,z"）。格式不對回傳 false。
func dev_place_player(spec: String) -> bool:
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	var xz: PackedStringArray = spec.split(",")
	if player == null or xz.size() != 2 or not xz[0].is_valid_float() or not xz[1].is_valid_float():
		return false
	player.global_position = Vector3(float(xz[0]), 0.05, float(xz[1]))
	player.snap_camera()
	return true


## 諾恩面向 `--face` 的節點（只轉水平角度），鏡頭跟著轉到他正後方。
func _update_dev_face() -> void:
	var target: Node3D = get_node_or_null(_dev_face) as Node3D
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	if target == null or player == null:
		return
	var d: Vector3 = target.global_position - player.global_position
	d.y = 0.0
	if d.length() < 0.3:
		return
	player.rotation.y = atan2(-d.x, -d.z) + deg_to_rad(_dev_face_off)
	player.yaw = player.rotation.y
	player.snap_camera()


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


## 蠟燭點著沒有（測試用）：入夜才點。
func candle_lit() -> bool:
	return _candle_light != null and _candle_light.visible and _candle_flame.visible


## 說話點：任務目前階段要走去的地方（測試用）。沒有就回傳 null。
func talk_spot() -> Node3D:
	var stage: String = Game.session.quests.stage_of(QUEST)
	if not STAGE_TALKS.has(stage):
		return null
	return get_node_or_null(str((STAGE_TALKS[stage] as Array)[0])) as Node3D


func _on_stage_changed(quest_id: String, _from: String, _to: String) -> void:
	if quest_id == QUEST:
		_apply_time_of_day()


## 腳步聲（D-182）：木板地。
func footstep_surface(_p: Vector3) -> String:
	return "wood"


## 中午：窗外的冷白光；入夜（晚餐之後）：窗外暗藍、壁爐變成主光。
func is_night() -> bool:
	var stage: String = Game.session.quests.stage_of(QUEST)
	return stage != "tavern_noon" and stage != ""


func _apply_time_of_day() -> void:
	var night: bool = is_night()
	if _window_light != null:
		_window_light.light_color = Color(0.36, 0.44, 0.62) if night else Color(0.86, 0.9, 1.0)
		_window_light.light_energy = 0.5 if night else 1.8
	if _sun_beam != null:
		_sun_beam.light_color = SUN_NIGHT if night else SUN_NOON
		_sun_beam.light_energy = SUN_NIGHT_ENERGY if night else SUN_NOON_ENERGY
	if _hearth_light != null:
		_hearth_light.light_energy = 3.2 if night else 1.6
	if hearth_sound != null:
		hearth_sound.volume_db = HEARTH_DB_NIGHT if night else HEARTH_DB_NOON
	if wind_sound != null:
		wind_sound.volume_db = WIND_INDOOR_DB_NIGHT if night else WIND_INDOOR_DB_NOON
	# 窗玻璃（D-186）：中午是霜後面亮亮的陰天與雪地，入夜只剩暗藍＋對街一扇點著燈的窗
	if _window_mat != null:
		_window_mat.set_shader_parameter("noon", 0.0 if night else 1.0)
	# 晚餐桌上的蠟燭：入夜才點
	if _candle_light != null:
		_candle_light.visible = night
		_candle_flame.visible = night


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


func _box(node_name: String, size: Vector3, pos: Vector3, color: Color, collide: bool = true, mat: Material = null) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.name = node_name
	b.size = size
	b.position = pos
	b.use_collision = collide
	if mat != null:
		b.material = mat
	else:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		b.material = m
	add_child(b)
	return b


## 不擋人的小東西（碗、瓶子、燭台）：MeshInstance3D，比 CSG 便宜。
func _prop(node_name: String, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi


static func _cyl(top_r: float, bottom_r: float, h: float, segments: int = 16) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bottom_r
	cm.height = h
	cm.radial_segments = segments
	cm.rings = 1
	return cm


## 室內木板（InteriorLook.plank，plank_wood.gdshader）：同一個 key 共用一個材質。
func plank(key: String, color: Color, width: float, length: float, opts: Dictionary = {}) -> ShaderMaterial:
	return _look.plank(key, color, width, length, opts)


## 室內牆（half_timber.gdshader，exterior 0）：牆腳一圈石塊、上面灰泥＋深色木框，天花板下燻黑。
## stone_h 設大＝整面石頭（壁爐）。
func interior_wall(key: String, stone_h: float, block_scale: float, soot: float, soot_top: float, soot_depth: float) -> ShaderMaterial:
	return _look.wall(key, PLASTER, WALL_STONE, stone_h, {
		"floor_height": TIMBER_FLOOR_H, "post_spacing": POST_SPACING, "block_scale": block_scale,
		"soot": soot, "soot_top": soot_top, "soot_depth": soot_depth,
	})


func wall_mat() -> ShaderMaterial:
	return interior_wall("wall", DADO_H, 0.8, 0.5, WALL_H, 1.3)


func floor_mat() -> ShaderMaterial:
	return plank("floor", Color(0.3, 0.215, 0.15), 0.19, 2.8, {"wear": 0.85, "wet_spot": DOOR_WET, "seam_dark": 0.75})


func table_mat() -> ShaderMaterial:
	return plank("table", Color(0.36, 0.25, 0.16), 0.24, 3.0, {"base_roughness": 0.58, "seam_dark": 0.6})


## 整根木頭（橫樑、桌腳、框）：板寬拉大＝沒有板縫、只有木紋
func timber_mat() -> ShaderMaterial:
	return _look.timber(Color(0.17, 0.12, 0.085))


func _build_room() -> void:
	var w: float = ROOM_HALF.x
	var d: float = ROOM_HALF.y
	_box("Floor", Vector3(w * 2.0 + 1.0, 0.2, d * 2.0 + 1.0), Vector3(0, -0.1, 0), FLOOR, true, floor_mat())
	# 天花板：橫樑之間的木板（沿南北，橫過橫樑）
	var ceiling := plank("ceiling", Color(0.2, 0.15, 0.11), 0.16, 3.2, {"along_z": true, "seam_dark": 0.8})
	_box("Ceiling", Vector3(w * 2.0 + 1.0, 0.2, d * 2.0 + 1.0), Vector3(0, WALL_H + 0.1, 0), BEAM, false, ceiling)
	var wall := wall_mat()
	_box("WallN", Vector3(w * 2.0, WALL_H, WALL_T), Vector3(0, WALL_H * 0.5, -d), WALL, true, wall)
	_box("WallW", Vector3(WALL_T, WALL_H, d * 2.0), Vector3(-w, WALL_H * 0.5, 0), WALL, true, wall)
	_build_east_wall(wall)
	# 南牆中間留門（1.6 m 寬、2.3 m 高）
	var side: float = (w * 2.0 - 1.6) * 0.5
	_box("WallS_W", Vector3(side, WALL_H, WALL_T), Vector3(-(0.8 + side * 0.5), WALL_H * 0.5, d), WALL, true, wall)
	_box("WallS_E", Vector3(side, WALL_H, WALL_T), Vector3(0.8 + side * 0.5, WALL_H * 0.5, d), WALL, true, wall)
	_box("WallS_Top", Vector3(1.6, WALL_H - 2.3, WALL_T), Vector3(0, 2.3 + (WALL_H - 2.3) * 0.5, d), WALL, true, wall)
	# 門板（直排木板）＋門框（兩邊的柱、上面的楣）
	var door_wood := plank("door", Color(0.22, 0.155, 0.11), 0.25, 4.0, {"vertical_planks": true, "seam_dark": 0.8})
	_box("TavernDoorLeaf", Vector3(1.5, 2.25, 0.08), Vector3(0, 1.125, d + 0.12), BEAM, true, door_wood)
	for sx: float in [-1.0, 1.0]:
		_box("DoorJamb", Vector3(0.14, 2.3, 0.42), Vector3(sx * 0.87, 1.15, d), BEAM, false, timber_mat())
	_box("DoorLintel", Vector3(1.88, 0.16, 0.42), Vector3(0, 2.38, d), BEAM, false, timber_mat())
	var door := Marker3D.new()
	door.name = "TavernDoor"
	door.position = DOOR_POS + Vector3(0, 1.0, 0)
	add_child(door)
	# 橫樑
	for i: int in 4:
		_box("Beam%d" % i, Vector3(w * 2.0, 0.22, 0.26), Vector3(0, WALL_H - 0.15, -3.6 + i * 2.4), BEAM, false, timber_mat())
	# 東牆的窗（中午的光從這裡進來）
	# 結霜玻璃（D-186）：隔著霜看得到模糊的對街（雪地、對面房子、積雪的屋頂；入夜對面的窗點著燈）
	_window_mat = ShaderMaterial.new()
	_window_mat.shader = load(FROST_WINDOW_SHADER) as Shader
	_window_mat.set_shader_parameter("pane_size", Vector2(WINDOW_SIZE.y, WINDOW_SIZE.x))
	var window := _box("Window", Vector3(0.06, WINDOW_SIZE.x, WINDOW_SIZE.y), WINDOW_CENTER, Color.WHITE, false, _window_mat)
	# 玻璃不擋光：窗外的光束穿過去，只有窗櫺投影子
	window.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_window_frame()
	_window_light = OmniLight3D.new()
	_window_light.name = "WindowLight"
	_window_light.position = Vector3(w - 1.0, 1.9, -1.0)
	_window_light.omni_range = 8.0
	_window_light.shadow_enabled = true
	add_child(_window_light)
	_sun_beam = SpotLight3D.new()
	_sun_beam.name = "SunBeam"
	_sun_beam.spot_angle = SUN_ANGLE_DEG
	_sun_beam.spot_range = SUN_DISTANCE + WINDOW_CENTER.distance_to(SUN_TARGET) + 1.5
	_sun_beam.shadow_enabled = true
	# 衰減放緩：窗外到地板 7 m 多，照物理衰減落到地上只剩一點點
	_sun_beam.spot_attenuation = 0.5
	_sun_beam.light_volumetric_fog_energy = 1.6
	add_child(_sun_beam)
	_sun_beam.look_at_from_position(sun_beam_origin(), SUN_TARGET, Vector3.UP)
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
	_build_hanging_lamp(lamp.position)


## 光束從哪裡來：窗外、沿著「窗中心 → SUN_TARGET」往回 SUN_DISTANCE（D-177）。
static func sun_beam_dir() -> Vector3:
	return (SUN_TARGET - WINDOW_CENTER).normalized()


static func sun_beam_origin() -> Vector3:
	return WINDOW_CENTER - sun_beam_dir() * SUN_DISTANCE


## 東牆（D-177）：原本一整塊、窗只是貼在牆前的發光板（光進不來）→ 拆成窗的北、南、下、上四塊，中間留真的窗洞。
## 牆的 shader 用世界座標，拆開看不出接縫。
func _build_east_wall(wall: Material) -> void:
	var w: float = ROOM_HALF.x
	var d: float = ROOM_HALF.y
	var c: Vector3 = WINDOW_CENTER
	var z0: float = c.z - WINDOW_SIZE.y * 0.5
	var z1: float = c.z + WINDOW_SIZE.y * 0.5
	var y0: float = c.y - WINDOW_SIZE.x * 0.5
	var y1: float = c.y + WINDOW_SIZE.x * 0.5
	_box("WallE_N", Vector3(WALL_T, WALL_H, z0 + d), Vector3(w, WALL_H * 0.5, (z0 - d) * 0.5), WALL, true, wall)
	_box("WallE_S", Vector3(WALL_T, WALL_H, d - z1), Vector3(w, WALL_H * 0.5, (z1 + d) * 0.5), WALL, true, wall)
	_box("WallE_Sill", Vector3(WALL_T, y0, z1 - z0), Vector3(w, y0 * 0.5, c.z), WALL, true, wall)
	_box("WallE_Head", Vector3(WALL_T, WALL_H - y1, z1 - z0), Vector3(w, (y1 + WALL_H) * 0.5, c.z), WALL, true, wall)


## 窗框（第 53 輪）：窗框四邊＋往房裡突出的窗台＋窗櫺（一直兩橫＝六格）。原本只有一片發光板。
func _build_window_frame() -> void:
	var c: Vector3 = WINDOW_CENTER
	var hh: float = WINDOW_SIZE.x * 0.5
	var hw: float = WINDOW_SIZE.y * 0.5
	var fx: float = c.x - 0.08
	var wood := timber_mat()
	_box("WindowFrameTop", Vector3(0.12, 0.12, WINDOW_SIZE.y + 0.24), Vector3(fx, c.y + hh + 0.06, c.z), BEAM, false, wood)
	_box("WindowSill", Vector3(0.24, 0.07, WINDOW_SIZE.y + 0.36), Vector3(c.x - 0.13, c.y - hh - 0.035, c.z), BEAM, false, wood)
	for sz: float in [-1.0, 1.0]:
		_box("WindowFrameSide", Vector3(0.12, WINDOW_SIZE.x, 0.12), Vector3(fx, c.y, c.z + sz * (hw + 0.06)), BEAM, false, wood)
	_box("WindowMullion", Vector3(0.05, WINDOW_SIZE.x, 0.05), Vector3(c.x - 0.04, c.y, c.z), BEAM, false, wood)
	for sy: float in [-1.0, 1.0]:
		_box("WindowTransom", Vector3(0.05, 0.05, WINDOW_SIZE.y), Vector3(c.x - 0.04, c.y + sy * WINDOW_SIZE.x / 6.0, c.z), BEAM, false, wood)


## 吧台上方的吊燈：從天花板垂下的鏈子＋燈罩（自發光）＋上下兩片鐵蓋。光本身是 CounterLamp。
func _build_hanging_lamp(at: Vector3) -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.08, 0.075, 0.07)
	iron.metallic = 0.6
	iron.roughness = 0.5
	var chain_len: float = WALL_H - (at.y + 0.14)
	var parts: Array[MeshInstance3D] = []
	parts.append(_prop("LampChain", _cyl(0.008, 0.008, chain_len, 6), Vector3(at.x, at.y + 0.14 + chain_len * 0.5, at.z), iron))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(1.0, 0.8, 0.5)
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.72, 0.4)
	glass.emission_energy_multiplier = 3.0
	parts.append(_prop("LampGlass", _cyl(0.06, 0.075, 0.18, 8), at, glass))
	parts.append(_prop("LampCap", _cyl(0.03, 0.1, 0.06, 8), at + Vector3(0, 0.12, 0), iron))
	parts.append(_prop("LampBase", _cyl(0.09, 0.07, 0.03, 8), at + Vector3(0, -0.105, 0), iron))
	# 燈本身是光源：不投影子（中午窗光會把燈罩的圓影投在北牆上，看起來像一塊汙漬）
	for mi: MeshInstance3D in parts:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## 壁爐（爐框中心在 base，背靠北牆、開口朝 +Z）：左右兩柱＋上面的爐楣＋爐台，中間凹進去的黑爐膛，
## 兩根交叉的柴＋底下一層發亮的炭，火焰（加法混色、往上縮小變紅）與零星火星。
const HEARTH_OPENING: Vector2 = Vector2(1.1, 0.8)
var hearth_flames: CPUParticles3D
var hearth_sparks: CPUParticles3D
var _flicker_t: float = 0.0


func _build_hearth(base: Vector3) -> void:
	var stone := Color(0.3, 0.28, 0.26)
	# 第 53 輪：爐框換成石塊（整面石頭、石塊小一點），爐口上方燻黑
	var stone_mat := interior_wall("hearth", 99.0, 0.55, 0.55, 1.4, 0.65)
	var ow: float = HEARTH_OPENING.x
	var oh: float = HEARTH_OPENING.y
	var side: float = (2.2 - ow) * 0.5
	for sx: float in [-1.0, 1.0]:
		_box("HearthJamb", Vector3(side, oh, 0.8), base + Vector3(sx * (ow + side) * 0.5, oh * 0.5, 0), stone, true, stone_mat)
	_box("Hearth", Vector3(2.2, 1.4 - oh, 0.8), base + Vector3(0, oh + (1.4 - oh) * 0.5, 0), stone, true, stone_mat)
	# 爐台（突出一點的石板）與上面的木頭壁架
	_box("HearthMantel", Vector3(2.5, 0.12, 0.3), base + Vector3(0, 1.46, 0.3), BEAM, false, timber_mat())
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


## 桌子（第 53 輪）：桌面是有厚度的木板（板縫沿 X）、底下一圈裙板、四支方腳。回傳桌面（名字＝node_name，說話點用）。
func _table(node_name: String, pos: Vector3, size: Vector2) -> Node3D:
	var t := _box(node_name, Vector3(size.x, 0.07, size.y), pos + Vector3(0, 0.765, 0), TABLE, true, table_mat())
	var wood := timber_mat()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box(node_name + "Leg", Vector3(0.09, 0.73, 0.09),
				pos + Vector3(sx * (size.x * 0.5 - 0.12), 0.365, sz * (size.y * 0.5 - 0.12)), TABLE, false, wood)
	# 裙板：桌面下 0.1 m，內縮到桌腳
	for sz: float in [-1.0, 1.0]:
		_box(node_name + "Apron", Vector3(size.x - 0.24, 0.1, 0.03), pos + Vector3(0, 0.68, sz * (size.y * 0.5 - 0.12)), TABLE, false, wood)
	for sx: float in [-1.0, 1.0]:
		_box(node_name + "Apron", Vector3(0.03, 0.1, size.y - 0.24), pos + Vector3(sx * (size.x * 0.5 - 0.12), 0.68, 0), TABLE, false, wood)
	return t


## 長凳：座板＋兩片板腳＋中間一根橫撐。沿 X 擺。
func _bench(node_name: String, pos: Vector3, length: float) -> void:
	_box(node_name, Vector3(length, 0.06, 0.3), pos + Vector3(0, 0.45, 0), TABLE, true, table_mat())
	var wood := timber_mat()
	for sx: float in [-1.0, 1.0]:
		_box(node_name + "Leg", Vector3(0.06, 0.42, 0.26), pos + Vector3(sx * (length * 0.5 - 0.16), 0.21, 0), TABLE, false, wood)
	_box(node_name + "Stretcher", Vector3(length - 0.32, 0.05, 0.04), pos + Vector3(0, 0.16, 0), TABLE, false, wood)


## 圓凳：圓座＋三支腳（不擋人）
func _stool(node_name: String, pos: Vector3) -> void:
	_prop(node_name, _cyl(0.17, 0.17, 0.05, 14), pos + Vector3(0, 0.47, 0), table_mat())
	var wood := timber_mat()
	for i: int in 3:
		var a: float = TAU * i / 3.0
		var leg := _prop(node_name + "Leg", _cyl(0.018, 0.022, 0.46, 6), pos + Vector3(cos(a) * 0.11, 0.225, sin(a) * 0.11), wood)
		leg.rotation = Vector3(sin(a) * 0.12, 0, -cos(a) * 0.12)


func _build_furniture() -> void:
	# 吧台（東北）：直排木板的正面＋往外突出的深色台面＋踢腳
	var front := plank("counter", Color(0.3, 0.205, 0.135), 0.16, 4.0, {"vertical_planks": true, "seam_dark": 0.8})
	_box("Counter", Vector3(0.7, 1.0, 3.6), Vector3(4.6, 0.5, -2.6), TABLE, true, front)
	var top := plank("counter_top", Color(0.2, 0.135, 0.09), 0.3, 3.9, {"base_roughness": 0.4, "seam_dark": 0.5, "along_z": true})
	_box("CounterTop", Vector3(0.92, 0.07, 3.8), Vector3(4.53, 1.035, -2.6), TABLE, false, top)
	_box("CounterKick", Vector3(0.66, 0.1, 3.56), Vector3(4.62, 0.05, -2.6), TABLE, false, timber_mat())
	# 晚餐的桌子（正中偏北）＋兩條長凳、畫地圖的小桌（東南）＋一張圓凳
	_table("DinnerTable", Vector3(-0.6, 0.0, -2.2), Vector2(2.2, 1.1))
	_bench("DinnerBenchN", Vector3(-0.6, 0.0, -3.05), 1.9)
	_bench("DinnerBenchS", Vector3(-0.75, 0.0, -1.35), 1.5)
	_table("MapTable", Vector3(3.4, 0.0, 2.2), Vector2(1.2, 0.9))
	_stool("MapStool", Vector3(3.15, 0.0, 2.95))
	# 地圖：一張紙
	_box("MapSheet", Vector3(0.7, 0.01, 0.5), Vector3(3.4, 0.81, 2.2), Color(0.86, 0.8, 0.66), false)
	# 西側安置傷者的長椅：木框＋草蓆床墊；空的那張腳邊疊一條毯子
	var straw := StandardMaterial3D.new()
	straw.albedo_color = Color(0.5, 0.43, 0.3)
	straw.roughness = 0.95
	for i: int in 3:
		var at := Vector3(-5.8, 0.0, -1.6 + i * 2.4)
		_box("Cot%d" % i, Vector3(0.8, 0.3, 2.0), at + Vector3(0, 0.2, 0), Color(0.4, 0.34, 0.28), true, timber_mat())
		_box("CotMattress%d" % i, Vector3(0.72, 0.12, 1.9), at + Vector3(0, 0.41, 0), Color.WHITE, false, straw)
	var wool := StandardMaterial3D.new()
	wool.albedo_color = Color(0.36, 0.14, 0.11)
	wool.roughness = 1.0
	_box("CotBlanket", Vector3(0.74, 0.07, 0.42), Vector3(-5.8, 0.505, 3.2 - 0.66), Color.WHITE, false, wool)
	_build_table_setting()
	_build_back_shelf()


## 晚餐桌上：三個湯碗、一條麵包、一個陶壺、中間一支蠟燭（入夜才點，_apply_time_of_day）。
func _build_table_setting() -> void:
	var y: float = 0.8
	var clay := StandardMaterial3D.new()
	clay.albedo_color = Color(0.42, 0.3, 0.2)
	clay.roughness = 0.7
	var soup := StandardMaterial3D.new()
	soup.albedo_color = Color(0.4, 0.24, 0.1)
	soup.roughness = 0.25
	var bowls: Array[Vector2] = [Vector2(-0.85, -1.92), Vector2(-0.15, -2.48), Vector2(0.2, -1.94)]
	for i: int in bowls.size():
		var b: Vector2 = bowls[i]
		_prop("Bowl%d" % i, _cyl(0.085, 0.05, 0.06), Vector3(b.x, y + 0.03, b.y), clay)
		_prop("Soup%d" % i, _cyl(0.074, 0.074, 0.004), Vector3(b.x, y + 0.052, b.y), soup)
	var bread := StandardMaterial3D.new()
	bread.albedo_color = Color(0.55, 0.36, 0.18)
	bread.roughness = 0.85
	var loaf := SphereMesh.new()
	loaf.radius = 0.08
	loaf.height = 0.09
	var bread_mi := _prop("Bread", loaf, Vector3(0.0, y + 0.035, -2.05), bread)
	bread_mi.scale = Vector3(1.7, 1.0, 1.0)
	var jug := StandardMaterial3D.new()
	jug.albedo_color = Color(0.3, 0.26, 0.22)
	jug.roughness = 0.45
	_prop("Jug", _cyl(0.045, 0.07, 0.22, 12), Vector3(0.6, y + 0.11, -2.45), jug)
	# 蠟燭：鐵燭台＋蠟＋火苗（自發光）＋一盞小點光
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.08, 0.075, 0.07)
	iron.metallic = 0.6
	iron.roughness = 0.5
	_prop("CandleHolder", _cyl(0.05, 0.055, 0.015, 12), CANDLE_POS + Vector3(0, 0.008, 0), iron)
	var wax := StandardMaterial3D.new()
	wax.albedo_color = Color(0.86, 0.82, 0.7)
	wax.roughness = 0.5
	_prop("Candle", _cyl(0.02, 0.022, 0.14, 10), CANDLE_POS + Vector3(0, 0.085, 0), wax)
	var flame := StandardMaterial3D.new()
	flame.albedo_color = Color(1.0, 0.8, 0.45)
	flame.emission_enabled = true
	flame.emission = Color(1.0, 0.7, 0.32)
	flame.emission_energy_multiplier = 5.0
	var fm := SphereMesh.new()
	fm.radius = 0.011
	fm.height = 0.045
	_candle_flame = _prop("CandleFlame", fm, CANDLE_POS + Vector3(0, 0.178, 0), flame)
	_candle_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_candle_light = OmniLight3D.new()
	_candle_light.name = "CandleLight"
	_candle_light.light_color = Color(1.0, 0.72, 0.42)
	_candle_light.light_energy = 0.6
	_candle_light.omni_range = 2.4
	_candle_light.position = CANDLE_POS + Vector3(0, 0.25, 0)
	add_child(_candle_light)


## 吧台後面東牆上的兩層架子：木板＋瓶子（深綠、褐、淡色玻璃，亮面反火光）＋木杯；吧台上兩個木杯。
func _build_back_shelf() -> void:
	var wood := timber_mat()
	var colors: Array[Color] = [Color(0.1, 0.2, 0.12), Color(0.26, 0.13, 0.06), Color(0.45, 0.5, 0.45), Color(0.16, 0.1, 0.06)]
	var glass: Array[StandardMaterial3D] = []
	for c: Color in colors:
		var g := StandardMaterial3D.new()
		g.albedo_color = c
		g.roughness = 0.12
		g.metallic_specular = 0.7
		glass.append(g)
	var cup := StandardMaterial3D.new()
	cup.albedo_color = Color(0.33, 0.23, 0.15)
	cup.roughness = 0.6
	var n: int = 0
	for row: int in 2:
		var sy: float = 1.55 + row * 0.5
		_box("BackShelf%d" % row, Vector3(0.3, 0.04, 2.0), Vector3(6.7, sy, -3.0), BEAM, false, wood)
		for k: int in 7:
			var z: float = -3.85 + k * 0.27 + (0.04 if row == 1 else 0.0)
			var h: float = fposmod(sin(float(n) * 12.9898) * 43758.5453, 1.0)
			if h < 0.28:
				_prop("ShelfCup%d" % n, _cyl(0.045, 0.04, 0.1, 10), Vector3(6.7, sy + 0.07, z), cup)
			else:
				var tall: float = lerpf(0.2, 0.3, h)
				_prop("Bottle%d" % n, _cyl(0.038, 0.042, tall, 10), Vector3(6.7, sy + 0.02 + tall * 0.5, z), glass[n % glass.size()])
				_prop("BottleNeck%d" % n, _cyl(0.013, 0.02, 0.07, 8), Vector3(6.7, sy + 0.02 + tall + 0.035, z), glass[n % glass.size()])
			n += 1
	for z: float in [-3.7, -3.48, -1.55]:
		_prop("CounterCup", _cyl(0.045, 0.04, 0.1, 10), Vector3(4.5, 1.12, z), cup)


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
	# 彌夏：墨綠過長外衣，抱著沒有指針的鐘（第 57 輪：小木箱換成真的座鐘，D-175）
	_puppet("Misha", Vector3(-1.8, 0.0, -1.2), 160.0, Color(0.16, 0.27, 0.21), Color(0.3, 0.26, 0.2))
	_build_clockless_clock(CLOCK_POS)
	# 酒館老闆：吧台後面
	_puppet("Keeper", Vector3(5.4, 0.0, -2.4), -90.0, Color(0.3, 0.22, 0.16), Color(0.5, 0.44, 0.36))
	# 傷者：躺在長椅上（仰躺，頭朝 +Z）
	for i: int in 2:
		_puppet("Wounded%d" % i, Vector3(-5.8, 0.62, -2.4 + i * 2.4), 0.0, Color(0.24, 0.24, 0.26), Color(0.5, 0.2, 0.18), "back")


# ---------------------------------------------------------------- 彌夏的鐘（第 57 輪，D-175）
# 沒有指針的座鐘：木殼（上面半圓頂）、底座、米白鐘面＋黃銅圈、十二道刻度，中間只剩一根空的軸（指針不見了）。
# 鐘面朝 +Z（酒館門那一側），放在桌上。

## 鐘的底部中心（桌面上）
const CLOCK_POS: Vector3 = Vector3(-1.2, 0.8, -2.2)
const CLOCK_W: float = 0.3
const CLOCK_BODY_H: float = 0.26
const CLOCK_D: float = 0.17
const CLOCK_FACE_R: float = 0.105
const CLOCK_HOUR_MARKS: int = 12


func _build_clockless_clock(at: Vector3) -> void:
	var clock := Node3D.new()
	clock.name = "ClocklessClock"
	clock.position = at
	add_child(clock)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.22, 0.12)
	wood.roughness = 0.45
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.62, 0.48, 0.24)
	brass.metallic = 0.75
	brass.roughness = 0.35
	var face_mat := StandardMaterial3D.new()
	face_mat.albedo_color = Color(0.86, 0.81, 0.69)
	face_mat.roughness = 0.7
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color(0.12, 0.1, 0.09)
	_clock_part(clock, "ClockBase", _box_mesh(Vector3(CLOCK_W + 0.06, 0.035, CLOCK_D + 0.05)), Vector3(0, 0.0175, 0), Vector3.ZERO, wood)
	_clock_part(clock, "ClockBody", _box_mesh(Vector3(CLOCK_W, CLOCK_BODY_H, CLOCK_D)), Vector3(0, 0.035 + CLOCK_BODY_H * 0.5, 0), Vector3.ZERO, wood)
	# 上面半圓頂：一個橫躺的圓柱（一半埋進鐘身）
	var dome := CylinderMesh.new()
	dome.top_radius = CLOCK_W * 0.5
	dome.bottom_radius = CLOCK_W * 0.5
	dome.height = CLOCK_D
	dome.radial_segments = 24
	_clock_part(clock, "ClockDome", dome, Vector3(0, 0.035 + CLOCK_BODY_H, 0), Vector3(90, 0, 0), wood)
	var face_y: float = 0.035 + CLOCK_BODY_H * 0.62
	var front: float = CLOCK_D * 0.5
	var face := CylinderMesh.new()
	face.top_radius = CLOCK_FACE_R
	face.bottom_radius = CLOCK_FACE_R
	face.height = 0.01
	face.radial_segments = 32
	_clock_part(clock, "ClockFace", face, Vector3(0, face_y, front + 0.004), Vector3(90, 0, 0), face_mat)
	var bezel := TorusMesh.new()
	bezel.inner_radius = CLOCK_FACE_R - 0.004
	bezel.outer_radius = CLOCK_FACE_R + 0.016
	bezel.rings = 32
	bezel.ring_segments = 8
	_clock_part(clock, "ClockBezel", bezel, Vector3(0, face_y, front + 0.008), Vector3(90, 0, 0), brass)
	for i: int in CLOCK_HOUR_MARKS:
		var a: float = float(i) / float(CLOCK_HOUR_MARKS) * TAU
		var long_mark: bool = i % 3 == 0
		var mark := _box_mesh(Vector3(0.006, 0.022 if long_mark else 0.012, 0.004))
		var r: float = CLOCK_FACE_R - (0.02 if long_mark else 0.015)
		_clock_part(clock, "ClockMark%d" % i, mark, Vector3(sin(a) * r, face_y + cos(a) * r, front + 0.011), Vector3(0, 0, -rad_to_deg(a)), ink)
	# 中間一根空的軸：指針不見了
	var spindle := CylinderMesh.new()
	spindle.top_radius = 0.006
	spindle.bottom_radius = 0.006
	spindle.height = 0.03
	spindle.radial_segments = 8
	_clock_part(clock, "ClockSpindle", spindle, Vector3(0, face_y, front + 0.02), Vector3(90, 0, 0), brass)


static func _box_mesh(size: Vector3) -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = size
	return bm


func _clock_part(parent: Node3D, node_name: String, mesh: Mesh, pos: Vector3, rot_deg: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
