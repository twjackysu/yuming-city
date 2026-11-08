shader_type spatial;
render_mode specular_occlusion_disabled;
// 濕石板路（參考 art-inbox/concepts 的冬夜概念圖：燈光在濕石頭上拉出倒影）。
// 全部程序生成、用世界座標 XZ（合併後的幾何沒有可靠的 UV），不依賴貼圖。
// - 石塊：錯位排列的圓角方石，每塊顏色略有差異
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
	vec2 p = world_pos.xz / stone_size;
	// 每排錯開半塊；石塊略長
	float row = floor(p.y);
	p.x += mod(row, 2.0) * 0.5 + hash(vec2(row, 7.0)) * 0.3;
	vec2 cell = floor(p);
	vec2 f = fract(p) - 0.5;
	// 圓角方形的距離場：0 在石塊中央，越接近 1 越靠縫
	vec2 d = abs(f) * 2.0;
	float edge = pow(pow(d.x, 6.0) + pow(d.y, 6.0), 1.0 / 6.0);
	float jag = (noise(world_pos.xz * 9.0) - 0.5) * 0.08;
	float stone = 1.0 - smoothstep(0.82, 0.95, edge + jag);
	// 遠處石塊比像素還小：淡成平均值，避免閃爍（沒有 mipmap 的程序紋理）
	float aa = clamp(length(fwidth(p)) * 1.2 - 0.15, 0.0, 1.0);
	stone = mix(stone, 0.8, aa);

	float tint = hash(cell);
	vec3 albedo = stone_color * mix(0.82, 1.1, tint);
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
	float rough = mix(stone_roughness, 0.22, 1.0 - stone);
	rough = mix(rough, 0.04, puddle);
	ROUGHNESS = mix(rough, 0.85, snow);
	SPECULAR = mix(mix(0.5, 0.75, wet), 1.0, puddle);
	// 石塊微微隆起（只在朝上的面）：越靠石縫法線越往外倒；水窪與雪是平的
	if (world_normal.y > 0.9) {
		vec2 tilt = f * smoothstep(0.45, 0.92, edge) * 1.1 * (1.0 - puddle) * (1.0 - snow) * (1.0 - aa);
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
