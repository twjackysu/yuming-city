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
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.07)
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
const HALF_TIMBER_SHADER: String = "res://src/world/half_timber.gdshader"
const WINDOW_SHADER: String = "res://src/world/window_glass.gdshader"
const SNOW_SHADER: String = "res://src/world/snow.gdshader"
const DOOR_SHADER: String = "res://src/world/door.gdshader"
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
	_mats[key] = m
	return m
