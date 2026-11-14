shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
// 反轉的畫面回饋（ReversalOverlay）：畫面邊緣的紫紅（被詛咒）→ 像玻璃一樣裂開、一片一片掉 → 金光。
// 三個數字都是 ReversalCue 給的 0～1。中間留空，不擋到角色。

uniform float curse = 0.0;
uniform float shatter = 0.0;
uniform float gold = 0.0;
uniform float aspect = 1.7778;
uniform vec3 curse_inner : source_color = vec3(0.62, 0.16, 0.9);
uniform vec3 curse_outer : source_color = vec3(0.42, 0.02, 0.12);
uniform vec3 gold_color : source_color = vec3(1.0, 0.8, 0.32);
uniform vec3 crack_color : source_color = vec3(1.0, 0.95, 0.78);

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

void fragment() {
	vec2 c = UV - 0.5;
	// 0＝畫面中間，1 左右＝角落
	float d = length(c * vec2(1.0, 0.86)) * 1.8;
	float edge = smoothstep(0.42, 1.02, d);

	// 碎片：Voronoi 的格子，每一格有自己的亂數
	vec2 p = vec2(UV.x * aspect, UV.y) * 6.5;
	vec2 ip = floor(p);
	vec2 fp = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 cell = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + hash2(ip + g) - fp;
			float dd = dot(r, r);
			if (dd < d1) {
				d2 = d1;
				d1 = dd;
				cell = ip + g;
			} else if (dd < d2) {
				d2 = dd;
			}
		}
	}
	float rnd = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float seam = 1.0 - smoothstep(0.0, 0.07, sqrt(d2) - sqrt(d1));
	// 這一片掉了沒：每一片的時間不一樣，掉之前先亮一下
	float fall_at = 0.12 + rnd * 0.75;
	float gone = step(fall_at, shatter);
	float about = smoothstep(fall_at - 0.25, fall_at, shatter) * (1.0 - gone);
	float cracking = step(0.001, shatter);

	// 紫紅：往角落越來越暗紅；每一片的深淺差一點（碎裂前就隱約看得到紋路）
	float veil = edge * curse * (0.78 + 0.22 * rnd) * (1.0 - gone);
	vec3 curse_rgb = mix(curse_inner, curse_outer, smoothstep(0.55, 1.15, d));
	vec3 rgb = curse_rgb * veil * 0.9;
	float a = veil * 0.82;

	// 裂痕與快掉的碎片：亮的金白色（加亮，不蓋住底下）
	float crack = seam * edge * curse * cracking * (1.0 - gone) * (1.0 - shatter * 0.5);
	rgb += crack_color * (crack * 0.9 + about * edge * curse * 0.38);

	// 金光：邊緣一圈＋碎裂那一下整個畫面很淡地亮一下
	float glow = smoothstep(0.5, 1.1, d) * gold;
	float flash = gold * gold * gold * 0.09;
	rgb += gold_color * (glow * 0.62 + flash);
	a += glow * 0.12;

	COLOR = vec4(rgb, clamp(a, 0.0, 1.0));
}
