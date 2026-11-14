class_name CorruptForest
extends StoryLevel
## 腐敗之森入口（第一章的起點，docs/story/chapter-1.md 節點 2；計畫在 docs/design/13-chapter-1-plan.md）。
## 現在是最小的一塊：出生點（席菈站在旁邊）→ 一團瘴氣（走進去中毒 → 反轉成回血 → 兩人講幾句）→ 林間空地的三隻劇毒史萊姆
## （席菈跟在後面，開打後往諾恩背上射藥：scenes/actors/sera/）。
## 地面是一片平面（顏色、路與空地的邊緣、落葉都在 forest_ground.gdshader 裡算），上面長一團一團的草（GrassTufts）。
## 樹、毒蕈、灌木是 Tripo 的模型（scripts/gen_props.sh 擺正後放 assets/props/tripo/，不進 git）；檔案不在就用程式拼的替身。
## 教學戰照劇本：席菈慌了，第一瓶拿錯成【重度麻痺＋防禦歸零】（對諾恩＝出手快 150%＋受傷少 80%）→ 打完兩人講話（兩個選項）。
## 劇情旗標：ch1.reversal_seen（第一次反轉）、ch1.slimes_cleared（三隻都倒了）、ch1.after_slimes_talked（戰後那段話講完，
## 對話資料自己設）——任務 data/quests/ch1_main.json 看這三個；ch1.gate_talked＝瘴氣裡那段對話講過了；
## ch1.misfire_seen＝拿錯的那一瓶射過了。

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
const GRASS_PATCHES: int = 230
const GROUND_SHADER: Shader = preload("res://src/world/forest_ground.gdshader")
## 樹腳下那一圈苔的半徑（公尺，再乘上樹的大小）：比模型自帶的土丘（約 3 m）大一圈，土丘才會埋在苔裡
const TREE_MOSS_RADIUS: float = 4.4
const MOSS_MASK_SIZE: int = 256
## 路（x 在這個寬度內）與空地不種樹
const PATH_HALF_WIDTH: float = 4.0
const FLAG_REVERSAL: String = "ch1.reversal_seen"
const FLAG_SLIMES: String = "ch1.slimes_cleared"
const FLAG_GATE_TALK: String = "ch1.gate_talked"
const FLAG_MISFIRE: String = "ch1.misfire_seen"
const FLAG_AFTER_TALK: String = "ch1.after_slimes_talked"
const GATE_DIALOGUE: String = "ch1_forest_gate"
const AFTER_DIALOGUE: String = "ch1_after_slimes"
## 教學戰席菈拿錯的那一瓶（statuses.json 的來源）
const PANIC_VIAL: String = "sera_panic_vial"
## 史萊姆都倒了之後隔多久席菈才開口（等最後一刀的停頓與橫幅）
const AFTER_TALK_DELAY: float = 1.6
## 第一次反轉之後隔多久席菈才開口（等碎裂與金光演完）
const GATE_TALK_DELAY: float = 1.2
## 席菈一開始站在諾恩的左前方（玩家的鏡頭一開場就看得到她），之後自己跟在後面
const SERA_START_OFFSET: Vector3 = Vector3(-1.7, 0.0, -2.6)

var slimes: Array[Slime] = []
var miasma: PoisonMist
var sera: Sera
## 離瘴氣裡那段對話還有幾秒（< 0＝沒有在等）
var _gate_talk_in: float = -1.0
## 離戰後那段對話還有幾秒（< 0＝沒有在等）
var _after_talk_in: float = -1.0
## 拿錯的那一瓶演到哪：0＝還沒舉弩、1＝舉弩喊過了，等藥瓶砸中
var _misfire_step: int = 0
var _rng := RandomNumberGenerator.new()
## 每棵樹：x、z＝位置，y＝大小（地面的苔與草叢照這個長）
var _trees := PackedVector3Array()

@onready var _player: PlayerController = $Player
@onready var _hud: Hud = $Hud


