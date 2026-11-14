class_name PropModels
extends RefCounted
## 現成素材（CC0）的接入點（查證在 docs/design/12-ready-made-characters.md 第 6 節）。
## 角色模型是建置時產生、不進 git（CharacterModels）；小物與武器的檔案小（一個 20～150 KB），
## 直接放進 game/assets/props/<包名>/<名字>.gltf 進 git，建置不用連網路。
## 找得到就用現成的模型，檔案不在（被刪、沒匯入）就回傳 null，呼叫的地方退回程式拼的那一份。

const DIR: String = "res://assets/props"


static func path_for(name: String) -> String:
	return "%s/%s.gltf" % [DIR, name]


## 匯入過的模型場景；沒有回傳 null。name 例："kaykit/sword_2handed"
static func scene_for(name: String) -> PackedScene:
	if name == "":
		return null
	var p: String = path_for(name)
	if not ResourceLoader.exists(p):
		p = p.trim_suffix(".gltf") + ".glb"  # 建置時產生的（Tripo 的武器與物件：scripts/gen_props.sh）是單一個 .glb
		if not ResourceLoader.exists(p):
			return null
	return load(p) as PackedScene


## 照順序找第一個有的模型生出來（例：先找 Tripo 產的，沒有就用 KayKit 的）；都沒有回傳 null。
static func instance_first(names: Array[String]) -> Node3D:
	for n: String in names:
		var node: Node3D = instance(n)
		if node != null:
			return node
	return null


## 直接生一個實例；沒有這個模型回傳 null。
static func instance(name: String) -> Node3D:
	var scene: PackedScene = scene_for(name)
	if scene == null:
		return null
	return scene.instantiate() as Node3D
