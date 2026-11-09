extends StoryLevel
## 第 1 章段落 5：一百七十二階（白盒，D-152；07-chapter1-door.md）。
## 梨販家地窖下的長階梯：方形螺旋往下（繞中間的石柱轉兩圈半），霧＋油燈只照得到前後十幾級。
## 照攻略，第一個陷阱是射箭：走近時諾恩攔住大家 → 玩家可以往前丟石頭試探（互動），
## 或直接走過去（踩到絆線）。兩種都掉下一桶髒水——攻略筆記「射箭陷阱」被推翻；樓梯深處傳來小孩的笑聲。
## 走到底是一扇門：段落 6「不可互動的門」——柯德舉著叉子出來（攻略標「不可互動」的門後面是一家人），
## 席菈摘下徽章；諾恩的回答記成柯德的第一印象（ch1.kord_first）。柯德說「那先吃點東西」→ 走進白晝城（daylight 關卡，D-154）。
##
## 路線：轉角 k 的位置是 CORNERS[k % 4]、高度 -k×DROP；轉角是平台、轉角之間是一段斜坡（看得到的台階＋看不到的斜坡碰撞）。
## 路線參數 s＝沿著路線的水平公尺數（轉角 k 在 s = k×SIDE）。

const QUEST: String = "ch1_main"
## 路線中心線離中間石柱中心多遠（方形的半邊長）
const H: float = 3.4
## 走道寬（從石柱表面到外牆）
const W: float = 2.4
const SIDE: float = H * 2.0
const DROP: float = 0.85
const FLIGHTS: int = 10
const STEPS_PER_FLIGHT: int = 6
const CORNERS: Array[Vector2] = [Vector2(-H, H), Vector2(H, H), Vector2(H, -H), Vector2(-H, -H)]
const CEILING_Y: float = 3.2
## 陷阱在這個轉角的平台（第 6 段之後）
const TRAP_CORNER: int = 6
## 走到離平台入口這麼近（沿著路線）諾恩就攔住大家
const WARN_AHEAD: float = 3.0
## 石頭從手上丟到平台中央的時間
const THROW_SEC: float = 0.55
## 水落下到開始講話
const TRAP_TALK_DELAY: float = 0.9
## 笑聲在這一句出現
const LAUGH_LINE: String = "DLG_CH1_TRAP_004"
const DOOR_RANGE: float = 1.8
## 樓梯底的出生點離最後一個轉角多遠（不要一出生就站在門口）
const BOTTOM_SPAWN_BACK: float = 2.2
## 門往裡開的角度（段落 6：柯德開門出來）
const DOOR_OPEN_DEG: float = -82.0
const SHEILA_BEHIND: float = 4.2
const MISHA_BEHIND: float = 5.6
const MISHA_SPEED: float = 4.2
## 樓梯頂的出生點（往下走了一點，頂層平台留給席菈和彌夏）
const TOP_SPAWN_S: float = 1.8
## 彌夏走在路線中心線的右邊這麼遠（不跟席菈疊在一起）
const MISHA_SIDE: float = 0.55
const LAMP_RANGE: float = 6.5
const LAMP_ENERGY: float = 1.5

const STONE: Color = Color(0.3, 0.28, 0.25)
const STONE_DARK: Color = Color(0.2, 0.19, 0.18)
const WALL: Color = Color(0.34, 0.32, 0.3)
const WOOD: Color = Color(0.3, 0.21, 0.13)
const DAYLIGHT: Color = Color(0.8, 0.86, 1.0)
const DOOR_GLOW: Color = Color(1.0, 0.94, 0.84)

var _stone_mat: StandardMaterial3D
var _dark_mat: StandardMaterial3D
var _bucket: Node3D
var _puddle: MeshInstance3D
var _throwing: bool = false
var _trap_talk_started: bool = false
var _door_inside: bool = false
var _misha_s: float = 0.0
var _misha: Puppet
var _lead: Marker3D
var _door_pivot: Node3D
var _doorway: MeshInstance3D
var _door_leak: OmniLight3D
var _kord: Puppet


