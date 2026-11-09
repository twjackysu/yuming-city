shader_type spatial;
// 乾掉的河床（第 55 輪，乾運河，D-173）：世界座標的龜裂泥塊——Voronoi 的邊界＝裂縫（格子先用雜訊扭過，不會是整齊的多邊形），
// 每塊顏色略不同、邊緣微微翹起（法線往裂縫倒）；河床中間一條還沒乾的濕泥（wet_x 中心、wet_half 半寬）：暗、亮、沒有裂縫。
// 只畫朝上的面；側面當成一般的泥。遠處（每像素超過幾公分）裂縫淡掉，避免閃。

uniform vec3 mud_color : source_color = vec3(0.16, 0.135, 0.115);
uniform vec3 crack_color : source_color = vec3(0.025, 0.021, 0.019);
uniform float cell_size = 0.5;
uniform float crack_width = 0.02;
uniform float wet_x = -0.3;
uniform float wet_half = 0.9;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash2(vec2 p) {
	return vec2(hash(p), hash(p + 17.31));
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

// 到最近格子邊界的距離（格子單位）、那一格的雜湊、往格子中心的方向。
vec4 cells(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) * 0.85 + 0.075 - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mr = r;
				mg = g;
			}
		}
	}
	md = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) * 0.85 + 0.075 - f;
			if (dot(mr - r, mr - r) > 0.00001) {
				md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
			}
		}
	}
	return vec4(md, hash(n + mg + 3.7), mr);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec2 wp = world_pos.xz;
	float px = length(fwidth(wp));
	float detail = 1.0 - smoothstep(0.03, 0.1, px);
	float up = step(0.5, n.y);

	// 裂縫：格子用低頻雜訊扭一下，再加一層大一倍的格子當主裂縫（大塊裡再裂成小塊）
	vec2 warp = (vec2(fbm(wp * 0.9), fbm(wp * 0.9 + 7.0)) - 0.5) * 0.7;
	vec4 small = cells(wp / cell_size + warp);
	vec4 big = cells(wp / (cell_size * 2.6) + warp * 0.5 + 11.0);
	float d_small = small.x * cell_size;
	float d_big = big.x * cell_size * 2.6;

	// 還沒乾的那一條：邊緣不規則
	float wd = abs(world_pos.x - wet_x) + (fbm(vec2(world_pos.z * 0.45, 3.0)) - 0.5) * 0.9;
	float wet = 1.0 - smoothstep(wet_half * 0.55, wet_half, wd);
	float dry = (1.0 - wet) * up;

	float cw = crack_width * mix(0.5, 1.5, noise(wp * 2.3)) * dry;
	float crack_s = 1.0 - smoothstep(cw * 0.4, cw * 0.4 + 0.004 + px, d_small);
	float crack_b = 1.0 - smoothstep(cw * 0.9, cw * 0.9 + 0.006 + px, d_big);
	float crack = max(crack_s * 0.85, crack_b) * detail * dry;
	crack = max(crack, crack_b * 0.5 * (1.0 - detail) * dry);

	// 每塊泥的顏色：深淺、偏灰偏黃；乾的地方表面一層淡淡的灰白（鹽霜／乾土）
	vec3 col = mud_color * mix(0.78, 1.18, small.y) * mix(0.85, 1.1, fbm(wp * 1.4 + 2.0));
	float crust = smoothstep(0.45, 0.75, fbm(wp * 0.6 + 5.0)) * dry;
	col = mix(col, col * 1.35 + vec3(0.02, 0.02, 0.018), crust * 0.6);
	// 翹起的邊緣接到光，亮一點
	float lip = (1.0 - smoothstep(0.0, 0.07, d_small - cw * 0.4)) * (1.0 - crack_s) * detail * dry;
	col *= 1.0 + lip * 0.18;
	col = mix(col, crack_color, crack);
	// 濕泥：暗、亮
	col = mix(col, mud_color * 0.42, wet * up);
	float rough = mix(0.93, 0.22, wet * up);
	rough = mix(rough, 1.0, crack);

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = mix(0.35, 0.6, wet * up);

	// 泥塊邊緣往裂縫倒（翹起）
	if (up > 0.5 && detail > 0.01) {
		float edge = (1.0 - smoothstep(0.0, 0.09, d_small)) * detail * dry;
		vec2 t = -normalize(small.zw + vec2(0.0001)) * edge * 0.55;
		vec3 nw = normalize(vec3(t.x, 1.0, t.y));
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	}
}
