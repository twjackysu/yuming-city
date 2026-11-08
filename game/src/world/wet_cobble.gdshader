shader_type spatial;
render_mode specular_occlusion_disabled;
// 濕石板路（參考 art-inbox/concepts 的冬夜概念圖：燈光在濕石頭上拉出倒影）。
// 全部程序生成、用世界座標 XZ（合併後的幾何沒有可靠的 UV），不依賴貼圖。
// - 石塊：每排錯開、長短不一的平石板（邊緣一圈倒角），每塊顏色、傾斜、磨損不同（D-095）
// - 石縫：較暗、濕（粗糙度低）
// - 水窪：低頻雜訊，平的暗水面＋細波紋（倒影拉成直條；中畫質靠 ReflectionProbe，高畫質再加 SSR）
// - 積雪：靠牆／低頻雜訊的淺色薄層（粗糙度高）
// - 地上的殘雪與髒雪（D-114）：石縫裡卡著雪、靠牆與角落多（街道範圍 lanes）；井邊與攤子前一圈踩實的灰褐髒雪（trodden）；
//   一道手推車的車轍（rut_pts 折線，兩條濕亮的細溝＋兩側被推開的雪）。沒設定（lane_count＝0 等）時跟原本一樣

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
// 石板長寬比（沿排的方向較長）；每排的石板長度再乘 0.8～1.25（D-120）
const float STONE_LEN = 1.35;
// D-120 排的方向：arc_paving＝true 時繞 arc_center 一圈圈弧形鋪（廣場繞中央石框），
// 否則是直排、但排會隨低頻雜訊微微起伏（row_wave：起伏幅度，單位 stone_size）
uniform bool arc_paving = false;
uniform vec2 arc_center = vec2(0.0);
uniform float row_wave = 1.1;
// D-120 這個圓（中心 xz、半徑）裡不蓋殘雪與薄雪（廣場石框裡）；半徑 0＝沒有
uniform vec3 clear_disc = vec3(0.0);

// D-114 殘雪：街道範圍（中心 xz、半寬 xz）。離邊（牆）越近，石縫裡卡的雪越多、石板上也有一片片薄雪；
// 兩個方向都靠邊（角落）更多。點在好幾個範圍裡時取離牆最遠的那個（街口不會被當成牆）；不在任何範圍裡當成靠牆
uniform vec4 lanes[8];
uniform int lane_count = 0;
uniform float wall_reach = 2.6;
uniform vec3 grime_color : source_color = vec3(0.37, 0.34, 0.31);
// 踩實的髒雪：圓心 xz、內半徑、外半徑（內半徑 > 0 是一圈，例如井邊）
uniform vec4 trodden[4];
uniform int trodden_count = 0;
// 車轍：折線（中心線），兩道輪溝相距 rut_gauge
uniform vec2 rut_pts[8];
uniform int rut_count = 0;
uniform float rut_gauge = 1.37;
uniform float rut_width = 0.075;

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

// 離牆多近（0＝街道中間、1＝牆腳或角落）
float wall_near(vec2 xz) {
	if (lane_count == 0) {
		return 0.0;
	}
	float near = 0.75;  // 不在任何範圍裡（房子後面、鎮外）
	bool inside = false;
	for (int i = 0; i < 8; i++) {
		if (i >= lane_count) {
			break;
		}
		vec2 d = lanes[i].zw - abs(xz - lanes[i].xy);
		if (d.x > 0.0 && d.y > 0.0) {
			vec2 pr = 1.0 - smoothstep(vec2(0.0), vec2(wall_reach), d);
			float n = clamp(pr.x + pr.y, 0.0, 1.0);
			near = inside ? min(near, n) : n;
			inside = true;
		}
	}
	return near;
}

// 踩實的髒雪有多少（0～1，邊緣用雜訊打散）
float trodden_mask(vec2 xz) {
	float m = 0.0;
	for (int i = 0; i < 4; i++) {
		if (i >= trodden_count) {
			break;
		}
		vec4 t = trodden[i];
		float r = length(xz - t.xy);
		float wob = (noise(xz * 1.3 + float(i) * 7.0) - 0.5) * 0.7;
		float outer = 1.0 - smoothstep(t.w - 0.6, t.w + 0.2, r + wob);
		float inner = t.z > 0.0 ? smoothstep(t.z - 0.05, t.z + 0.25, r) : 1.0;
		m = max(m, outer * inner);
	}
	return m;
}

