class_name PotionCrate
extends Node3D
## 新版前十分鐘的藥箱（D-209）：守衛背上那只木箱，牠倒下時摔在旁邊。箱蓋掀開、正面的木板摔斷了兩片，
## 裡面一格一格的瓶架大多是空瓶和碎瓶，只有角落兩瓶還封著、裝著發綠光的藥（霧蛇毒劑）。
## 走近按互動鍵 → 拿走那兩瓶（`PotionBelt.grant_once`：死亡重試、讀檔都只會拿到一次）→ `rb.potion_found` → 對話 `rb_potion_found`。
## 提示「按 {key}　拿走藥瓶」在 HUD 下方中央（InteractPrompt）。節點名 RbPotionCrate＝任務標記。
## 全部程式生成：木板（plank_wood.gdshader）、鐵條、車床轉出來的玻璃瓶（Lathe）、瓶裡自己發光的藥、一盞很弱的綠光。

const NODE_NAME: String = "RbPotionCrate"
const RANGE: float = 2.0
const GRANT_ID: String = "rb.guardian_crate"
const ITEM: String = PlayerController.PORTABLE_ITEM
const AMOUNT: int = 2
const DIALOGUE: String = "rb_potion_found"
const FOUND_FLAG: String = "rb.potion_found"
const HINT_KEY: String = "RB_CRATE_HINT"

## 箱子（本地座標：開口朝上、正面朝 +Z、原點在箱底中心）
const CASE_W: float = 0.86
const CASE_H: float = 0.24
const CASE_D: float = 0.42
const WALL: float = 0.024
## 瓶架：一排 5 格、前後 2 排
const COLUMNS: int = 5
const ROWS: int = 2
const BOTTLE_H: float = 0.215
const BOTTLE_R: float = 0.037
## 箱底鋪的乾草有多高（瓶子站在上面，瓶頸露出箱口）
const STRAW_Y: float = 0.055
## 封好的兩瓶在哪兩格（最右邊那一行的前後兩格＝「角落兩瓶」）
const FULL_SLOTS: Array[Vector2i] = [Vector2i(4, 0), Vector2i(4, 1)]
## 空瓶（還立著）、破瓶（只剩下半截）的格子；其他格子是空的
const EMPTY_SLOTS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(2, 1), Vector2i(3, 0)]
const BROKEN_SLOTS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0)]
const GLOW_COLOR: Color = Color(0.45, 1.0, 0.4)
const GLOW_ENERGY: float = 1.1
## 瓶裡的藥自己發光的顏色與強度（太強會曝成白色：要看得出是綠的）
const LIQUID_COLOR: Color = Color(0.22, 1.0, 0.25)
const LIQUID_ENERGY: float = 2.6
## 整個放大：牠兩公尺半高，背上的箱子比人用的大一號
const SIZE: float = 1.3
## 摔下來：從牠背上的高度掉到地上要幾秒
const DROP_HEIGHT: float = 1.5
const DROP_SEC: float = 0.38

## 藥已經被拿走了
var taken: bool = false
## 還在半空（剛從牠背上摔下來）：落地之前不能拿
var dropping: bool = false
var _player: PlayerController
var _near: bool = false
var _full: Array[Node3D] = []
var _glow: OmniLight3D
var _case: Node3D
var _look := InteriorLook.new()


func _ready() -> void:
	name = NODE_NAME
	add_to_group("interact_prompts")
	_build()
	if Game.session != null and Game.session.state.get_flag(FOUND_FLAG, false):
		taken = true
		_show_taken(false)


func is_near() -> bool:
	return _near


## 還封著的那幾瓶（拿走之後是 0）
func full_bottles_shown() -> int:
	var n: int = 0
	for b: Node3D in _full:
		if b.visible:
			n += 1
	return n


func glow() -> OmniLight3D:
	return _glow


func interact_hint() -> Dictionary:
	if not _near or taken:
		return {}
	return {"fmt": TranslationServer.translate(HINT_KEY), "action": "interact", "progress": -1.0}


