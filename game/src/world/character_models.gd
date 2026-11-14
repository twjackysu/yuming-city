class_name CharacterModels
extends RefCounted
## 正式角色模型的接入點（04-architecture「角色模型接入點」）。
## Jacky 把 GLB 放進 art-inbox/characters/<id>/<id>.glb → scripts/import_characters.py 用
## scripts/check_character_glb.py 收件檢查，通過才複製到 game/assets/characters/<id>/<id>.glb（不進 git）。
## Puppet 依 character_id 找得到就用模型，找不到就用程序人偶；外部介面不變。

const DIR: String = "res://assets/characters"

## Puppet 狀態 → 動作表（art-inbox/README.md）名稱，依序找第一個存在的
## 循環動作也認 `_loop` 結尾（Jacky 的席菈試作把走路匯出成 walk_loop）
const ANIM_MAP: Dictionary = {
	"idle": ["idle", "idle_loop", "sword_idle"],
	"walk": ["walk", "walk_loop"],
	"run": ["run", "run_loop", "sprint"],
	"dodge": ["dodge_roll"],
	"attack": ["light_attack_01"],
	"release": ["release"],
	"shoot": ["shoot"],
}
## 會循環播放的動作
const LOOPING: PackedStringArray = ["idle", "walk", "run"]
## 掛點骨骼：小寫、去掉 Mixamo 前綴（Godot 匯入時 "mixamorig:" 會變成 "mixamorig_"）後比對（Mixamo、Blender Rigify／一般命名）
const HAND_BONES: Dictionary = {
	"L": ["lefthand", "hand_l", "hand.l", "l_hand"],
	"R": ["righthand", "hand_r", "hand.r", "r_hand"],
}


## 程序人偶的關節名 → 模型的骨頭（比對方式跟手一樣）。掛在人偶關節上的東西（護腕掛在 elbow_R…）用模型時改掛在這根骨頭上。
## 前面是 Godot 人形骨架的名字（VRM 轉來的、自製的都用這一套），後面是 Mixamo 的。
const JOINT_BONES: Dictionary = {
	"hips": ["hips"], "spine": ["spine"], "chest": ["chest", "upperchest", "spine1"], "neck": ["neck"], "head": ["head"],
	"shoulder_L": ["leftupperarm", "leftarm"], "shoulder_R": ["rightupperarm", "rightarm"],
	"elbow_L": ["leftlowerarm", "leftforearm"], "elbow_R": ["rightlowerarm", "rightforearm"],
	"thigh_L": ["leftupperleg", "leftupleg"], "thigh_R": ["rightupperleg", "rightupleg"],
	"knee_L": ["leftlowerleg", "leftleg"], "knee_R": ["rightlowerleg", "rightleg"],
	"foot_L": ["leftfoot"], "foot_R": ["rightfoot"],
}
## 手臂與腿的關節沿著哪兩個關節的連線擺（從第一個指向第二個；手＝前臂的延長）。沒寫的（骨盆、胸、頭）跟模型同方向。
const JOINT_AXIS: Dictionary = {
	"shoulder_L": ["shoulder_L", "elbow_L"], "shoulder_R": ["shoulder_R", "elbow_R"],
	"elbow_L": ["elbow_L", "hand_L"], "elbow_R": ["elbow_R", "hand_R"],
	"hand_L": ["elbow_L", "hand_L"], "hand_R": ["elbow_R", "hand_R"],
	"thigh_L": ["thigh_L", "knee_L"], "thigh_R": ["thigh_R", "knee_R"],
	"knee_L": ["knee_L", "foot_L"], "knee_R": ["knee_R", "foot_R"],
}


static func path_for(character_id: String) -> String:
	return "%s/%s/%s.glb" % [DIR, character_id, character_id]


## 匯入過的模型場景；沒有就回傳 null（用程序人偶）。
static func scene_for(character_id: String) -> PackedScene:
	if character_id == "":
		return null
	var p: String = path_for(character_id)
	if not ResourceLoader.exists(p):
		return null
	return load(p) as PackedScene


## AnimationPlayer 裡對應 Puppet 狀態的動作名稱；沒有回傳空字串。
## glTF 匯入可能帶前綴（"Armature|idle"、"library/idle"），比對結尾。
static func find_animation(anim: AnimationPlayer, state: String) -> String:
	if anim == null:
		return ""
	var names: PackedStringArray = anim.get_animation_list()
	for want: Variant in (ANIM_MAP.get(state, []) as Array):
		var w: String = str(want)
		for n: String in names:
			var low: String = n.to_lower()
			if low == w or low.ends_with("|" + w) or low.ends_with("/" + w):
				return n
	return ""


## 掛點骨骼索引；沒有回傳 -1。
## 模型的臉朝哪邊（模型根節點 root 的座標）：上（骨盆→頭）× 右（左肩→右肩）。Godot 的正面是 −Z，所以正常是 (0, 0, −1) 左右；
## glTF 的慣例是臉朝 +Z，別人做的模型常常是反的。posed＝用目前動作的姿勢，否則用休息姿勢。量不出來（缺骨頭）回傳 Vector3.ZERO。
static func facing(skeleton: Skeleton3D, root: Node3D, posed: bool = false) -> Vector3:
	if skeleton == null:
		return Vector3.ZERO
	var to_root := Transform3D.IDENTITY
	var n: Node3D = skeleton
	while n != null and n != root:
		to_root = n.transform * to_root
		n = n.get_parent() as Node3D
	var at: Array[Vector3] = []
	for j: String in ["hips", "head", "shoulder_L", "shoulder_R"]:
		var b: int = find_joint_bone(skeleton, j)
		if b < 0:
			return Vector3.ZERO
		var t: Transform3D = skeleton.get_bone_global_pose(b) if posed else skeleton.get_bone_global_rest(b)
		at.append(to_root * t.origin)
	var f: Vector3 = (at[1] - at[0]).cross(at[3] - at[2])
	return f.normalized() if f.length() > 0.0001 else Vector3.ZERO


static func find_hand_bone(skeleton: Skeleton3D, side: String) -> int:
	return _find_bone(skeleton, HAND_BONES.get(side, []) as Array)


## 人偶的關節名（"elbow_R"、"hand_L"、"hips"…）對應的骨頭索引；沒有回傳 -1。
static func find_joint_bone(skeleton: Skeleton3D, joint_name: String) -> int:
	if joint_name.begins_with("hand_"):
		return find_hand_bone(skeleton, joint_name.trim_prefix("hand_"))
	return _find_bone(skeleton, JOINT_BONES.get(joint_name, []) as Array)


static func _find_bone(skeleton: Skeleton3D, wanted: Array) -> int:
	if skeleton == null or wanted.is_empty():
		return -1
	for i: int in skeleton.get_bone_count():
		var b: String = skeleton.get_bone_name(i).to_lower().replace("mixamorig:", "").replace("mixamorig_", "")
		if wanted.has(b):
			return i
	return -1
