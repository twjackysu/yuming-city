class_name DemoGuard
extends EnemyActor
## 示範場的守衛（第二段 B 的後半，D-233）：人形的小敵人，身體是程序人偶（跟布景裡那兩個守衛同一套顏色）。
## 兩種（進場景樹之前設 `kind`）：
## - club＝台下拿棍子的：棍子橫掃（swing，寬）、直刺（thrust，窄但遠）。
## - bracer＝台上示範、兩手戴著高速護腕的：快拳（jab）前兆很短，但**每打完一拳右手就麻掉、垂著僵住很久**
##   （破綻長、破綻中失衡三倍）——商人沒講的副作用，打起來一看就知道。他的左手從頭到尾垂著不動（早就麻了）。
## 沒有狀態攻擊：中毒回血在這一場幫不上忙。倒下之後躺在原地（是人，不沉進地裡），也不再算敵人。

const KIND_CLUB: String = "club"
const KIND_BRACER: String = "bracer"
const COAT: Color = Color(0.12, 0.14, 0.19)
const TRIM: Color = Color(0.5, 0.47, 0.42)
## 護腕箍上的冷光（跟台上桌子上那三個同一個顏色）；麻掉的時候變成一閃一閃的暗紅
const BRACER_GLOW: Color = Color(0.6, 0.85, 1.0)
const NUMB_GLOW: Color = Color(1.0, 0.3, 0.16)
const BRACER_ENERGY: float = 2.6
## 棍頭的銅箍：平常幾乎不亮，前兆時亮起來（看得出他要出手了）
const CLUB_GLOW: Color = Color(1.0, 0.72, 0.4)
## 斜掛在胸前的紅白布條（跟示範台的直條紋同一組顏色）：深色的人在暗的街上看得出「這兩個是商人的人」，也跟看熱鬧的人分得開
const SASH_RED: Color = Color(0.66, 0.11, 0.1)
const SASH_WHITE: Color = Color(0.86, 0.82, 0.74)
const STRIDE: float = 0.78
const STEP_DB: float = -15.0

var kind: String = KIND_CLUB
## 身高倍率（布景的那兩個是 1.1／1.08）
var height: float = 1.1
## 出過幾招、最後一招（測試用）
var strike_count: int = 0
var last_move: String = ""
## 截圖用：停在某個姿勢（不追、不出招）
var debug_hold: bool = false

var _puppet: Puppet
var _glow_mat: StandardMaterial3D
var _time: float = 0.0


## 蓋掉人偶的關節：人偶自己的 `_pose` 每一幀都會重設，所以掛在人偶底下、排在它後面跑。
class PoseDriver extends Node:
	var guard: DemoGuard

	func _process(delta: float) -> void:
		if guard != null and is_instance_valid(guard):
			guard.apply_pose(delta)


func intel_id() -> String:
	return "demo_bracer" if kind == KIND_BRACER else "demo_guard"


func is_bracer() -> bool:
	return kind == KIND_BRACER


func puppet() -> Puppet:
	return _puppet


## 右手麻掉了（快拳之後的破綻）：護腕變暗紅、手垂著
func is_numb() -> bool:
	return is_bracer() and brain != null and brain.state == EnemyBrain.State.RECOVER


func glow_energy() -> float:
	return _glow_mat.emission_energy_multiplier if _glow_mat != null else 0.0


func glow_color() -> Color:
	return _glow_mat.emission if _glow_mat != null else Color.BLACK


