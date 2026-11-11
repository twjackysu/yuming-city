class_name UndergroundMarket
extends StoryLevel
## 地下市場（第二段 A，docs/design/10-reboot-underground-market.md）：貨梯下來的高台 → 木坡道 →
## 一條往南的攤販街（兩側布棚、頭上一條條掛燈的繩子）→ 盡頭是彌夏藥店的綠色玻璃窗。
## 這個檔只蓋場景；劇情（任務 rb_market、檢查點 rb2_*、「待續」）在 UndergroundMarketStory，
## `Game.session.in_story()` 時才掛上去。座標：+z 往南；高台在北端。
## 光的原則：主光是攤子與繩上的暖色燈籠（多、小、不投影），大燈只有四盞投影；彩色只有三處
## （街底藥店的綠、詛咒物攤的紫、鐵匠攤的橘紅）；攤子之間留暗處，岩壁比街暗——
## 岩壁（cave_rock.gdshader）只靠布棚上面幾盞掛燈照出一小圈一小圈。

## 高台（貨梯在上面）的高度與南北範圍
const TERRACE_Y: float = 2.4
const TERRACE_N: float = -11.5
const TERRACE_S: float = -1.0
## 坡道：從高台南緣一路下到街面
const RAMP_S: float = 8.0
const RAMP_HALF: float = 1.6
## 街：半寬、兩側岩壁、藥店門面的位置
const STREET_HALF: float = 2.5
const WALL_X: float = 5.4
const SHOP_Z: float = 36.5
const CAVE_S: float = 40.5
const CEILING_Y: float = 9.5
## 貨梯停在高台上的位置（貨板中心）
const LIFT_POS: Vector3 = Vector3(0.0, TERRACE_Y, -9.2)
## 藥店的門（任務標記 MishaShopDoor 在這裡）
const SHOP_DOOR: Vector3 = Vector3(-1.7, 0.0, SHOP_Z - 0.4)
## 支撐的木架：第一座的位置、每座的間隔、幾座
## 店內（D-231）：門面後面的一間房。北牆＝門面的背面；洞的地板只到 CAVE_S，後面那一段是這間房自己的
const SHOP_INNER_Z: float = SHOP_Z + 0.5
const SHOP_ROOM_S: float = 42.2
const SHOP_ROOM_HALF: float = 4.6
const SHOP_ROOM_H: float = 3.4
## 門洞（門板往裡面開著）
const SHOP_DOOR_W: float = 1.3
const SHOP_DOOR_H: float = 2.25
## 櫃台：橫在房間中間，彌夏站在後面
const COUNTER_X: float = -0.2
const COUNTER_Z: float = 40.1
const COUNTER_LEN: float = 5.6
const COUNTER_TOP: float = 1.0
## 測試板在櫃台上靠客人的那一邊；彌夏在它後面偏西半步（站正後方會被刻度盤擋住上半身）。不放在門的正對面：人站在板子前，鏡頭在他背後，
## 要離門框與門板遠一點（放在 x＝-1.2 的時候鏡頭整個被門板擋住）
const BOARD_POS: Vector3 = Vector3(0.7, COUNTER_TOP, COUNTER_Z - 0.14)
const MISHA_POS: Vector3 = Vector3(0.05, 0.0, COUNTER_Z + 0.8)
## 測試板的指針（度；正的＝往西擺。鏡頭朝南時西邊在畫面右邊＝「回復」那一側）
const BOARD_HURT_DEG: float = -48.0
const BOARD_HEAL_DEG: float = 56.0
const BOARD_NEEDLE_SPEED: float = 140.0
const BOARD_LAMP_ENERGY: float = 0.9
const FRAME_Z0: float = 9.0
const FRAME_STEP: float = 8.4
const FRAME_COUNT: int = 4
const FRAME_BEAM_Y: float = 6.2
## 攤子：每個木架之間兩攤；最北邊兩攤在坡道兩旁、高台底下（從高台往下看的前景）
const STALL_PITCH: float = 4.2
const STALL_Z0: float = 2.7
const STALLS_PER_SIDE: int = 8
## 攤子的種類：-1＝空著（堆木箱，留一塊暗處）
const KIND_GAP: int = -1
const KIND_GOODS: int = 0
const KIND_CURSED: int = 2
const KIND_SMITH: int = 3
const KIND_FOOD: int = 4
const KIND_CLOTH: int = 5
const WEST_KINDS: Array[int] = [KIND_GOODS, KIND_CLOTH, KIND_GOODS, KIND_SMITH, KIND_GAP, KIND_CURSED, KIND_CLOTH, KIND_GOODS]
const EAST_KINDS: Array[int] = [KIND_FOOD, KIND_GOODS, KIND_CLOTH, KIND_GAP, KIND_GOODS, KIND_FOOD, KIND_GOODS, KIND_CLOTH]
## 有人顧的攤子（西側、東側各三個）
const WEST_VENDORS: Array[int] = [1, 3, 5]
const EAST_VENDORS: Array[int] = [0, 4, 6]
## 頭上的掛燈繩：幾條、第一條的位置、間隔
const ROPE_COUNT: int = 13
const ROPE_Z0: float = 0.6
const ROPE_STEP: float = 2.8
## 布棚（D-229）：前緣比攤桌外緣（STREET_HALF＋0.2）再出來一點點、不伸到街上；前緣高過過肩鏡頭
const AWNING_FRONT_OUT: Vector2 = Vector2(0.0, 0.2)
const AWNING_FRONT_Y: Vector2 = Vector2(2.75, 3.05)
const AWNING_BACK_Y: Vector2 = Vector2(3.45, 3.9)
## 棚子前緣的吊牌（寬、高）
const TAG_SIZE: Vector2 = Vector2(0.085, 0.12)
## 攤子的燈：吊在棚子前緣底下多少、多亮
const STALL_LAMP_DROP: float = 0.6
const STALL_LAMP_ENERGY: float = 1.5
## 攤子燈的玻璃多亮（5.0 的時候貼近鏡頭是一塊過曝的白）
const STALL_LAMP_GLOW: float = 2.4
## 岩壁上的掛燈（D-229）：[左右, z, 高]——在布棚上面，照出一小圈岩面，畫面兩側與上緣不是一片死黑
const WALL_LAMPS: Array[Vector3] = [Vector3(1.0, 4.6, 5.3), Vector3(-1.0, 1.7, 5.1), Vector3(-1.0, 8.2, 5.0), Vector3(1.0, 19.4, 5.2), Vector3(-1.0, 25.0, 5.4)]
## 藥店窗前的綠光（只照亮窗前幾步）
const SHOP_GLOW_ENERGY: float = 2.4
const SHOP_GLOW_RANGE: float = 8.0
## 街面：大塊的石板（寬，公尺）、有點潮（粗糙度低＝燈在地上有一片柔的反光）
## 藥店的綠窗（D-230）：門面幾乎整片是玻璃——主窗 4 格寬、東邊窄窗 2 格、門與西半邊上面一排氣窗。
## 從高台看過去（45 m 外）街底是一整條綠，不是一個小方塊
const SHOP_PANE_H: float = 0.78
const SHOP_WINDOW_ROWS: int = 4
const SHOP_WINDOW_Y0: float = 1.0
const SHOP_TRANSOM_ROWS: int = 2
## 高台西側欄杆前看街的兩個人（D-230）：位置、朝向（度；180＝面向南）、身高比例
const WATCHERS: Array[Array] = [
	[Vector3(-3.2, 0.0, TERRACE_S - 0.62), 196.0, 1.0],
	[Vector3(-4.05, 0.0, TERRACE_S - 0.7), 226.0, 0.93],
]
## 綠窗遠看的補償（window_glass.gdshader 的 far_boost／far_saturate）：40 m 外發光 ×(1＋BOOST)、顏色變濃；
## 10 m 以內不變。暖色的蒸氣會把 45 m 外的綠洗成灰黃；從高台看，街底要認得出是那間店
const SHOP_GLASS_FAR_BOOST: float = 2.0
const SHOP_GLASS_FAR_SATURATE: float = 2.0
const STREET_SLAB: float = 0.6
const STREET_ROUGHNESS: float = 0.4
## 燈的顏色
const LAMP: Color = Color(1.0, 0.74, 0.46)
const LAMP_DEEP: Color = Color(1.0, 0.5, 0.22)
## 貨梯井上面漏下來的冷光（上面是下雪的霜橋鎮）
const SHAFT_COOL: Color = Color(0.6, 0.72, 1.0)
const SHOP_GREEN: Color = Color(0.36, 1.0, 0.58)
const CURSE_PURPLE: Color = Color(0.62, 0.36, 1.0)
const FORGE_RED: Color = Color(1.0, 0.36, 0.12)
## 紙燈籠的顏色（琥珀最多，橘、淡黃點綴，紅的很少）
const PAPER_COLORS: Array[Color] = [
	Color(1.0, 0.62, 0.26), Color(1.0, 0.62, 0.26), Color(1.0, 0.44, 0.17), Color(1.0, 0.8, 0.5), Color(0.95, 0.24, 0.13),
]
## 藥店前面的紙燈籠是綠的：離門面這麼近以內的掛燈繩（最後兩條）
const SHOP_PAPER: Color = Color(0.4, 1.0, 0.55)
const SHOP_PAPER_REACH: float = 9.0
## 市場的底噪（D-230）：遠處的人聲嗡嗡的、岩洞的空氣聲、偶爾一聲碰撞。以前只有很小聲的風
const MURMUR_SFX: String = "market_murmur"
const MURMUR_DB: float = -14.0
## 樑下大鐵燈的左右位置（不排成一直線，也不擋住街底的綠窗）
const FRAME_LAMP_X: Array[float] = [-1.9, 1.9]
const CLOTH_STACK_COLORS: Array[Color] = [
	Color(0.4, 0.12, 0.1), Color(0.14, 0.2, 0.36), Color(0.5, 0.4, 0.16), Color(0.5, 0.46, 0.38), Color(0.2, 0.3, 0.2),
]
const REFLECT_LAYER: int = 1 << 10
const AWNING_SHADER: String = "res://src/world/awning_cloth.gdshader"
const LANTERN_SHADER: String = "res://src/world/paper_lantern.gdshader"
const ROCK_SHADER: String = "res://src/world/cave_rock.gdshader"

var look := FrostbridgeLook.new()
var interior := InteriorLook.new()
var _batch := StaticBatch.new()
var story: UndergroundMarketStory = null
## 測試、效能檢查用
var light_count: int = 0
var shadow_light_count: int = 0
var stall_count: int = 0
var awning_count: int = 0
var paper_lantern_count: int = 0
## 其中幾盞是藥店前面的綠燈籠
var shop_paper_count: int = 0
var vendors: Array[Puppet] = []
## 高台欄杆前看街的人（不顧攤、不轉頭）
var watchers: Array[Puppet] = []
## 藥店門面上發綠光的玻璃一共幾平方公尺（測試用）
var shop_glass_area: float = 0.0
var shop_light: OmniLight3D
## 店內（D-231）
var misha: Puppet
var test_board: Node3D
var board_needle: Node3D
var board_lamp: MeshInstance3D
var board_lamp_light: OmniLight3D
## 指針要擺到幾度、綠燈亮不亮（劇情設，_process 慢慢追上去）
var board_target_deg: float = 0.0
var board_lamp_on: bool = false
var shop_bottle_count: int = 0
var _board_lamp_mat: StandardMaterial3D
var _board_deg: float = 0.0
var _vendor_home_yaw: Array[float] = []
var _paper: Array[Vector4] = []  # xyz＝位置、w＝顏色的編號
var _cloths: Array[ShaderMaterial] = []
var _rock: Material
var _timber: Material
var _plank: Material
var _iron: Material
var _rope: Material
var _paper_tag: Material
var _forge_light: OmniLight3D
var _time: float = 0.0