func _ready() -> void:
	_rng.seed = 172
	_stone_mat = _mat(STONE, 0.92)
	_dark_mat = _mat(STONE_DARK, 0.95)
	_build_environment()
	_build_shaft()
	_build_flights()
	_build_trap()
	_build_bottom()
	_init_story()
	var dev_args: Dictionary = App.parse_user_args(OS.get_cmdline_user_args())
	# 開發用：`-- --level=stairs` 直接進來 → 照正式流程走到拿到油燈（段落 4 結束）
	if not (Game.session.quests.stage_of(QUEST) in ["stairs", "daylight_gate"]):
		load("res://scenes/levels/frostbridge.gd").call("dev_start_day", Game.session, "stairs")
	if dev_args.has("stairs-sprung"):
		Game.session.set_flag("ch1.stair_warned", true)
		Game.session.set_flag("ch1.stair_trap_sprung", true)
		Game.session.state.set_flag("ch1.stair_trap_talked", true)
	# 截圖用：`--stairs-door` 走到樓梯底、柯德開門出來（段落 6 的第一句）
	if dev_args.has("stairs-door"):
		Game.session.set_flag("ch1.stair_trap_sprung", true)
		Game.session.set_flag("ch1.stairs_bottom", true)
	_place_player(str(dev_args.get("stairs-at", "")))
	_brighten_lamp()
	_build_party()
	if bool(Game.session.state.get_flag("ch1.stair_trap_sprung", false)):
		_show_sprung(false, Vector3.INF)
	if bool(Game.session.state.get_flag("ch1.met_kord", false)):
		_show_door_open(false)
	Game.dialogue_started.connect(_on_dialogue_started)
	Game.dialogue_ended.connect(_on_dialogue_ended)
	if dev_args.has("stairs-door"):
		open_gate_door.call_deferred()


# ---------------------------------------------------------------- 路線

static func corner(k: int) -> Vector3:
	var c: Vector2 = CORNERS[posmod(k, 4)]
	return Vector3(c.x, -float(k) * DROP, c.y)


## 路線上 s 的那一點（高度照地面：轉角平台是平的，平台之間是斜坡）。
static func path_point(s: float) -> Vector3:
	var sc: float = clampf(s, 0.0, SIDE * FLIGHTS)
	var k: int = mini(int(sc / SIDE), FLIGHTS - 1)
	var u: float = sc - float(k) * SIDE
	var a: Vector3 = corner(k)
	var b: Vector3 = corner(k + 1)
	var dir: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var p: Vector3 = a + dir * u
	p.y = _flight_y(k, u)
	return p


## 第 k 段走了 u 公尺時的地面高度。
static func _flight_y(k: int, u: float) -> float:
	var ramp: float = SIDE - W
	var t: float = clampf((u - W * 0.5) / ramp, 0.0, 1.0)
	return -float(k) * DROP - t * DROP


## 某一點在路線上的 s（螺旋疊了好幾圈，用高度挑最近的那一段）。
static func path_param(p: Vector3) -> float:
	var best_s: float = 0.0
	var best_cost: float = INF
	for k: int in FLIGHTS:
		var a: Vector3 = corner(k)
		var b: Vector3 = corner(k + 1)
		var dir: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
		var rel: Vector3 = p - a
		var u: float = clampf(rel.x * dir.x + rel.z * dir.z, 0.0, SIDE)
		var q: Vector3 = a + dir * u
		var cost: float = Vector2(p.x - q.x, p.z - q.z).length() + absf(p.y - _flight_y(k, u)) * 2.0
		if cost < best_cost:
			best_cost = cost
			best_s = float(k) * SIDE + u
	return best_s


## 陷阱平台的入口（絆線）在路線上的 s。
static func trap_entrance_s() -> float:
	return float(TRAP_CORNER) * SIDE - W * 0.5


static func bottom_s() -> float:
	return float(FLIGHTS) * SIDE


func ground_y(p: Vector3) -> float:
	return path_point(path_param(p)).y


