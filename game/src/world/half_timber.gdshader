shader_type spatial;
// 半木構房子外牆（參考 art-inbox/concepts/frostbridge_winter：一樓石牆、樓上灰泥＋深色木框）。
// 全部程序生成、用世界座標（合併後的幾何沒有可靠的 UV），不依賴貼圖。
// - 牆面依法線選投影面：朝 ±X 的牆用 ZY、朝 ±Z 的牆用 XY；朝上的面是雪
// - stone_height 以下：錯位石塊＋暗色灰縫，牆腳濕、積一點雪
// - 以上：灰泥（髒污、雨痕），木框＝每層一道橫梁、固定間距的立柱、部分格子加斜撐
// - stone_height 設很大（例如 99）＝整面石牆（後牆、城牆、鐘樓、煙囪）

uniform vec3 plaster_color : source_color = vec3(0.42, 0.41, 0.40);
uniform vec3 stone_color : source_color = vec3(0.27, 0.28, 0.31);
uniform vec3 mortar_color : source_color = vec3(0.08, 0.085, 0.095);
uniform vec3 timber_color : source_color = vec3(0.085, 0.062, 0.046);
uniform vec3 snow_color : source_color = vec3(0.62, 0.67, 0.74);
uniform float stone_height = 2.6;
uniform float floor_height = 2.4;
uniform float post_spacing = 1.5;
uniform float beam_width = 0.2;
uniform float brace_chance : hint_range(0.0, 1.0) = 0.45;
uniform float block_scale = 1.0;

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
	vec3 n = normalize(world_normal);
	bool side_x = abs(n.x) > abs(n.z);
	float u = side_x ? world_pos.z : world_pos.x;
	float y = world_pos.y;
	vec2 wp = vec2(u, y);
	// 每像素幾公尺：細節太小時淡掉（沒有 mipmap 的程序紋理會閃）
	float px = length(fwidth(wp));
	float detail = 1.0 - smoothstep(0.03, 0.09, px);

	vec3 albedo;
	float rough;
	vec2 tilt = vec2(0.0);

	if (y < stone_height) {
		// 石塊：每排高度略不同、錯開，灰縫帶一點抖動
		float bh = 0.36 * block_scale;
		float bw = 0.66 * block_scale;
		float row = floor(y / bh);
		float uu = u / bw + hash(vec2(row, 3.0)) * 0.9 + mod(row, 2.0) * 0.5;
		vec2 cell = vec2(floor(uu), row);
		vec2 f = vec2(fract(uu), fract(y / bh));
		vec2 dm = min(f, 1.0 - f) * vec2(bw, bh);
		float jag = (noise(wp * 11.0) - 0.5) * 0.02;
		float gap = smoothstep(0.018, 0.04, min(dm.x, dm.y) + jag);
		gap = mix(0.85, gap, detail);
		float tint = hash(cell);
		vec3 stone = stone_color * mix(0.7, 1.18, tint) * mix(0.82, 1.06, fbm(wp * 2.6));
		albedo = mix(mortar_color, stone, gap);
		rough = mix(0.95, 0.82, gap);
		// 石塊邊緣往外倒一點（只有近處）
		tilt = (f - 0.5) * smoothstep(0.3, 0.48, abs(f - 0.5)) * 0.5 * detail;
		// 石牆頂端一條薄雪（窗台般的突出）
		float ledge = smoothstep(stone_height - 0.07, stone_height - 0.03, y) * step(stone_height, 50.0);
		albedo = mix(albedo, snow_color * 0.9, ledge * 0.8);
	} else {
		float yy = y - stone_height;
		float fy = mod(yy, floor_height);
		float fu = mod(u, post_spacing);
		float hw = beam_width * 0.5;
		// 橫梁（每層底部）、立柱
		float beam = 1.0 - smoothstep(beam_width - 0.015, beam_width + 0.015, fy);
		float post = 1.0 - smoothstep(hw * 0.8, hw * 0.8 + 0.02, abs(fu - post_spacing * 0.5));
		// 斜撐：部分格子，方向隨機
		vec2 panel = vec2(floor(u / post_spacing), floor(yy / floor_height));
		float brace = 0.0;
		if (hash(panel + 17.0) < brace_chance) {
			float s = post_spacing;
			float h = floor_height;
			float lu = hash(panel + 5.0) < 0.5 ? fu : s - fu;
			float d = abs(lu * h - fy * s) / sqrt(s * s + h * h);
			brace = 1.0 - smoothstep(hw * 0.75, hw * 0.75 + 0.02, d);
		}
		float timber = max(max(beam, post), brace) * mix(0.6, 1.0, detail);
		// 灰泥：大片髒污＋從木框往下的雨痕
		float dirt = fbm(wp * vec2(1.3, 0.7) + 4.0);
		float streak = noise(vec2(u * 3.1, y * 0.25)) * smoothstep(0.0, floor_height, floor_height - fy);
		vec3 plaster = plaster_color * mix(0.72, 1.06, dirt) * mix(1.0, 0.82, streak);
		vec3 wood = timber_color * mix(0.8, 1.15, noise(wp * vec2(9.0, 1.2)));
		albedo = mix(plaster, wood, timber);
		rough = mix(0.93, 0.72, timber);
		// 橫梁上緣積雪
		float sill = smoothstep(beam_width - 0.015, beam_width + 0.005, fy) * (1.0 - smoothstep(beam_width + 0.01, beam_width + 0.05, fy));
		albedo = mix(albedo, snow_color, sill * 0.65 * detail);
	}

	// 牆腳：濕（暗、亮面）＋一點積雪
	float damp = 1.0 - smoothstep(0.1, 0.7, y + (noise(wp * vec2(2.0, 1.0)) - 0.5) * 0.3);
	albedo *= mix(1.0, 0.6, damp);
	rough = mix(rough, 0.35, damp);
	float drift = 1.0 - smoothstep(0.08, 0.2, y - fbm(vec2(u * 0.9, 1.3)) * 0.28);
	albedo = mix(albedo, snow_color, drift * 0.9);
	rough = mix(rough, 0.85, drift);

	// 朝上的面（屋簷下沒被蓋住的牆頂、城牆頂）＝雪
	float top = smoothstep(0.6, 0.8, n.y);
	albedo = mix(albedo, snow_color, top);
	rough = mix(rough, 0.85, top);

	ALBEDO = albedo;
	ROUGHNESS = rough;
	if (top < 0.5 && abs(n.y) < 0.5) {
		vec3 t_world = side_x ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
		vec3 n_world = normalize(n + t_world * tilt.x + vec3(0.0, 1.0, 0.0) * tilt.y);
		NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	}
}