func _physics_process(_delta: float) -> void:
	if taken or dropping:
		_near = false
		return
	if _player == null or not is_instance_valid(_player):
		for n: Node in get_tree().get_nodes_in_group("player"):
			_player = n as PlayerController
			break
	_near = _player != null and not Game.is_player_locked() and not _player.health.is_dead() \
		and _flat_distance(_player.global_position) <= RANGE
	if _near and Input.is_action_just_pressed("interact"):
		take()


func _flat_distance(p: Vector3) -> float:
	var g: Vector3 = global_position
	return Vector2(p.x - g.x, p.z - g.z).length()


## 拿走那兩瓶（測試也用）。回傳這次有沒有拿。
func take() -> bool:
	if taken or dropping or Game.is_in_dialogue():
		return false
	taken = true
	_near = false
	PotionBelt.new(Game.session.state).grant_once(GRANT_ID, ITEM, AMOUNT)
	_show_taken(true)
	Sfx.play_at(self, "glass_clink", global_position + Vector3(0.0, 0.3, 0.0), -4.0)
	Game.session.set_flag(FOUND_FLAG, true)
	Game.start_dialogue(DIALOGUE)
	return true


## 牠倒下的那一刻：箱子從牠背上摔下來（先在半空、落地時一小團雪）。讀檔時不呼叫，箱子本來就在地上。
## delay 秒之後才出現（牠先跪下、往前倒，箱子才甩出去）；出現之前整個藏起來、也不能互動。
func drop_in(delay: float = 0.0) -> void:
	if _case == null:
		return
	_case.position.y = DROP_HEIGHT
	_case.rotation_degrees = Vector3(-38.0, 0.0, 24.0)
	dropping = true
	visible = false
	var t := create_tween()
	if delay > 0.0:
		t.tween_interval(delay)
	t.tween_callback(show)
	t.tween_property(_case, "position:y", 0.0, DROP_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_case, "rotation_degrees", _rest_rotation(), DROP_SEC)
	t.tween_callback(_on_landed)


func _rest_rotation() -> Vector3:
	# 一角陷在雪裡：往前傾一點、歪一點
	return Vector3(5.0, 0.0, -3.0)


func _on_landed() -> void:
	dropping = false
	Sfx.play_at(self, "blunt_weak", global_position, -8.0)
	Sfx.play_at(self, "glass_clink", global_position + Vector3(0.0, 0.2, 0.0), -9.0)
	# 一次性粒子：先建好、擺好位置才開始噴（D-208）
	var ps := CPUParticles3D.new()
	ps.name = "LandPuff"
	ps.emitting = false
	ps.one_shot = true
	ps.amount = 22
	ps.lifetime = 0.9
	ps.explosiveness = 0.9
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ps.emission_box_extents = Vector3(CASE_W * 0.5, 0.03, CASE_D * 0.5)
	ps.direction = Vector3.UP
	ps.spread = 70.0
	ps.initial_velocity_min = 0.5
	ps.initial_velocity_max = 1.3
	ps.gravity = Vector3(0.0, -2.2, 0.0)
	ps.scale_amount_min = 0.5
	ps.scale_amount_max = 1.1
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	quad.material = ParticleLook.material(Color(0.8, 0.86, 0.94, 0.5))
	ps.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ps.color_ramp = ramp
	add_child(ps)
	ps.position = Vector3(0.0, 0.05, 0.0)
	ps.emitting = true
	get_tree().create_timer(2.0).timeout.connect(ps.queue_free)


func _show_taken(animate: bool) -> void:
	for b: Node3D in _full:
		b.visible = false
	if _glow == null:
		return
	if animate and is_inside_tree():
		create_tween().tween_property(_glow, "light_energy", 0.0, 0.5)
	else:
		_glow.light_energy = 0.0


# ---------------------------------------------------------------- 外觀

