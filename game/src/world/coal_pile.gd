class_name CoalPile
extends RefCounted
## 倒下來的一堆煤（D-195）：取代乾運河閘道裡的黑色球體＋九個方塊（第 55 輪的「還可以」）。
## 原本是一顆壓扁的光滑球：暖燈照上去是一整片灰色的殼，看不出是一顆顆的煤。
## 模型座標：X＝長、Z＝寬、Y＝往上；底在 y=0（外圈稍微低於 0，貼進河床）。
## 堆本身：極座標網格（中心＋RINGS 圈 × SEGMENTS 段），高度是倒出來的錐形（頂上圓、往外越來越陡）＋塊狀起伏，
## 頂點在平面上也錯開一點（不是整齊的放射網格）；每個三角形各自的法線（平面著色）＝一塊塊煤的切面各自反光。
## 另外 LUMPS 顆小煤塊（不規則八面體）一部分躺在堆上、一部分滾到外圈的河床上，合在同一個 mesh。
## 頂點色：煤黑，外圈與凹處夾一點灰褐的煤粉；材質要開 vertex_color_use_as_albedo＋vertex_color_is_srgb（用 material()）。
## 正面順時針（Godot 慣例）；不規則度由 seed 決定（位置雜湊，不動關卡的 _rng）。

## 一圈約 13 cm、一段約 20 cm：切面跟一塊煤差不多大（太粗會變成一張揉皺的紙）
const RINGS: int = 10
const SEGMENTS: int = 40
## 輪廓往內凹的最大比例
const RAGGED: float = 0.2
## 表面塊狀起伏（公尺，最大）
const LUMP_AMP: float = 0.06
## 頂點在平面上錯開多少（以一段／一圈的間距為 1）
const JITTER: float = 0.32
## 錐形的次方：1＝直的錐、越大頂越圓、邊越陡
const PROFILE: float = 1.6
## 散落的小煤塊：幾顆、大小範圍（公尺，半徑）、幾顆滾到堆外
const LUMPS: int = 26
const LUMP_SIZE: Vector2 = Vector2(0.07, 0.16)
const LUMPS_OUTSIDE: int = 9
## 煤黑與煤粉的顏色（線性前的 sRGB，跟 canal.gd 的 COAL 同一個黑）
const COAL_COLOR: Color = Color(0.09, 0.085, 0.085)
const DUST_COLOR: Color = Color(0.2, 0.18, 0.16)
## 材質：低粗糙度、高鏡面——切面在燈下一點一點亮，不是整片灰
const ROUGHNESS: float = 0.3
const SPECULAR: float = 0.75