## 路線上 s 那一點的前進方向（水平）。
static func path_dir(s: float) -> Vector3:
	var k: int = clampi(int(clampf(s, 0.0, SIDE * FLIGHTS - 0.01) / SIDE), 0, FLIGHTS - 1)
	var a: Vector3 = corner(k)
	var b: Vector3 = corner(k + 1)
	return Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()


# ---------------------------------------------------------------- 流程

## 地底下只有這盞燈：照得比地面上遠一點（不然霧裡只看得到諾恩自己）。
## 油燈投影子（第 1 章的規則：白晝城裡只有油燈投影子）。第 39 輪先關掉過：畫面右側一整條黑帶＝諾恩自己擋了油燈；
## 第 44 輪查到是 SELF_LAYER 沒有獨佔（諾恩的幾何同時在第 1 層，shadow_caster_mask 照樣命中），修好之後打開。
func _brighten_lamp() -> void:
	var player: Node3D = get_node_or_null("Player") as Node3D
	var light: OmniLight3D = player.find_child("LanternLight", true, false) as OmniLight3D if player != null else null
	if light != null:
		light.omni_range = LAMP_RANGE
		light.light_energy = LAMP_ENERGY
		light.shadow_enabled = true


func _place_player(at: String) -> void:
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player == null:
		return
	var s: float = TOP_SPAWN_S
	if Game.session.quests.stage_of(QUEST) in ["daylight_gate", "daylight_city"] or at == "bottom":
		s = bottom_s() - BOTTOM_SPAWN_BACK
	elif at == "trap":
		s = trap_entrance_s() - WARN_AHEAD + 0.6
	elif at == "mid":
		s = SIDE * 2.5
	var p: Vector3 = path_point(s)
	player.global_position = p + Vector3(0, 0.05, 0)
	var d: Vector3 = path_dir(s)
	player.rotation.y = atan2(-d.x, -d.z)
	_misha_s = maxf(s - MISHA_BEHIND, 0.0)


func _physics_process(delta: float) -> void:
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player == null:
		return
	var s: float = path_param(player.global_position)
	_update_party(delta, s)
	if Game.is_player_locked():
		return
	var st: GameState = Game.session.state
	var stage: String = Game.session.quests.stage_of(QUEST)
	var sprung: bool = bool(st.get_flag("ch1.stair_trap_sprung", false))
	var entrance: float = trap_entrance_s()
	if not sprung and not _throwing:
		if not bool(st.get_flag("ch1.stair_warned", false)) and s >= entrance - WARN_AHEAD and s < entrance:
			Game.start_dialogue("ch1_stair_warn")
			return
		# 沒丟石頭就走上平台：踩到絆線，水淋在諾恩身上
		if s >= entrance and s < entrance + W:
			spring_trap(true)
			return
		if Input.is_action_just_pressed("interact") and can_throw():
			throw_stone()
	if stage == "stairs" and s >= bottom_s() - W * 0.5:
		Game.session.set_flag("ch1.stairs_bottom", true)
	var at_door: bool = player.global_position.distance_to(_door_pos()) <= DOOR_RANGE
	if at_door and not _door_inside:
		match Game.session.quests.stage_of(QUEST):
			"daylight_gate":
				open_gate_door()
			"daylight_city":
				enter_daylight()
	_door_inside = at_door


## 段落 6「不可互動的門」（測試也用）：門往裡開、柯德舉著叉子走出來 → 對話。
func open_gate_door() -> void:
	if bool(Game.session.state.get_flag("ch1.door_opened", false)) and _kord != null:
		return
	Game.session.set_flag("ch1.door_opened", true)
	_show_door_open(true)
	Game.start_dialogue("ch1_kord_door")


