class_name RoofMesh
extends RefCounted
## 三角屋頂（D-107）：跟 PrismMesh 一樣的外形（底寬 X、高 Y、沿屋脊 Z、中心在原點、屋脊在 x=0），
## 但兩片斜面的 UV 是「公尺」：u＝沿著屋簷的距離、v＝從屋簷往屋脊沿著斜面的距離，
## 屋瓦 shader（roof_tiles.gdshader）照這個排一排排的瓦。兩端的山牆三角形 UV 是 (-1, -1)（shader 畫成素面）。
## 不畫底面（底下是屋簷的方塊）。平面法線（每個三角形自己的頂點），正面順時針（Godot 慣例）。


static func build(width: float, height: float, length: float) -> ArrayMesh:
	var hx: float = width * 0.5
	var hy: float = height * 0.5
	var hz: float = length * 0.5
	var slope: float = Vector2(hx, height).length()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx: float in [-1.0, 1.0]:
		# 斜面：屋簷 (sx*hx, -hy, z) → 屋脊 (0, hy, z)
		var e0 := Vector3(sx * hx, -hy, -hz)
		var e1 := Vector3(sx * hx, -hy, hz)
		var r0 := Vector3(0.0, hy, -hz)
		var r1 := Vector3(0.0, hy, hz)
		var quad: Array[Vector3] = [e0, e1, r1, r0]
		var uv: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(length, 0.0), Vector2(length, slope), Vector2(0.0, slope)]
		var order: Array[int] = [0, 1, 2, 0, 2, 3]
		if sx < 0.0:
			order = [0, 2, 1, 0, 3, 2]
		for i: int in order:
			st.set_uv(uv[i])
			st.add_vertex(quad[i])
	# 山牆三角形（z = ±hz）
	for sz: float in [-1.0, 1.0]:
		var a := Vector3(-hx, -hy, sz * hz)
		var b := Vector3(hx, -hy, sz * hz)
		var c := Vector3(0.0, hy, sz * hz)
		var tri: Array[Vector3] = [a, b, c]
		if sz > 0.0:
			tri = [a, c, b]
		for v: Vector3 in tri:
			st.set_uv(Vector2(-1.0, -1.0))
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


## 一片屋瓦板（第四輪盤點，D-110）：陷落的破屋頂（D-091）一片片斷開的屋面原本是素面方塊，
## 跟有瓦的完整屋頂（D-107）不一致。外形跟 BoxMesh 一樣（中心在原點、X＝沿斜面長、Y＝厚、Z＝沿屋簷寬），
## 只有頂面（+Y）的 UV 是公尺：u＝沿屋簷（z + 寬/2）、v＝從屋簷（-X 那端）沿斜面往上（x + 長/2），
## roof_tiles.gdshader 照樣排瓦；其他五面 UV (-1, -1)（素面，斷口與底面）。平面法線、正面朝外。
static func slab(length: float, thick: float, width: float) -> ArrayMesh:
	var h := Vector3(length, thick, width) * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis: int in 3:
		for sgn: float in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[axis] = sgn
			# 面上的兩個方向（跟法線垂直的另外兩軸）
			var a1: int = (axis + 1) % 3
			var a2: int = (axis + 2) % 3
			var e1 := Vector3.ZERO
			e1[a1] = h[a1]
			var e2 := Vector3.ZERO
			e2[a2] = h[a2]
			var c: Vector3 = n * h[axis]
			var quad: Array[Vector3] = [c - e1 - e2, c + e1 - e2, c + e1 + e2, c - e1 + e2]
			var order: Array[int] = [0, 1, 2, 0, 2, 3]
			# Godot 正面是順時針：Plane(a, b, c) 的法線要朝外，反了就倒過來
			if Plane(quad[0], quad[1], quad[2]).normal.dot(n) < 0.0:
				order = [0, 2, 1, 0, 3, 2]
			for i: int in order:
				var p: Vector3 = quad[i]
				st.set_normal(n)
				if axis == 1 and sgn > 0.0:
					st.set_uv(Vector2(p.z + h.z, p.x + h.x))
				else:
					st.set_uv(Vector2(-1.0, -1.0))
				st.add_vertex(p)
	return st.commit()
