class_name ChainMesh
extends RefCounted
## 程序鐵鏈（D-199）：一節節橢圓鏈環，相鄰兩節繞 Y 轉 90° 互相套住；從 y=0（掛鉤）往 -Y 垂下去。
## 取代之前的素色細圓柱（遠看是一根棍子，看不出是鏈子）。法線照圓管算（光滑），鏈環轉折處在燈下各自亮一點。

## 鏈環中心線一圈幾段（4 的倍數：上下兩端剛好有頂點）、管子一圈幾段（一節 2×12×6＝144 個三角形）
const RING_SEGMENTS: int = 12
const TUBE_SEGMENTS: int = 6


## 相鄰兩節的中心距：下一節的上緣套在這一節的內側下緣＝外長減兩倍線徑
static func pitch(link_len: float, wire_r: float) -> float:
	return link_len - 2.0 * wire_r


## 垂下 length 公尺要幾節（最後一節的下緣剛好到或超過 length）
static func link_count(length: float, link_len: float, wire_r: float) -> int:
	if length <= link_len:
		return 1
	return int(ceil((length - link_len) / pitch(link_len, wire_r))) + 1


## length＝從掛鉤往下多長；link_len／link_w＝一節的外長／外寬；wire_r＝鐵條半徑
static func build(length: float, link_len: float, link_w: float, wire_r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p: float = pitch(link_len, wire_r)
	var a: float = link_len * 0.5 - wire_r
	var b: float = maxf(link_w * 0.5 - wire_r, wire_r * 0.5)
	for k: int in link_count(length, link_len, wire_r):
		var center := Vector3(0.0, -link_len * 0.5 - float(k) * p, 0.0)
		var twist := Basis(Vector3.UP, PI * 0.5 if k % 2 == 1 else 0.0)
		_link(st, center, a, b, wire_r, twist)
	return st.commit()


## 一節：中心線是 XY 平面上的橢圓（半長 a 沿 Y、半寬 b 沿 X），外面包一圈半徑 r 的管子
static func _link(st: SurfaceTool, center: Vector3, a: float, b: float, r: float, twist: Basis) -> void:
	var rows: Array[PackedVector3Array] = []
	var norms: Array[PackedVector3Array] = []
	for i: int in RING_SEGMENTS + 1:
		var t: float = TAU * float(i % RING_SEGMENTS) / float(RING_SEGMENTS)
		var c := Vector3(b * cos(t), a * sin(t), 0.0)
		var n_in := Vector3(a * cos(t), b * sin(t), 0.0).normalized()
		var pts := PackedVector3Array()
		var ns := PackedVector3Array()
		for j: int in TUBE_SEGMENTS + 1:
			var s: float = TAU * float(j % TUBE_SEGMENTS) / float(TUBE_SEGMENTS)
			var n: Vector3 = n_in * cos(s) + Vector3.BACK * sin(s)
			pts.append(center + twist * (c + n * r))
			ns.append(twist * n)
		rows.append(pts)
		norms.append(ns)
	for i: int in RING_SEGMENTS:
		for j: int in TUBE_SEGMENTS:
			_tri(st, rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], norms[i][j], norms[i + 1][j], norms[i + 1][j + 1])
			_tri(st, rows[i][j], rows[i + 1][j + 1], rows[i][j + 1], norms[i][j], norms[i + 1][j + 1], norms[i][j + 1])


## 照法線決定繞的方向：Godot 正面順時針＝(c - a) × (b - a) 朝外
static func _tri(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, n0: Vector3, n1: Vector3, n2: Vector3) -> void:
	if (p2 - p0).cross(p1 - p0).dot(n0 + n1 + n2) < 0.0:
		var tp: Vector3 = p1
		p1 = p2
		p2 = tp
		var tn: Vector3 = n1
		n1 = n2
		n2 = tn
	st.set_normal(n0)
	st.add_vertex(p0)
	st.set_normal(n1)
	st.add_vertex(p1)
	st.set_normal(n2)
	st.add_vertex(p2)
