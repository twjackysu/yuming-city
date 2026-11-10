class_name Undertaker
extends EnemyActor
## 送葬者（精英）：背負鐵架、追著心跳走。第一階段三招（02-gameplay「送葬者」）：
##   鐵架橫掃（扇形霜紋）／鐵架下砸（圓形霜紋，砸地後 0.6 秒破綻）／追心跳衝撞（直線霜紋，撞牆跪地 2 秒）。
## 生命降到 phase2_hp 進入第二階段：看穿裡「下砸」變成未證實，前兆縮短（攻略開始失準），轉向傷者車隊。
## 第二階段（pattern_phase2）：連續下砸（第二下前兆 0.5，攻略沒寫：諾恩沒挨打地看過一次才變已證實，
## 之前席菈的「閃開」對第二下算失敗）、抓取（抓前方最近的心跳；席菈守在旁邊就擋下）、橫掃、衝撞。
## 鐵架拋擲：第二階段生命 ≤ frame_throw_hp 或車隊過半時觸發一次（`slice.frame_thrown`），接九息或薪火劍。
## 弱點：鐵架關節，從背後打得到；跪地時全露。

signal phase_changed(phase: int)
## 鐵架拋擲（劇情觸發一次）：場景接九息石拱或席菈的薪火劍
signal frame_throw_started
## 連續下砸的第二下：諾恩看過一次（沒被打到）就變已證實
signal double_slam_verified
## 被斬倒、身體撞到地面的那一刻（D-052）
signal fell

const FROST: Color = Color(0.55, 0.82, 1.0)
const TELEGRAPH_SHADER: String = "res://src/world/telegraph.gdshader"
## 霧裡的輪廓（D-101）：鐵架的冷色邊緣光＋朝上的薄霜、腳下的接地陰影
const BIG_FADE_NEAR: float = 0.9
const BIG_FADE_FAR: float = 1.9
const FRAME_IRON_SHADER: String = "res://scenes/actors/undertaker/frame_iron.gdshader"
const GROUND_SHADOW_SHADER: String = "res://scenes/actors/undertaker/ground_shadow.gdshader"
## 大衣的底色：比霧暗得多，隔著霧才看得出一個深色的人形（原本 0.11，跟夜霧差不多亮）
const ROBE_ALBEDO: Color = Color(0.055, 0.055, 0.065)
## 手裡拖著的鐵鏈（D-200）：手的位置（Torso 座標，x 取左右）、一節的外長／外寬／鐵條半徑、地上往後拖多長
const CHAIN_HAND: Vector3 = Vector3(0.66, 0.03, 0.06)
const CHAIN_LINK: Vector3 = Vector3(0.12, 0.075, 0.014)
const CHAIN_TRAIL: float = 0.9
const GROUND_SHADOW_RADIUS: float = 1.15
const GROUND_SHADOW_STRENGTH: float = 0.6
## 前兆範圍的形狀（telegraph.gdshader 的 shape）
const SHAPE_DISC: int = 0
const SHAPE_LANE: int = 1
const SHAPE_FAN: int = 2

var phase: int = 1
## 測試或場景可以指定；空的就用 Game.session.state
var state: GameState
var frame_thrown: bool = false
## 舉起鐵架的剩餘秒數（>0 時站著不動）
var throw_windup: float = 0.0
var _throw_total: float = 1.0
## 最近抓住的諾恩（被打中弱點時鬆手）
var _grabbed: PlayerController
## 第二下的觀察距離：諾恩在這個範圍內沒被打到才算「看過」
const WITNESS_RANGE: float = 8.0

## 第 3 章的掙脫戰（D-169）：只有第一階段、少一招（不衝撞：運河岸太窄）、失衡上限比較低，不會進第二階段。
var struggle_mode: bool = false

var _decals: Dictionary = {}
var _charge_hit: Array[Node3D] = []
var _hit_wall: bool = false

## 腳步聲（D-187）：很重的拖步（低頻「咚」＋鐵鏈擦地，`step_heavy`），不分地面。步幅大、遠遠就聽得到；
## 衝撞時步子更大、更響。乾運河裡牠的步態是關卡演的，關卡在步態落地時呼叫 footsteps.stomp()。
const STRIDE: float = 1.3
const CHARGE_STRIDE: float = 2.2
const STEP_DB: float = -7.0
const CHARGE_STEP_DB: float = -3.0
const STEP_SOUND: String = "step_heavy"


func intel_id() -> String:
	return "undertaker"


func _make_footsteps() -> Footsteps:
	var f := Footsteps.new(STRIDE, CHARGE_STRIDE, STEP_DB, CHARGE_STEP_DB)
	f.sound = STEP_SOUND
	f.pitch_jitter = 0.05
	f.unit_size = 7.0
	return f


## 送葬者又高又寬（2.6 m、半徑 0.6 m），站在諾恩背後時離鏡頭 1.5 m 還是擋掉畫面三分之一：淡出範圍放大（D-115）
func camera_fade_range() -> Vector2:
	return Vector2(BIG_FADE_NEAR, BIG_FADE_FAR)


func _insight_height() -> float:
	return 3.1


## 背上的鐵架橫桿伸到 0.55 m、手臂到約 0.75 m：小卡要讓開整個鐵架（第八輪盤點第 8 項，D-146）
func insight_side() -> float:
	return 0.85


