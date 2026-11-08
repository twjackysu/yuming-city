class_name Lathe
extends RefCounted
## 車床旋轉體：把一條剖面線（x＝半徑、y＝高度）繞 Y 軸轉一圈，做成 ArrayMesh（D-081，鐘）。
## 剖面線的走向決定哪一面朝外：法線取剖面切線往「右手邊」轉 90°（n = (-dy, dr)）——
## 從上往下描外側、從下往上描內側，法線就分別朝外與朝鐘口裡面。一條剖面線裡的頂點法線是
## 相鄰兩段的平均（平滑）；要硬邊（鐘唇的轉角）就分成好幾條剖面線，各呼叫一次 add_profile。
## Godot 的正面是順時針（從法線那一側看），三角形照這個方向排。


var _st: SurfaceTool
var segments: int


func _init(radial_segments: int = 32) -> void:
	segments = maxi(radial_segments, 3)
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


## 剖面線上每一點 Vector2(半徑, 高度)，至少兩點。
func add_profile(points: PackedVector2Array) -> void:
	var n: int = points.size()
	if n < 2:
		return
	var seg_normals: Array[Vector2] = []
	for i: int in n - 1:
		var d: Vector2 = points[i + 1] - points[i]
		seg_normals.append(Vector2(-d.y, d.x).normalized())
	var normals: Array[Vector2] = []
	for i: int in n:
		var acc := Vector2.ZERO
		if i > 0:
			acc += seg_normals[i - 1]
		if i < n - 1:
			acc += seg_normals[i]
		normals.append(acc.normalized())
	for i: int in n - 1:
		for j: int in segments:
			var t0: float = TAU * float(j) / float(segments)
			var t1: float = TAU * float(j + 1) / float(segments)
			var a: Vector3 = _point(points[i], t0)
			var b: Vector3 = _point(points[i], t1)
			var c: Vector3 = _point(points[i + 1], t0)
			var d3: Vector3 = _point(points[i + 1], t1)
			var na: Vector3 = _normal(normals[i], t0)
			var nb: Vector3 = _normal(normals[i], t1)
			var nc: Vector3 = _normal(normals[i + 1], t0)
			var nd: Vector3 = _normal(normals[i + 1], t1)
			_vertex(a, na)
			_vertex(b, nb)
			_vertex(d3, nd)
			_vertex(a, na)
			_vertex(d3, nd)
			_vertex(c, nc)


func commit() -> ArrayMesh:
	return _st.commit()


func _vertex(p: Vector3, n: Vector3) -> void:
	_st.set_normal(n)
	_st.add_vertex(p)


static func _point(p: Vector2, theta: float) -> Vector3:
	return Vector3(p.x * sin(theta), p.y, p.x * cos(theta))


static func _normal(n: Vector2, theta: float) -> Vector3:
	return Vector3(n.x * sin(theta), n.y, n.x * cos(theta)).normalized()


## 鐘的剖面（鐘頂在 y＝0，鐘口在 y＝-height）：肩、細腰、往外翻的鐘口與一圈厚唇，內側中空。
## 回傳三條剖面線：外側（硬邊在鐘唇）、唇底、內側。
static func bell_profiles(height: float, mouth_radius: float) -> Array[PackedVector2Array]:
	var h: float = height
	var r: float = mouth_radius
	var outer := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(0.30 * r, -0.005 * h),
		Vector2(0.43 * r, -0.04 * h),
		Vector2(0.50 * r, -0.12 * h),
		Vector2(0.53 * r, -0.26 * h),
		Vector2(0.56 * r, -0.44 * h),
		Vector2(0.62 * r, -0.62 * h),
		Vector2(0.72 * r, -0.78 * h),
		Vector2(0.86 * r, -0.91 * h),
		Vector2(0.97 * r, -0.97 * h),
		Vector2(1.0 * r, -1.0 * h),
	])
	var lip := PackedVector2Array([
		Vector2(1.0 * r, -1.0 * h),
		Vector2(0.90 * r, -1.0 * h),
	])
	var inner := PackedVector2Array([
		Vector2(0.90 * r, -1.0 * h),
		Vector2(0.80 * r, -0.92 * h),
		Vector2(0.62 * r, -0.76 * h),
		Vector2(0.50 * r, -0.50 * h),
		Vector2(0.44 * r, -0.20 * h),
		Vector2(0.30 * r, -0.08 * h),
		Vector2(0.0, -0.07 * h),
	])
	var out: Array[PackedVector2Array] = [outer, lip, inner]
	return out


static func bell_mesh(height: float, mouth_radius: float, radial_segments: int = 40) -> ArrayMesh:
	var lathe := Lathe.new(radial_segments)
	for p: PackedVector2Array in bell_profiles(height, mouth_radius):
		lathe.add_profile(p)
	return lathe.commit()
