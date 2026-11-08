class_name NineBreathSite
extends Node3D
## 九息可保存物（docs/design/02-gameplay.md「九息」）：場景這一側，狀態機在 NineBreath（D-012）。
##
## BROKEN：廢墟＋地上淡淡的鐘紋；諾恩走近時 HUD 下方中央顯示「可以重現：南街石拱」與代價（RestorePrompt，D-059），
##         按住 nine_breath（V／Y）時顯示重現後的輪廓（預覽，不付代價），按滿 1 秒才發動，放開就取消。
## RESTORED：石拱重現、只有它發光、畫面去飽和、九聲心跳倒數；完整碰撞（擋鐵架拋擲），站在裡面的人被推出。
## SPENT：化灰（粒子），石拱消失只剩廢墟；記憶已付（GameState.memories_paid），讀檔後保持。

signal restored
signal spent
signal breath(index: int)

const PROMPT_RANGE: float = 5.0
const HOLD_SEC: float = 1.0
## 重現用的 InputMap 動作（鍵鼠 V、手把 Y）
const ACTION: String = "nine_breath"
const FROST: Color = Color(0.62, 0.86, 1.0)
const STONE: Color = Color(0.34, 0.33, 0.33)
## 九息期間的畫面飽和度
const DESAT: float = 0.12
const GHOST_SHADER: String = "res://src/world/restore_ghost.gdshader"
## 重現的石拱平常的發光強度（心跳時亮到三倍再退回）
const ARCH_GLOW: float = 0.85
# 石拱的形狀（D-129）：拱腳高度、拱洞半徑、拱圈外緣半徑、拱石塊數（單數，正中間是拱心石）
const ARCH_SPRING: float = 2.0
const ARCH_INNER: float = 1.6
const ARCH_OUTER: float = 2.15
const ARCH_SIDES: int = 48
const VOUSSOIRS: int = 11
## 拱心石的外緣比其他拱石高多少
const KEYSTONE_RISE: float = 0.16
const WALL_DEPTH: float = 1.2
# 拱石、拱墩線腳凸出牆面多少（每一面）
const TRIM_OUT: float = 0.07

@export var object_id: String = "south_arch"
@export var memory_id: String = "arch_father_last_talk"
@export var label_key: String = "NB_SITE_SOUTH_ARCH"
@export var cost_key: String = "NB_COST_ARCH_FATHER"
## 測試可以指定；空的就用 Game.session.state
var state: GameState
var nb: NineBreath
## 按住的進度（秒）
var hold: float = 0.0
## 截圖用：停在預覽（按住到一半）不發動
var debug_preview: bool = false

var _player: PlayerController
var _ruin: Node3D
var _arch: CSGCombiner3D
var _arch_mat: ShaderMaterial
var _ghost_mat: ShaderMaterial
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _ash: CPUParticles3D
var _env: Environment
var _env_saturation: float = 1.0
var _prompt_shown: bool = false


func _ready() -> void:
	add_to_group("nine_breath_site")
	nb = NineBreath.new(object_id, memory_id)
	nb.breath.connect(_on_breath)
	nb.finished.connect(_on_finished)
	_build()
	nb.load_from(_state())
	_apply_phase(false)


func _state() -> GameState:
	if state != null:
		return state
	return Game.session.state if Game.session != null else GameState.new()


func is_solid() -> bool:
	return nb.phase == NineBreath.Phase.RESTORED


func prompt_shown() -> bool:
	return _prompt_shown


## 提示全文（測試用）：走近時三行（可以重現／代價／按住），重現中是倒數。
func prompt_text() -> String:
	if is_counting():
		return countdown_text()
	if _prompt_shown:
		return "\n".join(prompt_lines())
	return ""


## HUD 用的三行：可以重現什麼、代價、按住哪個鍵（照目前的裝置）。
func prompt_lines() -> PackedStringArray:
	var key: String = InputGlyphs.label_for_action(ACTION, App.last_device)
	return PackedStringArray([tr(label_key), tr(cost_key), hold_hint_format().replace("{key}", key)])


## 「按住 {key}　重現 9 秒」（{key} 留著，HUD 在手把模式換成按鈕圖示）。
func hold_hint_format() -> String:
	return tr("NB_HOLD_HINT")


func hold_ratio() -> float:
	return clampf(hold / HOLD_SEC, 0.0, 1.0)


## 重現中（石拱立著、倒數中）。
func is_counting() -> bool:
	return nb.phase == NineBreath.Phase.RESTORED


## 還剩幾秒（心跳點亮著幾顆）。
func breaths_left() -> int:
	if not is_counting():
		return 0
	return clampi(int(ceil(nb.remaining() - 0.001)), 0, NineBreath.BREATHS)


