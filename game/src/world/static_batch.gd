class_name StaticBatch
extends RefCounted
## 靜態場景合併：程式生成的方塊／圓柱先收集起來，最後「每種材質一個 MeshInstance3D」＋
## 「一個 StaticBody3D（多個碰撞形狀）」。沙盒用一個方塊一個 CSG，draw call 約 236；
## 霜橋鎮改用這個（docs/design/04-architecture.md「關卡」）。

## 材質 instance id -> {"mat": Material, "st": SurfaceTool}
var _surfaces: Dictionary = {}
## 收集順序固定（截圖前後可對照、測試穩定）
var _order: Array[int] = []
## [Transform3D, Shape3D]
var _shapes: Array[Array] = []
var mesh_count: int = 0


## 方塊：size 公尺、xform 是方塊中心。collide=true 時加一個同大小的碰撞盒。
func add_box(size: Vector3, xform: Transform3D, mat: Material, collide: bool = true) -> void:
	var m := BoxMesh.new()
	m.size = size
	add_mesh(m, xform, mat)
	if collide:
		var s := BoxShape3D.new()
		s.size = size
		_shapes.append([xform, s])


func add_box_at(size: Vector3, pos: Vector3, mat: Material, collide: bool = true) -> void:
	add_box(size, Transform3D(Basis.IDENTITY, pos), mat, collide)


## 帶頂點色的方塊：每個方塊的資料放在頂點色，shader 用 COLOR 讀（例如窗，D-066）。
## 同一個材質的方塊要全部用這個方法加（合併後的頂點格式才一致）。collide=true 時加碰撞盒（木箱、攤桌）。
func add_box_tinted(size: Vector3, pos: Vector3, mat: Material, tint: Color, collide: bool = false) -> void:
	var box := BoxMesh.new()
	box.size = size
	var arrays: Array = box.get_mesh_arrays()
	var colors := PackedColorArray()
	colors.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	colors.fill(tint)
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	add_mesh(mesh, Transform3D(Basis.IDENTITY, pos), mat)
	if collide:
		var shape := BoxShape3D.new()
		shape.size = size
		_shapes.append([Transform3D(Basis.IDENTITY, pos), shape])


## 圓柱（top_radius=0 是圓錐）；碰撞用圓柱形狀（取較大半徑）。
func add_cylinder(top_radius: float, bottom_radius: float, height: float, pos: Vector3, mat: Material,
		collide: bool = true, segments: int = 16) -> void:
	var m := CylinderMesh.new()
	m.top_radius = top_radius
	m.bottom_radius = bottom_radius
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	var xf := Transform3D(Basis.IDENTITY, pos)
	add_mesh(m, xf, mat)
	if collide:
		var s := CylinderShape3D.new()
		s.radius = maxf(top_radius, bottom_radius)
		s.height = height
		_shapes.append([xf, s])


func add_sphere(radius: float, pos: Vector3, mat: Material) -> void:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 12
	m.rings = 6
	add_mesh(m, Transform3D(Basis.IDENTITY, pos), mat)


## 任意 PrimitiveMesh／ArrayMesh（第 0 個 surface）。
func add_mesh(mesh: Mesh, xform: Transform3D, mat: Material) -> void:
	var key: int = mat.get_instance_id()
	if not _surfaces.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[key] = {"mat": mat, "st": st}
		_order.append(key)
	var entry: Dictionary = _surfaces[key]
	(entry["st"] as SurfaceTool).append_from(mesh, 0, xform)
	mesh_count += 1


func material_count() -> int:
	return _order.size()


func shape_count() -> int:
	return _shapes.size()


## 產生節點並加到 parent 底下；回傳容器節點（名字 base_name）。之後這個 batch 不能再用。
func build(parent: Node3D, base_name: String, cast_shadows: bool = true) -> Node3D:
	var root := Node3D.new()
	root.name = base_name
	parent.add_child(root)
	var i: int = 0
	for key: int in _order:
		var entry: Dictionary = _surfaces[key]
		var st: SurfaceTool = entry["st"]
		var mi := MeshInstance3D.new()
		mi.name = "Mesh%d" % i
		mi.mesh = st.commit()
		mi.material_override = entry["mat"] as Material
		if not cast_shadows:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		i += 1
	if not _shapes.is_empty():
		var body := StaticBody3D.new()
		body.name = "Collision"
		root.add_child(body)
		for pair: Array in _shapes:
			var cs := CollisionShape3D.new()
			cs.transform = pair[0] as Transform3D
			cs.shape = pair[1] as Shape3D
			body.add_child(cs)
	_surfaces.clear()
	_order.clear()
	_shapes.clear()
	return root
