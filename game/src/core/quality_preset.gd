class_name QualityPreset
extends RefCounted
## 畫質三級（docs/design/03-art-audio-direction.md「畫質分級」）。純函式，方便測試。
## 場景用「中」的參數製作環境；這裡只切換開關，不改場景調好的顏色與密度。
## - 低：關體積霧（改用便宜的深度霧保住氛圍）、SSAO、Glow；MSAA 關。
## - 中：預設（體積霧、SSAO、Glow；MSAA 2x）。
## - 高：再加 SSR、SSIL；MSAA 4x；體積霧較細。
## - 水窪倒影的 ReflectionProbe（D-051）：中、高開；低關。

enum Level { LOW, MEDIUM, HIGH }

const NAME_KEYS: PackedStringArray = ["QUALITY_LOW", "QUALITY_MEDIUM", "QUALITY_HIGH"]
const DEFAULT_LEVEL: Level = Level.MEDIUM


static func clamp_level(value: int) -> Level:
	return clampi(value, Level.LOW, Level.HIGH) as Level


## 套到一個 Environment。低畫質時用深度霧代替體積霧，顏色取場景體積霧的發光色＋反照率。
static func apply_environment(env: Environment, level: Level) -> void:
	if env == null:
		return
	var low: bool = level == Level.LOW
	env.volumetric_fog_enabled = not low
	env.ssao_enabled = not low
	env.glow_enabled = not low
	env.ssr_enabled = level == Level.HIGH
	env.ssil_enabled = level == Level.HIGH
	env.fog_enabled = low
	if low:
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_light_color = (env.volumetric_fog_albedo * 0.12 + env.volumetric_fog_emission * 2.0).clamp()
		env.fog_density = env.volumetric_fog_density * 1.2
		env.fog_sky_affect = FrostbridgeLook.SKY_FOG_AFFECT


## ReflectionProbe（只在載入時拍一次）：低畫質關掉，省下每個像素取樣反射的成本。
static func apply_probe(probe: ReflectionProbe, level: Level) -> void:
	if probe == null:
		return
	probe.visible = level != Level.LOW


static func msaa_for(level: Level) -> Viewport.MSAA:
	match level:
		Level.LOW:
			return Viewport.MSAA_DISABLED
		Level.HIGH:
			return Viewport.MSAA_4X
		_:
			return Viewport.MSAA_2X


## 體積霧格點大小（全域設定，影響所有場景）。
static func volumetric_fog_size(level: Level) -> int:
	return 96 if level == Level.HIGH else 64


## 套到整棵樹：所有 WorldEnvironment 與根 viewport。
static func apply_tree(root: Node, level: Level) -> void:
	if root == null:
		return
	var vp: Viewport = root.get_viewport()
	if vp != null:
		vp.msaa_3d = msaa_for(level)
	RenderingServer.environment_set_volumetric_fog_volume_size(volumetric_fog_size(level), 64)
	for n: Node in root.find_children("*", "WorldEnvironment", true, false):
		apply_environment((n as WorldEnvironment).environment, level)
	for n: Node in root.find_children("*", "ReflectionProbe", true, false):
		apply_probe(n as ReflectionProbe, level)