func countdown_text() -> String:
	return tr("NB_BREATHS_LEFT").format([breaths_left()])


func is_previewing() -> bool:
	return nb.phase == NineBreath.Phase.BROKEN and hold > 0.0


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		for n: Node in get_tree().get_nodes_in_group("player"):
			_player = n as PlayerController
			break
	match nb.phase:
		NineBreath.Phase.BROKEN:
			var near: bool = player_near()
			_set_prompt(near)
			update_hold(delta, near and Input.is_action_pressed("nine_breath"))
			_ring_mat.albedo_color.a = 0.12 + 0.1 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.003))
		NineBreath.Phase.RESTORED:
			nb.tick(delta, _state())


func player_near() -> bool:
	if _player == null or Game.is_player_locked():
		return false
	return _player.global_position.distance_to(global_position) <= PROMPT_RANGE


## 按住／放開。按滿 HOLD_SEC 發動；放開歸零（不付代價）。回傳是否在這一幀發動。
func update_hold(delta: float, pressed: bool) -> bool:
	if nb.phase != NineBreath.Phase.BROKEN:
		hold = 0.0
		return false
	hold = hold + delta if pressed else 0.0
	if debug_preview:
		hold = HOLD_SEC * 0.6
	_arch.visible = hold > 0.0
	_arch.material_override = _ghost_mat
	_set_journal_highlight(hold > 0.0)
	if hold > 0.0:
		# 預覽輪廓隨按住的進度從地面往上長出來（D-046）
		_ghost_mat.set_shader_parameter("fill", clampf(hold / HOLD_SEC, 0.0, 1.0))
		_ghost_mat.set_shader_parameter("base_y", global_position.y)
	if hold >= HOLD_SEC:
		return activate()
	return false


## 預覽中：日記裡這段記憶標亮（JournalView 在畫面一角顯示這張卡）。
func _set_journal_highlight(on: bool) -> void:
	var j: Journal = Game.journal
	if j == null:
		return
	if on:
		j.highlighted = memory_id
	elif j.highlighted == memory_id:
		j.highlighted = ""


func activate() -> bool:
	if not nb.activate(_state()):
		return false
	hold = 0.0
	_set_journal_highlight(false)
	_apply_phase(true)
	_push_out_heartbeats()
	Sfx.play_at(self, "bell_ninth", global_position + Vector3.UP * 3.0, -2.0, 0.0, 12.0)
	restored.emit()
	return true


func _on_breath(i: int) -> void:
	Sfx.play_flat(self, "heartbeat", -4.0 + float(i) * 0.4)
	var t := create_tween()
	t.tween_property(_arch_mat, "shader_parameter/glow_energy", ARCH_GLOW * 3.0, 0.06)
	t.tween_property(_arch_mat, "shader_parameter/glow_energy", ARCH_GLOW, 0.6)
	breath.emit(i)


## 重現的石拱被東西撞上（送葬者的鐵架）：冷光猛亮一下再退回（D-053）。石拱不在時不作用。
var flash_count: int = 0


