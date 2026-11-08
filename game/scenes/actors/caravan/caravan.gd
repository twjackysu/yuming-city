class_name Caravan
extends Node3D
## 傷者車隊：一輛手推車＋兩名躺著的傷者，沿路線推進（邏輯在 CaravanRunner）。
## 在 "heartbeat" 群組：送葬者第二階段優先追它、鐵架打到它就停下並多一名傷者。
## 生命值不會真的掉（Health 只是讓敵人的命中判定通用），受傷記在 runner.injured。

signal hit_taken(injured: int)
signal arrived

const WOOD: Color = Color(0.3, 0.22, 0.15)
## 車架、立樁、車把、輪轂（比木板深一點，車斗的輪廓才分得出來）
const WOOD_DARK: Color = Color(0.17, 0.12, 0.085)
## 車斗（寬 X、長 Z）與板面高度；五片木板
const BED_W: float = 1.3
const BED_L: float = 2.2
const BED_TOP: float = 0.66
const PLANKS: int = 5
## 輪子：半徑、離中心多遠（X）、裝在車斗哪裡（Z）；輻條數
const WHEEL_R: float = 0.42
const WHEEL_X: float = 0.74
const WHEEL_Z: float = 0.3
## 輻條：每根橫過輪轂的木條算兩根（3 條＝六根輻條）
const SPOKE_BARS: int = 3
## 提燈掛在前右角燈柱的橫桿下
const LANTERN_POS: Vector3 = Vector3(0.69, 1.3, -1.25)
const CLOTH: Color = Color(0.32, 0.29, 0.26)
## 燈罩離鏡頭這麼近以內看不到、到 FAR 才完全不透明
const GLASS_FADE_NEAR: float = 0.8
const GLASS_FADE_FAR: float = 2.2
## 推車與傷者：離鏡頭 CART_FADE_NEAR 以內看不到、到 CART_FADE_FAR 才完全不透明（D-106）。
## 車隊戰時過肩鏡頭在諾恩身後約 4.2 m（CAMERA_DIST_COMBAT）：推車從後面追上來、經過鏡頭底下時
## 不再擋住半個畫面；推車在諾恩身邊或前面時（離鏡頭 3.4 m 以上）照常看得到。
const CART_FADE_NEAR: float = 1.6
const CART_FADE_FAR: float = 3.4

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


func _box(part_name: String, size: Vector3, pos: Vector3, mat: Material, rot: Basis = Basis.IDENTITY) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _part(part_name, m, Transform3D(rot, pos), mat)


