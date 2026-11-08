class_name Caravan
extends Node3D
## 傷者車隊：一輛手推車＋兩名躺著的傷者，沿路線推進（邏輯在 CaravanRunner）。
## 在 "heartbeat" 群組：送葬者第二階段優先追它、鐵架打到它就停下並多一名傷者。
## 生命值不會真的掉（Health 只是讓敵人的命中判定通用），受傷記在 runner.injured。

signal hit_taken(injured: int)
signal arrived

const WOOD: Color = Color(0.3, 0.22, 0.15)
const CLOTH: Color = Color(0.32, 0.29, 0.26)
## 燈罩離鏡頭這麼近以內看不到、到 FAR 才完全不透明
const GLASS_FADE_NEAR: float = 0.8
const GLASS_FADE_FAR: float = 2.2

var route: PackedVector3Array = []
var runner: CaravanRunner
var health: Health

var _cart: Node3D
var _lantern: OmniLight3D
var _shake: float = 0.0


func _ready() -> void:
	add_to_group("heartbeat")
	add_to_group("caravan")
	if route.is_empty():
		route = PackedVector3Array([global_position, global_position + Vector3(0, 0, -20)])
	runner = CaravanRunner.new(route)
	runner.hit_taken.connect(_on_runner_hit)
	runner.arrived.connect(func() -> void: arrived.emit())
	health = Health.new(9999.0)
	health.name = "Health"
	add_child(health)
	health.damaged.connect(_on_damaged)
	_build()
	_sync()


func _physics_process(delta: float) -> void:
	runner.tick(delta)
	_sync()
	if _shake > 0.0:
		_shake = maxf(_shake - delta, 0.0)
		_cart.position.x = sin(_shake * 60.0) * 0.06 * _shake
	_lantern.light_energy = 0.6 if runner.is_stopped() else 1.2


func _sync() -> void:
	global_position = runner.position()
	var h: Vector3 = runner.heading()
	rotation.y = atan2(-h.x, -h.z)


func _on_damaged(_amount: float, _info: Dictionary) -> void:
	health.hp = health.max_hp
	runner.hit()


func _on_runner_hit(n: int) -> void:
	_shake = 0.5
	Sfx.play_at(self, "blunt", global_position + Vector3.UP, 4.0, 0.05)
	hit_taken.emit(n)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	return m


func _build() -> void:
	_cart = Node3D.new()
	_cart.name = "Cart"
	add_child(_cart)
	var wood: StandardMaterial3D = _mat(WOOD)
	var bed := CSGBox3D.new()
	bed.size = Vector3(1.3, 0.12, 2.2)
	bed.position = Vector3(0, 0.62, 0)
	bed.material = wood
	_cart.add_child(bed)
	for x: float in [-0.65, 0.65]:
		var rail := CSGBox3D.new()
		rail.size = Vector3(0.06, 0.25, 2.2)
		rail.position = Vector3(x, 0.8, 0)
		rail.material = wood
		_cart.add_child(rail)
		var wheel := CSGCylinder3D.new()
		wheel.radius = 0.42
		wheel.height = 0.08
		wheel.sides = 14
		wheel.rotation_degrees = Vector3(0, 0, 90)
		wheel.position = Vector3(x * 1.12, 0.42, 0.3)
		wheel.material = wood
		_cart.add_child(wheel)
	for x: float in [-0.35, 0.35]:
		var handle := CSGBox3D.new()
		handle.size = Vector3(0.05, 0.05, 1.0)
		handle.position = Vector3(x, 0.75, -1.5)
		handle.material = wood
		_cart.add_child(handle)
	# 兩名傷者：程序人偶仰躺（頭朝車把）、腿和身體蓋著布
	var cloth: StandardMaterial3D = _mat(CLOTH)
	for i: int in 2:
		var x: float = -0.3 + 0.6 * float(i)
		var hurt := Puppet.new()
		hurt.name = "Wounded%d" % i
		hurt.lying = "back"
		hurt.coat_color = Color(0.24, 0.22, 0.2) if i == 0 else Color(0.2, 0.21, 0.24)
		hurt.trim_color = Color(0.3, 0.26, 0.2)
		hurt.position = Vector3(x, 0.68, 0.1)
		hurt.rotation.y = PI
		hurt.scale = Vector3.ONE * 0.92
		_cart.add_child(hurt)
		var blanket := CSGBox3D.new()
		blanket.size = Vector3(0.46, 0.08, 1.15)
		blanket.position = Vector3(x, 0.9, 0.42)
		blanket.material = cloth
		_cart.add_child(blanket)
		# 拿掉手上的鐘錘（程序人偶預設拿著）
		var hammer: Node = hurt.hand("R").get_node_or_null("BellHammer") if hurt.hand("R") != null else null
		if hammer != null:
			hammer.queue_free()
	# 推車的人掛的提燈：暗處也看得到車隊在哪
	_lantern = OmniLight3D.new()
	_lantern.light_color = Color(0.95, 0.72, 0.42)
	_lantern.omni_range = 4.5
	_lantern.light_energy = 1.2
	_lantern.position = Vector3(0.45, 1.3, -1.9)
	_cart.add_child(_lantern)
	# 燈罩：暖橘色的小方燈＋鐵蓋鐵底（之前是一顆不受光的白球，經過鏡頭旁像一個白色圓盤）
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(0.95, 0.58, 0.24)
	# 車隊從鏡頭旁邊經過時，燈罩貼到鏡頭前：太近就用抖動淡掉（光還在）
	gm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	gm.distance_fade_min_distance = GLASS_FADE_NEAR
	gm.distance_fade_max_distance = GLASS_FADE_FAR
	var glass := MeshInstance3D.new()
	glass.name = "LanternGlass"
	var glass_mesh := BoxMesh.new()
	glass_mesh.size = Vector3(0.11, 0.15, 0.11)
	glass.mesh = glass_mesh
	glass.material_override = gm
	glass.position = _lantern.position
	_cart.add_child(glass)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.07, 0.07, 0.08)
	iron.roughness = 0.5
	for y: float in [0.095, -0.09]:
		var cap := MeshInstance3D.new()
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(0.15, 0.035, 0.15)
		cap.mesh = cap_mesh
		cap.material_override = iron
		cap.position = _lantern.position + Vector3(0.0, y, 0.0)
		_cart.add_child(cap)
