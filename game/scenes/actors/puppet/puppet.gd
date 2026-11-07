class_name Puppet
extends Node3D
## 程序人偶：在正式角色模型（docs/ART_REQUESTS.md 第 1、2 項）到位前頂替，用程式動畫。
## 關節是 Node3D 樞紐（不是 Skeleton3D），膠囊肢體掛在樞紐上；角色面向 -Z。
##
## 對外介面固定，之後換成有骨架的模型＋AnimationTree 時，外部（PlayerController 等）不用改：
##   set_move_speed(m/s)、play_action("dodge"|"attack")、current_state() ∈ STATES、hand("L"|"R")
## STATES 也就是將來 AnimationTree 狀態機的狀態名。

const STATES: PackedStringArray = ["idle", "walk", "run", "dodge", "attack"]
const WALK_MIN_SPEED: float = 0.3
const RUN_MIN_SPEED: float = 4.6
const RUN_SPEED: float = 5.8
const ACTION_TIME: Dictionary = {"dodge": 0.35, "attack": 0.55}
const HIP_HEIGHT: float = 0.92
const THIGH_LEN: float = 0.44
const SHIN_LEN: float = 0.44
const UPPER_ARM_LEN: float = 0.3
const FOREARM_LEN: float = 0.28

@export var coat_color: Color = Color(0.16, 0.15, 0.17)
@export var trim_color: Color = Color(0.3, 0.24, 0.18)
@export var skin_color: Color = Color(0.62, 0.52, 0.45)

var move_speed: float = 0.0
var action: String = ""
var action_time: float = 0.0
var phase: float = 0.0
var breath: float = 0.0

## 關節名 -> Node3D
var joints: Dictionary = {}
var _roll: Node3D
var _coat: MeshInstance3D


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	advance(delta)


func set_move_speed(speed: float) -> void:
	move_speed = maxf(speed, 0.0)


## 播放一次性動作（閃避、攻擊）；播完回到移動狀態。
func play_action(action_name: String) -> void:
	if not ACTION_TIME.has(action_name):
		push_error("Puppet: 沒有動作 %s" % action_name)
		return
	action = action_name
	action_time = 0.0


func current_state() -> String:
	if action != "":
		return action
	if move_speed >= RUN_MIN_SPEED:
		return "run"
	if move_speed >= WALK_MIN_SPEED:
		return "walk"
	return "idle"


func hand(side: String) -> Node3D:
	return joints.get("hand_" + side) as Node3D


func joint(joint_name: String) -> Node3D:
	return joints.get(joint_name) as Node3D


## 推進動畫並套用姿勢（_process 會呼叫；測試直接呼叫）。
func advance(delta: float) -> void:
	breath += delta
	# 步頻跟速度走：走路約 1.8 步／秒，跑步約 2.8 步／秒（一個 phase 週期＝兩步）
	var speed_t: float = clampf(move_speed / RUN_SPEED, 0.0, 1.0)
	if move_speed >= WALK_MIN_SPEED:
		phase = fmod(phase + delta * TAU * lerpf(0.9, 1.4, speed_t), TAU)
	if action != "":
		action_time += delta
		if action_time >= float(ACTION_TIME[action]):
			action = ""
			action_time = 0.0
	_pose(speed_t)


func _pose(speed_t: float) -> void:
	var moving: float = clampf((move_speed - WALK_MIN_SPEED) / 0.6, 0.0, 1.0)
	var s: float = sin(phase)
	var c: float = cos(phase)
	# 移動：大腿前後擺、膝蓋在後擺時彎、手臂反向擺、骨盆上下
	var thigh_amp: float = lerpf(0.42, 0.75, speed_t) * moving
	var knee_amp: float = lerpf(0.6, 1.3, speed_t) * moving
	var arm_amp: float = lerpf(0.3, 0.7, speed_t) * moving
	var lean: float = lerpf(0.04, 0.2, speed_t) * moving
	var breathe: float = sin(breath * TAU * 0.25) * (1.0 - moving)

	_rot("thigh_L", Vector3(s * thigh_amp, 0, 0))
	_rot("thigh_R", Vector3(-s * thigh_amp, 0, 0))
	_rot("knee_L", Vector3(-maxf(-c, 0.0) * knee_amp - 0.05, 0, 0))
	_rot("knee_R", Vector3(-maxf(c, 0.0) * knee_amp - 0.05, 0, 0))
	_rot("shoulder_L", Vector3(-s * arm_amp, 0, -0.12 - 0.03 * breathe))
	_rot("shoulder_R", Vector3(s * arm_amp, 0, 0.12 + 0.03 * breathe))
	_rot("elbow_L", Vector3(0.25 + arm_amp * 0.6, 0, 0))
	_rot("elbow_R", Vector3(0.25 + arm_amp * 0.6, 0, 0))
	_rot("spine", Vector3(-lean, s * 0.08 * moving, 0))
	_rot("chest", Vector3(0.02 * breathe, -s * 0.1 * moving, 0))
	_rot("neck", Vector3(lean * 0.6, 0, 0))
	var hips: Node3D = joint("hips")
	if hips != null:
		hips.position.y = HIP_HEIGHT - absf(c) * 0.05 * moving + 0.006 * breathe
	if _coat != null:
		_coat.rotation.x = -lean * 0.8 - thigh_amp * 0.15
	if _roll != null:
		_roll.rotation.x = 0.0
		_roll.position = Vector3.ZERO

	match action:
		"dodge":
			_pose_dodge(action_time / float(ACTION_TIME["dodge"]))
		"attack":
			_pose_attack(action_time / float(ACTION_TIME["attack"]))


