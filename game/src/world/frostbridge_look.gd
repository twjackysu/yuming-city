class_name FrostbridgeLook
extends RefCounted
## 霜橋鎮的「樣子」：冬夜環境（AgX、體積霧、月光）與共用色盤／材質。
## 沙盒和霜橋鎮共用，畫質分級由 QualityPreset 在場景載入後套用（docs/design/03-art-audio-direction.md）。

const STONE: Color = Color(0.26, 0.28, 0.32)
const COBBLE: Color = Color(0.22, 0.23, 0.26)
const WALL: Color = Color(0.18, 0.19, 0.22)
const WALL_WARM: Color = Color(0.21, 0.19, 0.18)
const ROOF: Color = Color(0.11, 0.11, 0.13)
const WOOD: Color = Color(0.24, 0.17, 0.12)
const SNOW: Color = Color(0.66, 0.71, 0.78)
const LAMP: Color = Color(0.95, 0.72, 0.42)
const MOON: Color = Color(0.55, 0.65, 0.85)

## 同一種顏色共用同一個材質（StaticBatch 依材質合併）
var _mats: Dictionary = {}


## WorldEnvironment＋月光，加到 parent 底下。回傳 Environment（測試／截圖用）。
static func build_environment(parent: Node3D) -> Environment:
	var env := Environment.new()
	# 冬夜天空（D-117）：雲、月光、遠山稜線。霧只蓋掉天空的一部分，不然整片又是霧色。
	env.background_mode = Environment.BG_SKY
	env.background_color = Color(0.03, 0.04, 0.07)
	env.sky = night_sky()
	env.volumetric_fog_sky_affect = SKY_FOG_AFFECT
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.38, 0.55)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.2
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.03
	env.volumetric_fog_albedo = Color(0.62, 0.68, 0.8)
	env.volumetric_fog_emission = Color(0.045, 0.06, 0.1)
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_length = 80.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85
	env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	parent.add_child(we)

	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = MOON
	moon.light_energy = 0.6
	moon.light_volumetric_fog_energy = 1.5
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	moon.rotation_degrees = Vector3(-38.0, 35.0, 0.0)
	parent.add_child(moon)
	return env


const NIGHT_SKY_SHADER: String = "res://src/world/night_sky.gdshader"
## 霧對天空的影響（體積霧與低畫質的一般霧共用）：1.0 會把天空整片蓋成霧色
const SKY_FOG_AFFECT: float = 0.4


## 冬夜天空（night_sky.gdshader）。不用 TIME，反射用的 radiance 只算一次。
static func night_sky() -> Sky:
	var m := ShaderMaterial.new()
	m.shader = load(NIGHT_SKY_SHADER) as Shader
	var sky := Sky.new()
	sky.sky_material = m
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	return sky


