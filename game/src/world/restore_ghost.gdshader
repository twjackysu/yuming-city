shader_type spatial;
// 重現的預覽輪廓（按住 V 時，D-046）：不是平的半透明塊，而是邊緣亮、石縫隱約可見的冷光輪廓，
// 而且隨著按住的進度從地面往上「長」出來（fill 0→1），最上緣有一道亮線。按滿就是 activate()。
// 還沒長到的部分只有淡淡的邊緣輪廓（D-125：一開始就看得出整座拱的形狀，不會只看到兩根柱子）。
// 加法混合、不寫深度、不受光（在去飽和前的暗夜裡也看得清楚）。
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec3 color : source_color = vec3(0.62, 0.86, 1.0);
// 按住進度 0～1
uniform float fill : hint_range(0.0, 1.0) = 0.0;
// 物件的高度（世界座標，從物件底部算）
uniform float height = 4.6;
uniform float base_y = 0.0;
uniform float block_scale = 1.25;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float h = (world_pos.y - base_y) / height;
	// 往上長：fill 以上只剩淡淡的輪廓，邊界有一道亮線
	float level = fill * 1.04;
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 2.5);
	if (h > level) {
		float faint = 0.05 + 0.3 * fres;
		ALBEDO = color * faint;
		ALPHA = clamp(faint, 0.0, 1.0);
	} else {
		float edge_line = 1.0 - smoothstep(0.0, 0.035, level - h);
		// 石縫：跟石牆一樣錯位的石塊（只取灰縫）
		vec3 n = normalize(world_normal);
		float u = abs(n.x) > abs(n.z) ? world_pos.z : world_pos.x;
		float bh = 0.36 * block_scale;
		float bw = 0.66 * block_scale;
		float row = floor(world_pos.y / bh);
		float uu = u / bw + mod(row, 2.0) * 0.5;
		vec2 f = vec2(fract(uu), fract(world_pos.y / bh));
		vec2 dm = min(f, 1.0 - f) * vec2(bw, bh);
		float seam = 1.0 - smoothstep(0.012, 0.03, min(dm.x, dm.y));
		float k = 0.04 + 0.55 * fres + 0.22 * seam + 1.2 * edge_line;
		ALBEDO = color * k;
		ALPHA = clamp(k, 0.0, 1.0);
	}
}