func _on_strike() -> void:
	var fwd: Vector3 = forward()
	var origin: Vector3 = global_position
	match brain.move_id:
		"sweep":
			var reach: float = brain.move_num("sweep", "range", 3.2)
			var arc: float = brain.move_num("sweep", "arc_deg", 150.0)
			Sfx.play_at(self, "claw", origin + fwd * 1.5 + Vector3.UP, 2.0, 0.04)
			hit_heartbeats(brain.move_num("sweep", "damage", 28.0), "sweep",
				func(p: Vector3) -> bool: return PlayerController.in_strike_arc(origin, fwd, p, reach + 0.3, arc))
		"slam", "double_slam", "double_slam_2":
			var id: String = brain.move_id
			var center: Vector3 = slam_center()
			var r: float = brain.move_num(id, "radius", 2.0)
			Sfx.play_at(self, "blunt_weak", center + Vector3.UP * 0.3, 4.0, 0.03, 10.0)
			_shake_player(0.45)
			var player_hp: float = _player.health.hp if _player != null else 0.0
			hit_heartbeats(brain.move_num(id, "damage", 40.0), id,
				func(p: Vector3) -> bool: return Vector2(p.x - center.x, p.z - center.z).length() <= r)
			if id == "double_slam_2" and _player != null:
				var unhurt: bool = _player.health.hp >= player_hp
				note_second_slam(unhurt, _player.global_position.distance_to(global_position) <= WITNESS_RANGE)
		"grab":
			_grab()
		"spray":
			_spray()
		"charge":
			_charge_hit.clear()
			_hit_wall = false
			Sfx.play_at(self, "whoosh", origin + Vector3.UP, 4.0)


## 衝撞：出招期間往前直衝，碰到心跳就撞（每次衝撞每人一次）。
func _on_strike_tick(_delta: float) -> Vector3:
	if brain.move_id != "charge" or _hit_wall:
		return Vector3.ZERO
	var r: float = brain.move_num("charge", "hit_radius", 1.1)
	var me: Vector3 = global_position
	for n: Node in get_tree().get_nodes_in_group("heartbeat"):
		var hb: Node3D = n as Node3D
		if hb == null or _charge_hit.has(hb):
			continue
		if Vector2(hb.global_position.x - me.x, hb.global_position.z - me.z).length() <= r:
			_charge_hit.append(hb)
			hurt(hb, brain.move_num("charge", "damage", 22.0), "charge")
	return forward() * brain.move_num("charge", "speed", 11.0)


## 衝撞撞到牆（水平法線的碰撞）→ 跪地。
func _after_move() -> void:
	_after_move_phase2()
	if brain.state != EnemyBrain.State.STRIKE or brain.move_id != "charge" or _hit_wall:
		return
	for i: int in get_slide_collision_count():
		var c: KinematicCollision3D = get_slide_collision(i)
		var hit: Node = c.get_collider() as Node
		if absf(c.get_normal().y) < 0.5 and not (hit != null and hit.is_in_group("heartbeat")):
			_hit_wall = true
			brain.force_kneel(brain.move_num("charge", "wall_kneel", 2.0))
			Sfx.play_at(self, "blunt_weak", global_position + forward() + Vector3.UP, 4.0, 0.03, 10.0)
			_shake_player(0.6)
			return


func slam_center() -> Vector3:
	return global_position + forward() * brain.move_num(brain.move_id if brain.move_id.contains("slam") else "slam", "reach", 1.9)


## 連續下砸第二下的結果：諾恩在近處沒被打到＝看過一次 → 看穿變已證實、席菈之後抓得到時機。
func note_second_slam(unhurt: bool, witnessed: bool) -> void:
	if not (unhurt and witnessed) or bool(intel_overrides.get("double_slam", false)):
		return
	intel_overrides["double_slam"] = true
	brain.unreadable.erase("double_slam_2")
	double_slam_verified.emit()


## 抓取：前方 arc 內最近的心跳；席菈守著那個人（或她自己就是目標）時擋下。回傳被抓的對象（擋下或沒抓到＝null）。
func _grab() -> Node3D:
	var reach: float = brain.move_num("grab", "range", 2.2)
	var arc: float = brain.move_num("grab", "arc_deg", 90.0)
	var me: Vector3 = global_position
	var fwd: Vector3 = forward()
	var best: Node3D = null
	var best_d: float = INF
	for n: Node in get_tree().get_nodes_in_group("heartbeat"):
		var hb: Node3D = n as Node3D
		if hb == null or not PlayerController.in_strike_arc(me, fwd, hb.global_position, reach + 0.6, arc):
			continue
		var d: float = me.distance_squared_to(hb.global_position)
		if d < best_d:
			best_d = d
			best = hb
	intel_overrides["grab"] = true  # 抓過一次就知道了
	Sfx.play_at(self, "claw", me + fwd + Vector3.UP, 3.0, 0.04)
	if best == null:
		return null
	var guard: Node3D = _guard_for(best)
	if guard != null:
		hurt(guard, brain.move_num("grab", "damage", 20.0) * 0.5, "grab_blocked")
		return null
	hurt(best, brain.move_num("grab", "damage", 20.0), "grab")
	var p: PlayerController = best as PlayerController
	if p != null:
		_grabbed = p
		p.begin_grab(self, brain.move_num("grab", "hold", 2.0), int(brain.move_num("grab", "struggle", 5.0)), brain.move_num("grab", "squeeze_damage", 12.0))
		# 抓著人的時候站著不動
		brain.recover_sec = maxf(brain.recover_sec, brain.move_num("grab", "hold", 2.0))
	return best


## 守住：席菈開著守住、而且站在被抓的人旁邊（2.5 公尺內）就替他擋。
func _guard_for(victim: Node3D) -> Node3D:
	for n: Node in get_tree().get_nodes_in_group("heartbeat"):
		var s: Sheila = n as Sheila
		if s == null or s == victim or not s.brain.guard_active or s.brain.mode == CompanionBrain.Mode.DOWN:
			continue
		if s.global_position.distance_to(victim.global_position) <= 2.5:
			return s
	return null


func _game_state() -> GameState:
	if state != null:
		return state
	return Game.session.state if Game.session != null else null


## 第二階段：生命 ≤ frame_throw_hp 或車隊過半 → 鐵架拋擲（只一次）。
func _check_frame_throw() -> void:
	if phase != 2 or frame_thrown or health.is_dead():
		return
	var low: bool = health.hp <= CombatTuning.num("undertaker.frame_throw_hp", 300.0)
	var c: Caravan = _caravan()
	var half: bool = c != null and c.runner.progress() >= CombatTuning.num("undertaker.frame_throw_caravan_progress", 0.5)
	if low or half:
		trigger_frame_throw()


