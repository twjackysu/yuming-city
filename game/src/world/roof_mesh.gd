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
