class_name CorruptForest
extends StoryLevel
## 腐敗之森入口（第一章的起點，docs/story/chapter-1.md 節點 2；計畫在 docs/design/13-chapter-1-plan.md）。
## 現在是最小的一塊：出生點 → 一團瘴氣（走進去中毒 → 反轉成回血）→ 林間空地的三隻劇毒史萊姆。
## 樹、毒蕈、灌木是 Tripo 的模型（scripts/gen_props.sh 擺正後放 assets/props/tripo/，不進 git）；檔案不在就用程式拼的替身。
## 劇情旗標：ch1.reversal_seen（第一次反轉）、ch1.slimes_cleared（三隻都倒了）——任務 data/quests/ch1_main.json 看這兩個。

const GROUND_SIZE: float = 140.0
const MIASMA_POS: Vector3 = Vector3(0, 0, 2)
const MIASMA_RADIUS: float = 5.0
const GLADE_POS: Vector3 = Vector3(0, 0, -15)
const GLADE_RADIUS: float = 8.0
const SLIME_SPOTS: Array[Vector3] = [Vector3(-2.5, 0, -15), Vector3(2.5, 0, -16), Vector3(0, 0, -19)]
const TREE_MODEL: String = "tripo/prop_corrupt_tree"
const MUSHROOM_MODEL: String = "tripo/prop_glow_toxic_mushroom"
const BUSH_MODEL: String = "tripo/prop_rotten_fruit_bush"
const TREE_COUNT: int = 46
## 路（x 在這個寬度內）與空地不種樹
const PATH_HALF_WIDTH: float = 4.0
const FLAG_REVERSAL: String = "ch1.reversal_seen"
const FLAG_SLIMES: String = "ch1.slimes_cleared"

var slimes: Array[Slime] = []
var miasma: PoisonMist
var _rng := RandomNumberGenerator.new()

@onready var _player: PlayerController = $Player
@onready var _hud: Hud = $Hud


func _ready() -> void:
	_rng.seed = 20261114
	_build_environment()
	_build_ground()
	_build_forest()
	_build_miasma()
	_mark("MiasmaEdge", MIASMA_POS + Vector3(0, 0, MIASMA_RADIUS))
	_mark("SlimeGlade", GLADE_POS)
	var spawn: Marker3D = $Spawn
	_player.global_position = spawn.global_position
	# 截圖用：`-- --level=corrupt_forest --cam-yaw=90` 鏡頭繞到諾恩的側面（180＝正面）
	var args: Dictionary = App.parse_user_args(OS.get_cmdline_user_args())
	if args.has("cam-yaw"):
		_player.yaw = deg_to_rad(float(str(args["cam-yaw"])))
	_player.snap_camera()
	# 連拍用：`--burst-on=reversal` 進場 1.5 秒後讓諾恩吸到瘴氣，從那一刻開始拍（scripts/burst.sh）
	if str(args.get("burst-on", "")) == "reversal":
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			App.burst_start_in(1)
			_player.status_effects.apply_source("miasma"))
	if not bool(Game.session.state.get_flag(FLAG_SLIMES, false)):
		_spawn_slimes()
	QualityPreset.apply_tree(self, Settings.quality as QualityPreset.Level)


func footstep_surface(_p: Vector3) -> String:
	return "snow"  # 現有的三種裡最像落葉軟土的；之後加「土」的腳步聲


func _physics_process(_delta: float) -> void:
	if not Game.session.in_story():
		return
	var st: GameState = Game.session.state
	if not bool(st.get_flag(FLAG_REVERSAL, false)) and _player.status_effects.is_reversed("poison") and _player.status_effects.has("poison"):
		Game.session.set_flag(FLAG_REVERSAL, true)
		_hud.show_center_lines("CH1_REVERSAL_LINE1", "CH1_REVERSAL_LINE2")
	if not slimes.is_empty() and not bool(st.get_flag(FLAG_SLIMES, false)) and slimes_alive() == 0:
		Game.session.set_flag(FLAG_SLIMES, true)
		_hud.show_banner("CH1_SLIMES_CLEARED", 4.0)


func slimes_alive() -> int:
	var n: int = 0
	for s: Slime in slimes:
		if is_instance_valid(s) and not s.health.is_dead():
			n += 1
	return n


func _spawn_slimes() -> void:
	for i: int in SLIME_SPOTS.size():
		var s := Slime.new()
		s.name = "Slime%d" % (i + 1)
		s.position = SLIME_SPOTS[i]
		s.focus_player = true
		add_child(s)
		slimes.append(s)


func _mark(node_name: String, at: Vector3) -> void:
	var m := Marker3D.new()
	m.name = node_name
	m.position = at
	add_child(m)


