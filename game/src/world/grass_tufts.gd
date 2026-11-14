class_name GrassTufts
extends RefCounted
## 一整片草叢：一個 MultiMesh，每個位置一叢（幾片從同一點往外張開的尖葉），大小與朝向照亂數。
## 只是看的：沒有碰撞、不投影子。顏色與風在 grass_tufts.gdshader。

const BLADES: int = 7
const SHADER: Shader = preload("res://src/world/grass_tufts.gdshader")


## spots：每一叢的位置（世界座標，y＝地面）。
static func create(spots: PackedVector3Array, rng: RandomNumberGenerator) -> MultiMeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = tuft_mesh()
	mm.mesh.surface_set_material(0, mat)
	mm.instance_count = spots.size()
	for i: int in spots.size():
		var size: float = rng.randf_range(0.55, 1.2)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(size, size * rng.randf_range(0.7, 1.15), size)), spots[i])
		mm.set_instance_transform(i, xf)
		mm.set_instance_custom_data(i, Color(rng.randf(), 0, 0, 0))
	var node := MultiMeshInstance3D.new()
	node.name = "GrassTufts"
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## 一叢草的網格：BLADES 片三角形的尖葉繞一圈、往外倒。UV.y＝0 根部、1 尖端。
static func tuft_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	for b: int in BLADES:
		var around: float = TAU * float(b) / float(BLADES) + float(b % 3) * 0.4
		var out := Vector3(cos(around), 0.0, sin(around))
		var side := Vector3(-out.z, 0.0, out.x) * 0.05
		var foot: Vector3 = out * 0.06
		var height: float = 0.34 + 0.12 * float((b * 5) % 4)
		var tip: Vector3 = out * (0.16 + 0.05 * float(b % 3)) + Vector3.UP * height
		verts.append_array([foot - side, foot + side, tip])
		uvs.append_array([Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1)])
		normals.append_array([Vector3.UP, Vector3.UP, Vector3.UP])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
