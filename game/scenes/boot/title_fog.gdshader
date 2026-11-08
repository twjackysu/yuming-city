shader_type canvas_item;
// 標題背景：冬夜的霜橋鎮剪影（兩層屋頂＋鐘樓）、鐘樓上的一盞暖燈、在屋頂之間流動的霧堤、暗角。
// 全部程序生成，不依賴貼圖。霧要「看得出在動」：用 smoothstep 把 fbm 壓成一塊一塊的霧堤（D-061）。

uniform vec3 sky_top : source_color = vec3(0.02, 0.03, 0.06);
uniform vec3 sky_bottom : source_color = vec3(0.09, 0.12, 0.18);
uniform vec3 glow_color : source_color = vec3(0.95, 0.72, 0.42);
uniform vec2 glow_pos = vec2(0.72, 0.335);
uniform float fog_speed = 0.015;
uniform vec3 fog_color : source_color = vec3(0.46, 0.52, 0.6);
uniform vec3 near_color : source_color = vec3(0.012, 0.016, 0.028);
uniform vec3 far_color : source_color = vec3(0.05, 0.065, 0.095);
uniform vec3 window_color : source_color = vec3(1.0, 0.7, 0.38);

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
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// 一排屋頂的高度（uv.y，越小越高）：每格一棟，山牆屋頂。
float roofline(float x, float cell, float base, float var_h, float seed) {
	float c = floor(x / cell);
	float f = fract(x / cell);
	float h = base - hash(vec2(c, seed)) * var_h;
	float peak = 0.35 + hash(vec2(c, seed + 3.1)) * 0.3;
	float roof = cell * 0.55 * (1.0 - abs(f - 0.5) * 2.0);
	// 有些房子是平頂（煙囪或塔樓的感覺留給鐘樓）
	roof *= step(0.25, hash(vec2(c, seed + 7.7)));
	return h - roof * peak * 2.2;
}

void fragment() {
	vec2 uv = UV;
	float aspect = 1.0 / max(SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y, 0.0001);
	float ax = uv.x * aspect;
	vec3 col = mix(sky_top, sky_bottom, smoothstep(0.0, 1.0, uv.y));
	float t = TIME * fog_speed;

	// 鐘樓的燈：小而亮的燈心＋柔和的光暈（之前是一大團糊光）
	vec2 d = (uv - glow_pos) * vec2(aspect, 1.0);
	float r2 = dot(d, d);
	col += glow_color * (exp(-r2 * 900.0) * 1.4 + exp(-r2 * 40.0) * 0.28 + exp(-r2 * 6.0) * 0.08);

	// 天空的高霧（很淡，緩慢）
	float sky_fog = fbm(vec2(ax * 1.6 + t * 3.0, uv.y * 2.5));
	col = mix(col, fog_color * 0.5, smoothstep(0.45, 0.8, sky_fog) * 0.18 * (1.0 - uv.y));

	// 遠的一排屋頂（被霧吃掉一半）
	float far_h = roofline(ax + 0.37, 0.085, 0.70, 0.07, 1.0);
	float far_mask = smoothstep(far_h - 0.002, far_h + 0.002, uv.y);
	col = mix(col, far_color, far_mask * 0.85);

	// 鐘樓（在遠排屋頂之後、近排之前）：塔身、尖頂、鐘室開口透出燈光
	float tx = (uv.x - glow_pos.x) * aspect;
	float tower_w = 0.034;
	float body = step(abs(tx), tower_w) * step(glow_pos.y - 0.045, uv.y);
	float spire_top = glow_pos.y - 0.14;
	float spire = step(spire_top, uv.y) * step(uv.y, glow_pos.y - 0.045)
			* step(abs(tx), tower_w * 1.2 * (uv.y - spire_top) / 0.095);
	float belfry = step(abs(tx), tower_w * 0.42) * step(glow_pos.y - 0.026, uv.y) * step(uv.y, glow_pos.y + 0.022);
	// 鐘室下的一圈簷口（比塔身寬一點）、塔基往下微微放寬，輪廓才不像一根棍子
	float ledge = step(abs(tx), tower_w * 1.28) * step(glow_pos.y + 0.03, uv.y) * step(uv.y, glow_pos.y + 0.037);
	float base_w = tower_w * (1.0 + 0.22 * smoothstep(glow_pos.y + 0.25, glow_pos.y + 0.45, uv.y));
	float footing = step(abs(tx), base_w) * step(glow_pos.y + 0.25, uv.y);
	float tower = max(max(body, spire), max(ledge, footing)) * (1.0 - belfry);
	// 塔身的石塊層（很淡的橫紋）
	float course = step(fract((uv.y - glow_pos.y) / 0.014), 0.09) * body * (1.0 - belfry) * step(glow_pos.y + 0.04, uv.y);
	col = mix(col, near_color * 1.4, tower);
	col += vec3(0.012, 0.014, 0.02) * course;
	col = mix(col, glow_color * 0.75, belfry);
	// 塔身中段兩道窄窗（樓梯間的微光，比鐘室暗很多）
	float slit_w = step(abs(tx), tower_w * 0.11);
	float slit = slit_w * (step(glow_pos.y + 0.11, uv.y) * step(uv.y, glow_pos.y + 0.13)
			+ step(glow_pos.y + 0.2, uv.y) * step(uv.y, glow_pos.y + 0.22));
	col = mix(col, glow_color * 0.32, slit);

	// 中景的霧堤：在兩排屋頂之間流動（一塊一塊，看得出在動）
	float b1 = fbm(vec2(ax * 2.2 + t * 7.0, uv.y * 5.0 - t * 1.5));
	float b2 = fbm(vec2(ax * 4.5 - t * 11.0, uv.y * 9.0 + t * 2.0));
	float bank = smoothstep(0.42, 0.72, b1 * 0.7 + b2 * 0.3);
	float band = smoothstep(0.58, 0.74, uv.y) * (1.0 - smoothstep(0.86, 1.0, uv.y) * 0.4);
	col = mix(col, fog_color, bank * band * 0.42);

	// 近的一排屋頂（最暗）＋幾扇亮著的窗
	float near_h = roofline(ax, 0.13, 0.84, 0.08, 5.0);
	float near_mask = smoothstep(near_h - 0.0015, near_h + 0.0015, uv.y);
	vec2 wcell = vec2(ax / 0.032, uv.y / 0.045);
	vec2 wf = fract(wcell);
	float lit = step(0.9, hash(floor(wcell) + vec2(11.0, 3.0)));
	float win = lit * step(0.3, wf.x) * step(wf.x, 0.7) * step(0.25, wf.y) * step(wf.y, 0.75)
			* step(0.875, uv.y);
	col = mix(col, near_color, near_mask);
	col += window_color * win * near_mask * 0.5;

	// 前景的低霧：貼著地面，比較濃、比較快
	float g1 = fbm(vec2(ax * 3.0 + t * 12.0, uv.y * 6.0 - t * 2.0));
	float ground = smoothstep(0.4, 0.75, g1) * smoothstep(0.82, 1.0, uv.y);
	col = mix(col, fog_color * 0.8, ground * 0.5);

	// 暗角
	vec2 v = uv - 0.5;
	col *= 1.0 - dot(v, v) * 1.25;

	// 微弱顆粒，避免色帶
	col += (hash(uv * 1024.0 + TIME) - 0.5) * 0.012;
	COLOR = vec4(col, 1.0);
}
