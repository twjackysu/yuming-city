shader_type spatial;
// 屏障（第 2 章段落 5，D-161）：鐘把居民的壽命轉成的那道牆。窗外、眼睛前面一層很淡的冷光六角網格，
// 一道道慢慢掃過的光——「隔著屏障看我們」。疊加混色，不寫深度、不受燈光影響。
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec2 plane_size = vec2(12.0, 9.0);
// 六角格子多大（公尺）、線多細（格子大小的比例）
uniform float cell = 1.1;
uniform float line_w = 0.016;
uniform vec3 tint : source_color = vec3(0.55, 0.78, 1.0);
uniform float energy = 0.4;
// 整面一層很淡的光（讀得出這裡有一層東西）
uniform float haze = 0.015;
// 掃過的光：多快、多寬
uniform float sweep_speed = 0.45;
uniform float sweep_width = 1.6;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 到最近的六角格邊的距離（0＝在邊上；格子中心約 0.5）
float hex_edge(vec2 p) {
	const vec2 s = vec2(1.0, 1.7320508);
	vec4 hc = floor(vec4(p, p - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
	vec4 h = vec4(p - hc.xy * s, p - (hc.zw + 0.5) * s);
	vec2 q = dot(h.xy, h.xy) < dot(h.zw, h.zw) ? h.xy : h.zw;
	q = abs(q);
	return 0.5 - max(dot(q, s * 0.5), q.x);
}

void fragment() {
	vec2 p = (UV - 0.5) * plane_size;
	p.y = -p.y;
	float edge = hex_edge(p / cell);
	float line = smoothstep(line_w, 0.0, edge);
	// 網格不是每一段都一樣亮：大塊的明暗（有些地方幾乎看不到線）——像一道能量的膜，不是一面鐵絲網
	line *= smoothstep(0.25, 0.75, noise(p * 0.45 + vec2(3.1, 7.7)));
	// 斜斜掃過的一道光（網格在那裡亮起來）
	float band = p.x * 0.6 + p.y * 0.8 - TIME * sweep_speed;
	float sweep = 0.35 + 0.65 * smoothstep(sweep_width, 0.0, abs(mod(band, 9.0) - 4.5));
	// 四邊淡出：看不出一張四邊形的邊
	vec2 a = abs(UV - 0.5) * 2.0;
	float fade = (1.0 - smoothstep(0.7, 1.0, a.x)) * (1.0 - smoothstep(0.7, 1.0, a.y));
	ALBEDO = tint * energy * (line * sweep + haze) * fade;
}