## 鐵架拋擲的前兆：站定、把鐵架舉過頭（ConvoyEncounter 呼叫）。
func begin_throw_windup(seconds: float) -> void:
	throw_windup = seconds
	_throw_total = maxf(seconds, 0.01)
	Sfx.play_at(self, "whoosh", global_position + Vector3.UP * 3.0, 2.0, 0.0, 10.0)


## 鐵架擲出去了（被石拱擋下或被燃燒劍斬斷）：背上的鐵架藏起來，之後是空手；飛出去的那一副由 ThrownFrame 演。
func end_throw(_outcome: String) -> void:
	throw_windup = 0.0
	brain.force_kneel(1.2)
	var frame: Node3D = _frame_node()
	if frame != null:
		frame.visible = false


## 背上的鐵架還在不在（擲出去之後就不在了）。
func has_frame() -> bool:
	var frame: Node3D = _frame_node()
	return frame != null and frame.visible


## 鐵架擲出的位置（背上鐵架的中心，世界座標）。
func frame_launch_point() -> Vector3:
	return global_position + Vector3.UP * 3.1


func _frame_node() -> Node3D:
	return _body.get_node_or_null("Torso/Frame") as Node3D if _body != null else null


func _held(delta: float) -> bool:
	if throw_windup <= 0.0:
		return _scripted
	throw_windup = maxf(throw_windup - delta, 0.0)
	return true


# ---- 劇情走位（D-205，新版開場的追擊）----
## 照自己的腳走到目標（會轉向、有腳步聲、拖著鐵鏈），不是用 tween 搬位置。走位期間不跑狀態機、不出招、打不動。
const SCRIPT_ARRIVE: float = 0.35
const SCRIPT_TURN: float = 3.5

var script_target: Vector3 = Vector3.ZERO
var script_speed: float = 0.0
var _scripted: bool = false
var _script_look: Vector3 = Vector3.ZERO
var _script_has_look: bool = false


func scripted_walk(to: Vector3, speed: float) -> void:
	_scripted = true
	script_target = to
	script_speed = speed
	if health != null and not health.invulnerable_check.is_valid():
		health.invulnerable_check = is_scripted


## 站住時轉向這個位置（盯著人看）
func scripted_look_at(pos: Vector3) -> void:
	_script_look = pos
	_script_has_look = true


## 交回給狀態機（開打）
func end_scripted() -> void:
	_scripted = false
	script_speed = 0.0
	_script_has_look = false


func is_scripted() -> bool:
	return _scripted


func scripted_arrived() -> bool:
	var d: Vector3 = script_target - global_position
	d.y = 0.0
	return d.length() <= SCRIPT_ARRIVE


func _held_velocity(delta: float) -> Vector3:
	if not _scripted or throw_windup > 0.0:
		return Vector3.ZERO
	var d: Vector3 = script_target - global_position
	d.y = 0.0
	var moving: bool = script_speed > 0.0 and d.length() > SCRIPT_ARRIVE
	var look: Vector3 = d
	if not moving and _script_has_look:
		look = _script_look - global_position
		look.y = 0.0
	if look.length() > 0.05:
		_body.rotation.y = lerp_angle(_body.rotation.y, atan2(-look.x, -look.z) - rotation.y, clampf(SCRIPT_TURN * delta, 0.0, 1.0))
	return d.normalized() * script_speed if moving else Vector3.ZERO


func trigger_frame_throw() -> void:
	if frame_thrown:
		return
	frame_thrown = true
	var st: GameState = _game_state()
	if st != null:
		st.set_flag("slice.frame_thrown", true)
	frame_throw_started.emit()


func _caravan() -> Caravan:
	for n: Node in get_tree().get_nodes_in_group("caravan"):
		var c: Caravan = n as Caravan
		if c != null and not c.runner.is_arrived:
			return c
	return null


## 第二階段優先追車隊的心跳（前兆、出招中不換目標）。
func _nearest_heartbeat() -> Node3D:
	if phase == 2 and not (brain.state in [EnemyBrain.State.TELEGRAPH, EnemyBrain.State.STRIKE] and target != null and is_instance_valid(target)):
		var c: Caravan = _caravan()
		if c != null:
			return c
	return super._nearest_heartbeat()


func _after_move_phase2() -> void:
	_check_frame_throw()


func _on_damaged(amount: float, info: Dictionary) -> void:
	super._on_damaged(amount, info)
	# 抓著諾恩時被打中弱點（席菈「打弱點」）就鬆手
	if str(info.get("weak", "")) != "" and _grabbed != null and is_instance_valid(_grabbed) and _grabbed.grabbed_by == self:
		_grabbed.release_grab(true)
	if phase == 1 and not struggle_mode and health.hp <= CombatTuning.num("undertaker.phase2_hp", 450.0) and not health.is_dead():
		enter_phase_two()


## 掙脫戰（D-169）：招式輪替換成 pattern_struggle（沒有衝撞）、失衡上限 struggle_stagger_max；之後不會進第二階段。
func begin_struggle() -> void:
	struggle_mode = true
	_apply_struggle_brain()


func _apply_struggle_brain() -> void:
	var pat: Variant = CombatTuning.value("undertaker.pattern_struggle", [])
	if pat is Array:
		brain.set_pattern(PackedStringArray(pat as Array))
	brain.stagger_max = CombatTuning.num("undertaker.struggle_stagger_max", brain.stagger_max)


# ---- 南街守衛（新版前十分鐘，D-207）----
## 單階段：招式輪替 pattern_guardian（沒有衝撞、多一招「噴毒」）、生命 guardian_hp、不會進第二階段。
## 胸口多三根排氣管（只有守衛有；舊版的送葬者外觀不變）。
const SPRAY_GREEN: Color = Color(0.5, 1.0, 0.38)
const PIPE_IDLE_ENERGY: float = 0.3
const PIPE_HOT_ENERGY: float = 7.0
const PIPE_LIGHT_ENERGY: float = 2.0
const SPRAY_JET_SHADER: String = "res://scenes/actors/undertaker/spray_jet.gdshader"
const SPRAY_JET_SEC: float = 0.55
## 排氣管口（上身座標，-Z 是前方）
const PIPE_MOUTH: Vector3 = Vector3(0.0, 0.42, -0.5)

