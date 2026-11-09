shader_type spatial;
// 室內的木板（第 53 輪，酒館的地板、天花板、桌面、吧台）：世界座標，不靠 UV（CSGBox 的 UV 一面一張，
// 地板 15 m 寬會把四片木板拉成三公尺寬）。
// - 水平面：木板沿 X（along_z＝true 改沿 Z），每片寬 plank_width、長 plank_length 上下浮動，
//   每排接縫錯開；板縫暗、每片顏色略不同、沿板子方向的木紋＋偶爾一個節疤
// - 垂直面：木板橫排（沿牆的方向），寬 plank_width
// - 地板（wear＞0）：常走的地方磨得比較亮、比較滑；門口一片雪水（wet_spot：中心 xz、半徑、強度）
// - 只有木紋、沒有板縫：plank_width 設大（例如 4）＝整根木頭（橫樑、桌腳）

uniform vec3 wood_color : source_color = vec3(0.3, 0.21, 0.14);
uniform float plank_width = 0.2;
uniform float plank_length = 1.8;
uniform bool along_z = false;
// 垂直面的木板直排（門板、吧台正面）；預設橫排
uniform bool vertical_planks = false;
uniform float seam_dark : hint_range(0.0, 1.0) = 0.7;
uniform float wear : hint_range(0.0, 1.0) = 0.0;
uniform float base_roughness = 0.78;
uniform vec4 wet_spot = vec4(0.0, 0.0, 0.0, 0.0);

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
	bool flat_face = abs(n.y) > 0.5;
	// along＝沿著木板、across＝橫過木板
	float along;
	float across;
	if (flat_face) {
		along = along_z ? world_pos.z : world_pos.x;
		across = along_z ? world_pos.x : world_pos.z;
	} else {
		float horiz = abs(n.x) > abs(n.z) ? world_pos.z : world_pos.x;
		along = vertical_planks ? world_pos.y : horiz;
		across = vertical_planks ? horiz : world_pos.y;
	}
	vec2 wp = vec2(along, across);
	float px = length(fwidth(wp));
	float detail = 1.0 - smoothstep(0.02, 0.07, px);

	float row = floor(across / plank_width);
	float fa = fract(across / plank_width);
	// 每排的接縫錯開、板長上下浮動
	float len = plank_length * mix(0.7, 1.3, hash(vec2(row, 7.0)));
	float shifted = along / len + hash(vec2(row, 13.0));
	float seg = floor(shifted);
	float fl = fract(shifted);
	vec2 cell = vec2(seg, row);
	float aa = px * 1.5;
	float side_seam = 1.0 - smoothstep(0.0, 0.012 + aa, min(fa, 1.0 - fa) * plank_width);
	float end_seam = 1.0 - smoothstep(0.0, 0.01 + aa, min(fl, 1.0 - fl) * len);
	float seam = max(side_seam, end_seam) * detail;

	// 每片顏色：深淺、偏紅偏灰
	float tone = mix(0.78, 1.14, hash(cell));
	float warm = hash(cell + 31.0);
	vec3 col = wood_color * tone * mix(vec3(0.95, 0.97, 1.02), vec3(1.06, 0.98, 0.9), warm);
	// 木紋：沿板子方向拉長的條紋，用雜訊扭一下
	float g_coord = (across * 38.0 + hash(cell) * 9.0) + fbm(vec2(along * 0.7, across * 6.0) + cell) * 3.2;
	float grain = 0.5 + 0.5 * sin(g_coord * 3.14159);
	grain = mix(0.9, 1.06, grain);
	col *= mix(1.0, grain, detail);
	// 偶爾一個節疤
	float knot_h = hash(cell + 57.0);
	if (knot_h > 0.7) {
		vec2 kc = vec2((0.2 + 0.6 * hash(cell + 3.0)) * len, (0.3 + 0.4 * hash(cell + 9.0)) * plank_width);
		vec2 kp = vec2(fl * len, fa * plank_width) - kc;
		float kd = length(kp * vec2(0.45, 1.0));
		col *= mix(0.55, 1.0, smoothstep(0.012, 0.03, kd)) * mix(0.92, 1.0, smoothstep(0.03, 0.07, kd) * detail + (1.0 - detail));
	}
	float rough = base_roughness;
	// 磨損：常走的地方顏色淡一點、比較亮滑（大片 fbm，不是每片）
	float worn = smoothstep(0.42, 0.7, fbm(world_pos.xz * 0.35 + 2.0)) * wear;
	col = mix(col, col * 1.18 + vec3(0.02, 0.015, 0.01), worn * 0.6);
	rough = mix(rough, 0.48, worn);
	// 板縫：暗、粗
	col *= 1.0 - seam * seam_dark;
	rough = mix(rough, 0.95, seam);
	// 門口的雪水：暗、亮
	if (wet_spot.z > 0.0 && flat_face) {
		float d = length(world_pos.xz - wet_spot.xy) / wet_spot.z;
		float wet = (1.0 - smoothstep(0.55, 1.0, d + (fbm(world_pos.xz * 2.2) - 0.5) * 0.5)) * wet_spot.w;
		col *= mix(1.0, 0.62, wet);
		rough = mix(rough, 0.2, wet);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	// 板縫凹下去：法線往兩邊倒一點（只有近處）
	if (detail > 0.01) {
		float tilt_a = (fa - 0.5) * smoothstep(0.38, 0.5, abs(fa - 0.5)) * 0.6 * detail;
		vec3 t_across;
		if (flat_face) {
			t_across = along_z ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 0.0, 1.0);
		} else if (vertical_planks) {
			t_across = abs(n.x) > abs(n.z) ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
		} else {
			t_across = vec3(0.0, 1.0, 0.0);
		}
		vec3 nw = normalize(n + t_across * tilt_a);
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	}
}