func _ready() -> void:
	_rng.seed = 41  # 固定種子：截圖前後可對照
	build_environment(self)
	_make_materials()
	_build_cave()
	_build_terrace()
	_build_lift()
	_build_ramp()
	_build_nooks()
	_build_frames()
	_build_stalls()
	_build_ropes()
	_build_shop()
	_build_shop_interior()
	_build_wall_lamps()
	var market: Node3D = _batch.build(self, "Market")
	_build_paper_lanterns()
	_build_probes(market)
	_build_test_board()
	Ambience.play(self, MURMUR_SFX, MURMUR_DB)

	var player: PlayerController = $Player as PlayerController
	var spawn: Marker3D = $Spawn
	player.global_transform = spawn.global_transform
	player.yaw = player.rotation.y
	player.snap_camera()
	# 劇情交給 UndergroundMarketStory；沒有開新遊戲的 session（測試）就只有空的市場
	if Game.session.in_story():
		story = UndergroundMarketStory.new()
		story.name = "UndergroundMarketStory"
		add_child(story)
	player.snap_camera()


func ground_y(p: Vector3) -> float:
	if p.z <= TERRACE_S:
		return TERRACE_Y
	if p.z < RAMP_S and absf(p.x) <= RAMP_HALF:
		return TERRACE_Y * (RAMP_S - p.z) / (RAMP_S - TERRACE_S)
	return 0.0


func footstep_surface(p: Vector3) -> String:
	if p.z > TERRACE_S and p.z < RAMP_S and absf(p.x) <= RAMP_HALF:
		return "wood"
	if absf(p.x - LIFT_POS.x) < 1.2 and absf(p.z - LIFT_POS.z) < 1.0:
		return "wood"
	return "stone"


func _process(delta: float) -> void:
	_time += delta
	# 爐火的光微微跳動
	if _forge_light != null:
		_forge_light.light_energy = 2.3 + 0.35 * sin(_time * 9.0) + 0.2 * sin(_time * 23.0)
	_animate_board(delta)
	# 顧攤的人：諾恩走近就轉過來看他，走遠了轉回去看街
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player == null:
		return
	for i: int in vendors.size():
		var v: Puppet = vendors[i]
		var to: Vector3 = player.global_position - v.global_position
		to.y = 0.0
		var want: float = _vendor_home_yaw[i]
		if to.length() > 0.4 and to.length() < 5.5:
			want = atan2(-to.x, -to.z)
		v.rotation.y = lerp_angle(v.rotation.y, want, minf(delta * 3.0, 1.0))
	# 彌夏：人進到店裡就看著他（她在櫃台後面面向門，最多轉六十度）
	if misha != null:
		var to_m: Vector3 = player.global_position - misha.global_position
		to_m.y = 0.0
		var want_m: float = 0.0
		if to_m.length() > 0.4 and player.global_position.z > SHOP_INNER_Z - 1.0:
			want_m = clampf(atan2(-to_m.x, -to_m.z), -1.05, 1.05)
		misha.rotation.y = lerp_angle(misha.rotation.y, want_m, minf(delta * 3.0, 1.0))


# ---------------------------------------------------------------- 環境

## 地底：沒有天空。暖色的薄蒸氣（體積霧）讓燈籠有光暈；環境光很低，暗處才暗得下去。
static func build_environment(parent: Node3D) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.01, 0.009)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# 環境光偏冷：暖燈照不到的地方是藍灰的，不會整張圖只有橘色
	env.ambient_light_color = Color(0.25, 0.33, 0.42)
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 1.1
	env.ssao_enabled = true
	env.ssao_intensity = 2.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.018
	env.volumetric_fog_albedo = Color(0.9, 0.82, 0.7)
	env.volumetric_fog_emission = Color(0.03, 0.028, 0.03)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 64.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	parent.add_child(we)
	return env


func _make_materials() -> void:
	# 岩面（D-229）：不規則的大塊岩石，不是砌的石塊牆
	var rock := ShaderMaterial.new()
	rock.shader = load(ROCK_SHADER) as Shader
	_rock = rock
	_timber = interior.timber(Color(0.2, 0.14, 0.095))
	_plank = interior.plank("ramp", Color(0.27, 0.19, 0.125), 0.24, 2.4, {"along_z": true, "wear": 0.5})
	_iron = look.mat(Color(0.07, 0.07, 0.08), 0.5)
	_rope = look.mat(Color(0.2, 0.16, 0.11), 0.95)
	_paper_tag = look.mat(Color(0.74, 0.66, 0.5), 0.9)
	# 布棚的四種布：暗紅條紋、芥末黃條紋、靛藍、補過的米白
	for spec: Array in [
		[Color(0.46, 0.1, 0.08), Color(0.66, 0.56, 0.4), 7.0, 0.34],
		[Color(0.62, 0.42, 0.1), Color(0.3, 0.17, 0.08), 5.0, 0.22],
		[Color(0.1, 0.17, 0.34), Color(0.16, 0.26, 0.46), 9.0, 0.5],
		[Color(0.6, 0.54, 0.43), Color(0.42, 0.33, 0.24), 3.0, 0.12],
	]:
		var m := ShaderMaterial.new()
		m.shader = load(AWNING_SHADER) as Shader
		m.set_shader_parameter("cloth_color", spec[0] as Color)
		m.set_shader_parameter("stripe_color", spec[1] as Color)
		m.set_shader_parameter("stripe_count", float(spec[2]))
		m.set_shader_parameter("stripe_share", float(spec[3]))
		_cloths.append(m)


# ---------------------------------------------------------------- 岩洞、高台、坡道

func _build_cave() -> void:
	var z_n: float = TERRACE_N - 1.0
	var length: float = CAVE_S - z_n
	var mid_z: float = (CAVE_S + z_n) * 0.5
	# 地面：岩盤＋一層石板
	_batch.add_box_at(Vector3(WALL_X * 2.0 + 2.0, 1.0, length), Vector3(0.0, -0.5, mid_z), _rock)
	# 街面是大塊石板（D-229）：以前是小塊的濕石板，每一塊的邊都在反光、縫很黑，整條街的地板比攤子還搶
	var street: ShaderMaterial = interior.flagstone("street", Color(0.215, 0.195, 0.175), STREET_SLAB, {"base_roughness": STREET_ROUGHNESS, "seam_dark": 0.5})
	_batch.add_box_at(Vector3(WALL_X * 2.0, 0.02, CAVE_S - TERRACE_S), Vector3(0.0, 0.01, (CAVE_S + TERRACE_S) * 0.5), street, false)
	# 兩側岩壁、北牆、洞頂
	for side: float in [-1.0, 1.0]:
		_batch.add_box_at(Vector3(1.0, CEILING_Y, length), Vector3(side * (WALL_X + 0.5), CEILING_Y * 0.5, mid_z), _rock)
	_batch.add_box_at(Vector3(WALL_X * 2.0 + 2.0, CEILING_Y, 1.0), Vector3(0.0, CEILING_Y * 0.5, z_n - 0.5), _rock)
	_batch.add_box_at(Vector3(WALL_X * 2.0 + 2.0, 1.0, length), Vector3(0.0, CEILING_Y + 0.5, mid_z), _rock, false)


func _build_terrace() -> void:
	var depth: float = TERRACE_S - TERRACE_N
	var mid_z: float = (TERRACE_S + TERRACE_N) * 0.5
	_batch.add_box_at(Vector3(WALL_X * 2.0, TERRACE_Y, depth), Vector3(0.0, TERRACE_Y * 0.5, mid_z), _rock)
	var flag: ShaderMaterial = interior.flagstone("terrace", Color(0.25, 0.23, 0.21), 0.7, {"base_roughness": 0.5})
	_batch.add_box_at(Vector3(WALL_X * 2.0, 0.02, depth), Vector3(0.0, TERRACE_Y + 0.01, mid_z), flag, false)
	# 南緣的木欄杆（坡道口留空）
	for side: float in [-1.0, 1.0]:
		var x0: float = side * (RAMP_HALF + 0.1)
		var x1: float = side * (WALL_X - 0.05)
		_rail(Vector3(x0, TERRACE_Y, TERRACE_S - 0.12), Vector3(x1, TERRACE_Y, TERRACE_S - 0.12))
	# 坡道口的門架：兩根柱子、一根橫樑、兩幅短布——從貨梯走出來，整條街是從這個框裡看出去的
	# （鏡頭幾乎是水平的，畫面上緣要有近處的東西；背後井口的冷光照在樑的這一面）
	var gate_z: float = TERRACE_S - 0.4
	var gate_y: float = TERRACE_Y + 3.5
	for side: float in [-1.0, 1.0]:
		_batch.add_box_at(Vector3(0.26, 3.5, 0.26), Vector3(side * 2.05, TERRACE_Y + 1.75, gate_z), _timber)
		_beam(Vector3(side * 2.05, gate_y - 1.0, gate_z), Vector3(side * 1.15, gate_y - 0.08, gate_z), 0.14, _timber)
		_banner(Vector3(side * 1.5, gate_y - 0.13, gate_z + 0.16), 0.6, 1.0, _cloths[0 if side < 0.0 else 2])
	_batch.add_box_at(Vector3(5.0, 0.3, 0.3), Vector3(0.0, gate_y + 0.02, gate_z), _timber, false)
	_batch.add_box_at(Vector3(5.5, 0.12, 0.42), Vector3(0.0, gate_y + 0.23, gate_z), _timber, false)
	# 門架右柱外側掛一盞小燈，底下是剛從貨梯卸下來的貨（D-229：高台右半邊以前是空的、全黑）
	# 位置都是寫死的，不用 _rng（多抽一次，後面攤子的配置全部會變）
	var post_lamp := Vector3(2.4, TERRACE_Y + 2.15, gate_z - 0.05)
	_box_lantern(post_lamp, 0.15, LAMP, 2.4)
	_light("GatePostLamp", post_lamp + Vector3(0.25, -0.1, -0.2), LAMP, 1.1, 5.5, false, 0.6)
	var crates: ShaderMaterial = look.door()
	for spec: Array in [
		[Vector3(3.05, 0.4, gate_z - 0.5), 0.8], [Vector3(3.85, 0.31, gate_z - 0.62), 0.62],
		[Vector3(3.1, 1.07, gate_z - 0.55), 0.54], [Vector3(4.55, 0.36, gate_z - 0.45), 0.72],
	]:
		var size: float = float(spec[1])
		var at: Vector3 = (spec[0] as Vector3) + Vector3(0.0, TERRACE_Y, 0.0)
		_batch.add_box_tinted(Vector3(size, size, size), at, crates, FrostbridgeLook.crate_tint(at), true)
	_barrel(Vector3(2.55, TERRACE_Y, gate_z - 1.15))
	# 西半邊（鏡頭朝南時的畫面右邊，D-230：以前整片是黑的）：欄杆前兩個看街的人、靠牆幾箱等貨梯的行李、
	# 箱子上放一盞提燈。位置一樣寫死，不用 _rng
	for spec: Array in WATCHERS:
		_watcher((spec[0] as Vector3) + Vector3(0.0, TERRACE_Y, 0.0), float(spec[1]), float(spec[2]))
	for spec: Array in [
		[Vector3(-4.85, 0.36, gate_z - 0.9), 0.72], [Vector3(-4.9, 0.3, gate_z - 1.65), 0.6],
		[Vector3(-4.15, 0.23, gate_z - 1.4), 0.46],
	]:
		var size: float = float(spec[1])
		var at: Vector3 = (spec[0] as Vector3) + Vector3(0.0, TERRACE_Y, 0.0)
		_batch.add_box_tinted(Vector3(size, size, size), at, crates, FrostbridgeLook.crate_tint(at), true)
	var rest_lamp := Vector3(-4.85, TERRACE_Y + 0.83, gate_z - 0.9)
	_box_lantern(rest_lamp, 0.13, LAMP, 2.6)
	_light("TerraceRestLamp", rest_lamp + Vector3(0.3, 0.3, 0.1), LAMP, 1.0, 5.0, false, 0.5)