func _build() -> void:
	scale = Vector3.ONE * SIZE
	_case = Node3D.new()
	_case.name = "Case"
	_case.rotation_degrees = _rest_rotation()
	add_child(_case)
	# 舊木頭：顏色壓暗（諾恩的提燈就在旁邊，太淺會整片發黃）、板縫不要太黑（近看才不會變成一條一條的斑馬紋）
	var wood: ShaderMaterial = _look.plank("rb_crate", Color(0.2, 0.15, 0.11), 0.11, 0.9, {"seam_dark": 0.55, "base_roughness": 0.9})
	var wood_in: ShaderMaterial = _look.plank("rb_crate_in", Color(0.13, 0.1, 0.08), 0.11, 0.9, {"seam_dark": 0.4, "base_roughness": 0.95})
	var iron: Material = Undertaker.frame_iron_material()
	# 箱底、背板、兩側
	_box(_case, "Bottom", Vector3(CASE_W, WALL, CASE_D), Vector3(0.0, WALL * 0.5, 0.0), wood)
	_box(_case, "Back", Vector3(CASE_W, CASE_H, WALL), Vector3(0.0, CASE_H * 0.5, -CASE_D * 0.5 + WALL * 0.5), wood)
	for sx: float in [-1.0, 1.0]:
		_box(_case, "Side", Vector3(WALL, CASE_H, CASE_D), Vector3(sx * (CASE_W - WALL) * 0.5, CASE_H * 0.5, 0.0), wood)
	# 正面：三片橫板，上面兩片摔斷了（露出裡面的瓶子）——最下面一片完整、中間只剩左邊一截、最上面只剩右端一小段
	var slat: float = CASE_H / 3.0
	var fz: float = CASE_D * 0.5 - WALL * 0.5
	_box(_case, "Front0", Vector3(CASE_W, slat - 0.004, WALL), Vector3(0.0, slat * 0.5, fz), wood)
	_box(_case, "Front1", Vector3(CASE_W * 0.3, slat - 0.004, WALL), Vector3(-CASE_W * 0.35, slat * 1.5, fz), wood)
	_box(_case, "Front2", Vector3(CASE_W * 0.12, slat - 0.004, WALL), Vector3(-CASE_W * 0.44, slat * 2.5, fz), wood)
	# 摔斷的那兩片躺在箱子前面的雪上（不跟著箱子歪：直接掛在自己底下）
	var piece_a: MeshInstance3D = _box(self, "Splinter0", Vector3(CASE_W * 0.46, WALL, slat - 0.006), Vector3(0.12, 0.016, CASE_D * 0.5 + 0.2), wood)
	piece_a.rotation_degrees = Vector3(4.0, 17.0, 0.0)
	var piece_b: MeshInstance3D = _box(self, "Splinter1", Vector3(CASE_W * 0.3, WALL, slat - 0.006), Vector3(-0.3, 0.014, CASE_D * 0.5 + 0.34), wood)
	piece_b.rotation_degrees = Vector3(0.0, -31.0, 3.0)
	# 鐵條：兩道箍（前、後、蓋子上各一段）＋四個直角
	for sx: float in [-0.27, 0.27]:
		_box(_case, "StrapBack", Vector3(0.05, CASE_H + 0.006, 0.008), Vector3(sx, CASE_H * 0.5, -CASE_D * 0.5 - 0.004), iron)
		_box(_case, "StrapFront", Vector3(0.05, slat, 0.008), Vector3(sx, slat * 0.5, CASE_D * 0.5 + 0.004), iron)
		_box(_case, "StrapBottom", Vector3(0.05, 0.008, CASE_D + 0.012), Vector3(sx, -0.002, 0.0), iron)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var h: float = CASE_H if sz < 0.0 or sx < 0.0 else slat
			_box(_case, "Corner", Vector3(0.034, h + 0.004, 0.034), Vector3(sx * (CASE_W * 0.5 - 0.012), h * 0.5, sz * (CASE_D * 0.5 - 0.012)), iron)
	_build_lid(wood, iron)
	_build_rack(wood_in)
	_build_bottles()
	_build_harness(iron)
	_build_shards()
	# 瓶子的綠光：很弱、範圍小、不打高光（濕石板上不要多一顆刺眼的亮點，第 70 輪的教訓）
	_glow = OmniLight3D.new()
	_glow.name = "Glow"
	_glow.light_color = GLOW_COLOR
	_glow.light_energy = GLOW_ENERGY
	_glow.light_specular = 0.0
	_glow.omni_range = 2.8
	_glow.omni_attenuation = 1.4
	_glow.shadow_enabled = false
	_glow.light_volumetric_fog_energy = 0.8
	_glow.position = Vector3(_slot_pos(FULL_SLOTS[0]).x - 0.05, CASE_H + 0.12, 0.05)
	_case.add_child(_glow)
	ContactShadow.attach(self, 0.75, 0.6)