func flash(strength: float = 5.0) -> void:
	if not is_solid() or _arch_mat == null:
		return
	flash_count += 1
	var t := create_tween()
	t.tween_property(_arch_mat, "shader_parameter/glow_energy", ARCH_GLOW * strength, 0.04)
	t.tween_property(_arch_mat, "shader_parameter/glow_energy", ARCH_GLOW, 0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _on_finished() -> void:
	_apply_phase(true)
	spent.emit()


func _apply_phase(animate: bool) -> void:
	match nb.phase:
		NineBreath.Phase.BROKEN:
			_arch.visible = false
			_arch.use_collision = false
			_ring.visible = true
		NineBreath.Phase.RESTORED:
			_arch.visible = true
			_arch.material_override = _arch_mat
			_arch.use_collision = true
			_ring.visible = false
			_set_prompt(false)
			_desaturate(true, animate)
		NineBreath.Phase.SPENT:
			_arch.visible = false
			_arch.use_collision = false
			_ring.visible = false
			_set_prompt(false)
			_desaturate(false, animate)
			if animate:
				_ash.restart()
				_ash.emitting = true


func _set_prompt(on: bool) -> void:
	if on == _prompt_shown:
		return
	_prompt_shown = on


## 站在石拱實體範圍裡的人往前或往後推出去（不讓人卡在牆裡）。
func _push_out_heartbeats() -> void:
	for n: Node in get_tree().get_nodes_in_group("heartbeat"):
		var hb: Node3D = n as Node3D
		if hb == null or hb is Caravan:
			continue
		var local: Vector3 = to_local(hb.global_position)
		if absf(local.x) <= 2.6 and absf(local.z) <= 0.9 and absf(local.x) >= 1.5:
			var out_z: float = 1.4 if local.z >= 0.0 else -1.4
			hb.global_position = to_global(Vector3(local.x, local.y, out_z))


func _desaturate(on: bool, animate: bool) -> void:
	if _env == null:
		for n: Node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
			_env = (n as WorldEnvironment).environment
			if _env != null:
				_env_saturation = _env.adjustment_saturation
				break
	if _env == null or not _env.adjustment_enabled:
		return
	var to: float = DESAT if on else _env_saturation
	if animate:
		create_tween().tween_property(_env, "adjustment_saturation", to, 0.5 if on else 1.2)
	else:
		_env.adjustment_saturation = to


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	return m


func _build() -> void:
	# 廢墟：兩截斷柱（有碰撞）＋散落的石塊
	_ruin = Node3D.new()
	_ruin.name = "Ruin"
	add_child(_ruin)
	var stone: StandardMaterial3D = _mat(STONE)
	for side: Array in [[-2.05, 1.5], [2.05, 0.9]]:
		var stump := CSGBox3D.new()
		stump.size = Vector3(0.9, float(side[1]), 1.2)
		stump.position = Vector3(float(side[0]), float(side[1]) * 0.5, 0)
		stump.material = stone
		stump.use_collision = true
		_ruin.add_child(stump)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 7:
		var b := CSGBox3D.new()
		b.size = Vector3(rng.randf_range(0.4, 0.9), rng.randf_range(0.25, 0.5), rng.randf_range(0.4, 0.8))
		var x: float = rng.randf_range(-3.2, 3.2)
		if absf(x) < 1.3:
			x = signf(x) * 1.3 + x * 0.3 if x != 0.0 else 1.4
		b.position = Vector3(x, b.size.y * 0.5, rng.randf_range(-1.6, 1.6))
		b.rotation_degrees = Vector3(rng.randf_range(-12, 12), rng.randf_range(0, 90), rng.randf_range(-12, 12))
		b.material = stone
		_ruin.add_child(b)
	# 重現後的石拱（預覽時是半透明輪廓）
	_arch = CSGCombiner3D.new()
	_arch.name = "Arch"
	add_child(_arch)
	var block := CSGBox3D.new()
	block.size = Vector3(5.0, 4.6, 1.2)
	block.position = Vector3(0, 2.3, 0)
	_arch.add_child(block)
	var hole := CSGCylinder3D.new()
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	hole.radius = ARCH_INNER
	hole.height = 2.0
	# D-129：預設 8 邊的圓柱挖出來的拱頂是尖的多邊形（預覽輪廓像五角形的屋子）
	hole.sides = ARCH_SIDES
	hole.rotation_degrees = Vector3(90, 0, 0)
	hole.position = Vector3(0, ARCH_SPRING, 0)
	_arch.add_child(hole)
	var cut := CSGBox3D.new()
	cut.operation = CSGShape3D.OPERATION_SUBTRACTION
	cut.size = Vector3(ARCH_INNER * 2.0, ARCH_SPRING, 2.0)
	cut.position = Vector3(0, ARCH_SPRING * 0.5, 0)
	_arch.add_child(cut)
	_build_arch_trim()
	# 重現的石拱（D-043）：跟鎮上石牆同一個 shader（看得出是石頭），石縫透出冷光、邊緣亮，
	# 心跳時整體亮一下。不再是整塊發白的板子。
	_arch_mat = ShaderMaterial.new()
	_arch_mat.shader = load(FrostbridgeLook.HALF_TIMBER_SHADER) as Shader
	_arch_mat.set_shader_parameter("stone_height", 99.0)
	_arch_mat.set_shader_parameter("block_scale", 1.25)
	_arch_mat.set_shader_parameter("stone_color", Color(0.34, 0.36, 0.4))
	_arch_mat.set_shader_parameter("glow_color", FROST)
	_arch_mat.set_shader_parameter("glow_energy", ARCH_GLOW)
	_ghost_mat = ShaderMaterial.new()
	_ghost_mat.shader = load(GHOST_SHADER) as Shader
	_ghost_mat.set_shader_parameter("color", FROST)
	_ghost_mat.set_shader_parameter("height", 4.6)
	_ghost_mat.set_shader_parameter("block_scale", 1.25)
	# D-132：拱圈上的石縫沿半徑放射（一塊塊楔形拱石），不是牆上的水平錯縫
	for m: ShaderMaterial in [_arch_mat, _ghost_mat]:
		m.set_shader_parameter("arch_voussoirs", VOUSSOIRS)
		m.set_shader_parameter("arch_center", Vector2(0.0, ARCH_SPRING))
		m.set_shader_parameter("arch_inner", ARCH_INNER)
		m.set_shader_parameter("arch_outer", ARCH_OUTER)
		m.set_shader_parameter("arch_key_extra", KEYSTONE_RISE)
	_arch.material_override = _ghost_mat
	_arch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 地上的鐘紋：一圈淡淡的環
	var torus := TorusMesh.new()
	torus.inner_radius = 2.6
	torus.outer_radius = 2.75
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_mat.albedo_color = Color(FROST, 0.18)
	_ring = MeshInstance3D.new()
	_ring.name = "BellRing"
	_ring.mesh = torus
	_ring.material_override = _ring_mat
	_ring.scale = Vector3(1, 0.02, 1)
	_ring.position = Vector3(0, 0.03, 0)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	# 化灰：一次性的灰燼粒子，從石拱的形狀往上飄散
	_ash = CPUParticles3D.new()
	_ash.name = "Ash"
	_ash.emitting = false
	_ash.one_shot = true
	_ash.amount = 220
	_ash.lifetime = 2.6
	_ash.explosiveness = 0.75
	_ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_ash.emission_box_extents = Vector3(2.5, 2.3, 0.6)
	_ash.position = Vector3(0, 2.3, 0)
	_ash.direction = Vector3(0, 1, 0)
	_ash.spread = 60.0
	_ash.initial_velocity_min = 0.3
	_ash.initial_velocity_max = 1.4
	_ash.gravity = Vector3(0.25, 0.35, 0)
	_ash.scale_amount_min = 0.5
	_ash.scale_amount_max = 1.2
	var quad := QuadMesh.new()
	# 柔邊圓點（D-056）：比方形面片大一點，看起來一樣大但邊緣是散的灰
	quad.size = Vector2(0.09, 0.09)
	quad.material = ParticleLook.material(Color(0.7, 0.72, 0.76, 0.85), false, BaseMaterial3D.BILLBOARD_PARTICLES)
	_ash.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.92, 1.0, 1.0))
	ramp.set_color(1, Color(0.4, 0.4, 0.42, 0.0))
	_ash.color_ramp = ramp
	add_child(_ash)


