class_name ThrownFrame
extends Node3D
## 送葬者擲出的鐵架（演出，D-042）：從送葬者背上沿拋物線飛向落點、邊飛邊翻。
## 到了 → outcome "arch"：撞上重現的石拱碎成鐵條往回彈、揚起石粉；
##         "kindling"：被席菈的燃燒劍從中間斬成兩截、往兩邊落下，斷口燒紅、火星四散。
## 只是畫面：結局在 FrameThrowEvent 擲出那一刻就決定了。碎片數固定，DEBRIS_LIFE 秒後自己消失。
## top_level：不跟著父節點（遭遇戰節點）移動，座標一律是世界座標。

signal impacted(outcome: String)

const FLIGHT_SEC: float = 0.55
const ARC_HEIGHT: float = 2.2
const DEBRIS_LIFE: float = 2.6
const GRAVITY: float = 16.0
const HOT: Color = Color(1.0, 0.45, 0.12)
const DUST: Color = Color(0.72, 0.74, 0.78)

var outcome: String = "arch"
var from: Vector3 = Vector3.ZERO
var to: Vector3 = Vector3.ZERO
## 地面高度（碎片落到這裡會彈一下再停）
var ground_y: float = 0.0
## 飛行進度 0～1
var t: float = 0.0
var has_impacted: bool = false
var pieces: Array[Node3D] = []

var _frame: Node3D
var _vel: Array[Vector3] = []
var _spin: Array[Vector3] = []
var _life: float = 0.0
var _flash: OmniLight3D
var _iron: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


static func create(p_from: Vector3, p_to: Vector3, p_outcome: String, p_ground_y: float = 0.0) -> ThrownFrame:
	var f := ThrownFrame.new()
	f.name = "ThrownFrame"
	f.from = p_from
	f.to = p_to
	f.outcome = p_outcome
	f.ground_y = p_ground_y
	return f


## 拋物線：起點到落點直線內插，中間抬高 ARC_HEIGHT。
func position_at(k: float) -> Vector3:
	var p: Vector3 = from.lerp(to, k)
	p.y += ARC_HEIGHT * 4.0 * k * (1.0 - k)
	return p


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_rng.seed = 9091
	_iron = StandardMaterial3D.new()
	_iron.albedo_color = Color(0.3, 0.24, 0.2)
	_iron.metallic = 0.7
	_iron.roughness = 0.6
	_frame = Node3D.new()
	_frame.name = "Frame"
	add_child(_frame)
	# 跟送葬者背上的一樣：兩根立柱＋三根橫桿（中心在鐵架中間）
	for x: float in [-0.45, 0.45]:
		_frame.add_child(_bar(Vector3(0.08, 2.2, 0.08), Vector3(x, 0, 0)))
	for y: float in [-0.7, 0.0, 0.8]:
		_frame.add_child(_bar(Vector3(1.1, 0.07, 0.07), Vector3(0, y, 0)))
	_frame.position = from
	_face_flight()


func _physics_process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if not has_impacted:
		t = minf(t + delta / FLIGHT_SEC, 1.0)
		_frame.position = position_at(t)
		# 往前翻：一趟大約轉 3/4 圈
		_frame.rotate_object_local(Vector3.RIGHT, -delta / FLIGHT_SEC * TAU * 0.75)
		if t >= 1.0:
			_impact()
		return
	_life += delta
	for i: int in pieces.size():
		var p: Node3D = pieces[i]
		var v: Vector3 = _vel[i]
		v.y -= GRAVITY * delta
		var pos: Vector3 = p.position + v * delta
		if pos.y < ground_y + 0.05:
			pos.y = ground_y + 0.05
			v = Vector3(v.x * 0.55, absf(v.y) * 0.25, v.z * 0.55)
			_spin[i] *= 0.5
		p.position = pos
		_vel[i] = v
		p.rotate_object_local(Vector3.RIGHT, _spin[i].x * delta)
		p.rotate_object_local(Vector3.UP, _spin[i].y * delta)
		# 最後半秒縮小消失
		var fade: float = clampf((DEBRIS_LIFE - _life) / 0.5, 0.0, 1.0)
		p.scale = Vector3.ONE * maxf(fade, 0.01)
	if _flash != null:
		_flash.light_energy = maxf(_flash.light_energy - delta * 9.0, 0.0)
	if _life >= DEBRIS_LIFE:
		queue_free()


func _face_flight() -> void:
	var d: Vector3 = to - from
	d.y = 0.0
	if d.length() > 0.01:
		_frame.rotation.y = atan2(d.x, d.z)