## 前滾：整個人繞腰部高度轉一圈，膝與手臂收起。
func _pose_dodge(t: float) -> void:
	var e: float = ease(clampf(t, 0.0, 1.0), -1.8)
	var tuck: float = sin(clampf(t, 0.0, 1.0) * PI)
	_roll.position = Vector3(0, 0.5, 0)
	_roll.rotation.x = -TAU * e
	_roll.position.y = 0.5 - 0.35 * tuck
	for side: String in ["L", "R"]:
		_rot("thigh_" + side, Vector3(1.5 * tuck, 0, 0))
		_rot("knee_" + side, Vector3(-2.0 * tuck, 0, 0))
		_rot("shoulder_" + side, Vector3(1.2 * tuck, 0, 0))
		_rot("elbow_" + side, Vector3(1.6 * tuck, 0, 0))
	_rot("spine", Vector3(0.6 * tuck, 0, 0))


## 鐘錘下劈：舉起（0～35%）→ 劈下（35～60%）→ 收回。
func _pose_attack(t: float) -> void:
	var arm: float
	var twist: float
	if t < 0.35:
		var k: float = ease(t / 0.35, 0.6)
		arm = lerpf(0.0, 2.7, k)
		twist = lerpf(0.0, 0.35, k)
	elif t < 0.6:
		var k2: float = ease((t - 0.35) / 0.25, 2.2)
		arm = lerpf(2.7, 0.55, k2)
		twist = lerpf(0.35, -0.3, k2)
	else:
		var k3: float = ease((t - 0.6) / 0.4, -1.5)
		arm = lerpf(0.55, 0.0, k3)
		twist = lerpf(-0.3, 0.0, k3)
	_rot("shoulder_R", Vector3(arm, 0, 0.1))
	_rot("elbow_R", Vector3(0.3, 0, 0))
	_rot("chest", Vector3(0.1, twist, 0))
	_rot("spine", Vector3(-0.1 + twist * 0.3, 0, 0))
	_rot("thigh_L", Vector3(0.35, 0, 0))
	_rot("knee_L", Vector3(-0.3, 0, 0))
	_rot("thigh_R", Vector3(-0.25, 0, 0))


func _rot(joint_name: String, r: Vector3) -> void:
	var j: Node3D = joints.get(joint_name) as Node3D
	if j != null:
		j.rotation = r


# --- 建模 -------------------------------------------------------------------

