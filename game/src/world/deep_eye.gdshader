shader_type spatial;
// 窗外的眼睛（第 2 章段落 5，D-161）：伊薩拉開鐘院內室的窗簾，玻璃之外一堵黑色的牆動了一下——那是一隻眼睛（吞日獸）。
// 一張大的四邊形，面向內室；整張都是程序畫的：皺褶的黑色皮膚、杏仁形的眼眶、暗金的虹膜、慢慢收縮的瞳孔、
// 反射屏障冷光的一點濕亮。不受燈光影響（unshaded），亮度全在這裡決定。
// 動作由腳本推（eye_open／pupil／shift），截圖與測試可以停在任何一刻；TIME 只用在很慢的呼吸。
// fog_disabled：關卡的體積霧會把整面黑牆洗成灰的（第 44 輪截圖），眼睛自己決定亮度。
render_mode unshaded, cull_disabled, fog_disabled;

// 四邊形的大小（公尺）；UV 換成以中心為原點的公尺座標（x 往右、y 往上）
uniform vec2 plane_size = vec2(18.0, 12.0);
// 眼睛的中心（公尺，相對四邊形中心）、半寬、最大半高
uniform vec2 eye_center = vec2(0.0, 0.0);
uniform float eye_half_w = 2.1;
uniform float eye_half_h = 1.05;
uniform float iris_r = 0.95;
// 0＝閉著（只是一堵牆），1＝睜開
uniform float eye_open : hint_range(0.0, 1.0) = 0.0;
// 1＝瞳孔放大（剛睜開），0＝收縮成一道縫（看清楚我們了）
uniform float pupil : hint_range(0.0, 1.0) = 1.0;
// 整面牆往上移了多少（公尺）：「動了一下」
uniform float shift = 0.0;

uniform vec3 skin_dark : source_color = vec3(0.008, 0.009, 0.012);
uniform vec3 skin_lit : source_color = vec3(0.05, 0.065, 0.085);
uniform vec3 iris_color : source_color = vec3(0.55, 0.34, 0.1);
uniform vec3 iris_glow : source_color = vec3(1.0, 0.62, 0.2);
uniform float iris_energy = 0.95;
// 屏障的冷光（跟 barrier_grid 同色）：照在皮膚上方、眼睛上的濕亮
uniform vec3 barrier_tint : source_color = vec3(0.55, 0.78, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
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

void fragment() {
	vec2 p = (UV - 0.5) * plane_size;
	p.y = -p.y;
	// 很慢的呼吸：整面皮膚上下一點點
	float breathe = sin(TIME * 0.35) * 0.03;
	p.y -= shift + breathe;
	vec2 e = p - eye_center;

	// 皮膚：繞著眼睛一圈圈的皺褶＋大塊起伏；上方被屏障的冷光照到一點
	float r = length(e * vec2(0.55, 1.0));
	float w = fbm(p * 0.7);
	float folds = 0.5 + 0.5 * sin(r * 4.2 + w * 5.0);
	float near_eye = smoothstep(8.0, 2.2, r);
	vec3 col = mix(skin_dark, skin_lit, pow(folds, 4.0) * near_eye * 0.8 + w * 0.22);
	col += barrier_tint * 0.012 * smoothstep(-5.0, 5.0, p.y);

	// 眼眶：杏仁形，|y| < 半高 ×(1 − x²)
	float hx = clamp(e.x / eye_half_w, -1.0, 1.0);
	float lid = eye_half_h * (1.0 - hx * hx) * eye_open;
	float gap = lid - abs(e.y);
	float inside = smoothstep(0.0, 0.035, gap) * step(abs(e.x), eye_half_w);

	// 虹膜：暗金色、放射狀的紋路、靠瞳孔那圈微微發光
	float ir = length(e);
	float ang = atan(e.y, e.x);
	float stri = fbm(vec2(ang * 5.0, ir * 2.5));
	vec3 iris = mix(iris_color * 0.25, iris_color, smoothstep(iris_r, iris_r * 0.3, ir)) * (0.55 + 0.9 * stri);
	iris += iris_glow * 0.35 * smoothstep(0.35, 0.0, abs(ir - iris_r * 0.5)) * (0.4 + 0.6 * stri);
	iris *= iris_energy;
	// 瞳孔：直立的橢圓，越收越窄
	float pw = mix(0.1, 0.6, pupil);
	float pd = length(e / vec2(pw, iris_r * 0.85));
	iris = mix(iris, vec3(0.0), smoothstep(1.05, 0.92, pd));
	// 虹膜外面：很暗、濕濕的
	vec3 sclera = vec3(0.025, 0.02, 0.016) + iris_color * 0.025 * smoothstep(eye_half_w, iris_r, ir);
	vec3 eye_col = mix(sclera, iris, smoothstep(iris_r + 0.03, iris_r - 0.03, ir));
	// 上眼皮的陰影：靠眼眶上緣暗一點
	eye_col *= mix(0.35, 1.0, smoothstep(0.0, 0.3 * eye_half_h, lid - e.y));
	// 濕亮：屏障的冷光反在眼球上
	float hl = smoothstep(0.14, 0.0, length(e - vec2(-0.32, 0.36)));
	hl += 0.35 * smoothstep(0.07, 0.0, length(e - vec2(0.28, -0.3)));
	eye_col += barrier_tint * hl * 1.8 * step(0.02, gap);
	col = mix(col, eye_col, inside);
	// 眼眶邊緣一圈濕光
	float rim = smoothstep(0.05, 0.0, abs(gap)) * step(abs(e.x), eye_half_w) * eye_open;
	col += barrier_tint * 0.06 * rim;
	ALBEDO = col;
}
