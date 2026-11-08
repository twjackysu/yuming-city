class_name ParticleLook
extends RefCounted
## 粒子共用的外觀（D-056）：所有 CPUParticles3D 的面片都要有圓形貼圖。
## 沒有貼圖的 QuadMesh 粒子是硬邊方塊，一眼就看得出是方形面片（第 13 輪在倒地粉塵發現）。
## - soft_dot()：中心白、往外慢慢透明——雪粉、灰粉、石粉、化灰的灰燼。
## - hot_dot()：中心一小塊全亮、邊緣很快淡掉——火星；搭配加法混色，疊在一起會更亮（有 glow 時會發光）。
## 貼圖只建一次、大家共用（32×32，很小）。

static var _soft: GradientTexture2D
static var _hot: GradientTexture2D


static func soft_dot() -> GradientTexture2D:
	if _soft == null:
		_soft = _radial([[0.0, 1.0], [0.45, 0.55], [1.0, 0.0]])
	return _soft


static func hot_dot() -> GradientTexture2D:
	if _hot == null:
		_hot = _radial([[0.0, 1.0], [0.3, 0.9], [0.65, 0.25], [1.0, 0.0]])
	return _hot


## 粒子面片的材質：不受光、面向鏡頭、帶 alpha、吃粒子的顏色漸層。
## additive：加法混色（火星、冷光）；否則是一般透明（粉塵、灰燼）。
static func material(color: Color, additive: bool = false,
		billboard: BaseMaterial3D.BillboardMode = BaseMaterial3D.BILLBOARD_ENABLED) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = billboard
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color
	mat.albedo_texture = hot_dot() if additive else soft_dot()
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return mat


## 整理一棵樹底下所有 CPUParticles3D 面片的材質（測試用：確認沒有硬邊方塊）。
static func untextured(root: Node) -> Array[String]:
	var bad: Array[String] = []
	_collect_untextured(root, bad)
	return bad


static func _collect_untextured(n: Node, bad: Array[String]) -> void:
	if n is CPUParticles3D:
		var ps := n as CPUParticles3D
		var mat: StandardMaterial3D = null
		if ps.mesh != null:
			mat = ps.mesh.surface_get_material(0) as StandardMaterial3D
		if mat == null or mat.albedo_texture == null:
			bad.append(String(ps.name))
	for c: Node in n.get_children():
		_collect_untextured(c, bad)


static func _radial(stops: Array) -> GradientTexture2D:
	var g := Gradient.new()
	# Gradient 預設有 0 和 1 兩個點：先改這兩個，中間的再加
	var first: Array = stops[0]
	var last: Array = stops[stops.size() - 1]
	g.set_offset(0, float(first[0]))
	g.set_color(0, Color(1, 1, 1, float(first[1])))
	g.set_offset(1, float(last[0]))
	g.set_color(1, Color(1, 1, 1, float(last[1])))
	for i: int in range(1, stops.size() - 1):
		var s: Array = stops[i]
		g.add_point(float(s[0]), Color(1, 1, 1, float(s[1])))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t