var guardian_mode: bool = false
## 噴過幾次、最後一團毒霧（測試用）
var spray_count: int = 0
var last_spray: PoisonMist
var _pipes: Node3D
var _pipe_mat: StandardMaterial3D
var _pipe_light: OmniLight3D
var _pipe_glow: float = 0.0
var _spray_charging: bool = false
## 截圖用：噴出去的那一道不淡掉
var debug_hold_jet: bool = false


func begin_guardian() -> void:
	guardian_mode = true
	struggle_mode = true
	_apply_guardian_brain()
	health.max_hp = CombatTuning.num("undertaker.guardian_hp", health.max_hp)
	health.hp = health.max_hp
	# 攻略沒寫的招：看穿裡列成未證實
	intel_overrides["spray"] = false
	_build_spray_pipes()


func _apply_guardian_brain() -> void:
	var pat: Variant = CombatTuning.value("undertaker.pattern_guardian", [])
	if pat is Array:
		brain.set_pattern(PackedStringArray(pat as Array))
	brain.stagger_max = CombatTuning.num("undertaker.guardian_stagger_max", brain.stagger_max)


## 噴毒落在哪裡（前方 reach 公尺的地面）
func spray_center() -> Vector3:
	var c: Vector3 = global_position + forward() * brain.move_num("spray", "reach", 2.6)
	return Vector3(c.x, global_position.y, c.z)


## 噴毒：胸口的管子往前下方噴，地上留一團毒霧（life 秒後散掉）。霧本身不分敵我：站進去就中毒；
## 這一下沒有直接傷害（跟爪子、下砸不同：諾恩站在裡面會回血，但牠照樣可以接著打）。
func _spray() -> PoisonMist:
	var parent: Node = get_parent()
	if parent == null:
		return null
	spray_count += 1
	var center: Vector3 = spray_center()
	var m: PoisonMist = PoisonMist.create(brain.move_num("spray", "radius", 2.0), "guardian_spray", brain.move_num("spray", "life", 3.0))
	m.name = "GuardianSpray%d" % spray_count
	m.position = center
	parent.add_child(m)
	last_spray = m
	Sfx.play_at(parent, "poison_hiss", global_position + forward() * 0.8 + Vector3.UP * 1.4, 2.0, 0.04, 9.0)
	_spray_jet(center)
	return m


## 管口到地面的一道綠色噴霧（錐形面片＋流動的雜訊，不用粒子：截圖與慢幀下都看得到），半秒淡掉。
func _spray_jet(center: Vector3) -> void:
	var torso: Node3D = _body.get_node_or_null("Torso") as Node3D
	if torso == null or not is_inside_tree():
		return
	var from: Vector3 = torso.global_transform * PIPE_MOUTH
	var to: Vector3 = center + Vector3.UP * 0.1
	var length: float = from.distance_to(to)
	if length < 0.2:
		return
	var cone := CylinderMesh.new()
	cone.top_radius = 0.07
	cone.bottom_radius = brain.move_num("spray", "radius", 2.0) * 0.55
	cone.height = length
	cone.radial_segments = 20
	cone.rings = 6
	cone.cap_top = false
	cone.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = load(SPRAY_JET_SHADER) as Shader
	mat.set_shader_parameter("tint", SPRAY_GREEN)
	mat.set_shader_parameter("fade", 1.0)
	var jet := MeshInstance3D.new()
	jet.name = "SprayJet"
	jet.mesh = cone
	jet.material_override = mat
	jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(jet)
	# 圓柱的 +Y（窄的那一端）對著管口
	var up: Vector3 = (from - to).normalized()
	var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	jet.global_transform = Transform3D(Basis(side, up, side.cross(up)), (from + to) * 0.5)
	if debug_hold_jet:
		return
	var t := jet.create_tween()
	t.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, SPRAY_JET_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(jet.queue_free)


## 胸口的三根排氣管：平常只有一點暗綠，噴毒的前兆越來越亮（＋一盞綠光打在袍子與地上）。
func _build_spray_pipes() -> void:
	var torso: Node3D = _body.get_node_or_null("Torso") as Node3D if _body != null else null
	if torso == null or _pipes != null:
		return
	_pipes = Node3D.new()
	_pipes.name = "SprayPipes"
	torso.add_child(_pipes)
	var iron: Material = frame_iron_material()
	_pipe_mat = StandardMaterial3D.new()
	_pipe_mat.albedo_color = Color(0.05, 0.09, 0.04)
	_pipe_mat.roughness = 0.4
	_pipe_mat.emission_enabled = true
	_pipe_mat.emission = SPRAY_GREEN
	_pipe_mat.emission_energy_multiplier = PIPE_IDLE_ENERGY
	for x: float in [-0.17, 0.0, 0.17]:
		var pipe := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.05
		pm.bottom_radius = 0.06
		pm.height = 0.34
		pm.radial_segments = 10
		pipe.mesh = pm
		pipe.material_override = iron
		# 從胸口往前下方伸出來（圓柱的 +Y 朝前下）
		pipe.position = Vector3(x, 0.5 - absf(x) * 0.25, -0.34)
		pipe.rotation_degrees = Vector3(-68.0, 0.0, 0.0)
		_pipes.add_child(pipe)
		var mouth := MeshInstance3D.new()
		var mm := CylinderMesh.new()
		mm.top_radius = 0.042
		mm.bottom_radius = 0.042
		mm.height = 0.03
		mm.radial_segments = 10
		mouth.mesh = mm
		mouth.material_override = _pipe_mat
		mouth.position = Vector3(0.0, 0.165, 0.0)
		pipe.add_child(mouth)
	_pipe_light = OmniLight3D.new()
	_pipe_light.name = "PipeLight"
	_pipe_light.light_color = SPRAY_GREEN
	_pipe_light.light_energy = 0.0
	_pipe_light.omni_range = 4.0
	_pipe_light.omni_attenuation = 1.3
	_pipe_light.shadow_enabled = false
	# 體積霧裡只留一點點（不然牠整個人會被一顆綠色光球蓋掉，袍子的黑色輪廓就沒了）
	_pipe_light.light_volumetric_fog_energy = 0.2
	# 放在管口前下方：照亮地面與袍子的下襬，不是把整個上身染綠
	_pipe_light.position = PIPE_MOUTH + Vector3(0.0, -0.25, -0.75)
	_pipes.add_child(_pipe_light)
	# 噴毒的前兆範圍：地上一個綠色的圓（跟霜色的下砸分得出來）
	var disc := CylinderMesh.new()
	var r: float = brain.move_num("spray", "radius", 2.0)
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = 0.01
	_decals["spray"] = _decal(disc, Vector3(0, 0.03, -brain.move_num("spray", "reach", 2.6)), SHAPE_DISC, Vector2(r, 0.0), 0.0, SPRAY_GREEN)


