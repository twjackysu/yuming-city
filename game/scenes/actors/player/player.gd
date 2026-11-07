class_name PlayerController
extends CharacterBody3D
## 諾恩：第三人稱移動＋越肩鏡頭（docs/design/02-gameplay.md「鏡頭」）。
## 鏡頭架（CameraRig）設 top_level，自己跟隨玩家，避免角色轉身時鏡頭跟著甩。

const WALK_SPEED: float = 3.4
const SPRINT_SPEED: float = 5.8
const ACCEL: float = 12.0
const TURN_SPEED: float = 10.0
const GRAVITY: float = 18.0
const DODGE_SPEED: float = 8.5
const DODGE_TIME: float = 0.35
const DODGE_INVULN: float = 0.25
const DODGE_COOLDOWN: float = 0.2
const MOUSE_SENS: float = 0.0025
const PAD_LOOK_SPEED: float = 2.8
const PAD_DEADZONE: float = 0.15
const PITCH_MIN: float = deg_to_rad(-55.0)
const PITCH_MAX: float = deg_to_rad(40.0)
const CAMERA_HEIGHT: float = 1.6
const FOV_WALK: float = 70.0
const FOV_SPRINT: float = 75.0
## 鎖定（02-gameplay「鏡頭」）：15 公尺外自動解除；挑鏡頭前方 70° 內最近的敵人
const LOCK_RANGE: float = 15.0
const LOCK_CONE_DEG: float = 70.0
const LOCK_PITCH: float = -0.28

var yaw: float = 0.0
var pitch: float = -0.18
var invulnerable: bool = false
## 按住看穿（insight）中；敵人自己讀這個值決定要不要顯示已知資訊（02-gameplay「看穿」：不放慢時間）
var insight_active: bool = false
## 上一次揮擊打中弱點的數量（測試與音效用）
var last_weak_hits: int = 0
## 目前鎖定的敵人（null＝沒鎖定）；席菈的「打弱點」也打這個
var lock_target: Node3D = null
var _lock_marker: MeshInstance3D

var _dodge_left: float = 0.0
var _dodge_cooldown: float = 0.0
var _dodge_dir: Vector3 = Vector3.ZERO

@onready var _rig: Node3D = $CameraRig
@onready var _pitch_node: Node3D = $CameraRig/Pitch
@onready var _arm: SpringArm3D = $CameraRig/Pitch/SpringArm3D
@onready var _camera: Camera3D = $CameraRig/Pitch/SpringArm3D/Camera3D
@onready var _body: Node3D = $Body
@onready var _lantern: Node3D = $Body/Lantern

var _puppet: Puppet
## 生命（數值在 data/combat/tuning.json 的 noen）；閃避無敵期間不扣血
var health: Health
var _swing_resolved: bool = true
var _shake: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rig.top_level = true
	add_to_group("player")
	add_to_group("heartbeat")
	_puppet = Puppet.new()
	_puppet.name = "Puppet"
	_body.add_child(_puppet)
	# 提燈掛在左手
	_lantern.reparent(_puppet.hand("L"), false)
	_lantern.position = Vector3(0, -0.12, 0)
	_arm.add_excluded_object(get_rid())
	health = Health.new(CombatTuning.num("noen.max_hp", 100.0))
	health.name = "Health"
	health.invulnerable_check = is_invulnerable
	health.died.connect(_on_died)
	add_child(health)
	yaw = rotation.y
	snap_camera()
	_camera.current = true
	_build_lock_marker()


