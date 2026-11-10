shader_type spatial;
// 酒館東窗的結霜玻璃（D-186）：之前中午是一整片白光、入夜是一片暗藍。
// 現在隔著結霜的玻璃看得到模糊的對街：雪地、對面房子的牆和積雪的屋頂、一扇窗（入夜點著暖光），
// 四邊結霜（越靠窗框越白、邊緣不規則）。整片都很模糊（霜玻璃），不做清楚的景深——遠看就是「外面有一條街」。
// 面內座標用物件座標（窗是 CSGBox：薄邊朝 X，pane_size＝(沿 Z 的寬, 沿 Y 的高)），從屋裡往 +X 看時 +Z 在右邊。
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec2 pane_size = vec2(1.6, 1.1);
// 1＝中午、0＝入夜
uniform float noon : hint_range(0.0, 1.0) = 1.0;
uniform float noon_energy = 1.1;
uniform float night_energy = 1.0;
uniform vec3 sky_noon : source_color = vec3(0.6, 0.65, 0.74);
uniform vec3 sky_night : source_color = vec3(0.035, 0.05, 0.1);
uniform vec3 wall_noon : source_color = vec3(0.15, 0.135, 0.13);
uniform vec3 wall_night : source_color = vec3(0.018, 0.022, 0.04);
uniform vec3 snow_noon : source_color = vec3(0.93, 0.95, 1.0);
uniform vec3 snow_night : source_color = vec3(0.07, 0.09, 0.15);
uniform vec3 lamp_color : source_color = vec3(1.0, 0.6, 0.28);
uniform float lamp_energy = 2.4;
uniform vec3 frost_noon : source_color = vec3(0.95, 0.97, 1.0);
uniform vec3 frost_night : source_color = vec3(0.16, 0.19, 0.27);
// 結霜從窗框往中間長多深（0..0.5）
uniform float frost_depth = 0.15;
// 整片玻璃的霧化（0＝清楚、1＝只看得到霜）
uniform float haze = 0.1;
// 模糊程度（邊界的柔化寬度，0..1 的面內座標）
uniform float blur = 0.04;

varying vec3 obj_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.07;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	// u：從屋裡看的左→右、v：下→上
	vec2 uv = vec2(obj_pos.z / pane_size.x + 0.5, obj_pos.y / pane_size.y + 0.5);
	float b = blur;
	// 對街：雪地（最下面一條）、牆、積雪的屋頂（人字形，屋脊偏左）、上面是陰天
	float ridge_u = 0.36;
	float roof_line = 0.83 - 0.42 * abs(uv.x - ridge_u);
	float eave = 0.58;
	float ground = 0.13 + 0.025 * sin(uv.x * 5.0 + 1.3);
	float is_sky = smoothstep(roof_line - b, roof_line + b, uv.y);
	float is_roof = smoothstep(eave - b, eave + b, uv.y) * (1.0 - is_sky);
	float is_ground = 1.0 - smoothstep(ground - b, ground + b, uv.y);
	float is_wall = (1.0 - is_sky) * (1.0 - is_roof) * (1.0 - is_ground);
	// 煙囪（屋脊右邊一點）
	float chim = (1.0 - smoothstep(0.035 - b * 0.5, 0.035 + b * 0.5, abs(uv.x - 0.5))) * smoothstep(roof_line - b, roof_line + b * 0.5, uv.y)
			* (1.0 - smoothstep(0.86 - b, 0.86 + b, uv.y));
	// 對面的窗（右下）：中午是暗的、入夜點著燈
	vec2 wc = vec2(0.7, 0.34);
	vec2 wd = abs(uv - wc) - vec2(0.07, 0.085);
	float win = (1.0 - smoothstep(-b, b, max(wd.x, wd.y))) * is_wall;

	vec3 sky = mix(sky_night, sky_noon, noon);
	vec3 wall = mix(wall_night, wall_noon, noon);
	vec3 snow = mix(snow_night, snow_noon, noon);
	// 天空上亮下暗一點（雲層）、牆面一點點不均（半木構的影子，模糊成斑）
	sky *= 0.92 + 0.12 * uv.y;
	wall *= 0.85 + 0.3 * fbm(uv * vec2(6.0, 3.0));
	// 屋簷下的一道陰影（讓屋頂和牆分得開）
	float eave_shadow = (1.0 - smoothstep(0.0, 0.09, eave - uv.y)) * is_wall;
	wall *= 1.0 - 0.45 * eave_shadow;
	vec3 col = sky * is_sky + snow * is_roof + snow * 0.92 * is_ground + wall * is_wall;
	col = mix(col, wall * 0.8, chim);
	vec3 dark_win = wall * 0.45;
	vec3 lit_win = lamp_color * lamp_energy;
	col = mix(col, mix(lit_win, dark_win, noon), win);
	// 霧化：整片往霜的顏色拉一點
	vec3 frost = mix(frost_night, frost_noon, noon);
	col = mix(col, frost * 0.85, haze);
	// 四邊結霜：離窗框越近越白；邊緣用 fbm 弄得不規則，再加一點細的冰晶
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y) * 1.3);
	float n = fbm(uv * vec2(9.0, 6.5) + vec2(3.1, 7.7));
	float crystals = vnoise(uv * vec2(60.0, 42.0));
	float frost_mask = 1.0 - smoothstep(frost_depth * 0.35, frost_depth, edge + (n - 0.5) * 0.14);
	// 下緣的霜比較厚（水氣往下流）
	frost_mask = max(frost_mask, (1.0 - smoothstep(0.03, 0.12 + 0.06 * n, uv.y)) * 0.8);
	col = mix(col, frost * (0.9 + 0.2 * crystals), clamp(frost_mask, 0.0, 1.0));
	ALBEDO = col * mix(night_energy, noon_energy, noon);
}