## 管口的亮度：噴毒前兆跟著進度變亮、噴出去那一下最亮，其他時候慢慢暗回去。
func pipe_glow() -> float:
	return _pipe_glow


func _update_pipes() -> void:
	if _pipe_mat == null:
		return
	var want: float = 0.0
	if brain.move_id == "spray":
		if brain.state == EnemyBrain.State.TELEGRAPH:
			want = 0.15 + 0.85 * brain.telegraph_progress()
		elif brain.state == EnemyBrain.State.STRIKE:
			want = 1.0
	# 前兆開始的那一刻：嘶聲（越來越大），跟舉手的招式聽起來不一樣
	var charging: bool = want > 0.0 and brain.state == EnemyBrain.State.TELEGRAPH
	if charging and not _spray_charging and is_inside_tree():
		Sfx.play_at(get_parent(), "poison_charge", global_position + forward() * 0.6 + Vector3.UP * 1.4, 0.0, 0.03, 8.0)
	_spray_charging = charging
	_pipe_glow = want if want > _pipe_glow else lerpf(_pipe_glow, want, 0.08)
	_pipe_mat.emission_energy_multiplier = lerpf(PIPE_IDLE_ENERGY, PIPE_HOT_ENERGY, _pipe_glow)
	_pipe_light.light_energy = PIPE_LIGHT_ENERGY * _pipe_glow


## 第二階段：扯斷一條鐵鏈；看穿裡「下砸」變成未證實，下砸前兆縮短；換招式輪替、出現攻略沒寫的招。
func enter_phase_two() -> void:
	phase = 2
	# 扯斷一條鐵鏈（D-200）：右手那條不見了
	var torn: Node3D = _body.get_node_or_null("Torso/ChainR") as Node3D if _body != null else null
	if torn != null:
		torn.visible = false
	var torn_trail: Node3D = _body.get_node_or_null("ChainTrailR") as Node3D if _body != null else null
	if torn_trail != null:
		torn_trail.visible = false
	intel_overrides["slam"] = false
	intel_overrides["double_slam"] = false
	brain.unreadable["double_slam_2"] = true
	_apply_phase_two_brain()
	phase_changed.emit(phase)
	_check_frame_throw()


## 第二階段的招式數值與輪替（難度改了、brain 重新 configure 後也要再套一次）。
func _apply_phase_two_brain() -> void:
	var slam: Dictionary = (brain.moves.get("slam", {}) as Dictionary).duplicate()
	slam["telegraph"] = float(slam.get("telegraph_phase2", 0.7))
	brain.moves["slam"] = slam
	var pat: Variant = CombatTuning.value("undertaker.pattern_phase2", [])
	if pat is Array:
		brain.set_pattern(PackedStringArray(pat as Array))


func _on_settings_changed() -> void:
	var unread: Dictionary = brain.unreadable.duplicate()
	super._on_settings_changed()
	brain.unreadable = unread
	if phase == 2:
		_apply_phase_two_brain()
	elif guardian_mode:
		_apply_guardian_brain()
	elif struggle_mode:
		_apply_struggle_brain()


## 跪地（D-191）：比走路的拖步更重的一聲「咚」（音高壓低）＋鐵架晃一下的鐵響，鏡頭小震一下。
const KNEEL_DB: float = -1.0
const KNEEL_PITCH: float = 0.78
const KNEEL_SHAKE: float = 0.14


func _play_kneel(parent: Node) -> PackedStringArray:
	var at: Vector3 = global_position + forward() * 0.6
	var p: AudioStreamPlayer3D = Sfx.play_at(parent, STEP_SOUND, at, KNEEL_DB, 0.03, 7.0)
	if p != null:
		p.pitch_scale *= KNEEL_PITCH
	Sfx.play_at(parent, "iron_clang", at + Vector3.UP * 1.6, -12.0, 0.05, 6.0)
	_shake_player(KNEEL_SHAKE)
	_kneel_puff(at, Vector3(0.55, 0.05, 0.55), 18)
	return PackedStringArray([STEP_SOUND, "iron_clang"])


func _shake_player(amount: float) -> void:
	if _player != null and global_position.distance_to(_player.global_position) < 12.0:
		_player.shake(amount)


# ---------------------------------------------------------------- 被斬倒（D-052）

## 跪下 → 停一下 → 向前倒（背上的鐵架朝天）→ 落地那一刻鐵與身體撞地聲、雪粉、鏡頭小震 →
## 躺一會兒 → 沉進雪裡消失。FALL_FORWARD（EnemyActor）：繞 X 軸轉負角度，頭朝 forward()（-Z）倒下。
const FALL_KNEEL_SEC: float = 0.45
const FALL_HOLD_SEC: float = 0.5
const FALL_DROP_SEC: float = 0.55
const FALL_LIE_SEC: float = 2.5
const FALL_SINK_SEC: float = 1.4


func fall_total_sec() -> float:
	return FALL_KNEEL_SEC + FALL_HOLD_SEC + FALL_DROP_SEC + FALL_LIE_SEC + FALL_SINK_SEC