## 木欄杆：a → b（腳的位置，可以一高一低＝沿著坡道）。每 1.1 m 一根柱子、兩道橫木；整段一個碰撞盒。
func _rail(a: Vector3, b: Vector3) -> void:
	var d: Vector3 = b - a
	var n: int = maxi(int(ceilf(d.length() / 1.1)), 1)
	for i: int in n + 1:
		var p: Vector3 = a.lerp(b, float(i) / float(n))
		_batch.add_box_at(Vector3(0.1, 1.05, 0.1), p + Vector3(0.0, 0.525, 0.0), _timber, false)
	for h: float in [0.5, 1.0]:
		_beam(a + Vector3(0.0, h, 0.0), b + Vector3(0.0, h, 0.0), 0.07, _timber)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.14, 1.1, d.length())
	_batch.add_shape(Transform3D(_basis_along(d), (a + b) * 0.5 + Vector3(0.0, 0.55, 0.0)), shape)


## 貨梯：高台北側的木架（後面兩根柱子、往前伸出去的橫樑、滑輪、往洞頂去的繩子）＋停在高台上的貨板＋柱上一盞燈。
## 前面沒有柱子：諾恩一下來，鏡頭在他背後，前面不能有東西擋住往街上看的那一眼。
## 井口漏下來一束冷光（上面是下雪的霜橋鎮）：背後冷、前面整條街暖。
func _build_lift() -> void:
	var lift := Node3D.new()
	lift.name = "Lift"
	lift.position = LIFT_POS
	add_child(lift)
	var c: Vector3 = LIFT_POS
	_batch.add_box_at(Vector3(2.3, 0.07, 1.9), c + Vector3(0.0, 0.035, 0.0), _plank, false)
	for sx: float in [-1.0, 1.0]:
		_batch.add_box_at(Vector3(0.22, 5.0, 0.22), c + Vector3(sx * 1.35, 2.5, -1.15), _timber)
		_batch.add_box_at(Vector3(0.2, 0.22, 2.6), c + Vector3(sx * 1.35, 5.0, 0.0), _timber, false)
		_beam(c + Vector3(sx * 1.35, 3.6, -1.15), c + Vector3(sx * 1.35, 4.9, 0.2), 0.14, _timber)
		for sz: float in [-1.0, 1.0]:
			# 四條吊繩：貨板四角 → 滑輪
			_rod(c + Vector3(sx * 1.05, 0.07, sz * 0.85), c + Vector3(sx * 0.12, 4.55, 0.0), 0.02, _rope)
	for sz: float in [-1.0, 1.0]:
		_batch.add_box_at(Vector3(2.9, 0.22, 0.2), c + Vector3(0.0, 5.0, sz * 1.15), _timber, false)
	_batch.add_box_at(Vector3(0.2, 0.2, 2.6), c + Vector3(0.0, 5.05, 0.0), _timber, false)
	_batch.add_cylinder(0.22, 0.22, 0.12, c + Vector3(0.0, 4.7, 0.0), _iron, false, 12)
	_rod(c + Vector3(0.0, 4.8, 0.0), c + Vector3(0.0, CEILING_Y, 0.0), 0.035, _rope)
	# 柱上的燈（不投影、不強：高台是暗的，亮的是前面的街）
	var at: Vector3 = c + Vector3(-1.35, 2.3, -0.95)
	_box_lantern(at, 0.18, LAMP, 4.0)
	_light("LiftLamp", at + Vector3(0.15, 0.0, 0.2), LAMP, 1.0, 6.0, false, 0.8)
	var shaft := SpotLight3D.new()
	shaft.name = "ShaftLight"
	shaft.light_color = SHAFT_COOL
	shaft.light_energy = 5.0
	shaft.spot_range = 12.0
	shaft.spot_angle = 21.0
	shaft.spot_angle_attenuation = 0.7
	shaft.shadow_enabled = true
	shaft.light_volumetric_fog_energy = 2.2
	shaft.position = c + Vector3(0.0, CEILING_Y - TERRACE_Y - 0.4, 0.3)
	shaft.rotation_degrees.x = -90.0
	add_child(shaft)
	light_count += 1
	shadow_light_count += 1
	# 井口的冷光散到整個高台（不投影、幾乎不進霧）：地板與人的背後是冷的，跟前面暖色的街分開
	var spill := SpotLight3D.new()
	spill.name = "ShaftSpill"
	spill.light_color = SHAFT_COOL
	spill.light_energy = 4.5
	spill.spot_range = 14.0
	spill.spot_angle = 58.0
	spill.spot_angle_attenuation = 1.2
	spill.light_specular = 0.3
	spill.light_volumetric_fog_energy = 0.25
	spill.position = c + Vector3(0.0, 6.2, 1.0)
	spill.rotation_degrees.x = -125.0
	add_child(spill)
	light_count += 1


func _build_ramp() -> void:
	var run: float = RAMP_S - TERRACE_S
	var angle: float = atan2(TERRACE_Y, run)
	var slope_len: float = Vector2(run, TERRACE_Y).length()
	var tilt := Basis(Vector3.RIGHT, angle)
	var normal: Vector3 = tilt * Vector3.UP
	var mid := Vector3(0.0, TERRACE_Y * 0.5, (TERRACE_S + RAMP_S) * 0.5)
	# 坡面：木板（碰撞盒厚一點，腳不會卡進縫裡）
	_batch.add_box(Vector3(RAMP_HALF * 2.0, 0.12, slope_len), Transform3D(tilt, mid - normal * 0.06), _plank, false)
	var shape := BoxShape3D.new()
	shape.size = Vector3(RAMP_HALF * 2.0, 0.4, slope_len + 0.3)
	_batch.add_shape(Transform3D(tilt, mid - normal * 0.2), shape)
	# 坡面上的防滑橫條
	var cleats: int = 11
	for i: int in cleats:
		var t: float = (float(i) + 0.5) / float(cleats)
		var p := Vector3(0.0, TERRACE_Y * (1.0 - t), lerpf(TERRACE_S, RAMP_S, t))
		_batch.add_box(Vector3(RAMP_HALF * 2.0 - 0.2, 0.035, 0.07), Transform3D(tilt, p + normal * 0.017), _timber, false)
	# 底下的支架：三排柱子＋橫樑
	for t: float in [0.2, 0.5, 0.8]:
		var top: float = TERRACE_Y * (1.0 - t) - 0.12
		var zz: float = lerpf(TERRACE_S, RAMP_S, t)
		for sx: float in [-1.0, 1.0]:
			_batch.add_box_at(Vector3(0.18, top, 0.18), Vector3(sx * (RAMP_HALF - 0.1), top * 0.5, zz), _timber, false)
		_batch.add_box_at(Vector3(RAMP_HALF * 2.0, 0.16, 0.16), Vector3(0.0, top - 0.08, zz), _timber, false)
	# 兩側欄杆（沿著坡）
	for sx: float in [-1.0, 1.0]:
		_rail(Vector3(sx * (RAMP_HALF - 0.05), TERRACE_Y, TERRACE_S), Vector3(sx * (RAMP_HALF - 0.05), 0.0, RAMP_S))
	var top_marker := Marker3D.new()
	top_marker.name = "MarketStreetTop"
	top_marker.position = Vector3(0.0, 0.2, RAMP_S + 1.2)
	add_child(top_marker)


## 坡道兩旁、高台底下：最北邊的兩排攤子在這裡（_build_stalls）；靠高台的牆腳堆幾個桶。
func _build_nooks() -> void:
	for side: float in [-1.0, 1.0]:
		for i: int in 3:
			_barrel(Vector3(side * (RAMP_HALF + 0.7 + float(i) * 0.72), 0.0, TERRACE_S + 0.45))


func _barrel(base: Vector3) -> void:
	var wood: Material = look.mat(Color(0.25, 0.17, 0.11), 0.85)
	_batch.add_cylinder(0.3, 0.3, 0.95, base + Vector3(0.0, 0.475, 0.0), wood, true, 12)
	for h: float in [0.2, 0.75]:
		_batch.add_cylinder(0.315, 0.315, 0.05, base + Vector3(0.0, h, 0.0), _iron, false, 12)


# ---------------------------------------------------------------- 木架、攤子

func frame_z(i: int) -> float:
	return FRAME_Z0 + FRAME_STEP * float(i)


## 支撐洞頂的木架：兩根柱子＋一根橫樑＋斜撐。第 0、2、4 座的樑下各吊一盞大鐵燈（投影）。
func _build_frames() -> void:
	for i: int in FRAME_COUNT:
		var z: float = frame_z(i)
		var post_x: float = STREET_HALF + 0.22
		for side: float in [-1.0, 1.0]:
			_batch.add_box_at(Vector3(0.3, FRAME_BEAM_Y, 0.3), Vector3(side * post_x, FRAME_BEAM_Y * 0.5, z), _timber)
			_beam(Vector3(side * post_x, FRAME_BEAM_Y - 1.5, z), Vector3(side * (post_x - 1.4), FRAME_BEAM_Y - 0.1, z), 0.16, _timber)
			_beam(Vector3(side * post_x, FRAME_BEAM_Y - 1.5, z), Vector3(side * (post_x + 1.4), FRAME_BEAM_Y - 0.1, z), 0.16, _timber)
		_batch.add_box_at(Vector3(WALL_X * 2.0, 0.34, 0.34), Vector3(0.0, FRAME_BEAM_Y + 0.17, z), _timber, false)
		# 樑下垂著兩幅長布（跟布棚同一批布，會透光）：街的上半部不是一片黑
		for k: int in 2:
			var bx: float = (-1.0 if k == 0 else 1.0) * _rng.randf_range(0.5, 1.5) + (0.6 if i % 2 == 0 else -0.6)
			_banner(Vector3(bx, FRAME_BEAM_Y, z - 0.19), _rng.randf_range(0.6, 0.85), _rng.randf_range(1.5, 2.3), _cloths[(i * 2 + k) % _cloths.size()])
		if i % 2 == 0:
			var x: float = FRAME_LAMP_X[(i >> 1) % FRAME_LAMP_X.size()]
			var at := Vector3(x, FRAME_BEAM_Y - 1.5, z)
			_rod(Vector3(x, FRAME_BEAM_Y, z), at + Vector3(0.0, 0.28, 0.0), 0.018, _iron)
			_box_lantern(at, 0.34, LAMP, 3.6)
			_light("FrameLamp%d" % i, at + Vector3(0.0, -0.32, 0.0), LAMP, 3.0, 11.0, true, 1.6)