## 黃昏的紫黑森林：冷的月光、暗紫的環境光、薄的體積霧（畫質低時 QualityPreset 換成深度霧）。
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.05, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.36, 0.55)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.5, 0.38, 0.62)
	env.volumetric_fog_emission = Color(0.05, 0.03, 0.08)
	env.volumetric_fog_length = 70.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.72, 0.74, 1.0)
	moon.light_energy = 1.1
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-48, 32, 0)
	add_child(moon)


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GROUND_SIZE, 1.0, GROUND_SIZE)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.17, 0.2, 0.16)
	mat.roughness = 1.0
	plane.material = mat
	mesh.mesh = plane
	body.add_child(mesh)
	add_child(body)
	# 路：比兩邊亮一點的土色，從出生點一路到空地
	var path := MeshInstance3D.new()
	path.name = "Path"
	var strip := PlaneMesh.new()
	strip.size = Vector2(PATH_HALF_WIDTH * 1.4, 60.0)
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.3, 0.26, 0.24)
	dirt.roughness = 1.0
	strip.material = dirt
	path.mesh = strip
	path.position = Vector3(0, 0.01, -5.0)
	add_child(path)


## 樹散在路的兩邊與空地外圍；毒蕈與灌木點在路邊。位置用固定的亂數種子，每次都一樣。
func _build_forest() -> void:
	var forest := Node3D.new()
	forest.name = "Forest"
	add_child(forest)
	var placed: int = 0
	var tries: int = 0
	while placed < TREE_COUNT and tries < TREE_COUNT * 20:
		tries += 1
		var p := Vector3(_rng.randf_range(-30.0, 30.0), 0.0, _rng.randf_range(-40.0, 26.0))
		if not tree_spot_ok(p):
			continue
		forest.add_child(_tree(p, _rng.randf_range(0.85, 1.3), _rng.randf_range(0.0, TAU)))
		placed += 1
	for i: int in 9:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(side * _rng.randf_range(PATH_HALF_WIDTH * 0.8, PATH_HALF_WIDTH + 2.0), 0.0, 16.0 - float(i) * 4.5)
		forest.add_child(_small_prop(MUSHROOM_MODEL if i % 3 != 0 else BUSH_MODEL, at, _rng.randf_range(0.0, TAU), i % 3 != 0))


## 這個位置可不可以種樹：不擋路、不在空地與瘴氣裡。純函式。
static func tree_spot_ok(p: Vector3) -> bool:
	if absf(p.x) < PATH_HALF_WIDTH and p.z > GLADE_POS.z:
		return false
	if Vector2(p.x - GLADE_POS.x, p.z - GLADE_POS.z).length() < GLADE_RADIUS + 1.5:
		return false
	return Vector2(p.x - MIASMA_POS.x, p.z - MIASMA_POS.z).length() > MIASMA_RADIUS + 1.0


func _tree(at: Vector3, size: float, yaw: float) -> Node3D:
	var body := StaticBody3D.new()
	body.position = at
	body.rotation.y = yaw
	var shape := CollisionShape3D.new()
	var trunk := CylinderShape3D.new()
	trunk.radius = 0.45 * size
	trunk.height = 4.0
	shape.shape = trunk
	shape.position = Vector3(0, 2.0, 0)
	body.add_child(shape)
	var look: Node3D = PropModels.instance(TREE_MODEL)
	if look == null:
		var mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.2
		cyl.bottom_radius = 0.45
		cyl.height = 6.0
		var bark := StandardMaterial3D.new()
		bark.albedo_color = Color(0.2, 0.15, 0.2)
		cyl.material = bark
		mesh.mesh = cyl
		mesh.position = Vector3(0, 3.0, 0)
		look = mesh
	look.scale = Vector3.ONE * size
	body.add_child(look)
	return body


func _small_prop(model: String, at: Vector3, yaw: float, glows: bool) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = yaw
	var look: Node3D = PropModels.instance(model)
	if look == null:
		var mesh := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.4
		ball.height = 0.6
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.5, 0.9) if glows else Color(0.25, 0.4, 0.2)
		ball.material = mat
		mesh.mesh = ball
		mesh.position = Vector3(0, 0.3, 0)
		look = mesh
	root.add_child(look)
	if glows:
		var light := OmniLight3D.new()
		light.light_color = Color(0.45, 0.75, 1.0)
		light.light_energy = 0.8
		light.omni_range = 4.0
		light.position = Vector3(0, 0.8, 0)
		root.add_child(light)
	return root


func _build_miasma() -> void:
	miasma = PoisonMist.create(MIASMA_RADIUS, "miasma")
	miasma.name = "Miasma"
	miasma.tint = Color(0.62, 0.3, 0.85)
	miasma.position = MIASMA_POS
	add_child(miasma)
