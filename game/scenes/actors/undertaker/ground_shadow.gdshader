shader_type spatial;
// 腳下的接地陰影（D-101）：送葬者在霧裡像浮在石板上（夜裡月光的影子被霧吃掉）。
// 一片貼地的圓，中間最暗、往外柔和淡出；黑色＋透明度，所以照樣被霧蓋住（遠處不會突兀一塊黑）。
// 前兆範圍（telegraph，y 0.03）畫在它上面。
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform float strength : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float a = 1.0 - smoothstep(0.1, 1.0, d);
	ALBEDO = vec3(0.0);
	ALPHA = strength * a * a;
}