## 樑下垂的一幅長布：top＝上緣中心，下緣剪成燕尾。
func _banner(top: Vector3, width: float, length: float, cloth: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw: float = width * 0.5
	var rows: int = 4
	for r: int in rows:
		var v0: float = float(r) / float(rows)
		var v1: float = float(r + 1) / float(rows)
		# 往下一點點往前飄（不是一塊硬板）
		var z0: float = 0.1 * v0 * v0
		var z1: float = 0.1 * v1 * v1
		_awning_quad(st, [
			top + Vector3(-hw, -length * v0, z0), top + Vector3(hw, -length * v0, z0),
			top + Vector3(hw, -length * v1, z1), top + Vector3(-hw, -length * v1, z1),
		], [Vector2(0.0, v0 * 0.6), Vector2(0.45, v0 * 0.6), Vector2(0.45, v1 * 0.6), Vector2(0.0, v1 * 0.6)])
	var low: Vector3 = top + Vector3(0.0, -length, 0.1)
	for sx: float in [-1.0, 1.0]:
		for pair: Array in [[low + Vector3(sx * hw, 0.0, 0.0), Vector2(0.0, 0.6)], [low, Vector2(0.22, 0.6)], [low + Vector3(sx * hw * 0.9, -0.3, 0.02), Vector2(0.1, 0.8)]]:
			st.set_uv(pair[1] as Vector2)
			st.add_vertex(pair[0] as Vector3)
	st.generate_normals()
	_batch.add_mesh(st.commit(), Transform3D.IDENTITY, cloth)


func stall_z(i: int) -> float:
	return STALL_Z0 + STALL_PITCH * float(i)


func _build_stalls() -> void:
	for i: int in STALLS_PER_SIDE:
		_stall(stall_z(i), -1.0, WEST_KINDS[i], (i * 2 + 1) % 4, i in WEST_VENDORS)
		_stall(stall_z(i), 1.0, EAST_KINDS[i], (i * 3) % 4, i in EAST_VENDORS)


## 一個攤子。side：-1 西、+1 東（攤子朝街心）。kind：KIND_*；cloth：布的編號。
func _stall(z: float, side: float, kind: int, cloth: int, vendor: bool) -> void:
	var crates: ShaderMaterial = look.door()
	if kind == KIND_GAP:
		# 空位：靠牆堆幾個木箱和一個桶，沒有燈——街上的暗處
		for i: int in 4:
			var s: float = _rng.randf_range(0.55, 0.9)
			var pos := Vector3(side * _rng.randf_range(STREET_HALF + 0.9, WALL_X - 0.6), s * 0.5, z + _rng.randf_range(-1.4, 1.4))
			_batch.add_box_tinted(Vector3(s, s, s), pos, crates, FrostbridgeLook.crate_tint(pos), true)
		_barrel(Vector3(side * (STREET_HALF + 0.6), 0.0, z + 0.4))
		return
	stall_count += 1
	var half_len: float = _rng.randf_range(1.5, 1.75)
	var back_x: float = WALL_X - 0.55
	# 棚子前緣停在攤桌外緣上方、高過頭頂（D-229）：伸到街上、只有 2.2 m 高的時候，
	# 過肩鏡頭（約 2 m 高）走在街上右邊三分之一都是貼著鏡頭的一片布
	var front_x: float = STREET_HALF + _rng.randf_range(AWNING_FRONT_OUT.x, AWNING_FRONT_OUT.y)
	var back_y: float = _rng.randf_range(AWNING_BACK_Y.x, AWNING_BACK_Y.y)
	var front_y: float = _rng.randf_range(AWNING_FRONT_Y.x, AWNING_FRONT_Y.y)
	# 攤桌（木箱板）＋桌上鋪的一塊布
	var table := Vector3(side * (STREET_HALF + 0.75), 0.45, z)
	_batch.add_box_tinted(Vector3(1.1, 0.9, half_len * 2.0 - 0.5), table, crates, FrostbridgeLook.crate_tint(table), true)
	_batch.add_box_at(Vector3(1.16, 0.03, half_len * 2.0 - 0.9), table + Vector3(0.0, 0.465, 0.0), look.mat(Color(0.3, 0.24, 0.18), 0.95), false)
	# 後面的板牆
	var back_wall: ShaderMaterial = interior.plank("stall_back", Color(0.19, 0.135, 0.09), 0.22, 2.2, {"vertical_planks": true})
	var back_h: float = back_y - 0.35
	_batch.add_box_at(Vector3(0.08, back_h, half_len * 2.0), Vector3(side * (back_x + 0.1), back_h * 0.5, z), back_wall, false)
	# 四根竿子
	for sz: float in [-1.0, 1.0]:
		_batch.add_box_at(Vector3(0.08, front_y, 0.08), Vector3(side * (STREET_HALF + 0.12), front_y * 0.5, z + sz * half_len), _timber, false)
		_batch.add_box_at(Vector3(0.08, back_y, 0.08), Vector3(side * back_x, back_y * 0.5, z + sz * half_len), _timber, false)
	# 布棚
	var depth: float = back_x - front_x
	var mesh: ArrayMesh = awning_mesh(half_len + 0.15, depth, back_y, front_y, _rng.randf_range(0.16, 0.3))
	var xf := Transform3D(Basis.IDENTITY if side < 0.0 else Basis(Vector3.UP, PI), Vector3(side * back_x, 0.0, z))
	_batch.add_mesh(mesh, xf, _cloths[cloth])
	awning_count += 1
	# 棚子前緣掛的一排吊牌（每件東西一張，寫著副作用——這裡的規矩）
	var tags: int = _rng.randi_range(3, 5)
	for i: int in tags:
		var tz: float = z + lerpf(-half_len + 0.3, half_len - 0.3, (float(i) + _rng.randf_range(0.2, 0.8)) / float(tags))
		var top := Vector3(side * (front_x + 0.02), front_y - 0.34, tz)
		var drop: float = _rng.randf_range(0.12, 0.3)
		_rod(top, top - Vector3(0.0, drop, 0.0), 0.004, _rope, 4)
		var tag_basis := Basis.from_euler(Vector3(0.0, _rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.12, 0.12)))
		_batch.add_box(Vector3(0.008, TAG_SIZE.y, TAG_SIZE.x), Transform3D(tag_basis, top - Vector3(0.0, drop + TAG_SIZE.y * 0.5, 0.0)), _paper_tag, false)
	# 棚下的燈
	var lamp_color: Color = LAMP
	var lamp_energy: float = STALL_LAMP_ENERGY
	if kind == KIND_CURSED:
		lamp_color = CURSE_PURPLE
		lamp_energy = 2.2
	# 燈吊在棚子底下、桌面上方（棚子抬高了，燈不跟著上去：貨要照得到）
	var lamp_at := Vector3(side * (STREET_HALF + 0.8), front_y - STALL_LAMP_DROP, z + _rng.randf_range(-0.6, 0.6))
	_rod(lamp_at + Vector3(0.0, STALL_LAMP_DROP - 0.1, 0.0), lamp_at + Vector3(0.0, 0.15, 0.0), 0.008, _iron, 4)
	_box_lantern(lamp_at, 0.17, lamp_color, STALL_LAMP_GLOW)
	_light("StallLamp", lamp_at + Vector3(-side * 0.15, -0.2, 0.0), lamp_color, lamp_energy, 5.2, false, 1.0)
	_goods(kind, table + Vector3(0.0, 0.48, 0.0), half_len - 0.45, side, front_x, front_y)
	if vendor:
		_vendor(Vector3(side * (STREET_HALF + 1.75), 0.0, z + _rng.randf_range(-0.5, 0.5)), side)


## 布棚：局部座標 x＝0（靠牆、高）→ depth（臨街、低），z＝-half_len → half_len；中間往下垂 sag。
## 前緣一條波浪邊的垂簾。UV.x 沿著長邊（條紋），UV.y 從後到前（垂簾是 0.8～1）。
static func awning_mesh(half_len: float, depth: float, back_y: float, front_y: float, sag: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu: int = 10
	var nv: int = 5
	for iv: int in nv:
		for iu: int in nu:
			var u0: float = float(iu) / float(nu)
			var u1: float = float(iu + 1) / float(nu)
			var v0: float = float(iv) / float(nv)
			var v1: float = float(iv + 1) / float(nv)
			_awning_quad(st, [
				awning_point(half_len, depth, back_y, front_y, sag, u0, v0), awning_point(half_len, depth, back_y, front_y, sag, u1, v0),
				awning_point(half_len, depth, back_y, front_y, sag, u1, v1), awning_point(half_len, depth, back_y, front_y, sag, u0, v1),
			], [Vector2(u0, v0 * 0.8), Vector2(u1, v0 * 0.8), Vector2(u1, v1 * 0.8), Vector2(u0, v1 * 0.8)])
	for iu: int in nu:
		var u0: float = float(iu) / float(nu)
		var u1: float = float(iu + 1) / float(nu)
		var p0: Vector3 = awning_point(half_len, depth, back_y, front_y, sag, u0, 1.0)
		var p1: Vector3 = awning_point(half_len, depth, back_y, front_y, sag, u1, 1.0)
		var b0: Vector3 = p0 + Vector3(0.02, -0.14, 0.0)
		var b1: Vector3 = p1 + Vector3(0.02, -0.14, 0.0)
		var tip: Vector3 = (b0 + b1) * 0.5 + Vector3(0.0, -0.17, 0.0)
		_awning_quad(st, [p0, p1, b1, b0], [Vector2(u0, 0.8), Vector2(u1, 0.8), Vector2(u1, 0.92), Vector2(u0, 0.92)])
		for pair: Array in [[b0, Vector2(u0, 0.92)], [b1, Vector2(u1, 0.92)], [tip, Vector2((u0 + u1) * 0.5, 1.0)]]:
			st.set_uv(pair[1] as Vector2)
			st.add_vertex(pair[0] as Vector3)
	st.generate_normals()
	return st.commit()


static func awning_point(half_len: float, depth: float, back_y: float, front_y: float, sag: float, u: float, v: float) -> Vector3:
	var y: float = lerpf(back_y, front_y, v) - sag * sin(PI * u) * (0.35 + 0.65 * sin(PI * v))
	return Vector3(depth * v, y, lerpf(-half_len, half_len, u))


static func _awning_quad(st: SurfaceTool, p: Array, uv: Array) -> void:
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uv[i] as Vector2)
		st.add_vertex(p[i] as Vector3)