func _ready() -> void:
	_rng.seed = 20261114
	_build_environment()
	_build_forest()
	_build_ground()
	_build_miasma()
	_build_spores()
	_mark("MiasmaEdge", MIASMA_POS + Vector3(0, 0, MIASMA_RADIUS))
	_mark("SlimeGlade", GLADE_POS)
	var spawn: Marker3D = $Spawn
	_player.global_position = spawn.global_position
	# 截圖用：`-- --level=corrupt_forest --cam-yaw=90` 鏡頭繞到諾恩的側面（180＝正面）
	var args: Dictionary = App.parse_user_args(OS.get_cmdline_user_args())
	if args.has("cam-yaw"):
		_player.yaw = deg_to_rad(float(str(args["cam-yaw"])))
	# 截圖用：`--at=x,z` 把諾恩放到別的地方（空地前面＝--at=0,-5）
	var at: PackedStringArray = str(args.get("at", "")).split(",")
	if at.size() == 2:
		_player.global_position = Vector3(float(at[0]), spawn.global_position.y, float(at[1]))
	_player.snap_camera()
	_spawn_sera()
	# 連拍用（scripts/burst.sh）：`--burst-on=reversal` 進場 1.5 秒後讓諾恩吸到瘴氣、`--burst-on=vial` 讓席菈射一瓶，從那一刻開始拍
	var burst_on: String = str(args.get("burst-on", ""))
	if burst_on == "reversal" or burst_on == "vial":
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			App.burst_start_in(1)
			if burst_on == "vial":
				sera.brain.request()
			else:
				_player.status_effects.apply_source("miasma"))
	if not bool(Game.session.state.get_flag(FLAG_SLIMES, false)):
		_spawn_slimes()
	elif not bool(Game.session.state.get_flag(FLAG_AFTER_TALK, false)):
		_after_talk_in = AFTER_TALK_DELAY  # 打完、話還沒講就離開的存檔：讀回來接著講
	QualityPreset.apply_tree(self, Settings.quality as QualityPreset.Level)


func footstep_surface(_p: Vector3) -> String:
	return "snow"  # 現有的三種裡最像落葉軟土的；之後加「土」的腳步聲


func _physics_process(delta: float) -> void:
	if not Game.session.in_story():
		return
	var st: GameState = Game.session.state
	if not bool(st.get_flag(FLAG_REVERSAL, false)) and _player.status_effects.has("poison"):
		Game.session.set_flag(FLAG_REVERSAL, true)
		_hud.show_center_lines("CH1_REVERSAL_LINE1", "CH1_REVERSAL_LINE2")
		# 在瘴氣裡反轉的才講那段話（先被史萊姆撞到中毒的話，正在打架，不打斷）
		if not bool(st.get_flag(FLAG_GATE_TALK, false)) and miasma.global_position.distance_to(_player.global_position) < MIASMA_RADIUS + 1.0:
			_gate_talk_in = GATE_TALK_DELAY
	if _gate_talk_in >= 0.0:
		_gate_talk_in -= delta
		if _gate_talk_in < 0.0 and Game.start_dialogue(GATE_DIALOGUE):
			Game.session.set_flag(FLAG_GATE_TALK, true)
	_tick_misfire()
	if not slimes.is_empty() and not bool(st.get_flag(FLAG_SLIMES, false)) and slimes_alive() == 0:
		Game.session.set_flag(FLAG_SLIMES, true)
		_hud.show_banner("CH1_SLIMES_CLEARED", 4.0)
		_after_talk_in = AFTER_TALK_DELAY
	if _after_talk_in >= 0.0:
		_after_talk_in -= delta
		if _after_talk_in < 0.0 and not Game.start_dialogue(AFTER_DIALOGUE):
			_after_talk_in = 0.2  # 別的對話還沒講完：等一下再試


## 教學戰的誤射（劇本節點 2）：舉弩的時候喊一句；藥瓶砸中之後抱頭道歉，畫面中間寫這兩種狀態反轉成什麼。
## 只演一次——之後她射平常的那一瓶。倒下重來（旗標跟著退回檢查點）會再演。
func _tick_misfire() -> void:
	if sera.vial_source != PANIC_VIAL:
		return
	if _misfire_step == 0:
		if sera.brain.is_aiming():
			_misfire_step = 1
			_hud.show_bark(sera, "BARK_SERA_PANIC")
	elif sera.last_vial != null and (not is_instance_valid(sera.last_vial) or sera.last_vial.landed):
		sera.vial_source = Sera.VIAL_SOURCE
		Game.session.set_flag(FLAG_MISFIRE, true)
		_hud.show_bark(sera, "BARK_SERA_MISFIRE", 3.4)
		_hud.show_center_lines("CH1_MISFIRE_LINE1", "CH1_MISFIRE_LINE2", 5.0, Hud.CENTER_LINE2_COLOR)


