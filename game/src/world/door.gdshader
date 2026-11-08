shader_type spatial;
// 門（D-070）：直排木板＋板縫、深色門框、兩道鐵條與鉚釘、門把鐵環，門腳被雪水浸濕變暗。
// 取代原本一塊平的深棕色方塊。跟窗（window_glass.gdshader）一樣用 BoxMesh 的面內 UV：
// fract(UV × (3, 2))，y=0 在上。每扇門的資料在頂點色（StaticBatch.add_box_tinted）：
//   g＝0..1 木色深淺與門把在哪一邊、b＝0..1 舊不舊（板子顏色不一、鐵條生鏽）
//   r＝1 門；r＝0 木箱／攤桌（D-077）：橫排木板、四邊都有框（角條）、沒有門把與鐵條
//   r＝0.4／0.5／0.6 店招（D-122）：木箱的樣子＋兩個大面畫靴子／壺／鑰匙的剪影；a＝1 大面朝 ±X、0 朝 ±Z

uniform vec3 wood_color : source_color = vec3(0.24, 0.17, 0.12);
uniform vec3 frame_color : source_color = vec3(0.1, 0.075, 0.055);
uniform vec3 iron_color : source_color = vec3(0.07, 0.07, 0.08);
uniform vec3 rust_color : source_color = vec3(0.22, 0.12, 0.07);
uniform float planks = 5.0;
uniform float frame_width = 0.07;
// 店招的剪影：褪色的淺黃漆
uniform vec3 paint_color : source_color = vec3(0.62, 0.5, 0.3);

varying vec3 face_normal;

void vertex() {
	face_normal = NORMAL;
}

float hash1(float n) {
	return fract(sin(n * 91.345) * 47453.5453);
}