func _show_door_open(animate: bool) -> void:
	if _door_pivot != null:
		if animate:
			create_tween().tween_property(_door_pivot, "rotation_degrees:y", DOOR_OPEN_DEG, 0.6).set_trans(Tween.TRANS_SINE)
		else:
			_door_pivot.rotation_degrees.y = DOOR_OPEN_DEG
	if _doorway != null:
		_doorway.visible = true
	if _door_leak != null:
		_door_leak.light_energy = 2.2
		_door_leak.omni_range = 5.0
	if _kord == null:
		_kord = Puppet.new()
		_kord.name = "Kord"
		# 柯德：瘦、衣領兜不住脖子（07）——灰褐的舊衣、白灰色滾邊
		_kord.coat_color = Color(0.36, 0.33, 0.28)
		_kord.trim_color = Color(0.7, 0.68, 0.62)
		add_child(_kord)
		var hammer: Node = _kord.hand("R").get_node_or_null("BellHammer") if _kord.hand("R") != null else null
		if hammer != null:
			hammer.queue_free()
		var fork := MeshInstance3D.new()
		fork.name = "Fork"
		var fm := BoxMesh.new()
		fm.size = Vector3(0.03, 0.03, 0.42)
		fork.mesh = fm
		fork.material_override = _mat(Color(0.55, 0.55, 0.56), 0.4)
		if _kord.hand("R") != null:
			_kord.hand("R").add_child(fork)
			fork.position = Vector3(0, -0.05, -0.18)
		var out_at: Vector3 = _door_pos() + Vector3(-0.75, 0.0, 0.0)
		_kord.rotation.y = PI * 0.5
		if animate:
			_kord.global_position = _door_pos() + Vector3(0.1, 0.0, 0.0)
			create_tween().tween_property(_kord, "global_position", out_at, 0.7).set_delay(0.3)
		else:
			_kord.global_position = out_at


func _on_kord_talked() -> void:
	enter_daylight()


## 跟著柯德走進門（段落 7，D-154）：設旗標（白晝城的檢查點）→ 換關卡。讀檔停在 daylight_city 時走到門口也一樣。
func enter_daylight() -> void:
	if Game.session.quests.stage_of(QUEST) != "daylight_city":
		return
	Game.session.set_flag("ch1.entered_daylight", true)
	if Game.LEVELS.has("daylight"):
		Game.go_to_level.call_deferred("daylight")


## 互動提示（D-065）：攔住大家之後、走上平台之前。
func can_throw() -> bool:
	var st: GameState = Game.session.state
	if _throwing or bool(st.get_flag("ch1.stair_trap_sprung", false)) or not bool(st.get_flag("ch1.stair_warned", false)):
		return false
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player == null or Game.is_player_locked():
		return false
	var s: float = path_param(player.global_position)
	return s >= trap_entrance_s() - WARN_AHEAD - 1.5 and s < trap_entrance_s()


func interact_hint() -> Dictionary:
	if not can_throw():
		return {}
	return {"fmt": TranslationServer.translate("CH1_STAIR_THROW_HINT"), "action": "interact", "progress": -1.0}


## 往前丟一塊石頭：飛到平台中央 → 機關觸發（水落在空的平台上）。
func throw_stone() -> void:
	if not can_throw():
		return
	_throwing = true
	var player: Node3D = get_node("Player") as Node3D
	var from: Vector3 = player.global_position + Vector3(0, 1.4, 0)
	var to: Vector3 = corner(TRAP_CORNER) + Vector3(0, 0.08, 0)
	var stone := MeshInstance3D.new()
	stone.name = "TossedStone"
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.1
	stone.mesh = sm
	stone.material_override = _stone_mat
	add_child(stone)
	stone.global_position = from
	Sfx.play_at(self, "whoosh", from, -8.0)
	var fly := func(f: float) -> void:
		stone.global_position = from.lerp(to, f) + Vector3(0, sin(f * PI) * 0.9, 0)
	var land := func() -> void:
		Sfx.play_at(self, "blunt", to, -14.0)
		spring_trap(false)
	var t := create_tween()
	t.tween_method(fly, 0.0, 1.0, THROW_SEC)
	t.tween_callback(land)