func _mat(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


func _joint(joint_name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.name = joint_name
	j.position = pos
	parent.add_child(j)
	joints[joint_name] = j
	return j


## 在樞紐下方掛一段膠囊肢體（沿 -Y 方向，長度 length）。
func _limb(parent: Node3D, length: float, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = length + radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 4
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(0, -length * 0.5, 0)
	parent.add_child(mi)
	return mi


func _build() -> void:
	var coat: StandardMaterial3D = _mat(coat_color)
	var trim: StandardMaterial3D = _mat(trim_color)
	var skin: StandardMaterial3D = _mat(skin_color, 0.7)
	var dark: StandardMaterial3D = _mat(Color(0.08, 0.08, 0.09))
	var iron: StandardMaterial3D = _mat(Color(0.32, 0.3, 0.28), 0.45)
	iron.metallic = 0.7

	_roll = Node3D.new()
	_roll.name = "Roll"
	add_child(_roll)
	var hips: Node3D = _joint("hips", _roll, Vector3(0, HIP_HEIGHT, 0))

	# 長外套下擺：從腰部往下的圓錐，跟著步伐微擺
	var skirt := CylinderMesh.new()
	skirt.top_radius = 0.17
	skirt.bottom_radius = 0.36
	skirt.height = 0.9
	skirt.radial_segments = 14
	skirt.material = coat
	_coat = MeshInstance3D.new()
	_coat.name = "CoatSkirt"
	_coat.mesh = skirt
	var skirt_pivot := Node3D.new()
	skirt_pivot.name = "CoatPivot"
	hips.add_child(skirt_pivot)
	skirt_pivot.add_child(_coat)
	_coat.position = Vector3(0, -0.3, 0)

	var spine: Node3D = _joint("spine", hips, Vector3(0, 0.08, 0))
	var chest: Node3D = _joint("chest", spine, Vector3(0, 0.22, 0))
	var torso := _limb(chest, 0.26, 0.19, coat)
	torso.position = Vector3(0, 0.08, 0)
	torso.scale = Vector3(1.0, 1.0, 0.75)
	# 圍巾（暖色，讓剪影有一點顏色）
	var scarf := MeshInstance3D.new()
	var scarf_mesh := TorusMesh.new()
	scarf_mesh.inner_radius = 0.07
	scarf_mesh.outer_radius = 0.15
	scarf_mesh.material = trim
	scarf.mesh = scarf_mesh
	scarf.position = Vector3(0, 0.3, 0)
	chest.add_child(scarf)

	var neck: Node3D = _joint("neck", chest, Vector3(0, 0.34, 0))
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.125
	head_mesh.height = 0.27
	head_mesh.material = skin
	head.mesh = head_mesh
	head.position = Vector3(0, 0.14, 0)
	neck.add_child(head)
	var hair := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.132
	hair_mesh.height = 0.27
	hair_mesh.material = dark
	hair.mesh = hair_mesh
	hair.position = Vector3(0, 0.16, 0.025)
	neck.add_child(hair)

	for side: String in ["L", "R"]:
		var x: float = -1.0 if side == "L" else 1.0
		var shoulder: Node3D = _joint("shoulder_" + side, chest, Vector3(0.23 * x, 0.27, 0))
		_limb(shoulder, UPPER_ARM_LEN, 0.065, coat)
		var elbow: Node3D = _joint("elbow_" + side, shoulder, Vector3(0, -UPPER_ARM_LEN, 0))
		_limb(elbow, FOREARM_LEN, 0.055, coat)
		var hand_j: Node3D = _joint("hand_" + side, elbow, Vector3(0, -FOREARM_LEN - 0.04, 0))
		var hand_mesh := SphereMesh.new()
		hand_mesh.radius = 0.05
		hand_mesh.height = 0.1
		hand_mesh.material = skin
		var hand_mi := MeshInstance3D.new()
		hand_mi.mesh = hand_mesh
		hand_j.add_child(hand_mi)

		var thigh: Node3D = _joint("thigh_" + side, hips, Vector3(0.1 * x, -0.04, 0))
		_limb(thigh, THIGH_LEN, 0.08, dark)
		var knee: Node3D = _joint("knee_" + side, thigh, Vector3(0, -THIGH_LEN, 0))
		_limb(knee, SHIN_LEN, 0.065, dark)
		var boot := MeshInstance3D.new()
		var boot_mesh := BoxMesh.new()
		boot_mesh.size = Vector3(0.11, 0.08, 0.24)
		boot_mesh.material = dark
		boot.mesh = boot_mesh
		boot.position = Vector3(0, -SHIN_LEN - 0.02, -0.05)
		knee.add_child(boot)

	# 右手：鐘錘（握柄＋鐵錘頭）
	var hammer := Node3D.new()
	hammer.name = "BellHammer"
	hand("R").add_child(hammer)
	hammer.rotation = Vector3(-PI * 0.5, 0, 0)
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.02
	shaft_mesh.bottom_radius = 0.02
	shaft_mesh.height = 0.6
	shaft_mesh.material = trim
	shaft.mesh = shaft_mesh
	shaft.position = Vector3(0, 0.2, 0)
	hammer.add_child(shaft)
	var head_iron := MeshInstance3D.new()
	var iron_mesh := CylinderMesh.new()
	iron_mesh.top_radius = 0.06
	iron_mesh.bottom_radius = 0.075
	iron_mesh.height = 0.17
	iron_mesh.material = iron
	head_iron.mesh = iron_mesh
	head_iron.position = Vector3(0, 0.5, 0)
	head_iron.rotation = Vector3(0, 0, PI * 0.5)
	hammer.add_child(head_iron)
	_pose(0.0)