## 拱圈與線腳（D-129）：一圈楔形拱石（中間的拱心石高一點、凸多一點）、拱腳的線腳、柱腳、頂上的壓頂。
## 都凸出牆面一點，預覽輪廓（fresnel）與重現後的石頭都看得出「這是一座拱」，不是牆上挖一個洞。
func _build_arch_trim() -> void:
	var step: float = PI / float(VOUSSOIRS)
	var gap: float = 0.012
	for i: int in VOUSSOIRS:
		var key: bool = i * 2 + 1 == VOUSSOIRS
		var a0: float = step * float(i) + gap
		var a1: float = step * float(i + 1) - gap
		var outer: float = ARCH_OUTER + (KEYSTONE_RISE if key else 0.0)
		var out: float = TRIM_OUT + (0.05 if key else 0.0)
		var poly := PackedVector2Array()
		for p: Vector2 in [Vector2(cos(a0), sin(a0)) * ARCH_INNER, Vector2(cos(a1), sin(a1)) * ARCH_INNER,
				Vector2(cos(a1), sin(a1)) * outer, Vector2(cos(a0), sin(a0)) * outer]:
			poly.append(p + Vector2(0, ARCH_SPRING))
		var stone := CSGPolygon3D.new()
		stone.name = "Keystone" if key else "Voussoir%d" % i
		stone.polygon = poly
		stone.depth = WALL_DEPTH + out * 2.0
		# CSGPolygon3D 從 z=0 往 -Z 擠出
		stone.position = Vector3(0, 0, stone.depth * 0.5)
		_arch.add_child(stone)
	for sx: float in [-1.0, 1.0]:
		var pier_x: float = sx * (ARCH_INNER + 2.5) * 0.5
		var impost := CSGBox3D.new()
		impost.name = "Impost"
		impost.size = Vector3(2.5 - ARCH_INNER + 0.08, 0.16, WALL_DEPTH + TRIM_OUT * 2.0)
		impost.position = Vector3(pier_x, ARCH_SPRING - 0.08, 0)
		_arch.add_child(impost)
		var plinth := CSGBox3D.new()
		plinth.name = "Plinth"
		plinth.size = Vector3(2.5 - ARCH_INNER + 0.08, 0.32, WALL_DEPTH + TRIM_OUT * 2.0)
		plinth.position = Vector3(pier_x, 0.16, 0)
		_arch.add_child(plinth)
	var coping := CSGBox3D.new()
	coping.name = "Coping"
	coping.size = Vector3(5.16, 0.18, WALL_DEPTH + TRIM_OUT * 2.0)
	coping.position = Vector3(0, 4.6 - 0.09, 0)
	_arch.add_child(coping)


func _exit_tree() -> void:
	_set_journal_highlight(false)