## 機關觸發（測試也用）：設旗標（攻略筆記「射箭陷阱」被推翻）、木桶翻倒、水落下，稍後開對話。
func spring_trap(on_player: bool) -> void:
	if bool(Game.session.state.get_flag("ch1.stair_trap_sprung", false)):
		return
	_throwing = false
	Game.session.state.set_flag("ch1.stair_warned", true)
	Game.session.state.set_flag("ch1.stair_trap_soaked", on_player)
	Game.session.set_flag("ch1.stair_trap_sprung", true)
	var player: Node3D = get_node_or_null("Player") as Node3D
	var hit: Vector3 = player.global_position if on_player and player != null else corner(TRAP_CORNER)
	_show_sprung(true, hit)
	Sfx.play_at(self, "water_splash", hit + Vector3(0, 1.0, 0), -2.0)
	get_tree().create_timer(TRAP_TALK_DELAY).timeout.connect(_start_trap_talk)


func _start_trap_talk() -> void:
	if _trap_talk_started or not is_inside_tree():
		return
	_trap_talk_started = true
	Game.start_dialogue("ch1_stair_trap")


func _on_dialogue_started(r: DialogueRunner) -> void:
	r.line_shown.connect(_on_line_shown)


func _on_line_shown(_speaker: String, text_key: String) -> void:
	if text_key == LAUGH_LINE:
		Sfx.play_at(self, "child_laugh", corner(FLIGHTS) + Vector3(0, 1.2, 0), 2.0, 0.0, 14.0)


func _on_dialogue_ended(dialogue_id: String) -> void:
	if dialogue_id == "ch1_stair_trap":
		Game.session.state.set_flag("ch1.stair_trap_talked", true)
	elif dialogue_id == "ch1_kord_door":
		_on_kord_talked()


## 機關觸發後的樣子：木桶倒掛、平台上一灘髒水（animate＝剛觸發，水從桶裡倒下來）。
func _show_sprung(animate: bool, hit: Vector3) -> void:
	if _bucket != null:
		if animate:
			create_tween().tween_property(_bucket, "rotation_degrees:z", 128.0, 0.25).set_trans(Tween.TRANS_BACK)
		else:
			_bucket.rotation_degrees.z = 128.0
	if _puddle != null:
		_puddle.visible = true
		if hit.is_finite():
			_puddle.global_position = Vector3(hit.x, corner(TRAP_CORNER).y + 0.012, hit.z)
	if animate and hit.is_finite():
		var water := CPUParticles3D.new()
		water.name = "DirtyWater"
		water.one_shot = true
		water.emitting = true
		water.amount = 90
		water.lifetime = 0.7
		water.explosiveness = 0.75
		water.direction = Vector3.DOWN
		water.spread = 12.0
		water.initial_velocity_min = 1.0
		water.initial_velocity_max = 2.4
		water.gravity = Vector3(0, -14.0, 0)
		water.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		water.emission_sphere_radius = 0.2
		water.scale_amount_min = 0.05
		water.scale_amount_max = 0.12
		var quad := QuadMesh.new()
		quad.size = Vector2(1, 1)
		quad.material = ParticleLook.material(Color(0.42, 0.38, 0.3, 0.8))
		water.mesh = quad
		add_child(water)
		water.global_position = _bucket.global_position if _bucket != null else hit + Vector3(0, 2.4, 0)
		get_tree().create_timer(2.0).timeout.connect(water.queue_free)


func _door_pos() -> Vector3:
	return corner(FLIGHTS) + Vector3(W * 0.5, 0.0, 0.0)


# ---------------------------------------------------------------- 同伴：席菈跟著路線上的點走（不然會被石柱擋住）；彌夏是人偶