## 攤桌上與棚下掛的貨。top＝桌面中心，half＝桌面可以擺的半長。
func _goods(kind: int, top: Vector3, half: float, side: float, front_x: float, front_y: float) -> void:
	match kind:
		KIND_SMITH:
			# 鐵砧、爐子（爐口的紅炭）、棚下掛的三把劍的剪影
			_batch.add_box_at(Vector3(0.3, 0.2, 0.55), top + Vector3(0.0, 0.1, -half * 0.5), _iron, false)
			_batch.add_box_at(Vector3(0.2, 0.12, 0.3), top + Vector3(0.0, 0.26, -half * 0.5), _iron, false)
			var forge := Vector3(side * (STREET_HALF + 1.9), 0.5, top.z + half * 0.6)
			_batch.add_box_at(Vector3(0.9, 1.0, 0.9), forge, _rock, false)
			_batch.add_box_at(Vector3(0.6, 0.08, 0.6), forge + Vector3(0.0, 0.52, 0.0), look.glow(FORGE_RED, 5.0), false)
			_forge_light = _light("ForgeGlow", forge + Vector3(-side * 0.3, 0.9, 0.0), FORGE_RED, 2.3, 6.0, false, 1.4)
			for i: int in 3:
				var hang := Vector3(side * (front_x + 0.25), front_y - 0.5, top.z + (float(i) - 1.0) * 0.5)
				_batch.add_box_at(Vector3(0.03, 0.9, 0.07), hang - Vector3(0.0, 0.45, 0.0), _iron, false)
				_batch.add_box_at(Vector3(0.03, 0.04, 0.24), hang - Vector3(0.0, 0.12, 0.0), _iron, false)
		KIND_FOOD:
			# 一口大鍋、冒著蒸氣；旁邊一疊碗
			var pot: Vector3 = top + Vector3(0.0, 0.2, half * 0.3)
			_batch.add_cylinder(0.36, 0.3, 0.4, pot, _iron, false, 14)
			_batch.add_cylinder(0.33, 0.33, 0.02, pot + Vector3(0.0, 0.19, 0.0), look.mat(Color(0.5, 0.36, 0.2), 0.3), false, 14)
			for i: int in 4:
				_batch.add_cylinder(0.11, 0.07, 0.05, top + Vector3(0.1, 0.03 + float(i) * 0.04, -half * 0.6), look.mat(Color(0.62, 0.56, 0.46), 0.6), false, 10)
			_steam(pot + Vector3(0.0, 0.3, 0.0))
		KIND_CLOTH:
			# 幾疊布、棚下掛的護腕（短圓筒）
			for i: int in 5:
				var c: Color = CLOTH_STACK_COLORS[i]
				var n: int = _rng.randi_range(2, 4)
				for j: int in n:
					_batch.add_box_at(Vector3(0.5, 0.06, 0.34), top + Vector3(_rng.randf_range(-0.1, 0.1), 0.03 + float(j) * 0.062, lerpf(-half, half, float(i) / 4.0)), look.mat(c, 0.95), false)
			for i: int in 3:
				var hang := Vector3(side * (front_x + 0.3), front_y - 0.62, top.z + (float(i) - 1.0) * 0.62)
				_rod(hang + Vector3(0.0, 0.3, 0.0), hang, 0.005, _rope, 4)
				_batch.add_cylinder(0.07, 0.085, 0.2, hang - Vector3(0.0, 0.1, 0.0), look.mat(Color(0.26, 0.2, 0.15), 0.6), false, 10)
		KIND_CURSED:
			# 詛咒物：深色的盒子上放著發紫光的小東西
			for i: int in 5:
				var p: Vector3 = top + Vector3(_rng.randf_range(-0.2, 0.2), 0.07, lerpf(-half, half, float(i) / 4.0))
				_batch.add_box_at(Vector3(0.3, 0.14, 0.3), p, look.mat(Color(0.09, 0.08, 0.11), 0.5), false)
				_batch.add_sphere(0.055, p + Vector3(0.0, 0.12, 0.0), look.glow(CURSE_PURPLE, 2.6))
		_:
			# 雜貨：瓶子、罐子、小木箱
			var n: int = _rng.randi_range(7, 10)
			for i: int in n:
				var p: Vector3 = top + Vector3(_rng.randf_range(-0.3, 0.3), 0.0, lerpf(-half, half, float(i) / float(n - 1)))
				var pick: int = _rng.randi_range(0, 2)
				if pick == 0:
					var h: float = _rng.randf_range(0.18, 0.3)
					_batch.add_cylinder(0.03, 0.06, h, p + Vector3(0.0, h * 0.5, 0.0), look.mat(Color(0.2, 0.26, 0.2), 0.25), false, 8)
				elif pick == 1:
					_batch.add_cylinder(0.09, 0.1, 0.2, p + Vector3(0.0, 0.1, 0.0), look.mat(Color(0.42, 0.3, 0.2), 0.7), false, 10)
				else:
					var s: float = _rng.randf_range(0.18, 0.3)
					_batch.add_box_tinted(Vector3(s, s * 0.7, s), p + Vector3(0.0, s * 0.35, 0.0), look.door(), FrostbridgeLook.crate_tint(p), false)


## 岩壁上的掛燈：鐵架伸出來、吊一盞小燈；燈光貼著岩面（看得出一塊塊岩石的起伏）。
func _build_wall_lamps() -> void:
	for spec: Vector3 in WALL_LAMPS:
		var side: float = spec.x
		var root := Vector3(side * WALL_X, spec.z + 0.35, spec.y)
		var at := Vector3(side * (WALL_X - 0.55), spec.z, spec.y)
		_rod(root, Vector3(at.x, root.y, at.z), 0.02, _iron)
		_rod(Vector3(at.x, root.y, at.z), at + Vector3(0.0, 0.14, 0.0), 0.01, _iron, 4)
		_box_lantern(at, 0.16, LAMP_DEEP, 3.0)
		_light("WallLamp", at + Vector3(-side * 0.1, -0.05, 0.0), LAMP_DEEP, 1.25, 7.0, false, 0.7)


## 鍋子的蒸氣：常駐、慢慢往上、暖色很淡。
func _steam(at: Vector3) -> void:
	var steam := CPUParticles3D.new()
	steam.name = "Steam"
	steam.position = at
	steam.amount = 14
	steam.lifetime = 3.2
	steam.preprocess = 3.2
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	steam.emission_sphere_radius = 0.2
	steam.direction = Vector3(0, 1, 0)
	steam.spread = 12.0
	steam.initial_velocity_min = 0.35
	steam.initial_velocity_max = 0.6
	steam.gravity = Vector3(0.0, 0.06, 0.05)
	steam.scale_amount_min = 0.7
	steam.scale_amount_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.3))
	grow.add_point(Vector2(1.0, 1.0))
	steam.scale_amount_curve = grow
	var quad := QuadMesh.new()
	quad.size = Vector2(1.3, 1.3)
	quad.material = ParticleLook.material(Color(1.0, 0.86, 0.68, 1.0), false, BaseMaterial3D.BILLBOARD_PARTICLES)
	steam.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	ramp.add_point(0.15, Color(1.0, 1.0, 1.0, 0.16))
	ramp.add_point(0.6, Color(1.0, 1.0, 1.0, 0.07))
	steam.color_ramp = ramp
	add_child(steam)


## 顧攤的人：站在攤桌後面、看著街。
func _vendor(at: Vector3, side: float) -> void:
	var v := Puppet.new()
	v.name = "Vendor%d" % vendors.size()
	var coats: Array[Color] = [Color(0.3, 0.2, 0.14), Color(0.16, 0.22, 0.2), Color(0.33, 0.14, 0.12), Color(0.2, 0.19, 0.27), Color(0.34, 0.28, 0.16), Color(0.14, 0.15, 0.17)]
	v.coat_color = coats[vendors.size() % coats.size()]
	v.trim_color = Color(0.5, 0.42, 0.3)
	v.position = at
	# 朝街心：西側的人面向東（+x），東側的人面向西
	var yaw: float = atan2(side, 0.0)
	v.rotation.y = yaw
	add_child(v)
	var hammer: Node = v.hand("R").get_node_or_null("BellHammer") if v.hand("R") != null else null
	if hammer != null:
		hammer.queue_free()
	vendors.append(v)
	_vendor_home_yaw.append(yaw)


## 高台欄杆前看街的人：背對貨梯、往下看整條街（不轉頭）。腳邊一個碰撞盒，諾恩不會穿過去。
func _watcher(at: Vector3, face_deg: float, height: float) -> void:
	var v := Puppet.new()
	v.name = "Watcher%d" % watchers.size()
	var coats: Array[Color] = [Color(0.2, 0.24, 0.3), Color(0.36, 0.2, 0.14)]
	v.coat_color = coats[watchers.size() % coats.size()]
	v.trim_color = Color(0.46, 0.4, 0.3)
	v.position = at
	v.rotation_degrees.y = face_deg
	v.scale = Vector3.ONE * height
	add_child(v)
	var hammer: Node = v.hand("R").get_node_or_null("BellHammer") if v.hand("R") != null else null
	if hammer != null:
		hammer.queue_free()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 1.7, 0.5)
	_batch.add_shape(Transform3D(Basis(), at + Vector3(0.0, 0.85, 0.0)), shape)
	watchers.append(v)


# ---------------------------------------------------------------- 頭上的掛燈繩、街底的藥店

static func rope_point(a: Vector3, b: Vector3, sag: float, t: float) -> Vector3:
	var p: Vector3 = a.lerp(b, t)
	p.y -= sag * 4.0 * t * (1.0 - t)
	return p


## 街上方一條條橫拉的繩子：單數條掛紙燈籠（中間一盞不投影的小燈讓霧裡有光暈），雙數條掛三角旗。
func _build_ropes() -> void:
	for i: int in ROPE_COUNT:
		var z: float = ROPE_Z0 + ROPE_STEP * float(i)
		# 坡道上方的幾條跟著坡面墊高（人走在坡上不會撞到）
		var lift_up: float = ground_y(Vector3(0.0, 0.0, z)) * 0.85
		var a := Vector3(-(STREET_HALF + 1.1), lift_up + _rng.randf_range(3.9, 5.3), z + _rng.randf_range(-0.7, 0.7))
		var b := Vector3(STREET_HALF + 1.1, lift_up + _rng.randf_range(3.9, 5.3), z + _rng.randf_range(-0.7, 0.7))
		var sag: float = _rng.randf_range(0.35, 0.65)
		var segments: int = 10
		for s: int in segments:
			_rod(rope_point(a, b, sag, float(s) / float(segments)), rope_point(a, b, sag, float(s + 1) / float(segments)), 0.012, _rope, 5)
		if i % 2 == 0:
			var n: int = _rng.randi_range(3, 5)
			for k: int in n:
				var t: float = (float(k) + _rng.randf_range(0.3, 0.7)) / float(n)
				var p: Vector3 = rope_point(a, b, sag, t) - Vector3(0.0, 0.26, 0.0)
				_rod(p + Vector3(0.0, 0.26, 0.0), p + Vector3(0.0, 0.17, 0.0), 0.005, _rope, 4)
				# 顏色照舊先抽（_rng 的順序不變）；藥店前面那幾條繩子上的換成綠的（D-230：從高台看，街底是一串綠燈籠）
				var paper_index: float = float(_rng.randi_range(0, PAPER_COLORS.size() - 1))
				if z >= SHOP_Z - SHOP_PAPER_REACH:
					paper_index = -1.0
					shop_paper_count += 1
				_paper.append(Vector4(p.x, p.y, p.z, paper_index))
			var mid: Vector3 = rope_point(a, b, sag, 0.5) - Vector3(0.0, 0.5, 0.0)
			_light("RopeGlow%d" % i, mid, LAMP, 0.95, 6.5, false, 1.7)
		else:
			_pennants(a, b, sag, i)