func slimes_alive() -> int:
	var n: int = 0
	for s: Slime in slimes:
		if is_instance_valid(s) and not s.health.is_dead():
			n += 1
	return n


func _spawn_sera() -> void:
	sera = Sera.new()
	sera.name = "Sera"
	sera.target = _player
	sera.position = _player.global_position + SERA_START_OFFSET
	# 面向諾恩（開場看得到她的臉）
	sera.rotation.y = atan2(SERA_START_OFFSET.x, SERA_START_OFFSET.z)
	if not bool(Game.session.state.get_flag(FLAG_MISFIRE, false)):
		sera.vial_source = PANIC_VIAL
	add_child(sera)


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


## 黃昏的紫黑森林：頭頂暗、地平線泛紫的天，冷的月光、暗紫的環境光，
## 體積霧讓遠處的樹一層一層淡進紫色裡（畫質低時 QualityPreset 換成深度霧）。
func _build_environment() -> void:
	var dusk := ProceduralSkyMaterial.new()
	dusk.sky_top_color = Color(0.05, 0.03, 0.1)
	dusk.sky_horizon_color = Color(0.3, 0.19, 0.4)
	dusk.sky_curve = 0.25
	dusk.ground_horizon_color = dusk.sky_horizon_color
	dusk.ground_bottom_color = Color(0.07, 0.05, 0.11)
	dusk.sun_angle_max = 6.0
	var sky := Sky.new()
	sky.sky_material = dusk
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.36, 0.55)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.03
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
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter("path_half_width", PATH_HALF_WIDTH * 0.65)
	mat.set_shader_parameter("path_z_from", GLADE_POS.z)
	mat.set_shader_parameter("glade_center", Vector2(GLADE_POS.x, GLADE_POS.z))
	mat.set_shader_parameter("glade_radius", GLADE_RADIUS)
	mat.set_shader_parameter("ground_size", GROUND_SIZE)
	mat.set_shader_parameter("moss_mask", ImageTexture.create_from_image(moss_mask(_trees)))
	plane.material = mat
	mesh.mesh = plane
	body.add_child(mesh)
	add_child(body)


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
		var size: float = _rng.randf_range(0.85, 1.3)
		forest.add_child(_tree(p, size, _rng.randf_range(0.0, TAU)))
		_trees.append(Vector3(p.x, size, p.z))
		placed += 1
	for i: int in 9:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(side * _rng.randf_range(PATH_HALF_WIDTH * 0.8, PATH_HALF_WIDTH + 2.0), 0.0, 16.0 - float(i) * 4.5)
		forest.add_child(_small_prop(MUSHROOM_MODEL if i % 3 != 0 else BUSH_MODEL, at, _rng.randf_range(0.0, TAU), i % 3 != 0))
	forest.add_child(GrassTufts.create(_grass_spots(), _rng))


## 草叢的位置：一團一團地長（每團十幾叢），路邊與樹腳下（土丘的邊緣）多幾團。
func _grass_spots() -> PackedVector3Array:
	var spots := PackedVector3Array()
	for c: int in GRASS_PATCHES:
		var center := Vector3(_rng.randf_range(-28.0, 28.0), 0.0, _rng.randf_range(-38.0, 26.0))
		if c % 5 == 0:
			center.x = (-1.0 if c % 2 == 0 else 1.0) * _rng.randf_range(PATH_HALF_WIDTH * 0.7, PATH_HALF_WIDTH * 1.6)
		elif c % 5 < 3 and not _trees.is_empty():
			var tree: Vector3 = _trees[_rng.randi_range(0, _trees.size() - 1)]
			center = Vector3(tree.x, 0.0, tree.z) + Vector3.RIGHT.rotated(Vector3.UP, _rng.randf_range(0.0, TAU)) * 3.0 * tree.y
		var spread: float = _rng.randf_range(0.8, 2.4)
		for i: int in _rng.randi_range(8, 22):
			var p: Vector3 = center + Vector3(_rng.randfn(0.0, spread), 0.0, _rng.randfn(0.0, spread))
			if grass_spot_ok(p):
				spots.append(p)
	return spots