func _build_party() -> void:
	var player: Node3D = get_node_or_null("Player") as Node3D
	var s: float = path_param(player.global_position) if player != null else 0.0
	_lead = Marker3D.new()
	_lead.name = "SheilaLead"
	add_child(_lead)
	_lead.global_position = path_point(maxf(s - SHEILA_BEHIND, 0.0))
	var ally := Sheila.new()
	ally.name = "Sheila"
	ally.leader = _lead
	ally.position = path_point(maxf(s - SHEILA_BEHIND, 0.0)) + Vector3(0, 0.05, 0) - _side(s) * 0.4
	add_child(ally)
	_misha = Puppet.new()
	_misha.name = "Misha"
	_misha.coat_color = Color(0.16, 0.27, 0.21)
	_misha.trim_color = Color(0.3, 0.26, 0.2)
	add_child(_misha)
	var hammer: Node = _misha.hand("R").get_node_or_null("BellHammer") if _misha.hand("R") != null else null
	if hammer != null:
		hammer.queue_free()
	_misha.global_position = path_point(_misha_s) + _side(_misha_s) * MISHA_SIDE


## 路線 s 處的右手邊（水平）。
static func _side(s: float) -> Vector3:
	return path_dir(s).cross(Vector3.UP)


func _update_party(delta: float, player_s: float) -> void:
	if _lead != null:
		_lead.global_position = path_point(maxf(player_s - SHEILA_BEHIND, 0.0))
	if _misha == null:
		return
	var want: float = maxf(player_s - MISHA_BEHIND, 0.0)
	var step: float = clampf(want - _misha_s, -MISHA_SPEED * delta, MISHA_SPEED * delta)
	# 落後太多（讀檔、瞬移）就直接跟上
	if absf(want - _misha_s) > 8.0:
		step = want - _misha_s
	_misha_s += step
	_misha.global_position = path_point(_misha_s) + _side(_misha_s) * MISHA_SIDE
	var d: Vector3 = path_dir(_misha_s)
	_misha.rotation.y = atan2(-d.x, -d.z)
	_misha.set_move_speed(absf(step) / maxf(delta, 0.0001))


# ---------------------------------------------------------------- 場景

func _mat(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.005, 0.005, 0.008)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.32, 0.4)
	env.ambient_light_energy = 0.16
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_hdr_threshold = 1.1
	env.ssao_enabled = true
	# 油燈的光在霧裡：前後十幾級之外就看不到（07：「用霧和油燈範圍只看得到前後十幾級」）
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.035
	env.volumetric_fog_albedo = Color(0.55, 0.5, 0.44)
	env.volumetric_fog_length = 20.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.02, 0.025)
	env.fog_density = 0.02
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)