## 一條繩上的三角旗（跟布棚同一批布，會透光）。
func _pennants(a: Vector3, b: Vector3, sag: float, salt: int) -> void:
	var n: int = 11
	for k: int in n:
		var t0: float = (float(k) + 0.18) / float(n)
		var t1: float = (float(k) + 0.82) / float(n)
		var p0: Vector3 = rope_point(a, b, sag, t0)
		var p1: Vector3 = rope_point(a, b, sag, t1)
		var tip: Vector3 = (p0 + p1) * 0.5 - Vector3(0.0, 0.34, 0.0) + Vector3(0.0, 0.0, _rng.randf_range(-0.05, 0.05))
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for pair: Array in [[p0, Vector2(0.0, 0.0)], [p1, Vector2(0.35, 0.0)], [tip, Vector2(0.17, 0.6)]]:
			st.set_uv(pair[1] as Vector2)
			st.add_vertex(pair[0] as Vector3)
		st.generate_normals()
		_batch.add_mesh(st.commit(), Transform3D.IDENTITY, _cloths[(k + salt) % _cloths.size()])


## 紙燈籠：全部一個 MultiMesh（一個 draw call），顏色放在 instance color。
func _build_paper_lanterns() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.38
	sphere.radial_segments = 12
	sphere.rings = 8
	var mat := ShaderMaterial.new()
	mat.shader = load(LANTERN_SHADER) as Shader
	sphere.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = sphere
	mm.instance_count = _paper.size()
	for i: int in _paper.size():
		var p: Vector4 = _paper[i]
		var s: float = 0.85 + 0.3 * fposmod(p.x * 7.3 + p.z * 3.1, 1.0)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(s, s, s)), Vector3(p.x, p.y, p.z)))
		mm.set_instance_color(i, paper_color(p.w))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "PaperLanterns"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.layers |= REFLECT_LAYER
	add_child(mmi)
	paper_lantern_count = _paper.size()


## 紙燈籠的顏色：編號 0 以上＝PAPER_COLORS 的那一個；負的＝藥店前面的綠燈籠。
static func paper_color(index: float) -> Color:
	return SHOP_PAPER if index < 0.0 else PAPER_COLORS[int(index)]


## 街底：彌夏的藥店。深色木板的門面、左邊一扇門、右邊一大片綠色的格子玻璃窗（整條街的視線終點），門上掛一塊壺形招牌。
func _build_shop() -> void:
	var face_z: float = SHOP_Z
	var front: ShaderMaterial = interior.plank("shop_front", Color(0.15, 0.11, 0.08), 0.26, 3.0, {"vertical_planks": true})
	# 門面的牆在門洞那裡斷開（D-231：可以走進去）：門的西邊、東邊、門楣以上各一塊
	var door_w: float = SHOP_DOOR.x - SHOP_DOOR_W * 0.5
	var door_e: float = SHOP_DOOR.x + SHOP_DOOR_W * 0.5
	_batch.add_box_at(Vector3(door_w + WALL_X, 4.4, 0.5), Vector3((door_w - WALL_X) * 0.5, 2.2, face_z + 0.25), front)
	_batch.add_box_at(Vector3(WALL_X - door_e, 4.4, 0.5), Vector3((door_e + WALL_X) * 0.5, 2.2, face_z + 0.25), front)
	_batch.add_box_at(Vector3(SHOP_DOOR_W, 4.4 - SHOP_DOOR_H, 0.5), Vector3(SHOP_DOOR.x, (4.4 + SHOP_DOOR_H) * 0.5, face_z + 0.25), front)
	_batch.add_box_at(Vector3(WALL_X * 2.0, CEILING_Y - 4.4, 1.2), Vector3(0.0, 4.4 + (CEILING_Y - 4.4) * 0.5, face_z + 0.6), _rock, false)
	# 門面上緣一根大橫木、兩側的柱子
	_batch.add_box_at(Vector3(WALL_X * 2.0, 0.3, 0.62), Vector3(0.0, 4.3, face_z + 0.2), _timber, false)
	for x: float in [-WALL_X + 0.2, -0.55, 3.65, WALL_X - 0.2]:
		_batch.add_box_at(Vector3(0.26, 4.2, 0.6), Vector3(x, 2.1, face_z + 0.2), _timber, false)
	# 門
	# 門開著：門板整個推到底、貼在店裡的牆上（兩條鐵件；不立在門邊，鏡頭才不會被它擋住），門框是三根方木
	var leaf_at := Vector3(door_w - 0.62, 1.1, face_z + 0.5 + 0.05)
	_batch.add_box_at(Vector3(1.16, 2.16, 0.07), leaf_at, front, false)
	for strap_y: float in [0.45, 1.75]:
		_batch.add_box_at(Vector3(1.0, 0.07, 0.09), Vector3(leaf_at.x, strap_y, leaf_at.z), _iron, false)
	for jamb_x: float in [door_w - 0.05, door_e + 0.05]:
		_batch.add_box_at(Vector3(0.1, SHOP_DOOR_H, 0.56), Vector3(jamb_x, SHOP_DOOR_H * 0.5, face_z + 0.25), _timber, false)
	_batch.add_box_at(Vector3(SHOP_DOOR_W + 0.2, 0.1, 0.56), Vector3(SHOP_DOOR.x, SHOP_DOOR_H + 0.05, face_z + 0.25), _timber, false)
	_batch.add_box_at(Vector3(1.7, 0.16, 0.9), Vector3(SHOP_DOOR.x, 0.08, face_z - 0.45), interior.flagstone("shop_step", Color(0.24, 0.22, 0.2), 0.6), false)
	# 綠色格子窗（D-230：門面幾乎整片是玻璃，以前只有 4×3 格、從高台看是一個小方塊）：
	# 主窗 4×4 格（門右邊到柱子）、東邊窄窗 2×4 格、門與西半邊上面一排氣窗 5×2 格（壺形招牌逆著它變成剪影）
	var glass: ShaderMaterial = look.window().duplicate() as ShaderMaterial
	glass.set_shader_parameter("glow_color", SHOP_GREEN)
	glass.set_shader_parameter("far_boost", SHOP_GLASS_FAR_BOOST)
	glass.set_shader_parameter("far_saturate", SHOP_GLASS_FAR_SATURATE)
	var transom_y0: float = SHOP_WINDOW_Y0 + float(SHOP_WINDOW_ROWS - SHOP_TRANSOM_ROWS) * SHOP_PANE_H
	# [左緣 x, 一格多寬, 幾格, 最下面一格的底, 幾列]
	for bay: Array in [
		[0.05, 0.84, 4, SHOP_WINDOW_Y0, SHOP_WINDOW_ROWS],
		[3.8, 0.635, 2, SHOP_WINDOW_Y0, SHOP_WINDOW_ROWS],
		[-5.05, 0.872, 5, transom_y0, SHOP_TRANSOM_ROWS],
	]:
		var pitch: float = float(bay[1])
		for cx: int in int(bay[2]):
			for ry: int in int(bay[4]):
				var pane := Vector3(float(bay[0]) + (float(cx) + 0.5) * pitch, float(bay[3]) + (float(ry) + 0.5) * SHOP_PANE_H, face_z - 0.03)
				_batch.add_box_tinted(Vector3(pitch - 0.04, SHOP_PANE_H - 0.04, 0.08), pane, glass, FrostbridgeLook.window_tint(true, pane, 4.0), false)
				shop_glass_area += (pitch - 0.04) * (SHOP_PANE_H - 0.04)
	# 窗裡架上的瓶子（逆著綠光只看得到剪影）；前兩層用 _rng（跟以前一樣），上面兩層用寫死的雜湊（不多抽 _rng）
	var dark: Material = look.mat(Color(0.03, 0.035, 0.03), 0.4)
	for shelf: int in SHOP_WINDOW_ROWS:
		var y: float = SHOP_WINDOW_Y0 + 0.34 + float(shelf) * SHOP_PANE_H
		_batch.add_box_at(Vector3(3.3, 0.03, 0.05), Vector3(1.73, y - 0.01, face_z - 0.09), dark, false)
		for i: int in 11:
			var h: float
			var r: float
			if shelf < 2:
				h = _rng.randf_range(0.14, 0.3)
				r = _rng.randf_range(0.035, 0.065)
			else:
				h = lerpf(0.14, 0.3, fposmod(sin(float(shelf * 31 + i * 17) * 12.9898) * 43758.5453, 1.0))
				r = lerpf(0.035, 0.065, fposmod(sin(float(shelf * 13 + i * 29) * 78.233) * 43758.5453, 1.0))
			_batch.add_cylinder(r * 0.45, r, h, Vector3(0.25 + float(i) * 0.3, y + h * 0.5, face_z - 0.09), dark, false, 8)
	# 氣窗底下一根橫木（門楣）
	_batch.add_box_at(Vector3(4.5, 0.14, 0.2), Vector3(-2.87, transom_y0 - 0.07, face_z - 0.06), _timber, false)
	# 窗台
	_batch.add_box_at(Vector3(3.6, 0.1, 0.3), Vector3(1.73, 0.95, face_z - 0.12), _timber, false)
	_batch.add_box_at(Vector3(1.35, 0.1, 0.3), Vector3(4.43, 0.95, face_z - 0.12), _timber, false)
	# 招牌：壺的剪影（door.gdshader 的店招模式，r＝0.5），伸出來的鐵架上
	var sign_pos := Vector3(SHOP_DOOR.x, 3.0, face_z - 0.75)
	_batch.add_box_tinted(Vector3(0.7, 0.56, 0.06), sign_pos, look.door(), Color(0.5, 0.4, 0.3, 0.0), false)
	_rod(Vector3(SHOP_DOOR.x, 3.42, face_z), Vector3(SHOP_DOOR.x, 3.42, face_z - 1.1), 0.02, _iron)
	for dx: float in [-0.28, 0.28]:
		_rod(sign_pos + Vector3(dx, 0.28, 0.0), sign_pos + Vector3(dx, 0.42, 0.0), 0.008, _iron, 4)
	# 門邊一盞暖燈；窗前的綠光（進霧：街底一團綠色的光暈）
	_box_lantern(Vector3(SHOP_DOOR.x - 0.85, 2.3, face_z - 0.3), 0.18, LAMP, 5.0)
	_light("ShopDoorLamp", Vector3(SHOP_DOOR.x - 0.7, 2.2, face_z - 0.6), LAMP, 1.3, 5.0, false, 0.8)
	# 遠看的綠靠窗本身的發光與霧裡的光暈；這盞燈只照亮窗前幾步（D-229：以前 4.5／12 m，站在門口整個畫面都是綠的）
	shop_light = _light("ShopGlow", Vector3(1.75, 2.1, face_z - 1.3), SHOP_GREEN, SHOP_GLOW_ENERGY, SHOP_GLOW_RANGE, false, 4.5)
	var door_marker := Marker3D.new()
	door_marker.name = "MishaShopDoor"
	door_marker.position = SHOP_DOOR + Vector3(0.0, 1.0, 0.0)
	add_child(door_marker)


# ---------------------------------------------------------------- 店內（D-231）：櫃台、藥架、彌夏、測試板

## 位置雜湊（0～1）：店裡的東西都用這個決定大小與顏色，不抽 _rng（多抽一次，街上的攤子全部會變）
static func _hash01(a: float, b: float) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)