## 箱蓋：鉸鏈在背板上緣，往後掀開、靠在背後
func _build_lid(wood: Material, iron: Material) -> void:
	var hinge := Node3D.new()
	hinge.name = "Lid"
	hinge.position = Vector3(0.0, CASE_H, -CASE_D * 0.5)
	hinge.rotation_degrees.x = -112.0
	_case.add_child(hinge)
	_box(hinge, "Board", Vector3(CASE_W + 0.02, WALL, CASE_D + 0.01), Vector3(0.0, WALL * 0.5, CASE_D * 0.5), wood)
	# 蓋子內側釘了一層深色的氈（瓶子的綠光襯在深色上才看得清楚）
	var felt := StandardMaterial3D.new()
	felt.albedo_color = Color(0.07, 0.085, 0.075)
	felt.roughness = 1.0
	_box(hinge, "Felt", Vector3(CASE_W - 0.05, 0.006, CASE_D - 0.05), Vector3(0.0, -0.003, CASE_D * 0.5), felt)
	for sx: float in [-0.27, 0.27]:
		_box(hinge, "Strap", Vector3(0.05, 0.008, CASE_D + 0.02), Vector3(sx, WALL + 0.004, CASE_D * 0.5), iron)
		# 鉸鏈
		_box(hinge, "Hinge", Vector3(0.07, 0.03, 0.03), Vector3(sx, 0.0, 0.0), iron)
	# 蓋子前緣的搭扣（已經彈開）
	_box(hinge, "Hasp", Vector3(0.06, 0.012, 0.07), Vector3(0.0, WALL + 0.006, CASE_D + 0.02), iron)


## 瓶架：隔板＋箱底的乾草
func _build_rack(wood_in: Material) -> void:
	var straw := StandardMaterial3D.new()
	straw.albedo_color = Color(0.36, 0.3, 0.17)
	straw.roughness = 1.0
	_box(_case, "Straw", Vector3(CASE_W - WALL * 2.0, STRAW_Y - WALL, CASE_D - WALL * 2.0), Vector3(0.0, WALL + (STRAW_Y - WALL) * 0.5, 0.0), straw)
	var inner_w: float = CASE_W - WALL * 2.0
	var inner_d: float = CASE_D - WALL * 2.0
	var div_h: float = 0.11
	for c: int in range(1, COLUMNS):
		var x: float = -inner_w * 0.5 + inner_w * float(c) / float(COLUMNS)
		_box(_case, "Divider", Vector3(0.01, div_h, inner_d), Vector3(x, STRAW_Y + div_h * 0.5, 0.0), wood_in)
	_box(_case, "DividerLong", Vector3(inner_w, div_h, 0.01), Vector3(0.0, STRAW_Y + div_h * 0.5, 0.0), wood_in)
	# 幾撮翹出來的乾草
	var tuft_mat := StandardMaterial3D.new()
	tuft_mat.albedo_color = Color(0.5, 0.42, 0.22)
	tuft_mat.roughness = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7103
	for i: int in 14:
		var tuft: MeshInstance3D = _box(_case, "Tuft", Vector3(0.006, 0.006, rng.randf_range(0.07, 0.15)),
			Vector3(rng.randf_range(-inner_w * 0.45, inner_w * 0.45), STRAW_Y + rng.randf_range(0.0, 0.03), rng.randf_range(-inner_d * 0.4, inner_d * 0.4)), tuft_mat)
		tuft.rotation_degrees = Vector3(rng.randf_range(-40.0, 40.0), rng.randf_range(0.0, 180.0), 0.0)