static func build(length: float, width: float, height: float, seed: float) -> ArrayMesh:
	var a: float = length * 0.5
	var b: float = width * 0.5
	var edge := PackedFloat32Array()
	edge.resize(SEGMENTS)
	var ph1: float = _hash(seed, 80.0) * TAU
	var ph2: float = _hash(seed, 81.0) * TAU
	for i: int in SEGMENTS:
		var th: float = TAU * float(i) / float(SEGMENTS)
		var wave: float = 0.55 * sin(2.0 * th + ph1) + 0.3 * sin(5.0 * th + ph2) + 0.15 * (_hash(seed, float(i)) * 2.0 - 1.0)
		edge[i] = 1.0 - RAGGED * clampf(0.5 + 0.5 * wave, 0.0, 1.0)
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var peak := Vector2((_hash(seed, 40.0) - 0.5) * 0.25, (_hash(seed, 41.0) - 0.5) * 0.25)
	verts.append(Vector3(peak.x * a, height, peak.y * b))
	colors.append(COAL_COLOR)
	for r: int in range(1, RINGS + 1):
		for i: int in SEGMENTS:
			var n: float = float(r * SEGMENTS + i)
			var outer: bool = r == RINGS
			# 平面上錯開：角度 ±JITTER 段、半徑 ±JITTER 圈（最外圈只錯開角度，輪廓才不會鋸齒）
			var dth: float = (_hash(seed, 200.0 + n) - 0.5) * 2.0 * JITTER * TAU / float(SEGMENTS)
			var dk: float = 0.0 if outer else (_hash(seed, 300.0 + n) - 0.5) * 2.0 * JITTER / float(RINGS)
			var k: float = clampf(float(r) / float(RINGS) + dk, 0.02, 1.0)
			var th: float = TAU * float(i) / float(SEGMENTS) + dth
			var rr: float = lerpf(1.0, edge[i], k)
			var x: float = lerpf(peak.x, cos(th) * rr, k) * a
			var z: float = lerpf(peak.y, sin(th) * rr, k) * b
			var hgt: float = profile(k) * height
			var bump: float = 0.0
			if outer:
				hgt = -0.015
			else:
				# 塊狀起伏：中段最明顯（頂上與邊緣小），凹下去的地方夾煤粉
				bump = (_hash(seed, 400.0 + n) * 2.0 - 1.0) * LUMP_AMP * sin(PI * clampf(k * 1.15, 0.0, 1.0))
				hgt = maxf(hgt + bump, 0.01)
			verts.append(Vector3(x, hgt, z))
			var dust: float = clampf((k - 0.72) / 0.28, 0.0, 1.0) * 0.8 + clampf(-bump / LUMP_AMP, 0.0, 1.0) * 0.35
			colors.append(COAL_COLOR.lerp(DUST_COLOR, clampf(dust, 0.0, 1.0)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i: int in SEGMENTS:
		_tri_up(st, verts, colors, 0, 1 + i, 1 + (i + 1) % SEGMENTS)
	for r: int in range(1, RINGS):
		var inner: int = 1 + (r - 1) * SEGMENTS
		var outer_i: int = 1 + r * SEGMENTS
		for i: int in SEGMENTS:
			var j: int = (i + 1) % SEGMENTS
			_tri_up(st, verts, colors, inner + i, outer_i + i, outer_i + j)
			_tri_up(st, verts, colors, inner + i, outer_i + j, inner + j)
	for l: int in LUMPS:
		var outside: bool = l < LUMPS_OUTSIDE
		var th: float = _hash(seed, 500.0 + l) * TAU
		var k: float = lerpf(1.0, 1.25, _hash(seed, 520.0 + l)) if outside else lerpf(0.25, 0.85, _hash(seed, 520.0 + l))
		var x: float = cos(th) * k * a
		var z: float = sin(th) * k * b
		var size: float = lerpf(LUMP_SIZE.x, LUMP_SIZE.y, _hash(seed, 540.0 + l))
		if outside:
			size *= 0.75
		var y: float = size * 0.35 if outside else profile(k) * height + size * 0.2
		_lump(st, Vector3(x, y, z), size, seed + 17.0 * float(l + 1))
	st.generate_normals()
	return st.commit()


## 錐形的高度（0＝最高點、1＝外圈；回傳 0～1）
static func profile(k: float) -> float:
	return 1.0 - pow(clampf(k, 0.0, 1.0), PROFILE)


## 一顆煤塊（不規則八面體，半徑約 size）：煤車上、落下途中那一團也用（D-195）
static func lump_mesh(size: float, seed: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	_lump(st, Vector3.ZERO, size, seed)
	st.generate_normals()
	return st.commit()


## 煤的材質：頂點色當底色（煤黑＋煤粉）、低粗糙度、高鏡面
static func material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	# 頂點色是 sRGB（跟 albedo_color 一樣）：不設的話 0.09 會被當成線性值，煤變成淺灰
	m.vertex_color_is_srgb = true
	m.albedo_color = Color.WHITE
	m.roughness = ROUGHNESS
	m.metallic_specular = SPECULAR
	return m


static func _lump(st: SurfaceTool, center: Vector3, size: float, seed: float) -> void:
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	var basis := Basis.from_euler(Vector3(_hash(seed, 1.0), _hash(seed, 2.0), _hash(seed, 3.0)) * TAU)
	var pts := PackedVector3Array()
	for i: int in axes.size():
		# 每個角拉長或縮短（0.65～1.25）、上下壓扁一點：不是正八面體
		var stretch: float = lerpf(0.65, 1.25, _hash(seed, 10.0 + i))
		var p: Vector3 = axes[i] * size * stretch
		p.y *= 0.75
		pts.append(center + basis * p)
	var col: Color = COAL_COLOR.lerp(DUST_COLOR, 0.15 * _hash(seed, 30.0))
	# 八個面：(+X/-X) × (+Y/-Y) × (+Z/-Z)
	for xi: int in [0, 1]:
		for yi: int in [2, 3]:
			for zi: int in [4, 5]:
				var p0: Vector3 = pts[xi]
				var p1: Vector3 = pts[yi]
				var p2: Vector3 = pts[zi]
				var centroid: Vector3 = (p0 + p1 + p2) / 3.0
				_tri(st, p0, p1, p2, col, col, col, centroid - center)


## 堆的三角形：朝上（高度場，正面一律朝 +Y）
static func _tri_up(st: SurfaceTool, verts: PackedVector3Array, colors: PackedColorArray, i0: int, i1: int, i2: int) -> void:
	_tri(st, verts[i0], verts[i1], verts[i2], colors[i0], colors[i1], colors[i2], Vector3.UP)


## 照 outward 決定繞的方向：Godot 正面順時針＝(c - a) × (b - a) 朝外
static func _tri(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, c0: Color, c1: Color, c2: Color, outward: Vector3) -> void:
	if (p2 - p0).cross(p1 - p0).dot(outward) < 0.0:
		var tp: Vector3 = p1
		p1 = p2
		p2 = tp
		var tc: Color = c1
		c1 = c2
		c2 = tc
	st.set_color(c0)
	st.add_vertex(p0)
	st.set_color(c1)
	st.add_vertex(p1)
	st.set_color(c2)
	st.add_vertex(p2)


static func _hash(seed: float, n: float) -> float:
	return fposmod(sin(seed * 12.9898 + n * 78.233) * 43758.5453, 1.0)