func _solid(node_name: String, size: Vector3, xf: Transform3D, mat: Material, collide: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.transform = xf
	add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.name = node_name + "Body"
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		cs.shape = box
		body.add_child(cs)
		body.transform = xf
		add_child(body)
	return mi


func _box_at(node_name: String, size: Vector3, pos: Vector3, mat: Material, collide: bool = true) -> MeshInstance3D:
	return _solid(node_name, size, Transform3D(Basis.IDENTITY, pos), mat, collide)


func _build_shaft() -> void:
	var bottom: float = corner(FLIGHTS).y
	var top: float = CEILING_Y
	var tall: float = top - bottom + 1.0
	var mid_y: float = (top + bottom - 1.0) * 0.5
	var wall_mat: StandardMaterial3D = _mat(WALL, 0.97)
	# 中間的石柱（走道內緣）
	var ph: float = H - W * 0.5
	_box_at("Pillar", Vector3(ph * 2.0, tall, ph * 2.0), Vector3(0, mid_y, 0), wall_mat)
	# 外牆（走道外緣）
	var oh: float = H + W * 0.5
	var t: float = 0.4
	_box_at("WallN", Vector3(oh * 2.0 + t * 2.0, tall, t), Vector3(0, mid_y, -oh - t * 0.5), wall_mat)
	_box_at("WallS", Vector3(oh * 2.0 + t * 2.0, tall, t), Vector3(0, mid_y, oh + t * 0.5), wall_mat)
	_box_at("WallW", Vector3(t, tall, oh * 2.0), Vector3(-oh - t * 0.5, mid_y, 0), wall_mat)
	_box_at("WallE", Vector3(t, tall, oh * 2.0), Vector3(oh + t * 0.5, mid_y, 0), wall_mat)
	# 頂上：天花板＋地窖口（白天的光從上面漏下來）
	_box_at("Ceiling", Vector3(oh * 2.0, 0.3, oh * 2.0), Vector3(0, top + 0.15, 0), wall_mat, false)
	var c0: Vector3 = corner(0)
	var hatch := _box_at("Hatch", Vector3(1.0, 0.05, 0.8), Vector3(c0.x, top - 0.01, c0.z), _glow_mat(DAYLIGHT, 2.4), false)
	hatch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sun := SpotLight3D.new()
	sun.name = "HatchLight"
	sun.light_color = DAYLIGHT
	sun.light_energy = 2.6
	sun.spot_range = 7.0
	sun.spot_angle = 28.0
	sun.shadow_enabled = true
	add_child(sun)
	sun.look_at_from_position(Vector3(c0.x, top - 0.1, c0.z), Vector3(c0.x + 0.3, 0.0, c0.z - 0.2))
	# 頂層平台後面（還沒有上一段樓梯的地方）擋一道牆，不然會掉到下一圈
	_box_at("TopStop", Vector3(W, top, 0.3), Vector3(c0.x, top * 0.5, c0.z - W * 0.5 - 0.15), wall_mat)
	# 井底的地板（最後一段走完的高度）
	_box_at("ShaftFloor", Vector3(oh * 2.0, 0.3, oh * 2.0), Vector3(0, bottom - 0.15, 0), _dark_mat)


func _glow_mat(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _build_flights() -> void:
	var step_len: float = (SIDE - W) / float(STEPS_PER_FLIGHT)
	for k: int in FLIGHTS + 1:
		var c: Vector3 = corner(k)
		# 轉角平台
		_box_at("Landing%d" % k, Vector3(W, 0.35, W), c + Vector3(0, -0.175, 0), _stone_mat, k < FLIGHTS)
		if k == FLIGHTS:
			break
		var dir: Vector3 = path_dir(float(k) * SIDE + 0.1)
		var a: Vector3 = c + dir * (W * 0.5)
		var b: Vector3 = corner(k + 1) - dir * (W * 0.5)
		# 看不到的斜坡碰撞＋底下的石板（從下一圈往上看是天花板）
		var basis := Basis.looking_at(b - a, Vector3.UP)
		var mid: Vector3 = (a + b) * 0.5 - basis.y * 0.2
		var slope := _solid("Flight%d" % k, Vector3(W - 0.02, 0.4, (b - a).length()), Transform3D(basis, mid), _dark_mat, true)
		slope.visible = true
		# 台階（只是樣子，不擋人）
		for i: int in STEPS_PER_FLIGHT:
			var u: float = (float(i) + 0.5) * step_len
			var top_y: float = a.y - (float(i) + 0.5) / float(STEPS_PER_FLIGHT) * DROP + 0.03
			var p: Vector3 = a + dir * u
			p.y = top_y - 0.16
			var worn: float = _rng.randf_range(-0.02, 0.02)
			var step := _box_at("Step%d_%d" % [k, i], Vector3(W - 0.04, 0.32 + worn, step_len + 0.02), Vector3.ZERO, _stone_mat, false)
			step.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), p)