func _slot_pos(slot: Vector2i) -> Vector3:
	var inner_w: float = CASE_W - WALL * 2.0
	var inner_d: float = CASE_D - WALL * 2.0
	var x: float = -inner_w * 0.5 + inner_w * (float(slot.x) + 0.5) / float(COLUMNS)
	var z: float = -inner_d * 0.5 + inner_d * (float(slot.y) + 0.5) / float(ROWS)
	return Vector3(x, STRAW_Y, z)


func _build_bottles() -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.32, 0.5, 0.36, 0.34)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.08
	glass.metallic_specular = 0.9
	glass.rim_enabled = true
	glass.rim = 0.6
	glass.rim_tint = 0.3
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dull := glass.duplicate() as StandardMaterial3D
	dull.albedo_color = Color(0.3, 0.36, 0.33, 0.3)
	var liquid := StandardMaterial3D.new()
	liquid.albedo_color = Color(0.1, 0.32, 0.08)
	liquid.roughness = 0.3
	liquid.emission_enabled = true
	liquid.emission = LIQUID_COLOR
	liquid.emission_energy_multiplier = LIQUID_ENERGY
	var wax := StandardMaterial3D.new()
	wax.albedo_color = Color(0.36, 0.07, 0.05)
	wax.roughness = 0.55
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.74, 0.7, 0.58)
	paper.roughness = 0.95
	var bottle: ArrayMesh = bottle_mesh()
	var stump: ArrayMesh = broken_bottle_mesh()
	var fill: ArrayMesh = liquid_mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4411
	for slot: Vector2i in FULL_SLOTS:
		var b := Node3D.new()
		b.name = "FullBottle%d" % _full.size()
		b.position = _slot_pos(slot)
		b.rotation_degrees = Vector3(rng.randf_range(-4.0, 4.0), rng.randf_range(0.0, 360.0), rng.randf_range(-4.0, 4.0))
		_case.add_child(b)
		_mesh(b, "Liquid", fill, liquid)
		_mesh(b, "Glass", bottle, glass)
		var seal := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.016
		sm.bottom_radius = 0.019
		sm.height = 0.03
		sm.radial_segments = 10
		seal.name = "Seal"
		seal.mesh = sm
		seal.material_override = wax
		seal.position.y = BOTTLE_H - 0.008
		b.add_child(seal)
		# 標籤：貼在瓶肚上的一小張紙（字太小，不寫）
		var tag := MeshInstance3D.new()
		var tq := QuadMesh.new()
		tq.size = Vector2(0.046, 0.05)
		tag.name = "Label"
		tag.mesh = tq
		tag.material_override = paper
		tag.position = Vector3(0.0, 0.07, BOTTLE_R + 0.001)
		b.add_child(tag)
		_full.append(b)
	for slot: Vector2i in EMPTY_SLOTS:
		var e := Node3D.new()
		e.name = "EmptyBottle"
		e.position = _slot_pos(slot)
		e.rotation_degrees = Vector3(rng.randf_range(-9.0, 9.0), rng.randf_range(0.0, 360.0), rng.randf_range(-9.0, 9.0))
		_case.add_child(e)
		_mesh(e, "Glass", bottle, dull)
	for slot: Vector2i in BROKEN_SLOTS:
		var s := Node3D.new()
		s.name = "BrokenBottle"
		s.position = _slot_pos(slot)
		s.rotation_degrees.y = rng.randf_range(0.0, 360.0)
		_case.add_child(s)
		_mesh(s, "Glass", stump, dull)


