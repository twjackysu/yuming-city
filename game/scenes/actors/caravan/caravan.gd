class_name Caravan
extends Node3D
## 傷者車隊：一輛手推車＋兩名躺著的傷者，沿路線推進（邏輯在 CaravanRunner）。
## 在 "heartbeat" 群組：送葬者第二階段優先追它、鐵架打到它就停下並多一名傷者。
## 生命值不會真的掉（Health 只是讓敵人的命中判定通用），受傷記在 runner.injured。

signal hit_taken(injured: int)
signal arrived

const WOOD: Color = Color(0.3, 0.22, 0.15)
const CLOTH: Color = Color(0.55, 0.52, 0.48)

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
	# 兩名傷者：躺著、蓋著布
	var cloth: StandardMaterial3D = _mat(CLOTH)
	var skin: StandardMaterial3D = _mat(Color(0.6, 0.5, 0.44))
	for i: int in 2:
		var x: float = -0.3 + 0.6 * float(i)
		var body := CSGCylinder3D.new()
		body.radius = 0.2
		body.height = 1.4
		body.rotation_degrees = Vector3(90, 0, 0)
		body.position = Vector3(x, 0.86, 0.15)
		body.material = cloth
		_cart.add_child(body)
		var head := CSGSphere3D.new()
		head.radius = 0.13
		head.position = Vector3(x, 0.86, -0.7)
		head.material = skin
		_cart.add_child(head)
	# 推車的人掛的提燈：暗處也看得到車隊在哪
	_lantern = OmniLight3D.new()
	_lantern.light_color = Color(0.95, 0.72, 0.42)
	_lantern.omni_range = 4.5
	_lantern.light_energy = 1.2
	_lantern.position = Vector3(0.45, 1.3, -1.9)
	_cart.add_child(_lantern)
	var glass := CSGSphere3D.new()
	glass.radius = 0.08
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(1.0, 0.8, 0.5)
	glass.material = gm
	glass.position = _lantern.position
	_cart.add_child(glass)