## 樹腳下的苔：一張 MOSS_MASK_SIZE 見方的灰階圖蓋住整片地面，離樹越近越白（forest_ground.gdshader 照它長苔）。純函式。
static func moss_mask(trees: PackedVector3Array) -> Image:
	var img := Image.create_empty(MOSS_MASK_SIZE, MOSS_MASK_SIZE, false, Image.FORMAT_R8)
	var per_meter: float = float(MOSS_MASK_SIZE) / GROUND_SIZE
	for tree: Vector3 in trees:
		var center := Vector2(tree.x, tree.z) * per_meter + Vector2.ONE * float(MOSS_MASK_SIZE) * 0.5
		var reach: float = TREE_MOSS_RADIUS * tree.y * per_meter
		for y: int in range(maxi(int(center.y - reach), 0), mini(int(center.y + reach) + 2, MOSS_MASK_SIZE)):
			for x: int in range(maxi(int(center.x - reach), 0), mini(int(center.x + reach) + 2, MOSS_MASK_SIZE)):
				var near: float = 1.0 - smoothstep(0.55, 1.0, Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center) / reach)
				if near > img.get_pixel(x, y).r:
					img.set_pixel(x, y, Color(near, 0, 0))
	return img


## 這個位置可不可以長草：路的中間與空地（打架的地方）不長。純函式。
static func grass_spot_ok(p: Vector3) -> bool:
	if absf(p.x) < PATH_HALF_WIDTH * 0.6 and p.z > GLADE_POS.z:
		return false
	return Vector2(p.x - GLADE_POS.x, p.z - GLADE_POS.z).length() > GLADE_RADIUS - 1.0


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
		_self_lit(look, 0.45)
		var light := OmniLight3D.new()
		light.light_color = Color(0.45, 0.75, 1.0)
		light.light_energy = 1.6
		light.omni_range = 5.0
		light.position = Vector3(0, 0.8, 0)
		root.add_child(light)
	return root


## 讓模型自己發光（發光色＝它原本的顏色）：夜光毒蕈在暗處要看得出是亮的。
static func _self_lit(model: Node3D, energy: float) -> void:
	for n: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for surface: int in mi.mesh.get_surface_count():
			var src := mi.get_active_material(surface) as BaseMaterial3D
			if src == null:
				continue
			var mat := src.duplicate() as BaseMaterial3D
			mat.emission_enabled = true
			mat.emission = Color.BLACK
			mat.emission_texture = mat.albedo_texture
			mat.emission_energy_multiplier = energy
			mi.set_surface_override_material(surface, mat)


## 飄在林子裡的孢子：慢慢往上飄的紫色亮點，淡入淡出。只是氣氛。
func _build_spores() -> void:
	var spores := CPUParticles3D.new()
	spores.name = "Spores"
	spores.amount = 520
	spores.lifetime = 10.0
	spores.preprocess = 10.0
	spores.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	spores.emission_box_extents = Vector3(15.0, 1.5, 30.0)
	spores.position = Vector3(0.0, 1.5, -6.0)
	spores.direction = Vector3.UP
	spores.spread = 60.0
	spores.gravity = Vector3.ZERO
	spores.initial_velocity_min = 0.05
	spores.initial_velocity_max = 0.25
	spores.scale_amount_min = 0.5
	spores.scale_amount_max = 1.3
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	spores.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(0.13, 0.13)
	quad.material = ParticleLook.material(Color(0.85, 0.6, 1.0, 1.0), true)
	spores.mesh = quad
	spores.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(spores)


func _build_miasma() -> void:
	miasma = PoisonMist.create(MIASMA_RADIUS, "miasma")
	miasma.name = "Miasma"
	miasma.position = MIASMA_POS
	add_child(miasma)