float sd_box(vec2 p, vec2 c, vec2 h, float r) {
	vec2 q = abs(p - c) - h + r;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

// 店招的剪影（距離場，單位＝招牌高度，原點在中心、y 往上）。0 靴子、1 壺、2 鑰匙
float sign_icon(vec2 c, int icon) {
	if (icon == 0) {
		float leg = sd_box(c, vec2(-0.06, 0.07), vec2(0.09, 0.16), 0.02);
		float foot = sd_box(c, vec2(0.04, -0.13), vec2(0.19, 0.065), 0.055);
		float heel = sd_box(c, vec2(-0.12, -0.17), vec2(0.04, 0.03), 0.005);
		return min(min(leg, foot), heel);
	} else if (icon == 1) {
		float body = length(c - vec2(-0.03, -0.07)) - 0.16;
		float neck = sd_box(c, vec2(-0.03, 0.12), vec2(0.055, 0.08), 0.01);
		float lip = sd_box(c, vec2(-0.03, 0.2), vec2(0.085, 0.022), 0.01);
		float handle = abs(length((c - vec2(0.12, 0.0)) * vec2(1.0, 0.8)) - 0.09) - 0.022;
		handle = max(handle, 0.1 - c.x);
		return min(min(body, neck), min(lip, handle));
	}
	float bow = abs(length(c - vec2(-0.2, 0.0)) - 0.08) - 0.028;
	float shaft = sd_box(c, vec2(0.04, 0.0), vec2(0.17, 0.024), 0.01);
	float bit1 = sd_box(c, vec2(0.17, -0.06), vec2(0.03, 0.05), 0.005);
	float bit2 = sd_box(c, vec2(0.08, -0.045), vec2(0.022, 0.035), 0.005);
	return min(min(bow, shaft), min(bit1, bit2));
}

void fragment() {
	vec2 l = fract(UV * vec2(3.0, 2.0));
	float vary = COLOR.g;
	float age = COLOR.b;
	float door = step(0.75, COLOR.r);
	float is_sign = step(0.3, COLOR.r) * (1.0 - door);
	float aa = max(fwidth(l.x), fwidth(l.y)) * 1.2;
	vec2 d = min(l, 1.0 - l);
	// 門框：左右與上方（門腳沒有）；木箱是四邊一圈角條
	float frame = door > 0.5
		? max(1.0 - smoothstep(frame_width * 0.5, frame_width * 0.5 + aa, d.x),
			1.0 - smoothstep(frame_width * 0.3, frame_width * 0.3 + aa, l.y))
		: 1.0 - smoothstep(frame_width, frame_width + aa, min(d.x, d.y));
	// 木板：每片顏色略不同，板縫暗；木紋是沿板子方向的細條。門直排、木箱橫排
	float across = door > 0.5 ? l.x : l.y;
	float along = door > 0.5 ? l.y : l.x;
	float count = door > 0.5 ? planks : 4.0;
	float px = across * count;
	float plank = floor(px);
	float seam = smoothstep(0.0, 0.06 + aa * count, abs(fract(px) - 0.5) * 2.0 - 0.88);
	float tone = mix(0.8, 1.12, hash1(plank + vary * 17.0)) * mix(0.85, 1.1, vary);
	tone *= mix(1.0, mix(0.75, 1.15, hash1(plank * 3.1 + 5.0)), age);
	float grain = 0.92 + 0.08 * sin((along * 40.0 + hash1(plank) * 20.0) + sin(along * 9.0 + plank) * 2.0);
	vec3 col = wood_color * tone * grain * (1.0 - seam * 0.65);
	// 兩道鐵條（上 1/4、下 1/4）＋鉚釘
	float strap = 0.0;
	for (int i = 0; i < 2; i++) {
		float y = i == 0 ? 0.24 : 0.78;
		strap = max(strap, 1.0 - smoothstep(0.022, 0.022 + aa, abs(l.y - y)));
	}
	float rivet_row = min(abs(l.y - 0.24), abs(l.y - 0.78));
	float rivet = (1.0 - smoothstep(0.012, 0.02, length(vec2((fract(px) - 0.5) / planks, rivet_row)))) ;
	strap *= door;
	rivet *= door;
	vec3 iron = mix(iron_color, rust_color, age * 0.6);
	col = mix(col, iron, max(strap, rivet));
	// 門把鐵環（左或右）
	float handle_x = vary > 0.5 ? 0.82 : 0.18;
	float ring = abs(length((l - vec2(handle_x, 0.52)) * vec2(1.0, 2.1)) - 0.035);
	float handle = (1.0 - smoothstep(0.008, 0.008 + aa, ring)) * door;
	col = mix(col, iron * 1.4, handle);
	col = mix(col, frame_color, frame);
	// 店招的剪影：只畫在兩個大面（比例 0.72 × 0.5），背面左右相反（兩面都畫）
	float paint = 0.0;
	if (is_sign > 0.5) {
		float facing = COLOR.a > 0.5 ? abs(face_normal.x) : abs(face_normal.z);
		if (facing > 0.9) {
			int icon = int(floor((COLOR.r - 0.35) * 10.0));
			vec2 c = vec2((l.x - 0.5) * 1.44, 0.5 - l.y);
			float sd = sign_icon(c, icon);
			float edge = max(fwidth(sd), 0.004);
			paint = (1.0 - smoothstep(-edge, edge, sd)) * (1.0 - frame);
			// 漆舊了：斑駁掉色
			paint *= mix(1.0, 0.6 + 0.4 * hash1(floor(l.x * 23.0) + floor(l.y * 17.0) * 7.0), age);
		}
	}
	col = mix(col, paint_color * mix(1.0, 0.75, age), paint * 0.9);
	// 門腳被雪水浸濕
	float wet = smoothstep(door > 0.5 ? 0.82 : 0.86, 1.0, l.y);
	col *= mix(1.0, 0.6, wet);
	ALBEDO = col;
	float metal = max(max(strap, rivet), handle);
	METALLIC = metal * (1.0 - age * 0.5);
	ROUGHNESS = mix(mix(mix(0.82, 0.5, wet), 0.62, paint), 0.45, metal);
}