func mat(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var key: String = "%s/%.2f" % [color.to_html(), roughness]
	if _mats.has(key):
		return _mats[key] as StandardMaterial3D
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	_mats[key] = m
	return m


## 發光材質（窗、燈泡）。
func glow(color: Color, energy: float) -> StandardMaterial3D:
	var key: String = "glow/%s/%.2f" % [color.to_html(), energy]
	if _mats.has(key):
		return _mats[key] as StandardMaterial3D
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_mats[key] = m
	return m


const WET_COBBLE_SHADER: String = "res://src/world/wet_cobble.gdshader"
## 弧形鋪（廣場）遠處石塊淡成平均值的速度（wet_cobble 的 far_fade；直排街道用 shader 預設 1.2，D-144）
const ARC_FAR_FADE: float = 1.9
const HALF_TIMBER_SHADER: String = "res://src/world/half_timber.gdshader"
const WINDOW_SHADER: String = "res://src/world/window_glass.gdshader"
const SNOW_SHADER: String = "res://src/world/snow.gdshader"
const DOOR_SHADER: String = "res://src/world/door.gdshader"
const ROOF_TILES_SHADER: String = "res://src/world/roof_tiles.gdshader"
## 灰泥色（月光下偏冷／偏暖兩種），石牆的石頭色
const PLASTER: Color = Color(0.4, 0.4, 0.41)
const PLASTER_WARM: Color = Color(0.45, 0.4, 0.34)
const WALL_STONE: Color = Color(0.26, 0.27, 0.3)


## 半木構外牆（half_timber.gdshader）：一樓石牆、樓上灰泥＋木框。plaster 用 PLASTER／PLASTER_WARM。
func half_timber(plaster: Color) -> ShaderMaterial:
	return _wall_material("timber/%s" % plaster.to_html(), plaster, 2.6, 1.0)


## 整面石牆（後牆、城牆、鐘樓、煙囪）：同一個 shader，石牆高度拉到頂。block_scale 放大石塊。
func stone_wall(block_scale: float = 1.0) -> ShaderMaterial:
	return _wall_material("stonewall/%.2f" % block_scale, PLASTER, 99.0, block_scale)


func _wall_material(key: String, plaster: Color, stone_height: float, block_scale: float) -> ShaderMaterial:
	if _mats.has(key):
		return _mats[key] as ShaderMaterial
	var m := ShaderMaterial.new()
	m.shader = load(HALF_TIMBER_SHADER) as Shader
	m.set_shader_parameter("plaster_color", plaster)
	m.set_shader_parameter("stone_color", WALL_STONE)
	m.set_shader_parameter("stone_height", stone_height)
	m.set_shader_parameter("block_scale", block_scale)
	m.set_shader_parameter("snow_color", SNOW)
	_mats[key] = m
	return m


## 窗（window_glass.gdshader，D-066）：木窗框＋十字窗櫺＋亮／暗玻璃，全部的窗共用一個材質。
## 每扇窗用 StaticBatch.add_box_tinted 加，頂點色用 window_tint()。
func window() -> ShaderMaterial:
	if _mats.has("window"):
		return _mats["window"] as ShaderMaterial
	var m := ShaderMaterial.new()
	m.shader = load(WINDOW_SHADER) as Shader
	m.set_shader_parameter("glow_color", LAMP)
	_mats["window"] = m
	return m


## 積雪（snow.gdshader，D-068）：雪堆起伏、低處偏藍、街邊幾塊髒雪、雪粒閃點。全部的雪共用一個材質。
func snow() -> ShaderMaterial:
	if _mats.has("snow"):
		return _mats["snow"] as ShaderMaterial
	var m := ShaderMaterial.new()
	m.shader = load(SNOW_SHADER) as Shader
	m.set_shader_parameter("snow_color", SNOW)
	_mats["snow"] = m
	return m


## 屋瓦（roof_tiles.gdshader，D-107）：只給 RoofMesh 的斜面（UV 是公尺）。全部的屋頂共用一個材質。
func roof_tiles() -> ShaderMaterial:
	if _mats.has("roof_tiles"):
		return _mats["roof_tiles"] as ShaderMaterial
	var m := ShaderMaterial.new()
	m.shader = load(ROOF_TILES_SHADER) as Shader
	m.set_shader_parameter("base_color", ROOF)
	_mats["roof_tiles"] = m
	return m


## 門（door.gdshader，D-070）：木板＋板縫、門框、鐵條鉚釘、門把鐵環。全部的門共用一個材質。
func door() -> ShaderMaterial:
	if _mats.has("door"):
		return _mats["door"] as ShaderMaterial
	var m := ShaderMaterial.new()
	m.shader = load(DOOR_SHADER) as Shader
	m.set_shader_parameter("wood_color", WOOD)
	_mats["door"] = m
	return m


## 一扇門的頂點色：g 木色深淺與門把在哪邊、b 舊不舊（位置雜湊）。
static func door_tint(pos: Vector3) -> Color:
	var h1: float = fposmod(sin(pos.x * 17.13 + pos.z * 61.71) * 43758.5453, 1.0)
	var h2: float = fposmod(sin(pos.x * 83.07 + pos.z * 9.37) * 24634.6345, 1.0)
	return Color(1.0, h1, h2, 1.0)


## 木箱／攤桌的頂點色（door.gdshader 的木箱模式，D-077）：r＝0、g 木色深淺、b 舊不舊（位置雜湊）。
static func crate_tint(pos: Vector3) -> Color:
	var t: Color = door_tint(pos)
	return Color(0.0, t.g, t.b, 1.0)


## 店招的頂點色（door.gdshader 的店招模式，D-122）：r＝0.4／0.5／0.6 分別是靴子、壺、鑰匙的剪影
## （畫在招牌兩個大面上），g、b 同木箱；a＝1 招牌的大面朝 ±X、0 朝 ±Z（只在大面畫圖案）。
const SIGN_ICONS: int = 3


static func sign_icon(pos: Vector3) -> int:
	return int(fposmod(sin(pos.x * 5.31 + pos.z * 29.77) * 15731.743, 1.0) * SIGN_ICONS) % SIGN_ICONS


static func sign_tint(pos: Vector3, faces_x: bool) -> Color:
	var t: Color = door_tint(pos)
	return Color(0.4 + 0.1 * sign_icon(pos), t.g, t.b, 1.0 if faces_x else 0.0)


## 一扇窗的頂點色：lit 亮或暗、energy 發光強度（0～4）。色溫、窗簾、亮度起伏用位置雜湊決定
## （不動關卡的 _rng，房子配置不變）；約四成的亮窗拉了半邊窗簾。
static func window_tint(lit: bool, pos: Vector3, energy: float) -> Color:
	var h1: float = fposmod(sin(pos.x * 41.17 + pos.y * 13.31 + pos.z * 97.73) * 43758.5453, 1.0)
	var h2: float = fposmod(sin(pos.x * 7.91 + pos.y * 59.03 + pos.z * 23.57) * 24634.6345, 1.0)
	var curtain: float = 0.0
	if h2 < 0.42:
		curtain = 0.22 + h2 * 0.55
	var scale: float = lerpf(0.75, 1.2, fposmod(h1 * 7.31, 1.0))
	return Color(1.0 if lit else 0.0, h1, curtain, clampf(energy * scale / 4.0, 0.0, 1.0))


## 濕石板路（wet_cobble.gdshader）：石塊大小 stone_size 公尺、水窪比例 puddles（0～1）。
## 同參數共用同一個材質（StaticBatch 依材質合併）。
func wet_ground(color: Color, stone_size: float, puddles: float = 0.42) -> ShaderMaterial:
	var key: String = "wet/%s/%.2f/%.2f" % [color.to_html(), stone_size, puddles]
	if _mats.has(key):
		return _mats[key] as ShaderMaterial
	var m := ShaderMaterial.new()
	m.shader = load(WET_COBBLE_SHADER) as Shader
	m.set_shader_parameter("stone_color", color)
	m.set_shader_parameter("stone_size", stone_size)
	m.set_shader_parameter("puddle_amount", puddles)
	m.set_shader_parameter("snow_color", SNOW)
	_apply_ground_marks(m)
	_mats[key] = m
	return m


## 弧形鋪的濕石板（D-120）：石板一圈圈繞 center（xz）鋪，clear_radius 以內不蓋殘雪與薄雪
## （廣場繞中央石框，石框裡乾淨）。其他參數同 wet_ground；key 也是 "wet/" 開頭，殘雪設定一樣會套上。
func wet_ground_arc(color: Color, stone_size: float, puddles: float, center: Vector2, clear_radius: float) -> ShaderMaterial:
	var key: String = "wet/%s/%.2f/%.2f/arc/%.2f,%.2f/%.2f" % [color.to_html(), stone_size, puddles, center.x, center.y, clear_radius]
	if _mats.has(key):
		return _mats[key] as ShaderMaterial
	var m := wet_ground(color, stone_size, puddles).duplicate() as ShaderMaterial
	m.set_shader_parameter("arc_paving", true)
	m.set_shader_parameter("arc_center", center)
	m.set_shader_parameter("clear_disc", Vector3(center.x, center.y, clear_radius))
	# D-144：一圈圈的縫在中距離就淡掉（從遊玩高度看不像靶心）
	m.set_shader_parameter("far_fade", ARC_FAR_FADE)
	_mats[key] = m
	return m


## 地上的殘雪與髒雪（D-114）：wet_cobble.gdshader 的 lanes／trodden／rut_pts。
## lanes：街道範圍（中心 x、z，半寬 x、z）；trodden：踩實的髒雪（圓心 x、z，內半徑、外半徑）；
## rut：車轍中心線（xz 折線）。已經建立的濕石板材質立刻更新，之後建立的也會套上。
var ground_marks: Dictionary = {}


func set_ground_marks(lanes: Array[Vector4], trodden: Array[Vector4], rut: PackedVector2Array) -> void:
	ground_marks = {"lanes": lanes, "trodden": trodden, "rut": rut}
	for key: Variant in _mats:
		if str(key).begins_with("wet/"):
			_apply_ground_marks(_mats[key] as ShaderMaterial)


func _apply_ground_marks(m: ShaderMaterial) -> void:
	if ground_marks.is_empty():
		return
	var lanes: Array[Vector4] = ground_marks["lanes"]
	var trodden: Array[Vector4] = ground_marks["trodden"]
	var rut: PackedVector2Array = ground_marks["rut"]
	m.set_shader_parameter("lanes", _pad4(lanes, 8))
	m.set_shader_parameter("lane_count", mini(lanes.size(), 8))
	m.set_shader_parameter("trodden", _pad4(trodden, 4))
	m.set_shader_parameter("trodden_count", mini(trodden.size(), 4))
	var pts := PackedVector2Array(rut)
	pts.resize(8)
	m.set_shader_parameter("rut_pts", pts)
	m.set_shader_parameter("rut_count", mini(rut.size(), 8))


static func _pad4(items: Array[Vector4], n: int) -> PackedVector4Array:
	var out := PackedVector4Array()
	out.resize(n)
	for i: int in mini(items.size(), n):
		out[i] = items[i]
	return out