func _build_shop_interior() -> void:
	var n: float = SHOP_INNER_Z
	var s: float = SHOP_ROOM_S
	var half: float = SHOP_ROOM_HALF
	var mid_z: float = (n + s) * 0.5
	var depth: float = s - n
	var floor_mat: ShaderMaterial = interior.plank("shop_floor", Color(0.2, 0.145, 0.1), 0.2, 2.4, {"wear": 0.35})
	var wall_mat: ShaderMaterial = interior.plank("shop_wall", Color(0.165, 0.12, 0.085), 0.24, 3.0, {"vertical_planks": true})
	var counter_mat: ShaderMaterial = interior.plank("shop_counter", Color(0.25, 0.165, 0.1), 0.18, 1.6, {"vertical_planks": true})
	# 地板：看得到的木板不擋人；洞的岩盤只到 CAVE_S，後面補一塊一樣高的碰撞
	_batch.add_box_at(Vector3(half * 2.0, 0.04, depth), Vector3(0.0, 0.012, mid_z), floor_mat, false)
	var slab := BoxShape3D.new()
	slab.size = Vector3(half * 2.0 + 1.0, 1.0, s + 1.0 - CAVE_S)
	_batch.add_shape(Transform3D(Basis(), Vector3(0.0, -0.5, (s + 1.0 + CAVE_S) * 0.5)), slab)
	# 東西兩面牆、南牆、天花板與三根樑
	for side: float in [-1.0, 1.0]:
		_batch.add_box_at(Vector3(0.3, SHOP_ROOM_H, depth), Vector3(side * (half + 0.15), SHOP_ROOM_H * 0.5, mid_z), wall_mat)
	_batch.add_box_at(Vector3(half * 2.0 + 0.6, SHOP_ROOM_H, 0.3), Vector3(0.0, SHOP_ROOM_H * 0.5, s + 0.15), wall_mat)
	_batch.add_box_at(Vector3(half * 2.0 + 0.6, 0.3, depth + 0.3), Vector3(0.0, SHOP_ROOM_H + 0.15, mid_z + 0.15), wall_mat)
	var beam_zs: Array[float] = [n + 1.0, COUNTER_Z - 0.5, s - 1.0]
	for bz: float in beam_zs:
		_batch.add_box_at(Vector3(half * 2.0, 0.22, 0.2), Vector3(0.0, SHOP_ROOM_H - 0.11, bz), _timber, false)

	# 櫃台：直板的正面＋一整塊厚木的檯面
	_batch.add_box_at(Vector3(COUNTER_LEN, COUNTER_TOP - 0.06, 0.7), Vector3(COUNTER_X, (COUNTER_TOP - 0.06) * 0.5, COUNTER_Z), counter_mat)
	_batch.add_box_at(Vector3(COUNTER_LEN + 0.16, 0.06, 0.86), Vector3(COUNTER_X, COUNTER_TOP - 0.03, COUNTER_Z), _timber, false)
	_batch.add_box_at(Vector3(COUNTER_LEN + 0.04, 0.12, 0.05), Vector3(COUNTER_X, 0.06, COUNTER_Z - 0.37), _timber, false)

	# 發光的藥：綠的最多、幾瓶琥珀色；深色的是空瓶或不透光的
	var green: Material = look.glow(Color(0.24, 0.92, 0.46), 1.7)
	var amber: Material = look.glow(Color(1.0, 0.6, 0.2), 1.3)
	var dark_glass: Material = look.mat(Color(0.05, 0.075, 0.06), 0.3)
	var cork: Material = look.mat(Color(0.42, 0.32, 0.2), 0.9)
	# 南牆的藥架：三層，每層一排瓶子
	var shelf_z: float = s - 0.16
	for row: int in 3:
		var y: float = 1.12 + float(row) * 0.62
		_batch.add_box_at(Vector3(half * 2.0 - 0.5, 0.045, 0.3), Vector3(0.0, y, shelf_z), _timber, false)
		for i: int in 29:
			var x: float = -4.06 + float(i) * 0.29
			var h1: float = _hash01(float(row * 31 + i), 3.7)
			var h2: float = _hash01(float(i * 7 + row), 9.1)
			if h1 < 0.12:
				continue  # 空位
			var mat: Material = green if h2 < 0.56 else (amber if h2 < 0.72 else dark_glass)
			_bottle(Vector3(x, y + 0.022, shelf_z - 0.02 + (h1 - 0.5) * 0.08), lerpf(0.045, 0.075, h1), lerpf(0.16, 0.3, h2), mat, cork)
	for post_x: float in [-4.32, -1.45, 1.45, 4.32]:
		_batch.add_box_at(Vector3(0.07, 2.0, 0.3), Vector3(post_x, 1.72, shelf_z), _timber, false)

	# 西牆的抽屜櫃（藥材）：四排六格，每格一顆銅鈕
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.72, 0.54, 0.24)
	brass.metallic = 0.9
	brass.roughness = 0.38
	var cab_x: float = -half + 0.27
	var cab_z0: float = COUNTER_Z - 1.3
	_batch.add_box_at(Vector3(0.54, 2.1, 2.7), Vector3(cab_x, 1.05, cab_z0 + 1.2), counter_mat)
	_batch.add_box_at(Vector3(0.62, 0.07, 2.8), Vector3(cab_x, 2.13, cab_z0 + 1.2), _timber, false)
	for row: int in 4:
		for col: int in 6:
			var at := Vector3(cab_x + 0.28, 0.36 + float(row) * 0.47, cab_z0 + 0.1 + float(col) * 0.44)
			var shade: float = lerpf(0.75, 1.1, _hash01(float(row * 6 + col), 5.3))
			_batch.add_box_at(Vector3(0.03, 0.4, 0.38), at, look.mat(Color(0.2, 0.135, 0.085) * shade, 0.75), false)
			_batch.add_sphere(0.022, at + Vector3(0.03, 0.0, 0.0), brass)

	# 東牆的工作台：蒸餾用的銅壺、三顆大燒瓶（最亮的一團綠）、一疊木箱與一個桶
	var bench_x: float = half - 0.42
	_batch.add_box_at(Vector3(0.78, 0.84, 2.3), Vector3(bench_x, 0.42, n + 1.75), counter_mat)
	_batch.add_box_at(Vector3(0.86, 0.06, 2.4), Vector3(bench_x, 0.87, n + 1.75), _timber, false)
	var copper := StandardMaterial3D.new()
	copper.albedo_color = Color(0.74, 0.4, 0.22)
	copper.metallic = 0.85
	copper.roughness = 0.34
	var still := Vector3(bench_x, 0.9 + 0.24, n + 0.95)
	_batch.add_sphere(0.24, still, copper)
	_batch.add_cylinder(0.05, 0.13, 0.26, still + Vector3(0.0, 0.3, 0.0), copper, false, 10)
	_rod(still + Vector3(0.0, 0.42, 0.0), still + Vector3(-0.05, 0.3, 0.62), 0.018, copper)
	var flask_r: Array[float] = [0.15, 0.11, 0.17]
	for i: int in 3:
		var r: float = flask_r[i]
		var at := Vector3(bench_x - 0.05 + 0.1 * float(i % 2), 0.9 + r, n + 1.6 + float(i) * 0.46)
		_batch.add_sphere(r, at, green)
		_batch.add_cylinder(r * 0.22, r * 0.3, r * 1.1, at + Vector3(0.0, r * 1.35, 0.0), dark_glass, false, 8)
	var crate: Material = look.door()
	var crate_size: Array[float] = [0.62, 0.52, 0.44]
	var crate_y: Array[float] = [0.0, 0.62, 0.0]
	for i: int in 3:
		var size: float = crate_size[i]
		var base_y: float = crate_y[i]
		var at := Vector3(half - 0.5 - (0.72 if i == 2 else 0.0), base_y + size * 0.5, s - 0.75 + (0.1 if i == 1 else 0.0))
		_batch.add_box_tinted(Vector3(size, size, size), at, crate, FrostbridgeLook.crate_tint(at), false)
	_barrel(Vector3(COUNTER_X + COUNTER_LEN * 0.5 + 0.55, 0.0, COUNTER_Z + 0.1))

	# 櫃台上：研缽、帳本、幾瓶要賣的
	var stone: Material = look.mat(Color(0.34, 0.33, 0.31), 0.7)
	_batch.add_cylinder(0.1, 0.065, 0.11, Vector3(-0.9, COUNTER_TOP + 0.055, COUNTER_Z + 0.05), stone, false, 12)
	_rod(Vector3(-0.9, COUNTER_TOP + 0.08, COUNTER_Z + 0.05), Vector3(-0.77, COUNTER_TOP + 0.24, COUNTER_Z - 0.02), 0.016, stone)
	_batch.add_box_at(Vector3(0.34, 0.035, 0.25), Vector3(-2.35, COUNTER_TOP + 0.018, COUNTER_Z), _paper_tag, false)
	_batch.add_box_at(Vector3(0.36, 0.012, 0.27), Vector3(-2.35, COUNTER_TOP + 0.004, COUNTER_Z), look.mat(Color(0.3, 0.1, 0.08), 0.8), false)
	for i: int in 5:
		var h: float = _hash01(float(i), 2.2)
		_bottle(Vector3(1.45 + float(i) * 0.21, COUNTER_TOP, COUNTER_Z - 0.12 + h * 0.2), lerpf(0.04, 0.06, h), lerpf(0.15, 0.24, 1.0 - h), amber if i == 3 else green, cork)

	# 樑上掛著曬乾的藥草（倒掛的一束一束）
	var herbs: Array[Material] = [look.mat(Color(0.19, 0.23, 0.13), 0.95), look.mat(Color(0.27, 0.21, 0.13), 0.95), look.mat(Color(0.24, 0.2, 0.26), 0.95)]
	for i: int in 16:
		var bz: float = beam_zs[i % 2]
		var x: float = -4.0 + float(i) * 0.53
		var h: float = _hash01(float(i), 6.6)
		if absf(x - BOARD_POS.x - 0.9) < 0.45 and i % 2 == 1:
			continue  # 吊燈的位置
		var bundle: float = lerpf(0.28, 0.46, h)
		var top := Vector3(x, SHOP_ROOM_H - 0.22, bz + (h - 0.5) * 0.1)
		_rod(top, top - Vector3(0.0, 0.14, 0.0), 0.006, _rope, 4)
		_batch.add_cylinder(0.016, lerpf(0.045, 0.075, h), bundle, top - Vector3(0.0, 0.14 + bundle * 0.5, 0.0), herbs[i % herbs.size()], false, 7)

	# 光：櫃台上方一盞暖色吊燈（照亮測試板與彌夏的臉）；藥架的綠光從她背後打過來
	var lamp_at := Vector3(BOARD_POS.x + 0.9, 2.3, COUNTER_Z - 0.5)
	_rod(Vector3(lamp_at.x, SHOP_ROOM_H - 0.22, lamp_at.z), lamp_at + Vector3(0.0, 0.14, 0.0), 0.01, _iron, 4)
	# 燈本身不要太亮（5.0 的時候在畫面上是一塊純白的方塊）
	_box_lantern(lamp_at, 0.17, LAMP_DEEP, 2.0)
	_light("ShopCounterLamp", lamp_at - Vector3(0.0, 0.25, 0.1), LAMP, 2.6, 5.0, false, 0.5)
	_light("ShopShelfGlow", Vector3(0.0, 1.9, s - 0.75), SHOP_GREEN, 1.0, 3.8, false, 0.4)
	_light("ShopBenchGlow", Vector3(bench_x - 0.5, 1.3, n + 2.0), SHOP_GREEN, 0.7, 2.6, false, 0.3)
	# 西半邊：抽屜櫃頂上一盞小燈（不然站在櫃台前，畫面右邊三分之一是全黑的）
	var cab_lamp := Vector3(cab_x + 0.02, 2.3, cab_z0 + 0.45)
	_box_lantern(cab_lamp, 0.13, LAMP_DEEP, 2.0)
	_light("ShopCabinetLamp", cab_lamp + Vector3(0.7, -0.1, 0.4), LAMP, 1.5, 4.2, false, 0.3)

	# 彌夏：站在櫃台後面、面向門（深綠的工作服、淺色的圍裙邊）
	misha = Puppet.new()
	misha.name = "Misha"
	misha.coat_color = Color(0.15, 0.27, 0.23)
	misha.trim_color = Color(0.76, 0.7, 0.56)
	misha.position = MISHA_POS
	misha.scale = Vector3.ONE * 0.95
	add_child(misha)
	var hammer: Node = misha.hand("R").get_node_or_null("BellHammer") if misha.hand("R") != null else null
	if hammer != null:
		hammer.queue_free()
	var board_marker := Marker3D.new()
	board_marker.name = "MishaTestBoard"
	board_marker.position = BOARD_POS + Vector3(0.0, 0.5, 0.0)
	add_child(board_marker)


