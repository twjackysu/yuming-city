class_name SnowMound
extends RefCounted
## 低面數的雪堆（D-102）：中間厚、往邊緣薄到 0，輪廓是不規則的圓角長方形。
## 取代破屋頂上直邊的雪板（box 的四邊是垂直的白牆，近看像一片片冰板）。
## 模型座標：X＝長、Z＝寬、Y＝往上；底在 y=0（邊緣稍微低一點，貼在斜面上不會露縫）。
## 極座標網格：中心一點＋RINGS 圈 × SEGMENTS 段；不規則度由 seed 決定（位置雜湊，不動關卡的 _rng）。
## 正面順時針（Godot 慣例），法線朝上。用 StaticBatch.add_mesh 合併。
## bias：最高點往哪邊偏（以半長／半寬為 1；街邊雪帶用 (0, ±0.5) 讓靠牆那側高而陡、靠街那側低而緩，D-105）。

const RINGS: int = 4
## 20 段（D-110；原本 14 段近看看得出多邊形）
const SEGMENTS: int = 20
## 輪廓的「方」度：超橢圓的次方（2＝橢圓，越大越接近長方形）
const SQUARENESS: float = 3.2
## 輪廓往內凹的最大比例（每段不同）
const RAGGED: float = 0.22
## 最高點最多偏到哪裡（以半長／半寬為 1；要留在輪廓裡面，網格才不會翻面）
const PEAK_LIMIT: float = 0.55


static func build(length: float, width: float, height: float, seed: float, bias: Vector2 = Vector2.ZERO) -> ArrayMesh:
	var a: float = length * 0.5
	var b: float = width * 0.5
	var edge: PackedFloat32Array = PackedFloat32Array()
	edge.resize(SEGMENTS)
	# 輪廓往內凹：兩三個大的起伏＋一點點每段的雜訊（D-110；原本每段各自亂數，輪廓是鋸齒、近看像潑上去的白漆）
	var ph1: float = _hash(seed, 80.0) * TAU
	var ph2: float = _hash(seed, 81.0) * TAU
	for i: int in SEGMENTS:
		var th: float = TAU * float(i) / float(SEGMENTS)
		var wave: float = 0.6 * sin(2.0 * th + ph1) + 0.3 * sin(3.0 * th + ph2) + 0.1 * (_hash(seed, float(i)) * 2.0 - 1.0)
		edge[i] = 1.0 - RAGGED * (0.5 + 0.5 * wave)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	# 中心（最高點稍微偏一點，雪堆不是正中間鼓起）
	var peak := Vector2((_hash(seed, 40.0) - 0.5) * 0.3, (_hash(seed, 41.0) - 0.5) * 0.3) + bias
	peak = peak.clamp(Vector2(-PEAK_LIMIT, -PEAK_LIMIT), Vector2(PEAK_LIMIT, PEAK_LIMIT))
	verts.append(Vector3(peak.x * a, height, peak.y * b))
	uvs.append(Vector2(0.5 + peak.x * 0.5, 0.5 + peak.y * 0.5))
	for r: int in range(1, RINGS + 1):
		var k: float = float(r) / float(RINGS)
		for i: int in SEGMENTS:
			var th: float = TAU * float(i) / float(SEGMENTS)
			var c: float = cos(th)
			var s: float = sin(th)
			var sq: float = pow(pow(absf(c), SQUARENESS) + pow(absf(s), SQUARENESS), -1.0 / SQUARENESS)
			# 每一圈是輪廓對最高點的縮放（k²：裡面幾圈靠近最高點）；最高點偏很多時也不會翻面
			var rr: float = sq * lerpf(1.0, edge[i], k)
			var x: float = lerpf(peak.x, c * rr, k * k) * a
			var z: float = lerpf(peak.y, s * rr, k * k) * b
			# 高度：中間平緩、靠邊緣才很快降到 0；外圈稍微低於 0（貼進斜面）
			var hgt: float = height * pow(1.0 - k * k, 0.7) * lerpf(0.94, 1.05, _hash(seed, 60.0 + float(r * SEGMENTS + i)))
			if r == RINGS:
				hgt = -0.012
			verts.append(Vector3(x, hgt, z))
			uvs.append(Vector2(x / length + 0.5, z / width + 0.5))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := PackedInt32Array()
	# 中心扇形：(中心, i, i+1) 從上面看是順時針（X 往右、Z 往下）
	for i: int in SEGMENTS:
		idx.append(0)
		idx.append(1 + i)
		idx.append(1 + (i + 1) % SEGMENTS)
	for r: int in range(1, RINGS):
		var inner: int = 1 + (r - 1) * SEGMENTS
		var outer: int = 1 + r * SEGMENTS
		for i: int in SEGMENTS:
			var j: int = (i + 1) % SEGMENTS
			idx.append(inner + i)
			idx.append(outer + i)
			idx.append(outer + j)
			idx.append(inner + i)
			idx.append(outer + j)
			idx.append(inner + j)
	for n: int in idx.size():
		var v: int = idx[n]
		st.set_uv(uvs[v])
		st.add_vertex(verts[v])
	st.index()
	st.generate_normals()
	return st.commit()


static func _hash(seed: float, n: float) -> float:
	return fposmod(sin(seed * 12.9898 + n * 78.233) * 43758.5453, 1.0)
