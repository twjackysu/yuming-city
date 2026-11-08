shader_type spatial;
render_mode specular_occlusion_disabled;
// 濕石板路（參考 art-inbox/concepts 的冬夜概念圖：燈光在濕石頭上拉出倒影）。
// 全部程序生成、用世界座標 XZ（合併後的幾何沒有可靠的 UV），不依賴貼圖。
// - 石塊：每排錯開、長短不一的平石板（邊緣一圈倒角），每塊顏色、傾斜、磨損不同（D-095）
// - 石縫：較暗、濕（粗糙度低）
// - 水窪：低頻雜訊，平的暗水面＋細波紋（倒影拉成直條；中畫質靠 ReflectionProbe，高畫質再加 SSR）
// - 積雪：靠牆／低頻雜訊的淺色薄層（粗糙度高）

uniform vec3 stone_color : source_color = vec3(0.22, 0.23, 0.26);
uniform vec3 gap_color : source_color = vec3(0.06, 0.065, 0.075);
uniform vec3 snow_color : source_color = vec3(0.62, 0.67, 0.74);
uniform float stone_size = 0.55;
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.42;
uniform float snow_amount : hint_range(0.0, 1.0) = 0.18;
uniform float stone_roughness = 0.46;
// 水窪的細波紋（D-058）：垂直視線方向的細長波，把燈與亮窗的倒影拉成直條（概念圖的長條燈影）
uniform float ripple_strength : hint_range(0.0, 0.5) = 0.14;
// 水窪本身比濕石頭更暗（水面是黑的，倒影才跳得出來）
uniform float puddle_darken : hint_range(0.0, 1.0) = 0.25;
// 石板倒角（D-095）：只在邊緣這一圈（單位 stone_size）往外倒，石板本身是平的
uniform float bevel_width = 0.09;
uniform float bevel_strength = 0.8;
// 每塊石板自己的小傾斜（濕路上有的石板反光、有的暗）
uniform float stone_lean = 0.2;
// 石板長寬比（沿 x 較長）
const float STONE_LEN = 1.35;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// D-095：石板不再是一顆顆一樣大、整片鼓起的圓角方塊（遠看像氣泡紙）。
	// - 每排隨機錯開；約一半的格子再切成兩塊長短不一的石板（長度不一，像概念圖的鋪法）
	// - 石板是平的：只在最邊緣一圈倒角，每塊自己有一點傾斜（濕路上有的石板反光、有的暗）
	vec2 p = world_pos.xz / stone_size;
	// 排的寬度不一：每兩排一組，組內在 38%～62% 處分開（排寬 0.76～1.24 塊）
	float pair = floor(p.y * 0.5);
	float fy = fract(p.y * 0.5);
	float split_y = mix(0.38, 0.62, hash(vec2(pair, 21.0)));
	bool second = fy >= split_y;
	float row = pair * 2.0 + (second ? 1.0 : 0.0);
	float row_h = second ? (1.0 - split_y) * 2.0 : split_y * 2.0;
	float row_f = second ? (fy - split_y) / (1.0 - split_y) : fy / split_y;
	p.x = p.x / STONE_LEN + hash(vec2(row, 7.0)) + mod(row, 2.0) * 0.37;
	vec2 cell = vec2(floor(p.x), row);
	vec2 f = vec2(fract(p.x), row_f);
	float x0 = 0.0;
	float x1 = 1.0;
	if (hash(cell + vec2(3.7, 1.3)) > 0.5) {
		float s = mix(0.36, 0.64, hash(cell + vec2(9.1, 4.2)));
		if (f.x < s) { x1 = s; } else { x0 = s; }
	}
	vec2 sid = vec2(cell.x + x0, cell.y);
	// 石板內的座標（單位：stone_size），原點在石板中心
	vec2 half_size = vec2((x1 - x0) * STONE_LEN, row_h) * 0.5;
	vec2 lp = vec2(f.x * STONE_LEN, f.y * row_h) - vec2((x0 + x1) * 0.5 * STONE_LEN, row_h * 0.5);
	// 圓角矩形距離場：石板裡面是負的，邊緣是 0
	float corner = 0.1;
	vec2 q = abs(lp) - (half_size - corner);
	float sdf = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner;
	float jag = (noise(world_pos.xz * 11.0) - 0.5) * 0.05;
	float gap_half = 0.045;
	float stone = 1.0 - smoothstep(-gap_half - 0.03, -gap_half + 0.005, sdf + jag);
	// 遠處石塊比像素還小：淡成平均值，避免閃爍（沒有 mipmap 的程序紋理）
	float aa = clamp(length(fwidth(p)) * 1.2 - 0.15, 0.0, 1.0);
	stone = mix(stone, 0.8, aa);

	float tint = hash(sid);
	vec3 albedo = stone_color * mix(0.74, 1.14, tint);
	// 少數石板偏暖或偏冷（不同批的石頭）
	albedo *= mix(vec3(1.0), mix(vec3(1.06, 1.0, 0.92), vec3(0.93, 0.98, 1.06), hash(sid + vec2(2.2, 8.8))), 0.6);
	albedo *= mix(0.85, 1.05, fbm(world_pos.xz * 3.0));
	albedo = mix(gap_color, albedo, stone);

	// 水窪：低頻雜訊，石縫一定是濕的
	float puddle = smoothstep(1.0 - puddle_amount, 1.0 - puddle_amount + 0.12, fbm(world_pos.xz * 0.18 + 3.1));
	float wet = max(puddle, 1.0 - stone);
	albedo *= mix(1.0, 0.55, wet);
	albedo *= mix(1.0, 1.0 - puddle_darken, puddle);

	// 積雪：薄薄一層、不蓋住水窪
	float snow = smoothstep(1.0 - snow_amount, 1.0 - snow_amount + 0.08, fbm(world_pos.xz * 0.35 + 11.7)) * (1.0 - puddle);
	albedo = mix(albedo, snow_color, snow * 0.85);

	ALBEDO = albedo;
	// 石縫濕而不平（0.22）；水窪是平的水面（0.04），映得出燈與亮窗（中畫質靠 ReflectionProbe，高畫質再加 SSR）
	// 每塊石板的磨損程度不同：粗糙度 ±0.08
	float rough = mix(stone_roughness + (hash(sid + vec2(5.5, 0.7)) - 0.5) * 0.16, 0.22, 1.0 - stone);
	rough = mix(rough, 0.04, puddle);
	ROUGHNESS = mix(rough, 0.85, snow);
	SPECULAR = mix(mix(0.5, 0.75, wet), 1.0, puddle);
	// 石板是平的：只有最邊緣一圈倒角往外倒，加上每塊自己的小傾斜與表面的細微起伏；水窪與雪是平的
	if (world_normal.y > 0.9) {
		vec2 outward = vec2(0.0);
		if (q.x > 0.0 || q.y > 0.0) {
			outward = normalize(max(q, vec2(0.0)));
		} else {
			outward = q.x > q.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
		}
		outward *= sign(lp);
		float bevel = 1.0 - smoothstep(0.0, bevel_width, -sdf - gap_half);
		vec2 lean = vec2(hash(sid + vec2(1.9, 6.1)), hash(sid + vec2(7.3, 2.9))) - 0.5;
		vec2 bump = vec2(noise(world_pos.xz * 6.0 + 31.0), noise(world_pos.xz * 6.0 + 57.0)) - 0.5;
		vec2 tilt = (outward * bevel * bevel_strength + lean * stone_lean + bump * 0.06) * stone * (1.0 - puddle) * (1.0 - snow) * (1.0 - aa);
		// 水窪波紋：沿 z 起伏（看向南北時）與沿 x 起伏（看向東西時）依視線方向混合；
		// 波紋固定在世界座標上，轉鏡頭時只換權重，不會跟著鏡頭滑動。遠處波紋比像素細時淡掉（避免閃爍）
		vec3 v_w = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
		vec2 vd = abs(normalize(v_w.xz + vec2(1e-4)));
		float wz = vd.y * vd.y;
		float rz = noise(vec2(world_pos.x * 0.7, world_pos.z * 5.0)) - 0.5;
		float rx = noise(vec2(world_pos.x * 5.0 + 17.0, world_pos.z * 0.7)) - 0.5;
		float rfade = 1.0 - clamp(length(fwidth(world_pos.xz)) * 5.0 - 0.6, 0.0, 1.0);
		tilt += vec2(rx * (1.0 - wz), rz * wz) * ripple_strength * puddle * rfade;
		vec3 n_world = normalize(vec3(tilt.x, 1.0, tilt.y));
		NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	}
}
