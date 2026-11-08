shader_type spatial;
// 窗（D-066）：深色木窗框＋十字窗櫺＋玻璃，取代原本一整塊發光的長方形。
// - 亮窗：暖光從窗心往外漸暗、窗框內緣有一圈陰影；每扇窗的亮度與色溫不同（偏黃／偏橘）；
//   有些拉了半邊窗簾（布料擋住的地方暗一點、偏紅，有幾道褶）
// - 暗窗：深色玻璃（光滑，映得出路燈與 probe 裡的亮窗）
// 每扇窗的資料放在頂點色（StaticBatch.add_box_tinted）：
//   r＝亮（1）／暗（0）、g＝0..1 色溫與窗簾方向、b＝窗簾比例（0＝沒拉）、a＝亮度（× 4 是發光強度）
// 面內座標：BoxMesh 每個面佔 UV 的 1/3 × 1/2 格，fract(UV × (3, 2)) 就是面內 0..1（y=0 在上）。

uniform vec3 glow_color : source_color = vec3(0.95, 0.72, 0.42);
uniform vec3 frame_color : source_color = vec3(0.12, 0.088, 0.064);
uniform vec3 dark_glass : source_color = vec3(0.03, 0.036, 0.05);
uniform float frame_width = 0.085;
uniform float bar_width = 0.04;
// 橫的窗櫺在中間偏上（上窗格小、下窗格大）
uniform float bar_height = 0.42;

void fragment() {
	vec2 l = fract(UV * vec2(3.0, 2.0));
	float lit = step(0.5, COLOR.r);
	float vary = COLOR.g;
	float curtain = COLOR.b;
	float energy = COLOR.a * 4.0;

	vec2 d = min(l, 1.0 - l);
	float aa = max(fwidth(l.x), fwidth(l.y)) * 1.2;
	float frame = 1.0 - smoothstep(frame_width, frame_width + aa, min(d.x, d.y));
	float bar_v = 1.0 - smoothstep(bar_width * 0.5, bar_width * 0.5 + aa, abs(l.x - 0.5));
	float bar_h = 1.0 - smoothstep(bar_width * 0.5, bar_width * 0.5 + aa, abs(l.y - bar_height));
	float wood = max(frame, max(bar_v, bar_h));

	// 玻璃的光：窗心最亮、往外漸暗；靠窗框與窗櫺的地方有一圈陰影（窗框有厚度）
	vec2 c = (l - vec2(0.5, 0.56)) * vec2(1.25, 1.0);
	float falloff = 1.0 - clamp(length(c) * 1.15, 0.0, 1.0) * 0.5;
	float inner = min(min(d.x, d.y) - frame_width, min(abs(l.x - 0.5), abs(l.y - bar_height)) - bar_width * 0.5);
	float rim = mix(0.62, 1.0, smoothstep(0.0, 0.07, inner));
	vec3 warm = mix(glow_color, glow_color * vec3(1.05, 0.84, 0.62), vary);
	vec3 emit = warm * energy * falloff * rim;

	// 窗簾：從左或右拉過來（看 vary），布料透光較暗、偏紅，幾道垂直的褶
	float side_x = vary > 0.5 ? l.x : 1.0 - l.x;
	float in_curtain = 1.0 - smoothstep(curtain - aa, curtain + aa, side_x);
	float folds = 0.78 + 0.22 * sin(side_x * 62.0 + vary * 9.0);
	emit = mix(emit, warm * vec3(0.9, 0.55, 0.42) * energy * 0.32 * folds, in_curtain);

	vec3 glass_albedo = mix(dark_glass, warm * 0.5, lit);
	ALBEDO = mix(glass_albedo, frame_color, wood);
	// 窗框被屋裡的光從內側照到一點點
	EMISSION = mix(emit * lit, warm * energy * 0.035 * lit, wood);
	ROUGHNESS = mix(mix(0.07, 0.55, lit), 0.85, wood);
	SPECULAR = mix(0.65, 0.3, wood);
}
