class_name SnowMound
extends RefCounted
## 低面數的雪堆（D-102）：中間厚、往邊緣薄到 0，輪廓是不規則的圓角長方形。
## 取代破屋頂上直邊的雪板（box 的四邊是垂直的白牆，近看像一片片冰板）。
## 模型座標：X＝長、Z＝寬、Y＝往上；底在 y=0（邊緣稍微低一點，貼在斜面上不會露縫）。
## 極座標網格：中心一點＋RINGS 圈 × SEGMENTS 段；不規則度由 seed 決定（位置雜湊，不動關卡的 _rng）。
## 正面順時針（Godot 慣例），法線朝上。用 StaticBatch.add_mesh 合併。
## bias：最高點往哪邊偏（以半長／半寬為 1；街邊雪帶用 (0, ±0.5) 讓靠牆那側高而陡、靠街那側低而緩，D-105）。
## street_bank：街邊雪帶才設 true（D-126）：UV2.y 放「往 bias 那側多遠」（-1＝靠街的邊、+1＝靠牆的邊），
## 雪 shader 用來讓靠牆的角落暗一點、靠街那側才有腳印與髒雪。其他雪堆 UV2.y＝0（都不做）。
## on_tiles：鋪在屋瓦上的薄雪（破屋頂，D-127）：UV2.y＝TILES_MARK＋沿著模型 X 的公尺數，
## 雪 shader 用來畫出底下一排排屋瓦撐起的橫紋、薄的地方露出屋瓦。

const RINGS: int = 4
## 20 段（D-110；原本 14 段近看看得出多邊形）
const SEGMENTS: int = 20
## 輪廓的「方」度：超橢圓的次方（2＝橢圓，越大越接近長方形）
const SQUARENESS: float = 3.2
## 輪廓往內凹的最大比例（每段不同）
const RAGGED: float = 0.22
## 最高點最多偏到哪裡（以半長／半寬為 1；要留在輪廓裡面，網格才不會翻面）
const PEAK_LIMIT: float = 0.55
## on_tiles 的雪堆 UV2.y 從這個值起跳（街邊雪帶的 -1～1 不會碰到；shader 用 > 5 分辨）
const TILES_MARK: float = 10.0
## 街邊雪帶的 UV.x 從這個值起跳（D-134）：其他雪的 UV 在 0～1，shader 用 > 500 分辨
const BANK_MARK: float = 1000.0


static func build(length: float, width: float, height: float, seed: float, bias: Vector2 = Vector2.ZERO, street_bank: bool = false, on_tiles: bool = false) -> ArrayMesh:
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
	# UV2.x＝圈數（0＝最高點、1＝外圈）：雪 shader 用來讓外圈變薄（D-119）。
	# 跟其他雪（方塊、稜柱，沒有 UV2）合併時，SurfaceTool 會補 0＝不變薄。
	var rings := PackedFloat32Array()
	# UV2.y＝往 bias 那側多遠（只有 street_bank；D-126）
	var leans := PackedFloat32Array()
	var lean_dir: Vector2 = bias.normalized() if street_bank and bias.length() > 0.001 else Vector2.ZERO
	# 中心（最高點稍微偏一點，雪堆不是正中間鼓起）
	var peak := Vector2((_hash(seed, 40.0) - 0.5) * 0.3, (_hash(seed, 41.0) - 0.5) * 0.3) + bias
	peak = peak.clamp(Vector2(-PEAK_LIMIT, -PEAK_LIMIT), Vector2(PEAK_LIMIT, PEAK_LIMIT))
	verts.append(Vector3(peak.x * a, height, peak.y * b))
	uvs.append(Vector2(0.5 + peak.x * 0.5, 0.5 + peak.y * 0.5))
	rings.append(0.0)
	leans.append(TILES_MARK + peak.x * a if on_tiles else clampf(peak.dot(lean_dir), -1.0, 1.0))
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
			rings.append(k)
			leans.append(TILES_MARK + x if on_tiles else clampf(Vector2(x / a, z / b).dot(lean_dir), -1.0, 1.0))
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
		st.set_uv2(Vector2(rings[v], leans[v]))
		st.add_vertex(verts[v])
	st.index()
	st.generate_normals()
	return st.commit()


## 街邊雪帶（D-134）：跟 build(..., street_bank=true) 一樣，另外把 UV 換成雪帶自己的公尺座標，
## 讓 shader 沿著雪帶畫一串腳印：UV.x＝BANK_MARK＋沿著牆的公尺數（along0＝這段中心的位置，
## 同一條雪帶前後重疊的幾段算出來一樣，腳印接得起來）、UV.y＝離牆腳線多遠（往街那側為正；
## from_wall0＝這段中心離牆多遠）。toward_wall：模型 +Z 是不是朝牆（±1）。
static func build_bank(length: float, width: float, height: float, seed: float, toward_wall: float,
		along0: float, from_wall0: float) -> ArrayMesh:
	var mesh: ArrayMesh = build(length, width, height, seed, Vector2(0.0, 0.5 * toward_wall), true)
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs := PackedVector2Array()
	uvs.resize(verts.size())
	for i: int in verts.size():
		uvs[i] = Vector2(BANK_MARK + along0 + verts[i].x, from_wall0 - verts[i].z * toward_wall)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## 一整條連續的街邊雪帶（D-136，第八輪盤點第 1 項）：原本沿牆是一串重疊的 build_bank 雪堆，每個各有一個最高點，
