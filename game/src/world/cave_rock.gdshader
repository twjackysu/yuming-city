shader_type spatial;
// 岩洞的岩面（地下市場的洞壁、洞頂、高台的側面，D-229）：不是砌的石塊——
// 一大塊一大塊不規則的岩石，每一塊的面朝的方向都不太一樣（暖燈一照，有的面亮、有的面暗），
// 塊與塊之間是深色的裂縫，上面再疊細的凹凸、礦物的黃褐色與一片片往下流的潮濕。
// 全部用世界座標算，不用 UV；牆是軸向的方塊，直接挑法線最大的那一軸當投影面。
// 靜態：不用 TIME。

uniform vec3 rock_color : source_color = vec3(0.17, 0.16, 0.15);
uniform vec3 crevice_color : source_color = vec3(0.022, 0.02, 0.02);
uniform vec3 damp_color : source_color = vec3(0.06, 0.066, 0.072);
// 一塊岩石的寬（公尺）；chunk_squash＞1＝橫向比較長（一層一層的岩層）
uniform float chunk_size = 1.7;
uniform float chunk_squash = 1.45;
// 每一塊的面偏多少、塊的邊緣鼓多少
uniform float facet_strength : hint_range(0.0, 1.5) = 0.62;
uniform float rim_strength : hint_range(0.0, 1.5) = 0.45;
uniform float crevice_width : hint_range(0.01, 0.5) = 0.085;
// 細的凹凸、深淺
uniform float bump_strength : hint_range(0.0, 0.2) = 0.07;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.42;
uniform float damp_amount : hint_range(0.0, 1.0) = 0.6;
uniform float base_roughness : hint_range(0.0, 1.0) = 0.9;

varying vec3 wpos;
varying vec3 wnrm;

vec2 hash22(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm3(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v / 0.875;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 an = abs(n);
	// 投影面：法線最大的那一軸；tu、tv＝那個面上 uv 兩個方向對應的世界方向
	vec2 uv;
	vec3 tu;
	vec3 tv;
	if (an.x >= an.y && an.x >= an.z) {
		uv = wpos.zy;
		tu = vec3(0.0, 0.0, 1.0);
		tv = vec3(0.0, 1.0, 0.0);
	} else if (an.y >= an.z) {
		uv = wpos.xz;
		tu = vec3(1.0, 0.0, 0.0);
		tv = vec3(0.0, 0.0, 1.0);
	} else {
		uv = wpos.xy;
		tu = vec3(1.0, 0.0, 0.0);
		tv = vec3(0.0, 1.0, 0.0);
	}
	// 一個像素蓋到多大一塊岩面（公尺）：很斜、很遠的地方把細的凹凸收掉，不然會閃
	float footprint = max(length(dFdx(uv)), length(dFdy(uv)));
	float detail = 1.0 - smoothstep(0.03, 0.12, footprint);

	// 大塊：座標先扭一下（裂縫不是直線），再做 Voronoi
	vec2 p = uv / chunk_size;
	p.y *= chunk_squash;
	p += (vec2(vnoise(p * 0.9 + 3.7), vnoise(p * 0.9 + 41.2)) - 0.5) * 0.75;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 near_off = vec2(0.0);
	vec2 near_id = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + hash22(cell + g) - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				near_off = r;
				near_id = cell + g;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	d1 = sqrt(d1);
	d2 = sqrt(d2);
	float edge = d2 - d1;  // 0＝兩塊的交界
	float crevice = 1.0 - smoothstep(0.0, crevice_width, edge);
	float rim = 1.0 - smoothstep(0.0, 0.4, edge);
	// 每一塊：面偏一個方向、深淺不一樣；邊緣往外倒（鼓起來的石頭）
	vec2 tilt = hash22(near_id + 7.31) - 0.5;
	float tone = hash21(near_id + 2.17);
	vec2 away = -near_off / max(d1, 0.001);
	away.y *= chunk_squash;
	vec2 bend = tilt * 2.0 * facet_strength + normalize(away + vec2(0.0001)) * rim * rim_strength;

	// 細的凹凸：用高度的螢幕空間導數推法線
	float g1 = fbm3(uv * 2.3 + near_id * 3.1);
	float g2 = fbm3(uv * 7.5 + 5.0);
	float h = (g1 * 0.7 + g2 * 0.3) * bump_strength * detail;
	vec3 dpx = dFdx(wpos);
	vec3 dpy = dFdy(wpos);
	float dhx = dFdx(h);
	float dhy = dFdy(h);
	vec3 r1 = cross(dpy, n);
	vec3 r2 = cross(n, dpx);
	float det = dot(dpx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	vec3 wn = normalize(abs(det) * n - grad);
	wn = normalize(wn + (tu * bend.x + tv * bend.y) * 0.5);

	// 顏色：每一塊的深淺 × 顆粒 × 礦物的黃褐；潮濕的地方深、比較亮滑
	vec3 col = rock_color * mix(0.72, 1.28, tone);
	col *= mix(1.0 - grain_strength, 1.0 + grain_strength * 0.45, g1);
	col = mix(col, col * vec3(1.2, 1.02, 0.8), smoothstep(0.5, 0.78, g2) * 0.55 * detail);
	float damp = smoothstep(0.5, 0.7, fbm3(uv * vec2(0.8, 0.26) + 13.0)) * damp_amount;
	col = mix(col, damp_color, damp * 0.8);
	col *= mix(1.0, 0.6, rim * 0.7);
	col = mix(col, crevice_color, crevice);

	ALBEDO = col;
	ROUGHNESS = mix(base_roughness, 0.4, damp * (1.0 - crevice));
	SPECULAR = 0.4;
	AO = 1.0 - crevice * 0.75;
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
