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
// 拱圈（D-132，跟 half_timber 同一套）：arch_inner～arch_outer 之間的石縫沿半徑放射。0＝沒有拱圈
uniform int arch_voussoirs = 0;
uniform vec2 arch_center = vec2(0.0, 2.0);
uniform float arch_inner = 1.6;
uniform float arch_outer = 2.15;
uniform float arch_key_extra = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 obj_pos;
varying vec3 obj_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	obj_pos = VERTEX;
	obj_normal = NORMAL;
}

// 到拱圈裡最近石縫的距離（公尺）；不在拱圈裡回傳 -1。只畫正面（拱洞內面在預覽時看不太到）。
float arch_joint(vec3 p, vec3 nrm) {
	if (arch_voussoirs <= 0 || abs(nrm.z) < 0.5) {
		return -1.0;
	}
	vec2 d = p.xy - arch_center;
	float r = length(d);
	float nv = float(arch_voussoirs);
	float step_a = PI / nv;
	float a = atan(d.y, d.x);
	float ai = clamp(floor(a / step_a), 0.0, nv - 1.0);
	float outer = arch_outer + (int(ai) * 2 + 1 == arch_voussoirs ? arch_key_extra : 0.0);
	if (d.y < -0.02 || r < arch_inner - 0.03 || r > outer + 0.012) {
		return -1.0;
	}
	float fa = clamp(a / step_a - ai, 0.0, 1.0);
	float fr = clamp((r - arch_inner) / (outer - arch_inner), 0.0, 1.0);
	return min(min(fa, 1.0 - fa) * step_a * max(r, 0.01), min(fr, 1.0 - fr) * (outer - arch_inner));
}

void fragment() {
	float h = (world_pos.y - base_y) / height;
	// 往上長：fill 以上只剩淡淡的輪廓，邊界有一道亮線
	float level = fill * 1.04;
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 2.5);
	if (h > level) {
		// 還沒長到的拱圈也淡淡看得到一塊塊拱石的放射縫（D-135）：預覽一開始就讀得出「這是一座拱」
		float aj0 = arch_joint(obj_pos, normalize(obj_normal));
		float ring_seam = aj0 >= 0.0 ? 1.0 - smoothstep(0.012, 0.03, aj0) : 0.0;
		float faint = 0.05 + 0.3 * fres + 0.14 * ring_seam;
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
		float joint = min(dm.x, dm.y);
		float aj = arch_joint(obj_pos, normalize(obj_normal));
		if (aj >= 0.0) {
			joint = aj;
		}
		float seam = 1.0 - smoothstep(0.012, 0.03, joint);
		float k = 0.04 + 0.55 * fres + 0.22 * seam + 1.2 * edge_line;
		ALBEDO = color * k;
		ALPHA = clamp(k, 0.0, 1.0);
	}
}