func _part(part_name: String, mesh: Mesh, xform: Transform3D, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	mi.transform = xform
	mi.material_override = mat
	_cart.add_child(mi, true)
	return mi


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	return m


func _build() -> void:
	_cart = Node3D.new()
	_cart.name = "Cart"
	add_child(_cart)
	# 推車（第四輪盤點，D-111）：原本是 CSG 方塊車斗＋兩片實心圓柱輪（鏡頭底下像兩顆黑球），
	# 比廣場那台手推車（D-103）粗糙很多。改成：兩根深色縱梁上鋪五片木板、兩側兩道邊板＋三根立樁、
	# 前後擋板；鐵輪框＋木輪框＋輪轂＋六根輻條的木輪、鐵車軸；兩根略往上翹的車把＋橫把、前端兩根撐腳；
	# 提燈掛在前右角的燈柱上（原本浮在半空）。全部是 MeshInstance3D，做完再套 CameraFade（D-106）。
	var wood: StandardMaterial3D = _mat(WOOD)
	var frame: StandardMaterial3D = _mat(WOOD_DARK)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.07, 0.07, 0.08)
	iron.roughness = 0.5
	# 車架：兩根縱梁（第一個子節點，測試從這裡拿木頭材質）
	for x: float in [-0.45, 0.45]:
		_box("Bed" if x < 0.0 else "Beam", Vector3(0.09, 0.1, 2.3), Vector3(x, 0.56, 0.0), frame)
	# 車斗：五片木板，寬度與長短、厚薄不一，板與板之間一條縫
	var plank_w: float = (BED_W - 0.02 * float(PLANKS - 1)) / float(PLANKS)
	for i: int in PLANKS:
		var x: float = -BED_W * 0.5 + plank_w * (float(i) + 0.5) + 0.02 * float(i)
		var thick: float = 0.045 + 0.012 * float((i * 7) % 3) * 0.5
		var length: float = BED_L - 0.05 * float((i * 5) % 3)
		_box("Plank%d" % i, Vector3(plank_w, thick, length), Vector3(x, BED_TOP - thick * 0.5, 0.02 * float((i * 3) % 3 - 1)), wood)
	# 兩側：下面一道寬邊板、上面一道窄邊板（中間一條縫）、三根立樁；前後擋板
	for sx: float in [-1.0, 1.0]:
		var x: float = sx * (BED_W * 0.5 - 0.02)
		_box("SideLow", Vector3(0.04, 0.13, BED_L), Vector3(x, BED_TOP + 0.07, 0.0), wood)
		_box("SideHigh", Vector3(0.04, 0.08, BED_L - 0.1), Vector3(x, BED_TOP + 0.2, 0.0), wood)
		for z: float in [-0.95, 0.0, 0.95]:
			_box("Stake", Vector3(0.06, 0.4, 0.06), Vector3(x + sx * 0.04, BED_TOP + 0.08, z), frame)
	for sz: float in [-1.0, 1.0]:
		_box("EndBoard", Vector3(BED_W, 0.17, 0.04), Vector3(0.0, BED_TOP + 0.085, sz * (BED_L * 0.5 - 0.02)), wood)
	# 輪子：輪軸沿 X。鐵輪框＋木輪框＋輪轂＋六根輻條（兩邊輻條角度不同）
	var axle_basis := Basis(Vector3.BACK, PI * 0.5)  # 圓柱／圓環的軸（Y）轉成 X
	for sx: float in [-1.0, 1.0]:
		var hub := Vector3(sx * WHEEL_X, WHEEL_R, WHEEL_Z)
		var tire := TorusMesh.new()
		tire.inner_radius = WHEEL_R - 0.05
		tire.outer_radius = WHEEL_R
		tire.rings = 24
		tire.ring_segments = 6
		_part("Tire", tire, Transform3D(axle_basis, hub), iron)
		var felloe := TorusMesh.new()
		felloe.inner_radius = WHEEL_R - 0.11
		felloe.outer_radius = WHEEL_R - 0.04
		felloe.rings = 24
		felloe.ring_segments = 5
		_part("Felloe", felloe, Transform3D(axle_basis, hub), wood)
		var nave := CylinderMesh.new()
		nave.top_radius = 0.075
		nave.bottom_radius = 0.075
		nave.height = 0.16
		nave.radial_segments = 8
		nave.rings = 1
		_part("Nave", nave, Transform3D(axle_basis, hub), frame)
		for k: int in SPOKE_BARS:
			var spoke := Basis(Vector3.RIGHT, PI / float(SPOKE_BARS) * float(k) + (0.3 if sx > 0.0 else 0.0))
			_box("Spoke", Vector3(0.03, (WHEEL_R - 0.07) * 2.0, 0.04), hub, wood, spoke)
	var axle := CylinderMesh.new()
	axle.top_radius = 0.03
	axle.bottom_radius = 0.03
	axle.height = WHEEL_X * 2.0 + 0.12
	axle.radial_segments = 6
	axle.rings = 1
	_part("Axle", axle, Transform3D(axle_basis, Vector3(0.0, WHEEL_R, WHEEL_Z)), iron)
	# 車把：從車斗底下往前伸、前端稍微翹起，前端一根橫把；車斗前端兩根撐腳
	var lift := Basis(Vector3.RIGHT, deg_to_rad(6.0))
	for x: float in [-0.35, 0.35]:
		_box("Handle", Vector3(0.055, 0.055, 1.3), Vector3(x, 0.6, -1.65), frame, lift)
		_box("Leg", Vector3(0.05, 0.5, 0.05), Vector3(x, 0.26, -1.0), frame)
	_box("Grip", Vector3(0.78, 0.05, 0.05), Vector3(0.0, 0.6 + 0.6 * sin(deg_to_rad(6.0)), -1.65 - 0.6 * cos(deg_to_rad(6.0))), frame)
	# 提燈的燈柱：前右角往上，頂上一根短橫桿往前伸，燈掛在橫桿下
	_box("LanternPole", Vector3(0.045, 0.85, 0.045), Vector3(BED_W * 0.5 + 0.04, BED_TOP + 0.38, -BED_L * 0.5 + 0.06), frame)
	_box("LanternArm", Vector3(0.035, 0.035, 0.3), Vector3(BED_W * 0.5 + 0.04, BED_TOP + 0.78, -BED_L * 0.5 - 0.08), iron)
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
		_box("Blanket%d" % i, Vector3(0.46, 0.08, 1.15), Vector3(x, 0.9, 0.42), cloth,
			Basis(Vector3.FORWARD, deg_to_rad(4.0 if i == 0 else -3.0)))
		# 拿掉手上的鐘錘（程序人偶預設拿著）
		var hammer: Node = hurt.hand("R").get_node_or_null("BellHammer") if hurt.hand("R") != null else null
		if hammer != null:
			hammer.queue_free()
	# 推車的人掛的提燈：暗處也看得到車隊在哪
	_lantern = OmniLight3D.new()
	_lantern.light_color = Color(0.95, 0.72, 0.42)
	_lantern.omni_range = 4.5
	_lantern.light_energy = 1.2
	_lantern.position = LANTERN_POS
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
	for y: float in [0.095, -0.09]:
		var cap := MeshInstance3D.new()
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(0.15, 0.035, 0.15)
		cap.mesh = cap_mesh
		cap.material_override = iron
		cap.position = _lantern.position + Vector3(0.0, y, 0.0)
		_cart.add_child(cap)
	CameraFade.apply(_cart, CART_FADE_NEAR, CART_FADE_FAR)
