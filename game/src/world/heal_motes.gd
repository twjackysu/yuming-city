class_name HealMotes
extends Node3D
## 回血的畫面回饋（D-213）：中毒被逆轉成回血的那幾秒，身邊有淡綠的光點慢慢往上飄（常駐、回血停了就停）；
## 喝下毒劑的那一下，胸口多一小團往上散開的光點＋一下很短的綠光。
## 掛在角色底下、聽 Health.healed；任何來源的回血都會亮（毒霧、守衛噴的毒、自己帶的毒劑）。
## 光不打高光（濕石板上不要多一顆亮點，D-208／D-209 的教訓）。

## 最後一次回血之後多久停止（StatusEffects 每個物理幀補一次，停了約半秒就收掉）
const ACTIVE_SEC: float = 0.45
const MOTE_COLOR: Color = Color(0.5, 1.0, 0.55, 0.9)
const BURST_COLOR: Color = Color(0.62, 1.0, 0.6, 1.0)
const LIGHT_COLOR: Color = Color(0.45, 1.0, 0.5)
const BURST_LIGHT_ENERGY: float = 1.3
const BURST_LIGHT_SEC: float = 0.9
## 胸口的高度（角色原點在腳底）
const CHEST_Y: float = 1.15

## 噴過幾次「喝下去」的那一團（測試、除錯用）
var bursts: int = 0
var _motes: CPUParticles3D
var _light: OmniLight3D
var _since: float = 99.0
var _light_t: float = -1.0


## 掛到角色身上並接上生命的 healed 訊號
static func attach(parent: Node3D, health: Health) -> HealMotes:
	var fx := HealMotes.new()
	fx.name = "HealMotes"
	parent.add_child(fx)
	if health != null:
		health.healed.connect(fx._on_healed)
	return fx


func _ready() -> void:
	_motes = _build_motes()
	add_child(_motes)
	_light = OmniLight3D.new()
	_light.name = "HealLight"
	_light.light_color = LIGHT_COLOR
	_light.light_energy = 0.0
	_light.light_specular = 0.0
	_light.omni_range = 2.8
	_light.omni_attenuation = 1.6
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, CHEST_Y, 0.0)
	_light.visible = false
	add_child(_light)


func _process(delta: float) -> void:
	_since += delta
	_motes.emitting = is_active()
	if _light_t >= 0.0:
		_light_t += delta
		var k: float = _light_t / BURST_LIGHT_SEC
		if k >= 1.0:
			_light_t = -1.0
			_light.light_energy = 0.0
			_light.visible = false
		else:
			# 很快亮起來、慢慢暗下去
			_light.light_energy = BURST_LIGHT_ENERGY * minf(k / 0.12, 1.0) * (1.0 - k) * (1.0 - k)


func _on_healed(_amount: float, _info: Dictionary) -> void:
	_since = 0.0


## 現在是不是正在回血（光點在飄）
func is_active() -> bool:
	return _since < ACTIVE_SEC


func motes() -> CPUParticles3D:
	return _motes


func light() -> OmniLight3D:
	return _light


## 喝下去的那一下：胸口一小團光點往上散開＋一下綠光。一次性粒子先建好、擺好位置才開始噴（D-208）。
func burst() -> CPUParticles3D:
	bursts += 1
	var ps := CPUParticles3D.new()
	ps.name = "HealBurst"
	ps.emitting = false
	ps.one_shot = true
	ps.amount = 30
	ps.lifetime = 1.15
	ps.explosiveness = 0.88
	ps.local_coords = false
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	ps.emission_sphere_radius = 0.2
	ps.direction = Vector3.UP
	ps.spread = 50.0
	ps.initial_velocity_min = 0.7
	ps.initial_velocity_max = 1.7
	ps.gravity = Vector3(0.0, 0.5, 0.0)
	ps.damping_min = 1.2
	ps.damping_max = 2.0
	ps.scale_amount_min = 0.6
	ps.scale_amount_max = 1.3
	ps.mesh = _dot_mesh(0.11, BURST_COLOR)
	ps.color_ramp = _fade_ramp(0.08)
	add_child(ps)
	ps.position = Vector3(0.0, CHEST_Y, 0.0)
	ps.emitting = true
	get_tree().create_timer(2.4).timeout.connect(ps.queue_free)
	_light_t = 0.0
	_light.visible = true
	return ps


## 常駐的光點：繞著身體一圈冒出來、慢慢往上、淡入淡出。world 座標（角色走動時留在原地往上飄）。
func _build_motes() -> CPUParticles3D:
	var ps := CPUParticles3D.new()
	ps.name = "Motes"
	ps.emitting = false
	ps.amount = 18
	ps.lifetime = 1.6
	ps.randomness = 0.6
	ps.local_coords = false
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	ps.emission_ring_axis = Vector3.UP
	ps.emission_ring_radius = 0.46
	ps.emission_ring_inner_radius = 0.26
	ps.emission_ring_height = 0.9
	ps.direction = Vector3.UP
	ps.spread = 10.0
	ps.initial_velocity_min = 0.3
	ps.initial_velocity_max = 0.62
	ps.gravity = Vector3(0.0, 0.18, 0.0)
	ps.scale_amount_min = 0.45
	ps.scale_amount_max = 1.0
	ps.mesh = _dot_mesh(0.085, MOTE_COLOR)
	ps.color_ramp = _fade_ramp(0.25)
	ps.position = Vector3(0.0, 0.75, 0.0)
	return ps


static func _dot_mesh(size: float, color: Color) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = ParticleLook.material(color, true)
	return quad


## 淡入（前 rise 的比例）→ 亮 → 淡出
static func _fade_ramp(rise: float) -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(rise, Color(1, 1, 1, 1))
	ramp.add_point(0.6, Color(1, 1, 1, 0.8))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	return ramp