func _impact() -> void:
	has_impacted = true
	var at: Vector3 = _frame.position
	var rot: Basis = _frame.basis
	var back: Vector3 = from - to
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	var side: Vector3 = back.cross(Vector3.UP).normalized()
	_frame.queue_free()
	_frame = null
	if outcome == "arch":
		# 撞上石拱：碎成十截鐵條，往回彈、往上噴
		for x: float in [-0.45, 0.45]:
			for y: float in [-0.55, 0.55]:
				_piece(at + rot * Vector3(x, y, 0), rot, Vector3(0.08, 1.1, 0.08), back * _rng.randf_range(2.0, 4.5) + side * _rng.randf_range(-2.5, 2.5) + Vector3.UP * _rng.randf_range(2.0, 5.0), false)
		for y: float in [-0.7, 0.0, 0.8]:
			for x: float in [-0.28, 0.28]:
				_piece(at + rot * Vector3(x, y, 0), rot, Vector3(0.55, 0.07, 0.07), back * _rng.randf_range(1.5, 4.0) + side * signf(x) * _rng.randf_range(1.0, 3.0) + Vector3.UP * _rng.randf_range(1.5, 4.5), false)
		_burst(at, DUST, 48, 4.0, 0.16, 1.2)
		_light(at, Color(0.75, 0.88, 1.0), 3.0)
	else:
		# 燃燒劍從中間斬開：左右兩半，斷口燒紅
		for s: float in [-1.0, 1.0]:
			var half := Node3D.new()
			half.position = at + rot * Vector3(s * 0.3, 0, 0)
			half.basis = rot
			add_child(half)
			half.add_child(_bar(Vector3(0.08, 2.2, 0.08), Vector3(s * 0.15, 0, 0)))
			for y: float in [-0.7, 0.0, 0.8]:
				half.add_child(_bar(Vector3(0.5, 0.07, 0.07), Vector3(-s * 0.1, y, 0)))
				# 斷口：燒紅的小截面
				half.add_child(_hot_tip(Vector3(-s * 0.36, y, 0)))
			pieces.append(half)
			_vel.append(side * s * _rng.randf_range(3.0, 4.0) + back * 0.8 + Vector3.UP * 2.5)
			_spin.append(Vector3(_rng.randf_range(-6.0, 6.0), s * 5.0, 0))
		_burst(at, HOT, 48, 5.0, 0.05, 1.1)
		_light(at, HOT, 4.0)
	impacted.emit(outcome)


func _piece(pos: Vector3, rot: Basis, size: Vector3, vel: Vector3, hot: bool) -> void:
	var p := Node3D.new()
	p.position = pos
	p.basis = rot
	add_child(p)
	p.add_child(_bar(size, Vector3.ZERO))
	if hot:
		p.add_child(_hot_tip(Vector3.ZERO))
	pieces.append(p)
	_vel.append(vel)
	_spin.append(Vector3(_rng.randf_range(-12.0, 12.0), _rng.randf_range(-8.0, 8.0), 0))


func _bar(size: Vector3, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	m.material = _iron
	mi.mesh = m
	mi.position = pos
	return mi


func _hot_tip(pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.05, 0.09, 0.09)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = HOT
	mat.emission_enabled = true
	mat.emission = HOT
	mat.emission_energy_multiplier = 4.0
	m.material = mat
	mi.mesh = m
	mi.position = pos
	return mi


func _burst(at: Vector3, color: Color, amount: int, speed: float, size: float, life: float) -> void:
	var ps := CPUParticles3D.new()
	ps.name = "Burst"
	ps.position = at
	ps.one_shot = true
	ps.explosiveness = 0.95
	ps.amount = amount
	ps.lifetime = life
	ps.direction = Vector3.UP
	ps.spread = 180.0
	ps.initial_velocity_min = speed * 0.4
	ps.initial_velocity_max = speed
	ps.gravity = Vector3(0, -6.0, 0)
	ps.damping_min = 1.0
	ps.damping_max = 3.0
	ps.scale_amount_min = 0.6
	ps.scale_amount_max = 1.4
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color
	quad.material = mat
	ps.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ps.color_ramp = ramp
	add_child(ps)
	ps.emitting = true


func _light(at: Vector3, color: Color, energy: float) -> void:
	_flash = OmniLight3D.new()
	_flash.name = "Flash"
	_flash.position = at
	_flash.light_color = color
	_flash.light_energy = energy
	_flash.omni_range = 7.0
	_flash.shadow_enabled = false
	add_child(_flash)