## 戰鬥鏡頭低角度看過去是一節一節的枕頭／沙包。改成一整條沿牆的網格：橫切面靠牆高而陡、往街慢慢變薄到 0，
## 高度與伸出寬度沿著牆用低頻雜訊慢慢起伏（3～5 m 一個起伏）＋一點細的起伏，兩端 STRIP_TAPER（1 m）內收成 0。
## 模型座標：X＝沿著牆（-length/2～length/2）、原點在牆腳線的中點、Y＝往上；toward_wall＝模型 +Z 是不是朝牆（±1）。
## 埋進牆裡 into_wall（看不到，碰到牆時還很厚）；靠街那側伸出 out（每個位置 ×0.78～1.08）。
## UV、UV2 跟 build_bank 同一套：UV＝(BANK_MARK＋along0＋沿著牆的公尺數（從 -X 端起算）, 離牆腳線多遠)、
## UV2＝(往外第幾圈：牆腳線 0～靠街的邊 1, 往牆那側多遠：靠牆的邊 +1～靠街的邊 -1)。
const STRIP_STEP: float = 0.3
const STRIP_COLS: int = 9
const STRIP_TAPER: float = 1.0


static func build_strip(length: float, out: float, into_wall: float, height: float, seed: float,
		toward_wall: float, along0: float) -> ArrayMesh:
	var n: int = maxi(2, ceili(length / STRIP_STEP) + 1)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	for i: int in n:
		var s: float = length * float(i) / float(n - 1)  # 從 -X 端起算的公尺數
		var x: float = s - length * 0.5
		var taper: float = smoothstep(0.0, STRIP_TAPER, minf(s, length - s))
		var h: float = strip_height(s, height, seed) * taper
		var o: float = strip_out(s, out, seed) * lerpf(0.55, 1.0, taper)
		var total: float = o + into_wall
		var u0: float = into_wall / total  # 牆腳線在橫切面的哪裡
		for j: int in STRIP_COLS:
			var u: float = float(j) / float(STRIP_COLS - 1)
			var dfw: float = u * total - into_wall  # 離牆腳線多遠（往街為正）
			var k: float = clampf((u - u0) / (1.0 - u0), 0.0, 1.0)
			# 牆裡到牆腳線一樣高；往街：靠牆陡、靠街慢慢薄（1 - k^1.6）^1.4；最外一列稍微低於 0（貼地不露縫）
			var y: float = h * pow(1.0 - pow(k, 1.6), 1.4) * lerpf(0.95, 1.04, _hash(seed + float(i), float(j)))
			if j == STRIP_COLS - 1:
				y = -0.012
			verts.append(Vector3(x, y, -toward_wall * dfw))
			uvs.append(Vector2(BANK_MARK + along0 + s, dfw))
			uv2s.append(Vector2(k, 1.0 - 2.0 * u))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := PackedInt32Array()
	# j 增加＝往街；toward_wall＝+1 時往街是 -Z，繞向要反過來（Godot 正面順時針、法線朝上）
	var flip: bool = toward_wall > 0.0
	for i: int in n - 1:
		for j: int in STRIP_COLS - 1:
			var a: int = i * STRIP_COLS + j
			var b: int = (i + 1) * STRIP_COLS + j
			var tri: Array[int] = [a, b, b + 1, a, b + 1, a + 1]
			if flip:
				tri = [a, b + 1, b, a, a + 1, b + 1]
			for v: int in tri:
				idx.append(v)
	for v: int in idx:
		st.set_uv(uvs[v])
		st.set_uv2(uv2s[v])
		st.add_vertex(verts[v])
	st.index()
	st.generate_normals()
	return st.commit()


## 雪帶在沿著牆 s 公尺處最高多高：低頻（約 4 m）大起伏 ×0.6～1.0＋約 1.1 m 的細起伏
static func strip_height(s: float, height: float, seed: float) -> float:
	return height * (0.6 + 0.4 * _noise1(s / 4.2, seed) + 0.08 * (_noise1(s / 1.1, seed + 17.0) - 0.5))


## 雪帶在沿著牆 s 公尺處靠街那側伸出多遠：約 3 m 的起伏 ×0.78～1.08＋約 0.7 m 的小缺口
static func strip_out(s: float, out: float, seed: float) -> float:
	return out * (0.78 + 0.26 * _noise1(s / 3.1, seed + 5.0) + 0.06 * (_noise1(s / 0.7, seed + 23.0) - 0.5))


## 一維平滑值雜訊（0～1）：整數點是位置雜湊，中間用 smoothstep 內插
static func _noise1(x: float, seed: float) -> float:
	var i: float = floorf(x)
	var f: float = x - i
	return lerpf(_hash(seed, i * 1.37 + 3.0), _hash(seed, (i + 1.0) * 1.37 + 3.0), f * f * (3.0 - 2.0 * f))


static func _hash(seed: float, n: float) -> float:
	return fposmod(sin(seed * 12.9898 + n * 78.233) * 43758.5453, 1.0)