## 從台子上跳下來：只有身體從 from_height 落到地上（碰撞的膠囊一開始就在地上，不靠物理掉下來）。
func hop_down(from_height: float, sec: float) -> void:
	if _body == null:
		return
	_body.position.y = from_height
	var t := create_tween()
	t.tween_property(_body, "position:y", 0.0, sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## 截圖用：停在某一招的某個狀態（ratio＝那個狀態走到幾成），面向 look。之後不追、不出招。
func hold_pose(move: String, state: EnemyBrain.State, ratio: float, look: Vector3) -> void:
	debug_hold = true
	brain._set_move(move)
	brain.state = state
	var span: float = brain.telegraph_sec if state == EnemyBrain.State.TELEGRAPH else brain.recover_sec
	brain.time_in_state = span * ratio
	var d: Vector3 = look - global_position
	set_facing(atan2(-d.x, -d.z))
	_update_look()


func _make_footsteps() -> Footsteps:
	var f := Footsteps.new(STRIDE, STRIDE, STEP_DB, STEP_DB)
	f.pitch_base = 0.92
	f.pitch_jitter = 0.06
	f.unit_size = 3.5
	return f


func _insight_height() -> float:
	return 1.85 * height


func _hit_height() -> float:
	return 1.1 * height


func _held(_delta: float) -> bool:
	return debug_hold


## 出招：前方扇形裡的心跳（諾恩、席菈）受傷。每一招的距離、角度、傷害在 tuning.json。
func _on_strike() -> void:
	var move: String = brain.move_id
	strike_count += 1
	last_move = move
	var fwd: Vector3 = forward()
	var origin: Vector3 = global_position
	if is_inside_tree():
		Sfx.play_at(get_parent(), "blunt" if is_bracer() else "whoosh", origin + fwd * 0.9 + Vector3.UP * 1.2, -5.0, 0.06, 5.0)
	var reach: float = brain.move_num(move, "reach", brain.attack_range + 0.3)
	var arc: float = brain.move_num(move, "arc_deg", 100.0)
	hit_heartbeats(brain.move_num(move, "damage", 10.0), move,
		func(p: Vector3) -> bool: return PlayerController.in_strike_arc(origin, fwd, p, reach, arc))


func _update_look() -> void:
	_time += get_physics_process_delta_time()
	if _puppet != null:
		var real: Vector3 = get_real_velocity()
		_puppet.set_move_speed(Vector2(real.x, real.z).length() if brain.is_moving() else 0.0)
	if _glow_mat == null:
		return
	var p: float = brain.telegraph_progress()
	if not is_bracer():
		var lit: float = 4.5 if brain.state == EnemyBrain.State.STRIKE else p * p * 5.0
		_glow_mat.emission_energy_multiplier = 0.12 + lit
		return
	match brain.state:
		EnemyBrain.State.TELEGRAPH:
			_glow_mat.emission = BRACER_GLOW
			_glow_mat.emission_energy_multiplier = BRACER_ENERGY + p * 7.0
		EnemyBrain.State.STRIKE:
			_glow_mat.emission = BRACER_GLOW
			_glow_mat.emission_energy_multiplier = BRACER_ENERGY + 8.0
		EnemyBrain.State.RECOVER:
			# 麻掉：一閃一閃的暗紅（不規則，像接觸不良）
			_glow_mat.emission = NUMB_GLOW
			_glow_mat.emission_energy_multiplier = 1.0 + 1.6 * absf(sin(_time * 19.0) * sin(_time * 7.3))
		EnemyBrain.State.DEAD:
			_glow_mat.emission = NUMB_GLOW
			_glow_mat.emission_energy_multiplier = 0.25
		_:
			_glow_mat.emission = BRACER_GLOW
			_glow_mat.emission_energy_multiplier = BRACER_ENERGY


## 照狀態擺姿勢（PoseDriver 每一幀叫；用角色模型時沒有這些關節，什麼都不做）。
## 肩膀 x 正的＝手往前往上、z 正的（右手）＝往外張；手肘 x 正的＝彎；膝蓋 x 負的＝彎。
func apply_pose(_delta: float) -> void:
	if _puppet == null or _puppet.uses_model() or brain == null:
		return
	_rot("hand_R", Vector3.ZERO)
	if is_bracer():
		# 左手早就麻了：垂著，一次都不動（諾恩在台下看到的就是這個）
		_rot("shoulder_L", Vector3(0.0, 0.0, -0.04))
		_rot("elbow_L", Vector3(0.02, 0.0, 0.0))
	var p: float = ease(brain.telegraph_progress(), 0.5)
	match brain.state:
		EnemyBrain.State.TELEGRAPH:
			_pose_windup(brain.move_id, p)
		EnemyBrain.State.STRIKE:
			_pose_strike(brain.move_id, 1.0)
		EnemyBrain.State.RECOVER:
			var k: float = clampf(brain.time_in_state / maxf(brain.recover_sec, 0.01), 0.0, 1.0)
			if is_bracer():
				_pose_numb()
			else:
				_pose_strike(brain.move_id, 1.0 - ease(k, 0.6))
		EnemyBrain.State.STAGGERED:
			_pose_kneel()
		EnemyBrain.State.DEAD:
			_rot("shoulder_R", Vector3(2.5, 0.0, 0.5))
			_rot("elbow_R", Vector3(0.5, 0.0, 0.0))
			_rot("shoulder_L", Vector3(2.3, 0.0, -0.6))
			_rot("elbow_L", Vector3(0.7, 0.0, 0.0))
			_rot("neck", Vector3(-0.3, 0.5, 0.0))


func _pose_windup(move: String, p: float) -> void:
	match move:
		"swing":
			# 棍子往右後方拉開，身體跟著轉過去
			_rot("shoulder_R", Vector3(0.5 * p, 0.0, 0.12 + 1.35 * p))
			_rot("elbow_R", Vector3(0.25 + 0.5 * p, 0.0, 0.0))
			_rot("chest", Vector3(0.0, -0.7 * p, 0.0))
			_rot("spine", Vector3(-0.05, -0.2 * p, 0.0))
		"thrust":
			# 手肘往後收、棍頭對著人
			_rot("shoulder_R", Vector3(-0.75 * p, 0.0, 0.2))
			_rot("elbow_R", Vector3(0.25 + 1.5 * p, 0.0, 0.0))
			_rot("hand_R", Vector3(-0.75 * p, 0.0, 0.0))
			_rot("chest", Vector3(0.05 * p, -0.4 * p, 0.0))
		_:
			# 快拳：拳頭收到肩膀旁邊（很短的一下）
			_rot("shoulder_R", Vector3(-0.3 * p, 0.0, 0.25))
			_rot("elbow_R", Vector3(0.3 + 1.9 * p, 0.0, 0.0))
			_rot("chest", Vector3(0.0, -0.45 * p, 0.0))


## k＝1 出手到底、0 收回來
func _pose_strike(move: String, k: float) -> void:
	match move:
		"swing":
			_rot("shoulder_R", Vector3(1.25 * k, 0.0, 0.12 - 0.55 * k))
			_rot("elbow_R", Vector3(0.25 - 0.1 * k, 0.0, 0.0))
			_rot("chest", Vector3(0.12 * k, 0.75 * k, 0.0))
			_rot("spine", Vector3(-0.05, 0.25 * k, 0.0))
		"thrust":
			_rot("shoulder_R", Vector3(1.4 * k, 0.0, 0.12))
			_rot("elbow_R", Vector3(0.25 - 0.2 * k, 0.0, 0.0))
			_rot("hand_R", Vector3(-1.35 * k, 0.0, 0.0))
			_rot("chest", Vector3(0.22 * k, 0.3 * k, 0.0))
			_rot("thigh_L", Vector3(0.55 * k, 0.0, 0.0))
			_rot("knee_L", Vector3(-0.05 - 0.45 * k, 0.0, 0.0))
			_rot("thigh_R", Vector3(-0.35 * k, 0.0, 0.0))
		_:
			_rot("shoulder_R", Vector3(1.5 * k, 0.0, 0.12 - 0.2 * k))
			_rot("elbow_R", Vector3(0.25 - 0.2 * k, 0.0, 0.0))
			_rot("chest", Vector3(0.1 * k, 0.45 * k, 0.0))
			_rot("thigh_L", Vector3(0.35 * k, 0.0, 0.0))
			_rot("knee_L", Vector3(-0.05 - 0.3 * k, 0.0, 0.0))


## 麻掉：右手也垂下來、微微發抖，人往前駝、低頭看自己的手
func _pose_numb() -> void:
	var shake: float = sin(_time * 41.0) * 0.045
	_rot("shoulder_R", Vector3(0.1 + shake, 0.0, 0.03))
	_rot("elbow_R", Vector3(0.08 + shake * 0.6, 0.0, 0.0))
	_rot("chest", Vector3(0.3, 0.12, 0.0))
	_rot("spine", Vector3(0.14, 0.0, 0.0))
	_rot("neck", Vector3(0.45, 0.25, 0.0))


## 失衡跪地：右膝著地、左腳踩在前面，上身往前垮
func _pose_kneel() -> void:
	var hips: Node3D = _puppet.joint("hips")
	if hips != null:
		hips.position.y = Puppet.HIP_HEIGHT - 0.42
	_rot("thigh_L", Vector3(1.45, 0.0, 0.0))
	_rot("knee_L", Vector3(-1.5, 0.0, 0.0))
	_rot("thigh_R", Vector3(0.1, 0.0, 0.0))
	_rot("knee_R", Vector3(-1.6, 0.0, 0.0))
	_rot("spine", Vector3(0.35, 0.0, 0.0))
	_rot("neck", Vector3(0.35, 0.0, 0.0))
	_rot("shoulder_R", Vector3(0.35, 0.0, 0.2))
	_rot("elbow_R", Vector3(0.5, 0.0, 0.0))


func _rot(joint_name: String, r: Vector3) -> void:
	var j: Node3D = _puppet.joint(joint_name)
	if j != null:
		j.rotation = r


## 倒下：跪 → 往前撲倒 → 躺在原地（不沉下去、不釋放——是人，不是怪物）。倒下的那一刻就不算敵人了
## （鎖定、席菈找目標、戰鬥 HUD 都是數「enemies」群組）。
func _on_died() -> void:
	_begin_death()
	remove_from_group("enemies")
	if _puppet != null:
		_puppet.set_move_speed(0.0)
	_update_look()
	var t := create_tween()
	_fall_tween = t
	t.tween_property(_body, "position:y", -0.3, DIE_KNEEL_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_body, "rotation_degrees:x", FALL_FORWARD * 84.0, DIE_DROP_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_body, "position:y", 0.16, DIE_DROP_SEC)
	t.tween_callback(_on_fall_impact)


func _build_body() -> void:
	super._build_body()
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.7 * height
	shape.shape = cap
	shape.position = Vector3(0, 0.85 * height, 0)
	add_child(shape)
	ContactShadow.attach(self, 0.6, 0.5)
	_puppet = Puppet.new()
	_puppet.name = "Puppet"
	_puppet.coat_color = COAT
	_puppet.trim_color = TRIM
	_puppet.scale = Vector3.ONE * height
	_body.add_child(_puppet)
	if _puppet.uses_model():
		return
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.albedo_color = Color(0.2, 0.2, 0.22)
	_glow_mat.emission_enabled = true
	var club: Node3D = _puppet.hand("R").get_node_or_null("BellHammer") as Node3D if _puppet.hand("R") != null else null
	if is_bracer():
		if club != null:
			club.queue_free()
		_glow_mat.emission = BRACER_GLOW
		_glow_mat.emission_energy_multiplier = BRACER_ENERGY
		for side: String in ["L", "R"]:
			var elbow: Node3D = _puppet.joint("elbow_" + side)
			if elbow != null:
				var worn: Node3D = _bracer(1.15)
				worn.position = Vector3(0.0, -Puppet.FOREARM_LEN * 0.62, 0.0)
				elbow.add_child(worn)
	else:
		_glow_mat.albedo_color = Color(0.62, 0.42, 0.22)
		_glow_mat.metallic = 0.6
		_glow_mat.roughness = 0.4
		_glow_mat.emission = CLUB_GLOW
		_glow_mat.emission_energy_multiplier = 0.12
		if club != null:
			# 棍頭兩端各一圈銅箍（前兆時亮起來）
			for dy: float in [0.4, 0.6]:
				var band := MeshInstance3D.new()
				band.name = "ClubBand"
				var ring := CylinderMesh.new()
				ring.top_radius = 0.086
				ring.bottom_radius = 0.086
				ring.height = 0.035
				ring.radial_segments = 10
				ring.material = _glow_mat
				band.mesh = ring
				band.position = Vector3(0.0, dy, 0.0)
				band.rotation = Vector3(0.0, 0.0, PI * 0.5)
				club.add_child(band)
	_add_sash()
	var driver := PoseDriver.new()
	driver.name = "PoseDriver"
	driver.guard = self
	_puppet.add_child(driver)


## 胸前斜掛的布條（三段：紅、白、紅）＋兩隻上臂各一圈紅布。掛在胸口的關節上，跟著上身轉。
func _add_sash() -> void:
	var chest: Node3D = _puppet.joint("chest")
	if chest == null:
		return
	var sash := Node3D.new()
	sash.name = "Sash"
	sash.position = Vector3(0.0, 0.16, 0.0)
	sash.rotation = Vector3(0.0, 0.0, 0.62)
	chest.add_child(sash)
	var colors: Array[Color] = [SASH_RED, SASH_WHITE, SASH_RED]
	for i: int in colors.size():
		var strip := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.62, 0.045, 0.34)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i]
		mat.roughness = 0.9
		box.material = mat
		strip.mesh = box
		strip.position = Vector3(0.0, 0.047 * float(i - 1), 0.0)
		sash.add_child(strip)
	for side: String in ["L", "R"]:
		var shoulder: Node3D = _puppet.joint("shoulder_" + side)
		if shoulder == null:
			continue
		var band := MeshInstance3D.new()
		band.name = "ArmBand"
		var ring := CylinderMesh.new()
		ring.top_radius = 0.075
		ring.bottom_radius = 0.072
		ring.height = 0.07
		ring.radial_segments = 10
		var red := StandardMaterial3D.new()
		red.albedo_color = SASH_RED
		red.roughness = 0.9
		ring.material = red
		band.mesh = ring
		band.position = Vector3(0.0, -Puppet.UPPER_ARM_LEN * 0.45, 0.0)
		shoulder.add_child(band)


## 戴在前臂上的護腕：深色的箍＋兩圈會亮的環（兩隻手共用一個材質，一起亮、一起麻）。
func _bracer(size: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Bracer"
	var cuff := CylinderMesh.new()
	cuff.top_radius = 0.062 * size
	cuff.bottom_radius = 0.056 * size
	cuff.height = 0.12 * size
	cuff.radial_segments = 10
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.16, 0.15, 0.17)
	dark.roughness = 0.32
	cuff.material = dark
	var body := MeshInstance3D.new()
	body.mesh = cuff
	root.add_child(body)
	for dy: float in [-0.036, 0.036]:
		var ring := CylinderMesh.new()
		ring.top_radius = 0.067 * size
		ring.bottom_radius = 0.067 * size
		ring.height = 0.018 * size
		ring.radial_segments = 10
		ring.material = _glow_mat
		var band := MeshInstance3D.new()
		band.name = "Ring"
		band.mesh = ring
		band.position.y = dy * size
		root.add_child(band)
	return root