func _build_trap() -> void:
	var c: Vector3 = corner(TRAP_CORNER)
	var ceiling_y: float = corner(TRAP_CORNER - 4).y - 0.35
	# 繩子＋木桶（吊在上一圈平台的底下）
	var rope_len: float = 0.42
	_box_at("BucketRope", Vector3(0.02, rope_len, 0.02), Vector3(c.x, ceiling_y - rope_len * 0.5, c.z), _mat(Color(0.4, 0.34, 0.24), 1.0), false)
	_bucket = Node3D.new()
	_bucket.name = "Bucket"
	_bucket.position = Vector3(c.x, ceiling_y - rope_len, c.z)
	add_child(_bucket)
	var barrel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.24
	cyl.bottom_radius = 0.2
	cyl.height = 0.36
	barrel.mesh = cyl
	barrel.material_override = _mat(WOOD, 0.85)
	barrel.position = Vector3(0, -0.2, 0)
	_bucket.add_child(barrel)
	# 絆線（平台入口，很細、幾乎看不見）
	var dir: Vector3 = path_dir(trap_entrance_s() - 0.1)
	var wire_at: Vector3 = c - dir * (W * 0.5) + Vector3(0, 0.12, 0)
	var wire := _box_at("TripWire", Vector3(W, 0.008, 0.008), Vector3.ZERO, _mat(Color(0.55, 0.5, 0.42), 0.6), false)
	wire.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), wire_at)
	# 水灘（觸發後才出現）
	_puddle = MeshInstance3D.new()
	_puddle.name = "Puddle"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.65
	disc.bottom_radius = 0.65
	disc.height = 0.01
	_puddle.mesh = disc
	var wet := StandardMaterial3D.new()
	wet.albedo_color = Color(0.1, 0.09, 0.07)
	wet.roughness = 0.08
	wet.metallic_specular = 0.8
	_puddle.material_override = wet
	_puddle.visible = false
	add_child(_puddle)
	_puddle.position = c + Vector3(0, 0.012, 0)


func _build_bottom() -> void:
	var door_at: Vector3 = _door_pos()
	# 外牆上的木門（關著；門縫漏出白光——門後是白晝城的一戶人家）。鉸鏈在 -Z 那一邊，往裡（+X）開
	_door_pivot = Node3D.new()
	_door_pivot.name = "GateDoorPivot"
	_door_pivot.position = door_at + Vector3(-0.05, 0.0, -0.55)
	add_child(_door_pivot)
	var leaf := _box_at("GateDoorLeaf", Vector3(0.08, 2.1, 1.1), Vector3.ZERO, _mat(WOOD, 0.8), false)
	leaf.reparent(_door_pivot, false)
	leaf.position = Vector3(0.0, 1.05, 0.55)
	var leaf_body := StaticBody3D.new()
	leaf_body.name = "GateDoorLeafBody"
	var leaf_shape := CollisionShape3D.new()
	var leaf_box := BoxShape3D.new()
	leaf_box.size = Vector3(0.08, 2.1, 1.1)
	leaf_shape.shape = leaf_box
	leaf_body.add_child(leaf_shape)
	leaf_body.position = Vector3(0.0, 1.05, 0.55)
	_door_pivot.add_child(leaf_body)
	# 門開了才看得到的門洞：屋裡的白光（白晝城的燈），桌子、孩子、碎頭盔裡的蔥由對話說
	_doorway = _box_at("GateDoorway", Vector3(0.02, 2.1, 1.1), door_at + Vector3(-0.01, 1.05, 0), _glow_mat(DOOR_GLOW, 1.6), false)
	_doorway.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_doorway.visible = false
	var gap := _box_at("GateDoorGap", Vector3(0.02, 0.03, 1.1), door_at + Vector3(-0.1, 0.02, 0), _glow_mat(DOOR_GLOW, 3.0), false)
	gap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var side := _box_at("GateDoorCrack", Vector3(0.02, 2.0, 0.02), door_at + Vector3(-0.1, 1.0, 0.55), _glow_mat(DOOR_GLOW, 2.2), false)
	side.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var leak := OmniLight3D.new()
	_door_leak = leak
	leak.name = "DoorLeak"
	leak.light_color = DOOR_GLOW
	leak.light_energy = 0.7
	leak.omni_range = 3.2
	leak.position = door_at + Vector3(-0.3, 0.3, 0.2)
	add_child(leak)
	var marker := Marker3D.new()
	marker.name = "GateDoor"
	marker.position = door_at + Vector3(-0.2, 1.0, 0)
	add_child(marker)
	# 目標指引：段落 5 在霜橋鎮是地窖口，在這裡是樓梯底
	var down := Marker3D.new()
	down.name = "StairsDown"
	down.position = corner(FLIGHTS) + Vector3(0, 1.0, 0)
	add_child(down)
	add_to_group("interact_prompts")