func _on_died() -> void:
	# 不再追、不再更新前兆姿勢、不再擋路（EnemyActor._begin_death）
	_begin_death()
	for id: String in _decals:
		(_decals[id] as MeshInstance3D).visible = false
	var torso: Node3D = _body.get_node("Torso") as Node3D
	# 倒下時地上那段鐵鏈收掉（整個 _body 往前轉，貼地的那段會翹到半空中，D-200）
	set_chain_trails(false)
	# 兜帽裡的霜光在跪下時熄掉（倒地的冷光由 _frost_exhale 接手）
	var dim := create_tween()
	dim.tween_property(torso.get_node("HoodLight"), "light_energy", 0.0, FALL_KNEEL_SEC)
	for eye: Node in torso.find_children("HoodEye*", "MeshInstance3D", false, false):
		dim.parallel().tween_property(eye, "scale", Vector3.ONE * 0.01, FALL_KNEEL_SEC)
	var t := create_tween()
	_fall_tween = t
	# 跪下：身體下沉、上身往前垂
	t.tween_property(_body, "position:y", -0.55, FALL_KNEEL_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(torso, "rotation_degrees", Vector3(FALL_FORWARD * 18.0, 0.0, 0.0), FALL_KNEEL_SEC)
	t.tween_interval(FALL_HOLD_SEC)
	# 向前倒：越倒越快，身體抬回地面高度（躺平時大衣的半徑撐在雪上）
	t.tween_property(_body, "rotation_degrees:x", FALL_FORWARD * 84.0, FALL_DROP_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_body, "position:y", 0.3, FALL_DROP_SEC)
	t.parallel().tween_property(torso, "rotation_degrees", Vector3.ZERO, FALL_DROP_SEC)
	# 接地陰影跟著倒下的身體往前、拉長成躺著的形狀（D-101）
	var shadow: MeshInstance3D = ground_shadow()
	if shadow != null:
		var fwd: Vector3 = forward()
		fwd.y = 0.0
		var lying_at: Vector3 = to_local(global_position + fwd.normalized() * 1.1)
		lying_at.y = 0.015
		shadow.rotation.y = _body.rotation.y
		t.parallel().tween_property(shadow, "position", lying_at, FALL_DROP_SEC)
		t.parallel().tween_property(shadow, "scale", Vector3(0.9, 1.0, 1.8), FALL_DROP_SEC)
	t.tween_callback(_on_fall_impact)
	t.tween_interval(FALL_LIE_SEC)
	t.tween_property(_body, "position:y", -1.4, FALL_SINK_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_method(_set_shadow_strength, GROUND_SHADOW_STRENGTH, 0.0, FALL_SINK_SEC)
	t.tween_callback(queue_free)


func _on_fall_impact() -> void:
	has_fallen = true
	var at: Vector3 = global_position + forward() * 1.3
	var parent: Node = get_parent()
	Sfx.play_at(parent, "iron_clang", at, 1.0, 0.03)
	Sfx.play_at(parent, "blunt", at, 2.0, 0.03)
	_shake_player(0.35)
	_ground_puff(at, Vector3(0.6, 0.05, 1.2), 28, Color(0.75, 0.8, 0.88, 0.55))
	_frost_exhale(global_position + forward() * 1.1 + Vector3.UP * 1.4)
	fell.emit()
	if debug_hold_fallen and _fall_tween != null:
		_fall_tween.pause()


## 兜帽裡的霜光（D-075）；倒下時跪地那段熄掉
const HOOD_EYE_ENERGY: float = 5.0
const HOOD_LIGHT_ENERGY: float = 0.9
const HOOD_LIGHT_RANGE: float = 1.2
## 兜帽冷光在體積霧裡的亮度（Godot 預設 1.0）：只留一點點霧光，不再是一顆光球
const HOOD_LIGHT_FOG: float = 0.15
## 兜帽口最前面的 z（上身座標，-Z 是前方）；頭巾球在 (0, 1.45, -0.32)、半徑 0.26
const HOOD_FACE_Z: float = -0.6


## 倒地後身上的霜氣散出來：一盞冷光從大衣上方慢慢熄掉，讓暗色大衣在夜裡有輪廓（D-054）。
const EXHALE_ENERGY: float = 2.0
const EXHALE_SEC: float = 2.6


func _frost_exhale(at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = "FrostExhale"
	light.light_color = FROST
	light.light_energy = EXHALE_ENERGY
	light.omni_range = 4.0
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	add_child(light)
	light.global_position = at
	if debug_hold_fallen:
		return
	var t := create_tween()
	t.tween_property(light, "light_energy", 0.0, EXHALE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _update_look() -> void:
	var p: float = brain.telegraph_progress()
	for id: String in _decals:
		var mi: MeshInstance3D = _decals[id] as MeshInstance3D
		var on: bool = brain.state == EnemyBrain.State.TELEGRAPH and _decal_for(brain.move_id) == id
		mi.visible = on
		if on:
			(mi.material_override as ShaderMaterial).set_shader_parameter("progress", p)
	_body.position.y = -0.5 if brain.state == EnemyBrain.State.STAGGERED else 0.0
	var lean := Vector3.ZERO
	if brain.state == EnemyBrain.State.TELEGRAPH:
		lean = telegraph_lean(brain.move_id, p)
	if throw_windup > 0.0:
		# 舉起鐵架：上身後仰，越接近擲出越後仰
		var k: float = 1.0 - throw_windup / _throw_total
		lean = Vector3(-FALL_FORWARD * (10.0 + 25.0 * k), 0, 0)
	(_body.get_node("Torso") as Node3D).rotation_degrees = lean
	_update_pipes()


## 前兆姿勢（上身的旋轉角度）：橫掃身體向左擰、下砸上身後仰、抓取與衝撞往前探。
## 繞 X 軸負角度是往前（FALL_FORWARD）；之前正負號寫反，下砸變成前傾、衝撞變成後仰。
static func telegraph_lean(move_id: String, p: float) -> Vector3:
	match move_id:
		"sweep":
			return Vector3(0, 35.0 * p, 0)
		"slam", "double_slam", "double_slam_2":
			return Vector3(-FALL_FORWARD * 18.0 * p, 0, 0)
		"grab":
			return Vector3(FALL_FORWARD * 30.0 * p, 0, 0)
		"charge":
			return Vector3(FALL_FORWARD * 22.0 * p, 0, 0)
		"spray":
			# 噴毒：挺胸吸氣（微微後仰、往右擰一點），跟舉手的招式分得出來
			return Vector3(-FALL_FORWARD * 9.0 * p, -8.0 * p, 0)
	return Vector3.ZERO


func _build_body() -> void:
	super._build_body()
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.6
	cap.height = 2.6
	shape.shape = cap
	shape.position = Vector3(0, 1.3, 0)
	add_child(shape)
	var robe := StandardMaterial3D.new()
	robe.albedo_color = ROBE_ALBEDO
	robe.roughness = 1.0
	# 邊緣光：暗色大衣在燈下有一圈輪廓（D-054）
	robe.rim_enabled = true
	robe.rim = 0.7
	robe.rim_tint = 0.35
	var iron: ShaderMaterial = frame_iron_material()
	var torso := Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, 1.0, 0)
	_body.add_child(torso)
	var coat := CSGCylinder3D.new()
	coat.radius = 0.55
	coat.height = 2.0
	coat.cone = true
	coat.position = Vector3(0, 0.1, 0)
	coat.material = robe
	torso.add_child(coat)
	var chest := CSGBox3D.new()
	chest.size = Vector3(1.0, 0.8, 0.55)
	chest.position = Vector3(0, 0.95, -0.05)
	chest.rotation_degrees = Vector3(-15, 0, 0)
	chest.material = robe
	torso.add_child(chest)
	var hood := CSGSphere3D.new()
	hood.radius = 0.26
	hood.position = Vector3(0, 1.45, -0.32)
	hood.material = robe
	torso.add_child(hood)
	# 兜帽裡兩點霜光＋一盞小冷光照在胸口（D-075）：遠處的送葬者不再跟夜色融成一團，看得出他在看你
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color.BLACK
	eye_mat.emission_enabled = true
	eye_mat.emission = FROST
	eye_mat.emission_energy_multiplier = HOOD_EYE_ENERGY
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.024
	eye_mesh.height = 0.048
	eye_mesh.radial_segments = 8
	eye_mesh.rings = 4
	for x: float in [-0.065, 0.065]:
		var eye := MeshInstance3D.new()
		eye.name = "HoodEyeL" if x < 0.0 else "HoodEyeR"
		eye.mesh = eye_mesh
		eye.material_override = eye_mat
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.position = Vector3(x, 1.44, HOOD_FACE_Z - 0.012)
		torso.add_child(eye)
	# 兜帽口（D-101）：兜帽前面一塊壓扁的黑色橢球，看起來是兜帽裡一片看不見臉的黑，
	# 兩點霜光浮在黑裡（原本霜光點在頭巾球裡面被擋住，兜帽冷光又把頭巾照成一顆亮球）
	var void_mat := StandardMaterial3D.new()
	void_mat.albedo_color = Color(0.008, 0.008, 0.012)
	void_mat.roughness = 1.0
	var void_mesh := SphereMesh.new()
	void_mesh.radius = 0.17
	void_mesh.height = 0.34
	void_mesh.radial_segments = 16
	void_mesh.rings = 8
	var face := MeshInstance3D.new()
	face.name = "HoodVoid"
	face.mesh = void_mesh
	face.material_override = void_mat
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	face.scale = Vector3(1.0, 1.12, 0.35)
	face.position = Vector3(0, 1.43, HOOD_FACE_Z + 0.17 * 0.35)
	torso.add_child(face)
	var hood_light := OmniLight3D.new()
	hood_light.name = "HoodLight"
	hood_light.light_color = FROST
	hood_light.light_energy = HOOD_LIGHT_ENERGY
	# 只照胸口一小塊（D-101）：原本 2.4 m、放在兜帽前，把頭巾照成一顆亮球、整件大衣正面照成霧藍色，
	# 又在體積霧裡亮成一團光，整個人看起來是一團灰藍
	hood_light.omni_range = HOOD_LIGHT_RANGE
	hood_light.omni_attenuation = 1.6
	hood_light.shadow_enabled = false
	hood_light.light_volumetric_fog_energy = HOOD_LIGHT_FOG
	hood_light.position = Vector3(0, 1.05, -0.78)
	torso.add_child(hood_light)
	# 背上的鐵架：兩根立柱＋三根橫桿＋關節（弱點）；擲出去之後整組藏起來（ThrownFrame 接手）
	var frame := Node3D.new()
	frame.name = "Frame"
	torso.add_child(frame)
	for x: float in [-0.45, 0.45]:
		var post := CSGBox3D.new()
		post.size = Vector3(0.08, 2.2, 0.08)
		post.position = Vector3(x, 1.1, 0.5)
		post.material = iron
		frame.add_child(post)
	for y: float in [0.4, 1.1, 1.9]:
		var bar := CSGBox3D.new()
		bar.size = Vector3(1.1, 0.07, 0.07)
		bar.position = Vector3(0, y, 0.52)
		bar.material = iron
		frame.add_child(bar)
	for side: float in [-1.0, 1.0]:
		var arm := CSGCylinder3D.new()
		arm.radius = 0.12
		arm.height = 1.2
		arm.position = Vector3(side * 0.62, 0.6, -0.15)
		arm.rotation_degrees = Vector3(-20, 0, side * 8.0)
		arm.material = robe
		torso.add_child(arm)
	_build_chains(torso, iron)
	_build_ground_shadow()
	_build_decals()


## 手裡拖著的兩條鐵鏈（D-200）：從兩手垂到地上、再往身後拖一段（之前只有腳步聲裡的鐵鏈擦地，身上看不到）。
## 名字 ChainL／ChainR（Torso 底下，跟著手）＋ChainTrailL／R（_body 底下，躺在地上）；第二階段扯斷右邊那條（enter_phase_two 藏起來）。
func _build_chains(torso: Node3D, iron: Material) -> void:
	for side: float in [-1.0, 1.0]:
		var root := Node3D.new()
		root.name = "ChainL" if side < 0.0 else "ChainR"
		root.position = CHAIN_HAND * Vector3(side, 1.0, 1.0)
		torso.add_child(root)
		var drop: float = CHAIN_HAND.y + torso.position.y - 0.04
		var hang := MeshInstance3D.new()
		hang.name = "Hang"
		hang.mesh = ChainMesh.build(drop, CHAIN_LINK.x, CHAIN_LINK.y, CHAIN_LINK.z)
		hang.material_override = iron
		root.add_child(hang)
		# 躺在地上往身後（+Z）拖的一段：掛在 _body（不跟著上身前傾後仰，永遠貼地）。
		# ChainMesh 是往 -Y 長的，繞 X 轉 -90° 變成往 +Z
		var trail := MeshInstance3D.new()
		trail.name = "ChainTrail" + ("L" if side < 0.0 else "R")
		trail.mesh = ChainMesh.build(CHAIN_TRAIL, CHAIN_LINK.x, CHAIN_LINK.y, CHAIN_LINK.z)
		trail.material_override = iron
		trail.position = Vector3(side * CHAIN_HAND.x, CHAIN_LINK.z, CHAIN_HAND.z - CHAIN_LINK.x * 0.5)
		trail.rotation_degrees = Vector3(-90.0, side * 12.0, 0.0)
		_body.add_child(trail)


## 地上拖的那兩段看不看得到（D-200）：吊著（第 3 章）、倒下的時候藏起來；第二階段扯斷的右邊那條不會再出現。
func set_chain_trails(on: bool) -> void:
	if _body == null:
		return
	for side: String in ["L", "R"]:
		var trail: Node3D = _body.get_node_or_null("ChainTrail" + side) as Node3D
		if trail != null:
			trail.visible = on and not (side == "R" and phase >= 2)


## 鐵架材質（D-101）：背上的與擲出去的（ThrownFrame）共用
static func frame_iron_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(FRAME_IRON_SHADER) as Shader
	mat.set_shader_parameter("rim_color", FROST)
	return mat


## 腳下的接地陰影（D-101）：掛在送葬者本身（不跟著 _body 跪下、下沉），永遠貼地
func _build_ground_shadow() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * GROUND_SHADOW_RADIUS * 2.0
	var mat := ShaderMaterial.new()
	mat.shader = load(GROUND_SHADOW_SHADER) as Shader
	mat.set_shader_parameter("strength", GROUND_SHADOW_STRENGTH)
	mat.render_priority = -1
	var mi := MeshInstance3D.new()
	mi.name = "GroundShadow"
	mi.mesh = plane
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.015, 0)
	add_child(mi)


func ground_shadow() -> MeshInstance3D:
	return get_node_or_null("GroundShadow") as MeshInstance3D


func _set_shadow_strength(v: float) -> void:
	var mi: MeshInstance3D = ground_shadow()
	if mi != null:
		(mi.material_override as ShaderMaterial).set_shader_parameter("strength", v)


## 招式 → 地面霜紋（連續下砸共用下砸的圓、抓取用小扇形）
static func _decal_for(move: String) -> String:
	if move.contains("slam"):
		return "slam"
	return move


func _build_decals() -> void:
	var sweep_r: float = brain.move_num("sweep", "range", 3.2)
	var sweep_arc: float = brain.move_num("sweep", "arc_deg", 150.0)
	_decals["sweep"] = _decal(_fan_mesh(sweep_r, sweep_arc), Vector3(0, 0.03, 0), SHAPE_FAN, Vector2(sweep_r, 0.0), sweep_arc)
	var disc := CylinderMesh.new()
	var r: float = brain.move_num("slam", "radius", 2.0)
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = 0.01
	_decals["slam"] = _decal(disc, Vector3(0, 0.03, -brain.move_num("slam", "reach", 1.9)), SHAPE_DISC, Vector2(r, 0.0))
	var lane := BoxMesh.new()
	var length: float = 8.0
	var half_w: float = brain.move_num("charge", "hit_radius", 1.1)
	lane.size = Vector3(half_w * 2.0, 0.01, length)
	_decals["charge"] = _decal(lane, Vector3(0, 0.03, -length * 0.5), SHAPE_LANE, Vector2(half_w, length * 0.5))
	var grab_r: float = brain.move_num("grab", "range", 2.2)
	var grab_arc: float = brain.move_num("grab", "arc_deg", 90.0)
	_decals["grab"] = _decal(_fan_mesh(grab_r, grab_arc), Vector3(0, 0.03, 0), SHAPE_FAN, Vector2(grab_r, 0.0), grab_arc)


## 前兆範圍的材質（D-088）：telegraph.gdshader，亮邊＋淡底＋隨前兆進度從敵人那一端往外填滿。
func _decal(mesh: Mesh, pos: Vector3, shape: int, extent: Vector2, arc_deg: float = 0.0, tint: Color = FROST) -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = load(TELEGRAPH_SHADER) as Shader
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("shape", shape)
	mat.set_shader_parameter("extent", extent)
	mat.set_shader_parameter("half_arc", deg_to_rad(arc_deg * 0.5))
	mat.set_shader_parameter("progress", 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	_body.add_child(mi)
	return mi


## 地面扇形（朝 -Z，左右各 arc/2）。
static func _fan_mesh(radius: float, arc_deg: float, segments: int = 24) -> ArrayMesh:
	var verts := PackedVector3Array()
	var half: float = deg_to_rad(arc_deg * 0.5)
	for i: int in segments:
		var a0: float = -half + (2.0 * half) * float(i) / float(segments)
		var a1: float = -half + (2.0 * half) * float(i + 1) / float(segments)
		verts.append(Vector3.ZERO)
		verts.append(Vector3(-sin(a0), 0, -cos(a0)) * radius)
		verts.append(Vector3(-sin(a1), 0, -cos(a1)) * radius)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
