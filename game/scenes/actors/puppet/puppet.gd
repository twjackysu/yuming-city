class_name Puppet
extends Node3D
## 程序人偶：在正式角色模型（docs/ART_REQUESTS.md 第 1、2 項）到位前頂替，用程式動畫。
## 關節是 Node3D 樞紐（不是 Skeleton3D），膠囊肢體掛在樞紐上；角色面向 -Z。
##
## 對外介面固定，之後換成有骨架的模型＋AnimationTree 時，外部（PlayerController 等）不用改：
##   set_move_speed(m/s)、play_action("dodge"|"attack")、current_state() ∈ STATES、hand("L"|"R")
## STATES 也就是將來 AnimationTree 狀態機的狀態名。
##
## 正式模型：設 character_id（"noen"、"sheila"…），CharacterModels 找得到匯入過的 GLB 就用模型＋AnimationPlayer，
## 找不到（或模型沒有骨架）就用程序人偶。模型缺的動作：閃避退回整個人前滾、其他退回 idle。
## 碰撞、AI、弱點判定都不跟模型走（04-architecture「角色模型接入點」）。

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

## 正式模型 id（CharacterModels.path_for）；空字串＝程序人偶
@export var character_id: String = ""
## 直接指定模型場景（測試、工具）；優先於 character_id
var model_scene: PackedScene = null
## 用模型時：模型根節點、動畫播放器、骨架；用程序人偶時都是 null
var model: Node3D = null
var anim: AnimationPlayer = null
var skeleton: Skeleton3D = null
## 模型目前播的動作（測試用）
var model_animation: String = ""

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
	if model_scene == null:
		model_scene = CharacterModels.scene_for(character_id)
	if model_scene != null and _build_model():
		return
	_build()


func uses_model() -> bool:
	return model != null


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


## 右前臂的木板夾傷（原作：鐘樓上敲斷了手，席菈幫他上夾板）。只在程序人偶上畫；正式模型的夾板由模型負責。
func set_splint(on: bool) -> void:
	var elbow: Node3D = joint("elbow_R")
	if elbow == null:
		return
	var old: Node = elbow.get_node_or_null("Splint")
	if not on:
		if old != null:
			old.queue_free()
		return
	if old != null:
		return
	var splint := Node3D.new()
	splint.name = "Splint"
	elbow.add_child(splint)
	var wood: StandardMaterial3D = _mat(Color(0.42, 0.32, 0.21), 0.8)
	var cloth: StandardMaterial3D = _mat(Color(0.7, 0.66, 0.58), 0.95)
	for x: float in [-1.0, 1.0]:
		var slat := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.025, FOREARM_LEN * 0.95, 0.05)
		bm.material = wood
		slat.mesh = bm
		slat.position = Vector3(x * 0.068, -FOREARM_LEN * 0.5, 0)
		splint.add_child(slat)
	for y: float in [0.3, 0.7]:
		var wrap := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.085
		cm.bottom_radius = 0.085
		cm.height = 0.035
		cm.radial_segments = 10
		cm.material = cloth
		wrap.mesh = cm
		wrap.position = Vector3(0, -FOREARM_LEN * y, 0)
		splint.add_child(wrap)


func has_splint() -> bool:
	var elbow: Node3D = joint("elbow_R")
	return elbow != null and elbow.has_node("Splint")


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
	if model != null:
		_animate_model()
		return
	_pose(speed_t)


## 模型：依狀態換動作；缺的動作退回（閃避＝整個人前滾，其他＝idle）。
func _animate_model() -> void:
	var state: String = current_state()
	var name_found: String = CharacterModels.find_animation(anim, state)
	_roll.rotation.x = 0.0
	_roll.position = Vector3.ZERO
	if name_found == "" and state == "dodge":
		var t: float = clampf(action_time / float(ACTION_TIME["dodge"]), 0.0, 1.0)
		_roll.position = Vector3(0, 0.5 - 0.35 * sin(t * PI), 0)
		_roll.rotation.x = -TAU * ease(t, -1.8)
	if name_found == "":
		name_found = CharacterModels.find_animation(anim, "idle")
	if name_found == "":
		return
	if model_animation != name_found:
		model_animation = name_found
		anim.play(name_found, 0.15)
	# 步頻跟速度走（動作表的走路約 1.6 m/s、跑步約 RUN_SPEED）
	match state:
		"walk":
			anim.speed_scale = clampf(move_speed / 1.6, 0.6, 1.6)
		"run":
			anim.speed_scale = clampf(move_speed / RUN_SPEED, 0.7, 1.4)
		_:
			anim.speed_scale = 1.0


## 換成正式模型；沒有骨架就放棄（回傳 false，用程序人偶）。
func _build_model() -> bool:
	var inst: Node3D = model_scene.instantiate() as Node3D
	if inst == null:
		return false
	var skels: Array[Node] = inst.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		push_warning("Puppet: 模型 %s 沒有骨架，改用程序人偶" % character_id)
		inst.free()
		return false
	_roll = Node3D.new()
	_roll.name = "Roll"
	add_child(_roll)
	model = inst
	model.name = "Model"
	_roll.add_child(model)
	skeleton = skels[0] as Skeleton3D
	var players: Array[Node] = inst.find_children("*", "AnimationPlayer", true, false)
	anim = players[0] as AnimationPlayer if not players.is_empty() else null
	if anim != null:
		for st: String in CharacterModels.LOOPING:
			var n: String = CharacterModels.find_animation(anim, st)
			if n != "":
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	# 掛點：手骨骼上的 BoneAttachment3D；找不到骨骼就放在大約的位置
	for side: String in ["L", "R"]:
		var bone: int = CharacterModels.find_hand_bone(skeleton, side)
		var holder: Node3D
		if bone >= 0:
			var att := BoneAttachment3D.new()
			att.bone_name = skeleton.get_bone_name(bone)
			skeleton.add_child(att)
			holder = att
		else:
			push_warning("Puppet: 模型 %s 找不到 %s 手骨骼，掛點用估計位置" % [character_id, side])
			holder = Node3D.new()
			holder.position = Vector3(-0.3 if side == "L" else 0.3, 0.95, 0.0)
			model.add_child(holder)
		holder.name = "Hand" + side
		joints["hand_" + side] = holder
	_add_hammer()
	_animate_model()
	return true


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

	_add_hammer()
	_pose(0.0)


## 右手：鐘錘（握柄＋鐵錘頭）。正式模型也掛在右手掛點（武器之後換成模型）。
func _add_hammer() -> void:
	var trim: StandardMaterial3D = _mat(trim_color)
	var iron: StandardMaterial3D = _mat(Color(0.32, 0.3, 0.28), 0.45)
	iron.metallic = 0.7
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