## 一個藥瓶：瓶身＋瓶頸＋軟木塞。base＝瓶底中心。
func _bottle(base: Vector3, radius: float, height: float, glass: Material, cork: Material) -> void:
	_batch.add_cylinder(radius * 0.86, radius, height, base + Vector3(0.0, height * 0.5, 0.0), glass, false, 8)
	_batch.add_cylinder(radius * 0.3, radius * 0.4, height * 0.34, base + Vector3(0.0, height * 1.17, 0.0), glass, false, 6)
	_batch.add_cylinder(radius * 0.34, radius * 0.34, 0.025, base + Vector3(0.0, height * 1.34 + 0.012, 0.0), cork, false, 6)
	shop_bottle_count += 1


## 測試板（會動，不進合併的場景）：石板底座、銅的手掌盤、往後斜的刻度盤（東邊紅＝受傷、西邊綠＝回復）、指針、一顆綠燈。
func _build_test_board() -> void:
	test_board = Node3D.new()
	test_board.name = "TestBoard"
	test_board.position = BOARD_POS
	add_child(test_board)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.74, 0.56, 0.25)
	brass.metallic = 0.9
	brass.roughness = 0.34
	_board_part(test_board, _box_mesh(Vector3(0.58, 0.05, 0.38)), Vector3(0.0, 0.025, 0.0), look.mat(Color(0.085, 0.095, 0.105), 0.45))
	var plate := CylinderMesh.new()
	plate.top_radius = 0.115
	plate.bottom_radius = 0.125
	plate.height = 0.016
	plate.radial_segments = 20
	_board_part(test_board, plate, Vector3(0.0, 0.058, -0.06), brass)
	# 刻度盤：往後斜 20 度，正面朝客人
	var dial := Node3D.new()
	dial.name = "Dial"
	dial.position = Vector3(0.0, 0.05, 0.13)
	dial.rotation_degrees.x = 20.0
	test_board.add_child(dial)
	_board_part(dial, _box_mesh(Vector3(0.46, 0.27, 0.02)), Vector3(0.0, 0.135, 0.0), look.mat(Color(0.8, 0.74, 0.6), 0.85))
	_board_part(dial, _box_mesh(Vector3(0.5, 0.31, 0.012)), Vector3(0.0, 0.135, 0.012), brass)
	# 兩邊的色塊與中間的刻度
	_board_part(dial, _box_mesh(Vector3(0.12, 0.05, 0.004)), Vector3(0.15, 0.2, -0.012), look.mat(Color(0.62, 0.12, 0.08), 0.7))
	_board_part(dial, _box_mesh(Vector3(0.12, 0.05, 0.004)), Vector3(-0.15, 0.2, -0.012), look.mat(Color(0.14, 0.5, 0.24), 0.7))
	var ink: Material = look.mat(Color(0.1, 0.08, 0.07), 0.8)
	for i: int in 7:
		var a: float = deg_to_rad(-60.0 + float(i) * 20.0)
		var tick := _board_part(dial, _box_mesh(Vector3(0.006, 0.03 if i != 3 else 0.045, 0.004)), Vector3(-sin(a) * 0.17, 0.03 + cos(a) * 0.17, -0.012), ink)
		tick.rotation.z = a
	board_needle = Node3D.new()
	board_needle.name = "Needle"
	board_needle.position = Vector3(0.0, 0.03, -0.016)
	dial.add_child(board_needle)
	_board_part(board_needle, _box_mesh(Vector3(0.012, 0.175, 0.005)), Vector3(0.0, 0.0875, 0.0), look.mat(Color(0.05, 0.04, 0.04), 0.5))
	_board_part(board_needle, _box_mesh(Vector3(0.03, 0.03, 0.008)), Vector3.ZERO, brass)
	# 綠燈：讀到「回復」才亮
	_board_lamp_mat = StandardMaterial3D.new()
	_board_lamp_mat.albedo_color = Color(0.1, 0.2, 0.13)
	_board_lamp_mat.roughness = 0.3
	_board_lamp_mat.emission_enabled = true
	_board_lamp_mat.emission = SHOP_GREEN
	_board_lamp_mat.emission_energy_multiplier = 0.0
	var bulb := SphereMesh.new()
	bulb.radius = 0.024
	bulb.height = 0.048
	bulb.radial_segments = 12
	bulb.rings = 6
	board_lamp = _board_part(dial, bulb, Vector3(-0.19, 0.3, -0.004), _board_lamp_mat)
	board_lamp.name = "Lamp"
	board_lamp_light = OmniLight3D.new()
	board_lamp_light.name = "LampLight"
	board_lamp_light.light_color = SHOP_GREEN
	board_lamp_light.light_energy = 0.0
	board_lamp_light.omni_range = 1.8
	board_lamp_light.shadow_enabled = false
	board_lamp_light.position = Vector3(-0.19, 0.3, -0.06)
	dial.add_child(board_lamp_light)


static func _box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _board_part(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


## 手放上去的進度 0～1：指針慢慢往「受傷」那邊偏（板子正在下毒，照理說該往那邊走）
func set_board_progress(t: float) -> void:
	board_target_deg = BOARD_HURT_DEG * clampf(t, 0.0, 1.0)
	board_lamp_on = false


## 板子讀到的結果：true＝在回復（指針甩到另一邊、綠燈亮）
func set_board_healing(on: bool) -> void:
	board_target_deg = BOARD_HEAL_DEG if on else 0.0
	board_lamp_on = on


## 指針現在擺到幾度（不含抖動）
func board_needle_deg() -> float:
	return _board_deg


func _animate_board(delta: float) -> void:
	if board_needle == null:
		return
	_board_deg = move_toward(_board_deg, board_target_deg, BOARD_NEEDLE_SPEED * delta)
	# 到位之後指針還會微微抖（讀數在跳）
	var settled: bool = is_equal_approx(_board_deg, board_target_deg) and absf(board_target_deg) > 1.0
	board_needle.rotation_degrees.z = _board_deg + (1.6 * sin(_time * 17.0) if settled else 0.0)
	var want: float = BOARD_LAMP_ENERGY if board_lamp_on else 0.0
	board_lamp_light.light_energy = move_toward(board_lamp_light.light_energy, want, delta * 3.0)
	_board_lamp_mat.emission_energy_multiplier = board_lamp_light.light_energy / BOARD_LAMP_ENERGY * 4.0


# ---------------------------------------------------------------- 小工具

## 方形小燈：發光的玻璃＋鐵的上下蓋。at＝燈的中心。
func _box_lantern(at: Vector3, size: float, color: Color, energy: float) -> void:
	_batch.add_box_at(Vector3(size, size * 1.3, size), at, look.glow(color, energy), false)
	_batch.add_box_at(Vector3(size * 1.25, size * 0.16, size * 1.25), at + Vector3(0.0, size * 0.73, 0.0), _iron, false)
	_batch.add_box_at(Vector3(size * 1.15, size * 0.12, size * 1.15), at - Vector3(0.0, size * 0.71, 0.0), _iron, false)


func _light(light_name: String, at: Vector3, color: Color, energy: float, light_range: float, shadows: bool, fog: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = light_name
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.3
	l.shadow_enabled = shadows
	l.light_specular = 0.8
	l.light_volumetric_fog_energy = fog
	l.position = at
	add_child(l, true)
	light_count += 1
	if shadows:
		shadow_light_count += 1
	return l


## Y 軸對準 d 的 Basis（圓桿、斜樑用）。
static func _basis_y_along(d: Vector3) -> Basis:
	var y: Vector3 = d.normalized()
	var x: Vector3 = y.cross(Vector3.BACK)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	return Basis(x, y, x.cross(y))


## Z 軸對準 d 的 Basis（欄杆的碰撞盒用）。
static func _basis_along(d: Vector3) -> Basis:
	var z: Vector3 = d.normalized()
	var x: Vector3 = Vector3.UP.cross(z)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, z.cross(x), z)


## 圓桿：a → b。
func _rod(a: Vector3, b: Vector3, radius: float, mat: Material, segments: int = 6) -> void:
	var d: Vector3 = b - a
	if d.length() < 0.001:
		return
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = d.length()
	m.radial_segments = segments
	m.rings = 1
	_batch.add_mesh(m, Transform3D(_basis_y_along(d), (a + b) * 0.5), mat)


## 方木：a → b。
func _beam(a: Vector3, b: Vector3, thick: float, mat: Material) -> void:
	var d: Vector3 = b - a
	if d.length() < 0.001:
		return
	_batch.add_box(Vector3(thick, d.length(), thick), Transform3D(_basis_y_along(d), (a + b) * 0.5), mat, false)


## 街面石板上的倒影：街的北半、南半各一個（只拍一次；只拍合併的場景與紙燈籠）。
func _build_probes(market: Node3D) -> void:
	for c: Node in market.get_children():
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi != null:
			mi.layers |= REFLECT_LAYER
	_probe("ProbeStreetN", RAMP_S - 1.0, (RAMP_S + SHOP_Z) * 0.5)
	_probe("ProbeStreetS", (RAMP_S + SHOP_Z) * 0.5, SHOP_Z + 0.4)


func _probe(probe_name: String, z_from: float, z_to: float) -> void:
	var height: float = 8.0
	var p := ReflectionProbe.new()
	p.name = probe_name
	p.update_mode = ReflectionProbe.UPDATE_ONCE
	p.box_projection = true
	p.cull_mask = REFLECT_LAYER
	p.size = Vector3(WALL_X * 2.0, height, z_to - z_from)
	p.position = Vector3(0.0, -0.5 + height * 0.5, (z_from + z_to) * 0.5)
	p.origin_offset = Vector3(0.0, 2.0 - height * 0.5, 0.0)
	p.blend_distance = 1.5
	p.intensity = 2.0
	add_child(p)
