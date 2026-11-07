class_name CharacterModels
extends RefCounted
## 正式角色模型的接入點（04-architecture「角色模型接入點」）。
## Jacky 把 GLB 放進 art-inbox/characters/<id>/<id>.glb → scripts/import_characters.py 用
## scripts/check_character_glb.py 收件檢查，通過才複製到 game/assets/characters/<id>/<id>.glb（不進 git）。
## Puppet 依 character_id 找得到就用模型，找不到就用程序人偶；外部介面不變。

const DIR: String = "res://assets/characters"

## Puppet 狀態 → 動作表（art-inbox/README.md）名稱，依序找第一個存在的
const ANIM_MAP: Dictionary = {
	"idle": ["idle", "sword_idle"],
	"walk": ["walk"],
	"run": ["run", "sprint"],
	"dodge": ["dodge_roll"],
	"attack": ["light_attack_01"],
}
## 會循環播放的動作
const LOOPING: PackedStringArray = ["idle", "walk", "run"]
## 掛點骨骼：小寫、去掉 Mixamo 前綴（Godot 匯入時 "mixamorig:" 會變成 "mixamorig_"）後比對（Mixamo、Blender Rigify／一般命名）
const HAND_BONES: Dictionary = {
	"L": ["lefthand", "hand_l", "hand.l", "l_hand"],
	"R": ["righthand", "hand_r", "hand.r", "r_hand"],
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
static func find_hand_bone(skeleton: Skeleton3D, side: String) -> int:
	if skeleton == null:
		return -1
	for i: int in skeleton.get_bone_count():
		var b: String = skeleton.get_bone_name(i).to_lower().replace("mixamorig:", "").replace("mixamorig_", "")
		if (HAND_BONES.get(side, []) as Array).has(b):
			return i
	return -1