## 把輸入（x=左右，y=前後，前為負）依鏡頭水平角度轉成世界方向。純函式，方便測試。
static func move_direction(input: Vector2, camera_yaw: float) -> Vector3:
	var dir := Basis(Vector3.UP, camera_yaw) * Vector3(input.x, 0.0, input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	return dir


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_add_look(Vector2(-motion.relative.x, -motion.relative.y) * MOUSE_SENS)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func puppet() -> Puppet:
	return _puppet


func _add_look(delta_look: Vector2) -> void:
	if lock_target != null:
		delta_look.x = 0.0  # 鎖定中水平方向由目標決定
	yaw = wrapf(yaw + delta_look.x, -PI, PI)
	pitch = clampf(pitch + delta_look.y, PITCH_MIN, PITCH_MAX)


func _physics_process(delta: float) -> void:
	var pad := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if pad.length() > PAD_DEADZONE:
		_add_look(-pad * PAD_LOOK_SPEED * delta)

	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var talking: bool = Game.is_player_locked()
	if talking:
		input = Vector2.ZERO
	insight_active = Input.is_action_pressed("insight") and not talking and not health.is_dead()
	var dir: Vector3 = move_direction(input, yaw)
	var sprinting: bool = Input.is_action_pressed("sprint") and input.length() > 0.1

	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	if talking:
		pass
	elif Input.is_action_just_pressed("dodge") and _dodge_left <= 0.0 and _dodge_cooldown <= 0.0:
		_dodge_dir = dir if dir.length() > 0.1 else -_body.global_basis.z
		_dodge_dir = _dodge_dir.normalized()
		_dodge_left = DODGE_TIME
		_puppet.play_action("dodge")
		Sfx.play_at(self, "whoosh", global_position + Vector3.UP, -4.0)
	elif Input.is_action_just_pressed("attack") and _puppet.action == "" and not health.is_dead():
		start_attack()
	if not talking and Input.is_action_just_pressed("lock_on"):
		toggle_lock()
	_update_lock(delta)
	_update_swing()

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if _dodge_left > 0.0:
		_dodge_left -= delta
		invulnerable = _dodge_left > DODGE_TIME - DODGE_INVULN
		horizontal = _dodge_dir * DODGE_SPEED
		if _dodge_left <= 0.0:
			_dodge_cooldown = DODGE_COOLDOWN
			invulnerable = false
	else:
		var target: Vector3 = dir * (SPRINT_SPEED if sprinting else WALK_SPEED)
		horizontal = horizontal.lerp(target, clampf(ACCEL * delta, 0.0, 1.0))

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	_puppet.set_move_speed(horizontal.length())
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()

	if lock_target != null and _dodge_left <= 0.0 and not sprinting:
		var to_t: Vector3 = lock_target.global_position - global_position
		_body.rotation.y = lerp_angle(_body.rotation.y, atan2(-to_t.x, -to_t.z), clampf(TURN_SPEED * delta, 0.0, 1.0))
	elif horizontal.length() > 0.3:
		var face: float = atan2(-horizontal.x, -horizontal.z)
		_body.rotation.y = lerp_angle(_body.rotation.y, face, clampf(TURN_SPEED * delta, 0.0, 1.0))

	var fov_target: float = FOV_SPRINT if sprinting else FOV_WALK
	_camera.fov = lerpf(_camera.fov, fov_target, clampf(4.0 * delta, 0.0, 1.0))
	_follow_rig(delta)


func _on_died() -> void:
	var t := create_tween()
	t.tween_property(_body, "rotation_degrees:x", -85.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	Game.on_player_died()


## 鎖定／解除。回傳鎖定後的目標（解除或找不到時為 null）。
func toggle_lock() -> Node3D:
	if lock_target != null:
		lock_target = null
	else:
		var cam_fwd: Vector3 = Basis(Vector3.UP, yaw) * Vector3.FORWARD
		lock_target = pick_lock_target(global_position, cam_fwd, get_tree().get_nodes_in_group("enemies"))
	return lock_target


## 挑鎖定目標：鏡頭前方 LOCK_CONE_DEG 內、LOCK_RANGE 內，角度與距離加權最小者；前方沒有就挑最近的。純函式。
static func pick_lock_target(origin: Vector3, cam_forward: Vector3, candidates: Array) -> Node3D:
	var best: Node3D = null
	var best_score: float = INF
	var nearest: Node3D = null
	var nearest_d: float = INF
	for c: Variant in candidates:
		var n: Node3D = c as Node3D
		if n == null or not lockable(n):
			continue
		var d := Vector3(n.global_position.x - origin.x, 0.0, n.global_position.z - origin.z)
		var dist: float = d.length()
		if dist > LOCK_RANGE:
			continue
		if dist < nearest_d:
			nearest_d = dist
			nearest = n
		var ang: float = rad_to_deg(Vector3(cam_forward.x, 0.0, cam_forward.z).angle_to(d)) if dist > 0.01 else 0.0
		if ang <= LOCK_CONE_DEG:
			var score: float = dist + ang * 0.08
			if score < best_score:
				best_score = score
				best = n
	return best if best != null else nearest


static func lockable(n: Node3D) -> bool:
	if not is_instance_valid(n) or not n.is_inside_tree():
		return false
	var h: Health = n.get_node_or_null("Health") as Health
	return h == null or not h.is_dead()


func _update_lock(delta: float) -> void:
	if lock_target != null:
		if not lockable(lock_target) or lock_target.global_position.distance_to(global_position) > LOCK_RANGE:
			lock_target = null
	if lock_target == null:
		_lock_marker.visible = false
		return
	var d: Vector3 = lock_target.global_position - global_position
	if Vector2(d.x, d.z).length() > 0.3:
		yaw = lerp_angle(yaw, atan2(-d.x, -d.z), clampf(6.0 * delta, 0.0, 1.0))
	pitch = lerpf(pitch, LOCK_PITCH, clampf(3.0 * delta, 0.0, 1.0))
	var h: float = float(lock_target.call("lock_height")) if lock_target.has_method("lock_height") else 2.2
	_lock_marker.global_position = lock_target.global_position + Vector3.UP * h
	_lock_marker.visible = true


func _build_lock_marker() -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = true
	m.albedo_color = Color(1.0, 0.86, 0.6)
	var prism := PrismMesh.new()
	prism.size = Vector3(0.16, 0.16, 0.02)
	_lock_marker = MeshInstance3D.new()
	_lock_marker.name = "LockMarker"
	_lock_marker.mesh = prism
	_lock_marker.material_override = m
	_lock_marker.rotation_degrees = Vector3(0, 0, 180)  # 倒三角指向目標
	_lock_marker.top_level = true
	_lock_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lock_marker.visible = false
	add_child(_lock_marker)


func is_invulnerable() -> bool:
	return invulnerable


func start_attack() -> void:
	_puppet.play_action("attack")
	_swing_resolved = false


## 鐘錘下劈：動作進到命中區間（strike_window，動作時間比例）時判定一次。
func _update_swing() -> void:
	if _swing_resolved:
		return
	if _puppet.action != "attack":
		_swing_resolved = true
		return
	var t: float = _puppet.action_time / float(Puppet.ACTION_TIME["attack"])
	var window: Vector2 = CombatTuning.pair("noen.strike_window", Vector2(0.35, 0.6))
	if t >= window.x:
		_swing_resolved = true
		if t <= window.y:
			strike()


## 對前方扇形內所有 damageable 群組的目標造成鈍擊。回傳命中數。
func strike() -> int:
	var forward: Vector3 = -_body.global_basis.z
	var reach: float = CombatTuning.num("noen.strike_range", 1.9)
	var arc: float = CombatTuning.num("noen.strike_arc_deg", 110.0)
	var damage: float = CombatTuning.num("noen.blunt_damage", 6.0)
	var stagger: float = CombatTuning.num("noen.blunt_stagger", 20.0)
	var weak_damage: float = CombatTuning.num("noen.weak_damage_mult", 2.0)
	var weak_stagger: float = CombatTuning.num("noen.weak_stagger_mult", 2.0)
	var hits: int = 0
	var killed: bool = false
	last_weak_hits = 0
	for n: Node in get_tree().get_nodes_in_group("damageable"):
		var target: Node3D = n as Node3D
		if target == null or target == self:
			continue
		if not in_strike_arc(global_position, forward, target.global_position, reach, arc):
			continue
		var h: Health = target.get_node_or_null("Health") as Health
		if h == null:
			continue
		var weak: String = ""
		if target.has_method("weakpoint_exposed_to"):
			weak = str(target.call("weakpoint_exposed_to", global_position))
		var k_dmg: float = weak_damage if weak != "" else 1.0
		var k_stg: float = weak_stagger if weak != "" else 1.0
		if h.apply_damage(damage * k_dmg, {"source": self, "stagger": stagger * k_stg, "kind": "blunt", "weak": weak}):
			hits += 1
			if weak != "":
				last_weak_hits += 1
			killed = killed or h.is_dead()
	if hits > 0:
		Sfx.play_at(self, "blunt_weak" if last_weak_hits > 0 else "blunt", global_position + forward * reach * 0.7 + Vector3.UP * 0.6)
		var stop_key: String = "feel.hit_stop_kill" if killed else ("feel.hit_stop_weak" if last_weak_hits > 0 else "feel.hit_stop")
		Game.hit_stop(CombatTuning.num(stop_key, 0.06))
		shake(CombatTuning.num("feel.shake_kill" if killed else "feel.shake_hit", 0.2))
	return hits


## 水平面上的扇形判定（不看高度）。純函式。
static func in_strike_arc(origin: Vector3, forward: Vector3, target: Vector3, reach: float, arc_deg: float) -> bool:
	var d := Vector3(target.x - origin.x, 0.0, target.z - origin.z)
	var dist: float = d.length()
	if dist > reach:
		return false
	if dist < 0.3:
		return true
	var f := Vector3(forward.x, 0.0, forward.z)
	if f.length() < 0.001:
		return false
	return f.angle_to(d) <= deg_to_rad(arc_deg * 0.5)


## 鏡頭震動（減少晃動開啟時縮到 reduced_shake_scale）。
func shake(amount: float) -> void:
	var k: float = CombatTuning.num("feel.reduced_shake_scale", 0.25) if Settings.reduce_camera_shake else 1.0
	_shake = maxf(_shake, amount * k)


func shake_amount() -> float:
	return _shake


func _process(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(_shake - 2.5 * delta, 0.0)
	var a: float = _shake * _shake
	_camera.h_offset = _rng.randf_range(-1.0, 1.0) * 0.12 * a
	_camera.v_offset = _rng.randf_range(-1.0, 1.0) * 0.12 * a


func _follow_rig(delta: float) -> void:
	var target: Vector3 = global_position + Vector3(0.0, CAMERA_HEIGHT, 0.0)
	_rig.global_position = _rig.global_position.lerp(target, clampf(14.0 * delta, 0.0, 1.0))
	_rig.rotation = Vector3(0.0, yaw, 0.0)
	_pitch_node.rotation = Vector3(pitch, 0.0, 0.0)


## 傳送玩家後呼叫，鏡頭立即就位（不從舊位置滑過來）。
func snap_camera() -> void:
	_rig.global_position = global_position + Vector3(0.0, CAMERA_HEIGHT, 0.0)
	_rig.rotation = Vector3(0.0, yaw, 0.0)
	_pitch_node.rotation = Vector3(pitch, 0.0, 0.0)
