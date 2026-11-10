shader_type spatial;
// 送葬者招式前兆的地面範圍（D-088）：原本是一整片平塗的霜藍色塊（加法混合、透明度隨前兆變大，
// 近看像地上貼了一塊淺藍色的板子）。改成：
// - 邊緣一道亮的霜藍細線（範圍一眼看得出來）
// - 裡面很淡的底色
// - 前兆進度從敵人那一端往外「填滿」，填滿的前緣一條亮線——填到邊緣就是要打下來了
// 形狀用模型座標算（三種 mesh 都沒有 UV）：0＝圓（下砸）、1＝長條（衝撞，敵人在 +Z 端）、2＝扇形（橫掃、抓取，朝 -Z）、
// 3＝落點標記（噴毒，D-208）：一圈慢慢轉的虛線＋從中心往外擴的一道細圈，裡面不填色——
//   地上「要噴了」的記號是一個空心的虛線圈，「已經噴了」的毒霧是一團實心的綠霧，一眼分得出來。
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(0.55, 0.82, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int shape = 0;
// 圓、扇形：x＝半徑；長條：x＝半寬、y＝半長
uniform vec2 extent = vec2(1.0, 1.0);
uniform float half_arc = 0.785;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float edge;    // 到邊界的距離（公尺），裡面是正的
	float fill_t;  // 0＝敵人那一端，1＝最遠的邊
	if (shape == 0 || shape == 3) {
		float d = length(lp.xz);
		edge = extent.x - d;
		fill_t = d / max(extent.x, 0.001);
	} else if (shape == 1) {
		edge = min(extent.x - abs(lp.x), extent.y - abs(lp.z));
		fill_t = (extent.y - lp.z) / max(2.0 * extent.y, 0.001);
	} else {
		float d = length(lp.xz);
		float a = abs(atan(lp.x, -lp.z));
		edge = min(extent.x - d, (half_arc - a) * max(d, 0.05));
		fill_t = d / max(extent.x, 0.001);
	}
	float p = clamp(progress, 0.0, 1.0);
	float rim = 1.0 - smoothstep(0.0, 0.07, edge);
	float filled = 1.0 - smoothstep(p - 0.05, p, fill_t);
	if (shape == 3) {
		// 虛線：16 段、慢慢轉；線比其他前兆粗一點（遠看才看得出是一段一段的）
		float dash = smoothstep(0.42, 0.5, abs(fract(atan(lp.x, lp.z) / 6.2832 * 16.0 + TIME * 0.5) - 0.5) * 2.0);
		rim = (1.0 - smoothstep(0.0, 0.13, edge)) * (1.0 - dash);
		filled = 0.0;
	}
	float front = (1.0 - smoothstep(0.0, 0.035, abs(fill_t - p))) * (1.0 - step(0.995, p));
	// D-098：裡面的底色與填滿減半（盤點截圖裡一整片亮扇形蓋住畫面下三分之一）；邊線與前緣亮線不變，範圍與剩多久照樣一眼看得出來
	float a = rim * (0.5 + 0.5 * p) + 0.02 + filled * (0.035 + 0.085 * p) + front * 0.45;
	ALBEDO = tint;
	ALPHA = clamp(a, 0.0, 1.0);
}