// 車轍：回傳 (輪溝 0～1, 輪溝旁被推開的雪 0～1, 輪溝往外的方向 xz)
vec4 rut_mask(vec2 xz) {
	if (rut_count < 2) {
		return vec4(0.0);
	}
	float best = 1e6;
	vec2 away = vec2(0.0);
	float along = 0.0;
	float total = 0.0;
	float best_along = 0.0;
	for (int i = 0; i < 7; i++) {
		if (i + 1 >= rut_count) {
			break;
		}
		vec2 a = rut_pts[i];
		vec2 b = rut_pts[i + 1];
		vec2 ab = b - a;
		float len = length(ab);
		float h = clamp(dot(xz - a, ab) / (len * len), 0.0, 1.0);
		vec2 c = a + ab * h;
		float d = length(xz - c);
		if (d < best) {
			best = d;
			away = (xz - c) / max(d, 1e-4);
			best_along = total + h * len;
		}
		total += len;
	}
	// 兩道輪溝：中心線兩側 rut_gauge/2
	float off = best - rut_gauge * 0.5;
	float groove = 1.0 - smoothstep(rut_width * 0.6, rut_width, abs(off));
	float ridge = smoothstep(rut_width * 0.7, rut_width * 1.1, abs(off)) * (1.0 - smoothstep(rut_width * 1.6, rut_width * 3.2, abs(off)));
	// 兩端淡出、中間斷斷續續（舊車轍，被踩過、被雪蓋過）
	float ends = smoothstep(0.0, 1.5, best_along) * (1.0 - smoothstep(total - 2.5, total, best_along));
	float broken = smoothstep(0.25, 0.55, noise(vec2(best_along * 0.9, off > 0.0 ? 3.0 : 9.0)));
	float k = ends * mix(0.35, 1.0, broken);
	return vec4(groove * k, ridge * k, away * sign(off));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// D-095：石板不再是一顆顆一樣大、整片鼓起的圓角方塊（遠看像氣泡紙）。
	// - 每排隨機錯開；約一半的格子再切成兩塊長短不一的石板（長度不一，像概念圖的鋪法）
	// - 石板是平的：只在最邊緣一圈倒角，每塊自己有一點傾斜（濕路上有的石板反光、有的暗）
	// D-120：排不再全是 X 軸直線（廣場繞中央弧形鋪、街道的排微微起伏），每排石板長度不同，
	// 每塊石板的圓角、四邊縮進、邊緣起伏都不同（不像磁磚）
	vec2 xz = world_pos.xz;
	vec2 rd = xz - arc_center;
	float r_m = max(length(rd), 1e-3);
	vec2 p;  // x：沿排（之後換成格數），y：跨排（單位 stone_size）
	// 石板自己的座標軸在世界上的方向（倒角的法線要轉回世界）
	vec2 across_dir = vec2(0.0, 1.0);
	vec2 along_dir = vec2(1.0, 0.0);
	if (arc_paving) {
		across_dir = rd / r_m;
		along_dir = vec2(-across_dir.y, across_dir.x);
		p = vec2(atan(rd.y, rd.x) / TAU + 0.5, r_m / stone_size);
	} else {
		p = xz / stone_size;
		p.y += (noise(xz * 0.11 + vec2(2.3, 8.1)) - 0.5) * row_wave * 2.0;
	}
	// 排的寬度不一：每兩排一組，組內在 38%～62% 處分開（排寬 0.76～1.24 塊）
	float pair = floor(p.y * 0.5);
	float fy = fract(p.y * 0.5);
	float split_y = mix(0.38, 0.62, hash(vec2(pair, 21.0)));
	bool second = fy >= split_y;
	float row = pair * 2.0 + (second ? 1.0 : 0.0);
	float row_h = second ? (1.0 - split_y) * 2.0 : split_y * 2.0;
	float row_f = second ? (fy - split_y) / (1.0 - split_y) : fy / split_y;
	// 這一排的石板長度（單位 stone_size）、沿排方向的縮放（弧形鋪時外側比內側寬）
	float len_row = STONE_LEN * mix(0.8, 1.25, hash(vec2(row, 13.0)));
	float stretch = 1.0;
	float n_row = 0.0;
	if (arc_paving) {
		// 一圈剛好整數塊：接縫處不會切出半塊
		float r_c = pair * 2.0 + (second ? split_y * 2.0 : 0.0) + row_h * 0.5;
		n_row = max(floor(TAU * r_c / len_row + 0.5), 3.0);
		len_row = TAU * r_c / n_row;
		stretch = p.y / max(r_c, 1e-3);
		p.x = p.x * n_row + hash(vec2(row, 7.0));
	} else {
		p.x = p.x / len_row + hash(vec2(row, 7.0)) + mod(row, 2.0) * 0.37;
	}
	vec2 cell = vec2(floor(p.x), row);
	if (arc_paving) {
		cell.x = mod(cell.x, n_row);
	}
	vec2 f = vec2(fract(p.x), row_f);
	float x0 = 0.0;
	float x1 = 1.0;
	if (hash(cell + vec2(3.7, 1.3)) > 0.5) {
		float s = mix(0.36, 0.64, hash(cell + vec2(9.1, 4.2)));
		if (f.x < s) { x1 = s; } else { x0 = s; }
	}
	vec2 sid = vec2(cell.x + x0, cell.y);
	// 石板內的座標（單位：stone_size），原點在石板中心
	vec2 half_size = vec2((x1 - x0) * len_row * stretch, row_h) * 0.5;
	vec2 lp = vec2((f.x - (x0 + x1) * 0.5) * len_row * stretch, (f.y - 0.5) * row_h);
	// 每塊石板四邊縮進不同（石縫寬窄不一）、中心偏一點
	vec2 shrink = vec2(hash(sid + vec2(6.6, 3.3)), hash(sid + vec2(2.4, 9.7))) * 0.045;
	lp -= (vec2(hash(sid + vec2(8.2, 5.1)), hash(sid + vec2(4.8, 7.6))) - 0.5) * shrink;
	half_size -= shrink;
	// 圓角每塊不同（0.06～0.24，不超過短邊的 0.8 倍）：有的方正、有的圓
	float corner = min(mix(0.06, 0.24, hash(sid + vec2(4.1, 2.7))), min(half_size.x, half_size.y) * 0.8);
	vec2 q = abs(lp) - (half_size - corner);
	float sdf = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner;
	// 邊緣起伏：細的鋸齒＋石板大小的鼓出、凹進
	float jag = (noise(xz * 11.0) - 0.5) * 0.05 + (noise(xz * 3.6 + sid * 1.7) - 0.5) * 0.08;
	float gap_half = 0.045;
	float stone = 1.0 - smoothstep(-gap_half - 0.03, -gap_half + 0.005, sdf + jag);
	// 遠處石塊比像素還小：淡成平均值，避免閃爍（沒有 mipmap 的程序紋理）
	// （用連續的世界座標量：弧形鋪的 p.x 在排與排之間、接縫處不連續）
	float aa = clamp(length(fwidth(xz) / stone_size * vec2(0.8, 1.0)) * 1.2 - 0.15, 0.0, 1.0);
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

	// D-114 殘雪：石縫裡卡著雪（靠牆、角落多，街道中間一片一片），靠牆的石板上蓋一層薄雪，
	// 空地上偶爾一片被風吹散的薄雪（細雜訊打散，露出石頭）。水窪不蓋。
	// （fbm 的值大多在 0.3～0.65 之間，平均約 0.47：門檻照這個範圍抓）
	float near = wall_near(world_pos.xz);
	float patchy = fbm(world_pos.xz * 0.9 + 4.4);
	float lodge = clamp(near * 1.3 + smoothstep(0.5, 0.64, patchy) * 0.8, 0.0, 1.0);
	// 石縫裡的雪是一段一段的（不是一整張白格子），只有牆腳約 0.6 m 內才連成線
	// （D-124：窄街整條都在靠牆範圍裡，原本連成線的範圍太寬，月光下整條街是淺灰格子）
	float in_gap = (1.0 - stone) * lodge * mix(smoothstep(0.35, 0.6, noise(world_pos.xz * 2.7 + 5.0)), 1.0, smoothstep(0.85, 1.0, near));
	float on_stone = smoothstep(0.45, 0.8, near * 0.85 + (patchy - 0.47) * 1.2) * stone;
	float dust = smoothstep(0.5, 0.6, fbm(world_pos.xz * 0.5 + 7.0)) * smoothstep(0.25, 0.6, noise(world_pos.xz * 4.5 + 13.0));
	float rest = max(max(in_gap * 0.75, on_stone * 0.9), dust * 0.6 * stone) * (1.0 - puddle) * step(0.5, float(lane_count));
	snow = max(snow, rest);
	// D-120 石框裡不蓋殘雪與薄雪
	if (clear_disc.z > 0.0) {
		snow *= smoothstep(clear_disc.z - 0.3, clear_disc.z + 0.1, length(xz - clear_disc.xy));
	}

	// 踩實的髒雪：灰褐、斑駁（有的地方踩到露出石頭），石縫裡最髒
	float tm = trodden_mask(world_pos.xz);
	float grime = tm * mix(smoothstep(0.36, 0.52, fbm(world_pos.xz * 1.7 + 21.0)), 1.0, (1.0 - stone) * 0.8) * (1.0 - puddle * 0.7);
	// 髒雪蓋過的地方不再是乾淨的雪
	snow *= 1.0 - tm * 0.85;

	// 車轍：輪溝是濕的暗溝（積水，映得出燈），兩側一條被推開的雪
	vec4 rut = rut_mask(world_pos.xz);
	snow = max(snow, rut.y * 0.95 * (1.0 - puddle));
	snow *= 1.0 - rut.x;

	// 石縫裡的雪在陰影裡、比石板上的雪暗（近處不會像一張白格子，D-120）
	albedo = mix(albedo, snow_color * mix(1.0, 0.7, 1.0 - stone), snow * 0.85);
	albedo = mix(albedo, grime_color * mix(0.8, 1.15, noise(world_pos.xz * 4.0)), grime * 0.85);
	albedo = mix(albedo, gap_color * 1.4, rut.x * 0.7);

	ALBEDO = albedo;
	// 石縫濕而不平（0.22）；水窪是平的水面（0.04），映得出燈與亮窗（中畫質靠 ReflectionProbe，高畫質再加 SSR）
	// 每塊石板的磨損程度不同：粗糙度 ±0.08
	float rough = mix(stone_roughness + (hash(sid + vec2(5.5, 0.7)) - 0.5) * 0.16, 0.22, 1.0 - stone);
	rough = mix(rough, 0.04, puddle);
	rough = mix(rough, 0.62, grime);  // 踩實的雪：半濕半糊
	rough = mix(rough, 0.08, rut.x);  // 輪溝裡積水
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
		outward = outward.x * along_dir + outward.y * across_dir;
		float bevel = 1.0 - smoothstep(0.0, bevel_width, -sdf - gap_half);
		vec2 lean = vec2(hash(sid + vec2(1.9, 6.1)), hash(sid + vec2(7.3, 2.9))) - 0.5;
		vec2 bump = vec2(noise(world_pos.xz * 6.0 + 31.0), noise(world_pos.xz * 6.0 + 57.0)) - 0.5;
		vec2 tilt = (outward * bevel * bevel_strength + lean * stone_lean + bump * 0.06) * stone * (1.0 - puddle) * (1.0 - snow) * (1.0 - grime) * (1.0 - aa);
		// 輪溝兩壁往溝裡斜（燈光在溝邊拉出一條細亮線）：只在溝壁（遮罩的過渡帶），法線朝溝的中心
		tilt -= rut.zw * rut.x * (1.0 - rut.x) * 1.2 * (1.0 - aa);
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
