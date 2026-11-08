shader_type spatial;
// 門（D-070）：直排木板＋板縫、深色門框、兩道鐵條與鉚釘、門把鐵環，門腳被雪水浸濕變暗。
// 取代原本一塊平的深棕色方塊。跟窗（window_glass.gdshader）一樣用 BoxMesh 的面內 UV：
// fract(UV × (3, 2))，y=0 在上。每扇門的資料在頂點色（StaticBatch.add_box_tinted）：
//   g＝0..1 木色深淺與門把在哪一邊、b＝0..1 舊不舊（板子顏色不一、鐵條生鏽）

uniform vec3 wood_color : source_color = vec3(0.24, 0.17, 0.12);
uniform vec3 frame_color : source_color = vec3(0.1, 0.075, 0.055);
uniform vec3 iron_color : source_color = vec3(0.07, 0.07, 0.08);
uniform vec3 rust_color : source_color = vec3(0.22, 0.12, 0.07);
uniform float planks = 5.0;
uniform float frame_width = 0.07;

float hash1(float n) {
	return fract(sin(n * 91.345) * 47453.5453);
}

void fragment() {
	vec2 l = fract(UV * vec2(3.0, 2.0));
	float vary = COLOR.g;
	float age = COLOR.b;
	float aa = max(fwidth(l.x), fwidth(l.y)) * 1.2;
	vec2 d = min(l, 1.0 - l);
	// 門框：左右與上方（門腳沒有）
	float frame = max(1.0 - smoothstep(frame_width * 0.5, frame_width * 0.5 + aa, d.x),
		1.0 - smoothstep(frame_width * 0.3, frame_width * 0.3 + aa, l.y));
	// 木板：每片顏色略不同，板縫暗；木紋是沿板子方向的細條
	float px = l.x * planks;
	float plank = floor(px);
	float seam = smoothstep(0.0, 0.06 + aa * planks, abs(fract(px) - 0.5) * 2.0 - 0.88);
	float tone = mix(0.8, 1.12, hash1(plank + vary * 17.0)) * mix(0.85, 1.1, vary);
	tone *= mix(1.0, mix(0.75, 1.15, hash1(plank * 3.1 + 5.0)), age);
	float grain = 0.92 + 0.08 * sin((l.y * 40.0 + hash1(plank) * 20.0) + sin(l.y * 9.0 + plank) * 2.0);
	vec3 col = wood_color * tone * grain * (1.0 - seam * 0.65);
	// 兩道鐵條（上 1/4、下 1/4）＋鉚釘
	float strap = 0.0;
	for (int i = 0; i < 2; i++) {
		float y = i == 0 ? 0.24 : 0.78;
		strap = max(strap, 1.0 - smoothstep(0.022, 0.022 + aa, abs(l.y - y)));
	}
	float rivet_row = min(abs(l.y - 0.24), abs(l.y - 0.78));
	float rivet = (1.0 - smoothstep(0.012, 0.02, length(vec2((fract(px) - 0.5) / planks, rivet_row)))) ;
	vec3 iron = mix(iron_color, rust_color, age * 0.6);
	col = mix(col, iron, max(strap, rivet));
	// 門把鐵環（左或右）
	float handle_x = vary > 0.5 ? 0.82 : 0.18;
	float ring = abs(length((l - vec2(handle_x, 0.52)) * vec2(1.0, 2.1)) - 0.035);
	float handle = 1.0 - smoothstep(0.008, 0.008 + aa, ring);
	col = mix(col, iron * 1.4, handle);
	col = mix(col, frame_color, frame);
	// 門腳被雪水浸濕
	float wet = smoothstep(0.82, 1.0, l.y);
	col *= mix(1.0, 0.6, wet);
	ALBEDO = col;
	float metal = max(max(strap, rivet), handle);
	METALLIC = metal * (1.0 - age * 0.5);
	ROUGHNESS = mix(mix(0.82, 0.5, wet), 0.45, metal);
}
