class_name CameraFade
extends RefCounted
## 靠近鏡頭就淡掉：把一棵節點樹裡所有 StandardMaterial3D 設成依離鏡頭的距離抖動淡出
## （DISTANCE_FADE_PIXEL_DITHER：離鏡頭 near 以內看不到、到 far 才完全不透明）。
## 給會走到鏡頭和諾恩之間的東西用——例如車隊的推車與傷者：過肩鏡頭在諾恩身後約 3.5 m，
## 推車從後面追上來時整台擋在畫面下半（第三輪盤點第 9 項）。抖動是不透明的畫法，不會有半透明排序問題。
## 已經自己設好淡出的材質（例如提燈燈罩）不動。回傳這次設定的材質數（同一個材質只算一次）。
## ShaderMaterial 只有自己的 shader 宣告了 `fade_near`／`fade_far` 才會設定（例如送葬者的鐵架），其他不動。

## 角色（席菈、敵人）擋在鏡頭與諾恩之間時（SpringArm 不撞角色，鏡頭會在他們身體裡）：
## 離鏡頭 1 m 以內開始淡、0.4 m 以內看不到（第四輪盤點第 6 項）
const CHARACTER_NEAR: float = 0.4
const CHARACTER_FAR: float = 1.0


static func apply(root: Node, near: float, far: float) -> int:
	var seen: Dictionary = {}
	_walk(root, near, far, seen)
	return seen.size()


static func _walk(node: Node, near: float, far: float, seen: Dictionary) -> void:
	if node is CSGPrimitive3D:
		_fade(_csg_material(node as CSGPrimitive3D), near, far, seen)
	if node is GeometryInstance3D:
		_fade((node as GeometryInstance3D).material_override, near, far, seen)
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			if mi.mesh is PrimitiveMesh:
				_fade((mi.mesh as PrimitiveMesh).material, near, far, seen)
			for s: int in mi.mesh.get_surface_count():
				_fade(mi.mesh.surface_get_material(s), near, far, seen)
				_fade(mi.get_surface_override_material(s), near, far, seen)
	for child: Node in node.get_children():
		_walk(child, near, far, seen)


static func _csg_material(csg: CSGPrimitive3D) -> Material:
	var v: Variant = csg.get("material")
	return v as Material if v is Material else null


static func _fade(mat: Material, near: float, far: float, seen: Dictionary) -> void:
	if mat is ShaderMaterial:
		_fade_shader(mat as ShaderMaterial, near, far, seen)
		return
	var m := mat as BaseMaterial3D
	if m == null or seen.has(m):
		return
	if m.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED:
		return  # 自己有淡出設定的不動
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	m.distance_fade_min_distance = near
	m.distance_fade_max_distance = far
	seen[m] = true


static func _fade_shader(m: ShaderMaterial, near: float, far: float, seen: Dictionary) -> void:
	if seen.has(m) or m.shader == null:
		return
	var has_near: bool = false
	var has_far: bool = false
	for u: Dictionary in m.shader.get_shader_uniform_list():
		has_near = has_near or str(u.get("name", "")) == "fade_near"
		has_far = has_far or str(u.get("name", "")) == "fade_far"
	if not (has_near and has_far):
		return
	var current: Variant = m.get_shader_parameter("fade_far")
	if current != null and float(current) > 0.0:
		return  # 自己有淡出設定的不動
	m.set_shader_parameter("fade_near", near)
	m.set_shader_parameter("fade_far", far)
	seen[m] = true