## 玻璃瓶：圓肚、短頸、厚唇（車床旋轉體；從上往下描＝法線朝外）
static func bottle_mesh() -> ArrayMesh:
	var lathe := Lathe.new(14)
	lathe.add_profile(PackedVector2Array([
		Vector2(0.0, BOTTLE_H), Vector2(0.012, BOTTLE_H), Vector2(0.016, BOTTLE_H - 0.006), Vector2(0.013, BOTTLE_H - 0.016),
		Vector2(0.013, 0.165), Vector2(0.03, 0.135), Vector2(BOTTLE_R, 0.112), Vector2(BOTTLE_R, 0.018),
		Vector2(0.031, 0.0), Vector2(0.0, 0.0),
	]))
	return lathe.commit()


## 破瓶：只剩下半截，斷口高低不平
static func broken_bottle_mesh() -> ArrayMesh:
	var lathe := Lathe.new(9)
	lathe.add_profile(PackedVector2Array([
		Vector2(BOTTLE_R * 0.92, 0.075), Vector2(BOTTLE_R, 0.05), Vector2(BOTTLE_R, 0.018), Vector2(0.031, 0.0), Vector2(0.0, 0.0),
	]))
	return lathe.commit()


## 瓶裡的藥：比瓶肚小一圈，裝到瓶肩下面
static func liquid_mesh() -> ArrayMesh:
	var lathe := Lathe.new(12)
	var r: float = BOTTLE_R - 0.006
	lathe.add_profile(PackedVector2Array([
		Vector2(0.0, 0.118), Vector2(r * 0.8, 0.118), Vector2(r, 0.105), Vector2(r, 0.02), Vector2(r * 0.8, 0.006), Vector2(0.0, 0.006),
	]))
	return lathe.commit()


## 原本把箱子綁在牠背上的皮帶：兩條，一條斷了，攤在箱子後面的雪上；背板上兩個鐵環
func _build_harness(iron: Material) -> void:
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.1, 0.075, 0.06)
	leather.roughness = 0.75
	var back_z: float = -CASE_D * 0.5
	for sx: float in [-0.27, 0.27]:
		_box(_case, "Ring", Vector3(0.06, 0.05, 0.02), Vector3(sx, CASE_H * 0.62, back_z - 0.014), iron)
	var strap_a: MeshInstance3D = _box(self, "Belt0", Vector3(0.05, 0.012, 0.62), Vector3(-0.33, 0.012, back_z - 0.55), leather)
	strap_a.rotation_degrees.y = 14.0
	var strap_b: MeshInstance3D = _box(self, "Belt1", Vector3(0.05, 0.012, 0.34), Vector3(0.36, 0.012, back_z - 0.44), leather)
	strap_b.rotation_degrees.y = -28.0
	var strap_c: MeshInstance3D = _box(self, "Belt2", Vector3(0.05, 0.012, 0.26), Vector3(0.62, 0.012, back_z - 0.2), leather)
	strap_c.rotation_degrees.y = 61.0
	var buckle: MeshInstance3D = _box(self, "Buckle", Vector3(0.075, 0.016, 0.06), Vector3(-0.41, 0.016, back_z - 0.86), iron)
	buckle.rotation_degrees.y = 14.0


## 雪上的碎玻璃：十幾片小小的、朝不同方向翹的薄片（會反光）
func _build_shards() -> void:
	var shard := StandardMaterial3D.new()
	shard.albedo_color = Color(0.5, 0.6, 0.56, 0.32)
	shard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shard.roughness = 0.05
	shard.metallic_specular = 1.0
	shard.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rng := RandomNumberGenerator.new()
	rng.seed = 9127
	for i: int in 10:
		var a: float = rng.randf_range(-0.9, 2.2)
		var r: float = rng.randf_range(0.5, 0.9)
		var pos := Vector3(sin(a) * r, 0.012, cos(a) * r * 0.75)
		var piece: MeshInstance3D = _box(self, "Shard", Vector3(rng.randf_range(0.015, 0.035), 0.003, rng.randf_range(0.012, 0.03)), pos, shard)
		piece.rotation_degrees = Vector3(rng.randf_range(-25.0, 25.0), rng.randf_range(0.0, 360.0), rng.randf_range(-25.0, 25.0))
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.name = node_name
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi, true)
	return mi


func _mesh(parent: Node3D, node_name: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	return mi
